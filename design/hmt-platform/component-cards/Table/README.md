Bảng dữ liệu CRM: cột sắp xếp được, chọn nhiều hàng với thanh thao tác hàng loạt, trạng thái loading/rỗng, tự chuyển thành danh sách thẻ khi khung hẹp hơn `cardsBelow`.

- **Consumer cung cấp:** `columns` (`key`, `header`, `numeric`, `sortable`, `render`), `rows`, `rowKey`, `caption` (đọc cho trình đọc màn hình), `empty` (một StateView).
- Hàng 40px (CRM). Header `hmt-surface-subtle` dính trên cùng. Số canh phải, tabular. Hàng chọn: `hmt-selected` + vạch trái `hmt-action` + checkbox.
- Sắp xếp: nút trong `th`, `aria-sort`. Checkbox có nhãn "Chọn <tên>"; ô đầu chọn tất cả trên trang (indeterminate).
- Trạng thái trong ô dùng Badge (icon + chữ). Thao tác hàng: nút "…" mở Popover.
- Không dùng bảng trong Teacher Portal; không quá ~8 cột hiển thị — cột phụ đưa vào Drawer chi tiết.
