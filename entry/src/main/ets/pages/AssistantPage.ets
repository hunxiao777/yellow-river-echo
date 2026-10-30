import { router } from '@kit.ArkUI';
import { ChatTurn, Citation } from '../model/AiModels';
import { AiStore } from '../service/AiStore';
import { AiService, AiReply } from '../service/AiService';
import { AiContext } from '../service/AiContext';
import { INK, SUB, LOESS, CLAY, LINE, RIVER, fs } from '../common/Theme';
import { goDetail } from '../common/Nav';

const TIPS: string[] = [
  '仰韶彩陶有什么特点？',
  '二里头为什么被称为最早的中国？',
  '我收藏里哪几处值得先去？'
];

@Entry
@Component
struct AssistantPage {
  @StorageLink('aiRev') rev: number = 0;
  @State turns: ChatTurn[] = [];
  @State input: string = '';
  @State busy: boolean = false;
  @State cfgOpen: boolean = false;
  @State base: string = '';
  @State apiKey: string = '';
  @State personal: boolean = false;
  @State err: string = '';
  @State lastQ: string = '';
  @State clearAsk: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.reload();
    if (!AiStore.get().configured()) {
      this.cfgOpen = true;
    }
  }

  reload(): void {
    let s = AiStore.get();
    this.turns = s.turns.slice();
    this.base = s.baseUrl;
    this.apiKey = s.appKey;
    this.personal = s.personalOn;
    this.toBottom();
  }

  toBottom(): void {
    setTimeout((): void => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 60);
  }

  async send(): Promise<void> {
    let q = this.input.trim();
    if (q.length === 0 || this.busy) {
      return;
    }
    let store = AiStore.get();
    if (!store.configured()) {
      this.cfgOpen = true;
      this.err = '先填好 Dify 地址和 App Key 再提问';
      return;
    }
    this.input = '';
    this.err = '';
    this.clearAsk = false;
    store.pushTurn({ role: 'user', text: q, at: Date.now(), citations: [], failed: false });
    this.turns = store.turns.slice();
    this.busy = true;
    this.toBottom();

    let ctx = AiContext.build(q);
    let res: AiReply = await AiService.get().ask(q, ctx);
    this.busy = false;
    if (res.ok) {
      this.lastQ = '';
      store.pushTurn({
        role: 'ai', text: res.answer, at: Date.now(), citations: res.citations, failed: false
      });
    } else {
      this.err = res.error;
      this.lastQ = q;
    }
    this.turns = store.turns.slice();
    this.toBottom();
  }

  async saveCfg(): Promise<void> {
    if (this.apiKey.trim().length === 0) {
      this.err = 'App Key 不能为空';
      return;
    }
    await AiStore.get().saveSettings(this.base, this.apiKey);
    this.cfgOpen = false;
    this.err = '';
  }

  askTip(s: string): void {
    this.input = s;
    this.send();
  }

  retry(): void {
    let q = this.lastQ;
    if (q.length === 0 || this.busy) {
      return;
    }
    this.input = q;
    this.lastQ = '';
    this.send();
  }

  @Builder
  head() {
    Row({ space: 10 }) {
      Text('‹ 返回')
        .fontSize(fs(14))
        .fontColor(INK)
        .onClick((): void => {
          router.back();
        })
      Column({ space: 2 }) {
        Text('河小导')
          .fontSize(fs(16))
          .fontColor(INK)
          .fontWeight(FontWeight.Medium)
        Text('黄河续响平台 · 文化向导')
          .fontSize(fs(10))
          .fontColor(SUB)
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Text(this.cfgOpen ? '完成' : '设置')
        .fontSize(fs(12))
        .fontColor(this.cfgOpen ? CLAY : SUB)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick((): void => {
          this.cfgOpen = !this.cfgOpen;
          this.err = '';
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 10 })
  }

  @Builder
  cfgCard() {
    Scroll() {
      Column({ space: 12 }) {
        Text('接入设置')
          .fontSize(fs(15))
          .fontColor(INK)
          .fontWeight(FontWeight.Medium)
          .width('100%')
        Text('地址填到 Dify 的 /v1 为止，例如 https://api.dify.ai/v1。App Key 以 app- 开头，只保存在本机。')
          .fontSize(fs(11))
          .fontColor(SUB)
          .lineHeight(fs(17))
          .width('100%')

        Text('Dify 地址')
          .fontSize(fs(11))
          .fontColor(SUB)
          .width('100%')
        TextInput({ placeholder: 'https://api.dify.ai/v1', text: this.base })
          .height(40)
          .fontSize(fs(12))
          .backgroundColor('#FBF6EC')
          .borderRadius(10)
          .border({ width: 1, color: LINE })
          .onChange((v: string): void => {
            this.base = v;
          })

        Text('App Key')
          .fontSize(fs(11))
          .fontColor(SUB)
          .width('100%')
        TextInput({ placeholder: 'app-xxxxxxxx', text: this.apiKey })
          .type(InputType.Password)
          .height(40)
          .fontSize(fs(12))
          .backgroundColor('#FBF6EC')
          .borderRadius(10)
          .border({ width: 1, color: LINE })
          .onChange((v: string): void => {
            this.apiKey = v;
          })

        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Text('带上我的收藏与笔记')
              .fontSize(fs(13))
              .fontColor(INK)
            Text('开启后，最多 8 条摘要会随问题发给 Dify 上的模型；关闭则只发问题本身。')
              .fontSize(fs(10))
              .fontColor(SUB)
              .lineHeight(fs(15))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Toggle({ type: ToggleType.Switch, isOn: this.personal })
            .selectedColor(CLAY)
            .onChange((on: boolean): void => {
              this.personal = on;
              AiStore.get().setPersonal(on).catch((e: Error): void => {
                console.warn('personal toggle: ' + e.message);
              });
            })
        }
        .width('100%')

        if (this.err.length > 0) {
          Text(this.err)
            .fontSize(fs(11))
            .fontColor(CLAY)
            .width('100%')
        }

        Row({ space: 10 }) {
          Text('保存')
            .fontSize(fs(13))
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(40)
            .borderRadius(20)
            .backgroundColor(CLAY)
            .onClick((): void => {
              this.saveCfg();
            })
          Text(this.clearAsk ? '再点一次清空' : '清空对话')
            .fontSize(fs(12))
            .fontColor(this.clearAsk ? CLAY : SUB)
            .textAlign(TextAlign.Center)
            .width(108)
            .height(40)
            .borderRadius(20)
            .border({ width: 1, color: this.clearAsk ? CLAY : LINE })
            .onClick((): void => {
              if (!this.clearAsk) {
                this.clearAsk = true;
                return;
              }
              this.clearAsk = false;
              AiStore.get().clearChat().then((): void => {
                this.turns = [];
              });
            })
        }
        .width('100%')

        Text('知识库侧：Chat App 需要新增一个文本变量 personal_context，并在提示词里引用 {{personal_context}}；不配也不会影响普通问答。')
          .fontSize(fs(10))
          .fontColor(SUB)
          .lineHeight(fs(16))
          .width('100%')
          .margin({ top: 6 })
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .padding({ left: 14, right: 14, bottom: 16 })
  }

  @Builder
  citeChip(c: Citation) {
    Text('引 · ' + c.name)
      .fontSize(fs(10))
      .fontColor(c.siteId.length > 0 ? RIVER : SUB)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(9)
      .border({ width: 1, color: c.siteId.length > 0 ? 'rgba(74,123,140,0.45)' : LINE })
      .margin({ right: 6, top: 6 })
      .onClick((): void => {
        if (c.siteId.length > 0) {
          goDetail(c.siteId);
        }
      })
  }

  @Builder
  turnView(t: ChatTurn) {
    if (t.role === 'user') {
      Row() {
        Blank()
        Text(t.text)
          .fontSize(fs(13))
          .fontColor(Color.White)
          .lineHeight(fs(20))
          .padding({ left: 12, right: 12, top: 9, bottom: 9 })
          .backgroundColor(CLAY)
          .borderRadius({ topLeft: 14, topRight: 4, bottomLeft: 14, bottomRight: 14 })
          .constraintSize({ maxWidth: '82%' })
      }
      .width('100%')
    } else {
      Column({ space: 2 }) {
        Text(t.text)
          .fontSize(fs(13))
          .fontColor(t.failed ? CLAY : INK)
          .lineHeight(fs(21))
          .copyOption(CopyOptions.LocalDevice)
        if (t.citations.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(t.citations, (c: Citation): void => {
              this.citeChip(c)
            }, (c: Citation): string => c.siteId + '|' + c.name)
          }
          .width('100%')
          .margin({ top: 4 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius({ topLeft: 4, topRight: 14, bottomLeft: 14, bottomRight: 14 })
      .border({ width: t.failed ? 1 : 0, color: 'rgba(166,85,61,0.35)' })
    }
  }

  @Builder
  emptyState() {
    Column({ space: 12 }) {
      Stack() {
        Column()
          .width(64)
          .height(64)
          .borderRadius(32)
          .backgroundColor('#EFE3CE')
        Text('导')
          .fontSize(28)
          .fontColor(CLAY)
          .fontWeight(FontWeight.Bold)
      }
      Text('沿河有事，问我')
        .fontSize(fs(16))
        .fontColor(INK)
        .fontWeight(FontWeight.Medium)
      Text('我知道站内 20 处遗址、课程和活动，也能按你的收藏推荐路线。答不了的会直说，不编年代和票价。')
        .fontSize(fs(11))
        .fontColor(SUB)
        .lineHeight(fs(18))
        .textAlign(TextAlign.Center)
        .padding({ left: 18, right: 18 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(TIPS, (s: string): void => {
          Text(s)
            .fontSize(fs(11))
            .fontColor(INK)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .borderRadius(14)
            .backgroundColor('#FBF6EC')
            .border({ width: 1, color: LINE })
            .margin({ right: 6, top: 8 })
            .onClick((): void => {
              this.askTip(s);
            })
        }, (s: string): string => s)
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 40 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  chatBody() {
    List({ scroller: this.scroller, space: 12 }) {
      ForEach(this.turns, (t: ChatTurn, i: number): void => {
        ListItem() {
          this.turnView(t)
        }
      }, (t: ChatTurn, i: number): string => `${t.at}-${i}-${t.role}`)

      if (this.turns.length === 0) {
        ListItem() {
          this.emptyState()
        }
      }
      if (this.busy) {
        ListItem() {
          Text('河小导正在翻档案…')
            .fontSize(fs(11))
            .fontColor(SUB)
            .padding({ left: 2, top: 2, bottom: 2 })
        }
      }
      if (this.err.length > 0) {
        ListItem() {
          Row({ space: 8 }) {
            Text(this.err)
              .fontSize(fs(11))
              .fontColor(CLAY)
              .lineHeight(fs(17))
              .layoutWeight(1)
            if (this.lastQ.length > 0) {
              Text('重试')
                .fontSize(fs(11))
                .fontColor(CLAY)
                .fontWeight(FontWeight.Medium)
                .padding({ left: 8, right: 4, top: 2, bottom: 2 })
                .onClick((): void => {
                  this.retry();
                })
            }
          }
          .padding(10)
          .width('100%')
          .backgroundColor('rgba(166,85,61,0.08)')
          .borderRadius(8)
          .alignItems(VerticalAlign.Center)
        }
      }
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .padding({ left: 14, right: 14, bottom: 8 })
  }

  @Builder
  inputBar() {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: '问遗址、器物或路线…', text: this.input })
          .layoutWeight(1)
          .height(42)
          .fontSize(fs(13))
          .backgroundColor('#FBF6EC')
          .borderRadius(21)
          .border({ width: 1, color: LINE })
          .enterKeyType(EnterKeyType.Send)
          .onChange((v: string): void => {
            this.input = v;
          })
          .onSubmit((): void => {
            this.send();
          })
        Text(this.busy ? '…' : '问')
          .fontSize(fs(13))
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(42)
          .height(42)
          .borderRadius(21)
          .backgroundColor(this.busy ? SUB : CLAY)
          .onClick((): void => {
            if (!this.busy) {
              this.send();
            }
          })
      }
      .width('100%')
      Text('回答由 Dify 上的模型生成，请以站内档案为准。')
        .fontSize(fs(9))
        .fontColor(SUB)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 10 })
    .backgroundColor($r('app.color.card_bg'))
    .border({ width: { top: 1 }, color: $r('app.color.line') })
  }

  build() {
    Column() {
      this.head()
      if (this.cfgOpen) {
        this.cfgCard()
      } else {
        this.chatBody()
        this.inputBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
