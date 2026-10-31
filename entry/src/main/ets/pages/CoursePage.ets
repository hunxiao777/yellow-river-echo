import { router } from '@kit.ArkUI';
import { ContentRepo } from '../service/ContentRepo';
import { Course } from '../model/Models';
import { INK, SUB, CLAY } from '../common/Theme';
import { goPlayer } from '../common/Nav';
import { ArtCover } from '../view/ArtCover';

const CATS: string[] = ['全部', '手作', '讲读', '影像'];

function coverShape(c: Course): string {
  let hay = c.title + c.brief;
  if (hay.indexOf('拓') >= 0 || hay.indexOf('碑') >= 0 || hay.indexOf('刻') >= 0) {
    return 'scroll';
  }
  if (hay.indexOf('窑') >= 0 || hay.indexOf('塔') >= 0 || hay.indexOf('寺') >= 0) {
    return 'kiln';
  }
  if (hay.indexOf('爵') >= 0 || hay.indexOf('铜') >= 0 || hay.indexOf('范铸') >= 0) {
    return 'coin';
  }
  if (hay.indexOf('黑陶') >= 0 || hay.indexOf('拉坯') >= 0 || hay.indexOf('施釉') >= 0) {
    return 'jar';
  }
  if (hay.indexOf('彩陶') >= 0 || hay.indexOf('鱼纹') >= 0 || hay.indexOf('捏') >= 0) {
    return 'pot';
  }
  return 'tile';
}

@Entry
@Component
struct CoursePage {
  @State cat: string = '全部';

  list(): Course[] {
    return ContentRepo.get().coursesOf(this.cat);
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text('‹').fontSize(24).fontColor(CLAY).width(22)
          .onClick((): void => {
            router.back();
          })
        Column({ space: 2 }) {
          Text('课程影像').fontSize(18).fontColor(INK).fontWeight(FontWeight.Bold)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10 })

      Scroll() {
        Row({ space: 8 }) {
          ForEach(CATS, (o: string): void => {
            Text(o)
              .fontSize(12)
              .fontColor(o === this.cat ? Color.White : INK)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor(o === this.cat ? CLAY : $r('app.color.card_bg'))
              .onClick((): void => {
                this.cat = o;
              })
          }, (o: string): string => 'cat_' + o)
        }
        .padding({ left: 14, right: 14 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      if (ContentRepo.get().courses.length === 0) {
        Column({ space: 6 }) {
          Text('课程数据包未随包提供').fontSize(14).fontColor(INK)
          Text('遗址档案与彩陶工坊不受影响').fontSize(11).fontColor(SUB)
        }
        .width('100%')
        .margin({ top: 60 })
      } else if (this.list().length === 0) {
        Text('这一类暂时没有课程').fontSize(13).fontColor(SUB)
          .width('100%').margin({ top: 40 })
      } else {
        List({ space: 8 }) {
          ForEach(this.list(), (c: Course, i: number): void => {
            ListItem() {
              Row({ space: 10 }) {
                Stack() {
                  ArtCover({ palette: c.palette, shape: coverShape(c), seed: i + 1 })
                }
                .width(72)
                .height(92)
                .borderRadius(10)
                .clip(true)

                Column({ space: 5 }) {
                  Text(c.title).fontSize(15).fontColor(INK).fontWeight(FontWeight.Medium)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(c.brief).fontSize(12).fontColor(SUB)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${c.cat} · ${c.level} · ${c.minutes} 分钟 · ${c.steps.length} 个分镜`)
                    .fontSize(10).fontColor(CLAY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
              .alignItems(VerticalAlign.Top)
              .onClick((): void => {
                goPlayer(c.id);
              })
            }
          }, (c: Course): string => c.id + '_' + c.title.length)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ left: 14, right: 14 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .alignItems(HorizontalAlign.Start)
  }
}
