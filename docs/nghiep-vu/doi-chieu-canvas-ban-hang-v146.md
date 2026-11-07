# Đối chiếu canvas Bán hàng, Thu chi (v146 và bổ sung v2), 05/11/2026

Nguồn: `design/hmt-canvas-9933/` (HMT Platform v146, `1793854902-9933`) và `design/ban-hang-thu-chi-bo-sung/` (bổ sung v6, `1794026008-252a`, thay bản v2 `1793860849-8262` đã xoá); ghi chú anh Trường: `THAY_DOI_BAO_GIA_DON_PHIEU_THU.md` (chép dưới đây), `design/ban-hang-thu-chi-bo-sung/GHI_CHU_CHO_CODE.md`.
Quy tắc: khung có ở cả hai canvas thì canvas bổ sung thắng; canvas vênh luật thì **làm theo luật**.

## Bản chuẩn
v146 = v68 (`1793844909-31f7`, anh Trường đã sửa và OK) cộng đúng hai thay đổi: (1) bỏ hai ô thanh toán ở khung Đơn hàng; (2) dòng TC-02 trong `Muc_luc_man` trỏ sang canvas bổ sung. So với `6f57`: `canvas.json` giống hệt byte, nội dung 67 khung khác (do v68).

## Nhóm A: chỉ giao diện, làm cùng lúc làm Bán hàng (~12/11), không cần hỏi thêm
Bỏ "Hình thức thanh toán" và "Cơ sở thu tiền" khỏi khối thông tin đơn hàng (giữ "Kiểu thanh toán"), Đ258. 24 khung:
- BH05 (17): BH05_tao, _tao_trang, _nhap, _nhap_loi, _trinh, _chua_ql, _duyet, _duyet_ht, _duyet_thay, _tu_duyet, _tu_choi, _huy, _huy_chan, _chan_em, _tran, _thu, _vao_tai_tuc
- BH07 (1): BH07_duyet. BH08 (5): _chua_buoi, _co_buoi, _luan_phien, _tai, _trong. BH09 (1): BH09_bat.
Phiếu thu, phiếu chi (TC02_*, TC03_*, TC05_*, TC11, TC17_*) giữ hai ô này.

## Nhóm B: có thay đổi nghiệp vụ hoặc DB, CHƯA tạo migration, CHƯA viết mã
Lập bảng "sửa gì, ở đâu" gửi anh duyệt trước. Quy tắc voucher và ưu đãi linh hoạt chưa vào luật: chỗ khác luật thì hỏi anh qua Chat trước.
1. Thu nợ đầu kỳ (4 khung `TC02_no_dau_ky_*`): ghi chú mục 4.
2. Chiết khấu chip, ưu đãi linh hoạt, voucher (Báo giá, Đơn hàng): ghi chú mục 2.
3. Bản in báo giá `BH03_in`: ghi chú mục 5.
4. Vượt trần chiết khấu chỉ cảnh báo, không chặn (R-TIEN-29): ghi chú mục 1.

## Chưa có dữ liệu, không đoán
Số giờ gói 6 tháng của 12 sản phẩm; giá online của 2 sản phẩm (để trống như đã chốt).

## Kiểm gói (05/11/2026)
- v146: 485 file khung, `canvas.json` có 485 khung, tên khớp từng file. Bổ sung v2: 6 file, 6 khung, khớp.
