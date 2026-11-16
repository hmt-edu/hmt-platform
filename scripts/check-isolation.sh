#!/usr/bin/env bash
# Kiểm chủ động: khoá của hmt-platform KHÔNG chạm được hmt-prod (chốt 10/10/2026).
# Mỗi khoá được thử hai chiều: đọc được thử nghiệm (để biết bài kiểm có nghĩa) và KHÔNG đọc được chạy thật.
# Đầu vào (biến môi trường):
#   PROD_PROJECT_REF, PROD_CLOUDFLARE_ACCOUNT_ID: mã hmt-prod (công khai, bắt buộc).
#   STAGING_PROJECT_REF, SUPABASE_ACCESS_TOKEN, STAGING_DB_URL, CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID:
#   khoá thử nghiệm; khoá nào chưa có thì bỏ qua phần của khoá đó.
# Kiểm thử: scripts/check-isolation.test.ts.
set -uo pipefail
fail() {
  echo "::error::$1"
  exit 1
}

# Mã hmt-prod phải có và đúng (gõ sai thì mọi bài thử "bị từ chối" đều vô nghĩa).
[ -n "${PROD_PROJECT_REF:-}" ] || fail "Thiếu biến PROD_PROJECT_REF (mã project hmt-prod, không phải bí mật)."
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$PROD_PROJECT_REF.supabase.co/auth/v1/health")"
if [ "$code" = "000" ] || [ "$code" = "404" ]; then
  fail "PROD_PROJECT_REF ($PROD_PROJECT_REF) không phải project có thật (HTTP $code): sửa lại biến."
fi

# Token Supabase của TÀI KHOẢN CHỦ DỰ ÁN: đọc được hmt-staging, KHÔNG đọc được hmt-prod.
if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  [ -n "${STAGING_PROJECT_REF:-}" ] || fail "Thiếu STAGING_PROJECT_REF để kiểm token Supabase."
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    "https://api.supabase.com/v1/projects/$STAGING_PROJECT_REF")"
  [ "$code" = "200" ] || fail "SUPABASE_ACCESS_TOKEN không đọc được hmt-staging (HTTP $code): hết hạn hoặc sai; bài kiểm cách ly vô nghĩa."
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    "https://api.supabase.com/v1/projects/$PROD_PROJECT_REF")"
  [ "$code" != "200" ] || fail "NGUY HIỂM: SUPABASE_ACCESS_TOKEN của hmt-platform đọc được hmt-prod. Thu hồi token ngay."
  echo "Token Supabase: đọc được hmt-staging, bị hmt-prod từ chối (HTTP $code): đúng."
fi

# Mật khẩu DB thử nghiệm thử vào hmt-prod qua cùng bộ kết nối: phải bị từ chối.
if [ -n "${STAGING_DB_URL:-}" ]; then
  staging_ref="$(printf '%s' "$STAGING_DB_URL" | sed -E 's#.*://postgres\.([a-z0-9]+):.*#\1#')"
  probe="${STAGING_DB_URL/postgres.$staging_ref/postgres.$PROD_PROJECT_REF}"
  if PGCONNECT_TIMEOUT=10 psql "$probe" -X -At -c 'select 1' > /dev/null 2>&1; then
    fail "NGUY HIỂM: mật khẩu DB thử nghiệm vào được hmt-prod. Đổi mật khẩu hmt-prod ngay."
  fi
  echo "Mật khẩu DB thử nghiệm bị hmt-prod từ chối: đúng."
fi

# Token Cloudflare thử nghiệm: đọc được Pages của tài khoản thử nghiệm, KHÔNG đọc được tài khoản chạy thật.
if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
  [ -n "${PROD_CLOUDFLARE_ACCOUNT_ID:-}" ] || fail "Thiếu biến PROD_CLOUDFLARE_ACCOUNT_ID (mã tài khoản Cloudflare chạy thật, không phải bí mật)."
  [ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ] || fail "Thiếu CLOUDFLARE_ACCOUNT_ID của tài khoản thử nghiệm."
  cf() {
    curl -s --max-time 15 -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      "https://api.cloudflare.com/client/v4/accounts/$1/pages/projects"
  }
  cf "$CLOUDFLARE_ACCOUNT_ID" | grep -q '"success": *true' ||
    fail "CLOUDFLARE_API_TOKEN không đọc được Pages của tài khoản thử nghiệm: hết hạn hoặc sai; bài kiểm cách ly vô nghĩa."
  if cf "$PROD_CLOUDFLARE_ACCOUNT_ID" | grep -q '"success": *true'; then
    fail "NGUY HIỂM: CLOUDFLARE_API_TOKEN của hmt-platform đọc được tài khoản Cloudflare chạy thật. Thu hồi token ngay."
  fi
  echo "Token Cloudflare: đọc được tài khoản thử nghiệm, bị tài khoản chạy thật từ chối: đúng."
fi
