# HMT Design System Spec — Foundation

**HMT Platform · CRM · Teacher Portal · LMS**

| | |
| --- | --- |
| Phiên bản | 1.0 — đã duyệt (P3, 2026-10-11). Các mục OPEN vẫn mở |
| Ngày | 2026-10-11 |
| Nguồn chuẩn bản sắc | `HMT_BRAND_GUIDELINES.md` (đã duyệt) |
| File token | `HMT_DESIGN_TOKENS.css` |
| Công nghệ mục tiêu | React + Tailwind CSS v4, CSS custom properties |
| Phạm vi | Nền tảng (token, theme, quy tắc, ví dụ). **Không** gồm màn hình nghiệp vụ và thư viện component đầy đủ |

### Nhãn trạng thái

| Nhãn | Nghĩa |
| --- | --- |
| **APPROVED** | Kế thừa từ Brand Guidelines đã duyệt. Không đổi trong P3. |
| **PROPOSED** | Mới trong P3, chờ duyệt. |
| **OPEN** | Cần quyết định hoặc kiểm thử thêm. |

> **Giả định:** "Brand Guidelines đã được duyệt" được hiểu là các mục PROPOSED trong tài liệu đó nay là APPROVED. Các mục OPEN DECISION trong đó (font, logo rút gọn…) vẫn để mở. Nếu hiểu sai, các chỗ dẫn chiếu "Brand §…" cần xem lại.

---

## 1. Kiến trúc token

### 1.1 Ba tầng

| Tầng | Tiền tố | Ví dụ | Ai dùng |
| --- | --- | --- | --- |
| Primitive | `--hmt-p-*` | `--hmt-p-orange-600: #B54515` | Chỉ file token. **Không** dùng trong component |
| Semantic | `--hmt-*` | `--hmt-action`, `--hmt-danger-subtle` | Component, CSS tuỳ biến |
| Tailwind | `@theme` | `bg-action`, `text-fg-muted` | Mã React |

Component chỉ được tham chiếu **semantic token** (qua utility Tailwind hoặc `var(--hmt-*)`). Đổi theme hay chỉnh màu chỉ sửa tầng primitive/semantic, không sửa component.

### 1.2 Thuộc tính trên `<html>`

```html
<html lang="vi" data-theme="light" data-product="crm">
```

| Thuộc tính | Giá trị | Tác dụng |
| --- | --- | --- |
| `data-theme` | `light` · `dark` | Đổi toàn bộ semantic color, shadow |
| `data-product` | `crm` · `teacher` · `lms` | Đổi mật độ: cỡ chữ body, chiều cao control/hàng, khoảng cách, bo góc thẻ |

`data-theme` do app đặt: lần đầu theo `prefers-color-scheme`, sau đó theo lựa chọn người dùng (lưu trong tài khoản). **(PROPOSED)**

### 1.3 Cài đặt

```css
/* app.css */
@import "tailwindcss";
@import "./HMT_DESIGN_TOKENS.css";
```

File token **xoá bảng màu mặc định của Tailwind** (`--color-*: initial`), nên `bg-orange-500`, `text-red-600`… không tồn tại. Đây là chủ đích: mọi màu phải đi qua semantic token. **(PROPOSED)**

---

## 2. Màu

### 2.1 Brand tokens

| Semantic | Tailwind | Light | Dark | Vai trò | Trạng thái |
| --- | --- | --- | --- | --- | --- |
| `--hmt-brand` | `bg-brand` | `#EF6926` | `#EF6926` | Mảng nhận diện: banner, màn đăng nhập, minh hoạ | APPROVED |
| `--hmt-on-brand` | `text-on-brand` | `#211C16` | `#211C16` | Chữ trên mảng brand (5.41:1) | APPROVED |

**Không** dùng `brand` làm chữ, icon hay viền mang nghĩa trên nền sáng (2.87–3.13:1). **(APPROVED — Brand §3.2, §8.3)**

### 2.2 Nền, bề mặt, chữ, viền

| Semantic | Tailwind | Light | Dark | Vai trò |
| --- | --- | --- | --- | --- |
| `--hmt-canvas` | `bg-canvas` | `#F7F5F2` | `#141110` | Nền trang |
| `--hmt-surface` | `bg-surface` | `#FFFFFF` | `#1C1814` | Thẻ, bảng, form |
| `--hmt-surface-subtle` | `bg-surface-subtle` | `#F0ECE8` | `#25201B` | Header bảng, dòng xen kẽ, sidebar |
| `--hmt-surface-raised` | `bg-surface-raised` | `#FFFFFF` | `#25201B` | Dropdown, popover, tooltip |
| `--hmt-surface-overlay` | `bg-surface-overlay` | `#FFFFFF` | `#2E2822` | Modal, drawer, bottom sheet |
| `--hmt-scrim` | `bg-scrim` | `#141110` 48% | `#000` 60% | Lớp phủ sau modal |
| `--hmt-fg` | `text-fg` | `#211C16` | `#EDE8E2` | Chữ chính, số liệu |
| `--hmt-fg-muted` | `text-fg-muted` | `#6B635B` | `#A39A90` | Nhãn, metadata, placeholder |
| `--hmt-fg-inverse` | `text-fg-inverse` | `#EDE8E2` | `#211C16` | Chữ trên nền đảo (tooltip tối ở light) |
| `--hmt-border` | `border-border` | `#DDD6CF` | `#3A332C` | Đường chia, viền thẻ — **chỉ trang trí** |
| `--hmt-border-strong` | `border-border-strong` | `#8A8178` | `#7A7067` | Viền input, checkbox, nút viền (≥3:1) |

Màu: APPROVED (Brand §4). `surface-raised`/`surface-overlay` dark, `scrim`, `fg-inverse`: PROPOSED.

### 2.3 Interactive tokens

| Semantic | Tailwind | Light | Dark | Vai trò |
| --- | --- | --- | --- | --- |
| `--hmt-action` | `bg-action` | `#B54515` | `#F28A52` | Nút chính |
| `--hmt-action-hover` | `bg-action-hover` | `#933812` | `#F7A372` | Hover |
| `--hmt-action-pressed` | `bg-action-pressed` | `#7A2E0E` | `#FBC4A1` | Đang nhấn — **PROPOSED** |
| `--hmt-on-action` | `text-on-action` | `#FFFFFF` | `#1A1612` | Chữ/icon trên nút chính |
| `--hmt-link` | `text-link` | `#B54515` | `#F28A52` | Link trong nội dung |
| `--hmt-selected` | `bg-selected` | `#FBEDE5` | `#3A2418` | Hàng, tab, chip, mục menu đang chọn |
| `--hmt-on-selected` | `text-on-selected` | `#8F3510` | `#F7B48C` | Chữ trên `selected` |
| `--hmt-secondary` | `text-secondary` | `#2E4A66` | `#8DB0D4` | Link phụ, nhãn thông tin trung tính |
| `--hmt-secondary-subtle` | `bg-secondary-subtle` | `#E8EEF4` | `#1F2A36` | Nền nhạt đi với secondary |
| `--hmt-hover-overlay` | `bg-hover-overlay` | ink 5% | ivory 6% | Hover cho phần tử trung tính (hàng bảng, mục menu) — **PROPOSED** |
| `--hmt-pressed-overlay` | `bg-pressed-overlay` | ink 10% | ivory 12% | Nhấn phần tử trung tính — **PROPOSED** |

### 2.4 Focus

| Semantic | Tailwind | Light | Dark |
| --- | --- | --- | --- |
| `--hmt-focus` | `ring-focus` / utility `focus-ring` | `#1F5FBF` | `#8AB8F5` |
| `--hmt-focus-offset` | — | = `surface` | = `surface` |

**Quy tắc (PROPOSED):**

- Vòng focus **2px**, cách phần tử **2px** bằng màu nền. Dùng utility `focus-ring` (chỉ hiện với `:focus-visible`).
- Focus màu **xanh**, không phải cam. Lý do: cam đã là màu hành động; vòng xanh tách được "đang ở đâu" khỏi "bấm vào đây".
- Tương phản vòng focus với nền: light ≥ 5.18:1, dark ≥ 7.11:1 (vượt yêu cầu 3:1).
- Vòng focus trên nút cam chỉ đạt 1.11:1 nếu dính sát, **vì vậy bắt buộc có khoảng cách 2px** — khi đó vòng tiếp giáp với nền, không với nút.
- Không bao giờ `outline: none` mà không có thay thế.

### 2.5 Disabled

| Semantic | Tailwind | Light | Dark |
| --- | --- | --- | --- |
| `--hmt-disabled-bg` | `bg-disabled` | `#EFEBE6` | `#25201B` |
| `--hmt-disabled-fg` | `text-on-disabled` | `#A39A90` | `#6E655D` |
| `--hmt-disabled-border` | `border-disabled-border` | `#DDD6CF` | `#3A332C` |

**Quy tắc (PROPOSED):** WCAG miễn yêu cầu tương phản cho phần tử disabled, nhưng disabled **không chỉ thể hiện bằng màu**: dùng `disabled`/`aria-disabled="true"`, bỏ hover, `cursor-not-allowed`, và nếu người dùng cần biết lý do thì có dòng giải thích (ví dụ "Chưa đến giờ điểm danh"). Không dùng `opacity` để làm disabled (chữ dấu tiếng Việt mờ nhoè, tương phản không kiểm soát được).

### 2.6 Màu trạng thái — success, warning, danger, info

> **PROPOSED** — xác định mới trong P3, không suy ra từ màu thương hiệu (theo yêu cầu Brand §0).

Mỗi trạng thái có 6 token:

| Hậu tố | Dùng cho |
| --- | --- |
| *(không)* `--hmt-success` | Chữ và icon trạng thái trên `surface`/`canvas` |
| `-subtle` | Nền nhạt: alert, badge nhạt, ô bảng được đánh dấu |
| `on-…-subtle` | Chữ trên nền `-subtle` |
| `-border` | Viền mang nghĩa (input lỗi, alert) — ≥3:1 |
| `-solid` | Nền đặc: badge đặc, nút xác nhận nguy hiểm |
| `on-…-solid` | Chữ trên `-solid` |

| Token | Light | Dark | Light: fg/surface · on-subtle/subtle · on-solid/solid | Dark: tương tự |
| --- | --- | --- | --- | --- |
| success | `#127436` | `#6CCB8F` | 5.87 · 6.94 · 5.87 | 8.89 · 9.87 · 9.00 |
| success-subtle | `#E8F5EC` | `#16281D` | | |
| on-success-subtle | `#0F5F2D` | `#9BDDB2` | | |
| success-border | `#3E9A5E` | `#3E8F5C` | 3.51 | 4.44 |
| warning | `#8A5A00` | `#F0C04A` | 5.93 · 7.66 · 9.07 | 10.37 · 10.45 · 9.94 |
| warning-subtle | `#FDF3D7` | `#2E2410` | | |
| on-warning-subtle | `#6B4500` | `#F5D27A` | | |
| warning-border | `#B98A1E` | `#9C7A24` | 3.13 | 4.39 |
| warning-solid / on | `#F0B429` / `#211C16` | `#F0C04A` / `#211C16` | | |
| danger | `#B42318` | `#FF8A80` | 6.57 · 7.93 · 6.57 | 7.73 · 9.43 · 7.93 |
| danger-subtle | `#FDECEA` | `#3A1714` | | |
| on-danger-subtle | `#8E1B12` | `#FFB4AC` | | |
| danger-border | `#D2493E` | `#C2524A` | 4.41 | 3.86 |
| danger-solid / on | `#B42318` / `#FFFFFF` | `#FF8A80` / `#2A0D0A` | | |
| info | `#1F5FBF` | `#8AB8F5` | 6.09 · 7.45 · 6.09 | 8.62 · 10.19 · 8.55 |
| info-subtle | `#E8F0FB` | `#152338` | | |
| on-info-subtle | `#174A96` | `#B5D2F9` | | |
| info-border | `#4C7FCB` | `#4A79B8` | 4.03 | 3.96 |

**Cách dark mode khác light (không đảo máy móc):**

- Chữ trạng thái chuyển sang sắc **sáng, giảm bão hoà** (đỏ `#B42318` → hồng san hô `#FF8A80`), không chỉ đảo độ sáng — đỏ đậm trên nền tối vừa thiếu tương phản vừa "rung".
- Nền `-subtle` là sắc **tối cùng họ** (`#3A1714`), không phải nền nhạt sáng như light.
- Nền `-solid` ở dark dùng sắc sáng với chữ tối — đọc tốt hơn chữ trắng trên đỏ đậm trong phòng tối.

**Quy tắc bắt buộc (PROPOSED, thực thi Brand §0 và §8.3):**

1. **Trạng thái luôn có icon + nhãn chữ.** Màu là lớp thứ ba. Bộ icon: ✓ thành công · ⚠ cảnh báo · ✕/⛔ lỗi · ⓘ thông tin (icon cụ thể chọn ở bước component).
2. **Cam không bao giờ là màu trạng thái.**
3. **Danger và nút chính gần cùng độ sáng** (light 1.20:1, dark 1.08:1). Do đó:
   - Hành động nguy hiểm mặc định dùng **nút viền** `border-danger-border text-danger`, không phải nút đặc.
   - Nút đặc `danger-solid` chỉ dùng trong hộp xác nhận, luôn có động từ rõ ("Xoá học sinh", không phải "OK") và icon.
   - Không đặt nút chính cam và nút đặc danger cạnh nhau.
4. **Warning dark (`#F0C04A`) gần trùng `lms-reward` (`#F6C343`, 1.04:1)**. `lms-reward` đã duyệt, nên:
   - `lms-reward` chỉ dùng cho thành tích, **không bao giờ** cho trạng thái.
   - Cảnh báo trong LMS luôn có icon ⚠ và chữ; huy hiệu thành tích luôn có hình huy hiệu/ngôi sao.
5. **Success (`#127436`, 142°) và `lms-progress` (`#0F766E`, 175°)** gần cùng độ sáng (1.07:1). `lms-progress` chỉ cho thanh tiến độ và "hoàn thành bài"; trạng thái "Đã thu", "Có mặt" dùng `success`.

### 2.7 LMS tokens

| Semantic | Tailwind | Light | Dark | Trạng thái |
| --- | --- | --- | --- | --- |
| `--hmt-lms-progress` | `bg-lms-progress` | `#0F766E` | `#5EC4B6` | APPROVED |
| `--hmt-lms-progress-track` | `bg-lms-progress-track` | `#F0ECE8` | `#25201B` | PROPOSED |
| `--hmt-lms-reward` | `bg-lms-reward` | `#F6C343` | `#F6C343` | APPROVED |
| `--hmt-on-lms-reward` | `text-on-lms-reward` | `#211C16` | `#211C16` | APPROVED |

Token LMS định nghĩa toàn cục để dễ build, nhưng **chỉ được dùng trong LMS** (Brand §3.5). Đề xuất thêm lint rule chặn `lms-*` ngoài thư mục LMS. **(PROPOSED)**

---

## 3. Theme

| Khía cạnh | Light | Dark |
| --- | --- | --- |
| Nền | Kem nhạt `#F7F5F2`, thẻ trắng | Xám-nâu `#141110`, thẻ `#1C1814` — không đen tuyền |
| Elevation | Bóng đổ (`shadow-1/2/3`) | Bề mặt sáng dần (`surface` → `raised` → `overlay`) + viền mảnh; bóng chỉ hỗ trợ |
| Nút chính | Cam đậm, chữ trắng | Cam sáng, **chữ tối** |
| Trạng thái | Sắc đậm trên nền trắng | Sắc sáng giảm bão hoà; nền subtle là sắc tối cùng họ |
| Brand | `#EF6926` làm mảng | `#EF6926` giữ nguyên, đọc tốt hơn (6.0:1) |
| Logo | `hmt-logo-cropped.svg` | `hmt-logo-dark-cropped.svg` |
| Focus | Xanh `#1F5FBF` | Xanh nhạt `#8AB8F5` |

`color-scheme` được đặt theo theme để thanh cuộn, date picker gốc… cũng đổi theo.

---

## 4. Typography

### 4.1 So sánh Be Vietnam Pro và Inter

> **OPEN** — Brand Guidelines O1. Phải chốt trước khi build component.

Cách kiểm tra: Inter 4.0 được kiểm tra trực tiếp trên file font (đủ 178/178 chữ cái tiếng Việt có dấu và không dấu, thường + hoa, liệt kê bảng OpenType). Be Vietnam Pro **không tải được** từ môi trường làm việc (mạng chặn), nên thông tin lấy từ trang Fontsource; **cần kiểm tra lại trên file thật** trước khi chốt.

| Tiêu chí | Be Vietnam Pro | Inter 4.0 |
| --- | --- | --- |
| Thiết kế | Lâm Bảo, Tony Le, ViệtAnh Nguyễn — font của người Việt, cho tiếng Việt | Rasmus Andersson — font giao diện đa ngôn ngữ |
| Giấy phép | OFL 1.1 | OFL 1.1 (đã xác nhận trong file) |
| Tiếng Việt | Thiết kế riêng cho tiếng Việt; dấu chồng cân đối | Đủ toàn bộ ký tự tiếng Việt (đã kiểm tra) |
| Kiểu file | **Tĩnh**, 9 độ đậm × 2 (thường, nghiêng), mỗi độ đậm một file | Có bản **variable** (một file cho mọi độ đậm) |
| Số đều chiều rộng `tnum` | **Không có** trong danh sách tính năng của Fontsource (Fontsource ghi "có thể khác giữa các file") | **Có** `tnum`, thêm `zero` (số 0 gạch), `frac`, `case` |
| Tính năng khác | `case`, `frac`, `liga`, `ss01`, `sups/subs` | `cv01–cv13`, `ss01–ss08` (gồm biến thể phân biệt I/l/1), `calt` |
| Độ rộng | Rộng hơn → bảng CRM chứa ít ký tự hơn | Gọn, tối ưu cho UI dày đặc |
| Cá tính | Ấm, mềm, có bản sắc Việt — hợp LMS, tiêu đề | Trung tính, rõ ràng — hợp dữ liệu |

**Phát hiện quan trọng:** CRM cần số đều chiều rộng cho cột tiền, điểm, ngày. Nếu Be Vietnam Pro thật sự không có `tnum`, dùng riêng nó cho CRM sẽ làm các cột số không thẳng hàng.

**Các phương án:**

| | Phương án | Nhận xét |
| --- | --- | --- |
| A | Be Vietnam Pro cho tất cả | Bản sắc mạnh nhất; rủi ro cột số CRM; nhiều file tĩnh |
| B | Inter cho tất cả | An toàn kỹ thuật nhất; ít bản sắc |
| **C (đề xuất)** | **Inter cho giao diện và số liệu (`font-sans`), Be Vietnam Pro cho tiêu đề và display (`font-display`)** | Bảng số CRM chuẩn; tiêu đề, banner LMS vẫn mang chất Việt và ấm áp; cả hai OFL |

File token đã viết theo phương án C nhưng chỉ cần đổi 2 biến `--hmt-font-sans` / `--hmt-font-display` để chuyển sang A hoặc B.

**Việc cần làm trước khi chốt (OPEN):** tải Be Vietnam Pro từ Google Fonts, kiểm tra `tnum` bằng `font-feature-settings: "tnum"` trên chuỗi `1.111.111 ₫ / 8.888.888 ₫`, và đặt hai font cạnh nhau với bảng công nợ mẫu.

**Tải font:** tự host bằng `@fontsource-variable/inter` và `@fontsource/be-vietnam-pro` (chỉ các độ đậm dùng: 600, 700), subset `vietnamese` + `latin`. **(PROPOSED)**

### 4.2 Typography scale

APPROVED (Brand §5.3). Ánh xạ Tailwind:

| Cấp | Tailwind | Cỡ / dòng | Đậm | Font | Dùng cho |
| --- | --- | --- | --- | --- | --- |
| Display | `text-display font-display` | 32 / 40 | 700 | display | Màn chào, banner LMS |
| H1 | `text-h1 font-display` | 24 / 32 | 700 | display | Tiêu đề trang |
| H2 | `text-h2 font-display` | 20 / 28 | 600 | display | Tiêu đề khu vực |
| H3 | `text-h3` | 16 / 24 | 600 | sans | Tiêu đề thẻ, nhóm form |
| Body | `text-body` | **theo sản phẩm** | 400 | sans | Nội dung chính |
| Body sm | `text-body-sm` | 14 / 20 | 400 | sans | Body CRM |
| Body lg | `text-body-lg` | 16 / 24 | 400 | sans | Body Teacher, LMS |
| Label | `text-label` | 13 / 18 | 500 | sans | Nhãn form, tiêu đề cột |
| Caption | `text-caption` | 12 / 16 | 400 | sans | Metadata, ghi chú |

`text-body` tự đổi theo `data-product`: CRM 14px, Teacher Portal 16px, LMS 16px. **(PROPOSED)** Teacher Portal và LMS dùng 16px cho input để iOS Safari không tự phóng to khi chạm vào ô nhập.

**Quy tắc (APPROVED — Brand §5.4):** tối đa 3 cấp chữ trong một thẻ; line-height ≥ 1.4 cho body; không justify; số tiền `1.250.000 ₫`. **(PROPOSED)** Mọi cột số dùng utility `tabular`.

---

## 5. Spacing, radius, elevation, z-index

### 5.1 Spacing — bước 4px (PROPOSED)

Tailwind v4 nhân `--spacing: 0.25rem`: `p-1` = 4px, `p-4` = 16px…

| Token | px | Dùng điển hình |
| --- | --- | --- |
| `space-0_5` | 2 | Khe icon–chữ rất chặt |
| `space-1` | 4 | Icon–chữ trong badge |
| `space-2` | 8 | Giữa các nút, khoảng tối thiểu giữa hai vùng chạm |
| `space-3` | 12 | Padding ô bảng CRM, gap form CRM |
| `space-4` | 16 | Padding thẻ CRM/Teacher, gap LMS |
| `space-6` | 24 | Padding thẻ LMS, giữa các khu vực |
| `space-8` | 32 | Giữa các khối lớn |
| `space-12`, `space-16` | 48, 64 | Khoảng trắng màn chào, banner |

Token theo sản phẩm (đọc từ `data-product`):

| Tailwind | CRM | Teacher | LMS |
| --- | --- | --- | --- |
| `h-control` | 36px | 48px | 44px |
| `h-row` | 40px | 56px | 56px |
| `gap-gap` | 12px | 8px | 16px |
| `p-card` | 16px | 16px | 24px |
| `rounded-card` | 8px | 12px | 12px |
| `min-h-target` / `touch-target` | 44px | 44px | 44px |

### 5.2 Radius (PROPOSED)

| Token | px | Dùng cho |
| --- | --- | --- |
| `rounded-xs` | 2 | Checkbox |
| `rounded-sm` | 4 | Badge, tag |
| `rounded-md` | 6 | Nút, input, select |
| `rounded-lg` | 8 | Thẻ CRM, dropdown |
| `rounded-xl` | 12 | Thẻ LMS/Teacher, modal |
| `rounded-2xl` | 16 | Banner LMS, bottom sheet |
| `rounded-full` | — | Avatar, chip lọc, thanh tiến độ |

### 5.3 Elevation (PROPOSED)

| Cấp | Tailwind | Bề mặt | Dùng cho |
| --- | --- | --- | --- |
| 0 | — | `canvas`/`surface` | Trang, thẻ phẳng có viền |
| 1 | `shadow-1` | `surface` | Thẻ nổi nhẹ (LMS) |
| 2 | `shadow-2` | `surface-raised` | Dropdown, popover, toast |
| 3 | `shadow-3` | `surface-overlay` | Modal, drawer, bottom sheet |

CRM ưu tiên **viền thay vì bóng** cho thẻ và bảng (đỡ rối khi nhiều khối). LMS được dùng `shadow-1` cho thẻ bài học.

### 5.4 Z-index (PROPOSED)

`sticky 10 · dropdown 30 · overlay 40 · modal 50 · toast 60 · tooltip 70`

---

## 6. Breakpoints & layout

### 6.1 Breakpoints (PROPOSED)

Giữ mặc định Tailwind, thêm `3xl`.

| Tên | Từ | Thiết bị điển hình |
| --- | --- | --- |
| (gốc) | 0 | Điện thoại 360–430px |
| `sm` | 640px | Điện thoại ngang |
| `md` | 768px | Máy tính bảng dọc |
| `lg` | 1024px | Máy tính bảng ngang, laptop nhỏ |
| `xl` | 1280px | Laptop |
| `2xl` | 1536px | Desktop |
| `3xl` | 1920px | Màn rộng (quầy vận hành) |

### 6.2 Nguyên tắc layout theo sản phẩm (PROPOSED)

| | CRM | Teacher Portal | LMS |
| --- | --- | --- | --- |
| Hướng thiết kế | Desktop-first | **Mobile-first** | Mobile-first, đẹp trên desktop |
| Kích thước chính | 1280–1920px | 360–430px | 360px → 1280px |
| Tối thiểu hỗ trợ | 1024px; dưới đó chỉ xem | 320px | 320px |
| Khung | Sidebar trái thu gọn được + vùng nội dung tràn | Thanh tác vụ dưới (bottom bar), 1 cột | 1 cột trên mobile; 2–3 cột thẻ trên desktop, rộng tối đa ~1200px |
| Bảng | Bảng đầy đủ, cột cố định, header dính | Không dùng bảng; dùng danh sách thẻ | Hạn chế bảng; bảng điểm cho phụ huynh dạng thẻ trên mobile |
| Vị trí hành động chính | Góc trên phải vùng nội dung | Nút dính đáy màn, trong tầm ngón cái | Cuối thẻ hoặc dính đáy trên mobile |

Phóng to chữ 200% không được làm mất nội dung hay chức năng; nội dung phải chảy lại ở chiều rộng 320px (trừ bảng CRM, được cuộn ngang). **(PROPOSED — WCAG 1.4.4, 1.4.10)**

---

## 7. Motion & trạng thái tương tác

### 7.1 Motion (PROPOSED)

| Token | Thời gian | Dùng cho |
| --- | --- | --- |
| `duration-instant` | 80ms | Đổi màu hover |
| `duration-fast` | 150ms | Nút, checkbox, toggle |
| `duration-base` | 220ms | Dropdown, tooltip, accordion |
| `duration-slow` | 320ms | Modal, drawer, toast |
| `ease-standard` | `cubic-bezier(.2,0,0,1)` | Mặc định |
| `ease-enter` / `ease-exit` | — | Xuất hiện / biến mất |

- `prefers-reduced-motion: reduce` → mọi duration = 0 (đã có trong file token).
- CRM: chuyển động tối thiểu, không trì hoãn thao tác.
- LMS: được có hiệu ứng ghi nhận thành tích ngắn (≤ 600ms), không nhấp nháy quá 3 lần/giây (WCAG 2.3.1).

### 7.2 Trạng thái tương tác

| Trạng thái | Nút chính | Phần tử trung tính (hàng, menu) | Bắt buộc ngoài màu |
| --- | --- | --- | --- |
| Mặc định | `bg-action text-on-action` | `bg-surface` | — |
| Hover | `bg-action-hover` | `bg-hover-overlay` | Con trỏ tay |
| Pressed | `bg-action-pressed` | `bg-pressed-overlay` | — |
| Focus | `focus-ring` | `focus-ring` | Vòng 2px |
| Selected | — | `bg-selected text-on-selected` | `aria-selected`/`aria-current` + dấu ✓ hoặc vạch trái đậm hơn |
| Disabled | `bg-disabled text-on-disabled` | `text-on-disabled` | `disabled`/`aria-disabled`, không hover |
| Loading | Giữ màu, thêm spinner + chữ "Đang lưu…" | — | `aria-busy="true"`, chặn bấm lặp |
| Lỗi (input) | — | `border-danger-border` | Icon ✕ + thông báo chữ dưới ô, `aria-invalid` |

---

## 8. Phân biệt ba sản phẩm

Ba sản phẩm **dùng chung toàn bộ token màu, font, radius, motion**. Khác nhau ở **mật độ, bố cục và mức biểu cảm**.

### 8.1 CRM — rõ ràng, đọc dữ liệu, mật độ, tốc độ

| Quy định | Chi tiết |
| --- | --- |
| Mật độ | Body 14px, control 36px, hàng bảng 40px |
| Cam | Chỉ nút chính (1/vùng), link, hàng đang chọn |
| Số liệu | `tabular`, canh phải, `text-fg` — không tô màu số tiền |
| Trạng thái trong bảng | Badge nhạt (`-subtle` + `on-…-subtle`) có icon + chữ |
| Tốc độ | Phím tắt cho thao tác lặp; giữ vị trí cuộn và bộ lọc khi quay lại |
| Vùng chạm | Control 36px trên desktop là chấp nhận được (WCAG 2.5.8 yêu cầu 24px); trên máy tính bảng dùng `touch-target` |
| Không dùng | `lms-progress`, `lms-reward`, minh hoạ, `shadow` cho thẻ |

### 8.2 Teacher Portal — mobile-first, nhanh, chống nhầm khi điểm danh

| Quy định | Chi tiết |
| --- | --- |
| Mật độ | Body 16px, control 48px, hàng 56px |
| Vùng chạm | Mọi phần tử bấm ≥ 44×44px; khoảng cách ≥ 8px giữa hai vùng chạm kề nhau |
| Điểm danh | Mỗi học sinh một hàng; 3 lựa chọn **Có mặt / Vắng có phép / Vắng không phép** dạng nút phân đoạn, mỗi nút có **icon + chữ**, không chỉ màu |
| Chống nhầm | Không dùng thao tác vuốt để đổi trạng thái; tên và ảnh học sinh luôn hiển thị cạnh lựa chọn; nút "Lưu điểm danh" dính đáy, hiển thị tóm tắt ("28 có mặt · 2 vắng"); sau khi lưu có **hoàn tác** trong vài giây thay cho hộp xác nhận |
| Mặc định | **OPEN:** điểm danh mặc định "Có mặt" cho cả lớp hay để trống? (nhanh hơn vs. an toàn hơn) |
| Không dùng | Bảng nhiều cột, `lms-*` |

### 8.3 LMS — thân thiện với học sinh và phụ huynh

| Quy định | Chi tiết |
| --- | --- |
| Mật độ | Body 16px, control 44px, thẻ padding 24px, bo 12px |
| Biểu cảm | Được dùng mảng `brand`, `lms-progress`, `lms-reward`, minh hoạ hình học, `shadow-1` |
| Hai đối tượng | Màn học sinh: ngôn ngữ khích lệ, ít chữ. Màn phụ huynh: thông tin rõ (điểm, chuyên cần, học phí), giọng trang trọng hơn — cùng token |
| Nhiều độ tuổi | Không đổi token theo tuổi; khác biệt nằm ở nội dung và minh hoạ. **OPEN:** cỡ chữ lớn hơn cho lớp 2–5 (Brand O4) |
| Không dùng | Nhân vật hoạt hình, gradient, `lms-reward` cho cảnh báo |

---

## 9. Accessibility checklist (WCAG 2.2 AA)

| Tiêu chí | Cách đáp ứng trong hệ thống | Trạng thái |
| --- | --- | --- |
| 1.4.3 Tương phản chữ | Mọi cặp chữ/nền semantic ≥ 4.5:1 ở cả hai theme (bảng §2) | PROPOSED (đã đo) |
| 1.4.11 Tương phản phi văn bản | `border-strong`, `-border` trạng thái, focus ≥ 3:1 | PROPOSED (đã đo) |
| 1.4.1 Không chỉ dùng màu | Trạng thái = icon + chữ; selected có `aria-*` + dấu hiệu hình | APPROVED (nguyên tắc) |
| 2.4.7 / 2.4.11 Focus nhìn thấy, không bị che | `focus-ring` trên mọi phần tử tương tác; header/bottom bar dính không che phần tử đang focus (`scroll-padding`) | PROPOSED |
| 2.5.8 Kích thước vùng chạm | Tối thiểu 24px (AA); HMT dùng 44px cho Teacher Portal, LMS, icon button | PROPOSED |
| 1.4.4 / 1.4.10 Phóng to, reflow | Không khoá cỡ chữ gốc; layout chảy lại ở 320px | PROPOSED |
| 2.3.3 / reduced motion | Tắt chuyển động khi người dùng yêu cầu | PROPOSED |
| 3.3.1 Báo lỗi | Lỗi có chữ mô tả, icon, `aria-invalid`, `aria-describedby` | PROPOSED |
| Ngôn ngữ | `<html lang="vi">` để trình đọc màn hình đọc đúng tiếng Việt | PROPOSED |

---

## 10. Ví dụ sử dụng token

> Minh hoạ cách dùng token, **không phải** component chính thức.

### 10.1 Nút

```tsx
// Nút chính — một nút/vùng
<button className="h-control px-4 rounded-md bg-action text-on-action font-medium
  hover:bg-action-hover active:bg-action-pressed focus-ring
  disabled:bg-disabled disabled:text-on-disabled disabled:cursor-not-allowed
  transition-colors duration-150 ease-standard">
  Tạo phiếu thu
</button>

// Nút viền — hành động phụ
<button className="h-control px-4 rounded-md bg-surface text-fg border border-border-strong
  hover:bg-hover-overlay focus-ring">
  Xuất Excel
</button>

// Hành động nguy hiểm — mặc định dạng viền, có icon + động từ rõ
<button className="h-control px-4 rounded-md bg-surface text-danger border border-danger-border
  hover:bg-danger-subtle focus-ring">
  <XIcon aria-hidden /> Huỷ phiếu thu
</button>
```

### 10.2 Badge trạng thái (icon + chữ, không chỉ màu)

```tsx
const STATUS = {
  success: { cls: "bg-success-subtle text-on-success-subtle", icon: CheckIcon },
  warning: { cls: "bg-warning-subtle text-on-warning-subtle", icon: AlertTriangleIcon },
  danger:  { cls: "bg-danger-subtle  text-on-danger-subtle",  icon: XCircleIcon },
  info:    { cls: "bg-info-subtle    text-on-info-subtle",    icon: InfoIcon },
} as const;

function StatusBadge({ tone, children }: { tone: keyof typeof STATUS; children: React.ReactNode }) {
  const { cls, icon: Icon } = STATUS[tone];
  return (
    <span className={`inline-flex items-center gap-1 rounded-sm px-2 py-0.5 text-label ${cls}`}>
      <Icon aria-hidden className="size-3.5" /> {children}
    </span>
  );
}

<StatusBadge tone="danger">Quá hạn</StatusBadge>
```

### 10.3 Hàng bảng CRM

```tsx
<tr aria-selected={selected}
    className="h-row border-t border-border hover:bg-hover-overlay
               aria-selected:bg-selected aria-selected:text-on-selected">
  <td className="px-3">Trần Bình</td>
  <td className="px-3">9B1</td>
  <td className="px-3 text-right tabular">1.250.000 ₫</td>
  <td className="px-3"><StatusBadge tone="warning">Sắp hạn</StatusBadge></td>
</tr>
```

### 10.4 Lựa chọn điểm danh — Teacher Portal

```tsx
<fieldset className="flex gap-2">
  <legend className="sr-only">Điểm danh Nguyễn An</legend>
  {[
    { v: "present", label: "Có mặt",   Icon: CheckIcon },
    { v: "excused", label: "Có phép",  Icon: FileTextIcon },
    { v: "absent",  label: "Vắng",     Icon: XIcon },
  ].map(({ v, label, Icon }) => (
    <label key={v}
      className="touch-target flex-1 inline-flex items-center justify-center gap-1 rounded-md
                 border border-border-strong bg-surface text-fg text-body
                 has-checked:bg-selected has-checked:text-on-selected has-checked:border-action
                 has-focus-visible:ring-2 has-focus-visible:ring-focus">
      <input type="radio" name="att-an" value={v} className="sr-only" />
      <Icon aria-hidden className="size-5" /> {label}
    </label>
  ))}
</fieldset>
```

Lựa chọn đang chọn được nhận ra bằng **nền + viền + chữ đậm hơn + icon**, không chỉ màu. Màu riêng cho từng lựa chọn (xanh/đỏ) là **OPEN**: thêm màu giúp quét nhanh nhưng dễ bị hiểu là "đúng/sai".

### 10.5 Thẻ bài học LMS

```tsx
<article className="rounded-card bg-surface shadow-1 overflow-hidden">
  <div className="bg-brand px-card py-3 flex items-center gap-2">
    <span className="inline-flex items-center gap-1 rounded-full bg-lms-reward text-on-lms-reward px-2 py-0.5 text-label">
      <StarIcon aria-hidden className="size-4" /> Chuỗi 5 ngày
    </span>
  </div>
  <div className="p-card space-y-2">
    <h3 className="text-h3 text-fg">Phân số — Bài 12</h3>
    <p className="text-caption text-fg-muted">Lớp 4C3 · Cô Hương</p>
    <div role="progressbar" aria-valuenow={68} aria-valuemin={0} aria-valuemax={100}
         aria-label="Tiến độ bài học" className="h-2 rounded-full bg-lms-progress-track">
      <div className="h-full rounded-full bg-lms-progress" style={{ width: "68%" }} />
    </div>
    <div className="flex justify-between text-body-sm">
      <span className="text-fg-muted">68% hoàn thành</span>
      <a className="text-link font-medium focus-ring rounded-sm" href="#">Tiếp tục →</a>
    </div>
  </div>
</article>
```

### 10.6 Đổi theme và sản phẩm

```tsx
// Đặt một lần ở gốc app
document.documentElement.dataset.product = "teacher";
const prefersDark = matchMedia("(prefers-color-scheme: dark)").matches;
document.documentElement.dataset.theme = userSetting ?? (prefersDark ? "dark" : "light");
```

```tsx
// Logo theo theme
<img src={theme === "dark" ? logoDarkCropped : logoCropped} alt="Hòa Ma Toán" className="h-24" />
```

---

## 11. Kiểm tra nhất quán với Brand Guidelines

| Quy định Brand | Trong Design System | Kết quả |
| --- | --- | --- |
| §3.1 Bảng màu Hướng A, light + dark | Giá trị giữ nguyên trong primitive; chỉ thêm pressed, overlay | ✅ Khớp |
| §3.2 Cam logo không làm chữ nhỏ trên nền sáng | `brand` chỉ có utility nền; `text-brand` không tồn tại | ✅ Khớp |
| §3.3 Một nút cam mỗi vùng; không tô cam số liệu | Quy định §8.1; ví dụ §10 | ✅ Khớp |
| §3.4 Secondary không làm nút chính; info do UI DS quyết | Info dùng xanh `#1F5FBF` riêng, khác secondary `#2E4A66` | ✅ Khớp |
| §3.5 Lớp ấm chỉ trong LMS | Token toàn cục + quy định + đề xuất lint | ✅ Khớp (cần lint để thực thi) |
| §3.6 Không tạo sắc cam mới | Thêm 2 sắc: pressed `#7A2E0E` / `#FBC4A1` | ⚠️ **Cần duyệt** — là sắc tối/sáng hơn của cam hành động cho trạng thái nhấn, không dùng độc lập |
| §4 Không đen tuyền ở dark; viền control dùng `border-strong` | `canvas` dark `#141110`; input dùng `border-strong` | ✅ Khớp |
| §5 Font | Phương án C (Inter + Be Vietnam Pro) | ⚠️ Brand O1 vẫn mở; Brand §5.2 nghiêng về Be Vietnam Pro — phát hiện về `tnum` là lý do đề xuất C |
| §6 Mật độ, lượng cam, minh hoạ theo sản phẩm | `data-product` + §8 | ✅ Khớp |
| §7.3 Logo theo nền, cỡ ≥ 96px | Ví dụ §10.6 dùng `h-24` (96px) | ✅ Khớp |
| §8 WCAG 2.2 AA, không chỉ dùng màu | §2, §9 | ✅ Khớp |
| §0 Trạng thái, disabled, focus định nghĩa riêng | §2.4–2.6 xác định độc lập, có kiểm tra tương phản | ✅ Khớp |
| §0 Cam không làm màu trạng thái | Quy định §2.6 | ✅ Khớp |

---

## 12. Bảng ánh xạ token đầy đủ

| Tailwind | CSS variable | Nhóm | Vai trò |
| --- | --- | --- | --- |
| `bg-brand` | `--hmt-brand` | Brand | Mảng nhận diện |
| `text-on-brand` | `--hmt-on-brand` | Brand | Chữ trên brand |
| `bg-canvas` | `--hmt-canvas` | Background | Nền trang |
| `bg-surface` | `--hmt-surface` | Surface | Thẻ, bảng, form |
| `bg-surface-subtle` | `--hmt-surface-subtle` | Surface | Header bảng, sidebar |
| `bg-surface-raised` | `--hmt-surface-raised` | Surface | Dropdown, popover |
| `bg-surface-overlay` | `--hmt-surface-overlay` | Surface | Modal, drawer |
| `bg-scrim` | `--hmt-scrim` | Surface | Phủ sau modal |
| `text-fg` | `--hmt-fg` | Text | Chữ chính |
| `text-fg-muted` | `--hmt-fg-muted` | Text | Chữ phụ |
| `text-fg-inverse` | `--hmt-fg-inverse` | Text | Chữ trên nền đảo |
| `border-border` | `--hmt-border` | Border | Trang trí |
| `border-border-strong` | `--hmt-border-strong` | Border | Control |
| `bg-action` | `--hmt-action` | Interactive | Nút chính |
| `bg-action-hover` | `--hmt-action-hover` | Interactive | Hover |
| `bg-action-pressed` | `--hmt-action-pressed` | Interactive | Nhấn |
| `text-on-action` | `--hmt-on-action` | Interactive | Chữ trên nút chính |
| `text-link` | `--hmt-link` | Interactive | Link |
| `bg-selected` | `--hmt-selected` | Interactive | Đang chọn |
| `text-on-selected` | `--hmt-on-selected` | Interactive | Chữ trên đang chọn |
| `text-secondary` | `--hmt-secondary` | Interactive | Link phụ |
| `bg-secondary-subtle` | `--hmt-secondary-subtle` | Interactive | Nền phụ |
| `bg-hover-overlay` | `--hmt-hover-overlay` | Interactive | Hover trung tính |
| `bg-pressed-overlay` | `--hmt-pressed-overlay` | Interactive | Nhấn trung tính |
| `focus-ring`, `ring-focus` | `--hmt-focus` | Focus | Vòng focus |
| `bg-disabled` | `--hmt-disabled-bg` | Disabled | Nền |
| `text-on-disabled` | `--hmt-disabled-fg` | Disabled | Chữ |
| `border-disabled-border` | `--hmt-disabled-border` | Disabled | Viền |
| `text-{status}` | `--hmt-{status}` | Status | Chữ/icon trạng thái |
| `bg-{status}-subtle` | `--hmt-{status}-subtle` | Status | Nền nhạt |
| `text-on-{status}-subtle` | `--hmt-on-{status}-subtle` | Status | Chữ trên nền nhạt |
| `border-{status}-border` | `--hmt-{status}-border` | Status | Viền mang nghĩa |
| `bg-{status}-solid` | `--hmt-{status}-solid` | Status | Nền đặc |
| `text-on-{status}-solid` | `--hmt-on-{status}-solid` | Status | Chữ trên nền đặc |
| `bg-lms-progress` | `--hmt-lms-progress` | LMS | Tiến độ |
| `bg-lms-progress-track` | `--hmt-lms-progress-track` | LMS | Rãnh tiến độ |
| `bg-lms-reward` | `--hmt-lms-reward` | LMS | Thành tích |
| `text-on-lms-reward` | `--hmt-on-lms-reward` | LMS | Chữ trên thành tích |
| `font-sans` / `font-display` | `--hmt-font-*` | Type | Font giao diện / tiêu đề |
| `text-display … text-caption` | `--hmt-text-*` | Type | Cấp bậc chữ |
| `text-body` | `--hmt-density-text` | Type | Body theo sản phẩm |
| `p-1 … p-16` | `--spacing` | Spacing | Bước 4px |
| `h-control`, `h-row`, `p-card`, `gap-gap` | `--hmt-density-*` | Density | Theo sản phẩm |
| `min-h-target`, `touch-target` | `--hmt-target-min` | Density | Vùng chạm 44px |
| `rounded-xs … rounded-full`, `rounded-card` | `--hmt-radius-*` | Radius | Bo góc |
| `shadow-1/2/3` | `--hmt-shadow-*` | Elevation | Độ nổi |
| `ease-standard/enter/exit` | `--hmt-ease-*` | Motion | Đường cong |
| `tabular` | — | Utility | Số đều chiều rộng |

`{status}` = `success` · `warning` · `danger` · `info`.

---

## 13. Quyết định chưa được duyệt

### PROPOSED trong P3

| # | Đề xuất | Mục |
| --- | --- | --- |
| D1 | Kiến trúc 3 tầng token; tiền tố `--hmt-`; xoá bảng màu mặc định Tailwind | §1 |
| D2 | `data-theme` + `data-product` trên `<html>` | §1.2 |
| D3 | Màu trạng thái success/warning/danger/info (light + dark) và cấu trúc 6 token | §2.6 |
| D4 | Hành động nguy hiểm mặc định dạng viền; nút đặc danger chỉ trong hộp xác nhận | §2.6 |
| D5 | Focus xanh `#1F5FBF`/`#8AB8F5`, vòng 2px cách 2px | §2.4 |
| D6 | Token disabled; cấm dùng `opacity` cho disabled | §2.5 |
| D7 | Thêm sắc cam pressed `#7A2E0E`/`#FBC4A1` (ngoại lệ Brand §3.6) | §2.3 |
| D8 | Overlay hover/pressed; `surface-raised`/`overlay` dark; `scrim` | §2.2–2.3 |
| D9 | `text-body` theo sản phẩm (14/16/16) | §4.2 |
| D10 | Spacing 4px, radius, elevation, z-index | §5 |
| D11 | Mật độ theo sản phẩm (control 36/48/44, hàng 40/56/56…) | §5.1 |
| D12 | Breakpoints + nguyên tắc layout theo sản phẩm | §6 |
| D13 | Motion tokens | §7 |
| D14 | Quy tắc riêng cho CRM, Teacher Portal, LMS | §8 |
| D15 | Lint chặn `lms-*` ngoài LMS | §2.7 |
| D16 | Tự host font bằng Fontsource | §4.1 |

### OPEN

| # | Vấn đề | Ghi chú |
| --- | --- | --- |
| O1 | **Font:** phương án A / B / **C (đề xuất)** | Cần kiểm tra `tnum` của Be Vietnam Pro trên file thật |
| O2 | Điểm danh mặc định "Có mặt" hay để trống | Tốc độ vs. an toàn |
| O3 | Màu riêng cho từng lựa chọn điểm danh | Quét nhanh vs. hiểu nhầm đúng/sai |
| O4 | Cỡ chữ lớn hơn cho lớp 2–5 trong LMS | Kế thừa Brand O4; cần kiểm thử |
| O5 | Bảng màu phân loại: biểu đồ, 5 cơ sở, môn học | Kế thừa Brand U5; làm cùng chuẩn biểu đồ |
| O6 | Bộ icon (Lucide, Phosphor…) | Cần cho quy tắc icon + chữ |
| O7 | Dark mode cho cả 3 sản phẩm ngay từ đầu, hay CRM trước | Chi phí kiểm thử gấp đôi |
| O8 | Logo rút gọn cho header | Kế thừa Brand O2 (hoãn) |
