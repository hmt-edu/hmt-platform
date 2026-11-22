# CS-14 Dừng học: Xử lý tiền còn lại và Ngày dừng (migration 618)

Code D, 23/11/2026, thẻ D-23-07 (Chat chốt 02:32). Luật: R-GD-16, R-TIEN-28, R-TIEN-33, R-TIEN-01, R-V2-24. Khung: `CSN06e_dung_hoc`.

## Hàm đổi
| Hàm | Đổi gì |
| --- | --- |
| `create_ticket_task` (bản 571) | Phiếu `DUNG_HOC` kiểm sớm `money_mode` (`HOAN_TIEN` hoặc `GIU_SO_DU`; trống = `GIU_SO_DU` như trước) và `stop_date`. Lỗi: `HMT_PHIEU_DU_LIEU_SAI`, `HMT_DUNG_HOC_NGAY_SAI`. |
| `execute_ticket_task` (bản 567) | Nhánh `DUNG_HOC`: `HOAN_TIEN` gọi `apply_refund_request` hoàn **toàn bộ** (phí xử lý, phiếu chi, người duyệt từng cấp lấy từ nhật ký phiếu); `GIU_SO_DU` gọi `apply_enrollment_stop` như cũ. Kết quả phiếu ghi `money_mode`. |

## Tham số
`stop_date_max_days_ahead` (mặc định 0, 0 đến 30 ngày): «Ngày dừng» không được sau hôm nay quá số ngày này.

## Chỗ cần biết
- **Ngày dừng chỉ ghi nhận** trong payload, KHÔNG đổi cách tính giờ.
- Hoàn tiền dùng lý do trong danh mục lý do dừng học; mã lý do phải có cả trong danh mục lý do hoàn phí (bộ mã mặc định trùng nhau).
- Hoàn tiền kiểm cờ HOAN_PHI của cơ sở (như phiếu Hoàn học phí).
