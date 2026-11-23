# CS-16 Nhận xét chờ gửi phụ huynh: hàm nghiệp vụ (migration 622)

Anh Trường chốt 23/11/2026: CS-16 sống lại (sửa R-V2-40). Lời nhắn là chữ giáo viên (`session_student_review.teacher_comment`, R-V2-39); CSKH chỉ xem, sao chép, xuất ảnh và đánh dấu đã gửi (R-CS-13).

| Hàm | Ai gọi | Việc |
|---|---|---|
| `app.list_parent_messages(bộ lọc, limit, offset)` | người có TICKET/SUA trong phạm vi cơ sở (CSKH, Admin) | Danh sách phân trang, bộ lọc `status` (CHO_GUI mặc định, DA_GUI), `q` (tên em, mã lớp), `branch_id`; kèm đếm hai chip. Chỉ em có mặt (R-GV-04) và lời nhắn không trống. Mã lỗi HMT_KHONG_CO_QUYEN. |
| `app.mark_parent_message_sent(mã điểm danh)` | như trên, đúng cơ sở của buổi | Ghi `parent_sent_at`, `parent_sent_by`; gọi lại không đổi lúc đã ghi. Cờ `exported` của giáo viên (R-V2-38) giữ riêng. |

Kiểm thử: `supabase/tests/database/622_cs16_nhan_xet_cho_gui.test.sql` (19 bài: đúng, bị chặn, quyền giáo viên, cơ sở khác, Admin).
