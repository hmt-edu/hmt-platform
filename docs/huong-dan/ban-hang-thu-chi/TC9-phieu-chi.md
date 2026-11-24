---
id: tc9
ten: Phiếu chi, kể cả chi hoàn học phí
vai: [ke-toan, truong-co-so]
phan_he: thu-chi
ma_man: [TC-10, TC-11, TC-12]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Phiếu chi, kể cả chi hoàn học phí

**Làm xong bạn có:** tiền hoàn đã chi cho phụ huynh và phiếu chi ở «Đã chi».
**Ai làm:** Kế toán ghi nhận chi; Trưởng cơ sở xem (không thấy nút «Ghi nhận đã chi»). **Màn:** **Phiếu chi**.

## Cần nhớ
- Phiếu chi **không tạo tay**: hệ thống tạo khi yêu cầu «Hoàn học phí» đã được duyệt đủ hai cấp (Trưởng cơ sở rồi Kế toán) và người tạo bấm «Thực hiện». Phiếu mới ở «Chờ chi».
- Một người **không duyệt hai cấp** của cùng một phiếu nghiệp vụ.
- Số tiền hoàn do máy chủ tính (giờ còn lại × giá sau chiết khấu, trừ phí xử lý). Bạn không nhập số.

## Các bước
1. Duyệt cấp Kế toán: mở phiếu **Hoàn học phí** đang chờ (từ «Việc chờ tôi duyệt»), kiểm số liệu, bấm **«Duyệt»**. [CHƯA CHỤP: chờ tài khoản staging]
2. Người tạo phiếu bấm **«Thực hiện»**. *Bạn thấy:* hệ thống tính hoàn, trừ giờ và tạo phiếu chi `PC-…` ở «Chờ chi». [CHƯA CHỤP]
3. Vào **Phiếu chi**, mở phiếu: xem «Phụ huynh đã đóng cho ghi danh», «Số tiền hoàn trước phí», «Số tiền hoàn». [CHƯA CHỤP]
4. Chuyển tiền thật cho phụ huynh ngoài hệ thống. Rồi ghi «Ghi chú chi» và bấm **«Ghi nhận đã chi»**. *Bạn thấy:* phiếu chi sang «Đã chi». [CHƯA CHỤP]
5. Cần giấy tờ: dùng bản in «Hoàn học phí cho phụ huynh». [CHƯA CHỤP]

⚠ **Chỉ bấm «Ghi nhận đã chi» sau khi đã chuyển tiền thật.** Ghi nhầm không hoàn tác bằng nút.

## Sau bước này
- **Ai làm tiếp:** CSKH báo phụ huynh; hồ sơ phụ huynh thấy khoản hoàn.
- **Bạn xem ở đâu:** **Phiếu chi**, lọc «Chờ chi» và «Đã chi».

## Lỗi hay gặp
| Mã | Nghĩa là | Làm gì |
|---|---|---|
| `HMT_HOAN_PHI_DANG_MO` | ghi danh đã có yêu cầu hoàn phí chưa xong | xử lý yêu cầu đó trước |
| `HMT_HOAN_PHI_GIO_SAI` | giờ hoàn phải lớn hơn 0 và không quá giờ còn lại (không tính giờ tặng) | sửa số giờ ở phiếu |
| `HMT_PHIEU_MOT_NGUOI_HAI_CAP` | một người không duyệt hai cấp | nhờ người khác duyệt cấp còn lại |
| `HMT_KHONG_CO_QUYEN` | phiếu ở cấp Quản lý cơ sở: Kế toán không duyệt cấp này | chờ Trưởng cơ sở hoặc Admin |

## Hỏi đáp
- **Phụ huynh muốn giữ tiền cho đơn sau?** Chọn giữ thành «số dư khách hàng» ở phiếu dừng học, không tạo phiếu chi (bài «Số dư khách hàng»).
- **Vì sao không có nút tạo phiếu chi?** Phiếu chi chỉ sinh từ yêu cầu hoàn học phí đã duyệt.

## Tập trên dữ liệu mẫu
- **Cần:** 3 tài khoản (CSKH tạo yêu cầu, Trưởng cơ sở, Kế toán). Bộ mẫu chưa có phiếu chi: `[CẦN BỔ SUNG]`.
