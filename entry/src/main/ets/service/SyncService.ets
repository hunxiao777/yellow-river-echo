import { distributedKVStore, preferences } from '@kit.ArkData';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { common } from '@kit.AbilityKit';
import { MemoryStore } from './MemoryStore';
import { NoteRec } from '../model/Models';

export interface DeviceRow {
  name: string;
  id: string;
}

export interface ConflictRow {
  key: string;
  at: number;
  kept: string;
}

// 同步引擎：本地写 preferences 成功后进入 KV 存储队列，
// 发现同账号可信设备后 PUSH_PULL；策略是 updatedAt 新者胜，
// 被覆盖的笔记存一份副本，可在同步面板里找回。
export class SyncService {
  private static readonly inst: SyncService = new SyncService();
  static get(): SyncService {
    return SyncService.inst;
  }

  state: string = 'off'; // off | ready | unavailable
  hint: string = '同步未开始';
  lastSyncAt: number = 0;
  conflicts: ConflictRow[] = [];
  devices: DeviceRow[] = [];
  dirty: Map<string, number> = new Map();
  localOnly: boolean = false;

  private kv?: distributedKVStore.SingleKVStore;
  private devMgr?: distributedDeviceManager.DeviceManager;
  private p: preferences.Preferences | null = null;
  private syncing: boolean = false;
  private syncTimer: number = -1;
  private lastDevScan: number = 0;
  private putFailStreak: number = 0;
  private booted: boolean = false;

  async init(ctx: common.Context, bundleName: string): Promise<void> {
    if (this.booted) {
      return;
    }
    this.booted = true;
    MemoryStore.get().onLocalChange = (entity: string, id: string, payload: string, ts: number): void => {
      this.push(entity, id, payload, ts);
    };
    try {
      this.p = await preferences.getPreferences(ctx, 'hh_sync');
      this.lastSyncAt = this.p.getSync('lastSyncAt', 0) as number;
      this.localOnly = (this.p.getSync('localOnly', false) as boolean) === true;
      let raw = this.p.getSync('dirty', '{}') as string;
      let saved = JSON.parse(raw) as Record<string, number>;
      for (let k of Object.keys(saved)) {
        this.dirty.set(k, saved[k]);
      }
    } catch (e) {
      console.error('sync prefs: ' + JSON.stringify(e));
    }
    try {
      const cfg: distributedKVStore.KVManagerConfig = {
        context: ctx,
        bundleName: bundleName
      };
      let mgr = distributedKVStore.createKVManager(cfg);
      const opt: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: false,
        backup: false,
        autoSync: false,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      };
      this.kv = await mgr.getKVStore<distributedKVStore.SingleKVStore>('hh_memory_kv', opt);
      this.kv.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_REMOTE,
        (data: distributedKVStore.ChangeNotification): void => {
          this.onRemote(data.insertEntries.concat(data.updateEntries));
        });
      this.devMgr = distributedDeviceManager.createDeviceManager(bundleName);
      this.state = 'ready';
      if (this.localOnly) {
        this.hint = '本机模式：数据只写本地，跨设备同步暂停';
      } else {
        this.hint = '等待可信设备出现';
        // 设备扫描是同步阻塞调用，放到启动帧之后，别拖慢首屏
        setTimeout((): void => {
          this.refreshDevices();
          if (this.dirty.size > 0) {
            this.retry();
          }
        }, 1200);
      }
    } catch (e) {
      this.state = 'unavailable';
      this.hint = '本机分布式服务不可用，数据仍保存在本地，恢复后自动续传';
      console.error('kv init: ' + JSON.stringify(e));
    }
    this.notify();
  }

  private push(entity: string, id: string, payload: string, ts: number): void {
    let key = entity + ':' + id;
    this.dirty.set(key, ts);
    if (this.localOnly || this.kv === undefined) {
      this.persistDirty();
      this.notify();
      return;
    }
    let t0 = Date.now();
    this.kv.put(key, payload).then((): void => {
      this.putFailStreak = 0;
      this.scheduleSync();
    }).catch((err: Error): void => {
      console.warn('hh perf kv.put fail ' + key + ' ' + (Date.now() - t0) + 'ms ' + err.message);
      this.putFailStreak += 1;
      if (this.putFailStreak >= 3) {
        this.setLocalOnly(true, '分布式存储多次写入失败，已自动切换为本机模式');
        return;
      }
      this.hint = '写入分布式库失败：' + err.message;
      this.notify();
    });
  }

  setLocalOnly(on: boolean, why: string = ''): void {
    this.localOnly = on;
    if (on) {
      if (this.syncTimer >= 0) {
        clearTimeout(this.syncTimer);
        this.syncTimer = -1;
      }
      this.devices = [];
      this.syncing = false;
      this.hint = why.length > 0 ? why : '本机模式：数据只写本地，跨设备同步暂停';
    } else {
      this.putFailStreak = 0;
      this.hint = '等待可信设备出现';
      this.refreshDevices(true);
      if (this.dirty.size > 0) {
        this.trySync();
      }
    }
    if (this.p !== null) {
      this.p.put('localOnly', on);
    }
    this.persistDirty();
    this.notify();
  }

  // 连着改多条时合并成一次同步，别把设备扫描顶到界面上
  private scheduleSync(): void {
    if (this.syncTimer >= 0) {
      return;
    }
    this.syncTimer = setTimeout((): void => {
      this.syncTimer = -1;
      this.trySync();
    }, 1500);
  }

  refreshDevices(force: boolean = false): void {
    if (this.devMgr === undefined || this.localOnly) {
      return;
    }
    let now = Date.now();
    if (!force && now - this.lastDevScan < 8000) {
      return;
    }
    this.lastDevScan = now;
    try {
      let list = this.devMgr.getAvailableDeviceListSync();
      this.devices = list.map((d: distributedDeviceManager.DeviceBasicInfo): DeviceRow =>
        ({ name: d.deviceName, id: d.networkId ?? '' }));
      if (this.devices.length === 0 && this.hint.indexOf('不可用') < 0) {
        this.hint = '未发现同账号可信设备，检查蓝牙/Wi-Fi 与登录状态';
      }
    } catch (e) {
      this.devices = [];
    }
    this.notify();
  }

  private trySync(): void {
    if (this.localOnly || this.kv === undefined || this.syncing || this.dirty.size === 0) {
      return;
    }
    this.refreshDevices();
    if (this.devices.length === 0) {
      this.persistDirty();
      this.notify();
      return;
    }
    this.syncing = true;
    let ids = this.devices.map((d: DeviceRow): string => d.id).filter((s: string): boolean => s.length > 0);
    let sent = this.dirty.size;
    try {
      // sync 是异步广播，没有回执；4 秒内没抛异常就认为已推送，
      // 对端真正落库以对方的 dataChange 为准
      this.kv.sync(ids, distributedKVStore.SyncMode.PUSH_PULL, 3000);
      setTimeout((): void => {
        this.syncing = false;
        this.dirty.clear();
        this.lastSyncAt = Date.now();
        this.hint = '已向 ' + ids.length + ' 台设备推送 ' + sent + ' 条变更';
        this.persistDirty();
        this.notify();
      }, 4000);
    } catch (e) {
      this.syncing = false;
      this.hint = '同步通道异常，本地内容不受影响，稍后可手动重试';
      this.persistDirty();
      this.notify();
    }
  }

  retry(): void {
    this.lastDevScan = 0;
    this.refreshDevices(true);
    this.trySync();
  }

  private async onRemote(entries: distributedKVStore.Entry[]): Promise<void> {
    if (this.kv === undefined) {
      return;
    }
    let store = MemoryStore.get();
    for (let en of entries) {
      let key = en.key;
      let raw = en.value;
      if (typeof raw !== 'string') {
        continue;
      }
      let payload = raw;
      try {
        let rec = JSON.parse(payload) as Record<string, Object>;
        let remoteTs = rec.updatedAt as number;
        let sep = key.indexOf(':');
        let entity = key.substring(0, sep);
        let id = key.substring(sep + 1);
        let localTs = store.localTs(entity, id);
        if (this.dirty.has(key) && localTs > remoteTs) {
          // 双端都改过：时间戳新者胜，旧内容留档
          this.conflicts.unshift({ key: key, at: Date.now(), kept: '本机版本' });
          if (this.conflicts.length > 20) {
            this.conflicts.pop();
          }
          if (entity === 'note') {
            await store.addConflictCopy(JSON.parse(payload) as NoteRec);
          }
          let mine = store.recordOf(entity, id);
          if (mine !== undefined) {
            await this.kv.put(key, JSON.stringify(mine));
          }
          this.hint = '发现 ' + this.conflicts.length + ' 条冲突，已按最新时间保留';
        } else {
          this.dirty.delete(key);
          await store.applyRemote(entity, payload);
        }
      } catch (e) {
        console.error('remote key ' + key + ': ' + JSON.stringify(e));
      }
    }
    this.persistDirty();
    this.notify();
  }

  private persistDirty(): void {
    if (this.p === null) {
      return;
    }
    let obj: Record<string, number> = {};
    this.dirty.forEach((ts: number, key: string): void => {
      obj[key] = ts;
    });
    this.p.put('dirty', JSON.stringify(obj));
    this.p.put('lastSyncAt', this.lastSyncAt);
  }

  pendingCount(): number {
    return this.dirty.size;
  }

  private notify(): void {
    let rev = AppStorage.get<number>('syncRev') ?? 0;
    AppStorage.setOrCreate('syncRev', rev + 1);
  }
}
