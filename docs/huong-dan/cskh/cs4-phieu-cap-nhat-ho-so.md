---
id: cs4
ten: Phiếu Cập nhật hồ sơ
vai: [cskh]
phan_he: Chăm sóc khách hàng
ma_man: [CS-04, CS-08]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Phiếu Cập nhật hồ sơ

**Làm xong bạn có:** thông tin hồ sơ học sinh hoặc phụ huynh (ví dụ tên trường, khối, địa chỉ) đã đổi theo đề nghị của phụ huynh, có người duyệt và có lịch sử trước và sau.
**Ai làm:** CSKH lập phiếu và thực hiện; **Trưởng cơ sở duyệt** (bạn không tự duyệt phiếu bạn lập). **Màn:** ticket → «Tạo phiếu»; «Chăm sóc khách hàng» → «Phiếu nghiệp vụ».

> Video: [VIDEO: cs4]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Có ticket Đề nghị với nhóm «Hồ sơ», nhóm con «Cập nhật thông tin học sinh, phụ huynh». Chưa có thì tạo theo bài «Tạo ticket và xử lý». Ticket chưa «Đã đóng», «Đã huỷ», chưa có phiếu nào đang mở.
- [ ] Muốn sửa hồ sơ học sinh thì ticket phải gắn học sinh đó (ô «Học sinh» ở khối «Liên kết»). Sửa hồ sơ phụ huynh thì ticket có «Người gửi» là phụ huynh đúng.
- [ ] Bạn biết giá trị mới (ví dụ tên trường đúng) và có người duyệt: Trưởng cơ sở của cơ sở đó.

## Luật cần nhớ (lời thường)
- **Chỉ sửa được vài trường.** Học sinh: «Trường», «Loại trường», «Khối», «Mục tiêu», «Giới tính». Phụ huynh: «Họ tên phụ huynh», «Địa chỉ», «Người thân».
- **Không sửa được số điện thoại, mã khách, cơ sở tiếp nhận, họ tên học sinh** bằng phiếu này: đây là thông tin định danh hồ sơ. Gặp việc này thì báo quản lý hoặc quản trị.
- Chỉ ô nào bạn gõ mới đổi; **ô để trống là giữ nguyên**.
- Người lập phiếu không tự duyệt. Phiếu một cấp: Trưởng cơ sở duyệt (Admin duyệt thay được khi vắng).
- Chưa duyệt thì hồ sơ **chưa đổi**. Chỉ khi bấm «Thực hiện» hồ sơ mới đổi thật; hệ thống lưu giá trị cũ và mới.

## Các bước
1. Mở ticket «Cập nhật thông tin học sinh, phụ huynh», bấm «Tạo phiếu».
   *Bạn thấy:* hộp «Tạo phiếu Cập nhật hồ sơ», dưới tiêu đề ghi mã ticket, ô «Hồ sơ cần sửa» đang chọn «Học sinh».
   [CHƯA CHỤP: cần staging; ảnh dự kiến cskh-cs4-b1]
2. Chọn «Hồ sơ cần sửa» là «Học sinh» hoặc «Phụ huynh».
   *Bạn thấy:* danh sách ô bên dưới đổi theo: mỗi ô có dạng «Trường (giá trị mới)», «Địa chỉ (giá trị mới)»…
   [CHƯA CHỤP: cần staging; ảnh dự kiến cskh-cs4-b2]
3. Gõ giá trị mới vào đúng ô cần đổi, các ô còn lại để trống. Gõ «Lý do» (vì sao sửa, ví dụ «Phụ huynh báo trường mới»).
   *Bạn thấy:* nếu bấm lưu mà chưa nhập ô nào, dưới ô hiện «Nhập giá trị mới cho ít nhất một trường.»; thiếu lý do hiện «Nhập lý do của phiếu.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến cskh-cs4-b3]
4. Bấm «Tạo phiếu».
   *Bạn thấy:* báo «Đã tạo phiếu ở bước Nháp.», trang phiếu mở ra, khối «Nội dung cập nhật (học sinh)» hoặc «(phụ huynh)» liệt kê tên trường và giá trị mới bạn vừa nhập.
   [CHƯA CHỤP: cần staging; ảnh dự kiến cskh-cs4-b4]
5. Kiểm lại nội dung, bấm «Gửi duyệt».
   *Bạn thấy:* trạng thái «Chờ duyệt»; bảng «Các cấp duyệt» có một dòng «Cấp 1», vai «Quản lý cơ sở», kết quả đang chờ.
   [CHƯA CHỤP: cần staging; ảnh dự kiến cskh-cs4-b5]
6. **Nhờ Trưởng cơ sở duyệt** (người khác bạn): họ vào «Việc chờ tôi duyệt» hoặc «Phiếu nghiệp vụ» → «Chờ tôi duyệt», mở phiếu, bấm «Duyệt», rồi «Duyệt» trong hộp «Duyệt phiếu». Bạn tự bấm duyệt sẽ bị chặn.
   *Bạn thấy:* với bạn, trạng thái sang «Đã duyệt»; dòng «Duyệt xong lúc» có giờ.
   [CHƯA CHỤP: cần staging; ảnh dự kiến cskh-cs4-b6]
7. Mở lại phiếu «Đã duyệt», bấm «Thực hiện», rồi «Thực hiện» trong hộp «Thực hiện phiếu?».
   *Bạn thấy:* phiếu «Đã thực hiện»; ở khối «Nội dung cập nhật», giá trị cũ bị gạch ngang rồi mũi tên tới giá trị mới (ví dụ «~~Trường cũ~~ → Trường mới»); ticket gốc sang «Đã xử lý».
   [CHƯA CHỤP: cần staging; ảnh dự kiến cskh-cs4-b7]

⚠ **Bước 7 không hoàn tác bằng nút.** Nhập nhầm giá trị thì làm một ticket Đề nghị mới và phiếu mới để sửa lại giá trị đúng.

## Sau bước này
- **Ai làm tiếp:** bạn (hoặc người phụ trách) đóng ticket gốc: bấm bước «Đã đóng», gõ «Ghi chú làm tay» ngắn («Đã sửa theo phiếu …»).
- **Bạn xem ở đâu:** hồ sơ học sinh hoặc phụ huynh (xem trường đã đổi); khối «Phiếu nghiệp vụ» ở ticket gốc; lịch sử thay đổi ở cột «Ghi chú & hoạt động» của hồ sơ.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Phiếu còn «Nháp», nhập sai | Bấm «Huỷ phiếu», ghi «Lý do», rồi «Tạo phiếu» lại |
| Phiếu «Chờ duyệt» nhập sai | Bấm «Huỷ phiếu» (hoặc nhờ Trưởng cơ sở «Từ chối» kèm lý do), rồi «Tạo phiếu» lại |
| Phiếu bị «Từ chối» | Đọc «Lý do từ chối», rồi «Tạo phiếu» mới từ ticket gốc với nội dung đã sửa |
| Phiếu «Đã thực hiện» nhưng giá trị sai | Không hoàn tác bằng nút: làm ticket và phiếu mới để đổi lại giá trị đúng; giá trị cũ vẫn xem được ở nhật ký |
| Cần sửa số điện thoại, họ tên học sinh | Phiếu này không sửa được: báo Trưởng cơ sở hoặc quản trị |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Ticket chưa gắn học sinh nên chưa sửa hồ sơ học sinh được.» (HMT_TICKET_THIEU_HOC_SINH) | Ticket chưa có học sinh | Chọn «Phụ huynh», hoặc nhờ người có quyền gắn học sinh vào ticket rồi tạo lại |
| «Nhập giá trị mới cho ít nhất một trường.» | Chưa gõ ô nào | Gõ ít nhất một ô |
| «Nhập lý do của phiếu.» | Ô «Lý do» trống | Điền lý do |
| «Chọn hồ sơ (phụ huynh hoặc học sinh) và ít nhất một trường cần sửa.» (HMT_PHIEU_DU_LIEU_SAI) | Thiếu nội dung gửi lên | Chọn «Hồ sơ cần sửa» và gõ giá trị |
| «Trường này không được sửa bằng phiếu Cập nhật hồ sơ.» (HMT_PHIEU_TRUONG_SAI) | Trường ngoài danh sách cho phép | Báo quản trị nếu cần thêm trường |
| «Ticket này đã có một phiếu đang mở. Xong hoặc huỷ phiếu đó trước.» (HMT_PHIEU_DA_CO) | Đã có phiếu khác | Hoàn tất hoặc «Huỷ phiếu» phiếu đó |
| «Người tạo phiếu không tự duyệt phiếu của mình.» (HMT_PHIEU_TU_DUYET) | Bạn bấm duyệt phiếu bạn lập | Nhờ Trưởng cơ sở duyệt |
| «Không xác định được phụ huynh để cập nhật.» (HMT_KHONG_TIM_THAY) | Ticket thiếu phụ huynh/học sinh liên kết | Báo Trưởng cơ sở, kiểm ô «Người gửi» của ticket |
| Không thấy nút «Tạo phiếu» | Ticket đã có phiếu đang mở, đã đóng, hoặc nhóm con không có nghiệp vụ | Kiểm khối «Phiếu nghiệp vụ» của ticket và nhóm con |

## Tập trên dữ liệu mẫu
- **Cần:** `cskh1.cs5` (lập phiếu, thực hiện) và `ql.cs5` (Quản lý cơ sở, duyệt). Hai người khác nhau mới hoàn tất được bài.
- **Dùng:** bộ dữ liệu mẫu của bạn (menu tài khoản → «Dữ liệu mẫu của tôi»): có học sinh và phụ huynh «[MẪU]», và ticket «[MẪU] Đề nghị cập nhật trường học của con» đã có sẵn một phiếu Cập nhật hồ sơ **Chờ duyệt** do người tạo bộ lập. Dùng phiếu đó để tập bước 6 và 7 (đăng nhập `ql.cs5` duyệt, rồi `cskh1.cs5` thực hiện).
- Để tập bước 1 đến 5 từ đầu, ticket mẫu ở trên đã có phiếu đang mở nên không tạo thêm được: tự tạo một ticket Đề nghị mới (nhóm «Hồ sơ», nhóm con «Cập nhật thông tin học sinh, phụ huynh», chọn học sinh «[MẪU]»), tiêu đề bắt đầu bằng «[MẪU]».
- Chưa có trong bộ mẫu: phiếu Cập nhật hồ sơ phụ huynh, phiếu bị từ chối.

## Tự kiểm: bạn làm được khi
- [ ] Có một phiếu Cập nhật hồ sơ «[MẪU]» của bạn ở trạng thái «Đã thực hiện» và thấy giá trị cũ → mới trong khối «Nội dung cập nhật».
- [ ] Bạn nói được vì sao bạn không tự duyệt phiếu mình lập, và những thông tin nào phiếu này không sửa được.

**Bước trước:** Phiếu nghiệp vụ: cách làm chung và duyệt từng cấp · **Bước sau:** Đóng ticket sau khi phiếu đã thực hiện (bài «Tạo ticket và xử lý», bước 7)

## Ghi chú cho người soát (không hiển thị cho người học)
- **Vênh bài cũ §8:** bài cũ nói sửa «số điện thoại, tên». Danh sách trường cho phép (`ticket_task_field`, migration 226) không có số điện thoại, mã, cơ sở; «tên» chỉ là «Họ tên phụ huynh» (học sinh không có họ tên trong danh sách). Đã sửa theo code. Trường có thể đã được quản trị thêm bớt trong bảng cấu hình; bài liệt kê theo bản nạp ban đầu và dặn «báo quản trị».
- **Vênh bài cũ §8 (Từ chối):** như CS3, phiếu «Từ chối» không gửi lại được (`submit_ticket_task` chỉ nhận «Nháp»); bài viết «tạo phiếu mới». Chữ trên màn («người tạo sửa và gửi lại») chưa khớp.
- Bài cũ nói phiếu có «gửi duyệt, chờ duyệt, bấm Thực hiện» và không nói người lập không tự duyệt; bài mới nêu rõ (HMT_PHIEU_TU_DUYET) theo yêu cầu. Cấp duyệt mặc định một cấp (Quản lý cơ sở); từ migration 646 Trưởng cơ sở đúng cơ sở hoặc Admin duyệt, Kế toán không duyệt.
- `execute_ticket_task` cho nhánh Cập nhật hồ sơ: chỉ các cột có xử lý trong hàm mới đổi được; không đọc lại để kiểm cột `grade` («Khối») và `gender` («Giới tính») có định dạng giá trị riêng (ô nhập là chữ tự do). Không biết định dạng hợp lệ (ví dụ «Giới tính» nhập «Nam» hay mã); cần Chat/Code xác nhận trước khi dạy ví dụ cụ thể. Bài chỉ lấy ví dụ «Trường».
- Bài ghi «Họ tên phụ huynh» là trường sửa được; không chắc nghiệp vụ có muốn cho CSKH sửa tên qua phiếu hay không, nhưng đúng theo bảng cấu hình.
- Phiếu mẫu có sẵn do người tạo bộ lập và đã «Trình»: nếu cùng tài khoản duyệt thì bị chặn (HMT_PHIEU_TU_DUYET). Bài tập đã ghi cần hai tài khoản.
- Chưa xác định: hồ sơ phụ huynh/học sinh hiển thị trường «Mục tiêu», «Người thân» ở tên nào trên màn hồ sơ (bài chỉ dùng tên nhãn ở hộp tạo phiếu).
