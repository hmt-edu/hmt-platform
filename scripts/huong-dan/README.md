# Chụp ảnh có khung đánh dấu và quay video hướng dẫn (T2-S)

Chạy tay, không nằm trong CI. Chỉ dùng tài khoản giả và dữ liệu giả của bản thử nghiệm.

```
set -a; . ~/VanPhongAI/hmt-ca/.staging-test.env; set +a   # STAGING_URL, STAGING_PASSWORD, HD_SUPABASE_URL, HD_SUPABASE_KEY
node scripts/huong-dan/chay.mjs            # cả ba bài; hoặc: dang-nhap | danh-sach | ban-ghi
```

- Ra thư mục `HD_OUT` (mặc định `~/VanPhongAI/hmt-ca/ANH-HUONG-DAN/huong-dan-mau/<bài>/`, ngoài repo, không commit): `buoc-<n>.png` (khung cam `#EF6925`, số tròn, chú thích), `<bài>.mp4` (14–20 giây, khoảng 0,1–0,2 MB), `buoc.json` (số, chữ, tên ảnh) để ghép HTML.
- Cần `ffmpeg` để nén mp4 (`brew install ffmpeg`); không có thì giữ `.webm`.
- Tài khoản mặc định `sale.cs5@thu.hoamatoan.invalid`, đổi bằng `HD_TAI_KHOAN`. Thời gian dừng mỗi bước `HD_DUNG_MS` (mặc định 1600).
- Bài `dang-nhap`: bản thử nghiệm có bước chống máy tự động (Turnstile) nên bấm «Đăng nhập» tự động bị chặn. Kịch bản chụp khung ở bước bấm rồi nạp phiên lấy qua API Auth. Chỉ chạy với địa chỉ https không chứa chữ `prod`.
- Bài `ban-ghi` ghi một ghi chú giả có tiền tố «[Hướng dẫn mẫu]» vào một cơ hội của dữ liệu giả.
- Chữ nút thật nằm ở `nhan.mjs` (một chỗ); giao diện đổi chữ thì sửa ở đó. Thêm bài: thêm mục vào `BAI` trong `chay.mjs` (mảng bước `{chu, loc, lam}`).
- `muc-1.mjs`: ảnh thật cho `docs/huong-dan/01-bat-dau-nhanh.md` (10 ảnh, ra `docs/huong-dan/assets/`, tài khoản giả, khung cam). Chạy: `node scripts/huong-dan/muc-1.mjs [tên-ảnh …]`. Chưa chụp: `doi-mat-khau-lan-dau`, `hai-buoc-*` (cần tài khoản đổi mật khẩu lần đầu/chưa thiết lập hai bước), `thanh-duoi-hoc-sinh` (cần phiên học sinh).
