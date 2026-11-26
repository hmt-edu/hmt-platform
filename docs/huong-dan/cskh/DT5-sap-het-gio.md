---
id: dt5
ten: Xem học sinh sắp hết giờ
vai: [cskh]
phan_he: dao-tao
ma_man: [GD-07]
uu_tien: P2
cap_nhat: 2026-11-24
ma_luong: dt5
cong: crm
nguoi_viet: Code D
---

# Xem học sinh sắp hết giờ

**Làm xong bạn có:** danh sách học sinh sắp hết giờ hoặc đã hết giờ ở cơ sở của bạn, để gọi phụ huynh tái tục sớm.
**Ai làm:** CSKH, Trưởng cơ sở. **Màn:** Đào tạo → Sắp hết giờ.

## Trước khi bắt đầu, kiểm
- [ ] Phân hệ này đã bật cho cơ sở của bạn. Nếu màn hiện «Phân hệ chưa bật», nhờ Quản trị.
- [ ] Bạn đã biết cách mở phiếu tái tục (bài «Phiếu tái tục: xem danh sách, đổi giai đoạn, tạo tay»).

## Luật cần nhớ (lời thường)
- **Mỗi dòng là một học sinh trong một lớp.** Giờ còn là tổng giờ còn của mọi ghi danh còn hiệu lực của học sinh ở lớp đó, kể cả giờ tặng.
- Học sinh được gắn «Sắp hết giờ» khi **giờ còn từ 10 giờ trở xuống** hoặc **ngày hết giờ dự kiến còn từ 30 ngày trở xuống** kể từ hôm nay. Hai con số này do Quản trị cài, màn luôn ghi đúng số đang dùng ở câu giải thích dưới thanh công cụ.
- **Hạn gói chỉ để dự báo.** Quá hạn gói mà còn giờ thì học sinh vẫn học bình thường, không mất giờ, không cần gia hạn.
- Ghi danh đang bảo lưu hoặc đã dừng học không tính vào danh sách.

## Các bước
1. Vào menu **Đào tạo → Sắp hết giờ**.
   *Bạn thấy:* bảng các học sinh sắp hết giờ, mỗi dòng một học sinh trong một lớp; bên dưới thanh công cụ có câu ghi ngưỡng giờ và ngưỡng ngày đang dùng.
   [ẢNH: dt5-b1]
2. Đọc từng cột: «Học sinh», «Lớp», «Ghi danh», «Giờ còn», «Hết giờ dự kiến», «Hạn gói (dự báo)», «Tình trạng», «Phiếu tái tục».
   *Bạn thấy:* «Hết giờ dự kiến» là ngày học sinh dùng hết giờ nếu đi học đủ theo lịch lớp; «Hạn gói (dự báo)» là ngày hết hạn của gói, chỉ để tham khảo.
3. Muốn xem riêng một nhóm: bấm **«Filters»** rồi chọn **«Tình trạng»**: «Sắp hết giờ», «Hết giờ», «Sắp hết hạn gói» hoặc «Quá hạn gói, còn giờ».
   *Bạn thấy:* danh sách thu lại còn đúng nhóm đã chọn; thanh lọc hiện điều kiện đang áp dụng.
   [ẢNH: dt5-b2]
4. Tìm một học sinh: gõ tên học sinh hoặc mã lớp vào ô tìm.
   *Bạn thấy:* chỉ còn các dòng khớp.
5. Nhìn cột **«Phiếu tái tục»**:
   - Có mã phiếu: bấm vào để mở phiếu và gọi phụ huynh (xem bài «Phiếu tái tục: xem danh sách, đổi giai đoạn, tạo tay»).
   - Ghi «Chưa có phiếu · chờ đợt quét đêm»: học sinh đã hết giờ nhưng hệ thống chưa kịp sinh phiếu; đêm sau phiếu sẽ có.
   - Ghi «—»: chưa có phiếu. Phiếu tự sinh theo đợt quét đêm; nếu phụ huynh muốn mua thêm ngay, tạo tay một phiếu theo bài «Phiếu tái tục: xem danh sách, đổi giai đoạn, tạo tay».
   *Bạn thấy:* mã phiếu bấm được dẫn đúng sang phiếu của học sinh đó.
6. Bấm tên lớp để mở bản ghi lớp khi cần xem lịch và các buổi còn lại.

## Sau bước này
- **Ai làm tiếp:** CSKH gọi phụ huynh theo phiếu tái tục; phụ huynh đồng ý thì tạo đơn từ phiếu (bài «Phiếu tái tục: xem danh sách, đổi giai đoạn, tạo tay»).
- **Bạn xem ở đâu:** danh sách này mỗi sáng; phiếu ở Chăm sóc khách hàng → Tái tục.

## Làm nhầm thì sao
Màn này chỉ để xem, không có thao tác ghi nên không có gì phải hoàn tác.

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Phân hệ chưa bật» | cơ sở của bạn chưa bật màn này | nhờ Quản trị bật |
| «Chưa có học sinh sắp hết giờ» | không học sinh nào chạm ngưỡng, hoặc bộ lọc đang quá hẹp | bấm xoá bộ lọc; nếu vẫn trống thì không có học sinh nào cần tái tục |

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản CSKH giả (cskh1–3.cs5).
- **Dùng:** mở màn «Sắp hết giờ» ở CS5: có sẵn vài học sinh lớp Toán lớp 9 còn khoảng 8 đến 9 giờ. Lọc «Tình trạng» rồi mở lớp của một học sinh.

## Tự kiểm: bạn làm được khi
- [ ] Bạn nói được vì sao một học sinh có tên trong danh sách (giờ hay ngày).
- [ ] Bạn biết cột «Hạn gói» không làm học sinh mất giờ.

## Hỏi đáp
- **Quá hạn gói thì học sinh có bị khoá không?** Không. Còn giờ thì vẫn học; màn chỉ gắn «Quá hạn gói, còn giờ» để CSKH nhắc tái tục.
- **Vì sao học sinh còn giờ mà vẫn có trong danh sách?** Vì giờ còn đã chạm ngưỡng hoặc ngày hết giờ dự kiến đã gần; xem hai con số ngưỡng ở câu dưới thanh công cụ.
- **Vì sao cùng một học sinh mà có hai dòng?** Mỗi dòng là một lớp; học sinh học hai lớp thì có hai dòng.

**Bước trước:** (không) · **Bước sau:** Tái tục
