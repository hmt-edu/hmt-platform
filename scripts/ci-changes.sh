#!/usr/bin/env bash
# Bước "Chọn phần CI cần chạy" của ci.yml (Đ281): in `full=...` và `ui=...` (ghi vào $GITHUB_OUTPUT khi có). Mọi lỗi (không lấy được danh sách
# file, node lỗi, kết quả lạ) thì CHẠY ĐỦ: full=true, ui=true. Biến vào: EVENT_NAME, REPO, PR_NUMBER, GH_TOKEN (gh dùng). Có kiểm thử ở
# scripts/ci-changes.test.ts (gh giả).
set -uo pipefail

FALLBACK=$'full=true\nui=true\ne2e=true'

emit() {
  printf '%s\n' "$1"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then printf '%s\n' "$1" >> "$GITHUB_OUTPUT"; fi
}

if [ "${EVENT_NAME:-}" != "pull_request" ]; then
  echo "::notice::Chạy tay hoặc sự kiện khác: chạy đủ." >&2
  emit "$FALLBACK"
  exit 0
fi

if ! files="$(gh api --paginate "repos/${REPO:?}/pulls/${PR_NUMBER:?}/files" --jq '.[].filename' 2>/dev/null)"; then
  echo "::warning::Không lấy được danh sách file của PR: chạy đủ." >&2
  emit "$FALLBACK"
  exit 0
fi

if ! out="$(printf '%s\n' "$files" | node "$(dirname "$0")/ci-filter.ts" 2>/dev/null)"; then
  echo "::warning::Bộ lọc lỗi: chạy đủ." >&2
  emit "$FALLBACK"
  exit 0
fi

# Chỉ nhận đúng dạng ba dòng full, ui, e2e (true hoặc false); lạ thì chạy đủ.
valid=true
for key in full ui e2e; do
  # Không dùng `printf | grep -q` ở đây: grep -q thoát sớm, printf có thể nhận SIGPIPE (141) và `pipefail` coi cả dòng là lỗi, làm CI rơi về "chạy đủ" ngẫu nhiên.
  grep -Eq "^${key}=(true|false)$" <<<"$out" || valid=false
done
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 3 ] || valid=false
if [ "$valid" != true ]; then
  echo "::warning::Kết quả bộ lọc lạ: chạy đủ." >&2
  emit "$FALLBACK"
  exit 0
fi

# Nhãn `full-ci` trên PR: buộc chạy đủ (cả Playwright, bản xem trước). Không đọc được nhãn thì giữ kết quả bộ lọc.
if labels="$(gh api "repos/${REPO:?}/issues/${PR_NUMBER:?}/labels" --jq '.[].name' 2>/dev/null)" && grep -qx 'full-ci' <<<"$labels"; then
  echo "::notice::PR có nhãn full-ci: chạy đủ." >&2
  emit "$FALLBACK"
  exit 0
fi
emit "$out"
