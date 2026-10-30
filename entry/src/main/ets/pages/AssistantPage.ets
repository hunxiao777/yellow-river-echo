import { router } from '@kit.ArkUI';
import { ChatTurn, Citation } from '../model/AiModels';
import { AiStore } from '../service/AiStore';
import { AiService, StreamHandle } from '../service/AiService';
import { AiContext } from '../service/AiContext';
import { cleanAiText, cleanPartial } from '../common/Markdown';
import { INK, SUB, LOESS, CLAY, LINE, RIVER, fs } from '../common/Theme';
import { goDetail } from '../common/Nav';

const TIPS: string[] = [
  '仰韶彩陶有什么特点？',
  '二里头为什么被称为最早的中国？',
  '我收藏里哪几处值得先去？'
];

// 打字机的节拍：50ms 合并一次增量，既不会一格一格卡顿，也不至于整段跳出
const TYPE_MS: number = 50;

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
  @State live: string = '';
  @State liveOn: boolean = false;
  private scroller: Scroller = new Scroller();
  private handle: StreamHandle | null = null;
  private timer: number = -1;
  private rawTarget: string = '';
  private cleanTarget: string = '';
  private shown: number = 0;
  private streamDone: boolean = false;
  private streamErr: string = '';
  private streamCites: Citation[] = [];
  private askQ: string = '';
  private wasAborted: boolean = false;
  private closing: boolean = false;
  private lastFollow: number = 0;

  aboutToAppear(): void {
    this.reload();
    if (!AiStore.get().configured()) {
      this.cfgOpen = true;
    }
  }

  aboutToDisappear(): void {
    this.stopTimer();
    if (this.handle !== null) {
      this.handle.stop();
      this.handle = null;
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

  // 流式期间每 50ms 都会触发，滚动按 150ms 节流，避免和打字抢帧
  follow(): void {
    let now = Date.now();
    if (now - this.lastFollow < 150) {
      return;
    }
    this.lastFollow = now;
    this.scroller.scrollEdge(Edge.Bottom);
  }

  send(): void {
    let q = this.input.trim();
    if (q.length === 0 || this.busy) {
      return;
    }
    if (!AiStore.get().configured()) {
      this.cfgOpen = true;
      this.err = '先填好 Dify 地址和 App Key 再提问';
      return;
    }
    this.input = '';
    this.run(q, true);
  }

  run(q: string, pushUser: boolean): void {
    let store = AiStore.get();
    this.err = '';
    this.clearAsk = false;
    this.askQ = q;
    this.rawTarget = '';
    this.cleanTarget = '';
    this.shown = 0;
    this.live = '';
    this.streamDone = false;
    this.streamErr = '';
    this.streamCites = [];
    this.wasAborted = false;
    this.closing = false;
    if (pushUser) {
      store.pushTurn({
        role: 'user', text: q, at: Date.now(), citations: [], failed: false, isAborted: false
      });
    }
    this.turns = store.turns.slice();
    this.busy = true;
    this.liveOn = true;
    this.toBottom();
    this.startTimer();

    let ctx = AiContext.build(q);
    this.handle = AiService.get().start(q, ctx, {
      onChunk: (raw: string): void => {
        this.rawTarget = raw;
      },
      onDone: (citations: Citation[], aborted: boolean): void => {
        this.handle = null;
        this.streamDone = true;
        this.streamCites = citations;
        this.wasAborted = aborted;
        if (aborted) {
          this.fastForward();
        }
      },
      onError: (msg: string): void => {
        this.handle = null;
        this.streamDone = true;
        this.streamErr = msg;
      }
    });
  }

  startTimer(): void {
    this.stopTimer();
    this.timer = setInterval((): void => {
      this.pump();
    }, TYPE_MS);
  }

  stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  // 每次节拍都按最新原文重算可见文本：流没结束时半行保守清洗，结束后走正式清洗
  pump(): void {
    if (!this.liveOn || this.closing) {
      this.stopTimer();
      return;
    }
    this.cleanTarget = this.streamDone ? cleanAiText(this.rawTarget) : cleanPartial(this.rawTarget);
    if (this.shown < this.cleanTarget.length) {
      let remain = this.cleanTarget.length - this.shown;
      // 差距越大步进越大，避免模型吐得快时打字机永远追不上
      let step = Math.max(2, Math.ceil(remain / 6));
      this.shown = Math.min(this.cleanTarget.length, this.shown + step);
      this.live = this.cleanTarget.substring(0, this.shown);
      this.follow();
    }
    if (this.streamDone && this.shown >= this.cleanTarget.length) {
      this.finish();
    }
  }

  // 用户按停止：已收到的内容一次性补齐，立刻收尾，不留定时器也不留连接
  fastForward(): void {
    this.cleanTarget = cleanAiText(this.rawTarget);
    this.shown = this.cleanTarget.length;
    this.live = this.cleanTarget;
    this.finish();
  }

  finish(): void {
    if (this.closing) {
      return;
    }
    this.closing = true;
    this.stopTimer();
    this.busy = false;
    this.liveOn = false;
    let store = AiStore.get();
    let text = this.cleanTarget;
    if (text.length > 0) {
      store.pushTurn({
        role: 'ai', text: text, at: Date.now(), citations: this.streamCites,
        failed: false, isAborted: this.wasAborted
      });
      this.turns = store.turns.slice();
    }
    if (this.streamErr.length > 0) {
      this.err = text.length > 0 ? this.streamErr + '（回答已中断）' : this.streamErr;
      this.lastQ = this.askQ;
    } else if (text.length === 0) {
      this.err = '模型没有返回内容，稍后再试';
      this.lastQ = this.askQ;
    }
    this.live = '';
    this.rawTarget = '';
    this.toBottom();
  }

  stop(): void {
    if (this.handle !== null) {
      this.handle.stop();
      return;
    }
    this.streamDone = true;
    this.fastForward();
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
    if (this.busy) {
      return;
    }
    this.input = s;
    this.send();
  }

  retry(): void {
    let q = this.lastQ;
    if (q.length === 0 || this.busy) {
      return;
    }
    this.lastQ = '';
    this.run(q, false);
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
        if (t.isAborted === true) {
          Text('· 回答已中断')
            .fontSize(fs(10))
            .fontColor(SUB)
            .margin({ top: 3 })
        }
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
  liveBubble() {
    Column({ space: 2 }) {
      if (this.live.length > 0) {
        Text(this.live)
          .fontSize(fs(13))
          .fontColor(INK)
          .lineHeight(fs(21))
      }
      if (this.live.length === 0) {
        Text('河小导正在翻档案…')
          .fontSize(fs(11))
          .fontColor(SUB)
      } else if (!this.streamDone) {
        Text('▍')
          .fontSize(fs(12))
          .fontColor(CLAY)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius({ topLeft: 4, topRight: 14, bottomLeft: 14, bottomRight: 14 })
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
      if (this.liveOn) {
        ListItem() {
          this.liveBubble()
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
        if (this.busy) {
          Text('停')
            .fontSize(fs(13))
            .fontColor(CLAY)
            .textAlign(TextAlign.Center)
            .width(42)
            .height(42)
            .borderRadius(21)
            .border({ width: 1, color: CLAY })
            .backgroundColor('#FBF6EC')
            .onClick((): void => {
              this.stop();
            })
        } else {
          Text('问')
            .fontSize(fs(13))
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .width(42)
            .height(42)
            .borderRadius(21)
            .backgroundColor(CLAY)
            .onClick((): void => {
              this.send();
            })
        }
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
