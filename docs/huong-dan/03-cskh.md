---
title: Vai: CSKH và vận hành lớp
slug: theo-vai-cskh
group: vai
order: 50
role: CSKH và vận hành lớp
portals: [crm]
---

# Vai: CSKH và vận hành lớp (cổng CRM)

Vai: chăm sóc khách hàng (CSKH) và vận hành lớp. Nếu bạn mới, đọc trước [Giới thiệu hệ thống](/crm/huong-dan/bat-dau). Chữ trong dấu «…» là chữ hiện trên màn.

**Vai «Vận hành» (tạm thời):** hệ thống chưa có vai Vận hành riêng. Người làm vận hành lớp dùng **vai CSKH** và có đúng quyền của CSKH; các tài khoản tập «Vận hành 1…3» (vh1, vh2, vh3) cũng được gán vai CSKH. Khi có vai Vận hành riêng, bài này sẽ cập nhật.

Menu của bạn: **Khách hàng** (Phụ huynh, Học sinh), **Đào tạo** (Ghi danh, Lớp, Buổi học, Điểm danh trong ngày), **Chăm sóc KH** (Tất cả ticket, Phiếu nghiệp vụ). Chỉ hiện mục bạn có quyền. Phân hệ chưa bật ở cơ sở của bạn sẽ báo «Phân hệ chưa bật».


## Việc hằng ngày của bạn (gợi ý thứ tự)

1. Mở **Tất cả ticket**, bấm lọc «Quá hạn» rồi «Sắp quá hạn»: xử lý việc trễ trước.
2. Bấm lọc «Của tôi» để xem việc được giao riêng cho bạn.
3. Mở **Điểm danh trong ngày**: gọi nhắc em chưa tới hoặc vắng.
4. Mở **Ghi danh**, hàng chờ «Chờ xếp lớp»: xếp lớp cho em mới.
5. Cuối ngày mở **Phiếu nghiệp vụ**: phiếu đã duyệt đang chờ bạn bấm «Thực hiện».

## 1. Tìm khách và xem hồ sơ

**Mục tiêu:** tìm phụ huynh hay học sinh và xem toàn cảnh một em trước khi trả lời họ.

1. Vào **Phụ huynh** hoặc **Học sinh** ở menu Khách hàng.
2. Gõ tên hoặc số điện thoại vào ô tìm; lọc thêm theo tình trạng, khối, lớp nếu cần.
3. Bấm một dòng để mở hồ sơ. Hồ sơ phụ huynh có các con, đơn, phiếu thu, số dư, ticket. Hồ sơ học sinh có ghi danh, quỹ giờ, lớp đang học, điểm danh, nhận xét, bài tập, ticket.

- **Kết quả:** thấy đúng khách của cơ sở mình. Không có nút xuất tệp (chỉ quản trị).
- **Lỗi thường gặp:** không thấy khách thì kiểm cơ sở và bộ lọc; báo «không có quyền» nghĩa là khách thuộc cơ sở khác.
- **Ảnh:** [ẢNH: phu-huynh-ds], [ẢNH: hoc-sinh-ho-so]

## 2. Xếp lớp cho ghi danh

**Mục tiêu:** đưa ghi danh đang chờ vào đúng lớp.

1. Vào **Ghi danh**, chọn hàng chờ «Chờ xếp lớp» (chỉ gồm ghi danh chưa có lớp).
2. Mở một ghi danh, bấm **«Xếp lớp»**.
3. Chọn lớp đã duyệt (theo nhóm lớp hoặc từng lớp) và ngày vào lớp, rồi xác nhận.
4. Kiểm lại ở «Dòng xếp lớp» (lớp, ngày vào, ngày rời) và «Quỹ giờ» (giờ cấp, giờ tặng, còn lại). Bấm **«Sổ giờ»** để xem từng dòng cộng trừ giờ (chỉ xem).

- **Kết quả:** ghi danh sang «Đã xếp lớp», lớp hiện thêm học sinh, chỗ trống của lớp giảm.
- **Lỗi thường gặp:** lớp không hiện trong danh sách là do chưa duyệt, hết chỗ hoặc sai môn, khối, cơ sở (chọn lớp khác). Báo trùng giờ nghĩa là em đã có lớp trùng giờ (đổi lớp hoặc ngày vào). Xếp xong vẫn «Chờ xếp lớp»: tải lại trang, nếu vẫn vậy thì báo quản trị kèm mã ghi danh.
- **Ảnh:** [ẢNH: ghi-danh-cho-xep], [ẢNH: ghi-danh-xep-lop], [ẢNH: ghi-danh-so-gio]
- Điều chỉnh giờ («Điều chỉnh giờ») là việc của quản lý cơ sở, Kế toán và Admin (cộng hoặc bớt), xem [bài Trưởng cơ sở](/crm/huong-dan/theo-vai-truong-co-so).

## 3. Tạo lớp và trình duyệt

**Mục tiêu:** lập lớp mới để quản lý cơ sở duyệt.

1. Vào **Lớp**, bấm tạo lớp.
2. Điền môn, khối, loại, sĩ số tối đa, ngày khai giảng, tổng số buổi. Thêm thời khoá biểu: thứ, giờ, giáo viên, phòng.
3. Bấm **«Lưu nháp»**: lớp ở «Nháp».
4. Ở bản ghi lớp bấm **«Trình»**. Quản lý cơ sở xác nhận và duyệt; duyệt xong lớp tự sinh các buổi học.

- **Kết quả:** lớp từ Nháp sang Đã trình, sau duyệt có buổi. Chỉ sửa được khi lớp ở Nháp hoặc Từ chối.
- **Lỗi thường gặp:** thiếu thời khoá biểu thì không duyệt được (câu lý do hiện ngay trên màn). Trùng phòng hoặc giáo viên chỉ cảnh báo, không chặn.
- **Ảnh:** [ẢNH: lop-tao], [ẢNH: lop-trinh]

## 4. Điểm danh vận hành và theo dõi buổi học

**Mục tiêu:** biết hôm nay em nào chưa tới, gọi nhắc và ghi lại đã liên hệ thế nào.

1. Vào **Điểm danh trong ngày**: danh sách buổi hôm nay, em chưa tới hoặc vắng.
2. Ghi trạng thái phía vận hành và **lý do liên hệ** (ví dụ không nghe máy, đã nhắc). Có thể ghi cho nhiều em một lúc.
3. Mở **Buổi học**, vào một buổi: hai cột «Trung tâm điểm danh» và «Điểm danh giáo viên (chính thức)». Dòng «Lệch» đánh dấu hai bên khác nhau.
4. Cần thêm em học thử vào buổi thì bấm «Thêm học thử». Cần chốt danh sách thì bấm «Chốt danh sách».

- **Kết quả:** điểm danh vận hành lưu riêng. Giáo viên quyết định điểm danh chính thức ở cổng giáo viên.
- **Lỗi thường gặp:** không sửa được điểm danh chính thức (việc của giáo viên). Sửa sau khi buổi đã hoàn tất do quản lý cơ sở làm bằng «Sửa điểm danh».
- **Ảnh:** [ẢNH: diem-danh-trong-ngay], [ẢNH: buoi-ban-ghi]

## 5. Tạo và xử lý ticket

**Mục tiêu:** ghi nhận đề nghị hay khiếu nại của phụ huynh và xử lý đúng hạn.

1. Vào **Tất cả ticket**. Lọc theo Đề nghị, Khiếu nại, Chờ đóng, Sắp quá hạn, Quá hạn, Của tôi. Có thể đổi sang bảng kéo (Kanban) để xem theo bước.
2. Bấm tạo ticket: chọn loại, kênh, người gửi, nhóm và nhóm con, học sinh (nếu có), mô tả. Lưu.
3. Mở ticket. Bấm «Giao ticket» để chọn đội và người phụ trách. «Phân loại lại» đổi loại, nhóm, mức độ.
4. Đẩy ticket đi theo thanh trạng thái: Mới, Đã giao, Đang xử lý, Đã xử lý, Đã đóng.
5. Chuyển «Đã xử lý» phải ghi **Kết quả**. Huỷ phải ghi lý do (nút «Huỷ ticket»). Đóng khiếu nại phải chọn mức hài lòng từ 1 đến 5.

- **Kết quả:** ticket có mã và hạn xử lý theo loại và mức độ; dòng thời gian ghi mọi thay đổi.
- **Lỗi thường gặp:**

| Câu trên màn | Làm gì |
|---|---|
| «Chuyển sang Đã xử lý cần ghi kết quả.» | điền ô Kết quả |
| «Huỷ ticket cần ghi lý do.» | điền lý do huỷ |
| «Đóng khiếu nại cần ghi mức hài lòng của phụ huynh từ 1 đến 5.» | chọn mức 1 đến 5 |
| «Đã quá số ngày cho phép mở lại ticket.» | tạo ticket mới |

- **Mở lại ticket đã đóng:** bấm bước «Đang xử lý» trên thanh trạng thái, hộp «Mở lại ticket» bắt buộc ghi lý do, rồi bấm «Mở lại» (chỉ trong số ngày cho phép).
- **Ảnh:** [ẢNH: ticket-ds], [ẢNH: ticket-kanban], [ẢNH: ticket-ban-ghi], [ẢNH: ticket-doi-trang-thai]

## 6. Khiếu nại

**Mục tiêu:** xử lý khiếu nại có xác minh, phương án và phụ huynh xác nhận trước khi đóng.

1. Tạo ticket loại Khiếu nại (bài 5), chọn nhóm và nhóm con đúng nội dung.
2. Giao cho người phụ trách. Người xử lý ghi xác minh và phương án vào ghi chú của ticket.
3. Liên hệ phụ huynh, nghe phụ huynh xác nhận phương án.
4. Chuyển «Đã xử lý» kèm Kết quả, rồi đóng ticket: chọn **mức hài lòng từ 1 đến 5**.
5. Phụ huynh chưa hài lòng sau khi đóng: mở lại trong số ngày cho phép, hoặc bấm «Nâng cấp» để chuyển người cao hơn xử lý.

- **Kết quả:** khiếu nại có đủ dấu vết xử lý; số liệu hài lòng đi vào báo cáo.
- **Lỗi thường gặp:** quên mức hài lòng khi đóng (xem bảng ở bài 5). Khách muốn rút lại thì dùng «Khách huỷ» và ghi lý do.
- **Ảnh:** [ẢNH: khieu-nai-tao], [ẢNH: khieu-nai-dong]

## 7. Phiếu nghiệp vụ: cách làm chung

**Mục tiêu:** làm thay đổi thật (sửa hồ sơ, bảo lưu, chuyển lớp, chuyển phí, dừng học, hoàn học phí, đổi lịch) qua một phiếu có người duyệt, không sửa tay.

Mỗi phiếu đi qua: **Nháp → Chờ duyệt → Đã duyệt → Đã thực hiện**. Nhánh khác: «Từ chối» (bắt buộc lý do) và «Huỷ phiếu». Phiếu liên quan tiền có hai cấp duyệt: quản lý cơ sở rồi kế toán. Người tạo phiếu không tự duyệt phiếu của mình.

1. Mở ticket có nhóm con gắn nghiệp vụ, bấm **«Tạo phiếu»**. Mỗi ticket chỉ có một phiếu đang mở.
2. Chọn loại phiếu nếu hộp hỏi, điền các ô (xem từng loại ở các bài dưới) và lý do. Lưu.
3. Mở phiếu ở **Phiếu nghiệp vụ**, kiểm lại thông tin, bấm **«Gửi duyệt»**.
4. Chờ các cấp duyệt. Xem bảng «Duyệt» trong phiếu: từng cấp, người duyệt, kết quả, giờ.
5. Phiếu «Đã duyệt» thì CSKH (hoặc Trưởng cơ sở) bấm **«Thực hiện»**. Hộp «Thực hiện phiếu?» nhắc: hồ sơ sẽ được cập nhật theo nội dung phiếu, ticket chuyển sang «Đã xử lý», và **không hoàn tác bằng nút**. Bấm «Thực hiện» để xác nhận.
6. Nếu phiếu «Từ chối»: đọc lý do rồi tạo **phiếu mới** từ ticket gốc (phiếu đã từ chối không gửi lại được). Nhập nhầm thì bấm «Huỷ phiếu»; phiếu không xoá được, chỉ chuyển sang Huỷ.

- **Kết quả:** phiếu «Đã thực hiện»; ticket tự sang «Đã xử lý», người phụ trách đóng tay.
- **Lỗi thường gặp:**

| Tình huống | Làm gì |
|---|---|
| Ticket đã có phiếu đang mở | xong hoặc huỷ phiếu đó trước |
| Báo thiếu ghi danh, lý do, số tháng, lớp mới… | điền đủ rồi lưu lại |
| Bạn là người tạo mà bấm duyệt | nhờ quản lý hoặc kế toán duyệt |
| Phiếu chưa duyệt mà bấm «Thực hiện» | chờ đủ các cấp duyệt |
| «Phân hệ chưa bật» ở cơ sở | báo quản lý cơ sở hoặc quản trị |

- **Ảnh:** [ẢNH: phieu-tao-tu-ticket], [ẢNH: phieu-gui-duyet], [ẢNH: phieu-duyet-hai-cap], [ẢNH: phieu-thuc-hien]

## 8. Phiếu Cập nhật hồ sơ

**Mục tiêu:** sửa thông tin hồ sơ khách (ví dụ số điện thoại, tên) có người duyệt.

1. Làm bước 1 đến 2 của bài 7, chọn loại «Cập nhật hồ sơ».
2. Chọn hồ sơ cần sửa và điền giá trị mới cho từng trường được phép sửa.
3. Gửi duyệt, chờ duyệt, bấm «Thực hiện».

- **Kết quả:** hồ sơ đổi đúng như phiếu; lịch sử còn trong nhật ký.
- **Lỗi thường gặp:** trường không có trong danh sách thì không sửa qua phiếu được; hỏi quản trị.
- **Ảnh:** [ẢNH: phieu-cap-nhat-ho-so]

## 9. Phiếu Bảo lưu (kèm gia hạn, tiếp tục học)

**Mục tiêu:** tạm dừng học một thời gian mà vẫn giữ giờ còn lại.

1. Làm bước 1 đến 2 của bài 7, chọn «Bảo lưu» (hộp có ô «Hình thức»: bảo lưu mới, gia hạn bảo lưu, tiếp tục học).
2. Chọn **Ghi danh**, **Lý do** (từ danh mục), **Số tháng bảo lưu** (hoặc «Số tháng gia hạn» khi gia hạn).
3. Gửi duyệt, chờ duyệt, bấm «Thực hiện».

- **Kết quả:** ghi danh sang «Bảo lưu», giờ còn lại được giữ. Gia hạn và tiếp tục học áp dụng cho ghi danh đang bảo lưu.
- **Lỗi thường gặp:** chọn ghi danh không phù hợp (ví dụ đã hết hiệu lực) thì hệ thống chặn kèm câu lý do.
- **Ảnh:** [ẢNH: phieu-bao-luu-tao], [ẢNH: phieu-bao-luu-gia-han]

## 10. Phiếu Chuyển lớp (và chuyển cơ sở)

**Mục tiêu:** chuyển học sinh sang lớp khác hoặc sang cơ sở khác.

1. Làm bước 1 đến 2 của bài 7, chọn «Chuyển lớp».
2. Chọn **Ghi danh**, **Loại chuyển**, **Lý do**.
3. Chuyển trong cơ sở: chọn **Lớp mới** và **Hiệu lực từ buổi**.
4. Chuyển cơ sở: chọn **Cơ sở mới**. Lớp mới do quản lý cơ sở đích chọn ở cấp duyệt của họ.
5. Gửi duyệt, chờ duyệt; duyệt xong CSKH (hoặc Trưởng cơ sở) bấm «Thực hiện».

- **Kết quả:** học sinh rời lớp cũ và vào lớp mới theo hiệu lực trong phiếu.
- **Lỗi thường gặp:** lớp mới hết chỗ hoặc trùng giờ thì hệ thống báo trên màn, chọn lớp khác.
- **Ảnh:** [ẢNH: phieu-chuyen-lop], [ẢNH: phieu-chuyen-co-so]

## 11. Phiếu Dừng học

**Mục tiêu:** cho học sinh dừng học hẳn và xử lý tiền còn lại đúng cách.

1. Làm bước 1 đến 2 của bài 7, chọn «Dừng học».
2. Chọn **Ghi danh**, **Lý do**, **Ngày dừng**.
3. Chọn **Xử lý tiền còn lại**:
   - «Hoàn tiền (sang phiếu Hoàn học phí)»: hoàn học phí còn lại, có trừ phí xử lý; khi duyệt xong bấm «Thực hiện», hệ thống tính hoàn và tạo phiếu chi ngay, không sinh thêm phiếu Hoàn học phí để duyệt lại.
   - «Giữ số dư (không trừ phí)»: phần tiền còn lại thành số dư của phụ huynh để dùng lần sau.
4. Đọc dòng giải thích dưới ô: dừng học đóng ghi danh, giờ tặng còn lại bị huỷ; ngày dừng chỉ để ghi nhận, không đổi cách tính giờ.
5. Gửi duyệt, chờ duyệt, bấm «Thực hiện».

- **Kết quả:** ghi danh đóng. Chọn giữ số dư thì số dư tăng; chọn hoàn tiền thì tiền hoàn đã được tính và phiếu chi đã tạo khi bấm «Thực hiện».
- **Lỗi thường gặp:** chọn ghi danh của em khác hay của cơ sở khác sẽ bị chặn.
- **Ảnh:** [ẢNH: phieu-dung-hoc-tao], [ẢNH: phieu-dung-hoc-hoan-tien], [ẢNH: phieu-dung-hoc-giu-so-du]

## 12. Phiếu Hoàn học phí

**Mục tiêu:** hoàn tiền học phí còn lại cho phụ huynh, qua hai cấp duyệt.

1. Phiếu này tạo từ ticket «Hoàn học phí» (nhóm Học phí), không phải từ phiếu Dừng học: phiếu Dừng học chọn «Hoàn tiền» đã hoàn luôn khi bấm «Thực hiện» (bài 11). Mở phiếu ở **Phiếu nghiệp vụ**.
2. Xem bảng tính hoàn: số đã đóng, trừ giờ đã học theo giá gốc, phần còn lại, trừ phí xử lý, **số tiền hoàn**. Số này do hệ thống tính và chụp lại lúc tạo phiếu; màn chỉ hiện kết quả, không sửa tay.
3. Chọn **Hình thức hoàn** (chuyển khoản hoặc tiền mặt) và tài khoản nhận nếu chuyển khoản.
4. Bấm «Gửi duyệt». Quản lý cơ sở duyệt cấp 1, kế toán duyệt cấp 2. Duyệt xong bấm «Thực hiện».
5. Thực hiện xong, hệ thống sinh **phiếu chi**; kế toán xử lý và in phiếu chi.

- **Kết quả:** học phí được hoàn đúng số đã duyệt, có phiếu chi để đối soát. Giờ tặng không được hoàn.
- **Lỗi thường gặp:** người duyệt cấp 1 không được duyệt luôn cấp 2. Phân hệ hoàn phí chưa bật ở cơ sở thì phiếu khoá nút duyệt và thực hiện kèm câu báo.
- **Ảnh:** [ẢNH: phieu-hoan-phi-bang-tinh], [ẢNH: phieu-hoan-phi-cho-ke-toan], [ẢNH: phieu-hoan-phi-thuc-hien]

## 13. Phiếu Chuyển phí

**Mục tiêu:** chuyển phần học phí còn lại của em này sang một đơn nhận khác (đơn nhận do bạn chọn ở phiếu).

1. Làm bước 1 đến 2 của bài 7, chọn «Chuyển phí».
2. Chọn **Ghi danh** nguồn, **Kiểu chuyển**, và **Đơn nhận (tham khảo)**.
3. Xem **Bảng tính chuyển phí**: giờ mua, giờ đã học, giá sau chiết khấu, đã đóng, giá trị chuyển, giờ tặng bị huỷ, giá trị đơn nhận, phụ huynh đóng thêm (nếu có).
4. Gửi duyệt, chờ duyệt, bấm «Thực hiện».

- **Kết quả:** phiếu «Đã thực hiện» theo đúng bảng tính; phần phụ huynh phải đóng thêm (nếu có) hiện trong bảng. Số dư giữ lại xem ở hồ sơ phụ huynh.
- **Lỗi thường gặp:** phụ huynh nhận phải cùng cơ sở; chọn phụ huynh ở cơ sở khác sẽ bị chặn.
- **Ảnh:** [ẢNH: phieu-chuyen-phi-tao], [ẢNH: phieu-chuyen-phi-bang-tinh]

## 14. Phiếu Đổi lịch, học bù

**Mục tiêu:** dời một buổi học hoặc đổi ca cố định cho học sinh.

1. Làm bước 1 đến 2 của bài 7, chọn «Đổi lịch, học bù».
2. Chọn buổi sắp tới cần dời, hoặc chọn ca cố định cần đổi, và lịch mới.
3. Gửi duyệt, chờ duyệt, bấm «Thực hiện».

- **Kết quả:** lịch học của em đổi theo phiếu.
- **Lỗi thường gặp:** hệ thống chặn kèm câu lý do ngay trên màn khi buổi hay lịch chọn không hợp lệ; đọc câu đó rồi chọn lại.
- **Ảnh:** [ẢNH: phieu-doi-lich]

## 15. Hàng nhận xét chờ gửi phụ huynh

**Mục tiêu:** gửi nhận xét của giáo viên cho phụ huynh khi chưa có cổng phụ huynh.

1. Vào hàng nhận xét chờ gửi ở mục Chăm sóc KH.
2. Mở từng nhận xét, đọc nội dung giáo viên đã viết.
3. Gửi cho phụ huynh bằng cách bạn vẫn dùng (ví dụ Zalo), rồi **đánh dấu đã gửi**.

- **Kết quả:** nhận xét có dấu đã gửi, không gửi trùng.
- **Lỗi thường gặp:** quên đánh dấu thì nhận xét vẫn nằm trong hàng chờ.
- **Ảnh:** [ẢNH: nhan-xet-cho-gui]

## Khi gặp sự cố

- Lỗi hệ thống trả về luôn hiện câu tiếng Việt ngay trên màn: đọc kỹ, đa số cho biết thiếu gì hoặc ai có quyền làm.
- Mạng lỗi thì bấm «Thử lại». Nút lưu khoá khi đang lưu, đừng bấm hai lần.
- Số tiền, số giờ sai: không sửa tay. Dùng phiếu hoặc điều chỉnh có lý do, hoặc báo quản lý cơ sở.
- Không rõ ai đã đổi gì: nhờ quản trị xem nhật ký thao tác.
