import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

/*
 * 转台序列帧的读取与缓存。
 *
 * 帧是烘好的 3D 灰模（rawfile/pottery/turntable/<器型>/<帧号>.webp，5 器型 × 24 帧），
 * 映射表 index.json 由 tools/bake_pottery_frames.mjs 生成，里面记了每种器型的
 * topPx/botPx/maxHalfPx/band —— App 端罩釉色、按弧度贴纹样全靠这几个数，
 * 改了烘帧脚本就得重跑，表和帧不一致的话纹样会贴到器外去。
 *
 * 解码一律走异步 createPixelMap：ImageSource.createPixelMapSync 文档里点名不要在主线程调用，
 * 一帧 512×640 RGBA 解出来 1.3 MB，同步解 24 帧会把滑动直接卡死。
 * 缓存按「最近最少用」留 14 帧（≈18 MB），换来换去都命中；进出页面时整体 release。
 */

export interface ShapeMeta {
  key: string;
  label: string;
  frames: number;
  symmetric: boolean;
  topPx: number;
  botPx: number;
  maxHalfPx: number;
  rimHalfPx: number;
  band: number[];
  ms: number;
}

export interface TurntableIndex {
  frames: number;
  canvas: number[];
  degStep: number;
  ext: string;
  enc: string;
  shapes: Record<string, ShapeMeta>;
  totalBytes: number;
}

const DIR = 'pottery/turntable/';
const CACHE_MAX: number = 14;

export class TurntableFrames {
  private static readonly inst: TurntableFrames = new TurntableFrames();

  static get(): TurntableFrames {
    return TurntableFrames.inst;
  }

  index: TurntableIndex | null = null;
  private cache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private order: string[] = [];
  private loading: Map<string, Promise<image.PixelMap | null>> =
    new Map<string, Promise<image.PixelMap | null>>();
  private ctx: common.UIAbilityContext | null = null;

  // 读表是同步的：一次 1 KB 出头的 rawfile，比等一个 Promise 再决定画什么好办
  loadIndex(ctx: common.UIAbilityContext): TurntableIndex | null {
    if (this.index !== null) {
      return this.index;
    }
    try {
      this.ctx = ctx;
      let bytes = ctx.resourceManager.getRawFileContentSync(DIR + 'index.json');
      let dec = util.TextDecoder.create('utf-8');
      let idx = JSON.parse(dec.decodeToString(bytes)) as TurntableIndex;
      if (idx.canvas.length !== 2 || idx.canvas[0] <= 0 || idx.canvas[1] <= 0 || idx.frames <= 0) {
        console.warn('turntable index malformed');
        return null;
      }
      this.index = idx;
      return idx;
    } catch (e) {
      console.warn('turntable index missing');
      return null;
    }
  }

  // 页面里的器型是中文名（罐/盆/壶/瓶/鼎式），表里的键是拼音，靠 label 对接
  metaOf(label: string): ShapeMeta | null {
    let idx = this.index;
    if (idx === null) {
      return null;
    }
    let keys = Object.keys(idx.shapes);
    for (let i = 0; i < keys.length; i++) {
      let m = idx.shapes[keys[i]];
      if (m !== undefined && m.label === label) {
        return m;
      }
    }
    return null;
  }

  frameCount(m: ShapeMeta): number {
    return m.frames > 0 ? m.frames : 24;
  }

  // 已在缓存里就直接给，不等 Promise：拖动时每帧都要走这条路
  peek(key: string, frame: number): image.PixelMap | null {
    let k = key + '#' + frame;
    let pm = this.cache.get(k);
    if (pm !== undefined) {
      this.touch(k);
      return pm;
    }
    return null;
  }

  frame(key: string, frame: number): Promise<image.PixelMap | null> {
    let k = key + '#' + frame;
    let hit = this.cache.get(k);
    if (hit !== undefined) {
      this.touch(k);
      return Promise.resolve<image.PixelMap | null>(hit);
    }
    let go = this.loading.get(k);
    if (go !== undefined) {
      return go;
    }
    let task = this.decode(key, frame).then((pm: image.PixelMap | null): image.PixelMap | null => {
      this.loading.delete(k);
      if (pm !== null) {
        this.cache.set(k, pm);
        this.order.push(k);
        this.trim();
      }
      return pm;
    }).catch((): image.PixelMap | null => {
      this.loading.delete(k);
      return null;
    });
    this.loading.set(k, task);
    return task;
  }

  // 只入缓存，不回调：拖动前把左右两帧先解好，手指才不会“等图”
  prefetch(key: string, frame: number): void {
    let k = key + '#' + frame;
    if (this.cache.has(k) || this.loading.has(k)) {
      return;
    }
    this.frame(key, frame).then((): void => {});
  }

  private decode(key: string, frame: number): Promise<image.PixelMap | null> {
    let ctx = this.ctx;
    let idx = this.index;
    if (ctx === null || idx === null) {
      return Promise.resolve<image.PixelMap | null>(null);
    }
    let path = DIR + key + '/' + frame + '.' + idx.ext;
    try {
      let bytes = ctx.resourceManager.getRawFileContentSync(path);
      let src = image.createImageSource(bytes.buffer as ArrayBuffer);
      return src.createPixelMap().then((pm: image.PixelMap): image.PixelMap | null => {
        src.release().then((): void => {});
        return pm;
      });
    } catch (e) {
      console.warn('frame decode failed: ' + path);
      return Promise.resolve<image.PixelMap | null>(null);
    }
  }

  private touch(k: string): void {
    let i = this.order.indexOf(k);
    if (i >= 0) {
      this.order.splice(i, 1);
    }
    this.order.push(k);
  }

  private trim(): void {
    while (this.order.length > CACHE_MAX) {
      let oldest = this.order.shift();
      if (oldest === undefined) {
        return;
      }
      let pm = this.cache.get(oldest);
      if (pm !== undefined) {
        this.cache.delete(oldest);
        pm.release().then((): void => {});
      }
    }
  }

  // 离开页面时调用：PixelMap 是 native 内存，只靠 GC 收会一直占着
  releaseAll(): void {
    for (let k of this.cache.keys()) {
      let pm = this.cache.get(k);
      if (pm !== undefined) {
        pm.release().then((): void => {});
      }
    }
    this.cache.clear();
    this.order = [];
    this.loading.clear();
  }
}
