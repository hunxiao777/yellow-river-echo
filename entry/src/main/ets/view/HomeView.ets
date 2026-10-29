import { promptAction } from '@kit.ArkUI';
import { Goods, EventInfo, Suggestion, SiteInfo } from '../model/Models';
import { SiteRepo } from '../service/SiteRepo';
import { ContentRepo } from '../service/ContentRepo';
import { StudioStore } from '../service/StudioStore';
import { MemoryStore } from '../service/MemoryStore';
import { ArtCover } from './ArtCover';
import { Verse, verseOf, verseSiteName } from '../common/Verses';
import { siteU } from '../common/River';
import {
  INK, SUB, LOESS, CLAY, RIVER, LINE, PAPER,
  coverRes, coverOf, moneyText, fs
} from '../common/Theme';
import {
  openDrawer, switchTab, goList, goDetail, goArchive, goPottery,
  goActivity, goCheckin, goRoute, goQuiz,
  goEngineer, goTopic, goSync, goStudio
} from '../common/Nav';
import { PatternBg } from './PatternBg';

const SHAPES: string[] = ['pot', 'jar', 'ding', 'tile', 'stele', 'box', 'coin', 'kiln'];

interface TileRec {
  kind: string;
  title: string;
  act: () => void;
}

// 无边手绘图标：不垫底、不描框，只有两笔——一层淡赭铺色、一层褐线勾边，
// 线都带一点手抖的弯度，照参考图那种"直接画在纸上"的样子。
const ICON_STROKE: Map<string, string> = new Map<string, string>([
  ['archive', 'M11 8 Q22 6.5 33 8 M11 36 Q22 37.5 33 36 M14 8 Q13 22 14 36 M30 8 Q31 22 30 36 ' +
    'M18 15 Q22 14.5 26 15 M18 20 Q22 20.5 26 20 M18 25 Q20.5 25.5 23 25'],
  ['checkin', 'M18 20 Q17 10 22 9 Q27 10 26 20 Q26 23 30 25 L14 25 Q18 23 18 20 ' +
    'M12 25 Q22 23.5 32 25 L32 31 Q22 32.5 12 31 Z M16 35 Q22 34 28 35'],
  ['route', 'M9 33 Q16 32 18 26 Q20 20 26 20 Q32 20 33 14 Q33.5 11 36 10 ' +
    'M5.5 33 a3.5 3.5 0 1 0 7 0 a3.5 3.5 0 1 0 -7 0 M33 10 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0'],
  ['event', 'M22 9 Q31 9 31 20 Q31 31 22 31 Q13 31 13 20 Q13 9 22 9 M17 7.5 Q22 6.5 27 7.5 ' +
    'M17 32.5 Q22 33.5 27 32.5 M17.5 11 Q15.5 20 17.5 29 M26.5 11 Q28.5 20 26.5 29 ' +
    'M22 9 Q21.6 20 22 31 M22 33.5 Q22 35.5 22 37'],
  ['studio', 'M17 8 Q22 7 27 8 M18 8 Q18 12 14 14 Q8 18 8 24 Q8 34 22 34 Q36 34 36 24 Q36 18 30 14 Q26 12 26 8 ' +
    'M11 24 Q14.5 26.5 18 24 Q21.5 21.5 25 24 Q28.5 26.5 32 24'],
  ['quiz', 'M11 9 Q33 8 34 10 Q35 12 34 24 Q34 27 31 27 L21 27 L15 33 L15.5 27 L12 27 Q9 27 9 24 Q9 12 10 10 Q10.5 9 11 9 ' +
    'M18.5 15 Q19 11.5 22.5 12 Q26 12.5 25 15.5 Q24.3 17.5 22 18.5 L22 21 M22 24 L22 24.6'],
  ['gauge', 'M9 30 Q9.5 17 22 16.5 Q34.5 17 35 30 M22 30 L28.5 22 M22 16.5 L22 19.5 ' +
    'M12.5 21 L14.5 23 M31.5 21 L29.5 23 M7 30 Q22 28.5 37 30'],
  ['net', 'M9 12 a3.5 3.5 0 1 0 7 0 a3.5 3.5 0 1 0 -7 0 M30 9 a3.5 3.5 0 1 0 7 0 a3.5 3.5 0 1 0 -7 0 ' +
    'M18 31 a3.5 3.5 0 1 0 7 0 a3.5 3.5 0 1 0 -7 0 M32 27 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0 ' +
    'M14 15 L19 28 M16 11 L30 10 M25 30 L32 28'],
  ['sync', 'M12 19 Q14 11 22 10.5 Q29 11 31.5 16 M31.5 10.5 L31.5 16 L25.5 16 ' +
    'M32 25 Q30 33 22 33.5 Q15 33 12.5 28 M12.5 33.5 L12.5 28 L18.5 28'],
  ['notes', 'M30 8 Q34 10 33 13 L19 30 Q16 33 13.5 31 Q11.5 29 14 26 L30 8 M13 32 L10.5 37 L16 34.5']
]);

const ICON_FILL: Map<string, string> = new Map<string, string>([
  ['archive', 'M14 8 L30 8 L30 36 L14 36 Z'],
  ['checkin', 'M12 25 L32 25 L32 31 L12 31 Z'],
  ['route', 'M5.5 33 a3.5 3.5 0 1 0 7 0 a3.5 3.5 0 1 0 -7 0 Z'],
  ['event', 'M22 9 Q31 9 31 20 Q31 31 22 31 Q13 31 13 20 Q13 9 22 9 Z'],
  ['studio', 'M14 14 Q8 18 8 24 Q8 34 22 34 Q36 34 36 24 Q36 18 30 14 Q26 12 26 8 L18 8 Q18 12 14 14 Z'],
  ['quiz', 'M11 9 Q33 8 34 10 Q35 12 34 24 Q34 27 31 27 L21 27 L15 33 L15.5 27 L12 27 Q9 27 9 24 Q9 12 10 10 Q10.5 9 11 9 Z'],
  ['gauge', 'M9 30 Q9.5 17 22 16.5 Q34.5 17 35 30 Z'],
  ['net', 'M18 31 a3.5 3.5 0 1 0 7 0 a3.5 3.5 0 1 0 -7 0 Z'],
  ['notes', 'M17 23 L21 27 L19 30 Q16 33 13.5 31 Q11.5 29 14 26 Z']
]);

const ICON_TINT: Map<string, string> = new Map<string, string>([
  ['archive', 'rgba(200,161,96,0.18)'],
  ['checkin', 'rgba(166,85,61,0.28)'],
  ['route', 'rgba(166,85,61,0.45)'],
  ['event', 'rgba(200,161,96,0.22)'],
  ['studio', 'rgba(166,85,61,0.16)'],
  ['quiz', 'rgba(200,161,96,0.14)'],
  ['gauge', 'rgba(74,123,140,0.16)'],
  ['net', 'rgba(166,85,61,0.3)'],
  ['notes', 'rgba(43,38,34,0.22)']
]);

@Builder
function inkIcon(kind: string) {
  Stack() {
    if (ICON_FILL.has(kind)) {
      Path()
        .width(44)
        .height(44)
        .commands(ICON_FILL.get(kind) as string)
        .fill(ICON_TINT.get(kind) as string)
        .stroke(Color.Transparent)
    }
    Path()
      .width(44)
      .height(44)
      .commands(ICON_STROKE.get(kind) as string)
      .stroke('#8F6B44')
      .strokeWidth(1.7)
      .fill(Color.Transparent)
  }
  .width(44)
  .height(44)
}

// 宫格按钮：图标直接落在纸面上，无边无框，按下缩一下再弹回。
@Component
struct InkTile {
  @Prop kind: string = '';
  @Prop title: string = '';
  act: () => void = (): void => {};
  @State sc: number = 1;

  press(): void {
    animateTo({
      duration: 90, curve: Curve.EaseOut, onFinish: (): void => {
        animateTo({ duration: 160, curve: Curve.EaseIn }, (): void => {
          this.sc = 1;
        });
      }
    }, (): void => {
      this.sc = 0.88;
    });
    this.act();
  }

  build() {
    Column({ space: 4 }) {
      inkIcon(this.kind)
      Text(this.title)
        .fontSize(fs(10.5))
        .fontColor(INK)
        .maxLines(1)
    }
    .width('20%')
    .padding({ top: 6, bottom: 6 })
    .scale({ x: this.sc, y: this.sc })
    .onClick((): void => {
      this.press();
    })
  }
}

// 首页照故宫式排布：通栏海报 → 「今日开河」双卡（实景打卡 / 创意工坊）+ 行程行
// → 十枚无边手绘图标宫格 → 为你推荐 → 文创市集。陶艺 / 颜色 / 教程三个工坊
// 收进「创意工坊」单独模块，首页只留一枚入口；纸面底下垫一层慢漂的水纹。
@Component
export struct HomeView {
  @StorageLink('dataRev') @Watch('reload') dataRev: number = 0;
  @StorageLink('studioRev') studioRev: number = 0;
  @StorageLink('textScale') ts: number = 1;
  @State kw: string = '';
  @State verse: Verse | undefined = undefined;
  @State reco: Suggestion[] = [];
  @State hot: Goods[] = [];
  @State events: EventInfo[] = [];
  @State heroIdx: number = 0;
  @State today: string = '';
  @State routeStops: SiteInfo[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.verse = verseOf(Date.now());
    this.reco = SiteRepo.get().recommend(MemoryStore.get().favIds(), MemoryStore.get().views, 4, '');
    this.hot = ContentRepo.get().hotGoods(4);
    this.events = ContentRepo.get().upcomingEvents(2);
    let d = new Date();
    this.today = `${d.getMonth() + 1}月${d.getDate()}日`;
    let all = SiteRepo.get().sites.slice();
    all.sort((a: SiteInfo, b: SiteInfo): number => siteU(a) - siteU(b));
    this.routeStops = all.slice(0, 3);
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

  firstStopName(): string {
    return this.routeStops.length > 0 ? this.routeStops[0].name : '沿河遗存';
  }

  // 今日一句那一帧的底图：用诗句所属遗址的配图，换个日期换张图
  verseCover(): string {
    let v = this.verse;
    if (v === undefined) {
      return 'hero_river';
    }
    let s = SiteRepo.get().byId(v.siteId);
    if (s === undefined) {
      return coverOf('仰韶');
    }
    return s.cover.length > 0 ? s.cover : coverOf(s.eras[0]);
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

  tiles(): TileRec[] {
    return [
      { kind: 'archive', title: '遗址档案', act: (): void => { goArchive(0); } },
      { kind: 'checkin', title: '河道打卡', act: (): void => { goCheckin(); } },
      { kind: 'route', title: '行程规划', act: (): void => { goRoute(); } },
      { kind: 'event', title: '沿河活动', act: (): void => { this.openFirstEvent(); } },
      { kind: 'studio', title: '创意工坊', act: (): void => { goStudio(0); } },
      { kind: 'quiz', title: '趣味自测', act: (): void => { goQuiz('home'); } },
      { kind: 'gauge', title: '河工面板', act: (): void => { goEngineer(); } },
      { kind: 'net', title: '知识网络', act: (): void => { goTopic(); } },
      { kind: 'sync', title: '同步面板', act: (): void => { goSync(); } },
      { kind: 'notes', title: '收藏笔记', act: (): void => { goArchive(1); } }
    ];
  }

  // 顶栏叠在海报上：半透明圆片托住白色符号，海报的色彩能透上来
  @Builder
  topBar() {
    Row({ space: 8 }) {
      Text('☰')
        .fontSize(fs(17))
        .fontColor(Color.White)
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor('rgba(43,38,34,0.38)')
        .textAlign(TextAlign.Center)
        .onClick((): void => {
          openDrawer();
        })

      TextInput({ placeholder: '搜遗址、器物或纹样', text: this.kw })
        .height(34)
        .fontSize(fs(13))
        .fontColor(INK)
        .placeholderColor(SUB)
        .placeholderFont({ size: fs(13) })
        .backgroundColor('rgba(245,239,228,0.92)')
        .borderRadius(17)
        .border({ width: 1, color: 'rgba(229,218,198,0.9)' })
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
          .fontSize(fs(16))
          .fontColor(Color.White)
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('rgba(43,38,34,0.38)')
          .textAlign(TextAlign.Center)
        if (this.unread() > 0) {
          Text(`${this.unread()}`)
            .fontSize(fs(9))
            .fontColor(Color.White)
            .backgroundColor(CLAY)
            .borderRadius(7)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
      }
      .width(32)
      .height(32)
      .onClick((): void => {
        switchTab(2);
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 6 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  // 海报上压一层由透到暗的渐变：白字直接压在示意图上会糊，垫一层才立得住
  @Builder
  scrim() {
    Column()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 180,
        colors: [['rgba(43,38,34,0.16)', 0], ['rgba(43,38,34,0)', 0.34],
          ['rgba(43,38,34,0.34)', 0.66], ['rgba(43,38,34,0.72)', 1]]
      })
      .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  promo(title: string, lead: string, img: string, act: () => void) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(coverRes(img))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      this.scrim()
      Column({ space: 3 }) {
        Text(title)
          .fontSize(fs(19))
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
        Text(lead)
          .fontSize(fs(11))
          .fontColor('#EFE6D6')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 60, top: 14, bottom: 42 })
    }
    .width('100%')
    .height('100%')
    .onClick(act)
  }

  // 今日一句收进海报第二帧：首页少一张卡，诗句反而更醒目
  @Builder
  verseFrame() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(coverRes(this.verseCover()))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      this.scrim()
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text('今日一句')
            .fontSize(fs(9))
            .fontColor('#3A2A1E')
            .backgroundColor(LOESS)
            .borderRadius(7)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          Text(this.verse!.real ? '库内收录' : '拟咏')
            .fontSize(fs(9))
            .fontColor('#F0E7D8')
            .borderRadius(7)
            .border({ width: 1, color: 'rgba(240,231,216,0.6)' })
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        }
        Text(this.verse!.text)
          .fontSize(fs(16))
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .lineHeight(fs(24))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Text(this.verse!.from).fontSize(fs(10)).fontColor('#E3D8C6')
          Blank()
          Text(verseSiteName(this.verse!) + ' ›').fontSize(fs(10)).fontColor('#F4E9D8')
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 60, top: 14, bottom: 42 })
    }
    .width('100%')
    .height('100%')
    .onClick((): void => {
      goDetail(this.verse!.siteId);
    })
  }

  // 通栏海报：四帧轮播，右下角一枚 n/4 的页码片，照参考图那个位置
  @Builder
  hero() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Swiper() {
        this.promo('黄河记忆', '把这条河装进口袋 · 20 处沿河遗存', 'hero_river', (): void => {
          goArchive(0);
        })
        if (this.verse !== undefined) {
          this.verseFrame()
        }
        this.promo('彩陶工坊', '挑一件器形，描一组纹样', 'era_yangshao', (): void => {
          goPottery();
        })
        this.promo('沿河排期', this.eventLead(), 'era_hantang', (): void => {
          this.openFirstEvent();
        })
      }
      .width('100%')
      .height('100%')
      .autoPlay(true)
      .interval(4600)
      .loop(true)
      .cachedCount(2)
      .onChange((i: number): void => {
        this.heroIdx = i;
      })

      Text(`${this.heroIdx + 1}/4`)
        .fontSize(fs(10))
        .fontColor('#F0E7D8')
        .backgroundColor('rgba(43,38,34,0.55)')
        .borderRadius(10)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .margin({ right: 14, bottom: 40 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(286)
    .clip(true)
  }

  // 「今日开河」卡右上角的小楼阁：三层檐叠出来，给卡片一个视觉锚点
  @Builder
  pavilion() {
    Column() {
      Column().width(26).height(8).borderRadius({ topLeft: 7, topRight: 7 }).backgroundColor(CLAY)
      Column().width(16).height(7).backgroundColor('#F0E7D8')
      Column().width(44).height(8).borderRadius({ topLeft: 7, topRight: 7 }).backgroundColor('#B05E43')
      Column().width(30).height(9).backgroundColor('#F0E7D8')
      Column().width(52).height(4).borderRadius(2).backgroundColor(LOESS)
    }
    .opacity(0.9)
  }

  // 实景打卡子卡：卡里直接画一条三站的顺线，点整卡进河道打卡页
  @Builder
  checkinCard() {
    Column({ space: 7 }) {
      Text('实景打卡')
        .fontSize(fs(15))
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)
      Text('路线规划 · 地方介绍')
        .fontSize(fs(9))
        .fontColor('rgba(246,230,214,0.85)')
      Stack() {
        Column().width('82%').height(1.5).backgroundColor('rgba(255,255,255,0.4)')
        Row() {
          Column().width(7).height(7).borderRadius(4).backgroundColor(Color.White)
          Blank()
          Column().width(7).height(7).borderRadius(4).backgroundColor('rgba(255,255,255,0.35)')
            .border({ width: 1.2, color: Color.White })
          Blank()
          Column().width(7).height(7).borderRadius(4).backgroundColor('rgba(255,255,255,0.35)')
            .border({ width: 1.2, color: Color.White })
        }
        .width('82%')
      }
      .width('100%')
      .height(14)
      .padding({ top: 2, bottom: 2 })

      Text(`${this.firstStopName()} ›`)
        .fontSize(fs(10))
        .fontColor('#F6E6D6')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(12)
    .borderRadius(12)
    .linearGradient({ angle: 160, colors: [['#B05E43', 0], ['#8E4530', 1]] })
    .onClick((): void => {
      goCheckin();
    })
  }

  // 创意工坊子卡：一张侧身的文物小照当门面，点整卡进工坊模块
  @Builder
  workshopCard() {
    Column({ space: 6 }) {
      Row() {
        Text('创意工坊')
          .fontSize(fs(15))
          .fontColor(INK)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
        Blank()
        Text('›')
          .fontSize(fs(13))
          .fontColor(SUB)
      }
      .width('100%')

      Text('陶艺 · 颜色 · 教程')
        .fontSize(fs(9))
        .fontColor(SUB)

      Row({ space: 9 }) {
        Stack() {
          Image(coverRes('era_yangshao'))
            .width(64)
            .height(46)
            .objectFit(ImageFit.Cover)
            .borderRadius(7)
            .rotate({ x: 0, y: 1, z: 0, angle: -16 })
          Column()
            .width(46)
            .height(6)
            .borderRadius(3)
            .backgroundColor('rgba(43,38,34,0.2)')
            .blur(4)
            .margin({ top: 46 })
        }
        .width(64)
        .height(54)

        Column({ space: 3 }) {
          Text('陶艺 · 借器形纹样')
            .fontSize(fs(9))
            .fontColor(SUB)
          Text('颜色 · 六色六器')
            .fontSize(fs(9))
            .fontColor(SUB)
          Text('教程 · 手作讲读影像')
            .fontSize(fs(9))
            .fontColor(SUB)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1.12)
    .padding(12)
    .borderRadius(12)
    .backgroundColor('#F3EADB')
    .border({ width: 1, color: '#E0D2B8' })
    .onClick((): void => {
      goStudio(0);
    })
  }

  // 「今日开馆」式大卡：双卡 + 一行行程入口，卡顶压住海报下沿
  @Builder
  todayCard() {
    Column({ space: 11 }) {
      Row() {
        Column({ space: 2 }) {
          Text('今日开河')
            .fontSize(fs(19))
            .fontColor(INK)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(3)
          Text(this.today)
            .fontSize(fs(11))
            .fontColor(SUB)
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        this.pavilion()
      }
      .width('100%')

      Row({ space: 10 }) {
        this.checkinCard()
        this.workshopCard()
      }
      .width('100%')

      Row({ space: 8 }) {
        Stack() {
          Column().width(14).height(1.5).backgroundColor(CLAY)
          Row() {
            Column().width(5).height(5).borderRadius(2.5).backgroundColor(CLAY)
            Blank()
            Column().width(5).height(5).borderRadius(2.5).backgroundColor(PAPER).border({ width: 1, color: CLAY })
          }
          .width(14)
        }
        .width(16).height(8)
        Text('规划我的行程')
          .fontSize(fs(12))
          .fontColor(INK)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('›')
          .fontSize(fs(13))
          .fontColor(SUB)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 9, bottom: 9 })
      .borderRadius(10)
      .backgroundColor('#EFE6D5')
      .onClick((): void => {
        goRoute();
      })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .margin({ top: -26 })
    .shadow({ radius: 14, color: 'rgba(43,38,34,0.14)', offsetY: -4 })
  }

  @Builder
  tileGrid() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.tiles(), (t: TileRec): void => {
        InkTile({ kind: t.kind, title: t.title, act: t.act })
      }, (t: TileRec): string => t.kind)
    }
    .width('100%')
    .padding({ top: 6, bottom: 2 })
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

  // 为你推荐：两列图卡，每张都写清为什么推给你
  @Builder
  recoCard(sg: Suggestion, i: number) {
    Column({ space: 5 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Image(coverRes(sg.site.cover.length > 0 ? sg.site.cover : coverOf(sg.site.eras[0])))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
        Text(sg.site.eras[0])
          .fontSize(fs(9))
          .fontColor('#F0E7D8')
          .backgroundColor('rgba(43,38,34,0.42)')
          .borderRadius(7)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin(8)
      }
      .width('100%')
      .height(104)
      .borderRadius(10)
      .clip(true)

      Text(sg.site.name)
        .fontSize(fs(13))
        .fontColor(INK)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(`${sg.site.city} · ${sg.site.types.join('/')}`)
        .fontSize(fs(10))
        .fontColor(SUB)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      // 有偏好才写"为什么推给你"；冷启动四张卡理由是同一句，写出来像 bug，不如放摘要
      if (sg.score > 0) {
        Text(sg.reason)
          .fontSize(fs(10))
          .fontColor(CLAY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text(sg.site.summary)
          .fontSize(fs(10))
          .fontColor(SUB)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('48%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8, left: 8, right: 8, bottom: 10 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .margin({ right: i % 2 === 0 ? '4%' : 0, bottom: 10 })
    .onClick((): void => {
      goDetail(sg.site.id);
    })
  }

  @Builder
  recoGrid() {
    Column({ space: 8 }) {
      this.head('为你推荐', MemoryStore.get().favIds().length > 0 ? '按收藏加权' : '冷启动·精选',
        (): void => {
          goList('', '', '', '');
        })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.reco, (sg: Suggestion, i: number): void => {
          this.recoCard(sg, i)
        }, (sg: Suggestion): string => sg.site.id)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 文创市集：商品没有实拍图，用程序化封面顶上
  @Builder
  shopCard(g: Goods, i: number) {
    Column({ space: 5 }) {
      Column() {
        ArtCover({ palette: g.palette, shape: this.shapeOf(g.id), seed: i + 2, label: g.cat })
      }
      .width('100%')
      .height(104)
      .borderRadius(10)
      .clip(true)

      Text(g.name)
        .fontSize(fs(13))
        .fontColor(INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 6 }) {
        Text('¥' + moneyText(g.price))
          .fontSize(fs(12))
          .fontColor(CLAY)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(g.origin)
          .fontSize(fs(10))
          .fontColor(RIVER)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
    .width('48%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8, left: 8, right: 8, bottom: 10 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .margin({ right: i % 2 === 0 ? '4%' : 0, bottom: 10 })
    .onClick((): void => {
      switchTab(1);
    })
  }

  @Builder
  shopGrid() {
    Column({ space: 8 }) {
      this.head('文创市集', `${ContentRepo.get().goods.length} 件·演示数据`, (): void => {
        switchTab(1);
      })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.hot, (g: Goods, i: number): void => {
          this.shopCard(g, i)
        }, (g: Goods): string => g.id)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      PatternBg()

      Column() {
        Scroll() {
          Column() {
            this.hero()

            Column({ space: 14 }) {
              this.todayCard()
              this.tileGrid()
              this.recoGrid()
              this.shopGrid()

              Text('遗址档案文字来自公开资料整理；配图为 AI 生成示意图，非现场照片；今日一句中除两条唐诗外均为拟咏；文创、活动与色卡为概念演示数据，全程离线。')
                .fontSize(fs(10))
                .fontColor(SUB)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ left: 14, right: 14, bottom: 20 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')

      this.topBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
