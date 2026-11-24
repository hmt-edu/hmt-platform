---
id: qt11
ten: Hồ sơ dạy của giáo viên và trợ giảng
vai: [quan-tri]
phan_he: quan-tri
ma_man: [QT-16]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Hồ sơ dạy của giáo viên và trợ giảng

**Làm xong bạn có:** một hồ sơ dạy ghi môn, khối, cơ sở thường dạy của giáo viên hoặc trợ giảng, để xếp lịch đúng người.
**Ai làm:** Admin (tạo, sửa, ngừng). **Màn:** menu **Quản trị** → **Giáo viên, trợ giảng**.

> Video: [VIDEO: qt11]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Đây là thao tác thật trên môi trường đang dùng.** Tập thì chỉ tập trên staging.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin. Vai không có quyền Admin không thấy mục menu này; nếu vào được màn thì không thấy nút «Tạo hồ sơ», «Sửa», «Ngừng».
- [ ] Người cần lập hồ sơ **đã có tài khoản người dùng** (xem bài tạo người dùng). Hồ sơ không tự tạo tài khoản.
- [ ] Bạn biết môn, khối, cơ sở người đó thường dạy.

## Luật cần nhớ (lời thường)
- Mỗi người một hồ sơ. Ô chọn người chỉ liệt kê người **chưa có hồ sơ**.
- Hồ sơ phân loại theo vai: «Giáo viên» hoặc «Trợ giảng» (lấy từ tài khoản, không chọn ở đây).
- Môn, khối, cơ sở thường dạy chỉ để tham khảo khi xếp lịch. **Ghi chú** (ví dụ chỉ dạy ca tối) cũng chỉ để tham khảo, không chặn việc xếp lớp.
- Không xoá hồ sơ. «Ngừng» đổi tình trạng thành «Ngừng»; «Dùng lại» đưa về «Đang dạy».

## Các bước
1. Vào **Quản trị** → **Giáo viên, trợ giảng**.
   *Bạn thấy:* bảng: Họ tên, Mã GV/TG, Loại, Môn dạy, Khối dạy, Cơ sở thường dạy, Tình trạng (cột Ghi chú ẩn mặc định, bật ở chọn cột). Có bộ lọc Loại, Tình trạng, Môn dạy, Khối dạy, Cơ sở thường dạy. Chưa có hồ sơ nào thì ghi «Chưa có hồ sơ dạy».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt11-b1]
2. Bấm **Tạo hồ sơ**. Ở «Giáo viên, trợ giảng» chọn người (dạng «Tên · mã (Giáo viên)»).
   *Bạn thấy:* hộp «Tạo hồ sơ dạy» với các nhóm tích chọn «Môn dạy», «Khối dạy», «Cơ sở thường dạy» và ô «Ghi chú».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt11-b2]
3. Tích môn, khối, cơ sở; nhập ghi chú nếu cần; bấm **Tạo hồ sơ** trong hộp.
   *Bạn thấy:* thông báo «Đã tạo hồ sơ dạy.» và dòng mới ở bảng, tình trạng «Đang dạy».
4. Sửa: ở dòng cần sửa bấm **Sửa**, đổi, bấm **Lưu**.
   *Bạn thấy:* «Đã lưu hồ sơ dạy.» Người của hồ sơ không đổi được.
5. Ngừng hoặc dùng lại: bấm **Ngừng** (hoặc **Dùng lại** ở hồ sơ đã ngừng).
   *Bạn thấy:* «Đã ngừng hồ sơ dạy.» hoặc «Đã dùng lại hồ sơ dạy.»

## Sau bước này
- **Ai làm tiếp:** người xếp lịch dùng hồ sơ này để tham khảo (môn, khối, cơ sở) khi chọn giáo viên.
- **Bạn xem ở đâu:** bảng này, lọc theo Tình trạng. Mọi lần đổi có trong nhật ký thao tác.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Tích nhầm môn, khối, cơ sở | Bấm «Sửa» và tích lại |
| Ngừng nhầm | Bấm «Dùng lại» ở dòng đó |
| Lập hồ sơ nhầm người | Không xoá được. Bấm «Ngừng» ở hồ sơ đó và lập hồ sơ cho đúng người |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| Ô chọn người không thấy tên cần tìm | người đó đã có hồ sơ (có thể đang «Ngừng»), hoặc chưa có tài khoản giáo viên, trợ giảng | Lọc bảng theo tên, bấm «Dùng lại» nếu đã ngừng; chưa có tài khoản thì tạo người dùng trước |
| «Ghi chú tối đa 500 ký tự.» | ghi chú quá dài | Rút ngắn ghi chú |
| Thông báo lỗi đỏ trong hộp | máy chủ từ chối | Đọc câu trong hộp, làm theo; không rõ thì báo Admin hệ thống |
| Lỗi tải danh sách | lỗi mạng | Bấm thử lại |

## Tập trên dữ liệu mẫu
- **Cần:** `bgd.tap` (Admin) trên **staging**; một tài khoản giáo viên giả chưa có hồ sơ.
- **Dùng:** tạo hồ sơ cho giáo viên giả, sửa thêm một khối, Ngừng rồi Dùng lại. Chưa có trong bộ mẫu: giáo viên giả chưa có hồ sơ dành riêng cho việc tập.
- Vai Vận hành tập tạm bằng quyền CSKH (anh Trường chốt 24/11). Menu này đòi quyền Admin, nên tài khoản CSKH **không vào được**; việc tạo, sửa hồ sơ tập bằng `bgd.tap`.

## Tự kiểm: bạn làm được khi
- [ ] Bạn tạo hồ sơ và thấy dòng mới «Đang dạy».
- [ ] Bạn Ngừng rồi Dùng lại đúng hồ sơ đó.
- [ ] Bạn nói được vì sao ghi chú không chặn việc xếp lớp.
