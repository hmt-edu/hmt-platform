# HMT Hồ sơ 360°: ghi chú cho Code (canvas riêng, 27/11/2026)

Canvas này gồm hồ sơ phụ huynh (KH-02) và hồ sơ học sinh (KH-05) bản 360°. Canvas HMT Platform (9933) đã đầy nên các khung mới nằm riêng ở đây.

## Dùng khung nào
- **Hồ sơ phụ huynh và học sinh:** Code dựng theo các khung KH02_* và KH05_* trong canvas này, **không dựng theo khung KH02, KH05 cũ ở 9933**. 9933 giữ khung cũ để đối chiếu, không đổi nhãn.
- **Khối «Tài khoản app học sinh»:** dùng khung KH05_tk_*, KH05_dt_tk_*. Khối ở KH05 cũ (9933) còn bị làm mờ kèm câu «làm ở phân hệ sau»: **bỏ**, không dựng theo.
- Khung có ở cả hai canvas thì bản ở canvas này thắng; chỗ vênh luật thì làm theo luật.
- KH02_cac_con (thẻ từng con) giữ nguyên ở 9933, không vẽ lại.

## Danh sách khung (33)
| Khung | Nội dung |
|---|---|
| KH02_360, _360_khong_co, _360_an_tien | Phụ huynh: Làm nhanh, thẻ tóm tắt, cờ cảnh báo; không có cờ; không có quyền xem tiền |
| KH02_ghi_nhan_lien_he, KH05_dt_ghi_nhan | Hộp «Ghi nhận liên hệ» |
| KH02_tai_khoan | Tab Tài khoản phụ huynh |
| KH02_tai_tuc(_trong), KH02_lich_hen(_trong) | Tab Tái tục, Lịch hẹn của phụ huynh |
| KH05_360, _360_khong_co | Học sinh: Tổng quan, 8 tab |
| KH05_tai_tuc(_trong), KH05_lich_hen | Tab Tái tục, Lịch hẹn của học sinh |
| KH05_tk_chua_co, _hoat_dong, _da_khoa | Tài khoản app: Chưa có / Đang hoạt động / Đã khoá |
| KH05_tk_khong_quyen | Không có quyền QT-13: ẩn cả khối nút |
| KH05_tk_hop_cap, _hop_dat_lai, _hop_khoa, _hop_mo_khoa | Hộp xác nhận của bốn nút |
| KH05_tk_hop_cap_ket_qua | Hộp «Mật khẩu tạm» (hiện một lần) sau khi Cấp hoặc Đặt lại |
| KH02_dt, KH02_dt_tai_tuc, KH05_dt | Điện thoại 390×844 |
| KH05_dt_tk_* | Điện thoại: tài khoản app học sinh, hộp xác nhận là tấm trượt |

## Tài khoản app học sinh (anh Trường chốt 27/11)
- Ba trạng thái và nút: Chưa có tài khoản → **Cấp tài khoản**. Đang hoạt động → **Đặt lại mật khẩu**, **Khoá tài khoản**. Đã khoá → **Mở khoá tài khoản**. Nút ở đầu hồ sơ khớp nút trong khối.
- Quyền QT-13 cho cả bốn thao tác. Không có QT-13: ẩn cả khối nút, chỉ có dòng ghi chú.
- Mỗi nút có hộp xác nhận ngắn.
- **Mật khẩu tạm hiện đúng một lần** sau khi Cấp hoặc Đặt lại, không xem lại được. Ngoài thời điểm đó, ô Mật khẩu luôn «Không hiển thị».
- **Cần sửa luật R-CRM-32:** (1) thêm ngoại lệ «mật khẩu tạm hiện một lần»; (2) thêm thao tác **Mở khoá tài khoản** (QT-13, ghi nhật ký). Khung vẽ theo quyết định mới này; luật ở `docs/spec/` Code cập nhật theo.
- Mật khẩu trong khung (Kx7-4mQ2-Rt9) là dữ liệu giả.

## Luật thể hiện
- Các nút số (Ghi danh, Ticket mở, Phiếu thu…) bấm được, số khớp thẻ tóm tắt.
- Cờ bấm mở đúng tab: Nợ quá hạn → Tài chính; Ticket quá hạn → Ticket (học sinh: Đề nghị & khiếu nại); Sắp hết giờ → Tái tục; Lâu chưa liên hệ → dòng thời gian lọc «Liên hệ»; Thiếu nhận xét → Các con (học sinh: Điểm danh).
- Nhận xét buổi chỉ là đường dẫn (R-CRM-31): tab Điểm danh chỉ có «Xem nhận xét».
- Một phụ huynh chính + SĐT 2 + người thân; không vẽ nhiều người giám hộ.
- Ngưỡng «lâu chưa liên hệ», «sắp hết giờ» là tham số cấu hình (HS-PH-360 mục 6.3), số trong khung chỉ minh hoạ.
- Tên, số điện thoại, số tiền, số buổi trong khung là dữ liệu giả, không chép vào code hay test.

## Chữ tạm (Design soạn, chưa duyệt)
Tên cờ; các lựa chọn Kết quả liên hệ (Nghe máy, Không nghe máy, Hẹn gọi lại, Từ chối); câu «Không có cảnh báo nào», «Chưa có phiếu tái tục», «Chưa có lịch hẹn»; câu ẩn tiền; chữ trong bốn hộp xác nhận và dòng ghi chú khi không có quyền.

## Khuôn mới đề xuất (chưa có trong P0/K06)
Thẻ tóm tắt đầu hồ sơ; hàng cờ cảnh báo; hàng Làm nhanh; hộp «Ghi nhận liên hệ» (theo K08); thẻ bảng trên điện thoại (tab cuộn ngang, bảng thành thẻ xếp dọc); tấm trượt dưới cùng.

## Chưa vẽ / chưa chắc
- Báo giá của phụ huynh: đề xuất gộp vào tab Đơn hàng (cột Loại), chưa vẽ.
- Tệp giấy tờ; «Sức khoẻ học sinh» ba mức kèm lý do: cần luật trước, chưa vẽ.
- Tab Tài chính dùng khung Kế toán KH02_kt hiện có ở 9933.
- Dòng thời gian giữ 4 nút lọc; Vắng, Thu tiền, Ticket xếp dưới «Hệ thống».
