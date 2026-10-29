import { router } from '@kit.ArkUI';
import { ContentRepo } from '../service/ContentRepo';
import { Course } from '../model/Models';
import { INK, SUB, LOESS, CLAY, LINE, paletteOf, fs, coverRes } from '../common/Theme';
import { params, goPottery, goColor, goPlayer } from '../common/Nav';
import { PatternBg } from '../view/PatternBg';

// 展台上的六件"实物参考"：图用的是包内实景风格文物照，
// 一件对应一个时代、一种釉色，也对应工坊里的一套参数。
interface Relic {
  key: string;
  img: string;
  name: string;
  era: string;
  note: string;
  potHint: string;
  saying: string;
}

const RELICS: Relic[] = [
  {
    key: 'yangshao', img: 'era_yangshao', name: '彩陶鱼纹双耳盆', era: '仰韶',
    note: '鱼纹一笔撇在腹部，漩涡纹压在下带，是陶艺工坊纹样的原型。',
    potHint: '鱼纹、漩涡纹都取自这件；红陶底衬黑彩最稳。',
    saying: '彩陶的底色，是黄河泥在窑火里烧出来的红。'
  },
  {
    key: 'longshan', img: 'era_longshan', name: '黑陶高足杯', era: '龙山',
    note: '快轮拉坯、渗碳烧成，胎薄如壳，黑得发亮。',
    potHint: '素台加一圈拉坯线就够说话；器型可试高足。',
    saying: '黑陶靠渗碳烧成，黑得发亮，薄得透光。'
  },
  {
    key: 'xiashang', img: 'era_xiashang', name: '青铜尊与青铜盘', era: '夏商',
    note: '范铸在器身留下范线，兽面与同心圆藏在青绿锈里。',
    potHint: '兽面纹可以搬到陶腹上；配色取夏商青绿。',
    saying: '青铜刚铸出来是亮的青绿，锈了才沉成现在这样。'
  },
  {
    key: 'zhou', img: 'era_zhou', name: '青铜鼎与编钟组', era: '周',
    note: '礼乐器的组合：鼎数列等级，钟磬定声音。',
    potHint: '题字可以借金文笔意；器型试鼎式。',
    saying: '玉色是礼器的底子，温而不艳，压得住场面。'
  },
  {
    key: 'hantang', img: 'era_hantang', name: '三彩驼骑俑', era: '汉唐',
    note: '铅釉在窑里自己流动，赭黄与绿交叠，件件不同。',
    potHint: '配色用汉唐赭黄，让釉流一点更像三彩。',
    saying: '赭黄是三彩釉里的主色，铅釉在火里流得开。'
  },
  {
    key: 'song', img: 'era_song', name: '青花与青釉瓶', era: '宋',
    note: '"雨过天晴云破处"，宋人把这一层青烧进了釉里。',
    potHint: '素台天青，题字留白，纹样别抢戏。',
    saying: '天青是"雨过天晴云破处"的那一层青。'
  }
];

const WORKS: string[] = ['陶艺工坊', '颜色工坊', '教程工坊'];
const CATS: string[] = ['全部', '手作', '讲读', '影像'];

// 创意工坊：单独模块的默认页。顶栏切工坊、挑教程；
// 中间是 3D 展台——实景文物照排成一圈，侧件侧身、主件慢摆，脚下压一片影子。
@Entry
@Component
struct StudioPage {
  @State tab: number = 0;
  @State cur: number = 0;
  @State sway: number = -6;
  @State cat: string = '全部';

  aboutToAppear(): void {
    let p = params();
    if (p !== undefined && p.tab !== undefined && p.tab >= 0 && p.tab <= 2) {
      this.tab = p.tab;
    }
    animateTo({
      duration: 2800,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, (): void => {
      this.sway = 6;
    });
  }

  relic(): Relic {
    return RELICS[this.cur];
  }

  // 环形相对位置：-3..3，0 是正中间那件
  rel(i: number): number {
    let d = i - this.cur;
    if (d > 3) {
      d -= RELICS.length;
    }
    if (d < -3) {
      d += RELICS.length;
    }
    return d;
  }

  step(d: number): void {
    animateTo({ duration: 380, curve: Curve.EaseInOut }, (): void => {
      this.cur = (this.cur + d + RELICS.length) % RELICS.length;
    });
  }

  pick(i: number): void {
    if (i === this.cur) {
      return;
    }
    animateTo({ duration: 380, curve: Curve.EaseInOut }, (): void => {
      this.cur = i;
    });
  }

  // 每个工坊挂自己的教程：陶艺认"陶/泥/坯"，颜色认"釉/墨"，教程工坊走分类
  tutorials(): Course[] {
    let all = ContentRepo.get().courses;
    if (this.tab === 2) {
      return ContentRepo.get().coursesOf(this.cat);
    }
    let out: Course[] = [];
    for (let c of all) {
      if (this.tab === 0 && (c.title.indexOf('陶') >= 0 || c.title.indexOf('泥') >= 0 || c.title.indexOf('坯') >= 0)) {
        out.push(c);
      } else if (this.tab === 1 && (c.title.indexOf('釉') >= 0 || c.title.indexOf('墨') >= 0)) {
        out.push(c);
      }
    }
    return out;
  }

  @Builder
  topBar() {
    Row({ space: 10 }) {
      Text('‹')
        .fontSize(fs(24))
        .fontColor(CLAY)
        .width(22)
        .onClick((): void => {
          router.back();
        })
      Column({ space: 2 }) {
        Text('创意工坊')
          .fontSize(fs(18))
          .fontColor(INK)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
        Text('陶艺 · 颜色 · 教程')
          .fontSize(fs(10))
          .fontColor(SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 2 }) {
        ForEach(WORKS, (w: string, i: number): void => {
          Text(w)
            .fontSize(fs(12))
            .fontColor(this.tab === i ? Color.White : SUB)
            .fontWeight(this.tab === i ? FontWeight.Medium : FontWeight.Regular)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(this.tab === i ? CLAY : Color.Transparent)
            .onClick((): void => {
              this.tab = i;
            })
        }, (w: string, i: number): string => 'wk_' + i)
      }
      .padding(2)
      .borderRadius(16)
      .backgroundColor('rgba(233,219,196,0.65)')
    }
    .width('100%')
    .padding({ left: 14, right: 12, top: 10, bottom: 8 })
  }

  // 顶栏下面一行挑教程：陶艺/颜色挂相关课，教程工坊走分类筛选
  @Builder
  courseChips() {
    Row({ space: 8 }) {
      Text(this.tab === 2 ? '筛选' : '选教程')
        .fontSize(fs(11))
        .fontColor(LOESS)
        .fontWeight(FontWeight.Medium)
      Scroll() {
        Row({ space: 7 }) {
          if (this.tab === 2) {
            ForEach(CATS, (o: string): void => {
              Text(o)
                .fontSize(fs(11))
                .fontColor(o === this.cat ? Color.White : INK)
                .padding({ left: 11, right: 11, top: 5, bottom: 5 })
                .borderRadius(13)
                .backgroundColor(o === this.cat ? CLAY : 'rgba(255,255,255,0.6)')
                .border({ width: 1, color: o === this.cat ? CLAY : LINE })
                .onClick((): void => {
                  this.cat = o;
                })
            }, (o: string): string => 'cat_' + o)
          } else {
            ForEach(this.tutorials(), (c: Course): void => {
              Text(c.title)
                .fontSize(fs(11))
                .fontColor(INK)
                .padding({ left: 11, right: 11, top: 5, bottom: 5 })
                .borderRadius(13)
                .backgroundColor('rgba(255,255,255,0.6)')
                .border({ width: 1, color: LINE })
                .onClick((): void => {
                  goPlayer(c.id);
                })
            }, (c: Course): string => 'tut_' + c.id)
          }
        }
        .padding({ right: 12 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 0, bottom: 6 })
  }

  // 3D 展台：六件围成一圈，侧件侧身退后，主件慢摆，脚下压一片虚影
  @Builder
  stage() {
    Stack({ alignContent: Alignment.Center }) {
      // 地面虚影：位置不随摆动变，撑住"立在台面上"的感觉
      Column()
        .width(150)
        .height(14)
        .borderRadius(7)
        .backgroundColor('rgba(43,38,34,0.22)')
        .blur(9)
        .offset({ y: 108 })

      ForEach(RELICS, (r: Relic, i: number): void => {
        Stack() {
          Image(coverRes(r.img))
            .width(186)
            .height(186)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
          // 侧件压暗一点，拉开前后层次
          Column()
            .width(186)
            .height(186)
            .borderRadius(14)
            .linearGradient({
              angle: 90,
              colors: [['rgba(43,38,34,0.34)', 0], ['rgba(43,38,34,0.05)', 0.5], ['rgba(43,38,34,0.34)', 1]]
            })
            .opacity(this.rel(i) === 0 ? 0 : 0.8)
        }
        .rotate({ x: 0, y: 1, z: 0, angle: this.rel(i) === 0 ? this.sway : (this.rel(i) < 0 ? 42 : -42) })
        .scale({ x: this.rel(i) === 0 ? 1 : (Math.abs(this.rel(i)) === 1 ? 0.7 : 0.54),
          y: this.rel(i) === 0 ? 1 : (Math.abs(this.rel(i)) === 1 ? 0.7 : 0.54) })
        .opacity(this.rel(i) === 0 ? 1 : (Math.abs(this.rel(i)) === 1 ? 0.6 : 0.28))
        .translate({ x: this.rel(i) * 108, y: this.rel(i) === 0 ? -6 : (Math.abs(this.rel(i)) === 1 ? 8 : 16) })
        .zIndex(this.rel(i) === 0 ? 20 : (Math.abs(this.rel(i)) === 1 ? 10 : 4))
        .onClick((): void => {
          this.pick(i);
        })
      }, (r: Relic, i: number): string => 'st_' + r.key + '_' + i)

      Text('‹')
        .fontSize(fs(30))
        .fontColor('rgba(122,110,98,0.7)')
        .position({ x: 4, y: 128 })
        .zIndex(30)
        .onClick((): void => {
          this.step(-1);
        })
      Text('›')
        .fontSize(fs(30))
        .fontColor('rgba(122,110,98,0.7)')
        .position({ x: 330, y: 128 })
        .zIndex(30)
        .onClick((): void => {
          this.step(1);
        })
    }
    .width('100%')
    .height(288)
  }

  // 色点行：照参考图那排圆点，选中的套一圈环
  @Builder
  dots() {
    Row({ space: 26 }) {
      ForEach(RELICS, (r: Relic, i: number): void => {
        Stack() {
          if (this.cur === i) {
            Column()
              .width(27)
              .height(27)
              .borderRadius(14)
              .border({ width: 1.5, color: paletteOf(r.key).deep })
          }
          Column()
            .width(16)
            .height(16)
            .borderRadius(8)
            .backgroundColor(paletteOf(r.key).base)
        }
        .width(27)
        .height(27)
        .onClick((): void => {
          this.pick(i);
        })
      }, (r: Relic, i: number): string => 'dot_' + r.key + '_' + i)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 10, bottom: 4 })
  }

  @Builder
  courseRow(c: Course) {
    Row({ space: 10 }) {
      Image(coverRes(c.palette === 'yangshao' ? 'era_yangshao' :
        (c.palette === 'longshan' ? 'era_longshan' :
          (c.palette === 'xiashang' ? 'era_xiashang' :
            (c.palette === 'song' ? 'era_song' : 'era_hantang')))))
        .width(58)
        .height(72)
        .objectFit(ImageFit.Cover)
        .borderRadius(9)
        .rotate({ x: 0, y: 1, z: 0, angle: -8 })
      Column({ space: 4 }) {
        Text(c.title)
          .fontSize(fs(14))
          .fontColor(INK)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(c.brief)
          .fontSize(fs(11))
          .fontColor(SUB)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${c.cat} · ${c.level} · ${c.minutes} 分钟`)
          .fontSize(fs(10))
          .fontColor(CLAY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(fs(14))
        .fontColor(SUB)
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      goPlayer(c.id);
    })
  }

  @Builder
  actionCard() {
    if (this.tab === 2) {
      Column({ space: 8 }) {
        ForEach(this.tutorials(), (c: Course): void => {
          this.courseRow(c)
        }, (c: Course): string => 'row_' + c.id)
        if (this.tutorials().length === 0) {
          Text('这一类暂时没有课程')
            .fontSize(fs(12))
            .fontColor(SUB)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 16, bottom: 16 })
        }
      }
      .width('100%')
    } else {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text(this.tab === 0 ? '借这件的器形与纹样' : '借这件的釉色')
            .fontSize(fs(12))
            .fontColor(INK)
            .fontWeight(FontWeight.Medium)
          Text(this.tab === 0 ? this.relic().potHint : this.relic().saying)
            .fontSize(fs(10))
            .fontColor(SUB)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.tab === 0 ? '进陶艺工坊' : '进颜色工坊')
          .fontSize(fs(12))
          .fontColor(Color.White)
          .padding({ left: 13, right: 13, top: 8, bottom: 8 })
          .borderRadius(16)
          .backgroundColor(CLAY)
          .onClick((): void => {
            if (this.tab === 0) {
              goPottery();
            } else {
              goColor(this.relic().key);
            }
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)
    }
  }

  build() {
    Stack() {
      PatternBg()
      Column() {
        this.topBar()
        this.courseChips()
        Scroll() {
          Column({ space: 6 }) {
            this.stage()
            Row({ space: 8 }) {
              Text(this.relic().name)
                .fontSize(fs(17))
                .fontColor(INK)
                .fontWeight(FontWeight.Bold)
              Text(this.relic().era)
                .fontSize(fs(10))
                .fontColor(paletteOf(this.relic().key).ink)
                .backgroundColor(paletteOf(this.relic().key).deep)
                .borderRadius(7)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)

            Text(this.relic().note)
              .fontSize(fs(11))
              .fontColor(SUB)
              .width('100%')
              .textAlign(TextAlign.Center)
              .lineHeight(fs(18))
              .padding({ left: 26, right: 26 })

            this.dots()
            this.actionCard()

            Text('展台文物照为 AI 生成示意图，非馆藏实拍；教程为手绘分镜演示。')
              .fontSize(fs(10))
              .fontColor(SUB)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 10, bottom: 16 })
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
