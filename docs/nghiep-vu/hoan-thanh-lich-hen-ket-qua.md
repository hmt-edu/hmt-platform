# Hoàn thành lịch hẹn kèm Kết quả cuộc gọi và Hẹn lần sau (migration 628)

Code D, 23/11/2026, thẻ D-23-22 (anh duyệt 15:54, Chat chốt 5 điểm 16:04). Luật: R-CRM-04, TS-13. Đề xuất gốc: `docs/de-xuat/hoan-thanh-lich-hen-ket-qua-cuoc-goi.md`.

| Thành phần | Nội dung |
| --- | --- |
| Danh mục `APPOINTMENT_RESULT` | Kiểu mở, quản trị ở QT-07: `DA_TU_VAN_QUAN_TAM`, `HEN_GOI_LAI`, `KHONG_NGHE_MAY`, `KHACH_TU_CHOI`, `SAI_SO`, `DA_CHOT_DANG_KY` («Đã chốt đăng ký» chỉ là nhãn, không đổi giai đoạn) |
| Cột `app.appointment` | `result_code` (chỉ khi Hoàn thành), `result_note` (≤ 1000 ký tự, không bắt buộc), `next_appointment_id` |
| Tham số `appointment_call_result_required` | Mặc định **TẮT** cho tới khi hộp giao diện mới lên; bật thì lịch loại Gọi điện (không phải lịch tự nhắc) phải có kết quả |
| `complete_appointment(id, kết quả, ghi chú, hẹn lúc, loại, tiêu đề)` | Tham số mới đều có mặc định nên cách gọi một tham số cũ vẫn chạy. Lỗi: `HMT_LICH_HEN_TRANG_THAI_SAI`, `HMT_THIEU_KET_QUA`, `HMT_KET_QUA_KHONG_HOP_LE`, `HMT_GHI_CHU_DAI`, `HMT_HEN_LAN_SAU_QUA_KHU`, `HMT_LICH_HEN_KHONG_HEN_LAN_SAU` |
| Hẹn lần sau | Cùng lead/cơ hội, loại mặc định = loại vừa làm, chủ = người hoàn thành, tiêu đề mặc định «Gọi lại: …»; gọi `create_appointment` trong cùng giao dịch (cần quyền Lịch hẹn · Tạo) |
| `reopen_appointment` | Xoá kết quả và ghi chú; giữ `next_appointment_id` |

Chưa làm (giao diện, bước 2): hộp K08 «Hoàn thành lịch hẹn» chờ khung Design; đọc kết quả ở danh sách, bản ghi, xuất file (`list_appointments`, `export_appointments`) làm cùng bước 2 khi cần hiển thị. Hiện kết quả đã ghi vào dòng lịch sử của hồ sơ.
