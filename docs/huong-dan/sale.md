# Hướng dẫn cho Sale và Tuyển sinh (cổng CRM)

Vai: Sale, Tuyển sinh. Menu: **Tuyển sinh** (Lead, Cơ hội, Lịch hẹn, Phiếu kiểm tra), **Bán hàng và thu chi** (Báo giá, Đơn hàng, Phiếu thu). Xem thêm `README.md` về cách đọc.

## 1. Nhận và chăm sóc một lead
- **Mục đích:** ghi nhận khách mới, giao người chăm, lên lịch hẹn.
- **Ai làm:** Sale, Tuyển sinh (xem lead của cơ sở mình).
- **Các bước:**
  1. Vào **Lead** (`/crm/lead`), tìm theo tên hoặc số điện thoại, hoặc bấm tạo lead mới.
  2. Mở bản ghi lead. Điền khối «Thông tin phụ huynh», «Thông tin học sinh», «Nhu cầu»; khối «Nguồn và phụ trách» cho biết nguồn và người phụ trách.
  3. Menu «Hành động»: «Giao người phụ trách» (đổi người chăm), «Gộp trùng» (khi cùng một khách có hai hồ sơ), «Hoàn tác» (hoàn tác thao tác vừa làm khi còn cho phép).
  4. Bấm «Lên lịch hẹn» để hẹn gặp hoặc gọi; nút «Huỷ lịch hẹn» khi khách đổi ý.
  5. Khi khách có nhu cầu thật, bấm «Tạo cơ hội».
- **Kết quả mong đợi:** lead đổi giai đoạn theo chăm sóc; lịch hẹn hiện ở khối «Lịch hẹn»; «Tạo cơ hội» mở một cơ hội mới gắn lead.
- **Lỗi thường gặp:**

| Thấy gì | Nghĩa là | Làm gì |
|---|---|---|
| «Số điện thoại này đã có hồ sơ» / «đã có khách hàng» | trùng số | xem hồ sơ cũ rồi «Gộp trùng», hoặc «Vẫn dùng số này» nếu thật sự hai người |
| Nút «Tạo cơ hội» mờ kèm lý do | chưa đủ điều kiện | đọc lý do khi rê chuột, bổ sung thông tin còn thiếu |
| `HMT_KHONG_CO_QUYEN` | không có quyền ở cơ sở này | báo Trưởng cơ sở |

- **Ảnh:** [ẢNH: lead-ban-ghi], [ẢNH: lead-hanh-dong], [ẢNH: lead-tao-co-hoi]

## 2. Làm việc với cơ hội
- **Mục đích:** đi cơ hội qua các giai đoạn tới báo giá và đơn.
- **Ai làm:** Sale, Tuyển sinh.
- **Các bước:**
  1. Vào **Cơ hội**, mở một cơ hội. Thanh giai đoạn ở đầu bản ghi cho biết đang ở đâu; bấm giai đoạn kế để chuyển (hộp thoại «Chuyển sang …» hỏi thêm khi giai đoạn cần ghi chú).
  2. Các nút liên kết có số đếm: «Lead gốc», «Phụ huynh», «Lịch hẹn», «Kiểm tra», «Báo giá», «Đơn hàng». Nút số 0 và chưa dùng được thì mờ.
  3. «Lên lịch hẹn» để hẹn kiểm tra đầu vào; kết quả kiểm tra nằm ở «Kiểm tra».
  4. Khi đủ điều kiện, bấm «Tạo báo giá» rồi «Tạo đơn hàng» (nút chỉ sáng khi đúng giai đoạn; nếu mờ, rê chuột đọc lý do).
- **Kết quả mong đợi:** báo giá và đơn gắn đúng cơ hội; số đếm trên nút liên kết tăng.
- **Lỗi thường gặp:** chuyển giai đoạn bị chặn kèm câu lý do (thiếu phiếu kiểm tra, chưa đủ điều kiện); đọc câu trên màn rồi làm bước còn thiếu. **Ảnh:** [ẢNH: co-hoi-thanh-giai-doan], [ẢNH: co-hoi-lien-ket]

## 3. Lập báo giá
- **Mục đích:** báo giá gói học cho phụ huynh, có chiết khấu theo chính sách.
- **Ai làm:** Sale.
- **Các bước:** 1) Từ cơ hội bấm «Tạo báo giá». 2) Chọn gói cho từng dòng (nút chọn gói ở mỗi dòng hiện «Chọn gói…» rồi mã gói), nhập số lượng, giờ tặng nếu có, thêm chiết khấu theo chính sách. 3) Lưu. 4) Màn bản ghi báo giá có «In» (bản in cho phụ huynh), «Từ chối báo giá» (khi khách từ chối, ghi lý do), «Huỷ báo giá».
- **Kết quả mong đợi:** báo giá ở tình trạng Nháp rồi gửi; tổng tiền do hệ thống tính, không nhập tay.
- **Lỗi thường gặp:** thiếu số lượng thì báo tại ô dòng; gói không có giá cho hình thức đã chọn thì không chọn được (giá trống = không bán hình thức đó). **Ảnh:** [ẢNH: bao-gia-tao], [ẢNH: bao-gia-in]

## 4. Lập đơn hàng và chọn lớp
- **Mục đích:** chốt đơn từ báo giá, chọn lớp cho từng dòng.
- **Ai làm:** Sale (đơn của mình).
- **Các bước:**
  1. Từ cơ hội bấm «Tạo đơn hàng» (hoặc chuyển báo giá thành đơn).
  2. Ở «Dòng đơn»: chọn gói, số lượng, điều khoản thanh toán; mỗi dòng bấm «Chọn lớp» để chọn lớp (chỉ lớp đã duyệt, còn chỗ, đúng môn, khối, cơ sở) và buổi hoặc ngày vào lớp.
  3. Lưu đơn, rồi **«Trình duyệt»** (đơn đi cho người duyệt đã chốt; bước chuyển người duyệt có thông báo «Đã chuyển người duyệt.»).
  4. Đơn đã duyệt: bấm «Tạo phiếu thu» để thu tiền (xem mục 5).
- **Kết quả mong đợi:** đơn Đã trình rồi Đã duyệt; sau khi thu đủ và duyệt phiếu thu, mỗi dòng sinh một ghi danh.
- **Lỗi thường gặp:**

| Thấy gì | Làm gì |
|---|---|
| «Chưa trình được» / «Có em chưa đủ thông tin» | điền đủ thông tin học sinh ở dòng đơn rồi trình lại, hoặc «Vẫn trình» nếu được phép |
| Lớp hết chỗ, sai môn/khối | chọn lớp khác trong danh sách; lớp không hiện nghĩa là không đủ điều kiện |
| «Huỷ đơn» không có | chỉ người lập huỷ đơn Nháp; đơn đã trình do người duyệt đã chốt huỷ; đơn đã có phiếu thu phải qua ticket hoàn tiền |

- **Ảnh:** [ẢNH: don-hang-dong-don], [ẢNH: don-hang-chon-lop], [ẢNH: don-hang-trinh]

## 5. Lập phiếu thu
- **Mục đích:** ghi khoản phụ huynh đã đóng cho đơn.
- **Ai làm:** Sale hoặc CSKH có quyền lập phiếu thu.
- **Các bước:** 1) Trong đơn đã duyệt bấm «Tạo phiếu thu». 2) Nhập số tiền, hình thức, ngày nhận, mã giao dịch, đính chứng từ; ở «Chia tiền vào dòng đơn» chia khoản vào các dòng. 3) Lưu (Nháp), rồi **«Trình quản lý»**. 4) Nếu bị «Từ chối phiếu thu» (phiếu về Nháp) thì sửa theo lý do rồi trình lại; «Huỷ phiếu thu» khi nhập nhầm (chỉ phiếu chưa duyệt).
- **Kết quả mong đợi:** phiếu đi hai bước duyệt (Trưởng cơ sở rồi Kế toán); duyệt xong sinh khoản tiền vào và ghi danh.
- **Lỗi thường gặp:** số tiền vượt phần còn phải thu thì báo tại ô; phiếu đã duyệt không sửa được, muốn sửa phải để Kế toán đảo khoản. **Ảnh:** [ẢNH: phieu-thu-tao], [ẢNH: phieu-thu-trinh]

## 6. Việc phụ huynh hỏi sau khi mua
Bạn không duyệt tiền. Khi phụ huynh xin bảo lưu, chuyển lớp, hoàn phí: báo CSKH tạo ticket (xem `cskh.md`).
