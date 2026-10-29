import { router, promptAction } from '@kit.ArkUI';
import { SiteInfo } from '../model/Models';
import { SiteRepo } from '../service/SiteRepo';
import { StudioStore } from '../service/StudioStore';
import { RiverRibbon, siteDot } from '../common/River';
import { ERAS, INK, SUB, LOESS, CLAY, agoText, coverRes, fs } from '../common/Theme';
import { goDetail } from '../common/Nav';

// 河道打卡页：把首页那条动态河道搬到这里，让它从"装饰"变成"可点的地图"。
// 点一个圈选中一处遗址，盖章写进 StudioStore.siteCheckins（只存本机，不进分布式队列）。
const BAND_H: number = 262;
const HIT_R: number = 26;

@Entry
@Component
struct CheckinPage {
  @StorageLink('studioRev') @Watch('reload') studioRev: number = 0;
  @State bandW: number = 0;
  @State sites: SiteInfo[] = [];
  @State doneIds: string[] = [];
  @State checkedList: SiteInfo[] = [];
  @State sel: SiteInfo | undefined = undefined;

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.sites = SiteRepo.get().sites;
    this.doneIds = StudioStore.get().checkedSiteIds();
    // 章的列表也存进状态：@Builder 里直接调方法拿不到响应式，盖完章列表会停在旧数
    let list: SiteInfo[] = [];
    for (let c of StudioStore.get().siteCheckins) {
      let s = SiteRepo.get().byId(c.siteId);
      if (s !== undefined) {
        list.push(s);
      }
    }
    this.checkedList = list;
  }

  isChecked(id: string): boolean {
    return this.doneIds.indexOf(id) >= 0;
  }

  // @Builder 里不声明局部变量，标签在这儿算好
  checkedLabel(): string {
    let s = this.sel;
    if (s === undefined) {
      return '已打卡';
    }
    let r = StudioStore.get().checkinOf(s.id);
    return r === undefined ? '已打卡' : '已打卡 · ' + agoText(r.at);
  }

  // Area 的宽高可能是数字也可能是带单位的字符串，两种都吃
  toNum(v: Length): number {
    let n = parseFloat(`${v}`);
    return Number.isNaN(n) ? 0 : n;
  }

  // 命中判定：在带子里找离触点最近的圈，超过 HIT_R 就算点了空白
  pick(x: number, y: number): void {
    let w = this.bandW;
    if (w <= 0) {
      return;
    }
    let best: SiteInfo | undefined = undefined;
    let bestD = HIT_R * HIT_R;
    for (let s of this.sites) {
      let p = siteDot(s, w, BAND_H);
      let dx = p.x - x;
      let dy = p.y - y;
      let d = dx * dx + dy * dy;
      if (d <= bestD) {
        bestD = d;
        best = s;
      }
    }
    if (best === undefined) {
      promptAction.showToast({ message: '没点到圈，试试河道上那些小圆' });
      return;
    }
    this.sel = best;
  }

  doCheckin(): void {
    let s = this.sel;
    if (s === undefined) {
      return;
    }
    if (StudioStore.get().checkinSite(s.id)) {
      promptAction.showToast({ message: '已盖章：' + s.name });
    }
  }

  undoCheckin(): void {
    let s = this.sel;
    if (s === undefined) {
      return;
    }
    StudioStore.get().undoCheckinSite(s.id);
    promptAction.showToast({ message: '已撤销这一步' });
  }

  @Builder
  legend(filled: boolean, text: string) {
    Row({ space: 5 }) {
      Circle()
        .width(11)
        .height(11)
        .fill(filled ? CLAY : Color.Transparent)
        .stroke(filled ? CLAY : SUB)
        .strokeWidth(1.2)
      Text(text).fontSize(fs(11)).fontColor(SUB)
    }
  }

  @Builder
  selCard() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Image(coverRes(this.sel!.cover))
          .width(56).height(56).borderRadius(8).objectFit(ImageFit.Cover)
        Column({ space: 3 }) {
          Text(this.sel!.name)
            .fontSize(fs(16)).fontColor(INK).fontWeight(FontWeight.Bold)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.sel!.city} · ${this.sel!.eras.join('/')} · ${this.sel!.types.join('/')}`)
            .fontSize(fs(11)).fontColor(SUB)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('看档案 ›')
          .fontSize(fs(12)).fontColor(CLAY)
          .onClick((): void => {
            goDetail(this.sel!.id);
          })
      }
      .width('100%')

      Row({ space: 10 }) {
        if (this.isChecked(this.sel!.id)) {
          Text(this.checkedLabel())
            .fontSize(fs(12)).fontColor(LOESS).layoutWeight(1)
          Text('撤销这一步')
            .fontSize(fs(12)).fontColor(SUB)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .border({ width: 1, color: $r('app.color.line') })
            .borderRadius(14)
            .onClick((): void => {
              this.undoCheckin();
            })
        } else {
          Text('这一步还没走过').fontSize(fs(12)).fontColor(SUB).layoutWeight(1)
          Text('盖章打卡')
            .fontSize(fs(13)).fontColor('#FFFFFF')
            .padding({ left: 16, right: 16, top: 7, bottom: 7 })
            .backgroundColor(CLAY)
            .borderRadius(15)
            .onClick((): void => {
              this.doCheckin();
            })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
  }

  @Builder
  emptyCard() {
    Column({ space: 6 }) {
      Text('点河道上的一个小圆').fontSize(fs(13)).fontColor(INK)
      Text('选中一处遗址，就能在这条河上盖一个章').fontSize(fs(11)).fontColor(SUB)
    }
    .width('100%')
    .padding({ top: 22, bottom: 22 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Text('‹ 返回').fontSize(fs(15)).fontColor(CLAY)
          .onClick((): void => {
            router.back();
          })
        Text('河道打卡').fontSize(fs(18)).fontColor(INK).fontWeight(FontWeight.Bold).layoutWeight(1)
        Text(`${this.doneIds.length} / ${this.sites.length}`).fontSize(fs(14)).fontColor(LOESS)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10 })

      Scroll() {
        Column({ space: 12 }) {
          // 河道带：整块可点，坐标按 siteDot 命中
          Column({ space: 6 }) {
            Row({ space: 14 }) {
              this.legend(false, '没去过')
              this.legend(true, '盖过章')
              Blank()
              Text('纵向偏移＝城市自西向东').fontSize(fs(10)).fontColor(SUB)
            }
            .width('100%')

            // 年代轴：六个等宽格子的中心正好对上 siteU 的分段中点
            Row() {
              ForEach(ERAS, (era: string): void => {
                Text(era)
                  .fontSize(fs(9))
                  .fontColor(SUB)
                  .textAlign(TextAlign.Center)
                  .layoutWeight(1)
              }, (era: string): string => era)
            }
            .width('100%')

            Stack() {
              RiverRibbon({ bandHeight: BAND_H, showDots: true,
                activeId: this.sel === undefined ? '' : this.sel!.id, note: '' })
            }
            .width('100%')
            .height(BAND_H)
            .onAreaChange((oldV: Area, newV: Area): void => {
              this.bandW = this.toNum(newV.width);
            })
            .onClick((e: ClickEvent): void => {
              this.pick(e.x, e.y);
            })
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)

          if (this.sel === undefined) {
            this.emptyCard()
          } else {
            this.selCard()
          }

          // 进度：一眼看出这条河还差几段
          Column({ space: 6 }) {
            Row() {
              Text('这条河走了').fontSize(fs(12)).fontColor(SUB)
              Blank()
              Text(`${Math.round(this.sites.length === 0 ? 0 :
                this.doneIds.length * 100 / this.sites.length)}%`)
                .fontSize(fs(12)).fontColor(CLAY).fontWeight(FontWeight.Medium)
            }
            .width('100%')
            Stack({ alignContent: Alignment.Start }) {
              Column().width('100%').height(6).borderRadius(3)
                .backgroundColor($r('app.color.line'))
              Column().width(`${this.sites.length === 0 ? 0 :
                Math.round(this.doneIds.length * 100 / this.sites.length)}%`)
                .height(6).borderRadius(3)
                .backgroundColor(LOESS)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)

          Column({ space: 8 }) {
            Row() {
              Text('盖过的章').fontSize(fs(16)).fontColor(INK).fontWeight(FontWeight.Medium)
              Blank()
              Text(`${this.checkedList.length} 处`).fontSize(fs(11)).fontColor(SUB)
            }
            .width('100%')

            if (this.checkedList.length === 0) {
              Text('还没有章。河道上随便点一个圈，先盖一个试试')
                .fontSize(fs(12)).fontColor(SUB)
                .width('100%').padding({ top: 8, bottom: 8 })
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.checkedList, (s: SiteInfo): void => {
                  Row({ space: 5 }) {
                    Text(s.name.substring(0, 1))
                      .fontSize(fs(10)).fontColor('#F6E2CE')
                      .width(16).height(16).borderRadius(4)
                      .textAlign(TextAlign.Center)
                      .backgroundColor('rgba(166,85,61,0.86)')
                    Text(s.name).fontSize(fs(12)).fontColor(INK)
                  }
                  .padding({ left: 8, right: 10, top: 5, bottom: 5 })
                  .margin({ right: 8, bottom: 8 })
                  .backgroundColor($r('app.color.card_bg'))
                  .border({ width: 1, color: '#D9C9A8' })
                  .borderRadius(14)
                  .onClick((): void => {
                    goDetail(s.id);
                  })
                }, (s: SiteInfo): string => s.id)
              }
              .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Text('点位是示意排布，不是真实经纬；打卡只存本机，不进分布式队列；卡片配图为 AI 生成示意图。')
            .fontSize(fs(10)).fontColor(SUB)
            .width('100%').textAlign(TextAlign.Center)
            .margin({ top: 2, bottom: 18 })
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
    .backgroundColor($r('app.color.page_bg'))
  }
}
