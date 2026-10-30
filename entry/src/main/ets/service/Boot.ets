import { bundleManager, common } from '@kit.AbilityKit';
import { SiteRepo } from './SiteRepo';
import { ContentRepo } from './ContentRepo';
import { MemoryStore } from './MemoryStore';
import { StudioStore } from './StudioStore';
import { SyncService } from './SyncService';
import { AiStore } from './AiStore';

// 启动链：只跑一次，Splash 期间把它跑完，后面的页面默认数据已就绪。
export class Boot {
  private static done: boolean = false;

  static async run(ctx: common.Context): Promise<void> {
    if (Boot.done) {
      return;
    }
    let bn = '';
    try {
      bn = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).name;
    } catch (e) {
      console.warn('bundle name unavailable');
    }
    await SiteRepo.get().load(ctx);
    await ContentRepo.get().load(ctx);
    await MemoryStore.get().init(ctx);
    await StudioStore.get().init(ctx);
    await AiStore.get().init(ctx);
    await SyncService.get().init(ctx, bn);
    Boot.done = true;
  }

  static ready(): boolean {
    return Boot.done;
  }
}
