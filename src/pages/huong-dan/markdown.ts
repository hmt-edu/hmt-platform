// Bộ phân tích markdown nhỏ cho trang Hướng dẫn (A-23-30). Chỉ hỗ trợ phần tài liệu docs/huong-dan/ đang dùng:
// tiêu đề #..####, đoạn, danh sách gạch đầu dòng và đánh số (lồng một cấp bằng thụt hai chữ), bảng, khối mã, đường kẻ, trích dẫn.
// Trong dòng: **đậm**, `mã`, [chữ](đường dẫn), [ẢNH: tên], [VIDEO: tên]. Không chạy HTML thô (an toàn: mọi chữ được đưa ra dạng văn bản).

export type Inline =
  | { kind: 'text'; text: string }
  | { kind: 'bold'; text: string }
  | { kind: 'code'; text: string }
  | { kind: 'link'; text: string; href: string }
  | { kind: 'image'; name: string }
  | { kind: 'video'; name: string };

export type ListItem = { inline: Inline[]; children: ListItem[] };

export type Block =
  | { kind: 'heading'; level: 1 | 2 | 3 | 4; id: string; inline: Inline[]; text: string }
  | { kind: 'paragraph'; inline: Inline[] }
  | { kind: 'list'; ordered: boolean; items: ListItem[] }
  | { kind: 'table'; header: Inline[][]; rows: Inline[][][] }
  | { kind: 'code'; text: string }
  | { kind: 'quote'; inline: Inline[] }
  | { kind: 'rule' };

const INLINE_RE =
  /\*\*([^*]+)\*\*|`([^`]+)`|\[ẢNH:\s*([^\]]+)\]|\[VIDEO:\s*([^\]]+)\]|\[([^\]]+)\]\(([^)\s]+)\)/g;

/** Chỉ cho đường dẫn nội bộ (/…) hoặc https://; còn lại (javascript:, data:…) bỏ thành chữ thường. */
export function safeHref(href: string): string | null {
  if (href.startsWith('/') && !href.startsWith('//')) return href;
  if (href.startsWith('https://')) return href;
  return null;
}

export function parseInline(src: string): Inline[] {
  const out: Inline[] = [];
  let last = 0;
  for (const m of src.matchAll(INLINE_RE)) {
    const at = m.index ?? 0;
    if (at > last) out.push({ kind: 'text', text: src.slice(last, at) });
    if (m[1] !== undefined) out.push({ kind: 'bold', text: m[1] });
    else if (m[2] !== undefined) out.push({ kind: 'code', text: m[2] });
    else if (m[3] !== undefined) out.push({ kind: 'image', name: m[3].trim() });
    else if (m[4] !== undefined) out.push({ kind: 'video', name: m[4].trim() });
    else if (m[5] !== undefined && m[6] !== undefined) {
      const href = safeHref(m[6]);
      out.push(href ? { kind: 'link', text: m[5], href } : { kind: 'text', text: m[5] });
    }
    last = at + m[0].length;
  }
  if (last < src.length) out.push({ kind: 'text', text: src.slice(last) });
  return out;
}

/** Chữ thuần của một dòng (bỏ dấu định dạng): dùng cho tiêu đề, mã neo, tìm kiếm. */
export function inlineText(inline: Inline[]): string {
  return inline
    .map((i) => {
      if (i.kind === 'image') return '';
      if (i.kind === 'video') return '';
      return i.text;
    })
    .join('');
}

/** Mã neo từ tiêu đề: chữ thường, bỏ dấu tiếng Việt, gạch nối. */
export function slugify(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

const LIST_RE = /^(\s*)([-*]|\d+[.)])\s+(.*)$/;
const TABLE_SEP_RE = /^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?$/;

function splitRow(line: string): string[] {
  return line
    .trim()
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map((c) => c.trim());
}

export function parseMarkdown(src: string): Block[] {
  const lines = src.replace(/\r\n/g, '\n').split('\n');
  const blocks: Block[] = [];
  const usedIds = new Map<string, number>();
  let i = 0;

  while (i < lines.length) {
    const line = lines[i] ?? '';
    if (line.trim() === '') {
      i += 1;
      continue;
    }
    // Khối mã.
    if (line.trim().startsWith('```')) {
      const body: string[] = [];
      i += 1;
      while (i < lines.length && !(lines[i] ?? '').trim().startsWith('```')) {
        body.push(lines[i] ?? '');
        i += 1;
      }
      i += 1;
      blocks.push({ kind: 'code', text: body.join('\n') });
      continue;
    }
    const heading = /^(#{1,4})\s+(.*)$/.exec(line);
    if (heading) {
      const inline = parseInline((heading[2] ?? '').trim());
      const text = inlineText(inline);
      let id = slugify(text) || 'muc';
      const seen = usedIds.get(id) ?? 0;
      usedIds.set(id, seen + 1);
      if (seen > 0) id = `${id}-${seen + 1}`;
      blocks.push({
        kind: 'heading',
        level: (heading[1] ?? '#').length as 1 | 2 | 3 | 4,
        id,
        inline,
        text,
      });
      i += 1;
      continue;
    }
    if (/^(-{3,}|\*{3,})\s*$/.test(line)) {
      blocks.push({ kind: 'rule' });
      i += 1;
      continue;
    }
    // Bảng: dòng tiêu đề, dòng kẻ, các dòng thân.
    if (line.includes('|') && TABLE_SEP_RE.test((lines[i + 1] ?? '').trim())) {
      const header = splitRow(line).map(parseInline);
      i += 2;
      const rows: Inline[][][] = [];
      while (i < lines.length && (lines[i] ?? '').includes('|') && (lines[i] ?? '').trim() !== '') {
        rows.push(splitRow(lines[i] ?? '').map(parseInline));
        i += 1;
      }
      blocks.push({ kind: 'table', header, rows });
      continue;
    }
    if (line.startsWith('>')) {
      const parts: string[] = [];
      while (i < lines.length && (lines[i] ?? '').startsWith('>')) {
        parts.push((lines[i] ?? '').replace(/^>\s?/, ''));
        i += 1;
      }
      blocks.push({ kind: 'quote', inline: parseInline(parts.join(' ')) });
      continue;
    }
    const first = LIST_RE.exec(line);
    if (first) {
      const ordered = /\d/.test(first[2] ?? '');
      const baseIndent = (first[1] ?? '').length;
      const items: ListItem[] = [];
      while (i < lines.length) {
        const cur = lines[i] ?? '';
        const m = LIST_RE.exec(cur);
        if (!m) {
          // dòng nối tiếp (thụt vào, không phải mục mới): ghép vào mục cuối
          if (cur.trim() !== '' && /^\s+/.test(cur) && items.length > 0) {
            const lastItem = items[items.length - 1];
            const tail = lastItem?.children[lastItem.children.length - 1] ?? lastItem;
            if (tail) tail.inline.push(...parseInline(` ${cur.trim()}`));
            i += 1;
            continue;
          }
          break;
        }
        const indent = (m[1] ?? '').length;
        const item: ListItem = { inline: parseInline(m[3] ?? ''), children: [] };
        if (indent > baseIndent && items.length > 0) items[items.length - 1]?.children.push(item);
        else if (indent < baseIndent) break;
        else items.push(item);
        i += 1;
      }
      blocks.push({ kind: 'list', ordered, items });
      continue;
    }
    // Đoạn: gom các dòng liền nhau.
    const para: string[] = [];
    while (
      i < lines.length &&
      (lines[i] ?? '').trim() !== '' &&
      !/^(#{1,4})\s/.test(lines[i] ?? '') &&
      !LIST_RE.test(lines[i] ?? '') &&
      !(lines[i] ?? '').trim().startsWith('```')
    ) {
      para.push((lines[i] ?? '').trim());
      i += 1;
    }
    blocks.push({ kind: 'paragraph', inline: parseInline(para.join(' ')) });
  }
  return blocks;
}

/** Mục lục: các tiêu đề cấp 2 và 3 của một tài liệu. */
export function outline(blocks: Block[]): { id: string; text: string; level: 2 | 3 }[] {
  const out: { id: string; text: string; level: 2 | 3 }[] = [];
  for (const b of blocks) {
    if (b.kind === 'heading' && (b.level === 2 || b.level === 3))
      out.push({ id: b.id, text: b.text, level: b.level });
  }
  return out;
}

/** Chữ thuần của cả tài liệu, dùng cho tìm kiếm. */
export function plainText(blocks: Block[]): string {
  const parts: string[] = [];
  const addItems = (items: ListItem[]) => {
    for (const it of items) {
      parts.push(inlineText(it.inline));
      addItems(it.children);
    }
  };
  for (const b of blocks) {
    if (b.kind === 'heading') parts.push(b.text);
    else if (b.kind === 'paragraph' || b.kind === 'quote') parts.push(inlineText(b.inline));
    else if (b.kind === 'list') addItems(b.items);
    else if (b.kind === 'table') {
      parts.push(b.header.map(inlineText).join(' '));
      for (const r of b.rows) parts.push(r.map(inlineText).join(' '));
    } else if (b.kind === 'code') parts.push(b.text);
  }
  return parts.join('\n');
}
