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
  @StorageLink('dataRev') @Watch('syncCount') rev: number = 0;
  // 角标读的是普通单例，ArkUI 观察不到；dataRev 一变就把数量抄进 @State
  @State favN: number = 0;
  @State noteN: number = 0;

  aboutToAppear(): void {
    let p = params();
    if (p !== undefined && p.tab !== undefined) {
      this.tab = p.tab;
    }
    this.syncCount();
  }

  syncCount(): void {
    this.favN = MemoryStore.get().favsActive().length;
    this.noteN = MemoryStore.get().notesActive().length;
  }

  badgeOf(idx: number): string {
    // 角标从 @State 里取，不能在 @Builder 的普通参数里传值：
    // 传值是快照，favN 变了这一段不会跟着刷
    if (idx === 1) {
      return `${this.favN}`;
    }
    if (idx === 2) {
      return `${this.noteN}`;
    }
    return '';
  }

  @Builder
  seg(idx: number, title: string) {
    Column({ space: 3 }) {
      Row({ space: 4 }) {
        Text(title).fontSize(15)
          .fontColor(this.tab === idx ? INK : SUB)
          .fontWeight(this.tab === idx ? FontWeight.Bold : FontWeight.Normal)
        if (this.badgeOf(idx).length > 0) {
          Text(this.badgeOf(idx)).fontSize(10).fontColor(CLAY)
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
          this.seg(0, '探索')
          this.seg(1, '收藏')
          this.seg(2, '笔记')
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
