---
id: ch6
ten: Tìm kiếm toàn hệ thống và chuông thông báo
vai: [chung]
phan_he: chung
ma_man: [CHUNG-11, CHUNG-12]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Tìm kiếm toàn hệ thống và chuông thông báo

**Làm xong bạn có:** mở nhanh được một bản ghi (học sinh, lead, đơn…) bằng cách gõ tên, mã hoặc số điện thoại; và đọc, xử lý được các thông báo gửi cho bạn.
**Ai làm:** mọi người đăng nhập cổng CRM. **Màn:** thanh trên cùng, ô **Tìm kiếm** và biểu tượng **chuông Thông báo**.

> Video: [VIDEO: thong-bao]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Bạn đã đăng nhập cổng CRM.
- [ ] Bạn biết một phần tên, mã, hoặc số điện thoại của bản ghi cần tìm.

## Luật cần nhớ (lời thường)
- Tìm **không cần gõ dấu** tiếng Việt; tìm theo tên, số điện thoại, mã mới hoặc mã cũ.
- Chữ gõ phải đủ **số ký tự tối thiểu** do Admin đặt ở tham số «Số ký tự tối thiểu để tìm» (QT-09). Chưa đủ thì chưa tìm.
- Kết quả **chỉ gồm bản ghi bạn được xem** (theo cơ sở và quyền). Không thấy bản ghi mà đồng nghiệp thấy là bình thường.
- Kết quả gom theo loại: Học sinh, Khách hàng, Lead, Cơ hội, Đơn hàng, Phiếu thu, Lớp, Nhân viên; mỗi loại có số dòng tối đa do Admin đặt.
- Thông báo **chỉ của riêng bạn**. Số chưa đọc tự làm mới khoảng mỗi phút.

## Các bước: tìm kiếm
1. Bấm vào ô **Tìm mọi thứ…** ở thanh trên cùng (điện thoại: bấm biểu tượng kính lúp **Tìm kiếm** để mở ô).
   [CHƯA CHỤP: cần staging; ảnh dự kiến chung-ch6-b1]
2. Gõ tên, mã hoặc số điện thoại.
   *Bạn thấy:* «Đang tìm…», rồi các nhóm kết quả «Học sinh · 2», «Lead · 1»…, mỗi dòng có tiêu đề và dòng phụ. Không có kết quả thì ghi «Không tìm thấy», kèm gợi ý thử mã, số điện thoại hoặc tên khác.
   [CHƯA CHỤP: cần staging; ảnh dự kiến chung-ch6-b2]
3. Chọn kết quả bằng chuột, hoặc phím **↓ / ↑** rồi **Enter**. **Esc** để đóng.
   *Bạn thấy:* mở đúng bản ghi (ví dụ lead mở màn lead, lớp mở màn lớp).

## Các bước: thông báo
1. Nhìn biểu tượng **chuông**. Có thông báo chưa đọc thì chuông ghi số (mô tả «Thông báo (N chưa đọc)»).
2. Bấm chuông.
   *Bạn thấy:* khung «Thông báo», hai nút lọc **Tất cả** và **Chưa đọc (N)**, nút **Đánh dấu tất cả đã đọc**, danh sách thông báo mới nhất.
   [CHƯA CHỤP: cần staging; ảnh dự kiến chung-ch6-b4]
3. Bấm một thông báo.
   *Bạn thấy:* thông báo thành đã đọc và hệ thống mở bản ghi liên quan (nếu có).
4. Đọc xong cả loạt: bấm **Đánh dấu tất cả đã đọc**.
   *Bạn thấy:* số chưa đọc về 0. Lọc «Chưa đọc» khi hết thì ghi «Không còn thông báo chưa đọc.»; chưa từng có thì «Chưa có thông báo.»

## Sau bước này
- **Bạn xem ở đâu:** làm việc tiếp trên bản ghi vừa mở; thông báo vẫn nằm trong danh sách (lọc «Tất cả»).

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Mở nhầm bản ghi từ kết quả | Quay lại bằng nút Trở lại của trình duyệt, tìm lại |
| Bấm «Đánh dấu tất cả đã đọc» quá sớm | Thông báo vẫn còn trong «Tất cả», mở lại từng cái từ đó; chưa có nút đánh dấu lại là chưa đọc |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| Không có gì hiện khi gõ | chữ chưa đủ số ký tự tối thiểu | Gõ thêm |
| «Không tìm thấy» | không có bản ghi khớp trong phạm vi bạn xem | Thử mã, số điện thoại hoặc tên khác; nhớ rằng bản ghi ở cơ sở khác có thể ngoài quyền xem của bạn |
| Câu lỗi màu đỏ trong khung kết quả | lỗi mạng hoặc máy chủ | Thử lại; không hết thì báo Admin |
| «Chưa có thông báo.» | chưa có ai gửi thông báo cho bạn | Không cần làm gì |

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản tập bất kỳ (ví dụ `sale.cs5`) trên **staging**. Vai Vận hành tập tạm bằng quyền CSKH (anh Trường chốt 24/11).
- **Dùng:** gõ một phần tên học sinh mẫu không dấu, chọn kết quả; mở chuông, lọc «Chưa đọc», bấm một thông báo.
- Chưa có trong bộ mẫu: thông báo sẵn cho tài khoản tập (nếu chuông trống, nhờ người khác giao việc hoặc duyệt cho bạn để sinh thông báo).

## Tự kiểm: bạn làm được khi
- [ ] Bạn tìm được một học sinh mẫu bằng tên không dấu và mở đúng màn.
- [ ] Bạn nói được vì sao đồng nghiệp tìm thấy bản ghi mà bạn không thấy.
- [ ] Bạn đánh dấu tất cả đã đọc và thấy số chưa đọc về 0.
