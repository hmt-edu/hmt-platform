// Dựng docs/ke-hoach/man-hinh-theo-trang-thai.md: mỗi mã màn trong docs/design/ban-do-man-hinh.md một dòng.
// Chạy: node scripts/man-hinh-theo-trang-thai.ts   (chỉ ĐỌC repo, ghi một file tài liệu).
// Ba tầng bằng chứng, từ chắc đến yếu:
//  1. «Có màn»: mục menu CRM có tuyến thật ở src/app/routes.tsx; hoặc mã màn nằm trong 12 dòng đầu của một file màn/hộp thoại (src/pages, src/layout, trừ dev);
//     hoặc file ghi tay trong BANG_CHUNG (đã kiểm file có thật).
//  2. «Chỉ có DB»: mã nhắc trong migration (chú thích hàm) nhưng chưa thấy màn.
//  3. «Chưa có»: không thấy gì ở trên. Mã nhắc ở file không phải màn (hàm tiện ích, hộp thoại của màn khác) KHÔNG được tính.
// «Đúng canvas» lấy từ các bảng rà tay (xem NGUON_RA_UI); màn chưa có bảng nào: «chưa kiểm».
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
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

// Bằng chứng ghi tay (file màn thật, đã đối chiếu với tuyến/menu); script kiểm file còn tồn tại.
const BANG_CHUNG: Record<string, string> = {
  'CHUNG-01': 'src/pages/auth/LoginPages.tsx',
  'CHUNG-02': 'src/pages/auth/MfaPages.tsx',
  'CHUNG-03': 'src/pages/auth/TotpEnroll.tsx',
  'CHUNG-10': 'src/layout/CrmShell.tsx',
  'CHUNG-13': 'src/pages/common/ProfilePage.tsx',
  'CS-02': 'src/pages/ticket/TicketRecordPage.tsx',
  'CS-03': 'src/pages/ticket/TicketRecordPage.tsx',
  'CS-08': 'src/pages/phieu/TaskRecordPage.tsx',
  'CS-09': 'src/pages/phieu/BusinessTaskDialog.tsx',
  'CHUNG-06': 'src/pages/auth/LoginPages.tsx',
  'CHUNG-09': 'src/pages/auth/SessionEndDialog.tsx',
  'CHUNG-14': 'src/pages/home/CrmHome.tsx',
  'CHUNG-25': 'src/pages/common/ChoosePortalPage.tsx',
  'GV-01': 'src/layout/TabShell.tsx',
  'BH-10': 'src/pages/don-hang/OrderRecordPage.tsx',
  'TC-05': 'src/pages/phieu-thu/ReceiptRecordPage.tsx',
  'TC-06': 'src/pages/phieu-thu/ReceiptRecordPage.tsx',
  'CS-13': 'src/pages/ticket/TicketRecordPage.tsx',
};

// Các bảng rà tay đối chiếu canvas (mỗi dòng bảng nhắc mã màn và kết luận).
const NGUON_RA_UI = [
  'docs/nghiep-vu/ra-ui-quan-tri-d50.md',
  'docs/design/doi-chieu-ui-cham-soc-khach-hang.md',
  'docs/design/doi-chieu-ui-cong-giao-vien.md',
  'docs/nghiep-vu/doi-chieu-ui-dao-tao.md',
  'docs/nghiep-vu/doi-chieu-cot-gop.md',
];

type Row = { code: string; name: string; level: string };
const rows: Row[] = [];
for (const line of read('docs/design/ban-do-man-hinh.md').split('\n')) {
  const cells = line.split('|').map((c) => c.trim());
  if (cells.length < 6) continue;
  const code = cells[1] ?? '';
  if (!/^[A-Z]+-\d+[A-Za-z]*$/.test(code)) continue;
  rows.push({ code, name: cells[2] ?? '', level: cells[4] ?? '' });
}

// 1a. Mục menu: mã -> slug; tuyến có thật.
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

// 1b. Mã nằm trong 12 dòng đầu của file màn (không tính test, dev, nav, hàm tiện ích).
const screenFiles = walk('src').filter(
  (f) =>
    /\.tsx$/.test(f) &&
    !/\.test\./.test(f) &&
    !f.startsWith('src/pages/dev/') &&
    !f.startsWith('src/nav/') &&
    /(Page|Pages|Dialog|Dialogs|Form|Shell|Menu|Bell|Search|Record|List)\.tsx$|Pages?\.tsx$/.test(
      f,
    ),
);
const headMention = new Map<string, string>();
for (const f of screenFiles) {
  const head = read(f).split('\n').slice(0, 12).join('\n');
  for (const m of head.matchAll(/(?<![A-Za-z-])([A-Z]{2,5}-\d+[A-Za-z]*)\b/g)) {
    const code = m[1] ?? '';
    if (!headMention.has(code)) headMention.set(code, f);
  }
}

// 2. Migration nhắc mã.
const migrations = walk('supabase/migrations').filter((f) => f.endsWith('.sql'));
const dbMention = new Map<string, string>();
for (const f of migrations) {
  const text = read(f);
  for (const m of text.matchAll(/(?<![A-Za-z-])([A-Z]{2,5}-\d+[A-Za-z]*)\b/g)) {
    const code = m[1] ?? '';
    if (!dbMention.has(code)) dbMention.set(code, f.split('/').pop() ?? f);
  }
}

// 3. e2e nhắc mã.
const e2e = walk('e2e')
  .filter((f) => f.endsWith('.spec.ts'))
  .map((f): [string, string] => [f, read(f)]);
const e2eOf = (code: string): string[] =>
  e2e
    .filter(([, t]) => t.includes(code))
    .map(([f]) => f.replace('e2e/', ''))
    .slice(0, 2);

// 4. Khung canvas theo mã (TS-01 -> TS01*).
const canvasFiles = walk('design')
  .filter((f) => f.endsWith('.dc.html'))
  .map((f) => f.split('/').pop() ?? '');
const canvasOf = (code: string): number => {
  const k = code.replace('-', '').toUpperCase();
  return canvasFiles.filter(
    (n) => n.toUpperCase().startsWith(k) && /^[A-Za-z]+\d+[a-z]?(_|\.)/.test(n),
  ).length;
};

// 5. «Đúng canvas» từ các bảng rà tay: gom mọi dòng bảng nhắc mã, lấy kết luận tệ nhất.
type Verdict = 'Lệch (chưa sửa)' | 'Lệch → đã sửa' | 'Gần đúng' | 'Đúng';
const RANK: Verdict[] = ['Lệch (chưa sửa)', 'Lệch → đã sửa', 'Gần đúng', 'Đúng'];
const verdictOf = (text: string): Verdict | null => {
  const t = text.toLowerCase();
  if (/chưa rà|cụm sau|chưa so/.test(t)) return null;
  if (
    /chưa sửa|cần chat|chờ chat|cần luật|lệch cấu trúc|cần dữ liệu từ hàm|\*\*lệch\*\*/.test(t) &&
    !/đã sửa|đã thêm/.test(t)
  )
    return 'Lệch (chưa sửa)';
  if (/gần đúng/.test(t)) return 'Gần đúng';
  if (/đã sửa|đã thêm|sửa cụm|sửa ở pr|đã tách|lệch/.test(t)) return 'Lệch → đã sửa';
  if (/khớp|đúng/.test(t)) return 'Đúng';
  return null;
};
const canvasVerdict = new Map<string, Verdict>();
for (const f of NGUON_RA_UI) {
  if (!existsSync(f)) continue;
  for (const line of read(f).split('\n')) {
    if (!line.startsWith('|')) continue;
    const v = verdictOf(line);
    if (!v) continue;
    const codes = new Set<string>();
    for (const m of line.matchAll(/(?<![A-Za-z-])([A-Z]{2,5})-(\d+[A-Za-z]*)\b/g)) {
      const prefix = m[1] === 'CSN' ? 'CS' : (m[1] ?? '');
      codes.add(`${prefix}-${m[2] ?? ''}`);
    }
    // Chỉ lấy mã nằm trong ô đầu của dòng (tên màn), tránh mã chỉ nhắc ở ô ghi chú.
    const first = (line.split('|')[1] ?? '').trim();
    const firstCodes = [...codes].filter((c) => first.replace(/CSN/g, 'CS').includes(c));
    for (const code of firstCodes) {
      const old = canvasVerdict.get(code);
      if (!old || RANK.indexOf(v) < RANK.indexOf(old)) canvasVerdict.set(code, v);
    }
  }
}

// 6. Người giữ theo tiền tố.
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
const portal = (code: string): string =>
  code.startsWith('GV-')
    ? 'Giáo viên (GV)'
    : code.startsWith('HT-')
      ? 'Học sinh (HT)'
      : code.startsWith('PH-')
        ? 'Phụ huynh (PH)'
        : code.startsWith('BC-')
          ? 'Báo cáo (BC)'
          : 'CRM (còn lại)';

type Status = 'Có màn' | 'Chỉ có DB' | 'Chưa có';
const tally = new Map<string, Record<Status, number>>();
const table: string[] = [];
for (const r of rows) {
  const slug = slugOf.get(r.code);
  let status: Status = 'Chưa có';
  let where = '';
  if (slug !== undefined && hasRoute(slug)) {
    status = 'Có màn';
    where = slug === '' ? '/crm' : `/crm/${slug}`;
  } else if (BANG_CHUNG[r.code] && existsSync(BANG_CHUNG[r.code] ?? '')) {
    status = 'Có màn';
    where = BANG_CHUNG[r.code] ?? '';
  } else if (headMention.has(r.code)) {
    status = 'Có màn';
    where = headMention.get(r.code) ?? '';
  } else if (dbMention.has(r.code)) {
    status = 'Chỉ có DB';
    where = dbMention.get(r.code) ?? '';
  }
  const p = portal(r.code);
  const t = tally.get(p) ?? { 'Có màn': 0, 'Chỉ có DB': 0, 'Chưa có': 0 };
  t[status] += 1;
  tally.set(p, t);
  const e = e2eOf(r.code);
  const canvas = canvasOf(r.code);
  const right = canvasVerdict.get(r.code) ?? 'chưa kiểm';
  table.push(
    `| ${r.code} | ${r.name} | ${r.level} | **${status}**${where ? ` \`${where}\`` : ''} | ${canvas > 0 ? `có (${canvas} khung)` : 'không có khung'} | ${right} | ${e.length ? e.join(', ') : '—'} | ${lane(r.code)} |`,
  );
}

const sum = (k: Status): number => [...tally.values()].reduce((a, t) => a + t[k], 0);
const out: string[] = [];
out.push('# Màn hình theo trạng thái (sinh tự động)');
out.push('');
out.push(
  `Sinh bằng \`node scripts/man-hinh-theo-trang-thai.ts\` từ \`docs/design/ban-do-man-hinh.md\`, \`src/nav/crmMenu.ts\`, \`src/app/routes.tsx\`, đầu file màn trong \`src/\`, \`supabase/migrations/\`, \`e2e/\`, \`design/\` và các bảng rà tay. **${rows.length} mã màn: ${sum('Có màn')} có màn, ${sum('Chỉ có DB')} chỉ có DB (chưa thấy màn), ${sum('Chưa có')} chưa có.**`,
);
out.push('');
out.push('## Số theo cổng');
out.push('');
out.push('| Cổng | Tổng | Có màn | Chỉ có DB | Chưa có |');
out.push('|---|---|---|---|---|');
for (const p of [
  'CRM (còn lại)',
  'Giáo viên (GV)',
  'Học sinh (HT)',
  'Phụ huynh (PH)',
  'Báo cáo (BC)',
]) {
  const t = tally.get(p) ?? { 'Có màn': 0, 'Chỉ có DB': 0, 'Chưa có': 0 };
  out.push(
    `| ${p} | ${t['Có màn'] + t['Chỉ có DB'] + t['Chưa có']} | ${t['Có màn']} | ${t['Chỉ có DB']} | ${t['Chưa có']} |`,
  );
}
out.push('');
out.push(
  'Cách đọc: **Có màn** = mục menu có tuyến thật, hoặc mã màn nằm ở đầu file màn/hộp thoại, hoặc file ghi tay đã kiểm. **Chỉ có DB** = migration nhắc mã (hàm đã có) nhưng chưa thấy màn: có thể là hộp thoại nằm trong màn khác, người giữ xác nhận. **Chưa có** = không thấy gì. Mã nhắc ở file không phải màn (hàm tiện ích, hộp thoại của màn khác) KHÔNG được tính, để không báo thừa. «Đúng canvas» lấy từ các bảng rà tay (`ra-ui-*.md`, `doi-chieu-ui-*.md`, `doi-chieu-cot-gop.md`); chưa có bảng nào thì «chưa kiểm». «Ai giữ» theo tiền tố mã (gần đúng).',
);
out.push('');
out.push(
  '| Mã | Tên màn | Mức | Trạng thái (bằng chứng) | Khung canvas | Đúng canvas | e2e nhắc | Ai giữ |',
);
out.push('|---|---|---|---|---|---|---|---|');
out.push(...table);
out.push('');
writeFileSync('docs/ke-hoach/man-hinh-theo-trang-thai.md', out.join('\n'));
console.log(
  `Đã ghi ${rows.length} dòng: ${sum('Có màn')} có màn, ${sum('Chỉ có DB')} chỉ có DB, ${sum('Chưa có')} chưa có.`,
);
for (const [p, t] of tally) console.log(p, JSON.stringify(t));
