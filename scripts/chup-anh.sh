#!/usr/bin/env bash
# E32: chụp ảnh tự động cho docs/huong-dan trên Supabase local (dữ liệu giả, KHÔNG cần staging). Một lệnh: npm run chup-anh
# Ảnh lưu ngoài repo ($ANH_OUT, mặc định ~/VanPhongAI/hmt-ca/ANH-HUONG-DAN/<vai>/<ten>.png), không commit. Chạy lần lượt với lane khác (LUOT-DB), tắt DB khi xong (npm run db:stop).
set -euo pipefail
cd "$(dirname "$0")/.."
export E2E_PREVIEW_PORT="${E2E_PREVIEW_PORT:-4173}"
if lsof -nP -iTCP:"$E2E_PREVIEW_PORT" -sTCP:LISTEN > /dev/null 2>&1; then
  echo "DỪNG: cổng $E2E_PREVIEW_PORT đang có tiến trình (vite preview sót?). Đặt E2E_PREVIEW_PORT khác hoặc tắt tiến trình." >&2
  exit 1
fi
npx supabase status > /dev/null 2>&1 || npm run db:start
npm run db:reset
eval "$(npx supabase status -o env | grep -E '^(API_URL|DB_URL|SECRET_KEY|PUBLISHABLE_KEY|ANON_KEY)=')"
export API_URL DB_URL SECRET_KEY
export VITE_SUPABASE_URL="$API_URL"
export VITE_SUPABASE_PUBLISHABLE_KEY="${PUBLISHABLE_KEY:-${ANON_KEY:-}}"
export VITE_APP_ENV=local
SEED_PASSWORD="Ci$(openssl rand -hex 12)9"
export SEED_PASSWORD
npm run db:seed-users
CHUP_ANH=1 npx playwright test e2e/chup-anh.spec.ts --project=may-tinh --reporter=list
echo "Xong. Ảnh ở: ${ANH_OUT:-$HOME/VanPhongAI/hmt-ca/ANH-HUONG-DAN} (xem BAO-CAO.txt trong từng thư mục vai)."
