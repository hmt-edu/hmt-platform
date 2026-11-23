# Kế hoạch dựng cổng Học tập (HT-01..09) và cổng Phụ huynh (PH-01..05)

Thẻ D-23-13 bước 2, Code D, 23/11/2026. Canvas nguồn: `design/hmt-canvas-9189/` bản v55 (461 khung), ghi chú đi kèm `GHI_CHU_V55_CHO_CODE.md` (mục «ƯU TIÊN 2» cho HT, «ƯU TIÊN 3» cho PH). **Chưa code màn nào; chờ Chat giao lane.** Số trong khung (giờ còn, tiền, ngày, tên con, số tệp, dung lượng) là số minh hoạ, không chép vào code hay test. Mã PH-01, PH-03, HS-02 trên khung `KH02_*`, `KH05_hoc_tap` là tab CRM, trùng mã với cổng; khung cổng ghi «(cổng …)» trong tiêu đề.

Mức độ «đã kiểm / chưa kiểm»: mục nào ghi **(đã đọc code)** là đã mở tệp để xác nhận; **(chưa kiểm)** là suy từ tên tệp hay ghi chú, người nhận lane kiểm lại trước khi làm.

## 1. Bảng màn ↔ khung canvas

Khuôn chung: KG (tiêu đề + nội dung + thanh dưới `.tabbar`, thẻ `cardrow`, nhãn `hmt-tag`). Điện thoại 390×844; hai khung máy tính 1440×900 (HT-04, HT-09). Ba kiểu nhỏ chỉ có trong khung (`hs-seg`, `hs-ph`, `hs-kv`) là kiểu tạm: dùng thành phần chuẩn tương đương, không thêm khuôn.

### Cổng Học tập `/hoc` (41 khung)

| Màn | Việc | Khung |
| --- | --- | --- |
| HT-01 | Trang chủ học sinh | `HT01_ds`, `_tai`, `_trong`, `_loi` |
| HT-02 | Bài tập: Cần làm, Đã nộp, Đã chấm | `HT02_can_lam`, `_da_nop`, `_da_cham`, `_tai`, `_trong`, `_loi` |
| HT-03 | Chi tiết bài giao (còn hạn, quá hạn nhận muộn, quá hạn không nhận) | `HT03_ds`, `_muon`, `_het_han`, `_tai`, `_loi` |
| HT-04 | Nộp bài (chụp ảnh, nhiều trang, xem lại, nộp lại) | `HT04_dt_trong`, `_da_chon`, `_xem_lai`, `_dang_nop`, `_loi_tep`, `_loi_mang`, `_da_nop`; `HT04_pc` (máy tính, kéo thả) |
| HT-05 | Kết quả chấm một bài | `HT05_cham`, `_chua_xong`, `_tai`, `_loi` (ba trạng thái Không làm, Nộp sau, Không áp dụng cùng bố cục, chỉ đổi nhãn) |
| HT-06 | Lịch học | `HT06_ds`, `_tai`, `_trong`, `_loi` |
| HT-07 | Kết quả buổi và nhận xét (chip đổi lớp khi có hai lớp) | `HT07_ds`, `_khong_btvn`, `_tai`, `_loi` |
| HT-08 | Giờ học / chuỗi và sao (chỉ hiện khi cơ sở bật, R-LMS-05) | `HT08_ds`, `_tai`, `_trong`, `_loi` |
| HT-09 | Khung cổng (thanh dưới 5 mục; máy tính: menu trái, một cột giữa) | `HT09_dt`, `HT09_pc` |

Tab thứ 5 «Tài khoản» chưa vẽ nội dung (anh chốt: giữ nút trên thanh dưới; trang `ProfilePage` đã có ở `/hoc/tai-khoan`).

### Cổng Phụ huynh `/ph` (29 khung)

| Màn | Việc | Khuôn | Khung |
| --- | --- | --- | --- |
| PH-01 | Trang chủ | K09 | `PH01_ds`, `_tai`, `_trong`, `_loi` |
| PH-02 | Kết quả và nhận xét (dùng chung dữ liệu HT-07, HT-08) | K09 | `PH02_ds`, `_nhan_xet`, `_tai`, `_trong`, `_loi` |
| PH-03 | Học phí và giờ học (chỉ xem đơn và phiếu thu, không thanh toán) | K06 | `PH03_ds`, `_gio_thap`, `_don`, `_tai`, `_trong`, `_loi` |
| PH-04 | Đề nghị và khiếu nại (4 bước, gửi mới, xác nhận phương án, không đồng ý có lý do, chấm hài lòng) | K07 | `PH04_ds`, `_gui`, `_chi_tiet`, `_phuong_an`, `_khong_dong_y`, `_hai_long`, `_tai`, `_trong`, `_loi`, `_loi_gui` |
| PH-05 | Lịch học (giống HT-06) | K05 | `PH05_ds`, `_tai`, `_trong`, `_loi` |

Thanh dưới PH: Trang chủ, Kết quả, Học phí, Lịch, Đề nghị; chip chọn con, **ẩn khi phụ huynh chỉ có một con**.

### Màn đăng nhập và tài khoản liên quan (khung ở canvas Quản trị `design/hmt-canvas-dc47/`, DN ở `hmt-canvas-9933/`)

| Màn | Khung |
| --- | --- |
| CHUNG-06 Đăng nhập học sinh (mã HS) | khuôn `DN02` (đã dựng) |
| CHUNG-07 Đổi mật khẩu bắt buộc lần đầu, CHUNG-05 Đặt mật khẩu mới | `DN06_pc_new`, `_ok`, `_mb_new`, `_mb_ok` |
| CHUNG-23 Đăng nhập phụ huynh (mã PH, dựng như DN02) | `CHUNG23_dt_tai`, `_dt_ok`, `_dt_loi`, `Man_CHUNG23` |
| QT-17 Tài khoản phụ huynh (nhân viên) | `QT17_ds`, `_tai`, `_trong`, `_loi`, `_quyen`, `_cap`, `_khoa`, `_dat_lai` |
| CHUNG-21 Đính kèm tệp | `CHUNG21_trong`, `_co_tep`, `_dang_tai`, `_loi`, `_xem`, `_dt_trong`, `_dt_dang_tai` |

## 2. Cổng đã có tới đâu

**(đã đọc code `src/app/routes.tsx`, `supabase/migrations/20261121000616*.sql`, `docs/nghiep-vu/qt17-tai-khoan-phu-huynh.md`)**

| Phần | Hiện trạng |
| --- | --- |
| Khung `/hoc` | Có `StudentShell` bọc `RequirePortal portal="hoc"`; các tab Trang chủ, Bài tập, Lịch, Kết quả đang là `PortalTabPage` giữ chỗ «giai đoạn 4»; `tai-khoan` dùng `ProfilePage` thật. |
| Khung `/ph` | Có `ParentShell` bọc `RequirePortal portal="ph"`; trang chủ giữ chỗ, `tai-khoan` thật. Chưa có tab Kết quả, Học phí, Lịch, Đề nghị. |
| Đăng nhập | `dang-nhap/hoc-sinh` (`StudentLoginPage`, CHUNG-06) và `dang-nhap/phu-huynh` (`ParentLoginPage`, CHUNG-23) đã có route; hàm Edge `login` nhận mã HS và mã PH. |
| Tài khoản | QT-13 (học sinh) và QT-17 (phụ huynh, migration 616: cột `user_account.parent_code`, vai trò PARENT có cổng `ph`, `list_parent_accounts`, `admin_create_account` có mã PH) đã làm; màn nhân viên `tai-khoan-phu-huynh/` đã có. |
| Đổi mật khẩu lần đầu | `first_password_change_required` có nhánh phụ huynh (CHUNG-07, đã có trang đổi mật khẩu). |
| Dữ liệu cho cổng | **Chưa có.** Hàm DB cho cổng chưa có; học sinh và phụ huynh không có quyền ATTENDANCE nên `app.session_visible` (dùng cho RLS bảng LMS) trả sai với họ; RLS đọc dữ liệu của chính mình **chưa có** (xem mục 3). Migration 466/467 (R2) chỉ chặn học sinh đọc cấu hình nội bộ. |
| Công tắc | Phân hệ `HOC_TAP` đã có trong công tắc theo cơ sở (**chưa kiểm** cờ riêng cho cổng PH). |

## 3. Mỗi màn cần DB gì

**Nguyên tắc chung (CAO, quyền):** học sinh chỉ thấy dữ liệu của chính mình, phụ huynh chỉ thấy dữ liệu của con mình. Nhận diện người gọi: học sinh qua `user_account.student_code`, phụ huynh qua `user_account.parent_code` (đã có). Đề xuất **không mở thêm RLS cho vai HS/PH trên bảng nghiệp vụ**, mà dùng **hàm `security definer` riêng cho cổng** (`app.hs_*`, `app.ph_*`), kiểm bên trong «người gọi là học sinh đó / phụ huynh của học sinh đó», trả đúng cột cần, phân trang ở máy chủ, nhật ký truy cập nếu cần. Lý do: RLS hiện dựa quyền theo vai nhân viên; mở thêm cho HS/PH dễ lộ dữ liệu (đã có sự cố S16/R2c). Mỗi hàm có pgTAP: học sinh A không đọc được B; phụ huynh không đọc con người khác; vai nhân viên không gọi được hàm cổng; công tắc tắt thì chặn.

Bảng LMS đã có (**đã đọc** migration 597/598/612): `lms_assignment`, `_target`, `_file`, `lms_submission`, `_file`; hàm giáo viên `lms_create_assignment`, `lms_update_assignment`, `lms_withdraw_assignment`, `lms_list_assignments`, `lms_grading_list`, `lms_grading_sheet`, `lms_save_grade`, `lms_reopen_submission`, `lms_giveable_sessions`. **Chưa có hàm phía học sinh** (xem bài của mình, nộp bài, xem điểm).

| Màn | Hàm đọc/ghi cần | Đã có? | Ghi chú luật |
| --- | --- | --- | --- |
| HT-01 | `hs_home()`: việc cần làm, buổi sắp tới, bài sắp hạn, cờ chuỗi/sao | Chưa | R-LMS-05 cờ cơ sở; ẩn khối khi không bật |
| HT-02 | `hs_list_assignments(nhóm, limit, offset)` | Chưa (bảng có) | R-V2-35: lớp không giao BTVN thì ẩn, HT-02 rỗng giải thích; bài quá hạn nằm ở «Cần làm» nhãn «Quá hạn» |
| HT-03 | `hs_get_assignment(id)` | Chưa | R-LMS-02: còn hạn / quá hạn nhận muộn / quá hạn không nhận (khoá nút); R-LMS-01 công tắc «Nhận bài muộn» |
| HT-04 | `hs_submit(assignment, các trang)`, `hs_resubmit` | Chưa | R-LMS-03 nộp lại tới khi chấm, công tắc «Cho nộp lại»; R-LMS-04 số tệp, dung lượng đọc từ tham số; nhãn «Nộp muộn». **CHỜ KHO R2 (mục 6)** |
| HT-05 | `hs_get_result(assignment)` | Chưa (`lms_grading_sheet` là của giáo viên) | R-GV-11 năm trạng thái; điểm 1 đến 5; chỉ hiện sau khi chấm |
| HT-06, PH-05 | `hs_schedule(from, to)` / `ph_schedule(student, from, to)` | Chưa (**chưa kiểm** có hàm lịch dùng lại được) | Lịch buổi của các lớp đang học, chỉ lớp còn hiệu lực |
| HT-07, PH-02 | `hs_class_results(class)` / `ph_results(student, class)`: điểm danh, nhận xét, điểm | Chưa; dữ liệu có (`session_attendance`, `session_student_review`) | R-GV-12; chỉ nhận xét đã chốt/đã gửi; nhận xét chờ gửi (CS-16) chưa lộ ra cổng |
| HT-08 | `hs_streak_stars()` | Chưa | R-LMS-05: chuỗi, sao chỉ khi cơ sở bật; không xếp hạng |
| PH-01 | `ph_home(student)` | Chưa | Việc cần chú ý: giờ còn thấp, đề nghị đang xử lý, nhận xét mới |
| PH-03 | `ph_hours_orders(student)`, `ph_order(id)` | Chưa; dữ liệu có (quỹ giờ, đơn, phiếu thu) | R-GD-13 ngưỡng «giờ còn thấp» dùng tham số `upsale_hours_left_threshold` (đã có), «ngày hết dự kiến»: công thức chốt bên code; chỉ xem, không thanh toán |
| PH-04 | `ph_list_tickets`, `ph_create_request` (gửi đề nghị/khiếu nại), `ph_get_ticket`, `ph_confirm_option`, `ph_reject_option(lý do bắt buộc)`, `ph_rate(ticket)` | `create_ticket` có (của nhân viên); hàm phía phụ huynh **chưa** | R-CS-06, R-CS-09, R-CS-14: đối chiếu 4 bước như canvas, lệch thì báo lại; phụ huynh chỉ thấy ticket của mình, không thấy ghi chú nội bộ |
| HT-09, PH (khung) | Tab, chọn con, thông báo | Khung có; chip chọn con cần `ph_children()` | Chip ẩn khi chỉ một con |

## 4. Thứ tự dựng và chia lane (đề xuất)

1. **Lane 1 (khung cổng, THẤP-VỪA, chỉ giao diện):** HT-09 (thanh dưới 5 mục điện thoại, menu trái máy tính, tab Tài khoản giữ chỗ) và khung PH (thanh dưới, chip chọn con, `ph_children()` nếu cần một hàm nhỏ). Thay các `PortalTabPage` bằng trang thật rỗng-sẵn-sàng (đang tải/trống/lỗi theo khung KG). Kiểm: đăng nhập mã HS và mã PH vào đúng cổng, cổng khác bị chặn (đã có `RequirePortal`).
2. **Lane 2 (nền DB cho cổng, CAO: quyền):** migration một lần: hàm nhận diện `app.current_student_id()`, `app.current_parent_children()`, kiểm công tắc cổng; pgTAP ma trận HS A/B, PH con mình/con người khác, nhân viên. Mọi hàm màn sau dựa vào đây.
3. **Lane 3 (HT đọc: HT-01, 02, 03, 05, 06, 07, 08):** hàm `hs_*` đọc + giao diện từng màn, mỗi PR một nhóm nhỏ; CAO ở hàm (quyền riêng từng học sinh).
4. **Lane 4 (PH đọc: PH-01, 02, 03, 05):** hàm `ph_*` đọc; PH-02 dùng chung hàm với HT-07/08, PH-05 với HT-06 (tránh trùng việc: Lane 3 làm trước, Lane 4 bọc lại theo con).
5. **Lane 5 (PH-04 đề nghị và khiếu nại, CAO):** có ghi dữ liệu (gửi đề nghị, xác nhận/không đồng ý phương án, chấm hài lòng); đối chiếu R-CS-06/09/14; pgTAP đúng/bị chặn; ghi nhật ký.
6. **Lane 6 (HT-04 nộp bài, CAO: tệp + quyền):** **chờ kho R2** (mục 6). Có thể làm trước phần giao diện với tệp giả, hàm ghi `hs_submit` sau khi kho sẵn sàng.

Mức CAO (quyền, nhật ký): Lane 2, 3 (hàm), 4 (hàm), 5, 6. Mức THẤP-VỪA: Lane 1 và phần giao diện.

## 5. Điểm cần anh/Chat chốt trước khi giao lane

1. **Hàm cổng riêng thay vì mở RLS cho HS/PH** (mục 3): đề xuất đi hướng hàm riêng. Cần Chat OK.
2. **Nhận xét hiển thị cho phụ huynh:** chỉ nhận xét «Đã gửi» hay mọi nhận xét đã chốt (liên quan CS-16 Nhận xét chờ gửi).
3. **PH-03 «Ngày hết dự kiến» và ngưỡng «giờ còn thấp»:** công thức bên code; đề xuất lấy `upsale_hours_left_threshold` làm ngưỡng, ngày hết dự kiến = giờ còn ÷ số giờ học mỗi tuần theo lịch (cần anh duyệt công thức).
4. **Công tắc cổng:** dùng chung phân hệ `HOC_TAP` cho HT và PH hay thêm cờ riêng cho PH.

## 6. Việc chờ kho R2 (Cloudflare R2, giai đoạn 4)

- **HT-04 nộp bài bằng ảnh/PDF** và **CHUNG-21 Đính kèm tệp**: chưa có nơi lưu tệp (CLAUDE.md: tệp để R2, không dùng Supabase Storage). Giới hạn số tệp, dung lượng, định dạng đọc từ tham số (khung minh hoạ 10 MB, 5 tệp). Cần: kho R2 + quy trình cấp liên kết tải lên có thời hạn (Edge Function), kiểm quyền người tải, quét loại tệp, xoá khi gỡ.
- **HT-02/03 xem tệp đề của giáo viên** (`lms_assignment_file`) cũng cần kho R2 để xem ảnh/PDF đề.
- Giao diện HT-04 và CHUNG-21 có thể dựng trước với bộ chọn tệp thật và gọi hàm giả lập; **không bật cho người dùng thật** khi chưa có kho.

## 7. Tóm tắt rủi ro

Quyền dữ liệu học sinh và phụ huynh là rủi ro lớn nhất (lộ chéo). Mọi lane có hàm DB cho cổng cần pgTAP ma trận (HS A đọc B, PH đọc con người khác, nhân viên gọi hàm cổng) và Tester ĐẠT đúng sha; không cấp quyền `select` trực tiếp các bảng nghiệp vụ cho vai HS/PH.
