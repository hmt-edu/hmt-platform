# Kế hoạch chuyển dữ liệu từ hệ thống cũ (Google Sheet) sang HMT Platform

**BẢN NHÁP, gửi anh Trường duyệt.** Soạn 24/11/2026 theo thẻ C-23-46 (Code C). Chỉ tài liệu: không dữ liệu thật, không mật khẩu cũ, không chạy gì lên bản chạy thật. **Chưa làm bước nạp nào cho đến khi anh duyệt** (mục «cần anh quyết» ở cuối).

## Tài liệu này là gì, và nối với tài liệu nào

Đây là **kế hoạch tổng cho cả hệ thống** (năm cơ sở, mọi loại dữ liệu), trả lời: chuyển cái gì, theo thứ tự nào, khớp trùng ra sao, kiểm thế nào, ai quyết. Phần lớn công cụ và quy trình đã có; tài liệu này **nối, không chép lại**:

| Cần biết | Xem |
| --- | --- |
| Kế hoạch riêng CS5 (nháp 19/11, Code B): nguồn, bước 0 đến 7, đối soát, quay lại, lịch, 7 câu cần anh quyết | `docs/van-hanh/ke-hoach-migrate-cs5.md` |
| Cách bấm trên màn Nhập, cột bắt buộc, lỗi thường gặp, nạp hỏng giữa chừng | `docs/van-hanh/nap-du-lieu-17-11.md` |
| Hàm nạp, luật từng loại, báo cáo đối soát, số đo thời gian | `docs/nghiep-vu/nap-du-lieu.md` |
| Cờ tính năng và tham số cho CS5 | `docs/van-hanh/cau-hinh-cs5.md` |
| Lệnh chỉ đọc kiểm trước và sau nạp | `docs/van-hanh/sql-kiem-truoc-nap.sql` |
| Mã nghiệp vụ, danh mục | `docs/spec/02-chuan-ma-va-danh-muc.md` |
| Luật nạp (anh chốt 04/11, Đ285) | `docs/spec/04` mục 14, R-V2-29 đến R-V2-34 |

Điểm khác với kế hoạch CS5: kế hoạch CS5 là **một cơ sở, một lần nạp**; tài liệu này thêm **thứ tự giữa các cơ sở, các loại dữ liệu chưa có công cụ nạp** (mục 1, cột «Công cụ»), và các quyết định chung.

## 0. Nguyên tắc cứng (giữ nguyên từ CLAUDE.md và kế hoạch CS5)

1. Dữ liệu thật chỉ nằm trên máy anh Trường và trong bản chạy thật. Không vào repo, staging, máy local, log, chat, ảnh chụp màn hình. Diễn tập chỉ dùng file GIẢ.
2. **Không mang mật khẩu cũ.** Người dùng nạp xong có mật khẩu tạm ngẫu nhiên, đổi ở lần đăng nhập đầu.
3. **Nạp thật chỉ anh Trường làm**, từ `hmt-deploy`; Claude Code không có và không xin khoá chạy thật.
4. Đổi cấu trúc hay cờ đi bằng migration qua PR, không bấm tay trên bản chạy thật.
5. Một lần nạp là một giao dịch; nạp lại không ghi đè (dòng đã có thành TRUNG).

## 1. Đối tượng cần chuyển, theo thứ tự phụ thuộc

Mỗi hàng cần các hàng trên nó đã có. «Công cụ» là loại nạp có sẵn trên màn Nhập (QT-18, `/crm/quan-tri/nhap-du-lieu`, chỉ Admin) hoặc «chưa có».

| # | Đối tượng | Bảng đích | Công cụ | Cột mã cũ | Khớp trùng | Mã mới | Bắt buộc, hay thiếu |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Cơ sở, phòng, danh mục, tham số, cờ tính năng | `branch`, `room`, `catalog_item`, `setting_def`, `feature_flag` | **Không nạp từ file**: cấu hình bằng migration và màn Quản trị | không | theo `code` danh mục | mã cơ sở, danh mục cố định | Phải đủ **trước** mọi bước sau: khối, môn, hình thức, vai trò, nguồn khách, bật `VAN_HANH_LOP` cho cơ sở. Thiếu một mục danh mục thì dòng bị từ chối |
| 2 | Người dùng (nhân sự, giáo viên) | `user_account`, `user_role` | `NGUOI_DUNG` (Edge Function `import-users`) | `username` vào `legacy_ref` | `username` (không phân biệt hoa thường) hoặc `legacy_ref` | NV, GV, TG cấp theo vai trò (spec 02) | username, họ tên, vai trò có trong danh mục; email trống thì `username@<miền>` (tham số `import_user_email_domain`). Thiếu: người nghỉ cần cờ khoá; nhiều cơ sở chỉ lấy cơ sở đầu, phần còn lại chờ áp lại |
| 3 | Phụ huynh | `parent` | `PHU_HUYNH` | `ma_cu` vào `legacy_ref` | mã cũ; hoặc **SĐT chính/thứ hai** → TRUNG (không tự gộp) | PH | mã cũ, họ tên, SĐT 10 số, cơ sở. Hay thiếu: SĐT sai độ dài, một SĐT dùng chung nhiều nhà |
| 4 | Học sinh | `student` | `HOC_SINH` | `ma_cu` | mã cũ; cùng phụ huynh + tên chuẩn hoá + năm sinh (R-CRM-27) | HS | mã cũ, họ tên, ngày sinh (cần năm), khối 1 đến 12, SĐT phụ huynh có sẵn, cơ sở. Hay thiếu: ngày sinh, khối. Phụ huynh chưa nạp → LỖI (không tự tạo) |
| 5 | Khách tiềm năng, cơ hội, phiếu test (tuyển sinh) | `lead`, `opportunity`, `student_test` | `CO_HOI`, `PHIEU_TEST` | `ma_cu` (SĐT) vào `legacy_ref`; ngày tạo cũ ở `legacy_created_at` | mã cũ | LD, CO theo spec 02 | Có thể nạp song song với bước 3, 4 (nối theo SĐT). **Cần anh quyết có nạp không** (mục 7, câu 2) |
| 6 | Lớp | `class`, `class_slot` | `LOP` | `ma_lop_cu` | mã lớp cũ | mã lớp theo spec 02 (cơ sở, năm, môn, khối, loại, STT; cấp bằng hàm, không nhảy số) | giáo viên đã có (bước 2), lịch học, ngày khai giảng. Thiếu: lịch ghi tự do khó đọc |
| 7 | Ghi danh và **sổ giờ đầu kỳ** | `enrollment`, `enrollment_class`, `hour_ledger` (dòng `DAU_KY`) | `GHI_DANH` | `hoc_sinh_ma_cu` + `ma_lop_cu` | cặp học sinh, lớp | GD | lớp, học sinh có sẵn; `gio_con_lai` không âm. **Một dòng lỗi chặn cả loại** (R-V2-30). Hay thiếu: `ngay_vao_lop`, tình trạng |
| 8 | Số dư tiền: công nợ đầu kỳ, tiền thu thừa | `customer_balance_entry` | `SO_DU` | `hoc_sinh_ma_cu` | trùng học sinh đã có dòng sổ → TRUNG | không | tiền bằng ĐỒNG (file gốc nghìn đồng phải nhân 1000), không âm, không lẻ. **Cần anh quyết có nạp không** (Q-227 mới chốt cho ngày 17/11) |
| 9 | Lịch sử đơn hàng và phiếu thu (học phí đã đóng trước ngày chốt) | `sales_order`, `receipt` | **Chưa có** | — | — | mã đơn, mã phiếu thu theo spec 02 | **Đề xuất không nạp**: giờ còn lại (bước 7) và công nợ (bước 8) đã đủ cho vận hành; lịch sử thu giữ ở Sheet cũ (chỉ xem). Nạp lại đơn cũ phải đi qua luật tiền nên rủi ro cao. **Cần anh quyết** |
| 10 | Lịch sử buổi học và điểm danh | `legacy_attendance_record` và buổi cũ | `BUOI_HOC`, `DIEM_DANH` | — | — | — | **Chỉ để đối soát**, không tạo buổi, không trừ giờ (kế hoạch CS5 bước 7). Buổi mới do hệ thống sinh từ lớp đã duyệt |
| 11 | Ticket, bảo lưu, dừng học, hoàn phí cũ | `ticket`, `enrollment_hold`… | **Chưa có** | — | — | — | **Đề xuất không nạp**: bảo lưu đang chạy thì nhập tay bằng phiếu nghiệp vụ sau ngày vào dùng; ticket cũ giữ ở Sheet. **Cần anh quyết** |

Quy ước file chung: CSV UTF-8, mỗi tab một file, dòng đầu là tên cột như file mẫu (`docs/van-hanh/mau/`, toàn dữ liệu giả); ngày `yyyy-mm-dd`; giờ là số thập phân; SĐT 10 số bắt đầu 0 (hàm nhận +84). Mỗi lần tối đa `import_max_rows` dòng (mặc định 300): file lớn chia nhiều file, nạp lại không sinh trùng.

## 2. Mã cũ và mã nghiệp vụ: không nhảy số, không sửa

- **Mã cũ** luôn vào cột `legacy_ref` (có chỉ mục để tìm). Đây là cầu nối duy nhất giữa hai hệ thống; không dùng mã cũ làm mã mới.
- **Mã mới** cấp bằng hàm và bảng đếm khoá dòng trong DB (spec 02), nên số liền nhau theo thứ tự nạp, không nhảy, không sửa được. Hệ quả: **thứ tự dòng trong file quyết định số mã**, nên file nạp phải sắp ổn định (theo mã cũ) để diễn tập và nạp thật cho cùng một thứ tự.
- Nạp lại cùng file: TRUNG, không cấp mã mới (không đốt số).
- Trùng nghĩa, khác mã (hai phụ huynh một người): **không tự gộp lúc nạp**; gộp sau ở màn Gộp trùng.

## 3. Dùng công cụ Nhập dữ liệu (QT-18)

- **Định dạng:** CSV UTF-8, tên cột như file mẫu. Thiếu cột bắt buộc thì chặn ngay lúc tải, nêu tên cột; cột lạ bị bỏ và liệt kê.
- **Xem trước rồi nạp:** cùng một hàm, xem trước (`commit = false`) chạy hết rồi hoàn tác nên kết quả luôn khớp nạp thật.
- **Báo lỗi theo dòng:** mỗi dòng có trạng thái HỢP LỆ, TRÙNG (nêu mã hồ sơ có sẵn), LỖI (câu tiếng Việt, mã lỗi như `HMT_NAP_GIO_AM`). Chỉ có số dòng và chữ cái đầu của tên, **không in họ tên, SĐT, mã cũ** ở kết quả, lỗi, nhật ký. Nút «Tải dòng lỗi và trùng» trả file gốc kèm cột `ket_qua`, `ly_do` để sửa rồi nạp lại.
- **Dòng lỗi chặn hay không:** nhóm CRM (phụ huynh, học sinh, cơ hội, phiếu test): dòng lỗi không chặn dòng đúng. Nhóm đào tạo và tiền (lớp, ghi danh, số dư): **một dòng lỗi chặn cả loại**.
- **Nhật ký nạp:** `app.import_log` (loại, người nạp, tên file, tổng, số nạp, trùng, lỗi), Admin đọc.
- **Giới hạn thời gian:** vai trò `authenticated` có hạn 8 giây mỗi câu lệnh; vì vậy 300 dòng mỗi lần. Nạp nặng bằng Edge Function hoặc cắt lô tự động ở giao diện **chưa làm** (số đo ở `nap-du-lieu.md`, chưa đo trên staging).

## 4. Chốt mốc, nạp mấy đợt, kiểm đối soát

**Chốt mốc:** một ngày chốt chung (tham số `opening_balance_date`); giờ còn lại và công nợ lấy đúng tại ngày này. Từ lúc xuất file đến lúc đối soát đạt, hệ thống cũ **đóng băng** (không ghi danh, không thu tiền, không điểm danh); phát sinh trong khoảng đó ghi giấy, nhập sau. Đối soát đạt thì Sheet cũ chuyển chế độ chỉ xem.

**Nạp mấy đợt (đề xuất để anh chọn, mục 7 câu 3):**

| Phương án | Nội dung | Ưu | Nhược |
| --- | --- | --- | --- |
| A. Một đợt cho cả năm cơ sở | Nạp tất cả cùng một ngày chốt | Một lần đóng băng, một lần đối soát | Rủi ro dồn một chỗ; lỗi một cơ sở kéo cả đợt |
| B. **Từng cơ sở, CS5 trước (đề xuất)** | CS5 đã có kế hoạch riêng; rút kinh nghiệm rồi mới các cơ sở sau | Lỗi nhỏ, học được từ đợt đầu; đóng băng ngắn theo từng cơ sở | Nhiều lần nạp; người dùng nhiều cơ sở (nếu có) phải nạp ở đợt đầu rồi áp lại cơ sở |

Các bước, mỗi cơ sở: bước 0 (cấu hình, cờ) → 2 → 6 → 3, 4 → 7 → (8, 5 nếu anh duyệt) → đối soát. Giữa hai bước đều bấm Xem trước, chỉ Nạp khi 0 lỗi (hoặc lỗi đã hiểu), chạy kiểm chỉ đọc của bước đó rồi mới sang bước sau.

**Đối soát sau nạp** (chi tiết và dung sai ở kế hoạch CS5 mục 4): `app.import_reconciliation_report(mã cơ sở)` so với tab `DOI_SOAT` của script chuẩn bị file: số phụ huynh, học sinh, lớp, ghi danh đang học; **tổng giờ còn lại bằng đến 0,01 giờ**; tổng công nợ, tổng thu thừa bằng đến 1 đồng; số cơ hội theo giai đoạn. Cộng ba kiểm tay (mẫu 20 học sinh gồm ca khó, mọi dòng trùng/lỗi có người xử lý, không dữ liệu mồ côi). Kết luận một trang (ngày, người kiểm, số hai phía, chênh lệch, Đạt/Không đạt); **chưa Đạt thì chưa cho dùng thật**.

## 5. Thử trên staging bằng file GIẢ, đối chiếu, quay lại

1. **Chuẩn bị:** file giả đúng cấu trúc, cỡ tương đương một cơ sở (đếm theo số liệu tổng, không cần dữ liệu thật): tên «Mẫu 01», SĐT dải 090000xxxx. Có sẵn hai file mẫu: sạch và bẩn (kèm tab `KET_QUA_DU_KIEN`).
2. **Vòng 1, file sạch:** kỳ vọng 0 lỗi, đối soát khớp. **Vòng 2, file bẩn:** SĐT thiếu số 0, ngày lẫn định dạng, trùng SĐT, cơ sở viết khác, giờ âm: đối chiếu với `KET_QUA_DU_KIEN`, tập sửa file theo báo lỗi rồi nạp lại. **Vòng 3, quy mô thật:** đo thời gian, chia lô theo `import_max_rows`.
3. **Đối chiếu hai phía:** với mỗi vòng, so **số dòng** (file với báo cáo đối soát), **số tiền** (tổng công nợ, tổng thu thừa, đồng), **số giờ** (tổng giờ còn lại, 0,01) và mẫu 20 hồ sơ. Ghi vào `docs/van-hanh/kiem-tay-staging.md` (không tên thật).
4. **Hai tình huống hỏng cần tập:** nạp bị cắt giữa chừng (không còn nửa file vì một lần nạp là một giao dịch; xem trước rồi nạp lại) và **nạp nhầm file** (không có chức năng hoàn tác lần nạp).
5. **Rollback:** ngay trước khi nạp thật có **một bản sao lưu mới**, ghi giờ. Nạp sai nội dung thì **khôi phục từ bản sao lưu** (anh Trường khôi phục thử trước vào DB Docker tạm trên máy anh, xong xoá; Claude Code không chạy). Quay lại **mất mọi thay đổi** sau điểm sao lưu, nên chỉ làm trong khoảng đóng băng, trước ngày vào dùng thật. Xem `nap-du-lieu-17-11.md` mục 10 và `quay-lai-khi-deploy-loi.md`.

## 6. Rủi ro

| Rủi ro | Cách chặn |
| --- | --- |
| Lộ dữ liệu thật | File thật chỉ trên máy anh Trường; kết quả màn Nhập không in tên, SĐT; không chụp màn hình dòng dữ liệu; không đưa lên staging |
| Trùng phụ huynh (một SĐT nhiều em, hai SĐT) | Nối theo SĐT; ca đã có trong file mẫu; trùng nghĩa gộp sau ở màn Gộp trùng |
| Giờ còn lại sai do cách tính của hệ thống cũ | Đối soát tổng và mẫu 20 em; chênh lệch phải giải thích từng em |
| Tiền nhập nhằng (nghìn đồng và đồng) | File 09 nhân 1000; kiểm tổng; loại âm, lẻ bị chặn |
| Thiếu danh mục hoặc cờ `VAN_HANH_LOP` | Bước 0; dòng bị từ chối `HMT_TINH_NANG_TAT` |
| Giáo viên chưa có tài khoản khi nạp Lớp | Nạp Người dùng trước Lớp |
| Số mã đổi theo thứ tự dòng | File sắp ổn định theo mã cũ; diễn tập cùng thứ tự |
| Nạp song song hai người | Một người nạp tại một thời điểm, người kia chỉ xem |
| Mật khẩu tạm lộ | File mật khẩu tạm hiện một lần, giao riêng từng người, đổi ở lần đăng nhập đầu |
| Người dùng thật ghi dữ liệu trong lúc nạp | Đóng băng hệ thống cũ; sau nạp mới mở HMT Platform cho cơ sở |
| Giới hạn gói Free (DB 500 MB, tải ra 5 GB mỗi tháng) | Ước dung lượng sau nạp từ số dòng; không lưu file trong Supabase Storage |

## 7. Việc cần anh quyết (dừng chờ, chưa làm bước nạp nào)

1. **Phạm vi:** nạp những loại nào ở mục 1 (đặc biệt các hàng 5, 8, 9, 11: cơ hội, số dư tiền, lịch sử đơn và thu, ticket và bảo lưu cũ). Đề xuất: nạp 2 đến 4, 6, 7; hỏi anh 5 và 8; **không nạp** 9 và 11.
2. **Có nạp Cơ hội, Phiếu test** không, hay tuyển sinh bắt đầu sạch từ ngày vào dùng?
3. **Nạp mấy đợt:** phương án A hay B (đề xuất B, CS5 trước).
4. **Ngày chốt dữ liệu** (cắt tại ngày nào), ngày vào dùng thật, giờ đóng băng hệ thống cũ, người trực lúc nạp.
5. **Ai chuẩn bị file** từ Sheet cũ (script chuẩn bị đã dùng cho file mẫu) và **ai kiểm, ai ký đối soát** ở từng cơ sở.
6. **Cách thử cấu trúc file thật trước ngày nạp** mà không đưa dữ liệu thật lên staging: Xem trước ở bản chạy thật (không ghi gì), hay tự kiểm bằng script ẩn danh trên máy anh.
7. **Dung sai đối soát giờ:** đề xuất 0,01 giờ (kiểu dữ liệu); anh xác nhận hay nới.
8. **Chế độ Done buổi học** lúc vào dùng thật: giữ Tắt hay bật chấm nhận xét (`nap-du-lieu-17-11.md` mục 7).
9. **Chạy riêng một lần sao lưu ngay trước giờ nạp** có được không (sao lưu hiện chạy mỗi đêm từ `hmt-deploy`; Claude Code không kiểm được vì không có quyền ở đó).

## 8. Việc Claude Code làm được sau khi anh duyệt (không đụng dữ liệu thật)

Sinh file giả cỡ thật cho diễn tập; viết thêm khối đối soát chỉ đọc; chỉnh màn Nhập nếu diễn tập lộ chỗ khó; chạy diễn tập trên staging bằng file giả; viết tóm tắt một trang cho người nạp; nếu anh chọn nạp lịch sử đơn/phiếu thu (hàng 9) thì thiết kế loại nạp riêng và gửi anh duyệt trước. **Không làm:** nhìn dữ liệu thật, nạp thật, khôi phục bản sao lưu, giữ khoá chạy thật.
