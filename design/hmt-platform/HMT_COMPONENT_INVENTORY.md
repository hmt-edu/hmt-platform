# HMT Component Inventory

**HMT Platform · danh sách component, biến thể, props chính và các màn/thẻ mẫu đã có**
Cập nhật: 2026-10-11 (đợt 5.0) · Nguồn: `HMT_COMPONENT_SPEC.md` (P4 + §11), `components/index.d.ts`

> Mọi component đọc mật độ từ `data-product` (`crm` · `teacher` · `lms`) và màu từ token `--hmt-*`. Không có prop kích thước theo sản phẩm, trừ `Button size="sm"`.
> Mã trong `components/src/index.tsx` là **prototype tham chiếu hành vi** (React 18, CSS token). Production dựng lại cùng API bằng React + Tailwind v4.

## 1. Danh sách component (30 component, 27 thẻ ví dụ — TextInput, Select, Textarea dùng chung thẻ Field — và phần phụ trợ)

| # | Component | Nhóm | Biến thể / cấu hình | Props chính |
| --- | --- | --- | --- | --- |
| 1 | `Button` | Button | `variant`: primary · secondary · tertiary · destructive; `solid` (destructive nền đặc — chỉ trong ConfirmDialog); `iconOnly`; `size="sm"`; states: default, hover, pressed, focus, disabled, loading | `variant`, `solid`, `size`, `loading`, `loadingLabel`, `disabled`, `iconStart`, `iconEnd`, `iconOnly` + `label`, `fullWidth`, `neutral`, `onClick` |
| 2 | `Field` *(thêm `hideLabel` 11/10)* | Form | Bắt buộc · không bắt buộc · helper · lỗi · bộ đếm | `label`, `required`, `optional`, `helper`, `error`, `counter`, `children` (một ô nhập) |
| 3 | `TextInput` | Form | Có `leadingIcon` (tìm kiếm), `trailing`; disabled | `value`, `onChange`, `type`, `inputMode`, `leadingIcon`, `trailing`, `invalid`, `disabled` |
| 4 | `Select` | Form | Select gốc; placeholder | `options[{value,label}]`, `value`, `onChange`, `placeholder`, `invalid`, `disabled` |
| 5 | `Textarea` | Form | Có/không `maxLength` (bộ đếm) | `value`, `onChange`, `maxLength`, `invalid`, `disabled` |
| 6 | `DateInput` | Form | Gõ dd/mm/yyyy + lịch (desktop) · `native` (mobile) | `value` (dd/mm/yyyy), `onChange`, `native`, `invalid`, `disabled` |
| — | `MonthGrid` (đổi tên từ `Calendar`, 5.0) | Form (phụ trợ) | Dùng trong DateInput, DateRange; có tô khoảng | `value`, `onSelect`, `rangeFrom`, `rangeTo` |
| 7 | `Table` | Data display | Chỉ đọc · `selectable` + thanh hàng loạt · cột `sortable` / `numeric` · loading · rỗng · tự thành thẻ khi hẹp | `columns[{key,header,numeric,sortable,render}]`, `rows`, `rowKey`, `caption`, `selectable`, `selected`, `onSelectedChange`, `sort`, `onSortChange`, `loading`, `empty`, `bulkActions`, `cardsBelow` |
| 8 | `Pagination` | Data display | Đầy đủ · `compact` | `page`, `pageCount`, `onPageChange`, `total`, `pageSize`, `compact` |
| 9 | `Badge` | Data display | `tone`: success · warning · danger · info · neutral; subtle / `solid` | `tone`, `solid`, `icon` (tên hoặc `false` cho neutral), `children` |
| — | `CountBadge` | Data display (phụ trợ) | Số đếm, 99+ | `count`, `label` |
| 10 | `Avatar` | Data display | Ảnh · chữ cái đầu; `sm` · `md` · `lg` | `name`, `src`, `size`, `decorative` |
| 11 | `Tooltip` | Data display | — | `content`, `children` (một phần tử), `delay` |
| 12 | `Chip` | Data display | Tắt · bật (`aria-pressed`), có số đếm | `selected`, `onToggle`, `count`, `children` |
| 13 | `Sidebar` | Navigation | Mở rộng 240px · thu gọn 64px | `title`, `subtitle`, `sections[{label,items[{id,label,icon,badge}]}]`, `activeId`, `onNavigate`, `collapsed`, `onCollapsedChange`, `footer` |
| 14 | `TopNav` | Navigation | Desktop · mobile (nút quay lại) | `title`, `leading`, `actions`, `children` |
| 15 | `Tabs` | Navigation | Có/không số đếm | `items[{value,label,count}]`, `value`, `onChange`, `label`, `children` (panel) |
| 16 | `Breadcrumb` | Navigation | Đầy đủ · `compact` | `items[{label,href,onClick}]`, `compact` |
| 17 | `BottomNav` | Navigation | 3–5 mục, có CountBadge | `items[{id,label,icon,badge}]`, `activeId`, `onNavigate` |
| 18 | `Toast` (`ToastProvider` + `useToast`) | Feedback | `tone`: success · info · warning · danger; có/không thao tác (Hoàn tác, Thử lại); vị trí `bottom-right` · `bottom` | `push({ tone, message, action:{label,onClick}, duration })`, `dismiss(id)`, `placement` |
| 19 | `Alert` | Feedback | 4 tone; tiêu đề / nội dung / thao tác / nút đóng | `tone`, `title`, `children`, `actions`, `onDismiss`, `live` |
| 20 | `StateView` | Feedback | `kind`: empty · no-results · error · offline · no-access; `compact` | `kind`, `title`, `description`, `actions`, `compact` |
| 21 | `Loading` (`Skeleton`, `Spinner`) | Feedback | Skeleton · Spinner có chữ · (Button `loading`) | Skeleton: `width`, `height`, `radius`; Spinner: `label` |
| 22 | `Dialog` | Overlay | Thường 480px · `size="lg"` 720px · có `tone` | `open`, `onClose`, `title`, `description`, `tone`, `size`, `footer`, `initialFocus`, `dismissible`, `role` |
| 23 | `ConfirmDialog` **(sửa 5.0)** | Overlay (= Dialog cấu hình) | `tone`: danger · warning · info; đang xử lý; **lý do bắt buộc** | `open`, `onClose`, `onConfirm({reason,note})`, `title`, `description`, `confirmLabel`, `cancelLabel`, `tone`, `loading`, `reasonLabel`, `reasonOptions` |
| 24 | `Drawer` | Overlay | `placement`: right · bottom | `open`, `onClose`, `title`, `description`, `placement`, `footer`, `children` |
| 25 | `Popover` | Overlay | Menu thao tác · bộ lọc nhanh | `trigger`, `label`, `children` (hoặc hàm `(close) => …`), `placement` |
| 26 | `SegmentedControl` **(sửa 5.0)** | Lớp · học sinh · điểm danh | `layout`: stack · row; `colored` theo `tone` + `emphasis` subtle/solid; disabled | `name`, `label`, `options[{value,label,short,icon,tone,emphasis}]`, `value`, `onChange`, `colored`, `layout`, `disabled` |
| 27 | `AttendanceSheet` **(sửa 5.0)** | Lớp · học sinh · điểm danh | 4 trạng thái Có mặt · Đi muộn · Vắng có phép · Vắng không phép, mặc định trống, có màu (R-DD-01); `mode`: teacher · ops (lý do liên hệ) · compare (hai cột); tự lưu: đang lưu / đã lưu / chưa lưu được; **máy tính: dạng bảng khi khung ≥ 760px** | `session{className,label,time,campus}`, `students[{id,name,code,meta,note}]`, `mode`, `initial`, `opsMarks`, `onChange`, `onRequestNext` |
| 28 | `StudentListItem` (+ `PersonLine`) | Lớp · học sinh · điểm danh | Phần cuối dòng tuỳ ý; bấm được cả dòng | `name`, `meta`, `avatar`, `trailing`, `onClick` |
| 29 | `ClassCard` | Lớp · học sinh · điểm danh | Liên kết · tĩnh; có `footer` | `name`, `campus`, `schedule`, `teacher`, `enrolled`, `capacity`, `status`, `href`, `footer` |
| 30 | `ProgressBar` | Lớp · học sinh · điểm danh | `variant`: default · lms; `size="lg"` | `value`, `max`, `label`, `valueText`, `variant`, `size` |
| — | `Icon` **(sửa 5.0)** | Phụ trợ | Lucide nét 1,5px (O-12); bộ vẽ tạm dự phòng khi không tải được Lucide | `name`, `label`, `size` (16/20/24) |
| — | `ATT_STATUSES` | Hằng số | Có mặt · Có phép · Vắng | `[{value,label,icon,tone}]` |

### 1b. Thành phần bổ sung đợt 5.0 (21)

| # | Thành phần | Nhóm | Biến thể / cấu hình | Props chính |
| --- | --- | --- | --- | --- |
| 31 | `StatusBar` | Bản ghi | Bước đã qua/hiện tại/chưa tới; `forwardOnly`; `substatus`; `terminal` (Huỷ, Từ chối); `locked`; điện thoại "Các bước" | `steps[{id,label,short}]`, `current`, `actions`, `forwardOnly`, `substatus`, `terminal`, `locked`, `onStepClick` |
| 32 | `SmartButton` / `SmartButtonGroup` | Bản ghi | Có số đếm; nhóm `max`, dư → "Thêm" | `icon`, `label`, `count`, `onClick`; nhóm: `items`, `max` |
| 33 | `Chatter` | Bản ghi (CHUNG-22) | Ghi chú (@, đính kèm) · thay đổi trường · hệ thống; lọc; tab trên điện thoại | `entries`, `people`, `me`, `onPost` |
| 34 | `FilterBar` | Danh sách | Tìm kiếm; chip nhóm (HOẶC trong nhóm, VÀ giữa nhóm); lọc nâng cao; nhóm theo; yêu thích; chọn cột; kiểu xem; số kết quả | `search`, `groups`, `value`, `onChange`, `advancedCount`, `groupByOptions`, `favorites`, `columns`, `views`, `view`, `resultCount` |
| 35 | `BulkActionBar` | Danh sách | Số đã chọn + thao tác + Bỏ chọn | `count`, `children`, `onClear` |
| 36 | `Kanban` (+ `KanbanCard`) | Danh sách | Kéo thả / menu "Chuyển sang"; chặn có lý do | `columns`, `onMove`, `canMove`, `renderCard` |
| 37 | `Calendar` | Danh sách | Ngày (phòng/giáo viên) · tuần · tháng; 4 loại buổi; huỷ; trùng phòng | `events`, `view`, `by`, `resources`, `onOpen` |
| 38 | `Combobox` | Biểu mẫu | Chọn một / nhiều; không dấu; mã cũ; dòng phụ; khoá kèm lý do; không có kết quả | `options[{value,label,code,legacyCode,meta,disabled}]`, `value`, `onChange`, `multiple` |
| 39 | `DateRange` | Biểu mẫu | Mốc nhanh + tuỳ chọn | `value{from,to}`, `onChange` |
| 40 | `MoneyInput` | Biểu mẫu | Nhập · chỉ đọc (hệ thống tính) · lỗi · tắt | `value`, `onChange`, `readOnly` |
| 41 | `FileUpload` | Biểu mẫu | Kéo thả (máy tính) · chụp/chọn (điện thoại); xem trước; tiến độ; lỗi; gỡ | `label`, `accept`, `maxMB`, `mobile` |
| 42 | `HoursDisplay` | Học vụ | Bình thường · sắp hết · giờ tặng chưa cấp · quá hạn gói còn giờ · gọn | `granted`, `used`, `bonus`, `bonusLocked`, `expectedEnd`, `packageEnd`, `packageExpired` |
| 43 | `RatingScale` | Học vụ | 1–5, mô tả mức lấy từ cấu hình rubric; chưa chấm ≠ 0; bắt buộc | `name`, `label`, `value`, `onChange`, `descriptions`, `required` |
| 44 | `HomeworkStatus` **(sửa 11/10)** | Học vụ | 5 trạng thái (R-GV-11); xem "4/5" / sửa; **điểm gõ tay 1–5** (A-47) khi Đã chấm, Làm chưa xong; xếp dọc (điện thoại) hoặc cùng hàng (máy tính) | `value{status,score}`, `onChange`, `readOnly`, `min`, `max`, `decimals`, `showMissing`, `hideLabels` |
| 44b | `ScoreInput` **(mới 11/10)** | Học vụ (phụ trợ) | Ô điểm số, mặc định 1–5 (BTVN, A-47), kiểm tra đầu vào truyền 0–10; một chữ số thập phân (4,5); kiểm tra khi rời ô | `value`, `onChange`, `onErrorChange`, `min`, `max`, `decimals` |
| 45 | `RadarChart` | Học vụ | Chuỗi + trung bình lớp; bảng số | `title`, `axes`, `series[{name,values,kind}]` |
| 46 | `TaskStepper` | Học vụ (K12) | 5 bước; tiến độ; em trước/sau; hạn; **máy tính: cột bước bên trái (khung ≥ 760px)** | `title`, `steps`, `current`, `deadline`, `nav`, `footer` |
| 47 | `SlaBadge` | Phản hồi | Còn · Quá hạn · Đúng hạn · Trễ hạn | `kind`, `hours` |
| 48 | `ApprovalChain` | Phản hồi | Đã duyệt · Chờ duyệt · Từ chối · Chưa tới lượt; dọc/ngang | `levels[{role,approver,status,at,reason}]` |
| 49 | `BlockingDialog` | Phản hồi | `block` / `warn` | `kind`, `title`, `reasons[{text,detail,actionLabel,onAction}]`, `onContinue` |
| 50 | `VersionedConfig` | Quản trị (K10) | Đang dùng · sắp hiệu lực · lịch sử · so sánh | `versions`, `rows`, `format` |
| 51 | `PrintLayout` | In (K13) | **A4** cho cả ba: báo giá, biên nhận phiếu thu, phiếu chi | `size`, `campus`, `docTitle`, `code`, `party`, `columns`, `lines`, `totals`, `signatures` |

Ghi chú: `Toast` và `Loading` là tên thẻ ví dụ; component thật là `ToastProvider`/`useToast` và `Skeleton`/`Spinner`.

## 2. Đã bổ sung trong đợt 5.0 (trước là OPEN)

Combobox (O-14), DateRange (O-15), bộ icon Lucide (O-12). Còn thiếu: logo rút gọn (hoãn); chỉnh sửa trực tiếp trong ô bảng (chưa cho phép).

## 3. Màn / thẻ mẫu đã có

**Chưa có màn hình nghiệp vụ nào** — các màn trong `HMT_BAN_DO_MAN_HINH.md` bắt đầu từ đợt 5.1 (khuôn K01–K13). Những gì đã có là các thẻ ví dụ trong Design System "HMT Platform":

### 3.1 Thẻ nền tảng (Foundations)

| Thẻ | Nội dung |
| --- | --- |
| Cover | Bìa Design System |
| StatusAndActions | Nút, focus, disabled, form, 4 trạng thái (light/dark) |
| ProductDensity | Cùng token, 3 mật độ: bảng công nợ CRM · điểm danh Teacher · thẻ bài học LMS |
| FontCompare | Be Vietnam Pro vs Inter: tiếng Việt, cột số tabular, độ rộng |

### 3.2 Thẻ component tương tác (27)

| Thẻ | Kịch bản mẫu (dữ liệu giả) | Trạng thái bấm thử được |
| --- | --- | --- |
| Button | Lưu phiếu thu, Xuất Excel, Huỷ phiếu thu | Đổi mật độ CRM/Teacher/LMS, loading, disabled, focus, tooltip |
| Field | Form thêm học sinh (họ tên, SĐT phụ huynh, cơ sở, ghi chú) | Lỗi khi blur, tóm tắt lỗi khi gửi, thành công |
| DateInput | Ngày đến hạn học phí, ngày nhập học, ngày dạy bù | Lịch bằng bàn phím, ngày không tồn tại, native |
| Table | Công nợ học phí 6 học sinh | Sắp xếp, chọn nhiều + gửi nhắc, loading, không có kết quả, dạng thẻ |
| Pagination | 1.287 bản ghi | Đầy đủ, gọn |
| Badge | Đã thu, Sắp hạn, Quá hạn, Học bù | subtle/solid, CountBadge |
| Avatar | Học sinh | 3 cỡ, ảnh lỗi |
| Tooltip | Nút icon Sửa, Tải lại | Rê chuột, focus, Esc |
| Chip | Lọc trạng thái học phí | Bật/tắt có số đếm |
| Sidebar | CRM CS2: Tuyển sinh, Học vụ, Tài chính | Điều hướng, thu gọn |
| TopNav | Lớp 9B1 (desktop), 9B1 · Điểm danh (mobile) | — |
| Tabs | Hồ sơ học sinh Trần Bình | Phím mũi tên |
| Breadcrumb | Học vụ › Lớp học › 9B1 › Buổi 12 | Đầy đủ, gọn |
| BottomNav | Teacher Portal: Hôm nay, Điểm danh, Lớp, Tôi | Chuyển mục |
| Toast | Lưu phiếu thu, chuyển lớp | Hoàn tác, cảnh báo, lỗi không tự ẩn |
| Alert | Lịch nghỉ lễ, đồng bộ, thiếu giáo viên, lỗi thanh toán | Đóng |
| StateView | Lớp chưa có học sinh, không tìm thấy, lỗi 503, mất mạng, không có quyền | Chuyển loại |
| Loading | Danh sách học sinh | Skeleton, spinner, nút loading |
| Dialog | Chuyển lớp cho Trần Bình | Giữ focus, Esc |
| ConfirmDialog | Xoá Lê Chi khỏi lớp 4C3 | Focus ở Huỷ, đang xử lý, toast |
| Drawer | Hồ sơ Trần Bình (phải), Lọc học sinh (dưới) | Mở/đóng |
| Popover | Menu thao tác hàng, lọc cơ sở | Esc, click ngoài |
| SegmentedControl | Ngày/Tuần/Tháng; điểm danh trung tính vs có màu | So sánh OPEN O3 |
| AttendanceSheet | Lớp 7A2 · 18:00 · CS1 · 5 học sinh | Chống bỏ sót, "Còn lại: Có mặt", lưu, Hoàn tác; công tắc OPEN O2, O3 |
| StudentListItem | CRM, LMS phụ huynh | — |
| ClassCard | 9B1, 7A2, 4C3 (LMS có tiến độ) | — |
| ProgressBar | Thu học phí tháng 10; tiến độ bài học LMS | Tăng tiến độ |

### 3.3 Thẻ thêm trong đợt 5.0 (21 mới + 3 sửa)

StatusBar · SmartButton · Chatter · FilterBar · BulkActionBar · Kanban · Calendar · Combobox · DateRange · MoneyInput · HoursDisplay · RatingScale · HomeworkStatus · RadarChart · FileUpload · TaskStepper · SlaBadge · ApprovalChain · BlockingDialog · VersionedConfig · PrintLayout; sửa: AttendanceSheet, SegmentedControl, ConfirmDialog. Dữ liệu mẫu theo mục 2 file luật (HS000123, DH-CS1-2610-0001, CS1-2627-TOAN-K08-CB-A-001, 9.504.000 đ, 8A1 · Buổi 12 · 15/10/2026).


## 4. Đợt 5.1 · phần 1 — thẻ điều hướng

NavMap (sơ đồ ba cổng) · RoleMenu (vai trò → menu) · FlowMap (16 luồng). Chi tiết: `HMT_DIEU_HUONG_5.1.md`.


## 5. Đợt 5.2 — khuôn thành component và màn

| # | Component | Nhóm | Props chính |
| --- | --- | --- | --- |
| 52 | `AppShell` (+ `CrmNav`, `menuFor`, `CRM_MENU_ROWS`, `CAMPUSES`, `ROLE_LABEL`) | Khuôn K01 | `role`, `user{name,campus}`, `activeId`, `onNavigate`, `campus`, `onCampusChange`, `notifications`, `onSearch`, `onNotifications`, `onAccount`, `multiPortal`, `badges`, `loading`, `mobile`, `defaultCollapsed`, `children` |
| 53 | `AuthLayout` | Khuôn K11 | `product`, `logoSrc`, `logoWhiteSrc`, `title`, `subtitle`, `footer`, `mobile`, `children` |
| 54 | `PageHeader` | Trang | `title`, `code`, `breadcrumb`, `meta`, `actions` |
| 55 | `StatTile` | Khuôn K09 | `label`, `value`, `hint`, `hintTone`, `icon`, `target`, `onOpen`, `loading` |
| 56 | `TurnstileSlot` | Đăng nhập | `state`: verifying · success · error · expired, `onRetry` |
| 57 | `OtpInput` | Đăng nhập | `value`, `onChange`, `length`, `invalid`, `autoFocus` |
| 58 | `PasswordInput`, `PasswordRules`, `passwordOk` | Đăng nhập | `value`, `onChange`, `autoComplete` |

Thẻ màn đợt 5.2 (24): CHUNG-01, 02, 03, 04, 06, 07, 10, 11, 12, 14, 22, 26 · QT-01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 13.


## 6. Đợt 5.7 · 5.5 — biểu đồ, cổng Giáo viên, khuôn K14

| # | Component | Nhóm | Props chính |
| --- | --- | --- | --- |
| 59 | `LineChart` (đợt 5.7) | Biểu đồ · K09 | `labels`, `series[{name,short,values,color,dashed}]`, `format`, `axisFormat`, `height`, `label`, `yMax`, `tooltipTitle` — một trục y, chuỗi 2+ nét đứt, hộp số khi rê chuột / phím mũi tên, bảng ẩn |
| 60 | `TeacherShell` (+ `GV_NAV`) | Khung GV-01 (K02 điện thoại · K01 thu gọn laptop) | `device`: phone · laptop, `activeId`, `onNavigate`, `title`, `onBack`, `actions`, `user`, `badges`, `saveState`, `height`, `contentMaxWidth`, `flush` |
| 61 | `QuickGrid` | **Khuôn K14 · Bảng chấm nhanh (laptop)** | `rows`, `columns[{key,label,kind: radio·select·score·text·read, field, value, hotkey, options, min, max, decimals, group, sub, disabled}]`, `values`, `onChange`, `onOpenRow`, `caption`, `maxHeight`, `rowDisabled`, `rowNote`, `failOnSave` |

**K14 · Bảng chấm nhanh (laptop).** Hàng = học sinh, cột = trạng thái hoặc tiêu chí. Bàn phím: mũi tên, Tab / Shift+Tab, phím 1–4 cho 4 trạng thái điểm danh (cột trạng thái), phím số chọn trạng thái BTVN, gõ số + Enter (xuống em sau) hoặc Tab cho ô điểm, Delete bỏ trống, Enter trên ô lời nhắn hoặc bấm tên em mở ngăn bên (mô tả 5 mức của tiêu chí, lời nhắn dài). Ô trống là khung nét đứt không chữ, khác hẳn điểm; điểm ngoài thang (vd. 0, 6) báo lỗi ngay tại ô. Cột tên và hàng tiêu đề cố định khi cuộn. Lưu tự động từng ô: Đang lưu · Đã lưu · Chưa lưu được. Em vắng: cả hàng gạch chéo, một ô "Vắng · không chấm". Dùng cho GV-05, GV-07, GV-08 (laptop), GV-18.


## 7. Đợt 5.6 — cổng Học tập + Phụ huynh

| # | Component | Nhóm | Props chính |
| --- | --- | --- | --- |
| 62 | `StudentShell` (+ `HT_NAV`, `PH_NAV`) | Khung HT-09 (K02 điện thoại · K01 laptop một cột) | `portal`: hs · ph (5 tab Trang chủ, Kết quả, Lịch, Học phí, Đề nghị; Tài khoản ở menu ảnh đại diện — A-48), `device`: phone · laptop, `young`, `activeId`, `onNavigate`, `title`, `onBack`, `actions`, `user`, `badges`, `bottom`, `height`, `flush` |
| 63 | `PhotoPages` | Học tập · nộp bài | `pages[{id,kind: img·pdf,src,name,size,pages,status: done·uploading·error,progress,error}]`, `onChange`, `onView`, `onRetry`, `onAdd`, `review`, `columns` |
| 64 | `SubmissionViewer` | Học tập · xem bài nộp | `pages[{id,src,label}]`, `page`, `onPage`, `height`, `compact` — phím ← → + − R |

## 8. P6 — sửa thành phần (12/10)

- `Chip`, `Button` (`size="sm"`, `iconOnly`), `TextInput` / `Select` / `DateInput` (ô phủ hết chiều cao khung), `Tabs`, `FilterBar` (nút kiểu xem), `PasswordInput` (nút Hiện mật khẩu), `RatingScale` (nút Bỏ chấm): vùng bấm ≥ 44px trên điện thoại (P-100).
- `KanbanCard`: thêm `onOpen`, `openLabel` (P-101).
