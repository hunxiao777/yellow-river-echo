import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Citation, DifyChatResp, DifyError, DifyReq, RetrieverRes } from '../model/AiModels';
import { AiStore } from './AiStore';
import { SiteRepo } from './SiteRepo';
import { cleanAiText } from '../common/Markdown';

export interface AiReply {
  ok: boolean;
  answer: string;
  citations: Citation[];
  error: string;
}

// Dify 客户端的 M0 版本：阻塞式问答，先把链路和错误处理跑通。
// 流式（SSE）与打字机效果留到 M1，接口形状保持一致。
export class AiService {
  private static readonly inst: AiService = new AiService();
  static get(): AiService {
    return AiService.inst;
  }

  async ask(query: string, personalContext: string): Promise<AiReply> {
    let store = AiStore.get();
    if (!store.configured()) {
      return { ok: false, answer: '', citations: [], error: '先在设置里填写 Dify 地址和 App Key' };
    }
    let url = this.endpoint(store.baseUrl);
    if (url.length === 0) {
      return { ok: false, answer: '', citations: [], error: '接口地址格式不对，应以 http:// 或 https:// 开头' };
    }

    let body: DifyReq = {
      inputs: { personal_context: personalContext },
      query: query,
      response_mode: 'blocking',
      conversation_id: store.conversationId,
      user: store.userTag()
    };
    let header: Record<string, string> = {
      'Authorization': 'Bearer ' + store.appKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    let req = http.createHttp();
    try {
      let resp = await req.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 90000
      });
      let raw = resp.result as string;
      if (resp.responseCode !== 200) {
        return { ok: false, answer: '', citations: [], error: this.errorOf(resp.responseCode, raw) };
      }
      let data = JSON.parse(raw) as DifyChatResp;
      let answer = cleanAiText(data.answer ?? '');
      if (answer.length === 0) {
        return { ok: false, answer: '', citations: [], error: '模型没有返回内容，稍后再试' };
      }
      if ((data.conversation_id ?? '').length > 0) {
        await store.setConversation(data.conversation_id as string);
      }
      return { ok: true, answer: answer, citations: this.citationsOf(data), error: '' };
    } catch (e) {
      let be = e as BusinessError;
      let msg = be.message ?? '';
      return { ok: false, answer: '', citations: [], error: '网络不通或超时：' + msg };
    } finally {
      req.destroy();
    }
  }

  // 用户可能只填到域名，也可能已经带了 /v1，这里统一补齐到 /v1
  private endpoint(base: string): string {
    let b = base.trim();
    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      return '';
    }
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (!b.endsWith('/v1')) {
      b = b + '/v1';
    }
    return b + '/chat-messages';
  }

  private errorOf(code: number, raw: string): string {
    let detail = '';
    try {
      let err = JSON.parse(raw) as DifyError;
      detail = err.message ?? '';
    } catch (e) {
      detail = '';
    }
    if (code === 401) {
      return 'App Key 无效或已失效，请到 Dify 重新复制';
    }
    if (code === 404) {
      return '地址不对：确认填的是 Dify 的 /v1 地址';
    }
    if (code === 429) {
      return '调用太频繁，或该 Key 的额度用完了';
    }
    if (code === 400 && detail.length > 0) {
      return '请求被拒：' + detail;
    }
    return '服务返回 ' + code + (detail.length > 0 ? '：' + detail : '');
  }

  private citationsOf(data: DifyChatResp): Citation[] {
    let out: Citation[] = [];
    let list = data.metadata?.retriever_resources;
    if (list === undefined) {
      return out;
    }
    for (let r of list) {
      this.addCitation(out, r);
    }
    return out;
  }

  private addCitation(out: Citation[], r: RetrieverRes): void {
    let doc = r.document_name ?? '';
    if (doc.length === 0) {
      return;
    }
    let siteId = this.siteIdOf(doc);
    let site = siteId.length > 0 ? SiteRepo.get().byId(siteId) : undefined;
    let name = site !== undefined ? site.name : doc;
    if (site === undefined && name.endsWith('.md')) {
      name = name.substring(0, name.length - 3);
    }
    for (let c of out) {
      if (c.siteId === siteId && c.name === name) {
        return;
      }
    }
    let snippet = cleanAiText(r.content ?? '');
    if (snippet.length > 56) {
      snippet = snippet.substring(0, 56) + '…';
    }
    out.push({
      siteId: siteId,
      name: name,
      score: r.score ?? 0,
      snippet: snippet
    });
  }

  // 知识库文件名约定为「s01-庙底沟遗址.md」，引用回跳时只认 siteId
  private siteIdOf(doc: string): string {
    let name = doc.trim();
    if (name.endsWith('.md')) {
      name = name.substring(0, name.length - 3);
    }
    let dash = name.indexOf('-');
    if (dash > 0) {
      let head = name.substring(0, dash);
      if (SiteRepo.get().byId(head) !== undefined) {
        return head;
      }
    }
    if (SiteRepo.get().byId(name) !== undefined) {
      return name;
    }
    for (let s of SiteRepo.get().sites) {
      if (name.indexOf(s.name) >= 0) {
        return s.id;
      }
    }
    return '';
  }
}
