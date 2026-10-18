# Chuẩn mã và danh mục

Đã chốt với anh Trường ngày 09/10/2026; bổ sung 11/10/2026 (CS3 Hội sở) và 12/10/2026 (đánh dấu **(12/10)**).

## Nguyên tắc
1. **Hai lớp định danh.** ID nội bộ (uuid) chỉ máy dùng, không hiển thị, không bao giờ đổi. Mã nghiệp vụ cho người đọc, nói, tìm kiếm.
2. **Mã không chứa thông tin có thể đổi**: tên, số điện thoại, khối hiện tại, giáo viên, cơ sở của học sinh.
3. **Cấp một lần, không sửa, không dùng lại**, kể cả khi bản ghi bị huỷ. Mã do cơ sở dữ liệu cấp (bảng đếm khoá dòng, không nhảy số), không ai tự gõ.
4. **Định dạng cố định**: in hoa, không dấu, không khoảng trắng, số đủ chữ số.
5. **Danh mục dùng mã ngắn, tên hiển thị để riêng.** Đổi tên hiển thị không ảnh hưởng dữ liệu.
6. **Mã cũ trên Sheet giữ làm mã tham chiếu** (cột `legacy_ref`), tìm kiếm được.

## Danh mục gốc
| Danh mục | Mã | Ghi chú |
|---|---|---|
| Cơ sở | `CS1` Nguyễn Chí Thanh, `CS2` Đỗ Quang, `CS4` Hà Đông, `CS5` Mỹ Đình; `CS3` Hội sở | `CS3` Hội sở là văn phòng: chỉ gắn tài khoản nhân viên, không có phòng học, lớp, học sinh (chốt 11/10/2026). **(12/10)** Không xuất hiện trong ô chọn cơ sở của dữ liệu nghiệp vụ (R-HT-02). Không đánh số lại |
| Năm học | `2627` | Từ tháng 6 tới tháng 5 năm sau |
| Môn | `TOAN`, `DAI`, `HINH`, `LY`, `HOA`, `VAN`, `ANH`, `KHTN`, `TRUNG`, `SAT` | `DAI`, `HINH` chỉ dùng cho lớp, xem mục Đại/Hình |
| Khối | `K02` … `K12` | Hai chữ số |
| Phân loại lớp | `CB` cơ bản, `NC` nâng cao, `LR` lớp riêng | Lớp riêng là lớp bình thường, 1-2 em |
| Trình độ | `S`, `A`, `B`, `C` | S cao nhất. Chỉ cho lớp CB, NC |
| Cấp độ khung chương trình | `CB`, `NC` | |
| Hình thức | `OFF`, `ONL` | Thuộc ghi danh; lớp OMO nhận cả hai |
| Loại gói **(12/10)** | `LC` lớp chung, `VIP` VIP 1:1 và 1:2, `VNN` VIP nhóm nhỏ, `KR` kèm riêng, `DV` dịch vụ, `TL` tài liệu | `DV`, `TL` không có quỹ giờ, không sinh ghi danh (R-TIEN-15) |

## Mã các đối tượng
| Đối tượng | Mẫu | Ví dụ | Ghi chú |
|---|---|---|---|
| Học sinh | `HS` + 6 số | `HS000123` | Một em một mã suốt đời, mọi cơ sở, mọi năm |
| Phụ huynh | `PH` + 6 số | `PH000045` | Người trả tiền, có thể nhiều con |
| Lead **(12/10)** | `LD` + 6 số | `LD000123` | Đánh số toàn hệ thống, không gắn cơ sở |
| Cơ hội **(12/10)** | `CO` + 6 số | `CO000123` | |
| Phiếu kiểm tra đầu vào **(12/10)** | `PKT` + 6 số | `PKT000123` | |
| Ghi danh **(12/10)** | `GD` + 6 số | `GD000123` | |
| Phiếu tái tục **(12/10)** | `TT` + 6 số | `TT000123` | Lịch hẹn không có mã cho người đọc, giống buổi học |
| Giáo viên, trợ giảng | `GV`/`TG` + số đang dùng | `GV2007`, `TG8002` | Giữ số hiện tại (2xxx GV, 8xxx TG) |
| Nhân viên | `NV` + 4 số | `NV0012` | |
| Lớp chung | `CS-Năm-Môn-Khối-Phânloại-Trìnhđộ-STT` | `CS5-2627-TOAN-K08-CB-A-001` | Tên cũ `8A1` là tham chiếu. **(17/10)** Lớp thuộc nhóm lớp (R-LOP-14): nhóm không có mã riêng, số thứ tự cấp riêng từng lớp |
| Lớp riêng | `CS-Năm-Môn-Khối-LR-STT` | `CS2-2627-TOAN-K09-LR-014` | Không có trình độ |
| Khung chương trình | `Môn-Khối-Cấpđộ-Năm` | `TOAN-K03-CB-2627` | Sửa khung thì tạo bản mới, lớp cũ giữ khung cũ |
| Bài học | Mã khung + `B` + số bài | `TOAN-K03-CB-2627-B05` | Tên bài lấy từ khung |
| Gói bán **(12/10)** | `Loại-Môn-Khối` hoặc `Loại-Môn-KhốiđầuKhốicuối` | `LC-TOAN-K09`, `VIP-TOAN-K03K07`, `DV-CSGK`, `TL-MATOAN` | **Không chứa hình thức**: một gói có hai giá offline/online ở bảng giá có ngày hiệu lực; giá trống = không bán hình thức đó. (Bản 09/10 có hình thức ở cuối mã, vd `LC-TOAN-K09-OFF`: bỏ) |
| Buổi học | Không có mã cho người đọc | hiển thị `8A1 · Buổi 12 · 15/08/2026` | Chỉ ID nội bộ |
| Chứng từ | `Loại-CS-NămTháng-STT` | `BG-CS1-2610-0001` báo giá, `DH-…` đơn, `PT-…` phiếu thu, `PC-…` phiếu chi, `KTV-…` khoản tiền vào **(12/10)**, `DN-…` đề nghị, `KN-…` khiếu nại | Số thứ tự riêng từng cơ sở, liên tục. **(12/10)** Khoản đảo dùng chung dãy `KTV`, số tiền âm |

## Tình trạng
- **Học sinh** (một giá trị cho một em): Tiềm năng, Đang học, Bảo lưu, Dừng học.
- **Ghi danh** (mỗi ghi danh một giá trị; dưới ghi danh là các dòng xếp lớp): Chờ xếp lớp, Đã xếp lớp **(12/10)**, Đang học, Bảo lưu, Hoàn thành, Chuyển lớp, Dừng, Hoàn phí. Chờ xếp lớp = chưa có dòng xếp lớp đang mở; Đã xếp lớp = có lớp nhưng chưa có buổi Done; Đang học từ buổi Done đầu tiên (R-GD-05).
- Tạm nghỉ = Bảo lưu. Không có "Lớp phụ". Loại hình cũ "LC+HR" tách thành hai ghi danh.

## Điểm danh
| Mã | Tên hiển thị | Ký hiệu cũ |
|---|---|---|
| `CO_MAT` | Có mặt | `X`, `x` |
| `DI_MUON` | Đi muộn | mới |
| `VANG_CO_PHEP` | Vắng có phép | `P`, `p` |
| `VANG_KHONG_PHEP` | Vắng không phép | `KP` |
| (trống) | Chưa điểm danh | ô trống |

`N` trên Sheet = buổi đó cả lớp nghỉ (buổi huỷ không tính phí), không phải trạng thái của một em.

## Toán tách Đại số và Hình học
- Từ **khối 7**, lớp Toán chia thành hai lớp riêng `DAI` và `HINH`, mỗi lớp có giáo viên, lịch, khung chương trình riêng. Khối 2-6 học một lớp `TOAN`.
- Phụ huynh mua **tổng giờ Toán**. Gói và ghi danh chỉ có môn `TOAN`; không có giờ Đại, giờ Hình. *[17/10: vênh R-GD-14 mới (hai ghi danh riêng, mỗi ghi danh một quỹ giờ); chờ anh quyết, chưa đổi chữ.]*
- **(17/10) Nhóm lớp** (R-LOP-14): hai lớp `DAI` và `HINH` cùng khối, cùng cơ sở gắn vào một nhóm; nhóm **không có mã riêng**, mã mỗi lớp giữ nguyên; tên chung của nhóm (ví dụ tên cũ 9M1) là tham chiếu tự do, tuỳ chọn. Mỗi lớp vẫn độc lập. **Luân phiên** Đại, Hình cùng thứ, giờ: dùng cách lặp "mỗi N tuần" của khung giờ (R-LOP-13); trùng giờ kiểm ở cấp buổi thật (R-GD-15).

### Luật ghi danh và xếp lớp
1. **(17/10)** Mỗi dòng đơn sinh **một ghi danh, một quỹ giờ**, và mỗi dòng đơn chỉ chọn **một lớp**. Toán khối 7+ học cả Đại và Hình thì **hai dòng đơn riêng** (một lớp DAI, một lớp HINH), thành hai ghi danh riêng, mỗi ghi danh một quỹ giờ riêng; khi lập đơn hệ thống nhắc (không chặn) nếu học sinh mới có một trong hai (R-GD-14, thay bản 12/10).
2. Ghi danh có các **dòng xếp lớp**: lớp, ngày vào, ngày rời, tình trạng. **(17/10)** Bình thường một ghi danh có một lớp đang học; chuyển lớp thì đóng dòng cũ, mở dòng mới, giờ còn lại đi theo ghi danh (R-GD-02). Sĩ số, danh sách lớp, điểm danh đọc từ dòng xếp lớp.
3. Ghi danh Toán khối 7+ vào lớp chung: gợi ý xếp một lớp `DAI` và một lớp `HINH`. Chỉ một lớp thì cảnh báo, không chặn. *[CHỜ anh quyết 17/10: chuyển gợi ý Đại + Hình lên bước lập đơn; chưa đổi chữ.]*
4. Đổi lớp Hình thì đóng dòng xếp lớp Hình, mở dòng mới; lớp Đại giữ nguyên. Đại và Hình được ở hai lớp khác số.
5. Bảo lưu, dừng, hết giờ, hoàn phí thao tác ở cấp ghi danh, áp cho mọi lớp đang xếp. *[CHỜ anh quyết 17/10: một ticket đề nghị chọn nhiều ghi danh; chưa đổi chữ.]*
6. Buổi Done ở lớp nào cũng trừ cùng một quỹ. Số giờ Đại/Hình xem trong báo cáo. *[CHỜ anh quyết 17/10: quỹ theo từng ghi danh; chưa đổi chữ.]*
7. Dự báo ngày hết giờ cộng lịch mọi lớp đang xếp. *[CHỜ anh quyết 17/10: dự báo theo từng ghi danh; chưa đổi chữ.]*
8. Hợp lệ khi xếp: đúng môn của gói (gói `TOAN` → lớp `TOAN`, `DAI`, `HINH`), đúng loại lớp, đúng cơ sở, không trùng giờ với bất kỳ lớp nào em đang học (chặn, R-GD-15) **(12/10)**.
9. Lớp riêng khối 7+ giữ một lớp `TOAN`.

## Mã cũ (12/10)

Mã hệ thống Apps Script (`LEAD-2609-0001`, `OPP-…`, `TEST-…`, `ENR-…`, `UPS-…`, `SO-…`, `RCP-…`, `PAY-…`, `STU-…`) giữ ở cột `legacy_ref`, tìm kiếm được, hiện nhỏ dưới mã mới. **(17/10)** Phụ huynh **không có mã cũ** (hệ thống Sheet hiện tại không có mã phụ huynh): bỏ `CUST-…` khỏi danh sách; mã học sinh cũ `STU-…` hiện ở ô "Mã cũ (Sheet)" của hồ sơ học sinh (R-CRM-33), mã lớp cũ ở màn lớp (R-LOP-15).
