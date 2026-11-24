// Phép thử kho tệp Apps Script ở STAGING (F-23-58/59, mục 5 của docs/ke-hoach/kho-tep-apps-script.md).
// Chạy: APPS_SCRIPT_URL=... APPS_SCRIPT_SHARED_SECRET=... [OUTSIDE_FILE_ID=...] node scripts/apps-script-kho-tep/phep-thu.mjs
// Khoá chỉ đọc từ biến môi trường, không in ra. Dừng nếu thư mục gốc script trả về không có chữ «staging» (tránh chạm bản chạy thật).
// Chỉ lưu tệp giả (byte ngẫu nhiên) vào thư mục con PHEP-THU, thử xong xoá vĩnh viễn. In kết quả để dán vào PR #708.
// OUTSIDE_FILE_ID (tuỳ chọn): id một tệp anh tạo tay NGOÀI thư mục gốc, để thử script không đọc/xoá được.
import { randomBytes } from 'node:crypto';

const url = process.env.APPS_SCRIPT_URL ?? '';
const secret = process.env.APPS_SCRIPT_SHARED_SECRET ?? '';
if (!url.startsWith('https://script.google.com/') || !secret) {
  console.error('Thiếu hoặc sai APPS_SCRIPT_URL / APPS_SCRIPT_SHARED_SECRET.');
  process.exit(2);
}
const stamp = Date.now().toString(36);

async function call(body, withSecret = true) {
  const t0 = performance.now();
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain;charset=utf-8' },
    body: JSON.stringify(withSecret ? { secret, ...body } : body),
    redirect: 'follow',
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { ok: false, code: 'KHONG_PHAI_JSON', http: res.status };
  }
  return { json, ms: Math.round(performance.now() - t0) };
}
const line = (ok, name, extra = '') =>
  console.log(`${ok ? 'ĐẠT ' : 'TRƯỢT'} | ${name}${extra ? ' | ' + extra : ''}`);
const mb = (n) => randomBytes(n).toString('base64');

const ping = await call({ action: 'ping' });
if (!ping.json.ok || !/staging/i.test(String(ping.json.rootName))) {
  console.error('Ping lỗi hoặc thư mục gốc không có chữ «staging»: dừng.', ping.json.code ?? '');
  process.exit(3);
}
line(true, 'ping', `${ping.ms} ms`);

// Phép 5a: sai mật khẩu bị từ chối.
const bad = await call({ action: 'ping', secret: 'sai' }, false);
line(bad.json.code === 'SAI_MAT_KHAU', '5a sai mật khẩu bị từ chối', String(bad.json.code));

// Phép 1: thân 200 KB, 500 KB, 1 MB đi qua chuyển hướng 302.
const ids = [];
for (const kb of [200, 500, 1024]) {
  const r = await call({
    action: 'save',
    name: `pt_${stamp}_${kb}.bin`,
    path: ['PHEP-THU'],
    mimeType: 'application/octet-stream',
    dataBase64: mb(kb * 1024),
  });
  if (r.json.id) ids.push(r.json.id);
  line(Boolean(r.json.ok), `1 lưu ${kb} KB`, `${r.ms} ms`);
}

// Phép 2: thời gian ping 10 lần (lần đầu có thể lạnh).
const times = [];
for (let i = 0; i < 10; i++) times.push((await call({ action: 'ping' })).ms);
console.log(`ĐO   | 2 ping 10 lần (ms): ${times.join(', ')}`);

// Phép 6/8: đọc lại tệp 1 MB; sau đó tệp lớn gần trần (~19 MB) để đo thời gian đọc.
if (ids[2]) {
  const r = await call({ action: 'read', id: ids[2] });
  line(Boolean(r.json.ok) && r.json.dataBase64?.length > 1000, '6 đọc lại tệp 1 MB', `${r.ms} ms`);
}
const big = await call({
  action: 'save',
  name: `pt_${stamp}_big.bin`,
  path: ['PHEP-THU'],
  mimeType: 'application/pdf',
  dataBase64: mb(19 * 1024 * 1024),
});
line(Boolean(big.json.ok), '8 lưu ~19 MB', `${big.ms} ms ${big.json.code ?? ''}`);
if (big.json.id) {
  ids.push(big.json.id);
  const r = await call({ action: 'read', id: big.json.id });
  line(Boolean(r.json.ok), '8 đọc ~19 MB (base64 ≈ 25 MB)', `${r.ms} ms ${r.json.code ?? ''}`);
}

// Trần cỡ 21 MB.
const huge = await call({
  action: 'save',
  name: `pt_${stamp}_huge.bin`,
  path: ['PHEP-THU'],
  mimeType: 'application/pdf',
  dataBase64: mb(22 * 1024 * 1024),
});
line(
  huge.json.code === 'QUA_LON',
  'trần 21 MB: tệp 22 MB bị từ chối',
  String(huge.json.code ?? huge.json.http),
);
if (huge.json.id) ids.push(huge.json.id);

// Phép 5b: tệp ngoài thư mục gốc không đọc, không xoá được.
const outside = process.env.OUTSIDE_FILE_ID;
if (outside) {
  const r = await call({ action: 'read', id: outside });
  const d = await call({ action: 'remove', id: outside });
  line(
    r.json.code === 'KHONG_THAY' && d.json.removed === false,
    '5b tệp ngoài thư mục gốc: không đọc, không xoá',
    `${r.json.code} / removed=${d.json.removed}`,
  );
} else console.log('BỎ   | 5b chưa có OUTSIDE_FILE_ID');

// Phép 4: xoá vĩnh viễn, dung lượng giảm.
const q1 = await call({ action: 'quota' });
let removed = 0;
for (const id of ids) if ((await call({ action: 'remove', id })).json.removed) removed++;
const q2 = await call({ action: 'quota' });
line(removed === ids.length, `4 xoá vĩnh viễn ${removed}/${ids.length} tệp`);
console.log(
  `ĐO   | 4 dung lượng đã dùng (byte): trước ${q1.json.usage} → sau ${q2.json.usage}; giới hạn ${q2.json.limit}. Mở thùng rác Drive kiểm tay: không còn tệp pt_${stamp}_*`,
);
