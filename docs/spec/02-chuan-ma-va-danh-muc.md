# Chuẩn mã và danh mục

Đã chốt với anh Trường ngày 09/10/2026.

## Nguyên tắc
1. **Hai lớp định danh.** ID nội bộ (uuid) chỉ máy dùng, không hiển thị, không bao giờ đổi. Mã nghiệp vụ cho người đọc, nói, tìm kiếm.
2. **Mã không chứa thông tin có thể đổi**: tên, số điện thoại, khối hiện tại, giáo viên, cơ sở của học sinh.
3. **Cấp một lần, không sửa, không dùng lại**, kể cả khi bản ghi bị huỷ. Mã do cơ sở dữ liệu cấp (sequence), không ai tự gõ.
4. **Định dạng cố định**: in hoa, không dấu, không khoảng trắng, số đủ chữ số.
5. **Danh mục dùng mã ngắn, tên hiển thị để riêng.** Đổi tên hiển thị không ảnh hưởng dữ liệu.
6. **Mã cũ trên Sheet giữ làm mã tham chiếu** (cột `legacy_ref`), tìm kiếm được.

## Danh mục gốc
| Danh mục | Mã | Ghi chú |
|---|---|---|
| Cơ sở | `CS1` Nguyễn Chí Thanh, `CS2` Đỗ Quang, `CS4` Hà Đông, `CS5` Mỹ Đình | Không có CS3 (Config cũ có dòng CS3 thừa, bỏ), không đánh số lại |
| Năm học | `2627` | Từ tháng 6 tới tháng 5 năm sau |
| Môn | `TOAN`, `DAI`, `HINH`, `LY`, `HOA`, `VAN`, `ANH`, `KHTN`, `TRUNG`, `SAT` | `DAI`, `HINH` chỉ dùng cho lớp, xem mục Đại/Hình |
| Khối | `K02` … `K12` | Hai chữ số |
| Phân loại lớp | `CB` cơ bản, `NC` nâng cao, `LR` lớp riêng | Lớp riêng là lớp bình thường, 1-2 em |
| Trình độ | `S`, `A`, `B`, `C` | S cao nhất. Chỉ cho lớp CB, NC |
| Cấp độ khung chương trình | `CB`, `NC` | |
| Hình thức | `OFF`, `ONL` | Thuộc ghi danh; lớp OMO nhận cả hai |

## Mã các đối tượng
| Đối tượng | Mẫu | Ví dụ | Ghi chú |
|---|---|---|---|
| Học sinh | `HS` + 6 số | `HS000123` | Một em một mã suốt đời, mọi cơ sở, mọi năm |
| Phụ huynh | `PH` + 6 số | `PH000045` | Người trả tiền, có thể nhiều con |
| Giáo viên, trợ giảng | `GV`/`TG` + số đang dùng | `GV2007`, `TG8002` | Giữ số hiện tại (2xxx GV, 8xxx TG) |
| Nhân viên | `NV` + 4 số | `NV0012` | |
| Lớp chung | `CS-Năm-Môn-Khối-Phânloại-Trìnhđộ-STT` | `CS5-2627-TOAN-K08-CB-A-001` | Tên cũ `8A1` là tham chiếu |
| Lớp riêng | `CS-Năm-Môn-Khối-LR-STT` | `CS2-2627-TOAN-K09-LR-014` | Không có trình độ |
| Khung chương trình | `Môn-Khối-Cấpđộ-Năm` | `TOAN-K03-CB-2627` | Sửa khung thì tạo bản mới, lớp cũ giữ khung cũ |
| Bài học | Mã khung + `B` + số bài | `TOAN-K03-CB-2627-B05` | Tên bài lấy từ khung |
| Gói bán | `Loại-Môn-Khối-Hìnhthức` | `LC-TOAN-K09-OFF`, `HRD-TOAN-K09-OFF` | Giá ở bảng giá riêng, có ngày hiệu lực |
| Buổi học | Không có mã cho người đọc | hiển thị `8A1 · Buổi 12 · 15/08/2026` | Chỉ ID nội bộ |
| Chứng từ | `Loại-CS-NămTháng-STT` | `DH-CS1-2610-0001`, `PT-CS1-2610-0001` | Số thứ tự riêng từng cơ sở, liên tục |

## Tình trạng
- **Học sinh** (một giá trị cho một em): Tiềm năng, Đang học, Bảo lưu, Dừng học.
- **Ghi danh** (mỗi ghi danh một giá trị; dưới ghi danh là các dòng xếp lớp): Chờ xếp lớp, Đang học, Bảo lưu, Hoàn thành, Chuyển lớp, Dừng, Hoàn phí.
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
- Phụ huynh mua **tổng giờ Toán**. Gói và ghi danh chỉ có môn `TOAN`; không có giờ Đại, giờ Hình.

### Luật ghi danh và xếp lớp
1. Mỗi lần mua sinh **một ghi danh, một quỹ giờ**.
2. Ghi danh có các **dòng xếp lớp**: lớp, ngày vào, ngày rời, tình trạng. Sĩ số, danh sách lớp, điểm danh đọc từ dòng xếp lớp.
3. Ghi danh Toán khối 7+ vào lớp chung: gợi ý xếp một lớp `DAI` và một lớp `HINH`. Chỉ một lớp thì cảnh báo, không chặn.
4. Đổi lớp Hình thì đóng dòng xếp lớp Hình, mở dòng mới; lớp Đại giữ nguyên. Đại và Hình được ở hai lớp khác số.
5. Bảo lưu, dừng, hết giờ, hoàn phí thao tác ở cấp ghi danh, áp cho mọi lớp đang xếp.
6. Buổi Done ở lớp nào cũng trừ cùng một quỹ. Số giờ Đại/Hình xem trong báo cáo.
7. Dự báo ngày hết giờ cộng lịch mọi lớp đang xếp.
8. Hợp lệ khi xếp: đúng môn của gói (gói `TOAN` → lớp `TOAN`, `DAI`, `HINH`), đúng loại lớp, đúng cơ sở, không trùng giờ.
9. Lớp riêng khối 7+ giữ một lớp `TOAN`.
