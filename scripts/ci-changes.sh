#!/usr/bin/env bash
# Bước "Chọn phần CI cần chạy" của ci.yml (Đ281): in `full=...` và `ui=...` (ghi vào $GITHUB_OUTPUT khi có). Mọi lỗi (không lấy được danh sách
# file, node lỗi, kết quả lạ) thì CHẠY ĐỦ: full=true, ui=true. Biến vào: EVENT_NAME, REPO, PR_NUMBER, GH_TOKEN (gh dùng). Có kiểm thử ở
# scripts/ci-changes.test.ts (gh giả).
set -uo pipefail

FALLBACK=$'full=true\nui=true'

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

# Chỉ nhận đúng bốn kết quả hợp lệ; lạ thì chạy đủ.
case "$out" in
  $'full=true\nui=true' | $'full=true\nui=false' | $'full=false\nui=true' | $'full=false\nui=false') emit "$out" ;;
  *)
    echo "::warning::Kết quả bộ lọc lạ: chạy đủ." >&2
    emit "$FALLBACK"
    ;;
esac
