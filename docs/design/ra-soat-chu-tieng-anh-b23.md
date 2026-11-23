# Rà soát chữ tiếng Anh trên giao diện và câu báo lỗi HMT_* (Code B, 19/11/2026, thẻ B23)

Luật: CLAUDE.md mục Giao diện: chữ trên giao diện bằng tiếng Việt; ngoại lệ có chủ đích (Đ268): «Filters», «Group By», «Favorites», «Save to Favorites» của khuôn K03 theo canvas.

## Cách rà
1. `npm run check:hardcode`: **không thấy số nghiệp vụ viết cứng** (xanh).
2. Câu báo lỗi: quét mọi lời gọi `raise_error('HMT_…', '<câu>')` trong `supabase/migrations/` (1743 lời gọi): **không câu nào thiếu chữ tiếng Việt** (mọi câu đều có dấu tiếng Việt), nên giao diện hiện thẳng câu của máy chủ là tiếng Việt.
3. Chữ trên giao diện: quét `src/**/*.tsx` (bỏ bài kiểm thử và trang thử `dev`) các thuộc tính `label`, `title`, `placeholder`, `aria-label`, `confirmLabel`, `subtitle`, `alt`, `help`, `text` và chữ giữa thẻ JSX, tìm chuỗi không có dấu tiếng Việt, đứng một mình (≥ 2 từ) hoặc chứa từ giao diện tiếng Anh thường gặp (Save, Cancel, Search, Loading…).

## Kết quả
Không có chữ tiếng Anh nào cần sửa. Các chuỗi tiếng Anh còn lại đều **theo khung canvas hoặc luật**, giữ nguyên:

| Chuỗi | Nơi dùng | Nguồn |
|---|---|---|
| Filters, Group By, Favorites, Save to Favorites | khuôn danh sách K03 (`list/ListScreen.tsx`) | Đ268, canvas |
| Source · Sub-source, Stage · Sub-stage | tên nhóm «Group By» của Lead, Cơ hội (`leadConfig.tsx`, `oppConfig.tsx`) | canvas `design/hmt-p0-p2` (K1) |
| Start Date | ô «Start Date» của bản ghi Ghi danh (`EnrollmentRecordPage.tsx`) | canvas `design/hmt-canvas-9933` (GD02) |
| Time Table | tên khối thời khoá biểu của Lớp (`ClassFormPage.tsx`) | canvas 9933 (LOP03, BUOI02), spec R-LOP-02, R-LOP-03 |
| Kanban, Calendar (tên chế độ xem) | nút chuyển chế độ | tên khuôn K03 |
| Email | nhãn trường email | thuật ngữ chung, canvas |

Các từ còn lại tìm thấy (`close`, `search`, `loading`, `upload`, `login`, `password`, `new-password`, `confirm-password`) là tên biểu tượng, giá trị `autoComplete` và thuộc tính kỹ thuật, không hiện cho người dùng.

## Chỗ lớn còn lại
Không có. Nếu anh muốn Việt hoá các nhãn canvas giữ tiếng Anh (Start Date, Time Table, Source/Stage) thì cần Design đổi canvas trước (CLAUDE.md: canvas thắng khi khác gói thiết kế); chưa làm.

**Cập nhật 23/11/2026:** anh Trường chốt không dịch các nhãn Stage, Sub-stage, Source, Sub-source, Source type, Medium, Assign, Campaign, Time Table, Done; mục B5 (Việt hoá nhãn) bỏ khỏi danh sách việc sửa. Danh sách ở `config/nhan-tieng-anh-giu-nguyen.json`, xem `nhan-tieng-anh-trong-man.md`.
