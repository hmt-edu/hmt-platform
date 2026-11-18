# CI tách hai job: «DB (pgTAP)» và «Playwright (máy tính + iPhone)»

Từ 18/11/2026 (PR #142, thẻ D13) job `db-e2e` cũ được tách thành hai job chạy **song song**, để lỗi cài trình duyệt hay lỗi e2e không còn che kết quả pgTAP. Tệp: `.github/workflows/ci.yml`. Bộ chọn phần cần chạy: `scripts/ci-filter.ts` (có bài Vitest) qua `scripts/ci-changes.sh`.

## Các job và điều kiện chạy

| Job (tên hiện trên PR) | Việc | Khi nào chạy |
| --- | --- | --- |
| `checks` | lint, typecheck, Vitest, dò số viết cứng, format | luôn chạy |
| `changes` | chọn phần CI cần chạy từ danh sách file PR đổi | luôn chạy |
| **DB (pgTAP)** | dựng Supabase local, `db reset` (migration + seed), `supabase test db` | khi `checks` xanh **và** PR đổi ngoài `deploy/`, `docs/`, `design/`, `*.md` |
| **Playwright (máy tính + iPhone)** | tự dựng Supabase và DB riêng, tạo tài khoản giả, cài trình duyệt, `npm run e2e` | như DB (pgTAP) **và** PR có migration, đụng tiền (đơn hàng, phiếu thu, số dư, báo giá, gói bán, bảng giá, hoàn phí…) hoặc lõi truy cập (`src/lib/auth`, `src/nav`, `src/record`); hoặc PR gắn nhãn `full-ci`; hoặc bộ chọn lỗi |
| Bản xem trước | Cloudflare Pages | PR gắn nhãn `preview`, đổi giao diện, và hai job trên xanh hoặc bị bỏ |
| Báo main đỏ | mở issue | chạy tay trên `main` mà `checks`, DB hoặc Playwright đỏ |

Job bị **bỏ (skipped)** được coi là đạt, không phải lỗi. PR chỉ sửa tài liệu không chạy cả hai.

## Đọc kết quả

- **PR chỉ đổi SQL** (migration, pgTAP): cần `checks` và **DB (pgTAP)** xanh. Playwright chỉ chạy nếu có migration, nên một PR có migration sẽ có cả hai.
- **PR có giao diện**: cần thêm **Playwright** xanh khi nó chạy.
- **DB (pgTAP) xanh, Playwright đỏ**: DB ổn; xem log Playwright. Lỗi «Cài trình duyệt Playwright hỏng sau 2 lần thử» là hạ tầng GitHub, không phải mã của PR.

## Chạy lại một job

Chỉ chạy lại job hỏng, không chạy lại job đã xanh:

```
gh run list --workflow CI --branch <nhánh> --limit 3     # lấy mã lần chạy
gh run rerun <mã lần chạy> --failed                      # chỉ chạy lại các job hỏng
gh run rerun <mã lần chạy> --job <mã job>                # một job cụ thể
```

Trên web: mở lần chạy, bấm «Re-run failed jobs». Chỉ người có quyền ghi vào repo chạy lại được (các Code agent không có quyền `gh run rerun`; nhờ Chat).

## Chạy trên máy (không dùng CI)

- pgTAP một file: `npx supabase test db supabase/tests/database/<tên>.test.sql` (cần DB local; xem lượt DB `LUOT-DB.txt`, mỗi lúc một lane).
- Playwright: `npm run e2e` (cần `.env.local`, tài khoản giả); trước khi đẩy chỉ chạy bộ nhanh theo CLAUDE.md.

## Ruleset nhánh main

Ruleset `bao-ve-main` hiện không đòi tên check cụ thể nên không bị treo khi đổi tên job. Nếu sau này thêm «required status checks», dùng hai tên mới: `DB (pgTAP)` và, nếu muốn bắt buộc, `Playwright (máy tính + iPhone)`; không dùng tên cũ `DB (pgTAP) + Playwright`.
