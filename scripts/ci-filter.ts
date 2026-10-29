// Quyết định phần CI nào cần chạy cho một PR, từ danh sách file PR đổi (Đ210 #3, Đ281, Q-C3). Dùng ở job `changes` của ci.yml:
//   gh api ... --jq '.[].filename' | node scripts/ci-filter.ts   → in `full=true|false` và `ui=true|false`.
// Viết theo kiểu "danh sách được bỏ": CHỈ KHI mọi file đổi nằm trong deploy/, docs/, design/ hoặc là *.md thì bỏ DB (pgTAP) + Playwright
// và bản xem trước; file lạ, thư mục mới, .github/, scripts/ mặc định chạy đủ. Không có danh sách file (lỗi lấy file) thì chạy đủ.
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

/** Đổi thứ làm nên bản dựng giao diện: cần bản xem trước (Cloudflare Pages). */
export function touchesUi(files: string[]): boolean {
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
}

if (import.meta.url === `file://${process.argv[1] ?? ''}`) main();
