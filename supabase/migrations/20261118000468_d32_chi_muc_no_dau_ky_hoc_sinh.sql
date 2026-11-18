-- Migration 468 (Code D, 19/11/2026): thẻ D32, rà chỉ mục các bảng do lane D viết (hoàn phí, phiếu chi, dừng học, số dư, bảo lưu, chuyển lớp, khoản tiền vào).
-- Kết quả rà (docs/nghiep-vu/ra-chi-muc-lane-d.md): mọi khoá ngoại có chỉ mục, TRỪ: (1) money_in.opening_debt_student_id; (2) các khoá ngoại ghép (reason_catalog, reason_code) tới catalog_item.
-- (2) KHÔNG thêm chỉ mục: bảng danh mục không bao giờ xoá hay đổi mã (chỉ Ngừng), nên chỉ mục chỉ có tác dụng cho kiểm khoá khi xoá, không bao giờ xảy ra; thêm chỉ mục chỉ tốn ghi.
-- (1) thêm chỉ mục: tra «các khoản thu nợ đầu kỳ của một học sinh» (màn thu nợ, hoàn tác) và kiểm khoá ngoại khi dữ liệu học sinh đổi. Chỉ mục một phần (chỉ dòng có học sinh), nhỏ.

create index if not exists money_in_opening_student_idx on app.money_in (opening_debt_student_id) where opening_debt_student_id is not null;
