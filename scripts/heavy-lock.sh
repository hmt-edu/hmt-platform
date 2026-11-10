#!/usr/bin/env bash
# Khoá việc nặng giữa hai phiên Code trên cùng máy (check:all, Playwright dùng chung một Supabase local).
# Dùng:  scripts/heavy-lock.sh acquire "Code 1" "check:all lát 2"   (chờ đến khi có khoá, rồi ghi file owner)
#        scripts/heavy-lock.sh release                              (nhả khoá)
#        scripts/heavy-lock.sh status                               (ai đang giữ, từ mấy giờ)
# Khoá là thư mục; file owner bên trong ghi "tên · giờ máy · việc" để người kia biết ai giữ. Đặt HMT_HEAVY_LOCK để đổi đường dẫn (thử).
set -u
LOCK="${HMT_HEAVY_LOCK:-/tmp/hmt-heavy.lock}"
case "${1:-}" in
  acquire)
    who="${2:?Thiếu tên phiên (ví dụ \"Code 1\")}"
    note="${3:-}"
    until mkdir "$LOCK" 2> /dev/null; do sleep 15; done
    printf '%s %s %s\n' "$who" "$(date '+%H:%M')" "$note" > "$LOCK/owner"
    echo "Đã giữ khoá: $(cat "$LOCK/owner")"
    ;;
  release)
    rm -f "$LOCK/owner"
    rmdir "$LOCK" 2> /dev/null && echo "Đã nhả khoá." || echo "Không có khoá để nhả."
    ;;
  status)
    if [ -d "$LOCK" ]; then
      echo "Đang giữ: $(cat "$LOCK/owner" 2> /dev/null || echo 'không rõ (khoá thiếu file owner)')"
    else
      echo "Khoá rảnh."
    fi
    ;;
  *)
    echo "Dùng: $0 acquire \"<tên phiên>\" \"<việc>\" | release | status" >&2
    exit 2
    ;;
esac
