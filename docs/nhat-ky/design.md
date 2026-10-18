# Nhật ký Claude Design (bản lưu 17/10/2026, kiểm lại 23:06)

Đã so lại với canvas đang chạy lúc 23:06 ngày 17/10: `canvas.json` của cả ba canvas trùng với nguồn trong repo, không có ai sửa thêm sau lần xuất bản cuối của Design (mã phiên bản: P4 1792228500-368a, P5a 1792232446-fbdd, P5b 1792233478-4d11).

Mục đích: tài khoản Claude mới mở phiên Design đọc file này là làm tiếp được ngay. Nguồn các canvas đã lưu ở `design/nguon-canvas/` (xem mục 5).

## 1. Canvas, link, phiên bản
| Canvas | Link | Phiên bản lúc lưu | Tình trạng |
|---|---|---|---|
| "HMT Platform" (P0 khuôn, P1 đăng nhập, P2 cấu hình, P3 tuyển sinh, P4 khách hàng): 147 khung | https://claude.ai/artifact/RkrASNia4wUgbRwXiYRmFY | v57 (mã phiên bản 1792228500-368a) | P4 xong, chờ anh duyệt |
| "P5a Bán hàng và Thu chi": 86 khung | https://claude.ai/artifact/7NZAWMvx8QkYgMArFSkULp | v6 (mã 1792232446-fbdd) | Xong, **đóng băng**. Anh tự xem và sửa. Chưa đóng gói. |
| "P5b Đào tạo": 33 khung | https://claude.ai/artifact/RjJn6GwhSHkycVRNiCXvpU | v3 (mã 1792233478-4d11) | Mới xong cụm Ghi danh. |
| Hệ thống thiết kế "HMT Platform" | https://claude.ai/artifact/3Yco5qmVbyDiyfZm9HcJqN | bản chép trong canvas: 1792124962-8639 | Dùng chung cho mọi canvas |

Khung tạo canvas mới: tạo từ loại Design (https://claude.ai/artifact/QKN21svewxgyPb6SYRqWnd), rồi xuất bản tệp vào link của canvas đó.

## 2. Màn đã xong
- **P4:** KH-01..KH-07 (Phụ huynh, học sinh, tài chính, lịch sử, tìm kiếm) đã xuất bản cùng các khuôn K1..K5 và P0_v5.
- **P5a** (27 mã màn): BH-01..BH-11, TC-01..TC-16. Mức C không vẽ (BH-04, BH-10, BH-11, TC-06, TC-12, TC-14, TC-16). BH-03 (A4) và TC-07 (A5) dùng khuôn in K13 (anh đã duyệt).
- **P5b cụm 1 (Ghi danh), xong:** GD-01 (danh sách + trống, tải, không quyền), GD-02 (9 trạng thái: đang học, đã xếp lớp, chờ xếp lớp, bảo lưu, hết giờ, học trước, hoàn phí, đang tải, không quyền), GD-03 Xếp lớp (6 biến thể: nhóm lớp luân phiên, một lớp lẻ, lớp trùng buổi bị mờ kèm lý do, nhắc mềm Toán 7+, không có lớp, đang tải), GD-04 Sổ giờ, GD-05 Điều chỉnh giờ, GD-06 Hàng chờ xếp lớp, GD-07 Sắp hết giờ (4 trạng thái mỗi danh sách).

## 3. Màn dở và việc kế tiếp
**P5b, còn làm (theo thứ tự Lớp → Buổi → Tái tục, sau mỗi cụm báo anh một dòng):**
- LOP-01 (danh sách + kanban theo bước duyệt), LOP-02 bản ghi (mức A, đủ trạng thái: Nháp, Đã trình, Đã xác nhận, Đã duyệt, Từ chối, Đóng, Huỷ), LOP-03 Tạo lớp, LOP-04 Thời khoá biểu lớp (mức A), LOP-05..07 trình/xác nhận/duyệt, LOP-08 Lịch tuần cơ sở (K05, mức A), LOP-10. LOP-09 mức C (danh sách K03, không vẽ).
- BUOI-01..BUOI-13 (BUOI-02 bản ghi mức A, BUOI-04 Huỷ buổi mức A, BUOI-03/11 điểm danh trên điện thoại dùng K12, BUOI-07..10 học bù, củng cố, bổ trợ). BUOI-14 mức C (K08).
- TT-01 (danh sách + kanban L1–L8), TT-02. TT-03 mức C (K08).
- Khung ghi chú cuối canvas P5b (chỗ lệch, câu hỏi đánh số có đề xuất, màn dừng): **chưa tạo**.
- Khung tổng quan P5b đã tạo (`P5b_Tong_quan`).

**P4, việc nhỏ còn lại:** thread bình luận b2f15525 chưa đóng. Hai danh sách KH-01, KH-04 chưa bấm sang bản ghi được. TS18 và TS19 có trong `canvas.json` nhưng máy chủ không trả được tệp (lúc lưu): bản trong `design/nguon-canvas/p4-hmt-platform/project/` là **bản chép cũ từ máy, không chắc khớp bản đang chạy**, kiểm lại trước khi dùng.

**P5a:** không vẽ thêm. Anh tự thêm K13 vào P0 v5 và danh mục "Điều khoản thanh toán" vào P2 v5. Khi anh sửa một màn P5a hay P5b: liệt kê các màn liên quan trong nhóm A–I (bản đồ nhóm ở khung tổng quan P5a/P5b) và hỏi anh trước khi sửa. Chỉ nói "áp dụng hết" thì sửa tất cả rồi báo danh sách.

## 4. Câu hỏi treo, đề xuất của Design chờ anh trả lời "OK" (chưa vào khung ghi chú P5b)
1. Menu con của Đào tạo (Ghi danh, Hàng chờ xếp lớp, Sắp hết giờ, Tái tục, Lớp học, Lịch tuần cơ sở, Buổi học, Yêu cầu buổi, Điểm danh trong ngày, Buổi chưa hoàn tất): P0 chưa có mục cấp 2, đây là đề xuất của Design.
2. Nút Xuất ở danh sách ghi danh: đề xuất chỉ CS, Trưởng cơ sở, Kế toán, Admin.
3. Chặn môn theo khối khi xếp lớp: đề xuất, chờ anh.
4. GD-07, TT: dự báo theo từng ghi danh, hạn gói và End Date chỉ để dự báo, quá hạn gói còn giờ vẫn học (R-GD-07). Chờ duyệt theo 04e mục 3.
5. Khuôn mới đề xuất K12 (điểm danh trên điện thoại từng bước) và K14 (chấm nhanh): phải ghi "mới đề xuất", dừng màn nếu không có khuôn nào gần.
6. Mã cũ (Sheet): chỉ ở lớp (LOP-02, ô chỉ đọc cạnh mã lớp; tìm kiếm ở LOP-01 nhận mã cũ) và học sinh. Phụ huynh không có mã cũ.

## 5. Nguồn đã lưu trong repo
- `design/nguon-canvas/p4-hmt-platform/project/`: canvas.json và 146 khung của canvas "HMT Platform".
- `design/nguon-canvas/p5a/project/`, `design/nguon-canvas/p5b/project/`: canvas.json và các khung.
- `design/nguon-canvas/ds-hmt/`: bản chép hệ thống thiết kế HMT (tokens.json, components/bundle.css, handoff/hmt-tokens.css). Đặt vào `project/ds/hmt/` khi xuất bản lại một canvas.
- `design/nguon-canvas/script-dung/`: script Python dựng khung P5a/P5b (`p5a_*.py`, `p5b_*.py`), script P4 (`kh_common.py`, `build_kh_*.py`…), kiểm thử Playwright (`t*.js`), chụp màn hình (`shot5.js`).

Cách dựng lại một canvas từ repo: tạo canvas mới từ loại Design; chép `project/` của thư mục tương ứng và `ds-hmt/` vào `project/ds/hmt/`; xuất bản `canvas.json` trước, rồi các khung (mỗi lần tối đa vài chục tệp). Lưu ý: dựng lại là canvas mới, link mới, phiên bản về v1, bình luận cũ không theo sang.

## 6. Ghi chú bàn giao cho chat Design mới (đọc phần này đầu tiên)
**Vai trò:** em là Claude Design, vẽ wireframe dạng canvas (từng khung `.dc.html`), anh Cao Xuân Trường duyệt, Claude Chat viết luật, Claude Code dựng. Trả lời tiếng Việt, ngắn, gạch đầu dòng, không thuật ngữ thừa.

**Luật làm việc đang áp dụng:**
- Đề xuất trước, sửa sau khi anh OK (trừ lệnh trực tiếp).
- Một thay đổi trên một màn thì áp cho mọi màn giống nó: khi anh sửa một màn P5a/P5b, liệt kê các màn liên quan trong nhóm A–I rồi hỏi anh trước, trừ khi anh nói "áp dụng hết" (khi đó sửa hết và báo danh sách).
- P0–P2 đóng băng. Thay đổi dùng chung chuyển vào P0 v5.
- Chưa xuất bản thành công thì không báo "xong".
- Chỉ dùng thành phần và khuôn của P0. Thiếu khuôn: DỪNG màn đó và báo (tên màn, mã, khuôn gần nhất, chỗ thiếu). Khuôn mới phải ghi "mới đề xuất".
- Wireframe thắng P0–P2 khi hai bên vênh.
- Chỉ dữ liệu giả. Không dán link canvas vào câu trả lời trừ khi anh hỏi.
- Anh duyệt xong mới giao cho Code. Chỉ đóng gói zip khi anh nói.
- Không tự cập nhật khung ghi chú trừ khi anh dặn.
- Hộp thoại theo K08. Nút Xuất chỉ cho vai trò có quyền. Cột số căn phải. Tiền có dấu chấm (9.504.000 đ). Ngày dd/mm/yyyy.
- Mỗi cụm xong: báo anh một dòng.

**Luật nghiệp vụ đã thể hiện ở P5a/P5b:** mỗi dòng đơn một lớp một ghi danh một quỹ giờ (R-04e). Toán lớp 7 trở lên là hai lớp độc lập Đại và Hình, nối bằng "nhóm lớp" (không có mã riêng, có thể có tên chung như 9M1); báo giá Toán 7+ có hai dòng riêng. Trùng giờ tính theo buổi thật (R-GD-15); lớp luân phiên không báo trùng. Sổ giờ chỉ thêm dòng; điều chỉnh bằng dòng ngược dấu, bắt buộc lý do; chuyển giờ giữa ghi danh chỉ qua ticket "Chuyển phí" (R-GD-18). Hết giờ thì chặn điểm danh trừ giờ, trừ "cho học trước" (R-GD-12, âm tối đa 2 buổi). End Date và hạn gói chỉ để dự báo (R-GD-07). Lớp duyệt cần thời khoá biểu và tự sinh buổi. Điều khoản thanh toán chọn từ danh mục, lịch đợt chỉ đọc.

**Cách xuất bản (đã dùng ổn):**
- Công cụ Artifact: `url` = link canvas, `root` = thư mục chứa `project/`, `file_path` = đường dẫn tuyệt đối tới `project/canvas.json`, `files` = bảng `"project/X.dc.html": "project/X.dc.html"`. Chỉ gửi tệp mới hoặc đổi; gửi `canvas.json` khi thêm, bớt, đổi chỗ khung hoặc đổi ghi chú.
- Canvas mới: xuất bản với `type_url` loại Design và `title`, rồi gửi tệp vào link vừa tạo; cài hệ thống thiết kế bằng `project/ds/hmt/tokens.json` lấy từ artifact HMT Platform, cộng `components/bundle.css` và `handoff/hmt-tokens.css` từ `ds-hmt/`.
- Muốn sửa canvas cũ: phải đọc nó (action read) trước, và tài khoản phải có quyền chỉnh sửa (người được Share quyền xem thì không sửa được).
- Mỗi khung là một `.dc.html`; dòng `<script src="./support.js">` giữ nguyên; gốc khung có `data-ix="root"`.

**Việc đầu tiên khi mở phiên mới:** đọc file này, đọc `design/nguon-canvas/p5b/project/canvas.json`, hỏi anh còn dùng canvas P5b cũ (nếu tài khoản có quyền sửa) hay dựng lại từ repo, rồi làm cụm Lớp (LOP).

**Không chắc / lưu ý:** các script dựng nằm trong `design/nguon-canvas/script-dung/` và gọi nhau theo đường dẫn tương đối kiểu `scripts/…`, `p5a/project/`, `p5b/project/` của thư mục làm việc cũ; muốn chạy lại cần đặt chúng vào một thư mục `scripts/` và tạo `p5a/project/ds` từ `ds-hmt/`. Phiên mới có thể chỉnh lại đường dẫn khi cần.
