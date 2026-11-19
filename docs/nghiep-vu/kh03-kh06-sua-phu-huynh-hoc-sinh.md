# KH-03 Sửa phụ huynh, KH-06 Sửa học sinh (migration 570)

Luật: R-CRM-27 (không Tạo tay, chỉ Sửa và Gộp), R-CRM-28 (cơ sở tiếp nhận chỉ Admin), R-CRM-25 (bản đã gộp chỉ đọc), R-CRM-31, R-V2-04, Đ165.

| Hàm | Làm gì | Ai gọi | Lỗi |
|---|---|---|---|
| `app.update_parent(p_id, p_data)` | Sửa họ tên, SĐT, SĐT 2, người thân, tỉnh, phường, địa chỉ (khoá không gửi thì giữ nguyên) | Quyền Phụ huynh · Sửa ở cơ sở của hồ sơ | HMT_KHONG_TIM_THAY, HMT_KHONG_CO_QUYEN, HMT_BAN_GHI_DA_GOP, HMT_THIEU_THONG_TIN, HMT_SDT_SAI, HMT_SDT_TRUNG, HMT_CHI_ADMIN_DOI_CO_SO |
| `app.update_student(p_id, p_data)` | Sửa họ tên, ngày sinh, năm sinh, khối, trường, loại trường, giới tính, mục tiêu | Quyền Học sinh · Sửa ở cơ sở của hồ sơ | thêm HMT_THIEU_HOC_SINH, HMT_NAM_SINH_SAI, HMT_HOC_SINH_TRUNG |
| `app.get_parent_edit_refs(p_id)` | Trả mã tỉnh, mã phường để đổ vào ô chọn khi Sửa | Quyền Phụ huynh · Xem | HMT_KHONG_TIM_THAY, HMT_KHONG_CO_QUYEN |

Luật chính: SĐT (số chính hoặc số thứ hai) không trùng phụ huynh khác; cùng phụ huynh không có hai em trùng họ tên (không dấu) và năm sinh; có ngày sinh thì năm sinh phải khớp; đổi cơ sở tiếp nhận chỉ vai Admin (giao diện hiện chỉ xem, Admin đổi qua ticket Chuyển cơ sở theo R-CRM-28).
Kiểm thử: `supabase/tests/database/570_kh03_kh06_sua_ho_so.test.sql` (30 bài), e2e `khach-hang.spec.ts`.
Chưa làm (PR sau): KH-07 Gộp ngay trên bản ghi phụ huynh, học sinh (hàm `merge_parents`, `merge_students` đã có; hộp thoại gộp dùng chung với TS-10).
