# HMT Bán hàng & Thu chi · bổ sung: đọc trước

Canvas này **bổ sung** cho canvas chính **HMT Platform** (v146, `1793854902-9933`), vì canvas chính đã đầy giới hạn file.

## Quy tắc ưu tiên
- **Khung có ở cả hai canvas thì canvas bổ sung thắng.**
- Khung chỉ có ở canvas chính: dùng như trong canvas chính.
- Khi canvas vênh luật (`docs/spec/`): **Code làm theo luật**, xem `GHI_CHU_CHO_CODE.md`.

## Nội dung hiện có
- Màn **TC-02 · Thu nợ đầu kỳ**: 4 khung `TC02_no_dau_ky_*` (Tạo Nháp, Chờ kế toán duyệt, Đã duyệt, Lỗi vượt nợ), nhãn màn `Man_TC02_no_dau_ky`.
- Nợ tính theo từng em, ô Em bắt buộc. Luồng: Nháp → Chờ kế toán → Đã duyệt.
- **Từ 07/11/2026**: 15 khung BH05 (9) và TC02 (6) về nút và dòng thời gian khi sửa, nhãn màn `Man_BH05_sua_don`, `Man_TC02_sua_phieu`. Khung mới thay khung cũ cùng loại, xem GHI_CHU_CHO_CODE.md mục 6.
- **Từ 08/11/2026**: thêm 10 khung (6 dòng chặn trình của Đơn hàng và Phiếu thu, hộp BH-11, 3 khung Tạo theo khuôn bản ghi chung), nhãn màn `Man_Tao_khuon_chung`. 7 khung cũ đổi: bỏ khối đỏ "bị từ chối" (4 khung `*_tu_choi_xem`, `*_tu_choi_xac_nhan`), đổi chữ cảnh báo thành "Gửi lại, chưa sửa từ lần bị từ chối" (6 khung). Xem GHI_CHU_CHO_CODE.md mục 6 điểm 9 đến 13.
- **Từ 08/11/2026 (đợt 2)**: R-V2-11 (trần chiết khấu chỉ cảnh báo) sửa GHI_CHU mục 1 và chữ khung `BH02_tao_moi`; người lập chưa có quản lý trực tiếp thì Trưởng cơ sở duyệt: sửa 2 khung `*_nhap_xem_chua_ql` và thêm 6 khung (`*_nhap_xem_chua_ql_nguoi_khac`, `*_nhap_xem_chua_ql_khong_tcs`, `BH05_da_trinh_cho_tcs`, `TC02_da_trinh_cho_tcs`). Xem GHI_CHU_CHO_CODE.md mục 6 điểm 9 (c), (d) và điểm 14.
- **Từ 08/11/2026 (đợt 3, sau Chat kiểm)**: bỏ tên người trong nhật ký "Đã trình, chờ Trưởng cơ sở" (R-V2-41); chữ trần chiết khấu dưới bảng Dòng đơn của mọi khung BH05 đổi theo R-V2-11; khung `BH05_chua_ql_sua` đổi theo chữ mới; ô "Người duyệt: Trưởng cơ sở" ở `BH05_da_trinh_cho_tcs`; GHI_CHU mục 1 bỏ danh sách khung canvas chính.
- **Từ 08/11/2026 (đợt 4)**: `BH05_chua_ql_sua` chỉ giữ trường hợp có Trưởng cơ sở, bỏ hộp "Chưa trình được" (Q-133); khung `BH05_trinh_lai_chua_sua` có thêm ô "Người duyệt".
- **Từ 08/11/2026 (đợt 5)**: chip "Ưu đãi linh hoạt" (Q-144, R-V2-45): 8 khung mới (`BH02_chip_*` ×3, `BH05_chip_*` ×3, `BH05_log_tao_*` ×2), nhãn màn `Man_Chip_uu_dai`; cột Chiết khấu của 15 khung BH05 (gồm Tái tục sửa) và 3 khung Tạo (`BH05_tao_moi`, `BH05_tao_trang_moi`, `BH02_tao_moi`) đổi sang chip và cột Tổng %. Xem GHI_CHU_CHO_CODE.md mục 2.
- **Từ 08/11/2026 (đợt 6)**: Báo giá Sửa nháp theo chip (Q-161): `BH02_sua` đổi sang chip và thêm 3 khung `BH02_sua_chip_linh_hoat`, `BH02_sua_chip_vuot_han_muc`, `BH02_sua_chip_vuot_tran`. Ghi chú câu chờ PR Tái tục ở khung `BH05_vao_tai_tuc_sua` (Q-159). Xem GHI_CHU_CHO_CODE.md mục 8, 9.
- **K06c (thẻ hai tầng) bỏ**; bỏ nút "+ Thêm cả nhà" và "Nhân bản dòng" ở mọi khung (khung ở canvas chính: xem GHI_CHU_CHO_CODE.md).
- Mục lục: khung `Muc_luc_bs`. Design system và logo: bản sao từ canvas HMT Platform (`ds/hmt/`, `assets/hmt-logo.svg`).

## Liên kết
- Canvas chính: HMT Platform, https://claude.ai/artifact/KvsUknP8PTirpsVh8utRTR
- Mục lục canvas chính (`Muc_luc_man`) có một dòng trỏ sang canvas này.
- **Từ 10/11/2026 (đợt 7, Q-182)**: hộp "Người duyệt" cho Phiếu thu Đã trình (8 khung + cột Người duyệt ở danh sách `TC01`), chép 7 khung Phiếu thu từ canvas chính sang; Xem GHI_CHU_CHO_CODE.md mục 10 và mục 11 (Luật chung: thanh cuộn ngang, chip BH02).
