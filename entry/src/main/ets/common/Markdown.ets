// 模型回复的轻量清洗：ArkUI 没有 Markdown 渲染器，
// 直接上屏会满屏星号、井号和竖线。这里只去掉标记，保留文字的层次感。

const TABLE_SEP = /^\s*\|?[\s:|-]*-{2,}[\s:|-]*\|?\s*$/;
const BULLET = /^(\s*)[-*+]\s+/;
const HEADING = /^#{1,6}\s*/;
const QUOTE = /^>\s?/;
const HR = /^\s*([-*_])\1{2,}\s*$/;

// 表格的 |---| 分隔行要整行丢掉，不能变成空行，否则表头和数据之间会空一大截
const DROP = '\u0001';

function cleanLine(raw: string): string {
  let line = raw.replace(/\s+$/, '');
  if (HR.test(line)) {
    return '';
  }
  if (line.indexOf('|') >= 0 && TABLE_SEP.test(line)) {
    return DROP;
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

// 流式阶段用：完整行照常清洗，最后半行只把标记符号按字符抹掉。
// 半行不能走整行规则（比如 ** 还没闭合），否则会闪出星号又消失。
function cleanTail(raw: string): string {
  let line = raw.replace(/\r?\n/g, ' ');
  line = line.replace(HEADING, '');
  line = line.replace(QUOTE, '');
  line = line.replace(BULLET, '· ');
  if (line.length > 0 && line.charAt(0) === '|') {
    line = line.substring(1);
  }
  line = line.replace(/\|/g, ' ｜ ');
  line = line.replace(/[*_`#]/g, '');
  return line;
}

export function cleanAiText(raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  let text = raw.replace(/\r\n/g, '\n');
  let lines = text.split('\n');
  let kept: string[] = [];
  for (let line of lines) {
    let c = cleanLine(line);
    if (c !== DROP) {
      kept.push(c);
    }
  }
  text = kept.join('\n');
  text = cleanInline(text);
  text = text.replace(/[ \t]+\n/g, '\n');
  text = text.replace(/\n{3,}/g, '\n\n');
  return text.trim();
}

// 流式增量渲染用的版本：已收完整行按正式规则清洗，未完的半行做保守抹标记。
export function cleanPartial(raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  let text = raw.replace(/\r\n/g, '\n');
  let cut = text.lastIndexOf('\n');
  if (cut < 0) {
    return cleanTail(text);
  }
  let stable = cleanAiText(text.substring(0, cut));
  let tail = cleanTail(text.substring(cut + 1));
  if (tail.length === 0) {
    return stable;
  }
  return stable.length === 0 ? tail : stable + '\n' + tail;
}
