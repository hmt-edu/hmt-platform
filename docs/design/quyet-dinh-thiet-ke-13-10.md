> **Ghi chú của anh Trường (16/10/2026), đọc trước:** chỉ các quyết định về **giao diện, màu, thương hiệu, khuôn** trong file này còn hiệu lực. **Mục 1 (quy trình wireframe, bốn cổng duyệt) đã cũ**: quy trình hiện hành theo `docs/quy-trinh-phoi-hop.md` và `docs/lo-trinh-phan-he.md`.

# Quyết định thiết kế 13/10/2026 (anh Trường chốt)

File này ghi các quyết định mới về cách làm thiết kế kiểu Odoo. Khi vênh với `00-quy-trinh-phoi-hop.md` (mục 4 và 5) hoặc `ban-do-man-hinh.md` thì làm theo file này. Chưa là luật nghiệp vụ; luật chỉ vào `docs/spec/` khi anh nói "OK ĐƯA VÀO LUẬT".

## 1. Quy trình mới: từng phân hệ, bốn cổng duyệt
Làm theo từng phân hệ (giai đoạn 0 đến 5). Mỗi phân hệ đi qua 4 cổng, chưa qua cổng nào thì không sang bước sau:
1. **Wireframe**: Claude Chat vẽ trong artifact "Wireframe HMT kiểu Odoo". Anh duyệt.
2. **Thiết kế**: Claude Design làm đẹp trên nền wireframe đã duyệt. Mỗi lần giao tối đa 5 màn. Không đổi bố cục, không bỏ tính năng, chỉ làm đẹp. Anh duyệt.
3. **Code**: Claude Code dựng. Mỗi PR có bản xem trước và mục "Anh kiểm". Anh bình luận "OK" trên PR.
4. **Staging**: anh thử, rồi cập nhật bản chạy thật qua `hmt-deploy`.

Quy tắc kèm theo:
- Khoá khuôn trước: K1–K5 duyệt thiết kế một lần ở giai đoạn 0. Các phân hệ sau chỉ thêm màn đặc trưng và danh sách cột, trường; không vẽ lại khuôn.
- 151 màn chỉ là cấu hình của khuôn không vẽ, không wireframe. Claude Code dựng từ danh sách cột, trường theo luật; anh kiểm trên staging.
- Chạy gối đầu: lúc anh duyệt wireframe phân hệ N+1, Claude Code có thể đang code phân hệ N.
- Bộ thiết kế cũ `design/hmt-platform/` (P5) sẽ bị thay bằng bản Odoo. Claude Code không dựng giao diện mới khi chưa có "thiết kế đã duyệt".
- Claude Design chạy ở cùng tài khoản đang dùng; bỏ qua tài khoản có bộ "Hoà Ma Toán" cũ.
- **(13/10 chiều)** Trước khi giao màn cho Claude Design làm đẹp, làm bộ nhận diện trước: việc 1 chốt mã màu từ logo, việc 2 tạo bộ nhận diện và hệ thiết kế. Prompt ở `HMT/prompt/claude-design-thuong-hieu.md`.

## 2. Con số và tiến độ wireframe
Cần thiết kế 26: 11 khuôn (K1–K11) + 15 màn đặc trưng (Đ1–Đ15). 169 màn cũ không vẽ: 151 cấu hình + 11 bộ lọc lưu sẵn + 7 báo cáo Looker Studio. 28 màn cũ được thay bằng 26 thiết kế này.
Anh chọn vẽ wireframe đủ cả 26 (không bỏ K6, K7, K8).

| Giai đoạn | Wireframe | Tình trạng |
|---|---|---|
| 0 Chung, Quản trị | K1, K2, K3 | Đã duyệt |
| 0 Chung, Quản trị | K4, K5, K6, Đ1, Đ11 | **Đã duyệt 13/10** |
| 0 Chung, Quản trị | K7 | Claude Code đã code trang đăng nhập, anh thấy đẹp, không vẽ lại (chỉ để đối chiếu) |
| 0 Chung, Quản trị | Đ9 | **Bản tạm, ưu tiên sau.** Trang chỉ tập trung nhắc việc; làm lại cùng các màn nhắc việc và báo cáo sau khi xong các chức năng chính |
| 1 Tuyển sinh, Bán hàng, Thu chi | Đ2, Đ3, K8 | Chưa vẽ |
| 2 Đào tạo | Đ4, Đ5, Đ6, Đ7, Đ8 | Chưa vẽ |
| 3 Giáo viên | K9, K10, K11, Đ12, Đ13 | Chưa vẽ |
| 4 Học tập, Phụ huynh | Đ14, Đ15 | Chưa vẽ |
| 5 Báo cáo | Đ10 | Chưa vẽ |

## 3. Cổng CRM: 9 menu (đã duyệt)
Tổng quan · Tuyển sinh · Khách hàng · Bán hàng & thu chi · Đào tạo · Chăm sóc KH · Báo cáo · Cấu hình · Quản trị.
- Giáo viên, trợ giảng nằm ở Đào tạo.
- Công nợ, Số dư khách hàng, Nhận xét chờ gửi phụ huynh không có mục menu riêng, chỉ là bộ lọc lưu sẵn.
- Danh mục, Tham số, Công tắc tính năng nằm ở Cấu hình. Quản trị giữ người dùng, vai trò và quyền, cơ sở và phòng, tài khoản học sinh và phụ huynh, nhật ký.
- Báo cáo trong app chỉ có 4 màn; 7 báo cáo còn lại mở sang Looker Studio.
- Bản đầy đủ từng mục nằm ở artifact "HMT - Danh sách màn hình kiểu Odoo", tab "Bản đồ theo phân hệ".

## 4. Khuôn Tổng quan và Chi tiết (đã duyệt wireframe)
- Sidebar: đầu sidebar nền trắng ghi tên cổng (CRM, LMS, App Giáo viên); thân tối; menu 2 tầng; nút mở rộng/thu gọn tất cả; cuộn dọc; nút « thu gọn còn icon.
- Chi tiết: **có nút Sửa** (đổi quy tắc 12/10 "sửa trực tiếp, không nút Sửa"); bấm Sửa thì các ô thành ô nhập, nút đổi thành Lưu / Huỷ.
- **Bấm Tạo mở thẳng khuôn Chi tiết ở trạng thái trống cho mọi đối tượng**, bỏ kiểu "biểu mẫu tạo" riêng. Giai đoạn, smart button, ghi chú mờ cho đến khi lưu.
- Thanh giai đoạn chỉ ở bản ghi có giai đoạn. Giai đoạn đã qua bị khoá.
- 4 kiểu chuyển giai đoạn: Đổi ngay (thông báo + Hoàn tác) · Hỏi thêm (hộp chọn sub-stage + ghi chú) · Cần đủ điều kiện (hộp chặn liệt kê chỗ thiếu + nút đi tới ô cần điền) · Hệ thống tự đổi (ổ khoá + lý do).
- Anh đồng ý đề xuất của Claude cho 4 câu còn mở: bộ lọc thông minh, sao ưu tiên và nút Theo dõi, màu topbar (nền trắng như wireframe), và phạm vi các câu còn lại trong tab "Khuôn và thiết kế cần vẽ" của artifact danh sách màn hình.

## 5. Thuật ngữ
Giữ tiếng Anh cho khung Odoo: Sidebar, Topbar, Header, Toolbar, Stage, Sub-stage, Smart button, Filters, Group By, Favorites, Source, Sub-source, **Calendar** (anh chốt 13/10, thay cho "Lịch"). Từ nghiệp vụ HMT dùng tiếng Việt. Nút hành động dùng tiếng Việt. Cột phải ghi tên **"Ghi chú & hoạt động"** (không dùng Lognote & Activity).
Nhãn vùng như GIAI ĐOẠN, NÚT NGHIỆP VỤ, THÔNG TIN trên wireframe chỉ để anh đọc, không đưa lên hệ thống.
Wireframe còn một số chỗ ghi "Lịch" (menu, tiêu đề màn): cần đổi thành "Calendar" khi làm đẹp.

## 6. Màu (đã chốt 13/10 chiều, sau việc Brand Color Discovery)
- Màu cam chính thức của HMT: **#EF6926** (đọc từ file SVG logo; wireframe tạm dùng #EF6925). Logo không đổi, giữ cả dòng "18+ năm kinh nghiệm luyện thi".
- **Nút chính:** nền #CB4D0E (brand-600), chữ trắng. Cam logo #EF6926 dùng cho logo, Stage đang chọn, icon, điểm nhấn (chữ trắng trên cam logo chỉ đạt 3,13:1).
- Chữ cam và link dùng #AB420F (thay #B5440F của wireframe). Nút Huỷ, Từ chối, Xoá dạng viền, không dùng nền đỏ đặc cạnh nút cam. Viền ô nhập #8A8076, đường kẻ bảng và khối #E3DDD5. Icon cảnh báo vàng #7A5C00.
- Bảng màu đầy đủ (thang cam 50 đến 900, 4 màu trạng thái, trung tính ấm) nằm trong hệ thiết kế "HMT Platform" của Claude Design: `claude.ai/artifact/FJx7TsZfJ3jaNwfjm5TTeu`.
- Chỉ làm giao diện sáng. Font Inter cho giao diện và số, Be Vietnam Pro cho tiêu đề. Icon Lucide nét 1,5px.

## 7. Việc Claude Code (sau khi anh gửi)
Dừng bắt đầu PR giao diện mới; PR đang mở làm cho xong và chờ OK; phần không phụ thuộc giao diện (cơ sở dữ liệu, quyền, kiểm thử, logic đăng nhập) làm tiếp; cập nhật `docs/TIEN-DO.md`.

## 8. Báo cáo và trang chủ (13/10 chiều)
- **Tách trang chủ và báo cáo.** Đ9 Trang chủ CRM chỉ nhắc việc (thẻ số việc HÔM NAY / QUÁ HẠN, bộ lọc thời gian chỉ áp dụng cho thẻ số việc, hai danh sách chi tiết theo vai). KPI, tỷ lệ chuyển đổi, biểu đồ làm ở wireframe Báo cáo sau. Anh sẽ làm kỹ phần báo cáo.
- **Khái niệm đã chốt cho báo cáo:** "Doanh thu thu được" = tiền đã thu và kế toán duyệt, tính theo **ngày kế toán duyệt**. Học sinh mới = tính khi ghi danh sinh, học sinh chưa từng học. Tỷ lệ chuyển đổi tính **luỹ kế** theo giai đoạn hiện tại của cơ hội (cơ hội chỉ đi tới), kỳ lọc theo ngày tạo cơ hội; "đã đạt Lk" nghĩa là đang ở giai đoạn từ Lk trở lên (công thức cần anh xác nhận lại, xem ghi chú dưới).
- **Chưa chốt (hỏi lại khi vẽ báo cáo):** công thức luỹ kế (anh viết (L1..L4)/(L1..L8), em đề xuất (L4..L8)/(L1..L8)); ASP bán mới chia cho số học sinh mới hay số đơn bán mới; dashboard theo vai (Tuyển sinh, Trưởng cơ sở, CSKH) làm trong app hay Looker (em đề xuất trong app vì cần giới hạn dữ liệu theo cơ sở, nhân sự).
- Bản dashboard KPI dựng thử (Tuyển sinh, Trưởng cơ sở có lọc nhân sự, CSKH) đã lưu riêng để dùng làm nền cho wireframe Báo cáo.
