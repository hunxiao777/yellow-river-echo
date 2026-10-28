import { router } from '@kit.ArkUI';
import { SiteRepo } from '../service/SiteRepo';
import { SiteInfo } from '../model/Models';
import { ERAS, CITIES, TYPES, INK, SUB, LOESS, CLAY } from '../common/Theme';
import { params } from '../common/Nav';
import { SiteCard } from '../view/SiteCard';

@Entry
@Component
struct ListPage {
  @StorageLink('dataRev') rev: number = 0;
  @State kw: string = '';
  @State eras: string[] = [];
  @State cities: string[] = [];
  @State types: string[] = [];

  aboutToAppear(): void {
    let p = params();
    this.kw = p.kw ?? '';
    if (p.era !== undefined && p.era!.length > 0) {
      this.eras.push(p.era!);
    }
    if (p.city !== undefined && p.city!.length > 0) {
      this.cities.push(p.city!);
    }
    if (p.type !== undefined && p.type!.length > 0) {
      this.types.push(p.type!);
    }
  }

  // 数组内容变了但引用没变，@State 不一定会刷新，干脆换个新数组
  rebuild(which: string): void {
    if (which === 'era') {
      this.eras = this.eras.slice();
    } else if (which === 'city') {
      this.cities = this.cities.slice();
    } else {
      this.types = this.types.slice();
    }
  }

  clearAll(): void {
    this.kw = '';
    this.eras = [];
    this.cities = [];
    this.types = [];
  }

  condText(): string {
    let parts: string[] = [];
    if (this.kw.trim().length > 0) {
      parts.push('词:' + this.kw.trim());
    }
    if (this.eras.length > 0) {
      parts.push('年代:' + this.eras.join('/'));
    }
    if (this.cities.length > 0) {
      parts.push('城市:' + this.cities.join('/'));
    }
    if (this.types.length > 0) {
      parts.push('类型:' + this.types.join('/'));
    }
    return parts.length === 0 ? '没有加条件，看的全河段' : parts.join('　');
  }

  @Builder
  chipRow(title: string, options: string[], picked: string[], which: string) {
    Row({ space: 8 }) {
      Text(title).fontSize(12).fontColor(SUB).width(34)
      Scroll() {
        Row({ space: 8 }) {
          ForEach(options, (o: string): void => {
            Text(o)
              .fontSize(12)
              .fontColor(picked.indexOf(o) >= 0 ? Color.White : INK)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .borderRadius(12)
              .backgroundColor(picked.indexOf(o) >= 0 ? CLAY : $r('app.color.card_bg'))
              .onClick((): void => {
                let i = picked.indexOf(o);
                if (i >= 0) {
                  picked.splice(i, 1);
                } else {
                  picked.push(o);
                }
                this.rebuild(which);
              })
          }, (o: string): string => o)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text('‹ 返回').fontSize(15).fontColor(CLAY)
          .onClick((): void => {
            router.back();
          })
        Text('沿河检索').fontSize(18).fontColor(INK).fontWeight(FontWeight.Bold).layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10 })

      Search({ value: this.kw, placeholder: '名称、别名或摘要里的词' })
        .height(38)
        .margin({ left: 14, right: 14 })
        .onChange((v: string): void => {
          this.kw = v;
        })

      Row({ space: 8 }) {
        Text(this.condText())
          .fontSize(12)
          .fontColor(SUB)
          .layoutWeight(1)
          .maxLines(2)
        Text(`${this.results().length} 条`).fontSize(12).fontColor(LOESS).fontWeight(FontWeight.Medium)
        Text('清空').fontSize(12).fontColor(CLAY)
          .onClick((): void => {
            this.clearAll();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14 })

      this.chipRow('年代', ERAS, this.eras, 'era')
      this.chipRow('城市', CITIES, this.cities, 'city')
      this.chipRow('类型', TYPES, this.types, 'type')

      if (this.results().length === 0) {
        Column({ space: 6 }) {
          Text('这一带没有符合条件的').fontSize(14).fontColor(INK)
          Text('试着去掉一个筛选条件，或换个关键词').fontSize(12).fontColor(SUB)
        }
        .margin({ top: 50 })
      } else {
        List({ space: 8 }) {
          ForEach(this.results(), (s: SiteInfo): void => {
            ListItem() {
              SiteCard({ site: s })
            }
          }, (s: SiteInfo): string => s.id)
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
  }

  results(): SiteInfo[] {
    return SiteRepo.get().query(this.kw, this.eras, this.cities, this.types);
  }
}
