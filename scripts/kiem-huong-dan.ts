// Kiểm tài liệu Hướng dẫn (A-23-42 phần 2). CHỈ CẢNH BÁO, báo số, luôn thoát 0 cho tới khi anh Trường OK đặt ngưỡng trượt.
//  1. [ẢNH: tên] không có tệp trong public/huong-dan/anh/ (đuôi png, webp, jpg, jpeg, gif, svg).
//  2. Bài ưu tiên P1 (frontmatter priority: P1) chưa có video trong public/huong-dan/video-manifest.json (mã = slug bài).
//  3. Chữ «…» trong bài (tên nút, nhãn màn) không còn xuất hiện trong src/ (chữ trên màn đã đổi hoặc bài sai).
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { metaFromSource } from '../src/pages/huong-dan/frontmatter.ts';

const DOCS = 'docs/huong-dan';
const IMG_DIR = 'public/huong-dan/anh';
const IMG_EXT = ['png', 'webp', 'jpg', 'jpeg', 'gif', 'svg'];
const SHOW = 15; // số dòng mẫu in ra mỗi loại (trình bày)

const walk = (dir: string, test: (name: string) => boolean): string[] =>
  readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(join(dir, e.name), test) : test(e.name) ? [join(dir, e.name)] : [],
  );

const guides = walk(DOCS, (n) => n.endsWith('.md')).map((p) => ({
  path: p,
  rel: relative(DOCS, p),
  text: readFileSync(p, 'utf8'),
}));

const missingImages: string[] = [];
for (const g of guides)
  for (const m of g.text.matchAll(/\[ẢNH:\s*([^\]]+)\]/g)) {
    const name = (m[1] ?? '').trim();
    if (!IMG_EXT.some((x) => existsSync(join(IMG_DIR, `${name}.${x}`))))
      missingImages.push(`${g.rel}: [ẢNH: ${name}]`);
  }

let manifest: Record<string, unknown> = {};
try {
  manifest =
    (
      JSON.parse(readFileSync('public/huong-dan/video-manifest.json', 'utf8')) as {
        videos?: Record<string, unknown>;
      }
    ).videos ?? {};
} catch {
  /* không có manifest: coi như chưa có video nào */
}
const noVideo: string[] = [];
for (const g of guides) {
  const meta = metaFromSource(g.rel, g.text);
  if (meta?.priority === 'P1' && !manifest[meta.slug])
    noVideo.push(`${g.rel} (mã video: ${meta.slug})`);
}

const srcText = walk('src', (n) => /\.(tsx?|json)$/.test(n) && !/\.test\./.test(n))
  .map((p) => readFileSync(p, 'utf8'))
  .join('\n')
  .toLowerCase();
const staleLabels: string[] = [];
for (const g of guides)
  for (const m of g.text.matchAll(/«([^»\n]{2,60})»/g)) {
    const label = (m[1] ?? '').trim();
    if (/[…<>]/.test(label)) continue; // chỗ giữ chỗ, không phải chữ cố định trên màn
    if (!srcText.includes(label.toLowerCase())) staleLabels.push(`${g.rel}: «${label}»`);
  }

const report = (title: string, list: string[]) => {
  console.log(`${list.length === 0 ? 'OK ' : 'CẢNH BÁO'} ${title}: ${list.length}`);
  for (const x of list.slice(0, SHOW)) console.log(`   - ${x}`);
  if (list.length > SHOW) console.log(`   … và ${list.length - SHOW} dòng nữa`);
};
report('ảnh được gọi nhưng thiếu tệp', missingImages);
report('bài P1 chưa có video trong manifest', noVideo);
report('chữ «…» trong bài không thấy trong src/', [...new Set(staleLabels)]);
console.log('(chỉ cảnh báo, không làm trượt CI)');
