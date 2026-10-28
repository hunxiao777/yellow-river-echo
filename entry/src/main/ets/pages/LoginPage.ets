import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { StudioStore } from '../service/StudioStore';
import { INK, SUB, LOESS, CLAY, paletteOf } from '../common/Theme';

interface AvatarSeed {
  key: string;
  glyph: string;
}

const AVATARS: AvatarSeed[] = [
  { key: 'yangshao', glyph: '陶' },
  { key: 'longshan', glyph: '墨' },
  { key: 'xiashang', glyph: '鼎' },
  { key: 'zhou', glyph: '磬' },
  { key: 'hantang', glyph: '彩' },
  { key: 'song', glyph: '桥' }
];

@Entry
@Component
struct LoginPage {
  @State nick: string = '';
  @State bio: string = '';
  @State avatar: number = 0;

  enter(): void {
    let name = this.nick.trim();
    if (name.length === 0) {
      name = '河边来的人';
    }
    let s = StudioStore.get();
    let note = this.bio.trim();
    s.signIn(name, this.avatar).then((): void => {
      if (note.length > 0) {
        s.setBio(note);
      }
      router.replaceUrl({ url: 'pages/Index' });
    });
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回引导').fontSize(14).fontColor(SUB)
          .onClick((): void => {
            router.replaceUrl({ url: 'pages/GuidePage' });
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 20 })

      Column({ space: 8 }) {
        Text('登个记')
          .fontSize(26).fontColor(INK).fontWeight(FontWeight.Bold)
        Text('没有账号体系：昵称和签名只写在这台设备上，\n换设备靠分布式同步或备份文件接上。')
          .fontSize(12).fontColor(SUB).lineHeight(20)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 24, top: 26 })

      Column({ space: 18 }) {
        Row({ space: 12 }) {
          ForEach(AVATARS, (a: AvatarSeed, i: number): void => {
            Column() {
              Text(a.glyph)
                .fontSize(17)
                .fontColor(paletteOf(a.key).ink)
                .fontWeight(FontWeight.Medium)
            }
            .width(44)
            .height(44)
            .borderRadius(22)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(paletteOf(a.key).deep)
            .border({
              width: this.avatar === i ? 2.5 : 0,
              color: this.avatar === i ? CLAY : Color.Transparent
            })
            .onClick((): void => {
              this.avatar = i;
            })
          }, (a: AvatarSeed): string => a.glyph)
        }

        Column({ space: 6 }) {
          Text('昵称').fontSize(12).fontColor(SUB)
          TextInput({ placeholder: '比如：彩陶片收集者', text: this.nick })
            .fontSize(15)
            .fontColor(INK)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(10)
            .height(46)
            .maxLength(12)
            .onChange((v: string): void => {
              this.nick = v;
            })
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text('一句话签名').fontSize(12).fontColor(SUB)
          TextInput({ placeholder: '黄河岸边，一路捡旧物', text: this.bio })
            .fontSize(15)
            .fontColor(INK)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(10)
            .height(46)
            .maxLength(20)
            .onChange((v: string): void => {
              this.bio = v;
            })
        }
        .alignItems(HorizontalAlign.Start)

        Button('进入档案')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor(CLAY)
          .width('100%')
          .height(48)
          .borderRadius(24)
          .margin({ top: 8 })
          .onClick((): void => {
            this.enter();
          })

        Text('先随便看看')
          .fontSize(13)
          .fontColor(LOESS)
          .padding(8)
          .onClick((): void => {
            promptAction.showToast({ message: '游客身份进入，数据同样只存本机' });
            this.nick = '河边来的人';
            this.enter();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 26 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.page_bg'))
  }
}
