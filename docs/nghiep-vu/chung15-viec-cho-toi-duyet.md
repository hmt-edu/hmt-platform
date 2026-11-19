# CHUNG-15 Việc chờ tôi duyệt, phần DB (migration 556, Code F)

`app.list_my_approvals(bộ lọc, số dòng, bỏ qua)` → `{total, counts{loại: số}, rows[{kind, ref_id, code, subject_name, subject_code, detail, level_no, level_total, level_label, creator_name, waiting_since, branch_code}]}`. Bộ lọc: `kind`, `branch_id`. Chờ lâu nhất lên đầu; phân trang ở máy chủ. Hàm nội bộ `app.my_approval_items()` gom các nguồn (không mở cho người dùng).

Chỉ việc ĐẾN LƯỢT vai của người gọi, theo đúng điều kiện của hàm duyệt sẵn có:

| Loại (`kind`)       | Điều kiện                                                                                                     | Cấp          |
| ------------------- | ------------------------------------------------------------------------------------------------------------- | ------------ |
| DON_HANG            | đơn Đã trình, `can_approve_as_manager` (quản lý, Trưởng cơ sở route TRUONG_CS, Admin duyệt thay)              | 1/1          |
| PHIEU_THU           | Đã gửi: `can_approve_as_manager` (Admin không duyệt tiền, R-HT-01); Chờ kế toán: ACCOUNTING · Duyệt          | 1/2, 2/2     |
| LOP                 | Đã trình (Xác nhận), Đã xác nhận (Duyệt): CLASS · Duyệt                                                       | 1/2, 2/2     |
| YEU_CAU_BUOI        | Chờ duyệt: SESSION · Duyệt                                                                                    | 1/1          |
| HOAN_PHI, DUNG_HOC  | Chờ QL: ENROLLMENT · Duyệt; Chờ kế toán: ACCOUNTING · Duyệt                                                   | 1/2, 2/2     |
| BAO_LUU             | Chờ duyệt: ENROLLMENT · Duyệt                                                                                 | 1/1          |
| CHUYEN_LOP          | Chờ duyệt: ENROLLMENT · Duyệt ở cơ sở đi hoặc đến chưa duyệt                                                  | 1..2         |
| PHIEU_NGHIEP_VU     | phiếu Chờ duyệt, cấp hiện tại KE_TOAN (Kế toán hoặc Admin có TICKET · Duyệt) hoặc quản lý (TICKET · Duyệt)    | theo `levels` |

Người tạo không tự duyệt (Admin duyệt thay ở các loại có luật). Không có «chiết khấu vượt trần» (R-V2-11 bỏ). Khiếu nại và phiếu tái tục không có bước duyệt. Dòng việc chỉ để mở bản ghi, không duyệt hàng loạt.
Thời điểm đến lượt: thời điểm trình, hoặc thời điểm cấp trước duyệt (`manager_at`, `manager_approved_at`, sự kiện lớp). Phiếu nghiệp vụ lấy `submitted_at` (chưa có mốc từng cấp; có thể làm mịn sau).
Hiệu năng: mỗi nguồn quét dòng đang chờ nhờ chỉ mục sẵn có (branch_id, status_code, ...) và `receipt_waiting_accounting_idx`; EXPLAIN 100.000 phiếu thu, 200 chờ kế toán: dùng chỉ mục, 53 ms. Không thêm chỉ mục mới.

**Migration 557 (giao diện):** mỗi dòng có thêm `open_id`: id bản ghi để mở khi bấm dòng (id ghi danh cho hoàn phí, dừng học, bảo lưu, chuyển lớp; chính `ref_id` cho các loại còn lại). Màn: `/crm/viec-cho-duyet`; mã hiển thị của bốn loại trên là mã ghi danh.

**Migration 559 (hiệu năng):** `my_approval_items` tính phạm vi quyền một lần và lọc rẻ trước `can_approve_as_manager`; kết quả giữ nguyên. Đo trên dữ liệu giả 3.500 việc chờ: từ 2,2–2,8 giây xuống 10–50 ms.
