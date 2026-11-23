# Đặc tả giai đoạn 0: Nền móng

Giai đoạn 0 chưa có nghiệp vụ, chỉ dựng nền: hai môi trường, đăng nhập, phân quyền, danh mục, cấu hình, nhật ký, khung giao diện. Xong giai đoạn này, các phân hệ sau chỉ việc cắm vào.

## Tiêu chí hoàn thành (anh Trường tự kiểm trên môi trường thử nghiệm)
- Đẩy code lên GitHub thì môi trường thử nghiệm tự cập nhật; lên bản chạy thật chỉ anh Trường làm được, từ repo `hmt-deploy`.
- Đăng nhập được bằng tài khoản mẫu của mỗi vai trò, trên máy tính và điện thoại.
- Nhân viên CS5 không đọc được dữ liệu CS1, kể cả khi gọi thẳng vào cơ sở dữ liệu. Bộ kiểm thử tự động chứng minh điều này.
- Menu chỉ hiện phân hệ mà vai trò đó được dùng.
- Màn quản trị: người dùng, vai trò và quyền, danh mục gốc, Cài đặt, công tắc tính năng.
- Danh mục gốc nạp đủ theo file 02.
- Mọi thay đổi dữ liệu có nhật ký: ai, lúc nào, đổi gì.
- Màn Cài đặt sửa được tham số nghiệp vụ, có giới hạn và nhật ký; công tắc tính năng bật theo từng cơ sở.
- Kiểm thử tự động báo lỗi khi code có số nghiệp vụ viết cứng.
- Sao lưu tự động mỗi đêm lên Google Drive chạy, đã khôi phục thử thành công một lần.
- Toàn bộ chạy trên gói miễn phí; có báo cáo sử dụng hằng tuần.

## Các bước
| Bước | Nội dung | Anh Trường kiểm |
|---|---|---|
| 1. Hạ tầng | Repo `hmt-platform` và `hmt-deploy`, React (Vite), Supabase hai project Free, migration, CI trên GitHub, Cloudflare Pages, giữ project không bị tạm dừng | Mở được trang thử nghiệm; một thay đổi nhỏ đi đủ vòng nhánh → thử nghiệm → anh bấm chạy ở `hmt-deploy` → chạy thật |
| 2. Nền dữ liệu | Danh mục, cấp mã, nhật ký, Cài đặt, công tắc tính năng, dữ liệu giả | Danh mục đúng file 02 |
| 3. Đăng nhập, phân quyền | Tài khoản, vai trò, ma trận quyền, RLS theo cơ sở, bộ kiểm thử quyền | Đăng nhập từng vai trò; CS5 không thấy CS1 |
| 4. Khung giao diện | Sau khi Claude Design xong hệ thống thiết kế: khung ba cổng, menu theo quyền, màn quản trị | Dùng thử trên máy tính, điện thoại |
| 5. Vận hành | Sao lưu sang Google Drive, cảnh báo, khôi phục thử, sổ tay | Khôi phục thử thành công |

Mỗi bước là một yêu cầu riêng; xong bước này anh Trường kiểm rồi mới sang bước sau.

## Môi trường
Mọi thứ dùng gói miễn phí, kể cả chạy thật (chốt 09/10/2026).

| | Thử nghiệm | Chạy thật |
|---|---|---|
| Cơ sở dữ liệu | Supabase Free `hmt-staging` | Supabase Free `hmt-prod` |
| Giao diện | Cloudflare Pages, bản xem trước cho từng PR | Cloudflare Pages |
| Địa chỉ | Địa chỉ miễn phí `*.pages.dev` (sau có thể `thu.hoamatoan.edu.vn`) | `app.hoamatoan.edu.vn` |
| Dữ liệu | Giả hoặc đã che tên, số điện thoại | Thật |
| Ai dùng | Anh Trường, Claude Code, người thử | Toàn bộ HMT |
| Ai đưa code lên | GitHub Actions khi gộp `main` | Anh Trường bấm workflow trong repo `hmt-deploy` |

Thứ tự mỗi thay đổi: nhánh riêng → PR → kiểm thử tự động (trượt thì không gộp) → gộp `main` → thử nghiệm tự cập nhật, anh thử → anh bấm chạy ở `hmt-deploy` → chạy thật.

**Bước duyệt miễn phí:** GitHub Free không có bảo vệ nhánh, bước duyệt cho repo riêng tư. Thay bằng repo `hmt-deploy` đặt ở một tài khoản GitHub riêng chỉ anh Trường dùng (không đăng nhập trên máy Claude Code làm việc); khoá của bản chạy thật chỉ nằm ở đó. Claude Code (dùng TÀI KHOẢN CHỦ DỰ ÁN) không thấy repo này nên không đụng được bản chạy thật.

Thay đổi cấu trúc cơ sở dữ liệu nằm trong file migration có đánh số trong repo, chạy giống hệt ở hai môi trường; không ai sửa tay cơ sở dữ liệu chạy thật. Khoá, mật khẩu kỹ thuật nằm trong cài đặt GitHub, Cloudflare, Supabase, không nằm trong repo. Hai repo đều riêng tư.

Project Supabase Free tự tạm dừng sau 1 tuần không dùng: workflow hằng ngày gọi vào để giữ chạy (chủ yếu cho `hmt-staging`).

## Đăng nhập
| Người dùng | Cách đăng nhập | Ai tạo tài khoản | Giai đoạn |
|---|---|---|---|
| Nhân viên | Email + mật khẩu (HMT chưa có Google Workspace; có sau thì bật thêm Google) | Admin | 0 |
| Giáo viên, trợ giảng | Như nhân viên | Admin | 0 |
| Học sinh | Tên đăng nhập = mã học sinh + mật khẩu trung tâm cấp, **không bắt đổi mật khẩu lần đầu** (anh Trường chốt 19/11/2026, E31: «học sinh không cần đổi lần đầu, cần thì tự đổi sau»; tham số `first_password_change_required_student`, mặc định Tắt; nhân viên `first_password_change_required_staff` mặc định Bật), không cần email | CSKH hoặc Admin | 0 làm khung, 4 dùng thật |
| Phụ huynh | Chốt sau | CSKH | 4 |

- Nghỉ việc, dừng học thì **khoá** tài khoản, không xoá.
- Quên mật khẩu: giai đoạn 0 nhân viên liên hệ quản trị viên (theo thiết kế P1 v4, anh OK 18/10); tự đặt lại qua email làm sau; học sinh nhờ CSKH.
- Admin và Kế toán: xác thực hai bước KHÔNG bắt buộc từ 19/11/2026 (anh Trường chốt: «mỗi lần vào phải xác thực là không cần thiết»). Một tham số `mfa_required_enabled` (mặc định tắt) quyết định; bật lại thì bắt buộc như cũ. Trang cài thiết bị hai bước vẫn có ở Hồ sơ (tự nguyện). Xem migration 472.
- **Không chuyển mật khẩu từ hệ thống cũ.**

## Phân quyền
Quyền = vai trò × phạm vi dữ liệu × hành động trên từng phân hệ. Chặn trong cơ sở dữ liệu (RLS); giao diện chỉ ẩn nút cho gọn.

| Vai trò | Phạm vi mặc định | Làm gì |
|---|---|---|
| `ADMIN` Ban giám đốc, IT (anh Trường) | Toàn hệ thống | Mọi việc, quản trị người dùng, quyền, danh mục, cài đặt |
| `BRANCH_MANAGER` Trưởng cơ sở | Cơ sở mình | Mọi việc trong cơ sở, duyệt |
| `SALES` Tư vấn tuyển sinh | Cơ sở mình | Lead, cơ hội, kiểm tra đầu vào, báo giá, đơn hàng, phiếu thu |
| `CSKH` Chăm sóc, vận hành lớp | Cơ sở mình | Phụ huynh, học sinh, ghi danh, lớp, buổi, điểm danh, tái tục |
| `ACCOUNTANT` Kế toán | Toàn hệ thống | Duyệt phiếu thu, đối soát, xuất số liệu |
| `TEACHER` Giáo viên | Lớp, buổi được phân công | Lịch dạy, điểm danh, nhận xét, chấm bài |
| `TA` Trợ giảng | Lớp, buổi được phân công | Như giáo viên |
| `STUDENT` Học sinh | Chính mình | Bài tập, nộp bài, kết quả |
| `PARENT` Phụ huynh | Các con của mình | Xem kết quả, nhận xét, học phí |

- Phạm vi: Toàn hệ thống, Cơ sở mình, Của tôi, Được phân công, Chính mình.
- Hành động: xem, tạo, sửa, huỷ, duyệt, xuất file, giao việc.
- Mỗi nhân viên thuộc đúng một cơ sở. Ma trận quyền mặc định lấy từ hệ thống cũ (`docs/seed/old_permission_matrix.csv`); Admin sửa trên màn quản trị, mọi lần sửa vào nhật ký.

## Nền dữ liệu
| Thành phần | Luật |
|---|---|
| Danh mục | Mỗi danh mục: mã (không đổi), tên hiển thị, thứ tự, Đang dùng/Ngừng. Ngừng thay cho xoá |
| Cấp mã | Hàm trong cơ sở dữ liệu, dùng bảng đếm khoá dòng: không trùng, không dùng lại, không nhảy số, kể cả khi hai người tạo cùng lúc |
| Nhật ký thao tác | Mọi bảng nghiệp vụ tự ghi ai, lúc nào, trường nào đổi từ gì sang gì. Không ai sửa, xoá được nhật ký |
| Ghi chú trao đổi | Một khung dùng chung cho mọi bản ghi |
| Không xoá cứng | Huỷ là đổi trạng thái. Chỉ Admin xoá bản ghi nhập nhầm, vẫn có nhật ký |
| Tiền, giờ, ngày | Tiền lưu số nguyên đồng. Giờ học lưu số thập phân. Thời điểm lưu UTC, hiển thị giờ Việt Nam |
| Mã cũ | Mọi bảng chuyển từ Sheet có cột mã tham chiếu, tìm kiếm được |

## Quy ước viết nghiệp vụ bằng SQL
1. Mỗi hàm một việc, tên nói rõ việc đó; quá ~80 dòng thì tách hàm con.
2. Đầu mỗi hàm có chú thích tiếng Việt: làm gì, ai được gọi, đầu vào, kết quả, các luật áp dụng trỏ về mục trong docs/spec/.
3. Mỗi luật một đoạn code có chú thích riêng; không gộp nhiều luật vào một câu SQL khó đọc.
4. Mỗi luật có kiểm thử pgTAP cho trường hợp đúng và trường hợp bị chặn; tên bài kiểm thử ghi luật bằng tiếng Việt.
5. Lỗi có mã (ví dụ HMT_QUY_GIO_AM) và câu tiếng Việt để giao diện hiện thẳng.
6. Không dùng SQL động trừ khi bắt buộc, có ghi lý do.
7. Luật quá rắc rối cho SQL (nhiều nhánh, tính toán dài, gọi dịch vụ ngoài, chạy lâu): dừng lại, báo anh, đề xuất Edge Function hoặc service riêng.
8. docs/nghiep-vu/ liệt kê các hàm nghiệp vụ, cập nhật trong cùng PR.

## Cấu hình trên giao diện (4 tầng)
| Tầng | Gồm | Ai sửa | Luật |
|---|---|---|---|
| 1. Danh mục | Cơ sở, môn, khối, phân loại lớp, trình độ, hình thức, nguồn, giai đoạn lead/cơ hội, lý do huỷ test, loại hoạt động, phòng học, tỉnh và phường | Admin | Thêm, đổi tên hiển thị, đổi thứ tự, Ngừng. Không xoá, không đổi mã |
| 2. Tham số nghiệp vụ | Cho học trước tối đa (2 buổi), tự chốt buổi (30 phút, quét 2 giờ tới), hạn GV điểm danh (8 giờ), khối tách Đại/Hình (7), ngưỡng sắp hết giờ, thời hạn gói (6 tháng)… | Admin | Có kiểu, đơn vị, khoảng cho phép, giải thích, nhật ký. Cơ sở ghi đè được giá trị chung khi cần |
| 3. Cấu hình có hiệu lực | Bảng giá, gói, chiết khấu, khung chương trình, rubric nhận xét, ma trận quyền | Admin | Ngày hiệu lực hoặc phiên bản. Bản ghi chụp lại giá trị lúc tạo; đổi cấu hình không ảnh hưởng ngược |
| 4. Luật lõi | Cấu trúc mã, luật trừ giờ, chuyển tình trạng, tính tiền và giờ | Code | Đổi qua nhánh, kiểm thử, thử nghiệm, anh Trường duyệt |

Thêm **công tắc tính năng theo cơ sở**: mỗi phân hệ bật riêng cho từng cơ sở (chạy CS5 trước). Giai đoạn 0 dựng khung: màn danh mục dùng chung, màn Cài đặt, màn ma trận quyền, công tắc tính năng; nạp sẵn nguồn, giai đoạn, lý do huỷ, loại hoạt động, tỉnh và phường từ `docs/seed/`. Giai đoạn sau khai báo tham số của mình vào Cài đặt.

## Giao diện
- Claude Design dựng hệ thống thiết kế HMT: màu thương hiệu cam `#EF6925`, nền tối `#211C16`, chữ, khoảng cách, nút, ô nhập, bảng, thẻ, thanh trạng thái, hộp thoại, thông báo. Không dùng hộp thoại mặc định của trình duyệt.
- Giữ thói quen cũ: thanh trạng thái trên đầu bản ghi, nút liên kết góc phải, ghi chú và lịch sử cột phải, danh sách có tìm, lọc, nhóm, yêu thích, xem dạng danh sách, kanban, lịch.
- Mỗi bản ghi có đường link riêng; người không có quyền thì báo rõ.
- Cổng CRM ưu tiên máy tính; cổng Giáo viên và Học tập ưu tiên điện thoại.

## Kiểm thử, sao lưu, cảnh báo
| Việc | Cách làm |
|---|---|
| Kiểm thử phân quyền | Mỗi vai trò thử đọc, ghi dữ liệu trong và ngoài phạm vi; chạy mỗi lần đẩy code |
| Kiểm thử giao diện | Máy tự bấm thử đăng nhập, menu, màn quản trị trên cỡ màn hình máy tính và điện thoại |
| Sao lưu | Gói Free không có sao lưu. Mỗi đêm workflow trong `hmt-deploy` xuất toàn bộ DB chạy thật, mã hoá, đẩy lên Google Drive của `[email vận hành]`; giữ 30 bản hằng ngày + 12 bản hằng tháng |
| Khôi phục | Mỗi tháng một lần, anh Trường tự khôi phục thử vào một DB Docker tạm trên máy anh, kiểm xong xoá ngay; Claude Code không chạy bước này. Ghi các bước vào sổ tay |
| Cảnh báo | Sao lưu thất bại, lỗi hệ thống, đăng nhập sai nhiều lần → email admin |
| Báo cáo sử dụng | Hằng tuần gửi anh Trường: dung lượng DB, lượng tải ra, thời gian phản hồi so với giới hạn gói Free. Ngưỡng nâng Supabase Pro: DB > 400 MB, tải ra > 4 GB/tháng, hoặc chậm giờ cao điểm |
| Sổ tay vận hành | Tạo, khoá tài khoản; đặt lại mật khẩu; khôi phục; làm gì khi lỗi |
