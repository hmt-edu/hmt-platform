# Hướng dẫn nạp dữ liệu đào tạo ngày 17/11/2026

Dành cho người chuẩn bị file và người nạp dữ liệu. Không cần biết lập trình. Chỉ quản trị viên (Admin) được nạp. Diễn tập trên staging trước (14/11); nạp thật trên bản chạy thật do anh Trường làm.

## 1. Ai làm gì

| Việc | Ai | Khi nào |
| --- | --- | --- |
| Điền file mẫu bằng dữ liệu thật của cơ sở | Người phụ trách dữ liệu của cơ sở, anh Trường duyệt | Trước 13/11 |
| Diễn tập trên staging bằng file dữ liệu GIẢ | Admin | 14/11 |
| Nạp thật trên bản chạy thật | Anh Trường | 17/11 |

File mẫu: `docs/van-hanh/mau/HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx` (toàn dữ liệu giả). Không đưa file có tên, số điện thoại thật vào repo, vào chat hay vào staging. File thật chỉ nằm trên máy anh Trường.

## 2. Thứ tự nạp

Nạp đúng thứ tự, vì tab sau cần tab trước đã có:

1. Người dùng (giáo viên cần có mã nhân sự dạng GV2001).
2. **Lớp** (tab 03_LOP).
3. Phụ huynh (01_PHUHUYNH) rồi Học sinh (02_HOCSINH).
4. **Ghi danh** (tab 04_GHIDANH): tạo ghi danh, xếp lớp và dòng "Số dư đầu kỳ" cho giờ còn lại.
5. Tab 09_SODU (số dư học phí bằng tiền) **không nạp ngày 17/11** (Q-227, mục 8).
6. **Buổi học** (07_BUOIHOC) và **Điểm danh** (08_DIEMDANH): chỉ để đối soát, không tạo buổi, không trừ giờ.

Mỗi tab: bấm **Xem trước** trước. Xem trước không ghi gì; chỉ khi báo cáo không còn lỗi (hoặc lỗi đã hiểu rõ) mới bấm **Nạp**.

## 3. Cột bắt buộc

### Tab 03_LOP (Lớp)

| Cột | Điền gì | Bắt buộc |
| --- | --- | --- |
| ma_lop_cu | Mã lớp ở hệ thống cũ, ví dụ 4M1. Không đổi sau khi nạp | Có |
| loai_lop | "Lớp chung" hoặc "Lớp riêng" | Có |
| phan_loai | CB (Cơ bản) hoặc NC (Nâng cao). Lớp riêng để trống | Lớp chung |
| trinh_do | S, A, B... (theo danh mục Trình độ). Lớp riêng để trống | Lớp chung |
| nam_hoc | 4 số, ví dụ 2627 cho năm 2026-2027 | Có |
| mon, khoi | Môn (Toán, Vật lý...) và khối (số 2 đến 12) | Có |
| lich_hoc | Đúng dạng `Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30)`. Nhiều khung ngăn bằng dấu `;`. Chủ nhật viết `Chủ nhật` | Có |
| so_buoi | **Số buổi CÒN LẠI kể từ 17/11/2026**, không phải tổng số buổi cả khoá | Có |
| ma_gv | Số nhân sự của giáo viên, ví dụ 2001 (hệ thống ghép với mã GV2001) | Nên có |
| ngay_khai_giang, si_so_toi_da, tinh_trang, co_so | Ngày khai giảng gốc, sĩ số, "Đang chạy" hoặc "Đã đóng", mã cơ sở (CS1...) | Có |

Hệ thống chỉ sinh buổi từ 17/11/2026 trở đi. Buổi trước ngày đó không được sinh, nên không bị trừ giờ lần hai.

**Đặt các cột `nam_hoc`, `ma_gv`, `ma_ql_lop` dạng văn bản** trong Excel (nếu để dạng số, `2627` giữ được nhưng `0043` mất số 0 đầu).

**Lớp riêng (mã LR…)** để ngoài file nạp thử và nạp tay sau, vì hàm hiện nạp như lớp thường (Q-239). Ngày khai giảng sai dạng (ví dụ `CN - 12/7`) và tình trạng lớp để trống là **lỗi**, chặn dòng đó (Q-238): sửa lại trong file rồi nạp lại.

### Tab 04_GHIDANH (Ghi danh)

| Cột | Điền gì | Bắt buộc |
| --- | --- | --- |
| hoc_sinh_ma_cu, ma_lop_cu | Mã học sinh cũ và mã lớp cũ (lớp, học sinh đã nạp) | Có |
| tinh_trang_moi | Đang học, Bảo lưu, Hoàn thành, Chuyển lớp, Dừng, Hoàn phí hoặc Chờ xếp lớp | Có |
| ngay_vao_lop | yyyy-mm-dd | Với Đang học, Bảo lưu |
| thoi_luong_buoi | Số giờ mỗi buổi, ví dụ 2.5 | Có |
| gio_du_kien, gio_da_hoc, gio_con_lai | Giờ đã mua, đã học, còn lại. **gio_con_lai phải đúng bằng gio_du_kien trừ gio_da_hoc** | Có |

Mỗi dòng ghi danh sinh **một** dòng "Số dư đầu kỳ" bằng gio_con_lai, mang ngày 17/11/2026.

**Không nạp số âm ở `gio_con_lai`** (số từ 0 trở lên; anh Trường xác nhận không có em nào âm giờ, Q-253): số âm báo lỗi `HMT_NAP_GIO_AM`. Giờ còn lại bằng 0 vẫn sinh dòng "Số dư đầu kỳ" 0 giờ. **Ghi danh còn một dòng lỗi thì Nạp bị chặn cả loại** (không ghi dòng nào, kể cả dòng đúng): sửa hết lỗi trong báo cáo Xem trước rồi mới nạp. Cột `ngay_chot` trong tab này chỉ để tham khảo: hàm lấy ngày chốt từ tham số `opening_balance_date`, để trống cũng không sao. Cột `tinh_trang_moi` nên luôn điền; nếu để trống, hàm đặt tình trạng **Chờ xếp lớp** (không báo lỗi, có cảnh báo), nên kiểm lại báo cáo xem trước. Giá trị "Đã xếp lớp" (script sinh ra) thành **Đang học** nếu có `ngay_vao_lop`, không thì **Chờ xếp lớp**.

### Tab 07_BUOIHOC và 08_DIEMDANH

Giữ nguyên cột như file mẫu. Các cột số (`so_x`, `so_P`, `so_KP`, `so_N`, `so_M`) phải từ 0 trở lên: số âm báo lỗi hệ thống mã 23514, hãy sửa lại thành số không âm (Q-253). Tab 07 để trống `tinh_trang` vẫn nạp được; tab 08 ký hiệu lạ vẫn nạp được, vì hai tab này chỉ để đối soát. Buổi nghỉ lễ ghi tình trạng "Huỷ không tính phí": hệ thống ghi nhận là buổi huỷ, không điểm danh, giờ trừ 0, không tạo buổi bù. Cột `tinh_gio` của tab 08 ghi "Có" hoặc "Không" (x, P, KP, M tính giờ; N không tính).

## 4. Đọc báo cáo sau khi bấm Xem trước hoặc Nạp

Báo cáo cho biết: số dòng hợp lệ, số dòng trùng (đã nạp trước đó, bỏ qua, không ghi đè), số dòng lỗi.

- **Lỗi theo từng loại**: mỗi loại lỗi kèm danh sách số dòng.
- **Lớp chưa có giáo viên**: danh sách mã lớp cũ chưa ghép được giáo viên. Lớp vẫn được nạp, nhưng khung giờ chưa có giáo viên: cần gán sau.

## 5. Lỗi thường gặp và cách sửa

| Thông báo | Nghĩa là | Cách sửa rồi nạp lại |
| --- | --- | --- |
| Thiếu giá trị cột X | Ô bắt buộc để trống | Điền ô đó trong file |
| Lịch học sai dạng | `lich_hoc` không đúng dạng mẫu | Viết lại đúng `Thứ 5 (19h00-21h00)` |
| Cột so_buoi phải lớn hơn 0 | Điền 0 hoặc để chữ | Điền số buổi còn lại, từ 1 trở lên |
| Lớp chung cần cột phan_loai | Thiếu CB hoặc NC | Điền phan_loai, trinh_do |
| Giờ còn lại phải bằng giờ dự kiến trừ giờ đã học | Ba cột giờ không khớp | Kiểm lại số liệu, sửa cho khớp |
| Không tìm thấy học sinh / lớp | Chưa nạp tab Học sinh hoặc Lớp | Nạp tab trước rồi nạp lại tab này |
| Cột ngay phải có dạng yyyy-mm-dd | Ngày sai dạng | Sửa thành ví dụ 2026-11-17 |

**Cách sửa và nạp lại:** sửa các dòng lỗi trong file, giữ nguyên các dòng đã đúng, rồi nạp lại cả file. Dòng đã nạp được nhận ra qua mã cũ và bỏ qua (báo là "trùng"), không bị nạp hai lần. Chỉ dòng chưa nạp mới được ghi.

## 6. Ngày chốt 17/11/2026

Ngày này là tham số **Ngày chốt số dư đầu kỳ** (`opening_balance_date`) trong Cài đặt. Chỉ Admin sửa, mọi lần sửa đều ghi nhật ký. Không sửa giữa lúc đang nạp.

## 7. Chế độ Done buổi học giai đoạn đầu

Giai đoạn đầu, khi giáo viên chưa chấm nhận xét trên cổng giáo viên, tham số **Done buổi cần nhận xét hoặc điểm** (`session_done_requires_review`) ở trạng thái **Tắt** trên staging và bản chạy thật. Khi Tắt, buổi vẫn Done khi giáo viên đã điểm danh xong, giờ vẫn trừ. (Từ khi PR Nội dung buổi vào main, buổi thường cần thêm ít nhất một dòng nội dung buổi, cả khi Bật lẫn Tắt; buổi Kiểm tra không đòi dòng nội dung. Q-231, Q-252.)

- **Đã đặt Tắt bằng migration, không phải bước làm tay (Q-198):** migration `20261111000110_bat_van_hanh_lop_cs5.sql` (số 110) chạy lệnh `update app.setting_def set value = 'false' where key = 'session_done_requires_review'`. Đây là giá trị chung của mọi cơ sở, không ghi đè theo cơ sở, và có hiệu lực trên mỗi môi trường ngay khi migration được áp (staging khi gộp vào `main`; bản chạy thật khi anh chạy workflow bản chạy thật). Anh không cần vào đâu để đặt.
- **Kiểm:** chạy khối (d) trong `docs/van-hanh/sql-kiem-hmt-prod-chi-doc.sql` (chỉ đọc) rồi xem dòng `session_done_requires_review`: phải là `false` và cột `lech` là «khớp». Bảng cờ và tham số cần có cho CS5: `docs/van-hanh/cau-hinh-cs5.md`.
- **Bật lại** khi tính năng chấm nhận xét của giáo viên sẵn sàng (sau 17/11): cần **migration mới** đặt lại thành `true`. Màn Cài đặt (QT-09, «Tham số nghiệp vụ») chưa có (hiện chỉ là mục giữ chỗ trong menu, làm sau 17/11), nên chưa thể bật hay tắt bằng giao diện. Từ lúc Bật, buổi thường chỉ Done khi không còn ô nhận xét "Chưa đánh giá", buổi Kiểm tra khi mọi em có mặt đã được chấm. Buổi đã Done trước đó không bị ảnh hưởng. Khi Bật còn thêm điều kiện chấm BTVN buổi trước, nếu buổi trước có giao BTVN (Q-272).

## 8. Số dư tiền không nạp ngày 17/11 (Q-227)

Ngày 17/11 **chỉ nạp GIỜ** (từ `gio_con_lai` ở tab 04_GHIDANH). Tab 09_SODU (tiền thu thừa, công nợ phải thu đầu kỳ) **không nạp** ngày 17/11: các khoản này ghi tay (R-V2-24) và sẽ nạp tự động sau 17/11. Đây là quyết định vận hành, không đưa vào spec 04.

## 8b. Kiểm trước khi nạp (lệnh chỉ đọc)

Trước khi bấm **Nạp thật**, chạy `docs/van-hanh/sql-kiem-truoc-nap.sql` trong SQL Editor của project cần nạp (chỉ có câu SELECT; không in họ tên, số điện thoại). Sáu khối: (a) bản cập nhật cuối, (b) cờ `VAN_HANH_LOP` từng cơ sở, (c) tham số `import_max_rows`, `opening_balance_date`, `session_done_requires_review`, (d) danh mục tối thiểu, (e) đã nạp bao nhiêu hồ sơ từ dữ liệu cũ, (f) Admin đã xác thực hai bước. Cột `dat` là `false` ở khối nào thì sửa khối đó trước khi nạp; gửi Chat ảnh chụp kết quả.

## 9. Bật phân hệ Vận hành lớp cho từng cơ sở (làm trước khi nạp)

Hàm nạp Lớp, Ghi danh, Buổi, Điểm danh kiểm công tắc tính năng `VAN_HANH_LOP` của cơ sở trong file. Cơ sở chưa bật thì dòng bị từ chối với mã `HMT_TINH_NANG_TAT` («Phân hệ Vận hành lớp … chưa bật ở cơ sở CS5»). Trên staging và bản chạy thật phải bật công tắc **từng cơ sở** có trong file trước khi nạp.

- **Cách bật (Q-262):** công tắc `VAN_HANH_LOP` bật bằng **migration** (qua PR duyệt như mọi thay đổi cấu trúc), không bấm tay trên giao diện và không sửa tay cơ sở dữ liệu chạy thật. **CS5 bật trước.** Cơ sở khác chỉ bật khi anh Trường xác nhận cơ sở đó có trong file nạp. Công tắc là một dòng trong bảng `app.feature_flag` (phân hệ × cơ sở); migration chỉ bật, chạy lại không lỗi.
- **Áp cho cả staging lẫn bản chạy thật:** cờ bật ngay khi migration được áp lên môi trường đó (staging khi gộp vào `main`; bản chạy thật khi anh Trường chạy workflow bản chạy thật). Vì vậy bật xong trên bản chạy thật là người dùng CS5 thấy phân hệ Vận hành lớp; chỉ nên gộp migration đó khi sẵn sàng.
- Màn công tắc theo bản đồ màn hình là **QT-10 «Công tắc tính năng theo cơ sở»**; màn này làm **sau 17/11**.

## 10. Nạp hỏng giữa chừng: DB còn lại gì và làm gì

Viết 13/11/2026 theo thử thật trên cơ sở dữ liệu cục bộ với dữ liệu giả (phiếu dieu-phoi-kit#275), kèm đọc mã. Mỗi bảng dưới đây ghi rõ điều nào đã **thử thật** và điều nào **chỉ đọc mã**. Quay lại bản sao lưu khi deploy lỗi: `docs/van-hanh/quay-lai-khi-deploy-loi.md`.

**Quy tắc ngắn:** bấm **Xem trước** trước, chỉ bấm **Nạp** khi báo cáo xem trước có 0 lỗi. Nạp cùng một file nhiều lần không sinh trùng, nên nạp lại là cách làm lại an toàn.

### 10.1. Phụ huynh, Học sinh, Cơ hội, Lớp, Ghi danh, Buổi học, Điểm danh (hàm trong cơ sở dữ liệu)

Bảy loại này dùng cùng một cách chạy: **một lần bấm Nạp là một lần gọi, một giao dịch**; trong đó mỗi dòng được thử riêng, dòng lỗi bị bỏ qua và dòng đúng được giữ.

| Triệu chứng | Cơ sở dữ liệu còn lại gì | Làm gì | Ai |
| --- | --- | --- | --- |
| Nạp xong nhưng báo cáo ghi «lỗi N dòng» (N lớn hơn 0) | **Giữ một phần:** các dòng đúng ĐÃ được ghi, các dòng lỗi KHÔNG ghi gì. Nhật ký nạp (`import_log`) có một dòng cho cả lần nạp, ghi số dòng, số nạp được, số trùng, số lỗi | Sửa các dòng lỗi trong file (xem mục 5), giữ nguyên dòng đúng, **nạp lại cả file**. Dòng đã nạp báo «trùng» và bị bỏ qua | Admin |
| Nạp lại file cũ chưa sửa, hoặc nạp lại cùng file hai lần | **Không nạp trùng, không ghi đè.** Dòng đã nạp báo «trùng»; dòng lỗi vẫn báo lỗi. Với Lớp, số buổi đã sinh không tăng thêm | Không phải dọn gì. Nạp lại chỉ ghi các dòng còn thiếu | Admin |
| Bị cắt ngang khi đang nạp (mất mạng, đóng tab, hết giờ chờ, máy chủ lỗi) và chưa thấy báo cáo | **Không còn gì của lần nạp đó:** cả lần nạp quay lại, không có nửa file, không có dòng nhật ký | Nạp lại cả file. Không cần xoá hay dọn gì | Admin |
| Không chắc lần nạp trước đã xong chưa (đang chờ mà mất kết nối) | Hoặc đã ghi các dòng đúng (lần nạp xong), hoặc chưa ghi gì (lần nạp bị cắt): không có kết quả nửa vời ở lần gọi bị cắt | Bấm **Xem trước** lại đúng file đó: số dòng báo «trùng» là số dòng đã nạp. Nếu mọi dòng đúng đều «trùng» thì lần trước đã xong | Admin |
| Nạp xong rồi mới thấy file sai (nhầm file, nhầm ngày chốt, dữ liệu sai) | Dữ liệu đã ghi. **Không có chức năng hoàn tác một lần nạp**, nạp lại không ghi đè dòng đã có | Không sửa tay trên cơ sở dữ liệu chạy thật. Báo Chat ngay; xử lý bằng bản sao lưu theo `quay-lai-khi-deploy-loi.md` (xem mục đó về việc quay DB) | Anh Trường quyết, Chat điều phối |

**Đã thử thật (cơ sở dữ liệu cục bộ, dữ liệu giả, một phiên Admin hai bước):**
- Nạp Lớp, file 6 dòng, 3 dòng lỗi (thiếu cột, lịch sai dạng, lớp chung thiếu phân loại): nạp được 3, trùng 0, lỗi 3. Sau đó có **đúng 3 lớp** và 34 buổi trong cơ sở dữ liệu; nhật ký nạp có 1 dòng (6 dòng, 3 nạp, 0 trùng, 3 lỗi).
- Nạp lại đúng file đó: nạp được 0, trùng 3, lỗi 3. Vẫn **3 lớp, 34 buổi** (không sinh thêm).
- Sửa dòng 4 (thêm `so_buoi`) rồi nạp lại cả file: nạp được 1, trùng 3, lỗi 2. Có 4 lớp.
- Phụ huynh, file 1000 dòng hợp lệ (xem trước cho 1000 hợp lệ, mất khoảng 1,5 giây), cắt giữa chừng bằng giới hạn thời gian (300 mili giây): máy chủ báo huỷ truy vấn; sau đó **0 phụ huynh** và **0 dòng nhật ký**. Đây là mô phỏng việc bị cắt giữa chừng; **chưa** thử ngắt kết nối trình duyệt thật.
- Nạp lại trùng của Phụ huynh, Học sinh, Cơ hội, Ghi danh còn được kiểm bằng các bài pgTAP có sẵn (`059`, `063`, `106`).

**Chỉ đọc mã, chưa thử thật:** Học sinh, Cơ hội, Ghi danh, Buổi học, Điểm danh chưa được tôi thử riêng từng loại; trong mã chúng chạy cùng khung với Lớp và Phụ huynh (hai hàm `app.import_records` và `app.import_training_records` cùng cách xử lý dòng lỗi, dòng trùng và xem trước).

### 10.2. Nạp Người dùng (khác hẳn các loại trên)

Nạp Người dùng chạy qua một hàm riêng (Edge Function `import-users`), **không phải một giao dịch**: mỗi dòng tạo một tài khoản đăng nhập rồi một dòng người dùng, lần lượt từng dòng. **Chỉ đọc mã, chưa thử thật** (cần chạy hàm Edge và phiên Admin hai bước).

| Triệu chứng | Cơ sở dữ liệu còn lại gì | Làm gì | Ai |
| --- | --- | --- | --- |
| Nạp xong nhưng có dòng lỗi | Dòng đúng đã tạo xong; dòng lỗi không tạo; nếu lỗi xảy ra sau khi tạo tài khoản đăng nhập thì mã tự xoá tài khoản vừa tạo | Sửa dòng lỗi, nạp lại cả file; người đã tạo báo «trùng» theo tên đăng nhập, không tạo thứ hai | Admin |
| **Bị cắt ngang giữa chừng** | **Giữ một phần:** những người đã tạo XONG vẫn còn. Mật khẩu tạm chỉ được trả MỘT LẦN ở cuối lần nạp (về trình duyệt Admin, không lưu ở đâu), nên **người đã tạo trước khi bị cắt không còn mật khẩu tạm nào để giao** | Bấm **Xem trước** lại để biết ai đã tạo (báo «trùng»). Với những người đã tạo: dùng **«Đặt lại mật khẩu»** ở hồ sơ người dùng để lấy mật khẩu tạm mới. Rồi nạp lại file để tạo phần còn thiếu | Admin |

Vì vậy với file Người dùng: nên nạp nhiều lần file nhỏ thay vì một file lớn, và tải ngay tệp mật khẩu tạm khi báo cáo hiện ra. Việc này chưa có cơ chế bảo vệ trong mã (mật khẩu tạm mất nếu mất kết nối trước khi nhận phản hồi): nếu cần, đây là việc để Chat mở phiếu sửa.

### 10.3. Chưa trả lời được

- Chưa thử thật khi ngắt kết nối trình duyệt hoặc tắt máy chủ giữa lần nạp; chỉ mô phỏng hết giờ ở cơ sở dữ liệu cục bộ.
- Chưa thử trên staging hay cơ sở dữ liệu chạy thật: giới hạn thời gian chờ ở đó có thể khác (xem trước 1000 dòng mất vài giây trên máy cục bộ).
- Chưa thử nạp Người dùng thật (Edge Function).
