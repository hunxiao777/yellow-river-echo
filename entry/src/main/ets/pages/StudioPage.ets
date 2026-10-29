import { router } from '@kit.ArkUI';
import { INK, SUB, PAPER, CLAY, LINE, fs, coverRes, paletteOf } from '../common/Theme';
import { goBack, params, goPlayer, goCourses } from '../common/Nav';
import { PatternBg } from '../view/PatternBg';
import { ContentRepo } from '../service/ContentRepo';
import { Course } from '../model/Models';
import { colorRowOf } from './ColorPage';

// 「创意工坊」独立模块：默认页顶栏切工坊、选教程
// 页内三块：3D 文物展台（旋转 + 倒影 + 指示点）、陶艺/颜色工坊入口、教程选单
interface ExhibitRec {
  img: string;
  key: string;
}

// 六件展品：实物示意图 + 对应色键，与颜色工坊六色一一对上
const SHOW: ExhibitRec[] = [
  { img: 'relic_caitao', key: 'yangshao' },
  { img: 'relic_heitao', key: 'longshan' },
  { img: 'relic_qingtong', key: 'xiashang' },
  { img: 'relic_bianzhong', key: 'zhou' },
  { img: 'relic_sancai', key: 'hantang' },
  { img: 'relic_tianqing', key: 'song' }
];
const CATS: string[] = ['全部', '手作', '讲读', '影像'];
const CAT_NAMES: string[] = ['全部', '手作演示', '讲读', '影像'];

@Entry
@Component
export struct StudioPage {
  @State tab: number = 0;
  @State cur: number = 0;
  @State sway: number = -5;
  @State floatY: number = 0;
  @State cat: string = '全部';

  aboutToAppear(): void {
    let p = params();
    if (p !== undefined && p.tab !== undefined && p.tab >= 0 && p.tab <= 2) {
      this.tab = p.tab;
    }
    // 展台缓摆：绕 y 轴 -5°~5° 往复；上下 8px 浮沉，像展柜里被轻托着
    animateTo({
      duration: 6000, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate
    }, (): void => {
      this.sway = 5;
    });
    animateTo({
      duration: 4200, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate
    }, (): void => {
      this.floatY = -8;
    });
  }

  // 展品相对当前选中的偏移：-3..3，只渲染 |rel|<=1（两侧侧身件 + 中央正身件）
  private rel(i: number): number {
    let d = i - this.cur;
    while (d > 3) {
      d -= 6;
    }
    while (d < -3) {
      d += 6;
    }
    return d;
  }

  private pick(i: number): void {
    if (this.rel(i) === 1) {
      this.cur = (this.cur + 1) % 6;
    } else if (this.rel(i) === -1) {
      this.cur = (this.cur + 5) % 6;
    }
  }

  build() {
    Stack() {
      PatternBg()
      Column() {
      // 页头：返回 + 居中标题
      Row() {
        Text('‹')
          .fontSize(fs(20))
          .fontColor(INK)
          .width(34)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor('rgba(255,255,255,0.72)')
          .borderRadius(17)
          .onClick(goBack)
        Blank()
        Text('创意工坊')
          .fontSize(fs(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(INK)
          .letterSpacing(3)
        Blank()
        Column().width(34).height(34)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 6 })

      // 页顶栏：切工坊 / 选教程
      Row() {
        ForEach(['切工坊', '选教程'], (t: string, i: number): void => {
          Column({ space: 5 }) {
            Text(t)
              .fontSize(fs(14))
              .fontColor(this.tab === i ? INK : SUB)
              .fontWeight(this.tab === i ? FontWeight.Bold : FontWeight.Regular)
              .letterSpacing(1)
            Column()
              .width(this.tab === i ? 24 : 0)
              .height(3)
              .borderRadius(1.5)
              .backgroundColor(CLAY)
          }
          .padding({ left: 16, right: 16, top: 2, bottom: 4 })
          .onClick((): void => {
            animateTo({ duration: 240, curve: Curve.EaseOut }, (): void => {
              this.tab = i;
            });
          })
        }, (t: string, i: number): string => 'tab_' + i)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Scroll() {
        Column({ space: 14 }) {
          if (this.tab === 0) {
            this.stage()
            this.works()
          } else {
            this.coursePick()
          }
          Text('文物图为 AI 生成的博物馆示意，非馆藏实拍；教程为手绘分镜演示。')
            .fontSize(fs(9))
            .fontColor(SUB)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ bottom: 18 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAPER)
  }
  }

  // —— 3D 文物展台：中央正身缓摆 + 两侧侧身件 + 地面倒影 + 指示点 ——
  @Builder
  stage() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        // 展台净底：一圈纸色柔光晕开，文物像立在展柜灯下，也盖住背景纹样
        Column()
          .width(330)
          .height(296)
          .borderRadius(148)
          .radialGradient({
            center: ['50%', '46%'], radius: 210,
            colors: [['#F5EFE4', 0], ['#F5EFE4', 0.62], ['rgba(245,239,228,0)', 1]]
          })
        ForEach(SHOW, (e: ExhibitRec, i: number): void => {
          if (Math.abs(this.rel(i)) <= 1) {
            Column() {
              Image(coverRes(e.img))
                .width(216)
                .height(216)
                .objectFit(ImageFit.Contain)
              // 倒影：同一张图取一段翻转压扁，纸色渐变抹淡
              if (this.rel(i) === 0) {
                Stack({ alignContent: Alignment.Top }) {
                  Image(coverRes(e.img))
                    .width(216)
                    .height(64)
                    .objectFit(ImageFit.Cover)
                    .scale({ y: -1 })
                    .opacity(0.16)
                  Column()
                    .width(216)
                    .height(64)
                    .linearGradient({
                      angle: 180,
                      colors: [['rgba(245,239,228,0.25)', 0], ['rgba(245,239,228,1)', 0.85]]
                    })
                }
                .width(216)
                .height(64)
              }
            }
            .rotate({
              x: 0, y: 1, z: 0,
              angle: this.rel(i) === 0 ? this.sway : (this.rel(i) < 0 ? 40 : -40)
            })
            .scale({ x: this.rel(i) === 0 ? 1 : 0.66, y: this.rel(i) === 0 ? 1 : 0.66 })
            .opacity(this.rel(i) === 0 ? 1 : 0.55)
            .translate({ x: this.rel(i) * 148, y: this.rel(i) === 0 ? this.floatY : 12 })
            .zIndex(this.rel(i) === 0 ? 20 : 10)
            .onClick((): void => {
              this.pick(i);
            })
          }
        }, (e: ExhibitRec, i: number): string => 'stage_' + e.img + '_' + this.cur)
        // 左右切换箭头
        Row() {
          Text('‹')
            .fontSize(fs(22))
            .fontColor(SUB)
            .padding(10)
            .onClick((): void => {
              this.cur = (this.cur + 5) % 6;
            })
          Blank()
          Text('›')
            .fontSize(fs(22))
            .fontColor(SUB)
            .padding(10)
            .onClick((): void => {
              this.cur = (this.cur + 1) % 6;
            })
        }
        .width('100%')
        .height(60)
        .padding({ left: 4, right: 4 })
        .zIndex(30)
      }
      .width('100%')
      .height(300)

      // 展品名 + 指示点
      Text(colorRowOf(SHOW[this.cur].key).name)
        .fontSize(fs(15))
        .fontWeight(FontWeight.Bold)
        .fontColor(INK)
        .letterSpacing(2)
      Row({ space: 6 }) {
        ForEach(SHOW, (e: ExhibitRec, i: number): void => {
          Column()
            .width(i === this.cur ? 14 : 5)
            .height(5)
            .borderRadius(2.5)
            .backgroundColor(i === this.cur ? CLAY : LINE)
            .onClick((): void => {
              this.cur = i;
            })
        }, (e: ExhibitRec, i: number): string => 'dot_' + e.img)
      }

      Text(colorRowOf(SHOW[this.cur].key).saying)
        .fontSize(fs(10))
        .fontColor(SUB)
        .width('80%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 6 })
  }

  // —— 工坊入口：陶艺工坊 / 颜色工坊，各带一句玩法说明 ——
  @Builder
  works() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 6 }) {
          Text('陶艺工坊')
            .fontSize(fs(15))
            .fontWeight(FontWeight.Bold)
            .fontColor(INK)
            .letterSpacing(2)
          Text('拉坯 · 上彩 · 入窑，做一件自己的彩陶')
            .fontSize(fs(10))
            .fontColor(SUB)
          Row({ space: 4 }) {
            Text('进工坊')
              .fontSize(fs(10))
              .fontColor(CLAY)
            Text('›')
              .fontSize(fs(11))
              .fontColor(CLAY)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding(12)
        .backgroundColor('rgba(255,255,255,0.72)')
        .borderRadius(12)
        .border({ width: 1, color: LINE })
        .onClick((): void => {
          router.pushUrl({ url: 'pages/PotteryPage' });
        })
      }
      .width('100%')

      Row() {
        Column({ space: 6 }) {
          Text('颜色工坊')
            .fontSize(fs(15))
            .fontWeight(FontWeight.Bold)
            .fontColor(INK)
            .letterSpacing(2)
          Text('认矿物色 · 给线稿上彩，一色一类文物')
            .fontSize(fs(10))
            .fontColor(SUB)
          Row({ space: 4 }) {
            Text('进工坊')
              .fontSize(fs(10))
              .fontColor(CLAY)
            Text('›')
              .fontSize(fs(11))
              .fontColor(CLAY)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding(12)
        .backgroundColor('rgba(255,255,255,0.72)')
        .borderRadius(12)
        .border({ width: 1, color: LINE })
        .onClick((): void => {
          router.pushUrl({ url: 'pages/ColorPage' });
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
  }

  // —— 选教程：分类胶囊 + 教程列表 ——
  @Builder
  coursePick() {
    Column({ space: 10 }) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(CATS, (c: string, i: number): void => {
            Text(CAT_NAMES[i])
              .fontSize(fs(10.5))
              .fontColor(this.cat === c ? PAPER : INK)
              .backgroundColor(this.cat === c ? CLAY : 'rgba(255,255,255,0.72)')
              .borderRadius(13)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .border({ width: 1, color: this.cat === c ? CLAY : LINE })
              .onClick((): void => {
                this.cat = c;
              })
          }, (c: string): string => 'cat_' + c)
        }
        .padding({ left: 14, right: 14 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      Column({ space: 8 }) {
        ForEach(ContentRepo.get().coursesOf(this.cat), (c: Course): void => {
          Row({ space: 10 }) {
            Column()
              .width(56)
              .height(70)
              .borderRadius(9)
              .backgroundColor(paletteOf(c.palette).base)
              .border({ width: 1, color: LINE })
            Column({ space: 4 }) {
              Text(c.title)
                .fontSize(fs(12))
                .fontWeight(FontWeight.Medium)
                .fontColor(INK)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(c.level + ' · ' + c.minutes + ' 分钟')
                .fontSize(fs(9.5))
                .fontColor(SUB)
              Row({ space: 4 }) {
                Text('看教程')
                  .fontSize(fs(9.5))
                  .fontColor(CLAY)
                Text('›')
                  .fontSize(fs(10.5))
                  .fontColor(CLAY)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(10)
          .backgroundColor('rgba(255,255,255,0.72)')
          .borderRadius(12)
          .border({ width: 1, color: LINE })
          .onClick((): void => {
            goPlayer(c.id);
          })
        }, (c: Course): string => 'row_' + c.id)
      }
      .width('100%')
      .padding({ left: 14, right: 14 })

      Row({ space: 4 }) {
        Text('打开完整教程列表')
          .fontSize(fs(10))
          .fontColor(CLAY)
        Text('›')
          .fontSize(fs(11))
          .fontColor(CLAY)
      }
      .onClick((): void => {
        goCourses();
      })
    }
    .width('100%')
    .padding({ top: 6 })
  }
}
