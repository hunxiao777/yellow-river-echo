import { image } from '@kit.ImageKit';
import { LengthMetricsUnit } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fs, paletteOf, Palette, withAlpha, hexLum, SUB } from '../common/Theme';
import { drawBand, drawPaper, drawPedestal, drawWord, tracePath } from '../common/PotteryArt';
import { ShapeMeta, TurntableFrames, TurntableIndex } from '../service/TurntableFrames';
import { PotteryCanvas } from './PotteryCanvas';

/*
 * 伪 3D 转台：灰模序列帧打底，釉色和纹样在 App 端现罩。
 *
 * 为什么不走真 3D：设备不支持 WebGL 时（探针见 pages/PotteryPage.ets）没有渲染通路，
 * 但器型的立体感又不能丢，所以烘帧脚本先把 5 种器型各 24 个角度转成灰模 webp，
 * 到这里只用二维 Canvas 把「颜色 / 纹样 / 题字」重新叠上去 —— 换釉色换纹样都不用重新烘帧，
 * 转台拖动也只是换一张已解码的位图。代价在罩层：模拟器实测，卡顿是按「一帧往主画布上落了几笔」
 * 收的（八笔 clip ≈ 每轮 300+ 丢帧，一笔 ≈ 0），所以罩层的笔数就是这一页的性能预算。
 *
 * 三层合成只用 ArkUI 明确支持的 Porter-Duff：
 *   source-over    灰模帧本体
 *   source-atop    釉色罩层 + 按弧度贴上去的纹样带（只落在帧的不透明像素里）
 *   destination-over 展示座、纸底（压到一切后面）
 * 没有 multiply/overlay 可用，所以釉色靠「带透明度的渐变 + source-atop」压色，
 * 灰模自身的明暗从半透明色底下透出来，就是上釉的效果。
 * 也正因为 source-atop 只认 alpha，帧的轮廓必须无损 —— 见 tools/bake_pottery_frames.mjs。
 * 一个 ArkUI 特有的坑：source-atop 下 fillText 一个字都不出（矢量照出），
 * 所以题字走的是「器身轮廓 clip + source-over」，见 wrap() 里那段。
 *
 * 罩层画在「帧坐标系」里：先把画布变换成 scale(s)+居中偏移，之后一律按 512×640 的帧像素
 * 坐标作画。烘帧时器物的 topPx/botPx 就是按二维版的 0.12/0.76 归一化投影出来的，
 * 所以 PotteryArt 里那套画法原封不动搬进帧坐标系，位置和大小都自动对齐。
 */

// 纹样带按弧度切成几段。段数越多越接近真实的圆柱透视，但每段都要 clip+transform 重画一遍
// 纹样，8 段是「肉眼看不出分段、每帧罩层不超过 20 笔矢量」的折中。
const SLABS: number = 8;
const SPIN_MS: number = 120;
const RESUME_MS: number = 2500;
// 展开带位图每个「展开单位」烘几个像素。屏上一整条纹样带约占 2710 设备像素，而展开周期只有
// per≈741 个单位，按 1 倍烘就是 3.7 倍放大、糊得一眼可见；3 倍是「不比矢量软」和 3.5 MB 之间的折中。
const STRIP_SS: number = 3;
// 罩釉的压实度不是拍脑袋的数值表，是跟灰模底亮度对着算出来的：
// FRAME_LUM 是灰模器身上半部的实测亮度中位数，TINT_TOL 是「罩完允许差多少」的亮度容差，
// TINT_MIN 以下灰模的明暗就透出来了 —— 伪 3D 剩下的立体感全指望它。
const FRAME_LUM: number = 179;
const TINT_TOL: number = 22;
const TINT_MIN: number = 0.62;
const TINT_MAX: number = 0.94;

@Component
export struct PotteryTurntable {
  @Prop @Watch('onParam') shape: string = '罐';
  @Prop @Watch('onParam') motif: string = '鱼纹';
  @Prop @Watch('onParam') glaze: string = 'yangshao';
  @Prop @Watch('onParam') pedestal: string = '素台';
  @Prop @Watch('onParam') word: string = '';
  @Prop @Watch('onParam') seed: number = 0;
  // 提示行也吃字号档位：这一页的字号档是全店统一的
  @StorageLink('textScale') ts: number = 1;
  // 首帧解码到位之前先摆二维预览：转台和灰模帧是「渐进增强」，不能拿白屏等图
  @State ready: boolean = false;
  @State hint: boolean = true;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private c2d: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private idx: TurntableIndex | null = null;
  private meta: ShapeMeta | null = null;
  private cur: image.PixelMap | null = null;
  private fw: number = 512;
  private fh: number = 640;
  private degStep: number = 15;
  private angle: number = 0;
  private fitScale: number = 0;
  private seq: number = 0;
  private lastKey: string = '';
  private dragging: boolean = false;
  private dragBase: number = 0;
  private idleAt: number = 0;
  private spin: number = -1;
  // 展开带缓存：一张「一个展开周期宽 × 纹样带高」的位图，换纹样/釉色/种子/器型时整张重烘
  // （一次矢量重画），转台每帧只剩 8~16 次贴图。题字不烘进来：它的周期是「一整圈」而不是半周，
  // 而且要 source-over + 轮廓 clip（见 wrap 第二遍），留在矢量那条路走。
  private strip: image.PixelMap | null = null;
  private stripKey: string = '';

  aboutToAppear(): void {
    let svc = TurntableFrames.get();
    this.idx = svc.loadIndex(getContext(this) as common.UIAbilityContext);
    this.meta = svc.metaOf(this.shape);
    let m = this.meta;
    if (this.idx !== null && m !== null) {
      this.fw = this.idx.canvas[0];
      this.fh = this.idx.canvas[1];
      this.degStep = this.idx.degStep > 0 ? this.idx.degStep : 15;
      this.showFrame();
      // 进页就把整套帧铺进缓存：转台每 120ms 走一笔，成像路径上绝不能现解码
      svc.preloadFrom(m.key, this.frameIdx(), this.frameCount());
    }
    this.ensureSpin();
  }

  aboutToDisappear(): void {
    if (this.spin >= 0) {
      clearInterval(this.spin);
      this.spin = -1;
    }
    this.cur = null;
    // 带子位图也是 native 内存，离页一并交回去
    let s = this.strip;
    this.strip = null;
    this.stripKey = '';
    if (s !== null) {
      s.release().then((): void => {});
    }
    TurntableFrames.get().releaseAll();
  }

  onParam(): void {
    let svc = TurntableFrames.get();
    let m = svc.metaOf(this.shape);
    this.meta = m;
    if (m === null || this.idx === null) {
      // 器型在映射表里没有帧（或表没读到）：build 里就还是那张二维画
      this.cur = null;
      this.ready = false;
      return;
    }
    this.fw = this.idx.canvas[0];
    this.fh = this.idx.canvas[1];
    // 换器型要先退回二维：手上有的是上一件器型的灰模，罩层却按新器型的半径和纹样带画，
    // 两套数据凑在一张图上会贴歪。釉色 / 纹样 / 题字 / 展示座不用重新拿帧，罩层每帧现画。
    if (m.key !== this.lastKey) {
      this.cur = null;
      this.ready = false;
      // 上一件那套帧立刻放掉，缓存位全留给新器型，不然新的一套还没解完就被旧的挤出去
      svc.keepOnly(m.key);
      this.showFrame();
      svc.preloadFrom(m.key, this.frameIdx(), this.frameCount());
      return;
    }
    this.showFrame();
  }

  frameCount(): number {
    let m = this.meta;
    return m !== null && m.frames > 0 ? m.frames : Math.round(360 / this.degStep);
  }

  frameIdx(): number {
    let n = this.frameCount();
    let step = 360 / n;
    let k = Math.round(this.angle / step);
    return ((k % n) + n) % n;
  }

  // 帧号 → 位图：缓存命中就立刻画，没命中等异步解码，同时把左右两帧先解好
  showFrame(): void {
    let m = this.meta;
    let svc = TurntableFrames.get();
    if (m === null) {
      return;
    }
    let n = this.frameCount();
    let f = this.frameIdx();
    // 闭包里读不到这里的空值收窄，先把键取出来，解码回来时按当时那件器物算
    let key = m.key;
    let hit = svc.peek(key, f);
    if (hit !== null) {
      this.cur = hit;
      this.lastKey = key;
      this.ready = true;
      this.paint();
    } else {
      let my = this.seq + 1;
      this.seq = my;
      svc.frame(key, f).then((pm: image.PixelMap | null): void => {
        // 慢回来的旧帧不能盖住新帧，不然拖动会倒着闪
        if (my !== this.seq) {
          return;
        }
        if (pm === null) {
          // 帧文件不在包里：留在二维，别让转台把一个空画布顶在预览位上
          this.meta = null;
          this.ready = false;
          return;
        }
        this.cur = pm;
        this.lastKey = key;
        this.ready = true;
        this.paint();
      });
    }
    svc.prefetch(key, (f + 1) % n);
    svc.prefetch(key, (f + n - 1) % n);
  }

  ensureSpin(): void {
    if (this.spin >= 0) {
      return;
    }
    this.spin = setInterval((): void => {
      if (this.dragging || Date.now() - this.idleAt < RESUME_MS) {
        return;
      }
      if (this.meta === null) {
        return;
      }
      this.angle += this.degStep;
      this.showFrame();
    }, SPIN_MS);
  }

  // 手指拖多少，器表就转多少：肚皮处的表面点在屏上走的正是 dx，所以 1 vp = 180/(πR) 度
  onDrag(dx: number): void {
    let m = this.meta;
    if (m === null || this.fitScale <= 0) {
      return;
    }
    let rVp = m.maxHalfPx * this.fitScale;
    if (rVp <= 0) {
      return;
    }
    this.angle = this.dragBase + dx * (180 / (Math.PI * rVp));
    this.showFrame();
  }

  paint(): void {
    let c = this.c2d;
    let w = c.width;
    let h = c.height;
    let m = this.meta;
    let cur = this.cur;
    if (w <= 0 || h <= 0 || m === null || cur === null) {
      return;
    }
    let p = paletteOf(this.glaze);
    let s = Math.min(w / this.fw, h / this.fh);
    this.fitScale = s;
    let ox = (w - this.fw * s) / 2;
    let oy = (h - this.fh * s) / 2;
    c.clearRect(0, 0, w, h);

    c.save();
    c.setTransform(s, 0, 0, s, ox, oy);
    c.globalCompositeOperation = 'source-over';
    c.drawImage(cur, 0, 0, this.fw, this.fh);
    this.tint(c, p, m);
    this.wrap(c, p, m);
    // 器表明暗放在纹样之后：装饰要泡在同一层光里，不然纹样是「贴上去的」而不是「长在器上的」
    this.shade(c, m);
    // 口沿、底足不再描：二维版那句 drawRimFoot 是拿来把「轮廓路径的平口」补成椭圆口的，
    // 而灰模帧的口、足、耳在 3D 里已经烘进位图了，再描一遍等于让一圈红环浮在罐口上方。
    // 量过帧的不透明包围盒：top=71 / bot=491 / 半宽 237，与映射表 77 / 488 / 236 对得上，
    // 所以不是位置算错，是这一笔根本不该画（复现：node .tmp/pot_preview/preview.mjs measure）。
    c.globalCompositeOperation = 'destination-over';
    drawPedestal(c, p, this.shape, this.pedestal, m.botPx, this.fw, this.fh);
    c.restore();

    // 纸底留在画布坐标铺满整块预览区：帧只有器物那一圈是不透明的，别的都归纸底
    c.globalCompositeOperation = 'destination-over';
    drawPaper(c, p, this.seed, w, h);
    c.globalCompositeOperation = 'source-over';
  }

  // 釉色罩层：带透明度的竖向渐变压在灰模上，source-atop 保证颜色只落在器身里
  private tint(c: CanvasRenderingContext2D, p: Palette, m: ShapeMeta): void {
    // 六套釉色的深浅差得很远，一刀切的 alpha 两头都不讨好：淡泥压高了就没有立体感，
    // 龙山黑陶压低了又压不住底色（实测被灰模提亮 80 个亮度级，黑陶变灰陶）。
    // 所以按「罩完的亮度落在目标色 ±TINT_TOL 里」反解 alpha：a = 1 - TOL/(FRAME_LUM - 釉亮度)
    let d = FRAME_LUM - hexLum(p.base);
    let a = d <= TINT_TOL ? TINT_MIN : Math.max(TINT_MIN, Math.min(TINT_MAX, 1 - TINT_TOL / d));
    let g: CanvasGradient = c.createLinearGradient(0, m.topPx, 0, m.botPx);
    // stop 与二维器身那一笔完全一致（PotteryCanvas 里 base / base@0.55 / deep@1），
    // 只多一层透明度：灰模自身的明暗从半透明底下透出来，就是上釉的样子。
    g.addColorStop(0, withAlpha(p.base, a));
    g.addColorStop(0.55, withAlpha(p.base, a));
    g.addColorStop(1, withAlpha(p.deep, Math.min(TINT_MAX, a + 0.08)));
    c.globalCompositeOperation = 'source-atop';
    c.fillStyle = g;
    c.fillRect(0, 0, this.fw, this.fh);
  }

  /* 器表明暗 —— 补的那道「这是个圆东西」的光。
   *
   * 为什么非补不可：烘帧的相机在赤道上（camera.position.set(0,0,camZ)、lookAt 原点），
   * fov 只有 8.123°，接近正投影。旋转体在正投影下每个方位的轮廓是一模一样的，
   * 灰模自己给不出「转」的体积线索 —— 除了耳和附件，24 帧几乎是同一张图，
   * 这就是「绕竖直轴看不出立体效果」的根因（帧数据可查：罐 24 帧内容包围盒逐帧同形）。
   *
   * 人眼读「圆东西在转」靠的是一对相反的线索：**明暗在屏幕上是固定的，纹样在器表上是跟着转的**。
   * 高光不跑、纹样跑，就成立；两者一起跑反而像一张贴纸在平移。所以这一笔走屏幕坐标、
   * 且必须压在纹样之后（装饰泡在同一层光里，才是长在器上的）。
   * 高光偏右：帧里的键光在 three 是 position.set(2.8, 3.4, 4.2)，+x 投到屏上就是右，
   * 补的光跟帧里本来的光必须同侧，不然一件器物上会出现两个光源。
   */
  private shade(c: CanvasRenderingContext2D, m: ShapeMeta): void {
    let r = m.maxHalfPx;
    if (r <= 0) {
      return;
    }
    let g: CanvasGradient = c.createLinearGradient(this.fw / 2 - r, 0, this.fw / 2 + r, 0);
    g.addColorStop(0, 'rgba(43,38,34,0.26)');
    g.addColorStop(0.30, 'rgba(43,38,34,0.02)');
    g.addColorStop(0.46, 'rgba(255,255,255,0)');
    g.addColorStop(0.64, 'rgba(255,255,255,0.15)');
    g.addColorStop(0.80, 'rgba(255,255,255,0.03)');
    g.addColorStop(1, 'rgba(43,38,34,0.30)');
    c.globalCompositeOperation = 'source-atop';
    c.fillStyle = g;
    c.fillRect(0, 0, this.fw, this.fh);
  }

  /* 把纹样带烘成一张「一个周期宽 × 带高」的位图。返回 false 表示这条路走不通（拿不到
     OffscreenCanvas / getPixelMap），调用方退回矢量重画那条老路，画面不变、只是慢。
     两个刻意的收窄，都是上一版把 render_service 拖死之后改的：
     · 只烘一个周期（per = πR）：纹样本来就是半周一循环，题字那种「整圈」周期交给矢量第二遍。
     · 只烘纹样带那一段高：整帧高、一整圈宽的带子在 density 3.5 的屏上是 5194×2240 ≈ 46 MB
       native 内存，上一版就是它撞上 watchdog 的（faultlog sysfreeze-render_service-1003，
       Reason: SERVICE_BLOCK，thread(RenderService) blocked 5s）。按带高裁后是 2223×393 ≈ 3.5 MB。
     取回来的尺寸用 STRIP 日志打进 hilog，是为了把「OffscreenCanvas 到底按什么单位建位图」这件事
     钉死：want 和 got 相等才说明画布真是按像素建的，贴图坐标才可以照展开单位直接算。 */
  private ensureStrip(p: Palette, m: ShapeMeta, y0: number, y1: number): boolean {
    let r = m.maxHalfPx;
    if (r <= 0 || y1 <= y0) {
      return false;
    }
    let per = Math.PI * r;
    let key = this.shape + '|' + this.motif + '|' + this.glaze + '|' + this.seed + '|'
      + Math.round(per) + '|' + Math.round(y0) + '|' + Math.round(y1);
    if (this.strip !== null && key === this.stripKey) {
      return true;
    }
    let old = this.strip;
    this.strip = null;
    this.stripKey = '';
    try {
      let wPx = Math.ceil(per * STRIP_SS);
      let hPx = Math.ceil((y1 - y0) * STRIP_SS);
      let off = new OffscreenCanvas(wPx, hPx, LengthMetricsUnit.PX);
      let o = off.getContext('2d', new RenderingContextSettings(true));
      // 先按 STRIP_SS 放大、再把带子上沿挪到 0：drawBand 照旧用帧坐标（y 落在 y0..y1）画，
      // 出来的位图就是「只有带子那一条」，行号和贴图那边一一对上。
      o.scale(STRIP_SS, STRIP_SS);
      o.translate(0, -y0);
      drawBand(o, p, this.motif, this.seed, 0, per, y0, y1, this.fh);
      let pm = o.getPixelMap(0, 0, wPx, hPx);
      let got = pm.getImageInfoSync().size;
      console.info('STRIP want ' + wPx + 'x' + hPx + ' got ' + got.width + 'x' + got.height);
      this.strip = pm;
      this.stripKey = key;
    } catch (e) {
      console.warn('band strip unavailable: keep vector wrap');
      if (this.strip !== null) {
        this.strip.release().then((): void => {});
        this.strip = null;
        this.stripKey = '';
      }
    }
    if (old !== null) {
      old.release().then((): void => {});
    }
    return this.strip !== null;
  }

  // 纹样带按弧度覆盖：把器表正对的半周展开成一条带，等角度切成 SLABS 段，
  // 每段把展开坐标线性映射到屏上的 sin 位置——边缘自然被压扁，就是圆柱的味道。
  // 展开周期取 P = πR（正好是半周长），所以 φ=0 时图案铺满整个正面，和二维版同一张纹样。
  private wrap(c: CanvasRenderingContext2D, p: Palette, m: ShapeMeta): void {
    let r = m.maxHalfPx;
    let per = Math.PI * r;
    let y0 = m.topPx + (m.botPx - m.topPx) * m.band[0];
    let y1 = m.topPx + (m.botPx - m.topPx) * m.band[1];
    // 角度取负喂给展开坐标：烘帧脚本是 holder.rotation.y = +deg（tools/bake_pottery_frames.mjs），
    // three.js 里 +Y 旋转把正面那点推向 +X，也就是屏上向右；而展开式 s=P/2+R(a+φ) 里 φ 变大
    // 图案是往左滑的。两个符号不拧过来，转台一转就成了「耳朵往右走、鱼纹往左溜」，
    // 釉色纹样像是浮在器表上没粘住（模拟器实测：拖 900px 帧号动 8 档、纹样带几乎不动）。
    let phi = -this.angle * Math.PI / 180;
    let da = Math.PI / SLABS;
    // 题字不跟周期走：按二维版的宽高比取号，再平移回展开带的正中，
    // 否则它会跟纹样一起被拉伸 1.44 倍，两个字就把罐肚占满了
    let wordW = 2 * r / 0.92;
    let wordLo = per / 2 - wordW / 2;
    let wordHi = per / 2 + wordW / 2;
    // 先把 8 段的「屏上窗口 / 展开窗口 / 压缩比」算一遍存下来：纹样带和题字是两遍
    // 绘制（见下），两遍必须用同一套分段，否则字和纹样会错缝；顺手也省掉一半三角函数。
    let xL: number[] = [];
    let xR: number[] = [];
    let sL: number[] = [];
    let sR: number[] = [];
    let sq: number[] = [];
    for (let k = 0; k < SLABS; k++) {
      let a0 = -Math.PI / 2 + k * da;
      let a1 = a0 + da;
      let x0 = this.fw / 2 + r * Math.sin(a0);
      let x1 = this.fw / 2 + r * Math.sin(a1);
      let s0 = per / 2 + r * (a0 + phi);
      let s1 = per / 2 + r * (a1 + phi);
      xL.push(x0);
      xR.push(x1);
      sL.push(s0);
      sR.push(s1);
      sq.push((x1 - x0) / (s1 - s0));
    }
    // 展开带缓存这条路：带子先烘成一张一个周期宽的位图，每帧只剩 8~16 次贴图而不是重画矢量。
    // 按位拆罩层能定位到这一层（同一协议、同一台模拟器，累计 jank 帧）：
    // 去掉纹样带这一层 → 13；只留它、别的全关 → 1023；全开 → 464~1093。
    // 但换成位图之后并没有立刻变快，三臂各复测（每臂 2~5 轮）：
    //   矢量 · 八段 clip      325 / 333 / 642
    //   位图 · 八段 clip      295 / 328 / 364 / 410 / 624
    //   位图 · 一笔贴平        0 / 0   （画面是错的：没有柱面压缩，纹样横着铺满）
    // 所以这笔钱是按「主画布上落了几笔」收的，跟几何是矢量还是贴图关系不大：
    // 缓存把卡顿从中位 333 压到 364，等于没压下来；真要丝滑得把八段并到一屏一笔里去。
    // 这一层先按「画面正确」定下来（纹样贴在器表上、到边缘自然压扁），减笔数单独一轮，
    // 不在这里顺手改画面。
    let blitted = false;
    if (this.ensureStrip(p, m, y0, y1)) {
      let bmp = this.strip;
      if (bmp !== null) {
        blitted = true;
        let bh = y1 - y0;
        let sw = r * da;
        c.globalCompositeOperation = 'source-atop';
        for (let k = 0; k < SLABS; k++) {
          // 展开坐标按一个周期取模回到带子里。贴图用「整张带子铺满 per·slope 宽、再按段 clip」
          // 而不是带源矩形的八参形式：官方 d.ts 里 drawImage 源矩形的单位跟着 API 版本变
          // （18 以前 px、以后 vp），而 OffscreenCanvas 建出来的位图按不按 density 放大查不到实锤，
          // 两头都不敢猜 —— 八参那版上设备实测就是纹样缩成一小块浮在罐肚右边（取证
          // .tmp/em_jank/crop2.png），只给目标矩形的五参形式压根没有源坐标，单位问题直接消失。
          let u = sL[k] - per * Math.floor(sL[k] / per);
          let wide = per * sq[k];
          let x0 = xL[k] - u * sq[k];
          c.save();
          c.beginPath();
          c.rect(xL[k], y0, xR[k] - xL[k], bh);
          c.clip();
          c.drawImage(bmp, x0, y0, wide, bh);
          // 跨接缝的那一段：左边贴完还差一截，把同一张带子往右平移一个周期再贴一笔
          if (u + sw > per) {
            c.drawImage(bmp, x0 + wide, y0, wide, bh);
          }
          c.restore();
        }
      }
    }
    if (!blitted) {
      // 第一遍：纹样带。矢量走 source-atop，只落在灰模的不透明像素里，耳、口沿都能挂上。
      c.globalCompositeOperation = 'source-atop';
      for (let k = 0; k < SLABS; k++) {
        c.save();
        c.beginPath();
        c.rect(xL[k], 0, xR[k] - xL[k], this.fh);
        c.clip();
        c.translate(xL[k], 0);
        c.scale(sq[k], 1);
        c.translate(-sL[k], 0);
        let j0 = Math.floor(sL[k] / per);
        let j1 = Math.floor(sR[k] / per);
        for (let j = j0; j <= j1; j++) {
          drawBand(c, p, this.motif, this.seed, j * per, (j + 1) * per, y0, y1, this.fh);
        }
        c.restore();
      }
    }
    // 第二遍：题字。单独一遍是因为 ArkUI 的 Canvas 在 source-atop 下不画文字 ——
    // 同一个 slab 变换里写两笔、只差这一句合成模式：source-atop 的蓝 S 是 0 像素，
    // source-over 的红 O 正好落在算出来的位置（帧坐标 318,349 vs 314.5,350）。
    // 浏览器没这个限制，所以 headless 那套对照查不出来，只有上设备才看得见。
    // 换成 source-over 就没了 alpha 那道闸，所以自己按器身轮廓 clip 一道补上；
    // 这道 clip 必须走在 slab 变换之前，不然轮廓路径会跟着展开变换一起被歪曲到别处。
    //
    // 字还要按「整圈」复制着比：this.angle 是累加的（自动转台每 120ms 走 15°），
    // 只比一份窗口的话转过 ~152° 后 s0 永远大于 wordHi，字就再也不出来了。
    // 周期取 2·per（= 一整圈），所以字只出现在正面，转到背面自然消失。
    // 「只出现在正面」是量出来的，不是猜的：headless 按 15° 扫一整圈 24 档
    // （node .tmp/pot_preview/preview.mjs wordprobe），0°~45° 完整、60° 只剩 16×20、
    // 75°~285° 全被轮廓切掉，300° 起又回来；模拟器同一批角度逐档对得上，
    // 累加角 1050° 与裸角 330° 的暗像素数一模一样（4002）—— 说明 2·per 复制没有误差。
    if (this.word.length > 0) {
      c.save();
      tracePath(c, this.shape, this.fw, this.fh);
      c.clip();
      c.globalCompositeOperation = 'source-over';
      let nBase = Math.round(r * phi / (2 * per));
      for (let k = 0; k < SLABS; k++) {
        c.save();
        c.beginPath();
        c.rect(xL[k], 0, xR[k] - xL[k], this.fh);
        c.clip();
        c.translate(xL[k], 0);
        c.scale(sq[k], 1);
        c.translate(-sL[k], 0);
        for (let n = nBase - 1; n <= nBase + 1; n++) {
          let wLo = wordLo + 2 * n * per;
          let wHi = wordHi + 2 * n * per;
          if (sR[k] > wLo && sL[k] < wHi) {
            c.save();
            c.translate(wLo, 0);
            drawWord(c, p, this.word, this.shape, this.seed, wordW, this.fh);
            c.restore();
          }
        }
        c.restore();
      }
      c.restore();
      c.globalCompositeOperation = 'source-atop';
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.ready && this.meta !== null) {
        Canvas(this.c2d)
          .width('100%')
          .height('100%')
          // 压一层不透明的纸色。画布在首笔落下之前是全透明的，而预览位是个 Stack，
          // 底下还垫着 ArkWeb 真 3D 页（探针，WebGL 建不起来、rAF 又被系统按不可见节流），
          // 于是那一瞬漏出来的是「白底 + 没擦干净的上一帧器物」—— 模拟器实测：退到桌面
          // 再拉回彩陶页，预览位十几秒里显示的就是这张没有纸底的罐子，点配色也不动
          // （取证 .tmp/em_verify/link_龙山黑_full.png，纸底 #ffffff、纯白占比 53%）。
          // 底色取当前釉色的纸色，首笔之前最多是一整张纸，跟罩完的纸底接得上。
          .backgroundColor(paletteOf(this.glaze).paper)
          .onReady((): void => {
            this.paint();
          })
      } else {
        PotteryCanvas({
          shape: this.shape,
          motif: this.motif,
          glaze: this.glaze,
          pedestal: this.pedestal,
          word: this.word,
          seed: this.seed
        })
      }

      if (this.ready && this.hint) {
        Text('‹ 左右拖动转台 ›')
          .fontSize(fs(this.ts, 10))
          .fontColor(SUB)
          .padding({ left: 10, right: 10, top: 3, bottom: 3 })
          .borderRadius(9)
          .backgroundColor('rgba(255,255,255,0.72)')
          .margin({ bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 1 })
      .onActionStart((e: GestureEvent): void => {
        this.dragging = true;
        this.dragBase = this.angle;
        this.hint = false;
      })
      .onActionUpdate((e: GestureEvent): void => {
        this.onDrag(e.offsetX);
      })
      .onActionEnd((): void => {
        this.dragging = false;
        this.idleAt = Date.now();
      })
      .onActionCancel((): void => {
        this.dragging = false;
        this.idleAt = Date.now();
      }))
  }
}
