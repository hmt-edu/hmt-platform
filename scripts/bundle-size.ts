// Đo dung lượng tải (nén gzip) của từng cổng, màn từ bản kê gói của Vite (dist/.vite/manifest.json).
// Chạy sau `npm run build`. Chỉ BÁO số liệu, chưa có ngưỡng: ngưỡng do anh Trường quyết sau khi xem số đo
// (CLAUDE.md, Hiệu năng). Truyền --max-kb=<số> để thử ngưỡng cho "Trang đầu cổng CRM"; không truyền thì không bao giờ trượt.
import { readFileSync, existsSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import { join } from 'node:path';

const dist = 'dist';
const manifestPath = join(dist, '.vite', 'manifest.json');
if (!existsSync(manifestPath)) {
  console.error('Chưa có dist/.vite/manifest.json. Chạy npm run build trước.');
  process.exit(2);
}
type Chunk = { file: string; css?: string[]; imports?: string[]; isEntry?: boolean };
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as Record<string, Chunk>;
const gz = (file: string) => gzipSync(readFileSync(join(dist, file))).length;

// Mọi gói và CSS cần để mở một điểm vào: điểm vào + các gói nó import tĩnh (đệ quy).
function closure(keys: string[]): Set<string> {
  const seen = new Set<string>();
  const files = new Set<string>();
  const visit = (key: string): void => {
    const chunk = manifest[key];
    if (seen.has(key) || !chunk) return;
    seen.add(key);
    files.add(chunk.file);
    for (const css of chunk.css ?? []) files.add(css);
    for (const imp of chunk.imports ?? []) visit(imp);
  };
  keys.forEach(visit);
  return files;
}
const find = (suffix: string): string | undefined =>
  Object.keys(manifest).find((k) => k.endsWith(suffix));
const entry = Object.keys(manifest).find((k) => manifest[k]?.isEntry);
if (!entry) {
  console.error('Không thấy điểm vào trong bản kê gói.');
  process.exit(2);
}

const screens: [string, string[]][] = [
  ['Đăng nhập', ['pages/auth/LoginPages.tsx']],
  [
    'Trang đầu cổng CRM (khung + trang chủ)',
    ['layout/CrmShell.tsx', 'pages/common/PortalPages.tsx'],
  ],
  ['Cổng Giáo viên (khung + trang đầu)', ['layout/TabShell.tsx', 'pages/common/PortalPages.tsx']],
  ['Cổng Học tập (khung + trang đầu)', ['layout/TabShell.tsx', 'pages/common/PortalPages.tsx']],
  [
    'Màn danh sách mẫu /dev/danh-sach (thêm vào khung CRM)',
    ['layout/CrmShell.tsx', 'pages/dev/ListDemoPage.tsx'],
  ],
];

const rows: { name: string; kb: number; files: number }[] = [];
for (const [name, suffixes] of screens) {
  const keys = [entry, ...suffixes.map(find).filter((k): k is string => k !== undefined)];
  const files = closure(keys);
  const total = [...files].reduce((sum, f) => sum + gz(f), 0);
  rows.push({ name, kb: total / 1024, files: files.size });
}
console.log('Dung lượng tải nén (gzip), gồm gói điểm vào + CSS:');
for (const r of rows)
  console.log(`  ${r.kb.toFixed(0).padStart(4)} KB  ${r.name} (${r.files} tệp)`);

const argMax = process.argv.find((a) => a.startsWith('--max-kb='));
if (argMax) {
  const max = Number(argMax.split('=')[1]);
  const crm = rows.find((r) => r.name.startsWith('Trang đầu cổng CRM'));
  if (crm && crm.kb > max) {
    console.error(`Trang đầu cổng CRM ${crm.kb.toFixed(0)} KB vượt ngưỡng ${max} KB.`);
    process.exit(1);
  }
}
