import { router } from '@kit.ArkUI';
import { StudioStore } from '../service/StudioStore';
import { fs, ERAS, INK, SUB, LOESS, CLAY, RIVER, PAPER, paletteOf } from '../common/Theme';

@Entry
@Component
struct GuidePage {
  // 字号档位变了要整页重画：不持有这行，切档后这一页还是老字号
  @StorageLink('textScale') ts: number = 1;
  @State idx: number = 0;
  private ctrl: SwiperController = new SwiperController();

  finish(): void {
    let s = StudioStore.get();
    s.markGuideSeen();
    router.replaceUrl({ url: s.signedIn() ? 'pages/Index' : 'pages/LoginPage' });
  }

  eraKey(e: string): string {
    if (e === '龙山') {
      return 'longshan';
    }
    if (e === '夏商') {
      return 'xiashang';
    }
    if (e === '周') {
      return 'zhou';
    }
    if (e === '汉唐') {
      return 'hantang';
    }
    if (e === '宋') {
      return 'song';
    }
    return 'yangshao';
  }

  @Builder
  eraStrip() {
    Row({ space: 5 }) {
      ForEach(ERAS, (e: string): void => {
        Column({ space: 5 }) {
          Column()
            .width(26)
            .height(58)
            .borderRadius({ topLeft: 13, topRight: 13, bottomLeft: 4, bottomRight: 4 })
            .backgroundColor(paletteOf(this.eraKey(e)).deep)
          Text(e).fontSize(fs(this.ts, 10)).fontColor(SUB)
        }
      }, (e: string): string => e)
    }
    .padding({ left: 18, right: 18, top: 22, bottom: 22 })
    .backgroundColor(PAPER)
    .borderRadius(16)
  }

  @Builder
  noteMock() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        Circle().width(8).height(8).fill(CLAY)
        Text('龙门石窟 · 读到第 4 节').fontSize(fs(this.ts, 11)).fontColor(SUB)
      }
      Column({ space: 6 }) {
        Column().width(200).height(8).borderRadius(4).backgroundColor('#E5DAC6')
        Column().width(164).height(8).borderRadius(4).backgroundColor('#E5DAC6')
        Column().width(182).height(8).borderRadius(4).backgroundColor('#EFE4CE')
      }
      .alignItems(HorizontalAlign.Start)
      Text('看过的地方会自动排进来').fontSize(fs(this.ts, 10)).fontColor(SUB)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .width(248)
    .backgroundColor(PAPER)
    .borderRadius(16)
  }

  @Builder
  deviceMock() {
    Row({ space: 16 }) {
      Column() {
        Column().width(52).height(84).borderRadius(10).backgroundColor(INK)
        Text('手机').fontSize(fs(this.ts, 10)).fontColor(SUB).margin({ top: 6 })
      }
      Column({ space: 4 }) {
        Text('⇄').fontSize(fs(this.ts, 20)).fontColor(LOESS)
        Text('时间戳新者胜').fontSize(fs(this.ts, 9)).fontColor(SUB)
      }
      Column() {
        Column().width(78).height(56).borderRadius(8).backgroundColor(RIVER)
        Text('平板').fontSize(fs(this.ts, 10)).fontColor(SUB).margin({ top: 6 })
      }
    }
    .padding({ left: 22, right: 22, top: 24, bottom: 20 })
    .backgroundColor(PAPER)
    .borderRadius(16)
  }

  @Builder
  slide(kind: number, title: string, lead: string) {
    Column({ space: 24 }) {
      Column() {
        if (kind === 0) {
          this.eraStrip()
        } else if (kind === 1) {
          this.noteMock()
        } else {
          this.deviceMock()
        }
      }
      .height(210)
      .justifyContent(FlexAlign.Center)

      Column({ space: 10 }) {
        Text(title).fontSize(fs(this.ts, 23)).fontColor(INK).fontWeight(FontWeight.Bold)
        Text(lead).fontSize(fs(this.ts, 13)).fontColor(SUB).lineHeight(fs(this.ts, 22)).textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 30, right: 30, bottom: 60 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Swiper(this.ctrl) {
        this.slide(0, '一条河，六个年代',
          '从仰韶彩陶到宋代城砖，20 处黄河沿线遗址按年代、城市、类型三条线索归置，想找哪一段都有路。')
        this.slide(1, '读到哪儿，记到哪儿',
          '阅读进度、收藏、标签、笔记都存在本机，离线也能翻；写下的笔记还能几台设备一起整理。')
        this.slide(2, '两台设备，一份记忆',
          '收藏与笔记走分布式键值存储，冲突时保留较新一版，旧笔记留档可寻，不会悄悄丢。')
      }
      .width('100%')
      .height('100%')
      .indicator(false)
      .loop(false)
      .onChange((i: number): void => {
        this.idx = i;
      })

      Row() {
        Text('跳过').fontSize(fs(this.ts, 14)).fontColor(SUB)
          .onClick((): void => {
            this.finish();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: 22, top: 22 })
      .position({ x: 0, y: 16 })

      Column({ space: 16 }) {
        Row({ space: 7 }) {
          ForEach([0, 1, 2], (i: number): void => {
            Column()
              .width(this.idx === i ? 20 : 7)
              .height(7)
              .borderRadius(4)
              .backgroundColor(this.idx === i ? LOESS : '#D9CDB6')
          }, (i: number): string => `${i}`)
        }

        Button(this.idx === 2 ? '开始使用' : '下一步')
          .fontSize(fs(this.ts, 15))
          .fontColor('#FFFFFF')
          .backgroundColor(CLAY)
          .width(190)
          .height(44)
          .borderRadius(22)
          .onClick((): void => {
            if (this.idx === 2) {
              this.finish();
            } else {
              this.ctrl.showNext();
            }
          })
      }
      .padding({ bottom: 52 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
