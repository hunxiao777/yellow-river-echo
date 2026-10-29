import { promptAction } from '@kit.ArkUI';
import { Goods, EventInfo, Suggestion } from '../model/Models';
import { SiteRepo } from '../service/SiteRepo';
import { ContentRepo } from '../service/ContentRepo';
import { StudioStore } from '../service/StudioStore';
import { MemoryStore } from '../service/MemoryStore';
import { ArtCover } from './ArtCover';
import { Verse, verseOf, verseSiteName } from '../common/Verses';
import {
  INK, SUB, LOESS, CLAY, RIVER, LINE,
  coverRes, coverOf, moneyText, fs
} from '../common/Theme';
import {
  openDrawer, switchTab, goList, goDetail, goArchive, goPottery,
  goActivity, goCheckin
} from '../common/Nav';

const SHAPES: string[] = ['pot', 'jar', 'ding', 'tile', 'stele', 'box', 'coin', 'kiln'];

// 首页四段（照参考图排布）：横幅轮播 → 四个主题按钮 → 为你推荐 → 文创市集。
// 河道动效不在这页了：它搬去「河道打卡」页当可点的地图，详情页里也留了一条缩略的。
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

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.verse = verseOf(Date.now());
    this.reco = SiteRepo.get().recommend(MemoryStore.get().favIds(), MemoryStore.get().views, 4, '');
    this.hot = ContentRepo.get().hotGoods(4);
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

  eventLead(): string {
    if (this.events.length === 0) {
      return '沿河馆舍的排期正在整理';
    }
    return `${this.events[0].date}｜${this.events[0].title}`;
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

  // 横幅上压一层由透到暗的渐变：白字直接压在示意图上会糊，垫一层才立得住
  @Builder
  scrim() {
    Column()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 180,
        colors: [['rgba(43,38,34,0)', 0.30], ['rgba(43,38,34,0.30)', 0.62], ['rgba(43,38,34,0.68)', 1]]
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
          .fontSize(fs(17))
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
        Text(lead)
          .fontSize(fs(11))
          .fontColor('#EFE6D6')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 26 })
    }
    .width('100%')
    .height('100%')
    .onClick(act)
  }

  // 今日一句收进横幅第二帧：首页少一张卡，诗句反而更醒目
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
          .fontSize(fs(15))
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .lineHeight(fs(23))
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
      .padding({ left: 14, right: 14, top: 14, bottom: 26 })
    }
    .width('100%')
    .height('100%')
    .onClick((): void => {
      goDetail(this.verse!.siteId);
    })
  }

  @Builder
  banner() {
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
    .height(178)
    .autoPlay(true)
    .interval(4600)
    .loop(true)
    .cachedCount(2)
    .indicator(new DotIndicator()
      .itemWidth(5)
      .itemHeight(5)
      .selectedItemWidth(15)
      .selectedItemHeight(5)
      .color('rgba(255,255,255,0.45)')
      .selectedColor('#FFFFFF'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  quick(icon: string, title: string, act: () => void) {
    Column({ space: 7 }) {
      Text(icon)
        .fontSize(fs(19))
        .fontColor(CLAY)
        .width(46)
        .height(46)
        .borderRadius(23)
        .backgroundColor('#F1E7D5')
        .textAlign(TextAlign.Center)
      Text(title)
        .fontSize(fs(11))
        .fontColor(INK)
    }
    .layoutWeight(1)
    .onClick(act)
  }

  // 四个主题按钮，照参考图那一行：档案 / DIY / 签到 / 活动
  @Builder
  quickRow() {
    Row() {
      this.quick('◫', '档案', (): void => {
        goArchive(0);
      })
      this.quick('⌣', 'DIY', (): void => {
        goPottery();
      })
      this.quick('◎', '签到', (): void => {
        goCheckin();
      })
      this.quick('⚑', '活动', (): void => {
        this.openFirstEvent();
      })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
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

  // 文创市集：对应参考图的「推荐店铺」。商品没有实拍图，用程序化封面顶上
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
    Column() {
      this.topBar()

      Scroll() {
        Column({ space: 14 }) {
          this.banner()
          this.quickRow()
          this.recoGrid()
          this.shopGrid()

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
