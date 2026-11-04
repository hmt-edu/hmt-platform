# Đối chiếu quyết định nghiệp vụ 04/11 (từ v2) với spec và DB v1, kế hoạch theo mốc

Viết 04/11/2026, **chờ anh Trường OK trước khi viết migration hay code** (Đ286). Luật đã vào `docs/spec/04` mục 14 và `docs/spec/06` mục 3. "DB v1" là các migration tới `063` trên `main`. Chỗ ghi **[CHỜ]** cần anh trả lời (mục 3).

## 1. Bảng khác biệt

| # | Chủ đề | Quyết định 04/11 | `docs/spec` | DB v1 hiện tại | Việc phải làm |
|---|---|---|---|---|---|
| 1 | Giai đoạn Lead | C1 đến C4 | Giống (06 mục 1.2) | Giống | Không đổi |
| 2 | Giai đoạn Cơ hội | L1 đến L8 | Giống (06 mục 1.3) | Giống | Không đổi |
| 3 | Nhóm con L4 | 8 nhóm L4A đến L4H; L4E đến L4H người dùng chọn, không tự đóng cơ hội | 4 nhóm L4A đến L4D | L4A đến L4D | Thêm L4E đến L4H. **[CHỜ]** tên (file `02.Stage` trong `_inbox/` chỉ có L4A đến L4D) |
| 4 | Nhóm con L7 | 18 nhóm L7A đến L7S; L7M đến L7S người dùng chọn | 11 nhóm: L7A đến L7I, L7K, L7L | Giống spec | Thêm L7M đến L7S. **[CHỜ]** tên và mã (bản đang có chỉ tới L7L; L7J không dùng) |
| 5 | Nhóm con L5, L6 | Hệ thống đặt: C4D, L5C đến L5O, L5P, L6A | L5A, L5B, L5P hệ thống gắn; L5C đến L5Q nối lý do huỷ test; L6A hệ thống, L6B đến L6F chọn tay (R-CRM-34) | L5A đến L5Q (không J, L); **L6A đến L6G** (spec chỉ tới L6F) | Đối chiếu danh mục, báo anh chỗ lệch **trước khi sửa** (L5Q, L6G). **[CHỜ]** |
| 6 | Nhóm con L8 | Nằm trong nhóm "hệ thống đặt": L8A đến L8C | **Nhân viên chọn tay** L8A, L8B, L8C; tự nâng L8C (R-CRM-16, 17, 35) | Chọn tay | **Vênh.** **[CHỜ]** anh xác nhận ai đặt L8A, L8B, L8C |
| 7 | Bỏ qua test | Lý do BQ1 đến BQ5 (BQ5 ghi chú), từ bất kỳ giai đoạn nào trước L7 khi chưa có phiếu hợp lệ | 4 lý do (danh mục 33), "Khác" ghi chú | 4 lý do | Đổi danh mục 33 thành BQ1 đến BQ5; kiểm lại điều kiện (R-V2-03) |
| 8 | Số điện thoại | Đúng 10 số bắt đầu 0; thêm số thứ hai cho phụ huynh, học sinh | Chuẩn hoá và khớp theo SĐT (R-CRM-27); chưa có số thứ hai | Đã chặn đúng 10 số bắt đầu 0 (`HMT_SDT_SAI`); chưa có cột số thứ hai | Giữ quy tắc 10 số; thêm cột SĐT 2. **[CHỜ]** số thứ hai có dùng để khớp phụ huynh không. Khi nạp: dòng sai độ dài vào file lỗi |
| 9 | Trùng SĐT | Chỉ cảnh báo, "Mở bản ghi trùng" và "Vẫn tạo" | Giống (TS-03) | Giống | Không đổi |
| 10 | Xuất dữ liệu | Admin và người được cấp trong ma trận quyền | Chỉ Admin (R-CRM-29) | Chỉ Admin | Chuyển sang hành động XUAT trong ma trận cho Lead, Cơ hội, Phụ huynh, Học sinh |
| 11 | Hồ sơ phụ huynh | Mọi cơ sở xem được | Dùng chung toàn hệ thống (R-CRM-26) | RLS theo cơ sở **[cần kiểm]** | Kiểm RLS của phụ huynh; mở đọc cho mọi cơ sở nếu đang giới hạn |
| 12 | Ghi chú và hoạt động | Hai luồng Ghi chú, Hệ thống; chip lọc | Có Chatter (khuôn K06) | Có luồng hệ thống; luồng ghi chú người dùng **[cần kiểm]** | Kiểm; thiếu thì thêm ghi chú sửa, ẩn của chính mình |
| 13 | Tên đăng nhập | `annv`; trùng thì `annv1`; hàm DB; không đổi | Chưa có luật sinh tên | Đặt tay khi tạo tài khoản | Hàm DB sinh tên (dùng cho nạp Người dùng và tạo tài khoản) |
| 14 | Vai trò | Thêm MARKETER, MARKETING_MANAGER (quyền SALES, mọi cơ sở); MARKETING giữ; vận hành là ADMIN | 9 vai trò: ADMIN, BRANCH_MANAGER, SALES, CSKH, ACCOUNTANT, TEACHER, TA, STUDENT, PARENT (R-HT) | Giống spec: 9 vai trò. **Chưa có** MARKETER, MARKETING_MANAGER, và cũng chưa có MARKETING, OPERATIONS (file cấu hình `_inbox/` có hai vai trò sau) | Thêm MARKETER, MARKETING_MANAGER và dòng ma trận quyền. **[CHỜ]** "MARKETING cũ giữ nguyên" nhưng DB v1 chưa có vai trò này: có tạo MARKETING và OPERATIONS không |
| 15 | Phạm vi cơ sở | "Tất cả" hoặc danh sách mã cơ sở mỗi người; giáo viên, trợ giảng tất cả cơ sở | Phạm vi theo vai trò (`default_scope`) và cơ sở người dùng | Bảng cơ sở theo người dùng | Thêm chế độ "Tất cả" mỗi người; giáo viên, trợ giảng mặc định tất cả |
| 16 | CS3 | Cơ sở dạy học thường (có lớp, phòng, học sinh); khối 1 đến 12 | CS3 Hội sở, không có lớp; ô chọn cơ sở không có CS3 (R-HT-02) | CS3 là Hội sở (`app.branch.is_office = true`) | Đổi CS3 thành cơ sở dạy học (bỏ cờ văn phòng, kiểm các chỗ dùng cờ này). **[CHỜ]** ô chọn cơ sở có hiện CS3 không; công tắc tính năng có cột CS3 không |
| 17 | Quản lý trực tiếp | Mỗi người có ô Quản lý trực tiếp | Có (R-HT-06) | Có `manager_id` | Không đổi; nạp Người dùng đọc cột `quan_ly` |
| 18 | Duyệt đơn | Quản lý trực tiếp; không có thì Trưởng cơ sở | Người lập không có quản lý trực tiếp (và không phải Trưởng cơ sở) thì **không trình được** (R-HT-06) | Chặn trình khi thiếu quản lý | Đổi: không có quản lý trực tiếp thì chuyển Trưởng cơ sở duyệt |
| 19 | Trần chiết khấu 20% | Chỉ cảnh báo, không chặn | Vượt trần phải quản lý duyệt (R-TIEN-29) | Báo giá: cảnh báo (`over_cap`). Đơn: người duyệt **phải tích đồng ý** mới duyệt (Đ102, `HMT_CAN_TICH_DONG_Y`) | **[CHỜ]** có bỏ ô tích đồng ý ở bước duyệt không. Tên cờ và cảnh báo giữ |
| 20 | Trạng thái đơn | Nháp, **Đã gửi**, Đã trình, Đã duyệt; Huỷ; từ chối về Nháp kèm lý do trong ghi chú; "Hết hạn" là nhãn sau 14 ngày từ lúc Gửi | Nháp, Đã trình, Đã duyệt, Huỷ (R-TIEN-01, 06); hạn 14 ngày áp báo giá (R-TIEN-05) | NHAP, DA_TRINH, DA_DUYET, HUY | **[CHỜ]** "Đã gửi" của đơn nghĩa là gì (gửi cho ai, để làm gì) trước khi thêm trạng thái |
| 21 | Trạng thái phiếu thu | Nháp, **Đã gửi**, Chờ kế toán, Đã duyệt; Huỷ | Người lập trình, quản lý duyệt, kế toán duyệt; từ chối về Nháp (R-TIEN-01) | Chưa có bảng phiếu thu (chỉ có điều khoản thanh toán `payment_term`); DB2 chưa làm | Dựng khi làm Thu chi; "Đã gửi" thay "Đã trình" |
| 22 | Phiếu thu không qua đơn | **Thu nợ đầu kỳ**: CSKH tạo, kế toán duyệt, không cần đơn, không vượt nợ còn lại | Mọi phiếu thu sinh từ đơn (R-TIEN-02) | Chưa có | Thêm loại phiếu. **[CHỜ]** có qua bước quản lý trực tiếp không |
| 23 | Sổ số dư, nợ đầu kỳ | Nợ đầu kỳ là số âm trong sổ số dư khách hàng; thu bằng phiếu | Sổ số dư chỉ thêm dòng (R-TIEN-33) | Chưa có | Làm cùng phiếu thu (DB-TC) |
| 24 | Loại buổi | Danh mục; thêm **Kiểm tra** (trừ quỹ chính); mỗi loại gắn form nhận xét; ai xếp lịch chọn loại | 4 loại: Chính, Củng cố, Học bù, Học bổ trợ (R-BUOI-01); `SESSION_TYPE` | 4 loại | Thêm loại Kiểm tra và liên kết loại buổi với form nhận xét. **[CHỜ]** danh sách loại cuối cùng (Học kiến thức mới, Ôn tập, Kiểm tra giữa kỳ, cuối kỳ…) và có giữ 4 loại cũ không |
| 25 | Kiểm tra | Một buổi bình thường (lịch, điểm danh, trừ giờ); form riêng: phạm vi, điểm tối đa 10, Điểm tổng hoặc Theo 3 nhóm; Chưa chấm, Đã chấm, Vắng | Chưa có luật riêng cho kiểm tra định kỳ | Chưa có | Làm trong Đào tạo (R-V2-20): bảng điểm theo em, tham số điểm tối đa |
| 26 | Nhận xét buổi | 9 tiêu chí thang 1 đến 5; sau Done giáo viên không sửa, sửa qua ticket giáo viên; sửa điểm sau Done chỉ quản lý đào tạo | R-GV-01 và R-GV-04 (bộ tiêu chí cũ, đang đổi); GV07b, GV08b là bản nháp chờ đổi luật | Chưa có | Đối chiếu R-GV-01 với 9 tiêu chí. **[CHỜ]** bộ 9 tiêu chí chính thức |
| 27 | Aftersale: loại ticket | 3 loại: Đề nghị, Khiếu nại, Ticket giáo viên; phân loại hai cấp; khiếu nại sinh đề nghị con | 2 loại, mã DN, KN (R-CS-01) | Chưa có | Làm Aftersale (DB trước) |
| 28 | Aftersale: duyệt | Duyệt ở **bản ghi nghiệp vụ** (bảo lưu, chuyển lớp…); ticket chỉ đóng khi nghiệp vụ xong | Duyệt ở ticket theo nhóm con (R-CS-05, 07) | Chưa có | Làm Aftersale theo mới |
| 29 | Aftersale: trạng thái | Luồng chung; không tự đóng; "Chờ đóng" quá 3 ngày; huỷ kèm lý do | Hai luồng riêng đề nghị, khiếu nại (R-CS-05, 06) | Chưa có | **[CHỜ]** chốt luồng chung (tài liệu `v2-aftersale.md` đề xuất 7 bước) |
| 30 | Aftersale: tái tục | Tái tục là một dạng Đề nghị, không danh sách riêng; đơn tái tục tạo từ nút "Tạo đơn hàng" trên ticket | Phiếu tái tục TT tự sinh, L1 đến L8, màn TT-01 đến TT-03 (R-GD-13) | Chưa có | **Vênh lớn.** **[CHỜ]** số phận phiếu tái tục TT và R-GD-13 |
| 31 | Aftersale: hạn, mức độ | Khẩn, Cao, Thường, Thấp; dưới 25% thời gian vàng; quá hạn đỏ; mọi số là tham số | SLA theo loại (R-CS-08); mức độ trong danh mục | Chưa có | Thêm tham số SLA theo loại, mức độ, nhóm con. **[CHỜ]** bảng số (tài liệu v2 ghi "anh duyệt 30/10") |
| 32 | Nạp dữ liệu CS5 | Thứ tự: Người dùng, Lớp, Phụ huynh, Học sinh, Ghi danh, Số dư, Cơ hội, Phiếu test, (Buổi học, Điểm danh để đối soát); màn Nhập chỉ Admin | Nạp qua hàm riêng (R-CRM-27); nhập lead từ file CSV (TS-04) | Nhập lead CSV (TS-04); chưa có loại Lớp, Ghi danh, Số dư | Mở rộng khung nạp theo loại (xem kế hoạch) |
| 33 | Học phí cũ | Chỉ nạp số dư đầu kỳ; nhân 1000; tiền thu thừa | Chưa quy định | Chưa có | Cột và loại nạp "Số dư" (R-V2-32) |
| 34 | Phiếu test cũ | "Hoàn thành (dữ liệu cũ)", giữ điểm, không bắt trình độ, xếp loại | Phiếu Hoàn thành bắt trình độ, phân loại (R-CRM-10) | Chưa có cờ dữ liệu cũ | Thêm cờ; nới ràng buộc cho dữ liệu cũ |
| 35 | Sổ giờ đầu kỳ | Mỗi em một dòng "Số dư đầu kỳ"; điểm danh cũ chỉ đối soát; x, P, KP, M tính giờ; N không | Sổ giờ chỉ thêm dòng (R-GD-04) | Chưa có | Dòng số dư đầu kỳ trong sổ giờ; ngày chốt 17/11 |

## 2. Kế hoạch PR theo mốc

Nguyên tắc: mỗi nhóm một PR nhỏ, CI xanh, anh OK mới gộp; DB trước, giao diện sau; chưa sửa giao diện Báo giá, Đơn hàng, Phiếu thu khi anh chưa gửi yêu cầu (Đ287). Ngày là mục tiêu, đẩy sớm được thì đẩy.

### Mốc 10/11: Tuyển sinh và màn Nhập CS5
| PR | Nội dung | Thiết kế |
|---|---|---|
| T1 (DB) | Vai trò MARKETER, MARKETING_MANAGER; phạm vi "Tất cả"; hàm sinh tên đăng nhập; cờ dạy học CS3; xuất theo ma trận; kiểm RLS hồ sơ phụ huynh | Không cần giao diện |
| T2 (DB) | SĐT 10 số, SĐT thứ hai; cột mới phụ huynh (người thân, địa chỉ) và học sinh (trường, khối, giới tính); BQ1 đến BQ5 | Giao diện: chỉ thêm trường ở KH-02, KH-05 theo khuôn có sẵn |
| T3 (DB) | Nhóm con mới L4E đến L4H, L7M đến L7S, chỉnh nhóm con L5, L6, L8 | Cần **[CHỜ]** tên và L8 |
| T4 (DB) | Khung nạp theo loại: Người dùng, Lớp, Phụ huynh, Học sinh, Cơ hội, Phiếu test (xem trước, dòng lỗi, `legacy_ref`, bỏ qua dòng trùng mã cũ); phiếu test cũ | Không cần giao diện |
| T5 (UI) | Màn **Nhập dữ liệu CS5** (chỉ Admin): chọn loại, tải file, ghép cột, xem trước, báo lỗi, xuất dòng lỗi | **Dựng theo TS-04 và K4b** có sẵn. Thiếu: màn chọn loại nạp nhiều loại, xuất dòng lỗi, chế độ "một dòng lỗi chặn cả loại" (chưa có khung) |
| T6 (UI) | Chỉnh giao diện Tuyển sinh theo mục 14.1 (nhóm con mới, lý do BQ, ghi chú hai luồng nếu thiếu) | Theo TS-xx trong `design/hmt-canvas-6f57/` |

Rủi ro 10/11: T3 và T5 phụ thuộc câu trả lời ở mục 3 (tên nhóm con, cách đặt L8). Nạp Ghi danh, Số dư, Lớp cần thêm DB đào tạo (mốc 17/11): ở mốc 10/11 nạp Lớp trước để Ghi danh nạp sau.

### Mốc ~12/11: Bán hàng, Thu chi
| PR | Nội dung | Thiết kế |
|---|---|---|
| B1 (DB) | Duyệt đơn: không có quản lý trực tiếp thì Trưởng cơ sở duyệt; trần chỉ cảnh báo (sau câu trả lời về ô tích); trạng thái đơn "Đã gửi" (sau câu trả lời) | Không sửa giao diện khi anh chưa gửi yêu cầu |
| B2 (DB) | Phiếu thu hai bước, khoản tiền vào (chỉ thêm), đảo khoản; Thu nợ đầu kỳ; Sổ số dư; nạp Số dư | Canvas có TC-01 đến TC-05, TC-07 đến TC-11, TC-13, TC-15, TC-17; **thiếu TC-06 (Huỷ phiếu thu), TC-12 (bản in phiếu chi), TC-14 (Số dư khách hàng), TC-16 (Dùng số dư cho đơn mới)** (chờ anh chỉnh phiếu thu) |
| B3 (UI) | Giao diện Thu chi theo TC có sẵn (**chỉ sau khi anh gửi yêu cầu chỉnh phiếu thu**) | Như trên |
| B4 | Số giờ gói 6 tháng (12 sản phẩm), giá online hai sản phẩm | **[CHỜ]** anh báo |

### Mốc ~17/11: Đào tạo, Cổng giáo viên, Aftersale (chốt giờ 17/11)
| PR | Nội dung | Thiết kế |
|---|---|---|
| D1 (DB) | Lớp, Ghi danh, Sổ giờ, Buổi học, Điểm danh; nạp Lớp, Ghi danh, Số dư, Buổi học, Điểm danh (đối soát) | Lớp: LOP-01 đến 03, 05, 06, 09 (`hmt-canvas-6f57`); **LOP-08 ở `hmt-canvas-8a0d`**. Ghi danh GD-01 đến GD-07, Buổi BUOI-01, 02, 04 đến 14 ở `6f57`; **BUOI-03 ở `8a0d`** |
| D2 (DB) | Loại buổi (thêm Kiểm tra), form nhận xét, 9 tiêu chí, bảng điểm kiểm tra, "Nhận xét chờ gửi" | Cổng giáo viên GV-01 đến GV-16 và bộ khuôn KG ở `8a0d`. **GV-07, GV-08 chưa dựng được** (Design sửa lại GV07b, GV08b); GV-17, GV-18 chưa có |
| D3 (UI) | Ghi danh, Lớp, Buổi, Cổng giáo viên | Như trên |
| A1 (DB) | Aftersale: ticket 3 loại, danh mục hai cấp, SLA tham số, phiếu nghiệp vụ (bảo lưu, chuyển lớp, dừng học, học bù, hoàn phí, chuyển phí); ticket giáo viên | DB làm trước được |
| A2 (UI) | Màn Aftersale (danh sách, bản ghi, tạo ticket) | **Chưa có thiết kế** (Design đang vẽ): dừng đến khi có khuôn |

Tổng hợp **màn chưa có thiết kế** (không dựng được): Aftersale (CS-01 đến CS-16, trừ CS-16 chưa kiểm), GV-07, GV-08 (nháp), TC-06, TC-12, TC-14, TC-16, màn chọn loại nạp và xuất dòng lỗi của màn Nhập, GV-17, GV-18.

## 3. Câu hỏi cần anh trả lời trước khi làm

1. Tên và mã các nhóm con mới L4E đến L4H, L7M đến L7S (file `02.Stage` trong `_inbox/` chỉ có L4A đến L4D, L7A đến L7L). Anh gửi bảng đầy đủ.
2. L8A đến L8C và L5A, L5B, L5Q: hệ thống đặt hay nhân viên chọn tay? (Quyết định ghi hệ thống đặt L8A đến L8C; spec đang cho chọn tay.)
3. Danh mục v1 có L5Q và L6G; spec chỉ có L6A đến L6F. Giữ hay bỏ?
4. SĐT thứ hai có dùng để khớp phụ huynh không?
5. CS3 dạy học thường: ô chọn cơ sở khi xem dữ liệu có hiện CS3 không?
6. Vai trò MARKETING và OPERATIONS (có trong file cấu hình, chưa có trong DB v1): có tạo không?
7. Trần chiết khấu chỉ cảnh báo: có bỏ luôn ô tích đồng ý khi duyệt đơn vượt trần không?
8. "Đã gửi" của đơn hàng nghĩa là gì và gửi cho ai?
9. Thu nợ đầu kỳ có qua bước quản lý trực tiếp trước kế toán không?
10. Loại buổi: danh sách cuối cùng; bộ 9 tiêu chí nhận xét chính thức; có đổi R-GV-01, R-GV-04 không?
11. Phiếu tái tục TT (R-GD-13) giữ hay thay bằng ticket Đề nghị "Tái tục"?
12. Aftersale: luồng trạng thái chung và bảng SLA (con số), danh mục ticket giáo viên, thứ tự ưu tiên nghiệp vụ.
13. Số giờ gói 6 tháng và giá online hai sản phẩm (đã nói anh báo sau).
