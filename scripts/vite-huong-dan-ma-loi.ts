// Plugin Vite (A-23-42 phần 3): module ảo «virtual:huong-dan-ma-loi» = bảng tra MÃ LỖI HMT_* tự sinh từ supabase/migrations,
// kèm các bài hướng dẫn có nhắc mã đó. Chỉ tải khi mở trang «Tra mã lỗi»; không có bản chép tay nào để lệch với DB.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Plugin } from 'vite';
import { metaFromSource } from '../src/pages/huong-dan/frontmatter.ts';

const VIRTUAL_ID = 'virtual:huong-dan-ma-loi';
const RESOLVED_ID = `\0${VIRTUAL_ID}`;

export type ErrorCodeEntry = {
  code: string;
  /** Câu tiếng Việt giao diện hiện cho mã này (mới nhất trước, bỏ trùng, tối đa vài câu). */
  messages: string[];
  /** Bài hướng dẫn có nhắc mã này. */
  guides: { slug: string; title: string }[];
};

const CODE_RE = /\bHMT_[A-Z0-9_]+\b/g;
const RAISE_RE = /raise_error\(\s*'(HMT_[A-Z0-9_]+)'\s*,\s*'((?:[^']|'')*)'/g;
const MAX_MESSAGES = 3; // allow-number: số câu mẫu tối đa hiện cho một mã (trình bày)

function listFiles(dir: string, ext: string): string[] {
  return readdirSync(dir, { withFileTypes: true })
    .sort((a, b) => a.name.localeCompare(b.name))
    .flatMap((e) =>
      e.isDirectory()
        ? listFiles(join(dir, e.name), ext)
        : e.name.endsWith(ext)
          ? [join(dir, e.name)]
          : [],
    );
}

/** Quét migration (cũ → mới) rồi bài hướng dẫn; trả danh sách mã theo thứ tự chữ cái. */
export function buildErrorCodes(migrationsDir: string, guideRoot: string): ErrorCodeEntry[] {
  const byCode = new Map<string, ErrorCodeEntry>();
  const entry = (code: string): ErrorCodeEntry => {
    let e = byCode.get(code);
    if (!e) byCode.set(code, (e = { code, messages: [], guides: [] }));
    return e;
  };

  for (const path of listFiles(migrationsDir, '.sql')) {
    const text = readFileSync(path, 'utf8');
    for (const m of text.matchAll(CODE_RE)) entry(m[0]);
    for (const m of text.matchAll(RAISE_RE)) {
      const msg = (m[2] ?? '').replace(/''/g, "'").trim();
      const e = entry(m[1] ?? '');
      if (msg && !e.messages.includes(msg)) e.messages.unshift(msg); // bản mới ở đầu
    }
  }
  for (const e of byCode.values()) e.messages = e.messages.slice(0, MAX_MESSAGES);

  for (const path of listFiles(guideRoot, '.md')) {
    const rel = path.slice(guideRoot.length + 1);
    const text = readFileSync(path, 'utf8');
    const meta = metaFromSource(rel, text);
    if (!meta || meta.slug === 'tra-ma-loi') continue;
    for (const m of new Set(text.match(CODE_RE) ?? [])) {
      const e = byCode.get(m);
      if (e && !e.guides.some((g) => g.slug === meta.slug))
        e.guides.push({ slug: meta.slug, title: meta.title });
    }
  }
  return [...byCode.values()].sort((a, b) => a.code.localeCompare(b.code));
}

export function huongDanMaLoi(
  migrationsDir = 'supabase/migrations',
  guideRoot = 'docs/huong-dan',
): Plugin {
  return {
    name: 'hmt-huong-dan-ma-loi',
    resolveId: (id) => (id === VIRTUAL_ID ? RESOLVED_ID : null),
    load(id) {
      if (id !== RESOLVED_ID) return null;
      return `export default ${JSON.stringify(buildErrorCodes(migrationsDir, guideRoot))};`;
    },
  };
}
