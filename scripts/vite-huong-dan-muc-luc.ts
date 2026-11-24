// Plugin Vite (A-23-42): module ảo «virtual:huong-dan-muc-luc» = mục lục Hướng dẫn tự sinh từ phần đầu (frontmatter) của docs/huong-dan/**/*.md.
// Chỉ đọc phần đầu, không nhúng thân bài (thân bài vẫn tải theo từng mục). Sửa bài khi chạy dev thì mục lục tự cập nhật.
import { readdirSync, readFileSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import type { Plugin } from 'vite';
import {
  metaFromSource,
  sortGuideMetas,
  type GuideMeta,
} from '../src/pages/huong-dan/frontmatter.ts';

const VIRTUAL_ID = 'virtual:huong-dan-muc-luc';
const RESOLVED_ID = `\0${VIRTUAL_ID}`;

function listMarkdown(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory()
      ? listMarkdown(join(dir, e.name))
      : e.name.endsWith('.md')
        ? [join(dir, e.name)]
        : [],
  );
}

/** Đọc mục lục từ thư mục bài; tệp không có phần đầu (README, CHUP-ANH, bản kê…) bị bỏ qua. Slug trùng thì báo lỗi. */
export function buildGuideIndex(root: string): GuideMeta[] {
  const metas: GuideMeta[] = [];
  for (const path of listMarkdown(root).sort()) {
    const file = relative(root, path).split(sep).join('/');
    const meta = metaFromSource(file, readFileSync(path, 'utf8'));
    if (meta) metas.push(meta);
  }
  const seen = new Map<string, string>();
  for (const m of metas) {
    const other = seen.get(m.slug);
    if (other) throw new Error(`Hai bài cùng slug «${m.slug}»: ${other} và ${m.file}`);
    seen.set(m.slug, m.file);
  }
  return sortGuideMetas(metas);
}

export function huongDanMucLuc(root = 'docs/huong-dan'): Plugin {
  return {
    name: 'hmt-huong-dan-muc-luc',
    resolveId: (id) => (id === VIRTUAL_ID ? RESOLVED_ID : null),
    load(id) {
      if (id !== RESOLVED_ID) return null;
      for (const path of listMarkdown(root)) this.addWatchFile(join(process.cwd(), path));
      return `export default ${JSON.stringify(buildGuideIndex(root))};`;
    },
    configureServer(server) {
      server.watcher.add(root);
      const refresh = (path: string) => {
        if (!path.includes('docs/huong-dan') || !path.endsWith('.md')) return;
        const mod = server.moduleGraph.getModuleById(RESOLVED_ID);
        if (mod) server.moduleGraph.invalidateModule(mod);
      };
      server.watcher.on('add', refresh).on('change', refresh).on('unlink', refresh);
    },
  };
}
