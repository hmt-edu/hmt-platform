# D-23-30 · Phiếu Hoàn học phí, Dừng học, Chuyển phí kiểm phạm vi dữ liệu (migration 636)

Lỗi CAO từ rà soát N0 #17: qua rpc, phiếu nhận ghi danh của em khác hoặc cơ sở khác; phiếu Chuyển phí nhận phụ huynh bất kỳ.

| Thành phần | Việc |
|---|---|
| Trigger `ticket_task_check_scope` (hàm `app.ticket_task_check_scope`, nội bộ) trên `app.ticket_task` | Với loại HOAN_PHI, DUNG_HOC, CHUYEN_PHI: ghi danh trong payload phải của đúng học sinh gắn với ticket, đúng cơ sở của ticket, còn hiệu lực (lúc tạo và lúc trình). HOAN_PHI kiểm sớm loại hoàn và giờ hoàn bằng `compute_refund`. CHUYEN_PHI: `to_parent_id` phải cùng cơ sở của ticket. Payload khoá sau khi tạo. Lỗi `HMT_PHIEU_DU_LIEU_SAI`. |

Chọn trigger thay vì sửa `create_ticket_task`, `execute_ticket_task`: nhiều PR cùng sửa hai hàm này, bản sau ghi đè bản trước; trigger đứng ngoài nên không bị ghi đè và phủ mọi đường ghi.
Còn mở: chưa có bảng quan hệ anh chị em nên «phụ huynh nhận» chỉ ràng buộc cùng cơ sở, chưa ràng buộc là anh chị em thật. Phiếu Hoàn học phí thiếu dữ liệu nay bị chặn lúc tạo (trước đây lúc thực hiện).
