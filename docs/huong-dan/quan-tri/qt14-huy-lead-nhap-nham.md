---
id: qt14
ten: Huỷ lead nhập nhầm (chỉ Admin)
vai: [quan-tri]
phan_he: quan-tri
ma_man: [CHUNG-20, TS-02]
uu_tien: P3
cap_nhat: 2026-11-24
---

# Huỷ lead nhập nhầm (chỉ Admin)

**Làm xong bạn có:** một lead nhập nhầm (nhập thử, sai người, nhập hai lần mà chưa gộp được) chuyển sang «Đã huỷ», có ghi lý do, không còn tính vào danh sách làm việc và không tính trùng số điện thoại.
**Ai làm:** Admin. **Màn:** mở bản ghi lead → nút **Hành động** → **Huỷ lead nhập nhầm**.

> Video: [VIDEO: qt14]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Hệ thống không xoá hẳn.** «Huỷ» chỉ đổi lead sang «Đã huỷ», bản ghi vẫn còn để tra và mọi lần huỷ ghi nhật ký. Hiện chỉ có lead dùng chức năng này.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin. Vai khác không thấy mục «Huỷ lead nhập nhầm» trong menu «Hành động».
- [ ] Lead **chưa có cơ hội và chưa có lịch hẹn nào** (kể cả lịch hẹn đã huỷ hoặc đã xong). Có rồi thì không huỷ được (xem «Lỗi hay gặp»).
- [ ] Đó đúng là lead **nhập nhầm**. Lead trùng với lead khác thì dùng **Gộp trùng** (cùng menu), không huỷ. Khách không còn nhu cầu thì để người phụ trách chuyển giai đoạn, không huỷ.
- [ ] Bạn có lý do ngắn gọn để ghi.

## Luật cần nhớ (lời thường)
- Chỉ Admin huỷ được. Lý do bắt buộc.
- Lead đã gộp hoặc đã huỷ thì không huỷ lại được.
- Lead đã huỷ chỉ còn **xem**: không sửa, không tạo thêm cơ hội hay lịch hẹn.
- Số điện thoại của lead đã huỷ không còn bị coi là trùng, nên nhập lại đúng thông tin vẫn được.

## Các bước
1. Mở bản ghi lead cần huỷ (từ **Tuyển sinh** → danh sách lead, tìm theo số điện thoại hoặc tên).
   *Bạn thấy:* trang bản ghi lead, trên cùng có nút **Hành động**.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt14-b1]
2. Bấm **Hành động** → **Huỷ lead nhập nhầm**.
   *Bạn thấy:* hộp «Huỷ lead nhập nhầm», dòng phụ ghi mã, tên, số điện thoại lead; ô «Lý do» (bắt buộc).
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt14-b2]
3. Gõ lý do vào ô «Lý do», ví dụ «Nhập thử khi tập huấn».
   *Bạn thấy:* nút «Huỷ lead» sáng lên (chưa gõ lý do thì nút chưa bấm được).
4. Bấm **Huỷ lead**. Đổi ý thì bấm «Giữ lại».
   *Bạn thấy:* thông báo «Đã huỷ lead nhập nhầm.»; trong bản ghi có nhãn «Đã huỷ» và dòng «Lead nhập nhầm, đã huỷ: <lý do>».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt14-b4]

⚠ **Bước 4 không có nút hoàn tác trên màn.** Huỷ nhầm thì báo bộ phận kỹ thuật, kèm mã lead.

## Sau bước này
- **Ai làm tiếp:** không ai. Lead không còn trong danh sách việc cần làm.
- **Bạn xem ở đâu:** mở lại bản ghi lead (vẫn tìm được), hoặc xem nhật ký thao tác (Quản trị → Nhật ký).

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Huỷ nhầm lead còn dùng được | Màn không có «Mở lại». Báo bộ phận kỹ thuật; nếu cần gấp, tạo lại lead mới với đúng số điện thoại (số đó không còn bị tính trùng) |
| Ghi sai lý do | Không sửa được lý do; ghi chú đính chính vào cột ghi chú của bản ghi |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Lead đã có N cơ hội nên không huỷ được.» (HMT_LEAD_CO_CO_HOI) | lead đã được tạo cơ hội | Không huỷ. Xử lý cơ hội trước (chuyển giai đoạn cho phù hợp) |
| «Lead đã có N lịch hẹn nên không huỷ được.» (HMT_LEAD_CO_LICH_HEN) | lead đã có lịch hẹn (hệ thống đếm mọi lịch hẹn, kể cả đã huỷ hoặc đã xong) | Không huỷ được: để người phụ trách chuyển giai đoạn lead và ghi chú rõ đây là lead nhập nhầm |
| «Lead này đã gộp hoặc đã huỷ, không huỷ được nữa.» (HMT_LEAD_KHONG_HUY_DUOC) | đã xử lý rồi | Không cần làm gì |
| «Cần ghi lý do huỷ lead.» (HMT_THIEU_THONG_TIN) | để trống ô Lý do | Gõ lý do rồi bấm lại |
| «Chỉ Admin được huỷ lead nhập nhầm.» (HMT_KHONG_CO_QUYEN) | bạn không phải Admin | Nhờ Admin làm |

## Hỏi đáp
- **Huỷ lead có làm mất lịch sử không?** Không. Bản ghi và nhật ký vẫn còn.
- **Khác gì «Gộp trùng»?** Gộp dùng khi cùng một khách có hai lead: giữ một, nối lịch sử. Huỷ dùng khi lead không đáng có.
- **Tuỳ chọn «xoá» cho phiếu thu, đơn hàng?** Chưa có. Các bản ghi tiền dùng luồng huỷ riêng (xem bài huỷ phiếu thu, huỷ đơn hàng).

## Tập trên dữ liệu mẫu
- **Cần:** `bgd.tap` (Admin) trên **staging**; một lead mẫu do bạn tự tạo để huỷ (nhập tên «Thử huỷ», số điện thoại giả).
- **Dùng:** tạo lead thử, mở, huỷ theo các bước trên, rồi nhìn nhãn «Đã huỷ». Thử mở menu «Hành động» của lead đã huỷ để thấy không còn mục huỷ.
- Không huỷ lead của người thật đang làm việc trên staging dùng chung.

## Tự kiểm: bạn làm được khi
- [ ] Bạn huỷ được một lead thử và thấy nhãn «Đã huỷ» cùng lý do.
- [ ] Bạn phân biệt được khi nào dùng «Gộp trùng», khi nào «Huỷ lead nhập nhầm».
- [ ] Bạn nói được vì sao lead đã có lịch hẹn thì không huỷ được.

**Bước trước:** Nhật ký thao tác · **Bước sau:** —

## Ghi chú cho người soát (không hiển thị cho người học)
- Bản đồ màn hình (CHUNG-20) mô tả «xoá bản ghi nhập nhầm» chung; mã hiện chỉ làm cho **lead** (`CancelLeadDialog.tsx`, `app.cancel_wrong_lead`, migration 508). Bài chỉ nói lead; các bản ghi khác chưa có.
- Điều kiện hiện nút: `access.can('ADMIN','TAO')` và lead đang dùng (`DANG_DUNG`). Chưa kiểm trên staging nhãn vị trí «Hành động» (từ mã).
- «Không có nút mở lại» suy từ mã: không thấy hàm mở lại lead đã huỷ (cần người soát xác nhận).
