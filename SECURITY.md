# Chính sách bảo mật

## Báo lỗ hổng bảo mật

Nếu thấy lỗ hổng, **đừng mở issue công khai**. Dùng báo cáo riêng của GitHub: tab **Security** của repo này > **Report a vulnerability** (Private vulnerability reporting). Mô tả việc xảy ra, các bước tái hiện, mức ảnh hưởng. Không đính kèm dữ liệu cá nhân thật.

Chúng tôi sẽ phản hồi trong vài ngày làm việc và báo lại khi đã sửa.

## Phạm vi

- Mã nguồn ứng dụng (thư mục `src/`, `supabase/`).
- Cấu hình CI trong `.github/`.

Ngoài phạm vi: dịch vụ bên thứ ba (Supabase, Cloudflare, GitHub) và dữ liệu thật của khách hàng. Repo này **không chứa** dữ liệu thật hay khoá bí mật; mọi dữ liệu mẫu đều là dữ liệu giả. Nếu thấy thứ gì giống bí mật hoặc dữ liệu thật trong repo, hãy báo qua kênh riêng ở trên.

## Cho người đóng góp

- Không đưa khoá, mật khẩu, tệp `.env*` (trừ `.env.example`) vào repo.
- Workflow chạy trên PR từ nhánh ngoài không nhận secret. Job cần secret (bản xem trước Cloudflare) chạy trong **Environment `preview`** và chỉ chạy sau khi người có quyền duyệt bấm Approve.
- Thay đổi `.github/**`, `deploy/**`, `scripts/**`, `supabase/migrations/**` cần người duyệt theo `CODEOWNERS`.
