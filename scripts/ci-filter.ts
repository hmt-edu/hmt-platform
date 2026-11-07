// Quyết định phần CI nào cần chạy cho một PR, từ danh sách file PR đổi (Đ210 #3, Đ281, Q-C3). Dùng ở job `changes` của ci.yml:
//   gh api ... --jq '.[].filename' | node scripts/ci-filter.ts   → in `full=true|false` và `ui=true|false`.
// Viết theo kiểu "danh sách được bỏ": CHỈ KHI mọi file đổi nằm trong deploy/, docs/, design/ hoặc là *.md thì bỏ DB (pgTAP) + Playwright
// và bản xem trước (job DB còn lại chạy pgTAP); file lạ, thư mục mới, .github/, scripts/ mặc định chạy job DB. Playwright chỉ khi có migration hoặc đụng tiền (needsE2e). Không có danh sách file (lỗi lấy file) thì chạy đủ cả hai (full=true, ui=true).
// Kiểm nhanh (lint, typecheck, test, hardcode, format:check) luôn chạy, không qua bộ lọc này.
import { readFileSync } from 'node:fs';

/** File nằm trong phần được bỏ: bản chép cho hmt-deploy, tài liệu, thiết kế, hoặc file Markdown. */
export function isSkippable(file: string): boolean {
  return /^(deploy|docs|design)\//.test(file) || /\.md$/i.test(file);
}

/** Cần chạy đủ (DB + Playwright): không có file nào, hoặc có ít nhất một file ngoài phần được bỏ. */
export function needsFullCi(files: string[]): boolean {
  if (files.length === 0) return true;
  return files.some((f) => !isSkippable(f));
}

/** File migration: luôn cần Playwright (DB đổi thì luồng trên giao diện phải chạy lại). */
export function isMigration(file: string): boolean {
  return /^supabase\/migrations\//.test(file);
}

/**
 * File "đụng tiền" (đơn hàng, phiếu thu, số dư, báo giá, gói bán, bảng giá và các phần sắp có: công nợ, thu nợ đầu kỳ, voucher, hoàn phí), xác định theo
 * ĐƯỜNG DẪN (không theo nhãn): màn và bài Playwright của các phần này (kể cả dữ liệu giả dùng chung bao-gia-seed), hàm định dạng và đọc tiền dùng chung
 * (format, amountInWords), bài pgTAP của các phần. Thêm phần mới thì thêm tên thư mục ở đây (Q-36, Q-39).
 */
export function isMoney(file: string): boolean {
  return (
    /^src\/pages\/(don-hang|phieu-thu|so-du|bao-gia|goi-ban|bang-gia|cong-no|thu-no-dau-ky|voucher|hoan-phi)\//.test(
      file,
    ) ||
    /^e2e\/(don-hang|phieu-thu|so-du|bao-gia|goi-ban|bang-gia|cong-no|thu-no-dau-ky|voucher|hoan-phi)[^/]*$/.test(
      file,
    ) ||
    /^src\/lib\/(format|amountInWords)(\.test)?\.ts$/.test(file) ||
    /^supabase\/tests\/database\/[^/]*(don_hang|phieu_thu|so_du|bao_gia|goi_ban|bang_gia|cong_no|thu_no_dau_ky|voucher|hoan_phi)[^/]*$/.test(
      file,
    )
  );
}

/**
 * File "lõi" (Q-36, Q-39, Q-66): đăng nhập, phiên, ma trận quyền và menu theo quyền (src/lib/auth/, src/nav/), khung hồ sơ dùng chung (src/record/). Sai ở đây là hỏng mọi màn nên
 * cũng chạy Playwright. Bản in nằm trong thư mục của từng màn (Báo giá, Phiếu thu) nên đã thuộc isMoney; không có thư mục src/print/. src/ui/ KHÔNG tính (Q-66).
 */
export function isCore(file: string): boolean {
  return /^src\/(lib\/auth|nav|record)\//.test(file);
}

/**
 * Cần chạy Playwright trên PR (Q-21, anh chốt 06/11; mở rộng Q-36, Q-39): CHỈ khi PR có migration, đụng tiền (isMoney) hoặc lõi truy cập (isCore). Nhãn `full-ci` ép chạy (scripts/ci-changes.sh);
 * không lấy được danh sách file thì chạy. PR khác: Code dán kết quả `npm run check:all` trên máy (commit, số bài qua) vào bình luận PR; nhánh main sau khi gộp
 * KHÔNG chạy đủ mỗi lần gộp: main chạy đủ theo lịch đêm khi có commit mới (ci.yml, job gate) và chạy tay trước đợt cập nhật bản thật (Q-37). Đổi cho từng loại file: xem bảng trong mô tả PR Q-21.
 */
export function needsE2e(files: string[]): boolean {
  if (files.length === 0) return true;
  if (!needsFullCi(files)) return false;
  return files.some((f) => isMigration(f) || isMoney(f) || isCore(f));
}

/** Đổi thứ làm nên bản dựng giao diện: cần bản xem trước (Cloudflare Pages). Không có danh sách file thì coi như có (chạy đủ, Đ281). */
export function touchesUi(files: string[]): boolean {
  if (files.length === 0) return true;
  return files.some((f) =>
    /^(src\/|index\.html$|vite\.config\.ts$|tsconfig[^/]*\.json$|package(-lock)?\.json$|\.nvmrc$|design\/hmt-p0-p2\/|\.github\/workflows\/ci\.yml$)/.test(
      f,
    ),
  );
}

function main() {
  const input = readFileSync(0, 'utf8');
  const files = input
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);
  console.log(`full=${String(needsFullCi(files))}`);
  console.log(`ui=${String(touchesUi(files))}`);
  console.log(`e2e=${String(needsE2e(files))}`);
}

if (import.meta.url === `file://${process.argv[1] ?? ''}`) main();
