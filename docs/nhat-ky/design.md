# Nhật ký Claude Design (bản lưu 19/10/2026, sau khi gộp ba canvas)

Ba canvas (HMT Platform, P5a, P5b) đã gộp thành một canvas "HMT Platform" ngày 19/10 (v64; v65 sửa câu ở 4 khung không có quyền; v66 cập nhật khung Ghi chú cuối). Số liệu dưới đây là của canvas gộp; hai canvas P5a, P5b cũ vẫn còn, giữ nguyên, chưa ghi "đã chuyển".

Mục đích: tài khoản Claude mới mở phiên Design đọc file này là làm tiếp được ngay. Nguồn các canvas đã lưu ở `design/nguon-canvas/` (xem mục 5).

## 1. Canvas, link, phiên bản
| Canvas | Link | Phiên bản lúc lưu | Tình trạng |
|---|---|---|---|
| "HMT Platform" (gộp P0 khuôn, P1 đăng nhập, P2 cấu hình, P3 tuyển sinh, P4 khách hàng, P5a bán hàng và thu chi, P5b đào tạo): 308 khung = 285 khung màn hình + 23 khung mục lục, tiêu đề nhóm, bảng tổng hợp | https://claude.ai/artifact/RkrASNia4wUgbRwXiYRmFY | v66 (mã phiên bản 1792379582-46a6) | P3 đã duyệt 16/10 (v48); P4 xong, chờ anh duyệt; P5a xong, đóng băng; P5b đang làm (Ghi danh, LOP-01..03 xong). Làm tiếp P5b ngay trên canvas này. |
| "P5a Bán hàng và Thu chi" (canvas cũ): 86 khung | https://claude.ai/artifact/7NZAWMvx8QkYgMArFSkULp | v6 (mã 1792232446-fbdd) | Đã chép nguyên sang HMT Platform (hash trùng từng khung). Giữ nguyên, chưa ghi "đã chuyển", chờ anh nói. Bình luận cũ không sang canvas gộp. |
| "P5b Đào tạo" (canvas cũ): 53 khung | https://claude.ai/artifact/RjJn6GwhSHkycVRNiCXvpU | v4 (mã 1792316717-d2b7) | Đã chép sang HMT Platform (chỉ đổi một câu ở 5 khung không có quyền). Giữ nguyên, chưa ghi "đã chuyển", chờ anh nói. Bình luận cũ không sang canvas gộp. Không vẽ thêm ở đây. |
| Hệ thống thiết kế "HMT Platform" | https://claude.ai/artifact/3Yco5qmVbyDiyfZm9HcJqN | bản chép trong canvas: 1792124962-8639 | Dùng chung cho mọi canvas |

Khung tạo canvas mới: tạo từ loại Design (https://claude.ai/artifact/QKN21svewxgyPb6SYRqWnd), rồi xuất bản tệp vào link của canvas đó.

## 2. Màn đã xong
- **P4:** KH-01..KH-07 (Phụ huynh, học sinh, tài chính, lịch sử, tìm kiếm) đã xuất bản cùng các khuôn K1..K5 và P0_v5.
- **P5a** (27 mã màn): BH-01..BH-11, TC-01..TC-16. Mức C không vẽ (BH-04, BH-10, BH-11, TC-06, TC-12, TC-14, TC-16). BH-03 (A4) và TC-07 (A5) dùng khuôn in K13 (anh đã duyệt).
- **P5b cụm 1 (Ghi danh), xong:** GD-01 (danh sách + trống, tải, không quyền), GD-02 (9 trạng thái: đang học, đã xếp lớp, chờ xếp lớp, bảo lưu, hết giờ, học trước, hoàn phí, đang tải, không quyền), GD-03 Xếp lớp (6 biến thể: nhóm lớp luân phiên, một lớp lẻ, lớp trùng buổi bị mờ kèm lý do, nhắc mềm Toán 7+, không có lớp, đang tải), GD-04 Sổ giờ, GD-05 Điều chỉnh giờ, GD-06 Hàng chờ xếp lớp, GD-07 Sắp hết giờ (4 trạng thái mỗi danh sách).
- **P5b cụm 2 (Lớp), đợt 1 xong:** LOP-01 (danh sách + trống, tải, không quyền; kanban 7 cột theo bước duyệt), LOP-02 bản ghi (Nháp, Đã trình, Đã xác nhận thiếu thời khoá biểu, Đã duyệt luân phiên Đại/Hình, Từ chối, Đã đóng, Huỷ, đang tải, không quyền; hộp thoại LOP-05, 06, 07, 10 mở được từ bản ghi), LOP-03 (tạo nhóm lớp, lớp riêng, sửa lớp bị từ chối, lỗi, đang tải, không quyền).

## 3. Màn dở và việc kế tiếp
**P5b, còn làm (theo thứ tự Lớp → Buổi → Tái tục, sau mỗi cụm báo anh một dòng):**
- LOP-04 Thời khoá biểu lớp (mức A), khung riêng cho hộp thoại LOP-05, 06, 07, 10, LOP-08 Lịch tuần cơ sở (K05, mức A) (LOP-05..07, 10 đã có trong LOP-02 để bấm thử). LOP-09 mức C (danh sách K03, không vẽ).
- BUOI-01..BUOI-13 (BUOI-02 bản ghi mức A, BUOI-04 Huỷ buổi mức A, BUOI-03/11 điểm danh trên điện thoại dùng K12, BUOI-07..10 học bù, củng cố, bổ trợ). BUOI-14 mức C (K08).
- TT-01 (danh sách + kanban L1–L8), TT-02. TT-03 mức C (K08).
- Khung ghi chú cuối của P5b: đã có khung `Ghi_chu_cuoi` chung cho cả canvas gộp (chỗ lệch, câu hỏi chờ anh, màn dừng); khi làm xong các cụm P5b thì bổ sung vào đó.
- Khung tổng quan P5b (`P5b_Tong_quan`) đã tạo; chưa cập nhật cho các màn LOP đã xong.

**P4, việc nhỏ còn lại:** thread bình luận b2f15525 chưa đóng. Hai danh sách KH-01, KH-04 chưa bấm sang bản ghi được. TS18 và TS19 là hai khung trống (có trong `canvas.json` cũ nhưng không có tệp; đã bỏ theo gói P3, xếp lịch gộp vào TS-15, huỷ phiếu nằm ở TS-17): đã gỡ khỏi canvas gộp. Bản chép cũ ở `design/nguon-canvas/p4-hmt-platform/project/TS18|TS19.dc.html` không dùng.

**P5a:** không vẽ thêm. Anh tự thêm K13 vào P0 v5 và danh mục "Điều khoản thanh toán" vào P2 v5. Khi anh sửa một màn P5a hay P5b: liệt kê các màn liên quan trong nhóm A–I (bản đồ nhóm ở khung tổng quan P5a/P5b) và hỏi anh trước khi sửa. Chỉ nói "áp dụng hết" thì sửa tất cả rồi báo danh sách.

## 4. Câu hỏi treo, đề xuất của Design chờ anh trả lời "OK" (chưa vào khung ghi chú P5b)
1. Menu con của Đào tạo (Ghi danh, Hàng chờ xếp lớp, Sắp hết giờ, Tái tục, Lớp học, Lịch tuần cơ sở, Buổi học, Yêu cầu buổi, Điểm danh trong ngày, Buổi chưa hoàn tất): P0 chưa có mục cấp 2, đây là đề xuất của Design.
2. Nút Xuất ở danh sách ghi danh: đề xuất chỉ CS, Trưởng cơ sở, Kế toán, Admin.
3. Chặn môn theo khối khi xếp lớp: đề xuất, chờ anh.
4. GD-07, TT: dự báo theo từng ghi danh, hạn gói và End Date chỉ để dự báo, quá hạn gói còn giờ vẫn học (R-GD-07). Chờ duyệt theo 04e mục 3.
5. Khuôn mới đề xuất K12 (điểm danh trên điện thoại từng bước) và K14 (chấm nhanh): phải ghi "mới đề xuất", dừng màn nếu không có khuôn nào gần.
6. Mã cũ (Sheet): chỉ ở lớp (LOP-02, ô chỉ đọc cạnh mã lớp; tìm kiếm ở LOP-01 nhận mã cũ) và học sinh. Phụ huynh không có mã cũ.
7. K4f (19/10): khuôn mới "hộp Gộp trùng" cho TS-10 và KH-07 (khung `K4f`, 3 trạng thái: chưa tick, đã tick, bị chặn); thêm một dòng vào `design/hmt-p3/P0_v5_thay_doi.md`. Chưa sửa TS-10, KH-07 để dùng khuôn này, chờ anh bảo. Ví dụ vẽ dùng R-CRM-22; điều kiện chặn của KH-07 còn [CHỜ] ở R-CRM-25.
8. TS-06 (18/10): nút "Gộp vào cơ hội cũ" đổi thành "Mở cơ hội cũ". Còn lệch chữ ở đoạn cảnh báo ("Chọn Gộp…") và ở `docs/design/ban-do-man-hinh.md` dòng TS-06; Design chưa sửa, chờ anh.
9. Câu mẫu "phân hệ Bán hàng và thu chi" ở khung không có quyền của GD-01, GD-02, GD-04, GD-06, GD-07: đã đổi thành "phân hệ Đào tạo" (19/10, anh OK, v64 và v65). Chỉ đổi câu đó.
10. Câu hỏi từ LOP-01..03 (cũng ghi ở khung cạnh LOP-02): "Tình trạng vận hành" của lớp chưa có giá trị trong luật (đang vẽ tạm Chưa khai giảng, Đang học, Đã kết thúc); định dạng mã cũ CLS-2609-0014 là mẫu tự đặt; chặn môn theo khối khi tạo lớp chờ anh quyết (hiện chỉ nhắc nhẹ).

## 5. Nguồn đã lưu trong repo
- **`design/nguon-canvas/hmt-platform-gop/project/` (nguồn hiện hành):** canvas.json và 308 khung của canvas gộp v66 (kèm `ds/hmt/`). Các thư mục `p4-hmt-platform/`, `p5a/`, `p5b/` là bản cũ trước khi gộp, chỉ để tham khảo.
- `design/nguon-canvas/p4-hmt-platform/`, `p5a/`, `p5b/`: bản chép cũ ba canvas riêng (P4 không có K4f, TS06 mới, khung LOP; P5b dừng ở 33 khung).
- `design/nguon-canvas/ds-hmt/`: bản chép hệ thống thiết kế HMT (tokens.json, components/bundle.css, handoff/hmt-tokens.css). Đặt vào `project/ds/hmt/` khi xuất bản lại một canvas.
- `design/nguon-canvas/script-dung/`: script Python dựng khung P5a/P5b (`p5a_*.py`, `p5b_*.py`, gồm `p5b_lop.py`), script P4 (`kh_common.py`, `build_kh_*.py`, `build_k4f.py`…), script gộp canvas (`gop_*.py`: sơ đồ vị trí, khung tiêu đề, bảng chưa vẽ), kiểm thử Playwright (`t*.js`), chụp màn hình (`shot5.js`).

Cách dựng lại canvas từ repo: tạo canvas mới từ loại Design; chép `design/nguon-canvas/hmt-platform-gop/project/` vào `project/`; xuất bản **`project/canvas.json`** trước (chỉ file này là chỉ mục; không đặt `canvas.json` ở thư mục gốc), rồi các khung (mỗi lần tối đa vài chục tệp, không quá 255 tệp, 16 MB một lần). Lưu ý: dựng lại là canvas mới, link mới, phiên bản về v1, bình luận cũ không theo sang.

## 6. Ghi chú bàn giao cho chat Design mới (đọc phần này đầu tiên)
**Vai trò:** em là Claude Design, vẽ wireframe dạng canvas (từng khung `.dc.html`), anh CHỦ DỰ ÁN duyệt, Claude Chat viết luật, Claude Code dựng. Trả lời tiếng Việt, ngắn, gạch đầu dòng, không thuật ngữ thừa.

**Luật làm việc đang áp dụng:**
- Đề xuất trước, sửa sau khi anh OK (trừ lệnh trực tiếp).
- Một thay đổi trên một màn thì áp cho mọi màn giống nó: khi anh sửa một màn P5a/P5b, liệt kê các màn liên quan trong nhóm A–I rồi hỏi anh trước, trừ khi anh nói "áp dụng hết" (khi đó sửa hết và báo danh sách).
- P0–P2 đóng băng. Thay đổi dùng chung chuyển vào P0 v5.
- Chưa xuất bản thành công thì không báo "xong".
- Chỉ dùng thành phần và khuôn của P0. Thiếu khuôn: DỪNG màn đó và báo (tên màn, mã, khuôn gần nhất, chỗ thiếu). Khuôn mới phải ghi "mới đề xuất".
- Khi các nguồn vênh nhau: luật (`docs/spec/` 04, 02, 06) > quyết định thiết kế 13/10 > bản đồ màn hình > gói thiết kế P0–P2; làm theo luật, ghi chỗ vênh.
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

**Việc đầu tiên khi mở phiên mới:** đọc file này và `design/nguon-canvas/hmt-platform-gop/project/canvas.json`; làm tiếp P5b (LOP-04, khung riêng LOP-05..07, 10, LOP-08, rồi Buổi, Tái tục) ngay trên canvas "HMT Platform" (đã có sẵn nhóm con BUOI, TT còn trống). Chỉ chỉ mục `project/canvas.json` có hiệu lực.

**Không chắc / lưu ý:** các script dựng nằm trong `design/nguon-canvas/script-dung/` và gọi nhau theo đường dẫn tương đối kiểu `scripts/…`, `p5a/project/`, `p5b/project/` của thư mục làm việc cũ; muốn chạy lại cần đặt chúng vào một thư mục `scripts/` và tạo `p5a/project/ds` từ `ds-hmt/`. Phiên mới có thể chỉnh lại đường dẫn khi cần.


## 7. Canvas gộp (19/10): bố cục và việc đã làm
- Thứ tự từ trên xuống: Mục lục (bảng trạng thái từng nhóm) · P0 · P1 · P2 · P3 (Lead, Lịch hẹn, Cơ hội, Phiếu kiểm tra, Gộp trùng và Nhập lô) · P4 · P5a (BH rồi TC) · P5b (GD, LOP, BUOI, TT) · Giai đoạn sau (chưa vẽ: P13, P14 và bảng mã màn chưa có khung) · Ghi chú cuối. Mỗi nhóm có khung tiêu đề (tên, số khung, trạng thái).
- Chỉ chuyển và xếp lại khung. Không đổi tên tệp, không đổi mã màn. Nội dung khung chỉ đổi đúng một câu "phân hệ Bán hàng và thu chi" thành "phân hệ Đào tạo", ở 5 khung không có quyền của P5b (GD01_khong_quyen, GD02_quyen, GD04_khong_quyen, GD06_khong_quyen, GD07_khong_quyen; anh duyệt). P5a: 86 khung giống hệt bản gốc; P5b: 53 khung, khác bản gốc đúng ở câu đó.
- Sửa lỗi của bản v59: khung K4f chưa nằm trong chỉ mục `project/canvas.json` (bản v59 lỡ ghi vào `canvas.json` thư mục gốc), nên chưa hiện trên canvas. Đã thêm vào P0 (cạnh P0 v5). `canvas.json` thư mục gốc là bản cũ lệch (có KH02_day_du không tệp, thiếu KH05_diem_danh); v64 ghi cùng nội dung vào cả hai chỗ để khỏi lệch.
- Hai khung trống TS18, TS19 bỏ khỏi canvas. Ghi chú trên canvas: bỏ các tiêu đề nhóm cũ (đã có khung tiêu đề), mã ghi chú P5a, P5b thêm tiền tố `p5a_`, `p5b_`; ghi chú trạng thái và ghi chú trên từng cụm giữ nguyên. Ghi chú P4 cũ "CHƯA VẼ 2 CHỖ" (HS-03, HS-05) chỉ còn trong `canvas.json` gốc lệch, đã xong nên không đưa sang.
- Bảng "Màn chưa vẽ" (khung `Chua_ve`): đối chiếu `ban-do-man-hinh.md` (195 mã) với canvas: 72 mã có khung, 123 mã chưa có khung (Mức C không vẽ 27, đang làm tiếp ở P5b 21, chưa vẽ trong giai đoạn đã mở 30, giai đoạn sau 45). Mã PH-01, PH-03, HS-01..07 ghi trên khung P4 là tab của KH-02, KH-05, trùng tên mã PH-, HT- của bản đồ.
- Bình luận ở hai canvas P5a, P5b cũ không chuyển sang canvas gộp. Bình luận trên HMT Platform (kể cả thread b2f15525) vẫn ở nguyên.
- Lưu nguồn canvas HMT Platform v117 (26/10/2026) vào `design/nguon-canvas/hmt-platform-v117/` (480 artboard, bỏ `artifact-type/` và `support.js`); giữ nguyên các thư mục canvas cũ.
