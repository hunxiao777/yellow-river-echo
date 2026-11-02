import { Palette } from './Theme';

/*
 * 彩陶器型的矢量画法：轮廓、纹样带、六种纹样、题字。
 *
 * 这份代码原来长在 view/PotteryCanvas.ets 里，现在抽出来给两处共用：
 *   1) view/PotteryCanvas.ets —— 纯二维现画（也是序列帧加载失败时的兜底）
 *   2) view/PotteryTurntable.ets —— 把同一套纹样按弧度罩到 3D 灰模序列帧上
 * 抽出来的目的不是省字，是「降级前后纹样必须一模一样」：两条链路各写一遍，
 * 改了一种纹样就会只在一边生效，而这种差异只有对着两台设备比才看得出来。
 *
 * 所以这里的函数一律把 shape / motif / seed 当参数收进来，不读组件状态。
 * 轮廓数据与 rawfile/pottery/geometry.js 镜像，改一处要改两处
 * （改完跑 node tools/bake_pottery_frames.mjs --check 会校验帧与映射表是否同步）。
 */

export const V_TOP: number = 0.12;
export const V_BOT: number = 0.76;

export function profileOf(shape: string): number[][] {
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

export function halfWidthAt(shape: string, t: number, w: number): number {
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

export function bandOf(shape: string): number[] {
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

// 器身轮廓闭合路径（只建路径，不填不描，由调用方决定怎么用）
export function tracePath(c: CanvasRenderingContext2D, shape: string,
  w: number, h: number): void {
  let prof = profileOf(shape);
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

export function fish(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
  y0: number, y1: number, seed: number): void {
  let cy = (y0 + y1) / 2;
  let n = 3;
  let cw = (x1 - x0) / n;
  let bh = y1 - y0;
  for (let i = 0; i < n; i++) {
    let bx = x0 + i * cw + cw * 0.10 + (seed % 3) * cw * 0.03;
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

export function bird(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
  y0: number, y1: number, seed: number): void {
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

export function swirl(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
  y0: number, y1: number, seed: number): void {
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
      let px = sx + rr * Math.cos(a + (seed % 4));
      let py = cy + rr * Math.sin(a + (seed % 4)) * 0.9;
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

export function grid(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
  y0: number, y1: number, seed: number): void {
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

export function sawtooth(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
  y0: number, y1: number, seed: number): void {
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

export function petal(c: CanvasRenderingContext2D, p: Palette, x0: number, x1: number,
  y0: number, y1: number, seed: number): void {
  let cy = (y0 + y1) / 2;
  let n = 3;
  let cw = (x1 - x0) / n;
  let r = Math.min(cw * 0.30, (y1 - y0) * 0.40);
  for (let i = 0; i < n; i++) {
    let sx = x0 + i * cw + cw * 0.5;
    for (let k = 0; k < 6; k++) {
      c.save();
      c.translate(sx, cy);
      c.rotate(k * Math.PI / 3 + (seed % 3) * 0.2);
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

export type MotifPainter = (c: CanvasRenderingContext2D, p: Palette, x0: number,
  x1: number, y0: number, y1: number, seed: number) => void;

// 六种纹样的统一入口：二维版整幅画一次，转台版按弧度切成 8 段各画一次
export function motifPainter(motif: string): MotifPainter {
  if (motif === '鸟纹') {
    return bird;
  }
  if (motif === '漩涡纹') {
    return swirl;
  }
  if (motif === '网格纹') {
    return grid;
  }
  if (motif === '锯齿纹') {
    return sawtooth;
  }
  if (motif === '花瓣纹') {
    return petal;
  }
  return fish;
}

export function drawWord(c: CanvasRenderingContext2D, p: Palette, word: string,
  shape: string, seed: number, w: number, h: number): void {
  if (word.length === 0) {
    return;
  }
  let top = h * V_TOP;
  let bot = h * V_BOT;
  let bd = bandOf(shape);
  let wt = Math.min(bd[1] + 0.15, 0.88);
  let wy = top + (bot - top) * wt;
  let cs = word.split('');
  let hw = halfWidthAt(shape, wt, w);
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
