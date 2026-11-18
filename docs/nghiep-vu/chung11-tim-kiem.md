# CHUNG-11 Tìm kiếm toàn hệ thống (migration 552)

`app.search_records(p_query)` (S03-15): tìm không dấu theo tên, số điện thoại, mã mới, mã cũ. Chữ ngắn hơn `search_min_length` thì không tìm. Mỗi loại tối đa `search_result_max` dòng. Chạy bằng quyền người gọi (không security definer) nên RLS cắt theo quyền; hồ sơ phụ huynh, học sinh dùng chung toàn hệ thống (R-CRM-26).

Loại: STUDENT, PARENT, LEAD, OPPORTUNITY, ORDER, RECEIPT, CLASS, USER_ACCOUNT. Mọi bảng đã có chỉ mục gin trgm trên `search_text`.

Giao diện: ô tìm ở thanh trên CRM (`src/layout/GlobalSearch.tsx`), kết quả nhóm theo loại, bàn phím lên/xuống/Enter/Esc; điện thoại thu thành biểu tượng. pgTAP `552_chung11_tim_kiem.test.sql`.
