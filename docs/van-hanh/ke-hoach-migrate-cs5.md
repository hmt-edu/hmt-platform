# Kế hoạch chuyển dữ liệu thật CS5 từ hệ thống cũ sang HMT Platform

Bản nháp ngày 19/11/2026 (Code B, theo chỉ thị Chat 16:05, sau khi xong CRM và Giáo viên). Cho anh Trường duyệt trước khi làm. Chỗ nào anh phải quyết ghi «**cần anh quyết**» (gom ở mục 10).

Tài liệu này nối các tài liệu đã có, không chép lại:

- Cách bấm trên màn Nhập, cột bắt buộc, lỗi thường gặp, nạp hỏng giữa chừng: `docs/van-hanh/nap-du-lieu-17-11.md`.
- Hàm nạp, luật từng loại, báo cáo đối soát: `docs/nghiep-vu/nap-du-lieu.md`.
- Cờ tính năng, tham số cho CS5: `docs/van-hanh/cau-hinh-cs5.md`.
- Lệnh chỉ đọc kiểm trước và sau nạp: `docs/van-hanh/sql-kiem-truoc-nap.sql`, `docs/van-hanh/sql-kiem-hmt-prod-chi-doc.sql`.
- Đưa bản mới lên chạy thật, quay lại khi deploy lỗi: `docs/van-hanh/dua-len-chay-that.md`, `docs/van-hanh/quay-lai-khi-deploy-loi.md`.

## 0. Nguyên tắc cứng

1. **Dữ liệu thật chỉ nằm trên máy anh Trường và trong bản chạy thật.** Không đưa tên, số điện thoại học sinh, phụ huynh vào repo, staging, máy local, log, chat, ảnh chụp màn hình (CLAUDE.md, mục Tuyệt đối không). Diễn tập chỉ dùng file GIẢ.
2. **Không mang mật khẩu từ hệ thống cũ.** Người dùng nạp xong có mật khẩu tạm, đổi ở lần đăng nhập đầu.
3. **Nạp thật chỉ do anh Trường làm** trên bản chạy thật (workflow ở `hmt-deploy`); Claude Code không có khoá chạy thật và không nạp.
4. Mọi thay đổi cấu trúc hay cờ (ví dụ bật `VAN_HANH_LOP` cho CS5) đi bằng migration qua PR, không bấm tay trên bản chạy thật.

## 1. Nguồn dữ liệu: file nào, cột nào

Nguồn là file Excel chuẩn bị từ các Google Sheet cũ của CS5 theo đúng cấu trúc file mẫu `docs/van-hanh/mau/HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx` (toàn dữ liệu giả). Mỗi tab xuất thành một file CSV UTF-8 (dòng đầu là tên cột) để tải lên màn **Nhập dữ liệu** (QT-18, `/crm/quan-tri/nhap-du-lieu`, chỉ Admin).

| Tab | Việc | Cột chính (đủ danh sách: tab `MO_TA_COT` của file mẫu) | Ghi chú |
| --- | --- | --- | --- |
| `00_NGUOIDUNG` | Tài khoản nhân sự, giáo viên | username, ho_ten, ma_nv (giáo viên dạng GV2001), vai_tro, co_so_truy_cap, trang_thai, email, quan_ly | Qua Edge Function `import-users`; sinh mật khẩu tạm |
| `03_LOP` | Lớp | ma_lop_cu, ma_lop_moi, loai_lop, mon, khoi, lich_hoc, thoi_luong_buoi, ma_gv, ngay_khai_giang, si_so_toi_da, tinh_trang, co_so | Cần giáo viên đã có |
| `01_PHUHUYNH` | Phụ huynh | ma_cu, ho_ten, sdt, sdt_2, ho_ten_2, dia_chi, co_so | `ma_cu` lưu vào `legacy_ref` |
| `02_HOCSINH` | Học sinh | ma_cu, ho_ten, ngay_sinh, gioi_tinh, sdt_ph, truong, khoi, co_so | Gắn phụ huynh qua `sdt_ph` |
| `04_GHIDANH` | Ghi danh, xếp lớp, **giờ còn lại** | hoc_sinh_ma_cu, ma_lop_cu, hinh_thuc, tinh_trang_moi, ngay_vao_lop, gio_da_hoc, gio_con_lai, ngay_chot | Tạo dòng «Số dư đầu kỳ» của sổ giờ |
| `09_SODU` | **Tiền**: thu thừa, công nợ đầu kỳ | hoc_sinh_ma_cu, cong_no_phai_thu_dong, tien_thu_thua_dong, ngay_chot | Tiền bằng ĐỒNG (file gốc nghìn đồng đã nhân 1000). Xem mục 10, Q-227 |
| `05_COHOI`, `06_PHIEUTEST` | Cơ hội, phiếu test của tuyển sinh | xem file mẫu | Có hàm nạp; **cần anh quyết** có nạp CS5 không (mục 10) |
| `07_BUOIHOC`, `08_DIEMDANH` | Buổi học, điểm danh lịch sử | xem file mẫu | **Chỉ để đối soát**, không tạo buổi, không trừ giờ |

Quy ước chung: ngày `yyyy-mm-dd`; giờ là số thập phân; SĐT 10 số bắt đầu 0 (hàm nhận +84); mã cũ học sinh dạng `M-Họ tên-1234` nếu có, nếu không thì `SĐT|tên không dấu|ngày sinh`.

**Người chuẩn bị file** (**cần anh quyết**: ai): xuất từ Sheet cũ bằng script chuẩn bị đã dùng cho file mẫu, kiểm mắt các ô lạ, giữ file chỉ trên máy anh Trường.

## 2. Thứ tự nạp

Mỗi bước: bấm **Xem trước** (không ghi gì) → chỉ bấm **Nạp** khi báo cáo 0 lỗi (hoặc lỗi đã hiểu rõ) → chạy kiểm đối soát của bước (mục 4) → mới sang bước sau.

| Bước | Loại | Điều kiện trước | Kiểm ngay sau bước |
| --- | --- | --- | --- |
| 0 | Chuẩn bị môi trường | Danh mục (khối, môn, hình thức…) và cấu hình CS5 đã đúng (`cau-hinh-cs5.md`); cờ `VAN_HANH_LOP` của CS5 đã bật bằng migration; `opening_balance_date` đã chốt; `session_done_requires_review` đúng chế độ (nap-du-lieu-17-11 mục 7, 9) | Chạy `sql-kiem-truoc-nap.sql` (6 khối) |
| 1 | Người dùng (`00_NGUOIDUNG`) | Danh mục vai trò, cơ sở | Số tài khoản = số dòng file; giáo viên có `ma_nv` |
| 2 | Lớp (`03_LOP`) | Giáo viên đã có | Số lớp = số dòng; lịch học, giáo viên đúng mẫu 3 lớp mở mắt |
| 3 | Phụ huynh rồi Học sinh | — | Số phụ huynh, số học sinh khớp file; không có học sinh mồ côi |
| 4 | Ghi danh (`04_GHIDANH`) | Lớp, học sinh đã có | Số ghi danh đang học; **tổng giờ còn lại** khớp file |
| 5 | Số dư tiền (`09_SODU`) | Học sinh đã có; **chỉ khi anh Trường bảo** (Q-227) | **Tổng công nợ**, **tổng thu thừa** khớp file |
| 6 | Cơ hội, phiếu test (nếu có) | Phụ huynh, học sinh | Số cơ hội theo giai đoạn L1 đến L8 khớp file |
| 7 | Buổi học, điểm danh lịch sử | Chỉ để đối soát | Không đổi số dư giờ sau bước này |

Vì sao đúng thứ tự này: lớp cần giáo viên; ghi danh cần lớp và học sinh; số dư tiền gắn học sinh; mỗi tab sau cần tab trước đã có (nap-du-lieu-17-11 mục 2).

## 3. Chốt mốc, đóng băng nguồn

Để số liệu nạp khớp hệ thống cũ, hai hệ thống không được cùng ghi trong lúc chuyển:

1. Chọn **ngày chốt** (tham số `opening_balance_date`). Giờ còn lại, công nợ lấy đúng tại ngày này.
2. **Đóng băng hệ thống cũ** từ giờ xuất file đến lúc nạp xong và đối soát đạt: không ghi danh, không thu tiền, không điểm danh ở Sheet cũ trong khoảng đó. Phát sinh trong khoảng đóng băng ghi tay ra giấy, nhập sau khi đối soát đạt.
3. Sau đối soát đạt, từ ngày vào dùng thật: **chỉ ghi ở HMT Platform**; Sheet cũ chuyển chế độ chỉ xem.

Ngày chốt, giờ đóng băng, người trực: **cần anh quyết** (mục 10).

## 4. Kiểm đối soát sau nạp (tổng giờ, tổng tiền khớp nguồn)

Dùng hàm báo cáo đối soát có sẵn `app.import_reconciliation_report(mã cơ sở)` (Admin; chỉ đếm hồ sơ nạp có `legacy_ref`; không in tên hay SĐT) và tab `DOI_SOAT` do script chuẩn bị file sinh ra. So từng chỉ số với nguồn:

| Chỉ số báo cáo | So với | Đạt khi |
| --- | --- | --- |
| `parents`, `students` | Số dòng 01, 02 sau khi bỏ dòng trùng đã biết | Bằng nhau |
| `classes` | Số dòng 03 | Bằng nhau |
| `enrollments_active` | Số ghi danh đang học trong 04 | Bằng nhau |
| `hours_left` | Tổng `gio_con_lai` trong 04 | **Bằng đến 0,01 giờ** (kiểu `numeric(6,2)`); chênh phải giải thích từng học sinh |
| `opportunities_by_stage`, `opportunities_total` | Số cơ hội mỗi giai đoạn trong 05 (nếu nạp) | Bằng nhau |
| `debt_total_vnd` | Tổng `cong_no_phai_thu_dong` trong 09 | **Bằng đến 1 đồng** |
| `credit_total_vnd` | Tổng `tien_thu_thua_dong` trong 09 | **Bằng đến 1 đồng** |

Thêm ba kiểm tay (người phụ trách dữ liệu cơ sở làm, anh Trường ký):

1. **Mẫu 20 học sinh** (chọn ngẫu nhiên, gồm các ca khó: nhiều em một phụ huynh, lớp 2 buổi/tuần, học sinh nghỉ, còn nợ): mở hồ sơ trên màn, so giờ còn lại, công nợ, lớp đang học với Sheet cũ.
2. **Mọi dòng bị trùng hoặc lỗi** ở báo cáo: có danh sách, mỗi dòng có người xử lý và kết quả (sửa file rồi nạp lại; dòng đã nạp báo «trùng»).
3. **Không có dữ liệu mồ côi**: học sinh không phụ huynh, ghi danh không lớp (chạy khối (e) của `sql-kiem-truoc-nap.sql`, chỉ đọc).

Kết luận đối soát ghi vào một trang (ngày, người kiểm, số liệu hai phía, chênh lệch, kết luận Đạt / Không đạt); **chưa Đạt thì chưa cho dùng thật**.

## 5. Diễn tập trên staging bằng dữ liệu GIẢ

Làm ít nhất hai vòng, mỗi vòng đủ bước 0 đến 7:

1. **Vòng 1, file mẫu sạch** `HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx`: kỳ vọng 0 lỗi, đối soát khớp.
2. **Vòng 2, file mẫu bẩn** `HMT5_FILE_MAU_NAP_DU_LIEU_GIA_BAN.xlsx` (SĐT thiếu số 0, ngày lẫn định dạng, trùng SĐT, cơ sở viết khác, giờ âm…): đối chiếu kết quả với tab `KET_QUA_DU_KIEN`; tập sửa file theo báo lỗi và nạp lại.
3. **Vòng 3, quy mô thật**: sinh file giả cỡ tương đương CS5 (đếm theo số liệu tổng, không cần dữ liệu thật) để đo thời gian. Số đo đã có (1000 dòng Phụ huynh 5 đến 8 giây, Học sinh 10 đến 20 giây; `nap-du-lieu.md`). Nạp lô lớn chia nhiều file nếu vượt `import_max_rows`.
4. Tập hai tình huống hỏng: **nạp bị cắt giữa chừng** và **nạp nhầm file** theo mục 6.
5. **Kiểm giờ chạy:** người nạp bấm đồng hồ cả buổi diễn tập để ước giờ chiếm trên bản chạy thật (dùng làm lịch ở mục 8).

Mọi dữ liệu trong diễn tập là giả (tên «Mẫu 01», SĐT dải 090000xxxx). Người diễn tập là Admin; kết quả ghi vào `docs/van-hanh/kiem-tay-staging.md` (không có tên thật).

## 6. Cách quay lại

Theo mức độ, nhẹ đến nặng (chi tiết `nap-du-lieu-17-11.md` mục 10):

1. **Thiếu dòng hoặc có dòng lỗi:** sửa file, nạp lại cả file. Nạp lại không sinh trùng, không ghi đè. Không cần quay lại.
2. **Bị cắt ngang:** không còn nửa file (một lần nạp là một giao dịch); xem trước rồi nạp lại.
3. **Nạp SAI NỘI DUNG** (nhầm file, nhầm ngày chốt): nạp lại không sửa được vì không ghi đè và không có chức năng hoàn tác lần nạp. Quyết định của anh Trường: **khôi phục từ bản sao lưu đêm trước** (file `.age` trên Google Drive vận hành). Anh khôi phục thử vào DB Docker tạm trên máy anh trước khi áp bản thật; Claude Code không chạy khôi phục.
4. **Điều kiện cần:** **ngay trước khi nạp thật, có một bản sao lưu mới** và ghi giờ, để luôn có điểm quay lại sát nhất. Sao lưu mỗi đêm chạy từ `hmt-deploy`; có chạy riêng một lần ngay trước giờ nạp được không thì **cần anh Trường xác nhận** (Claude Code chưa kiểm được vì không có quyền ở `hmt-deploy`).

Quay lại là **mất mọi thay đổi** sau điểm sao lưu (cả thao tác của người dùng thật nếu đã vào dùng), nên chỉ làm trong khoảng đóng băng, trước ngày vào dùng thật.

## 7. Rủi ro đã biết và cách chặn

| Rủi ro | Cách chặn |
| --- | --- |
| Trùng phụ huynh (một SĐT cho nhiều em, hai SĐT) | Hàm nạp gắn theo SĐT; ca đã có trong file mẫu; báo cáo hiện số dòng gắn vào phụ huynh có sẵn |
| Giờ còn lại sai do cách tính của hệ thống cũ | Đối soát tổng và mẫu 20 em; chênh lệch phải có giải thích từng em trước khi nhận |
| Công nợ, thu thừa nhập nhằng (nghìn đồng so với đồng) | File 09 đã nhân 1000; kiểm tổng `debt_total_vnd`, `credit_total_vnd`; loại tiền âm hoặc lẻ bị chặn (`HMT_NAP_TIEN_SAI`) |
| Cơ sở chưa bật `VAN_HANH_LOP` | Dòng bị từ chối `HMT_TINH_NANG_TAT`; bật bằng migration trước bước 0 |
| Giáo viên trong lớp chưa có tài khoản | Nạp Người dùng trước Lớp (bước 1 trước bước 2) |
| Nạp song song hai người | Quy định một người nạp tại một thời điểm, người kia chỉ xem |
| Lộ dữ liệu thật | File thật chỉ trên máy anh Trường; báo cáo màn Nhập không in tên, SĐT; không chụp màn hình dòng dữ liệu |
| Mật khẩu tạm lộ | File mật khẩu tạm hiện một lần, tải xong giao riêng từng người, đổi ở lần đăng nhập đầu |

## 8. Lịch gợi ý (số giờ lấy từ buổi diễn tập, mục 5)

| Mốc | Việc | Ai |
| --- | --- | --- |
| T-14 ngày | Chốt phạm vi tab nạp, ngày chốt, người chuẩn bị file | Anh Trường |
| T-10 | Xuất file thật lần 1 trên máy anh; kiểm lỗi cấu trúc bằng Xem trước ở **bản chạy thật** không ghi gì (hoặc bằng bản sao ẩn danh nếu anh muốn, **cần anh quyết**) | Người chuẩn bị file, anh Trường |
| T-7 | Diễn tập vòng 1 đến 3 trên staging bằng file giả | Admin, Chat điều phối |
| T-3 | Chốt danh sách kiểm go-live (do Code F làm); sao lưu thử, khôi phục thử vào DB tạm | Anh Trường |
| T-1 | Đóng băng hệ thống cũ; xuất file thật lần cuối | Anh Trường, cơ sở |
| T0 | Sao lưu mới → nạp theo bước 0 đến 7 → đối soát → ký kết luận | Anh Trường (nạp), người phụ trách dữ liệu cơ sở (đối soát) |
| T0 đến T+2 | Hỗ trợ cơ sở vào dùng; mọi chênh lệch phát hiện ghi và xử lý theo mục 6 | Chat, các lane |

## 9. Việc Claude Code làm được, không làm được

- **Làm trước (không đụng dữ liệu thật):** sinh file giả cỡ thật cho diễn tập; viết thêm khối đối soát chỉ đọc; chỉnh màn Nhập nếu diễn tập lộ chỗ khó; chạy diễn tập trên staging bằng file giả; viết bản tóm tắt một trang cho người nạp.
- **Không làm:** nhìn dữ liệu thật; nạp thật; khôi phục bản sao lưu; giữ khoá chạy thật.

## 10. Cần anh quyết

1. **Có nạp số dư tiền (`09_SODU`) lúc chuyển CS5 không** (Q-227 mới chỉ chốt cho ngày 17/11 là chỉ nạp giờ)? Nếu có, công nợ đầu kỳ thu bằng phiếu «Thu nợ đầu kỳ» (R-V2-15) và nạp tiền thu thừa vào Sổ số dư khách hàng như `nap-du-lieu.md` mô tả.
2. **Có nạp Cơ hội, Phiếu test của CS5 không**, hay tuyển sinh bắt đầu sạch từ ngày vào dùng?
3. **Ngày chốt**, ngày vào dùng thật, **giờ đóng băng** hệ thống cũ, và người trực lúc nạp.
4. **Người chuẩn bị file** của CS5 và người ký đối soát (người phụ trách dữ liệu cơ sở).
5. **Cách thử cấu trúc file thật trước ngày nạp** mà không đưa dữ liệu thật lên staging: Xem trước ở bản chạy thật (không ghi gì), hay tự kiểm bằng script ẩn danh trên máy anh.
6. **Dung sai đối soát giờ:** đề xuất 0,01 giờ (kiểu dữ liệu); anh xác nhận hay nới.
7. **Chế độ Done buổi học** lúc vào dùng thật: giữ Tắt (đang đặt Tắt bằng migration 110) hay bật chấm nhận xét (nap-du-lieu-17-11 mục 7).
