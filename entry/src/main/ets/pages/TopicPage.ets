import { router } from '@kit.ArkUI';
import { SiteRepo } from '../service/SiteRepo';
import { MemoryStore } from '../service/MemoryStore';
import { SiteInfo, TopicRec, FavRec } from '../model/Models';
import { ERAS, INK, SUB, LOESS, CLAY } from '../common/Theme';
import { goDetail } from '../common/Nav';
import { SiteCard } from '../view/SiteCard';

interface Pt {
  x: number;
  y: number;
  id: string;
}

@Entry
@Component
struct TopicPage {
  @StorageLink('dataRev') @Watch('redraw') rev: number = 0;
  @State sel: string = '';
  @State newName: string = '';
  @State netMode: boolean = true;
  @State editMembers: boolean = false;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private pts: Pt[] = [];

  redraw(): void {
    if (this.netMode) {
      this.draw();
    }
  }

  members(): SiteInfo[] {
    let t = MemoryStore.get().topicOf(this.sel);
    if (t === undefined) {
      return [];
    }
    let out: SiteInfo[] = [];
    for (let id of t.siteIds) {
      let s = SiteRepo.get().byId(id);
      if (s !== undefined) {
        out.push(s);
      }
    }
    return out;
  }

  sharedTag(a: SiteInfo, b: SiteInfo): boolean {
    let fa = MemoryStore.get().favOf(a.id);
    let fb = MemoryStore.get().favOf(b.id);
    if (fa === undefined || fb === undefined) {
      return false;
    }
    for (let t of fa.tagIds) {
      if (fb.tagIds.indexOf(t) >= 0) {
        return true;
      }
    }
    return false;
  }

  draw(): void {
    let c = this.ctx;
    let w = c.width;
    let h = c.height;
    c.clearRect(0, 0, w, h);
    this.pts = [];
    let ms = this.members();
    if (ms.length === 0) {
      return;
    }
    let cx = w / 2;
    let cy = h / 2;
    let r = Math.min(w, h) / 2 - 56;
    ms.sort((a: SiteInfo, b: SiteInfo): number =>
      ERAS.indexOf(a.eras[0]) - ERAS.indexOf(b.eras[0]));
    for (let i = 0; i < ms.length; i++) {
      let ang = ms.length === 1 ? -Math.PI / 2 : (Math.PI * 2 * i) / ms.length - Math.PI / 2;
      let x = ms.length === 1 ? cx : cx + r * Math.cos(ang);
      let y = ms.length === 1 ? cy : cy + r * Math.sin(ang);
      this.pts.push({ x: x, y: y, id: ms[i].id });
    }
    for (let i = 0; i < ms.length; i++) {
      for (let j = i + 1; j < ms.length; j++) {
        let color = '';
        let dash = false;
        if (SiteRepo.queryShared(ms[i].eras, ms[j].eras)) {
          color = LOESS;
        } else if (ms[i].city === ms[j].city) {
          color = CLAY;
        } else if (this.sharedTag(ms[i], ms[j])) {
          color = SUB;
          dash = true;
        }
        if (color.length > 0) {
          c.strokeStyle = color;
          c.lineWidth = 1.5;
          c.setLineDash(dash ? [5, 5] : []);
          c.beginPath();
          c.moveTo(this.pts[i].x, this.pts[i].y);
          c.lineTo(this.pts[j].x, this.pts[j].y);
          c.stroke();
          c.setLineDash([]);
        }
      }
    }
    for (let i = 0; i < ms.length; i++) {
      let p = this.pts[i];
      c.beginPath();
      c.arc(p.x, p.y, 24, 0, Math.PI * 2);
      c.fillStyle = '#FFFFFF';
      c.fill();
      c.strokeStyle = LOESS;
      c.lineWidth = 2;
      c.stroke();
      c.fillStyle = '#2B2622';
      c.font = '11px sans-serif';
      c.textAlign = 'center';
      c.textBaseline = 'middle';
      let short = ms[i].name.replace('遗址', '').replace('古墓群', '墓群');
      c.fillText(short.substring(0, 4), p.x, p.y);
      c.fillStyle = SUB;
      c.font = '9px sans-serif';
      c.fillText(ms[i].eras.join('/'), p.x, p.y + 34);
    }
  }

  onTapCanvas(x: number, y: number): void {
    for (let p of this.pts) {
      let dx = p.x - x;
      let dy = p.y - y;
      if (dx * dx + dy * dy < 28 * 28) {
        goDetail(p.id);
        return;
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 12 }) {
      Row({ space: 10 }) {
        Text('‹ 返回').fontSize(15).fontColor(CLAY)
          .onClick((): void => {
            if (this.sel.length > 0) {
              this.sel = '';
            } else {
              router.back();
            }
          })
        Text(this.sel.length === 0 ? '主题知识库' :
          (MemoryStore.get().topicOf(this.sel)?.name ?? '主题'))
          .fontSize(18).fontColor(INK).fontWeight(FontWeight.Bold).layoutWeight(1)
        if (this.sel.length > 0) {
          Text(this.netMode ? '看列表' : '看网络')
            .fontSize(13).fontColor(CLAY)
            .onClick((): void => {
              this.netMode = !this.netMode;
              if (this.netMode) {
                setTimeout((): void => {
                  this.draw();
                }, 50);
              }
            })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10 })

      if (this.sel.length === 0) {
        Row({ space: 8 }) {
          TextInput({ text: this.newName, placeholder: '比如：夏商文明探访' })
            .height(38).fontSize(13).layoutWeight(1)
            .onChange((v: string): void => {
              this.newName = v;
            })
          Button('新建')
            .height(38)
            .backgroundColor(LOESS)
            .onClick(async (): Promise<void> => {
              await MemoryStore.get().addTopic(this.newName);
              this.newName = '';
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14 })

        List({ space: 8 }) {
          ForEach(MemoryStore.get().topicsActive(), (t: TopicRec): void => {
            ListItem() {
              Row() {
                Column({ space: 3 }) {
                  Text(t.name).fontSize(15).fontColor(INK).fontWeight(FontWeight.Medium)
                  Text(`${t.siteIds.length} 个节点`).fontSize(11).fontColor(SUB)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('删除').fontSize(12).fontColor(SUB)
                  .onClick(async (): Promise<void> => {
                    await MemoryStore.get().deleteTopic(t.id);
                  })
                Text('  打开 ›').fontSize(13).fontColor(CLAY)
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(10)
              .onClick((): void => {
                this.sel = t.id;
                setTimeout((): void => {
                  this.draw();
                }, 80);
              })
            }
          }, (t: TopicRec): string => t.id + '_' + t.siteIds.length)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ left: 14, right: 14 })

        if (MemoryStore.get().topicsActive().length === 0) {
          Column({ space: 6 }) {
            Text('还没有主题').fontSize(15).fontColor(INK)
            Text('把收藏的遗址归进一个主题，就能看到它们之间的线').fontSize(12).fontColor(SUB)
          }
          .margin({ top: 40 })
        }
      } else if (this.netMode) {
        Canvas(this.ctx)
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
          .margin({ left: 14, right: 14 })
          .onReady((): void => {
            this.draw();
          })
          .onTouch((e: TouchEvent): void => {
            if (e.type === TouchType.Up && e.touches.length > 0) {
              this.onTapCanvas(e.touches[0].x, e.touches[0].y);
            }
          })
        Row({ space: 14 }) {
          this.legend(LOESS, '同年代', false)
          this.legend(CLAY, '同城市', false)
          this.legend(SUB, '同标签', true)
          Blank()
          Text('点节点看详情').fontSize(10).fontColor(SUB)
        }
        .width('100%')
        .padding({ left: 18, right: 14, bottom: 10 })
        Row({ space: 10 }) {
          Button('编辑成员')
            .fontSize(13).backgroundColor($r('app.color.line')).fontColor(INK)
            .onClick((): void => {
              this.editMembers = true;
            })
          Text(this.members().length < 2 ? '节点太少，先收几处遗址进主题' :
            `${this.members().length} 个节点，连线都是可解释的关系`).fontSize(11).fontColor(SUB)
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 12 })
      } else {
        List({ space: 8 }) {
          ForEach(this.members(), (s: SiteInfo): void => {
            ListItem() {
              SiteCard({ site: s })
            }
          }, (s: SiteInfo): string => s.id)
          ListItem() {
            Button('编辑成员')
              .fontSize(13).backgroundColor($r('app.color.line')).fontColor(INK)
              .onClick((): void => {
                this.editMembers = true;
              })
          }
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

      if (this.editMembers) {
        Column()
          .width('100%').height('100%')
          .backgroundColor('#66000000')
          .onClick((): void => {
            this.editMembers = false;
          })
        Column({ space: 8 }) {
          Text('勾选要放进主题的遗址').fontSize(16).fontColor(INK).fontWeight(FontWeight.Medium)
          List() {
            ForEach(SiteRepo.get().sites, (s: SiteInfo): void => {
              ListItem() {
                Row() {
                  Text(s.name).fontSize(14).fontColor(INK).layoutWeight(1)
                  Text(s.city).fontSize(11).fontColor(SUB)
                  Checkbox()
                    .select(MemoryStore.get().topicOf(this.sel)?.siteIds.includes(s.id) ?? false)
                    .selectedColor(CLAY)
                    .onChange((on: boolean): void => {
                      let t = MemoryStore.get().topicOf(this.sel);
                      if (t !== undefined && (t.siteIds.includes(s.id) !== on)) {
                        MemoryStore.get().toggleTopicSite(t.id, s.id);
                      }
                    })
                }
                .width('100%')
                .padding({ top: 6, bottom: 6 })
              }
            }, (s: SiteInfo): string => s.id)
          }
          .height(300)
          .scrollBar(BarState.Auto)
          Button('完成')
            .backgroundColor(LOESS)
            .onClick((): void => {
              this.editMembers = false;
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius({ topLeft: 16, topRight: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  legend(color: string, label: string, dash: boolean) {
    Row({ space: 4 }) {
      Line().width(18).height(2).startPoint([0, 1]).endPoint([18, 1])
        .stroke(color).strokeDashArray(dash ? [4, 4] : [])
      Text(label).fontSize(11).fontColor(SUB)
    }
  }
}
