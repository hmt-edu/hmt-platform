# R-V2-44 «Chuyển người duyệt» (migration 400; PR #82; cờ `approver_reassign_enabled` TẮT mặc định)

Luật: `docs/spec/04-luat-nghiep-vu.md` R-V2-44 (chốt 18/11), R-HT-01 (Admin không duyệt tiền), R-HT-06, R-V2-41. Khung: canvas 9933 `TC17_admin`.

## Việc làm được
Admin (đã xác thực hai bước) đổi **người được giao duyệt bước quản lý** của đơn `DA_TRINH` hoặc phiếu thu `DA_GUI` có đường duyệt `QUAN_LY`. Admin **không** duyệt, không từ chối thay. Chứng từ vẫn ở đúng trạng thái và đúng `approval_route`; chỉ `assigned_approver_id` đổi. Đường `TRUONG_CS` (mọi Trưởng cơ sở duyệt được) và `TU_DUYET` không cần chuyển.

## Điều kiện (mỗi điều kiện một lỗi có mã, câu tiếng Việt hiện thẳng ở hộp)
| Điều kiện | Lỗi |
|---|---|
| Người gọi là Admin có hai bước | `HMT_KHONG_CO_QUYEN` |
| Cờ bật theo cơ sở của chứng từ | `HMT_TINH_NANG_TAT` |
| Chứng từ đang chờ bước quản lý | `HMT_SAI_TRANG_THAI` |
| Đường duyệt là `QUAN_LY` | `HMT_KHONG_CAN_CHUYEN` |
| Có lý do từ danh mục `REASSIGN_REASON` («Khác» cần ghi chú) | `HMT_LY_DO_THIEU` |
| Người nhận hợp lệ: còn hoạt động, không khoá, không phải người lập, không phải Admin hay Kế toán, có quyền Duyệt ở cơ sở, là quản lý trực tiếp của người lập hoặc Trưởng cơ sở của cơ sở; khác người đang được giao | `HMT_NGUOI_NHAN_KHONG_HOP_LE` |
| Người đã chốt không duyệt được: bị khoá, mất quyền Duyệt, hoặc quá `approver_reassign_after_hours` (48 giờ, tính từ lúc trình hoặc lần chuyển gần nhất) | `HMT_NGUOI_DUYET_CON_HIEU_LUC` |

## Hàm
`reassign_approver(loại, id, người nhận, mã lý do, ghi chú)`, `list_approver_candidates(loại, id)` (tối đa 50 người), `get_reassign_state(loại, id)` (nút hiện hay không), và hai hàm nội bộ `approver_candidate_problem`, `approver_unavailable_reason` (đã thu hồi quyền người đăng nhập, có bài pgTAP 42501).

## Lịch sử
Sự kiện `CHUYEN_NGUOI_DUYET` ở lịch sử đơn (`sales_order_event`, kèm lý do) và phiếu thu (`receipt_event`, lời ghi «Chuyển từ A sang B. Lý do: …»); thay đổi ghi `audit_log`.

## Giao diện
Nút «Chuyển người duyệt» ở bản ghi đơn và phiếu thu, chỉ hiện khi `get_reassign_state.can`; hộp chọn người nhận, lý do, ghi chú. Dòng thời gian hiện sự kiện mới.

## Kiểm thử
pgTAP `400_r_v2_44_chuyen_nguoi_duyet.test.sql` (42 bài): từng điều kiện đúng và bị chặn, quyền Trưởng cơ sở, Kế toán, Sale, Admin chưa hai bước, quá hạn 48 giờ, không chuyển liên tiếp, người nhận mới duyệt được, hàm phụ bị thu hồi quyền.
