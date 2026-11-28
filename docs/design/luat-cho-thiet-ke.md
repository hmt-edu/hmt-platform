# HMT Platform: luật nghiệp vụ cho người thiết kế

> Ghi chú của repo (12/10/2026): chép nguyên từ `HMT_LUAT_CHO_THIET_KE.md` của anh Trường. Đây là bản rút gọn cho người vẽ giao diện; **chỗ nào khác `docs/spec/04-luat-nghiep-vu.md`, `docs/spec/02-chuan-ma-va-danh-muc.md` thì spec đúng** (ví dụ mục 2 còn mã gói có hình thức, mục 4 chưa có "Đã xếp lớp"). Dòng "Admin làm được mọi việc, kể cả việc chỉ dành cho Kế toán" ở mục 9 đã được anh chốt lại: xem R-HT-01 trong spec 04. `HMT_DANH_MUC_VA_THAM_SO.md` = `docs/spec/06-danh-muc-va-tham-so.md`. Bảng mã `S02-*`, `S03-*`: [ma-luat-S02-S03.md](ma-luat-S02-S03.md).

Bản rút gọn của luật nghiệp vụ (file 04), chuẩn mã (file 02) và đặc tả nền tảng (file 03), viết cho người vẽ giao diện. Đây là nghiệp vụ đã chốt: **vẽ đúng như ghi, không tự thêm nghiệp vụ**. Chỗ nào không có ở đây thì ghi vào "Câu hỏi mở" trong manifest, không đoán.

Mã trong ngoặc (R-…) là mã luật, để đối chiếu với cột "Mã luật" của bản đồ màn hình.

---

## 1. Người dùng và phạm vi

| Vai trò | Viết tắt | Cổng | Thấy dữ liệu |
|---|---|---|---|
| Admin (Ban giám đốc, IT) | AD | CRM | Toàn hệ thống |
| Trưởng cơ sở | BM | CRM | Cơ sở mình; là người duyệt |
| Tuyển sinh | SA | CRM | Cơ sở mình |
| Chăm sóc khách hàng, vận hành lớp | CS | CRM | Cơ sở mình |
| Kế toán | KT | CRM | Toàn hệ thống |
| Giáo viên, trợ giảng | GV, TG | Giáo viên | Chỉ lớp, buổi được phân công. Không vào cổng CRM |
| Học sinh | HS | Học tập | Chính mình |
| Phụ huynh | PH | Học tập (giai đoạn 4) | Các con của mình |

- Mỗi nhân viên thuộc **đúng một cơ sở**. Admin và Kế toán có ô **chọn cơ sở** trên thanh trên, với lựa chọn "Tất cả cơ sở".
- Người có nhiều vai trò (vừa nhân viên vừa giáo viên) chọn cổng sau đăng nhập và đổi cổng từ menu tài khoản.
- Menu chỉ hiện phân hệ vai trò được dùng. Mở link ngoài quyền thì hiện màn "Không có quyền", không lộ dữ liệu.
- **Trưởng cơ sở không duyệt tiền.** Phiếu thu, đảo khoản, phiếu chi do Kế toán hoặc Admin hệ thống duyệt.

### Cơ sở
| Mã | Tên | Ghi chú |
|---|---|---|
| CS1 | Nguyễn Chí Thanh | Cơ sở học |
| CS2 | Đỗ Quang | Cơ sở học |
| CS3 | Hội sở | Văn phòng: **không có phòng học, lớp, học sinh**. Không bao giờ xuất hiện trong ô chọn cơ sở của lớp, phòng, học sinh |
| CS4 | Hà Đông | Cơ sở học |
| CS5 | Mỹ Đình | Cơ sở học |

Giá học như nhau ở mọi cơ sở.

## 2. Mã và cách hiển thị

| Đối tượng | Mẫu dùng trong dữ liệu mẫu |
|---|---|
| Học sinh | `HS000123` |
| Phụ huynh | `PH000045` |
| Nhân viên | `NV0012` |
| Giáo viên, trợ giảng | `GV2007`, `TG8002` |
| Lớp chung | `CS5-2627-TOAN-K08-CB-A-001`; tên ngắn cũ `8A1` hiện kèm làm tham chiếu |
| Lớp riêng | `CS2-2627-TOAN-K09-LR-014` (không có trình độ) |
| Lớp Đại số, Hình học | `CS5-2627-DAI-K08-CB-A-001`, `CS5-2627-HINH-K08-CB-A-001` |
| Khung chương trình | `TOAN-K03-CB-2627`; bài học `TOAN-K03-CB-2627-B05` |
| Gói bán | `LC-TOAN-K09-OFF`, `HRD-TOAN-K09-OFF` |
| Chứng từ | Báo giá `BG-CS1-2610-0001`, đơn `DH-CS1-2610-0001`, phiếu thu `PT-…`, phiếu chi `PC-…`, đề nghị `DN-…`, khiếu nại `KN-…` |
| Buổi học | Không có mã. Hiển thị `8A1 · Buổi 12 · 15/08/2026` (R-BUOI-08) |

Quy ước khác:
- **Mã cũ** trên Google Sheet tìm kiếm được và hiện nhỏ dưới mã mới.
- **Tiền:** `9.504.000 đ`. **Giờ học:** số thập phân, ví dụ `1,5 giờ`. **Ngày:** `15/08/2026`. **Giờ:** 24 giờ, `18:30`.
- **Môn:** TOAN, DAI, HINH, LY, HOA, VAN, ANH, KHTN, TRUNG, SAT. **Khối:** K02–K12, hiển thị "Lớp 8".
- **Phân loại lớp:** CB cơ bản, NC nâng cao, LR lớp riêng. **Trình độ:** S, A, B, C (S cao nhất). **Hình thức:** Offline, Online. Hình thức thuộc **ghi danh**, không thuộc lớp: lớp OMO có cả hai.
- **Dữ liệu mẫu phải là dữ liệu giả.** Tên Việt Nam tự đặt, số điện thoại dạng `09xx xxx xxx` không có thật. Không dùng tên, số điện thoại học sinh thật.

## 3. Không có nút "Tạo mới" tay (R-TIEN-02)
Báo giá, đơn hàng, phiếu thu, phiếu tái tục và ghi danh **chỉ sinh từ luồng**:
- Cơ hội sinh ra báo giá hoặc đơn.
- Đơn sinh ra phiếu thu.
- Phiếu thu được duyệt sinh ra khoản tiền vào, rồi ghi danh.
- Quỹ giờ chạm ngưỡng sinh ra phiếu tái tục; có thêm nút "Tạo phiếu tái tục thủ công" trên ghi danh.

Danh sách của các đối tượng này **không có nút Tạo**.

## 4. Trạng thái từng đối tượng
Thanh trạng thái đặt trên đầu bản ghi. Bước nào chỉ đi tới thì không có nút lùi. Hành động bị chặn thì hiện hộp thoại liệt kê lý do, không chỉ làm mờ nút.

| Đối tượng | Các bước (tên hiển thị) | Ai bấm, ghi chú |
|---|---|---|
| Lead | C1 Data mới · C2 Chưa liên hệ được · C3 Không có nhu cầu · C4 Khách hàng tiềm năng; mỗi bước có nhóm con (ví dụ C2A Không nghe máy, C3H Không nghe máy nhiều lần, C4C Đủ điều kiện tạo cơ hội) | SA, CS. Lead sinh được nhiều cơ hội (R-CRM-01) |
| Cơ hội | L1 Khách hàng mới · L2 Chưa liên hệ được · L3 Không có nhu cầu · L4 Khách hàng tiềm năng · L5 Đồng ý tham gia test · L6 Đã tham gia test · L7 Tư vấn · L8 Đăng ký học; có nhóm con | **Chỉ đi tới, không lùi** (R-CRM-02). Từ L5 bắt buộc có tên và năm sinh học sinh (R-CRM-03). Huỷ test thì về nhóm con L5C–L5Q (R-CRM-15) |
| Lịch hẹn | Chưa làm · Hoàn thành · Huỷ | Hoàn thành bấm một lần. Huỷ chọn lý do từ danh mục 34. Mở lại được, có xác nhận. Không đổi giai đoạn, không tạo việc, không gửi thông báo. "Lịch hẹn kế tiếp" trên lead, cơ hội do hệ thống tự tính (R-CRM-04) |
| Phiếu kiểm tra đầu vào | Nháp · Đang test · Chờ giáo viên chấm · Hoàn thành; nhánh Huỷ (không còn Từ chối); đưa về Nháp được (bắt buộc lý do) | Tạo từ cơ hội ở L5 trở đi, **ngày giờ test bắt buộc** (R-CRM-05). Huỷ bắt buộc chọn lý do (R-CRM-06). Có ngày giờ test thì tự sinh lịch hẹn nhắc |
| Báo giá | Nháp · Đã gửi · Đã chuyển đơn · Từ chối | Hạn hiệu lực mặc định 14 ngày, **tính từ ngày bấm Gửi** (Nháp để trống). Quá hạn chỉ hiện nhãn "Đã quá hạn N ngày", không đổi trạng thái, không chặn chuyển đơn; không còn trạng thái Hết hạn và nút "Tạo lại" (R-TIEN-05). Một báo giá tạo nhiều đơn, mỗi đơn lấy một số dòng; "Đã chuyển đơn" khi mọi dòng nằm trong đơn đang sống (R-TIEN-02). Mỗi dòng ghi một học sinh, chọn trong danh sách em của cơ hội (mặc định em đầu; không có em mới trên dòng và không có nút "Thêm em"; báo giá nháp cho phép em chưa đủ họ tên hoặc năm sinh) (R-TIEN-35, R-CRM-23), giờ mua và giờ tặng do nhân viên điền (R-TIEN-36) |
| Đơn hàng | Nháp · Đã trình · Đã duyệt · Từ chối · Huỷ | **Quản lý trực tiếp của người lập duyệt** (Trưởng cơ sở lập thì tự duyệt, lịch sử ghi "tự duyệt"; Admin duyệt thay khi vắng; người duyệt chốt lúc trình, đổi quản lý sau không đổi; không có quản lý thì không trình được: R-HT-06). Mỗi dòng ghi một học sinh chọn trong danh sách em của cơ hội, đơn bắt buộc đủ họ tên và năm sinh; trước khi duyệt dòng hiện nhãn "chưa có hồ sơ", màn duyệt ghi mỗi dòng "sẽ tạo hồ sơ mới" hoặc "dùng HS…" (R-TIEN-35, R-CRM-27). **Duyệt xong tự khoá**; "khoá" là một biểu tượng, không phải một bước (R-TIEN-03). Bị từ chối thì về Nháp, sửa, trình lại |
| Phiếu thu | Nháp · Đã trình · Chờ kế toán (quản lý đã duyệt) · Đã duyệt · Từ chối · Huỷ | **Hai bước (R-TIEN-01):** quản lý trực tiếp của người lập duyệt trước (Trưởng cơ sở lập thì tự duyệt bước này; **Admin duyệt thay được**, kể cả cả hai bước và phiếu mình lập, có nhật ký (26/11, R-HT-01); quản lý vắng thì Admin cũng có thể "Chuyển người duyệt" sang người khác đủ điều kiện), rồi KT duyệt từng phiếu. Người duyệt chốt lúc trình, đổi quản lý sau không đổi (R-HT-06). Quản lý từ chối thì về Nháp kèm lý do. Kế toán từ chối thì về Nháp kèm lý do; người lập sửa rồi Trình, phiếu **đi lại từ bước quản lý** (người duyệt chốt lại lúc trình), không nhảy thẳng tới KT; lịch sử giữ cả lần từ chối cũ; Trưởng cơ sở lập vẫn tự duyệt bước quản lý (TD14). Khoản tiền vào chỉ sinh khi KT duyệt |
| Khoản tiền vào | Tự sinh khi duyệt phiếu thu; khoản đảo là một dòng âm trỏ về khoản gốc | Chỉ KT đảo; chặn đảo hai lần (R-TIEN-26) |
| Phiếu chi | Nháp · Đã duyệt · Đã chi (tạm, chốt ở giai đoạn 2) | KT lập, từ ticket hoàn tiền đã duyệt |
| Ghi danh | Chờ xếp lớp · Đang học · Bảo lưu · Hoàn thành · Chuyển lớp · Dừng · Hoàn phí | Thành Đang học khi có buổi Done đầu tiên (R-GD-05) |
| Dòng xếp lớp | Đang học · Đã rời; có ngày vào, ngày rời | Một ghi danh có nhiều dòng (Toán khối 7+: một dòng lớp Đại, một dòng lớp Hình) |
| Phiếu tái tục | L1 Chờ tái tục … L7 Dự thu · L8 Hoàn thành tái tục (tên đầy đủ lấy từ danh mục) | Tự sinh khi giờ còn ≤ 10 hoặc ngày hết giờ dự kiến còn ≤ 30 ngày. Có cờ rủi ro khi vắng ≥ 3 buổi (R-GD-13) |
| Lớp: bước duyệt | Nháp → Đã trình → Đã xác nhận → Đã duyệt → Đã đóng; nhánh Từ chối (về Nháp được) và Huỷ; Đã trình và Đã xác nhận có thêm đường "Đưa về Nháp"; Đã duyệt huỷ được khi chưa có buổi Hoàn thành | CS soạn, trình; BM xác nhận và duyệt (R-LOP-01, 02). Chỉ sửa thông tin ở Nháp, Từ chối; riêng Time Table sửa được ở Đã trình, Đã xác nhận, Đã duyệt (R-LOP-02) |
| Lớp: vận hành | Trường riêng với bước duyệt, tính tự động, không sửa tay, chỉ có giá trị từ lớp Đã duyệt: Chưa khai giảng · Đang học · Đã kết thúc; trước Đã duyệt hiện "—" (R-LOP-05) | |
| Buổi học | Nháp → Đã chốt → Done; nhánh Huỷ có tính phí, Huỷ không tính phí | Đã chốt thì có danh sách. Tự chốt trước giờ học (R-GIO-05). Tự Done khi GV hoàn tất (R-GIO-06); chưa Done thì hiện lý do |
| Loại buổi | Chính · Củng cố (trừ giờ) · Học bù · Học bổ trợ (không trừ giờ) | R-BUOI-01 |
| Yêu cầu buổi (bù, củng cố, bổ trợ) | Chờ duyệt · Đã duyệt · Từ chối | **Chỉ BM duyệt**; CS xem |
| Ticket đề nghị | Mới → Đang xử lý → Chờ duyệt → Đã duyệt → Đang thực hiện → Hoàn thành; nhánh Từ chối (bắt buộc lý do), Khách huỷ | R-CS-05 |
| Ticket khiếu nại | Mới → Đã tiếp nhận → Đang xác minh → Có phương án → Chờ phụ huynh xác nhận → Đóng – hài lòng / Đóng – không hài lòng; nhánh Mở lại, Nâng cấp | R-CS-06 |
| Tài khoản | Đang dùng · Khoá · Tạm khoá (do đăng nhập sai nhiều lần) | Không xoá tài khoản |

## 5. Luật theo phân hệ (cái giao diện phải thể hiện)

### Tuyển sinh
- **Bộ lọc nhanh có hai nhóm** (R-CRM-07):
  - "Của tôi": tôi là sale, tôi là giáo viên chấm.
  - "Thời gian": quá hạn, hôm nay, sắp tới, chưa có lịch.
  - Chọn trong cùng nhóm là HOẶC; giữa hai nhóm là VÀ.
- **Tạo cơ hội khi lead đã có cơ hội:** hiện cảnh báo kèm mã cơ hội cũ. Người dùng chọn một trong ba: Mở cơ hội cũ; Thêm em vào cơ hội cũ (không tạo cơ hội mới); Vẫn tạo thêm (xác nhận lần hai) (R-CRM-01). Lead chỉ tạo cơ hội khi ở C4C (R-CRM-40).
- **Tạo lead:** cảnh báo trùng số điện thoại với lead hoặc phụ huynh đã có.

### Bán hàng và tiền
- **Bốn tầng:** báo giá (không bắt buộc) → đơn hàng → phiếu thu → khoản tiền vào → ghi danh (R-TIEN-01).
- **Dòng đơn gồm:** học sinh, gói, hình thức, lớp, ngày vào lớp, số giờ, đơn giá, các chiết khấu, giờ tặng, thành tiền.
  - Giá tính theo giờ. Gói không có giá cho một hình thức thì không bán hình thức đó.
  - Giá do hệ thống tính; ô giá chỉ đọc.
- **Chiết khấu** theo % hoặc theo giờ tặng, cộng dồn trên một dòng. Tổng không quá 20%; vượt mức thì BM duyệt (R-TIEN-29).
- **Chọn lớp trên dòng đơn:** chỉ lớp Đã duyệt, còn chỗ, đúng môn, khối, cơ sở (R-GD-08).
  - Lớp đã có buổi: chọn ngày vào từ danh sách buổi sắp tới.
  - Lớp chưa có buổi: chọn ngày, phải đúng thứ có lịch và không trước ngày khai giảng (R-GD-06).
  - Không chọn lớp thì ghi danh vào trạng thái Chờ xếp lớp.
- **Trình đơn bị chặn** thì chỉ đúng dòng và ô còn thiếu.
- **Điều khoản thanh toán** (anh chốt 11/10): chọn trên đơn, sinh lịch đóng tiền từng đợt có hạn. Màn công nợ hiện các đợt sắp đến hạn và quá hạn.
- **Phiếu thu có ô "Cấn vào dòng":** chọn một dòng đơn để tiền dồn vào dòng đó trước; để trống thì chia theo tỉ lệ. Ô này khoá khi phiếu rời Nháp (R-TIEN-23).
- **Ghi danh** sinh khi tiền đã vào ≥ 1.000.000 đ. Giờ cấp theo tỉ lệ tiền đã thu. Giờ tặng chỉ cấp khi thu đủ (R-TIEN-20, 21, 24).
- **Kế toán duyệt phiếu thu sau ngày vào lớp:** hiện cảnh báo "đã qua N buổi" (R-TIEN-27).
- **"Cho học trước, đóng tiền sau":** BM bật trên đơn đã duyệt mà chưa thu tiền. Tối đa 2 buổi chưa đóng tiền; vượt thì em bị loại khỏi danh sách buổi, kèm cảnh báo cho vận hành và sale (R-GD-12).
- **Hoàn tiền** (chỉ qua ticket đề nghị đã duyệt). Bảng tính hoàn hiện từng bước theo ví dụ:
  - Tiền đã đóng 9.504.000 đ.
  - Trừ giờ đã học tính theo giá gốc: 20 giờ × 220.000 đ.
  - Còn 5.104.000 đ.
  - Trừ phí xử lý 10%.
  - Hoàn 4.593.600 đ.
  - Giờ tặng không hoàn. Kế toán lập phiếu chi (R-TIEN-28).
- **Số dư khách hàng:** tiền dư sau chuyển phí được giữ lại và dùng cho đơn sau.

### Ghi danh, xếp lớp, quỹ giờ
- **Mỗi dòng đơn sinh một ghi danh, một quỹ giờ.**
  - Ghi danh có các dòng xếp lớp.
  - Buổi Done ở lớp nào cũng trừ cùng một quỹ (R-GD-01, 02).
- **Toán từ khối 7 tách hai lớp, Đại số và Hình học.**
  - Phụ huynh mua tổng giờ Toán, không có giờ Đại, giờ Hình riêng.
  - Khi xếp lớp, gợi ý một lớp DAI và một lớp HINH; chỉ xếp một lớp thì cảnh báo, không chặn.
  - Lớp riêng khối 7+ vẫn là một lớp TOAN.
- **Quỹ giờ hiển thị:** đã cấp, đã dùng, còn lại, giờ tặng, ngày hết giờ dự kiến (cộng lịch mọi lớp đang xếp).
  - Hạn gói 6 tháng **chỉ để dự báo**: quá hạn mà còn giờ thì em vẫn học bình thường (R-GD-07).
- **Sổ giờ chỉ thêm dòng**, không sửa, không xoá. Điều chỉnh là thêm dòng ngược dấu, bắt buộc lý do (R-GD-04).

### Lớp học
- **Thời khoá biểu:** mỗi thứ có thể nhiều khung giờ; mỗi khung có giờ, giáo viên, trợ giảng, phòng.
  - Trùng phòng thì **cảnh báo, không chặn** (R-LOP-08). Trùng giáo viên (cùng ngày, cùng giờ, ở cấp buổi thật) cũng chỉ cảnh báo, không chặn; lớp luân phiên không bị coi là trùng (23/10).
- **Duyệt lớp** bắt buộc có thời khoá biểu. Duyệt xong **tự sinh buổi**; hộp thoại duyệt hiện trước số buổi và ngày kết thúc dự kiến, đã bỏ ngày nghỉ lễ (R-LOP-03, 09).
- **Đóng lớp** bị chặn khi còn em còn giờ: liệt kê tên các em. **Huỷ lớp** bị chặn khi đã có buổi Done (R-LOP-04).
- **Khung chương trình** bắt buộc với lớp chung, tuỳ chọn với lớp riêng. Lớp có "bài bắt đầu" (R-LOP-07).
- **Đổi giáo viên cả lớp:** sinh lại các buổi chưa diễn ra. Đổi giáo viên một buổi là dạy thay; giờ dạy tính cho người dạy thật.

### Buổi học, danh sách, điểm danh
- **Có tên trong danh sách và buổi Done thì trừ giờ**, dù em có mặt, đi muộn hay vắng (R-GIO-01).
- **Em không vào danh sách** khi: chưa tới ngày vào lớp, đang bảo lưu, đã dừng, không đủ giờ (trừ khi đang trong hạn mức cho học trước).
  - Bản ghi buổi có mục "Không vào danh sách" kèm lý do từng em.
- **Mỗi em một dòng điểm danh mỗi buổi** (R-GIO-04).
- **Điểm danh có 4 trạng thái** (R-DD-01): **Có mặt · Đi muộn · Vắng có phép · Vắng không phép**. Ô trống nghĩa là chưa điểm danh.
  - Mặc định để trống. Có nút "Còn lại: Có mặt".
  - Màu: Có mặt nhạt, Đi muộn vàng, hai loại Vắng đậm.
- **Điểm danh hai phía** (R-DD-02, 03):
  - Vận hành ghi riêng kèm lý do liên hệ (Không nghe máy, Đã nhắc vào lớp, Đã vào lớp, Xin nghỉ học…).
  - Giáo viên ghi riêng; **ô của giáo viên là trạng thái chính thức**.
  - Bản ghi buổi hiện hai cột cạnh nhau.
- **Huỷ buổi:**
  - Trung tâm huỷ: không tính phí, tự thêm một buổi vào cuối lịch và dời nhãn bài.
  - Học sinh huỷ buổi lớp riêng: người huỷ tự chọn "có tính phí" (không bù) hoặc "không tính phí" (xếp buổi bù), bắt buộc lý do (R-BUOI-06, 07).
- **Học thử:** miễn phí, là tư cách của em trong một buổi, không phải loại buổi (R-GD-11).
- **Sửa điểm danh sau khi buổi Done** (anh chốt 11/10):
  - Chỉ BM được sửa, bắt buộc lý do.
  - Đổi giữa các trạng thái đi học không đổi giờ.
  - Thêm hoặc bớt em khỏi danh sách thì thêm dòng điều chỉnh sổ giờ.

### Cổng giáo viên (điện thoại trước)
Giáo viên làm một buổi theo các bước:
1. Điểm danh.
2. Nội dung buổi (danh sách dòng) và giao bài tập về nhà (BTVN).
3. Chấm từng em.
4. Chấm BTVN của buổi trước.
5. Hoàn tất.

Chấm từng em (R-GV-01, 02, 04):
- **Thái độ 3 tiêu chí:** Tập trung, Chủ động, Tinh thần học tập.
- **Kiến thức 3 tiêu chí:** Nắm kiến thức, Hiểu bản chất, Ghi nhớ.
- **Vận dụng:** mỗi dòng nội dung buổi là một mục chấm.
- Thang 1–5, có mô tả mức lấy từ rubric.
- **Ô trống khác điểm 0.**
- Em có mặt phải có đủ 6 điểm tiêu chí và lời nhắn phụ huynh. Em vắng không phải chấm.
- Điểm trung bình vận dụng do hệ thống tính, giáo viên không nhập.

Chấm BTVN của buổi trước (R-GV-11): mỗi em mỗi bài có đúng một trạng thái:
- **Đã chấm** (điểm 1–5)
- **Làm chưa xong** (vẫn có điểm)
- **Không làm**
- **Nộp sau** (cập nhật ở buổi sau mà không mở lại buổi cũ)
- **Không áp dụng**

Hạn và quyền:
- **Hạn hoàn tất buổi:** 8 giờ sau khi buổi kết thúc. Hệ thống **tự đóng dấu một lần**, Đúng hạn hoặc Trễ hạn kèm số giờ trễ, vào lúc giáo viên lưu xong mục cuối cùng và đủ các bước của R-GIO-06 (điểm danh, nội dung buổi và BTVN, chấm nhận xét, chấm BTVN buổi trước; bỏ bước cuối nếu buổi trước không giao BTVN). Giáo viên không bấm đóng dấu; sửa điểm sau đó không đổi dấu (R-GV-05, QĐ-Đ21).
- **Giáo viên không được:** tạo dòng điểm danh, đổi tình trạng buổi, sửa sổ giờ. Giáo viên chỉ thấy buổi của mình. Trợ giảng có quyền như giáo viên trong lớp được phân công (R-GV-08, 09).
- **Giáo viên tạo được ticket** cho lớp mình, nhưng không duyệt.
- **Chấm kiểm tra đầu vào** có từ giai đoạn 1, trong cổng giáo viên bản tối giản (anh chốt 11/10).

### Báo cáo BTVN (R-GV-12)
Hai chỉ số **tách riêng**, không gộp "Không làm" thành điểm 0:
- **Tỉ lệ làm bài** = (Đã chấm + Làm chưa xong) ÷ số bài phải làm.
- **Điểm BTVN trung bình** = trung bình điểm các bài Đã chấm và Làm chưa xong.

### Chăm sóc khách hàng (ticket)
- **Hai loại ticket:** Đề nghị và Khiếu nại.
- **Phải qua ticket đề nghị đã duyệt** mới làm được: chuyển lớp, chuyển cơ sở, bảo lưu, chuyển phí, hoàn tiền, **dừng học** (anh chốt 11/10). Nút "Thực hiện" trên ticket mở hộp thoại riêng cho từng nhóm con.
- **Nhóm đề nghị và nhóm con:**
  - Chuyển lớp: cùng môn (đổi giờ học, đổi trình độ, đổi giáo viên); khác môn.
  - Chuyển cơ sở.
  - Bảo lưu: mới, gia hạn, quay lại sớm.
  - Chuyển phí: sang môn khác, sang anh/chị/em, sang gói khác.
  - Hoàn tiền: toàn bộ, một phần.
  - Đổi lịch học: dời một buổi, đổi ca cố định, xin học bù.
  - Dừng học.
- **Nhóm khiếu nại:** Chương trình học · Giáo viên · Phương pháp giảng dạy · Tư vấn tuyển sinh · Vận hành · Chăm sóc · Khác (mỗi nhóm có nhóm con).
  - **Mức độ:** Thấp, Trung bình, Cao, Nghiêm trọng. Nghiêm trọng báo Ban giám đốc ngay.
- **Người duyệt** (cấu hình được):
  - Chuyển lớp cùng môn, bảo lưu, đổi lịch: BM.
  - Chuyển lớp khác môn, chuyển phí, hoàn tiền: BM rồi KT.
  - Chuyển cơ sở: BM của **cả hai** cơ sở.
  - Bản ghi ticket hiện chuỗi người duyệt.
- **Hạn xử lý (SLA)** (R-CS-08):
  - Khiếu nại thường: phản hồi 24 giờ, xử lý xong 3 ngày.
  - Khiếu nại nghiêm trọng: phản hồi 2 giờ, xử lý xong 1 ngày.
  - Đề nghị: phản hồi 24 giờ, xử lý xong 2 ngày (hoàn tiền 7 ngày).
  - Hiện "còn x giờ" hoặc "quá hạn". Quá hạn thì tự nâng cấp.
- **Thông tin trên ticket:** học sinh, phụ huynh, ghi danh, lớp, người bị khiếu nại, kênh tiếp nhận, người phụ trách, mô tả, đính kèm, phương án, kết quả, mức hài lòng.
- **28/11 anh bỏ mục menu CS-16** «Nhận xét chờ gửi» (không còn màn ở CRM); giáo viên vẫn tự xuất ảnh ở màn chấm nhận xét của cổng giáo viên và tự gửi vào group Zalo lớp (R-V2-40 giữ nguyên). Luật cũ: **Nhận xét chờ gửi phụ huynh** (anh chốt 11/10): khi phụ huynh chưa có tài khoản, CSKH lấy lời nhắn sau buổi, sao chép hoặc xuất ảnh để gửi Zalo tay, rồi đánh dấu đã gửi.

### Quản trị và cấu hình (không viết cứng trong code)
| Tầng | Gồm | Giao diện |
|---|---|---|
| **Danh mục** | Nguồn, giai đoạn, lý do, loại hoạt động, phòng… | Thêm, đổi tên hiển thị, kéo thứ tự, Ngừng. Không xoá, không đổi mã. Danh mục khoá chỉ đổi tên. Có danh mục nhiều cấp: giai đoạn → nhóm con; tỉnh → phường; nhóm → nhóm con ticket |
| **Tham số** | Xem bảng ở mục 6 | Kiểu, đơn vị, khoảng cho phép, giải thích; giá trị chung và ghi đè theo cơ sở; lịch sử thay đổi |
| **Cấu hình có hiệu lực** | Bảng giá, gói, chiết khấu, điều khoản thanh toán, khung chương trình, rubric, ma trận quyền, người duyệt ticket | Có phiên bản hoặc ngày hiệu lực. Đổi cấu hình không làm đổi bản ghi cũ |
| **Công tắc tính năng** | Mỗi phân hệ, mỗi cơ sở | Bật, tắt |

Thêm: nhật ký thao tác chỉ đọc; xuất file luôn ghi nhật ký.

## 6. Tham số mặc định (dùng làm số trong dữ liệu mẫu)
| Tham số | Mặc định |
|---|---|
| Cho học trước tối đa | 2 buổi |
| Tự chốt danh sách | quét mỗi 30 phút, các buổi trong 2 giờ tới |
| Hạn GV hoàn tất buổi | 8 giờ |
| Khối tách Đại, Hình | 7 |
| Thời hạn gói | 6 tháng |
| Ngưỡng tái tục | 10 giờ hoặc 30 ngày |
| Số buổi vắng rủi ro | 3 |
| Hạn báo giá | 14 ngày |
| Tiền cọc tối thiểu | 1.000.000 đ |
| Bảo lưu tối đa | 6 tháng |
| Phí xử lý hoàn | 10% |
| Trần chiết khấu | 20% |
| Mở lại khiếu nại | trong 7 ngày |

Tự đăng xuất khi không dùng: nhân viên 60 phút; giáo viên, trợ giảng, học sinh 7 ngày.

## 7. Đăng nhập
- **Nhân viên, giáo viên:** email + mật khẩu (ít nhất 8 ký tự, có chữ và số).
  - Quên mật khẩu thì tự đặt lại qua email.
  - **Admin và Kế toán bắt buộc xác thực hai bước** (mã 6 số từ ứng dụng).
- **Học sinh:** đăng nhập bằng mã HS (`HS000123`) + mật khẩu trung tâm cấp, đổi mật khẩu lần đầu. Quên mật khẩu thì nhờ CSKH.
- **Phụ huynh:** cách đăng nhập chốt ở giai đoạn 4.
- **Sai nhiều lần thì tạm khoá.** Thông báo lỗi chung chung, không nói sai email hay sai mật khẩu.

## 8. Quyết định thiết kế đã chốt (thay cho các câu hỏi mở trong nhật ký quyết định P1–P4)
| # | Quyết định |
|---|---|
| O-1 | Font Inter cho giao diện và số (chữ số đều cột), Be Vietnam Pro cho tiêu đề |
| O-2, O-3 | Điểm danh mặc định để trống; có màu: Có mặt nhạt, Đi muộn vàng, Vắng đậm |
| O-7 | Học sinh lớp 2–12 |
| O-8 | Bỏ con số "18+ năm" khỏi giao diện cho tới khi có số chắc chắn |
| O-10 | Xưng hô: CRM trung tính; cổng Giáo viên gọi "thầy cô"; Học tập gọi học sinh là "em", xưng "HMT"; với phụ huynh gọi "Anh/Chị" |
| O-12 | Biểu tượng Lucide, nét 1,5px, cỡ 16/20/24 |
| O-13 | Chỉ làm giao diện sáng; giao diện tối để sau khi chạy thật |
| O-14, O-15 | Làm ô chọn có tìm kiếm (Combobox) và chọn khoảng ngày (DateRange) |
| O-17 | Điểm danh khi mất mạng: để giai đoạn 3 (quyết định kỹ thuật); hiện trạng thái "đang lưu / đã lưu / chưa lưu được" |
| O-18 | Có "Đi muộn" (R-DD-01) |
| Báo cáo | Báo cáo tổng hợp làm trên Looker Studio. Trong app chỉ có màn tổng quan Ban giám đốc, báo cáo trễ hạn giáo viên, giờ dạy giáo viên và các danh sách theo dõi |
| CRM trên điện thoại | CRM ưu tiên máy tính. Màn duyệt (hàng chờ duyệt, duyệt đơn, duyệt yêu cầu buổi, duyệt ticket) và điểm danh vận hành có thêm bản điện thoại |
| In ấn | Có bản in báo giá, biên nhận phiếu thu, phiếu chi |

## 9. Cập nhật 12/10/2026: quyết định trong lúc vẽ P5
File luật đầy đủ mới nhất là `04-luat-nghiep-vu.md` (các dòng đánh dấu **(12/10)**); danh mục và tham số ở `HMT_DANH_MUC_VA_THAM_SO.md`. Khi kiểm (P6), dùng hai file này làm chuẩn. Những điểm thấy trên giao diện:
- **Mã:** lead `LD000123`, cơ hội `CO000123`, phiếu kiểm tra `PKT000123`, ghi danh `GD000123`, phiếu tái tục `TT000123`, khoản tiền vào `KTV-CS1-2610-0221`, gói `LC-TOAN-K09` (không chứa hình thức).
- **Ghi danh** có thêm trạng thái **Đã xếp lớp** (có lớp, chưa có buổi Done).
- **Lead** đổi giai đoạn tự do; C4D do hệ thống gắn. **Phiếu tái tục** L1–L8, L5 = Không tái tục (bắt buộc lý do).
- **Đơn, phiếu thu** bị từ chối thì về Nháp, sửa, trình lại. **Điều khoản thanh toán** sinh lịch đóng tiền từng đợt.
- **Giờ tặng tính vào trần 20%** (giờ tặng ÷ giờ mua); quà tặng tài liệu, dịch vụ không tính.
- **Điểm BTVN thang 1–5**; kiểm tra đầu vào thang 0–10.
- **Dừng học** qua ticket nhóm "Dừng học": hoàn tiền hoặc giữ số dư.
- **Admin** làm được mọi việc, kể cả việc của Trưởng cơ sở, lịch sử ghi "Admin duyệt thay". **(26/11)** Việc tiền (duyệt phiếu thu, đảo khoản, phiếu chi, hoàn phí, dừng học) Admin duyệt được, kể cả cả hai bước và chứng từ mình lập, mỗi lần dùng ngoại lệ ghi nhật ký; vai khác giữ hai người khác nhau, không tự duyệt (R-HT-01, R-TIEN-01).
- **Cổng phụ huynh**: 5 tab Trang chủ, Kết quả, Lịch, Học phí, Đề nghị; Tài khoản ở menu ảnh đại diện.
- **Cổng giáo viên** có bố cục điện thoại và laptop (khuôn K14).
