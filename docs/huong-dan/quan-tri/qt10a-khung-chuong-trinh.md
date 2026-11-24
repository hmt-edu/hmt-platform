---
id: qt10a
ten: Khung chương trình và danh sách bài học
vai: [quan-tri]
phan_he: quan-tri
ma_man: [CH-05, CH-06]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Khung chương trình và danh sách bài học

**Làm xong bạn có:** một khung chương trình (môn, khối, cấp độ, năm học) với danh sách bài đúng thứ tự, sẵn để dùng khi tạo lớp.
**Ai làm:** Admin (đủ quyền). Trưởng cơ sở chỉ xem. **Màn:** menu **Cấu hình** → **Khung chương trình**.

> Video: [VIDEO: qt10a]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Đây là thao tác thật trên môi trường đang dùng.** Tập thì chỉ tập trên staging.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin. Vai khác vào được màn nhưng không thấy nút «Tạo bản mới», «Thêm bài», «Ngừng»; màn bài học ghi «Bạn chỉ xem được khung chương trình. Admin sửa.»
- [ ] Môn và Khối bạn cần đã có trong danh mục (xem bài danh mục). Môn hoặc khối đã ngừng thì không chọn được.
- [ ] Bạn biết năm học (ví dụ 2026–2027) và cấp độ (Cơ bản hoặc Nâng cao).

## Luật cần nhớ (lời thường)
- Mã khung ghép từ Môn, Khối, Cấp độ, Năm học, ví dụ `TOAN-K03-CB-2627`. Bản đầu không có đuôi; bản kế thêm `-v2`, `-v3`.
- **Tạo bản mới sao chép TOÀN BỘ bài từ bản trước** (giữ thứ tự, tên, gợi ý). Bản đầu mới tạo chưa có bài.
- Mã bài dạng `<mã khung>-B01`, cấp một lần và **không đổi khi bạn đổi thứ tự** bài. Số của bài đã dùng không cấp lại.
- Không xoá khung hay bài. «Ngừng» chỉ ẩn khung khỏi chỗ chọn khi tạo lớp mới; lớp đang dùng giữ nguyên.
- Lớp chỉ lưu **tên khung dạng chữ**, nên sửa bài trong khung không làm đổi lớp cũ.

## Các bước
1. Vào **Cấu hình** → **Khung chương trình**.
   *Bạn thấy:* tiêu đề «Khung chương trình», các ô lọc Môn, Khối, Cấp độ, Năm học, Trạng thái, và bảng: Mã khung, Môn, Khối, Cấp độ, Năm học, Trạng thái, Thao tác.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt10a-b1]
2. Bấm **Tạo bản mới**. Chọn đủ Môn, Khối, Cấp độ, Năm học.
   *Bạn thấy:* dòng «Mã khung» tự hiện mã sắp cấp. Nếu bộ này đã có bản, hộp thêm ô «Sao chép bài từ bản» và dòng «Sao chép N bài từ bản …». Chưa có bản thì ghi «Bản đầu của khung này, chưa có bài.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt10a-b2]
3. Bấm **Tạo bản mới** trong hộp để xác nhận.
   *Bạn thấy:* thông báo «Đã tạo khung <mã>.» và khung mới ở bảng.
4. Bấm mã khung để mở danh sách bài.
   *Bạn thấy:* mã khung làm tiêu đề, nhãn trạng thái, dòng «Môn · Khối · Cấp độ · Năm học · N bài», bảng bài.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt10a-b4]
5. Bấm **Thêm bài**, nhập «Tên bài» (bắt buộc), «Nội dung gợi ý» (không bắt buộc), bấm xác nhận.
   *Bạn thấy:* «Đã thêm bài.» Bài mới nằm cuối danh sách, có mã `-Bnn` kế tiếp.
6. Sửa một bài: bấm nút sửa ở dòng, đổi tên hoặc gợi ý, bấm lưu.
   *Bạn thấy:* «Đã lưu bài.» Mã bài giữ nguyên.
7. Đổi thứ tự: dùng nút **Lên** / **Xuống** ở cuối dòng (không kéo thả). Dòng đầu không Lên được, dòng cuối không Xuống được.
   *Bạn thấy:* dòng đổi chỗ, mã bài không đổi.

⚠ **«Nhập từ file» là nút mờ, chưa dùng được.** Thêm bài từng dòng.

## Ngừng một khung
Ở bảng, dòng khung đang dùng, bấm **Ngừng** → hộp «Ngừng khung <mã>?» → **Ngừng khung** (hoặc **Giữ lại** để thôi). Khung ngừng không hiện ở chỗ chọn khi tạo lớp mới.

## Sau bước này
- **Ai làm tiếp:** người tạo lớp chọn được khung (bản đang dùng) khi tạo lớp.
- **Bạn xem ở đâu:** bảng khung; lọc Trạng thái để thấy khung đã ngừng. Mọi lần đổi có trong nhật ký thao tác.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Tạo nhầm khung | Không xoá được. Bấm «Ngừng» ở dòng khung đó |
| Ngừng nhầm | Mở khung đó và dùng lại (quyền Sửa); nếu không thấy nút, báo người quản trị hệ thống |
| Tên bài sai | Sửa tại dòng, mã bài giữ nguyên |
| Thứ tự sai | Dùng Lên/Xuống đưa về đúng chỗ |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| Lỗi «đã có khung» (HMT_KHUNG_DA_CO) khi tạo | bộ Môn/Khối/Cấp độ/Năm này đã có bản đầu | Tạo lại: hộp sẽ tự chuyển sang tạo bản kế |
| Lỗi năm học (HMT_NAM_HOC_KHONG_HOP_LE) | năm học không phải hai năm liền nhau | Chọn lại năm học trong danh sách |
| Lỗi cấp độ (HMT_CAP_DO_KHONG_HOP_LE) | cấp độ ngoài Cơ bản, Nâng cao | Chọn lại |
| Lỗi thiếu tên bài (HMT_THIEU_TEN_BAI) | tên bài để trống | Nhập tên bài |
| Lỗi thứ tự bài (HMT_THU_TU_BAI_SAI) | dữ liệu bị đổi giữa chừng | Tải lại trang, làm lại |
| «Không tải được khung chương trình» | lỗi mạng | Bấm «Thử lại» |
| «Bạn không có quyền xem màn này» | vai trò chưa được cấp xem | Báo Admin |

## Tập trên dữ liệu mẫu
- **Cần:** `bgd.tap` (Admin) trên **staging**.
- **Dùng:** tạo khung cho một môn và năm học tập, thêm 3 bài, đổi thứ tự bài 3 lên đầu, rồi Tạo bản mới của đúng bộ đó và kiểm bản `-v2` có đủ 3 bài. Xong thì Ngừng cả hai khung tập.
- Chưa có trong bộ mẫu: khung dành riêng cho việc tập (khung tạo ra sẽ nằm lại trên staging).

## Tự kiểm: bạn làm được khi
- [ ] Bạn tạo được bản đầu và bản `-v2`, thấy bản `-v2` có đủ bài của bản đầu.
- [ ] Bạn đổi thứ tự bài mà mã bài không đổi.
- [ ] Bạn nói được vì sao nút «Nhập từ file» không bấm được.
