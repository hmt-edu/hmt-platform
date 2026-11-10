#!/usr/bin/env bash
# Bộ kiểm đầy đủ trên máy, giống CI (Đ210 #6, Đ281): lint, typecheck, test, check:hardcode, format:check, db:reset, db:test, e2e.
# Chạy trước khi mở PR hoặc đẩy commit (luật "đẩy một lần", CLAUDE.md). Cần Docker Desktop (Supabase local) và `npx playwright install chromium webkit` một lần.
# Không cần biến môi trường: địa chỉ, khoá công khai lấy từ `supabase status`; mật khẩu tài khoản giả sinh ngẫu nhiên mỗi lần, không lưu.
# Dừng ở bước trượt đầu tiên.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n=== %s ===\n' "$1"; }

# Cổng xem trước của Playwright (mặc định 4173; đặt E2E_PREVIEW_PORT để mỗi thư mục làm việc một cổng, Q-222) phải trống. Tiến trình `vite preview` sót từ lần chạy bị dừng giữa chừng vẫn phục vụ bản build CŨ, mà
# Playwright dùng lại tiến trình đang giữ cổng (reuseExistingServer) nên bài kiểm chạy trên mã cũ (gốc lỗi 08/11: bài tab của #198 báo sai).
# Thấy tiến trình thì dừng ngay và báo; không tự tắt để người chạy thấy.
PREVIEW_PORT="${E2E_PREVIEW_PORT:-4173}"
export E2E_PREVIEW_PORT="$PREVIEW_PORT"
if lsof -nP -iTCP:"$PREVIEW_PORT" -sTCP:LISTEN > /dev/null 2>&1; then
  echo "DỪNG: cổng $PREVIEW_PORT đang có tiến trình (thường là vite preview sót từ lần check:all bị dừng):"
  lsof -nP -iTCP:"$PREVIEW_PORT" -sTCP:LISTEN
  echo "Tắt tiến trình đó (ví dụ: pkill -f 'vite preview --port $PREVIEW_PORT') rồi chạy lại check:all."
  exit 1
fi

step "Kiểm nhanh: lint, typecheck, test, hardcode, format"
npm run lint
npm run typecheck
npm run test
npm run check:hardcode
npm run format:check

step "Supabase local: bật (nếu chưa), dựng lại DB, kiểm thử DB (pgTAP)"
npx supabase status > /dev/null 2>&1 || npm run db:start
npm run db:reset
npm run db:test

step "Playwright (máy tính + iPhone)"
eval "$(npx supabase status -o env | grep -E '^(API_URL|DB_URL|SECRET_KEY|PUBLISHABLE_KEY|ANON_KEY)=')"
export API_URL DB_URL SECRET_KEY
export VITE_SUPABASE_URL="$API_URL"
export VITE_SUPABASE_PUBLISHABLE_KEY="${PUBLISHABLE_KEY:-${ANON_KEY:-}}"
export VITE_APP_ENV=local
SEED_PASSWORD="Ci$(openssl rand -hex 12)9"
export SEED_PASSWORD
npm run db:seed-users

# Chờ dịch vụ đăng nhập (GoTrue) nối lại cơ sở dữ liệu sau khi dựng lại DB và tạo tài khoản. Điều kiện thật: đăng nhập sai mật khẩu phải trả 400
# (sai thông tin), KHÔNG phải 500 (không nối được DB: "failed SASL auth ... i/o timeout", gốc của bài auth.spec chập chờn 29/10). Cần ba lần liên tiếp
# trả 400 (đã ấm kết nối); quá 90 giây thì dừng và báo rõ, không chạy e2e trên dịch vụ chưa sẵn sàng.
step "Chờ dịch vụ đăng nhập sẵn sàng"
deadline=$((SECONDS + 90))
ok=0
code=000
while [ "$ok" -lt 3 ]; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "Quá 90 giây: dịch vụ đăng nhập vẫn trả HTTP $code cho đăng nhập sai mật khẩu (cần 400). Xem: docker logs supabase_auth_hmt-platform" >&2
    exit 1
  fi
  code="$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST "$API_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $VITE_SUPABASE_PUBLISHABLE_KEY" -H 'Content-Type: application/json' \
    -d '{"email":"khong.co@thu.hoamatoan.invalid","password":"KhongPhaiMatKhau1"}' || true)"
  if [ "$code" = "400" ]; then ok=$((ok + 1)); else ok=0; sleep 2; fi
done
echo "Dịch vụ đăng nhập sẵn sàng."

# Thử lại bài trượt 2 lần như CI (playwright.config.ts): loại báo nhầm do GoTrue trên Docker chập chờn; lỗi thật vẫn trượt.
export E2E_RETRIES=2
npm run e2e

printf '\nXanh: có thể mở PR hoặc đẩy commit. Ảnh chụp của bài e2e ra thư mục tạm (chỉ ghi vào docs/anh-chup/ khi đặt SO_SANH_GHI_VAO_REPO=1).\n'
