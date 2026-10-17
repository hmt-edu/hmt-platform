# 00_DOC_TRUOC — Gói bàn giao P3 · Tuyển sinh (HMT CRM)

Đọc file này trước khi mở gói. Gói chỉ có **P3 Tuyển sinh (mã màn TS-xx)**, bản duyệt **16/10/2026, canvas v48** (anh Trường duyệt). P0, P1, P2 đã có ở gói **HMT_P0-P2_BAN_GIAO_v4**, không lặp lại ở đây. Gói này dùng chung `ds/hmt/...` với gói v4 (cùng token, cùng `bundle.css`).

Gồm **26 artboard**. **TS-18 và TS-19 đã bỏ** (xếp lịch gộp vào TS-15; huỷ phiếu nằm trong menu Hành động của TS-17), không có trong gói.

## 0. Cấu trúc gói
```
00_DOC_TRUOC.md
P0_v5_thay_doi.md                  những chỗ khuôn P0 sẽ đổi ở bản v5 (xem mục 4)
ds/hmt/handoff/hmt-tokens.css      token màu, chữ, khoảng cách, bo góc (giống gói v4)
ds/hmt/components/bundle.css       thành phần dùng chung (giống gói v4)
ds/hmt/tokens.json                 token dạng JSON (giống gói v4)
artboards/*.dc.html                26 artboard P3
artboards/ds/hmt/...               bản sao token để mở artboard độc lập
png/*.png                          ảnh từng artboard (1440×1000); tên PNG trùng tên artboard
```
- Mỗi artboard là một file `.dc.html` của Design canvas, tham chiếu `ds/hmt/...` theo đường dẫn tương đối. Cần `support.js` của công cụ canvas mới mở độc lập được. Khi dựng thật, lấy HTML trong `<x-dc>` và CSS token làm chuẩn, không cần `support.js`.
- Các artboard **bấm được** (bộ lọc, hộp thoại, chuyển giai đoạn, Hoàn tác…) để xem hành vi. Logic nằm trong thẻ script của từng file; đó là bản mô phỏng, không phải mã dựng thật.
- Ảnh PNG chụp bằng trình duyệt không có phông Inter / Be Vietnam Pro nên chữ là phông thay thế. Kích thước và màu đúng; phông chuẩn lấy theo token.
- Dữ liệu trong màn là dữ liệu mẫu (CO000121, PKT000105…).

## 1. Danh sách artboard

| Artboard | Mã màn | Nội dung | PNG |
|---|---|---|---|
| TS01 | TS-01 | Lead · danh sách | `png/TS01.png` |
| TS01b | TS-01b | Lead · kanban | `png/TS01b.png` |
| TS02 | TS-02 | Lead · chi tiết | `png/TS02.png` |
| TS03 | TS-03 | Tạo lead (cảnh báo trùng SĐT) | `png/TS03.png` |
| TS04 | TS-04 | Nhập lead từ file | `png/TS04.png` |
| TS06 | TS-06 | Hộp thoại Tạo cơ hội khi đã có cơ hội | `png/TS06.png` |
| TS07_K1 | TS-07 | K1 Tổng quan dạng List (Cơ hội) | `png/TS07_K1.png` |
| TS07_K2 | TS-07 | K2 Tổng quan dạng Kanban (Cơ hội) | `png/TS07_K2.png` |
| TS08_K3 | TS-08 | K3 Chi tiết Cơ hội CO000121 | `png/TS08_K3.png` |
| TS08b_K3 | TS-08b | K3 Cơ hội CO000099 có 2 phiếu test (Huỷ + Hoàn thành) | `png/TS08b_K3.png` |
| TS09 | TS-09 | Chuyển CO000121 từ L6A sang L7 (phiếu đã Hoàn thành) | `png/TS09.png` |
| TS09a | TS-09a | Chuyển L7/L8 bị chặn: còn phiếu test dang dở | `png/TS09a.png` |
| TS09b | TS-09b | Chuyển L7/L8 khi chưa có phiếu (hoặc phiếu đều Huỷ): lý do bỏ qua test | `png/TS09b.png` |
| TS09c | TS-09c | Chuyển L8: chọn L8A/L8B/L8C, không hoàn tác | `png/TS09c.png` |
| TS09d | TS-09d | Chuyển sang L5 khi thiếu thông tin học sinh | `png/TS09d.png` |
| TS10 | TS-10 | Gộp lead / cơ hội trùng | `png/TS10.png` |
| TS10b | TS-10b | Lead ở trạng thái Đã gộp (LD000241) | `png/TS10b.png` |
| TS11_K5 | TS-11 | K5 Calendar (Lịch hẹn) | `png/TS11_K5.png` |
| TS11b | TS-11b | Lịch hẹn · danh sách | `png/TS11b.png` |
| TS11c | TS-11c | Lịch hẹn · Kanban (cột = trạng thái) | `png/TS11c.png` |
| TS13 | TS-13 | Hộp thoại tạo / dời lịch hẹn | `png/TS13.png` |
| TS15 | TS-15 | Hộp thoại Tạo phiếu kiểm tra | `png/TS15.png` |
| TS16 | TS-16 | Phiếu kiểm tra · danh sách | `png/TS16.png` |
| TS16b | TS-16b | Phiếu kiểm tra · kanban | `png/TS16b.png` |
| TS16c | TS-16c | Phiếu kiểm tra · calendar | `png/TS16c.png` |
| TS17 | TS-17 | Phiếu kiểm tra · chi tiết | `png/TS17.png` |

Khuôn P0 mỗi màn dùng: TS-01 K1 · TS-01b K2 · TS-02 K3 (biến thể Lead) · TS-03 K07b/K07c · TS-04 K4b · TS-07 K1/K2 · TS-08 K3 · TS-09 và các bản a–d, TS-10, TS-10b, TS-13, TS-15 hộp thoại K4 · TS-11b K1 · TS-11c K2 · TS-11 K5 · TS-16 K1 · TS-16b K2 · TS-16c K5 · TS-17 K3 (phiếu kiểm tra).
Màn dùng chung một bộ máy Filters / Group By: TS-01, TS-07 K1, TS-11b, TS-11 K5, TS-16, 16b, 16c. Trong file hiện mỗi artboard còn mang một bản sao riêng; dựng thật thì tách thành một chỗ dùng chung.

## 2. Quyết định dùng chung đã chốt

**Giai đoạn (stage) của Cơ hội**
- Cơ hội đi từ L1 đến L8. Giai đoạn con dùng đúng danh sách tên đầy đủ, ở mọi màn có giai đoạn con (thanh giai đoạn, bộ lọc, Group By, dòng thời gian): L1 không có giai đoạn con; L2A–C; L3A–H; L4A–D; L5A/B/P/C–I/K/N/M/O/Q; L6A–F; L7A–I/K/L; L8A–C. Không dùng L5J, L5L, L7J.
- **L6 do hệ thống tự đổi** (khoá, không chọn tay). **L8 chọn tay** sau khi thu tiền: L8A "PH đặt cọc", L8B "PH thanh toán chia để trả", L8C "PH hoàn thành 100% học phí". Hộp chọn bắt buộc và có ô tick xác nhận "Chuyển L8 không hoàn tác được" (TS-09c).
- Đổi giai đoạn Cơ hội **chỉ đi tới**, không có thanh Hoàn tác.
- L7 là chặng tuỳ chọn có giai đoạn con. Chuyển sang L7/L8 phải kiểm tra phiếu test: còn phiếu dang dở thì **chặn**, nêu mã phiếu và nút mở phiếu (TS-09a); chưa có phiếu (hoặc mọi phiếu đều Huỷ) thì bắt chọn **lý do bỏ qua test** (4 lý do; "Khác" bắt ghi chú) (TS-09b).
- Sang L5 phải có tên và năm sinh học sinh, thiếu thì chặn (TS-09d).
- Nút **"Tạo lịch Test" chỉ dùng được từ L5 trở đi**; ở L1–L4 mờ, rê chuột: "Chuyển cơ hội sang L5 trước".
- Menu **Hành động** của Cơ hội (K3) và Lead (TS-02) chỉ có **"Gộp trùng"** và **"Giao người phụ trách"**; không có Huỷ hay Từ chối.
- 1 phụ huynh có nhiều con: một cơ hội có thể có nhiều học sinh; chỉ tạo cơ hội thứ hai khi thời điểm khác nhau.

**Gộp trùng (TS-10, TS-10b) và bản ghi "Đã gộp"**
- Gộp được Lead hoặc Cơ hội. Chọn thẻ giữ lại, danh sách mục chuyển sang thẻ giữ lại (phiếu test cũng chuyển). Bị chặn nếu có báo giá hoặc đơn hàng, hộp nêu mã gây chặn. Có ô tick "Gộp không hoàn tác được" mới bấm được nút chính.
- Bản ghi đã gộp: chỉ đọc, dòng "Đã gộp vào <mã>" là link. **Mặc định ẩn** khỏi danh sách (K1); Filters có nhóm "Trạng thái bản ghi: Đã gộp" để hiện; khi hiện thì dòng mờ, có nhãn "Đã gộp · vào <mã>", bấm mở bản chỉ đọc. Kanban không hiện bản đã gộp. Tìm theo mã vẫn thấy.

**Nhập lead từ file (TS-04):** hộp nhiều bước K4b, 3 bước.

**Phiếu kiểm tra (TS-15…17)**
- Trạng thái: Nháp · Đang test · Chờ giáo viên chấm · Hoàn thành; thêm "Đã huỷ" (Kanban gập cột này, mặc định đóng).
- **Chỉ có "Huỷ phiếu"** (đã gộp "Từ chối phiếu" vào). Nằm trong menu Hành động; hộp lý do chọn từ danh mục **"Lý do huỷ test" (13 lý do)**; "Khác" bắt ghi chú.
- Thanh giai đoạn của phiếu **chỉ đọc**; đổi bằng nút, mỗi trạng thái 1 nút chính (Bắt đầu test → Nộp bài → Hoàn thành). Quy tắc chỉ áp cho phiếu test (và sau này đơn hàng, phiếu thu, báo giá), không áp cho Cơ hội và Lead.
- "Đưa về Nháp" ở Hoàn thành bắt nhập lý do. Lùi bước và đổi người phụ trách chỉ ghi log. Nút Sửa luôn hiện, bấm thì thành Lưu; sửa sau Hoàn thành ghi log.
- Bốn thông tin: Người tạo phiếu (tự ghi, chỉ đọc) · Cơ sở tạo phiếu (tự ghi, chỉ đọc) · **Cơ sở test** (mặc định = cơ sở người tạo, đổi được) · Người phụ trách (nhân viên care lịch test; mặc định = người tạo). Tên gọi: "Ngày giờ test", "Cơ sở test", nút "Nộp bài".
- Tạo phiếu (TS-15): **Đề test là ô nhập chữ**; **Ngày test và Giờ test bắt buộc, để trống mặc định**, vẫn có nút chọn nhanh; nút Tạo mờ đến khi điền đủ. Không có "Thêm học sinh khác". Kèm lịch hẹn nhắc: mặc định 17:00 hôm trước, hoặc 2 giờ trước nếu test trong 24 giờ.
- Kanban và Calendar: **không có** khay/cột/nhóm "Chưa có lịch"; phiếu nào cũng có ngày giờ. Kanban phiếu không kéo thả; cột không có lịch hẹn thì ẩn thanh màu dưới tên cột. Calendar: kéo khối sang ô khác mở hộp Đổi lịch (TS-15), bấm ô trống mở Tạo phiếu điền sẵn ngày giờ và phòng; không có chế độ xem theo giáo viên chấm.

**Lịch hẹn (TS-11, 11b, 11c, 13)**
- Trạng thái chỉ có **Chưa làm · Hoàn thành · Huỷ**. "Sắp tới / Hôm nay / Quá hạn" là bộ lọc và màu, không phải trạng thái.
- Lịch hẹn là nhắc lịch: Hoàn thành, Huỷ, Mở lại **không đổi giai đoạn, không tạo việc, không gửi thông báo**. Có nút **Mở lại** ở mọi nơi lịch hẹn đã Hoàn thành/Huỷ, không giới hạn thời gian, có hỏi xác nhận và ghi log.
- **Huỷ lịch hẹn** chọn lý do: PH báo bận · Không liên lạc được · Tạo nhầm · Khác ("Khác" bắt ghi chú). Hoàn thành lịch hẹn: một bấm.
- Ô "Gắn với" bắt buộc, chưa điền thì nút Tạo mờ (không có lịch mồ côi). Cột "Gắn với" là link mở Lead/Cơ hội, cuộn tới lịch hẹn.
- Kanban lịch hẹn: kéo sang Hoàn thành hỏi kết quả; sang Huỷ hỏi lý do; ra khỏi Hoàn thành/Huỷ hỏi xác nhận mở lại; Hoàn thành ⇄ Huỷ không chuyển trực tiếp.

**Bộ lọc và thanh công cụ**
- Hộp "Thêm bộ lọc tuỳ chỉnh": trường xếp A–Z; ô giá trị có tìm kiếm và tick nhiều giá trị; dropdown nổi tối đa 240px, Esc đóng danh sách trước; mặc định **BẤT KỲ (OR)** có ghi chú AND/OR.
- Hàng chip kiểu TS-01 ("Xoá lọc" ngay sau chip; "Save to Favorites" trong menu Favorites). "Tôi là sale" đổi thành **"Tôi phụ trách"**; phiếu test có thêm "Tôi tạo", "Tôi chấm bài".
- **Mặc định lọc "Tuần này"** cho Lịch hẹn (list, Kanban, Calendar) và Phiếu kiểm tra; tắt được. Lịch hẹn có dòng nhắc "Còn N lịch Quá hạn từ các tuần trước · Xem".
- Smart button chỉ hiện **số đếm, không ghi mã**; bằng 0 thì mờ. Smart button "Kiểm tra" ở K3 đếm đủ số phiếu; có tab "Kiểm tra đầu vào (n)" liệt kê từng phiếu.
- Mọi bước tiến có thanh **Hoàn tác 8 giây** (trừ đổi giai đoạn Cơ hội).

**Hộp lý do dùng chung:** chọn lý do từ danh mục (bắt buộc); ô ghi chú chỉ hiện và bắt buộc khi chọn "Khác". Dùng cho Huỷ phiếu, Huỷ lịch hẹn, bỏ qua test.

## 3. Ghi chú theo màn
- **TS-08 / TS-08b (K3):** TS-08 là CO000121 ở L6A, có phiếu PKT000105 Hoàn thành. TS-08b là CO000099 ở L7A, 2 phiếu (PKT000099 Huỷ "Con ốm", PKT000108 Hoàn thành), mở sẵn tab Kiểm tra đầu vào.
- **TS-09 …09d:** 09 = CO000121 L6A→L7 (chọn giai đoạn con); 09a = bị chặn bởi PKT000112; 09b = bắt lý do bỏ qua test; 09c = chuyển L8; 09d = CO000137 ở L4 thiếu tên/năm sinh học sinh.
- **TS-16:** cột mặc định Mã PKT · Học sinh · Người tạo · Môn · Hình thức · Cấp độ · Ngày giờ test · Cơ sở test · Người phụ trách · GV chấm · Trạng thái. Cột ẩn chọn thêm: Cơ hội gốc, Điểm, Cơ sở tạo, Ngày tạo, Đề test, Phòng, Lớp đề xuất.
- **TS-17:** smart bar 6 nút (Cơ hội gốc · Học sinh · Lead · Lịch hẹn · Báo giá · Đơn hàng). Nút "Hoàn thành" mờ đến khi đủ GV chấm, điểm, bài làm, nhận xét.
- **Hộp "Huỷ phiếu" riêng (TS-19) không còn**; dùng hộp lý do ở TS-17.

## 4. Đổi gì so với P0 v4 (đưa vào P0 v5)
K3 gốc ở P0 **giữ nguyên** trong gói v4. Các dòng dưới đây là chỗ khuôn P0 sẽ đổi khi làm P0 v5; màn P3 tương ứng đã vẽ sẵn. File riêng: `P0_v5_thay_doi.md`.

| Khuôn P0 | Đổi gì | Lấy theo màn P3 |
|---|---|---|
| K3 | Thanh giai đoạn: L6 do hệ thống tự đổi (khoá); L8 chọn tay sau khi thu tiền (không khoá) | TS-08 K3 |
| K3, K1, K2 | Giai đoạn con dùng đúng danh sách tên đầy đủ 16/10 (L2A–C, L3A–H, L4A–D, L5A/B/P/C–I/K/N/M/O/Q, L6A–F, L7A–I/K/L, L8A–C; L1 không có; không dùng L5J, L5L, L7J) ở thanh giai đoạn, bộ lọc, Group By, dòng thời gian | TS-07, TS-08, TS-08b, TS-09, TS-09a–d |
| K3 | Đổi giai đoạn cơ hội không có thanh Hoàn tác (chỉ đi tới) | TS-09, TS-09c |
| K3 | Menu Hành động chỉ có "Gộp trùng", "Giao người phụ trách"; không có Huỷ/Từ chối | TS-08 K3, TS-02 |
| K3 | Nút "Tạo lịch Test" mờ ở L1–L4, rê chuột: "Chuyển cơ hội sang L5 trước" | TS-08 K3, TS-09d |
| K3 | Smart button "Kiểm tra" đếm đủ số phiếu; thêm tab "Kiểm tra đầu vào (n)" liệt kê từng phiếu | TS-08 K3, TS-08b |
| K3 | Hoạt động sắp tới: Huỷ lịch hẹn chọn lý do (PH báo bận · Không liên lạc được · Tạo nhầm · Khác, Khác bắt ghi chú) | TS-08 K3 |
| K4 (hộp lý do) | Lý do chọn từ danh mục (bắt buộc), ô ghi chú chỉ hiện và bắt buộc khi chọn "Khác" | TS-17, TS-16b, mọi chỗ Huỷ lịch hẹn |
| K4 (biến thể chặn) | Hộp chặn chuyển giai đoạn nêu mã bản ghi gây chặn + nút mở bản ghi | TS-09a |
| K4 (xác nhận không hoàn tác) | Ô tick "… không hoàn tác được" bắt buộc trước nút chính | TS-09c, TS-10 |
| K4b | Dùng nguyên cho Nhập lead từ file, 1 hộp chuyển bước | TS-04 |
| K2 | Thanh màu dưới tên cột: cột không có lịch hẹn nào thì ẩn thanh (không vẽ thanh xám) | TS-16b |
| Trạng thái chung | Trạng thái "Đã gộp": chỉ đọc, dòng "Đã gộp vào <mã>" là link, ẩn khỏi danh sách mặc định, tìm được bằng mã | TS-10b |
| K1 | Bản ghi “Đã gộp” mặc định ẩn; Filters có nhóm “Trạng thái bản ghi: Đã gộp” để hiện; dòng mờ, nhãn “Đã gộp · vào <mã>”, bấm mở bản chỉ đọc. Kanban (K2) không hiện bản đã gộp | TS-01, TS-07 K1 |

## 5. Chỗ còn chưa chốt / chưa vẽ
Những mục sau chưa được anh Trường chốt hoặc chưa vẽ trong bản v48; người viết đặc tả cần hỏi lại trước khi dựng:
1. **Danh mục đề test** ở màn Cấu hình: chưa vẽ. Đề test hiện chỉ là ô nhập chữ ở TS-15 và TS-17.
2. **Hộp Dời lịch hẹn** (chọn ngày, giờ mới, lý do) chưa nối thật vào TS-11b, TS-11c, K5; TS-13 có nhưng nút Dời ở danh sách mới báo "mở hộp Dời".
3. **TS-16c chế độ Tháng**, K5 chế độ Ngày/Tháng và Group By trên Calendar: chưa vẽ.
4. **K3 nhiều học sinh:** chưa có danh sách học sinh và nút Học sinh trong K3.
5. **Thanh màu Kanban** (TS-01b, K2) là hình tĩnh: kéo thẻ không tự đổi thanh, bấm khúc màu chưa lọc cột.
6. **"Hôm nay" của Lịch hẹn:** K5 coi là 13/10, TS-01/11b coi là 14/10; chưa thống nhất.
7. **Màu thanh giai đoạn TS-17** (thread bb848b00) và nút bấm được ở TS-17 (thread e3768f29): chưa có kết luận.
8. **Quyền xem theo vai trò** (K09b): chưa có quy định riêng cho P3 (chờ QT-05).
9. **Dải nhắc quá hạn** cho TS-16 giống Lịch hẹn: chưa quyết.
10. Hai ô TS-18, TS-19 đã bỏ; nhắc lại để không dựng.
