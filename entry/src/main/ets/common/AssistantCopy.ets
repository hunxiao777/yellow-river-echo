// 河小导的"人话"文案层：AiService 抛回来的是技术错误，直接念给用户太硬。
// 这里按错误特征分组成一句口语主句 + 一行小字技术细节，
// 界面只负责排布，重试/去设置的入口都还在原来的位置上。

export interface ErrCopy {
  // 主句：河小导的口吻
  line: string;
  // 小字：原文错误，方便排错；不需要时给空串
  sub: string;
}

function has(s: string, needle: string): boolean {
  return s.indexOf(needle) >= 0;
}

export function errCopyOf(raw: string): ErrCopy {
  let t = (raw ?? '').trim();
  if (t.length === 0) {
    return { line: '河小导刚才走神了，再问一次试试。', sub: '' };
  }
  let low = t.toLowerCase();

  if (has(t, '回答已中断') || has(t, '已中断')) {
    return { line: '这段先放下了，想听的话再说一声。', sub: t };
  }
  if (has(t, '先在设置') || (has(t, 'App Key') && has(t, '地址'))) {
    return { line: '我还没连上档案室，先到设置里填好地址和 App Key。', sub: t };
  }
  if (has(t, '格式不对')) {
    return { line: '档案室的门牌号写错了，地址要以 http:// 或 https:// 开头。', sub: t };
  }
  if (has(t, 'App Key 无效') || has(t, '失效') || has(low, '401')) {
    return { line: '这把钥匙开不了门，到 Dify 重新复制一份 App Key 吧。', sub: t };
  }
  if (has(t, '地址不对') || has(low, '404')) {
    return { line: '按这个地址找不到档案室，确认填的是 Dify 的 /v1 地址。', sub: t };
  }
  if (has(low, '429') || has(t, '额度') || has(t, '太频繁')) {
    return { line: '档案室今天被问得太多，让我缓一缓，稍后再来。', sub: t };
  }
  if (has(low, 'timeout') || has(t, '超时') || has(t, '没有响应')) {
    return { line: '云端翻档案有点慢，先等几秒，或者换个短一点的问题。', sub: t };
  }
  if (has(low, 'resolve host') || has(low, 'offline') || has(low, 'network')
    || has(low, 'connection') || has(low, 'connect') || has(t, '连不上')) {
    return { line: '这会儿像是没网，河小导够不着云端档案。检查一下网络再试试？', sub: t };
  }
  if (has(t, '模型侧报错') || has(t, '模型没有返回')) {
    return { line: '档案室那边答不上来，我换个说法再试试。', sub: t };
  }
  if (has(t, '请求被拒')) {
    return { line: '这个问题被档案室挡回来了，换一种问法试试。', sub: t };
  }
  return { line: '河小导没听清这一下，再说一遍？', sub: t };
}
