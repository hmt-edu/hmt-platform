# 2. Thao tác cơ bản dùng chung

Áp dụng cho mọi danh sách và bản ghi trong cổng CRM (Lead, Cơ hội, Đơn hàng, Phiếu thu, Ticket…). Xem `README.md` về cách đọc. Chữ trong dấu «…» là chữ trên màn thật (đối chiếu code trên `main` và bảng nhãn K03 do Tester 2 ghi từ staging). Chỗ chèn ảnh ghi `[ẢNH: tên-kịch-bản]`, ảnh chụp sau bằng tài khoản giả. Dữ liệu trong ví dụ là giả.

> Các nhãn **Filters**, **Group By**, **Favorites**, **Save to Favorites**, **Calendar** viết bằng tiếng Anh và **giữ nguyên**, không dịch.

## 2.1 Thanh công cụ của một danh sách
- **Mục tiêu:** biết từng nút trên thanh đầu danh sách.
- **Từ trái sang phải:** ô tìm (chữ gợi ý khác theo màn, ví dụ «Tìm mã, phụ huynh, SĐT, tên em…») · «Làm mới» · «Cột» · «Kiểu xem» (chỉ màn có thêm kiểu, ví dụ «Danh sách» | «Kanban», hoặc **Calendar**) · «Trường ngày» · «Khoảng thời gian» · **Filters** · **Group By** · **Favorites** · «Trang trước» / «Trang sau».
- Màn nào không có kanban hay lịch thì không có nút «Kiểu xem». Danh sách không có nút «Xuất» trên thanh này.
- **Ảnh:** [ẢNH: danh-sach-thanh-cong-cu]

## 2.2 Tìm kiếm
- **Các bước:** 1) Bấm vào ô tìm ở đầu danh sách. 2) Gõ mã, tên hoặc số điện thoại (chữ gợi ý trong ô cho biết tìm theo gì). 3) Kết quả lọc ngay theo từ khoá; xoá chữ để quay lại đầy đủ.
- **Nếu không ra dòng nào:** màn hiện «Không có kết quả khớp bộ lọc» và gợi ý «Thử bớt điều kiện hoặc đổi từ khoá.»
- **Ảnh:** [ẢNH: danh-sach-tim]

## 2.3 Filters (lọc)
- **Mục tiêu:** xem một nhóm bản ghi theo điều kiện.
- **Các bước:**
  1. Bấm **Filters**. Hộp mở có «Lọc nhanh» (các chip như «Của tôi», «Tình trạng»…) và dòng «Cùng nhóm là HOẶC, khác nhóm là VÀ.»
  2. Bấm chip muốn lọc. Điều kiện áp dụng ngay (trên điện thoại bấm «Áp dụng»).
  3. Muốn lọc kỹ hơn bấm «Lọc nâng cao…». Hộp «Lọc nâng cao» có «Thêm điều kiện»: chọn trường, phép so sánh, giá trị; các dòng nối với nhau bằng VÀ. Chưa có dòng nào thì hiện «Chưa có điều kiện nào. Bấm “Thêm điều kiện”.» Bấm «Áp dụng».
  4. Lọc theo ngày: chọn «Trường ngày» rồi «Khoảng thời gian».
- **Kết quả:** các điều kiện đang dùng hiện thành chip ở hàng «Điều kiện đang áp dụng» dưới thanh công cụ; bấm vào chip để bỏ từng cái, hoặc «Xoá tất cả» để bỏ hết.
- **Ảnh:** [ẢNH: danh-sach-loc], [ẢNH: danh-sach-loc-nang-cao]

## 2.4 Group By (nhóm)
- **Các bước:** 1) Bấm **Group By**. 2) Hộp «Nhóm theo» liệt kê các trường có thể nhóm (ví dụ Đơn hàng: «Tình trạng», «Sale»). 3) Bấm trường muốn nhóm; chọn **tối đa 2 cấp**, theo thứ tự bấm; bấm lại để bỏ. 4) Danh sách chia thành các nhóm có số đếm; bấm một nhóm để mở các dòng bên trong.
- **Ảnh:** [ẢNH: danh-sach-nhom]

## 2.5 Favorites và Save to Favorites (lưu bộ lọc)
- **Mục tiêu:** lưu bộ lọc hay dùng để mở lại bằng một cú bấm.
- **Lưu:** 1) Đặt các bộ lọc như 2.3. 2) Ở hàng chip bấm **Save to Favorites** (hộp lưu tên «Lưu bộ lọc hiện tại»). 3) Nhập «Tên bộ lọc». Người có quyền còn thấy ô «Dùng cho mọi người» để chia sẻ bộ lọc; bộ đã chia sẻ hiện nhãn «Dùng chung». 4) Lưu. Chưa đặt tên thì báo «Hãy đặt tên cho bộ lọc.»
- **Dùng lại:** bấm **Favorites**, hộp «Bộ lọc của tôi» liệt kê các bộ đã lưu; bấm tên để áp dụng. Chưa có bộ nào thì hiện «Chưa có bộ lọc nào được lưu» kèm gợi ý «Chọn lọc rồi bấm “Lưu bộ lọc hiện tại”.»
- **Bỏ bộ đã lưu:** ở dòng bộ lọc trong **Favorites** có nút «Bỏ bộ lọc <tên>». (Nút «Xoá bộ lọc» khi danh sách trống chỉ bỏ các điều kiện đang áp dụng, không xoá bộ đã lưu.)
- **Nếu lỗi:** «Chưa lưu được bộ lọc.» hoặc «Chưa bỏ được bộ lọc.» thì thử lại; «Không tải được bộ lọc đã lưu. Kiểm tra mạng rồi mở lại.» thì kiểm tra mạng, bấm «Thử lại».
- **Ảnh:** [ẢNH: danh-sach-luu-bo-loc], [ẢNH: danh-sach-favorites]

## 2.6 Chọn cột («Cột»)
- **Các bước:** 1) Bấm «Cột». 2) Hộp «Cột hiển thị»: tích hoặc bỏ tích cột muốn hiện/ẩn. Cột bị khoá luôn hiện. 3) Đổi thứ tự bằng cách kéo hoặc dùng nút mũi tên. 4) Bấm «Mặc định» để trả về cột gốc.
- **Ghi nhớ:** hệ thống nhớ lựa chọn cột của bạn cho từng màn ngay trên trình duyệt này (không lưu lên máy chủ; đổi máy hoặc xoá dữ liệu trình duyệt thì về cột mặc định). Bảng mặc định hiện tối đa 8 cột; cột còn lại nằm sẵn trong «Cột».
- **Ảnh:** [ẢNH: danh-sach-chon-cot]

## 2.7 Đổi giữa danh sách, Kanban và Calendar
- **Chỉ ở màn có nhiều kiểu xem** (ví dụ Cơ hội có «Danh sách» | «Kanban»). Bấm tên kiểu xem ở nhóm «Kiểu xem».
- **Kanban:** mỗi cột là một giai đoạn, thẻ có thông tin chính; kéo thẻ sang cột kế **chỉ đi được khi luật cho phép**, đi sai thì có thông báo lý do.
- **Calendar:** xem theo tuần, tháng hoặc ngày; bấm vào một mục để mở bản ghi.
- **Ảnh:** [ẢNH: chuyen-kanban], [ẢNH: chuyen-calendar]

## 2.8 Phân trang
- Mỗi trang mặc định **50 dòng**. Bấm «Trang sau» hoặc «Trang trước» để chuyển; thanh trên có số kiểu «1–8 / 8» cho biết vị trí.
- **Ảnh:** [ẢNH: danh-sach-phan-trang]

## 2.9 Mở, tạo, sửa, lưu một bản ghi
- **Mở:** bấm vào dòng trong danh sách (hoặc bấm mã, tên ở cột đầu). Trong bản ghi có «Bản ghi trước» và «Bản ghi sau» để duyệt nhanh theo danh sách vừa xem; «Làm mới» để tải lại.
- **Tạo:** bấm nút tạo ở đầu danh sách (tên theo màn, ví dụ «Tạo mới», «Tạo đơn hàng», «Tạo cơ hội»). Trường thiếu hoặc sai được báo ngay tại ô.
- **Sửa và lưu:** nhiều bản ghi có nút «Sửa» rồi «Lưu» và «Huỷ»; nút theo việc làm được hiện ngay trên thanh trạng thái, không có thì bạn chưa đủ quyền hoặc bản ghi đang ở trạng thái không cho sửa. Bấm «Lưu» thì nút bị khoá trong lúc lưu; lỗi mạng thì giữ nguyên dữ liệu bạn đã nhập, bấm «Thử lại».
- **Huỷ:** không xoá hẳn bản ghi; huỷ là đổi trạng thái, có hộp xác nhận (đôi khi bắt nhập lý do).
- **Ảnh:** [ẢNH: ban-ghi-mo], [ẢNH: ban-ghi-tao], [ẢNH: ban-ghi-sua-luu]

## 2.10 Ghi chú và nhật ký
- **Ở đâu:** cột phải của bản ghi, khối «Ghi chú & hoạt động» (có thể ở dưới bản ghi trên điện thoại). Dòng «DÒNG THỜI GIAN» liệt kê theo thứ tự: ghi chú của đồng nghiệp và các thay đổi hệ thống tự ghi («… đổi thành …»).
- **Viết ghi chú:** 1) Bấm ô «Viết ghi chú… gõ @ để nhắc đồng nghiệp». 2) Gõ nội dung; gõ `@` rồi chọn đồng nghiệp để nhắc (mục «Nhắc đồng nghiệp»; không có ai thì báo «Không tìm thấy đồng nghiệp nào.»). 3) Bấm «Gửi ghi chú». Lỗi thì báo «Chưa gửi được ghi chú. Thử lại.»
- **Lọc dòng thời gian:** bộ lọc «Lọc dòng thời gian» có «Tất cả», «Ghi chú», «Hệ thống».
- **Lưu ý:** đính kèm tệp **chưa bật** (hiện «Đính kèm tệp (chưa bật)»). Không có quyền xem trao đổi thì hiện «Bạn không có quyền xem trao đổi». Nhật ký hệ thống chỉ đọc, không ai sửa hay xoá được.
- **Ảnh:** [ẢNH: ban-ghi-ghi-chu], [ẢNH: ban-ghi-nhat-ky]

## 2.11 Thông báo
- **Ở đâu:** biểu tượng chuông «Thông báo» ở thanh trên; số cạnh chuông là số chưa đọc (tự cập nhật mỗi phút).
- **Các bước:** 1) Bấm chuông, hộp «Thông báo» hiện các mục mới nhất. 2) Lọc «Tất cả» hoặc «Chưa đọc». 3) Bấm một thông báo để đọc và mở đúng bản ghi liên quan. 4) Dùng «Đánh dấu tất cả đã đọc» để đọc hết một lần.
- **Lưu ý:** mỗi người chỉ thấy thông báo của mình.
- **Ảnh:** [ẢNH: thong-bao]

## 2.12 Việc chờ tôi duyệt
- **Ở đâu:** menu «Tổng quan» › «Việc chờ tôi duyệt». Mục này **chỉ hiện với người có quyền duyệt**.
- **Các bước:** 1) Mở mục. 2) Danh sách liệt kê các bản ghi đang chờ bạn (dùng chung thanh công cụ ở 2.1: tìm, **Filters**…). 3) Bấm một dòng để mở bản ghi, xem tóm tắt, rồi bấm nút duyệt hoặc từ chối ở thanh trạng thái (có hộp xác nhận; từ chối thường bắt nhập lý do).
- **Kết quả:** bản ghi chuyển trạng thái, dòng đó rời khỏi danh sách của bạn, nhật ký ghi người duyệt và thời điểm.
- **Ảnh:** [ẢNH: viec-cho-toi-duyet-danh-sach], [ẢNH: viec-cho-toi-duyet-mo-ban-ghi]

## Dữ liệu mẫu
_(Để trống: viết sau khi tính năng chạy.)_
