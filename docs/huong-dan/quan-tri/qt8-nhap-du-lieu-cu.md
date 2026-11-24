---
id: qt8
ten: Nhập dữ liệu cũ bằng file CSV
vai: [quan-tri]
phan_he: quan-tri
ma_man: [QT-18]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Nhập dữ liệu cũ bằng file CSV

**Làm xong bạn có:** dữ liệu từ hệ thống cũ (người dùng, phụ huynh, học sinh, lớp…) đã nằm trong hệ thống mới, theo từng loại.
**Ai làm:** Admin. **Màn:** menu **Quản trị** → **Nhập dữ liệu**.

> Video: [VIDEO: qt8]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Nạp thật là thao tác thật trên môi trường đang dùng.** Tập thì chỉ tập trên staging, bằng file dữ liệu giả. Không dùng tên, số điện thoại thật của học sinh, phụ huynh để thử.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin.
- [ ] File ở dạng **CSV UTF-8** (trong Excel: Lưu thành → CSV UTF-8), dòng đầu là tên cột. Muốn có khuôn đúng cột, bấm «Tải file mẫu» ở loại tương ứng.
- [ ] Loại bạn định nạp **không cần loại khác nạp trước**, hoặc loại đó đã nạp rồi (xem cột «Cần có trước»).
- [ ] Với loại thuộc đào tạo (Lớp, Ghi danh…): cơ sở trong file đã được **bật phân hệ Vận hành lớp** ở bài «Công tắc tính năng theo cơ sở», nếu chưa thì sẽ bị chặn.

## Luật cần nhớ (lời thường)
- Nạp **theo từng loại**, đúng thứ tự: Người dùng, Lớp, Phụ huynh, Học sinh, Ghi danh, Số dư, Cơ hội, Phiếu test. Loại nào cần dữ liệu có trước thì nạp sau.
- Dòng **đã có** thì bị bỏ qua (báo «Trùng»), **không ghi đè, không tự gộp**. Nạp lại cùng file không làm nhân đôi.
- Dòng **lỗi** không được nạp. Một số loại (Ghi danh, Số dư) **không nạp từng phần**: còn một dòng lỗi là không nạp cả loại; phải sửa file hết lỗi mới nạp được.
- **Không mang mật khẩu của hệ thống cũ sang.** Khi nạp Người dùng, hệ thống tạo **mật khẩu tạm mới** cho từng người, hiện **một lần**, bạn tải file giao từng người; họ đổi mật khẩu ở lần đăng nhập đầu.
- Loại ghi «Sắp có» chưa nạp được.

## Các bước
1. Vào **Quản trị** → **Nhập dữ liệu**, tìm đúng loại trong bảng.
   *Bạn thấy:* bảng «Loại dữ liệu nạp» với cột «Thứ tự», «Loại nạp», «Mô tả», «Cần có trước», «Trạng thái» («Sẵn sàng» hoặc «Sắp có»).
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt8-b1]
2. (Nếu chưa có file) bấm «Tải file mẫu» ở dòng đó, điền dữ liệu theo file mẫu, lưu CSV UTF-8.
   *Bạn thấy:* trình duyệt tải về file `mau-<loại>.csv` có dòng tên cột và một dòng ví dụ (dữ liệu giả).
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt8-b2]
3. Bấm nút «Nhập <tên loại>» ở dòng đó (ví dụ «Nhập người dùng»).
   *Bạn thấy:* hộp nhiều bước «Nhập <loại> từ file», các bước: «Chọn loại», «Tải file», «Xem trước», «Kết quả». Có bảng «Cột nhận của loại» với «Tên cột», «Ý nghĩa», «Yêu cầu» («Bắt buộc» hoặc «Tuỳ chọn»), «Ví dụ (dữ liệu giả)».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt8-b3]
4. Kéo file CSV vào khung, hoặc bấm «chọn file».
   *Bạn thấy:* tên file, số dòng, số cột. Nếu file sai: «File thiếu cột bắt buộc: …. Sửa tên cột rồi chọn lại.» hoặc «File không đọc được. Chỉ nhận file CSV (UTF-8)…».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt8-b4]
5. Bấm «Tiếp» để xem trước.
   *Bạn thấy:* các ô đếm «Tất cả dòng», «Hợp lệ», «Trùng (bỏ qua)», «Lỗi (bỏ qua)» (bấm ô để lọc), và bảng «Kết quả từng dòng» với «Dòng», «Kết quả», «Giải thích», «Cảnh báo». Chưa có gì được nạp ở bước này.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt8-b5]
6. Xem kỹ dòng «Lỗi» và «Trùng». Cần sửa thì bấm «Tải dòng lỗi và trùng», sửa file, rồi «Đổi file» và chọn lại. Hài lòng thì bấm «Nạp thật».
   *Bạn thấy:* khi xong, tiêu đề đổi thành «Đã nạp <loại>» kèm «N dòng đã nạp, N dòng trùng bỏ qua, N dòng lỗi (tổng N dòng).»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt8-b6]
7. Nếu nạp **Người dùng**: bấm «Tải file mật khẩu tạm» ngay, rồi mới bấm «Xong».
   *Bạn thấy:* chữ «Đã tải.» cạnh nút; chưa tải thì chưa đóng được hộp.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt8-b7]

⚠ **Bước 6 «Nạp thật» và bước 7 không hoàn tác bằng nút.** Dữ liệu đã nạp muốn sửa phải sửa từng bản ghi, hoặc báo kỹ thuật. File mật khẩu tạm chỉ tải được một lần.

## Sau bước này
- **Ai làm tiếp:** nạp loại kế tiếp theo thứ tự (cột «Cần có trước»). Giao mật khẩu tạm cho từng người (nếu nạp Người dùng).
- **Bạn xem ở đâu:** màn **Người dùng** với người dùng đã nạp; các màn Phụ huynh, Học sinh, Lớp… với loại tương ứng. Loại Cơ hội: hộp kết quả có thêm «Báo cáo cơ hội hợp lệ» (theo giai đoạn, dòng thiếu thông tin em).

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Thấy lỗi ở bước xem trước | Chưa nạp gì: «Đổi file» và chọn lại file đã sửa |
| Đã nạp nhưng sửa dữ liệu trong file | Sửa file rồi nạp lại: dòng đã nạp báo «Trùng», bỏ qua, nên **không** cập nhật dữ liệu cũ. Sửa trực tiếp ở màn của bản ghi đó |
| Nạp sai thứ tự (thiếu loại có trước) | Dòng báo lỗi, không nạp. Nạp loại thiếu trước, rồi nạp lại |
| Quên tải file mật khẩu tạm | Dùng «Đặt lại mật khẩu» ở bài Người dùng (qt1) cho từng người |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «File thiếu cột bắt buộc: …» | thiếu tên cột | sửa dòng đầu theo file mẫu |
| «File không đọc được. Chỉ nhận file CSV (UTF-8)…» | sai định dạng | lưu lại bằng Excel: CSV UTF-8 |
| «File chưa có dòng dữ liệu nào (chỉ có dòng tên cột).» | file rỗng | điền dữ liệu |
| «File có N dòng, tối đa M dòng mỗi lần nạp. Tách file rồi chọn lại.» | file quá dài | chia nhỏ file |
| «Còn N dòng lỗi. Loại này không nạp từng phần…» | loại nạp cả khối | sửa hết dòng lỗi |
| «Phân hệ "…" chưa bật ở cơ sở …» (HMT_TINH_NANG_TAT) | cơ sở trong file chưa bật Vận hành lớp | bật công tắc (bài qt6) rồi nạp lại |
| «Lớp chưa có giáo viên (N)» | lớp vẫn nạp, thiếu giáo viên | gán giáo viên sau |

## Tập trên dữ liệu mẫu
- **Cần:** `bgd.tap` (Admin) trên **staging**.
- **Dùng:** chỉ file CSV tự tạo từ «Tải file mẫu» với dữ liệu giả (họ tên «Nguyễn Văn A» và số điện thoại giả). Thử theo thứ tự: Người dùng (1–2 dòng) → Phụ huynh → Học sinh.
- Chưa có trong bộ mẫu: file CSV mẫu đủ nhiều loại để tập. Không dùng dữ liệu thật.

## Tự kiểm: bạn làm được khi
- [ ] Bạn tải được file mẫu, điền 2 dòng giả, đến bước xem trước và đọc đúng số dòng «Hợp lệ», «Trùng», «Lỗi».
- [ ] Bạn nạp được 1 loại trên staging và nói được vì sao nạp lại không làm nhân đôi.
- [ ] Bạn nói được hệ thống có mang mật khẩu cũ sang không (không) và mật khẩu tạm lấy ở đâu.

**Bước trước:** Công tắc tính năng theo cơ sở (qt6) · **Bước sau:** Người dùng (qt1) để giao mật khẩu tạm hoặc đặt lại

## Ghi chú cho người soát (không hiển thị cho người học)
- Tên menu và tiêu đề trang là «Nhập dữ liệu»; bản đồ màn hình (QT-18) ghi «Nhập dữ liệu cũ»; bài dùng chữ trên màn.
- Bản đồ màn hình QT-18 nói chỉ có ba loại (Người dùng, Phụ huynh, Học sinh); mã nguồn hiện có tám loại (thêm Lớp, Ghi danh, Số dư, Cơ hội, Phiếu test). Bài theo mã nguồn (importKinds.ts). Tên «Ghi danh» đã xác nhận trong importKinds.ts.
- Giới hạn «tối đa N dòng mỗi lần» là tham số; bài không ghi con số.
- Bước tải trong hộp: bước 2 «Tải file» có nút «Tiếp»; ở «Xem trước» nút tiếp là «Nạp thật» và nút lùi là «Đổi file» (theo ImportDataDialog).
- Chưa xác nhận trên staging: «Báo cáo nạp» (lỗi theo loại) hiện với loại nào; không mô tả chi tiết.
- Hệ thống tạo mật khẩu tạm bằng Edge Function (docs/nghiep-vu/nap-du-lieu.md): xác nhận không có chỗ nào nhập mật khẩu cũ; cột CSV Người dùng không có cột mật khẩu.
