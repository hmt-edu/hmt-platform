# Quay lại khi deploy production lỗi (viết cho anh Trường)

Viết 13/11/2026 (phiếu T3). Chỉ viết cách làm; **chưa diễn tập trên production**. Chỗ nào chưa có hoặc chưa chắc thì ghi rõ "CHƯA CÓ" hoặc "chưa kiểm". Đọc cùng `docs/van-hanh/dua-len-chay-that.md` (các bước deploy) và `deploy/README.md` (sao lưu).

**Ba điều nhớ trước:**

1. Không sửa tay cơ sở dữ liệu chạy thật, không chạy lại Deploy production "cho thử xem". Dừng, chụp màn hình, báo Chat.
2. Migration **không có bản lùi**. Lỗi migration thì cách chính là **sửa tiến tới**: viết migration mới, qua PR, lên thử nghiệm, rồi anh chạy Deploy production lại.
3. Giao diện thì quay lại được (Cloudflare giữ các bản cũ). Cơ sở dữ liệu thì chỉ quay lại bằng bản sao lưu, và **hiện chưa có cách bấm để khôi phục lên chạy thật** (xem mục D).

## 1. Trước khi bấm Deploy (làm đủ cả sáu, ghi vào một tin nhắn cho Chat)

| #   | Chụp / ghi lại gì                                                                                                                                                  | Để làm gì                                        |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| 1   | Chạy tay **Backup production** (repo deploy riêng > Actions > Run workflow), chờ xanh, mở Google Drive `HMT-backup/daily/` thấy file `.age` mới, dung lượng khác 0 | Có điểm để khôi phục DB                          |
| 2   | Dán `docs/van-hanh/sql-kiem-hmt-prod-chi-doc.sql` vào SQL Editor của `hmt-prod`, chụp kết quả (số migration cuối, số dòng các bảng chính)                          | Biết DB "trước" trông thế nào để so với "sau"    |
| 3   | Cloudflare > Workers & Pages > `hmt-prod` > Deployments: chụp bản **Production** đang chạy (giờ, mã commit)                                                        | Biết quay giao diện về bản nào                   |
| 4   | Ghi tag bản **đang** chạy và tag bản **sắp** deploy                                                                                                                | Quay giao diện bằng tag cũ nếu cần               |
| 5   | Kiểm khoá giải mã `age` còn trong trình quản lý mật khẩu                                                                                                           | Không có khoá thì bản sao lưu vô dụng            |
| 6   | Ghi giờ bắt đầu; báo người dùng không thao tác trong lúc deploy                                                                                                    | Không có ai ghi dữ liệu giữa chừng               |

Nếu bước 1 đỏ hoặc không thấy file: **dừng, không deploy**.

## 2. Gặp lỗi thì làm gì (tìm đúng dòng theo triệu chứng)

| Triệu chứng                                                                                               | Nghĩa là                                                          | Làm gì                                                                                                                       | Ai làm            |
| --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| **A.** Đỏ ở "Kiểm tra bản được chọn" hoặc "Build"                                                         | Chưa đổi gì trên DB và giao diện                                  | Đọc câu lỗi tiếng Việt, chụp, báo Chat. Chọn lại tag đúng rồi chạy lại.                                                      | Anh bấm, Chat xem |
| **B.** Đỏ ở "Áp migration lên hmt-prod"                                                                   | DB đã mới **một phần** (các file trước file lỗi vẫn nằm lại); giao diện vẫn bản cũ | **Dừng, không bấm chạy lại.** Chụp màn hình (tên file lỗi + câu lỗi), chạy `select max(version) from supabase_migrations.schema_migrations;` (chỉ đọc), gửi Chat. Chat quyết **sửa tiến tới** (Code viết migration mới trên `main`, qua PR, thử nghiệm) rồi anh chạy lại với tag mới. | Anh chụp; Chat quyết; Code sửa |
| **C.** Migration xanh nhưng giao diện lỗi (trang trắng, báo lỗi đỏ ngay khi mở, đăng nhập không được)    | DB đã mới, giao diện mới có lỗi                                   | Quay giao diện về bản trước (mục 3). Nếu bản trước cũng không chạy được trên DB mới thì đi tiếp **sửa tiến tới**, không quay. | Anh bấm trên Cloudflare |
| **D.** Dữ liệu trong DB sai hoặc mất sau deploy (lỗi migration làm hỏng dữ liệu)                          | Cần quay **DB** về bản sao lưu                                    | Xem mục 4. Hiện **CHƯA CÓ** cách bấm khôi phục lên chạy thật.                                                               | Chat quyết, anh làm |

## 3. Quay giao diện về bản cũ (Cloudflare Pages)

Làm trên trình duyệt, tài khoản Cloudflare chạy thật. Các bước này là tính năng "Rollback" có sẵn của Cloudflare Pages; **chưa diễn tập trên `hmt-prod`**.

1. Cloudflare > **Workers & Pages** > `hmt-prod` > **Deployments**.
2. Tìm bản **Production** đã chụp ở mục 1 bước 3 (giờ và mã commit khớp).
3. Bấm dấu ba chấm bên phải dòng đó > **Rollback to this deployment** > xác nhận.
4. Mở `https://hmt-prod.pages.dev` bằng cửa sổ ẩn danh, đăng nhập bằng Admin, mở Lead, Cơ hội, Đơn hàng: danh sách mở được, không báo lỗi đỏ.

**Lưu ý quan trọng:** giao diện cũ chạy trên DB **mới**. Chỉ an toàn khi các migration mới chỉ **thêm** (bảng, cột, hàm). Migration **xoá cột hoặc xoá bảng** làm giao diện cũ hỏng (ví dụ migration 043 xoá cột của lead và cơ hội). Trước deploy, nhờ Chat liệt kê migration nào trong bản mới có xoá hay đổi tên; nếu có, coi mục 3 **không dùng được** cho bản đó.

**Lần deploy production đầu tiên (16/11):** nếu `hmt-prod` chưa từng có bản giao diện nào thì **không có bản để quay lại**. Khi đó đi theo **sửa tiến tới** (mục 2, dòng B và C).

## 4. Quay lại DB bằng bản sao lưu (mục D)

**Tình trạng thật:** bản sao lưu đêm và bản chụp tay ở mục 1 là file `.age` trên Google Drive. `deploy/README.md` mục "Khôi phục thử" chỉ nạp file đó vào một DB **tạm** trên máy Mac của anh để kiểm tra. **Chưa có** workflow nào nạp bản sao lưu lên `hmt-prod`, vì chuỗi kết nối DB chạy thật chỉ nằm trong Secrets của repo deploy và không bao giờ nằm trên máy Mac (luật bảo mật số 1 của `deploy/README.md`). Đây là chỗ hở lớn nhất của kế hoạch quay lại.

**Cần quyết trước 16/11 12:00 (Chat đề xuất, anh chọn):**

- **Cách 1 (khuyến nghị, đã hứa trong `dua-len-chay-that.md`):** viết workflow **Restore production** trong repo deploy: chạy tay, anh duyệt, đọc bản `.age` từ Drive, giải mã bằng khoá `age`, nạp vào `hmt-prod`. Viết xong và **diễn tập trên một project Supabase thử** trước khi dùng.
- **Cách 2 (chỉ chấp nhận được cho deploy 16/11):** vì lúc đó `hmt-prod` **chưa có dữ liệu thật** (dữ liệu cơ sở 5 nạp ngày 17/11, sau deploy), chấp nhận **không khôi phục**, chỉ sửa tiến tới. Cách này **hết hiệu lực** từ khi nạp dữ liệu thật.

**Việc trước 17/11 mà tài liệu hiện chưa trả lời:** nếu **nạp dữ liệu 17/11** chạy hỏng một nửa thì quay về trạng thái "trước khi nạp" thế nào? `docs/van-hanh/nap-du-lieu-17-11.md` hiện không có mục này. Cách tạm đề xuất: chụp sao lưu **ngay trước khi nạp** (như mục 1 bước 1) và chỉ nạp khi Cách 1 đã có. Chat cần chốt.

## 5. Sau khi quay lại: kiểm gì

1. Giao diện mở được bằng cửa sổ ẩn danh, đăng nhập Admin được.
2. `select max(version) from supabase_migrations.schema_migrations;` khớp với dự tính (nếu đang sửa tiến tới: số cuối của bản sửa).
3. Dán lại `sql-kiem-hmt-prod-chi-doc.sql`, so số dòng các bảng chính với ảnh chụp ở mục 1 bước 2: không được **ít đi**.
4. Báo Chat kết quả và giờ xong; Chat ghi lại để tổng kết sau.

## 6. Việc còn thiếu (để Chat xếp phiếu)

1. Workflow **Restore production** (mục 4, Cách 1) và diễn tập trên project thử.
2. Diễn tập mục 3 (Cloudflare Rollback) trên bản thử nghiệm `hmt-staging` để biết các bước đúng trên giao diện hiện tại của Cloudflare.
3. Mục "nạp dữ liệu hỏng giữa chừng" trong `nap-du-lieu-17-11.md` (mục 4).
4. Chat liệt kê, trước mỗi lần deploy, migration nào của bản mới có xoá hoặc đổi tên (mục 3, lưu ý).
