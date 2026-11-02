import { router } from '@kit.ArkUI';
import { Goods } from '../model/Models';
import { ContentRepo } from '../service/ContentRepo';
import { ArtCover } from '../view/ArtCover';
import { INK, SUB, LOESS, CLAY, LINE, paletteOf, Palette, fs } from '../common/Theme';
import { goGoods, params } from '../common/Nav';

// 颜色工坊：一个颜色对应一类文物。色名是演示口径的称呼（仰韶红、宋天青…），
// 对应的文物从文创演示数据里按 palette 取，点芯片能跳到那件文物。
export interface ColorRow {
  key: string;
  name: string;
  era: string;
  saying: string;
}

const ROWS: ColorRow[] = [
  { key: 'yangshao', name: '仰韶红', era: '仰韶', saying: '彩陶的底色，是黄河泥在窑火里烧出来的红。' },
  { key: 'longshan', name: '龙山黑', era: '龙山', saying: '黑陶靠渗碳烧成，黑得发亮，薄得透光。' },
  { key: 'xiashang', name: '夏商青绿', era: '夏商', saying: '青铜刚铸出来是亮的青绿，锈了才沉成现在这样。' },
  { key: 'zhou', name: '周玉色', era: '周', saying: '玉色是礼器的底子，温而不艳，压得住场面。' },
  { key: 'hantang', name: '汉唐赭黄', era: '汉唐', saying: '赭黄是三彩釉里的主色，铅釉在火里流得开。' },
  { key: 'song', name: '宋天青', era: '宋', saying: '天青是"雨过天晴云破处"的那一层青。' }
];

// 展台等外部页面按色键取色名与一句话说法
export function colorRowOf(key: string): ColorRow {
  for (let r of ROWS) {
    if (r.key === key) {
      return r;
    }
  }
  return ROWS[0];
}

const SHAPES: string[] = ['pot', 'jar', 'ding', 'tile', 'stele', 'box', 'coin', 'kiln'];

@Entry
@Component
struct ColorPage {
  // 字号档位变了要整页重画：不持有这行，切档后这一页还是老字号
  @StorageLink('textScale') ts: number = 1;
  @State sel: string = 'yangshao';

  aboutToAppear(): void {
    // 从创意工坊展台带色进来时，落地先选中那一色
    let p = params();
    if (p !== undefined && p.colorKey !== undefined && p.colorKey.length > 0) {
      this.sel = p.colorKey;
    }
  }

  goodsOf(key: string): Goods[] {
    let out: Goods[] = [];
    for (let g of ContentRepo.get().goods) {
      if (g.palette === key) {
        out.push(g);
      }
    }
    return out;
  }

  row(): ColorRow {
    return colorRowOf(this.sel);
  }

  rep(): Goods | undefined {
    let list = this.goodsOf(this.sel);
    return list.length > 0 ? list[0] : undefined;
  }

  shapeOf(id: string): string {
    let n = 0;
    for (let i = 0; i < id.length; i++) {
      n += id.charCodeAt(i);
    }
    return SHAPES[n % SHAPES.length];
  }

  pal(): Palette {
    return paletteOf(this.sel);
  }

  @Builder
  swatch(r: ColorRow) {
    Column({ space: 5 }) {
      Stack() {
        Column()
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor(paletteOf(r.key).base)
          .border({ width: 2, color: this.sel === r.key ? paletteOf(r.key).deep : LINE })
        Column()
          .width(16)
          .height(16)
          .borderRadius(8)
          .backgroundColor(paletteOf(r.key).deep)
      }
      .width(48)
      .height(48)

      Text(r.name)
        .fontSize(fs(this.ts, 11))
        .fontColor(this.sel === r.key ? CLAY : INK)
        .fontWeight(this.sel === r.key ? FontWeight.Medium : FontWeight.Regular)
      Text(r.era)
        .fontSize(fs(this.ts, 9))
        .fontColor(SUB)
    }
    .width(64)
    .onClick((): void => {
      this.sel = r.key;
    })
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Text('‹ 返回')
          .fontSize(fs(this.ts, 15))
          .fontColor(CLAY)
          .onClick((): void => {
            router.back();
          })
        Text('颜色工坊')
          .fontSize(fs(this.ts, 18))
          .fontColor(INK)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text('六色六器')
          .fontSize(fs(this.ts, 12))
          .fontColor(LOESS)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          Scroll() {
            Row({ space: 4 }) {
              ForEach(ROWS, (r: ColorRow): void => {
                this.swatch(r)
              }, (r: ColorRow): string => r.key)
            }
            .padding({ left: 4, right: 10 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .padding({ top: 12, bottom: 10 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)

          Column({ space: 10 }) {
            Column() {
              ArtCover({ palette: this.sel, shape: this.rep() === undefined ? 'pot' : this.shapeOf(this.rep()!.id),
                seed: 3, label: this.rep() === undefined ? '' : this.rep()!.cat })
            }
            .width('100%')
            .height(150)
            .borderRadius(12)
            .clip(true)

            Row({ space: 8 }) {
              Text(this.row().name)
                .fontSize(fs(this.ts, 17))
                .fontColor(INK)
                .fontWeight(FontWeight.Bold)
              Text(this.row().era)
                .fontSize(fs(this.ts, 10))
                .fontColor(this.pal().ink)
                .backgroundColor(this.pal().deep)
                .borderRadius(7)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              Blank()
              Text(`${this.goodsOf(this.sel).length} 件对应文物`)
                .fontSize(fs(this.ts, 10))
                .fontColor(SUB)
            }
            .width('100%')

            Text(this.row().saying)
              .fontSize(fs(this.ts, 12))
              .fontColor(SUB)
              .width('100%')
              .lineHeight(fs(this.ts, 19))

            if (this.rep() !== undefined) {
              Column({ space: 4 }) {
                Text(this.rep()!.name)
                  .fontSize(fs(this.ts, 13))
                  .fontColor(INK)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                Text(this.rep()!.sub)
                  .fontSize(fs(this.ts, 11))
                  .fontColor(SUB)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(10)
              .backgroundColor(this.pal().paper)
              .borderRadius(10)
              .onClick((): void => {
                goGoods(this.rep()!.id);
              })
            }

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.goodsOf(this.sel), (g: Goods): void => {
                Text(g.name)
                  .fontSize(fs(this.ts, 10))
                  .fontColor(INK)
                  .padding({ left: 8, right: 10, top: 5, bottom: 5 })
                  .borderRadius(12)
                  .backgroundColor($r('app.color.card_bg'))
                  .border({ width: 1, color: LINE })
                  .margin({ right: 7, bottom: 7 })
                  .onClick((): void => {
                    goGoods(g.id);
                  })
              }, (g: Goods): string => 'cg_' + g.id)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)
          .alignItems(HorizontalAlign.Start)

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
