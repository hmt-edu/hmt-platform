// Dựng docs/ke-hoach/man-hinh-theo-trang-thai.md: mỗi mã màn trong docs/design/ban-do-man-hinh.md một dòng: có code (đường dẫn), canvas, e2e, ai giữ.
// Chạy: node scripts/man-hinh-theo-trang-thai.ts   (chỉ ĐỌC repo, ghi một file tài liệu). «Có code» suy từ: mục menu CRM (src/nav/crmMenu.ts, mã -> đường dẫn có tuyến thật
// ở src/app/routes.tsx), hoặc mã màn nhắc ở đầu file trong src/. «Canvas» = có file khung design/**/<MÃ không gạch>*.dc.html. «Đúng canvas» KHÔNG suy tự động: ghi «chưa kiểm»
// trừ các màn đã đối chiếu tay (bảng kết quả ở docs/nghiep-vu/doi-chieu-ui-dao-tao.md, doi-chieu-cot-gop.md, doi-chieu-menu-canvas.md).
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const read = (p: string): string => readFileSync(p, 'utf8');
const walk = (dir: string, out: string[] = []): string[] => {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
};

// 1. Mã màn từ bản đồ màn hình.
type Row = { code: string; name: string; kind: string; level: string };
const rows: Row[] = [];
for (const line of read('docs/design/ban-do-man-hinh.md').split('\n')) {
  const cells = line.split('|').map((c) => c.trim());
  if (cells.length < 6) continue;
  const code = cells[1] ?? '';
  if (!/^[A-Z]+-\d+[A-Za-z]*$/.test(code)) continue;
  rows.push({ code, name: cells[2] ?? '', kind: cells[3] ?? '', level: cells[4] ?? '' });
}

// 2. Mục menu: mã -> slug; tuyến có thật.
const menu = read('src/nav/crmMenu.ts');
const slugOf = new Map<string, string>();
for (const m of menu.matchAll(
  /code: '([A-Z]+-\d+[A-Za-z]*)',\s*label: '[^']+',\s*slug: '([^']*)'/g,
))
  slugOf.set(m[1] ?? '', m[2] ?? '');
for (const m of menu.matchAll(/\{ code: '([A-Z]+-\d+[A-Za-z]*)', label: '[^']+', slug: '([^']*)'/g))
  slugOf.set(m[1] ?? '', m[2] ?? '');
const routes = read('src/app/routes.tsx');
const hasRoute = (slug: string): boolean =>
  routes.includes(`path: '${slug}'`) ||
  routes.includes(`path: "${slug}"`) ||
  routes.includes(`slug="${slug}"`) ||
  routes.includes(`slug: '${slug}'`);

// 3. Mã nhắc ở đầu file nguồn (12 dòng đầu), ưu tiên tên file trang.
const srcFiles = walk('src').filter((f) => /\.(tsx?|ts)$/.test(f) && !/\.test\./.test(f));
const mention = new Map<string, { file: string; page: boolean }>();
for (const f of srcFiles) {
  const head = read(f).split('\n').slice(0, 12).join('\n');
  for (const m of head.matchAll(/\b([A-Z]{2,5}-\d+[A-Za-z]*)\b/g)) {
    const code = m[1] ?? '';
    const prev = mention.get(code);
    const isPage = /Page\.tsx$|Dialog|Form/.test(f);
    if (!prev || (isPage && !prev.page)) mention.set(code, { file: f, page: isPage });
  }
}

// 3b. Dự phòng: mã nhắc ở chỗ khác trong file nguồn (không phải menu, không phải bài kiểm thử): ghi «nhắc» để người giữ xác nhận.
const anywhere = new Map<string, string>();
for (const f of srcFiles) {
  if (f.startsWith('src/nav/') || f.startsWith('src/pages/dev/')) continue;
  const text = read(f);
  for (const m of text.matchAll(/\b([A-Z]{2,5}-\d+[A-Za-z]*)\b/g))
    if (!anywhere.has(m[1] ?? '')) anywhere.set(m[1] ?? '', f);
}

// 4. e2e nhắc mã.
const e2e = walk('e2e')
  .filter((f) => f.endsWith('.spec.ts'))
  .map((f): [string, string] => [f, read(f)]);
const e2eOf = (code: string): string[] =>
  e2e
    .filter(([, t]) => t.includes(code))
    .map(([f]) => f.replace('e2e/', ''))
    .slice(0, 2);

// 5. Khung canvas theo mã (TS-01 -> TS01*, GD-07 -> GD07*).
const canvasFiles = walk('design')
  .filter((f) => f.endsWith('.dc.html'))
  .map((f) => f.split('/').pop() ?? '');
const canvasOf = (code: string): number => {
  const k = code.replace('-', '');
  return canvasFiles.filter(
    (n) => n.toUpperCase().startsWith(k.toUpperCase()) && /^[A-Za-z]+\d+[a-z]?(_|\.)/.test(n),
  ).length;
};

// 6. Người giữ theo tiền tố (gần đúng, theo phân vùng làn 18/11; xem HANG-DOI.md).
const LANE: [RegExp, string][] = [
  [/^(GD|LOP|BUOI)-/, 'Code A'],
  [/^(CS|AS)-/, 'Code B'],
  [/^(BH|TT)-/, 'Code C'],
  [/^TC-/, 'Code C/D'],
  [/^GV-/, 'Code E'],
  [/^(QT|CH|CHUNG|BC)-/, 'Code F'],
  [/^(TS|KH)-/, 'Code ?'],
  [/^(HT|PH)-/, 'giai đoạn sau'],
];
const lane = (code: string): string => LANE.find(([re]) => re.test(code))?.[1] ?? '?';

// 7. Màn đã đối chiếu tay với canvas (kết quả khớp) từ các bảng đối chiếu.
const CHECKED_OK = new Set([
  'GD-01',
  'GD-06',
  'BUOI-01',
  'BUOI-10',
  'BUOI-12',
  'TS-01',
  'TS-07',
  'TS-11',
  'BH-01',
  'BH-06',
  'CS-01',
  'CHUNG-15',
  'TT-01',
  'BC-08',
  'BC-09',
]);
const CHECKED_FIXED = new Set(['LOP-01', 'GD-07', 'TS-16', 'BUOI-15']);

let have = 0;
let missing = 0;
const table: string[] = [];
const out: string[] = [];
for (const r of rows) {
  const slug = slugOf.get(r.code);
  const m = mention.get(r.code);
  let where = '';
  if (slug !== undefined && hasRoute(slug === '' ? '' : slug))
    where = slug === '' ? '/crm' : `/crm/${slug}`;
  if (!where && m) where = m.file;
  let hint = false;
  if (!where && anywhere.has(r.code)) {
    where = anywhere.get(r.code) ?? '';
    hint = true;
  }
  const e = e2eOf(r.code);
  const canvas = canvasOf(r.code);
  const right = CHECKED_OK.has(r.code)
    ? 'có'
    : CHECKED_FIXED.has(r.code)
      ? 'có (đã sửa theo canvas)'
      : 'chưa kiểm';
  if (where) have++;
  else missing++;
  table.push(
    `| ${r.code} | ${r.name} | ${r.level} | ${where ? '`' + where + '`' + (hint ? ' (nhắc, chưa chắc là màn)' : '') : '**chưa có**'} | ${canvas > 0 ? `có (${canvas} khung)` : 'không có khung'} | ${right} | ${e.length ? e.join(', ') : '—'} | ${lane(r.code)} |`,
  );
}
out.push('# Màn hình theo trạng thái (sinh tự động)');
out.push('');
out.push(
  `Sinh bằng \`node scripts/man-hinh-theo-trang-thai.ts\` từ \`docs/design/ban-do-man-hinh.md\`, \`src/nav/crmMenu.ts\`, \`src/app/routes.tsx\`, đầu file trong \`src/\`, \`e2e/\`, \`design/\`. **${rows.length} mã màn: ${have} có code, ${missing} chưa có.**`,
);
out.push('');
out.push(
  'Cách đọc: «Có code» = mục menu có tuyến thật, hoặc mã màn được nhắc ở đầu một file trong `src/` (đường dẫn file; có thể là hộp thoại của màn khác); dòng **chưa có** chưa thấy bằng chứng, cần người giữ xác nhận. «Đúng canvas» chỉ ghi «có» cho màn đã đối chiếu tay (xem `doi-chieu-*.md`), còn lại «chưa kiểm». «Ai giữ» theo tiền tố mã (gần đúng, theo phân làn 18/11).',
);
out.push('');
out.push(
  '| Mã | Tên màn | Mức | Có code (đường dẫn) | Khung canvas | Đúng canvas | e2e nhắc | Ai giữ |',
);
out.push('|---|---|---|---|---|---|---|---|');
out.push(...table);
out.push('');
writeFileSync('docs/ke-hoach/man-hinh-theo-trang-thai.md', out.join('\n'));
console.log(`Đã ghi ${rows.length} dòng: ${have} có code, ${missing} chưa có.`);
