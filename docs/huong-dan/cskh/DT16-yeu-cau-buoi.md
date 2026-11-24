---
id: dt16
ten: Yêu cầu học bù, buổi củng cố, học bổ trợ
vai: [cskh, truong-co-so]
phan_he: dao-tao
ma_man: [BUOI-07, BUOI-08, BUOI-09, BUOI-10]
uu_tien: P2
cap_nhat: 2026-11-24
ma_luong: dt16
cong: crm
nguoi_viet: Code D
---

# Yêu cầu học bù, buổi củng cố, học bổ trợ

**Làm xong bạn có:** một yêu cầu buổi gửi Trưởng cơ sở duyệt; duyệt xong hệ thống sinh buổi mới vào lịch của lớp.
**Ai làm:** CSKH tạo; Trưởng cơ sở duyệt hoặc từ chối. **Màn:** Đào tạo → Yêu cầu buổi.

## Trước khi bắt đầu, kiểm
- [ ] Phân hệ «Yêu cầu buổi» đã bật cho cơ sở (nếu không, menu «Hành động» của lớp không có «Yêu cầu học bù», «Yêu cầu bổ trợ»; nhờ Quản trị).
- [ ] Lớp đang **«Đã duyệt»** (lớp chưa duyệt không tạo được yêu cầu buổi).
- [ ] Bạn biết loại nào cần: **học bù** (em nghỉ, học lại), **củng cố** (thêm buổi cả lớp, tính tiền như buổi thường), **bổ trợ** (kèm em yếu).

## Luật cần nhớ (lời thường)
| Loại | Trừ giờ học sinh? | Tạo từ đâu | Ghi chú |
|---|---|---|---|
| Học bù | **Không** | bản ghi lớp | không gắn với buổi gốc, bắt buộc có lý do |
| Củng cố | **Có**, như buổi thường | màn Yêu cầu buổi | chèn buổi vào lịch, dời nhãn bài các buổi sau; không bắt buộc phụ huynh đồng ý trong hệ thống |
| Bổ trợ | **Không**, nhưng tính giờ dạy của giáo viên | bản ghi lớp | chọn em yếu và giáo viên |
- **Chỉ Trưởng cơ sở duyệt.** CSKH chỉ tạo, xem và huỷ yêu cầu của mình.
- Duyệt thì mới sinh buổi. Trùng giờ chỉ cảnh báo, người duyệt vẫn duyệt được.

## Các bước (tạo yêu cầu)
**Học bù hoặc bổ trợ**
1. Mở **Đào tạo → Lớp học**, bấm vào lớp, mở menu **«Hành động»**.
   *Bạn thấy:* hai mục **«Yêu cầu bổ trợ»** và **«Yêu cầu học bù»**.
   [ẢNH: dt16-b2]
2. Chọn một mục. Lớp đã được chọn sẵn, không chọn lại.
3. **Học bù:** chọn **«Em học bù»**, chọn «Ngày», «Giờ bắt đầu», «Giờ kết thúc» (để trống thì theo khung giờ của lớp), «Phòng», nhập **«Lý do học bù»**.
   [ẢNH: dt16-b3]
4. **Bổ trợ:** chọn **«Em yếu cần bổ trợ»** (mỗi em hiện số giờ còn), «Ngày», «Giờ», **«Giáo viên»**, «Phòng»; «Ghi chú» không bắt buộc.
   [ẢNH: dt16-b5]
5. Bấm **«Gửi duyệt»**; chưa chắc thì bấm **«Lưu nháp»**. **«Huỷ»** để bỏ.
   *Bạn thấy:* yêu cầu có mã và hiện ở danh sách «Yêu cầu buổi» với tình trạng chờ duyệt.

**Buổi củng cố**
1. Vào **Đào tạo → Yêu cầu buổi**, bấm **«Tạo yêu cầu buổi củng cố»**.
   [ẢNH: dt16-b1]
2. Ở «Lớp» gõ mã lớp hoặc tên môn rồi chọn lớp; dòng «Học sinh: cả lớp» hiện ra.
3. Chọn «Ngày buổi củng cố», «Giờ bắt đầu», «Giờ kết thúc», «Phòng»; «Ghi chú (không bắt buộc)».
   [ẢNH: dt16-b4]
4. Bấm **«Gửi duyệt»** hoặc **«Lưu nháp»**.

## Các bước (Trưởng cơ sở duyệt)
1. Vào **Đào tạo → Yêu cầu buổi** (hoặc «Việc chờ tôi duyệt»), lọc **«Chờ duyệt»**.
   *Bạn thấy:* các yêu cầu với «Loại», «Mã», «Ngày giờ», «Người tạo», «Tình trạng».
2. Bấm **«Duyệt»**. Nếu hộp «Trùng giờ, vẫn duyệt?» hiện các dòng trùng, đọc rồi xác nhận nếu vẫn muốn duyệt.
   *Bạn thấy:* yêu cầu thành đã duyệt và buổi mới hiện ở «Buổi học» của lớp.
3. Muốn từ chối: bấm **«Từ chối»**, chọn **«Lý do»**, ghi «Ghi chú», bấm gửi.
   [CHƯA CHỤP: không có yêu cầu chờ duyệt trên staging]
4. Người tạo muốn bỏ yêu cầu chưa duyệt: bấm **«Huỷ»** ở dòng đó, rồi **«Xác nhận huỷ»**.

## Sau bước này
- **Ai làm tiếp:** Trưởng cơ sở duyệt; sau đó báo giáo viên và phụ huynh về buổi mới.
- **Bạn xem ở đâu:** «Yêu cầu buổi» (lọc «Tất cả») và «Buổi học» của lớp.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Tạo nhầm, chưa duyệt | bấm «Huỷ» ở dòng yêu cầu, «Xác nhận huỷ» |
| Đã duyệt rồi mới thấy sai | buổi đã sinh; xử lý như buổi thường (bài «Huỷ buổi, dời một buổi») |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Chỉ lớp đã duyệt mới có yêu cầu học bù.» (hoặc củng cố, bổ trợ) | lớp chưa «Đã duyệt» | chờ lớp được duyệt |
| «Chưa chọn lớp» | mở form học bù/bổ trợ không đi từ bản ghi lớp | mở lớp, chọn lại từ menu «Hành động» |
| «Lớp chưa có học sinh.» | lớp chưa xếp em nào | xếp em vào lớp trước |

## Tập trên dữ liệu mẫu
- **Cần:** CSKH giả (cskh.cs5) để tạo; Trưởng cơ sở giả (truongcs.cs5) để duyệt.
- **Dùng:** lớp Toán mẫu đã duyệt trong «Dữ liệu mẫu của tôi». Tạo một yêu cầu học bù «[MẪU]», rồi nhờ Trưởng cơ sở duyệt, hoặc huỷ yêu cầu của chính bạn.

## Tự kiểm: bạn làm được khi
- [ ] Bạn nói được loại nào trừ giờ học sinh (chỉ củng cố).
- [ ] Bạn biết CSKH chỉ tạo, Trưởng cơ sở mới duyệt.

## Hỏi đáp
- **Vì sao không thấy «Yêu cầu học bù» trong menu lớp?** Phân hệ chưa bật, hoặc bạn không có quyền.
- **Học bù có làm trừ giờ lần nữa không?** Không, kể cả khi buổi bù bị huỷ có tính phí.
- **Củng cố có cần phụ huynh đồng ý trong hệ thống không?** Không bắt buộc; bạn có thể ghi chú.
- **Ô «Loại buổi: Buổi kiểm tra» ở cuối form là gì?** Tuỳ chọn để tạo buổi kiểm tra. Từ yêu cầu học bù, bổ trợ thì không trừ giờ; từ củng cố thì trừ giờ như buổi chính.

**Bước trước:** Xếp lớp cho ghi danh · **Bước sau:** Điểm danh buổi
