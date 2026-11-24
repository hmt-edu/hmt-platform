---
id: qt2
ten: Vai trò và ma trận quyền
vai: [quan-tri]
phan_he: quan-tri
ma_man: [QT-04, QT-05]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Vai trò và ma trận quyền

**Làm xong bạn có:** biết mỗi vai trò làm được gì, và (khi cần) đổi quyền của một vai trò, có hiệu lực ngay và có ghi lại ai đổi gì.
**Ai làm:** Admin. **Màn:** menu **Quản trị** → **Vai trò**, rồi **Ma trận quyền**.

> Video: [VIDEO: qt2]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Đổi quyền ảnh hưởng mọi người mang vai trò đó, ở mọi cơ sở, ngay khi lưu.** Mặc định màn chỉ để xem; muốn sửa phải bật công tắc trước (xem «Trước khi bắt đầu»). Tập thì chỉ tập trên staging.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin. Vai khác không thấy mục này.
- [ ] Chỉ **xem**: không cần gì thêm.
- [ ] Muốn **sửa**: tham số «Cho phép sửa ma trận quyền» (Quản trị → Cài đặt tham số, nhóm Đăng nhập, bảo mật) đang **Bật**. Đang tắt thì trên màn Ma trận quyền có dòng cảnh báo vàng «Sửa ma trận quyền đang tắt…» và không có nút «Sửa». Bật xong, làm xong việc thì nên tắt lại.
- [ ] Bạn đã biết chính xác vai trò nào, phân hệ nào, hành động nào cần đổi, và ai đồng ý.

## Luật cần nhớ (lời thường)
- Quyền = **vai trò × phân hệ × hành động**, mỗi ô có một **phạm vi dữ liệu** (ví dụ chỉ cơ sở của mình, hoặc toàn bộ) hoặc «Không có».
- Mỗi lần **Lưu thay đổi** tạo một **phiên bản mới**, có hiệu lực ngay. Không có «lưu nháp».
- Phân hệ **Quản trị** chỉ cấp cho Admin: ô của vai khác ở phân hệ này bị mờ, không sửa được.
- Chỉ vai **Kế toán** được có quyền «Kế toán · Duyệt» (duyệt tiền). Admin và vai khác không duyệt tiền, hệ thống chặn nếu gán.

## Các bước
1. Vào **Quản trị** → **Vai trò**. Xem bảng các vai trò, hoặc gõ vào ô «Tìm vai trò» (tên hoặc mã).
   *Bạn thấy:* mỗi dòng một vai trò, các cột «Phạm vi mặc định», «Cổng vào», «Hai bước» (Bắt buộc / Không), «Nhóm tự đăng xuất», «Số người», «Ô quyền».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt2-b1]
2. Bấm vào nút «Mở ma trận quyền của …» ở dòng vai trò bạn quan tâm (hoặc vào thẳng **Ma trận quyền**).
   *Bạn thấy:* tiêu đề «Ma trận quyền», dòng «Hiện hành: phiên bản N · lưu lúc …». Bên trái danh sách vai trò, bên phải bảng: mỗi hàng một phân hệ, mỗi cột một hành động, trong ô là phạm vi dữ liệu.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt2-b2]
3. Chọn vai trò ở danh sách bên trái để xem bảng quyền của vai đó. Nếu chỉ cần xem thì dừng ở đây.
   *Bạn thấy:* tiêu đề giữa bảng đổi theo tên vai trò đã chọn.
4. Muốn sửa: bấm **Sửa** (góc phải trên bảng). Mỗi ô thành hộp chọn; chọn «Không có» hoặc một phạm vi khác.
   *Bạn thấy:* ô đã đổi có **viền cam**; vai trò có ô đã đổi hiện nhãn «N ô sửa»; phía dưới có dòng «Đã đổi N ô…».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt2-b4]
5. (Tuỳ chọn) gõ «Ghi chú phiên bản» nói vì sao đổi (ví dụ: «Cho CSKH xuất danh sách lớp»).
6. Bấm **Lưu thay đổi**. Muốn bỏ thì bấm **Huỷ**.
   *Bạn thấy:* thông báo «Đã lưu phiên bản N, có hiệu lực ngay.»; dòng «Hiện hành» tăng số phiên bản; phần «Lịch sử thay đổi gần đây» có thêm dòng mới ghi từng ô đã đổi.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt2-b6]

⚠ **Bước 6 có hiệu lực ngay cho mọi người mang vai trò đó.** Người đang đăng nhập có thể cần tải lại trang mới thấy.

## Sau bước này
- **Ai làm tiếp:** người dùng mang vai trò đó thấy hoặc không thấy chức năng theo quyền mới.
- **Bạn xem ở đâu:** phần «Lịch sử thay đổi gần đây» ngay dưới ma trận (5 phiên bản mới nhất); đầy đủ hơn ở nhật ký thao tác (Quản trị → Nhật ký).

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Chọn nhầm ô, chưa lưu | Chọn lại giá trị cũ, hoặc bấm **Huỷ** để bỏ hết thay đổi |
| Đã lưu nhầm | Bấm **Sửa**, đặt lại các ô như cũ (xem giá trị cũ trong «Lịch sử thay đổi gần đây»), **Lưu thay đổi** (thành phiên bản mới; không có nút «quay về phiên bản cũ») |
| Quên tắt công tắc sửa sau khi xong | Vào Cài đặt tham số, tắt «Cho phép sửa ma trận quyền» |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Sửa ma trận quyền đang tắt…» (dòng vàng, không có nút Sửa) | công tắc sửa đang tắt | Bật tham số «Cho phép sửa ma trận quyền» nếu đã thống nhất |
| «Ma trận quyền vừa được lưu thành phiên bản N. Hãy tải lại rồi sửa tiếp.» | có Admin khác vừa lưu | Tải lại trang, xem thay đổi của họ, rồi sửa tiếp |
| «Chỉ vai trò Kế toán được có quyền Kế toán · Duyệt…» (HMT_CHI_KE_TOAN_DUYET_TIEN) | bạn gán quyền duyệt tiền cho vai khác | Bỏ ô đó. Muốn ai duyệt tiền thì gán **vai trò Kế toán** cho người đó |
| «Không tải được ma trận quyền» | lỗi mạng | Bấm «Thử lại» |

## Hỏi đáp
- **Vì sao ô của vai khác ở phân hệ Quản trị bị mờ?** Phân hệ Quản trị chỉ dành cho Admin, không đổi được.
- **Admin có duyệt được phiếu thu không?** Không. Duyệt tiền chỉ vai Kế toán.
- **Đổi quyền có xoá dữ liệu cũ không?** Không. Chỉ đổi người nào thấy và làm được gì từ lúc lưu.

## Tập trên dữ liệu mẫu
- **Cần:** `bgd.tap` (Admin) trên **staging**; một tài khoản vai khác (ví dụ `ql.cs5`) để thử thấy khác đi.
- **Dùng:** bật công tắc sửa, đổi một ô ít quan trọng của vai tập, lưu, nhờ tài khoản vai đó tải lại để thấy khác; rồi đặt lại như cũ và tắt công tắc.
- Chưa có trong bộ mẫu: vai trò riêng dành cho việc tập quyền.

## Tự kiểm: bạn làm được khi
- [ ] Bạn mở được ma trận của một vai trò và đọc đúng phạm vi ở một ô.
- [ ] Bạn nói được vì sao không thấy nút «Sửa».
- [ ] Bạn lưu một thay đổi, thấy phiên bản tăng và dòng mới trong lịch sử, rồi đặt lại như cũ.

**Bước trước:** Công tắc tính năng (qt6) · **Bước sau:** Danh mục

## Ghi chú cho người soát (không hiển thị cho người học)
- Chữ trên màn lấy từ `PermissionMatrixPage.tsx`, `RoleListPage.tsx`; câu lỗi từ migration 20261116000182 và 20261118000455.
- Bài cũ `quan-tri.md` §6 viết «không đổi trong lúc vận hành»; màn thật có nút Sửa khi công tắc bật. Bài theo màn thật.
- Chưa kiểm trên staging: tên chính xác nút/mục menu «Vai trò» (đối chiếu `crmMenu.ts`), việc người đang đăng nhập có cần tải lại.
