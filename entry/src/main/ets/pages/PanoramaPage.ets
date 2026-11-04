import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { params } from '../common/Nav';
import { fs } from '../common/Theme';

// Remote pages have no Native JavaScript bridge or local-file access.
@Entry
@Component
struct PanoramaPage {
  // 字号档位变了要整页重画：不持有这行，切档后这一页还是老字号
  @StorageLink('textScale') ts: number = 1;
  private controller: webview.WebviewController = new webview.WebviewController();
  @State panoramaId: string = '';
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State noGL: boolean = false;
  aboutToAppear(): void { this.panoramaId = params().id ?? ''; }
  url(): string {
    if (this.panoramaId === 'longmen') { return 'https://demo4.museumcloud.com.cn/vrs/01'; }
    if (this.panoramaId === 'kaifeng') {
      return 'https://www.360cities.net/zh/image/kaifeng-tower-park-4-henan?pano_detail=true&portfolio_view=false';
    }
    return '';
  }
  build() {
    Column() {
      Row() {
        Button('‹ 返回地图').fontSize(fs(this.ts, 14)).fontColor('#715B37').backgroundColor(Color.Transparent)
          .onClick((): void => { router.back(); })
        Text(this.panoramaId === 'longmen' ? '云上龙门' : '开封铁塔').fontSize(fs(this.ts, 18)).layoutWeight(1).textAlign(TextAlign.Center)
        Button('刷新').fontSize(fs(this.ts, 13)).fontColor('#715B37').backgroundColor(Color.Transparent)
          .onClick((): void => { this.failed = false; this.loading = true; this.controller.refresh(); })
      }.width('100%').height(54)
      Text(this.panoramaId === 'longmen' ? '龙门石窟研究院 · 官方实拍全景 · 需联网' : '360Cities / Jacky Cheng · 2007 年实拍 · 需联网')
        .fontSize(fs(this.ts, 11)).fontColor('#81765F').padding(8).width('100%')
      if (this.url().length === 0) {
        Text('此地点暂未接入真实全景').padding(24)
      } else {
        if (this.loading) { Text('正在打开全景，可左右拖动环视…').fontSize(fs(this.ts, 12)).padding(8).fontColor('#81765F') }
        // 模拟器等无 GPU 的内核拿不到 WebGL，全景站点会留白，先把话说清楚
        if (this.noGL) { Text('本机内核未开启 WebGL，全景画面可能空白；真机或系统浏览器可正常环视。')
          .fontSize(fs(this.ts, 12)).fontColor('#9A5B3C').padding(8).width('100%') }
        if (this.failed) { Text('全景页面暂时无法加载，请检查网络后刷新。手绘地图仍可离线使用。').fontSize(fs(this.ts, 13)).padding(12) }
        Web({ src: this.url(), controller: this.controller })
          .javaScriptAccess(true).domStorageAccess(true).fileAccess(false)
          .onPageEnd((): void => {
            this.loading = false;
            this.controller.runJavaScript('!!document.createElement("canvas").getContext("webgl")')
              .then((r: string): void => { this.noGL = r !== 'true'; })
              .catch((): void => {})
          })
          .onErrorReceive((event): void => { if (event.request.isMainFrame()) { this.failed = true; this.loading = false; } })
          .onLoadIntercept((event): boolean => { return !event.data.getRequestUrl().startsWith('https://'); })
          .width('100%').layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor('#FFF9EB')
  }
}
