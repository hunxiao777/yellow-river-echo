import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { fs, paletteOf, Palette, withAlpha, SUB } from '../common/Theme';
import { drawBand, drawPaper, drawPedestal, drawRimFoot, drawWord } from '../common/PotteryArt';
import { ShapeMeta, TurntableFrames, TurntableIndex } from '../service/TurntableFrames';
import { PotteryCanvas } from './PotteryCanvas';

/*
 * 伪 3D 转台：灰模序列帧打底，釉色和纹样在 App 端现罩。
 *
 * 为什么不走真 3D：设备不支持 WebGL 时（探针见 pages/PotteryPage.ets）没有渲染通路，
 * 但器型的立体感又不能丢，所以烘帧脚本先把 5 种器型各 24 个角度转成灰模 webp，
 * 到这里只用二维 Canvas 把「颜色 / 纹样 / 题字」重新叠上去 —— 换釉色换纹样都不用重新烘帧，
 * 转台拖动也只是换一张已解码的位图，成本全在罩层那几笔矢量上。
 *
 * 三层合成只用 ArkUI 明确支持的 Porter-Duff：
 *   source-over    灰模帧本体
 *   source-atop    釉色罩层 + 按弧度贴上去的纹样带（只落在帧的不透明像素里）
 *   destination-over 展示座、纸底（压到一切后面）
 * 没有 multiply/overlay 可用，所以釉色靠「带透明度的渐变 + source-atop」压色，
 * 灰模自身的明暗从半透明色底下透出来，就是上釉的效果。
 * 也正因为 source-atop 只认 alpha，帧的轮廓必须无损 —— 见 tools/bake_pottery_frames.mjs。
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

  aboutToAppear(): void {
    let svc = TurntableFrames.get();
    this.idx = svc.loadIndex(getContext(this) as common.UIAbilityContext);
    this.meta = svc.metaOf(this.shape);
    if (this.idx !== null && this.meta !== null) {
      this.fw = this.idx.canvas[0];
      this.fh = this.idx.canvas[1];
      this.degStep = this.idx.degStep > 0 ? this.idx.degStep : 15;
      this.showFrame();
    }
    this.ensureSpin();
  }

  aboutToDisappear(): void {
    if (this.spin >= 0) {
      clearInterval(this.spin);
      this.spin = -1;
    }
    this.cur = null;
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
    c.globalCompositeOperation = 'source-over';
    drawRimFoot(c, p, this.shape, this.fw, this.fh);
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
    let g: CanvasGradient = c.createLinearGradient(0, m.topPx, 0, m.botPx);
    g.addColorStop(0, withAlpha(p.paper, 0.55));
    g.addColorStop(0.45, withAlpha(p.base, 0.80));
    g.addColorStop(1, withAlpha(p.deep, 0.86));
    c.globalCompositeOperation = 'source-atop';
    c.fillStyle = g;
    c.fillRect(0, 0, this.fw, this.fh);
  }

  // 纹样带按弧度覆盖：把器表正对的半周展开成一条带，等角度切成 SLABS 段，
  // 每段把展开坐标线性映射到屏上的 sin 位置——边缘自然被压扁，就是圆柱的味道。
  // 展开周期取 P = πR（正好是半周长），所以 φ=0 时图案铺满整个正面，和二维版同一张纹样。
  private wrap(c: CanvasRenderingContext2D, p: Palette, m: ShapeMeta): void {
    let r = m.maxHalfPx;
    let per = Math.PI * r;
    let y0 = m.topPx + (m.botPx - m.topPx) * m.band[0];
    let y1 = m.topPx + (m.botPx - m.topPx) * m.band[1];
    let phi = this.angle * Math.PI / 180;
    let da = Math.PI / SLABS;
    // 题字不跟周期走：按二维版的宽高比取号，再平移回展开带的正中，
    // 否则它会跟纹样一起被拉伸 1.44 倍，两个字就把罐肚占满了
    let wordW = 2 * r / 0.92;
    let wordLo = per / 2 - wordW / 2;
    let wordHi = per / 2 + wordW / 2;
    c.globalCompositeOperation = 'source-atop';
    for (let k = 0; k < SLABS; k++) {
      let a0 = -Math.PI / 2 + k * da;
      let a1 = a0 + da;
      let x0 = this.fw / 2 + r * Math.sin(a0);
      let x1 = this.fw / 2 + r * Math.sin(a1);
      let s0 = per / 2 + r * (a0 + phi);
      let s1 = per / 2 + r * (a1 + phi);
      c.save();
      c.beginPath();
      c.rect(x0, 0, x1 - x0, this.fh);
      c.clip();
      c.translate(x0, 0);
      c.scale((x1 - x0) / (s1 - s0), 1);
      c.translate(-s0, 0);
      let j0 = Math.floor(s0 / per);
      let j1 = Math.floor(s1 / per);
      for (let j = j0; j <= j1; j++) {
        drawBand(c, p, this.motif, this.seed, j * per, (j + 1) * per, y0, y1, this.fh);
      }
      if (this.word.length > 0 && s1 > wordLo && s0 < wordHi) {
        c.translate(per / 2 - wordW / 2, 0);
        drawWord(c, p, this.word, this.shape, this.seed, wordW, this.fh);
      }
      c.restore();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.ready && this.meta !== null) {
        Canvas(this.c2d)
          .width('100%')
          .height('100%')
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
