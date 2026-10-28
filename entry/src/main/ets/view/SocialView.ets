import { promptAction } from '@kit.ArkUI';
import { ContentRepo } from '../service/ContentRepo';
import { StudioStore } from '../service/StudioStore';
import { SyncService } from '../service/SyncService';
import { SiteRepo } from '../service/SiteRepo';
import { Post, PostComment } from '../model/Models';
import { INK, SUB, CLAY, RIVER, agoText, likeText, paletteOf, eraPalette } from '../common/Theme';
import { openDrawer, goDetail, goSync } from '../common/Nav';

// 社区页：推荐流 + 本机提醒。动态与作者都是随包演示数据。
@Component
export struct SocialView {
  @StorageLink('studioRev') @Watch('syncMine') studioRev: number = 0;
  @StorageLink('dataRev') dataRev: number = 0;
  @StorageLink('syncRev') syncRev: number = 0;
  @State sub: number = 0;
  @State topic: string = '';
  @State openIds: string[] = [];
  @State cmtIds: string[] = [];
  @State myLikes: string[] = [];
  @State myFollows: string[] = [];

  aboutToAppear(): void {
    this.syncMine();
  }

  // 点赞和关注点了要当场变，绑到状态上才吃得到刷新
  syncMine(): void {
    let st = StudioStore.get();
    this.myLikes = st.likes.slice();
    this.myFollows = st.followed.slice();
  }

  flip(arr: string[], id: string): string[] {
    let out = arr.slice();
    let i = out.indexOf(id);
    if (i >= 0) {
      out.splice(i, 1);
    } else {
      out.push(id);
    }
    return out;
  }

  isOpen(id: string): boolean {
    return this.openIds.indexOf(id) >= 0;
  }

  showCmt(id: string): boolean {
    return this.cmtIds.indexOf(id) >= 0;
  }

  shown(): Post[] {
    return ContentRepo.get().postsOfTopic(this.topic);
  }

  avatarKey(siteId: string): string {
    let s = SiteRepo.get().byId(siteId);
    if (s === undefined) {
      return 'yangshao';
    }
    return eraPalette(s.eras.length > 0 ? s.eras[0] : '');
  }

  siteName(siteId: string): string {
    let s = SiteRepo.get().byId(siteId);
    return s === undefined ? '' : s.name;
  }

  rowKey(p: Post): string {
    return `${p.id}_${this.isOpen(p.id)}_${this.showCmt(p.id)}` +
      `_${this.myLikes.indexOf('p_' + p.id) >= 0}_${this.myFollows.indexOf(p.author) >= 0}`;
  }

  syncLine(): string {
    let s = SyncService.get();
    if (s.localOnly) {
      return '本机模式：数据只存这台设备';
    }
    return `同步：${s.hint}，待同步 ${s.pendingCount()} 条`;
  }

  @Builder
  subTab(title: string, idx: number) {
    Text(title)
      .fontSize(14)
      .fontColor(this.sub === idx ? INK : SUB)
      .fontWeight(this.sub === idx ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 6, right: 6, top: 4, bottom: 4 })
      .borderWidth({ bottom: this.sub === idx ? 2 : 0 })
      .borderColor(CLAY)
      .onClick((): void => {
        this.sub = idx;
      })
  }

  @Builder
  topicChip(title: string, val: string) {
    Text(title)
      .fontSize(12)
      .fontColor(this.topic === val ? Color.White : SUB)
      .padding({ left: 11, right: 11, top: 5, bottom: 5 })
      .borderRadius(13)
      .backgroundColor(this.topic === val ? CLAY : $r('app.color.card_bg'))
      .onClick((): void => {
        this.topic = val;
      })
  }

  @Builder
  commentRow(c: PostComment) {
    Column({ space: 2 }) {
      Row({ space: 6 }) {
        Text(c.author).fontSize(11).fontColor(INK)
        Text(agoText(c.at)).fontSize(10).fontColor(SUB)
      }
      Text(c.text).fontSize(12).fontColor(SUB).lineHeight(18)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor('#F7F2E8')
    .borderRadius(8)
  }

  @Builder
  postCard(p: Post) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Column() {
          Text(p.author.substring(0, 1))
            .fontSize(15)
            .fontColor(paletteOf(this.avatarKey(p.siteId)).ink)
            .fontWeight(FontWeight.Bold)
        }
        .width(38)
        .height(38)
        .borderRadius(19)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(paletteOf(this.avatarKey(p.siteId)).deep)

        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(p.author).fontSize(14).fontColor(INK).fontWeight(FontWeight.Medium)
            Text(p.role).fontSize(10).fontColor(SUB)
          }
          Row({ space: 6 }) {
            Text(agoText(p.at)).fontSize(11).fontColor(SUB)
            if (p.kind === '问答') {
              Text(p.kind)
                .fontSize(10).fontColor(CLAY)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .border({ width: 1, color: CLAY })
                .borderRadius(6)
            } else {
              Text(p.kind)
                .fontSize(10).fontColor(SUB)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .backgroundColor('#F0E8D8')
                .borderRadius(6)
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Column({ space: 4 }) {
        Text(p.text)
          .fontSize(13)
          .fontColor(INK)
          .lineHeight(21)
          .width('100%')
          .maxLines(this.isOpen(p.id) ? 20 : 3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (!this.isOpen(p.id) && p.text.length > 48) {
          Text('全文')
            .fontSize(12)
            .fontColor(CLAY)
            .onClick((): void => {
              this.openIds = this.flip(this.openIds, p.id);
              StudioStore.get().markPostRead(p.id);
            })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.siteName(p.siteId).length > 0) {
        Row({ space: 4 }) {
          Text('关联遗址').fontSize(10).fontColor(SUB)
          Text(this.siteName(p.siteId))
            .fontSize(11)
            .fontColor(RIVER)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .border({ width: 1, color: '#CFC4AE' })
            .borderRadius(9)
        }
        .onClick((): void => {
          goDetail(p.siteId);
        })
      }

      Row({ space: 16 }) {
        Text(this.myLikes.indexOf('p_' + p.id) >= 0 ?
          `♥ ${likeText(p.likes + 1)}` : `♡ ${likeText(p.likes)}`)
          .fontSize(12)
          .fontColor(this.myLikes.indexOf('p_' + p.id) >= 0 ? CLAY : SUB)
          .onClick((): void => {
            StudioStore.get().toggleLike('p_' + p.id);
          })
        Text(`评论 ${p.comments.length}`)
          .fontSize(12)
          .fontColor(this.showCmt(p.id) ? INK : SUB)
          .onClick((): void => {
            this.cmtIds = this.flip(this.cmtIds, p.id);
            StudioStore.get().markPostRead(p.id);
          })
        Blank()
        Text(this.myFollows.indexOf(p.author) >= 0 ? '已关注' : '+ 关注')
          .fontSize(12)
          .fontColor(this.myFollows.indexOf(p.author) >= 0 ? SUB : CLAY)
          .padding({ left: 10, right: 10, top: 3, bottom: 3 })
          .border({ width: 1, color: this.myFollows.indexOf(p.author) >= 0 ? '#D9CDB6' : CLAY })
          .borderRadius(11)
          .onClick((): void => {
            StudioStore.get().toggleFollow(p.author);
          })
      }
      .width('100%')

      if (this.showCmt(p.id)) {
        Column({ space: 6 }) {
          ForEach(p.comments, (c: PostComment): void => {
            this.commentRow(c)
          }, (c: PostComment, idx: number): string => `${p.id}_c${idx}`)
          if (p.comments.length === 0) {
            Text('还没有人回话').fontSize(11).fontColor(SUB)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .onClick((): void => {
      StudioStore.get().markPostRead(p.id);
    })
  }

  @Builder
  noteRow(title: string, desc: string, act: string, onTap: () => void) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(title).fontSize(14).fontColor(INK).fontWeight(FontWeight.Medium)
        Text(desc).fontSize(12).fontColor(SUB).lineHeight(18)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (act.length > 0) {
        Text(act)
          .fontSize(12)
          .fontColor(CLAY)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .border({ width: 1, color: '#D9CDB6' })
          .borderRadius(11)
          .onClick((): void => {
            onTap();
          })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(10)
  }

  @Builder
  msgPane() {
    Column({ space: 10 }) {
      Text('本机提醒，非聊天')
        .fontSize(12)
        .fontColor(SUB)
        .width('100%')

      this.noteRow('社区动态',
        `未读 ${StudioStore.get().unread(ContentRepo.get().posts.length)} 条 · ` +
        `已读 ${ContentRepo.get().posts.length - StudioStore.get().unread(ContentRepo.get().posts.length)} 条`,
        '去看动态', (): void => {
          this.sub = 0;
        })

      this.noteRow('同步状态', this.syncLine(), '同步面板', (): void => {
        goSync();
      })

      this.noteRow('每日签到',
        StudioStore.get().checkedToday() ?
          `今天已签到，连续 ${StudioStore.get().streak()} 天，签一次能领一个字` :
          '今天还没签到，签到会拿到一个还没集到的字',
        '去签到', (): void => {
          promptAction.showToast({ message: '在「活动」页签到' });
        })

      this.noteRow('集字进度',
        `已集 ${StudioStore.get().chars.length}/4 字`, '', (): void => {
        })

      if (SyncService.get().conflicts.length > 0) {
        this.noteRow('冲突提醒',
          `${SyncService.get().conflicts.length} 条记录两端都改过，已按最新时间保留，旧版存了副本`,
          '去处理', (): void => {
            goSync();
          })
      }

      Text('社区动态与活动为演示数据，非真实用户产生')
        .fontSize(11)
        .fontColor(SUB)
        .width('100%')
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Text('☰')
          .fontSize(18)
          .fontColor(INK)
          .padding({ right: 2 })
          .onClick((): void => {
            openDrawer();
          })
        Text('社群')
          .fontSize(20)
          .fontColor(INK)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        this.subTab('推荐', 0)
        this.subTab('消息', 1)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      if (this.sub === 0) {
        if (ContentRepo.get().posts.length > 0) {
          Scroll() {
            Row({ space: 8 }) {
              this.topicChip('全部', '')
              ForEach(ContentRepo.get().topics(), (t: string): void => {
                this.topicChip(t, t)
              }, (t: string): string => t)
            }
            .padding({ left: 14, right: 14, top: 2, bottom: 8 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }

        if (this.shown().length === 0) {
          Column({ space: 8 }) {
            Text('社区数据未随包提供').fontSize(15).fontColor(INK)
            Text('先去档案库看看沿河的遗存').fontSize(12).fontColor(SUB)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.shown(), (p: Post): void => {
              ListItem() {
                this.postCard(p)
              }
            }, (p: Post): string => this.rowKey(p))

            ListItem() {
              Text('社区动态与活动为演示数据，非真实用户产生')
                .fontSize(11).fontColor(SUB)
                .width('100%')
                .padding({ top: 6, bottom: 18 })
            }
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .padding({ left: 14, right: 14 })
        }
      } else {
        Scroll() {
          this.msgPane()
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .alignItems(HorizontalAlign.Start)
  }
}
