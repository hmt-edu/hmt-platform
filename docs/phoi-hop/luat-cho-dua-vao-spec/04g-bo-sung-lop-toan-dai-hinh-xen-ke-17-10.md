# Bổ sung luật 17/10/2026: lớp Toán Đại + Hình học xen kẽ, nhóm lớp, mã cũ

Anh Trường đã nói "OK ĐƯA VÀO LUẬT" ngày 17/10/2026 (15:53, thêm mục 3 lúc 15:57). File này **bổ sung sau** `04e`. Khi Code đưa vào repo: sửa R-LOP-08, R-LOP-09, R-GD-15 trong `docs/spec/04-luat-nghiep-vu.md` (ghi "(17/10)"), thêm R-LOP-13, R-LOP-14, R-LOP-15, R-CRM-33; sửa `docs/spec/02-chuan-ma-va-danh-muc.md` mục "Toán tách Đại số và Hình học" (thêm nhóm lớp), dòng mã lớp (ghi chú nhóm) và mục "Mã cũ" (bỏ `CUST-…`, phụ huynh không có mã cũ); sửa `docs/design/ban-do-man-hinh.md` (LOP-02, LOP-03, LOP-04, LOP-08, GD-03, KH-05); không giữ file riêng. Repo là bản đúng.

## 1. Vấn đề
Lớp chung Toán khối 7+ chia thành hai lớp độc lập `DAI` và `HINH` (spec 02). Thực tế một nhóm học sinh (ví dụ tên cũ 9M1) học cả hai: có khi Đại và Hình khác giờ trong tuần, có khi **cùng thứ, cùng giờ và luân phiên** (tuần này Đại, tuần sau Hình). Lịch hàng tuần cũ không biểu diễn được luân phiên, và luật R-GD-15 (chặn trùng giờ) sẽ chặn nhầm học sinh vào cả hai lớp. Một học sinh có thể chỉ học Đại hoặc chỉ học Hình trong nhóm.

## 2. Sửa luật đã có

| Mã | Sửa thành | |
|---|---|---|
| R-LOP-08 | **(17/10)** Thời khoá biểu: mỗi thứ có thể nhiều khung giờ; mỗi khung có giờ, giáo viên, trợ giảng, phòng riêng, **cách lặp** (R-LOP-13). Trùng phòng thì cảnh báo, không chặn; **kiểm trùng ở cấp buổi thật** (cùng ngày, cùng giờ), không kiểm ở cấp khung, nên hai lớp luân phiên cùng khung giờ không bị coi là trùng. | [CHỐT] |
| R-LOP-09 | **(17/10)** Ngày kết thúc dự kiến: chạy lịch từ ngày bắt đầu, lấy các thứ trong thời khoá biểu **theo cách lặp của từng khung**, bỏ ngày nghỉ lễ (bảng ngày nghỉ), đếm đủ số buổi. | [CHỐT] |
| R-GD-15 | **(17/10)** Xếp lớp **chặn** nếu có **buổi trùng giờ** (cùng ngày, cùng giờ, tính cả buổi sắp sinh theo lịch) với lớp em đang học, kể cả lớp của ghi danh khác. Lớp trùng vẫn hiện nhưng không chọn được, kèm lý do. Hai lớp luân phiên (không có buổi nào trùng ngày giờ) không bị chặn. | [CHỐT] |

## 3. Luật mới

| Mã | Luật | |
|---|---|---|
| R-LOP-13 | **(17/10)** **Cách lặp của khung giờ.** Mỗi khung giờ có **"lặp mỗi N tuần"** (N là số nguyên từ 1 đến `class_slot_repeat_weeks_max`, mặc định 1 = hàng tuần) và **"buổi đầu tiên vào ngày …"** (đúng thứ của khung, không trước ngày khai giảng). Luân phiên Đại, Hình: hai lớp cùng thứ, giờ, phòng, cùng lặp mỗi 2 tuần, ngày buổi đầu cách nhau 1 tuần. Duyệt lớp tự sinh buổi theo cách lặp (R-LOP-03). Đổi cách lặp của lớp đã duyệt đi qua luồng đổi lịch cố định (R-LOP-11): xem trước các buổi chưa diễn ra bị đổi rồi sinh lại. | [CHỐT]; tham số `class_slot_repeat_weeks_max` khai báo bằng migration (mặc định 4, khoảng 1–8) |
| R-LOP-14 | **(17/10)** **Nhóm lớp.** Hai lớp Toán `DAI` và `HINH` cùng khối, cùng cơ sở được **gắn vào một nhóm lớp** (nhóm có tối đa một lớp mỗi môn, một lớp không thuộc quá một nhóm). Nhóm **không có mã riêng**; mã mỗi lớp giữ đúng quy định spec 02 (`CS-Năm-Môn-Khối-Phânloại-Trìnhđộ-STT`, số thứ tự cấp riêng cho từng lớp). **Tên chung** của nhóm (ví dụ tên cũ 9M1) là **tham chiếu tự do, tuỳ chọn**, không thay mã, hiện nhỏ dưới mã lớp. Mỗi lớp trong nhóm **vẫn độc lập**: giáo viên, lịch, khung chương trình, sĩ số, bước duyệt riêng. Nhóm dùng để: (1) tạo hai lớp một lần ("Tạo lớp còn lại cho nhóm này"); (2) xếp lớp một lần cho học sinh: chọn nhóm thì hệ thống xếp ghi danh Đại vào lớp DAI, ghi danh Hình vào lớp HINH, học sinh chỉ có một ghi danh thì chỉ xếp lớp tương ứng; (3) hiển thị chung trên lịch và danh sách. Chuyển lớp, đóng lớp, huỷ lớp tính từng lớp, không kéo theo lớp kia. | [CHỐT]; kiểm môn theo khối khi tạo lớp **[CHỜ]** |
| R-LOP-15 | **(17/10, 15:57)** **Mã lớp cũ.** Theo luật chung về mã cũ ở spec 02 (cột `legacy_ref`, tìm kiếm được, hiện nhỏ dưới mã mới), màn chi tiết lớp (LOP-02) hiện rõ ô **"Mã cũ (Sheet)"** cạnh mã lớp; ô tìm của danh sách lớp (LOP-01) gõ mã cũ ra đúng lớp. Người dùng thường không sửa; **đợt chuyển dữ liệu từ Google Sheet điền**, Admin sửa được khi điền sai (ghi nhật ký). Mã mới vẫn là mã chính. Khác với "tên chung của nhóm" (R-LOP-14). | [CHỐT] |
| R-CRM-33 | **(17/10, 15:57)** **Mã học sinh cũ.** Hồ sơ học sinh (KH-05) hiện ô **"Mã cũ (Sheet)"** cạnh mã HS, tìm được ở KH-04; cùng cách dùng như R-LOP-15. **Phụ huynh không có mã cũ** (anh Trường xác nhận 17/10, 17:13: hệ thống Sheet hiện tại không có mã phụ huynh): **sửa spec 02 mục "Mã cũ", bỏ `CUST-…` khỏi danh sách mã cũ**; KH-01, KH-02 không có ô mã cũ (sửa dòng KH-01 trong bản đồ: bỏ "mã cũ" khỏi tìm theo). | [CHỐT] |

## 4. Còn chờ anh
- **Chặn môn theo khối khi tạo lớp** (khối từ `algebra_geometry_split_grade` trở lên không tạo lớp chung `TOAN`, khối dưới không tạo `DAI`, `HINH`, trừ lớp riêng): đề xuất chặn trong hàm tạo lớp, lỗi có mã. **[CHỜ]**
- Mẫu luân phiên không đều (ví dụ chu kỳ 3 tuần: Đại hai buổi, Hình một buổi): anh nói chỉ luân phiên đều; cách lặp N tuần + khung nhiều buổi đã đủ, không làm thêm.

## 5. Việc cho giai đoạn code
- Bảng khung giờ: thêm `repeat_every_weeks smallint default 1`, `first_session_date date`; hàm sinh buổi theo chu kỳ; hàm tính ngày kết thúc dự kiến theo chu kỳ (R-LOP-09); pgTAP: luân phiên Đại, Hình cùng khung giờ không báo trùng; buổi trùng thật thì cảnh báo; xếp lớp học sinh vào hai lớp luân phiên được, vào hai lớp có buổi trùng thì bị chặn.
- Nhóm lớp: bảng nhóm (id, tên chung tuỳ chọn), cột nhóm ở lớp; ràng buộc mỗi nhóm một lớp mỗi môn; chỉ mục theo nhóm; hàm "tạo lớp còn lại", hàm "xếp vào nhóm".
- Mã cũ: `legacy_ref` ở bảng lớp và bảng học sinh (theo quy ước repo đã có chỉ mục); tìm kiếm trong hàm danh sách lớp, học sinh khớp cả mã cũ; chặn sửa `legacy_ref` ngoài Admin và hàm đồng bộ (RLS/hàm), pgTAP.
- Giao diện: LOP-02 thêm ô "Mã cũ (Sheet)"; LOP-03 thêm "Nhóm lớp" (chọn nhóm có sẵn, hoặc tạo nhóm mới, tên chung tuỳ chọn); LOP-04 mỗi khung thêm "Lặp mỗi N tuần" và "Buổi đầu tiên"; GD-03 xếp theo nhóm hoặc theo lớp; LOP-08 hiện hai lớp cùng nhóm cùng màu viền, luân phiên không báo trùng; KH-05 (P4) thêm ô "Mã cũ (Sheet)".
