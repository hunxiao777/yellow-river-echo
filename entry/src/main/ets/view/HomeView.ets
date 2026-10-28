import { promptAction } from '@kit.ArkUI';
import { SiteInfo, Goods, EventInfo } from '../model/Models';
import { SiteRepo } from '../service/SiteRepo';
import { ContentRepo } from '../service/ContentRepo';
import { StudioStore } from '../service/StudioStore';
import { ArtCover } from './ArtCover';
import {
  ERAS, ERA_WORD, INK, SUB, LOESS, CLAY, RIVER, LINE, PAPER,
  coverRes, paletteOf, eraPalette, moneyText
} from '../common/Theme';
import {
  openDrawer, switchTab, goList, goDetail, goArchive, goPottery,
  goCourses, goActivity, goTopic, goGoods
} from '../common/Nav';

const SHAPES: string[] = ['pot', 'jar', 'ding', 'tile', 'stele', 'box', 'coin', 'kiln'];

interface EraBlock {
  era: string;
  key: string;
  word: string;
  count: number;
  shape: string;
  deep: string;
}

// 首页：检索入口、三帧推荐、宫格、今日一景、年代长廊、活动与热门文创。
@Component
export struct HomeView {
  @StorageLink('dataRev') @Watch('reload') dataRev: number = 0;
  @StorageLink('studioRev') studioRev: number = 0;
  @State kw: string = '';
  @State todaySite: SiteInfo | undefined = undefined;
  @State blocks: EraBlock[] = [];
  @State events: EventInfo[] = [];
  @State hot: Goods[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    let repo = SiteRepo.get();
    let n = repo.sites.length;
    let d = new Date();
    let pick = d.getFullYear() * 372 + (d.getMonth() + 1) * 31 + d.getDate();
    this.todaySite = n > 0 ? repo.sites[pick % n] : undefined;

    let out: EraBlock[] = [];
    for (let i = 0; i < ERAS.length; i++) {
      let era = ERAS[i];
      let key = eraPalette(era);
      let w = ERA_WORD.get(era);
      let pal = paletteOf(key);
      out.push({ era: era, key: key, word: w === undefined ? '' : w,
        count: repo.countByEra(era), shape: SHAPES[i % SHAPES.length], deep: pal.deep });
    }
    this.blocks = out;
    this.events = ContentRepo.get().upcomingEvents(2);
    this.hot = ContentRepo.get().hotGoods(4);
  }

  shapeOf(id: string): string {
    let n = 0;
    for (let i = 0; i < id.length; i++) {
      n += id.charCodeAt(i);
    }
    return SHAPES[n % SHAPES.length];
  }

  firstEventId(): string {
    return this.events.length > 0 ? this.events[0].id : '';
  }

  eventLead(): string {
    if (this.events.length === 0) {
      return '沿河馆舍的排期正在整理';
    }
    return `${this.events[0].date}｜${this.events[0].title}`;
  }

  unread(): number {
    return StudioStore.get().unread(ContentRepo.get().posts.length);
  }

  doSearch(): void {
    goList(this.kw, '', '', '');
  }

  openFirstEvent(): void {
    let id = this.firstEventId();
    if (id.length === 0) {
      promptAction.showToast({ message: '暂时没有排期' });
      return;
    }
    goActivity(id);
  }

  @Builder
  topBar() {
    Row({ space: 8 }) {
      Text('☰')
        .fontSize(20)
        .fontColor(INK)
        .width(26)
        .onClick((): void => {
          openDrawer();
        })

      TextInput({ placeholder: '搜遗址、器物或纹样', text: this.kw })
        .height(36)
        .fontSize(13)
        .fontColor(INK)
        .placeholderColor(SUB)
        .placeholderFont({ size: 13 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(18)
        .border({ width: 1, color: LINE })
        .enterKeyType(EnterKeyType.Search)
        .layoutWeight(1)
        .onChange((v: string): void => {
          this.kw = v;
        })
        .onSubmit((key: EnterKeyType): void => {
          this.doSearch();
        })

      Stack({ alignContent: Alignment.TopEnd }) {
        Text('✉')
          .fontSize(19)
          .fontColor(INK)
          .margin({ top: 5, right: 6 })
        if (this.unread() > 0) {
          Text(`${this.unread()}`)
            .fontSize(9)
            .fontColor(Color.White)
            .backgroundColor(CLAY)
            .borderRadius(7)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
      }
      .width(30)
      .height(30)
      .onClick((): void => {
        switchTab(2);
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  promo(title: string, lead: string, img: string, act: () => void) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(coverRes(img))
        .width('100%')
        .height(152)
        .objectFit(ImageFit.Cover)
      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
        Text(lead)
          .fontSize(11)
          .fontColor('#EFE6D6')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .padding(10)
      .margin({ left: 10, bottom: 10 })
      .backgroundColor('rgba(43,38,34,0.46)')
      .borderRadius(10)
    }
    .width('100%')
    .height(152)
    .borderRadius(14)
    .clip(true)
    .onClick(act)
  }

  @Builder
  quick(icon: string, title: string, act: () => void) {
    Column({ space: 6 }) {
      Text(icon)
        .fontSize(17)
        .fontColor(CLAY)
        .width(34)
        .height(34)
        .borderRadius(17)
        .backgroundColor('#F1E7D5')
        .textAlign(TextAlign.Center)
      Text(title)
        .fontSize(11)
        .fontColor(INK)
    }
    .layoutWeight(1)
    .padding({ top: 6, bottom: 6 })
    .onClick(act)
  }

  @Builder
  head(title: string, hint: string, act: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(INK)
        .fontWeight(FontWeight.Medium)
      Blank()
      Text(hint)
        .fontSize(11)
        .fontColor(SUB)
      Text(' ›')
        .fontSize(13)
        .fontColor(SUB)
    }
    .width('100%')
    .padding({ top: 4, bottom: 2 })
    .onClick(act)
  }

  build() {
    Column() {
      this.topBar()

      Scroll() {
        Column({ space: 14 }) {
          Swiper() {
            this.promo('档案库', '二十处沿河遗存，离线也能翻', 'hero_river', (): void => {
              goArchive(0);
            })
            this.promo('彩陶工坊', '挑一件器形，描一组纹样', 'era_yangshao', (): void => {
              goPottery();
            })
            this.promo('近期活动', this.eventLead(), 'era_hantang', (): void => {
              this.openFirstEvent();
            })
          }
          .width('100%')
          .height(152)
          .autoPlay(true)
          .interval(4200)
          .loop(true)

          Row() {
            this.quick('◫', '档案库', (): void => {
              goArchive(0);
            })
            this.quick('⌣', '彩陶工坊', (): void => {
              goPottery();
            })
            this.quick('☼', '课程影像', (): void => {
              goCourses();
            })
            this.quick('◎', '线下活动', (): void => {
              this.openFirstEvent();
            })
            this.quick('⊚', '知识网络', (): void => {
              goTopic();
            })
          }
          .width('100%')
          .padding({ top: 8, bottom: 4 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)

          if (this.todaySite !== undefined) {
            Column() {
              Stack({ alignContent: Alignment.BottomStart }) {
                Image(coverRes(this.todaySite!.cover))
                  .width('100%')
                  .height(148)
                  .objectFit(ImageFit.Cover)
                Row({ space: 8 }) {
                  Text('今日一景')
                    .fontSize(10)
                    .fontColor('#3A2A1E')
                    .backgroundColor(LOESS)
                    .borderRadius(8)
                    .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  Text(this.todaySite!.name)
                    .fontSize(17)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                }
                .padding(10)
                .margin({ left: 10, bottom: 10 })
                .backgroundColor('rgba(43,38,34,0.42)')
                .borderRadius(10)
              }
              .width('100%')
              .height(148)

              Column({ space: 6 }) {
                Text(this.todaySite!.summary)
                  .fontSize(12)
                  .fontColor(SUB)
                  .lineHeight(19)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 6 }) {
                  Text(this.todaySite!.city)
                    .fontSize(11)
                    .fontColor(RIVER)
                    .backgroundColor('#EDF1F0')
                    .borderRadius(8)
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  Text(this.todaySite!.eras.join(' / '))
                    .fontSize(11)
                    .fontColor(SUB)
                  Blank()
                  Text('看档案 ›')
                    .fontSize(12)
                    .fontColor(CLAY)
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
            }
            .width('100%')
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            .clip(true)
            .onClick((): void => {
              goDetail(this.todaySite!.id);
            })
          }

          Column({ space: 6 }) {
            this.head('年代长廊', '六个年代，六段河岸', (): void => {
              goList('', '', '', '');
            })
            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.blocks, (b: EraBlock, i: number): void => {
                  Column({ space: 5 }) {
                    Column() {
                      ArtCover({ palette: b.key, shape: b.shape, seed: b.count + i })
                    }
                    .width(92)
                    .height(50)
                    .borderRadius(6)
                    .clip(true)
                    Text(b.era)
                      .fontSize(14)
                      .fontColor(INK)
                      .fontWeight(FontWeight.Medium)
                    Text(b.word)
                      .fontSize(11)
                      .fontColor(SUB)
                    Text(`${b.count} 处`)
                      .fontSize(10)
                      .fontColor(b.deep)
                  }
                  .width(96)
                  .padding({ top: 8, bottom: 8 })
                  .alignItems(HorizontalAlign.Center)
                  .backgroundColor($r('app.color.card_bg'))
                  .border({ width: { bottom: 2 }, color: b.deep })
                  .borderRadius(10)
                  .onClick((): void => {
                    goList('', b.era, '', '');
                  })
                }, (b: EraBlock): string => b.era)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }

          Column({ space: 8 }) {
            this.head('最近的活动', `${ContentRepo.get().events.length} 场排期`, (): void => {
              this.openFirstEvent();
            })
            if (this.events.length === 0) {
              Text('活动包还没随进来，晚些再来看').fontSize(12).fontColor(SUB)
                .width('100%').padding(14)
                .backgroundColor($r('app.color.card_bg')).borderRadius(10)
            }
            ForEach(this.events, (e: EventInfo): void => {
              Row({ space: 10 }) {
                Column({ space: 1 }) {
                  Text(e.date.substring(8, 10))
                    .fontSize(17)
                    .fontColor(CLAY)
                    .fontWeight(FontWeight.Bold)
                  Text(e.date.substring(0, 7))
                    .fontSize(9)
                    .fontColor(SUB)
                }
                .width(52)
                .height(46)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(PAPER)
                .borderRadius(8)

                Column({ space: 3 }) {
                  Text(e.title)
                    .fontSize(14)
                    .fontColor(INK)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${e.kind} · ${e.place}`)
                    .fontSize(11)
                    .fontColor(SUB)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${e.fee}｜${e.seats}`)
                    .fontSize(11)
                    .fontColor(LOESS)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(10)
              .onClick((): void => {
                goActivity(e.id);
              })
            }, (e: EventInfo): string => e.id)
          }

          Column({ space: 8 }) {
            this.head('有人在看这些', '按点赞排', (): void => {
              switchTab(1);
            })
            if (this.hot.length === 0) {
              Text('文创数据包未随包提供').fontSize(12).fontColor(SUB)
                .width('100%').padding(14)
                .backgroundColor($r('app.color.card_bg')).borderRadius(10)
            }
            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.hot, (g: Goods, i: number): void => {
                  Column({ space: 4 }) {
                    Column() {
                      ArtCover({ palette: g.palette, shape: this.shapeOf(g.id), seed: i + 2,
                        label: g.cat })
                    }
                    .width(122)
                    .height(90)
                    .borderRadius(8)
                    .clip(true)
                    Text(g.name)
                      .fontSize(12)
                      .fontColor(INK)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`¥${moneyText(g.price)}`)
                      .fontSize(12)
                      .fontColor(CLAY)
                      .fontWeight(FontWeight.Medium)
                  }
                  .width(122)
                  .alignItems(HorizontalAlign.Start)
                  .padding(8)
                  .backgroundColor($r('app.color.card_bg'))
                  .borderRadius(10)
                  .onClick((): void => {
                    goGoods(g.id);
                  })
                }, (g: Goods): string => g.id)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }

          Text('文创商品与活动为概念演示数据，遗址档案内容来自公开资料整理。')
            .fontSize(10)
            .fontColor(SUB)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 4, bottom: 20 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
