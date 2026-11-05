# Nhật ký Claude Code (cập nhật 04/11/2026)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang. Bản dài trước 28/10 nằm trong lịch sử git của file này: `git log -- docs/nhat-ky/code.md`.)

## Đang làm (04/11)
- **v1 làm tiếp cho Cơ sở 5 chạy thật; v2 dừng hẳn** (Đ285). v1 từng đóng băng tại #152 (02/11), nay mở lại.
- PR tài liệu `docs/canvas-6f57-quyet-dinh-v2`: lưu canvas `6f57` và `8a0d` vào `design/`, canvas chuẩn là `6f57` (thay `8ab9`), quyết định nghiệp vụ từ v2 vào `docs/spec/04` mục 14 và `06` mục 3, bảng khác biệt và kế hoạch ở `docs/nghiep-vu/doi-chieu-quyet-dinh-v2.md`. **Chờ anh OK kế hoạch trước khi viết migration** (Đ286).
- Mốc: 10/11 Tuyển sinh và màn Nhập CS5; ~12/11 Bán hàng, Thu chi; ~17/11 Đào tạo, Cổng giáo viên, Aftersale (Đ289).
- UI-O2c (Duyệt, Từ chối đơn): nhánh `feat/p5a-ui-o2c-duyet-tu-choi` giữ trên máy, chưa đẩy. Chưa sửa giao diện Báo giá, Đơn hàng, Phiếu thu khi anh chưa gửi yêu cầu (Đ287).
- `_inbox/`: đã xoá mọi thứ của v2 (wireframe, zip). Còn tài liệu nghiệp vụ `v2-*.md`, hai gói canvas, file mẫu nạp dữ liệu giả (không commit).

## Đã gộp gần đây (Bán hàng, P5a)
- DB: đơn hàng (051, 052), báo giá tên em (053), lọc Đã chuyển đơn (054, 057), xem thử, gói bán, chính sách (055), mã đơn từng dòng (056), chính sách quà tặng (058), `total_discount_percent` (059), quyền chung hàm đọc phụ và `student_names` (060), tạo đơn kèm điều khoản một giao dịch và `preview_order_students` (061).
- Giao diện BH-01, BH-02 (đủ chuỗi xem, Gửi, Từ chối, Huỷ, sửa Nháp, quà tặng, Tạo báo giá từ cơ hội), BH-06 danh sách đơn. Chi tiết nằm trong mô tả PR và `docs/TIEN-DO.md`.
- Gộp PR độc lập bằng squash, PR xếp chồng bằng merge commit (Đ240).

## Đã chốt
- Đ277: bản in báo giá giữ số điện thoại phụ huynh che giữa ("0912 *** 345").
- Đ278 (a đã sửa bởi Đ279): `truongcx-95` bật xác thực hai bước, chỉ dùng trên trình duyệt; `hmt-vanhanh` là collaborator quyền Write.
- Đ279: `truongcx-95` là chủ hai repo (đã chuyển xong); tài khoản OK gộp PR vẫn là `caotruong276` (collaborator của `hmt-platform`); Đ278a sửa lại: không thay hẳn.
- Đ255: nợ kỹ thuật `preview_quotation_lines` trả lỗi tất cả dòng trong một lần.
- Đ256 đến Đ276 (28/10): thứ tự làm; khung BH-05 là bản canvas `1793154455-8ab9` (Đ270, Đ272); canvas anh chốt thắng gói thiết kế và bản đồ (Đ271); bỏ Hình thức thanh toán, Cơ sở thu tiền khỏi đơn (Đ258); Chuyển thành đơn là form trắng bỏ bớt bằng ✕ (Đ259); gộp tạo đơn và điều khoản một giao dịch (Đ260); BH-06 Đã thu, Còn phải thu "—" (Đ262, Đ269); in báo giá mọi trạng thái, nhãn BẢN NHÁP, ĐÃ TỪ CHỐI, ĐÃ HUỶ, hộp in của trình duyệt (Đ263 đến Đ267, Đ273, Đ274); giữ chữ tiếng Anh của khuôn K03 (Đ268); bỏ gợi ý "dùng báo giá còn hiệu lực" (Đ275).
- Luật mới R-TIEN-39 (28/10): đơn thẳng từ cơ hội mà cơ hội đã có đơn Nháp thì cảnh báo, Mở đơn cũ hoặc Vẫn tạo.
- Điện thoại giữ bản chỉ đọc cho BH-02, BH-05 (Đ248).

## Đang chờ
- Chat: duyệt chữ ký hàm và bài kiểm DB-O1c; báo canvas mới cho BH-03.
- Anh Trường: OK PR luật R-TIEN-39 và PR CLAUDE.md.
- Nhánh gốc phiếu tái tục của Tạo báo giá và Tạo đơn (TT-02, L6 và L7): chờ bảng phiếu tái tục (P5b).

## Việc theo ngày
- Sau 7 ngày kể từ khi PR Cắt phút CI gộp: đo lại phút Actions, so với tháng 10 (~2.000 phút, 201 lượt CI).

## File hoặc link mới
- Canvas chuẩn: `design/hmt-canvas-6f57/` (`1793759210-6f57`, giống hệt `8ab9`, Đ285) và `design/hmt-canvas-8a0d/` (Đào tạo, Giáo viên: GV-01..16, BUOI-03, LOP-08, bộ khuôn KG; GV07b, GV08b là bản nháp). `design/nguon-canvas/` giữ làm lịch sử.
- Ảnh chụp: `docs/anh-chup/bh01/`, `bh02/`, `bh06/`, `bh05/`, `bh03/` (năm tình trạng, PDF A4 do trình duyệt xuất).

## 04/11/2026: T3 nhóm con mới và danh mục 33
- Migration 066: L4E đến L4H, L7M đến L7S (thêm), danh mục 33 thành BQ1 đến BQ5 (bốn mã cũ Ngừng). Bài kiểm 058; sửa bài 006, 011, 012, 013, 020, 022 theo mã BQ.
- Đã đối chiếu Config mới với DB: lệch L5B (tên), L5P, L5Q, L6A đến L6G. Chưa đổi, báo anh Trường.
- Bài e2e đăng nhập chập chờn ghi vào TIEN-DO "Việc để sau" (xử lý sau 10/11).

## 04/11/2026: T3b nhóm con L5, L6 theo Config mới
- Migration 067: L6 đánh lại A đến G, L5B đổi tên, L5P và L5Q Ngừng, lý do huỷ \"Trung tâm không xếp được lịch test\" nối L5M. Hàm đổi: `opportunity_l5_substage`, `submit_student_test` (lên L6A), `complete_student_test` (L6B), `change_opportunity_stage` (chặn tay L6A, L6B).
- Giao diện `oppStage.ts`; bài kiểm 011, 017, 020, 022, 006, 058, Vitest, e2e co-hoi.

## 04/11/2026: T4a nạp Phụ huynh và Học sinh
- Migration 068: `app.import_records` (xem trước/nạp, chỉ Admin), `import_one_parent`, `import_one_student`, `app.import_log`, tham số `import_max_rows`. Bài kiểm 059. Tài liệu `docs/nghiep-vu/nap-du-lieu.md`.
- Kết quả và nhật ký nạp chỉ có số dòng và chữ cái đầu của tên, không có họ tên, SĐT, mã cũ (có bài kiểm).
- Việc đã kiểm SQL xoá cơ hội giả của #157 trên DB local có dữ liệu giả (đơn, báo giá, phiếu kiểm tra, lịch hẹn); lead về C4C.

## 04/11/2026: T4b nạp Người dùng
- Migration 069: `import_users_resolve`, `import_user_create`, `import_user_set_manager`, `import_user_lock`, `import_users_finish`, bảng `import_user_branch_pending`, tham số `import_user_email_domain`, `import_temp_password_length`. Edge Function `import-users`; `_shared/temp-password.ts`. Bài kiểm 060 và Vitest. Đã thử Edge Function trên Supabase local (xem trước, nạp, nạp lại).
- Quyết định anh trả lời 04/11 (#160): email quy ước theo tham số, nhiều cơ sở lấy cơ sở đầu kèm cảnh báo, mật khẩu tạm trả một lần.

## 05/11/2026: nhập canvas Bán hàng, Thu chi (v146 và bổ sung v2)
- `design/hmt-canvas-9933/` (485 khung, `canvas.json` khớp 485 file) thay `hmt-canvas-6f57`; `design/hmt-canvas-8262/` (6 khung). Chỉ tài liệu, không sửa file canvas (Đ293).

## 05/11/2026: T4c nạp Cơ hội, ngoại lệ R-CRM-03 cho lượt nạp
- Migration 072: `import_one_opportunity`, `import_records` thêm loại `CO_HOI` và báo cáo `summary`; cột `legacy_created_at` (lead, cơ hội), `student_info_missing` (cơ hội), `opportunity_import` (phụ huynh); lý do `NAP_CU` (Ngừng).
- **Anh chốt 05/11 (ngoại lệ chỉ cho lượt nạp):** cơ hội L5 trở lên thiếu tên và/hoặc năm sinh em vẫn nạp, đánh dấu "thiếu thông tin em (dữ liệu cũ)", bổ sung trước khi sang bước tiếp theo hoặc ghi danh; không suy năm sinh từ khối; R-CRM-03 giữ nguyên cho cơ hội tạo mới. Kiểm file `HMT5_CHUAN_BI_IMPORT.xlsx` (239 dòng Cơ hội, 150 từ L5 trở lên): 146 thiếu năm sinh, 124 thiếu cả tên em.
