import { router } from '@kit.ArkUI';
import { ExploreView } from '../view/ExploreView';
import { FavoriteView } from '../view/FavoriteView';
import { NoteView } from '../view/NoteView';
import { MemoryStore } from '../service/MemoryStore';
import { INK, SUB, CLAY } from '../common/Theme';
import { params } from '../common/Nav';

@Entry
@Component
struct ArchivePage {
  @State tab: number = 0;
  @StorageLink('dataRev') rev: number = 0;

  aboutToAppear(): void {
    let p = params();
    if (p !== undefined && p.tab !== undefined) {
      this.tab = p.tab;
    }
  }

  @Builder
  seg(idx: number, title: string, badge: string) {
    Column({ space: 3 }) {
      Row({ space: 4 }) {
        Text(title).fontSize(15)
          .fontColor(this.tab === idx ? INK : SUB)
          .fontWeight(this.tab === idx ? FontWeight.Bold : FontWeight.Normal)
        if (badge.length > 0) {
          Text(badge).fontSize(10).fontColor(CLAY)
        }
      }
      Divider().width(20).strokeWidth(2)
        .color(this.tab === idx ? CLAY : Color.Transparent)
    }
    .padding({ top: 6, bottom: 2 })
    .onClick((): void => {
      this.tab = idx;
    })
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Text('‹ 返回').fontSize(15).fontColor(CLAY)
          .onClick((): void => {
            router.back();
          })
        Row({ space: 18 }) {
          this.seg(0, '探索', '')
          this.seg(1, '收藏', `${MemoryStore.get().favsActive().length}`)
          this.seg(2, '笔记', `${MemoryStore.get().notesActive().length}`)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        Text('同步').fontSize(14).fontColor(SUB)
          .onClick((): void => {
            router.pushUrl({ url: 'pages/SyncPage' });
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 4 })

      Column() {
        if (this.tab === 0) {
          ExploreView()
        } else if (this.tab === 1) {
          FavoriteView()
        } else {
          NoteView()
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
