# Đặc tả P3 · Tuyển sinh (bản 2, 16/10/2026)

Người viết: Claude Chat. Anh Trường duyệt bản vẽ P3 canvas **v48** ngày 16/10 (v49 chỉ thêm ghi chú "Đã duyệt" và màn "P0 v5 · Đổi gì"). Bản 2 đã chốt 4 câu hỏi của bản 1 (mục 7).
Đặc tả này **chỉ dẫn mã luật, không chép lại luật**. Khi vênh: luật (`docs/spec/04`, `02`, `06` trong repo) > `docs/design/quyet-dinh-thiet-ke-13-10.md` > `docs/design/ban-do-man-hinh.md` > đặc tả này > gói thiết kế `design/hmt-p3/`. Vênh thì làm theo luật, ghi vào PR.

---

## 0. Nguồn

| Nguồn | Ở đâu |
|---|---|
| Luật CRM gốc | `docs/spec/04` mục 1 (R-CRM-01…20, gồm phần 04b đã vào repo ở PR #27) |
| Luật bổ sung 16/10 tối | `HMT/spec/04c-bo-sung-phieu-test-lich-hen-gop-16-10.md` (Project). **Chưa vào repo**: Code chép vào `docs/spec/04`, `06` ở PR đầu của P3 |
| Danh mục | `docs/spec/06` mục 1.1–1.3, danh mục 9, 10, 11, 13, 14, 15, 16, 33 + 34 mới (04c) |
| Mã | `docs/spec/02`: LD + 6 số, CO + 6 số, PKT + 6 số |
| Bản vẽ | Canvas "HMT Platform", hàng P3 · Tuyển sinh, bản v49. Gói bàn giao Design xuất → `_inbox/` → `design/hmt-p3/` |
| Khuôn | P0 v4 (`design/hmt-p0-p2/`) + bảng "P0 v5 · Đổi gì so với v4" (14 dòng, file `P0_v5_thay_doi.md` trong gói P3) |

---

## 1. Phạm vi

**Làm trong P3:**

| Mã màn | Tên | Artboard | Khuôn |
|---|---|---|---|
| TS-01 | Lead · danh sách | TS01 | K1 (+ Filters, Group By, Cột, Favorites) |
| TS-01b | Lead · Kanban | TS01b | K2 |
| TS-02 | Lead · bản ghi | TS02 | K3 (biến thể Lead) |
| TS-03 | Tạo nhanh lead + cảnh báo trùng SĐT | TS03, K07b, K07c | K07b, K07c |
| TS-04 | Nhập lead từ file | TS04 | K4b |
| TS-05 | Giao người phụ trách | (hộp Assign trong TS02, TS07) | K4 (Assign) |
| TS-06 | Tạo cơ hội khi lead đã có cơ hội | TS06 | K07c |
| TS-07 | Cơ hội · danh sách / Kanban | TS07_K1, TS07_K2 | K1, K2 |
| TS-08 | Cơ hội · bản ghi | TS08_K3, TS08b_K3 | K3 |
| TS-09 | Chuyển giai đoạn cơ hội | TS09, TS09a, TS09b, TS09c, TS09d | K4 |
| TS-10 | Gộp trùng + bản ghi "Đã gộp" | TS10, TS10b | K4 |
| TS-11 | Lịch hẹn · Calendar / danh sách / Kanban | TS11_K5, TS11b, TS11c | K5, K1, K2 |
| TS-13 | Tạo / dời lịch hẹn | TS13 | K4 |
| TS-14 | Cảnh báo trùng khách hàng | dùng K07c | K07c |
| TS-15 | Tạo phiếu kiểm tra (gồm xếp lịch, đổi lịch) | TS15 | K4 |
| TS-16 | Phiếu kiểm tra · danh sách / Kanban / Calendar | TS16, TS16b, TS16c | K1, K2, K5 |
| TS-17 | Phiếu kiểm tra · bản ghi (gồm Huỷ, Đưa về Nháp) | TS17 | K3 |

**Không làm trong P3:**
- TS-12: gộp vào trang chủ theo vai trò K09b (PR 5a).
- TS-18, TS-19: đã bỏ (gộp vào TS-15 và menu Hành động TS-17). Bản đồ màn hình sửa theo.
- GV-15 chấm test ở cổng giáo viên (làm sau, xem mục 7).
- Màn của phân hệ khác mà P3 trỏ tới: Phụ huynh, Học sinh (KH-xx), Báo giá, Đơn hàng (BH-xx), Lớp. Các nút trỏ tới hiện **mờ** (mục 5).
- Một cơ hội nhiều học sinh (R-CRM-23).
- Danh mục đề test, đính kèm file đề, bài làm, phiếu đánh giá (giai đoạn 4, file ở Cloudflare R2).
- Ô "Deadline" và "Stage Deadline" trên lead, cơ hội (luật chưa có; bỏ ở giai đoạn 1).

---

## 2. Dữ liệu

Code đề xuất lược đồ cụ thể trong kế hoạch. Yêu cầu:
- Mọi bảng theo chuẩn CLAUDE.md: `id uuid`, 4 cột người/giờ tạo-sửa, trigger nhật ký, RLS bật, không xoá cứng, `legacy_ref` có chỉ mục (dữ liệu sẽ nhập từ Sheet cũ), cột tìm không dấu như `user_account.search_text`.
- Mã cấp bằng hàm + bảng đếm (spec 02), cấp **lúc Lưu** (R-CRM-19; quyết định 13/10: Tạo mở khuôn chi tiết trống).
- Lưu **mã danh mục** (giai đoạn, nhóm con, nguồn, lý do…), tên đọc từ danh mục.

| Bảng (gợi ý) | Ý chính |
|---|---|
| Lead | Thông tin phụ huynh (họ tên, SĐT, phường/xã, tỉnh, địa chỉ, nhu cầu), học sinh (tên, ngày sinh, năm sinh, trường, học lực tự đánh giá, mục tiêu), cơ sở, người phụ trách, người hỗ trợ, nguồn 3 cấp (danh mục 9), chiến dịch, giai đoạn C1–C4 + nhóm con (danh mục 10), trạng thái bản ghi (Đang dùng / Đã gộp + gộp vào id), ngày giao |
| Cơ hội | Lead gốc, phụ huynh, **một** học sinh (R-CRM-23), cơ sở, người phụ trách, người hỗ trợ, nguồn (chép từ lead lúc tạo), giai đoạn L1–L8 + nhóm con (danh mục 11), lý do bỏ qua test (danh mục 33) + ghi chú, trạng thái bản ghi, ngày giao |
| Phụ huynh, học sinh | Bản tối giản đủ cho P3 (tên, SĐT, năm sinh, trường…); màn KH làm sau. Kiểm trùng SĐT dùng bảng phụ huynh |
| Lịch hẹn | Gắn với **đúng một** hồ sơ (lead, cơ hội, phiếu test), loại hoạt động (danh mục 16), ngày giờ, nội dung, người phụ trách, trạng thái Chưa làm / Hoàn thành / Huỷ, lý do huỷ (danh mục 34) + ghi chú, ai/lúc nào hoàn thành, huỷ, mở lại |
| Phiếu kiểm tra | Cơ hội, học sinh, môn, lớp (khối), hình thức (14), cấp độ đề (15), tên đề (chữ), ngày giờ test (bắt buộc), cơ sở test (mặc định cơ sở người tạo), phòng, giáo viên chấm, người tạo, cơ sở tạo (tự ghi, chỉ đọc), người phụ trách (mặc định người tạo), trạng thái Nháp / Đang test / Chờ giáo viên chấm / Hoàn thành / Huỷ, lý do huỷ (13) + ghi chú, kết quả (R-CRM-10: điểm 0–10 một số lẻ, nhận xét, trình độ đề xuất S/A/B/C, phân loại CB/NC, lớp đề xuất), người nhập kết quả (ghi lại ai nhập), lịch hẹn nhắc |

"Lịch hẹn kế tiếp" trên lead, cơ hội: **tự tính** (R-CRM-04), không là cột nhập tay.

---

## 3. Hàm nghiệp vụ (rpc)

Mỗi hàm: một giao dịch, kiểm quyền bên trong, lỗi có mã `HMT_…` + câu tiếng Việt, pgTAP cho trường hợp đúng và bị chặn (tên bài ghi luật tiếng Việt), ghi vào `docs/nghiep-vu/` (thêm file `tuyen-sinh.md`).

| Hàm (gợi ý) | Luật |
|---|---|
| Tạo / sửa lead; kiểm trùng SĐT với lead và phụ huynh | TS-03, TS-14; trả danh sách trùng để hiện K07c |
| Đổi giai đoạn lead | R-CRM-09 (tự do hai chiều; C4D chỉ hệ thống gắn) |
| Tạo cơ hội từ lead | R-CRM-01 (cảnh báo kèm mã cơ hội cũ, xác nhận lần hai); gắn C4D cho lead |
| Đổi giai đoạn cơ hội | R-CRM-02 (chỉ đi tới), R-CRM-03 (L5+ cần tên, năm sinh), R-CRM-12 (còn phiếu dang dở thì chặn L7/L8, nêu mã), R-CRM-14 (bỏ qua test cần lý do), R-CRM-13 (L6 không bấm tay), R-CRM-16 (L8 bắt L8A/B/C + xác nhận). Nhóm con L5 không chọn tay (R-CRM-15) |
| Tạo phiếu kiểm tra | R-CRM-05 (sửa 16/10 tối): cơ hội ≥ L5, ngày giờ bắt buộc, tự sinh lịch hẹn nhắc; nhiều phiếu một cơ hội |
| Đổi trạng thái phiếu: Bắt đầu test, Nộp bài, Hoàn thành, lùi bước | R-CRM-10, R-CRM-21. Hoàn thành cần: giáo viên chấm, điểm, nhận xét (không cần file đính kèm ở giai đoạn 1) |
| Huỷ phiếu | R-CRM-06 (sửa 16/10 tối): lý do danh mục 13, "Lý do khác" bắt ghi chú |
| Mở lại phiếu đã Huỷ về Nháp | R-CRM-10: bắt lý do |
| Tính lại nhóm con L5 và lên L6 | R-CRM-15 (thứ tự ưu tiên khi nhiều phiếu), R-CRM-13. Chạy sau **mọi** lần đổi trạng thái phiếu, cùng giao dịch |
| Đổi lịch phiếu | TS-15 chế độ Đổi lịch; cập nhật lịch hẹn nhắc |
| Lịch hẹn: tạo, dời, hoàn thành, huỷ, mở lại | R-CRM-04 (sửa 16/10 tối) |
| Giao người phụ trách (một hoặc nhiều bản ghi) | TS-05; quyền "Giao việc" (G) |
| Gộp trùng lead / cơ hội | R-CRM-22 |
| Nhập lead từ file | R-CRM-11 (giữ như bản cũ); TS-04: xem trước, báo dòng lỗi, dòng trùng SĐT, nhập cả lô một giao dịch hoặc bỏ dòng lỗi (Code đề xuất) |

Danh mục cần thêm bằng migration (04c): L5Q vào danh mục 11; hai lý do mới vào 13 ("Trung tâm không xếp được lịch test" nối L5Q, "Tạo phiếu sai" không nối); danh mục 34 "Lý do huỷ lịch hẹn". Khoá các nhóm con do hệ thống gắn: C4D, L5A, L5B, L5P, L6A (đã ghi ở TIEN-DO).

Tham số mới (Cài đặt, có mặc định, không viết cứng): giờ nhắc phiếu test mặc định (17:00 ngày trước; test trong 24 giờ tới thì nhắc trước 2 giờ).

---

## 4. Quyền

Dùng phân hệ có sẵn `LEAD`, `OPPORTUNITY`, `STUDENT_TEST` và phân hệ **Lịch hẹn** mới (PR 6e). Phạm vi theo ma trận quyền; Code không viết cứng vai trò, trừ hai chỗ luật nói rõ:
- Gộp trùng: chỉ Trưởng cơ sở và Admin (R-CRM-22). Gợi ý: quyền "Duyệt" (D) trên Lead/Cơ hội, Code nêu cách làm trong kế hoạch.
- Huỷ phiếu: không giới hạn vai trò (R-CRM-14), vẫn theo phạm vi xem.

---

## 5. Màn hình

Chỉ ghi chỗ cần nói rõ; còn lại làm đúng bản vẽ. Mọi màn dùng engine Filters / Group By / chip chung (Design ghi: tách file chung sau khi duyệt).

### Chung cho P3
- **Thanh giai đoạn:**
  - Lead: bấm đổi tự do; kiểu "Đổi ngay" có Hoàn tác 8 giây.
  - Cơ hội: bấm mở TS-09; không có Hoàn tác; L6 có ổ khoá ("Hệ thống tự đổi").
  - Phiếu test: chỉ đọc, đổi bằng nút.
- **Hoàn tác 8 giây:** có cho lịch hẹn và các bước tiến của phiếu test; **không** cho đổi giai đoạn cơ hội.
- **Nút trỏ sang phân hệ chưa làm** (Tạo báo giá, Tạo đơn hàng, smart button Phụ huynh / Học sinh / Báo giá / Đơn hàng, Lớp đề xuất, Gợi ý lớp): **hiện mờ**, rê chuột hiện "Sẽ có khi làm phân hệ <tên>". Smart button vẫn đếm đúng. Khi phân hệ kia xong thì bật, không đổi giao diện.
- **Smart button** (khi có đích):
  - Hiện số đếm, không ghi mã; số 0 thì mờ.
  - 1 bản ghi: mở thẳng bản ghi.
  - Nhiều bản ghi: mở danh sách K1 đã lọc sẵn theo bản ghi cha (chip "Cơ hội: CO000121").
- **Menu Hành động:**
  - Lead, Cơ hội: chỉ "Gộp trùng" (Trưởng cơ sở, Admin) và "Giao người phụ trách".
  - Phiếu: "Huỷ phiếu", "Đưa về Nháp" (khi Hoàn thành), "Lùi về…".
- **Lọc mặc định "Tuần này":** cho Lịch hẹn (3 kiểu xem) và Phiếu test (3 kiểu xem).
  - Lịch hẹn có dòng nhắc "Còn N lịch Quá hạn từ các tuần trước · Xem". Phiếu test có dải nhắc phiếu quá giờ.
  - Mở lại màn thì về "Tuần này". "Xoá lọc" bỏ hết.
- **Chip "của tôi":**
  - Lead, Cơ hội, Lịch hẹn: "Tôi phụ trách", bật sẵn.
  - Phiếu test: "Tôi tạo" / "Tôi phụ trách" (bật sẵn) / "Tôi chấm bài".
  - Cùng nhóm là HOẶC, khác nhóm là VÀ (R-CRM-07). Nhóm thời gian của phiếu test không còn "Chưa có lịch".
- **Bản ghi "Đã gộp":**
  - Danh sách: ẩn mặc định; Filters có "Trạng thái bản ghi: Đã gộp". Khi hiện thì dòng mờ, nhãn "Đã gộp · vào <mã>".
  - Kanban không hiện.
  - Mở ra: chỉ đọc (TS-10b).
- **Kanban Cơ hội (TS-07 K2):**
  - Chỉ kéo tới.
  - Kéo tới L5 trở lên khi thiếu học sinh: hiện TS-09d.
  - Kéo sang L6: không cho thả.
  - Kéo sang L7/L8: đi qua đúng kiểm tra của TS-09a/b.
  - Kéo sang L8: mở TS-09c.
- **Kanban Lead:** kéo tự do.
- **Thanh màu dưới tên cột:** xanh còn hạn, vàng hôm nay, đỏ quá hạn. Cột không có lịch hẹn thì ẩn thanh. Bấm khúc màu thì lọc cột. Thanh tự cập nhật khi kéo thẻ.

### TS-03, TS-06, TS-14
- Gõ xong SĐT là kiểm trùng; trùng thì hiện K07c, có hai nút "Gắn vào hồ sơ có sẵn" / "Vẫn tạo mới".
- Tạo cơ hội khi lead đã có cơ hội: hiện mã cơ hội cũ, xác nhận lần hai (R-CRM-01).

### TS-08 Cơ hội
- Nút "Tạo lịch Test": mờ ở L1–L4, rê chuột hiện "Chuyển cơ hội sang L5 trước".
- Tab "Kiểm tra đầu vào (n)" liệt kê mọi phiếu (TS-08b).
- Học sinh: bắt buộc từ L5 (R-CRM-03); khung báo lỗi hiện đúng câu trong bản vẽ.
- Không có ô Deadline, Stage Deadline.
- "Tạo báo giá", "Tạo đơn hàng": hiện mờ trong P3. Khi làm thật thì theo R-CRM-16, R-CRM-19, R-CRM-20.

### TS-09 (5 artboard)

| Artboard | Ca |
|---|---|
| TS-09 | Chuyển bình thường (L6A → L7). Sub-stage chọn được, không bắt buộc |
| TS-09a | Bị chặn vì phiếu dang dở: nêu mã + nút "Mở phiếu" |
| TS-09b | Bỏ qua test: bắt "Lý do bỏ qua test" (danh mục 33), "Khác" bắt ghi chú |
| TS-09c | Sang L8: bắt L8A/B/C + ô tick "Chuyển L8 không hoàn tác được" |
| TS-09d | Sang L5+ thiếu tên hoặc năm sinh học sinh: nút "Đi tới ô cần điền" |

Thứ tự kiểm khi bấm L7/L8: R-CRM-03 → R-CRM-12 → R-CRM-14 → (L8) R-CRM-16. Giao diện kiểm trước để hiện đúng hộp, **hàm DB kiểm lại tất cả**.

### TS-10 Gộp trùng
- Chọn bản giữ lại; xem trước lịch hẹn, ghi chú, phiếu test sẽ chuyển sang.
- Ô tick "Gộp không hoàn tác được".
- Gộp cơ hội bị chặn khi bản bị gộp có báo giá hoặc đơn (nêu mã; khi chưa có P5 thì luôn qua).

### TS-11, TS-13 Lịch hẹn
- Nút trên dòng / thẻ: Hoàn thành (một bấm), Dời (mở TS-13 chế độ Dời), Huỷ (hộp lý do danh mục 34), Mở lại (có xác nhận).
- Kanban TS-11c: 3 cột theo trạng thái.
  - Kéo sang Hoàn thành: hỏi kết quả. Kéo sang Huỷ: hỏi lý do. Kéo ra khỏi Hoàn thành/Huỷ: hỏi mở lại.
  - Hoàn thành ⇄ Huỷ không kéo thẳng.
- Ô "Gắn với" bắt buộc: chưa có thì nút Tạo mờ. Cột "Gắn với" là link.

### TS-15 Tạo phiếu / Đổi lịch
- Tên học sinh lấy từ cơ hội, khoá. **Khối (Lớp) chọn khi tạo phiếu, không lấy từ cơ hội** (cơ hội, học sinh chưa có khối; anh chốt 18/10); bản vẽ TS15 cho chọn (không khoá).
- Ngày test, giờ test **bắt buộc**, mở ra để trống, có chọn nhanh.
- Cơ sở test mặc định cơ sở người tạo. Người phụ trách bắt buộc, mặc định người tạo. Tên đề: ô chữ.
- Lịch hẹn nhắc tạo cùng phiếu: Gọi điện, giờ theo tham số mục 3; sửa tay thì không bị ghi đè; giờ nhắc phải trước giờ test.
- Chế độ Đổi lịch: cùng hộp, điền sẵn ngày giờ.

### TS-16 Phiếu test
- **Danh sách:** cột mặc định và cột ẩn đúng bản vẽ.
- **Kanban:** 4 cột + cột gập "Đã huỷ". Không kéo thả; đổi bằng nút trên thẻ. Phiếu Nháp quá giờ thì thẻ có nhãn đỏ "Quá giờ".
- **Calendar:**
  - Tuần (mặc định), Ngày (cột = phòng). Tháng: chưa vẽ, không làm.
  - Khối dài 60 phút.
  - Kéo khối: mở Đổi lịch, không đổi thẳng. Bấm ô trống: mở Tạo phiếu điền sẵn. Không có khay "Chưa có lịch".

### TS-17 Phiếu test
- **Nút theo trạng thái:** Nháp: Bắt đầu test, Đổi lịch → Đang test: Nộp bài → Chờ giáo viên chấm: ô kết quả + Hoàn thành.
- **Kết quả:** người phụ trách phiếu (hoặc người có quyền Sửa phiếu) nhập thay giáo viên; chọn tên giáo viên chấm; lịch sử ghi "nhập thay" kèm người nhập.
- **Nút Hoàn thành:** mờ đến khi đủ giáo viên chấm, điểm, nhận xét. Không có file đính kèm trong P3: bỏ ô và nút tải bài làm, đề, phiếu đánh giá.
- **Sửa:**
  - Nút Sửa luôn hiện.
  - Ở Nháp/Đang test chỉ mở Người phụ trách, Cơ sở test.
  - Sau Hoàn thành vẫn sửa được, mỗi lần ghi lịch sử (R-CRM-21).
- **Đưa về Nháp, Huỷ, mở lại phiếu Huỷ:**
  - Phiếu Hoàn thành đưa về Nháp: bắt lý do.
  - Huỷ: bắt lý do danh mục 13.
  - Phiếu Huỷ mở lại về Nháp: bắt lý do (R-CRM-10).
- **Smart bar 6 nút:** Cơ hội gốc · Học sinh · Lead · Lịch hẹn · Báo giá · Đơn hàng (Học sinh, Báo giá, Đơn hàng mờ trong P3).
- **Lớp đề xuất, Gợi ý lớp:** mờ trong P3.

---

## 6. Kiểm thử và bàn giao

- pgTAP: mọi luật ở mục 3; RLS mỗi vai trò đọc/ghi trong và ngoài phạm vi cơ sở.
- Playwright 1440×900 (CRM ưu tiên máy tính) cho: tạo lead trùng SĐT, tạo cơ hội, chuyển L5 thiếu học sinh, tạo phiếu, Bắt đầu → Nộp bài → Hoàn thành → cơ hội lên L6A, chuyển L7 bị chặn / bỏ qua test, chuyển L8, huỷ / mở lại lịch hẹn, gộp trùng.
- Ảnh so sánh từng màn với PNG trong gói (`docs/so-sanh/`).
- Dữ liệu giả trong `seed.sql`; không dữ liệu thật.

### Gợi ý chia PR (Code chốt trong kế hoạch)
1. **P3a tài liệu:** chép 04c vào `docs/spec/04`, `06`; sửa R-CRM-11 (mục 7); sửa `docs/design/luat-cho-thiet-ke.md` (lịch hẹn "Chưa làm", phiếu bỏ "Từ chối", ngày giờ bắt buộc) và `ban-do-man-hinh.md` (TS-18, TS-19 bỏ; TS-17 bỏ Từ chối; TS-12 vào K09b); đưa đặc tả này vào `docs/design/dac-ta/P3-tuyen-sinh.md`; đưa gói thiết kế vào `design/hmt-p3/`.
2. **P3b dữ liệu và hàm:** bảng, hàm, danh mục mới, pgTAP.
3. **P3c** Lead + Lịch hẹn (TS-01…06, 11, 13, 14).
4. **P3d** Cơ hội (TS-07, 08, 09).
5. **P3e** Phiếu test (TS-15, 16, 17).
6. **P3f** Gộp trùng + Nhập file (TS-10, TS-04).

---

## 7. Đã chốt với anh Trường (16/10 tối)

1. Nút trỏ sang phân hệ chưa làm: hiện mờ, rê chuột có gợi ý.
2. Kết quả test ở giai đoạn 1: người phụ trách phiếu nhập thay giáo viên. Màn chấm test trong cổng giáo viên (GV-15) làm sau.
3. Chưa có đính kèm file ở P3.
4. Bỏ ô Deadline, Stage Deadline.

**Luật cần sửa theo câu 2 (chờ anh nói "OK ĐƯA VÀO LUẬT" mới đưa vào spec):**
- R-CRM-11 sửa thành: *"Giáo viên chấm kiểm tra đầu vào trong cổng giáo viên (bản tối giản chỉ gồm mục chấm test, làm sau). Trong lúc chưa có cổng này, người phụ trách phiếu nhập kết quả thay trong CRM; lịch sử ghi rõ 'nhập thay' và người nhập. Giữ chiến dịch marketing và nhập lead từ file như bản cũ."*

Code vẫn làm PR P3a như mô tả, phần R-CRM-11 chỉ sửa sau khi có OK ĐƯA VÀO LUẬT.
