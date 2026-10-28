import { router } from '@kit.ArkUI';
import { SiteRepo } from '../service/SiteRepo';
import { MemoryStore } from '../service/MemoryStore';
import { SiteInfo, Suggestion, NoteRec, TagRec, Poem } from '../model/Models';
import { coverRes, INK, SUB, LOESS, CLAY } from '../common/Theme';
import { params, goNote } from '../common/Nav';
import { SiteCard } from '../view/SiteCard';

interface SecCard {
  t: string;
  body: string;
}

@Entry
@Component
struct DetailPage {
  @StorageLink('dataRev') rev: number = 0;
  @State site: SiteInfo | undefined = undefined;
  @State sheetOpen: boolean = false;
  @State sheetPicked: string[] = [];

  aboutToAppear(): void {
    let p = params();
    if (p.id !== undefined) {
      this.site = SiteRepo.get().byId(p.id);
      if (this.site !== undefined) {
        MemoryStore.get().touchView(this.site.id);
      }
    }
  }

  secs(): SecCard[] {
    let s = this.site;
    if (s === undefined) {
      return [];
    }
    let out: SecCard[] = [];
    out.push({ t: '概况', body: s.intro });
    out.push({ t: '考古发现', body: s.archaeology });
    out.push({ t: '历史事件', body: s.history });
    let poemText = s.poems.map((x: Poem): string => `${x.line}　——${x.author}${x.source}`).join('\n');
    out.push({ t: '相关诗词', body: poemText.length > 0 ? poemText : '暂未收录可靠篇目，欢迎补充线索。' });
    let tr = s.travel;
    out.push({ t: '文旅信息',
      body: `门票：${tr.ticket}\n开放：${tr.openTime}\n提示：${tr.tips}\n（更新于 ${tr.updated}，出行前请以官方公告为准）` });
    out.push({ t: '来源', body: '文字与考据线索来自：' + s.source });
    return out;
  }

  readLine(): string {
    let s = this.site;
    if (s === undefined) {
      return '';
    }
    let pr = MemoryStore.get().progressOf(s.id);
    if (pr === undefined) {
      return '刚开始读';
    }
    return `读到第 ${pr.maxSection + 1} 节 / 共 ${this.secs().length} 节`;
  }

  @Builder
  sectionCard(sec: SecCard, idx: number) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(`${idx + 1}`).fontSize(12).fontColor(Color.White)
          .width(18).height(18).borderRadius(9)
          .backgroundColor(idx < 3 ? CLAY : LOESS)
          .textAlign(TextAlign.Center)
        Text(sec.t).fontSize(16).fontColor(INK).fontWeight(FontWeight.Medium)
      }
      Text(sec.body)
        .fontSize(14)
        .fontColor(INK)
        .lineHeight(23)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.site !== undefined) {
        List({ space: 10 }) {
          ListItem() {
            Column() {
              Stack({ alignContent: Alignment.BottomStart }) {
                Image(coverRes(this.site.cover))
                  .width('100%').height(200).objectFit(ImageFit.Cover)
                Column({ space: 4 }) {
                  Text(this.site.name)
                    .fontSize(22).fontColor(Color.White).fontWeight(FontWeight.Bold)
                  Text(`${this.site.city} · ${this.site.eras.join('/')} · ${this.site.types.join('/')}`)
                    .fontSize(12).fontColor('#E8E0D2')
                }
                .alignItems(HorizontalAlign.Start)
                .padding(14)
              }
              .width('100%').height(200).clip(true)
            }
          }

          ListItem() {
            Row({ space: 10 }) {
              Button(MemoryStore.get().isFav(this.site.id) ? '已收藏' : '收藏')
                .fontSize(13)
                .backgroundColor(MemoryStore.get().isFav(this.site.id) ? LOESS : CLAY)
                .onClick(async (): Promise<void> => {
                  if (MemoryStore.get().isFav(this.site!.id)) {
                    await MemoryStore.get().removeFav(this.site!.id);
                  } else {
                    await MemoryStore.get().addFav(this.site!.id);
                  }
                })
              Button('归类')
                .fontSize(13)
                .backgroundColor($r('app.color.line'))
                .fontColor(INK)
                .onClick((): void => {
                  let fav = MemoryStore.get().favOf(this.site!.id);
                  this.sheetPicked = fav === undefined ? [] : fav.tagIds.slice();
                  this.sheetOpen = true;
                })
              Button('写一笔')
                .fontSize(13)
                .backgroundColor($r('app.color.line'))
                .fontColor(INK)
                .onClick((): void => {
                  goNote(this.site!.id, '');
                })
              Blank()
              Text(MemoryStore.get().progressOf(this.site.id) !== undefined &&
                MemoryStore.get().progressOf(this.site.id)!.read ? '已读' : '未读')
                .fontSize(12).fontColor(SUB)
                .onClick(async (): Promise<void> => {
                  let pr = MemoryStore.get().progressOf(this.site!.id);
                  let cur = pr !== undefined && pr.read;
                  await MemoryStore.get().markRead(this.site!.id, !cur);
                })
            }
            .width('100%')
            .padding({ left: 2, right: 2 })
          }

          ListItem() {
            Text(this.readLine()).fontSize(11).fontColor(SUB)
              .width('100%').padding({ left: 4 })
          }

          ForEach(this.secs(), (sec: SecCard, idx: number): void => {
            ListItem() {
              this.sectionCard(sec, idx)
            }
          }, (sec: SecCard): string => sec.t)

          ListItem() {
            Text(`这里的笔记（${MemoryStore.get().notesOfSite(this.site.id).length}）`)
              .fontSize(15).fontColor(INK).fontWeight(FontWeight.Medium)
              .width('100%').padding(4)
          }

          ForEach(MemoryStore.get().notesOfSite(this.site.id), (n: NoteRec): void => {
            ListItem() {
              Column({ space: 4 }) {
                Text(n.text).fontSize(13).fontColor(INK).maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text('点按编辑').fontSize(10).fontColor(SUB)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(10)
              .onClick((): void => {
                goNote('', n.id);
              })
            }
          }, (n: NoteRec): string => n.id)

          ListItem() {
            Text('顺着河往下看')
              .fontSize(15).fontColor(INK).fontWeight(FontWeight.Medium)
              .width('100%').padding(4)
          }

          ForEach(SiteRepo.get().related(this.site, 4), (sg: Suggestion): void => {
            ListItem() {
              SiteCard({ site: sg.site, note: sg.reason })
            }
          }, (sg: Suggestion): string => sg.site.id)

          ListItem() {
            Column().height(24)
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .padding({ left: 14, right: 14 })
        .onScrollIndex((first: number, last: number): void => {
          // 头部占两行，正文节号从 2 开始；末尾笔记/推荐行不计入
          let max = this.secs().length - 1;
          let secIdx = Math.min(Math.max(last - 3, 0), max);
          if (this.site !== undefined) {
            MemoryStore.get().bumpSection(this.site.id, secIdx);
          }
        })
      } else {
        Column() {
          Text('没找到这条资源').fontSize(15).fontColor(INK)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }

      Text('‹ 返回')
        .fontSize(14)
        .fontColor(Color.White)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .margin({ left: 10, top: 12 })
        .backgroundColor('#66000000')
        .borderRadius(14)
        .position({ x: 0, y: 0 })
        .onClick((): void => {
          router.back();
        })

      if (this.sheetOpen && this.site !== undefined) {
        Column()
          .width('100%').height('100%')
          .backgroundColor('#66000000')
          .onClick((): void => {
            this.sheetOpen = false;
          })
        Column({ space: 10 }) {
          Text('归类到标签').fontSize(16).fontColor(INK).fontWeight(FontWeight.Medium)
          ForEach(MemoryStore.get().tagsActive(), (t: TagRec): void => {
            Row() {
              Text(t.name).fontSize(14).fontColor(INK).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.sheetPicked.indexOf(t.id) >= 0 })
                .selectedColor(CLAY)
                .onChange((on: boolean): void => {
                  let i = this.sheetPicked.indexOf(t.id);
                  if (on && i < 0) {
                    this.sheetPicked.push(t.id);
                  } else if (!on && i >= 0) {
                    this.sheetPicked.splice(i, 1);
                  }
                })
            }.width('100%')
          }, (t: TagRec): string => t.id)
          Button('保存归类')
            .backgroundColor(LOESS)
            .fontColor(Color.White)
            .onClick(async (): Promise<void> => {
              await MemoryStore.get().setFavTags(this.site!.id, this.sheetPicked);
              this.sheetOpen = false;
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
    .backgroundColor($r('app.color.page_bg'))
  }
}
