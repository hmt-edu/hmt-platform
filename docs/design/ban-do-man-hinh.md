# HMT Platform: bản đồ màn hình

> Ghi chú của repo (12/10/2026): chép từ `HMT_BAN_DO_MAN_HINH.md` của anh Trường; các dòng CHUNG-02, CHUNG-03, CHUNG-08, CHUNG-13, QT-08, QT-13 đã sửa theo chốt của anh chiều 12/10 (đánh dấu **(chốt 12/10)**). Mã luật `R-*` xem `docs/spec/04-luat-nghiep-vu.md`. **Bước 4 điều chỉnh TC-05, TC-09, TC-11**: Admin không duyệt phiếu thu, đảo khoản, phiếu chi trực tiếp (R-HT-01); cột Vai trò của ba màn này còn ghi "KT, AD". Chi tiết: `docs/nghiep-vu/doi-chieu-luat-1210.md`.

Danh sách bắt buộc cho Claude Design (chốt 11/10/2026). Mỗi dòng là một màn hoặc hộp thoại; **mã màn là tên artboard**. Không thêm, bớt màn khi chưa ghi vào manifest.

**Mức:** A = vẽ đầy đủ mọi trạng thái · B = vẽ bố cục bằng khuôn, một trạng thái chính · C = không vẽ, chỉ ghi trong manifest là dựng từ khuôn nào · Looker = báo cáo làm trên Looker Studio, không vẽ.

**Vai trò:** AD Admin · BM Trưởng cơ sở · SA Tuyển sinh · CS CSKH/vận hành lớp · KT Kế toán · GV Giáo viên · TG Trợ giảng · HS Học sinh · PH Phụ huynh.

**Mã luật:** R-* xem file [luat-cho-thiet-ke.md](luat-cho-thiet-ke.md) (mục 4–5); S02-* luật xếp lớp; S03-* đăng nhập, quyền, cấu hình: bảng mã ở [ma-luat-S02-S03.md](ma-luat-S02-S03.md).

## Khuôn màn (đợt 5.1)

| Mã | Khuôn | Gồm |
|---|---|---|
| K01 | Khung CRM máy tính | Menu trái theo quyền, thanh trên (tìm kiếm, chọn cơ sở, thông báo, tài khoản), vùng nội dung |
| K02 | Khung di động | Thanh dưới 4–5 tab, tiêu đề trên, nút quay lại; cho cổng Giáo viên và Học tập |
| K03 | Danh sách | Thanh lọc nhanh, lọc nâng cao, nhóm theo, yêu thích, chọn cột, đổi kiểu xem, chọn nhiều + thao tác hàng loạt, phân trang 25, xuất; dưới 640px thành thẻ |
| K04 | Kanban | Cột theo giai đoạn, thẻ có thông tin chính, kéo thả chỉ đi tới khi luật yêu cầu, đếm số thẻ |
| K05 | Lịch | Tuần/tháng/ngày, theo phòng hoặc người, màu theo loại, bấm mở bản ghi |
| K06 | Bản ghi | Thanh trạng thái + nút hành động, nút liên kết có số đếm, tiêu đề + mã, tab nội dung, cột phải ghi chú trao đổi + lịch sử thay đổi |
| K07 | Biểu mẫu tạo/sửa | Trang hoặc ngăn kéo, nhóm trường, kiểm lỗi tại chỗ, lưu nháp |
| K08 | Hộp thoại thao tác | Tóm tắt việc sắp làm, trường bắt buộc (lý do), cảnh báo không chặn, lỗi chặn kèm danh sách lý do, xác nhận |
| K09 | Tổng quan / báo cáo | Bộ lọc khoảng ngày + cơ sở, thẻ số, biểu đồ, bảng chi tiết, xuất |
| K10 | Cấu hình | Danh mục (thêm, đổi tên, thứ tự, ngừng), tham số (kiểu, đơn vị, khoảng), cấu hình có hiệu lực (phiên bản, ngày hiệu lực, lịch sử) |
| K11 | Trang đơn | Đăng nhập, lỗi, khoá: logo, một khối nội dung, không có menu |
| K12 | Tác vụ di động từng bước | Danh sách em, thao tác một tay, thanh tiến độ, bấm Lưu (không tự lưu; "Lưu và em tiếp theo" lưu từng em, QĐ-Đ18), bước kế tiếp; dùng cho điểm danh, chấm, nộp bài |
| K14 | Bảng chấm nhanh (laptop) | Hàng = học sinh, cột = trạng thái/tiêu chí; nhập bằng phím số, Tab, phím tắt 1–4 cho điểm danh; ô trống khác điểm 0; ngăn bên xem chi tiết một em; bấm Lưu để lưu cả bảng, rời màn khi chưa lưu thì hiện hộp thoại nhắc của ứng dụng (QĐ-Đ18) |
| K13 | Bản in A4/A5 | Đầu trang logo + thông tin cơ sở, bảng dòng, tổng tiền, chữ ký |

## Đợt 5.2: Chung + Quản trị (giai đoạn 0)

36 màn: A 8, B 16, C 12.


### Chung

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| CHUNG-01 | Đăng nhập nhân viên, giáo viên | Trang · K11 | A | Cả hai | Tất cả NV, GV, TG | Đăng nhập bằng email + mật khẩu, có Turnstile | Đăng nhập; Quên mật khẩu | CHUNG-04, CHUNG-02, CHUNG-10 | S03-01, S03-18, R-HT-03 |
| CHUNG-02 | Xác thực hai bước (nhập mã TOTP) | Trang · K11 | B | Cả hai | AD, KT | Nhập mã 6 số sau khi đăng nhập. **(chốt 12/10)** Không có mã dự phòng | Xác nhận | CHUNG-10 | S03-05 |
| CHUNG-03 | Thiết lập xác thực hai bước lần đầu | Trang · K11 | B | Cả hai | AD, KT | Quét QR, nhập mã xác nhận. **(chốt 12/10)** Không có mã dự phòng; mỗi người đăng ký tối đa 2 thiết bị | Quét mã; Xác nhận | CHUNG-10 | S03-05 |
| CHUNG-04 | Quên mật khẩu (liên hệ quản trị viên) **(theo thiết kế P1 v4, 18/10)** | Trang · K11 | B | Cả hai | Tất cả NV, GV, TG | Màn chỉ nói "Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm."; chưa gửi email tự động | Quay lại đăng nhập | CHUNG-01 | S03-04 |
| CHUNG-05 | Đặt mật khẩu mới (từ link email) **(HOÃN, thiết kế P1 v4)** | Trang · K11 | C | Cả hai | Tất cả NV, GV, TG | Trang có trong code nhưng chưa có màn nào dẫn tới; làm tiếp khi bật quên mật khẩu qua email | Lưu | CHUNG-01 | S03-04 |
| CHUNG-06 | Đăng nhập học sinh (mã HS) | Trang · K11 | A | Điện thoại | HS | Đăng nhập bằng mã học sinh + mật khẩu trung tâm cấp; quên mật khẩu thì nhờ CSKH | Đăng nhập | CHUNG-07, HT-01 | S03-02, S03-04, R-HT-03 |
| CHUNG-07 | Đổi mật khẩu bắt buộc lần đầu | Trang · K11 | B | Cả hai | HS, Tất cả NV | Người được cấp mật khẩu tạm phải đổi ngay | Lưu | HT-01, CHUNG-10 | S03-02 |
| CHUNG-08 | Không thể đăng nhập **(chốt 12/10; chữ theo thiết kế P1 v4)** | Trang · K11 | C | Cả hai | Tất cả | Tiêu đề "Không thể đăng nhập", câu "Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm." Một câu chung cho tạm khoá và khoá hẳn: không nói thời gian khoá, không nói lý do (đăng nhập không lộ trạng thái khoá, chốt 10/10) | Quay lại đăng nhập | CHUNG-01 | S03-03, S03-18, R-HT-03 |
| CHUNG-09 | Hết phiên làm việc | Hộp thoại · K08 | C | Cả hai | Tất cả | Tự đăng xuất khi không dùng quá thời gian theo vai trò | Đăng nhập lại | CHUNG-01 | S03-19 |
| CHUNG-10 | Khung ứng dụng CRM (menu trái, thanh trên, chọn cơ sở; điện thoại: menu thu gọn) | Trang · K01 | A | Cả hai | Tất cả NV, AD | Menu dựng từ ma trận quyền; Admin/Kế toán chọn cơ sở xem; ô tìm kiếm, thông báo, tài khoản | Chuyển phân hệ; Chọn cơ sở; Tìm kiếm; Mở thông báo | CHUNG-11, CHUNG-12, CHUNG-13, CHUNG-14 | S03-06, S03-23, R-HT-01, R-HT-02 |
| CHUNG-11 | Tìm kiếm toàn hệ thống | Hộp thoại · K08 | B | Máy tính | Tất cả NV, AD | Tìm học sinh, phụ huynh, lead, đơn, phiếu thu, lớp theo tên, SĐT, mã mới, mã cũ | Mở bản ghi | Mọi màn bản ghi | S03-15 |
| CHUNG-12 | Trung tâm thông báo | Danh sách · K03 | B | Cả hai | Tất cả | Cảnh báo SLA, quá hạn, cho học trước vượt hạn mức, khiếu nại nghiêm trọng, việc chờ duyệt | Đánh dấu đã đọc; Mở bản ghi | Bản ghi liên quan | R-CS-08, R-CS-04, R-GD-12, R-GV-05 |
| CHUNG-13 | Hồ sơ cá nhân (đổi mật khẩu, hai bước, phiên đăng nhập) | Biểu mẫu · K07 | C | Cả hai | Tất cả | Xem thông tin của mình, đổi mật khẩu, quản lý hai bước. **(chốt 12/10)** Tối đa 2 thiết bị TOTP | Đổi mật khẩu; Thêm, gỡ thiết bị hai bước | CHUNG-03 | S03-05 |
| CHUNG-14 | Trang chủ CRM theo vai trò (việc của tôi hôm nay) | Tổng quan · K09 | A | Máy tính | SA, CS, BM, KT, AD | Mỗi vai trò thấy việc cần làm: lịch hẹn hôm nay, phiếu chờ duyệt, buổi chưa điểm danh, ticket sắp quá hạn | Mở danh sách lọc sẵn | TS-12, TC-04, BUOI-01, CS-01, CHUNG-15 | R-CRM-07 |
| CHUNG-16 | Không có quyền truy cập | Trang · K11 | C | Cả hai | Tất cả | Mở link bản ghi ngoài phạm vi: báo rõ, không lộ dữ liệu | Về trang chủ | CHUNG-14 | S03-16 |
| CHUNG-17 | Không tìm thấy / lỗi hệ thống | Trang · K11 | C | Cả hai | Tất cả | Link sai, bản ghi không tồn tại, lỗi máy chủ (thông báo dễ hiểu, mã lỗi để báo IT) | Về trang chủ; Thử lại | CHUNG-14 | S03-16 |
| CHUNG-18 | Xuất file (có nhật ký) | Hộp thoại · K08 | C | Máy tính | Có quyền xuất, AD | Chọn cột, phạm vi, định dạng; mọi lần xuất ghi nhật ký | Xuất | QT-12 | S03-21 |
| CHUNG-19 | Lưu bộ lọc yêu thích | Hộp thoại · K08 | C | Máy tính | Tất cả NV, AD | Lưu bộ lọc, đặt mặc định, dùng chung hay riêng | Lưu; Đặt mặc định | — | S03-17 |
| CHUNG-20 | Xoá bản ghi nhập nhầm (chỉ Admin) | Hộp thoại · K08 | C | Máy tính | AD | Xoá cứng có lý do, vẫn ghi nhật ký | Xoá | QT-11 | S03-14 |
| CHUNG-22 | Ghi chú trao đổi + lịch sử thay đổi (cột phải mọi bản ghi) | Bản ghi · K06 | A | Cả hai | Tất cả NV, GV | Ghi chú, nhắc tên đồng nghiệp, đính kèm; lịch sử ai đổi gì lúc nào của chính bản ghi | Thêm ghi chú; Đính kèm; Lọc ghi chú/lịch sử | CHUNG-21 | S03-13, S03-17, R-CS-09 |
| CHUNG-24 | Phân hệ chưa bật ở cơ sở này | Trang · K11 | C | Cả hai | Tất cả | Mở link vào phân hệ đang tắt theo công tắc tính năng | Về trang chủ | CHUNG-14 | S03-11 |
| CHUNG-25 | Chọn cổng (người có nhiều vai trò) | Trang · K11 | C | Cả hai | Tất cả NV, GV | Người vừa là nhân viên vừa là giáo viên chọn vào CRM hoặc cổng Giáo viên; đổi cổng từ menu tài khoản | Chọn cổng | CHUNG-10, GV-01 | S03-06 |
| CHUNG-26 | Hộp thoại xác nhận chung + cảnh báo rời trang chưa lưu | Hộp thoại · K08 | B | Cả hai | Tất cả | Thay hộp thoại mặc định của trình duyệt | Ở lại; Rời trang | — | S03-17 |

### Quản trị

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| QT-01 | Người dùng (danh sách) | Danh sách · K03 | B | Máy tính | AD | Danh sách tài khoản nhân viên, giáo viên, trợ giảng; lọc theo vai trò, cơ sở, trạng thái | Tạo; Khoá; Mở khoá; Xuất | QT-02, QT-03 | S03-03, R-HT-02 |
| QT-02 | Người dùng (bản ghi) | Bản ghi · K06 | B | Máy tính | AD | Thông tin, vai trò (nhiều), cơ sở (một), mã NV/GV/TG, trạng thái, lịch sử đăng nhập | Sửa vai trò, cơ sở; Khoá; Đặt lại mật khẩu (mật khẩu tạm hiện đúng một lần ở hộp **K4g** máy tính, **K4e4** điện thoại); Đặt lại hai bước; Thu hồi phiên | QT-04, QT-13 | S03-03, S03-20, S03-23 |
| QT-03 | Tạo người dùng | Biểu mẫu · K07 | B | Máy tính | AD | Tạo tài khoản, cấp mật khẩu tạm (sau khi tạo, mật khẩu tạm hiện đúng một lần ở hộp **K4g** máy tính, **K4e4** điện thoại; đóng hộp rồi không xem lại được) | Tạo | QT-02 | S03-01 |
| QT-04 | Vai trò (danh sách + mô tả) | Danh sách · K10 | B | Máy tính | AD | Các vai trò hệ thống và phạm vi mặc định | Mở ma trận | QT-05 | S03-06 |
| QT-05 | Ma trận quyền (vai trò × phân hệ × hành động × phạm vi) | Cấu hình · K10 | A | Máy tính | AD | Sửa quyền xem, tạo, sửa, huỷ, duyệt, xuất, giao việc; có hiệu lực và nhật ký | Sửa; Xem lịch sử | QT-11 | S03-07, S03-10 |
| QT-06 | Danh mục (danh sách các danh mục) | Danh sách · K10 | B | Máy tính | AD | Mọi danh mục: hệ thống (khoá) và mở; số mục, trạng thái | Mở danh mục | QT-07 | S03-08 |
| QT-07 | Danh mục (sửa các mục) | Cấu hình · K10 | A | Máy tính | AD | Thêm, đổi tên hiển thị, đổi thứ tự, Ngừng; danh mục nhiều cấp (giai đoạn → nhóm con; **(26/10, Đ184)** nguồn lead 3 cấp Source type → Source → Medium, Medium bắt buộc khi Source có Medium con (spec 06 mục 1.1); tỉnh → phường; nhóm → nhóm con ticket); danh mục khoá chỉ đổi tên | Thêm; Đổi tên; Kéo thứ tự; Ngừng | — | S03-08, R-CS-11, R-GV-11, R-HT-04 |
| QT-08 | Cơ sở và phòng học | Cấu hình · K10 | B | Máy tính | AD | Cơ sở (CS3 Hội sở không có phòng), phòng học từng cơ sở, sức chứa. **(chốt 12/10)** Cơ sở là danh mục khoá: không thêm, không ngừng trên giao diện (mở cơ sở mới qua migration); sửa được tên hiển thị, địa chỉ, hotline | Sửa tên, địa chỉ, hotline cơ sở; Thêm, sửa, ngừng phòng | — | S03-24, R-LOP-08 |
| QT-09 | Cài đặt tham số nghiệp vụ | Cấu hình · K10 | A | Máy tính | AD | Mọi tham số: kiểu, đơn vị, khoảng cho phép, giải thích; giá trị chung và ghi đè theo cơ sở; nhật ký | Sửa; Ghi đè cơ sở; Xem lịch sử | QT-11 | S03-09, R-GD-12, R-GIO-05, R-GV-05, R-GD-07, R-GD-13, R-TIEN-05, R-TIEN-20, R-GD-09, R-TIEN-28, R-TIEN-29, R-CS-08, R-CS-06, R-HT-03 |
| QT-10 | Công tắc tính năng theo cơ sở | Cấu hình · K10 | B | Máy tính | AD | Bật từng phân hệ cho từng cơ sở (chạy CS5 trước) | Bật; Tắt | — | S03-11, R-HT-02, R-LMS-05 |
| QT-11 | Nhật ký thao tác | Danh sách · K03 | B | Máy tính | AD | Ai, lúc nào, bảng nào, trường nào đổi từ gì sang gì; chỉ đọc | Lọc; Xuất | — | S03-12 |
| QT-12 | Nhật ký đăng nhập và xuất file | Danh sách · K03 | C | Máy tính | AD | Đăng nhập thành công/thất bại, tạm khoá, các lần xuất file | Lọc; Mở khoá tạm | — | S03-18, S03-21 |
| QT-13 | Tài khoản học sinh (cấp, khoá, đặt lại mật khẩu) | Danh sách · K03 | B | Máy tính | AD (bước 4); CS từ giai đoạn 4 **(chốt 12/10)** | Cấp tài khoản theo mã HS, in/gửi mật khẩu tạm, đặt lại khi em quên | Cấp hàng loạt; Đặt lại mật khẩu; Khoá | KH-06 | S03-02, S03-04 |

## Đợt 5.3: Tuyển sinh, Khách hàng, Bán hàng, Thu chi (giai đoạn 1)

57 màn: A 10, B 30, C 17.


### Chung

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| CHUNG-15 | Hàng việc chờ tôi duyệt (gộp mọi loại) | Danh sách · K03 | A | Cả hai | BM, KT, AD | Một chỗ thấy mọi thứ chờ mình duyệt: đơn, phiếu thu, lớp, yêu cầu buổi, ticket, chiết khấu vượt trần | Duyệt; Từ chối; Mở bản ghi | BH-07, TC-17, TC-05, LOP-05, BUOI-10, CS-08 | R-TIEN-01, R-LOP-02, R-BUOI-03, R-CS-07, S03-22, R-HT-05 |
| CHUNG-21 | Đính kèm tệp (tải lên, xem trước) | Hộp thoại · K08 | C | Cả hai | Tất cả NV, GV | Tải ảnh, PDF vào ghi chú trao đổi hoặc chứng từ | Tải lên; Xem; Gỡ | — | S03-13, R-CS-09 |

### Cấu hình bán hàng

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| CH-01 | Gói bán / sản phẩm (danh sách) | Danh sách · K10 | B | Máy tính | AD | Mã gói Loại-Môn-Khối-Hình thức, số giờ, loại lớp, trạng thái | Tạo; Ngừng | CH-02 | R-TIEN-10, S03-10, R-TIEN-15 |
| CH-02 | Gói bán (bản ghi) | Bản ghi · K06 | C | Máy tính | AD | Thông tin gói, các giá theo hiệu lực | Sửa; Thêm giá mới | CH-03 | R-TIEN-10 |
| CH-03 | Bảng giá có ngày hiệu lực | Cấu hình · K10 | B | Máy tính | AD | Giá offline/online theo giờ, hiệu lực từ ngày; giá trống = không bán hình thức đó. **(26/10, Đ164)** Đã vẽ ở canvas v117 (một khung danh sách bản và giá, một khung lỗi) | Thêm bảng giá mới; So sánh | — | R-TIEN-10, R-TIEN-11, R-TIEN-14, S03-10, R-TIEN-15 |
| CH-04 | Chính sách chiết khấu | Cấu hình · K10 | B | Máy tính | AD | % hoặc giờ tặng; hiệu lực từ/đến; mức tối đa; cần duyệt; áp dụng nhóm gói, cơ sở. **(26/10, Đ164)** Hai tab: Chiết khấu và Chính sách quà tặng (quà tặng chưa có mã màn riêng) | Tạo; Ngừng | — | R-TIEN-29, S03-10, R-TIEN-30 |
| CH-08 | Chiến dịch marketing | Danh sách · K10 | C | Máy tính | AD, SA | Chiến dịch gắn nguồn lead, thời gian chạy | Tạo; Ngừng | — | R-CRM-11 |
| CH-09 | Điều khoản thanh toán (các đợt, hạn đóng) | Cấu hình · K10 | C | Máy tính | AD | Mẫu chia đợt: số đợt, % hoặc số tiền mỗi đợt, số ngày đến hạn; chọn trên đơn để sinh lịch đóng. **(26/10, Đ164)** Đã vẽ ở canvas v117 (mức C, một khung chính, một khung lỗi) | Tạo; Ngừng | — | S03-10, R-TIEN-07 |

### Tuyển sinh

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| TS-01 | Lead (danh sách / kanban theo giai đoạn) | Danh sách · K03, K04 | A | Máy tính | SA, CS, BM, AD | Lọc nhanh của tôi + thời gian, nhóm theo giai đoạn, nguồn, sale | Tạo; Nhập file; Giao sale; Xuất | TS-02, TS-03, TS-04, TS-05 | R-CRM-07, S03-17 |
| TS-02 | Lead (bản ghi) | Bản ghi · K06 | B | Máy tính | SA, CS, BM, AD | Thông tin liên hệ, nguồn, giai đoạn C1–C4 + nhóm con, lịch hẹn, cơ hội đã sinh, ghi chú | Đổi giai đoạn; Thêm lịch hẹn; Tạo cơ hội; Giao sale | TS-06, TS-13, TS-05 | R-CRM-01, R-CRM-04, R-CRM-09 |
| TS-03 | Tạo lead nhanh (kèm kiểm trùng SĐT) | Biểu mẫu · K07 | B | Máy tính | SA, CS, BM, AD | Tạo lead, cảnh báo trùng SĐT với lead, phụ huynh có sẵn | Tạo; Mở bản ghi trùng | TS-02, TS-14 | — |
| TS-04 | Nhập lead từ file | Hộp thoại · K08 | C | Máy tính | SA, CS, BM, AD | **CSV trước, Excel sau (chốt 18/10).** Tải file, ghép cột, xem trước, báo dòng lỗi, trùng; quyền Lead · Tạo (CSKH nhập được, chốt 18/10) | Nhập | TS-01 | R-CRM-11 |
| TS-05 | Giao người phụ trách (lead, cơ hội, phiếu tái tục, ticket) | Hộp thoại · K08 | C | Máy tính | BM, AD, CS | Giao một hoặc nhiều lead, cơ hội cho sale | Giao | — | — |
| TS-06 | Tạo cơ hội từ lead (cảnh báo đã có cơ hội) | Hộp thoại · K08 | B | Máy tính | SA, CS, BM, AD | Lead đã có cơ hội: hiện mã cũ; chọn một trong ba: mở cơ hội cũ, thêm em vào cơ hội cũ (không tạo cơ hội mới), hoặc vẫn tạo thêm (xác nhận lần hai). **(26/10, Đ186)** Lead chỉ tạo cơ hội khi ở C4C, chưa đủ thì nút Tạo cơ hội mờ kèm lý do (R-CRM-40) | Tạo; **Mở cơ hội cũ** (đổi từ "Gộp vào cơ hội cũ", chốt 18/10: lúc đó chưa có cơ hội thứ hai để gộp; dựng ở P3d); **Thêm em vào cơ hội cũ**; **Vẫn tạo thêm** (chữ nút theo R-CRM-01 bản 26/10, mới hơn Đ124; canvas v118 đã ghi "Vẫn tạo thêm" (Đ197, Đ198)) | TS-08 | R-CRM-01, R-CRM-40 |
| TS-07 | Cơ hội (danh sách / kanban L1–L8) | Danh sách · K03, K04 | B | Máy tính | SA, CS, BM, AD | Kanban theo giai đoạn chỉ kéo tới; lọc của tôi, thời gian. **(26/10, Đ186)** Cơ hội tạo trực tiếp, không cần lead gốc, với mọi nguồn: form có Source type, Source, Medium (spec 06 mục 1.1), danh sách em, kiểm trùng SĐT | Tạo cơ hội; Mở; Xuất; Giao sale | TS-08, TS-14 | R-CRM-01, R-CRM-02, R-CRM-07 |
| TS-08 | Cơ hội (bản ghi) | Bản ghi · K06 | A | Máy tính | SA, CS, BM, AD | Thanh giai đoạn L1–L8 chỉ đi tới, nhóm con; học sinh (bắt buộc tên, năm sinh từ L5); lịch hẹn; phiếu test; báo giá; đơn | Chuyển giai đoạn; Tạo phiếu test; Tạo báo giá; Tạo đơn; Thêm lịch hẹn | TS-09, TS-15, BH-02, BH-05, TS-13 | R-CRM-02, R-CRM-03, R-CRM-04, R-TIEN-02 |
| TS-09 | Chuyển giai đoạn cơ hội (chọn nhóm con, lý do) | Hộp thoại · K08 | C | Máy tính | SA, CS, BM, AD | Chỉ hiện giai đoạn phía trước; L5+ đòi tên, năm sinh học sinh | Xác nhận | — | R-CRM-02, R-CRM-03 |
| TS-10 | Gộp lead / cơ hội trùng | Hộp thoại · K08 | C | Máy tính | SA, CS, BM, AD | Chọn bản giữ lại, gộp lịch hẹn, ghi chú, phiếu test; quyền Duyệt trong cơ sở mình, hai cơ sở khác nhau chỉ Admin | Gộp | — | R-CRM-01, R-CRM-22 |
| TS-11 | Lịch hẹn (danh sách + lịch tuần) | Lịch · K03, K05 | A | Máy tính | SA, CS, BM, AD | Mọi lịch hẹn của tôi: quá hạn, hôm nay, sắp tới | Hoàn thành (1 bấm); Huỷ (1 bấm); Dời | TS-02, TS-08 | R-CRM-04, R-CRM-07 |
| TS-12 | Việc tuyển sinh hôm nay (lọc sẵn) | Tổng quan · K09 | C | Máy tính | SA, AD | **Gộp vào trang chủ theo vai trò K09b (CHUNG-14), không làm riêng trong P3.** Lịch hẹn, phiếu test hôm nay, cơ hội quá hạn chăm | Mở | TS-11, TS-16 | R-CRM-07 |
| TS-13 | Tạo / dời lịch hẹn | Hộp thoại · K08 | B | Máy tính | SA, CS, BM, AD | Loại hoạt động, thời gian, ghi chú; nhiều lịch song song | Lưu | — | R-CRM-04 |
| TS-14 | Cảnh báo trùng khách hàng | Hộp thoại · K08 | C | Máy tính | SA, CS, AD | SĐT trùng với phụ huynh, lead có sẵn: mở hoặc gắn vào hồ sơ cũ | Gắn vào hồ sơ có sẵn; Vẫn tạo mới | KH-02 | — |

### Kiểm tra đầu vào

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| TS-15 | Tạo phiếu kiểm tra từ cơ hội (gồm xếp lịch, đổi lịch) | Hộp thoại · K08 | B | Máy tính | SA, CS, AD | Môn; **Khối chọn khi tạo, không lấy từ cơ hội** (cơ hội chưa có khối; chốt 18/10); hình thức test, cấp độ đề; **ngày giờ test bắt buộc và ở tương lai**; phòng và giáo viên chấm chọn sau; lịch hẹn nhắc tạo cùng phiếu | Tạo | TS-17 | R-CRM-05 |
| TS-16 | Phiếu kiểm tra (danh sách + Kanban + lịch) | Danh sách · K03, K05 | B | Máy tính | SA, CS, BM, AD | Lọc Tôi tạo / Tôi phụ trách / Tôi chấm bài; quá hạn, hôm nay, sắp tới (không còn "chưa có lịch"); mặc định "Tuần này" | Mở; Đổi lịch | TS-17 | R-CRM-07 |
| TS-17 | Phiếu kiểm tra (bản ghi) | Bản ghi · K06 | A | Máy tính | SA, CS, BM, AD | Thanh trạng thái Nháp → Đang test → Chờ GV chấm → Hoàn thành; nhánh Huỷ; kết quả, gợi ý lớp phù hợp (đính kèm file làm ở giai đoạn 4) | Đổi lịch; Bắt đầu; Nhập kết quả; Gợi ý lớp; Huỷ; Đưa về Nháp (lý do) | GV-15, BH-02, BH-08, CHUNG-21 | R-CRM-05, R-CRM-06, R-CRM-10 |

### Khách hàng

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| KH-01 | Phụ huynh (danh sách) | Danh sách · K03 | B | Máy tính | SA, CS, BM, KT, AD | Tìm theo tên, SĐT (phụ huynh không có mã cũ, R-CRM-33) | Xuất (chỉ Admin, R-CRM-29) | KH-02 | S03-15 |
| KH-02 | Phụ huynh (bản ghi) | Bản ghi · K06 | B | Máy tính | SA, CS, BM, KT, AD | Thông tin, các con, đơn, phiếu thu, số dư, ticket; nút liên kết có số đếm | Sửa; Gộp; Tạo ticket (không có Tạo tay, R-CRM-27) | KH-05, BH-05, TC-02, CS-04 | R-TIEN-25 |
| KH-03 | Sửa phụ huynh (không có Tạo tay) | Biểu mẫu · K07 | C | Máy tính | SA, CS, AD | Thông tin liên hệ, địa chỉ (tỉnh, phường); Cơ sở tiếp nhận chỉ Admin sửa | Lưu | KH-02 | R-CRM-27, R-CRM-28 |
| KH-04 | Học sinh (danh sách) | Danh sách · K03 | B | Máy tính | SA, CS, BM, KT, AD | Tình trạng Tiềm năng, Đang học, Bảo lưu, Dừng học; lọc khối, cơ sở, lớp | Xuất (chỉ Admin, R-CRM-29) | KH-05 | S02-TT-HS |
| KH-05 | Học sinh (hồ sơ 360°) | Bản ghi · K06 | B | Máy tính | SA, CS, BM, KT, AD | Ghi danh, quỹ giờ, lớp đang học, điểm danh, nhận xét, BTVN, ticket, tài khoản học tập; ô "Mã cũ (Sheet)" | Sửa; Gộp; Tạo ticket; Cấp tài khoản (giai đoạn 4) | GD-02, LOP-02, CS-04, QT-13 | S02-TT-HS, R-GD-02, R-CRM-33 |
| KH-06 | Sửa học sinh (không có Tạo tay) | Biểu mẫu · K07 | C | Máy tính | SA, CS, AD | Tên, năm sinh, khối, trường, mục tiêu (một ô chữ); Cơ sở tiếp nhận chỉ Admin sửa. **(26/10, Đ165)** Năm sinh bắt buộc, ngày sinh không bắt buộc; chữ báo trùng "họ tên hoặc năm sinh" | Lưu | KH-05 | R-CRM-03, R-CRM-27, R-CRM-31 |
| KH-07 | Gộp phụ huynh / học sinh trùng | Hộp thoại · K08 | C | Máy tính | SA, CS, BM, AD | Chọn hồ sơ giữ lại, gộp đơn, ghi danh, ghi chú; mã bị gộp vẫn tìm được; quyền Duyệt trong cơ sở mình, hai cơ sở khác nhau chỉ Admin | Gộp | — | S03-15, R-CRM-25 |

### Bán hàng

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| BH-01 | Báo giá (danh sách) | Danh sách · K03 | B | Máy tính | SA, CS, BM, AD | QT1 Nháp, Đã gửi, Đã chuyển đơn, Từ chối (không còn Hết hạn; quá hạn hiện nhãn "Đã quá hạn N ngày"); cột Học sinh | Mở; Xuất (chỉ Trưởng cơ sở, Kế toán, Admin) | BH-02 | R-TIEN-02, R-TIEN-05, R-TIEN-35 |
| BH-02 | Báo giá (bản ghi, dòng gói) | Bản ghi · K06 | A | Máy tính | SA, CS, BM, AD | Dòng gói kèm học sinh (ba cách chọn), hình thức, giờ mua và giờ tặng do nhân viên điền, giá, chiết khấu, hạn hiệu lực tính từ ngày Gửi; không có nút tạo tay. **(26/10, Đ187)** Báo giá có đúng một gốc: cơ hội, hoặc phiếu tái tục (vào từ TT-02, học sinh và lớp lấy từ phiếu) | Gửi; Chuyển thành đơn (form trắng, các dòng chưa vào đơn, bỏ bớt bằng ✕); Từ chối; Huỷ; In | BH-03, BH-04, BH-05 | R-TIEN-01, R-TIEN-02, R-TIEN-05, R-TIEN-10, R-TIEN-12, R-TIEN-13, R-TIEN-29, R-TIEN-35, R-TIEN-36 |
| BH-03 | Bản in / gửi báo giá cho phụ huynh | Bản in · K13 | B | Máy tính | SA, CS, AD | Bản A4 hoặc ảnh gửi qua tin nhắn | In; Tải PDF | — | R-TIEN-05, R-TIEN-08 |
| BH-04 | Từ chối báo giá (lý do) | Hộp thoại · K08 | C | Máy tính | SA, CS, BM, AD | Lý do từ chối | Xác nhận | — | — |
| BH-05 | Đơn hàng (bản ghi) | Bản ghi · K06 | A | Máy tính | SA, CS, BM, KT, AD | Dòng: học sinh (trước khi duyệt hiện tên, năm sinh, nhãn "chưa có hồ sơ"), gói, hình thức, lớp, ngày vào lớp, giờ, giá, chiết khấu cộng dồn, giờ tặng; tiền đã vào, còn lại; khoá khi duyệt; phiếu thu, ghi danh; lịch đóng tiền từng đợt theo điều khoản thanh toán. **(26/10, Đ187)** Đường vào từ phiếu tái tục (TT-02, khi phiếu ở L6 hoặc L7): học sinh và lớp lấy từ phiếu; đơn có đúng một gốc, cơ hội hoặc phiếu tái tục | Trình duyệt (báo đúng dòng, ô còn thiếu); Sửa và trình lại khi bị từ chối; Tạo phiếu thu; Cho học trước; Huỷ đơn | BH-07, BH-08, BH-09, TC-03, GD-02 | R-TIEN-01, R-TIEN-03, R-TIEN-04, R-TIEN-12, R-TIEN-13, R-TIEN-14, R-TIEN-22, R-TIEN-24, R-TIEN-25, R-TIEN-29, R-GD-01, R-GD-06, R-GD-08, R-TIEN-06, R-TIEN-07, R-TIEN-15, R-TIEN-30, R-TIEN-35, R-TIEN-36, R-HT-06 |
| BH-06 | Đơn hàng (danh sách) | Danh sách · K03 | B | Máy tính | SA, CS, BM, KT, AD | Nháp, Đã trình, Đã duyệt (khoá), Từ chối, Huỷ; đã thu đủ/chưa | Mở; Xuất (chỉ Trưởng cơ sở, Kế toán, Admin) | BH-05 | R-TIEN-02 |
| BH-07 | Duyệt / từ chối đơn hàng | Hộp thoại · K08 | B | Cả hai | BM, AD | Xem tóm tắt, mỗi dòng ghi "sẽ tạo hồ sơ mới" hoặc "dùng HS…", chiết khấu vượt trần, lớp + ngày vào lớp; duyệt thì khoá. Người duyệt là quản lý trực tiếp của người lập (Trưởng cơ sở lập thì tự duyệt, Admin thay khi vắng) | Duyệt; Từ chối (lý do) | — | R-TIEN-03, R-TIEN-29, R-TIEN-35, R-GD-06, R-HT-05, R-HT-06 |
| BH-08 | Chọn lớp và ngày vào lớp cho dòng đơn | Hộp thoại · K08 | A | Máy tính | SA, CS, AD | Chỉ lớp đã duyệt, còn chỗ, đúng môn/khối/cơ sở; chọn buổi sắp tới hoặc ngày đúng thứ có lịch | Chọn | — | R-GD-06, R-GD-08, S02-XL-3, S02-XL-8, R-GD-14, R-GD-15 |
| BH-09 | Bật "Cho học trước, đóng tiền sau" | Hộp thoại · K08 | B | Máy tính | BM, AD | Trên đơn đã duyệt chưa thu tiền; hiện hạn mức buổi | Bật; Tắt | — | R-GD-12 |
| BH-10 | Huỷ đơn hàng (lý do) | Hộp thoại · K08 | C | Máy tính | SA, BM, AD | Huỷ đơn chưa có tiền; đơn đã có tiền phải qua ticket hoàn tiền | Xác nhận | CS-05 | R-TIEN-03, R-CS-02 |
| BH-11 | Cảnh báo cơ hội đã có đơn nháp | Hộp thoại · K08 | C | Máy tính | SA, CS, AD | Trước khi lập đơn mới: hiện đơn nháp đang có, mở đơn cũ hoặc vẫn tạo | Mở đơn cũ; Vẫn tạo | BH-05 | R-TIEN-39 |

### Thu chi

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| TC-01 | Phiếu thu (danh sách) | Danh sách · K03 | B | Máy tính | SA, CS, BM, KT, AD | Nháp, Đã trình, **Chờ kế toán** (quản lý đã duyệt), Đã duyệt, Từ chối, Huỷ; lọc chờ quản lý duyệt, chờ kế toán duyệt | Mở; Xuất | TC-02 | R-TIEN-01 |
| TC-02 | Phiếu thu (bản ghi) | Bản ghi · K06 | A | Máy tính | SA, CS, BM, KT, AD | Số tiền, hình thức, ngày nhận, tài khoản, mã giao dịch, ảnh chứng từ, cấn vào dòng (khoá khi rời nháp) | Trình quản lý; Sửa và trình lại khi bị từ chối; Huỷ; In (chỉ in được sau khi phiếu đã duyệt) | TC-05, TC-06, TC-07 | R-TIEN-04, R-TIEN-23, R-TIEN-06 |
| TC-03 | Tạo phiếu thu từ đơn hàng | Hộp thoại · K08 | B | Máy tính | SA, CS, AD | Số tiền gợi ý = còn lại; chọn cấn vào dòng (trống = chia tỉ lệ) | Tạo nháp | TC-02 | R-TIEN-02, R-TIEN-22, R-TIEN-23 |
| TC-04 | Hàng chờ kế toán duyệt | Danh sách · K03 | B | Máy tính | KT, AD | Phiếu thu **đã qua quản lý** (trạng thái Chờ kế toán) mọi cơ sở, đối chiếu sao kê | Duyệt; Từ chối | TC-05 | R-TIEN-01, S03-22 |
| TC-05 | Kế toán duyệt / từ chối phiếu thu | Hộp thoại · K08 | A | Máy tính | KT, AD | Duyệt sinh khoản tiền vào và ghi danh (nếu đủ cọc); cảnh báo "đã qua N buổi" | Duyệt; Từ chối (lý do): phiếu về Nháp, người lập sửa và Trình lại thì đi lại từ bước quản lý (TD14) | TC-08, GD-02 | R-TIEN-01, R-TIEN-20, R-TIEN-21, R-TIEN-24, R-TIEN-27, S03-22, R-HT-01 |
| TC-06 | Huỷ phiếu thu (lý do) | Hộp thoại · K08 | C | Máy tính | SA, CS, AD | Chỉ phiếu chưa duyệt | Xác nhận | — | — |
| TC-07 | Bản in phiếu thu / biên nhận | Bản in · K13 | B | Máy tính | SA, CS, KT, AD | Biên nhận A5/A4 gửi phụ huynh | In; Tải PDF | — | R-TIEN-08 |
| TC-08 | Khoản tiền vào (sổ thu tiền) | Danh sách · K03 | B | Máy tính | KT, BM, AD | Khoản tự sinh khi duyệt phiếu, khoản đảo âm trỏ về khoản gốc; chỉ đọc | Đảo khoản (chỉ KT); Xuất | TC-09 | R-TIEN-01, R-TIEN-26 |
| TC-09 | Đảo khoản tiền (lý do) | Hộp thoại · K08 | B | Máy tính | KT, AD | Thêm khoản âm, chặn đảo hai lần, báo giờ cấp sẽ tính lại | Xác nhận | — | R-TIEN-26, R-HT-01 |
| TC-13 | Công nợ (đơn chưa thu đủ) | Danh sách · K03 | B | Máy tính | KT, BM, SA, CS, AD | Đơn còn phải thu theo lịch đóng từng đợt; sắp đến hạn, quá hạn; theo cơ sở, sale | Mở đơn; Xuất (chỉ Trưởng cơ sở, Kế toán, Admin) | BH-05 | R-TIEN-07 |
| TC-15 | Đối soát thu tiền | Báo cáo · K09 | B | Máy tính | KT, AD | Theo ngày, tài khoản nhận, hình thức, mã giao dịch; khớp sao kê; xuất | Lọc; Đánh dấu đã khớp; Xuất | TC-02 | S03-21 |

### Cổng giáo viên

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| GV-15 | Chấm kiểm tra đầu vào | Biểu mẫu · K12 | B | Cả hai | GV | Phiếu test được giao chấm: nhập kết quả, nhận xét, đề xuất lớp/trình độ, tải bài làm (GĐ1 chưa có, R-CRM-10). GĐ1 dùng trong cổng giáo viên bản tối giản (chỉ mục chấm test) | Lưu (nháp); Trả về sale (nộp kết quả, phiếu Hoàn thành, không cần lý do; QĐ-Đ25) | TS-17 | R-CRM-05, R-CRM-10, R-CRM-11 |

## Đợt 5.4: Ghi danh, Lớp, Buổi, Chăm sóc khách hàng, Tái tục (giai đoạn 2)

59 màn: A 10, B 39, C 10.


### Quản trị

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| QT-14 | Ngày nghỉ lễ | Cấu hình · K10 | B | Máy tính | AD, BM | Bảng ngày nghỉ dùng để tính ngày kết thúc lớp; thêm ngày nghỉ sau khi đã sinh buổi thì xem trước các buổi bị ảnh hưởng rồi dời | Thêm; Sửa; Xem buổi bị ảnh hưởng | — | R-LOP-09, R-GD-13, R-LOP-12 |
| QT-15 | Cấu hình người duyệt ticket theo nhóm con | Cấu hình · K10 | B | Máy tính | AD | Ai duyệt từng nhóm con đề nghị (có hiệu lực, như ma trận quyền) | Sửa; Xem lịch sử | — | R-CS-07, R-CS-11 |
| QT-16 | Giáo viên, trợ giảng (hồ sơ dạy) | Danh sách · K03 | B | Máy tính | AD, BM | Mã GV/TG, môn dạy, khối, cơ sở thường dạy, tài khoản liên kết | Tạo; Sửa; Ngừng | QT-02, GV-11 | R-LOP-08, R-LOP-10 |

### Cấu hình đào tạo

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| CH-05 | Khung chương trình (danh sách phiên bản) | Danh sách · K10 | B | Máy tính | AD (BM xem) | Mã Môn-Khối-Cấp độ-Năm; sửa khung = tạo bản mới | Tạo bản mới; Ngừng | CH-06 | R-LOP-07, S03-10 |
| CH-06 | Khung chương trình (danh sách bài học) | Cấu hình · K10 | B | Máy tính | AD (BM xem) | Bài số, tên bài, nội dung gợi ý; dùng cho nhãn bài từng buổi | Thêm bài; Kéo thứ tự; Nhập từ file | — | R-LOP-07 |

### Khách hàng

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| KH-08 | Lên khối đầu năm học (hàng loạt) | Hộp thoại · K08 | C | Máy tính | AD | Tăng khối cho học sinh đang học khi sang năm học mới; xem trước, loại trừ | Xác nhận | — | — |

### Thu chi

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| TC-10 | Phiếu chi (danh sách) | Danh sách · K03 | B | Máy tính | KT, BM, AD | Phiếu chi hoàn phí, chuyển phí trả lại | Mở; Xuất | TC-11 | R-TIEN-28 |
| TC-11 | Phiếu chi (bản ghi) | Bản ghi · K06 | B | Máy tính | KT, AD | Gắn ticket hoàn tiền đã duyệt; bảng tính hoàn; người nhận, hình thức chi | Lập; Duyệt; In | TC-12 | R-TIEN-28, R-CS-02, R-TIEN-34 |
| TC-12 | Bản in phiếu chi | Bản in · K13 | C | Máy tính | KT, AD | Mẫu phiếu chi | In; Tải PDF | — | R-TIEN-28, R-TIEN-08 |
| TC-14 | Số dư khách hàng (tiền dư giữ lại) | Danh sách · K03 | C | Máy tính | KT, BM, AD | Tiền dư của phụ huynh sau chuyển phí, dùng cho đơn sau | Xem lịch sử; Cấn vào đơn mới | KH-02 | R-CS-03, R-TIEN-33 |
| TC-16 | Dùng số dư khách hàng cho đơn mới | Hộp thoại · K08 | C | Máy tính | KT, CS, AD | Trừ số dư, ghi vào đơn mới như một khoản tiền vào | Xác nhận | BH-05 | R-CS-03, R-TIEN-33 |
| TC-17 | Quản lý duyệt phiếu thu | Hộp thoại · K08 | B | Máy tính | BM, AD | Phiếu thu đã trình chờ quản lý trực tiếp của người lập (Trưởng cơ sở lập thì tự duyệt bước này; Admin không duyệt thay, quản lý vắng thì Admin dùng "Chuyển người duyệt" sang người khác đủ điều kiện, có nhật ký); duyệt thì phiếu sang "Chờ kế toán", từ chối thì về Nháp kèm lý do. Hàng chờ của quản lý nằm trong CHUNG-15 | Duyệt; Từ chối (lý do) | TC-05 | R-TIEN-01, R-HT-06 |

### Ghi danh

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| GD-01 | Ghi danh (danh sách) | Danh sách · K03 | B | Máy tính | CS, BM, SA, KT, AD | Tình trạng Chờ xếp lớp, Đã xếp lớp, Đang học, Bảo lưu, Hoàn thành, Chuyển lớp, Dừng, Hoàn phí; giờ còn | Mở; Xuất | GD-02 | R-GD-05, R-TIEN-02 |
| GD-02 | Ghi danh (bản ghi) | Bản ghi · K06 | A | Máy tính | CS, BM, SA, KT, AD | Quỹ giờ (cấp, đã dùng, còn, tặng), dòng xếp lớp, sổ giờ, ngày hết giờ dự kiến, hạn gói (chỉ dự báo), hình thức học, ticket liên quan | Xếp lớp; Điều chỉnh giờ; Tạo ticket; Tạo phiếu tái tục thủ công (TT-03) | GD-03, GD-04, GD-05, TT-03, CS-04 | R-GD-01, R-GD-02, R-GD-03, R-GD-04, R-GD-05, R-GD-07, R-GD-13, R-TIEN-12, R-TIEN-21, S02-XL-1, S02-XL-2, S02-XL-5, S02-XL-6, S02-XL-7 |
| GD-03 | Xếp lớp cho ghi danh (theo nhóm hoặc theo lớp) | Hộp thoại · K08 | A | Máy tính | CS, BM, AD | xếp theo **nhóm lớp** (ghi danh Đại vào lớp DAI, ghi danh Hình vào lớp HINH) hoặc theo từng lớp; mỗi ghi danh một lớp; kiểm đúng môn, loại lớp, cơ sở, trùng giờ; chọn ngày vào | Xếp | — | S02-XL-3, S02-XL-4, S02-XL-8, S02-XL-9, R-GD-06, R-GD-08, R-GD-14, R-GD-15, R-LOP-14 |
| GD-04 | Sổ giờ của ghi danh | Danh sách · K03 | B | Máy tính | CS, BM, KT, AD | Mọi dòng cộng/trừ giờ, nguồn (buổi, phiếu thu, điều chỉnh); chỉ thêm, không sửa | Xuất | — | R-GD-04, R-GIO-01, R-GIO-04 |
| GD-05 | Điều chỉnh giờ (dòng ngược dấu, bắt buộc lý do) | Hộp thoại · K08 | B | Máy tính | BM, AD | Thêm dòng điều chỉnh, không sửa dòng cũ | Xác nhận | — | R-GD-04 |
| GD-06 | Hàng chờ xếp lớp | Danh sách · K03 | B | Máy tính | CS, BM, AD | Ghi danh chưa có lớp, Toán 7+ mới xếp một lớp, đang học trước chưa đóng tiền | Xếp lớp | GD-03 | R-GD-06, S02-XL-3, R-GD-12 |
| GD-07 | Sắp hết giờ / dự báo hết giờ | Danh sách · K03 | B | Máy tính | CS, SA, BM, AD | Ghi danh còn ít giờ hoặc sắp hết hạn dự kiến; quá hạn gói vẫn học. **(26/10, Đ157)** Mỗi dòng là một học sinh trong một lớp (tính theo học sinh, lớp); giờ còn là tổng các ghi danh còn hiệu lực | Tạo phiếu tái tục; Mở | TT-02 | R-GD-07, R-GD-13 |

### Tái tục

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| TT-01 | Phiếu tái tục (danh sách / kanban L1–L8) | Danh sách · K03, K04 | B | Máy tính | CS, SA, BM, AD | Tự sinh khi chạm ngưỡng giờ hoặc ngày; cờ rủi ro vắng nhiều. **(26/10, Đ157)** Tính theo (học sinh, lớp); nhóm con L1B (tạo tay) và L8A "Đã đóng đủ, đã cấp quỹ giờ mới" | Mở; Giao; Xuất | TT-02 | R-GD-13, R-TIEN-02 |
| TT-02 | Phiếu tái tục (bản ghi) | Bản ghi · K06 | B | Máy tính | CS, SA, BM, AD | Giờ còn, ngày hết dự kiến, số buổi vắng, lịch hẹn, báo giá/đơn sinh ra. **(26/10, Đ157, Đ187, Đ192)** Tính theo (học sinh, lớp). Thêm: Email phụ huynh (chỉ đọc, lấy từ hồ sơ phụ huynh); hai ô tự do Mục tiêu/nhu cầu tiếp theo và Lộ trình tiếp theo (sửa được, mọi lần sửa ghi nhật ký); tab Tình hình học tập hiện nhưng mờ, chưa dùng, chỉ bật ở giai đoạn Giáo viên | Chuyển giai đoạn; Tạo báo giá và Tạo đơn (chỉ khi phiếu ở L6 hoặc L7, CSKH phụ trách phiếu tạo; tạo báo giá thì phiếu sang L7A, tạo đơn sang L7B); Thêm lịch hẹn | BH-02, BH-05, TS-13 | R-GD-13, R-TIEN-02 |
| TT-03 | Tạo phiếu tái tục thủ công | Hộp thoại · K08 | C | Máy tính | CS, SA, AD | Khi chưa chạm ngưỡng nhưng phụ huynh muốn mua thêm | Tạo | TT-02 | R-GD-13 |

### Lớp học

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| LOP-01 | Lớp (danh sách / kanban theo bước duyệt) | Danh sách · K03, K04 | B | Máy tính | CS, BM, SA, AD | Tình trạng duyệt và tình trạng vận hành; sĩ số, còn chỗ; lọc cơ sở, môn, khối; tìm theo mã cũ (R-LOP-15). **(26/10, Đ160)** Nhãn "Khối" (thay "Cấp"); Trưởng cơ sở, CSKH, Sale chỉ thấy lớp cơ sở mình; Admin xem toàn hệ thống (có khung Admin) | Tạo; Mở; Xuất | LOP-02, LOP-03 | R-LOP-01, R-LOP-05 |
| LOP-02 | Lớp (bản ghi) | Bản ghi · K06 | A | Máy tính | CS, BM, SA, AD | Thanh duyệt; thông tin; thời khoá biểu; học sinh (dòng xếp lớp); buổi; khung, bài bắt đầu; ngày kết thúc dự kiến; ô "Mã cũ (Sheet)"; tên chung của nhóm lớp (nhỏ dưới mã) | Trình; Xác nhận; Duyệt; Từ chối; Huỷ; Đóng; Đưa về Nháp; Sửa (Nháp, Từ chối), Sửa Time Table (Đã trình, Đã xác nhận), Sửa lớp (Đã duyệt): đều dẫn tới LOP-03, nơi đổi giáo viên của cả lớp (R-LOP-10); Yêu cầu bổ trợ | LOP-03, LOP-05, LOP-06, BUOI-02, BUOI-09 | R-LOP-01, R-LOP-02, R-LOP-03, R-LOP-05, R-LOP-07, R-LOP-09, R-GD-02, R-LOP-14, R-LOP-15 |
| LOP-03 | Tạo / sửa lớp (chỉ ở Nháp, Từ chối) | Biểu mẫu · K07 | B | Máy tính | CS, BM, AD | Cơ sở mình, môn, khối (**26/10, Đ160:** nhãn "Khối", thay "Cấp"), phân loại, trình độ, sĩ số tối đa, khung, bài bắt đầu, ngày khai giảng; **Nhóm lớp** (chọn nhóm có sẵn hoặc tạo nhóm mới, tên chung tuỳ chọn; "Tạo lớp còn lại cho nhóm này"); mã lớp tự cấp. **(26/10, R-LOP-10, Đ161, Đ162)** Time Table (khung giờ, giáo viên, trợ giảng, phòng, cách lặp; trước đây ở LOP-04) nằm trong màn này; lớp đã duyệt sửa Time Table ở đây, nhập "Áp dụng từ ngày", xem trước các buổi chưa diễn ra bị đổi rồi sinh lại (trước đây LOP-07, LOP-10); cảnh báo trùng giáo viên, không chặn | Lưu nháp | LOP-02 | R-LOP-02, R-LOP-06, R-LOP-07, S03-24, R-LOP-14 |
| LOP-04 | Thời khoá biểu lớp **(đã gộp vào LOP-03, 26/10, R-LOP-10)** | Biểu mẫu · K07 | A | Máy tính | CS, BM, AD | Mỗi thứ nhiều khung giờ; mỗi khung có giờ, giáo viên, trợ giảng, phòng; **mỗi khung có "Lặp mỗi N tuần" và "Buổi đầu tiên"** (luân phiên Đại, Hình); cảnh báo trùng phòng, trùng giáo viên (ở cấp buổi thật; chỉ cảnh báo, không chặn); xem trước ngày kết thúc | Thêm khung; Lưu | — | R-LOP-08, R-LOP-09, R-LOP-10, R-LOP-13 |
| LOP-05 | Trình / xác nhận / duyệt / từ chối lớp | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Duyệt bắt buộc có thời khoá biểu; duyệt xong tự sinh buổi (xem trước số buổi) | Trình; Xác nhận; Duyệt; Từ chối; Đưa về Nháp; Huỷ | — | R-LOP-01, R-LOP-02, R-LOP-03 |
| LOP-06 | Đóng / huỷ lớp (bị chặn thì liệt kê lý do) | Hộp thoại · K08 | B | Máy tính | BM, AD | Đóng chặn khi còn em còn giờ (liệt kê tên); huỷ chặn khi đã có buổi Done | Xác nhận | — | R-LOP-01, R-LOP-04 |
| LOP-07 | Đổi giáo viên và sinh lại buổi chưa diễn ra **(đã gộp vào LOP-03, 26/10, R-LOP-10, R-LOP-11)** | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Chọn GV mới từ ngày nào, xem trước các buổi bị đổi | Xác nhận | — | R-LOP-10 |
| LOP-08 | Lịch tuần cơ sở (theo phòng, giáo viên) | Lịch · K05 | A | Máy tính | CS, BM, AD | Mọi buổi trong tuần theo phòng hoặc giáo viên; thấy trùng phòng, trùng GV (chỉ cảnh báo, không chặn); hai lớp cùng nhóm cùng màu viền, luân phiên không báo trùng | Mở buổi; Lọc | BUOI-02 | R-LOP-08, R-LOP-13, R-LOP-14 |
| LOP-09 | Danh sách học sinh của lớp (dòng xếp lớp) | Danh sách · K03 | C | Máy tính | CS, BM, AD | Ngày vào, ngày rời, tình trạng, giờ còn, Đại/Hình | Xếp thêm; Xuất | GD-02 | R-GD-02, S02-XL-2 |
| LOP-10 | Đổi lịch cố định của lớp đã duyệt **(đã gộp vào LOP-03, 26/10, R-LOP-10)** | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Đổi ca, phòng, thứ cho mọi buổi chưa diễn ra; xem trước buổi bị đổi, sinh lại | Xác nhận | LOP-04 | R-LOP-10, R-LOP-08, R-LOP-09, R-LOP-11 |

### Buổi học

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| BUOI-01 | Buổi học (danh sách, mặc định hôm nay) | Danh sách · K03, K05 | B | Máy tính | CS, BM, AD | Lọc ngày, lớp, GV, tình trạng; buổi chưa Done kèm lý do | Mở; Xuất | BUOI-02 | R-BUOI-02, R-BUOI-08, R-GIO-06 |
| BUOI-02 | Buổi học (bản ghi) | Bản ghi · K06 | A | Máy tính | CS, BM, AD | Thanh Nháp → Đã chốt → Done, nhánh huỷ; loại buổi; danh sách; em không vào danh sách kèm lý do; điểm danh hai cột (vận hành, GV chính thức); nhận xét; lý do chưa Done | Chốt danh sách; Huỷ; Dời; Đổi GV buổi; Thêm học thử; Điểm danh vận hành | BUOI-03, BUOI-04, BUOI-05, BUOI-06, BUOI-13, BUOI-14 | R-BUOI-01, R-BUOI-02, R-BUOI-08, R-GIO-01, R-GIO-02, R-GIO-03, R-GIO-04, R-GIO-06, R-DD-01, R-DD-02, R-GV-04 |
| BUOI-03 | Điểm danh phía vận hành + lý do liên hệ | Biểu mẫu · K12 | B | Cả hai | CS, AD | Ghi trạng thái phía vận hành và lý do liên hệ (Không nghe máy, Đã nhắc…); ô GV quyết định chính thức | Lưu | — | R-DD-01, R-DD-02, R-DD-03, R-HT-05 |
| BUOI-04 | Huỷ buổi (trung tâm huỷ / học sinh huỷ lớp riêng) | Hộp thoại · K08 | A | Máy tính | CS, BM, AD | Trung tâm huỷ: không tính phí, tự thêm buổi cuối, dời bài. Lớp riêng: người huỷ chọn có/không tính phí, bắt buộc lý do | Xác nhận | — | R-BUOI-02, R-BUOI-06, R-BUOI-07, R-BUOI-09 |
| BUOI-05 | Dời một buổi (đổi ngày, giờ, phòng) | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Kiểm trùng phòng, trùng GV: cảnh báo, không chặn (R-LOP-08, 23/10) | Xác nhận | — | R-LOP-08, R-CS-03 |
| BUOI-06 | Thêm học sinh học thử vào buổi | Hộp thoại · K08 | B | Máy tính | CS, SA, AD | Học thử miễn phí, không trừ giờ; gắn với cơ hội | Thêm | — | R-GD-11, R-GD-17 |
| BUOI-07 | Yêu cầu học bù (tạo) | Biểu mẫu · K07 | B | Máy tính | CS, SA, AD | Chọn em, buổi/lớp học bù, lý do; không trừ giờ | Gửi duyệt | BUOI-10 | R-BUOI-03 |
| BUOI-08 | Yêu cầu buổi củng cố (tạo) | Biểu mẫu · K07 | B | Máy tính | CS, AD | Chèn buổi tính tiền như buổi thường; **(26/10, Đ167, R-BUOI-10)** không bắt buộc ghi nhận phụ huynh đồng ý, có ô Ghi chú (không bắt buộc); xem trước dời nhãn bài | Gửi duyệt | BUOI-10 | R-BUOI-04, R-BUOI-10 |
| BUOI-09 | Yêu cầu học bổ trợ (tạo từ lớp) | Biểu mẫu · K07 | B | Cả hai | CS, GV, AD | Chọn em yếu, thời gian, GV; không trừ giờ, tính giờ dạy GV | Gửi duyệt | BUOI-10 | R-BUOI-05 |
| BUOI-10 | Yêu cầu buổi (danh sách + duyệt) | Danh sách · K03 | B | Cả hai | BM, CS, AD | Học bù, củng cố, bổ trợ: chờ duyệt, đã duyệt, từ chối; chỉ Trưởng cơ sở duyệt, CSKH xem; duyệt thì sinh buổi | Duyệt; Từ chối | BUOI-02 | R-BUOI-03, R-BUOI-04, R-BUOI-05, R-HT-01, R-HT-05 |
| BUOI-11 | Điểm danh vận hành trong ngày (gọi nhắc) | Danh sách · K03 | B | Máy tính | CS, AD | Các buổi hôm nay, em chưa tới/vắng, gọi nhắc, ghi lý do liên hệ hàng loạt | Ghi lý do; Mở buổi | BUOI-03 | R-DD-03 |
| BUOI-12 | Theo dõi buổi chưa Done, GV chưa hoàn tất | Danh sách · K03 | B | Máy tính | BM, CS, AD | Buổi kẹt ở Đã chốt kèm lý do, GV sắp trễ hạn | Nhắc GV; Mở buổi | BUOI-02 | R-GIO-06, R-GV-05 |
| BUOI-13 | Đổi giáo viên / trợ giảng cho một buổi (dạy thay) | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Chọn người dạy thay cho buổi; giờ dạy tính cho người dạy thật; kiểm trùng lịch | Xác nhận | — | R-LOP-10, R-BUOI-05, R-LOP-11 |
| BUOI-14 | Sửa điểm danh sau khi buổi Done | Hộp thoại · K08 | C | Máy tính | BM, AD | Chỉ Trưởng cơ sở, bắt buộc lý do; đổi giữa có mặt/vắng không đổi giờ (R-GIO-01); thêm/bớt em khỏi danh sách thì thêm dòng điều chỉnh sổ giờ | Xác nhận | GD-05 | R-GIO-01, R-GD-04, R-GIO-07 |

### Chăm sóc KH

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| CS-01 | Ticket (danh sách / kanban theo bước) | Danh sách · K03, K04 | B | Máy tính | CS, SA, BM, KT, AD | Đề nghị và khiếu nại; lọc loại, nhóm, mức độ, người phụ trách, sắp/quá hạn SLA | Tạo; Mở; Giao người phụ trách; Xuất | CS-02, CS-03, CS-04, TS-05 | R-CS-01, R-CS-08 |
| CS-02 | Ticket đề nghị (bản ghi) | Bản ghi · K06 | A | Máy tính | CS, SA, BM, KT, AD | Thanh Mới → Đang xử lý → Chờ duyệt → Đã duyệt → Đang thực hiện → Hoàn thành; chuỗi người duyệt; nút Thực hiện theo nhóm con; gắn HS, PH, ghi danh, lớp | Nhận xử lý; Giao người phụ trách; Trình duyệt; Duyệt; Từ chối; Thực hiện; Hoàn thành; Khách huỷ | CS-05, CS-06, CS-07, CS-08, CS-09, CS-10, CS-11, CS-12 | R-CS-02, R-CS-05, R-CS-07, R-CS-09 |
| CS-03 | Ticket khiếu nại (bản ghi) | Bản ghi · K06 | A | Máy tính | CS, BM, AD | Thanh Mới → Đã tiếp nhận → Đang xác minh → Có phương án → Chờ PH xác nhận → Đóng hài lòng/không; mức độ; người bị khiếu nại; phương án; mức hài lòng | Chuyển bước; Nâng cấp; Đóng; Mở lại | CS-08, CS-13 | R-CS-04, R-CS-06, R-CS-08, R-CS-09, R-CS-14 |
| CS-04 | Tạo ticket (chọn loại, nhóm, nhóm con) | Biểu mẫu · K07 | B | Máy tính | CS, SA, BM, AD | Trường thay đổi theo nhóm con; gắn HS, PH, ghi danh, lớp; kênh tiếp nhận, mức độ, mô tả, đính kèm | Tạo | CS-02, CS-03 | R-CS-01, R-CS-03, R-CS-04, R-CS-09, R-CS-10 |
| CS-05 | Thực hiện hoàn tiền (bảng tính hoàn) | Hộp thoại · K08 | A | Máy tính | KT, BM, AD | Giờ đã học × giá gốc, bỏ chiết khấu; trừ phí xử lý; giờ tặng không hoàn; sinh phiếu chi | Tạo phiếu chi | TC-11 | R-TIEN-28, R-CS-02, R-TIEN-31 |
| CS-06 | Thực hiện chuyển lớp (cùng môn) | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Đóng dòng xếp lớp cũ, mở dòng mới; Đại/Hình đổi riêng; giờ đi theo ghi danh | Xác nhận | — | R-GD-10, R-CS-02, S02-XL-4 |
| CS-07 | Thực hiện chuyển cơ sở | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Giữ nguyên giờ; chọn lớp ở cơ sở mới; quản lý hai cơ sở cùng duyệt (cơ sở đích được xem ticket này) | Xác nhận | — | R-GD-10, R-CS-02, R-CS-07 |
| CS-08 | Duyệt / từ chối ticket (từng cấp) | Hộp thoại · K08 | B | Cả hai | BM, KT, AD | Theo cấu hình người duyệt; từ chối bắt buộc lý do | Duyệt; Từ chối | — | R-CS-05, R-CS-07, R-HT-05 |
| CS-09 | Thực hiện bảo lưu (mới, gia hạn, quay lại sớm) | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Từ ngày, đến ngày ≤ tối đa; giữ nguyên giờ; em ra khỏi danh sách buổi | Xác nhận | — | R-GD-09, R-CS-02, R-GIO-03 |
| CS-10 | Thực hiện chuyển phí (sang môn khác, anh chị em, gói khác) | Hộp thoại · K08 | B | Máy tính | CS, BM, KT, AD | Dừng ghi danh cũ, quy tiền còn lại sang đơn mới; thiếu đóng thêm, dư hoàn hoặc giữ số dư | Tạo đơn mới; Xác nhận | BH-05, TC-14 | R-CS-03, R-GD-10, R-CS-02, R-TIEN-32 |
| CS-11 | Thực hiện đổi lịch học (dời buổi, đổi ca, xin học bù) | Hộp thoại · K08 | B | Máy tính | CS, BM, AD | Dời một buổi, chuyển sang ca cố định khác, hoặc tạo yêu cầu học bù | Xác nhận | BUOI-05, BUOI-07, CS-06 | R-CS-03 |
| CS-12 | Từ chối / khách huỷ ticket (lý do) | Hộp thoại · K08 | C | Máy tính | CS, BM, AD | Bắt buộc lý do | Xác nhận | — | R-CS-05 |
| CS-13 | Nâng cấp / mở lại khiếu nại | Hộp thoại · K08 | C | Máy tính | CS, BM, AD | Nâng lên quản lý cơ sở, Ban giám đốc; mở lại trong số ngày cho phép | Xác nhận | — | R-CS-06, R-CS-08 |
| CS-14 | Thực hiện dừng học (ticket nhóm Dừng học) | Hộp thoại · K08 | C | Máy tính | CS, BM, AD | Hai lựa chọn: hoàn tiền (R-TIEN-28) hoặc giữ số dư (giờ còn lại × giá sau chiết khấu, không trừ phí); giờ tặng còn lại huỷ | Xác nhận | — | R-GD-16, R-CS-02 |

## Đợt 5.5: Cổng giáo viên (giai đoạn 3)

19 màn: A 5, B 13, C 1.


### Cấu hình đào tạo

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| CH-07 | Rubric nhận xét (tiêu chí, mô tả mức 1–5, theo môn) | Cấu hình · K10 | B | Máy tính | AD | Tiêu chí Thái độ 3, Kiến thức 3; mô tả từng mức; riêng theo môn; có phiên bản | Sửa; Tạo phiên bản | — | R-GV-01, S03-10 |

### Chăm sóc KH

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| CS-16 | Nhận xét chờ gửi phụ huynh | Danh sách · K03 | B | Máy tính | CS, AD | Lời nhắn phụ huynh sau mỗi buổi đã chấm xong: xem, sao chép nhanh hoặc xuất ảnh để gửi Zalo tay, đánh dấu đã gửi | Sao chép; Xuất ảnh; Đánh dấu đã gửi | KH-05 | R-GV-04, R-CS-13 |

### Cổng giáo viên

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| GV-01 | Khung cổng giáo viên (điện thoại: thanh dưới · laptop: menu trái thu gọn) | Trang · K02, K01 | B | Cả hai | GV, TG | Hôm nay, Lịch dạy, Lớp, Cần làm (QĐ-Đ19), Tài khoản | Chuyển tab | GV-02, GV-03, GV-10, GV-12 | R-GV-08, R-GV-09, R-GV-13 |
| GV-02 | Hôm nay (buổi dạy, việc sắp trễ hạn) | Tổng quan · K09 | A | Cả hai | GV, TG | Buổi hôm nay theo giờ; buổi chưa hoàn tất kèm hạn còn lại, **hiện cả buổi đã quá hạn** | Mở buổi | GV-04 | R-GV-05 |
| GV-03 | Lịch dạy (tuần, tháng) | Lịch · K05 | B | Cả hai | GV, TG | Chỉ buổi của mình; loại buổi, phòng, lớp. Điện thoại xem theo ngày, laptop xem cả tuần | Mở buổi | GV-04 | R-GV-08 |
| GV-04 | Buổi dạy (tổng quan các bước cần làm) | Bản ghi · K12 | A | Cả hai | GV, TG | Bước: điểm danh → nội dung buổi → chấm từng em → BTVN; tiến độ, hạn hoàn tất; dấu Đúng hạn/Trễ hạn **tự đóng một lần** khi đủ bốn bước (QĐ-Đ21), khi đã đủ chỉ hiện dấu đã đóng lúc nào. Laptop: hai cột (bước bên trái, nội dung bên phải) | Mở từng bước; Kiểm còn thiếu | GV-05, GV-06, GV-07, GV-08, GV-09 | R-GV-04, R-GV-05, R-GIO-06 |
| GV-05 | Điểm danh (4 trạng thái) | Biểu mẫu · K12, K14 | A | Cả hai | GV, TG | Có mặt, Đi muộn, Vắng có phép, Vắng không phép; trống = chưa; "Còn lại: Có mặt"; thấy ghi chú vận hành | Lưu | GV-04 | R-DD-01, R-DD-02, R-GV-08, R-GV-13 |
| GV-06 | Nội dung buổi + giao BTVN | Biểu mẫu · K12 | B | Cả hai | GV, TG | Các dòng nội dung (mỗi dòng là mục chấm vận dụng; ít nhất một dòng, QĐ-Đ23), BTVN giao mới, ô "Buổi này không giao BTVN" (QĐ-Đ22) | Thêm dòng; Không giao BTVN; Lưu | GV-04 | R-GV-07, R-GV-08, R-GV-11 |
| GV-07 | Chấm nhận xét từng em | Biểu mẫu · K12, K14 | A | Cả hai | GV, TG | Thái độ 3, Kiến thức 3, Vận dụng theo nội dung; thang 1–5 có mô tả mức; trống ≠ 0; lời nhắn phụ huynh. Điện thoại: từng em. Laptop: bảng chấm nhanh (hàng = em, cột = tiêu chí, nhập bằng bàn phím), ngăn bên cho mô tả mức và lời nhắn | Lưu; Em tiếp theo | GV-04 | R-GV-01, R-GV-02, R-GV-03, R-GV-04, R-GV-13 |
| GV-08 | Chấm BTVN của buổi trước (5 trạng thái) | Biểu mẫu · K12, K14 | A | Cả hai | GV, TG | Đã chấm, Làm chưa xong, Không làm, Nộp sau, Không áp dụng; cập nhật bài Nộp sau mà không mở buổi cũ; **trạng thái "buổi trước không giao BTVN"** (bước này bỏ qua, không chặn Done) | Lưu | GV-04 | R-GV-10, R-GV-11, R-GIO-06 |
| GV-09 | Kiểm còn thiếu (QĐ-Đ21) | Hộp thoại · K08 | B | Cả hai | GV, TG | Kiểm còn thiếu gì: liệt kê em chưa điểm danh, chưa chấm, thiếu BTVN; hiện dấu Đúng hạn/Trễ hạn đã đóng (không có nút đóng dấu) | Mở bước còn thiếu | GV-02 | R-GV-04, R-GV-05, R-GIO-06 |
| GV-10 | Lớp của tôi (danh sách) | Danh sách · K03 | B | Cả hai | GV, TG | Lớp được phân công, sĩ số, buổi tiếp theo | Mở lớp | GV-11 | R-GV-08, R-GV-09 |
| GV-11 | Lớp (chi tiết cho giáo viên) | Bản ghi · K06 | B | Cả hai | GV, TG | Học sinh, lịch, lịch sử buổi, tiến độ khung, BTVN | Mở học sinh; Yêu cầu bổ trợ; Tạo ticket | GV-13, BUOI-09, GV-14 | R-GV-08 |
| GV-12 | Việc cần làm / quá hạn | Danh sách · K03 | B | Cả hai | GV, TG | Buổi chưa hoàn tất, bài Nộp sau chờ cập nhật, phiếu test chờ chấm | Mở | GV-04, GV-08, GV-15 | R-GV-05, R-GV-11 |
| GV-13 | Học sinh (hồ sơ rút gọn cho giáo viên) | Bản ghi · K06 | C | Cả hai | GV, TG | Điểm danh, điểm tiêu chí, BTVN theo thời gian trong lớp của mình | Xem | — | R-GV-08 |
| GV-14 | Tạo ticket từ cổng giáo viên + ticket lớp tôi | Biểu mẫu · K07 | B | Cả hai | GV, TG | Chỉ tạo, không duyệt; chỉ thấy ticket trong lớp mình | Tạo; Xem | — | R-CS-10 |
| GV-16 | Giờ dạy của tôi (căn cứ lương) | Báo cáo · K09 | B | Cả hai | GV, TG | Theo tháng: số buổi, giờ theo loại buổi (gồm bổ trợ), số buổi trễ hạn, tổng giờ trễ. Điện thoại: khuôn mới "báo cáo tháng" do Design vẽ (QĐ-Đ24) | Xem chi tiết | — | R-BUOI-05, R-GV-06 |

### Báo cáo

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| BC-08 | Giáo viên trễ hạn hằng tháng | Báo cáo · K09 | B | Máy tính | AD, BM | Số buổi trễ, tổng giờ trễ từng GV | Lọc; Xuất | — | R-GV-06, R-BC-01 |
| BC-09 | Giờ dạy giáo viên (căn cứ tính lương) | Báo cáo · K09 | B | Máy tính | AD, KT, BM | Theo tháng, GV, loại buổi (gồm bổ trợ) | Lọc; Chốt tháng; Xuất | — | R-BUOI-05, R-GV-14, R-BC-01 |

## Đợt 5.6: Học tập + Phụ huynh (giai đoạn 4)

18 màn: A 2, B 13, C 3.


### Chung

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| CHUNG-23 | Đăng nhập phụ huynh | Trang · K11 | C | Điện thoại | PH | Cách đăng nhập chốt ở GĐ4 | Đăng nhập | PH-01 | — |

### Quản trị

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| QT-17 | Tài khoản phụ huynh (cấp, khoá, đặt lại) | Danh sách · K03 | C | Máy tính | CS, AD | Cấp tài khoản theo mã PH khi mở cổng phụ huynh | Cấp; Khoá; Đặt lại mật khẩu | KH-02 | — |
| QT-18 | Nhập dữ liệu cũ (chọn loại, tải file CSV, xem trước từng dòng, nạp, tải dòng lỗi) | Trang + hộp nhiều bước · K4b ⑤ | B | Máy tính | AD | **(anh chốt 05/11: Design chưa vẽ, dựng tối giản theo khuôn có sẵn)** Loại nạp: Người dùng, Phụ huynh, Học sinh (Cơ hội sau T4c); xem trước đếm Hợp lệ, Trùng, Lỗi; mật khẩu tạm Người dùng hiện một lần | Nạp thật, Tải dòng lỗi | QT-01 | docs/nghiep-vu/nap-du-lieu.md |

### Cổng giáo viên

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| GV-17 | Giao bài trên LMS (đề, tệp, hạn nộp) | Biểu mẫu · K07 | B | Cả hai | GV, TG | Giao BTVN có đề và tệp cho lớp hoặc từng em | Giao | HT-03 | R-GV-10, R-LMS-01 |
| GV-18 | Chấm bài nộp online | Biểu mẫu · K12, K14 | B | Cả hai | GV, TG | Xem ảnh/tệp học sinh nộp, cho điểm, trạng thái, lời phê | Lưu; Bài tiếp theo | HT-05 | R-GV-10, R-GV-11, R-LMS-02, R-LMS-03 |

### Học tập (LMS)

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| HT-01 | Trang chủ học sinh | Tổng quan · K09 | A | Điện thoại | HS | Bài cần làm, hạn nộp, buổi sắp tới, tiến độ | Mở bài; Mở lịch | HT-02, HT-06 | R-LMS-05 |
| HT-02 | Bài tập (cần làm, đã nộp, đã chấm) | Danh sách · K03 | B | Điện thoại | HS | Danh sách bài theo trạng thái, hạn nộp | Mở bài | HT-03 | R-GV-11 |
| HT-03 | Chi tiết bài tập | Bản ghi · K12 | B | Điện thoại | HS | Đề bài, tệp đính kèm, hạn nộp, trạng thái | Làm bài; Nộp | HT-04 | R-GV-10, R-LMS-02 |
| HT-04 | Nộp bài (chụp ảnh, tải tệp) | Biểu mẫu · K12 | A | Cả hai | HS | Điện thoại: chụp nhiều ảnh, tải PDF. Laptop: kéo thả tệp, xem trước nhiều ảnh. Xem lại trước khi nộp; nộp lại khi được phép | Nộp | HT-05 | R-GV-10, R-LMS-03, R-LMS-04 |
| HT-05 | Kết quả bài và nhận xét | Bản ghi · K06 | B | Điện thoại | HS | Điểm, trạng thái BTVN, lời phê của giáo viên | Xem | — | R-GV-11 |
| HT-06 | Lịch học của em | Lịch · K05 | B | Điện thoại | HS | Buổi các lớp đang học (Đại, Hình), buổi bù, buổi huỷ | Xem | — | R-GD-02 |
| HT-07 | Kết quả học tập (tiêu chí theo thời gian) | Báo cáo · K09 | B | Điện thoại | HS, PH | Điểm Thái độ, Kiến thức, Vận dụng theo buổi; chuyên cần; tỉ lệ làm BTVN và điểm BTVN TB | Xem theo môn, thời gian | — | R-GV-01, R-GV-12 |
| HT-08 | Nhận xét các buổi học | Danh sách · K03 | C | Điện thoại | HS, PH | Lời nhắn của giáo viên theo từng buổi | Xem | — | R-GV-04 |
| HT-09 | Khung cổng học tập (điện thoại: thanh dưới · laptop: menu trái, nội dung một cột giữa trang) | Trang · K02, K01 | B | Cả hai | HS | Trang chủ, Bài tập, Lịch, Kết quả, Tài khoản | Chuyển tab | HT-01, HT-02, HT-06, HT-07 | — |

### Phụ huynh

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| PH-01 | Trang chủ phụ huynh (các con) | Tổng quan · K09 | B | Điện thoại | PH | Mỗi con: buổi gần nhất, nhận xét mới, giờ còn, việc cần chú ý | Chọn con | PH-02, PH-03 | — |
| PH-02 | Kết quả và nhận xét của con | Báo cáo · K09 | B | Điện thoại | PH | Như HT-07 + HT-08, xem theo con | Xem | — | R-GV-01, R-GV-12 |
| PH-03 | Học phí và giờ học của con | Bản ghi · K06 | B | Điện thoại | PH | Đơn, phiếu thu, giờ còn, ngày hết dự kiến | Xem | — | R-GD-13 |
| PH-04 | Gửi đề nghị / khiếu nại và theo dõi | Biểu mẫu · K07 | B | Điện thoại | PH | Phụ huynh tự gửi ticket, xem bước xử lý, xác nhận phương án, chấm hài lòng | Gửi; Xác nhận phương án | — | R-CS-06, R-CS-09, R-CS-14 |
| PH-05 | Lịch học của con | Lịch · K05 | B | Điện thoại | PH | Như HT-06 theo từng con | Xem | — | — |

## Đợt 5.7: Báo cáo (giai đoạn 5)

8 màn: A 1, B 0, C 0, Looker 7.


### Báo cáo

| Mã | Tên màn | Loại · khuôn | Mức | Thiết bị | Vai trò | Nội dung | Hành động | Dẫn tới | Luật |
|---|---|---|---|---|---|---|---|---|---|
| BC-01 | Tổng quan Ban giám đốc | Tổng quan · K09 | A | Máy tính | AD, BM | Số học sinh, doanh thu ghi nhận, thu tiền, tái tục, ticket, theo cơ sở | Lọc thời gian, cơ sở | BC-02, BC-03, BC-05 | R-BC-01, R-BC-02, R-BC-03, R-BC-04, R-BC-05 |
| BC-02 | Báo cáo tuyển sinh (phễu lead → đăng ký) | Báo cáo · K09 | Looker (không vẽ) | Máy tính | AD, BM, SA | Theo nguồn, chiến dịch, sale, cơ sở; tỉ lệ test, chốt | Lọc; Xuất | — | — |
| BC-03 | Doanh thu ghi nhận theo buổi Done | Báo cáo · K09 | Looker (không vẽ) | Máy tính | AD, KT, BM | Doanh thu theo cơ sở nơi buổi Done, theo môn, Đại/Hình | Lọc; Xuất | — | R-GD-10, S02-XL-6, R-BC-04 |
| BC-04 | Thu tiền và giờ chưa dạy (quỹ giờ còn) | Báo cáo · K09 | Looker (không vẽ) | Máy tính | AD, KT | Tiền đã thu, giờ đã cấp, giờ còn phải dạy quy ra tiền | Lọc; Xuất | — | R-GD-04, R-BC-05 |
| BC-05 | Tái tục | Báo cáo · K09 | Looker (không vẽ) | Máy tính | AD, BM, CS | Tỉ lệ tái tục, phiếu theo giai đoạn, rủi ro | Lọc; Xuất | — | R-GD-13, R-BC-03 |
| BC-06 | Sĩ số, lấp đầy lớp, chuyên cần | Báo cáo · K09 | Looker (không vẽ) | Máy tính | AD, BM, CS | Sĩ số so với tối đa, tỉ lệ có mặt, vắng theo lớp, em | Lọc; Xuất | — | R-DD-01 |
| BC-07 | BTVN (tỉ lệ làm bài, điểm TB) | Báo cáo · K09 | Looker (không vẽ) | Máy tính | AD, BM, CS | Hai chỉ số tách riêng theo lớp, em, GV | Lọc; Xuất | — | R-GV-12 |
| BC-10 | Báo cáo ticket | Báo cáo · K09 | Looker (không vẽ) | Máy tính | AD, BM, CS | Theo loại, nhóm, cơ sở; đúng hạn; thời gian xử lý; khiếu nại theo người; lý do chuyển, bảo lưu, hoàn | Lọc; Xuất | — | R-CS-12 |

## Luồng phải đi liền mạch (dùng ở đợt 5.1 và kiểm ở P6)

- **L1 Tuyển sinh tới đăng ký:** Nhập/tạo lead (TS-03/TS-04) → Gọi, ghi lịch hẹn (TS-13/TS-11) → Tạo cơ hội (TS-06) → Tạo phiếu test (TS-15) → Xếp lịch test (TS-15) → GV chấm test (GV-15) → Báo giá (BH-02) → Gửi báo giá (BH-03) → Chuyển đơn, chọn lớp + ngày vào (BH-05/BH-08) → Trình, BM duyệt đơn (BH-07) → Tạo phiếu thu (TC-03) → KT duyệt (TC-05) → Ghi danh tự sinh (GD-02) → Xếp lớp nếu chưa chọn (GD-06/GD-03)
- **L2 Đóng tiền nhiều đợt:** Phiếu thu đợt 1 (cọc) (TC-03) → KT duyệt → ghi danh, cấp giờ theo tỉ lệ (TC-05) → Theo dõi còn phải thu (TC-13) → Phiếu thu đợt 2, cấn vào dòng (TC-03) → KT duyệt → cấp thêm giờ, giờ tặng khi đủ (TC-05) → Đảo khoản nếu sai (TC-09)
- **L3 Mở lớp tới buổi đầu:** Tạo lớp nháp (LOP-03) → Thời khoá biểu (LOP-04) → Trình → xác nhận → duyệt (LOP-05) → Buổi tự sinh, xem lịch (LOP-08) → Xếp học sinh (GD-03) → Tự chốt danh sách (BUOI-02)
- **L4 Một buổi học:** Vận hành gọi nhắc (BUOI-11/BUOI-03) → GV điểm danh (GV-05) → Nội dung + giao BTVN (GV-06) → Chấm từng em (GV-07) → Chấm BTVN buổi trước (GV-08) → Hoàn tất (GV-09) → Buổi Done, trừ giờ (BUOI-02/GD-04) → Theo dõi buổi kẹt (BUOI-12)
- **L5 Huỷ, dời, bù:** Trung tâm huỷ buổi (BUOI-04) → Học sinh huỷ lớp riêng (BUOI-04) → Dời buổi (BUOI-05) → Yêu cầu học bù (BUOI-07) → BM duyệt (BUOI-10) → Củng cố (BUOI-08) → Bổ trợ (BUOI-09)
- **L6 Tái tục:** Phiếu tái tục tự sinh (TT-01) → Gọi tư vấn, lịch hẹn (TT-02/TS-13) → Báo giá / đơn mới (BH-02/BH-05) → Thu tiền (TC-03/TC-05)
- **L7 Chuyển lớp / cơ sở:** Tạo ticket (CS-04) → Duyệt (CS-08) → Thực hiện (CS-06/CS-07) → Hoàn thành (CS-02)
- **L8 Bảo lưu và quay lại:** Tạo ticket bảo lưu (CS-04) → Duyệt (CS-08) → Thực hiện bảo lưu (CS-09) → Quay lại sớm / gia hạn (CS-09)
- **L9 Hoàn tiền:** Tạo ticket hoàn tiền (CS-04) → BM duyệt, KT duyệt (CS-08) → Bảng tính hoàn (CS-05) → Phiếu chi (TC-11) → In phiếu chi (TC-12)
- **L10 Chuyển phí:** Tạo ticket (CS-04) → Duyệt (CS-08) → Thực hiện, sinh đơn mới (CS-10/BH-05) → Số dư giữ lại (TC-14)
- **L16 Nhận xét tới phụ huynh (trước khi có cổng PH):** GV chấm, viết lời nhắn (GV-07) → CSKH lấy nhận xét chờ gửi (CS-16) → Gửi tay qua Zalo, đánh dấu đã gửi (CS-16)
- **L11 Khiếu nại:** Tiếp nhận (CS-04) → Xác minh, phương án (CS-03) → Phụ huynh xác nhận (CS-03/PH-04) → Đóng / mở lại / nâng cấp (CS-13) → Báo cáo (BC-10)
- **L12 Bài tập LMS:** GV giao bài (GV-17) → HS xem bài (HT-02/HT-03) → HS nộp (HT-04) → GV chấm (GV-18) → HS xem kết quả (HT-05) → PH xem (PH-02)
- **L13 Quản trị nền:** Tạo người dùng (QT-03) → Phân vai trò, cơ sở (QT-02) → Sửa quyền (QT-05) → Sửa danh mục (QT-07) → Sửa tham số (QT-09) → Bật tính năng cho cơ sở (QT-10) → Xem nhật ký (QT-11)
- **L14 Đăng nhập:** NV đăng nhập (CHUNG-01) → Hai bước (CHUNG-02/CHUNG-03) → Quên mật khẩu (CHUNG-04/CHUNG-05) → HS đăng nhập lần đầu (CHUNG-06/CHUNG-07) → Bị khoá (CHUNG-08) → Hết phiên (CHUNG-09)
- **L15 Cho học trước, đóng tiền sau:** BM bật trên đơn đã duyệt (BH-09) → Ghi danh tạo sớm (GD-02) → Xếp lớp (GD-03) → Vượt hạn mức → cảnh báo (CHUNG-12/GD-06) → Thu tiền, trừ các buổi đã học (TC-05)
