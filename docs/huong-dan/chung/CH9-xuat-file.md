---
id: ch9
ten: Xuất danh sách ra file
vai: [chung]
phan_he: chung
ma_man: [CHUNG-18]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Xuất danh sách ra file

**Làm xong bạn có:** một file CSV (mở bằng Excel hoặc Google Sheets) chứa các dòng của danh sách bạn đang xem, theo đúng bộ lọc bạn đã chọn.
**Ai làm:** người có quyền «Xuất» ở phân hệ đó (thường là Trưởng cơ sở, Kế toán, Admin; một số danh sách còn cho vai khác). **Màn:** nút **Xuất** ở thanh trên của danh sách.

> Video: [VIDEO: ch9]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **File chứa thông tin khách và học sinh.** Chỉ dùng cho việc công ty, không gửi qua ứng dụng cá nhân, không để trên máy dùng chung. **Mọi lần xuất đều được ghi lại** (ai, danh sách nào, bao nhiêu dòng, bộ lọc nào).

## Trước khi bắt đầu, kiểm
- [ ] Danh sách bạn mở có nút **Xuất** ở thanh trên. Không có nút nghĩa là vai của bạn chưa có quyền xuất danh sách này; không tự tìm cách khác, hỏi Admin hoặc Trưởng cơ sở.
- [ ] Bạn đã đặt **bộ lọc** đúng thứ cần (xem bài «Danh sách: tìm, Filters, Group By…»). File chỉ gồm các dòng khớp bộ lọc.
- [ ] Bạn biết mục đích dùng file.

## Luật cần nhớ (lời thường)
- Có nút **Xuất** là có quyền. Hệ thống kiểm lại quyền khi xuất, nên không dùng được mẹo.
- Mỗi lần xuất có **giới hạn số dòng** (mặc định 5.000 dòng, mới nhất trước). Quá giới hạn thì file chỉ gồm phần mới nhất và có thông báo cho bạn.
- Chỉ xuất các dòng bạn **được phép xem** (theo cơ sở). File không chứa dòng ngoài phạm vi của bạn.
- Tên cột trong file là chữ tiếng Việt, giá trị là tên (không phải mã nội bộ).

## Các bước
1. Mở danh sách cần xuất (ví dụ Cơ hội, Lịch hẹn, Báo giá, Đơn hàng, Người dùng).
2. Đặt bộ lọc và tìm kiếm cho ra đúng các dòng cần.
   *Bạn thấy:* số dòng tổng ở góc phân trang đúng với số bạn định xuất.
   [CHƯA CHỤP: cần staging; ảnh dự kiến chung-ch9-b2]
3. Bấm **Xuất** ở thanh trên. Chờ vài giây; nút quay tròn trong lúc đang xuất, đừng bấm lại.
   *Bạn thấy:* trình duyệt tải về một file `.csv` (tên có ngày, ví dụ `co-hoi-2026-11-24.csv`) và thông báo «Đã xuất N dòng.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến chung-ch9-b3]
4. Mở file từ thư mục tải về. Trong Excel: nếu chữ tiếng Việt lỗi, dùng **Dữ liệu → Từ văn bản/CSV**, chọn mã hoá UTF-8. Google Sheets: **Tệp → Nhập**.
   *Bạn thấy:* dòng đầu là tên cột, các dòng sau là dữ liệu.

⚠ **Bước 3 không thu hồi được.** Xuất xong coi như đã có file ngoài hệ thống; xoá file khi dùng xong.

## Sau bước này
- **Ai làm tiếp:** tuỳ mục đích của bạn.
- **Bạn xem ở đâu:** Admin xem lịch sử xuất ở **Quản trị** → **Nhật ký đăng nhập, xuất file** → tab **Xuất file**.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Xuất nhầm bộ lọc | Xoá file, đặt lại bộ lọc, xuất lại. Lần xuất nhầm vẫn nằm trong nhật ký, không cần báo |
| Lỡ gửi file cho người không liên quan | Báo ngay Trưởng cơ sở hoặc Admin |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Đã xuất N trên M dòng (quá giới hạn mỗi lần xuất). Thêm bộ lọc để xuất phần còn lại.» | số dòng vượt giới hạn | Thêm bộ lọc (ví dụ theo tháng) và xuất từng phần |
| Chữ tiếng Việt thành ký tự lạ trong Excel | Excel mở sai mã hoá | Mở bằng **Dữ liệu → Từ văn bản/CSV**, chọn UTF-8 |
| Không có nút **Xuất** | vai của bạn chưa có quyền | Hỏi Admin hoặc Trưởng cơ sở |
| Thông báo lỗi sau khi bấm Xuất | mất mạng hoặc quyền đổi giữa chừng | Bấm lại; vẫn lỗi thì báo kèm mã lỗi HMT_… (xem bài «Gặp lỗi») |

## Hỏi đáp
- **File có xuất được hình ảnh, tệp đính kèm không?** Không, chỉ chữ và số.
- **Có xuất được ngoài phạm vi cơ sở của tôi không?** Không.
- **Admin có biết tôi đã xuất gì không?** Có. Lần xuất được ghi tên bạn, danh sách, số dòng và bộ lọc.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản vai có quyền xuất (ví dụ `ql.cs5` Quản lý cơ sở) trên **staging**.
- **Dùng:** mở **Cơ hội**, lọc theo một giai đoạn, bấm **Xuất**, mở file; rồi nhờ Admin xem dòng mới ở tab «Xuất file».

## Tự kiểm: bạn làm được khi
- [ ] Bạn xuất được một danh sách đã lọc và mở file đọc được tiếng Việt.
- [ ] Bạn nói được vì sao file ít dòng hơn tổng (giới hạn, bộ lọc, phạm vi cơ sở).
- [ ] Bạn nói được lần xuất của bạn được ghi ở đâu.

**Bước trước:** Danh sách (CH4) · **Bước sau:** Gặp lỗi (CH10)

## Ghi chú cho người soát (không hiển thị cho người học)
- Nhãn «Xuất» và thông báo từ `OpportunityListPage.tsx` (hàm `exportFile`); giới hạn mặc định từ tham số `export_max_rows` = 5000 (migration 20261019000033; admin đổi được ở Cài đặt tham số).
- Danh sách có nút Xuất theo mã: Cơ hội, Lịch hẹn, Người dùng (chỉ Admin), Báo giá, Đơn hàng, Phiếu kiểm tra; Báo cáo trễ hạn có «Xuất CSV» riêng. Danh sách khác (Lớp: học sinh) chưa có nút. Chưa kiểm nút có hiện đúng theo vai trên staging.
- Mã hoá file (UTF-8, có dấu BOM hay không) chưa kiểm: cần mở thử bằng Excel.
- Bản đồ màn hình CHUNG-18 mô tả «Chọn cột, phạm vi, định dạng»; màn thật tải thẳng CSV, không có hộp chọn cột. Bài theo màn thật.
