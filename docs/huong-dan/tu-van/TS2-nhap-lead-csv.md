---
title: Nhập lead từ file CSV
group: vai
slug: tu-van-ts2
order: 42
role: Tư vấn tuyển sinh
portals: [crm]
priority: P1
flow: ts2
screens: [TS-04, QT-18]
checked: 2026-11-24
---

# Nhập lead từ file CSV

**Làm xong bạn có:** nhiều lead mới được tạo cùng lúc từ một file, và biết dòng nào bị bỏ qua vì trùng hoặc lỗi.
**Ai làm:** Tư vấn tuyển sinh, CSKH, Trưởng cơ sở (ai có quyền tạo lead). **Màn:** Tuyển sinh → Lead → «Nhập».

> Video: chưa có.
> Video: [VIDEO: ts2]
> Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] File là **CSV**, dòng đầu là tên cột. Từ Excel: «Lưu thành» → «CSV UTF-8».
- [ ] Mỗi dòng có tên phụ huynh và số điện thoại.
- [ ] Số dòng không quá mức cho phép (hộp sẽ báo; mặc định 500 dòng mỗi lần). Quá thì tách file.
- [ ] Không có số điện thoại thật của người ngoài kế hoạch: trên môi trường thử chỉ dùng số mẫu.

## Luật cần nhớ (lời thường)
- Bạn xem trước kết quả rồi mới bấm nhập; xem trước không tạo gì.
- Dòng **trùng số điện thoại** với lead hoặc phụ huynh đang có thì bị **bỏ qua**, không tự gộp.
- Dòng **lỗi** không được nhập. Dòng hợp lệ vẫn nhập bình thường.
- Cột nào bạn không ghép thì dữ liệu cột đó **không** vào hệ thống.

## Các bước
1. Vào **Lead**, bấm **«Nhập»**.
   *Bạn thấy:* hộp «Nhập lead từ file», ba bước «Tải file», «Ghép cột», «Xem trước».
   [ẢNH: ts04-ts2-b1]
2. Kéo file CSV vào khung, hoặc bấm «chọn file».
   *Bạn thấy:* tên file, số dòng, số cột. Nếu file quá dòng cho phép: khung đỏ «File có … dòng, tối đa … dòng mỗi lần nhập. Tách file rồi chọn lại.»
   [ẢNH: ts04-ts2-b2]
3. Sang bước «Ghép cột». Hệ thống tự ghép cột có tên quen (ví dụ «Họ tên phụ huynh», «SĐT»). Kiểm từng dòng ở bảng «Cột trong file» ↔ «Trường trong hệ thống»; sai thì chọn lại.
   *Bạn thấy:* cột chưa ghép có nhãn «Chưa ghép». Thiếu cột bắt buộc: khung đỏ «Chưa ghép cột bắt buộc: Tên phụ huynh, SĐT.» (chỉ hiện trường còn thiếu).
   [ẢNH: ts04-ts2-b3]
4. Chọn giá trị mặc định cho cả lô nếu file không có cột đó: «Source», «Sub-source», «Chiến dịch», «Cơ sở» (nếu bạn xem nhiều cơ sở), «Người phụ trách».
   *Bạn thấy:* các ô mặc định; «Người phụ trách» để trống thì lead giao cho chính bạn.
5. Bấm tiếp sang «Xem trước».
   *Bạn thấy:* ba ô đếm «dòng hợp lệ», «dòng trùng SĐT», «dòng lỗi» và bảng «Kết quả từng dòng» (nhãn «Hợp lệ», «Trùng SĐT», «Lỗi», kèm lý do). Bấm ô đếm để lọc bảng.
   [ẢNH: ts04-ts2-b5]
   [CHƯA CHỤP: cần chụp trên staging CS5]
6. Đọc các dòng «Lỗi» và «Trùng SĐT». Nếu cần sửa file: đóng hộp, sửa file, làm lại từ bước 1. Nếu ổn: bấm **«Nhập»**.
   *Bạn thấy:* thông báo «Đã nhập N lead. Bỏ qua N dòng trùng SĐT, N dòng lỗi.» và danh sách lead mới hiện ở «Lead».
   [ẢNH: ts04-ts2-b6]
   [CHƯA CHỤP: cần chụp trên staging CS5]

⚠ **Nhập xong không có nút hoàn tác cả lô.** Nhập nhầm thì nhờ Admin «Huỷ lead nhập nhầm» từng lead.

## Sau bước này
- **Ai làm tiếp:** Trưởng cơ sở hoặc CSKH giao lead cho sale (menu «Giao người phụ trách»), nếu bạn chưa chọn người phụ trách; sale gọi khách (bài «Chăm sóc lead»).
- **Bạn xem ở đâu:** Lead, sắp xếp theo «Ngày tạo»; các lead mới ở «C1 Data mới».

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Ghép sai cột ở bước 3 | quay lại bước «Ghép cột» bằng nút quay lại, chỉnh, xem trước lại |
| Chưa bấm «Nhập» mà muốn bỏ | đóng hộp; chưa tạo gì |
| Đã nhập sai nguồn hoặc cơ sở | sửa từng lead («Sửa» → «Lưu»); sai cơ sở thì nhờ Admin |
| Đã nhập nhầm cả file | nhờ Admin «Huỷ lead nhập nhầm» từng lead (cần lý do) |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Chưa ghép cột bắt buộc: …» | thiếu cột tên phụ huynh hoặc SĐT | ghép cột còn thiếu |
| «File có … dòng, tối đa … dòng mỗi lần nhập. Tách file rồi chọn lại.» | file quá dài | tách file |
| Dòng «Trùng SĐT» | số đã có ở lead hoặc phụ huynh | bỏ qua, hoặc xử lý riêng ở hồ sơ cũ |
| Dòng «Lỗi» kèm câu | dòng sai (số sai dạng, nguồn không có trong danh mục…) | sửa trong file rồi nhập lại dòng đó |
| «Không tìm thấy nhân viên có email …» (HMT_NGUOI_PHU_TRACH_SAI) | email người phụ trách trong file sai | sửa email hoặc để trống |

## Hỏi đáp
- **File Excel .xlsx được không?** Chưa. Lưu thành «CSV UTF-8» rồi tải lên.
- **Dòng trùng có bị gộp vào hồ sơ cũ không?** Không, chỉ bị bỏ qua. Gộp trùng làm riêng ở hồ sơ.
- **Tiếng Việt bị lỗi font?** Lưu lại bằng «CSV UTF-8».

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản `tvts1–3.cs5` hoặc `cskh1–3.cs5`.
- **Dùng:** tạo file CSV nhỏ 5 dòng với số mẫu 0999 000 xxx, trong đó 1 dòng trùng số bộ dữ liệu mẫu của bạn và 1 dòng thiếu số; xem trước, nhập.

## Tự kiểm: bạn làm được khi
- [ ] Có 3 lead «[MẪU]» mới từ file; bạn chỉ ra được dòng nào bị bỏ qua và vì sao.
- [ ] Bạn nói được vì sao không có nút «Hoàn tác» cho cả lô.
