import { SiteInfo } from '../model/Models';
import { SiteRepo } from '../service/SiteRepo';
import { StudioStore } from '../service/StudioStore';
import {
  ERAS, CITIES, WATER_FLOW, WATER_STILL, WATER_OFF,
  SUB, fs
} from '../common/Theme';

// 河道母题（扩展设计方案 §1）：一条纯矢量干流 + 两岸遗址点，
// 首页开篇、详情页缩略、测试结果页共用这一份几何，不各画一套。

export function effectiveWaterMode(): string {
  // 河道动效已按要求撤掉：河还是画出来，但不再有常开的流水帧。
  // 侧栏那个「河道动效/静水/关闭」开关也一并删了，这里固定回静水，
  // BasinMap 里的水花、点选缓动照旧按忙闲起停，只是不再常年占一帧。
  return WATER_STILL;
}

// 干流中轴：u∈[0,1] 自西向东，返回归一化纵坐标。
// 用两条正弦叠加，得到"几"字弯的手感，且任意 u 都能精确取点（落点/高光带共用）。
export function riverY(u: number): number {
  let v = 0.5 + 0.20 * Math.sin(u * Math.PI * 1.7 + 0.42) + 0.055 * Math.sin(u * Math.PI * 3.1 + 1.1);
  if (v < 0.12) {
    return 0.12;
  }
  return v > 0.88 ? 0.88 : v;
}

// 遗址落点：横轴=年代（仰韶→宋），纵轴=城市在名单里的次序（自西向东）偏移。
// 这是示意排布，不是真实经纬度，界面上必须带着 note 那句话。
export function siteU(s: SiteInfo): number {
  let era = s.eras.length > 0 ? s.eras[0] : ERAS[0];
  let i = ERAS.indexOf(era);
  if (i < 0) {
    i = Math.floor(ERAS.length / 2);
  }
  return (i + 0.5) / ERAS.length;
}

export function siteLane(s: SiteInfo): number {
  let i = CITIES.indexOf(s.city);
  if (i < 0) {
    return 0;
  }
  return (i - (CITIES.length - 1) / 2) * 0.11;
}

// 同年代同城市的遗址会撞在同一个点上，按 id 做确定性抖开（不是随机，重进页面位置不变）
function hashOf(s: string): number {
  let n = 0;
  for (let i = 0; i < s.length; i++) {
    n = (n * 31 + s.charCodeAt(i)) % 9973;
  }
  return n;
}

export interface DotPos {
  x: number;
  y: number;
}

// 遗址在河道带里的落点（单位 vp）。RiverRibbon 按它画点，打卡页按它做点击命中，
// 两边共用一份几何，否则"点得中的地方"和"看得见的点"会错开。
export function siteDot(s: SiteInfo, w: number, h: number): DotPos {
  let hsh = hashOf(s.id);
  let u = siteU(s) + ((hsh % 5) - 2) * 0.006;
  let x = u * w;
  let y = riverY(u) * h + siteLane(s) * h + ((hsh % 3) - 1) * 4;
  if (y < 5) {
    y = 5;
  } else if (y > h - 5) {
    y = h - 5;
  }
  return { x: x, y: y };
}

@Component
export struct RiverRibbon {
  // 字号档位变了要整页重画：不持有这行，切档后这一页还是老字号
  @StorageLink('textScale') ts: number = 1;
  @Prop activeId: string = '';
  @Prop showDots: boolean = true;
  @Prop bandHeight: number = 78;
  @Prop note: string = '';
  @StorageLink('studioRev') @Watch('refresh') rev: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private timer: number = -1;
  private phase: number = 0;

  aboutToDisappear(): void {
    this.stop();
  }

  refresh(): void {
    this.stop();
    this.paint();
    this.start();
  }

  start(): void {
    if (effectiveWaterMode() !== WATER_FLOW || this.timer >= 0) {
      return;
    }
    this.timer = setInterval((): void => {
      this.phase = (this.phase + 0.006) % 1;
      this.paint();
    }, 90);
  }

  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private strokeRiver(c: CanvasRenderingContext2D, w: number, h: number,
    u0: number, u1: number, style: string, width: number): void {
    let steps = 14;
    c.beginPath();
    for (let k = 0; k <= steps; k++) {
      let u = u0 + (u1 - u0) * (k / steps);
      let x = u * w;
      let y = riverY(u) * h;
      if (k === 0) {
        c.moveTo(x, y);
      } else {
        c.lineTo(x, y);
      }
    }
    c.strokeStyle = style;
    c.lineWidth = width;
    c.stroke();
  }

  private paint(): void {
    let c = this.ctx;
    let w = c.width;
    let h = c.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    c.clearRect(0, 0, w, h);
    let mode = effectiveWaterMode();
    if (mode === WATER_OFF) {
      return;
    }
    let bandW = Math.max(h * 0.17, 7);

    // 主河道 + 水面亮线
    this.strokeRiver(c, w, h, 0, 1, 'rgba(200,161,96,0.34)', bandW);
    this.strokeRiver(c, w, h, 0, 1, 'rgba(200,161,96,0.55)', bandW * 0.55);
    this.strokeRiver(c, w, h, 0, 1, 'rgba(255,251,242,0.62)', Math.max(h * 0.03, 1.4));

    // 三条高光带沿中轴向东移；静水档只留首带，位置固定
    let bands: number[][] = [
      [0, 0.055, 0.30, 3.2],
      [0.34, 0.030, 0.22, 2.0],
      [0.67, 0.075, 0.26, 4.0]
    ];
    for (let b of bands) {
      let u0 = (mode === WATER_FLOW ? this.phase + b[0] : b[0]) % 1;
      let u1 = u0 + b[1];
      if (u1 > 1) {
        this.strokeRiver(c, w, h, u0, 1, `rgba(74,123,140,${b[2]})`, bandW * 0.5);
        this.strokeRiver(c, w, h, 0, u1 - 1, `rgba(74,123,140,${b[2]})`, bandW * 0.5);
      } else {
        this.strokeRiver(c, w, h, u0, u1, `rgba(74,123,140,${b[2]})`, bandW * 0.5);
      }
    }

    if (!this.showDots) {
      return;
    }
    let checked = StudioStore.get().checkedSiteIds();
    for (let s of SiteRepo.get().sites) {
      let p = siteDot(s, w, h);
      let x = p.x;
      let y = p.y;
      let on = checked.indexOf(s.id) >= 0;
      let active = s.id === this.activeId;
      if (on) {
        c.beginPath();
        c.arc(x, y, active ? 5 : 3.4, 0, Math.PI * 2);
        c.fillStyle = 'rgba(166,85,61,0.92)';
        c.fill();
        c.beginPath();
        c.arc(x, y, active ? 8.5 : 6.4, 0, Math.PI * 2);
        c.strokeStyle = 'rgba(166,85,61,0.45)';
        c.lineWidth = 1.2;
        c.stroke();
      } else {
        c.beginPath();
        c.arc(x, y, active ? 4.4 : 2.6, 0, Math.PI * 2);
        c.strokeStyle = 'rgba(122,110,98,0.75)';
        c.lineWidth = 1.2;
        c.stroke();
      }
      if (active) {
        c.beginPath();
        c.moveTo(x, y - (active ? 11 : 9));
        c.lineTo(x, y - 3);
        c.strokeStyle = 'rgba(43,38,34,0.6)';
        c.lineWidth = 1.1;
        c.stroke();
      }
    }
  }

  build() {
    Column({ space: 3 }) {
      Canvas(this.ctx)
        .width('100%')
        .height(this.bandHeight)
        .onReady((): void => {
          this.paint();
          this.start();
        })
      if (this.note.length > 0) {
        Text(this.note)
          .fontSize(fs(this.ts, 9))
          .fontColor(SUB)
          .opacity(0.85)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
