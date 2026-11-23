# GV05, GV06, GV07: đề xuất cho 6 chỗ lệch khung điện thoại (E-23-18)

Nguồn: đối chiếu E-23-10 giữa `design/hmt-canvas-9189` (khung `_dt`) và `src/pages/gv/`. Phần chữ nhỏ đã sửa ở #604. Dưới đây là 6 chỗ lệch còn lại: **chưa làm, không code trước khi anh Trường OK**. Cỡ: nhỏ (dưới nửa ngày), vừa (1 đến 2 ngày), lớn (hơn 2 ngày). Số trong khung là minh hoạ.

## Thứ tự đề nghị

1 → 3 → 2a → 2b → 2c (làm được ngay, chỉ giao diện) rồi chờ anh quyết 4, 5, 6.

| #   | Việc                                                                                          | Khung                                                                    | Cỡ   | Cần DB                                                                                          | Rủi ro                                      |
| --- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | ---- | ----------------------------------------------------------------------------------------------- | ------------------------------------------- |
| 1   | Thanh 4 bước, nút «Sửa điểm danh», dòng tóm tắt sau lưu                                       | GV05_buoc_tiep, GV06_buoc_tiep                                           | nhỏ  | Không                                                                                           | Thấp                                        |
| 2a  | GV07: nút «Điểm danh em này», hàng «Không chấm» cho em vắng, «Chấm lại ô này» thay «Xoá điểm» | GV07_chua_dd, GV07_vang, GV07_gon                                        | nhỏ  | Không                                                                                           | Thấp                                        |
| 2b  | GV07: hộp thống kê 4 ô, ô Vắng đã nhập («Giữ, không tính»)                                    | GV07_o_4_trang_thai, GV07_vang_da_nhap                                   | vừa  | Không (dữ liệu có sẵn trong lượt tải)                                                           | Thấp; kiểm lại cách tính điểm trung bình    |
| 2c  | GV07: chấm theo cột, «Cả lớp mức 3», xuất nhận xét, hộp xung đột                              | GV07_cot, GV07_tieu_chi, GV07X_*, GV07_xung_dot                          | lớn  | Có thể (lưu hàng loạt «Cả lớp»; xuất nhận xét nên ở trình duyệt hoặc Edge Function)             | Vừa: ghi đè nhận xét, chạm điểm             |
| 3   | GV06: hộp xung đột «Giữ của tôi / Lấy của …» (thay cho báo tải lại, Q-243)                    | GV06_xung_dot                                                            | vừa  | Không nếu máy chủ đã trả bản mới nhất khi từ chối; nếu chưa thì sửa hàm lưu nội dung buổi       | Thấp đến vừa                                |
| 4   | GV06 buổi kiểm tra: giáo viên sửa «Phạm vi kiến thức», bỏ khối dòng nội dung                  | GV06_kiem_tra                                                            | vừa  | Có: hàm lưu phạm vi (hiện `scope_text` do người xếp lịch đặt, giáo viên chỉ xem) và quyền       | Vừa: đổi quyền ai sửa                       |
| 5   | Chữ nhóm tiêu chí GV07                                                                        | GV07_o_4_trang_thai, _cot, _tieu_chi và GV07_vang, _chua_dd, _xung_dot   | nhỏ  | Không nếu chỉ nhãn; có nếu nhãn nằm trong danh mục                                              | Thấp                                        |
| 6   | Phân biệt «vắng có phép» và «vắng không phép» ở GV07, GV07K                                   | GV07_vang, GV07K_vang                                                    | nhỏ  | Không (danh mục đã có `VANG_CO_PHEP`)                                                           | Thấp                                        |

## Chi tiết từng mục

**1. Thanh bước, Sửa điểm danh, tóm tắt.** Khung có thanh «1 Điểm danh · 2 Nội dung · 3 Nhận xét · 4 BTVN» ở đầu GV05 và GV06 (dấu ✓ ở bước đã xong), nút «Bước tiếp: Nội dung buổi» và «Sửa điểm danh» sau khi lưu, dòng tóm tắt theo trạng thái (ví dụ «Có mặt 3 · Vắng có phép 1»). Làm thành một thành phần thanh bước dùng chung (khuôn P0), đọc trạng thái bước từ dữ liệu buổi đã có. Chỉ giao diện.

**2a, 2b, 2c. GV07.** Chia ba để PR nhỏ. 2a và 2b chỉ đọc thêm dữ liệu đã có. 2c là phần lớn, đã ghi «chưa làm, sau 17/11» ở đầu `ReviewGradingPage.tsx`; xin anh chọn có làm bản chấm theo cột và xuất nhận xét trong đợt này không. Xuất nhận xét (GV07X_*) có rủi ro riêng về ảnh và PDF, nên làm sau.

**3. Xung đột GV06.** Hiện máy chủ từ chối lưu khi hai người cùng sửa và giao diện báo tải lại. Khung cho chọn giữ bản mình hay lấy bản kia, giống GV05 đã làm. Cần kiểm hàm lưu có trả bản hiện tại khi từ chối.

**4. Câu hỏi cho anh (nghiệp vụ).** Ở buổi Kiểm tra, khung cho giáo viên **sửa** ô «Phạm vi kiến thức» và **không có** khối dòng nội dung. Code hiện tại: phạm vi chỉ xem (người xếp lịch đặt khi tạo buổi), vẫn có khối dòng nội dung. Hỏi anh:

- (a) Giáo viên có được sửa phạm vi không?
- (b) Nếu có, sửa tới lúc nào (trước khi chấm điểm, hay tới Hoàn thành)?
- (c) Buổi Kiểm tra còn cần dòng nội dung không (Q-252 đang cho lưu khi không có dòng)?

Khung và luật đang vênh: theo CLAUDE.md làm theo luật, nên giữ nguyên tới khi anh chốt.

**5. Câu hỏi cho anh (chữ).** Ngay trong khung, tên nhóm tiêu chí không thống nhất: một số khung ghi «Thái độ / Tiếp thu / Vận dụng», số khác ghi «Kiến thức». Code ghi «Tiếp thu kiến thức» và «Năng lực vận dụng». Hỏi anh: chữ chốt cho ba nhóm là gì? Sau khi anh chốt thì nhờ Design sửa khung cho khớp.

**6. Câu hỏi cho anh (nghiệp vụ).** Khung GV07 và GV07K nói «Em vắng **có phép**: không chấm / không nhập điểm»; code gộp mọi ca vắng. Danh mục đã có `VANG_CO_PHEP`. Hỏi anh: em vắng **không phép** có được chấm nhận xét, nhập điểm kiểm tra không, hay cũng không như vắng có phép? Nếu cùng không chấm thì chỉ sửa chữ cho gọn; nếu khác thì cần luật mới trong `docs/spec/`.
