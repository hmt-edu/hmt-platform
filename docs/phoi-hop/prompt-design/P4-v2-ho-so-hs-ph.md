# Lời nhắn cho Claude Design: P4 v2, hồ sơ học sinh và phụ huynh (17/10/2026)

(Ghi chú 17/10 chiều: đã sửa "Giờ đăng ký (đã phân bổ)" thành "Giờ đăng ký", vì mỗi dòng đơn một lớp, không còn phân bổ giờ. Xem `P4-bo-sung-ma-cu.md` cho ô mã cũ.)

Dán nguyên văn vào cuộc chat Design, kèm link wireframe (artifact "Wireframe hồ sơ phụ huynh và học sinh"; nhớ cho Design quyền xem) hoặc ảnh chụp 10 màn.

---

Chào Design. Anh Trường đã duyệt wireframe hồ sơ học sinh và phụ huynh (10 màn, đính kèm). Nhờ em làm đẹp lại bằng khuôn P0 và **điều chỉnh các màn P4 hiện có** theo đúng nội dung wireframe. Wireframe là nguồn nội dung đã duyệt: **không thêm, bớt trường, nút, cột**; chỉ đổi cách trình bày cho đúng hệ thiết kế HMT.

**1. Màn cần cập nhật (mã trong `docs/design/ban-do-man-hinh.md`)**
- KH-05 Học sinh (hồ sơ): 7 màn wireframe HS-01 đến HS-07 (Tổng quan, Học tập, Điểm danh, Điểm danh chi tiết một lớp, Điểm kiểm tra, Chăm sóc, Đề nghị và khiếu nại). Khuôn K06.
- KH-02 Phụ huynh (bản ghi): 3 màn PH-01 Tổng quan, PH-02 Chăm sóc, PH-03 Tài chính. Khuôn K06.
- KH-01 và KH-04 (danh sách): làm theo K03. Cột đề nghị: Mã, Họ tên, Khối (học sinh), Tình trạng, Cơ sở tiếp nhận, Đang học tại, SĐT phụ huynh (với KH-01: số con). Nếu thấy thiếu cột nào, hỏi anh, đừng tự thêm.
- KH-03 và KH-06 (biểu mẫu tạo/sửa): **bỏ phần Tạo**; chỉ còn Sửa. Hồ sơ sinh tự động từ cơ hội, phiếu test, đơn duyệt.
- KH-07 Gộp trùng: hộp thoại K08 như cũ, quyền Duyệt.

**2. Luật mới đã chốt, phản ánh vào giao diện**
- Không có nút **Tạo** và **Xuất** trên hồ sơ và danh sách (Xuất chỉ Admin, ẩn với vai trò khác). Trên hồ sơ chỉ có Sửa, Gộp, Tạo ticket.
- **Cơ sở tiếp nhận**: cố định, chỉ Admin sửa. **Đang học tại**: tự tính từ các lớp. Chuyển cơ sở qua đề nghị được duyệt.
- **Quỹ giờ riêng từng lớp** (HS-02): mỗi lớp một dòng với Giờ đăng ký, Đã học, Còn lại; Start Date, End Date (ngày hết phí). Học quá giờ bị chặn; chuyển giờ phải qua Đề nghị "Chuyển phí". Chuyển lớp, bảo lưu, dừng học xem ở tab "Đề nghị và khiếu nại".
- Mục tiêu là một ô chữ tự do. Mật khẩu học sinh không bao giờ hiển thị; ba nút Cấp tài khoản, Đặt lại mật khẩu, Khoá tài khoản nằm trên thanh nút, **mờ ở giai đoạn 1**.
- HS-04: cột "Nhận xét buổi học" chỉ là đường dẫn tới nhận xét của giáo viên (từ App Giáo viên); hồ sơ không lặp lại rubric hay lời nhắn.
- Số liệu căn phải, thẳng hàng trong mọi bảng số.
- Tab Học tập, Điểm danh, Tài chính hiện **mờ ở giai đoạn 1** (dữ liệu có từ giai đoạn 2, 3); vẽ trạng thái mờ đó bằng khuôn chung.

**3. Cách làm**
- Chỉ dùng thành phần và khuôn P0; chỗ nào wireframe cần cách tương tác mà khuôn chưa có (ví dụ bảng có nhóm cột, hàng gộp), **dừng, ghi rõ tên màn, khuôn gần nhất, chỗ thiếu và báo anh**, đừng tự chế.
- Khi nội dung wireframe và gói P0 đến P2 vênh nhau, ưu tiên wireframe, ghi chỗ vênh vào ghi chú.
- Dữ liệu mẫu là dữ liệu giả; không dùng tên, SĐT thật.
- Làm xong gửi anh duyệt trước; anh OK mới chuyển Code.
