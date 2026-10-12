# HMT Platform

Design System dùng chung cho **CRM**, **Teacher Portal** và **LMS** của Hòa Ma Toán (5 cơ sở tại Hà Nội). Một ngôn ngữ thiết kế, ba mức mật độ.

| Giai đoạn | Tài liệu | Trạng thái |
| --- | --- | --- |
| P1 · Brand Color Discovery | mục *P1 — Brand Color Discovery* | Hoàn tất — chọn Hướng A · Cam vận hành |
| P2 · Brand Guidelines | mục *HMT Brand Guidelines* | **Đã duyệt** (các mục OPEN vẫn mở) |
| P3 · UI Design System Foundation | mục *HMT Design System Spec* + `HMT_DESIGN_TOKENS.css` | **Đã duyệt** (các mục OPEN vẫn mở) |
| P4 · Core Components | mục *HMT Component Spec* + 27 thẻ component tương tác | **Đã duyệt** (các mục OPEN vẫn mở) |
| P5 · đợt 5.0 · Thành phần CRM bổ sung | Spec §11 + 21 thẻ mới, sửa P4 theo luật; sửa theo góp ý 11/10 (§11.9) | **Chờ duyệt** |
| P5 · đợt 5.1 · phần 1 · Điều hướng | Thẻ NavMap, RoleMenu, FlowMap + `HMT_DIEU_HUONG_5.1.md` | **Chờ duyệt** |
| P5 · đợt 5.1 · phần 2 · Khuôn K01–K13 | 13 thẻ (nhóm "Khuôn 5.1") · Spec §16 | **Chờ duyệt** |
| P5 · đợt 5.3 · phần 1 · Tuyển sinh, Khách hàng | 18 thẻ màn (nhóm "Màn 5.3") · Spec §14 | **Chờ duyệt** |
| P5 · đợt 5.3 · phần 2 · Bán hàng, Thu chi, Cấu hình bán hàng | 22 thẻ màn (nhóm "Màn 5.3 · Bán hàng", "Màn 5.3 · Thu chi", "Màn 5.3 · Cấu hình bán hàng") · Spec §15 | **Chờ duyệt** |
| P5 · đợt 5.4 · phần 1 · Ghi danh, Lớp học, Cấu hình đào tạo | 21 thẻ màn (nhóm "Màn 5.4 · …") · Spec §17 | **Chờ duyệt** |
| P5 · đợt 5.4 · phần 2 · Buổi học | 13 thẻ màn (nhóm "Màn 5.4 · Buổi học") · Spec §18 | **Chờ duyệt** |
| P5 · đợt 5.4 · phần 3 · Chăm sóc khách hàng, Tái tục | 17 thẻ màn (nhóm "Màn 5.4 · Chăm sóc khách hàng", "· Tái tục", "· Quản trị", "· Thu chi") · Spec §19 | **Chờ duyệt** |
| P5 · áp dụng câu trả lời 12/10 (A-22…A-37) · danh mục, tham số | Sửa ~40 thẻ màn + menu Admin · Spec §20 · nguồn `HMT_DANH_MUC_VA_THAM_SO.md` | **Chờ duyệt** |
| P5 · đợt 5.7 · Báo cáo | BC-01 (mức A, đối chiếu prompt 12/10: thêm Đang bảo lưu, Quỹ giờ còn) + thẻ LineChart; BC-02…07, BC-10 làm trên Looker · Spec §21 | **Chờ duyệt** |
| P5 · đợt 5.5 · phần 1 · Khung cổng Giáo viên, khuôn K14 | GV-01, K14 + thẻ QuickGrid · Spec §23 | **Chờ duyệt** |
| P5 · đợt 5.5 · phần 2 · Các màn cổng Giáo viên | 13 thẻ màn GV (nhóm "Màn 5.5 · Cổng giáo viên") + đối chiếu CH-07, CS-16, BC-08, BC-09 · Spec §24 | **Chờ duyệt** |
| P5 · đợt 5.6 · Học tập + Phụ huynh (+ sửa A-47…A-53: BTVN 1–5, khung phụ huynh, PH-05) | 17 thẻ màn (nhóm "Màn 5.6 · Học tập", "· Phụ huynh", "· Cổng giáo viên") + thẻ StudentShell, PhotoPages, SubmissionViewer · Spec §26, §27 | **Chờ duyệt** |
| P5 · đợt 5.2 · Chung + Quản trị | 24 thẻ màn (nhóm "Màn 5.2") + khuôn AppShell, AuthLayout, StatTile… (Spec §13) | **Chờ duyệt** |

| P5 · Manifest tổng | `HMT_MANIFEST_P5.md`: 147 màn A + B đã vẽ, 43 màn C liệt kê, 7 màn Looker | **Chờ duyệt** |
| P6 · Kiểm tra (QA) | `HMT_QA_P6.md`: 25 dòng lỗi + 1 dòng phát hiện khi kiểm lại; 24 đã sửa, 2 bỏ theo ý anh; kiểm lại 147/147 đạt · Spec §28 | **Chờ duyệt** |

> Từ P5: **luật nghiệp vụ > bản đồ màn hình > Design System > ý tưởng riêng**. Các quyết định chốt theo luật §8 và thay đổi P4 do luật: xem *HMT Decision Log*.

## Bắt đầu nhanh

```css
@import "tailwindcss";
@import "./HMT_DESIGN_TOKENS.css";
```

```html
<html lang="vi" data-theme="light" data-product="crm">
```

- `data-theme`: `light` · `dark` — đổi toàn bộ màu semantic. **Hiện chỉ làm giao diện sáng** (O-13); token tối giữ để dùng sau.
- `data-product`: `crm` · `teacher` · `lms` — đổi mật độ (cỡ body, chiều cao control và hàng, padding thẻ).
- Component chỉ dùng token semantic `hmt-*` (Tailwind: `bg-action`, `text-fg-muted`, `bg-danger-subtle`…). Bảng màu mặc định của Tailwind bị tắt.

## Nguyên tắc nền

1. **Cam có kỷ luật.** `hmt-brand` (#EF6926, màu logo) là mảng nhận diện; `hmt-action` (#B54515 / #F28A52) là màu bấm. Một nút cam mỗi vùng. Cam không bao giờ là màu trạng thái.
2. **Neutral ấm là nền móng.** `hmt-canvas`, `hmt-surface`, `hmt-fg` chiếm phần lớn diện tích; dark mode xám-nâu, không đen tuyền.
3. **Không chỉ dùng màu.** Mọi trạng thái có icon + chữ; đang chọn có `aria-*` + dấu hiệu hình.
4. **Tương phản WCAG 2.2 AA** — 106 cặp chữ/nền P3 đã đo ở cả hai theme; thành phần đợt 5.0 đo ở giao diện sáng.
5. **Focus xanh** `hmt-focus`, vòng 2px cách phần tử 2px.
6. **Lớp ấm chỉ trong LMS:** `hmt-lms-progress`, `hmt-lms-reward`.
7. **Màu phân loại** `hmt-cat-1..4` (đề xuất, đợt 5.0) chỉ cho loại buổi và biểu đồ — không dùng cho trạng thái, luôn kèm chữ.

## Mật độ theo sản phẩm

| | CRM | Teacher Portal | LMS |
| --- | --- | --- | --- |
| Body | 14px | 16px | 16px |
| Control | 36px | 48px | 44px |
| Hàng | 40px | 56px | 56px |
| Gap | 12px | 8px | 16px |
| Padding thẻ | 16px | 16px | 24px |
| Bo thẻ | 8px | 12px | 12px |
| Thiết kế | Desktop-first | Điện thoại trước + bản máy tính | Mobile-first |

Teacher Portal trên máy tính: đặt thêm `data-device="desktop"` (≥ 1024px) → nút/ô 40px, hàng 48px, chữ vẫn 16px (đề xuất P-12). AttendanceSheet, TaskStepper, HomeworkStatus tự đổi bố cục theo độ rộng khung.

## Component

48 component (27 P4 + 21 đợt 5.0) + 7 khuôn đợt 5.2 (AppShell, AuthLayout, PageHeader, StatTile, TurnstileSlot, OtpInput, PasswordInput) chạy thật trong trang Components (React 18, `window.HMT`); API ở `components/index.d.ts`, quy định đầy đủ ở mục *HMT Component Spec*.

- Dùng một component có cấu hình thay vì tạo bản sao: `Button variant`, `Field` bọc mọi ô nhập, `StateView kind`, `Drawer placement`, `ConfirmDialog` = `Dialog` cấu hình sẵn, điểm danh = `SegmentedControl` trong `AttendanceSheet`, hành động bị chặn = `BlockingDialog`, hành động cần lý do = `ConfirmDialog` có ô lý do.
- Mật độ không phải prop: đặt `data-product` trên vùng chứa, component đọc `--hmt-density-*`.
- Trạng thái luôn icon + chữ; hành động hoàn tác được thì làm ngay + Toast "Hoàn tác"; không hoàn tác được thì `ConfirmDialog`.
- Các thẻ là prototype tham chiếu hành vi; production dựng cùng API bằng React + Tailwind v4. Icon: **Lucide** nét 1,5px, cỡ 16/20/24 (O-12), nạp từ `lucide@0.460.0`; không tải được thì hiện icon vẽ tạm.

## Logo

Dùng bản cắt khung trong giao diện: `hmt-logo-cropped.svg` trên nền sáng, `hmt-logo-dark-cropped.svg` trên nền tối, `hmt-logo-white-cropped.svg` trên nền màu (ưu tiên `hmt-action`). Cao tối thiểu 96px. Logo rút gọn cho header: chưa có (hoãn). Không sửa, đổi màu hay cắt logo.

## Typography

Đã chốt (O-1): **Inter** cho giao diện và số liệu (chữ số đều cột), **Be Vietnam Pro** cho tiêu đề.

## Quyết định đang mở

Logo rút gọn · vùng trống quanh logo · cỡ chữ lớp 2–5 · "Nguyên tắc 5 Không" · màu cho 5 cơ sở/môn học · sửa trực tiếp trong ô bảng · phím tắt CRM. Câu hỏi nghiệp vụ còn mở: số lần sai trước khi tạm khoá (Q-13); khoảng cho phép và ghi đè tham số (Q-12); AD có xem danh sách vận hành không (Q-8); CS3 trong ô chọn cơ sở (Q-9); . Đề xuất sửa file nguồn: `HMT_DE_XUAT_SUA_NGUON_Q7.md`. Chi tiết: *HMT Decision Log*.
