# Rà chỗ gộp nhiều thông tin vào một ô (23/11/2026)

Thẻ D-23-11 (Chat 11:21, anh Trường bức xúc 11:20: nhiều trường thông tin bị gộp vào nhau). **Chỉ lập bảng, chưa sửa code.** Cách rà: `grep` trong `src/` các mẫu `${a} · ${b}`, `.join(' · ')`, `.join(', ')`, nhãn cột/trường có «·», «và», rồi đọc ngữ cảnh. Bỏ qua: lời nhắn, câu hướng dẫn, nhãn lựa chọn trong ô chọn (option label), nhãn hộp thoại phụ đề, màn dev (`src/pages/dev/`). Khoảng 260 chỗ có mẫu gộp; bảng dưới chỉ giữ chỗ **nội dung gộp nằm trong một cột bảng, một trường chi tiết hoặc một thẻ** (người dùng muốn thấy, lọc, sắp xếp riêng).

Cột «Lọc / sắp xếp»: «Sắp xếp» chỉ có ở cột khai `sortable: true` trong cấu hình danh sách (đếm: ticketConfig 0, approvalsConfig 0, ExpiringListPage 0, TeachingProfilePage 0, classConfig 2, oppConfig 3, leadConfig 3, quoteConfig 2, orderConfig 1, custConfig 2). «Lọc» đi theo bộ lọc Filters/Group By theo trường dữ liệu, không theo cột hiển thị; ô đã gộp thì không lọc riêng được từng thành phần bằng cách gõ vào cột.

Mức: **A** = gộp hai đối tượng khác loại vào một cột bảng danh sách, người dùng cần lọc/sắp xếp riêng; **B** = gộp ở trường chi tiết hoặc thẻ, khó sao chép/đọc; **C** = chấp nhận được (tiêu đề, mã đi kèm tên).

## 1. Cột bảng danh sách (mức A)

| Tệp:dòng | Màn | Nội dung gộp | Nên tách thành | Lọc / sắp xếp |
| --- | --- | --- | --- | --- |
| `pages/ticket/ticketConfig.tsx:71-77` | Danh sách ticket (CS-01) | Cột «Nhóm · Nhóm con» ghép `group_name · category_name` | Hai cột: Nhóm, Nhóm con | Không sắp xếp; lọc theo nhóm con có ở bộ lọc |
| `pages/lop/classConfig.tsx:95-99` | Danh sách lớp (LOP-01) | Cột «Phân loại» ghép loại lớp · trình độ | Hai cột: Loại lớp, Trình độ | Không sắp xếp |
| `pages/lop/classConfig.tsx:15-25, 106` | LOP-01 | Cột «Lịch học» ghép thứ · giờ · giáo viên · phòng, nhóm theo chuỗi | Cột Lịch học (thứ, giờ); giáo viên, phòng đã có cột riêng | Không sắp xếp |
| `pages/lop/classConfig.tsx:78-86` | LOP-01 | Dưới mã lớp ghép «tên chung · mã cũ» | Cột Tên chung, Mã cũ (ẩn mặc định) | Không |
| `pages/viec-cho-duyet/approvalsConfig.tsx:30-41` | Việc chờ tôi duyệt (CHUNG-15) | Cột «Học sinh · đối tượng» ghép tên học sinh hoặc chi tiết với mã đối tượng | Hai cột: Học sinh, Đối tượng (mã) | Không |
| `pages/viec-cho-duyet/approvalsConfig.tsx:48` | CHUNG-15 | Cột cấp duyệt ghép «cấp/tổng · nhãn cấp» | Cột Cấp, cột Vai trò duyệt | Không |
| `pages/yeu-cau-buoi/SessionRequestListPage.tsx:160-163` | Yêu cầu buổi (BUOI-07..09) | Một ô ghép «loại · đối tượng» và «lớp · khi nào · ngày đề nghị» | Cột Loại, Đối tượng, Lớp, Ngày buổi, Ngày đề nghị | Không |
| `pages/yeu-cau-buoi/requestLogic.ts:72-79` | Yêu cầu buổi | Cột đối tượng nối danh sách tên học sinh bằng dấu phẩy; cột «ngày · giờ bắt đầu–kết thúc» | Cột Ngày, Giờ bắt đầu, Giờ kết thúc | Không |
| `pages/khach-hang/custConfig.tsx:71, 142, 147` | Phụ huynh, Học sinh (KH-01..) | «Đang học tại» và «Lớp» nối nhiều mục bằng dấu phẩy trong một ô | Giữ ô nhiều giá trị nhưng cho chip riêng; lọc theo giá trị (đã có bộ lọc «Đang học tại», migration 603) | Có sắp xếp 2 cột khác; cột này không |
| `pages/ho-so-day/TeachingProfilePage.tsx:60-65` | Hồ sơ dạy (GV) | Môn dạy, Khối dạy, Cơ sở nối bằng dấu phẩy | Chip riêng từng mục | Không |
| `pages/sap-het-gio/ExpiringListPage.tsx:73` | Sắp hết giờ | Cột «Ghi danh» nối nhiều mã ghi danh bằng dấu phẩy | Một dòng một ghi danh (mở rộng dòng) hoặc chip | Không |
| `pages/bao-gia/quoteConfig.tsx:66`, `pages/don-hang/orderConfig.tsx:70` | Báo giá (BH-04), Đơn hàng (BH-06) | Cột Học sinh nối nhiều tên bằng dấu phẩy | Chip riêng từng học sinh; lọc theo học sinh | Có sắp xếp cột khác; cột này không |
| `pages/nguoi-duyet-ticket/ApproverConfigPage.tsx:72` | Người duyệt ticket (QT-15) | Cột nhóm con nối bằng dấu phẩy | Chip riêng | Không |
| `pages/co-hoi/oppConfig.tsx:25-28` (`oppTitle`) | Cơ hội (TS-04, TS-xx): tiêu đề thẻ, lớp phủ | Ghép «học sinh · phụ huynh» thành một tên hiển thị | Hai trường: Học sinh; Phụ huynh (cột đã có riêng ở bảng) | Có sắp xếp (cột Phụ huynh) |
| `pages/lead/leadFormat.ts:44` (`leadTitle`) | Lead (TS-01): tiêu đề thẻ | Ghép «phụ huynh · học sinh» | Hai trường riêng trên thẻ | Có sắp xếp (cột Phụ huynh) |
| `pages/buoi/sessionLogic.ts:89` | Buổi học (BUOI-01..) | Nhãn lớp ghép «môn · mã lớp» dùng làm cột và tiêu đề | Cột Môn, cột Lớp | Cần kiểm cột có sortable |
| `pages/diem-danh-ngay/DayAttendancePage.tsx:95`, `dayLogic.ts:60` | Điểm danh ngày | Một dòng ghép «giờ bắt đầu–kết thúc · phòng · …» | Cột Giờ, Phòng, Giáo viên | Không |

## 2. Trường chi tiết và thanh thông tin (mức B)

| Tệp:dòng | Màn | Nội dung gộp | Nên tách thành |
| --- | --- | --- | --- |
| `pages/phieu-thu/ReceiptRecordPage.tsx:710` | Phiếu thu (TC-02) | Trường Phụ huynh ghép tên · mã · số điện thoại | Ba trường: Phụ huynh, Mã, Điện thoại |
| `pages/phieu-thu/ReceiptRecordPage.tsx:734, 249` | TC-02 | «người lập · ngày giờ»; «người duyệt kế toán · ngày» | Người lập / Lúc lập; Người duyệt / Lúc duyệt |
| `pages/phieu-thu/ReceiptRecordPage.tsx:740` | TC-02 | Một ô ghép «đã trả / tổng · còn … · cọc …» | Ba trường: Đã thu, Tổng, Còn lại (cọc riêng) |
| `pages/don-hang/OrderRecordPage.tsx:911`, `OrderCreatePage.tsx:230, 441`, `bao-gia/QuotationRecordPage.tsx:545`, `QuotationCreatePage.tsx:95` | Đơn hàng, Báo giá | Phụ huynh ghép tên · mã · số điện thoại | Ba trường |
| `pages/don-hang/OrderRecordPage.tsx:973` | Đơn hàng | «người duyệt · ngày duyệt (duyệt thay)» | Người duyệt, Ngày duyệt, Duyệt thay (nhãn) |
| `pages/phieu-chi/VoucherRecordPage.tsx:255` | Phiếu chi (TC-11) | Phụ huynh ghép tên · mã | Phụ huynh, Mã |
| `pages/ghi-danh/EnrollmentRecordPage.tsx:166, 171` | Ghi danh (GD-01) | Học sinh ghép tên · mã; Phụ huynh ghép tên · mã | Hai trường mỗi đối tượng (tên, mã) |
| `pages/tai-tuc/UpsaleRecordPage.tsx:149` | Tái tục | Học sinh ghép tên · mã | Tên, Mã |
| `pages/buoi/SessionRecordPage.tsx:197, 211` | Buổi học (BUOI-03) | «số buổi · trạng thái» và «ngày · giờ bắt đầu–kết thúc» | Số buổi, Trạng thái; Ngày, Giờ bắt đầu, Giờ kết thúc |
| `pages/lop/ClassRecordPage.tsx:253` | Bản ghi lớp | Trường «Phân loại» ghép loại lớp · trình độ | Loại lớp, Trình độ |
| `pages/phieu/TestRecordPage.tsx:406` | Phiếu kiểm tra | Môn ghép mã môn · tên môn | Môn |
| `pages/nguoi-dung/UserRecordPage.tsx:347` | Người dùng | Phiên đăng nhập ghép «IP · thiết bị» | Hai cột: IP, Thiết bị |
| `pages/khung-chuong-trinh/CurriculumFramePage.tsx:272` | Khung chương trình | Nhãn «Môn · Khối» là một trường ghép hai giá trị | Hai trường: Môn, Khối |
| `pages/khung-chuong-trinh/LessonListPage.tsx:216-217` | Danh sách bài | Một dòng ghép môn · khối · trình độ · năm học · số bài | Các trường riêng ở đầu trang |
| `pages/phieu/TaskRecordPage.tsx:114, 206` | Phiếu nghiệp vụ | Tiêu đề «loại phiếu · mã ticket»; «mã ticket · tiêu đề» | Tiêu đề chỉ loại phiếu; mã và tiêu đề ticket hai ô |
| `pages/khach-hang/StudentRecordPage.tsx:482, 503`, `ParentRecordPage.tsx:424, 444, 465` | Học sinh, Phụ huynh (tab con) | Dòng tab ghép «ngày giờ · lớp», «ngày tạo · tiền», «ngày thu · tiền», «lớp · khối · trạng thái» | Bảng con có cột riêng |
| `pages/khach-hang/CustTickets.tsx:49-53` | Tab Ticket của khách | «mã · tiêu đề», «nhóm · ngày» | Cột Mã, Tiêu đề, Nhóm, Ngày |
| `pages/co-hoi/OpportunityRecordPage.tsx:339-341` | Cơ hội, tab Bài test | Cột «Bài test · cơ sở» ghép môn · hình thức · trình độ · cơ sở | Cột Môn, Hình thức, Trình độ, Cơ sở |
| `pages/co-hoi/OpportunityRecordPage.tsx:684`, `lead/LeadRecordPage.tsx:855` | Cơ hội, Lead | Nhóm trường «Nguồn và phụ trách» gộp hai nhóm | Hai nhóm: Nguồn; Phụ trách (đã là hai trường con, chỉ là tiêu đề nhóm) |
| `pages/ghi-danh/EnrollmentRecordPage.tsx:363` | Ghi danh | Nối nhiều giá trị bằng « · » trong một ô | Chip riêng |
| `pages/danh-muc/CatalogHistoryDialog.tsx:22` | Lịch sử danh mục | Cột «Mục» ghép mã · tên mục | Cột Mã, Tên |
| `pages/phieu/TestListPage.tsx:297, 475, 536` | Danh sách phiếu kiểm tra | Thẻ và dòng ghép «giờ hẹn · cơ sở», nhiều trường nối bằng « · » | Cột riêng |

## 3. Thẻ (card) và thanh ngữ cảnh (mức B/C)

| Tệp:dòng | Màn | Nội dung gộp | Nên tách thành |
| --- | --- | --- | --- |
| `pages/lop/ClassCard.tsx:24` | Thẻ lớp | Một dòng nối nhiều thuộc tính bằng « · » | Mỗi thuộc tính một dòng nhỏ |
| `pages/ticket/TicketCard.tsx:27` | Thẻ ticket | «loại · nhóm con» | Hai nhãn |
| `pages/lead/LeadListPage.tsx:504-512`, `co-hoi/OpportunityListPage.tsx:428-436` | Thẻ lead, cơ hội | Nhiều thông tin trên một dòng «điện thoại · cơ sở» | Điện thoại, Cơ sở riêng |
| `pages/tai-tuc/UpsaleCard.tsx:14, 24` | Thẻ tái tục | Hai dòng nối nhiều trường bằng « · » | Mỗi trường một nhãn |
| `pages/home/CrmHome.tsx:123` | Trang chủ CRM | Dòng nối nhiều trường lịch hẹn | Tên hoạt động, Giờ, Đối tượng riêng |
| `pages/gv/classesLogic.ts:52, 64`, `gv/todayLogic.ts:56`, `gv/scheduleLogic.ts:65`, `gv/TeacherClassPage.tsx:107-198` | Cổng giáo viên (điện thoại) | Dòng thẻ lớp, buổi nối môn · loại lớp · trình độ · giờ · phòng | Cổng điện thoại cần ngắn; nên tách ít nhất giờ, phòng ra dòng riêng |

## 4. Chấp nhận được (mức C, không đổi)

Tiêu đề trang và dấu vết trên thanh (`useCrumbTail`) dạng «tên · mã» (`ParentRecordPage:111, 215`, `StudentRecordPage:114, 179`, `TestRecordPage:145`); nhãn lựa chọn trong ô chọn (`MergeDialog`, `ClassFormPage:277`, `QuoteLineGrid:273`, `SettingsPage:415`, `HolidayPage:246`, …); phụ đề hộp thoại (`... subtitle={`${record.code} · ${...}`}`); đếm phân trang `Data.tsx:92`; thanh tài khoản `CrmShell.tsx:173` («vai trò · cơ sở»).

## 5. Việc đề xuất sau khi anh chọn

1. **Mức A** (17 chỗ, mục 1): đổi cột ghép thành cột riêng; ưu tiên Ticket, Lớp, Việc chờ duyệt, Yêu cầu buổi. Mỗi cột mới khai `key` riêng để sắp xếp được khi có cột dữ liệu ở DB; cần kiểm hàm danh sách DB đã trả đủ trường chưa (không cần migration nếu hàm đã trả tên nhóm, nhóm con riêng).
2. **Mức B** (mục 2 và 3): tách trường chi tiết (Phụ huynh: tên, mã, điện thoại; người lập, lúc lập; …); không đổi DB.
3. Cột nhiều giá trị (nối dấu phẩy): dùng chip, một giá trị một chip, lọc theo giá trị.
4. Cổng giáo viên điện thoại: giữ ngắn gọn nhưng không ghép hai loại thông tin khác nhau vào một dòng.
