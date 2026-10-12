# HMT Component Spec — Core Components & Interaction Rules

**HMT Platform · CRM · Teacher Portal · LMS**

| | |
| --- | --- |
| Phiên bản | 1.1 — P4 đã duyệt; bổ sung đợt 5.0 (mục 11, chờ duyệt) theo `HMT_LUAT_CHO_THIET_KE.md` |
| Ngày | 2026-10-11 |
| Dựa trên | `HMT_BRAND_GUIDELINES.md` (đã duyệt), `HMT_DESIGN_SYSTEM_SPEC.md` + `HMT_DESIGN_TOKENS.css` (đã duyệt) |
| Ví dụ tương tác | Design System "HMT Platform" — mỗi component có một thẻ chạy thật (React 18), thử được bàn phím, light/dark |
| Phạm vi | 27 component cốt lõi. **Không** gồm màn hình nghiệp vụ |

**Nhãn:** các quy định trong tài liệu này đã được duyệt cùng P4 (trước đó ghi PROPOSED). Chỗ ghi **APPROVED** là kế thừa từ Brand/DS Spec; chỗ ghi **OPEN** vẫn chờ quyết định.

> **Về mã nguồn ví dụ:** các thẻ tương tác dùng một bản dựng React thuần với CSS đọc token `--hmt-*`, để chạy được trong Design System. Đây là **prototype tham chiếu hành vi**, không phải mã production. Production dựng cùng API (props) bằng React + Tailwind v4 theo `HMT_DESIGN_SYSTEM_SPEC.md` §10. File `index.d.ts` trong Design System mô tả API của từng component.

---

## 0. Nguyên tắc chung

### 0.1 Một component, nhiều cấu hình

Theo yêu cầu không tạo component trùng lặp, bộ này gom các biến thể vào một component có prop:

| Thay vì tạo riêng… | Dùng |
| --- | --- |
| PrimaryButton, DangerButton, IconButton, LoadingButton | `Button` với `variant`, `solid`, `iconOnly`, `loading` |
| Label + Input + HelperText + ErrorText rời rạc | `Field` bọc `TextInput` / `Select` / `Textarea` / `DateInput` |
| EmptyState, ErrorState, NoResults, Offline, NoPermission | `StateView` với `kind` |
| ConfirmDialog như một overlay riêng | `ConfirmDialog` = `Dialog` cấu hình sẵn (role, focus, nút) |
| Side panel và Bottom sheet | `Drawer` với `placement="right" \| "bottom"` |
| Bộ chọn điểm danh, bộ chọn Ngày/Tuần/Tháng, chế độ xem | `SegmentedControl` (điểm danh = SegmentedControl + danh sách trạng thái) |
| Dòng học sinh cho CRM, Teacher, LMS | `StudentListItem` với `trailing` khác nhau |
| ProgressBar CRM và LMS | `ProgressBar` với `variant="lms"` |
| Bảng và danh sách thẻ trên mobile | `Table` tự chuyển dạng thẻ khi hẹp (`cardsBelow`) |
| Menu thao tác, bộ lọc nhanh, lịch | `Popover` |
| Mật độ CRM / Teacher / LMS | Không có biến thể component: đọc `--hmt-density-*` theo `data-product` |

### 0.2 Ma trận trạng thái tương tác (áp dụng cho mọi component bấm được)

| Trạng thái | Hiển thị | Bắt buộc ngoài màu |
| --- | --- | --- |
| Mặc định | Theo variant | — |
| Hover | `hmt-action-hover` (nút chính) hoặc lớp `hmt-hover-overlay` | Con trỏ tay |
| Pressed | `hmt-action-pressed` hoặc `hmt-pressed-overlay` | — |
| Focus | Vòng 2px `hmt-focus`, cách 2px (APPROVED) | Chỉ với `:focus-visible` |
| Selected / current | `hmt-selected` + `hmt-on-selected` | `aria-selected` / `aria-current` / `aria-pressed` + dấu hiệu hình (✓, vạch, chữ đậm, viền 2px) |
| Disabled | Token `disabled-*` (APPROVED) | `disabled` hoặc `aria-disabled`, không hover; nên kèm lý do |
| Loading | Giữ màu, spinner + chữ | `aria-busy`, chặn bấm lặp |
| Lỗi | Viền `hmt-danger-border` + icon + chữ | `aria-invalid`, `aria-describedby` |

### 0.3 Bàn phím chung

| Phím | Hành vi |
| --- | --- |
| Tab / Shift+Tab | Đi qua các phần tử tương tác theo thứ tự đọc |
| Enter / Space | Kích hoạt nút, chọn ngày, bật/tắt chip |
| Mũi tên | Di chuyển **trong** một nhóm: tabs, radio/SegmentedControl, lịch, menu |
| Esc | Đóng tooltip, popover, dialog, drawer; trả focus về nút đã mở |
| Home / End | Phần tử đầu/cuối trong nhóm (tabs, lịch) |

### 0.4 Kích thước theo sản phẩm (APPROVED — DS Spec §5.1)

| | CRM | Teacher Portal | LMS |
| --- | --- | --- | --- |
| Control (nút, input) | 36px | 48px | 44px |
| Hàng bảng/danh sách | 40px | 56px | 56px |
| Body | 14px | 16px | 16px |
| Vùng chạm tối thiểu | 24px (WCAG 2.5.8); 44px trên tablet | **44px** | **44px** |

Component không có prop kích thước theo sản phẩm; chúng đọc `--hmt-density-*`. Chỉ `Button size="sm"` (32px) có riêng, dùng trong bảng và toolbar CRM.

### 0.5 Văn phong trong component (PROPOSED)

- Nhãn nút là **động từ + đối tượng**: "Lưu phiếu thu", "Xoá khỏi lớp". Không "OK", "Đồng ý", "Submit".
- Lỗi nói **cách sửa**: "Số điện thoại cần 10 chữ số, bắt đầu bằng 0", không "Dữ liệu không hợp lệ".
- Xác nhận nêu **đúng đối tượng**: "Xoá Lê Chi khỏi lớp 4C3?".
- Số: `1.250.000 ₫`, ngày `15/10/2026`, giờ `18:00`.

---

## 1. Button

### Button

| | |
| --- | --- |
| **Mục đích** | Thực hiện một hành động trên trang hiện tại (lưu, tạo, gửi, xoá). |
| **Variants** | `primary` (cam hành động — một nút/vùng) · `secondary` (viền) · `tertiary` (chữ, hành động phụ trong dòng) · `destructive` (viền đỏ) · `destructive` + `solid` (nền đỏ — chỉ trong ConfirmDialog) · `iconOnly` (nút vuông có tooltip) |
| **States** | default · hover · pressed · focus · disabled · loading |
| **Kích thước** | Cao `--hmt-density-control-h` (36/48/44); padding ngang 12/16/20px; `size="sm"` 32px; icon 1.15em, cách chữ 6px; chữ 500 cỡ body; bo `radius-md` 6px; khoảng cách giữa các nút 8px |
| **Màu & tương phản** | Primary `hmt-on-action` trên `hmt-action`: 5.49 (light) / 7.31 (dark); hover 7.46 / 8.94; pressed 9.44 / 11.57. Secondary `hmt-fg` + viền `hmt-border-strong` (≥3.65). Destructive `hmt-danger` trên surface 6.57 / 7.73, viền ≥3.86. |
| **Desktop / Mobile** | Desktop: nút chính ở cuối nhóm hành động (phải). Mobile: nút chính rộng hết màn, dính đáy nếu là hành động chính của màn; tối đa 2 nút cạnh nhau. |
| **Bàn phím & a11y** | `<button type="button">`; disabled dùng `aria-disabled` (vẫn focus được, đọc được lý do); loading đặt `aria-busy`, đổi nhãn ("Đang lưu…"), chặn bấm lặp; `iconOnly` bắt buộc `label` → `aria-label` + tooltip. |
| **Không dùng khi** | Điều hướng sang trang khác (dùng liên kết). Hai nút primary cạnh nhau. Nút destructive đặc ngoài hộp xác nhận (APPROVED — DS Spec §2.6). Nhãn chung chung. |

---

## 2. Form

### Field (khung dùng chung)

| | |
| --- | --- |
| **Mục đích** | Một khung chuẩn cho nhãn, ô nhập, helper text và lỗi; tự nối `id`, `aria-describedby`, `aria-invalid`, `aria-required` cho ô bên trong. |
| **Variants** | Bắt buộc (`*` đỏ + `aria-required`) · Không bắt buộc ("(không bắt buộc)") · có helper · có lỗi · có bộ đếm |
| **States** | default · focus (viền `hmt-focus` 1px + vòng 1px) · error · disabled · read-only |
| **Kích thước** | Nhãn 13/18 (CRM), 14/20 (Teacher/LMS), đậm 500; khoảng nhãn–ô 6px; helper/lỗi 12/16; khoảng giữa các Field 12px (CRM) / 16px (Teacher/LMS) |
| **Màu** | Viền ô `hmt-border-strong` (3.82/3.65); lỗi: viền `hmt-danger-border` (4.41/3.86) + icon + chữ `hmt-danger` (6.57/7.73); helper `hmt-fg-muted` (≥5.0) |
| **Desktop / Mobile** | Desktop CRM: form 1–2 cột, tối đa 640px mỗi cột. Mobile: 1 cột, chữ trong ô 16px để iOS không tự phóng to. |
| **Hành vi kiểm tra** | Kiểm tra khi rời ô (blur) và khi gửi; khi đã báo lỗi thì kiểm tra lại mỗi lần gõ để lỗi biến mất ngay khi đúng. Khi gửi có lỗi: **tóm tắt lỗi** ở đầu form nhận focus, mỗi dòng là liên kết tới ô lỗi. Không khoá nút gửi vì form chưa hợp lệ — để người dùng bấm và thấy lỗi. |
| **A11y** | `<label for>` luôn hiển thị; không dùng placeholder thay nhãn; lỗi được đọc qua `aria-describedby`. |
| **Không dùng khi** | Ô tìm kiếm trên thanh công cụ (TextInput có `aria-label`, không cần Field). |

### TextInput · Select · Textarea

| | TextInput | Select | Textarea |
| --- | --- | --- | --- |
| **Mục đích** | Một dòng chữ/số | Chọn 1 trong danh sách ngắn (≤ 15) | Văn bản nhiều dòng (ghi chú, nhận xét) |
| **Variants** | `leadingIcon` (tìm kiếm), `trailing` (nút xoá, đơn vị) | `placeholder` không chọn được | `maxLength` có bộ đếm |
| **Kích thước** | Cao control theo sản phẩm | Như TextInput; mũi tên 16px phải | Tối thiểu 80px, kéo dọc |
| **Mobile** | `type`/`inputMode` đúng: `tel`, `numeric`, `email` | Select gốc của hệ điều hành | Bộ đếm đọc qua `aria-live` |
| **Không dùng khi** | Chọn ngày (DateInput); giá trị từ danh sách cố định (Select) | > 15 lựa chọn hoặc cần tìm (cần Combobox — **OPEN C1**); 2–4 lựa chọn luôn nhìn thấy (SegmentedControl) | Một dòng ngắn |

### DateInput

| | |
| --- | --- |
| **Mục đích** | Nhập một ngày theo định dạng Việt Nam dd/mm/yyyy. |
| **Variants** | Ô gõ + lịch (desktop, CRM) · `native` (bộ chọn ngày của hệ điều hành — Teacher Portal, LMS trên điện thoại) |
| **States** | default · focus · lịch mở · ngày không hợp lệ · disabled |
| **Kích thước** | Ô như TextInput; lịch 288px, ô ngày cao 36px; tuần bắt đầu **Thứ Hai** (T2…CN) |
| **Màu** | Ngày chọn `hmt-action` + `hmt-on-action`; hôm nay viền `hmt-border-strong`; ngày ngoài tháng `hmt-fg-muted` |
| **Desktop / Mobile** | Desktop: gõ số tự thêm "/", hoặc mở lịch. Mobile: `native`. |
| **Bàn phím & a11y** | Lịch `role="grid"`, focus vào ngày đang chọn khi mở; ← → ±1 ngày, ↑ ↓ ±1 tuần, PageUp/PageDown đổi tháng, Home/End đầu/cuối tuần, Enter chọn, Esc đóng và trả focus. Mỗi ngày có nhãn đầy đủ ("15 tháng 10 2026"). |
| **Kiểm tra** | Ngày phải tồn tại (31/02 báo lỗi kèm lý do). Giới hạn min/max do màn hình nghiệp vụ kiểm tra và báo qua `Field error`. |
| **Không dùng khi** | Khoảng ngày (cần DateRange — **OPEN C2**); ngày sinh (gõ nhanh hơn chọn lịch — dùng ô gõ, không mở lịch mặc định). |

---

## 3. Data display

### Table

| | |
| --- | --- |
| **Mục đích** | Hiển thị và thao tác trên tập bản ghi lớn trong CRM: công nợ, học sinh, lead, lớp. |
| **Variants** | Chỉ đọc · `selectable` (chọn nhiều + thanh thao tác hàng loạt) · cột `sortable` · cột `numeric` · dạng thẻ khi hẹp |
| **States** | dữ liệu · loading (skeleton theo hàng) · rỗng / không có kết quả (StateView trong bảng) · hàng hover · hàng chọn · cột đang sắp xếp |
| **Kích thước** | Hàng `--hmt-density-row-h` (40px CRM); header 36px, chữ label 13/18; padding ô 12px; checkbox 18px trong cột 44px; tối đa ~8 cột hiển thị |
| **Typography** | Họ tên: `PersonLine` (tên + mã/cơ sở). Số: canh phải, `tabular-nums`, không tô màu. Ngày: dd/mm/yyyy. |
| **Màu** | Header `hmt-surface-subtle` + `hmt-fg-muted`; đường kẻ `hmt-border`; hàng chọn `hmt-selected` + `hmt-on-selected` (6.83/8.21) + **vạch trái 3px `hmt-action`** + checkbox; hover `hmt-hover-overlay` |
| **Desktop** | Header dính; cột đầu có thể dính khi cuộn ngang; thao tác hàng ở cột cuối (nút "…" → Popover). Chọn hàng → thanh "Đã chọn n" thay cho header với thao tác hàng loạt. |
| **Mobile / hẹp** | Dưới 640px tự thành danh sách thẻ: cột đầu là tiêu đề thẻ, các cột khác thành cặp nhãn–giá trị. |
| **Bàn phím & a11y** | `<table>` thật với `<caption>` ẩn, `th scope="col"`; sắp xếp là `<button>` trong `th`, `aria-sort` trên `th`; checkbox có nhãn "Chọn <tên>"; ô chọn tất cả có trạng thái indeterminate; thanh hàng loạt đọc số đã chọn qua `aria-live`; vùng loading `aria-busy`. |
| **Không dùng khi** | Teacher Portal (dùng danh sách). Dữ liệu < 5 dòng hoặc chỉ 2 cột (dùng danh sách). Thông tin chi tiết của một bản ghi (dùng Drawer). Không đặt input chỉnh sửa trực tiếp trong ô ở giai đoạn này (**OPEN C3**). |

### Pagination

| | |
| --- | --- |
| **Mục đích** | Chia danh sách dài thành trang trong CRM. |
| **Variants** | Đầy đủ (desktop: tổng số "1–25 / 1.287", trang 1 … 6 7 8 … 52) · `compact` ("Trang 3/9" — mobile) |
| **Kích thước** | Nút `size="sm"` 32px CRM; trên Teacher/LMS theo control 44–48px |
| **Màu** | Trang hiện tại `hmt-selected` + viền `hmt-action` + chữ đậm |
| **A11y** | `<nav aria-label="Phân trang">`; trang hiện tại `aria-current="page"`; nút trước/sau có nhãn, disabled ở đầu/cuối. Đổi trang: giữ bộ lọc, đưa về đầu bảng. |
| **Không dùng khi** | Feed LMS (dùng "Xem thêm"); danh sách vừa một trang. Cỡ trang mặc định CRM: 25 (**PROPOSED**), cho chọn 25/50/100. |

### Badge (gồm CountBadge)

| | |
| --- | --- |
| **Mục đích** | Nhãn trạng thái ngắn (1–3 từ) gắn với một đối tượng: học phí, lớp, buổi học. |
| **Variants** | `tone` success · warning · danger · info · neutral; subtle (mặc định) / `solid`; `CountBadge` cho số đếm |
| **Kích thước** | Cao 20px, chữ 13/18 đậm 500, padding 8px, bo 4px, icon 1.15em |
| **Màu** | Subtle: `hmt-on-*-subtle` trên `hmt-*-subtle` (≥6.94). Solid: `hmt-on-*-solid` trên `hmt-*-solid` (≥5.87). Count: `hmt-on-action` trên `hmt-action`. |
| **A11y** | **Luôn có icon + chữ** (APPROVED); icon `aria-hidden`; CountBadge có nhãn đầy đủ ("3 thông báo mới"). |
| **Không dùng khi** | Làm nút bấm. Dùng màu cam/brand hay `lms-reward` cho trạng thái (APPROVED). Câu dài (dùng Alert). |

### Avatar

| | |
| --- | --- |
| **Mục đích** | Nhận diện nhanh học sinh, phụ huynh, giáo viên bên cạnh họ tên. |
| **Variants** | Ảnh · chữ cái đầu (2 chữ cuối của họ tên Việt: "Nguyễn Thị Hồng Nhung" → "HN"); `sm` 28 · `md` 36 · `lg` 48 |
| **Màu** | Nền `hmt-secondary-subtle`, chữ `hmt-secondary` (7.85/6.44). **Không** tô màu theo từng người (bảng màu phân loại còn OPEN). |
| **A11y** | Có `role="img"` + tên; `decorative` khi họ tên đã hiển thị cạnh avatar. Ảnh lỗi tự về chữ cái. |
| **Không dùng khi** | Là cách duy nhất để nhận ra học sinh (luôn kèm họ tên). |

### Tooltip

| | |
| --- | --- |
| **Mục đích** | Nhãn ngắn giải thích một nút icon hoặc văn bản bị cắt. |
| **States** | Ẩn · hiện khi rê chuột (sau 400ms) · hiện ngay khi focus bàn phím |
| **Kích thước** | Tối đa 260px, chữ 13/18, padding 6×10, bo 6px |
| **Màu** | `hmt-fg-inverse` trên `hmt-fg` (13.88) |
| **A11y** | `role="tooltip"`, nối bằng `aria-describedby`; Esc để ẩn; không có phần tử tương tác bên trong. |
| **Không dùng khi** | Thông tin bắt buộc, liên kết, nút (điện thoại không có hover — dùng Popover hoặc helper text). |

### Chip

| | |
| --- | --- |
| **Mục đích** | Bộ lọc nhanh bật/tắt độc lập (nhiều chip cùng bật được). |
| **States** | tắt · bật (`hmt-selected` + viền `hmt-action` + ✓ + chữ đậm) · hover · focus |
| **Kích thước** | 32px (CRM), 40px (Teacher/LMS), bo tròn, cách nhau 8px; có số đếm tuỳ chọn |
| **A11y** | `<button aria-pressed>`; nhóm chip trong `role="group"` có nhãn. |
| **Không dùng khi** | Chọn 1 trong nhiều giá trị loại trừ nhau (SegmentedControl). Hiển thị trạng thái (Badge). |

---

## 4. Navigation

### Sidebar (CRM)

| | |
| --- | --- |
| **Mục đích** | Điều hướng chính của CRM, nhóm theo nghiệp vụ (Tuyển sinh, Học vụ, Tài chính…). |
| **Variants** | Mở rộng 240px · thu gọn 64px (chỉ icon + tooltip) |
| **States** | mục thường · hover · **hiện tại** (`hmt-selected` + `hmt-on-selected` + vạch 3px `hmt-action` + chữ đậm + `aria-current="page"`) · có số việc cần xử lý (CountBadge) |
| **Kích thước** | Mục cao 36px, icon 18px, nhóm có nhãn 11px viết hoa; tối đa 2 cấp |
| **Đầu sidebar** | Tên bằng chữ: "Hòa Ma Toán" + "CRM · CS2" (cơ sở đang làm việc). **Không** tự tạo biểu tượng/logo rút gọn (APPROVED — Brand §7.3, logo rút gọn còn hoãn). |
| **Desktop / Mobile** | ≥ 1024px: cố định bên trái. < 1024px: ngăn kéo (Drawer trái) mở bằng nút menu trên TopNav. |
| **A11y** | `<nav aria-label="Điều hướng chính">`; khi thu gọn, mục có `aria-label` + tooltip; nút thu gọn có `aria-expanded`. |
| **Không dùng khi** | Teacher Portal, LMS trên điện thoại (BottomNav). |

### TopNav

| | |
| --- | --- |
| **Mục đích** | Đầu trang: tiêu đề (h1), nút dẫn (menu hoặc quay lại), thao tác chính của trang. |
| **Kích thước** | Cao 56px; tiêu đề 18/24 font display 600 |
| **Desktop** | Tiêu đề + tối đa 1 nút primary + 1–2 nút secondary bên phải; breadcrumb ngay dưới. |
| **Mobile** | Nút quay lại 44px trái; tiêu đề ngắn; tối đa 2 nút icon phải, còn lại vào menu "…". |
| **A11y** | `<header>`; tiêu đề là `<h1>` duy nhất của trang. |
| **Không dùng khi** | Đặt bộ lọc, tab hoặc form trong TopNav. |

### Tabs

| | |
| --- | --- |
| **Mục đích** | Chuyển giữa các phần nội dung cùng cấp trong một trang (hồ sơ học sinh: Thông tin / Lớp / Chuyên cần / Học phí). |
| **States** | thường (`hmt-fg-muted`) · hover · chọn (`hmt-on-selected` đậm + gạch dưới 2px `hmt-action`) · focus · có số đếm |
| **Kích thước** | Cao 40px (CRM), 44px (Teacher/LMS); tràn thì cuộn ngang |
| **Bàn phím & a11y** | Mẫu ARIA tabs: `tablist`/`tab`/`tabpanel`; ← → chuyển và kích hoạt; Home/End; chỉ tab đang chọn nằm trong thứ tự Tab; panel focus được. |
| **Không dùng khi** | Điều hướng giữa các trang (Sidebar/BottomNav). Quá 6 tab. Tab lồng tab. Chọn chế độ xem dữ liệu (SegmentedControl). |

### Breadcrumb

| | |
| --- | --- |
| **Mục đích** | Cho biết vị trí trong cây CRM và quay lại cấp trên. |
| **Variants** | Đầy đủ (desktop) · `compact` (mobile: chỉ "‹ cấp cha") |
| **Kích thước** | Chữ 13px; dấu phân cách chevron 14px `hmt-fg-muted` |
| **A11y** | `<nav aria-label="Vị trí">` + `<ol>`; trang hiện tại không phải liên kết, `aria-current="page"`. |
| **Không dùng khi** | Teacher Portal, LMS (cây nông — dùng nút quay lại trên TopNav). |

### BottomNav (mobile navigation)

| | |
| --- | --- |
| **Mục đích** | Điều hướng chính trên điện thoại cho Teacher Portal (Hôm nay · Điểm danh · Lớp · Tôi) và LMS. |
| **States** | thường · hiện tại (viên `hmt-selected` sau icon + chữ đậm `hmt-on-selected` + `aria-current`) · có số việc chờ |
| **Kích thước** | 3–5 mục; mỗi mục cao 56px, icon 24px, **luôn có chữ** 12/16; tôn trọng safe-area |
| **A11y** | `<nav aria-label="Điều hướng chính">`; CountBadge có nhãn ("2 lớp chưa điểm danh"). |
| **Không dùng khi** | Desktop CRM. Đặt hành động (Thêm, Lưu) trong BottomNav. Ẩn BottomNav khi cuộn ở màn điểm danh. |

---

## 5. Feedback

### Toast

| | |
| --- | --- |
| **Mục đích** | Xác nhận ngắn sau một thao tác; cho phép **Hoàn tác** thay cho hỏi trước. |
| **Variants** | success · info · warning · danger; có/không có thao tác (Hoàn tác, Thử lại) |
| **Thời gian** | 5s; 8s khi có thao tác; dừng đếm khi rê chuột/focus; **lỗi không tự ẩn** |
| **Vị trí** | Desktop: góc dưới phải. Mobile: giữa, phía trên BottomNav/nút dính đáy. Tối đa 3, cái mới đẩy cái cũ. |
| **Màu** | Nền `hmt-surface-raised` + viền `hmt-border-strong` + `shadow-2`; icon theo tone; nút thao tác `hmt-link` |
| **A11y** | Vùng `aria-live="polite"`; lỗi `aria-live="assertive"`; nút đóng có nhãn. Không đưa focus vào toast. |
| **Không dùng khi** | Lỗi cần sửa trong form (Field error). Thông tin phải đọc kỹ hoặc cần quyết định (Alert/Dialog). |

### Alert

| | |
| --- | --- |
| **Mục đích** | Thông báo gắn với nội dung của trang hoặc một khu vực: lịch nghỉ, lỗi kết nối, việc còn thiếu. |
| **Variants** | info · success · warning · danger; có tiêu đề / nội dung / thao tác / nút đóng |
| **Màu** | `hmt-on-*-subtle` trên `hmt-*-subtle` + viền `hmt-*-border` + icon |
| **A11y** | `live` (role status/alert) chỉ khi alert xuất hiện do thao tác vừa làm; alert có sẵn khi tải trang thì không. |
| **Không dùng khi** | Xác nhận thoáng qua (Toast). Chồng nhiều alert. Quảng bá/khuyến mãi. |

### ConfirmDialog

Xem §6 — là `Dialog` cấu hình sẵn.

### StateView (empty · no-results · error · offline · no-access)

| | |
| --- | --- |
| **Mục đích** | Thay nội dung khi không có gì để hiển thị, và chỉ cách đi tiếp. |
| **Variants** | `empty` (chưa có dữ liệu) · `no-results` (bộ lọc/tìm kiếm không khớp) · `error` (không tải được) · `offline` (mất mạng) · `no-access` (không có quyền) |
| **Kích thước** | Icon tròn 56px; tiêu đề 16/24 đậm; mô tả tối đa 380px; tối đa 2 nút; `compact` trong bảng/thẻ |
| **Nội dung** | Tiêu đề nói chuyện gì xảy ra; mô tả nói làm gì tiếp; `error` luôn có "Thử lại" và mã lỗi; `offline` nói rõ dữ liệu có được lưu tạm không. |
| **A11y** | `error` có `role="alert"`. |
| **Không dùng khi** | Minh hoạ nhân vật/hoạt hình (APPROVED — Brand §6). Đổ lỗi cho người dùng. |

### Loading (Skeleton · Spinner · Button loading)

| | |
| --- | --- |
| **Mục đích** | Cho biết hệ thống đang làm việc. |
| **Chọn loại** | Skeleton: nội dung có cấu trúc (bảng, danh sách, thẻ). Spinner + chữ: chờ ngắn không có cấu trúc. Button `loading`: thao tác vừa bấm. |
| **Thời điểm** | < 300ms: không hiện gì. 300ms–10s: skeleton/spinner. > 10s: thêm lời giải thích + nút huỷ. |
| **A11y** | Vùng đang tải `aria-busy="true"`; Spinner có `role="status"` + chữ; shimmer tắt khi `prefers-reduced-motion`. |
| **Không dùng khi** | Spinner toàn màn hình chặn thao tác khi chỉ một khối đang tải. |

---

## 6. Overlay

### Dialog

| | |
| --- | --- |
| **Mục đích** | Tác vụ ngắn cần tập trung, không rời trang: chuyển lớp, sửa nhanh, xác nhận. |
| **Variants** | Thường 480px · `size="lg"` 720px · có `tone` (icon trạng thái ở đầu) |
| **States** | đóng · mở (scrim + hiệu ứng 320ms, tắt khi reduced-motion) · đang xử lý (không đóng được) |
| **Kích thước** | Padding 20px; tiêu đề 20/28 font display; footer: nút phụ bên trái nút chính, canh phải |
| **Màu** | `hmt-surface-overlay` + `shadow-3`; scrim `hmt-scrim` |
| **Desktop / Mobile** | Giữa màn hình. Trên điện thoại, nội dung dài hơn nửa màn: dùng Drawer `bottom`. |
| **Bàn phím & a11y** | `role="dialog"` + `aria-modal` + `aria-labelledby`/`describedby`; focus vào ô đầu tiên (hoặc nút đầu ở footer); **giữ focus bên trong**; Esc/scrim/nút đóng; **trả focus** về nút đã mở; khoá cuộn trang. |
| **Không dùng khi** | Dialog chồng dialog. Form dài nhiều bước (trang riêng). Thông báo không cần quyết định (Toast/Alert). |

### ConfirmDialog (Dialog cấu hình)

| | |
| --- | --- |
| **Mục đích** | Xác nhận hành động **không hoàn tác được** (xoá, huỷ phiếu thu, kết thúc lớp). |
| **Cấu hình** | `role="alertdialog"`; tone danger (icon); **focus mặc định ở nút Huỷ**; nút xác nhận `destructive solid` + icon + động từ cụ thể; khi xử lý: nút loading, không đóng bằng Esc/scrim. |
| **Nội dung** | Tiêu đề là câu hỏi nêu đúng đối tượng ("Xoá Lê Chi khỏi lớp 4C3?"); mô tả nêu hậu quả và dữ liệu nào được giữ. |
| **Không dùng khi** | Hành động **hoàn tác được** — làm luôn và hiện Toast có Hoàn tác (ít bước hơn, đúng tinh thần Teacher Portal). |

### Drawer

| | |
| --- | --- |
| **Mục đích** | `right`: xem/sửa chi tiết bản ghi mà không rời danh sách (hồ sơ học sinh từ bảng công nợ). `bottom`: bộ lọc, lựa chọn trên điện thoại. |
| **Kích thước** | Phải: rộng 440px, cao toàn màn. Dưới: cao tối đa 85%, bo trên 16px, có tay nắm. Footer dính với thao tác chính. |
| **A11y** | Như Dialog (modal, giữ focus, Esc, trả focus). |
| **Không dùng khi** | Điều hướng chính (trừ Sidebar dạng ngăn kéo < 1024px). Luồng nhiều bước. |

### Popover

| | |
| --- | --- |
| **Mục đích** | Khung nổi không chặn trang, gắn với một nút: menu thao tác của hàng, bộ lọc nhanh, lịch. |
| **Hành vi** | Mở bằng click; đóng bằng Esc, click ra ngoài, hoặc chọn một mục; tự lật lên trên khi không đủ chỗ; không khoá cuộn. |
| **Kích thước** | Tối thiểu 200px; mục menu cao 36px (CRM), icon + chữ |
| **A11y** | Nút mở có `aria-haspopup`, `aria-expanded`; focus vào phần tử đầu tiên; Esc trả focus về nút. Mục nguy hiểm có màu `hmt-danger` **và** mở ConfirmDialog. |
| **Không dùng khi** | Form dài, nội dung bắt buộc phải đọc, hoặc trên điện thoại cho nội dung > 3 lựa chọn (dùng Drawer `bottom`). |

---

## 7. Component chuyên biệt — lớp, học sinh, điểm danh

### SegmentedControl

| | |
| --- | --- |
| **Mục đích** | Chọn đúng 1 trong 2–4 lựa chọn luôn hiển thị. Là nền của lựa chọn điểm danh và các bộ chuyển chế độ xem (Ngày/Tuần/Tháng). |
| **Variants** | `stack` (icon trên chữ) · `row` (icon cạnh chữ — điểm danh lưới 2 × 2) · `colored` (lựa chọn đã chọn tô theo `tone` + `emphasis` — điểm danh, O-3 đã chốt) |
| **States** | chưa chọn · chọn (nền `hmt-selected`, **viền 2px** `hmt-action`, chữ đậm) · hover · focus · disabled |
| **Kích thước** | Mỗi lựa chọn ≥ 44px (Teacher 48px), cách nhau `--hmt-density-gap` (8px Teacher); icon 20px |
| **A11y** | Dựng trên **radio gốc** trong `fieldset` + `legend` (ẩn): mũi tên chuyển lựa chọn, Tab ra khỏi nhóm. |
| **Không dùng khi** | > 4 lựa chọn (Select). Chọn nhiều (Chip). |

### AttendanceSheet (điểm danh — Teacher Portal)

> **Đã thay bằng §11.2 (đợt 5.0)** vì luật R-DD-01 có 4 trạng thái và có màu. Bảng dưới đây giữ để đối chiếu.

| | |
| --- | --- |
| **Mục đích** | Điểm danh một buổi học trên điện thoại nhanh nhất và khó nhầm nhất. |
| **Cấu trúc** | Đầu: lớp, giờ, cơ sở, ngày, sĩ số. Danh sách: mỗi học sinh một hàng — avatar + **họ tên đầy đủ** + thông tin phụ (chuyên cần gần đây) + ghi chú phụ huynh (nếu có) + SegmentedControl **Có mặt / Có phép / Vắng** (icon + chữ). Chân dính đáy: tóm tắt số lượng + nút lưu. |
| **Giảm số lần chạm** | 1 chạm cho mỗi học sinh. Nút **"Còn lại n: Có mặt"** đánh dấu tất cả học sinh **chưa đánh dấu** là Có mặt (không ghi đè lựa chọn đã chọn), kèm Toast **Hoàn tác**. Lưu xong không hỏi xác nhận — Toast tóm tắt + **Hoàn tác**. |
| **Chống nhầm** | Học sinh chưa đánh dấu có vạch trái + nhãn "⚠ Chưa điểm danh". Khi còn học sinh chưa đánh dấu, nút lưu đổi thành **"Đến học sinh chưa điểm danh (n)"** và cuộn + focus tới học sinh đó — **không cho lưu thiếu**. Không dùng thao tác vuốt. Lựa chọn cách nhau 8px, cao ≥ 48px. Sau khi lưu, sửa lại hiện "Có thay đổi chưa lưu". |
| **States** | chưa đánh dấu · đang đánh dấu · đủ, chưa lưu · đang lưu (nút loading) · đã lưu (✓ Đã lưu) · đã lưu có thay đổi · mất mạng (lưu tạm trên máy, Alert offline — hành vi đồng bộ **OPEN C4**) |
| **Màu** | Lựa chọn trung tính (`hmt-selected` + viền `hmt-action`) theo mặc định; tô màu trạng thái là **OPEN O3**. Cờ chưa điểm danh `hmt-warning` + icon. |
| **A11y** | Mỗi học sinh là một nhóm radio có legend "Điểm danh <họ tên>"; tóm tắt chân trang `aria-live="polite"`; nút lưu loading `aria-busy`. |
| **Cấu hình** | `defaultStatus` (null = để trống — đề xuất; `'present'` = mặc định Có mặt — **OPEN O2**), `colored` (**OPEN O3**), `statuses` (có thể thêm "Đi muộn" nếu nghiệp vụ cần — **OPEN C5**). |
| **Không dùng khi** | Điểm danh hàng loạt nhiều buổi (cần màn riêng trên CRM). |

### StudentListItem (PersonLine)

| | |
| --- | --- |
| **Mục đích** | Một dòng học sinh dùng chung: danh sách lớp (CRM), điểm danh (Teacher), danh sách con (LMS phụ huynh). |
| **Variants** | Phần cuối dòng do consumer truyền: Badge (CRM), SegmentedControl (Teacher), nút "Xem" (LMS); có/không `onClick` (cả dòng bấm được) |
| **Kích thước** | Cao `--hmt-density-row-h`; avatar 36px; tên 600, thông tin phụ 12/16 `hmt-fg-muted` |
| **A11y** | Khi bấm được, cả dòng là **một** vùng focus; tên đầy đủ (cắt "…" chỉ khi thiếu chỗ). |
| **Không dùng khi** | Hơn 2 thao tác ở cuối dòng (đưa vào Popover "…"). |

### ClassCard

| | |
| --- | --- |
| **Mục đích** | Tóm tắt một lớp: tên, cơ sở, lịch, giáo viên, sĩ số, trạng thái — dùng ở danh sách lớp (CRM, Teacher) và "Lớp của con" (LMS). |
| **Variants** | Liên kết (cả thẻ bấm được) · tĩnh; có `footer` (LMS: ProgressBar tiến độ khoá) |
| **Kích thước** | Padding/bo theo `--hmt-density-card-*`; thông tin dạng `dl` với icon + nhãn |
| **Màu** | Sĩ số đủ: Badge warning "Đã đủ"; trạng thái lớp: Badge (Đang học / Hôm nay / Tạm dừng) |
| **A11y** | Thẻ liên kết có một vùng focus; không lồng nút trong thẻ liên kết. |
| **Không dùng khi** | Cần so sánh nhiều lớp theo cột (dùng Table). |

### ProgressBar

| | |
| --- | --- |
| **Mục đích** | Tỉ lệ hoàn thành: thu học phí (CRM), tiến độ bài/khoá học (LMS). |
| **Variants** | Mặc định (`hmt-secondary`) · `variant="lms"` (`hmt-lms-progress` — chỉ LMS, APPROVED) · `size="lg"` 12px |
| **Kích thước** | Rãnh 8px bo tròn; nhãn + giá trị bằng chữ phía trên |
| **A11y** | `role="progressbar"` + `aria-valuenow/min/max` + `aria-valuetext` ("18/32 buổi"); giá trị luôn hiển thị bằng số. |
| **Không dùng khi** | Trạng thái đạt/không đạt; so sánh điểm số giữa học sinh. |

---

## 8. Nguyên tắc theo sản phẩm

### CRM — dày đặc nhưng đọc tốt, thao tác nhanh

1. Table là trung tâm: hàng 40px, header dính, số tabular canh phải, tối đa ~8 cột; chi tiết mở bằng Drawer phải để không mất vị trí trong danh sách.
2. Thao tác hàng loạt qua checkbox + thanh "Đã chọn n"; thao tác từng hàng qua Popover "…".
3. Bộ lọc nhanh bằng Chip có số đếm; bộ lọc và trang được giữ khi quay lại.
4. Một nút primary mỗi vùng; nút trong bảng dùng `size="sm"`.
5. Hành động không hoàn tác được → ConfirmDialog; hoàn tác được → làm ngay + Toast Hoàn tác.
6. Phím tắt cho thao tác lặp (**OPEN C6** — danh sách phím tắt cần làm cùng màn nghiệp vụ).

### Teacher Portal — ít chạm, màn nhỏ, khó điểm danh nhầm

1. BottomNav; nút chính rộng hết màn, dính đáy, trong tầm ngón cái.
2. Không dùng Table, Breadcrumb, Popover nhiều lựa chọn; dùng danh sách, Drawer `bottom`.
3. Mọi vùng chạm ≥ 44px (control 48px), cách nhau ≥ 8px.
4. Điểm danh theo AttendanceSheet: 1 chạm/học sinh, "Còn lại: Có mặt", không cho lưu thiếu, Hoàn tác thay cho hỏi xác nhận.
5. Chữ trong ô nhập 16px; DateInput `native`.

### LMS — phản hồi rõ cho học sinh và phụ huynh

1. Mọi thao tác có phản hồi ngay: Toast cho lưu/nộp bài, ProgressBar `lms` cập nhật, StateView giải thích khi trống/lỗi.
2. Lời nhắn đơn giản, không thuật ngữ nội bộ ("Con đã hoàn thành 68% bài"). Học sinh: khích lệ; phụ huynh: rõ ràng, trang trọng hơn — cùng component.
3. Dùng mảng `hmt-brand`, `lms-progress`, `lms-reward` theo DS Spec; trạng thái vẫn dùng Badge với icon + chữ.
4. Không phụ thuộc hover; vùng chạm 44px; BottomNav trên điện thoại.

---

## 9. Kiểm tra đã thực hiện

| Kiểm tra | Kết quả |
| --- | --- |
| 27 thẻ ví dụ chạy ở light và dark | Không lỗi JavaScript |
| Dialog: focus ban đầu, giữ focus khi Tab, Esc trả focus về nút mở | Đạt |
| ConfirmDialog: focus mặc định ở "Huỷ" | Đạt |
| Lịch: mở focus vào ngày đang chọn; mũi tên + Enter chọn đúng ngày | Đạt (15/10 → → ↓ → 23/10) |
| Tabs: ← → chuyển tab | Đạt |
| Table: `aria-sort` đổi khi sắp xếp; chuyển dạng thẻ khi hẹp | Đạt |
| Form: gửi khi có lỗi → tóm tắt lỗi nhận focus | Đạt |
| Popover: Esc trả focus về nút mở | Đạt |
| Điểm danh: nút lưu đưa focus tới học sinh chưa đánh dấu; "Còn lại: Có mặt" chỉ đánh dấu phần còn thiếu; lưu → "✓ Đã lưu" | Đạt |
| Tương phản các cặp màu riêng của component (tab chọn, avatar, tooltip, cờ điểm danh, viền lựa chọn, thanh tiến độ) | Tất cả ≥ 4.5:1 cho chữ, ≥ 3:1 cho viền/đồ hoạ |

Chưa kiểm tra: trình đọc màn hình thật (VoiceOver/TalkBack), thiết bị thật, font thật (môi trường kiểm thử chặn Google Fonts).

---

## 10. Quyết định chưa được duyệt

### Mới trong P4 — đã duyệt cùng P4 (trước đó PROPOSED)

Toàn bộ quy định component ở §0–§8, đáng chú ý:

| # | Đề xuất |
| --- | --- |
| P4-1 | Gom biến thể vào component cấu hình được (bảng §0.1) |
| P4-2 | Disabled dùng `aria-disabled` (vẫn focus được) thay vì `disabled` |
| P4-3 | Kiểm tra form khi blur + khi gửi; tóm tắt lỗi nhận focus; không khoá nút gửi |
| P4-4 | Tuần trong lịch bắt đầu Thứ Hai; DateInput `native` trên mobile |
| P4-5 | Table tự chuyển dạng thẻ dưới 640px; cỡ trang mặc định 25 |
| P4-6 | Hoàn tác (Toast) thay cho hộp xác nhận với hành động hoàn tác được |
| P4-7 | Toast: 5s / 8s có thao tác / lỗi không tự ẩn; tối đa 3 |
| P4-8 | Điểm danh: không cho lưu khi còn học sinh chưa đánh dấu; nút "Còn lại n: Có mặt" |
| P4-9 | Sidebar dùng tên bằng chữ thay logo cho đến khi có logo rút gọn |
| P4-10 | Văn phong trong component (§0.5) |

### OPEN

| # | Vấn đề | Ghi chú |
| --- | --- | --- |
| O1 | Font (Inter + Be Vietnam Pro) | Kế thừa DS Spec — thẻ ví dụ đang dùng phương án C |
| O2 | Điểm danh mặc định "để trống" hay "Có mặt" | Có công tắc trong thẻ AttendanceSheet để so sánh |
| O3 | Tô màu trạng thái cho lựa chọn điểm danh | Có công tắc trong thẻ AttendanceSheet và SegmentedControl |
| O6 | Bộ icon | Thẻ ví dụ dùng icon vẽ tạm; cần chọn thư viện (Lucide, Phosphor…) |
| C1 | Combobox (chọn có tìm kiếm) cho danh sách > 15 (học sinh, lớp) | Cần cho CRM; chưa có trong bộ này |
| C2 | DateRange (khoảng ngày) cho báo cáo | Chưa có |
| C3 | Chỉnh sửa trực tiếp trong ô bảng | Chưa cho phép |
| C4 | Điểm danh khi mất mạng: lưu tạm và đồng bộ | Cần quyết định kỹ thuật |
| C5 | Thêm trạng thái "Đi muộn" trong điểm danh | Phụ thuộc quy định nghiệp vụ |
| C6 | Phím tắt CRM | Làm cùng màn nghiệp vụ |
| C7 | Bảng màu phân loại (5 cơ sở, môn học, biểu đồ) | Kế thừa DS Spec O5 |


---

## 11. Đợt 5.0 — thành phần bổ sung và sửa theo luật

Nguồn: `HMT_LUAT_CHO_THIET_KE.md` (ưu tiên cao nhất), `HMT_BAN_DO_MAN_HINH.md` (khuôn K01–K13). Mỗi thành phần có thẻ tương tác trong Design System với dữ liệu HMT giả đúng định dạng, công tắc mật độ CRM / Giáo viên / Học tập (khi dùng ở nhiều sản phẩm) và bản điện thoại khi dùng trên điện thoại.

**Trạng thái chung cho mọi thành phần dưới đây:** mặc định · rê chuột (`hmt-hover-overlay` hoặc `hmt-action-hover`) · focus (vòng 2px `hmt-focus` cách 2px) · tắt (token `disabled-*` + `aria-disabled`) · lỗi (`hmt-danger-border` + icon + chữ). Cỡ theo `--hmt-density-*` của `data-product` (control 36 / 48 / 44px). Trên điện thoại mọi vùng chạm ≥ 44px.

### 11.1 Thay đổi chung (theo mục 8 file luật)

| # | Thay đổi | Lý do |
| --- | --- | --- |
| G1 | Bộ icon → **Lucide**, nét **1,5px**, cỡ 16/20/24. Thẻ ví dụ nạp `lucide@0.460.0` từ CDN; bản dựng có bộ vẽ tạm dự phòng khi không tải được | O-12 |
| G2 | **Chỉ giao diện sáng**. Token dark giữ trong file nhưng không kiểm thử cho thành phần mới | O-13 |
| G3 | Font: Inter (giao diện, số đều cột) + Be Vietnam Pro (tiêu đề) — chính thức | O-1 |
| G4 | Lịch chọn ngày cũ (`Calendar` của P4) đổi tên nội bộ thành **`MonthGrid`**, nhường tên `Calendar` cho lịch buổi học | Tránh trùng tên |
| G5 | **ConfirmDialog** thêm `reasonLabel` / `reasonOptions`: ô lý do bắt buộc (huỷ, từ chối, điều chỉnh, đảo khoản, đưa về Nháp). Không tạo hộp thoại riêng | Luật giao diện chung; K08 |
| G6 | **Table** dùng `BulkActionBar` cho thao tác hàng loạt | Dùng chung |
| G7 | **SegmentedControl** `colored` theo `tone` + `emphasis` (subtle/solid) | R-DD-01 |
| G8 | Dữ liệu mẫu các thẻ P4 sửa theo luật: tiền "đ" (không "₫"), không dùng CS3 cho lớp/học sinh, mã HS000123, PT-CS1-2610-… | Mục 2 file luật |
| G9 | Token mới `hmt-cat-1..4` (+ `-subtle`) cho loại buổi trên lịch, `hmt-chart-1` cho biểu đồ | Calendar, RadarChart, HoursDisplay |

### 11.2 AttendanceSheet (sửa theo R-DD-01/02/03)

| | |
| --- | --- |
| **Trạng thái điểm danh** | **Có mặt · Đi muộn · Vắng có phép · Vắng không phép**. Ô trống = chưa điểm danh. Mặc định để trống |
| **Màu** | Có mặt: `success-subtle` (nhạt) · Đi muộn: `warning-subtle` (vàng) · hai loại Vắng: `danger-solid` (đậm). Luôn kèm icon (✓, đồng hồ, giấy có dấu ✓, người gạch chéo) + chữ đầy đủ |
| **Chế độ** | `teacher` — giáo viên, chính thức · `ops` — vận hành ghi riêng + **lý do liên hệ** (Không nghe máy, Đã nhắc vào lớp, Đã vào lớp, Xin nghỉ học — danh mục cấu hình được) · `compare` — bản ghi buổi hiện **hai cột cạnh nhau**: Vận hành (chỉ đọc, có lý do) | Giáo viên (chính thức), đánh dấu "Khác vận hành" |
| **Lưu** | Tự lưu sau mỗi lần chọn: **Đang lưu… / Đã lưu / Chưa lưu được** (+ Alert có "Thử lại"). Đồng bộ ngoại tuyến để giai đoạn 3 (O-17) |
| **Nhanh** | "Còn lại: Có mặt (n)" chỉ áp cho em chưa đánh dấu, có Hoàn tác |
| **Chặn** | Trong TaskStepper, "Tiếp: Nội dung buổi" khi còn em trống → BlockingDialog liệt kê từng em, nút "Đến em này" cuộn + focus |
| **Điện thoại** | Lưới 2 × 2, mỗi ô ≥ 48px, cách 8px; tên + mã HS luôn hiện |
| **Không làm** | Giáo viên không tạo dòng điểm danh, không đổi tình trạng buổi (R-GV-08). Sửa sau khi buổi Done: chỉ BM, bắt buộc lý do (ConfirmDialog `reasonLabel`) |

### 11.3 Bản ghi (K06)

| Thành phần | Biến thể / trạng thái riêng | Cỡ & điện thoại | Bàn phím & a11y | Ví dụ HMT trong thẻ |
| --- | --- | --- | --- | --- |
| **StatusBar** | Bước đã qua / hiện tại (`hmt-action`) / chưa tới; `forwardOnly` (không lùi, R-CRM-02); `substatus` (nhóm con); `terminal` (Huỷ, Từ chối — Badge đặc riêng bên phải); `locked` (biểu tượng khoá, không phải bước — R-TIEN-03); nút hành động bên trái. > 5 bước: bước không hiện tại rút gọn còn mã (L1…), đủ tên cho trình đọc màn hình | Bước cao 32px (CRM); điện thoại < 640px: "Bước 4/8 · L4 Khách hàng tiềm năng" + nút "Các bước" (bottom sheet, dòng 44px) | Bước hiện tại `aria-current="step"`; bước bị chặn mở BlockingDialog | Cơ hội L1–L8 (bấm L5 khi thiếu tên/năm sinh → chặn, R-CRM-03); đơn DH-CS1-2610-0001 đã khoá; phiếu thu Từ chối → "Đưa về Nháp" có lý do |
| **SmartButton / SmartButtonGroup** | Có số đếm; nhóm `max` 4 (máy tính) / 2 (điện thoại), dư → "Thêm" (menu) | Cao ≥ 44px mọi sản phẩm | Nhãn đọc "Phiếu thu: 2" | HS000123: Phiếu thu 2 · Ghi danh 3 · Đơn hàng 1 · Thêm 3 |
| **Chatter** (CHUNG-22) | Ghi chú (có @nhắc tên, đính kèm) · thay đổi trường (cũ gạch ngang → mới đậm, ai, lúc nào) · sự kiện hệ thống; lọc Tất cả / Ghi chú / Lịch sử; rỗng | Máy tính: cột phải 320–400px; điện thoại: tab "Trao đổi (n)" | @: listbox ↑ ↓ Enter Esc; Ctrl/⌘+Enter gửi; nút icon có nhãn | Đơn DH-CS1-2610-0001: ghi chú CSKH nhắc @Phạm Ngọc Ánh, đổi trạng thái Đã trình → Đã duyệt, đổi ngày vào lớp |

### 11.4 Danh sách (K03, K04, K05)

| Thành phần | Biến thể / trạng thái riêng | Cỡ & điện thoại | Bàn phím & a11y | Ví dụ HMT |
| --- | --- | --- | --- | --- |
| **FilterBar** | Tìm kiếm (tên, SĐT, mã mới, mã cũ); lọc nhanh chip chia nhóm — **trong nhóm HOẶC, giữa nhóm VÀ** (R-CRM-07) + câu tóm tắt "(A hoặc B) và (C)"; lọc nâng cao (Drawer, đếm điều kiện); nhóm theo; yêu thích (lưu, đặt mặc định, riêng/dùng chung — CHUNG-19); chọn cột (cột khoá luôn hiện); đổi kiểu xem danh sách/kanban/lịch; số kết quả; "Xoá lọc nhanh" | Control theo mật độ; < 640px: tìm kiếm cả dòng, nút còn icon, chip cuộn ngang | Nhóm chip `role="group"` có nhãn; kiểu xem `radiogroup`; số kết quả `aria-live` | Cơ hội: "Của tôi" (Tôi là sale, Tôi là giáo viên chấm) × "Thời gian" (Quá hạn, Hôm nay, Sắp tới, Chưa có lịch) |
| **BulkActionBar** | Hiện khi chọn ≥ 1; số đã chọn; thao tác theo quyền; Bỏ chọn | Dính đầu bảng | Số đã chọn `aria-live` | Lead: Giao người phụ trách, Đổi giai đoạn, Xuất |
| **Kanban** | Cột có số thẻ; thẻ: mã, tên, thông tin chính, người phụ trách, hạn; cột rỗng; thả bị chặn → BlockingDialog nêu lý do | Cột 240px+, cuộn ngang; không dùng trên điện thoại | Thay kéo thả: nút "⋮" trên thẻ → "Chuyển sang…" | Cơ hội L4–L7; kéo L5 về L4 → "chỉ đi tới, không lùi (R-CRM-02)" |
| **Calendar** | Ngày (theo phòng / theo giáo viên), tuần, tháng; loại buổi Chính · Củng cố · Học bù · Học bổ trợ = màu `hmt-cat-1..4` **+ nhãn chữ**; Học bổ trợ vạch nét đứt; buổi huỷ gạch ngang + "Huỷ"; "Trùng phòng" (cảnh báo, không chặn — R-LOP-08); buổi trùng giờ xếp cạnh nhau; tháng: tối đa 2 buổi/ô + "+n buổi" | Cột ≥ 170px, cuộn; mở sẵn 16:00 | Mỗi buổi là nút có nhãn đầy đủ (loại, giờ, phòng, huỷ, trùng phòng) | CS1 tuần 13–19/10: 8A1, 9B2, 7A1 học bù trùng P.202, 8A1 Buổi 13 huỷ |

### 11.5 Biểu mẫu

| Thành phần | Biến thể / trạng thái riêng | Cỡ & điện thoại | Bàn phím & a11y | Ví dụ HMT |
| --- | --- | --- | --- | --- |
| **Combobox** | Chọn một / chọn nhiều (thẻ có nút bỏ); tìm theo tên, mã, mã cũ, **không cần dấu**; dòng phụ (sĩ số, còn chỗ, phụ huynh); lựa chọn không chọn được kèm lý do ("Hết chỗ"); không có kết quả; đang tìm; lỗi; tắt | Cao control theo mật độ; danh sách tối đa 8 dòng | ARIA combobox/listbox; ↑ ↓ bỏ qua lựa chọn bị khoá, Enter, Esc, Tab đóng, Backspace bỏ thẻ cuối | Lớp trên dòng đơn (chỉ lớp Đã duyệt, R-GD-08); học sinh HS000123 / mã cũ NCT-0456 |
| **DateRange** | Mốc nhanh Hôm nay · Tuần này · Tháng này · Tháng trước; tuỳ chọn hai ngày; nút hiện tên mốc + khoảng | Popover; trên điện thoại dùng bottom sheet (dự kiến) | Lịch dùng MonthGrid | Báo cáo tháng 10/2026 |
| **MoneyInput** | Nhập; `readOnly` (giá hệ thống tính: khoá + "Hệ thống tính", nền nhạt, viền nét đứt); lỗi; tắt | Căn phải, `tabular-nums`, đuôi "đ" | `inputMode="numeric"`; giá trị đọc kèm đơn vị | Đơn giá 220.000 đ (chỉ đọc); tiền cọc < 1.000.000 đ báo lỗi |
| **FileUpload** | Máy tính: kéo thả + "chọn tệp"; điện thoại: "Chụp ảnh" (camera sau) + "Chọn ảnh, PDF"; xem trước ảnh / biểu tượng PDF; tiến độ; lỗi (quá 10 MB, sai định dạng); gỡ | Nút điện thoại rộng 50%, cao ≥ 44px | Nút gỡ có nhãn; tiến độ `role="progressbar"` | Chứng từ chuyển khoản phiếu thu; ảnh bài làm BTVN |

### 11.6 Học vụ

| Thành phần | Biến thể / trạng thái riêng | Cỡ & điện thoại | Bàn phím & a11y | Ví dụ HMT |
| --- | --- | --- | --- | --- |
| **HoursDisplay** | Thanh đã dùng / còn lại / giờ tặng; sắp hết ≤ 10 giờ (Badge + đổi vàng); giờ tặng chưa cấp (sọc nét đứt, "cấp khi thu đủ tiền" — R-TIEN-24); **quá hạn gói còn giờ = thông tin, không phải lỗi** (R-GD-07); gọn | Giờ dạng "16,5 giờ" | Thanh có nhãn đọc đủ số | 36 giờ cấp, 18 đã dùng, 4 tặng, hết giờ dự kiến 20/12/2026 |
| **RatingScale** | 1–5 có mô tả mức; **chưa chấm** (ô nét đứt + "Chưa chấm — khác điểm 0") ≠ điểm; bỏ chấm; bắt buộc | Ô ≥ 44px, cách 8px — một tay | Radio gốc, mũi tên đổi mức | Thái độ 3, Kiến thức 3, Vận dụng 2 dòng nội dung; lời nhắn phụ huynh bắt buộc |
| **HomeworkStatus** | Đã chấm · Làm chưa xong (có điểm) · Không làm · Nộp sau · Không áp dụng; dạng xem / sửa; thiếu điểm = lỗi | — | Select + radio | 8A1 Buổi 11 Bài 1 |
| **RadarChart** | Một chuỗi `hmt-chart-1` + trung bình lớp nét đứt; **luôn có "Xem bảng số"**; tooltip khi rê | Rộng tối đa 420px | `role="img"` + nhãn đọc toàn bộ số; bảng số là `<table>` | 6 tiêu chí tháng 10/2026 |
| **TaskStepper** (K12) | 5 bước buổi dạy; thanh tiến độ; bước bấm được; hạn còn lại (SlaBadge); "Em trước / Em sau" ở bước chấm | Đầu và chân dính; nút ≥ 44px | Bước hiện tại `aria-current="step"`; tiến độ `progressbar` | 8A1 · Buổi 12 · 15/10/2026, còn 5 giờ |

### 11.7 Phản hồi, duyệt, cấu hình, in

| Thành phần | Biến thể / trạng thái riêng | Ghi chú | Ví dụ HMT |
| --- | --- | --- | --- |
| **SlaBadge** | Còn x giờ (info; ≤ 4 giờ warning) · Quá hạn x giờ (danger đặc) · Đúng hạn (success) · Trễ hạn x giờ (danger) | Ngưỡng 4 giờ là đề xuất | Ticket, hạn hoàn tất buổi 8 giờ |
| **ApprovalChain** | Cấp: Đã duyệt · Chờ duyệt · Từ chối (+ lý do) · Chưa tới lượt; dọc / ngang | Người duyệt cấu hình được | Hoàn tiền BM CS1 → Kế toán; chuyển cơ sở BM CS2 → BM CS5 (từ chối) |
| **BlockingDialog** | `block` (⊘, chỉ Đóng, mỗi lý do có nút đến chỗ sửa) · `warn` (⚠, Quay lại / Vẫn tiếp tục) | Thay cho làm mờ nút | Đóng lớp còn em còn giờ (R-LOP-04); duyệt phiếu thu đã qua 2 buổi (R-TIEN-27) |
| **VersionedConfig** (K10) | Đang dùng · Sắp hiệu lực · Lịch sử; so sánh hai phiên bản (Đã đổi / Thêm mới / Bỏ) | Đổi cấu hình không đổi bản ghi cũ | Bảng giá 2026-08 vs 2026-11 |
| **PrintLayout** (K13) | A4 (báo giá) · A5 (biên nhận, phiếu chi); logo, cơ sở, bên liên quan, bảng dòng, tổng, bằng chữ, chữ ký | In đen trắng cố định (không theo theme) | BG-CS1-2610-0001 9.504.000 đ; PT-CS1-2610-0019; PC-CS1-2610-0002 hoàn 4.593.600 đ |

### 11.8 Đã kiểm tra

- 48 thẻ chạy không lỗi JavaScript (giao diện sáng).
- Tương tác: DateRange "Tháng trước" = 01/09–30/09/2026; Combobox tìm không dấu, mã cũ, bỏ qua lựa chọn bị khoá; ConfirmDialog bắt lý do; StatusBar chặn L4 → L5 khi thiếu dữ liệu; Kanban chặn lùi; Chatter @nhắc tên; AttendanceSheet chặn "Tiếp" và đưa focus tới em chưa điểm danh; hai cột vận hành | giáo viên; lịch ngày/tuần/tháng.
- Tương phản: chữ trên nền loại buổi ≥ 14,6:1; chữ phụ ≥ 5,1:1; vạch loại buổi 2 và 3 dưới 3:1 → nhãn chữ bắt buộc (đã có). Bảng màu phân loại kiểm bằng công cụ: 3 màu đầu đạt các ngưỡng bắt buộc (cảnh báo CVD 6,1 giữa màu 2 và 3 → hợp lệ vì có nhãn chữ).
- Chưa kiểm tra: icon Lucide thật (môi trường chặn CDN), trình đọc màn hình, thiết bị thật.


### 11.9 Sửa theo góp ý sau manifest (11/10)

**Điểm BTVN gõ số (A-6, sửa bởi A-47: thang 1–5 theo R-GV-11)** — thay thang bấm trong HomeworkStatus.

| Mục | Quy định |
| --- | --- |
| Thành phần | `ScoreInput` (mới, phụ trợ), đặt trong `Field`. Khoảng mặc định 1–5 (A-47; kiểm tra đầu vào truyền 0–10), cho một chữ số thập phân — 4,5 (A-8) |
| Bàn phím | `inputMode="numeric"` trên điện thoại; căn phải; chữ số đều cột; đuôi "/ 10" |
| Kiểm tra | Khi rời ô hoặc bấm Enter. Lỗi: "Điểm phải từ 1 đến 10" · "Chỉ nhập số, ví dụ 8" · "Tối đa 1 chữ số sau dấu phẩy". Khi gõ đúng lại thì lỗi tự tắt |
| Thiếu điểm | "Đã chấm" và "Làm chưa xong" bắt buộc có điểm; `showMissing` hiện "Nhập điểm từ 1 đến 10" sau khi bấm Hoàn tất / Kiểm tra |
| Ô trống | Là "chưa có điểm", không phải 0. "Không làm" không thành điểm 0 (R-GV-12) |
| Dạng xem | Badge trạng thái + "8/10" |

**Cổng Giáo viên trên máy tính (A-7)** — cùng component với điện thoại; bố cục đổi theo độ rộng khung (container query), không theo loại thiết bị.

| Thành phần | Điện thoại | Máy tính |
| --- | --- | --- |
| Khung | BottomNav | Sidebar (thu gọn được) |
| Mật độ | 48px ô/nút, 56px hàng | `data-device="desktop"`: 40px ô/nút, 48px hàng, chữ vẫn 16px (P-12) |
| AttendanceSheet | Thẻ từng em, lựa chọn lưới 2 × 2, chân dính, "Tiếp" rộng hết | Khung ≥ 760px: bảng Học sinh · Ghi chú · 4 lựa chọn một hàng (· Lý do liên hệ ở chế độ vận hành); chân trang: tổng bên trái, "Tiếp" bên phải |
| TaskStepper | Thanh bước trên, "Em trước / Em sau" dưới | Khung ≥ 760px: cột bước bên trái (tên đầy đủ), nội dung phải, nút góc phải |
| Chấm từng em | Một em một màn, cuộn dọc | Danh sách em bên trái (Đủ / x/6) + phiếu chấm hai cột Thái độ · Kiến thức (P-13) |
| HomeworkStatus | Trạng thái và Điểm xếp dọc | Khung ≥ 380px: cùng hàng; trong bảng dùng `hideLabels` |
| RatingScale | Ô 44px | Ô 40px theo mật độ máy tính |

**Câu trả lời Q-1…Q-5** — Calendar không ghi giờ trừ cho Học bù/Bổ trợ; điểm danh vận hành dùng 4 trạng thái; "Sắp trễ" ≤ 4 giờ; cả ba bản in khổ A4, vai trò ký theo P-9; mô tả mức rubric lấy từ cấu hình.

**Đã kiểm tra** — 52 thẻ hiển thị không lỗi JS (giao diện sáng). Đã bấm thử: gõ 11, "tám", 7,5 và để trống đều báo lỗi đúng; điểm danh dạng bảng ở 1280px; "Tiếp" bị chặn khi còn em chưa điểm danh ở dạng bảng; TaskStepper đổi bố cục ở 760px.


## 12. Đợt 5.1 · phần 1 — điều hướng ba cổng

Ba thẻ mới trong nhóm "Điều hướng · đợt 5.1" (thẻ sơ đồ, không phải component):

| Thẻ | Nội dung |
| --- | --- |
| NavMap | Đăng nhập → chọn cổng → CRM (thanh trên cố định + menu trái 9 nhóm) · Giáo viên (5 tab) · Học tập (5 tab + đề xuất phụ huynh) · trang dùng chung. Mỗi dòng có mã màn |
| RoleMenu | Ma trận vai trò AD/BM/SA/CS/KT × mục menu, lấy từ cột Vai trò của bản đồ; chọn vai trò để xem menu của vai trò đó |
| FlowMap | 16 luồng L1–L16 thành chuỗi mã màn, màu + nhãn theo cổng, đánh dấu chuyển cổng, mức vẽ A/B/C; lọc "Có chuyển cổng" (5 luồng: L1, L4, L11, L12, L16) |

Tài liệu bàn giao: `HMT_DIEU_HUONG_5.1.md`.


## 13. Đợt 5.2 — Chung + Quản trị

### 13.1 Khuôn thành component (dùng lại ở các đợt sau)

| Component | Khuôn | Cố định | Màn thay | Ghi chú |
| --- | --- | --- | --- | --- |
| `AppShell` | K01 | Menu trái (9 nhóm, dựng theo vai trò từ `CRM_MENU_ROWS` / `menuFor(role)`), thanh trên: tìm kiếm, chọn cơ sở (chỉ AD, KT: Tất cả, CS1, CS2, CS4, CS5), chuông thông báo, tài khoản | `children` = vùng nội dung | `defaultCollapsed`, `mobile` (menu vào ngăn kéo trái), `badges` theo mã màn, `loading` |
| `AuthLayout` | K11 | Mảng thương hiệu nền `hmt-action` + logo trắng (máy tính); logo trên đầu (điện thoại) | Khối biểu mẫu | `product="lms"` cho học sinh |
| `PageHeader` | — | — | Tiêu đề + mã + breadcrumb + meta + nút | |
| `StatTile` | K09 | — | Thẻ số bấm mở danh sách lọc sẵn | Có `loading`, `hintTone`, mã màn đích |
| `TurnstileSlot` | — | Giữ chỗ 300 × 65 cho ô Cloudflare | Trạng thái: đang xác minh, đã xác minh, lỗi, hết hạn | Ô thật do Cloudflare vẽ |
| `OtpInput` | — | — | 6 ô số, dán cả mã, phím mũi tên, xoá lùi | CHUNG-02, CHUNG-03 |
| `PasswordInput`, `PasswordRules` | — | — | Nút Hiện/Ẩn; luật ≥ 8 ký tự, có chữ, có số | `passwordOk()` |

Chú thích vùng: thẻ màn có công tắc "Hiện vùng cố định / thay đổi" (viền xám = cố định, viền xanh = màn thay).

### 13.2 Màn đã vẽ

Mức A (đủ trạng thái): CHUNG-01, CHUNG-06, CHUNG-10, CHUNG-14 (4 biến thể vai trò), CHUNG-22, QT-05, QT-07, QT-09.
Mức B (trạng thái chính): CHUNG-02, CHUNG-03, CHUNG-04, CHUNG-07, CHUNG-11, CHUNG-12, CHUNG-26, QT-01, QT-02, QT-03, QT-04, QT-06, QT-08, QT-10, QT-11, QT-13.
Mỗi màn là một thẻ trong nhóm "Màn 5.2 · …", tên thẻ = mã màn; README của thẻ chép dòng bản đồ + trạng thái đã vẽ.

### 13.3 Đã kiểm tra

75 thẻ hiển thị không lỗi JS (giao diện sáng). Bấm thử: menu đổi theo 5 vai trò, chọn cơ sở chỉ có ở AD/KT; ma trận quyền đổi ô → thanh "thay đổi chưa lưu" + ô vàng; danh mục đổi tên, đổi thứ tự, Ngừng; tham số ngoài khoảng báo lỗi; tìm kiếm không dấu.


## 14. Đợt 5.3 · phần 1 — Tuyển sinh, Kiểm tra đầu vào, Khách hàng

Mức A: TS-01 (danh sách + kanban), TS-08, TS-11, TS-17. Mức B: TS-02, 03, 06, 07, 13, 15, 16, 18, 19, KH-01, 02, 04, 05, GV-15 (điện thoại).
Thay đổi DS: `Calendar` thêm `types`, `legendLabel`, `cancelledLabel` (mặc định vẫn là loại buổi).
Luật thể hiện: cơ hội chỉ đi tới (thanh trạng thái + kanban); từ L5 bắt buộc tên, năm sinh (chặn có nút đến ô); lead đã có cơ hội (cảnh báo + xác nhận lần hai hoặc gộp); trùng SĐT (cảnh báo, không chặn); lịch hẹn một bấm; phiếu test tạo không có lịch, xếp lịch tự sinh lịch hẹn nhắc; huỷ test bắt buộc lý do nối L5C–L5O; báo giá, đơn chỉ sinh từ cơ hội.

## 15. Đợt 5.3 · phần 2 — Bán hàng, Thu chi, Cấu hình bán hàng

Mức A: BH-05 (9 trạng thái), TC-05, TC-02, BH-02, BH-08, CHUNG-15 (máy tính + điện thoại). Mức B: BH-01, 03, 06, 07 (cả hai), 09, TC-01, 03, 04, 07, 08, 09, 13, 15, CH-01, 03, 04.
Thay đổi DS: `.hmt-chip` thêm `flex: none; white-space: nowrap` (P-46). Không thêm component mới.
Dựng lại: K06 (BH-05, BH-02, TC-02), K08 (BH-07, BH-08, BH-09, TC-03, TC-05, TC-09), K03 (BH-01, BH-06, TC-01, TC-04, TC-08, TC-13, CHUNG-15), K09 (TC-15), K10 (CH-01, CH-03 dùng `VersionedConfig`, CH-04), K13 (BH-03, TC-07 dùng `PrintLayout` A4).
Luật thể hiện: không có nút "Tạo" báo giá, đơn, phiếu thu ở danh sách (chỉ sinh từ cơ hội / đơn); giá chỉ đọc; chiết khấu cộng dồn, vượt trần 20% là cảnh báo cần Trưởng cơ sở duyệt; trình đơn bị chặn chỉ đúng dòng, đúng ô; đơn duyệt thì khoá, huỷ đơn có tiền phải qua ticket; phiếu thu có "Cấn vào dòng" (trống = chia tỉ lệ); chỉ Kế toán duyệt tiền, "đã qua N buổi" là cảnh báo; duyệt sinh khoản tiền vào, cấp giờ theo tỉ lệ, tạo ghi danh khi đủ ngưỡng; khoản tiền vào chỉ đọc, đảo khoản một lần, có lý do.

## 16. Đợt 5.1 · phần 2 — khuôn K01–K13 (làm bù)

13 thẻ nhóm "Khuôn 5.1". Mỗi thẻ có: danh sách màn dùng khuôn (đếm từ bản đồ), các trạng thái (P-47), nút "Hiện vùng cố định / thay đổi" (P-48).
Bản điện thoại: K01, K03, K06, K11 (máy tính + điện thoại); K02, K12 điện thoại trước, có bản máy tính cho cổng Giáo viên (A-7); cổng Học tập chỉ điện thoại.
Thay đổi DS: CSS `[data-zone="fixed|vary"]` + `data-zone-label` (chỉ dùng trong thẻ xem trước), `.hmt-zone-legend`, `.hmt-kbar*` (biểu đồ thanh một chuỗi cho K09). Helper xem trước `TplFrame`, `Z`, `TplState` trong `previews/_shared.tsx`. Không thêm component mới.
Cập nhật 12/10 theo A-13…A-16: tổng chiết khấu dòng = % + giờ tặng ÷ giờ mua (hiện cả hai phần); mã gói bỏ hình thức (`LC-TOAN-K09`), CH-01 có cột Loại, Đơn vị, Hình thức bán được, Quỹ giờ; CH-03 hai giá Offline/Online mỗi gói, DV theo tháng, TL theo bộ; mã khoản tiền vào `KTV-CS1-2610-0221`, khoản đảo "Đảo của …".

## 17. Đợt 5.4 · phần 1 — Ghi danh, Lớp học, Cấu hình đào tạo

Mức A: GD-02 (8 trạng thái, 4 vai trò), GD-03 (6), LOP-02 (10, 3 vai trò), LOP-04 (7), LOP-08 (5). Mức B: GD-01, 04, 05, 06, 07, LOP-01 (danh sách + kanban), 03, 05, 06, 07, 10, CH-05, 06, 07, QT-14, QT-16. Mức C: LOP-09 (K03).
Thay đổi DS: `EventChip`/`Calendar` — `conflict` thêm "teacher", "both" (P-61); kiểu `CalendarEvent.type` mở thành string. Không thêm component mới.
Dữ liệu mẫu chung (`previews/_shared.tsx`): `CLS` (lớp CS1 2026–2027), `LOP_STEPS`, `GD_STATUS`/`GdBadge`, `CHAU_LEDGER` (sổ giờ GD000076, số dư 28 giờ).
Luật thể hiện: ghi danh không có nút Tạo; một quỹ giờ cho nhiều dòng xếp lớp (Đại + Hình); chỉ một lớp → cảnh báo; sổ giờ chỉ thêm, điều chỉnh là dòng ngược dấu có lý do; hạn gói chỉ dự báo; lớp chỉ sửa ở Nháp, Từ chối; duyệt bắt buộc có thời khoá biểu, xem trước số buổi và ngày kết thúc đã trừ ngày nghỉ; trùng phòng cảnh báo; đóng lớp chặn khi còn em còn giờ, huỷ chặn khi có buổi Done; đổi giáo viên, đổi lịch sinh lại buổi chưa diễn ra.

## 18. Đợt 5.4 · phần 2 — Buổi học

Mức A: BUOI-02 (8 trạng thái, 2 vai trò), BUOI-04 (7). Mức B: BUOI-01 (danh sách + lịch ngày), 03 (máy tính + điện thoại), 05, 06, 07, 08, 09 (CRM + cổng Giáo viên điện thoại), 10, 11, 12, 13. Mức C: BUOI-14 (K08).
Thay đổi DS: không. Dùng AttendanceSheet `mode="compare"` cho bản ghi buổi và `mode="ops"` cho điểm danh vận hành.
Luật thể hiện: buổi không có mã (hiện lớp · buổi · ngày); có tên trong danh sách và Done thì trừ giờ, kể cả vắng; học thử không trừ giờ; ô giáo viên là chính thức; chưa Done luôn có lý do; huỷ lớp chung = trung tâm huỷ, không tính phí, thêm buổi cuối; lớp riêng chọn có/không tính phí, lý do bắt buộc; học bù, bổ trợ không trừ giờ, củng cố trừ giờ; chỉ Trưởng cơ sở duyệt yêu cầu buổi.

## 19. Đợt 5.4 · phần 3 — Chăm sóc khách hàng, Tái tục, QT-15, TC-10, TC-11

Mức A: CS-02 (11 trạng thái, 3 vai trò), CS-03 (11, 3 vai trò), CS-05 (bảng hoàn tiền, hoàn một phần, bị chặn, trùng, đang xử lý, lỗi, Trưởng cơ sở chỉ đọc). Mức B: CS-01 (danh sách + kanban), 04, 06, 07, 08 (máy tính + điện thoại), 09, 10, 11, 16, TT-01, TT-02, QT-15, TC-10, TC-11. Mức C: CS-12, CS-13, CS-14, TT-03, TC-16 (K08), TC-12 (K13), TC-14 (K03).
Thay đổi DS: không.
Luật thể hiện: ticket có mã `DN-CS1-2610-0012` / `KN-…`; chuỗi duyệt theo QT-15 (tiền: Trưởng cơ sở xác nhận nghiệp vụ, Kế toán duyệt tiền); khiếu nại có hạn xử lý, quá hạn tự leo thang; hoàn tiền = đã thu − giờ đã dùng × đơn giá − phí theo cấu hình, đề nghị hoàn một phần nhập số giờ hoàn; chuyển lớp, chuyển cơ sở, bảo lưu, chuyển phí chỉ đi qua ticket; phiếu chi chỉ sinh từ ticket đã duyệt.
Cập nhật BUOI theo A-18…A-21: huỷ buổi tới khi Done (kể cả sau chốt, dòng điểm danh vô hiệu; CSKH, Trưởng cơ sở huỷ, Giáo viên không có nút); củng cố bắt buộc "Phụ huynh đã đồng ý" (kênh, ngày, người xác nhận), thiếu thì chặn gửi duyệt; học thử tối đa `hoc_thu_toi_da` = 2 buổi/cơ hội, không tính vào sĩ số ("Sĩ số 12/15 · học thử 1"), vượt sĩ số chỉ cảnh báo; cơ hội khác khối chỉ cảnh báo.

## 20. Áp dụng câu trả lời 12/10 (A-22…A-37) và bảng danh mục, tham số

Nguồn mới: `HMT_DANH_MUC_VA_THAM_SO.md` (30 danh mục, 29 tham số) — giá trị nạp sẵn là dữ liệu thật.
Thay đổi DS: `menuFor` cho Admin đủ mọi mục CRM (A-22); `CONTACT_REASONS` thêm "Khác" (danh mục 17); `GD_STATUS` (xem trước) thêm `placed` = Đã xếp lớp. Không thêm component mới.
Màn đã sửa:
- Quản trị: QT-04, QT-05 (Admin), QT-06 (30 danh mục, cột Khoá), QT-07 (ba loại khoá, 3 cấp, giá trị thật), QT-09 (29 tham số, khoảng, ghi đè), QT-14 (áp dụng theo cơ sở), QT-01, CHUNG-01, CHUNG-06 (sai 10 lần, khoá 15 phút).
- Ghi danh: GD-01, GD-02, GD-06 (trạng thái Đã xếp lớp; hàng chờ chỉ gồm Chờ xếp lớp), GD-03, BH-08 (trùng giờ kể cả ghi danh khác là chặn), GD-05 (lý do điều chỉnh giờ).
- Danh mục áp vào màn: TS-01/02/03/08/11/17/19, BUOI-03/04/10/11, CS-04, TC-02/05, CHUNG-14/15.
- CSKH, tái tục, thu chi: CS-05, CS-10 (chuyển phí theo giá sau chiết khấu, không trừ phí), TT-01, TT-02 (L1–L8 mới, L5 Không tái tục là nhánh kết thúc), TC-11 (một Kế toán lập và duyệt).
Câu hỏi mới: Q-33 (Admin duyệt tiền?), Q-34 (lý do từ chối báo giá, lớp, đảo khoản, khoá tài khoản), Q-35 (nhóm con khiếu nại).

## 21. Đợt 5.7 — Báo cáo

Mức A: BC-01 (Admin mọi cơ sở, Trưởng cơ sở, Một phần lỗi, Không có số liệu, Đang tải, Lỗi, Không có quyền). Mức B: BC-08, BC-09 (thuộc bản đồ đợt 5.5, gộp vào đợt Báo cáo). Looker (không vẽ): BC-02, BC-03, BC-04, BC-05, BC-06, BC-07, BC-10 — BC-01 có link mở tab mới.
Thay đổi DS: thêm `LineChart` (P-78) + CSS `.hmt-lc*`; helper `Shell` nhận `campus`, `onCampus` (P-79).
Luật thể hiện: một trục y; chú giải + nhãn cuối đường, chuỗi 2 nét đứt, bảng số đi kèm; số tiền đầy đủ dạng 1.208.400.000 đ ở dòng phụ và bảng; không có CS3 trong số liệu; lọc cơ sở bằng ô trên thanh trên; link ngoài vai trò bị ẩn; giờ dạy tính cho người dạy thật, học bổ trợ có cột riêng.

## 22. Đối chiếu prompt đợt 5.4 (12/10)

Sửa: CS-05 theo đúng ví dụ file luật (9.504.000 − 20 × 220.000 = 5.104.000; trừ 10%; hoàn 4.593.600 đ), cập nhật CS-02, CS-08, TC-10, TC-11, LOP-02. BUOI-10 có bản điện thoại. CS-02 thêm trạng thái "Nhóm con Dừng học · Thực hiện" (hộp thoại CS-14 vẽ ngay trong thẻ). Màn vẽ trước đợt (CH-07, CS-16, BC-08, BC-09, BC-01) sẽ đối chiếu lại khi có prompt đợt của chúng (P-82).

## 23. Đợt 5.5 · phần 1 — khung cổng Giáo viên và khuôn K14

Mức B: GV-01 (điện thoại + laptop). Khuôn mới: K14 Bảng chấm nhanh (laptop) — 7 trạng thái, 3 kiểu cột.
Thay đổi DS: thêm `TeacherShell` (+ `GV_NAV`), `QuickGrid` (K14) + CSS `.hmt-gvshell*`, `.hmt-qg*`; COMPONENT_INVENTORY mục 6. Dữ liệu buổi mẫu `GV_SESSION`, `GV_ROSTER` (12 em), `GV_ATT_COLS`, `GV_CRIT`, `GV_RUBRIC`, `GV_LINES`, `GV_GRADE_COLS` trong `previews/_shared.tsx`.
Luật thể hiện: điểm danh 4 trạng thái, mặc định trống, màu Có mặt nhạt / Đi muộn vàng / Vắng đậm; tiêu chí 1–5 có mô tả mức từ rubric; BTVN điểm 1–10 có số lẻ; ô trống khác điểm; em vắng không chấm; TB vận dụng do hệ thống tính; lưu tự động từng ô; không có nút đổi tình trạng buổi.

## 24. Đợt 5.5 · phần 2 — các màn cổng Giáo viên

Mức A (điện thoại + laptop): GV-02 (6 trạng thái), GV-04 (7), GV-05 (7, laptop K14), GV-07 (7, laptop K14 + ngăn bên), GV-08 (7, laptop K14). Mức B: GV-03 (điện thoại xem ngày, laptop xem tuần), GV-06 và GV-09 (cả hai; GV-09 có Còn thiếu, Đúng hạn, Trễ hạn 3 giờ), GV-10, 11, 12, 14, 16 (điện thoại). Đã có từ trước, đối chiếu đúng: CH-07, BC-08, BC-09; CS-16 đổi dữ liệu sang buổi 9A2. Mức C: GV-13 (K06).
Một buổi trọn vẹn 9A2 Đại · Buổi 4 · 12 em đi từ GV-02 → GV-04 → GV-05 → GV-06 → GV-07 → GV-08 → GV-09 trên cả hai thiết bị.
Thay đổi DS: `TeacherShell` thêm `flush` (bỏ đệm để TaskStepper chiếm trọn vùng nội dung).
Luật thể hiện: không có nút đổi tình trạng buổi; buổi tự Done khi hoàn tất, đóng dấu Đúng/Trễ hạn kèm giờ trễ; em có mặt đủ 6 tiêu chí + lời nhắn; em vắng không chấm; BTVN mỗi em một trạng thái, Nộp sau cập nhật ở buổi sau; giáo viên chỉ tạo ticket, không duyệt.

## 25. Áp dụng câu trả lời Q-33…Q-39 (A-39…A-45)

- QT-05: Admin duyệt thay phiếu thu, đảo khoản, yêu cầu buổi; BUOI-10, TC-05 ghi "Admin duyệt thay".
- Danh mục: 24 có cột Áp dụng cho; thêm 31 Lý do đảo khoản, 32 Lý do khoá tài khoản (QT-06 32 danh mục, QT-07); nhóm con khiếu nại theo R-CS-04 (QT-07, CS-03, CS-04).
- Lý do trên màn: BH-04 (báo giá), LOP-02 (lớp), TC-05 / CHUNG-15 (phiếu thu), BUOI-10 (yêu cầu buổi) lọc theo Áp dụng cho; TC-09 dùng danh mục 31; QT-02, CHUNG-26 dùng danh mục 32. "Khác…" luôn có ở cuối ô chọn và bắt buộc ghi chú (ConfirmDialog); bỏ các mục "Khác" trùng.
- BC-01: số Đang bảo lưu (tile + cột), định nghĩa doanh thu ghi nhận mới. BC-09: nút Chốt tháng + trạng thái Đã chốt.
- CS-02: dừng học — giữ thành số dư = 18 giờ × 198.000 đ = 3.564.000 đ, giờ tặng còn lại bị huỷ.

## 26. Đợt 5.6 — Học tập + Phụ huynh (giai đoạn 4)

Mức A: HT-01 (7 trạng thái, hai bản lớp 3 / lớp 11, điện thoại), HT-04 (11 trạng thái, điện thoại + laptop). Mức B: GV-17, GV-18 (hai thiết bị), HT-02, HT-03, HT-05, HT-06, HT-07, HT-09 (hai thiết bị), PH-01…PH-04. Mức C (chỉ liệt kê): HT-08 (đã có trong khối "Theo từng buổi" của HT-07 / PH-02), PH-05, CHUNG-23, QT-17.
Thay đổi DS: thêm `StudentShell` (+ `HT_NAV`, `PH_NAV`), `PhotoPages`, `SubmissionViewer`; 6 biểu tượng (rotateCw, zoomIn, zoomOut, eye, award, flame); CSS `.hmt-lshell*`, `.hmt-lms-*`, `.hmt-pp*`, `.hmt-sv*`, `[data-young]`. Sửa `LineChart`: lưới một cột `minmax(0,1fr)` để không tràn khi đặt trong khung hẹp.
Luật thể hiện: R-GV-10 (giao, nộp bài), R-GV-11 (5 trạng thái BTVN, điểm 1–5 một chữ số thập phân — A-47), R-GV-12 (tỉ lệ làm bài và điểm TB tách riêng, Không làm không tính 0), R-GD-13 (sắp hết giờ ≤ 30 ngày), R-CS-06 (bước khiếu nại, phụ huynh xác nhận phương án, chấm hài lòng).
Xưng hô: học sinh "em", HMT xưng "HMT"; phụ huynh "Anh/Chị", gọi học sinh là "con". Lớp màu ấm chỉ trong cổng học sinh.

## 27. Áp dụng câu trả lời Q-40…Q-44 và hai sửa (A-47…A-53)

- **Thang điểm BTVN 1–5 (A-47):** `HomeworkStatus`, `ScoreInput` mặc định 1–5 (lỗi ví dụ tự theo thang). Sửa GV-08 (TB 3,9/5), GV-04, GV-09, GV-03, GV-18 (Nam 4 · Thư 5 · Kiệt 4,5 · Ánh 4), HT-01 (Dương 4,5/5, TB 4,1/5), HT-02, HT-05 (4/5), HT-07 (TB 3,8/5; nếu tính Không làm là 0 thì sai thành 2,5), PH-02 (Ngọc 4,3/5), thẻ HomeworkStatus, K14, QuickGrid, KH-05. GV-15 giữ 0–10.
- **Khung phụ huynh (A-48):** `PH_NAV` = Trang chủ, Kết quả, Lịch, Học phí, Đề nghị; `StudentShell portal="ph"` có nút ảnh đại diện trên thanh tiêu đề mở menu Tài khoản, Đổi mật khẩu, Đăng xuất. Vẽ PH-05 Lịch học của con (mức B, chọn cả hai con / từng con).
- **Phần thưởng (A-49):** QT-10 thêm dòng "Cổng Học tập · Phần thưởng" và "Cổng Phụ huynh"; HT-01 thêm trạng thái "Cơ sở tắt phần thưởng".
- **Nộp muộn, nộp lại (A-50):** GV-17 chữ hướng dẫn hai công tắc; GV-18 thêm trạng thái "Bài đã chấm · khoá nộp lại" với nút "Mở lại cho em nộp lại", nhãn Nộp muộn; HT-04 ghi chú.
- **Hài lòng (A-52):** QT-09 thêm tham số `cs_han_ph_xac_nhan_ngay` (3 ngày, 1–14, không ghi đè theo cơ sở).
- **Tệp (A-53):** HT-04 thêm "Ảnh sẽ được nén để tải nhanh"; dung lượng ảnh mẫu sau nén khoảng 420–460 KB.

## 28. P6 — sửa sau kiểm tra (A-54, P-100, P-101)

- **Vùng bấm ≥ 44px trên điện thoại** (sửa ở thành phần gốc): Chip 44px trong cổng Giáo viên, Học tập (laptop giáo viên 36px); `Button size="sm"` 44px trong cổng Giáo viên, Học tập và khung điện thoại (laptop 32px); nút chỉ có biểu tượng tối thiểu 44px; ô nhập, ô chọn phủ hết chiều cao khung; Tabs, nút đổi kiểu xem của FilterBar 44px; link mã trong danh sách điện thoại cao 44px. Khung `.hmt-phone` và `@media (max-width: 640px)` dùng chung quy tắc cho bản điện thoại của màn CRM.
- **KanbanCard** nhận `onOpen`, `openLabel`: mã trên thẻ là link mở bản ghi.
- **Màn sửa:** TC-05, TC-13, BH-08, GD-03, TC-09, TC-03, TS-11, BH-07, BH-03, BH-09, LOP-03, LOP-04, LOP-05, CS-08, TC-11, TT-01, QT-02, TS-17, HT-01 (đổi tên học sinh lớp 11), CHUNG-06, GV-17, BC-01 (đợt 5.7).
- **Ngoại lệ đã chốt:** mã QR mẫu (CHUNG-03) giữ đen trên nền trắng; tên thẻ màn giữ dạng rút gọn.
