Nút thực hiện hành động; một component, cấu hình bằng `variant` (primary · secondary · tertiary · destructive), `solid`, `loading`, `disabled`, `iconOnly`.

- **Consumer cung cấp:** nhãn là động từ cụ thể ("Lưu phiếu thu", không "OK"); `label` bắt buộc khi `iconOnly` (thành tooltip + aria-label).
- **Primary** `hmt-action`: một nút/vùng. **Secondary** viền `hmt-border-strong`. **Tertiary** chữ `hmt-link`, cho hành động phụ trong dòng. **Destructive** viền `hmt-danger-border`; `solid` chỉ trong ConfirmDialog.
- Cao theo `data-product`: 36 / 48 / 44px; `size="sm"` (32px) chỉ trong bảng, toolbar CRM.
- `loading`: giữ màu, spinner + `loadingLabel`, `aria-busy`, chặn bấm lặp. `disabled`: `aria-disabled`, vẫn focus được để đọc lý do.
- Không dùng nút cho điều hướng sang trang (dùng liên kết); không đặt hai nút primary cạnh nhau.
