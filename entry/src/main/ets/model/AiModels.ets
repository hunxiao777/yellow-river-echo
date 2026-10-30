// 河小导（Dify 客户端）的数据形状。
// 只保留页面要用的字段，Dify 返回的其余内容不落库。

export interface Citation {
  siteId: string;
  name: string;
  score: number;
  snippet: string;
}

export interface ChatTurn {
  role: string; // 'user' | 'ai'
  text: string;
  at: number;
  citations: Citation[];
  failed: boolean;
}

export interface DifyInputs {
  personal_context: string;
}

export interface DifyReq {
  inputs: DifyInputs;
  query: string;
  response_mode: string;
  conversation_id: string;
  user: string;
}

export interface RetrieverRes {
  document_name?: string;
  content?: string;
  score?: number;
}

export interface DifyMeta {
  retriever_resources?: RetrieverRes[];
}

export interface DifyChatResp {
  answer?: string;
  conversation_id?: string;
  message_id?: string;
  metadata?: DifyMeta;
}

export interface DifyError {
  code?: string;
  message?: string;
  status?: number;
}
