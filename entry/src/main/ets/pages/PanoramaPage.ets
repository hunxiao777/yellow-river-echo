import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { params } from '../common/Nav';

// Remote pages have no Native JavaScript bridge or local-file access.
@Entry
@Component
struct PanoramaPage {
  private controller: webview.WebviewController = new webview.WebviewController();
  @State panoramaId: string = '';
  @State loading: boolean = true;
  @State failed: boolean = false;
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
        Button('‹ 返回地图').fontSize(14).fontColor('#715B37').backgroundColor(Color.Transparent)
          .onClick((): void => { router.back(); })
        Text(this.panoramaId === 'longmen' ? '云上龙门' : '开封铁塔').fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
        Button('刷新').fontSize(13).fontColor('#715B37').backgroundColor(Color.Transparent)
          .onClick((): void => { this.failed = false; this.loading = true; this.controller.refresh(); })
      }.width('100%').height(54)
      Text(this.panoramaId === 'longmen' ? '龙门石窟研究院 · 官方实拍全景 · 需联网' : '360Cities / Jacky Cheng · 2007 年实拍 · 需联网')
        .fontSize(11).fontColor('#81765F').padding(8).width('100%')
      if (this.url().length === 0) {
        Text('此地点暂未接入真实全景').padding(24)
      } else {
        if (this.loading) { Text('正在打开全景，可左右拖动环视…').fontSize(12).padding(8).fontColor('#81765F') }
        if (this.failed) { Text('全景页面暂时无法加载，请检查网络后刷新。手绘地图仍可离线使用。').fontSize(13).padding(12) }
        Web({ src: this.url(), controller: this.controller })
          .javaScriptAccess(true).domStorageAccess(true).fileAccess(false)
          .onPageEnd((): void => { this.loading = false; })
          .onErrorReceive((event): void => { if (event.request.isMainFrame()) { this.failed = true; this.loading = false; } })
          .onLoadIntercept((event): boolean => { return !event.data.getRequestUrl().startsWith('https://'); })
          .width('100%').layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor('#FFF9EB')
  }
}
