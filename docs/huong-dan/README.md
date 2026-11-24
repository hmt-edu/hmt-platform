# Hướng dẫn sử dụng: cách thêm một bài (A-23-42)

Trang `/crm/huong-dan` và `/gv/huong-dan` đọc mọi tệp `.md` trong thư mục này (kể cả thư mục con, ví dụ `tu-van/nhap-lead.md`). **Mục lục tự sinh từ phần đầu của từng bài**: thêm bài = thêm một tệp có phần đầu; không sửa tệp mục lục nào, nhiều người viết cùng lúc không đụng nhau.

## Phần đầu bài (đặt ở dòng đầu tệp)

```
---
title: Nhập lead từ file CSV
group: vai
slug: tu-van-nhap-lead
order: 30
role: Tư vấn tuyển sinh
portals: [crm]
priority: P1
flow: ts2
screens: [TS-04]
checked: 2026-11-24
---
```

- **Bắt buộc:** `title` (tên hiện trên menu), `group` (`bat-dau`, `vai` hoặc `tra-cuu`).
- **Tuỳ chọn:** `slug` (đường dẫn; mặc định là đường dẫn tệp, «/» thành «-»; chỉ chữ thường không dấu, số, gạch nối) · `no` (số hiện trước tên, nhóm Bắt đầu) · `order` (số nhỏ hiện trước; mặc định 1000) · `role` (nút «Bạn là ai?» ở đầu hướng dẫn) · `portals` (`[crm]` mặc định; thêm `gv` để hiện ở cổng Giáo viên) · `priority`, `flow` (mã luồng trong `KE-NGHIEP-VU.md`), `screens` (mã màn), `checked` (ngày đi thử lần cuối): công cụ kiểm sau này dùng các trường này.
- Phần đầu sai khuôn (thiếu `title`, `group` lạ, `slug` trùng) thì **dựng ứng dụng báo lỗi nêu tên tệp**.
- Tệp **không** có phần đầu (như tệp này, `CHUP-ANH.md`, `KE-NGHIEP-VU.md`) không phải bài người dùng: không vào menu. Muốn thêm tệp loại này, đưa tên vào `NOT_GUIDE` trong `src/pages/huong-dan/guideIndex.test.ts`.
- Thứ tự menu: nhóm, rồi `order`, rồi tên tệp. «Bài trước / Bài sau» đi theo đúng thứ tự này.

## Ảnh và video

Viết `[ẢNH: tên]` và `[VIDEO: tên]` (xem `CHUP-ANH.md`). Ảnh nằm ở `public/huong-dan/anh/<tên>.png`; video khai ở `public/huong-dan/video-manifest.json`.

## Ghi chú chung khi viết

- Chữ trong dấu «…» là chữ trên màn thật. Lỗi do máy chủ trả về luôn hiện **câu tiếng Việt** ngay trên màn. Dữ liệu trong ví dụ là giả.
- Từ điển thuật ngữ: `04-tu-dien.md`. Muốn kiểm tay từng màn: `docs/van-hanh/kiem-tay-staging.md`.
