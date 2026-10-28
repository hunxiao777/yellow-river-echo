import { router } from '@kit.ArkUI';
import { ContentRepo } from '../service/ContentRepo';
import { SiteRepo } from '../service/SiteRepo';
import { Course, CourseStep } from '../model/Models';
import { INK, SUB, LINE, CLAY, paletteOf, Palette } from '../common/Theme';
import { params, goPottery, goDetail } from '../common/Nav';

function kindOf(t: string, i: number): string {
  if (t.indexOf('窑') >= 0 || t.indexOf('烧') >= 0 || t.indexOf('浇注') >= 0) {
    return 'fire';
  }
  if (t.indexOf('绘') >= 0 || t.indexOf('纹') >= 0 || t.indexOf('彩') >= 0 || t.indexOf('墨') >= 0
    || t.indexOf('釉') >= 0 || t.indexOf('稿') >= 0 || t.indexOf('画') >= 0 || t.indexOf('刻') >= 0
    || t.indexOf('拓') >= 0 || t.indexOf('点睛') >= 0) {
    return 'paint';
  }
  if (t.indexOf('修') >= 0 || t.indexOf('削') >= 0 || t.indexOf('刮') >= 0 || t.indexOf('磨') >= 0
    || t.indexOf('压光') >= 0 || t.indexOf('范') >= 0 || t.indexOf('凹') >= 0) {
    return 'trim';
  }
  if (t.indexOf('轮') >= 0 || t.indexOf('拉') >= 0 || t.indexOf('叠') >= 0 || t.indexOf('接') >= 0
    || t.indexOf('出跳') >= 0 || t.indexOf('斗') >= 0 || t.indexOf('用材') >= 0) {
    return 'throw';
  }
  if (t.indexOf('泥') >= 0 || t.indexOf('揉') >= 0 || t.indexOf('练') >= 0 || t.indexOf('纸') >= 0
    || t.indexOf('清理') >= 0 || t.indexOf('塑') >= 0) {
    return 'knead';
  }
  let mods: string[] = ['knead', 'throw', 'trim', 'paint', 'fire'];
  return mods[i % mods.length];
}

@Entry
@Component
struct PlayerPage {
  @State course: Course | undefined = undefined;
  @State @Watch('repaint') idx: number = 0;
  @State playing: boolean = false;
  private timer: number = -1;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    let p = params();
    let id = p.courseId ?? '';
    this.course = ContentRepo.get().courseOf(id);
  }

  aboutToDisappear(): void {
    this.stopPlay();
  }

  steps(): CourseStep[] {
    return this.course?.steps ?? [];
  }

  total(): number {
    return this.steps().length;
  }

  stepIdx(): number {
    let st = this.steps();
    if (st.length === 0) {
      return 0;
    }
    return this.idx < st.length ? this.idx : st.length - 1;
  }

  stepTitle(): string {
    let st = this.steps();
    return st.length === 0 ? '' : st[this.stepIdx()].t;
  }

  stepBody(): string {
    let st = this.steps();
    return st.length === 0 ? '' : st[this.stepIdx()].d;
  }

  coverText(): string {
    let co = this.course;
    return co === undefined ? '课程影像' : co.title;
  }

  srcText(): string {
    let co = this.course;
    return co === undefined ? '' : co.source;
  }

  paletteKey(): string {
    let co = this.course;
    return co === undefined ? 'yangshao' : co.palette;
  }

  repaint(): void {
    this.paint();
  }

  advance(): void {
    if (this.idx >= this.total() - 1) {
      this.stopPlay();
    } else {
      this.idx = this.idx + 1;
    }
  }

  togglePlay(): void {
    if (this.playing) {
      this.stopPlay();
      return;
    }
    if (this.total() === 0) {
      return;
    }
    if (this.idx >= this.total() - 1) {
      this.idx = 0;
    }
    this.playing = true;
    this.timer = setInterval((): void => {
      this.advance();
    }, 5000);
  }

  stopPlay(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.playing = false;
  }

  jump(i: number): void {
    this.idx = i;
  }

  private vessel(c: CanvasRenderingContext2D, p: Palette, cx: number, cy: number,
    rw: number, rh: number): void {
    c.fillStyle = p.base;
    c.strokeStyle = p.deep;
    c.lineWidth = Math.max(rw * 0.06, 1.2);
    c.beginPath();
    c.moveTo(cx - rw * 0.42, cy - rh);
    c.lineTo(cx + rw * 0.42, cy - rh);
    c.bezierCurveTo(cx + rw, cy - rh * 0.5, cx + rw, cy + rh * 0.5, cx + rw * 0.5, cy + rh);
    c.lineTo(cx - rw * 0.5, cy + rh);
    c.bezierCurveTo(cx - rw, cy + rh * 0.5, cx - rw, cy - rh * 0.5, cx - rw * 0.42, cy - rh);
    c.closePath();
    c.fill();
    c.stroke();
  }

  private spiral(c: CanvasRenderingContext2D, p: Palette, sx: number, sy: number, r: number): void {
    c.beginPath();
    let first = true;
    for (let a = 0; a <= Math.PI * 4; a += 0.2) {
      let rr = r * (1 - a / (Math.PI * 4.4));
      let px = sx + rr * Math.cos(a);
      let py = sy + rr * Math.sin(a);
      if (first) {
        c.moveTo(px, py);
        first = false;
      } else {
        c.lineTo(px, py);
      }
    }
    c.stroke();
  }

  private scene(c: CanvasRenderingContext2D, p: Palette, w: number, h: number, kind: string): void {
    let ground = h * 0.76;
    c.strokeStyle = 'rgba(43,38,34,0.30)';
    c.lineWidth = Math.max(h * 0.006, 1);
    c.beginPath();
    c.moveTo(w * 0.06, ground);
    c.lineTo(w * 0.94, ground);
    c.stroke();

    if (kind === 'knead') {
      c.fillStyle = p.deep;
      c.beginPath();
      c.ellipse(w * 0.5, ground - h * 0.10, w * 0.22, h * 0.14, 0, 0, Math.PI * 2);
      c.fill();
      c.beginPath();
      c.ellipse(w * 0.24, ground - h * 0.03, w * 0.07, h * 0.05, 0, 0, Math.PI * 2);
      c.fill();
      c.beginPath();
      c.ellipse(w * 0.76, ground - h * 0.035, w * 0.06, h * 0.045, 0, 0, Math.PI * 2);
      c.fill();
      c.strokeStyle = p.ink;
      c.lineWidth = Math.max(h * 0.012, 1.2);
      for (let i = -1; i <= 1; i++) {
        c.beginPath();
        c.arc(w * 0.5 + i * w * 0.09, ground - h * 0.13, w * 0.06, Math.PI * 0.15, Math.PI * 0.85);
        c.stroke();
      }
      c.strokeStyle = 'rgba(43,38,34,0.55)';
      c.beginPath();
      c.moveTo(w * 0.30, h * 0.22);
      c.quadraticCurveTo(w * 0.5, h * 0.10, w * 0.70, h * 0.22);
      c.stroke();
    } else if (kind === 'throw') {
      c.fillStyle = 'rgba(43,38,34,0.30)';
      c.beginPath();
      c.ellipse(w * 0.5, ground, w * 0.30, h * 0.06, 0, 0, Math.PI * 2);
      c.fill();
      this.vessel(c, p, w * 0.5, ground - h * 0.20, w * 0.18, h * 0.20);
      c.strokeStyle = p.accent;
      c.lineWidth = Math.max(h * 0.010, 1.2);
      c.setLineDash([h * 0.03, h * 0.03]);
      for (let i = 0; i < 2; i++) {
        c.beginPath();
        c.ellipse(w * 0.5, ground - h * 0.22, w * (0.26 + i * 0.07), h * (0.07 + i * 0.02),
          0, Math.PI * 1.05, Math.PI * 1.95);
        c.stroke();
      }
      c.setLineDash([]);
      c.strokeStyle = 'rgba(43,38,34,0.50)';
      c.lineWidth = Math.max(h * 0.014, 1.4);
      c.beginPath();
      c.arc(w * 0.30, ground - h * 0.24, w * 0.09, Math.PI * 1.3, Math.PI * 1.9);
      c.stroke();
      c.beginPath();
      c.arc(w * 0.70, ground - h * 0.24, w * 0.09, Math.PI * 1.1, Math.PI * 1.7);
      c.stroke();
    } else if (kind === 'trim') {
      c.fillStyle = 'rgba(43,38,34,0.22)';
      c.beginPath();
      c.ellipse(w * 0.5, ground, w * 0.26, h * 0.05, 0, 0, Math.PI * 2);
      c.fill();
      this.vessel(c, p, w * 0.46, ground - h * 0.22, w * 0.19, h * 0.22);
      c.strokeStyle = p.deep;
      c.lineWidth = Math.max(h * 0.008, 1);
      for (let i = 0; i < 4; i++) {
        c.beginPath();
        c.moveTo(w * 0.36, ground - h * (0.34 - i * 0.06));
        c.lineTo(w * 0.54, ground - h * (0.36 - i * 0.06));
        c.stroke();
      }
      c.strokeStyle = '#5A4030';
      c.lineWidth = Math.max(h * 0.016, 1.6);
      c.beginPath();
      c.moveTo(w * 0.84, h * 0.20);
      c.lineTo(w * 0.58, ground - h * 0.26);
      c.stroke();
      c.fillStyle = p.deep;
      for (let i = 0; i < 5; i++) {
        c.beginPath();
        c.ellipse(w * (0.62 + i * 0.05), ground - h * (0.06 - i * 0.01),
          w * 0.020, h * 0.012, 0.5 + i * 0.3, 0, Math.PI * 2);
        c.fill();
      }
    } else if (kind === 'paint') {
      this.vessel(c, p, w * 0.5, ground - h * 0.22, w * 0.22, h * 0.24);
      let by = ground - h * 0.30;
      c.strokeStyle = p.accent;
      c.lineWidth = Math.max(h * 0.012, 1.2);
      c.beginPath();
      c.moveTo(w * 0.30, by - h * 0.06);
      c.lineTo(w * 0.70, by - h * 0.06);
      c.moveTo(w * 0.30, by + h * 0.06);
      c.lineTo(w * 0.70, by + h * 0.06);
      c.stroke();
      this.spiral(c, p, w * 0.40, by, h * 0.05);
      this.spiral(c, p, w * 0.58, by, h * 0.05);
      c.strokeStyle = '#5A4030';
      c.lineWidth = Math.max(h * 0.014, 1.4);
      c.beginPath();
      c.moveTo(w * 0.86, h * 0.14);
      c.lineTo(w * 0.64, by - h * 0.04);
      c.stroke();
      c.fillStyle = p.accent;
      c.beginPath();
      c.moveTo(w * 0.64, by - h * 0.04);
      c.lineTo(w * 0.60, by + h * 0.01);
      c.lineTo(w * 0.66, by + h * 0.02);
      c.closePath();
      c.fill();
    } else {
      c.fillStyle = p.deep;
      c.beginPath();
      c.moveTo(w * 0.22, ground);
      c.lineTo(w * 0.22, h * 0.30);
      c.quadraticCurveTo(w * 0.5, h * 0.10, w * 0.78, h * 0.30);
      c.lineTo(w * 0.78, ground);
      c.closePath();
      c.fill();
      let mg: CanvasGradient = c.createLinearGradient(0, ground, 0, h * 0.42);
      mg.addColorStop(0, '#F2A44C');
      mg.addColorStop(1, '#A6553D');
      c.fillStyle = mg;
      c.beginPath();
      c.moveTo(w * 0.36, ground);
      c.lineTo(w * 0.36, h * 0.56);
      c.quadraticCurveTo(w * 0.5, h * 0.44, w * 0.64, h * 0.56);
      c.lineTo(w * 0.64, ground);
      c.closePath();
      c.fill();
      c.fillStyle = '#F6E1B0';
      for (let i = -1; i <= 1; i++) {
        c.beginPath();
        c.moveTo(w * 0.5 + i * w * 0.09 - w * 0.03, ground);
        c.lineTo(w * 0.5 + i * w * 0.09, ground - h * (0.16 - Math.abs(i) * 0.04));
        c.lineTo(w * 0.5 + i * w * 0.09 + w * 0.03, ground);
        c.closePath();
        c.fill();
      }
      c.strokeStyle = 'rgba(43,38,34,0.35)';
      c.lineWidth = Math.max(h * 0.008, 1);
      for (let i = 0; i < 3; i++) {
        c.beginPath();
        let yy = h * (0.22 - i * 0.05);
        c.moveTo(w * 0.40, yy);
        c.quadraticCurveTo(w * 0.46, yy - h * 0.03, w * 0.52, yy);
        c.quadraticCurveTo(w * 0.58, yy + h * 0.03, w * 0.64, yy);
        c.stroke();
      }
    }

    c.fillStyle = 'rgba(43,38,34,0.62)';
    c.font = `${Math.round(h * 0.06)}px sans-serif`;
    c.textAlign = 'left';
    c.textBaseline = 'top';
    c.fillText(`分镜 ${this.idx + 1} / ${this.total()}`, w * 0.05, h * 0.05);
    c.font = `${Math.round(h * 0.05)}px sans-serif`;
    c.fillText(this.kindLabel(kind), w * 0.05, h * 0.15);
  }

  private kindLabel(kind: string): string {
    if (kind === 'knead') {
      return '泥料';
    }
    if (kind === 'throw') {
      return '成型';
    }
    if (kind === 'trim') {
      return '修整';
    }
    if (kind === 'paint') {
      return '纹样';
    }
    return '火候';
  }

  private paint(): void {
    let c = this.ctx;
    let w = c.width;
    let h = c.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    let co = this.course;
    if (co === undefined) {
      return;
    }
    let st = this.steps();
    if (st.length === 0) {
      return;
    }
    let p = paletteOf(co.palette);
    c.clearRect(0, 0, w, h);
    let g: CanvasGradient = c.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, p.paper);
    g.addColorStop(1, p.base);
    c.fillStyle = g;
    c.fillRect(0, 0, w, h);
    let i = this.stepIdx();
    this.scene(c, p, w, h, kindOf(st[i].t, i));
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text('‹').fontSize(24).fontColor(CLAY).width(22)
          .onClick((): void => {
            this.stopPlay();
            router.back();
          })
        Column({ space: 2 }) {
          Text(this.coverText())
            .fontSize(17).fontColor(INK).fontWeight(FontWeight.Bold)
          Text('手绘分镜演示，非实拍视频').fontSize(11).fontColor(SUB)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10 })

      if (this.course === undefined) {
        Column({ space: 12 }) {
          Text('课程不存在').fontSize(16).fontColor(INK)
          Button('返回')
            .backgroundColor($r('app.color.line')).fontColor(INK)
            .onClick((): void => {
              router.back();
            })
        }
        .width('100%')
        .margin({ top: 80 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 0 }) {
              Canvas(this.ctx)
                .width('100%')
                .height(260)
                .backgroundColor(paletteOf(this.paletteKey()).paper)
                .onReady((): void => {
                  this.paint();
                })
            }
            .width('100%')
            .borderRadius(14)
            .clip(true)
            .backgroundColor($r('app.color.card_bg'))

            Column({ space: 8 }) {
              Row({ space: 10 }) {
                Text(this.playing ? '▮▮' : '▶')
                  .fontSize(15).fontColor(Color.White)
                  .width(40).height(34).borderRadius(8)
                  .backgroundColor(CLAY)
                  .textAlign(TextAlign.Center)
                  .onClick((): void => {
                    this.togglePlay();
                  })
                Text('‹ 上一镜')
                  .fontSize(12).fontColor(INK)
                  .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                  .borderRadius(8)
                  .backgroundColor($r('app.color.line'))
                  .onClick((): void => {
                    if (this.idx > 0) {
                      this.idx = this.idx - 1;
                    }
                  })
                Text('下一镜 ›')
                  .fontSize(12).fontColor(INK)
                  .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                  .borderRadius(8)
                  .backgroundColor($r('app.color.line'))
                  .onClick((): void => {
                    if (this.idx < this.total() - 1) {
                      this.idx = this.idx + 1;
                    }
                  })
                Blank()
                Text(this.playing ? '每 5 秒一镜' : '已暂停')
                  .fontSize(10).fontColor(SUB)
              }
              .width('100%')

              Row({ space: 4 }) {
                ForEach(this.steps(), (s: CourseStep, i: number): void => {
                  Column()
                    .layoutWeight(1)
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor(i === this.idx ? CLAY : LINE)
                    .onClick((): void => {
                      this.jump(i);
                    })
                }, (s: CourseStep, i: number): string => 'seg_' + i)
              }
              .width('100%')

              Column({ space: 6 }) {
                Text(this.stepTitle())
                  .fontSize(19).fontColor(INK).fontWeight(FontWeight.Bold).width('100%')
                Text(this.stepBody())
                  .fontSize(14).fontColor(INK).lineHeight(23).width('100%')
                Text('这一段是手绘分镜示意图，不是实拍视频')
                  .fontSize(10).fontColor(SUB).width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
            }
            .width('100%')

            Column({ space: 2 }) {
              Text('全部分镜').fontSize(13).fontColor(INK).fontWeight(FontWeight.Medium)
                .width('100%').padding({ bottom: 6 })
              ForEach(this.steps(), (s: CourseStep, i: number): void => {
                Row({ space: 8 }) {
                  Text(`${i + 1}`)
                    .fontSize(11).fontColor(i === this.idx ? Color.White : SUB)
                    .width(20).height(20).borderRadius(10)
                    .backgroundColor(i === this.idx ? CLAY : $r('app.color.page_bg'))
                    .textAlign(TextAlign.Center)
                  Column({ space: 2 }) {
                    Text(s.t).fontSize(13).fontColor(INK).width('100%')
                    Text(s.d).fontSize(10).fontColor(SUB).width('100%').maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 7, bottom: 7 })
                .onClick((): void => {
                  this.jump(i);
                })
              }, (s: CourseStep, i: number): string => 'row_' + i + '_' + s.t.length)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 12, right: 12, bottom: 6 })
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(12)

            Row({ space: 10 }) {
              Button('跟着做一遍')
                .fontSize(13).backgroundColor(CLAY).fontColor(Color.White)
                .onClick((): void => {
                  this.stopPlay();
                  goPottery();
                })
              if (this.siteName().length > 0) {
                Button('去遗址看看')
                  .fontSize(13).backgroundColor($r('app.color.line')).fontColor(INK)
                  .onClick((): void => {
                    let co = this.course;
                    if (co !== undefined) {
                      this.stopPlay();
                      goDetail(co.siteId);
                    }
                  })
              }
              Blank()
            }
            .width('100%')

            Text(`课程线索来源：${this.srcText()}`)
              .fontSize(10).fontColor(SUB).width('100%')
          }
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 14 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .alignItems(HorizontalAlign.Start)
  }

  private siteName(): string {
    let co = this.course;
    if (co === undefined) {
      return '';
    }
    let s = SiteRepo.get().byId(co.siteId);
    return s === undefined ? '' : s.name;
  }
}
