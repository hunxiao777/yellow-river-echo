import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ChatTurn } from '../model/AiModels';
import { MemoryStore } from './MemoryStore';

// 助手的本机配置与对话留档。
// App Key 只落在 preferences，不进源码、不进构建产物、也不参与跨端同步。
export class AiStore {
  private static readonly inst: AiStore = new AiStore();
  static get(): AiStore {
    return AiStore.inst;
  }

  baseUrl: string = 'https://api.dify.ai/v1';
  appKey: string = '';
  personalOn: boolean = false;
  conversationId: string = '';
  turns: ChatTurn[] = [];

  private p: preferences.Preferences | null = null;
  private rev: number = 0;

  async init(ctx: common.Context): Promise<void> {
    if (this.p !== null) {
      return;
    }
    this.p = await preferences.getPreferences(ctx, 'hh_ai');
    this.baseUrl = (this.p.getSync('baseUrl', this.baseUrl) as string).trim();
    this.appKey = (this.p.getSync('appKey', '') as string).trim();
    this.personalOn = (this.p.getSync('personalOn', false) as boolean) === true;
    this.conversationId = this.p.getSync('conversationId', '') as string;
    let raw = this.p.getSync('turns', '[]') as string;
    try {
      this.turns = JSON.parse(raw) as ChatTurn[];
    } catch (e) {
      this.turns = [];
    }
    // 旧版本把失败提示也当消息存过；读到就丢掉，只留正常问答
    this.turns = this.turns.filter((t: ChatTurn): boolean =>
      !(t.role === 'ai' && t.failed === true));
    for (let t of this.turns) {
      if (t.citations === undefined) {
        t.citations = [];
      }
      for (let c of t.citations) {
        if (c.name.endsWith('.md')) {
          c.name = c.name.substring(0, c.name.length - 3);
        }
      }
    }
  }

  configured(): boolean {
    return this.appKey.length > 0 && this.baseUrl.length > 0;
  }

  // Dify 的 user 字段只用来分会话，不需要真实身份
  userTag(): string {
    let sn = MemoryStore.get().deviceSn;
    return sn.length > 0 ? 'hh-' + sn : 'hh-guest';
  }

  async saveSettings(base: string, key: string): Promise<void> {
    let b = base.trim();
    this.baseUrl = b.length > 0 ? b : this.baseUrl;
    this.appKey = key.trim();
    await this.persist();
    this.bump();
  }

  async setPersonal(on: boolean): Promise<void> {
    this.personalOn = on;
    await this.persist();
    this.bump();
  }

  async setConversation(id: string): Promise<void> {
    this.conversationId = id;
    await this.persist();
  }

  pushTurn(turn: ChatTurn): void {
    this.turns.push(turn);
    if (this.turns.length > 40) {
      this.turns = this.turns.slice(this.turns.length - 40);
    }
    this.saveTurns();
    this.bump();
  }

  async clearChat(): Promise<void> {
    this.turns = [];
    this.conversationId = '';
    await this.persist();
    this.bump();
  }

  private saveTurns(): void {
    if (this.p === null) {
      return;
    }
    this.p.put('turns', JSON.stringify(this.turns)).then((): void => {
      if (this.p !== null) {
        this.p.flush();
      }
    }).catch((e: Error): void => {
      console.warn('ai turns save: ' + e.message);
    });
  }

  private async persist(): Promise<void> {
    if (this.p === null) {
      return;
    }
    await this.p.put('baseUrl', this.baseUrl);
    await this.p.put('appKey', this.appKey);
    await this.p.put('personalOn', this.personalOn);
    await this.p.put('conversationId', this.conversationId);
    await this.p.put('turns', JSON.stringify(this.turns));
    await this.p.flush();
  }

  private bump(): void {
    this.rev++;
    AppStorage.setOrCreate('aiRev', this.rev);
  }
}
