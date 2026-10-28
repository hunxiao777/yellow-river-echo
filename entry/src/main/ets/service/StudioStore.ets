import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Profile, WorkRec } from '../model/Models';

// 本机互动与创作数据：昵称头像、商品点赞/清单、集字、签到、彩陶作品。
// 刻意不进分布式队列——这些是演示型数据，跨端要同步的仍是档案收藏与笔记。
export class StudioStore {
  private static readonly inst: StudioStore = new StudioStore();
  static get(): StudioStore {
    return StudioStore.inst;
  }

  profile: Profile = { nick: '', avatar: 0, bio: '黄河岸边，一路捡旧物', joinedAt: 0 };
  likes: string[] = [];
  cart: string[] = [];
  chars: string[] = [];
  checkins: string[] = [];
  works: WorkRec[] = [];
  readPosts: string[] = [];
  followed: string[] = [];
  guideSeen: boolean = false;

  private p: preferences.Preferences | null = null;

  async init(ctx: common.Context): Promise<void> {
    if (this.p !== null) {
      return;
    }
    this.p = await preferences.getPreferences(ctx, 'hh_studio');
    this.guideSeen = (this.p.getSync('guideSeen', false) as boolean) === true;
    let raw = this.p.getSync('profile', '') as string;
    if (raw.length > 0) {
      try {
        this.profile = JSON.parse(raw) as Profile;
      } catch (e) {
        console.warn('profile broken, reset');
      }
    }
    this.likes = this.readArr('likes');
    this.cart = this.readArr('cart');
    this.chars = this.readArr('chars');
    this.checkins = this.readArr('checkins');
    this.works = this.readArr<WorkRec>('works');
    this.readPosts = this.readArr('readPosts');
    this.followed = this.readArr('followed');
  }

  private readArr<T>(key: string): T[] {
    if (this.p === null) {
      return [];
    }
    let raw = this.p.getSync(key, '[]') as string;
    try {
      return JSON.parse(raw) as T[];
    } catch (e) {
      return [];
    }
  }

  private save(key: string, val: Object): void {
    if (this.p === null) {
      return;
    }
    this.p.put(key, JSON.stringify(val));
    this.scheduleFlush();
    StudioStore.rev();
  }

  private flushTimer: number = -1;

  // flush 慢，攒一批后台落盘，别卡在点击上
  scheduleFlush(): void {
    if (this.p === null || this.flushTimer >= 0) {
      return;
    }
    this.flushTimer = setTimeout((): void => {
      this.flushTimer = -1;
      this.flushNow();
    }, 900);
  }

  static rev(): void {
    let r = AppStorage.get<number>('studioRev') ?? 0;
    AppStorage.setOrCreate('studioRev', r + 1);
  }

  signedIn(): boolean {
    return this.profile.joinedAt > 0;
  }

  markGuideSeen(): void {
    this.guideSeen = true;
    if (this.p !== null) {
      this.p.put('guideSeen', true);
      this.scheduleFlush();
    }
  }

  async signIn(nick: string, avatar: number): Promise<void> {
    this.profile = { nick: nick, avatar: avatar, bio: this.profile.bio, joinedAt: Date.now() };
    this.save('profile', this.profile);
  }

  async setBio(bio: string): Promise<void> {
    this.profile.bio = bio;
    this.save('profile', this.profile);
  }

  isLiked(id: string): boolean {
    return this.likes.indexOf(id) >= 0;
  }

  toggleLike(id: string): void {
    let i = this.likes.indexOf(id);
    if (i >= 0) {
      this.likes.splice(i, 1);
    } else {
      this.likes.unshift(id);
    }
    this.save('likes', this.likes);
  }

  inCart(id: string): boolean {
    return this.cart.indexOf(id) >= 0;
  }

  toggleCart(id: string): void {
    let i = this.cart.indexOf(id);
    if (i >= 0) {
      this.cart.splice(i, 1);
    } else {
      this.cart.push(id);
    }
    this.save('cart', this.cart);
  }

  isFollowed(nick: string): boolean {
    return this.followed.indexOf(nick) >= 0;
  }

  toggleFollow(nick: string): void {
    let i = this.followed.indexOf(nick);
    if (i >= 0) {
      this.followed.splice(i, 1);
    } else {
      this.followed.push(nick);
    }
    this.save('followed', this.followed);
  }

  markPostRead(id: string): void {
    if (this.readPosts.indexOf(id) < 0) {
      this.readPosts.push(id);
      this.save('readPosts', this.readPosts);
    }
  }

  unread(total: number): number {
    return total > this.readPosts.length ? total - this.readPosts.length : 0;
  }

  hasChar(c: string): boolean {
    return this.chars.indexOf(c) >= 0;
  }

  addChar(c: string): boolean {
    if (this.chars.indexOf(c) >= 0) {
      return false;
    }
    this.chars.push(c);
    this.save('chars', this.chars);
    return true;
  }

  today(): string {
    let d = new Date();
    let m = d.getMonth() + 1;
    let dd = d.getDate();
    return `${d.getFullYear()}-${m < 10 ? '0' : ''}${m}-${dd < 10 ? '0' : ''}${dd}`;
  }

  checkedToday(): boolean {
    return this.checkins.indexOf(this.today()) >= 0;
  }

  checkin(): boolean {
    let day = this.today();
    if (this.checkins.indexOf(day) >= 0) {
      return false;
    }
    this.checkins.push(day);
    this.save('checkins', this.checkins);
    return true;
  }

  streak(): number {
    let n = 0;
    let cursor = new Date();
    for (let i = 0; i < 60; i++) {
      let m = cursor.getMonth() + 1;
      let dd = cursor.getDate();
      let key = `${cursor.getFullYear()}-${m < 10 ? '0' : ''}${m}-${dd < 10 ? '0' : ''}${dd}`;
      if (this.checkins.indexOf(key) >= 0) {
        n += 1;
      } else if (i > 0 || n > 0) {
        break;
      }
      cursor.setDate(cursor.getDate() - 1);
    }
    return n;
  }

  addWork(w: WorkRec): void {
    this.works.unshift(w);
    if (this.works.length > 30) {
      this.works.pop();
    }
    this.save('works', this.works);
  }

  workOf(id: string): WorkRec | undefined {
    for (let w of this.works) {
      if (w.id === id) {
        return w;
      }
    }
    return undefined;
  }

  dropWork(id: string): void {
    let i = -1;
    for (let k = 0; k < this.works.length; k++) {
      if (this.works[k].id === id) {
        i = k;
        break;
      }
    }
    if (i >= 0) {
      this.works.splice(i, 1);
      this.save('works', this.works);
    }
  }

  flushNow(): void {
    if (this.flushTimer >= 0) {
      clearTimeout(this.flushTimer);
      this.flushTimer = -1;
    }
    if (this.p !== null) {
      this.p.flush().catch((e: Error): void => {
        console.error('studio flush: ' + e.message);
      });
    }
  }
}
