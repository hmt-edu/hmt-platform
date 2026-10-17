# P5b: Đào tạo (Ghi danh, Lớp, Buổi, Tái tục)

(Dán sau brief chung.)

Canvas: **"P5b Đào tạo"**. Giai đoạn 2 (máy tính, vài màn dùng cả điện thoại). Mã màn: **GD-01 đến GD-07, LOP-01 đến LOP-10, BUOI-01 đến BUOI-14, TT-01 đến TT-03.**

**Mức A:** GD-02 Ghi danh (bản ghi), GD-03 Xếp lớp, LOP-02 Lớp (bản ghi), LOP-04 Thời khoá biểu lớp, LOP-08 Lịch tuần cơ sở (K05), BUOI-02 Buổi học (bản ghi), BUOI-04 Huỷ buổi.
**Mức B:** GD-01, GD-04, GD-05, GD-06, GD-07; LOP-01 (danh sách và kanban theo bước duyệt), LOP-03, LOP-05, LOP-06, LOP-07, LOP-10; BUOI-01, BUOI-03 (K12), BUOI-05 đến BUOI-13; TT-01 (danh sách và kanban L1–L8), TT-02.
**Mức C: không vẽ**, ghi dựng từ khuôn nào: LOP-09, BUOI-14, TT-03.

**Chú ý riêng**
- **Một ghi danh = một lớp = một quỹ giờ** (04e). **GD-02 Ghi danh (bản ghi), phần quan trọng nhất:** quỹ giờ (cấp, đã học, còn lại, giờ tặng), lớp đang học và lịch sử chuyển lớp (dòng xếp lớp: ngày vào, ngày rời), Start Date, End Date (dự kiến, chỉ dự báo), sổ giờ, ticket liên quan. Hành động: Xếp lớp, Điều chỉnh giờ, Tạo ticket. Dùng cách thể hiện của P4 HS-02.
- **Lớp Toán Đại + Hình và nhóm lớp (04g, R-LOP-13, R-LOP-14):** từ khối 7 (tham số `algebra_geometry_split_grade`) lớp chung Toán là hai lớp **độc lập** `DAI` và `HINH` (giáo viên, lịch, khung chương trình, sĩ số, bước duyệt riêng; có thể một giáo viên dạy cả hai hoặc mỗi lớp một giáo viên). Hai lớp được **gắn vào một "nhóm lớp"**. Nhóm **không có mã riêng**: mã lớp giữ đúng quy định (ví dụ `CS5-2627-DAI-K09-CB-A-001` và `CS5-2627-HINH-K09-CB-A-001`). **Tên chung của nhóm** (ví dụ 9M1) là tham chiếu tự do, tuỳ chọn, hiện nhỏ dưới mã lớp giống "tên cũ". Học sinh có thể chỉ học Đại hoặc chỉ học Hình trong nhóm; sĩ số tính riêng từng lớp.
- **Mã lớp cũ (04g, R-LOP-15):** màn **LOP-02** có ô **"Mã cũ (Sheet)"** cạnh mã lớp, chỉ xem (người thường không sửa; Admin sửa được). Ô tìm của **LOP-01** gõ mã cũ ra đúng lớp (ghi trong chú thích ô tìm). Đây là mã lớp ở Google Sheet cũ, khác "tên chung của nhóm". Phụ huynh không có mã cũ. Ở các màn khác, mã cũ (nếu có) hiện nhỏ dưới mã mới theo spec 02.
- **LOP-03 Tạo lớp:** thêm ô "Nhóm lớp" (chọn nhóm có sẵn hoặc tạo nhóm mới, tên chung tuỳ chọn) và nút "Tạo lớp còn lại cho nhóm này" (tạo nhanh lớp Hình khi vừa tạo lớp Đại, và ngược lại). Môn là TOAN, DAI, HINH, ...; chặn môn theo khối khi tạo lớp là **đề xuất chờ anh duyệt**; lớp riêng khối 7+ giữ một lớp `TOAN`.
- **LOP-04 Thời khoá biểu:** mỗi khung giờ có giờ, giáo viên, trợ giảng, phòng, **"Lặp mỗi N tuần"** (mặc định 1 = hàng tuần) và **"Buổi đầu tiên vào ngày"**. Luân phiên Đại, Hình: hai lớp cùng thứ, giờ, phòng, cùng lặp mỗi 2 tuần, buổi đầu cách nhau 1 tuần. Xem trước ngày kết thúc và các buổi sẽ sinh. Cảnh báo trùng phòng, trùng giờ tính ở cấp buổi thật: luân phiên không báo trùng. Vẽ một ví dụ luân phiên và một ví dụ hai buổi khác thứ.
- **GD-03 Xếp lớp (cho ghi danh chưa có lớp):** chọn **nhóm lớp** (xếp ghi danh Đại vào lớp DAI, ghi danh Hình vào lớp HINH, học sinh chỉ có một ghi danh thì chỉ xếp lớp tương ứng) hoặc chọn một lớp lẻ; kiểm đúng môn, loại lớp, cơ sở, **trùng giờ ở cấp buổi** (R-GD-15, luân phiên hợp lệ); chọn ngày vào lớp (R-GD-06). Học sinh Toán 7+ mới có Đại hoặc Hình: chỉ nhắc mềm, không chặn.
- **LOP-08 Lịch tuần cơ sở:** hai lớp cùng nhóm cùng màu viền; luân phiên hiện đúng buổi của từng tuần.
- **GD-04 Sổ giờ:** chỉ thêm dòng, không sửa; mỗi dòng ghi nguồn (buổi, phiếu thu, điều chỉnh). GD-05: điều chỉnh bằng dòng ngược dấu, bắt buộc lý do.
- **GD-07 và TT-01, TT-02:** dự báo hết giờ theo ghi danh (cũng là theo lớp); **một phiếu tái tục cho mỗi ghi danh**, nên học sinh Đại + Hình có thể có hai phiếu (CSKH gộp khi báo giá). Quá hạn gói mà còn giờ vẫn học (R-GD-07). Chờ anh duyệt (04e mục 3).
- **LOP-02:** thanh trạng thái duyệt (Nháp, Đã trình, Đã xác nhận, Đã duyệt, Từ chối, Đóng, Huỷ); duyệt bắt buộc có thời khoá biểu và **tự sinh buổi** (xem trước số buổi). Hiện nhóm lớp và lớp còn lại của nhóm (liên kết).
- **BUOI-02:** thanh Nháp → Đã chốt → Done và nhánh huỷ; danh sách em; em không vào danh sách kèm lý do; điểm danh **hai cột** (vận hành, giáo viên chính thức); giờ trừ vào quỹ ghi danh của lớp đó. BUOI-03 và BUOI-11: điểm danh vận hành, lý do liên hệ, dùng khuôn K12 cho điện thoại.
- **BUOI-04 Huỷ buổi:** hai nhánh: trung tâm huỷ (không tính phí, tự thêm buổi cuối, dời bài) và học sinh huỷ lớp riêng (người huỷ chọn có hoặc không tính phí, bắt buộc lý do).
- **BUOI-07 đến BUOI-10:** học bù (không trừ giờ), củng cố (tính tiền như buổi thường, bắt buộc ghi nhận phụ huynh đồng ý), bổ trợ (không trừ giờ, tính giờ dạy giáo viên); danh sách yêu cầu: chỉ Trưởng cơ sở duyệt, CSKH xem.

Nối với: nhóm A, B, D, E, F, G, I. Thứ tự: Lớp (LOP) → Buổi (BUOI) → Ghi danh (GD) → Tái tục (TT); giao diện Ghi danh nên vẽ sớm để khớp với đơn ở P5a.
