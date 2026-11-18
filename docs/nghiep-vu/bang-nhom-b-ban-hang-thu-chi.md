# Bảng nhóm B: sửa gì, ở đâu (gói canvas Báo giá, Đơn hàng, Phiếu thu v146 và bổ sung v2)

Gửi anh duyệt trước khi làm migration (05/11/2026). Nguồn: `design/hmt-canvas-9933`, `design/hmt-canvas-abea/GHI_CHU_CHO_CODE.md`, `docs/nghiep-vu/doi-chieu-canvas-ban-hang-v146.md`. Quy tắc: canvas vênh luật thì **làm theo luật**; quy tắc voucher và ưu đãi linh hoạt chưa vào luật nên chỗ khác luật em hỏi anh qua Chat (cuối tài liệu).
Giờ = thang ước lượng em dùng từ đầu (đã gồm pgTAP, Playwright, tài liệu). Cột "(e)" đã gồm giờ làm bản in hoặc màn nếu có.

## Thứ tự anh chốt (05/11) và tách mốc

1. **Phiếu thu B2 tối thiểu (mục 7): xong trước 12/11**, vì CS5 thu học phí bằng hệ thống đúng 12/11. Là đường găng.
2. Sau B2: mục 1 (vượt trần chỉ cảnh báo), 3 (chip), 2 (BH03_in), 4 (ưu đãi linh hoạt), nhóm A, rồi mục 6 tối thiểu (nạp Số dư dạng sổ chỉ đọc).
3. **Sau 12/11, trước 28/11:** Thu nợ đầu kỳ (mục 8) và "Dùng số dư".
4. **Voucher (mục 5): hoãn sau 12/11**, làm khi anh chốt xong 4 câu hỏi.
5. **Ưu đãi linh hoạt: hạn mức mặc định 5%, sửa được trong Cài đặt (tham số `flexible_discount_max_percent`), có ghi nhật ký người nhập.**

Lưu ý thứ tự trong tuần: T4c (nạp Cơ hội, cần cho mốc nạp 10/11) làm trước B2.

| # | Việc | Cần migration | Giờ | Mốc | Nếu hoãn thì nhân viên CS5 không làm được gì |
|---|---|---|---|---|---|
| 7a | **Phiếu thu B2 tối thiểu** (mục 7) | Có (lớn) | 47 đến 60 | **trước 12/11** | **Không thu tiền học phí bằng hệ thống** |
| 1 | Vượt trần chỉ cảnh báo | Có (nhỏ) | 3 đến 5 | trước 12/11 | Vẫn lên đơn, duyệt được; quản lý phải tích ô "đồng ý vượt trần" (luật cũ) |
| 3 | Chiết khấu chip | Không | 6 đến 8 | trước 12/11 | Vẫn chọn chính sách bằng hộp có sẵn, chưa theo kiểu chip mới |
| 2 | Bản in BH03_in (kèm che SĐT chỉ ở bản in) | Không | 4,5 đến 6,5 | trước 12/11 | Vẫn in bản hiện tại, chưa đúng mẫu chốt |
| 4 | Ưu đãi linh hoạt (mặc định 5%) | Có | 8 đến 10 | trước 12/11 | Không giảm giá theo thương lượng ngoài các chính sách có sẵn |
| A | Nhóm A (bỏ hai ô thanh toán khỏi Đơn hàng, 24 khung) | Không | 3 đến 4 | trước 12/11 | Đơn hàng còn hai ô thừa (Hình thức thanh toán, Cơ sở thu tiền) chồng với phiếu thu |
| 6a | Nạp Số dư, sổ chỉ đọc (mục 6 tối thiểu) | Có | 8 đến 10 | trước 12/11 | Số dư cũ của phụ huynh không có trong hệ thống, phải ghi tay |
| 8 | Thu nợ đầu kỳ và "Dùng số dư" | Có | 10 đến 14 | sau 12/11, trước 28/11 | Không thu nợ cũ qua hệ thống; kế toán đối soát nợ cũ bằng Excel |
| 5 | Voucher | Có (lớn) | 16 đến 22 | sau 12/11, khi anh chốt 4 câu hỏi | Không bán được đơn có voucher; tính ngoài hệ thống hoặc dùng chính sách khác |

Tổng trước 12/11 (B2, 1, 3, 2, 4, A, 6a): khoảng 80 đến 103 giờ-ước. Công suất đã đo: khoảng 30 giờ-ước mỗi ngày làm việc liên tục (05/11 xong khoảng 30 giờ-ước trong 9 giờ thật), nên trước 12/11 làm được khoảng 150 giờ-ước kể cả T4c, nạp 10/11 và chờ CI: **kịp**, nhưng B2 là việc nhiều rủi ro nhất (nhiều luật, nhiều màn).

## Giờ-ước dự kiến từng ngày (06/11 đến 12/11)

| Ngày | Việc | Giờ-ước |
|---|---|---|
| 05/11 (tối) | Nút Đặt lại mật khẩu (xong, chờ CI), bắt đầu T4c | 3 |
| 06/11 | T4c nạp Cơ hội (8); B2 thiết kế bảng, mã phiếu, ghi luật Đ258 và công nợ đầu kỳ vào `docs/spec` (6) | 14 |
| 07/11 | B2 DB: migration phiếu thu, khoản tiền vào, hàm tạo, gửi, duyệt, huỷ, chia tiền về dòng, pgTAP | 18 |
| 08/11 | B2 giao diện: TC-03 tạo từ đơn, TC-02 bản ghi, TC-01 danh sách | 18 |
| 09/11 | B2 giao diện: TC-04 hàng chờ kế toán, TC-05 duyệt, từ chối, TC-06 huỷ, TC-07 in biên nhận; bộ chuyển xlsx sang CSV | 18 |
| 10/11 | Nạp thật (theo dõi, sửa lỗi); sửa B2 theo kiểm thử e2e; mục 1 vượt trần | 12 |
| 11/11 | Mục 3 chip (7), mục 2 BH03_in (5), mục 4 ưu đãi linh hoạt (9) | 21 |
| 12/11 | Nhóm A (4), nạp Số dư sổ chỉ đọc (9), dự phòng sửa lỗi (8) | 21 |

Câu hỏi nghiệp vụ Đào tạo, Cổng giáo viên, Aftersale gửi anh qua Chat (không chặn B2); bảng này không tính giờ viết câu hỏi (khoảng 2 giờ, làm lúc chờ CI).

## B2 tối thiểu gồm gì, để sau 12/11 là gì

**Làm trước 12/11 (tối thiểu để CS5 thu học phí):**
- DB: bảng phiếu thu (Nháp, Đã gửi, Chờ kế toán, Đã duyệt; Huỷ) và khoản tiền vào (`KTV`); mã nghiệp vụ theo chuẩn mã; hàm tạo từ đơn (R-TIEN-02), gửi, kế toán duyệt hoặc từ chối, huỷ phiếu chưa duyệt; **hai bước duyệt** (R-V2-14: người lập gửi, quản lý trực tiếp hoặc Trưởng cơ sở duyệt, rồi kế toán duyệt); chia tiền về các dòng của đơn theo tỉ lệ thành tiền (R-TIEN-22) và "cấn vào dòng" (R-TIEN-23); số tiền đã thu và còn lại của đơn; các trường theo Đ258 (hình thức thanh toán từ danh mục, **Cơ sở thu tiền** mặc định cơ sở người lập, nhắc nhẹ khi khác cơ sở đơn, **Người nhận tiền**); quyền theo ma trận; nhật ký thao tác; RLS và chỉ mục; pgTAP cho từng luật.
- Giao diện: TC-03 tạo phiếu thu từ đơn (hộp), TC-02 bản ghi phiếu thu, TC-01 danh sách phiếu thu, TC-04 hàng chờ kế toán, TC-05 duyệt hoặc từ chối, TC-06 huỷ, TC-07 bản in biên nhận A5. Hiển thị đã thu, còn lại trên bản ghi đơn hàng BH-05.
- Làm theo luật khi canvas vênh: ô "Mã giao dịch" không bắt buộc với tiền mặt; danh sách hình thức đọc từ danh mục, không gõ sẵn.

**Để sau 12/11 (không chặn thu tiền):**
- Cấp giờ học theo tiền đã thu (R-TIEN-21, 24) và **tạo ghi danh khi đủ cọc** (R-TIEN-20): cần bảng lớp, ghi danh của Đào tạo (chưa có). Trước đó nhân viên ghi danh bằng tay sau khi phiếu thu duyệt; hệ thống chỉ ghi tiền.
- Sổ thu tiền TC-08, đảo khoản TC-09 (R-TIEN-26), công nợ TC-13, đối soát TC-15, phiếu chi và hoàn tiền TC-10 đến TC-12, số dư TC-14, "Dùng số dư", Thu nợ đầu kỳ.
- Cảnh báo "đã qua N buổi" khi duyệt sau ngày vào lớp (R-TIEN-27): cần buổi học.

## 1. Vượt trần chỉ cảnh báo
- **(a) Hiện tại:** luật R-V2-11 (04/11, chốt, hoãn): trần 20% chỉ cảnh báo ở mọi bước. DB: `app.price_line` đã tính `over_cap` (không chặn lưu) nhưng đặt `needs_acknowledgement = true` khi vượt trần; `app.order_approve_core` (migration 063) **chặn duyệt nếu chưa tích đồng ý** (`p_acknowledged`); `submit_order` có `p_acknowledged` cho đường tự duyệt. Giao diện: ô tích "Đồng ý chiết khấu vượt trần" ở BH-07 duyệt, nhãn "Vượt trần 20%, cần duyệt" ở BH-02, chữ "Chiết khấu cộng dồn không quá 20%" ở BH-05, BH-08, BH-09, TC-03.
- **(b) Canvas đòi:** canvas vẫn có ô tích và nhãn "cần duyệt" (vênh luật, ghi chú mục 1): làm theo luật.
- **(c) Khác ở đâu:** cần bỏ yêu cầu tích đồng ý khi duyệt và đổi nhãn thành cảnh báo màu vàng "Vượt trần chiết khấu 20% (chỉ cảnh báo)".
- **(d) Migration:** có, nhỏ: sửa `order_approve_core`, `submit_order` bỏ chặn; giữ cột `needs_acknowledgement` và `acknowledged` để không phá dữ liệu cũ (chỉ dùng cho cảnh báo). Cập nhật pgTAP 037, 048, 054, 063 và Playwright BH-07.
- **(e) Giờ:** 3 đến 5.

## 2. Bản in báo giá BH03_in
- **(a) Hiện tại:** trang in `QuotationPrintPage` (A4) có cột chiết khấu hiện tên chính sách và số tiền giảm, dòng quà tặng in "1 cuốn", "1 giờ".
- **(b) Canvas đòi (quyết định anh, thread 9233dbe0):** cột Chiết khấu chỉ in **%** (không có thì 0%); số tiền giảm ở cột **Giảm** riêng căn phải, không dấu "−"; dòng quà tặng, voucher: cột Giờ mua in "—"; voucher một dòng riêng, số âm; bố cục cột cố định (số căn phải, chữ căn trái).
- **Quy tắc che số điện thoại phụ huynh (anh chốt 05/11):** **chỉ che ở bản in BH03_in**; màn xem báo giá trên hệ thống và mọi màn khác vẫn hiện đầy đủ, DB không đổi. Kiểu che: giữ 4 số đầu và 3 số cuối, che 3 số giữa, ví dụ `0912 *** 621`.
  - **Hiện trạng code:** hàm `maskPhone` ở `src/pages/bao-gia/quotePrint.ts` đã che đúng kiểu này (`0912 *** 345`) và chỉ trang in `QuotationPrintPage.tsx` dùng nó; màn xem báo giá không che. Nên phần che **đã có**; việc còn lại là giữ nguyên và thêm bài kiểm xác nhận màn xem báo giá không che (`quotePrint.test.ts`, `e2e/bao-gia.spec.ts`), khoảng 0,5 giờ.
  - **File liên quan:** `src/pages/bao-gia/quotePrint.ts`, `src/pages/bao-gia/QuotationPrintPage.tsx`, `src/pages/bao-gia/quotePrint.test.ts`.
- **(c) Khác ở đâu:** đổi cột và căn lề; phần voucher chờ mục 5.
- **(d) Migration:** không (dữ liệu đã có đủ: phần trăm và tiền giảm từng dòng).
- **(e) Giờ:** 4 đến 6 (không gồm voucher), cộng khoảng 0,5 giờ bài kiểm che số.

## 3. Chiết khấu chip
- **(a) Hiện tại:** BH-02 sửa Nháp đã có hộp chọn chính sách (chọn nhiều, tối đa một chính sách tặng giờ), chip chính sách có ô nhập %, giờ tặng, "Tổng chiết khấu"; DB `price_apply_discounts` cộng dồn, `price_line` trả `total_discount_percent`.
- **(b) Canvas đòi:** cột "Chiết khấu": chip chọn nhiều, "+ Thêm", ✕ trên chip, cột "Tổng %" cộng dồn; áp dụng cho Đơn hàng (BH-05) và Báo giá (BH-02); 15 khung BH-02 và 16 khung BH-05 còn kiểu cũ (nút "+ Chính sách", cột "Loại chiết khấu").
- **(c) Khác ở đâu:** BH-02 gần như đã có; BH-05 (bảng dòng đơn) chưa dùng chip; cần thống nhất hai màn dùng cùng thành phần.
- **(d) Migration:** không.
- **(e) Giờ:** 6 đến 8.

## 4. Ưu đãi linh hoạt
- **(a) Hiện tại:** chính sách chiết khấu là cấu hình có sẵn (`discount_policy`: mức tối đa, cần duyệt, hiệu lực, nhóm gói, cơ sở). Nhân viên không nhập % tay.
- **(b) Canvas và anh chốt trong bình luận (chưa vào luật):** chip "Ưu đãi linh hoạt": nhân viên nhập % tay, **không ghi % trong ngoặc, không cần lý do**; hạn mức do anh cấu hình sau; ai có quyền lên đơn đều dùng được; tính vào trần 20%.
- **(c) Khác ở đâu:** là chính sách đặc biệt với % do người nhập; cần hạn mức tối đa (chưa có).
- **(d) Migration:** có: một chính sách hệ thống kiểu PERCENT với mức tối đa đọc từ tham số Cài đặt `flexible_discount_max_percent`; cho `price_apply_discounts` nhận % nhập tay trong giới hạn.
- **(e) Giờ:** 8 đến 10.
- **Anh đã chốt (05/11):** hạn mức mặc định **5%**, sửa được trong Cài đặt (`flexible_discount_max_percent`); **có ghi nhật ký người nhập** (ai nhập bao nhiêu phần trăm, trên dòng nào, ghi chung nhật ký đơn).

## 5. Voucher (hoãn sau 12/11, chờ anh chốt 4 câu hỏi)
- **(a) Hiện tại:** không có. Đơn có các loại dòng: học, quà tặng. Tiền của đơn nhiều dòng chia về các dòng theo tỉ lệ thành tiền (R-TIEN-22); hoàn tiền theo dòng học (R-TIEN-28, 31).
- **(b) Canvas và anh chốt (chưa vào luật):** voucher là **một dòng đơn loại "Voucher"**, gắn một em, số lượng 1, đơn giá và thành tiền **âm**; bên trong **chia về các dòng học của em đó theo tỉ lệ thành tiền** (làm tròn, dòng cuối nhận phần dư), lưu lúc tạo đơn, màn chỉ hiện một dòng; hoàn tiền theo dòng học, **voucher không hoàn**; ghi nhận **giảm trừ doanh thu**; trên hoá đơn là một dòng giảm giá riêng. Tính: % trên giá niêm yết trước, rồi trừ voucher. Đơn chỉ có voucher không lưu được ("Thêm ít nhất một dòng học"); tổng đơn không được âm.
- **(c) Khác ở đâu:** thêm loại dòng; đổi cách tính tổng (`order_refresh_totals`, `price_line`); thêm bảng chia voucher về dòng; ảnh hưởng hoàn tiền, báo cáo doanh thu.
- **(d) Migration:** có, lớn (loại dòng, bảng chia, tính tổng, kiểm tra, bản in, hoá đơn).
- **(e) Giờ:** 16 đến 22.
- **Câu hỏi cho Chat trước khi làm:**
  1. "Voucher không hoàn" nghĩa là tiền hoàn tính trên **giá trước voucher** hay **giá sau khi đã trừ phần voucher đã chia về dòng**? (Khác R-TIEN-31: hoàn = giờ hoàn × giá sau chiết khấu − phí.)
  2. Voucher có mã, hạn dùng, giá trị tối đa không? Ai được thêm voucher (mọi người lên đơn, hay quyền riêng)?
  3. "Giảm trừ doanh thu" ghi ở đâu (chưa có báo cáo doanh thu)? Đề xuất: ghi cột riêng trên dòng đơn, báo cáo đọc sau.
  4. Voucher có tính vào trần 20% không (canvas ghi "phần voucher chia về dòng" tính vào trần)?

## 6. Nạp Số dư (09_SODU) và công nợ đầu kỳ
- **(a) Hiện tại:** R-TIEN-33: số dư khách hàng của phụ huynh, sổ chỉ thêm dòng, "Dùng số dư" như một khoản tiền vào của đơn mới. **DB chưa có bảng số dư.** Anh chốt 04/11: công nợ đầu kỳ khoá theo phụ huynh, mỗi em một dòng sổ, nợ ghi âm, thừa ghi dương, không tự bù trừ, mọi dòng có `legacy_ref`.
- **(b) Canvas:** TC-14 (số dư khách hàng, mức C); 4 khung Thu nợ đầu kỳ ở mục 8.
- **(c) Khác ở đâu:** cần bảng sổ số dư và hàm nạp; chưa có màn.
- **(d) Migration:** có: bảng `customer_balance_entry` (phụ huynh, em, số tiền ±, loại: nợ đầu kỳ, thừa đầu kỳ, từ chuyển phí, dùng; `legacy_ref`; chỉ thêm), hàm nạp `import_balance`, thêm loại nạp vào màn Nhập.
- **(e) Giờ:** 8 đến 10 cho sổ và nạp (tối thiểu cho 12/11: bảng, nạp, màn xem theo phụ huynh); "Dùng số dư" làm cùng phiếu thu (mục 7).

## 7. Phiếu thu B2 (nền tảng)
- **(a) Hiện tại:** chưa có bảng phiếu thu, khoản tiền vào (`KTV`). Luật đã có: R-TIEN-01 đến 09, 20 đến 27, R-V2-14, R-V2-15; đã chốt giữ Đ258 (hình thức thanh toán, **Cơ sở thu tiền** và **Người nhận tiền** ở phiếu thu, mặc định cơ sở người lập, khác cơ sở đơn thì nhắc nhẹ).
- **(b) Canvas:** TC-01 đến TC-05, TC-07, TC02_* (Nháp, Đã gửi, Chờ kế toán, Đã duyệt; Huỷ), TC03 (tạo từ đơn).
- **(c) Khác ở đâu:** toàn bộ phân hệ mới: bảng, hàm tạo/gửi/duyệt/huỷ, chia tiền về dòng (R-TIEN-21 đến 23), cấp giờ theo tiền đã thu, tạo ghi danh khi đủ cọc, hai bước duyệt.
- **(d) Migration:** có, nhiều (4 đến 6 migration).
- **(e) Giờ:** phần tối thiểu trước 12/11: 47 đến 60 (DB 25 đến 32, giao diện 22 đến 28); phần còn lại sau 12/11 ước thêm 20 đến 30.
- Ghi luật Đ258 và công nợ đầu kỳ vào `docs/spec/04` cùng PR này (đã chốt, chưa ghi).

## 8. Thu nợ đầu kỳ
- **(a) Hiện tại:** R-V2-15 (chốt 04/11): phiếu thu loại "Thu nợ đầu kỳ": CSKH tạo, **kế toán duyệt, không qua quản lý**, không cần đơn, số tiền không vượt nợ còn lại **của em đó**; duyệt xong ghi khoản tiền vào và giảm nợ đầu kỳ. Phiếu gắn phụ huynh, luôn chọn em.
- **(b) Canvas (`design/hmt-canvas-abea`):** `TC02_no_dau_ky_tao` (Nháp), `_cho_kt`, `_da_duyet`, `_loi_vuot_no`; nợ từng em, ô Em bắt buộc; luồng Nháp, Chờ kế toán, Đã duyệt. Vênh luật: ô "Mã giao dịch" bắt buộc kể cả tiền mặt; danh sách hình thức gõ sẵn (Chuyển khoản, Tiền mặt, Quẹt thẻ): **làm theo luật phiếu thu và danh mục cấu hình**, không theo khung.
- **(c) Khác ở đâu:** phiếu loại mới không có đơn; kiểm số tiền theo nợ còn lại của em; ghi sổ số dư (mục 6).
- **(d) Migration:** có.
- **(e) Giờ:** 10 đến 14, **sau** mục 7 và mục 6.

## Câu hỏi còn lại cần anh trả lời
1. Bốn câu về voucher ở mục 5 (khi anh sẵn sàng; voucher đã hoãn sau 12/11).
2. Phiếu thu B2: người lập phiếu thu là ai (đề xuất: nhân viên Sale hoặc CSKH đã lập đơn) và bước quản lý duyệt phiếu thu theo quản lý trực tiếp như đơn hàng (R-V2-12)? Em đang theo R-V2-14: người lập gửi, quản lý duyệt, kế toán duyệt, trừ Thu nợ đầu kỳ (không qua quản lý).

## Cụm Thu tiền: TC-08 Khoản tiền vào, TC-13 Công nợ (migration 122)

Chỉ đọc. Luật: R-TIEN-01, R-TIEN-07, R-TIEN-26. Đảo khoản (TC-09), Xuất file chưa làm.

| Hàm                                                  | Ai                                                          | Việc                                                                                                                                                                                                                  |
| ---------------------------------------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `list_money_in(bộ lọc, sắp xếp, limit, offset)`      | Đối soát kế toán · Xem (Kế toán, Admin: mọi cơ sở; Trưởng cơ sở: cơ sở mình) | Sổ khoản tiền vào: tìm mã khoản, phiếu, đơn, phụ huynh, SĐT; lọc cơ sở, loại (thu, đảo), khoảng ngày ghi sổ; kết quả có tổng số tiền theo bộ lọc |
| `list_receivables(bộ lọc, sắp xếp, limit, offset)`   | Đơn hàng · Xem (Kế toán, Admin: mọi cơ sở; Trưởng cơ sở, Sale, CSKH: cơ sở mình) | Mỗi dòng là một đợt còn nợ của đơn Đã duyệt; tình trạng Quá hạn, Sắp đến hạn, Chưa đến hạn; lọc cơ sở, sale lập đơn, hạn đóng; kết quả có tổng còn nợ |

Cách tính «đã đóng» của đợt (quy tắc hiển thị, chưa vào luật): tiền đã vào ròng của đơn (khoản đảo đã trừ) lấp lần lượt từ đợt 1; đợt đóng đủ thì không hiện. Tham số `debt_due_soon_days` (mặc định 3 ngày) quyết định Sắp đến hạn. Không chặn học (R-TIEN-07).
