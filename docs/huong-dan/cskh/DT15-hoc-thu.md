---
id: dt15
ten: Thêm học sinh học thử vào buổi
vai: [cskh, truong-co-so]
phan_he: dao-tao
ma_man: [BUOI-06]
uu_tien: P2
cap_nhat: 2026-11-24
ma_luong: dt15
cong: crm
nguoi_viet: Code D
---

# Thêm học sinh học thử vào buổi

**Làm xong bạn có:** một học sinh của cơ hội tuyển sinh được thêm vào danh sách một buổi để học thử, không mất tiền, không trừ giờ.
**Ai làm:** CSKH, Trưởng cơ sở (quyền «Sửa buổi»). **Màn:** Đào tạo → Buổi học → bản ghi buổi.

## Trước khi bắt đầu, kiểm
- [ ] **Phân hệ «Học thử vào buổi» đang bật** cho cơ sở. Mặc định phân hệ này **tắt**; chưa bật thì không có nút «Thêm học thử». Nhờ Quản trị bật.
- [ ] Buổi đang ở trạng thái **«Đã chốt»** (chốt danh sách rồi, chưa hoàn thành).
- [ ] Cơ hội của em **từ giai đoạn L5 trở lên** và **cùng cơ sở** với buổi.
- [ ] Cơ hội chưa dùng hết số buổi học thử cho phép (mặc định 2 buổi mỗi cơ hội).

## Luật cần nhớ (lời thường)
- Học thử **miễn phí, không trừ giờ**.
- Học thử **không tính vào sĩ số lớp** và không tính vào chỗ còn trống khi bán; nhưng tính vào số em của buổi (ví dụ «Sĩ số 12/15 · học thử 1»).
- Vượt sĩ số tối đa, hoặc cơ hội khác khối với lớp: chỉ **cảnh báo**, vẫn thêm được.

## Các bước
1. Vào **Đào tạo → Buổi học**, mở buổi «Đã chốt» cần thêm em.
   *Bạn thấy:* bản ghi buổi; nếu đủ điều kiện ở trên thì có nút **«Thêm học thử»**.
   [CHƯA CHỤP: phân hệ Học thử đang tắt trên staging]
2. Bấm **«Thêm học thử»**.
   *Bạn thấy:* hộp «Thêm học thử» với câu giải thích, ô «Cơ hội».
3. Ở «Cơ hội» gõ tên, số điện thoại hoặc mã cơ hội để tìm, rồi chọn.
   *Bạn thấy:* hiện thêm ô «Học sinh của cơ hội».
4. Chọn học sinh trong ô «Học sinh của cơ hội».
5. Bấm **«Thêm vào buổi»**.
   *Bạn thấy:* thông báo «Đã thêm học sinh học thử vào buổi». Nếu có cảnh báo (vượt sĩ số, khác khối) thì thông báo ghi kèm cảnh báo. Trong «Danh sách và điểm danh» tên em có nhãn **«Học thử»**.

## Sau bước này
- **Ai làm tiếp:** giáo viên điểm danh em như học sinh khác; tư vấn tuyển sinh chăm cơ hội sau buổi học thử.
- **Bạn xem ở đâu:** bản ghi buổi, danh sách có nhãn «Học thử».

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Thêm nhầm em hoặc nhầm buổi | màn không có nút gỡ em học thử; nhờ Trưởng cơ sở hoặc Quản trị xử lý |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Cơ hội thuộc cơ sở khác với buổi học.» (mã HMT_HOC_THU_KHAC_CO_SO) | cơ hội ở cơ sở khác | chọn buổi của đúng cơ sở của em |
| «Cơ hội này đã dùng hết số buổi học thử cho phép (N buổi).» (mã HMT_HOC_THU_VUOT_HAN_MUC) | đã học thử đủ số buổi cho phép | báo tư vấn tuyển sinh chốt đơn; cần thêm buổi thì hỏi Trưởng cơ sở |

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản CSKH giả và phân hệ Học thử đã bật ở cơ sở tập. Nếu chưa bật, bài này chỉ để đọc.
- **Dùng:** một cơ hội «[MẪU]» ở L5 trở lên và một buổi «Đã chốt» của cơ sở đó.

## Tự kiểm: bạn làm được khi
- [ ] Bạn nói được vì sao nút «Thêm học thử» không hiện (phân hệ tắt, buổi chưa chốt, thiếu quyền).
- [ ] Bạn biết học thử không trừ giờ.

## Hỏi đáp
- **Vì sao không thấy nút «Thêm học thử»?** Phân hệ tắt, buổi chưa «Đã chốt», hoặc bạn không có quyền sửa buổi.
- **Một em học thử mấy buổi?** Tối đa số buổi mỗi cơ hội (mặc định 2).
- **Học thử có làm lớp đầy chỗ không?** Không tính vào sĩ số và chỗ bán, nhưng có tính vào số em của buổi.

**Bước trước:** Điểm danh, chốt danh sách buổi · **Bước sau:** Điểm danh buổi
