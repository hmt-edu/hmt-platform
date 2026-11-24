---
id: tc7
ten: Công nợ và thu nợ đầu kỳ
vai: [ke-toan, truong-co-so, tu-van, cskh]
phan_he: thu-chi
ma_man: [TC-13, TC-02]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Công nợ và thu nợ đầu kỳ

**Làm xong bạn có:** biết đơn nào còn phải thu, đến hạn hay quá hạn; thu được khoản nợ từ trước khi dùng hệ thống.
**Ai làm:** Kế toán, Trưởng cơ sở xem công nợ; Tư vấn, CSKH lập phiếu thu nợ đầu kỳ. **Màn:** **Công nợ**; **Phiếu thu** → «Thu nợ đầu kỳ».

## Cần nhớ
- Công nợ lấy từ **điều khoản thanh toán** của đơn (đợt, hạn đóng).
- **Nợ đầu kỳ** là khoản phụ huynh còn nợ từ trước khi chuyển sang hệ thống; thu bằng phiếu thu riêng, cũng qua hai bước duyệt như phiếu thu thường.
- Tính năng này **tắt mặc định** theo cơ sở: chưa bật thì không thu được.

## Các bước (xem công nợ)
1. Vào **Công nợ**: cột «Phụ huynh», «Đơn hàng», «Sale», «Đợt», «Hạn đóng», «Phải đóng (đ)», «Đã đóng (đ)», «Còn nợ (đ)», «Tình trạng». [CHƯA CHỤP: chờ tài khoản staging]
2. Lọc sắp đến hạn hoặc quá hạn; nhóm theo «Group By» nếu cần (Cơ sở, Sale, Tình trạng); bấm dòng để mở đơn. [CHƯA CHỤP]

## Các bước (thu nợ đầu kỳ)
1. Vào **Phiếu thu** → **«Thu nợ đầu kỳ»**. [CHƯA CHỤP]
2. Chọn «Phụ huynh», nhập «Số tiền», chọn «Hình thức» → **«Tạo phiếu nháp»**. *Bạn thấy:* phiếu Nháp thu nợ đầu kỳ. [CHƯA CHỤP]
3. Điền chứng từ, bấm **«Trình quản lý»**; quản lý rồi Kế toán duyệt (bài «Duyệt phiếu thu: bước quản lý», «Kế toán duyệt phiếu thu»). *Bạn thấy:* nợ đầu kỳ của phụ huynh giảm đúng số đã duyệt. [CHƯA CHỤP]

## Sau bước này
- **Ai làm tiếp:** quản lý rồi Kế toán duyệt.
- **Bạn xem ở đâu:** **Công nợ** và **Số dư khách hàng**.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Phiếu nợ đầu kỳ còn Nháp | sửa, hoặc «Huỷ phiếu thu» |
| Đã duyệt nhầm số | Kế toán hoàn tác khoản tiền vào (bài «Khoản tiền vào và hoàn tác») |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| «Thu nợ đầu kỳ chưa được bật cho cơ sở này» (`HMT_TINH_NANG_TAT`) | tính năng chưa bật | báo Trưởng cơ sở hoặc Admin bật |

## Hỏi đáp
- **Quá hạn thì có khoá lớp không?** Không: «quá hạn» chỉ là nhãn để nhắc thu.
- **Nợ đầu kỳ có vào cọc không?** Khoản thu được duyệt sẽ thành khoản tiền vào như thường.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản Kế toán và một tài khoản Tư vấn hoặc CSKH. Bộ mẫu chưa có công nợ và nợ đầu kỳ: `[CẦN BỔ SUNG]`.
