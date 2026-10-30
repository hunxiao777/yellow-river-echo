// 模型回复的轻量清洗：ArkUI 没有 Markdown 渲染器，
// 直接上屏会满屏星号、井号和竖线。这里只去掉标记，保留文字的层次感。

const TABLE_SEP = /^\s*\|?[\s:|-]*-{2,}[\s:|-]*\|?\s*$/;
const BULLET = /^(\s*)[-*+]\s+/;
const HEADING = /^#{1,6}\s*/;
const QUOTE = /^>\s?/;
const HR = /^\s*([-*_])\1{2,}\s*$/;

function cleanLine(raw: string): string {
  let line = raw.replace(/\s+$/, '');
  if (HR.test(line)) {
    return '';
  }
  if (line.indexOf('|') >= 0 && TABLE_SEP.test(line)) {
    return '';
  }
  if (line.length > 0 && line.charAt(0) === '|') {
    let body = line;
    if (body.charAt(body.length - 1) === '|') {
      body = body.substring(0, body.length - 1);
    }
    body = body.substring(1);
    let cells = body.split('|');
    let out: string[] = [];
    for (let c of cells) {
      let v = c.trim();
      if (v.length > 0) {
        out.push(v);
      }
    }
    return out.join(' ｜ ');
  }
  line = line.replace(HEADING, '');
  line = line.replace(QUOTE, '');
  line = line.replace(BULLET, '· ');
  return line;
}

function cleanInline(raw: string): string {
  let t = raw;
  t = t.replace(/```[^\n]*\n?/g, '');
  t = t.replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1');
  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1（$2）');
  t = t.replace(/<br\s*\/?>/gi, '\n');
  t = t.replace(/<\/?[a-zA-Z][^>]*>/g, '');
  t = t.replace(/\*\*([^*]+)\*\*/g, '$1');
  t = t.replace(/__([^_]+)__/g, '$1');
  t = t.replace(/(^|[^*])\*([^*\n]+)\*/g, '$1$2');
  t = t.replace(/(^|[^_])_([^_\n]+)_/g, '$1$2');
  t = t.replace(/`([^`]+)`/g, '$1');
  t = t.replace(/`/g, '');
  return t;
}

export function cleanAiText(raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  let text = raw.replace(/\r\n/g, '\n');
  let lines = text.split('\n');
  let kept: string[] = [];
  for (let line of lines) {
    kept.push(cleanLine(line));
  }
  text = kept.join('\n');
  text = cleanInline(text);
  text = text.replace(/[ \t]+\n/g, '\n');
  text = text.replace(/\n{3,}/g, '\n\n');
  return text.trim();
}
