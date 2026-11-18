# Khung chương trình (CH-05, CH-06) · migration 300 (Code A, 18/11/2026)

Luật: R-LOP-07 (18/11/2026, anh Trường chốt: tạo bản mới SAO CHÉP TOÀN BỘ bài từ bản trước; bản đầu chưa khoá sửa bài, kể cả khi đã có lớp dùng vì lớp chỉ lưu tên khung dạng chữ), spec 02 (mã khung), canvas 1aab (CH05_*, CH06_*).
Quyền: phân hệ `CONFIG_TRAINING` có sẵn (migration 22): Admin đủ quyền toàn hệ thống; Trưởng cơ sở, CSKH, giáo viên, trợ giảng chỉ Xem. Không xoá khung hay bài; Ngừng là đổi trạng thái.

## Bảng
- `app.curriculum_frame`: `code` (khoá chính), môn, khối, cấp độ (`CB` hoặc `NC`, danh mục CLASS_TYPE), năm học `year_code` bốn số (2627 = 2026–2027, hai năm liền nhau), `version`, `status_code` (`DANG_DUNG`, `NGUNG`), `prev_frame_id`. Duy nhất theo (môn, khối, cấp độ, năm, phiên bản).
- `app.curriculum_lesson`: khung, `position` (vị trí hiện tại, đổi khi sắp xếp lại), `code` (mã bài `<mã khung>-Bnn`, cấp một lần, KHÔNG đổi khi đổi thứ tự), tên bài, nội dung gợi ý.

## Mã khung
`Môn-Khối-Cấpđộ-Năm`: `TOAN-K03-CB-2627` (bản đầu, không hậu tố), `-v2`, `-v3` cho bản kế. Hàm trợ giúp `app.curriculum_frame_code(môn, khối, cấp độ, năm, phiên bản)`.

## Hàm (đều `security definer`, kiểm quyền bên trong; giao diện gọi qua rpc)
| Hàm | Làm gì | Quyền | Lỗi có mã |
|---|---|---|---|
| `app.list_curriculum_frames(bộ lọc, giới hạn, vị trí)` | Danh sách khung, lọc `status` (mảng), `subject`, `grade`, `level`, `year`; phân trang ở máy chủ (mặc định 50, tối đa 100); kèm số bài | Xem | `HMT_KHONG_CO_QUYEN` |
| `app.get_curriculum_frame(id)` | Một khung kèm các bài theo thứ tự | Xem | `HMT_KHONG_CO_QUYEN`, `HMT_KHONG_TIM_THAY` |
| `app.create_curriculum_frame(môn, khối, cấp độ, năm)` | Tạo bản đầu (chưa có bài). Môn, khối phải còn dùng; cấp độ chỉ CB, NC; năm học hai năm liền nhau | Tạo | `HMT_CAP_DO_KHONG_HOP_LE`, `HMT_NAM_HOC_KHONG_HOP_LE`, `HMT_KHUNG_DA_CO` |
| `app.create_curriculum_version(id nguồn)` | Tạo bản kế (`-v2`, `-v3`...) và SAO CHÉP TOÀN BỘ bài (giữ thứ tự, tên, gợi ý, đuôi mã bài; đổi tiền tố theo mã khung mới). Khoá theo bộ (môn, khối, cấp độ, năm) để hai người không trùng số | Tạo | `HMT_KHONG_TIM_THAY` |
| `app.set_curriculum_frame_active(id, dùng)` | Ngừng (quyền Huỷ) hoặc Dùng lại (quyền Sửa) | Huỷ, Sửa | `HMT_KHONG_TIM_THAY` |
| `app.save_curriculum_lesson(khung, bài, tên, gợi ý)` | Bài rỗng = thêm vào cuối khung (mã `-Bnn` kế tiếp, không dùng lại số); có bài = sửa tên, gợi ý (mã giữ nguyên) | Sửa | `HMT_THIEU_TEN_BAI`, `HMT_KHONG_TIM_THAY` |
| `app.reorder_curriculum_lessons(khung, danh sách mã bài mới)` | Đổi thứ tự: danh sách phải gồm đúng tất cả bài của khung, mỗi bài một lần; chỉ đổi `position` | Sửa | `HMT_THU_TU_BAI_SAI` |
| `app.assert_curriculum_permission(hành động)` | Nội bộ: kiểm quyền Cấu hình đào tạo toàn hệ thống theo hành động | | `HMT_KHONG_CO_QUYEN` |

## Giao diện và kiểm thử
- Màn CH-05 `/crm/cau-hinh/khung-chuong-trinh` (danh sách, lọc, Tạo bản mới, Ngừng) và CH-06 `/crm/cau-hinh/khung-chuong-trinh/:id` (danh sách bài, Thêm bài, Sửa tại dòng, Lên/Xuống). Đổi thứ tự bằng nút Lên, Xuống thay cho kéo thả; «Nhập từ file» chỉ là nút mờ (khung chưa có hộp thoại).
- pgTAP: `supabase/tests/database/300_ch05_khung_chuong_trinh.test.sql` (31 bài). e2e: `e2e/khung-chuong-trinh.spec.ts` (4 bài, Admin giả `quantri2.cs5`).
- Chỉ mục: `curriculum_frame_list_idx` (trạng thái, môn, khối), `curriculum_frame_prev_idx`, khoá duy nhất (khung, vị trí). EXPLAIN trên 1.920 dòng giả: 0,08–0,13 ms.
