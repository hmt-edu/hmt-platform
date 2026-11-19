# Yêu cầu khung cho Design: GV-17 Giao bài trên LMS, GV-18 Chấm bài nộp online

Ngày 20/11/2026. Anh Trường chốt: màn thiếu khung chờ Design vẽ sau 0:00 chủ nhật 22/11, Code không tự dựng. File này gom đủ để Design vẽ đúng ngay. Hai màn thuộc giai đoạn 4 (LMS), nằm trong cổng Giáo viên `/gv`, ưu tiên điện thoại 390×844, laptop là bản phụ. Chưa có bảng cơ sở dữ liệu LMS; QĐ-Đ63 (24/10): viết kịch bản LMS, anh duyệt, rồi mới vẽ và code. Tài liệu này là phần đề xuất kịch bản cho Design và anh duyệt; số liệu trong khung là minh hoạ.

Nguồn: `docs/design/ban-do-man-hinh.md` (GV-17, GV-18, HT-02..HT-05, luồng L12), `docs/spec/04-luat-nghiep-vu.md` (R-GV-10, R-GV-11, R-V2-35, R-LMS-01..05).

## Khuôn dùng lại (không vẽ khuôn mới)
- GV-17: Biểu mẫu K07 (bản điện thoại từng nhóm trường), hộp xác nhận K08, khung cổng giáo viên KG, thanh dưới.
- GV-18: Tác vụ di động từng bước K12 (điện thoại), Bảng chấm nhanh K14 (laptop), hộp rời màn chưa lưu theo K14.
- Màn kế nối: HT-03 (học sinh xem bài), HT-05 (học sinh xem kết quả), GV-08 (chấm BTVN buổi trước, năm trạng thái), GV-06 (nội dung buổi và BTVN).
- Chỗ khung hiện chưa có (cần Design vẽ): toàn bộ hai màn dưới đây, kể cả trạng thái trống, lỗi, tải.

## GV-17 Giao bài trên LMS

**Mục đích:** giáo viên giao bài tập về nhà có đề và tệp cho cả lớp hoặc từng em, đặt hạn nộp; học sinh thấy bài ở HT-02/HT-03.
**Ai dùng:** giáo viên và trợ giảng được phân vào lớp. Chỉ thấy lớp mình (R-GV-08).
**Vào từ:** GV-06 (mục BTVN của buổi), chi tiết lớp (GV-02), hoặc nút Giao bài ở Việc cần làm.
**Trường:**
1. Lớp và buổi giao (điền sẵn từ nơi vào, đổi được trong lớp mình).
2. Giao cho: «Cả lớp» (mặc định) hoặc «Chọn từng em» (danh sách em có tích; em vắng buổi giao vẫn chọn được).
3. Tiêu đề bài (bắt buộc), mô tả/đề bài (chữ, bắt buộc có chữ hoặc tệp).
4. Tệp đính kèm: ảnh và PDF; tối đa 10 MB mỗi tệp (R-LMS-04). Hiện tên, dung lượng, nút Xoá từng tệp, thanh tiến độ tải.
5. Hạn nộp: ngày giờ; mặc định = giờ vào buổi sau (R-LMS-01); giáo viên đổi được; không được trước thời điểm giao.
6. Công tắc «Cho nộp lại» (R-LMS-01, R-LMS-03).
7. Công tắc «Nhận bài muộn» (R-LMS-01, R-LMS-02); tắt thì quá hạn học sinh không nộp được.
**Thao tác:** Giao (hộp K08 xác nhận: số em nhận, hạn nộp); Lưu nháp; Huỷ (hỏi khi đã nhập dở); Sửa bài đã giao (đổi hạn, mô tả, thêm tệp; ghi rõ sửa sau khi giao có thông báo học sinh hay không, Design đề xuất); Gỡ bài (chỉ khi chưa có em nào nộp).
**Trạng thái cần vẽ:** form trống; có lỗi từng trường (thiếu tiêu đề, tệp quá 10 MB, hạn trong quá khứ); đang tải tệp; đang lưu (khoá nút); lỗi mạng kèm Thử lại; giao thành công; bài đã có em nộp (hạn và tệp cũ khoá hoặc cảnh báo); danh sách «Bài đã giao» của lớp (mỗi dòng: tiêu đề, hạn, «đã nộp/đã giao», trạng thái Nháp / Đang mở / Quá hạn / Đã chấm hết) làm màn vào của GV-17.
**Luật:** R-LMS-01 (giao cả lớp hoặc từng em, hạn mặc định, hai công tắc, bản đầu soạn đề mỗi lần chưa có kho đề), R-GV-10 (BTVN giao ở buổi N chấm ở buổi N+1, hạn chấm theo `teacher_session_complete_hours`; khi có LMS xét lại hạn riêng, mục cần anh chốt bên dưới), R-LMS-04 (10 MB mỗi tệp, 20 trang mỗi bài), R-V2-35 (BTVN tuỳ giáo viên, không có ô «không giao BTVN»), R-LMS-05 (công tắc tính năng theo cơ sở: cơ sở tắt thì không hiện màn).

## GV-18 Chấm bài nộp online

**Mục đích:** giáo viên xem ảnh/tệp học sinh nộp, cho điểm, chọn trạng thái, viết lời phê; kết quả hiện ở HT-05.
**Ai dùng:** giáo viên và trợ giảng của lớp.
**Vào từ:** Việc cần làm (GV-08 khi bài có nộp online), danh sách «Bài đã giao» của GV-17.
**Màn danh sách em của một bài:** thanh tiến độ «đã chấm x/y»; mỗi em một dòng: tên, nhãn trạng thái nộp (Chưa nộp, Đã nộp, **Nộp muộn** là nhãn không phải trạng thái, R-LMS-02), trạng thái chấm; lọc nhanh Chưa chấm / Đã chấm.
**Màn chấm một em (điện thoại K12, từng bước):**
1. Xem bài nộp: ảnh nhiều trang (lướt, phóng to, xoay), tệp PDF; ghi số lần nộp lại và giờ nộp.
2. Điểm thang 1–5 (R-GV-11).
3. Trạng thái BTVN (đúng năm trạng thái của R-GV-11): Đã chấm, Làm chưa xong (vẫn có điểm), Không làm, Nộp sau, Không áp dụng. Em chưa nộp tới lúc chấm: giáo viên chọn «Nộp sau» hoặc «Không làm» (R-LMS-02).
4. Lời phê (chữ, tuỳ chọn).
**Thao tác:** Lưu; «Lưu và em tiếp theo» (lưu từng em, QĐ-Đ18; không tự lưu); Bài tiếp theo / Quay lại danh sách; Mở lại bài đã chấm (R-LMS-03: chấm rồi thì khoá, giáo viên mở lại được).
**Laptop (K14):** hàng = em, cột = trạng thái, điểm; ngăn bên xem bài nộp của em đang chọn; phím số, Tab; bấm Lưu để lưu cả bảng; rời màn chưa lưu thì hộp thoại hỏi.
**Trạng thái cần vẽ:** danh sách trống (chưa giao hoặc chưa ai nộp); ảnh đang tải hoặc lỗi tải ảnh, Thử lại; em chưa nộp; em nộp muộn; bài đã chấm (khoá, nút Mở lại); đang lưu; lỗi mạng; hết bài cần chấm («Đã chấm hết bài của lớp»); chưa lưu mà rời màn.
**Luật:** R-GV-10 (hạn chấm), R-GV-11 (thang 1–5, năm trạng thái, em vắng buổi giao bài mặc định Không áp dụng, giáo viên đổi được), R-LMS-02 (nhãn Nộp muộn), R-LMS-03 (nộp lại không giới hạn trước khi chấm; chấm rồi khoá, giáo viên mở lại được), R-LMS-04, QĐ-Đ60 (bài của em vắng buổi chấm vẫn vào Việc cần làm như Nộp sau).
**Quyền:** chỉ giáo viên/trợ giảng của lớp; học sinh không thấy bài của em khác.

## Điểm cần anh chốt trước khi Design vẽ (Code chưa tự quyết)
1. Hạn chấm khi có LMS: giữ R-GV-10 (chấm trong hạn hoàn tất buổi N+1) hay đặt hạn riêng (R-GV-10 ghi «xét lại»).
2. Sửa bài đã giao: có thông báo học sinh hay không; có cho đổi hạn sau khi đã có em nộp hay không.
3. Chấm AI (QĐ-Đ62, Đ63, Đ64) nằm ngoài khung này; không vẽ ô AI ở bản đầu.
4. Kho đề: bản đầu soạn đề mỗi lần (R-LMS-01); không vẽ chọn từ kho.
5. Cổng phụ huynh (PH-02) xem điểm: ngoài phạm vi hai khung này.

## Việc của Code khi có khung
Dựng hai màn trong `src/pages/gv/`, thêm bảng LMS và hàm giao/chấm (migration dải 500–549), pgTAP quyền theo lớp, e2e điện thoại. Làm sau khi anh duyệt kịch bản và Design vẽ xong.
