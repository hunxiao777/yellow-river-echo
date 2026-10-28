import { promptAction } from '@kit.ArkUI';
import { SiteInfo, EventInfo, Suggestion } from '../model/Models';
import { SiteRepo } from '../service/SiteRepo';
import { ContentRepo } from '../service/ContentRepo';
import { StudioStore } from '../service/StudioStore';
import { MemoryStore } from '../service/MemoryStore';
import { ArtCover } from './ArtCover';
import { RiverRibbon } from '../common/River';
import { Verse, verseOf, verseSiteName } from '../common/Verses';
import {
  ERAS, ERA_WORD, INK, SUB, LOESS, CLAY, RIVER, LINE, PAPER,
  paletteOf, eraPalette, agoText, fs
} from '../common/Theme';
import {
  openDrawer, switchTab, goList, goDetail, goArchive, goPottery,
  goCourses, goActivity, goTopic, goSync, goQuiz
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

interface RecentItem {
  site: SiteInfo;
  at: number;
}

interface GridTile {
  ch: string;
  title: string;
  note: string;
  act: () => void;
}

// 首页（扩展设计方案 §2.4）：开篇留白→今日一句→继续浏览→年代时间轴→为你推荐→功能宫格。
// 全局背景河尚未落地，所以河道元素收在开篇那一条里，避免画面出现两套河。
@Component
export struct HomeView {
  @StorageLink('dataRev') @Watch('reload') dataRev: number = 0;
  @StorageLink('studioRev') studioRev: number = 0;
  @StorageLink('textScale') ts: number = 1;
  @State kw: string = '';
  @State verse: Verse | undefined = undefined;
  @State recent: RecentItem[] = [];
  @State blocks: EraBlock[] = [];
  @State reco: Suggestion[] = [];
  @State events: EventInfo[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    let repo = SiteRepo.get();
    this.verse = verseOf(Date.now());

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

    let mem = MemoryStore.get();
    let list: RecentItem[] = [];
    for (let v of mem.views.slice(0, 3)) {
      let s = repo.byId(v.siteId);
      if (s !== undefined) {
        list.push({ site: s, at: v.at });
      }
    }
    this.recent = list;

    this.reco = repo.recommend(mem.favIds(), mem.views, 6, '');
    this.events = ContentRepo.get().upcomingEvents(2);
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

  tiles(): GridTile[] {
    return [
      { ch: '架', title: '档案库', note: '20 处遗存', act: (): void => {
        goArchive(0);
      } },
      { ch: '印', title: '在此打卡', note: '走到的地方', act: (): void => {
        goActivity(this.firstEventId());
      } },
      { ch: '陶', title: '彩陶工坊', note: '拼一件器物', act: (): void => {
        goPottery();
      } },
      { ch: '问', title: '趣味测试', note: '你是哪种人手', act: (): void => {
        goQuiz('');
      } },
      { ch: '课', title: '课程影像', note: '跟着工序走', act: (): void => {
        goCourses();
      } },
      { ch: '市', title: '文创市集', note: '把河带走', act: (): void => {
        switchTab(1);
      } },
      { ch: '络', title: '知识网络', note: '关联摊开看', act: (): void => {
        goTopic();
      } },
      { ch: '步', title: '同步面板', note: '两台设备', act: (): void => {
        goSync();
      } }
    ];
  }

  @Builder
  topBar() {
    Row({ space: 8 }) {
      Text('☰')
        .fontSize(fs(20))
        .fontColor(INK)
        .width(26)
        .onClick((): void => {
          openDrawer();
        })

      TextInput({ placeholder: '搜遗址、器物或纹样', text: this.kw })
        .height(36)
        .fontSize(fs(13))
        .fontColor(INK)
        .placeholderColor(SUB)
        .placeholderFont({ size: fs(13) })
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
          .fontSize(fs(19))
          .fontColor(INK)
          .margin({ top: 5, right: 6 })
        if (this.unread() > 0) {
          Text(`${this.unread()}`)
            .fontSize(fs(9))
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

  // 1. 开篇留白：标题 + 一条干流，不再叠促销图
  @Builder
  opening() {
    Column({ space: 2 }) {
      Text('黄河记忆')
        .fontSize(fs(24))
        .fontColor(INK)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(4)
      Text('把这条河，装进口袋')
        .fontSize(fs(11))
        .fontColor(SUB)
        .letterSpacing(1)
        .margin({ bottom: 4 })
      RiverRibbon({ bandHeight: 82, showDots: true, activeId: '',
        note: '横轴是年代（仰韶 → 宋），纵向偏移是城市自西向东；示意排布，非真实经纬。实心点是你打过卡的现场。' })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 6, bottom: 10 })
  }

  // 2. 今日一句：按日期确定性取，点进去就是那句诗所属的遗址
  @Builder
  verseCard() {
    if (this.verse !== undefined) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('今日一句')
            .fontSize(fs(10))
            .fontColor('#3A2A1E')
            .backgroundColor(LOESS)
            .borderRadius(8)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          Text(this.verse.real ? '库内收录' : '拟咏')
            .fontSize(fs(10))
            .fontColor(SUB)
            .borderRadius(8)
            .border({ width: 1, color: LINE })
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          Blank()
          Text('去现场 ›')
            .fontSize(fs(11))
            .fontColor(CLAY)
        }
        .width('100%')

        Text(this.verse!.text)
          .fontSize(fs(16))
          .fontColor(INK)
          .lineHeight(fs(26))
        Row({ space: 6 }) {
          Text(this.verse!.from)
            .fontSize(fs(11))
            .fontColor(SUB)
          Blank()
          Text(verseSiteName(this.verse!))
            .fontSize(fs(11))
            .fontColor(RIVER)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(14)
      .onClick((): void => {
        goDetail(this.verse!.siteId);
      })
    }
  }

  // 3. 继续浏览：本机最近三条阅读记录
  @Builder
  continueRow() {
    Column({ space: 8 }) {
      this.head('继续浏览', '上次读到这儿', (): void => {
        goArchive(0);
      })
      Row({ space: 10 }) {
        ForEach(this.recent, (r: RecentItem): void => {
          Column({ space: 5 }) {
            Column() {
              ArtCover({ palette: eraPalette(r.site.eras[0]), shape: this.shapeOf(r.site.id),
                seed: r.site.id.length })
            }
            .width('100%')
            .height(56)
            .borderRadius(8)
            .clip(true)
            Text(r.site.name)
              .fontSize(fs(12))
              .fontColor(INK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(agoText(r.at))
              .fontSize(fs(10))
              .fontColor(SUB)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .onClick((): void => {
            goDetail(r.site.id);
          })
        }, (r: RecentItem): string => r.site.id)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  head(title: string, hint: string, act: () => void) {
    Row() {
      Text(title)
        .fontSize(fs(16))
        .fontColor(INK)
        .fontWeight(FontWeight.Medium)
      Blank()
      Text(hint)
        .fontSize(fs(11))
        .fontColor(SUB)
      Text(' ›')
        .fontSize(fs(13))
        .fontColor(SUB)
    }
    .width('100%')
    .padding({ top: 4, bottom: 2 })
    .onClick(act)
  }

  // 4. 年代时间轴：六段河岸，点一段就是按年代筛选
  @Builder
  eraTimeline() {
    Column({ space: 8 }) {
      this.head('年代时间轴', '点一段，筛一次', (): void => {
        goList('', '', '', '');
      })
      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width('100%')
          .height(2)
          .backgroundColor(LINE)
          .margin({ top: 9 })
        Row() {
          ForEach(this.blocks, (b: EraBlock): void => {
            Column({ space: 4 }) {
              Circle()
                .width(9)
                .height(9)
                .fill(b.count > 0 ? b.deep : '#D9CDB6')
              Text(b.era)
                .fontSize(fs(12))
                .fontColor(INK)
              Text(b.word)
                .fontSize(fs(10))
                .fontColor(SUB)
              Text(b.count > 0 ? `${b.count} 处` : '缺口')
                .fontSize(fs(10))
                .fontColor(b.count > 0 ? b.deep : SUB)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 2, bottom: 8 })
            .onClick((): void => {
              goList('', b.era, '', '');
            })
          }, (b: EraBlock): string => b.era)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 2, right: 2 })
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(12)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 5. 为你推荐：端侧加权，每张卡都写清理由
  @Builder
  recoSection() {
    Column({ space: 8 }) {
      this.head('为你推荐', MemoryStore.get().favIds().length > 0 ? '按收藏加权' : '冷启动·精选',
        (): void => {
          goList('', '', '', '');
        })
      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.reco, (sg: Suggestion, i: number): void => {
            Column({ space: 5 }) {
              Column() {
                ArtCover({ palette: eraPalette(sg.site.eras[0]), shape: this.shapeOf(sg.site.id),
                  seed: i + 3 })
              }
              .width(150)
              .height(84)
              .borderRadius(8)
              .clip(true)
              Text(sg.site.name)
                .fontSize(fs(13))
                .fontColor(INK)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(sg.reason)
                .fontSize(fs(10))
                .fontColor(SUB)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width(150)
            .alignItems(HorizontalAlign.Start)
            .padding(10)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(12)
            .onClick((): void => {
              goDetail(sg.site.id);
            })
          }, (sg: Suggestion): string => sg.site.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 6. 功能入口宫格：自绘印章式汉字，不用 emoji
  @Builder
  grid() {
    Column({ space: 8 }) {
      this.head('沿河可去', '八个入口', (): void => {
        openDrawer();
      })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.tiles(), (t: GridTile): void => {
          Column({ space: 6 }) {
            Text(t.ch)
              .fontSize(fs(17))
              .fontColor('#FBF4E7')
              .width(38)
              .height(38)
              .borderRadius(10)
              .backgroundColor(CLAY)
              .textAlign(TextAlign.Center)
            Text(t.title)
              .fontSize(fs(11))
              .fontColor(INK)
            Text(t.note)
              .fontSize(fs(9))
              .fontColor(SUB)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('24%')
          .height(86)
          .margin({ bottom: 8 })
          .padding({ top: 8 })
          .alignItems(HorizontalAlign.Center)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
          .onClick((): void => {
            t.act();
          })
        }, (t: GridTile): string => t.title)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 7. 排期（保留原有活动入口，压缩成两张卡）
  @Builder
  eventSection() {
    Column({ space: 8 }) {
      this.head('沿河排期', `${ContentRepo.get().events.length} 场·演示数据`, (): void => {
        this.openFirstEvent();
      })
      if (this.events.length === 0) {
        Text('活动包还没随进来，晚些再来看').fontSize(fs(12)).fontColor(SUB)
          .width('100%').padding(14)
          .backgroundColor($r('app.color.card_bg')).borderRadius(10)
      }
      ForEach(this.events, (e: EventInfo): void => {
        Row({ space: 10 }) {
          Column({ space: 1 }) {
            Text(e.date.substring(8, 10))
              .fontSize(fs(17))
              .fontColor(CLAY)
              .fontWeight(FontWeight.Bold)
            Text(e.date.substring(0, 7))
              .fontSize(fs(9))
              .fontColor(SUB)
          }
          .width(52)
          .height(46)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(PAPER)
          .borderRadius(8)

          Column({ space: 3 }) {
            Text(e.title)
              .fontSize(fs(14))
              .fontColor(INK)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${e.kind} · ${e.place}`)
              .fontSize(fs(11))
              .fontColor(SUB)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${e.fee}｜${e.seats}`)
              .fontSize(fs(11))
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
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.topBar()

      Scroll() {
        Column({ space: 14 }) {
          this.opening()
          this.verseCard()
          if (this.recent.length > 0) {
            this.continueRow()
          }
          this.eraTimeline()
          this.recoSection()
          this.grid()
          this.eventSection()

          Text('遗址档案文字来自公开资料整理；配图为 AI 生成示意图，非现场照片；今日一句中除两条唐诗外均为拟咏；文创与活动为概念演示数据，全程离线。')
            .fontSize(fs(10))
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
