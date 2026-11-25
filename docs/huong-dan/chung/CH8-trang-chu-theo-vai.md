---
title: Trang chủ theo vai
slug: chung-trang-chu
group: bat-dau
order: 28
role: Mọi người
portals: [crm]
priority: P1
flow: CH8
screens: [CHUNG-14]
---

# Trang chủ theo vai

**Làm xong bạn có:** đọc được trang chủ «Việc của tôi hôm nay» và biết bấm vào đâu để xử lý việc đang chờ.
**Ai làm:** mọi người dùng cổng CRM. Cổng Giáo viên có màn «Hôm nay» và «Cần làm» riêng.

> Video: [VIDEO: ch8]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Luật cần nhớ
- Mỗi khối chỉ hiện việc **thuộc quyền của bạn** và thuộc phân hệ đang bật ở cơ sở. Đồng nghiệp khác vai có thể thấy khối khác: không phải lỗi.
- Khối chưa có dữ liệu thì không hiện thẻ trống hay số giả.

## Các khối có thể thấy
| Khối | Hiện với ai | Cho biết gì |
|---|---|---|
| Lịch hẹn | Người xem được lịch hẹn | Số lịch «Hôm nay» và «Quá hạn», danh sách lịch cần làm, nút «Mở danh sách» |
| Việc chờ tôi duyệt | Người có quyền duyệt | Các việc đến lượt bạn duyệt |
| Buổi chưa hoàn tất | Người xem buổi học | Buổi đã diễn ra nhưng chưa hoàn tất |
| Lớp chờ duyệt | Người duyệt lớp | Lớp đã trình, chờ bạn duyệt |
| Ticket quá hạn | Người xem ticket | Ticket quá hạn xử lý, ai đang giữ |
| Buổi hôm nay | Người xem buổi, khi phân hệ điểm danh trong ngày bật | Lịch buổi hôm nay, buổi chưa ghi điểm danh tô đỏ |
| Công nợ quá hạn | Người xem đơn hàng | Các khoản công nợ đã quá hạn |

## Các bước
1. Đăng nhập, hệ thống mở «Trang chủ» với tiêu đề «Việc của tôi hôm nay» và ngày hôm nay.
   [ẢNH: viec-cua-toi-hom-nay]
2. Đọc từng khối; mỗi dòng cho biết một việc. Bấm dòng để mở bản ghi liên quan.
3. Khối nào ghi «Không có … nào …» (ví dụ «Không có việc nào chờ bạn duyệt.») nghĩa là bạn không còn việc loại đó.
4. Quay lại trang chủ bằng «Trang chủ» ở menu «Tổng quan» để thấy số mới nhất.

## Admin: xem thử vai trò
Admin có nhóm «Xem thử vai trò» ở đầu trang: «Của tôi» và từng vai. Chọn một vai để xem trang chủ **trông như thế nào** với vai đó (hiện dòng «Đang xem thử bố cục của vai trò …»). Chỉ đổi khối nào hiện; số liệu vẫn theo quyền thật của bạn.

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| «Chưa có mục nhắc việc nào cho bạn.» | Vai của bạn chưa có khối nào, hoặc phân hệ tắt | Bình thường với vai chỉ dùng menu; cần thì hỏi quản trị viên |
| «Không tải được lịch hẹn» | Lỗi mạng | Bấm «Thử lại» |
| «Không tải được quyền của vai trò này. Thử lại sau.» | Admin đang xem thử vai | Thử lại sau |

## Hỏi đáp
- **Tại sao tôi không thấy khối «Công nợ quá hạn»?** Khối chỉ hiện với người xem được đơn hàng ở phân hệ bán hàng đang bật.
- **Số trên trang chủ có tự cập nhật không?** Tải lại trang (hoặc về lại «Trang chủ») để lấy số mới.
