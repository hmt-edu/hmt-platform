# Đề xuất G1 · Chốt danh sách phải tính giờ đã «giữ chỗ» ở buổi Đã chốt chưa Done (thẻ A29, Code A, 19/11/2026) · CHỜ CHAT DUYỆT, chưa code

Nguồn: Soát S14 (soat.md 19/11 06:28, mục G1, mức Trung bình, đã tái hiện). Luật: R-GIO-03 (không đủ giờ thì không vào danh sách buổi), R-GIO-01, 02, 04 (trừ giờ, chốt danh sách, ghi danh được trừ), R-BUOI-01. Hàm: `app.build_session_roster` (chốt danh sách) và `app.deduct_session_hours` (trừ giờ khi Done), cả hai ở migration 303 (bản mới nhất; gốc 102, 141).

## 1. Lỗi
Em còn 1,5 giờ, mỗi buổi 1,5 giờ. Buổi 1 và buổi 2 đều chốt trước khi buổi 1 Done (giáo viên hoàn tất trễ):
1. Chốt buổi 1: quỹ 1,5 ≥ 1,5 → em vào danh sách. Quỹ vẫn 1,5 (chưa có dòng trừ, chỉ trừ lúc Done).
2. Chốt buổi 2: quỹ vẫn 1,5 → em lại vào danh sách (đáng lẽ không, vì 1,5 giờ đã dành cho buổi 1).
3. Buổi 1 Done: trừ 1,5, quỹ về 0. Buổi 2 Done: `deduct_session_hours` thấy quỹ − 1,5 < 0 → `HMT_QUY_GIO_AM`, **cả buổi kẹt ở Đã chốt**: các em đủ giờ cũng chưa bị trừ, buổi không được đóng dấu (lỗi ghi vào `session_auto_done_error`).

## 2. Nguyên nhân
`build_session_roster` kiểm `app.enrollment_hours_balance(e.id) (+ giờ cho phép học trước) >= giờ buổi`. `enrollment_hours_balance` chỉ cộng sổ giờ (`hour_ledger`); dòng trừ `TRU_BUOI` chỉ ghi ở `deduct_session_hours` lúc Done. Buổi Đã chốt chưa Done của cùng ghi danh đã «giữ chỗ» nhưng chưa có dòng trừ nên không được tính.

## 3. Phương án đề xuất (của Soát, em đồng ý): tính giờ giữ chỗ lúc chốt
Thêm hàm `app.enrollment_hours_reserved(p_enrollment_id uuid, p_session_id uuid)`: tổng giờ (`app.session_hours`) của các buổi **khác** mà ghi danh này đang nằm trong danh sách (`session_attendance.is_active`, không học thử), buổi **trừ giờ** (`app.session_deducts_hours(buổi)`, tức không phải học bù/bổ trợ/kiểm tra bù), đang **Đã chốt (`DA_CHOT`) chưa Done**, và **diễn ra trước** buổi đang chốt (ngày rồi giờ bắt đầu; bằng nhau thì theo mã buổi) để chốt buổi sớm sau buổi muộn không đẩy em ra khỏi buổi sớm.
`build_session_roster` đổi điều kiện thành: `balance − reserved + (pay_later ? max_sessions_ahead × giờ buổi : 0) ≥ giờ buổi`. Em không đủ thì như cũ: không vào danh sách, lý do `HET_GIO` (R-GIO-03). `deduct_session_hours` giữ nguyên (vẫn chặn âm như lớp bảo vệ cuối).
- Không viết lại dữ liệu cũ: chỉ áp dụng cho lần chốt từ khi có migration; buổi đã chốt trước đó giữ danh sách.
- Hàm chỉ đọc, `stable`, dùng chỉ mục sẵn có của `session_attendance` (theo ghi danh và theo buổi); mỗi lần chốt một lớp ≤ vài chục em, vài truy vấn nhỏ.

## 4. Phương án khác đã cân nhắc, không chọn
- **Trừ ngay lúc chốt** (ghi `hour_ledger` khi chốt, hoàn lại nếu huỷ): đổi luật trừ giờ lõi (R-GIO-01: trừ khi Done), đụng huỷ buổi, hoàn phí, báo cáo giờ: rủi ro rất lớn.
- **Done loại riêng em thiếu giờ và vẫn đóng buổi:** làm sai luật «chỉ trừ cho em trong danh sách», che lỗi dữ liệu giờ; không chọn.

## 5. Ca kiểm pgTAP (tên bài ghi luật bằng tiếng Việt)
1. Em 1,5 giờ, hai buổi 1,5 giờ cùng chốt: buổi 2 loại em (HET_GIO), em 2 (10 giờ) vẫn vào (R-GIO-03).
2. Buổi 1 huỷ không tính phí (hết giữ chỗ): chốt buổi 2 sau đó, em vào.
3. Buổi 1 đã Done (có dòng trừ): chốt buổi 2 như cũ, không trừ đôi giữ chỗ.
4. Buổi 1 là Học bù, hoặc kiểm tra bù `no_charge`: không giữ chỗ (R-BUOI-03), buổi 2 chốt bình thường.
5. Học trước (pay_later) còn hạn mức: giữ chỗ vẫn tính vào hạn mức.
6. Chốt buổi sớm sau buổi muộn: em vẫn vào buổi sớm (chỉ tính buổi diễn ra trước).
7. Tái hiện đúng kịch bản Soát: `auto_complete_sessions` cả hai buổi Done, không kẹt, em 2 bị trừ đủ hai lần.

## 6. Rủi ro và việc cần duyệt
- Mức CAO (lõi giờ): sửa `build_session_roster` (hàm lớn, đã chạm ở 303); cần Tester ĐẠT và chạy cả bộ pgTAP.
- Em chưa Done nhưng quá muộn: giữ chỗ kéo dài làm các buổi sau của em bị loại khỏi danh sách cho tới khi buổi trước Done hoặc huỷ: đây là mong muốn của R-GIO-03, nhưng nên có nhắc ở GV-12 «Buổi chưa hoàn tất» (đã có).
- Câu hỏi cho Chat/anh: (1) đồng ý phương án mục 3? (2) buổi **kiểm tra trừ giờ như buổi Chính** có giữ chỗ như buổi Chính (đề xuất: có)? (3) cho cả lớp riêng LR hay chỉ lớp thường (đề xuất: mọi lớp).
