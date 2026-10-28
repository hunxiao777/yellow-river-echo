import { paletteOf, Palette } from '../common/Theme';

// 彩陶组装预览：器型、纹样、配色、题字、展示座全部按画布尺寸归一化现画。
// shape：罐 / 盆 / 壶 / 瓶 / 鼎式；glaze 存 palette key；pedestal：素台 / 木座 / 圆几 / 无
const V_TOP: number = 0.12;
const V_BOT: number = 0.76;

function profileOf(shape: string): number[][] {
  if (shape === '盆') {
    return [[0, 0.46], [0.06, 0.45], [0.20, 0.42], [0.38, 0.36],
      [0.56, 0.29], [0.74, 0.20], [0.90, 0.12], [1, 0.09]];
  }
  if (shape === '壶') {
    return [[0, 0.15], [0.04, 0.18], [0.12, 0.13], [0.24, 0.12], [0.36, 0.20],
      [0.48, 0.33], [0.60, 0.38], [0.74, 0.34], [0.86, 0.25], [0.94, 0.17], [1, 0.19]];
  }
  if (shape === '瓶') {
    return [[0, 0.11], [0.04, 0.14], [0.16, 0.10], [0.34, 0.12], [0.46, 0.25],
      [0.58, 0.31], [0.84, 0.31], [0.95, 0.28], [1, 0.27]];
  }
  if (shape === '鼎式') {
    return [[0, 0.30], [0.05, 0.33], [0.14, 0.34], [0.32, 0.32],
      [0.50, 0.26], [0.68, 0.18], [0.86, 0.13], [1, 0.12]];
  }
  return [[0, 0.20], [0.05, 0.26], [0.16, 0.37], [0.32, 0.45], [0.48, 0.46],
    [0.64, 0.42], [0.82, 0.30], [0.94, 0.21], [1, 0.19]];
}

function halfWidthAt(shape: string, t: number, w: number): number {
  let prof = profileOf(shape);
  let lo = prof[0];
  let hi = prof[prof.length - 1];
  for (let i = 0; i < prof.length - 1; i++) {
    if (t >= prof[i][0] && t <= prof[i + 1][0]) {
      lo = prof[i];
      hi = prof[i + 1];
      break;
    }
  }
  let span = hi[0] - lo[0];
  let f = span <= 0 ? 0 : (t - lo[0]) / span;
  return (lo[1] + (hi[1] - lo[1]) * f) * w;
}

function bandOf(shape: string): number[] {
  if (shape === '鼎式') {
    return [0.16, 0.44];
  }
  if (shape === '瓶') {
    return [0.48, 0.76];
  }
  if (shape === '壶') {
    return [0.42, 0.70];
  }
  return [0.32, 0.60];
}

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

  private trace(c: CanvasRenderingContext2D, w: number, h: number): void {
    let prof = profileOf(this.shape);
    let cx = w / 2;
    let top = h * V_TOP;
    let bot = h * V_BOT;
    let right: number[][] = [];
    for (let i = 0; i < prof.length; i++) {
      right.push([cx + prof[i][1] * w, top + (bot - top) * prof[i][0]]);
    }
    c.beginPath();
    c.moveTo(right[0][0], right[0][1]);
    for (let i = 1; i < right.length - 1; i++) {
      c.quadraticCurveTo(right[i][0], right[i][1],
        (right[i][0] + right[i + 1][0]) / 2, (right[i][1] + right[i + 1][1]) / 2);
    }
    c.lineTo(right[right.length - 1][0], right[right.length - 1][1]);
    for (let i = right.length - 1; i > 0; i--) {
      let mx = (2 * cx - right[i][0] + 2 * cx - right[i - 1][0]) / 2;
      let my = (right[i][1] + right[i - 1][1]) / 2;
      c.quadraticCurveTo(2 * cx - right[i][0], right[i][1], mx, my);
    }
    c.lineTo(2 * cx - right[0][0], right[0][1]);
    c.closePath();
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

  private fish(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
    y0: number, y1: number): void {
    let cy = (y0 + y1) / 2;
    let n = 3;
    let cw = (x1 - x0) / n;
    let bh = y1 - y0;
    for (let i = 0; i < n; i++) {
      let bx = x0 + i * cw + cw * 0.10 + (this.seed % 3) * cw * 0.03;
      c.fillStyle = p.accent;
      c.beginPath();
      c.moveTo(bx, cy);
      c.lineTo(bx + cw * 0.40, cy - bh * 0.27);
      c.lineTo(bx + cw * 0.40, cy + bh * 0.27);
      c.closePath();
      c.fill();
      c.strokeStyle = p.accent;
      c.lineWidth = Math.max(bh * 0.05, 1);
      c.beginPath();
      c.moveTo(bx + cw * 0.40, cy);
      c.lineTo(bx + cw * 0.58, cy - bh * 0.26);
      c.moveTo(bx + cw * 0.40, cy);
      c.lineTo(bx + cw * 0.58, cy + bh * 0.26);
      c.stroke();
      c.fillStyle = p.paper;
      c.beginPath();
      c.arc(bx + cw * 0.12, cy, Math.max(bh * 0.045, 1), 0, Math.PI * 2);
      c.fill();
      for (let k = 0; k < 3; k++) {
        for (let j = -1; j <= 1; j++) {
          c.fillStyle = p.paper;
          c.beginPath();
          c.arc(bx + cw * (0.22 + k * 0.07), cy + j * bh * 0.12,
            Math.max(bh * 0.028, 0.8), 0, Math.PI * 2);
          c.fill();
        }
      }
    }
  }

  private bird(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
    y0: number, y1: number): void {
    let cy = (y0 + y1) / 2 + (y1 - y0) * 0.10;
    let n = 3;
    let cw = (x1 - x0) / n;
    let bh = y1 - y0;
    c.strokeStyle = p.accent;
    c.fillStyle = p.accent;
    c.lineWidth = Math.max(bh * 0.07, 1.2);
    for (let i = 0; i < n; i++) {
      let bx = x0 + i * cw + cw * 0.34;
      c.beginPath();
      c.ellipse(bx, cy, cw * 0.20, bh * 0.17, -0.35, 0, Math.PI * 2);
      c.fill();
      let hx = bx + cw * 0.26;
      let hy = cy - bh * 0.40;
      c.beginPath();
      c.moveTo(bx + cw * 0.12, cy - bh * 0.10);
      c.quadraticCurveTo(hx, cy - bh * 0.16, hx, hy);
      c.stroke();
      c.beginPath();
      c.arc(hx, hy, Math.max(cw * 0.055, 1.5), 0, Math.PI * 2);
      c.fill();
      c.beginPath();
      c.moveTo(hx + cw * 0.05, hy);
      c.lineTo(hx + cw * 0.16, hy + bh * 0.06);
      c.stroke();
      c.beginPath();
      for (let k = -1; k <= 1; k++) {
        c.moveTo(bx - cw * 0.16, cy);
        c.lineTo(bx - cw * 0.36, cy + k * bh * 0.20 - bh * 0.06);
      }
      c.stroke();
      c.beginPath();
      c.moveTo(bx - cw * 0.02, cy + bh * 0.15);
      c.lineTo(bx - cw * 0.04, cy + bh * 0.32);
      c.moveTo(bx + cw * 0.08, cy + bh * 0.14);
      c.lineTo(bx + cw * 0.10, cy + bh * 0.31);
      c.stroke();
    }
  }

  private swirl(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
    y0: number, y1: number): void {
    let cy = (y0 + y1) / 2;
    let n = 3;
    let cw = (x1 - x0) / n;
    let r = Math.min(cw * 0.34, (y1 - y0) * 0.44);
    c.strokeStyle = p.accent;
    c.lineWidth = Math.max((y1 - y0) * 0.055, 1.2);
    for (let i = 0; i < n; i++) {
      let sx = x0 + i * cw + cw * 0.5;
      c.beginPath();
      let first = true;
      for (let a = 0; a <= Math.PI * 4.2; a += 0.16) {
        let rr = r * (1 - a / (Math.PI * 4.6));
        let px = sx + rr * Math.cos(a + (this.seed % 4));
        let py = cy + rr * Math.sin(a + (this.seed % 4)) * 0.9;
        if (first) {
          c.moveTo(px, py);
          first = false;
        } else {
          c.lineTo(px, py);
        }
      }
      c.stroke();
      c.beginPath();
      c.moveTo(sx + r * 1.18, cy);
      c.lineTo(sx + cw * 0.48, cy);
      c.stroke();
    }
  }

  private grid(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
    y0: number, y1: number): void {
    c.strokeStyle = p.accent;
    c.lineWidth = Math.max((y1 - y0) * 0.035, 1);
    let step = (y1 - y0) * 0.46;
    let span = (x1 - x0) + (y1 - y0);
    for (let d = 0; d < span; d += step) {
      let x = x0 - (y1 - y0) + d;
      c.beginPath();
      c.moveTo(x, y0);
      c.lineTo(x + (y1 - y0), y1);
      c.stroke();
      c.beginPath();
      c.moveTo(x + (y1 - y0), y0);
      c.lineTo(x, y1);
      c.stroke();
    }
  }

  private sawtooth(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
    y0: number, y1: number): void {
    c.fillStyle = p.accent;
    c.strokeStyle = p.accent;
    c.lineWidth = Math.max((y1 - y0) * 0.04, 1);
    let n = 9;
    let cw = (x1 - x0) / n;
    let h1 = y1 - (y1 - y0) * 0.44;
    for (let i = 0; i < n; i++) {
      c.beginPath();
      c.moveTo(x0 + i * cw, h1);
      c.lineTo(x0 + i * cw + cw / 2, y1);
      c.lineTo(x0 + (i + 1) * cw, h1);
      c.closePath();
      c.fill();
    }
    c.beginPath();
    let z = n * 2;
    let zw = (x1 - x0) / z;
    for (let i = 0; i <= z; i++) {
      let yy = i % 2 === 0 ? y0 + (y1 - y0) * 0.10 : y0 + (y1 - y0) * 0.32;
      if (i === 0) {
        c.moveTo(x0, yy);
      } else {
        c.lineTo(x0 + i * zw, yy);
      }
    }
    c.stroke();
  }

  private petal(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
    y0: number, y1: number): void {
    let cy = (y0 + y1) / 2;
    let n = 3;
    let cw = (x1 - x0) / n;
    let r = Math.min(cw * 0.30, (y1 - y0) * 0.40);
    for (let i = 0; i < n; i++) {
      let sx = x0 + i * cw + cw * 0.5;
      for (let k = 0; k < 6; k++) {
        c.save();
        c.translate(sx, cy);
        c.rotate(k * Math.PI / 3 + (this.seed % 3) * 0.2);
        c.fillStyle = k % 2 === 0 ? p.accent : 'rgba(255,255,255,0.55)';
        c.beginPath();
        c.ellipse(0, -r * 0.62, r * 0.30, r * 0.55, 0, 0, Math.PI * 2);
        c.fill();
        c.strokeStyle = p.accent;
        c.lineWidth = Math.max(r * 0.06, 1);
        c.stroke();
        c.restore();
      }
      c.fillStyle = p.accent;
      c.beginPath();
      c.arc(sx, cy, r * 0.22, 0, Math.PI * 2);
      c.fill();
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
    if (this.motif === '鱼纹') {
      this.fish(c, p, 0, w, y0, y1);
    } else if (this.motif === '鸟纹') {
      this.bird(c, p, 0, w, y0, y1);
    } else if (this.motif === '漩涡纹') {
      this.swirl(c, p, 0, w, y0, y1);
    } else if (this.motif === '网格纹') {
      this.grid(c, p, 0, w, y0, y1);
    } else if (this.motif === '锯齿纹') {
      this.sawtooth(c, p, 0, w, y0, y1);
    } else {
      this.petal(c, p, 0, w, y0, y1);
    }
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

  private drawWord(c: CanvasRenderingContext2D, p: Palette, w: number, h: number): void {
    if (this.word.length === 0) {
      return;
    }
    let top = h * V_TOP;
    let bot = h * V_BOT;
    let bd = bandOf(this.shape);
    let wt = Math.min(bd[1] + 0.15, 0.88);
    let wy = top + (bot - top) * wt;
    let cs = this.word.split('');
    let hw = halfWidthAt(this.shape, wt, w);
    let size = w * 0.085;
    let fit = hw * 1.7 / (cs.length * 1.18);
    if (fit < size) {
      size = fit;
    }
    if (size < 6) {
      return;
    }
    c.fillStyle = p.accent;
    c.font = `${Math.round(size)}px sans-serif`;
    c.textAlign = 'center';
    c.textBaseline = 'middle';
    let total = cs.length * size * 1.18;
    for (let i = 0; i < cs.length; i++) {
      c.fillText(cs[i], w / 2 - total / 2 + size * 0.59 + i * size * 1.18, wy);
    }
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

    this.trace(c, w, h);
    let g: CanvasGradient = c.createLinearGradient(0, top, 0, bot);
    g.addColorStop(0, p.base);
    g.addColorStop(0.55, p.base);
    g.addColorStop(1, p.deep);
    c.fillStyle = g;
    c.fill();

    this.trace(c, w, h);
    c.save();
    c.clip();
    this.drawMotif(c, p, w, h);
    this.drawWord(c, p, w, h);
    c.fillStyle = 'rgba(43,38,34,0.14)';
    c.fillRect(w * 0.62, top, w * 0.40, bot - top);
    c.restore();

    this.trace(c, w, h);
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
