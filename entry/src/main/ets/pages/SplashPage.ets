import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Boot } from '../service/Boot';
import { StudioStore } from '../service/StudioStore';
import { INK, SUB, LOESS, CLAY, RIVER } from '../common/Theme';

// 几字形河道，归一化坐标，画的时候按画布尺寸缩放
const RIVER_PTS: number[][] = [
  [0.10, 0.16], [0.28, 0.12], [0.50, 0.19], [0.62, 0.31],
  [0.50, 0.41], [0.32, 0.48], [0.30, 0.62], [0.46, 0.72],
  [0.68, 0.74], [0.86, 0.66]
];

@Entry
@Component
struct SplashPage {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State draw: number = 0;
  @State titleIn: number = 0;
  private timer: number = -1;
  private step: number = 0;
  private leaving: boolean = false;

  aboutToAppear(): void {
    let ctx = getContext(this) as common.UIAbilityContext;
    let started = Date.now();
    Boot.run(ctx).catch((e: Error): void => {
      console.error('boot: ' + e.message);
    });
    this.timer = setInterval((): void => {
      this.step += 1;
      this.draw = Math.min(this.step / 14, 1);
      this.titleIn = Math.min(this.step / 8, 1);
      this.paint();
      if (this.step >= 20 && Date.now() - started > 1700 && !this.leaving) {
        this.leaving = true;
        clearInterval(this.timer);
        this.go();
      }
    }, 60);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  go(): void {
    let s = StudioStore.get();
    if (!s.guideSeen) {
      router.replaceUrl({ url: 'pages/GuidePage' });
    } else if (!s.signedIn()) {
      router.replaceUrl({ url: 'pages/LoginPage' });
    } else {
      router.replaceUrl({ url: 'pages/Index' });
    }
  }

  private paint(): void {
    let c = this.ctx;
    let w = c.width;
    let h = c.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    c.clearRect(0, 0, w, h);

    // 远山：两层淡墨
    c.fillStyle = 'rgba(122,110,98,0.10)';
    c.beginPath();
    c.moveTo(0, h * 0.30);
    c.quadraticCurveTo(w * 0.22, h * 0.18, w * 0.44, h * 0.29);
    c.quadraticCurveTo(w * 0.68, h * 0.40, w, h * 0.26);
    c.lineTo(w, h);
    c.lineTo(0, h);
    c.closePath();
    c.fill();
    c.fillStyle = 'rgba(74,123,140,0.10)';
    c.beginPath();
    c.moveTo(0, h * 0.44);
    c.quadraticCurveTo(w * 0.30, h * 0.34, w * 0.58, h * 0.46);
    c.quadraticCurveTo(w * 0.80, h * 0.55, w, h * 0.48);
    c.lineTo(w, h);
    c.lineTo(0, h);
    c.closePath();
    c.fill();

    // 河道：按 draw 逐段推进
    let n = RIVER_PTS.length;
    let reach = this.draw * (n - 1);
    c.lineCap = 'round';
    c.lineJoin = 'round';
    c.strokeStyle = 'rgba(200,161,96,0.55)';
    c.lineWidth = Math.max(w * 0.055, 10);
    c.beginPath();
    c.moveTo(RIVER_PTS[0][0] * w, RIVER_PTS[0][1] * h);
    for (let i = 1; i < n; i++) {
      if (i > reach) {
        break;
      }
      let p = RIVER_PTS[i];
      let prev = RIVER_PTS[i - 1];
      let frac = Math.min(reach - (i - 1), 1);
      let x = prev[0] * w + (p[0] * w - prev[0] * w) * frac;
      let y = prev[1] * h + (p[1] * h - prev[1] * h) * frac;
      let mx = (prev[0] * w + x) / 2;
      c.quadraticCurveTo(prev[0] * w + (mx - prev[0] * w) * 0.9, prev[1] * h, x, y);
    }
    c.stroke();
    c.strokeStyle = 'rgba(255,252,246,0.55)';
    c.lineWidth = Math.max(w * 0.012, 2);
    c.stroke();

    // 日头
    c.fillStyle = 'rgba(166,85,61,0.75)';
    c.beginPath();
    c.arc(w * 0.80, h * 0.14, w * 0.035 * Math.min(this.draw * 1.6, 1), 0, Math.PI * 2);
    c.fill();

    // 掠水鸟
    if (this.draw > 0.5) {
      c.strokeStyle = 'rgba(43,38,34,0.45)';
      c.lineWidth = 1.6;
      let birds: number[][] = [[0.62, 0.10], [0.70, 0.075], [0.76, 0.115]];
      for (let b of birds) {
        let bx = b[0] * w;
        let by = b[1] * h;
        let r = w * 0.018;
        c.beginPath();
        c.moveTo(bx - r, by);
        c.quadraticCurveTo(bx - r * 0.4, by - r * 0.7, bx, by - r * 0.1);
        c.quadraticCurveTo(bx + r * 0.4, by - r * 0.7, bx + r, by);
        c.stroke();
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .onReady((): void => {
          this.paint();
        })

      Column({ space: 10 }) {
        Text('黄河续响平台')
          .fontSize(40)
          .fontColor(INK)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(8)
          .opacity(this.titleIn)
        Text('黄河文化分布式数字档案')
          .fontSize(14)
          .fontColor(SUB)
          .letterSpacing(3)
          .opacity(this.titleIn)
        Row({ space: 6 }) {
          Circle().width(6).height(6).fill(LOESS)
          Circle().width(6).height(6).fill(CLAY).opacity(0.7)
          Circle().width(6).height(6).fill(RIVER).opacity(0.5)
        }
        .margin({ top: 18 })
        .opacity(this.titleIn)
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 30, bottom: 64 })

      Text('按时间沉淀的东西，值得再捞一次')
        .fontSize(11)
        .fontColor(SUB)
        .opacity(this.draw * 0.8)
        .padding({ left: 30, bottom: 34 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .onClick((): void => {
      if (!this.leaving && this.step >= 8) {
        this.leaving = true;
        clearInterval(this.timer);
        this.go();
      }
    })
  }
}
