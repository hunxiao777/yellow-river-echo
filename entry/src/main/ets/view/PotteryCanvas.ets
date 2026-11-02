import { paletteOf, Palette } from '../common/Theme';
import {
  V_TOP, V_BOT, profileOf, bandOf, tracePath, motifPainter, drawWord
} from '../common/PotteryArt';

// 彩陶组装预览：器型、纹样、配色、题字、展示座全部按画布尺寸归一化现画。
// shape：罐 / 盆 / 壶 / 瓶 / 鼎式；glaze 存 palette key；pedestal：素台 / 木座 / 圆几 / 无
//
// 轮廓和纹样的画法抽到了 common/PotteryArt.ets，由这里和 view/PotteryTurntable.ets
// 共用一份：转台要把同一套纹样按弧度罩到 3D 灰模序列帧上，两边各写一遍的话，
// 改一种纹样只会在一边生效，而这种差异只有拿两台设备对着看才看得出来。
// 这个组件同时也是转台拿不到帧文件时的兜底画面，它必须一直能独立画完一件器物。

@Component
export struct PotteryCanvas {
  @Prop @Watch('repaint') shape: string = '罐';
  @Prop @Watch('repaint') motif: string = '鱼纹';
  @Prop @Watch('repaint') glaze: string = 'yangshao';
  @Prop @Watch('repaint') pedestal: string = '素台';
  @Prop @Watch('repaint') word: string = '';
  @Prop @Watch('repaint') seed: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  repaint(): void {
    this.paint();
  }

  private bg(c: CanvasRenderingContext2D, p: Palette, w: number, h: number): void {
    let g: CanvasGradient = c.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, p.paper);
    g.addColorStop(1, p.base);
    c.fillStyle = g;
    c.fillRect(0, 0, w, h);
    c.fillStyle = 'rgba(255,255,255,0.22)';
    for (let i = 0; i < 5; i++) {
      let yy = h * (0.10 + i * 0.19) + (this.seed % 5) * h * 0.01;
      c.beginPath();
      c.moveTo(0, yy);
      c.quadraticCurveTo(w * 0.5, yy - h * 0.04, w, yy + h * 0.02);
      c.lineTo(w, yy + h * 0.03);
      c.quadraticCurveTo(w * 0.5, yy - h * 0.01, 0, yy + h * 0.03);
      c.closePath();
      c.fill();
    }
  }

  private feet(c: CanvasRenderingContext2D, p: Palette, w: number, h: number): void {
    if (this.shape !== '鼎式') {
      return;
    }
    let bot = h * V_BOT;
    let top = h * V_TOP;
    c.fillStyle = p.deep;
    let xs: number[] = [w / 2 - w * 0.20, w / 2, w / 2 + w * 0.20];
    for (let i = 0; i < xs.length; i++) {
      let fx = xs[i];
      let fl = (bot - top) * (i === 1 ? 0.14 : 0.20);
      c.beginPath();
      c.moveTo(fx - w * 0.045, bot - (bot - top) * 0.06);
      c.lineTo(fx + w * 0.045, bot - (bot - top) * 0.06);
      c.lineTo(fx + w * 0.03, bot + fl);
      c.lineTo(fx - w * 0.03, bot + fl);
      c.closePath();
      c.fill();
    }
  }

  private drawPedestal(c: CanvasRenderingContext2D, p: Palette, w: number, h: number): void {
    let base = h * V_BOT + (h - h * V_BOT) * 0.42;
    if (this.shape === '鼎式') {
      base = h * V_BOT + (h - h * V_BOT) * 0.53;
    }
    if (this.pedestal === '无') {
      c.fillStyle = 'rgba(43,38,34,0.10)';
      c.beginPath();
      c.ellipse(w / 2, base, w * 0.30, h * 0.03, 0, 0, Math.PI * 2);
      c.fill();
      return;
    }
    c.fillStyle = 'rgba(43,38,34,0.12)';
    c.beginPath();
    c.ellipse(w / 2, base + h * 0.055, w * 0.36, h * 0.035, 0, 0, Math.PI * 2);
    c.fill();
    if (this.pedestal === '木座') {
      c.fillStyle = '#5A4030';
      c.beginPath();
      c.moveTo(w * 0.24, base);
      c.lineTo(w * 0.76, base);
      c.lineTo(w * 0.70, base + h * 0.055);
      c.lineTo(w * 0.30, base + h * 0.055);
      c.closePath();
      c.fill();
      c.fillRect(w * 0.30, base + h * 0.055, w * 0.055, h * 0.045);
      c.fillRect(w * 0.645, base + h * 0.055, w * 0.055, h * 0.045);
      c.fillRect(w * 0.47, base + h * 0.055, w * 0.06, h * 0.035);
    } else if (this.pedestal === '圆几') {
      c.strokeStyle = p.accent;
      c.lineWidth = Math.max(w * 0.012, 1.5);
      let rx = w * 0.30;
      c.beginPath();
      c.ellipse(w / 2, base, rx, h * 0.045, 0, 0, Math.PI * 2);
      c.fillStyle = 'rgba(255,255,255,0.35)';
      c.fill();
      c.stroke();
      for (let i = -1; i <= 1; i++) {
        c.beginPath();
        c.moveTo(w / 2 + i * rx * 0.66, base + h * 0.03);
        c.lineTo(w / 2 + i * rx * 0.80, base + h * 0.09);
        c.stroke();
      }
    } else {
      c.fillStyle = 'rgba(255,255,255,0.55)';
      c.fillRect(w * 0.20, base, w * 0.60, h * 0.055);
      c.strokeStyle = p.deep;
      c.lineWidth = Math.max(w * 0.008, 1);
      c.strokeRect(w * 0.20, base, w * 0.60, h * 0.055);
    }
  }

  private drawMotif(c: CanvasRenderingContext2D, p: Palette, w: number, h: number): void {
    let top = h * V_TOP;
    let bot = h * V_BOT;
    let bd = bandOf(this.shape);
    let y0 = top + (bot - top) * bd[0];
    let y1 = top + (bot - top) * bd[1];
    c.save();
    c.beginPath();
    c.rect(0, y0, w, y1 - y0);
    c.clip();
    c.fillStyle = 'rgba(255,255,255,0.16)';
    c.fillRect(0, y0, w, y1 - y0);
    motifPainter(this.motif)(c, p, 0, w, y0, y1, this.seed);
    c.strokeStyle = p.accent;
    c.lineWidth = Math.max(h * 0.006, 1);
    c.beginPath();
    c.moveTo(0, y0 + (y1 - y0) * 0.03);
    c.lineTo(w, y0 + (y1 - y0) * 0.03);
    c.moveTo(0, y1 - (y1 - y0) * 0.03);
    c.lineTo(w, y1 - (y1 - y0) * 0.03);
    c.stroke();
    c.restore();
  }

  private paint(): void {
    let c = this.ctx;
    let w = c.width;
    let h = c.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    let p = paletteOf(this.glaze);
    let top = h * V_TOP;
    let bot = h * V_BOT;
    c.clearRect(0, 0, w, h);
    this.bg(c, p, w, h);
    this.feet(c, p, w, h);

    tracePath(c, this.shape, w, h);
    let g: CanvasGradient = c.createLinearGradient(0, top, 0, bot);
    g.addColorStop(0, p.base);
    g.addColorStop(0.55, p.base);
    g.addColorStop(1, p.deep);
    c.fillStyle = g;
    c.fill();

    tracePath(c, this.shape, w, h);
    c.save();
    c.clip();
    this.drawMotif(c, p, w, h);
    drawWord(c, p, this.word, this.shape, this.seed, w, h);
    c.fillStyle = 'rgba(43,38,34,0.14)';
    c.fillRect(w * 0.62, top, w * 0.40, bot - top);
    c.restore();

    tracePath(c, this.shape, w, h);
    c.strokeStyle = p.deep;
    c.lineWidth = Math.max(w * 0.008, 1.2);
    c.stroke();

    let prof = profileOf(this.shape);
    let rx = prof[0][1] * w;
    c.fillStyle = p.deep;
    c.beginPath();
    c.ellipse(w / 2, top, rx, Math.max(rx * 0.22, 2), 0, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = p.ink;
    c.beginPath();
    c.ellipse(w / 2, top, rx * 0.74, Math.max(rx * 0.15, 1.4), 0, 0, Math.PI * 2);
    c.fill();

    if (this.shape === '鼎式') {
      c.strokeStyle = p.deep;
      c.lineWidth = Math.max(w * 0.022, 2);
      c.beginPath();
      c.arc(w / 2 - rx * 0.86, top - h * 0.01, rx * 0.24, Math.PI, Math.PI * 2);
      c.stroke();
      c.beginPath();
      c.arc(w / 2 + rx * 0.86, top - h * 0.01, rx * 0.24, Math.PI, Math.PI * 2);
      c.stroke();
    } else if (this.shape === '罐' || this.shape === '壶') {
      c.strokeStyle = p.deep;
      c.lineWidth = Math.max(w * 0.012, 1.4);
      c.beginPath();
      c.arc(w / 2 - rx * 1.02, top + (bot - top) * 0.22, rx * 0.26, -Math.PI * 0.5, Math.PI * 0.5);
      c.stroke();
      c.beginPath();
      c.arc(w / 2 + rx * 1.02, top + (bot - top) * 0.22, rx * 0.26, Math.PI * 0.5, Math.PI * 1.5);
      c.stroke();
    }

    let fr = prof[prof.length - 1][1] * w;
    c.strokeStyle = p.deep;
    c.lineWidth = Math.max(w * 0.006, 1);
    c.beginPath();
    c.ellipse(w / 2, bot, fr, Math.max(fr * 0.16, 1.6), 0, 0, Math.PI * 2);
    c.stroke();

    this.drawPedestal(c, p, w, h);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .backgroundColor(paletteOf(this.glaze).paper)
      .onReady((): void => {
        this.paint();
      })
  }
}
