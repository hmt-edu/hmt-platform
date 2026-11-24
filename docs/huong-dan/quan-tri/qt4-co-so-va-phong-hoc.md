---
id: qt4
ten: Cơ sở và phòng học
vai: [quan-tri]
phan_he: quan-tri
ma_man: [QT-08]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Cơ sở và phòng học

**Làm xong bạn có:** tên và địa chỉ cơ sở đúng, và danh sách phòng học của từng cơ sở (mã, tên, sức chứa) để chọn khi xếp lớp.
**Ai làm:** Admin. **Màn:** menu **Quản trị** → **Cơ sở và phòng**.

> Video: [VIDEO: qt4]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Đây là thao tác thật trên môi trường đang dùng.** Tập thì chỉ tập trên staging.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin. Vai khác mở được màn nhưng chỉ xem, có dòng «Bạn chỉ xem được; chỉ Quản trị sửa được cơ sở và phòng học.»
- [ ] Bạn biết mã phòng muốn tạo (ví dụ P101): chữ viết hoa, số, dấu gạch dưới.

## Luật cần nhớ (lời thường)
- **Không thêm, không ngừng cơ sở trên màn này.** Chỉ sửa «Tên hiển thị» và «Địa chỉ». Mở cơ sở mới do kỹ thuật làm.
- Mã cơ sở và mã phòng **không đổi được** sau khi tạo.
- Địa chỉ một dòng, tối đa 200 ký tự.
- Phòng không bị xoá: chỉ **Ngừng**. Phòng đã ngừng không hiện ở ô chọn phòng mới, nhưng dữ liệu cũ giữ phòng đó. Muốn dùng lại, bấm «Dùng lại».
- Mã phòng và tên phòng không được trùng trong cùng một cơ sở. Sức chứa là số chỗ ngồi, lớn hơn 0.
- Cơ sở văn phòng (Hội sở) không có phòng học, không có lead hay cơ hội; cơ sở đang có phòng học thì không đổi thành văn phòng được.

## Các bước
1. Vào **Quản trị** → **Cơ sở và phòng**.
   *Bạn thấy:* tiêu đề «Cơ sở và phòng học». Bên trái là danh sách cơ sở (mỗi cơ sở ghi số phòng hoặc «Chưa có phòng học»); bên phải là cơ sở đang chọn.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt4-b1]
2. Bấm vào một cơ sở ở cột trái, rồi bấm «Sửa cơ sở».
   *Bạn thấy:* hộp «Sửa cơ sở <mã>» với «Mã» (khoá, ghi «Mã không đổi được.»), «Tên hiển thị», «Địa chỉ» (kèm bộ đếm ký tự).
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt4-b2]
3. Sửa tên hoặc địa chỉ rồi bấm «Lưu».
   *Bạn thấy:* thông báo «Đã lưu cơ sở.» và thông tin mới ở phần «Mã», «Tên hiển thị», «Địa chỉ».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt4-b3]
4. Ở khối «Phòng học» của cơ sở đó, bấm «Thêm phòng».
   *Bạn thấy:* hộp «Thêm phòng · <mã cơ sở> <tên cơ sở>» với «Mã phòng», «Tên phòng», «Sức chứa».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt4-b4]
5. Điền ba ô rồi bấm «Thêm phòng».
   *Bạn thấy:* «Đã thêm phòng.» và phòng mới trong bảng (cột «Mã phòng», «Phòng», «Sức chứa», «Trạng thái» = «Đang dùng»).
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt4-b5]
6. Muốn đổi tên hoặc sức chứa: bấm «Sửa» ở dòng phòng, sửa, bấm «Lưu». Muốn ngừng: bấm «Ngừng» ở dòng phòng, rồi «Ngừng phòng» trong hộp xác nhận.
   *Bạn thấy:* «Đã lưu phòng.» hoặc «Đã ngừng phòng.»; trạng thái đổi thành «Ngừng», nút đổi thành «Dùng lại».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt4-b6]

⚠ **Bước 6 «Ngừng phòng» ảnh hưởng chỗ chọn phòng mới:** phòng ngừng không hiện khi xếp lớp mới. Hoàn tác bằng «Dùng lại».

## Sau bước này
- **Ai làm tiếp:** người xếp lớp chọn được phòng này khi tạo hoặc sửa lớp.
- **Bạn xem ở đâu:** quay lại màn này; mỗi cơ sở ghi «N phòng (M đang dùng)». Mọi sửa có trong nhật ký thao tác.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Sai tên hoặc sức chứa phòng | «Sửa» ở dòng phòng |
| Sai mã phòng | Mã không đổi được: «Ngừng» phòng sai rồi thêm phòng mới với mã đúng |
| Ngừng nhầm phòng | «Dùng lại» |
| Sai tên hoặc địa chỉ cơ sở | «Sửa cơ sở» |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Mã phòng chỉ gồm chữ viết hoa, số và dấu gạch dưới (ví dụ P101).» | mã sai dạng | sửa mã |
| «Mã P101 đã có trong cơ sở.» / «Mã phòng này đã có trong cơ sở.» (HMT_PHONG_MA_TRUNG) | trùng mã | chọn mã khác |
| «Tên phòng này đã có trong cơ sở.» (HMT_PHONG_TEN_TRUNG) | trùng tên | đổi tên |
| «Nhập sức chứa, là số lớn hơn 0.» / «Sức chứa phải lớn hơn 0.» | sức chứa trống hoặc 0 | nhập số chỗ ngồi |
| «Địa chỉ tối đa 200 ký tự.» | địa chỉ quá dài | rút gọn |
| «Cơ sở đang có phòng học, không đổi thành văn phòng được.» (HMT_CO_SO_VAN_PHONG) | cơ sở có phòng | báo kỹ thuật, không tự xử lý |

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản tập `bgd.tap` (Admin). `ql.cs5` (Quản lý cơ sở) chỉ xem được màn này, dùng để kiểm dòng «Bạn chỉ xem được…». Chỉ làm trên **staging**.
- **Dùng:** thêm một phòng mã dạng `PTAP01`, tên «Phòng tập», sức chứa 10 vào cơ sở tập; sau đó «Ngừng» rồi «Dùng lại». Không sửa tên hay địa chỉ cơ sở thật trên staging dùng chung.
- Chưa có trong bộ mẫu: cơ sở riêng để tập sửa tên và địa chỉ.

## Tự kiểm: bạn làm được khi
- [ ] Bạn thêm được một phòng mẫu và thấy nó trong bảng với «Đang dùng».
- [ ] Bạn ngừng và dùng lại được phòng đó.
- [ ] Bạn nói được vì sao không thấy nút «Thêm cơ sở».

**Bước trước:** Người dùng (qt1) · **Bước sau:** Công tắc tính năng theo cơ sở (qt6)

## Ghi chú cho người soát (không hiển thị cho người học)
- Vênh canvas và bản đồ màn hình: QT-08 ghi «Sửa tên, địa chỉ, **hotline** cơ sở». Màn thật (BranchRoomPage) chỉ có «Tên hiển thị» và «Địa chỉ», không có hotline; bài theo màn thật.
- Menu ghi «Cơ sở và phòng», tiêu đề trang ghi «Cơ sở và phòng học»: bài dùng cả hai đúng chỗ.
- Mã nguồn chưa xác nhận: nhãn cột trái của danh sách cơ sở và tên nút chọn cơ sở (đọc theo `nav aria-label="Cơ sở"`, không có nút tên riêng). Kiểm khi chụp ảnh.
- Dòng «Hội sở không có phòng học» suy từ lỗi HMT_CO_SO_VAN_PHONG; quy tắc R-V2-10 (CS3 là cơ sở dạy học thường) không đưa vào bài vì không liên quan thao tác.
- Câu báo trùng mã trên màn: «Mã <mã> đã có trong <cơ sở>.» (giao diện) và «Mã phòng này đã có trong cơ sở.» (DB).
