import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Boot } from '../service/Boot';
import { StudioStore } from '../service/StudioStore';
import { AuroraSplash } from '../view/AuroraSplash';

// 启动页：Aurora 渐变（故宫红 + 米黄光团在背景缓慢流动），中央「黄河续响」。
// 视觉用 AuroraSplash，本页只管开河数据的引导加载与首启分流：
// 没看过引河 → GuidePage，没登录 → LoginPage，否则直接进 Index。
@Entry
@Component
struct SplashPage {
  private timer: number = -1;
  private step: number = 0;
  private leaving: boolean = false;

  aboutToAppear(): void {
    let ctx = getContext(this) as common.UIAbilityContext;
    let started = Date.now();
    Boot.run(ctx).catch((e: Error): void => {
      console.error('boot: ' + e.message);
    });
    this.timer = setInterval((): void => {
      this.step += 1;
      // 光团要漂到位才走，所以最短停 2.3 秒；数据没回来就继续等
      if (this.step >= 20 && Date.now() - started > 2300 && !this.leaving) {
        this.leaving = true;
        clearInterval(this.timer);
        this.go();
      }
    }, 60);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  go(): void {
    let s = StudioStore.get();
    if (!s.guideSeen) {
      router.replaceUrl({ url: 'pages/GuidePage' });
    } else if (!s.signedIn()) {
      router.replaceUrl({ url: 'pages/LoginPage' });
    } else {
      router.replaceUrl({ url: 'pages/Index' });
    }
  }

  build() {
    Stack() {
      AuroraSplash()
    }
    .width('100%')
    .height('100%')
    .onClick((): void => {
      if (!this.leaving && this.step >= 8) {
        this.leaving = true;
        clearInterval(this.timer);
        this.go();
      }
    })
  }
}
