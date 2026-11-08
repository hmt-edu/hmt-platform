# Lịch 06/11 đến 28/11, "cổng CRM xong" và diễn tập nạp một lần (06/11/2026)

Anh đổi kế hoạch dữ liệu 06/11: **dừng nạp dữ liệu khách hàng thật** (Cơ hội, Phụ huynh, Học sinh, ghi danh, số dư, nợ đầu kỳ) cho tới khi cổng CRM xong, sau đó **nạp một lần** vào ngày anh chốt. Mốc 10/11 "nạp dữ liệu, nhân viên dùng tuyển sinh" bỏ. Giữ nguyên màn Nhập, hàm nạp, bộ chuyển Cơ hội, quy tắc năm sinh, ngoại lệ R-CRM-03 và nối theo SĐT. **Ngoại lệ:** vẫn nạp tài khoản nhân sự sớm (108 người theo bộ chuyển hiện tại) để nhân viên đăng nhập thử, lộ lỗi đăng nhập, xác thực hai bước, phân quyền trên bản thật.
Bản chạy thật **không cập nhật 07/11**: cập nhật một lần cùng B2 khoảng 12/11 (kiểm hạ tầng, đăng nhập Admin, nạp nhân sự, chưa nạp khách hàng). Tag bản chạy thật sinh sau khi B2 xong.

## 1. Kế hoạch từng ngày (giờ-ước, thang đã dùng từ đầu; công suất đo khoảng 25 đến 30 giờ-ước mỗi ngày)

| Ngày | Việc | Giờ-ước |
|---|---|---|
| 06/11 | Gộp #175 (khi anh OK); bộ chuyển Người dùng (xong); B2 bài pgTAP phiếu thu; PR tài liệu cuối ngày | 14 |
| 07/11 | B2 giao diện: TC-03 tạo từ đơn, TC-02 bản ghi, TC-01 danh sách | 18 |
| 08/11 | B2 giao diện: TC-04 hàng chờ kế toán, TC-05 duyệt, TC-06 huỷ, TC-07 in biên nhận; bộ lọc **Chờ ghi danh**, cờ đủ cọc, giờ đã cấp (R-TIEN-20, 21) | 20 |
| 09/11 | B2 e2e, sửa lỗi, mở PR B2; màn Người dùng nút **Tạo** và **Sửa email** (khung đợt 1 trước 09/11) | 24 |
| 10/11 | Nhóm A (bỏ hai ô thanh toán khỏi Đơn hàng), vượt trần chỉ cảnh báo, chip chiết khấu; màn Danh mục | 24 |
| 11/11 | Màn Bảng giá, Gói bán (khung đợt 2 trước 11/11); BH03_in (che SĐT chỉ ở bản in) | 22 |
| 12/11 | **Cập nhật bản chạy thật (anh làm qua `hmt-deploy`, kèm B2, nạp 108 tài khoản nhân sự)**; ưu đãi linh hoạt (mặc định 5%); nạp Số dư sổ chỉ đọc; màn Cơ sở và phòng học | 26 |
| 13 đến 14/11 | Đăng nhập bằng tên đăng nhập; giờ lưới lịch 7 đến 21, thời lượng lịch hẹn, phiếu test thành tham số; chỉnh màn Nhập theo khung Design, nút **Tải file mẫu**; Thu nợ đầu kỳ và "Dùng số dư" | 34 |
| 15 đến 21/11 | Đào tạo: lớp, thời khoá biểu, ghi danh, buổi học, điểm danh (phần tối thiểu), nối ghi danh với phiếu thu | 190 |
| 22 đến 23/11 | **Chuẩn bị nạp một lần (anh chốt Q-N1):** bộ chuyển Phụ huynh, Học sinh, Ghi danh, Số dư; bảng ghép 7 người phụ trách Cơ hội với tài khoản nhân sự; diễn tập đầy đủ trên staging bằng dữ liệu giả lớn (hai lần, có hoàn tác); nạp thử 3 dòng mỗi loại trên bản chạy thật | 46 |
| 24 đến 27/11 | **Nạp thật một lần (dự kiến 25/11)** và theo dõi, sửa lỗi sau nạp (khoảng 8); Cổng giáo viên: lịch dạy, việc cần làm, điểm danh, nhận xét buổi (phần tối thiểu, phần BTVN lùi nếu vượt) | 110 |
| 28/11 | Aftersale: chỉ lõi ticket và SLA (A1a, A1b) | 28 |
| **Cộng** | | **608** |

**Phần lùi sau 28/11 nếu vượt công suất:** Aftersale giao diện (A2), ticket giáo viên trên cổng (A3), phiếu nghiệp vụ nền và phiếu 1 đến 4 (A4, A5); Cổng giáo viên: BTVN, xuất nhận xét. Anh chốt bản cuối khi thấy tiến độ thật ở 21/11.

Nhu cầu đầy đủ ước 560 đến 830 giờ-ước so với công suất khoảng 690 (23 ngày): **sát trần, nhiều khả năng vượt ở Aftersale và Cổng giáo viên**. Đào tạo, Cổng giáo viên, Aftersale là phần có khả năng không xong hết; cam kết tối thiểu như đã chốt, phần còn lại ghi "làm tay" hoặc sau 28/11. Nếu chạy hai phiên song song sau 12/11 (anh quyết sau khi xem phút CI) thì Đào tạo và Cổng giáo viên có thể xong trọn.

## 2. "Cổng CRM xong": điều kiện để anh chốt ngày nạp một lần

Cổng xong khi **tất cả** các mục sau đạt (em báo từng mục khi xong, anh chốt ngày dựa trên danh sách này):

1. **Tuyển sinh** (đã xong): Lead, Cơ hội, Lịch hẹn, Phiếu test; màn Nhập có loại Người dùng, Cơ hội, Phụ huynh, Học sinh.
2. **Bán hàng**: báo giá, đơn hàng, nhóm A, vượt trần chỉ cảnh báo, chip chiết khấu, ưu đãi linh hoạt, BH03_in. (Voucher hoãn sau 28/11, không thuộc cổng.)
3. **Thu chi**: phiếu thu B2 chạy thật trên bản chạy thật với Trưởng cơ sở CS5 đã có người, hai bước duyệt đã thử; Thu nợ đầu kỳ; "Dùng số dư"; sổ số dư.
4. **Đào tạo**: lớp, ghi danh, buổi, điểm danh (phần tối thiểu); **ghi danh chặn cơ hội còn dấu thiếu thông tin em**; bộ lọc "Chờ ghi danh" dùng được.
5. **Cấu hình nhập tay xong trên bản chạy thật**: Gói bán, Bảng giá, Chiết khấu, Điều khoản thanh toán, Cơ sở và phòng học, Danh mục, Công tắc tính năng (danh sách "anh phải nhập" ở mục 4 dưới đây).
6. **Tài khoản nhân sự đã nạp** (108 người), nhân viên đã đăng nhập thử: đăng nhập, xác thực hai bước, phân quyền, đặt lại mật khẩu chạy đúng; lỗi lộ ra đã sửa.
7. **Bộ chuyển và nối**: bộ chuyển Cơ hội (xong), Phụ huynh, Học sinh, Ghi danh, Số dư (viết khi anh chốt ngày); **bảng ghép 7 người phụ trách Cơ hội** với tài khoản nhân sự; chức năng nối Phụ huynh, Học sinh theo SĐT đã làm.
8. **Diễn tập đầy đủ xong** trên staging bằng dữ liệu giả lớn, đạt tiêu chí mục 3.
9. **Sao lưu đêm** của bản chạy thật chạy được và đã khôi phục thử (anh làm).
10. **Mỗi cơ sở có người duyệt phiếu thu bước quản lý:** CS1, CS2, CS4 có Trưởng cơ sở trong file nhân sự. **CS5 có tài khoản quản lý tạm do người thật giữ** (anh chốt 06/11): "Quản lý CS5 (tạm)", vai BRANCH_MANAGER, cơ sở CS5, do người quản lý CS4 giữ (một người thật, không dùng chung, không phải người lập phiếu CS5); thêm một dòng vào bộ chuyển Người dùng (tổng nạp 112, tên đăng nhập theo quy tắc, email quy ước). **Đổi tài khoản này khi CS5 có Trưởng cơ sở** (xem "Việc cần đổi sau"). Không làm PR "cơ sở phụ".
11. **Dự phòng bước kế toán:** R-HT-01 cho Admin gán tạm vai Kế toán cho người làm thay khi kế toán vắng (có nhật ký, có thời hạn); **cột thời hạn của vai trò chưa có** nên hiện phải gỡ vai tay; cân nhắc làm vai trò có hạn trước khi nạp.

Không thuộc cổng (làm sau): voucher, Aftersale phiếu nhóm B, C, báo cáo, Cổng học tập.

## 3. Diễn tập nạp đầy đủ trên staging bằng dữ liệu giả lớn

Mục tiêu: nạp một lần trên bản thật chỉ chạy đúng thứ tự đã tập, không bất ngờ.

1. **Dữ liệu giả** (không bao giờ dùng dữ liệu thật ở staging): em sinh file CSV cùng định dạng với file thật, quy mô bằng hoặc lớn hơn (Người dùng khoảng 120; Cơ hội 500 đến 5.000; Phụ huynh, Học sinh theo khối lượng thật; ghi danh; số dư), trộn đủ tình huống: dòng hợp lệ, trùng, lỗi từng loại, L5 trở lên thiếu thông tin em, SĐT trùng phụ huynh có sẵn, người phụ trách không có tài khoản.
2. **Thứ tự nạp** (cố định, ghi vào tài liệu): Người dùng, Phụ huynh, Học sinh, Cơ hội (nối theo SĐT), Ghi danh, Số dư, Nợ đầu kỳ. Mỗi loại: xem trước, đọc báo cáo, nạp thật, tải dòng lỗi, nạp lại đúng file (toàn bỏ qua).
3. **Đo**: thời gian mỗi lô (tối đa `import_max_rows` mỗi lần), EXPLAIN các câu chính trên dữ liệu lớn, dung lượng DB (giới hạn 500 MB), băng thông.
4. **Kiểm** sau nạp: đếm khớp (số dòng nguồn, nạp, trùng, lỗi); không còn cơ hội L5 trở lên thiếu thông tin em mà chưa có dấu; phụ huynh không trùng SĐT; nối Phụ huynh, Học sinh theo SĐT đúng và liệt kê các khớp mơ hồ; tài khoản đăng nhập thử được.
5. **Hoàn tác**: câu SQL xoá sạch dữ liệu diễn tập trên staging (em soạn, anh chạy); tập hai lần.
6. **Tiêu chí đạt**: hai lần diễn tập liên tiếp cho cùng kết quả đếm; không lỗi hệ thống; mỗi lô dưới 2 phút; không dòng nào mất.
7. **Trên bản chạy thật**: nạp thử 3 dòng thật mỗi loại, anh kiểm, rồi nạp toàn bộ; đối chiếu số dòng với `app.import_log`.

## 4. Số phút GitHub Actions và hai phiên song song

- **Đã dùng (repo `hmt-platform`, từ 01/11):** 538 phút tính tiền trong 41 lượt chạy (04/11: 187, 05/11: 350). Hoá đơn của anh (4,51 đô trong 5 ngày đầu tháng) lệch với số này (em không thấy phần chênh: có thể từ `hmt-deploy`, `hmt-v2` hoặc làm tròn); em **không xem được trang Billing**, anh xem số chính thức (Settings, Billing and plans, Actions).
- **Còn lại (ước):** hạn mức 12 đô tương đương 2.000 phút Linux ở giá 0,006 đô mỗi phút; nếu hoá đơn thực tế gấp khoảng 2,6 lần số phút của repo này (như đã thấy) thì còn khoảng 220 phút, nếu không thì còn khoảng 1.460 phút.
- **Mức dùng dự kiến:** sau khi giảm phút CI (#171), một PR có code tốn khoảng 19 đến 28 phút; một phiên làm 8 đến 10 PR mỗi ngày tốn khoảng 200 phút mỗi ngày. Một phiên: **hết hạn mức khoảng 10 đến 14/11 (ước thấp) hoặc 08 đến 09/11 (nếu hoá đơn gấp 2,6)**. Hai phiên song song: hết nhanh gấp đôi (khoảng 400 phút mỗi ngày).
- **Kết luận:** chạy hai phiên từ 13/11 gần như chắc chắn cần repo công khai (hoặc thêm thanh toán, anh đã nói không). Nên anh quyết sớm và chạy quét trước (mục 5).

## 5. Danh sách quét cần anh duyệt nếu phải mở repo công khai (chỉ lập danh sách, chưa quét lại)

Kết quả quét 05/11 (anh đã duyệt): không có khoá bí mật; email và tên tài khoản vận hành đã thay bằng nhãn trong bản hiện tại. Trước khi mở công khai quét lại:
1. **Khoá và token** trong toàn bộ lịch sử và mọi nhánh: gitleaks cộng quét tay các mẫu `sb_secret_`, JWT, khoá riêng tư, token Cloudflare, mã Turnstile, chuỗi kết nối DB (kể cả file mới từ 05/11: `import-users`, bộ chuyển, bài kiểm).
2. **Dữ liệu thật** trong lịch sử commit: file xlsx, csv, dump SQL, `_inbox`; số điện thoại, email, họ tên thật (đối chiếu với file nhân sự và các file nạp đang có trên máy, trong bộ nhớ, không in); tài liệu và ảnh chụp màn hình (`docs/anh-chup/`) có dữ liệu thật không.
3. **Seed và bài kiểm**: không có tên, SĐT thật của học sinh, phụ huynh (CLAUDE.md đã cấm); kiểm các số 20 file đã liệt kê 05/11 và file bài kiểm mới (063, 073).
4. **Tài liệu nội bộ** công khai theo: `CLAUDE.md`, `docs/`, `design/` (anh cân nhắc có chấp nhận lộ thiết kế và nghiệp vụ không).
5. **Cấu hình CI**: secrets chỉ nằm ở Settings của repo (không lộ khi công khai), nhưng workflow chạy được bởi PR từ fork với quyền đọc: kiểm `pull_request_target`, quyền `permissions`, bài kiểm cách ly với hmt-prod.
6. **Email còn trong lịch sử cũ** (anh đã chấp nhận ở 05/11): xác nhận lại khi mở.
7. **Sau khi mở:** bật quét bí mật (secret scanning, push protection) trên GitHub.

## 6. Việc cần đổi sau (ghi nhận 06/11)

- **Tài khoản "Quản lý CS5 (tạm)":** khi CS5 có Trưởng cơ sở thì Admin gán vai Trưởng cơ sở cho người đó (màn Người dùng), gỡ vai và khoá tài khoản tạm; phiếu thu đang chờ ở bước quản lý chuyển người duyệt bằng "Chuyển người duyệt" trước khi khoá.
- **Cột thời hạn cho vai tạm của kế toán** (câu d, R-HT-01 "có thời hạn"): **làm sau 28/11**, chưa làm. Trước đó, kế toán vắng thì Admin gán tạm vai Kế toán cho người làm thay và gỡ vai bằng tay, có nhật ký.
- **Người dùng ở nhiều cơ sở** (danh sách cơ sở theo người): hoãn, không làm PR "cơ sở phụ".

## 7. Quét repo trước khi mở công khai: kế hoạch và giờ-ước (bắt đầu sáng 07/11, anh duyệt kết quả rồi tự đổi chế độ repo)

Một phiên, không đẩy commit chỉ để thử CI, gom lại, chạy `check:all` trên máy. Chưa đổi chế độ repo. Báo kết quả từng mục.

| # | Mục quét | Cách làm | Giờ-ước |
|---|---|---|---|
| 1 | Khoá và token | gitleaks toàn lịch sử và mọi nhánh, quét tay các mẫu, file mới từ 05/11 | 1 |
| 2 | Dữ liệu thật trong lịch sử | file xlsx, csv, dump, `_inbox`; đối chiếu trong bộ nhớ với file nhân sự và các file nạp đang có (không in); tài liệu, ảnh chụp | 2 |
| 3 | Seed và bài kiểm | số điện thoại, tên trong seed, 063, 073, các bài kiểm mới | 0,5 |
| 4 | Tài liệu nội bộ công khai theo | liệt kê `CLAUDE.md`, `docs/`, `design/` để anh quyết | 0,5 |
| 5 | Cấu hình CI | workflow cho phép PR từ fork, `pull_request_target`, `permissions`, secrets, bài kiểm cách ly hmt-prod | 1 |
| 6 | Email trong lịch sử cũ | đề xuất cách xử lý **không force-push main** (xem dưới) | 1 |
| 7 | Bật secret scanning | các bước chủ repo bật secret scanning và push protection (anh làm trên trình duyệt) | 0,5 |
| | **Cộng** | | **6,5** |

**Đề xuất xử lý email trong lịch sử cũ (không force-push `main`):** (a) chấp nhận: email là địa chỉ liên hệ, không phải khoá; hoặc (b) **tạo repo công khai mới** từ cây thư mục hiện tại (đã dùng nhãn thay email) với lịch sử gộp một commit, repo `hmt-platform` hiện tại giữ riêng tư làm kho lịch sử; mất lịch sử PR trong repo công khai, phải gắn lại Cloudflare và Secrets (khoảng 2 đến 3 giờ-ước); hoặc (c) viết lại lịch sử bằng `git filter-repo` trên **bản sao** rồi đẩy sang repo công khai mới, giữ commit nhưng đổi email (khoảng 3 đến 4 giờ-ước). `main` của repo riêng tư không bị đụng ở cả ba cách.
