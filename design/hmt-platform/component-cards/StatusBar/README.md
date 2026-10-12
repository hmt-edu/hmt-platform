Thanh trạng thái trên đầu mọi bản ghi (K06): các bước nằm ngang, bước hiện tại nổi bật màu `hmt-action`, nút hành động hợp lệ ở bên trái, nhánh kết thúc (Huỷ, Từ chối) và biểu tượng khoá hiện riêng bên phải.

- **Consumer cung cấp:** `steps` (tên bước đúng file luật mục 4, `short` cho mã như "L4" khi > 5 bước), `current`, `actions` (chỉ nút hợp lệ ở bước hiện tại, theo quyền), `terminal`, `locked`, `substatus` (nhóm con, ví dụ "L4B …").
- `forwardOnly`: bước đã qua không bấm được, không có nút lùi (R-CRM-02). Bấm bước bị chặn → mở BlockingDialog liệt kê lý do, không chỉ làm mờ.
- Khoá là biểu tượng + chữ "Đã khoá", không phải một bước (R-TIEN-03).
- Dưới 640px: hiện "Bước n/N" + tên bước hiện tại + nút "Các bước" (bottom sheet liệt kê đủ bước, mỗi dòng cao 44px).
- Bước hiện tại `aria-current="step"`; bước đã qua đọc "(đã qua)".
