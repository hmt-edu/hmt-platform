#!/usr/bin/env bash
# Khởi động Supabase local trong CI, thử lại có chờ tăng dần (D28, 19/11/2026). Lý do: nhiều lượt CI cùng kéo ảnh Docker từ kho công khai nên có lúc báo
# «toomanyrequests: Rate exceeded»; lỗi này tự hết sau vài chục giây. Thử tối đa 4 lần, chờ 20, 60, 120 giây giữa các lần; trước mỗi lần thử lại dọn container dở.
# Lỗi khác (ví dụ migration hỏng) KHÔNG nằm ở bước này (bước này chỉ khởi động dịch vụ) nên thử lại không che lỗi thật.
set -u
waits=(20 60 120)
attempt=1
while true; do
  if npx supabase start -x studio,imgproxy,mailpit,logflare,vector,realtime,storage-api,supavisor,postgres-meta; then
    exit 0
  fi
  if [ "$attempt" -gt "${#waits[@]}" ]; then
    echo "::error::Khởi động Supabase local hỏng sau $attempt lần thử."
    exit 1
  fi
  wait_s="${waits[$((attempt - 1))]}"
  echo "::warning::Lần $attempt khởi động Supabase hỏng (có thể do giới hạn kéo ảnh). Chờ ${wait_s} giây rồi thử lại."
  npx supabase stop --no-backup > /dev/null 2>&1 || true
  sleep "$wait_s"
  attempt=$((attempt + 1))
done
