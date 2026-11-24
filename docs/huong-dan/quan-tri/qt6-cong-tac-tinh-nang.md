---
id: qt6
ten: Công tắc tính năng theo cơ sở
vai: [quan-tri]
phan_he: quan-tri
ma_man: [QT-10]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Công tắc tính năng theo cơ sở

**Làm xong bạn có:** một phân hệ (ví dụ Vận hành lớp, Hoàn phí) được bật hoặc tắt đúng cho cơ sở bạn muốn.
**Ai làm:** Admin. **Màn:** menu **Quản trị** → **Công tắc tính năng**.

> Video: [VIDEO: qt6]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Đây là thao tác thật trên môi trường đang dùng.** Tắt một phân hệ là người dùng của cơ sở đó dùng không được ngay. Tập thì chỉ tập trên staging.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin. Vai khác chỉ thấy bảng với chữ «Bật» / «Tắt», không bấm đổi được.
- [ ] Bạn đã thống nhất với người phụ trách cơ sở là sẽ bật hay tắt phân hệ nào, lúc nào.

## Luật cần nhớ (lời thường)
- Công tắc theo từng **phân hệ** và từng **cơ sở**. Phân hệ chưa có công tắc nghĩa là **Tắt**.
- Tắt: người dùng của cơ sở không dùng được phân hệ đó nữa, **kể cả việc đang làm dở**.
- Bật: người dùng của cơ sở dùng được phân hệ theo quyền của vai trò họ. Bật công tắc không tự tạo dữ liệu.
- Cả giao diện lẫn phần xử lý bên trong đều kiểm công tắc này.
- Phân hệ «Cổng giáo viên» không có công tắc (cổng giáo viên chạy theo vai trò).
- Hiện đã bật chạy thử ở CS5 trước.

## Các bước
1. Vào **Quản trị** → **Công tắc tính năng**.
   *Bạn thấy:* tiêu đề «Công tắc tính năng». Bảng: cột «Phân hệ» (tên ngắn, bên dưới là tên đầy đủ), mỗi cơ sở một cột (mã CS), cột «Đang bật» ghi dạng «2/5».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt6-b1]
2. Tìm dòng phân hệ và cột cơ sở, bấm vào ô «Bật» hoặc «Tắt» ở giao điểm.
   *Bạn thấy:* hộp «Bật phân hệ cho cơ sở» (hoặc «Tắt phân hệ ở cơ sở») ghi «Phân hệ», «Cơ sở», «Trạng thái mới».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt6-b2]
3. Đọc dòng giải thích trong hộp, rồi bấm «Bật» (hoặc «Tắt») để xác nhận.
   *Bạn thấy:* thông báo «Đã bật phân hệ.» hoặc «Đã tắt phân hệ.», ô đổi nhãn, cột «Đang bật» cập nhật.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt6-b3]

⚠ **Bước 3 tắt có hiệu lực ngay.** Hoàn tác bằng cách bật lại đúng ô đó; việc đang làm dở sẽ tiếp tục dùng được.

## Sau bước này
- **Ai làm tiếp:** người dùng của cơ sở làm việc trong phân hệ như bình thường (nếu vai trò của họ có quyền).
- **Bạn xem ở đâu:** bảng này, cột «Đang bật». Mọi lần đổi có trong nhật ký thao tác.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Bật nhầm | Bấm lại ô đó, chọn «Tắt» |
| Tắt nhầm | Bấm lại ô đó, chọn «Bật» |
| Bật nhầm cơ sở | Tắt ở cơ sở đó, bật đúng cơ sở. Dữ liệu đã tạo trong lúc bật vẫn còn |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Phân hệ "<tên>" chưa bật ở cơ sở <mã>.» (HMT_TINH_NANG_TAT), hiện ở màn nghiệp vụ của người dùng | phân hệ đang Tắt cho cơ sở đó | Admin vào màn này và bật nếu đã thống nhất |
| «Không tải được công tắc» | lỗi mạng | bấm «Thử lại» |

## Tập trên dữ liệu mẫu
- **Cần:** `bgd.tap` (Admin) trên **staging**; `ql.cs5` (Quản lý cơ sở) để xem hiệu quả sau khi đổi.
- **Dùng:** chọn một phân hệ ít quan trọng (ví dụ «Sắp hết giờ») ở một cơ sở tập, tắt rồi bật lại, ghi lại hiện tượng trên tài khoản `ql.cs5`. Không đổi công tắc của cơ sở người dùng thật đang làm việc trên staging dùng chung mà chưa báo.
- Chưa có trong bộ mẫu: cơ sở riêng dành cho việc tập công tắc.

## Tự kiểm: bạn làm được khi
- [ ] Bạn tắt rồi bật lại một công tắc ở cơ sở tập và thấy thông báo «Đã tắt phân hệ.», «Đã bật phân hệ.».
- [ ] Bạn nói được điều gì xảy ra với việc đang làm dở khi tắt.
- [ ] Bạn nói được câu báo «chưa bật ở cơ sở» nghĩa là gì và ai xử lý.

**Bước trước:** Cơ sở và phòng học (qt4) · **Bước sau:** Nhập dữ liệu cũ (qt8)

## Ghi chú cho người soát (không hiển thị cho người học)
- Vênh bài cũ `quan-tri.md` mục 5: bài cũ viết «phân hệ hiện hoặc ẩn khỏi menu». Chữ trên màn thật nói về «không dùng được nữa, kể cả việc đang làm dở»; bài theo màn thật, không nói chuyện ẩn menu (chưa xác nhận menu có ẩn thật).
- Bài cũ liệt kê «Thu nợ đầu kỳ» là một công tắc: không thấy phân hệ này trong mã (các phân hệ có kiểm công tắc: BAN_HANG, VAN_HANH_LOP, AFTERSALE, HOC_TAP, BAO_LUU, CHUYEN_LOP, HOAN_PHI, DUNG_HOC, HOC_THU, YEU_CAU_BUOI, SAP_HET_GIO, DIEM_DANH_TRONG_NGAY; «Báo cáo» có trong danh mục). Bài không liệt kê cụ thể.
- Công tắc «Cổng giáo viên» đã bị loại khỏi bảng (featureLogic.ts, anh chốt 23/11/2026).
- Ví dụ «Sắp hết giờ» trong mục tập chưa xác nhận có trong bảng trên staging (cần kiểm khi tập).
- Cột cơ sở trong bảng chỉ gồm cơ sở dạy học (`teachingBranches`), không có Hội sở.
