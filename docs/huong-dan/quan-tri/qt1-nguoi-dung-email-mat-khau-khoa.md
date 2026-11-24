---
id: qt1
ten: Người dùng - tạo, sửa email, đặt lại mật khẩu, khoá và mở khoá
vai: [quan-tri]
phan_he: quan-tri
ma_man: [QT-01, QT-02, QT-03]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Người dùng: tạo, sửa email, đặt lại mật khẩu, khoá và mở khoá

**Làm xong bạn có:** một tài khoản nhân viên, giáo viên hoặc trợ giảng dùng được; hoặc một tài khoản đã đổi email, đổi mật khẩu tạm, bị khoá hay được mở lại.
**Ai làm:** Admin (Ban giám đốc). **Màn:** menu **Quản trị** → **Người dùng**.

> Video: [VIDEO: qt1]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

⚠ **Đây là thao tác thật trên môi trường đang dùng.** Tập thì chỉ tập trên staging (xem mục «Tập trên dữ liệu mẫu»).

## Trước khi bắt đầu, kiểm
- [ ] Bạn đăng nhập bằng tài khoản Admin. Không phải Admin thì danh sách chỉ xem, không có nút «Tạo người dùng».
- [ ] Bạn có sẵn: họ tên người cần tạo, email công việc của họ, cơ sở, và vai trò (một hoặc nhiều).
- [ ] Bạn có cách giao mật khẩu tạm an toàn (gặp trực tiếp hoặc tin nhắn riêng), không gửi vào nhóm chung.

## Luật cần nhớ (lời thường)
- Mật khẩu tạm chỉ hiện **một lần**. Đóng hộp là không xem lại được; mất thì đặt lại mật khẩu.
- Người dùng phải đổi mật khẩu ở lần đăng nhập đầu tiên.
- Tên đăng nhập và mã nhân sự không đổi được sau khi tạo. Mỗi người chỉ thuộc **một cơ sở**, nhưng có thể có **nhiều vai trò**.
- Mỗi email chỉ dùng cho một tài khoản.
- Không có nút xoá người dùng. Người nghỉ việc thì **Khoá**, mở lại được.
- Hệ thống luôn giữ ít nhất một Admin: không khoá, không bỏ vai trò của Admin cuối cùng.
- Bạn không tự khoá mình và không tự đổi email của mình ở đây; nhờ Admin khác.
- Xác thực hai bước: chỉ Admin thuộc diện này, và chỉ khi công tắc hai bước trong Cài đặt tham số nghiệp vụ đang **Bật** (mặc định đang Tắt). Kế toán không còn bị bắt hai bước.

## Các bước (tạo người dùng mới)
1. Vào **Quản trị** → **Người dùng**, bấm «Tạo người dùng».
   *Bạn thấy:* khung bên phải tên «Tạo người dùng», dòng «Tài khoản nhân viên, giáo viên, trợ giảng.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt1-b1]
2. Điền «Tên hiển thị», «Tên đăng nhập» (hệ thống gợi ý theo tên, bạn sửa được) và «Email».
   *Bạn thấy:* nếu trùng, báo ngay dưới ô: «Tên đăng nhập này đã có người dùng.» hoặc «Email này đã dùng cho tài khoản khác.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt1-b2]
3. Chọn «Cơ sở» (một cơ sở), «Loại nhân sự» (Nhân viên, Giáo viên, Trợ giảng), rồi bấm «Thêm vai trò» để chọn vai trò (được chọn nhiều).
   *Bạn thấy:* mỗi vai trò đã chọn hiện thành một thẻ, có dấu × để bỏ. Ô «Mã nhân sự» ghi «Tự cấp khi tạo»: bạn không nhập.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt1-b3]
4. Bấm «Tạo tài khoản».
   *Bạn thấy:* hộp «Mật khẩu tạm» với mật khẩu và nút «Chép mật khẩu». Bấm xong nút này đổi thành «Đã chép».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt1-b4]
5. Chép mật khẩu (hoặc bôi đen và chép tay nếu hiện «Không chép được vào bộ nhớ tạm. Bôi đen và chép tay.»), giao cho người dùng, rồi bấm «Xong».
   *Bạn thấy:* nếu chưa chép mà bấm «Xong», hộp báo «Chưa chép mật khẩu. Đóng hộp này là không xem lại được; bấm Xong lần nữa nếu đã ghi lại.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt1-b5]

⚠ **Bước 5 không hoàn tác.** Đóng hộp rồi, mật khẩu tạm biến mất; chỉ lấy lại được bằng cách đặt lại mật khẩu (phần dưới).

## Các việc khác trên một người dùng đã có
Mở người đó từ danh sách (ô «Tìm tên, email, mã NV/GV/TG…»), rồi dùng nút «Hành động» ở đầu trang. Mỗi việc là một hộp xác nhận ngắn:

| Muốn làm | Chọn trong «Hành động» | Bạn thấy / kết quả |
|---|---|---|
| Đổi email đăng nhập | «Sửa email» → ô «Email mới» → «Lưu email» | «Đã lưu email mới.» Tên đăng nhập giữ nguyên; người này bị đăng xuất mọi thiết bị và đăng nhập lại bằng email mới. |
| Cấp lại mật khẩu | «Đặt lại mật khẩu» → «Đặt lại mật khẩu» | Hộp «Mật khẩu tạm» như bước 4. Mật khẩu cũ hết hiệu lực ngay, người này bị đăng xuất khỏi mọi thiết bị, và phải đổi ở lần đăng nhập kế tiếp. |
| Khoá | «Khoá» (hoặc nút «Khoá» ngay ở dòng trong danh sách) → chọn «Lý do» → «Khoá» | «Đã khoá tài khoản.» Trạng thái đổi thành «Đã khoá»; người này không đăng nhập được và bị đăng xuất. |
| Mở khoá | «Mở khoá» → «Mở khoá» | «Đã mở khoá tài khoản.» Người này đăng nhập lại bằng mật khẩu hiện có. |
| Đăng xuất mọi máy | «Thu hồi phiên» | «Đã thu hồi phiên.» |
| Đổi vai trò, cơ sở, quản lý | «Sửa vai trò», «Đổi cơ sở», «Quản lý trực tiếp» | «Đã lưu vai trò.», «Đã đổi cơ sở.», «Đã lưu quản lý trực tiếp.» Đổi cơ sở thì người này bị đăng xuất và đăng nhập lại. |
| Xoá thiết bị hai bước (mất điện thoại) | «Đặt lại hai bước» | «Đã đặt lại hai bước.» |

Lý do khoá chọn từ danh sách: Nghỉ việc, Dừng học, Tạm nghỉ, Nghi lộ mật khẩu, Khác. Chọn «Khác» thì phải ghi «Ghi chú».
[CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt1-b6 (menu «Hành động»), quan-tri-qt1-b7 (hộp «Khoá tài khoản»)]

## Sau bước này
- **Ai làm tiếp:** người dùng đăng nhập bằng mật khẩu tạm và tự đổi mật khẩu. Nếu cần duyệt đơn qua một quản lý, đặt «Quản lý trực tiếp» cho họ.
- **Bạn xem ở đâu:** mở người đó, mục «Tài khoản» (Trạng thái, Đăng nhập gần nhất), mục «Phân quyền» (Mật khẩu: «Phải đổi ở lần đăng nhập sau» cho tới khi họ đổi), và «Lịch sử đăng nhập».

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Đóng hộp mật khẩu tạm khi chưa chép | «Hành động» → «Đặt lại mật khẩu» để có mật khẩu mới |
| Gõ sai email | «Hành động» → «Sửa email» |
| Chọn sai vai trò hoặc cơ sở | «Sửa vai trò», «Đổi cơ sở» (người đó phải đăng nhập lại) |
| Khoá nhầm người | «Mở khoá» |
| Tên đăng nhập hoặc mã nhân sự sai | Không đổi được. Khoá tài khoản đó và tạo tài khoản mới |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Chưa tạo được.» kèm lý do | thiếu hoặc trùng thông tin | đọc dòng lý do, sửa ô tương ứng |
| «Tên đăng nhập này đã có người dùng.» (HMT_TEN_DANG_NHAP_TRUNG) | trùng tên đăng nhập | đổi tên đăng nhập |
| «Email này đã dùng cho tài khoản khác.» (HMT_EMAIL_TRUNG) | trùng email | dùng email khác |
| «Email mới trùng email hiện tại.» | chưa đổi gì | nhập email khác |
| «Không thể khoá hoặc bỏ vai trò của quản trị viên cuối cùng. Hãy cấp vai trò ADMIN cho người khác trước.» (HMT_ADMIN_CUOI_CUNG) | đang là Admin cuối cùng | cấp vai Admin cho người khác trước |
| «Không tự khoá tài khoản của mình.» (HMT_KHONG_TU_KHOA) | tự khoá mình | nhờ Admin khác |
| «Admin không tự đổi email của mình ở đây; nhờ Admin khác.» (HMT_KHONG_TU_DOI_EMAIL) | tự đổi email mình | nhờ Admin khác |

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản tập `bgd.tap` (Ban Giám Đốc, Admin; hai bước chỉ cần khi công tắc hai bước đang Bật) và `ql.cs5` (Quản lý cơ sở) để thử «Quản lý trực tiếp». Chỉ làm trên **staging**.
- **Dùng:** tạo người dùng tên có chữ «MẪU» hoặc «tập» để dễ nhận ra; thử Khoá rồi Mở khoá chính tài khoản mẫu đó, không đụng tài khoản của người thật.
- Chưa có trong bộ mẫu: người dùng «nhân viên mới» sẵn để tạo; bạn tự tạo một người rồi dùng lại.

## Tự kiểm: bạn làm được khi
- [ ] Bạn tạo được một người dùng mẫu, chép được mật khẩu tạm, và nói được vì sao không xem lại được.
- [ ] Bạn đặt lại mật khẩu, khoá và mở khoá được một tài khoản mẫu.
- [ ] Bạn nói được vì sao không khoá được Admin cuối cùng.

**Bước trước:** (đầu bài) · **Bước sau:** Cơ sở và phòng học (qt4)

## Ghi chú cho người soát (không hiển thị cho người học)
- Vênh bài cũ `quan-tri.md`: bài cũ viết «Admin cần thiết lập hai bước khi đăng nhập» và «Đặt lại hai bước cho Admin hoặc Kế toán». Theo mã nguồn: migration 20261118000472 (D41) đặt hai bước bắt buộc chỉ khi tham số `mfa_required_enabled` Bật (mặc định Tắt); migration 20261123000647 (A-23-27) đặt `require_mfa=false` cho ACCOUNTANT nên chỉ còn Admin. Bài này viết theo đó. Hộp «Đặt lại hai bước» trên màn vẫn hiện chữ riêng theo từng vai.
- Bài cũ gọi mật khẩu tạm là «Mật khẩu tạm» và có nút chép: khớp mã nguồn («Chép mật khẩu»).
- Tên vai Admin trong bảng vai trò (migration 009) là «Ban giám đốc, IT»; canvas đã đổi tên vai trò ở v152 nhưng chưa xác nhận tên hiển thị hiện hành trên màn: kiểm trên staging trước khi chụp ảnh.
- Tên nhãn ô «Lý do» trong hộp «Khoá tài khoản» lấy theo mặc định của khuôn hộp (`reasonLabel = 'Lý do'`, `noteLabel = 'Ghi chú'`), chưa xác nhận trên màn thật.
- Chưa xác nhận tài khoản tập `bgd.tap`, `ql.cs5` và biến SEED_PRACTICE: không thấy trong `scripts/` của nhánh này.
- Không đọc mã nguồn kỹ nút «Xuất» ở danh sách (có tồn tại ở UserListPage); bài không nói về nó.
