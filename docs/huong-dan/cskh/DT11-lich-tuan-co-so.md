---
id: dt11
ten: Lịch tuần cơ sở và học sinh của lớp
vai: [cskh, truong-co-so]
phan_he: dao-tao
ma_man: [LOP-08, LOP-09]
uu_tien: P2
cap_nhat: 2026-11-24
ma_luong: dt11
cong: crm
nguoi_viet: Code D
---

# Lịch tuần cơ sở và học sinh của lớp

**Làm xong bạn có:** biết tuần này cơ sở có những buổi nào, ở phòng nào, giáo viên nào, có trùng không; và xem được danh sách học sinh của một lớp.
**Ai làm:** CSKH, Trưởng cơ sở. **Màn:** Đào tạo → Lịch tuần cơ sở; bản ghi lớp → «Học sinh».

## Trước khi bắt đầu, kiểm
- [ ] Phân hệ «Lịch tuần cơ sở» đã bật cho cơ sở của bạn (nếu không, nhờ Quản trị).
- [ ] Bạn biết mình đang xem cơ sở nào (CSKH và Trưởng cơ sở chỉ thấy cơ sở của mình).

## Luật cần nhớ (lời thường)
- Trùng phòng, trùng giáo viên (cùng ngày, cùng giờ) **chỉ cảnh báo, không chặn**.
- Hai lớp cùng nhóm (Đại và Hình luân phiên) có **cùng màu viền** và **không bị báo trùng**.

## Các bước (lịch tuần)
1. Vào menu **Đào tạo → Lịch tuần cơ sở**.
   *Bạn thấy:* bảng tuần hiện tại, mỗi cột một ngày (Thứ 2 đến Chủ nhật), mỗi hàng một phòng; ô có buổi ghi mã lớp, giờ học và giáo viên.
   [ẢNH: dt11-b1]
2. Đổi tuần bằng **«Tuần trước»**, **«Tuần này»**, **«Tuần sau»**.
   *Bạn thấy:* khoảng ngày ở đầu bảng đổi theo, bảng hiện buổi của tuần đó.
3. Đổi cách xem bằng **«Theo phòng»** hoặc **«Theo giáo viên»**.
   *Bạn thấy:* các hàng đổi thành phòng hoặc thành giáo viên. Buổi chưa có phòng nằm ở hàng «Chưa có phòng».
4. Đọc dòng chú thích: «Cùng nhóm: cùng màu viền», «Luân phiên: không báo trùng», «Cảnh báo trùng phòng hoặc giáo viên (không chặn)».
5. Nếu có khung vàng «… buổi trùng phòng hoặc giáo viên»: đọc, rồi nhờ Trưởng cơ sở hoặc người xếp lịch đổi phòng, giờ hoặc giáo viên. Bạn vẫn dùng bình thường vì đây chỉ là cảnh báo.
6. Bấm vào một buổi trên bảng.
   *Bạn thấy:* mở bản ghi của lớp có buổi đó.

## Các bước (học sinh của lớp)
1. Ở bản ghi lớp, bấm **«Học sinh»** (số bên cạnh là số học sinh).
   *Bạn thấy:* danh sách «Học sinh của lớp».
   [ẢNH: dt11-b3]
2. Đọc các cột: «Mã học sinh», «Học sinh», «Ghi danh», «Cơ sở phụ trách», «Hình thức học», «Ngày vào», «Ngày rời», «Tình trạng».
   *Bạn thấy:* học sinh đang học có «Đã xếp lớp»; học sinh đã nghỉ có ngày rời và «Đã rời».
   [ẢNH: dt11-b4]
3. Muốn thêm học sinh vào lớp: bấm **«Xếp thêm»** (có quyền sửa ghi danh mới thấy). Nút dẫn sang «Hàng chờ xếp lớp» (bài «Xếp lớp cho ghi danh đang chờ»).
4. Bấm **«Quay lại lớp …»** để về bản ghi lớp.

## Sau bước này
- **Ai làm tiếp:** có trùng phòng hoặc giáo viên thì người xếp lịch sửa Time Table của lớp (bài «Tạo lớp, thời khoá biểu và trình duyệt»).
- **Bạn xem ở đâu:** màn Lịch tuần cơ sở mỗi đầu tuần.

## Làm nhầm thì sao
Hai màn này chỉ để xem; không có gì phải hoàn tác.

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Không tải được lịch tuần» | lỗi mạng hoặc máy chủ | bấm «Thử lại» |
| «Phân hệ chưa bật» | cơ sở chưa bật màn này | nhờ Quản trị |

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản CSKH giả (cskh1–3.cs5).
- **Dùng:** mở «Lịch tuần cơ sở» tuần này ở CS5, đổi «Theo giáo viên», rồi mở một lớp Toán mẫu và xem «Học sinh».

## Tự kiểm: bạn làm được khi
- [ ] Bạn tìm được buổi của một lớp trong tuần sau.
- [ ] Bạn biết khung vàng «trùng» không chặn ai.

## Hỏi đáp
- **Hai lớp cùng giờ cùng phòng mà không báo trùng, vì sao?** Hai lớp cùng nhóm, luân phiên Đại và Hình, nên không bị coi là trùng.
- **Vì sao một buổi nằm ở hàng «Chưa có phòng»?** Khung giờ của lớp chưa chọn phòng.
- **Bấm buổi sao không ra bản ghi buổi?** Ở màn này bấm buổi mở bản ghi **lớp**; muốn mở buổi, vào «Buổi học» rồi lọc theo lớp.

**Bước trước:** Tạo lớp, thời khoá biểu · **Bước sau:** Xếp lớp cho ghi danh
