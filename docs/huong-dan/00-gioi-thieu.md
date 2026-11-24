---
title: Giới thiệu hệ thống
slug: bat-dau
group: bat-dau
no: 0
order: 10
portals: [crm]
---

# 0. Giới thiệu hệ thống HMT Platform

Dành cho người mới: nhân viên, giáo viên, kế toán, quản lý cơ sở, quản trị. Đọc bài này trước, rồi sang bài của vai mình (xem mục «Hướng dẫn theo vai trò» ở menu trái). Bài này không dạy bấm nút; nó trả lời ba câu: hệ thống chạy trên gì, dữ liệu nối với nhau thế nào, và mỗi phần dùng để làm việc gì.


## 1. HMT Platform là gì

HMT (Hòa Ma Toán) là trung tâm dạy thêm có bốn cơ sở ở Hà Nội, khoảng 1.300 học sinh, 166 lớp, 30 nhân viên và 50 đến 60 giáo viên. HMT Platform là hệ thống thay cho bộ công cụ cũ làm bằng Google Sheet: **một ứng dụng, một cơ sở dữ liệu, ba cổng** cho ba nhóm người dùng.

| Cổng | Ai dùng | Làm gì |
|---|---|---|
| **CRM** (`/crm`) | Sale, chăm sóc khách hàng (CSKH), vận hành, kế toán, quản lý cơ sở, ban giám đốc, quản trị | Từ khách hỏi thăm tới học sinh đang học: lead, cơ hội, kiểm tra đầu vào, báo giá, đơn hàng, thu tiền, ghi danh, lớp, buổi học, chăm sóc sau bán, báo cáo. Dùng chủ yếu trên máy tính. |
| **Giáo viên** (`/gv`) | Giáo viên, trợ giảng | Lịch dạy, điểm danh, nhận xét buổi, bài tập về nhà, căn cứ tính lương. Dùng chủ yếu trên điện thoại. |
| **Học tập** (`/hoc`) | Học sinh (chính), phụ huynh (xem) | Nhận bài tập, nộp bài, xem điểm và nhận xét. Dùng trên điện thoại hoặc máy tính. |

Mỗi người chỉ thấy cổng và menu đúng quyền của mình. Vào địa chỉ ngoài quyền thì màn báo «Bạn không có quyền xem trang này» và không lộ dữ liệu.

## 2. Hệ thống chạy trên nền tảng gì

Phần này để bạn hiểu vì sao hệ thống hành xử như vậy, không cần nhớ chi tiết.

- **Giao diện:** một ứng dụng web viết bằng React, là các tệp tĩnh đặt trên Cloudflare Pages (dịch vụ miễn phí). Không có máy chủ riêng của HMT. Trình duyệt nói chuyện thẳng với cơ sở dữ liệu.
- **Cơ sở dữ liệu và đăng nhập:** Supabase, dùng Postgres. Có hai môi trường tách hẳn nhau: **thử nghiệm** (để thử, dữ liệu giả) và **chạy thật**. Người dùng hằng ngày chỉ làm việc ở bản chạy thật.
- **Luật nghiệp vụ nằm trong cơ sở dữ liệu**, không nằm ở màn hình. Tiền, giờ học, cấp mã, đổi trạng thái đều do hàm trong cơ sở dữ liệu tính và kiểm. Màn hình chỉ hiện kết quả. Vì vậy hai người ở hai máy luôn thấy cùng một số, và một thao tác hoặc xong trọn vẹn hoặc không xảy ra gì.
- **Phân quyền chặn ngay trong cơ sở dữ liệu**, không chỉ ẩn nút. Người ngoài quyền có cố mở địa chỉ hay gọi trực tiếp cũng không đọc được.
- **Việc hẹn giờ** (tự chốt danh sách buổi học, nhắc hạn, sinh phiếu tái tục) do cơ sở dữ liệu tự chạy theo lịch.
- **Sao lưu** tự động mỗi đêm cho bản chạy thật, mã hoá và lưu ngoài hệ thống.
- **Google Sheet** chỉ còn là bản sao chỉ đọc để đối soát; không sửa dữ liệu ở đó.
- **Chi phí:** thiết kế để nằm trong gói miễn phí của các dịch vụ. Vì vậy danh sách luôn chia trang (mặc định 50 dòng) và chỉ tải các cột đang hiện.

## 3. Ba nguyên tắc bạn sẽ gặp ở mọi màn

1. **Chỉ thêm, không sửa lịch sử.** Sổ giờ, phiếu thu, nhật ký thao tác là dạng chỉ thêm dòng mới. Làm sai thì tạo dòng điều chỉnh hoặc đảo khoản, có lý do; dòng cũ vẫn còn để tra.
2. **Không xoá, chỉ đổi trạng thái.** Huỷ, ngừng, đóng đều là đổi trạng thái. Hồ sơ vẫn xem lại được.
3. **Bản ghi chụp lại số lúc tạo.** Báo giá, đơn hàng, phiếu hoàn giữ nguyên giá, số giờ, chiết khấu tại lúc tạo. Sau này bảng giá hay tham số đổi thì bản ghi cũ **không** bị tính lại.

Mọi con số nghiệp vụ như hạn mức, phí xử lý, số ngày nhắc đều là **tham số cấu hình**, người quản trị đổi trong «Cài đặt tham số» và có nhật ký. Mỗi cơ sở có thể có giá trị riêng.

## 4. Dữ liệu nối với nhau thế nào (mức khái niệm)

Đây là sợi dây chính, từ người hỏi thăm đến buổi học:

```
Lead  →  Cơ hội  →  (Phiếu kiểm tra đầu vào)  →  Báo giá  →  Đơn hàng  →  Phiếu thu
                                                                              │
                                                                              ▼
                              Buổi học  ←  Lớp  ←  Xếp lớp  ←  Ghi danh (quỹ giờ)  ←  Học sinh
```

- **Lead:** một lượt khách quan tâm (gọi, để lại số, đăng ký). Có nguồn, giai đoạn, người phụ trách. Hệ thống cảnh báo khi số điện thoại trùng với lead hay phụ huynh đã có.
- **Cơ hội:** lead đã đủ nghiêm túc để tư vấn. Đi qua các giai đoạn chỉ tiến về phía trước. Từ giai đoạn gần chốt phải có tên và năm sinh học sinh.
- **Phiếu kiểm tra đầu vào:** xếp lịch, giáo viên chấm, kết quả dùng để tư vấn lớp phù hợp.
- **Báo giá → Đơn hàng:** báo giá chọn gói, số giờ, chiết khấu; chuyển thành đơn khi phụ huynh đồng ý, chọn lớp và ngày vào học. Đơn qua bước **duyệt** của quản lý cơ sở.
- **Phiếu thu:** tiền thu về cho đơn, có thể nhiều đợt. Kế toán duyệt. Duyệt xong mới có giờ học.
- **Học sinh và phụ huynh:** hồ sơ khách hàng. Một phụ huynh có thể có nhiều em; một em có thể có nhiều ghi danh.
- **Ghi danh:** gắn một em với một môn/gói đã mua, mang theo **quỹ giờ** (giờ được cấp, đã dùng, còn lại, giờ tặng). Mọi cộng trừ giờ nằm trong **sổ giờ** của ghi danh. Ghi danh có các tình trạng như Chờ xếp lớp, Đã xếp lớp, Đang học, Bảo lưu, Hoàn thành, Chuyển lớp, Dừng, Hoàn phí.
- **Lớp:** có giáo viên, thời khoá biểu, phòng, sĩ số. Lớp mới đi qua các bước nháp, trình, xác nhận, duyệt.
- **Buổi học:** sinh tự động theo thời khoá biểu của lớp. Giáo viên điểm danh, ghi nội dung, giao bài, nhận xét. Khi buổi hoàn tất, hệ thống **tự trừ giờ** của từng em có mặt. Vắng, học bù, huỷ buổi, dời buổi đều có luật riêng.
- **Ticket và phiếu nghiệp vụ (chăm sóc sau bán):** mọi yêu cầu sau khi đã học (khiếu nại, bảo lưu, chuyển lớp, chuyển cơ sở, dừng học, hoàn học phí, chuyển phí, đổi lịch, cập nhật hồ sơ) bắt đầu bằng một **ticket**. Việc cần duyệt hoặc làm thật tách thành **phiếu nghiệp vụ** gắn với ticket, có hai cấp duyệt khi liên quan tiền.
- **Phiếu tái tục:** tự sinh khi ghi danh sắp hết giờ hoặc sắp hết hạn, để CSKH và sale gọi tư vấn mua tiếp.

Mã của từng bản ghi (lead, cơ hội, đơn, phiếu thu, ghi danh, lớp, buổi, ticket) do hệ thống cấp, **liền số, không nhảy, không sửa được**. Mã cho biết loại bản ghi và cơ sở; bạn chỉ cần đọc, không phải đặt.

## 5. Từng phân hệ dùng để làm gì

**Tuyển sinh.** Quản lý lead và cơ hội trên danh sách hoặc bảng kéo theo giai đoạn; nhập lead từ tệp; giao người phụ trách; gộp lead hoặc cơ hội trùng; lịch hẹn gọi, gặp, nhắn của từng người (quá hạn, hôm nay, sắp tới); phiếu kiểm tra đầu vào. Người làm chính: sale, CSKH.

**Bán hàng.** Báo giá, gửi báo giá, chuyển thành đơn hàng, trình và duyệt đơn. Có thể cho học trước, đóng tiền sau nếu quản lý cơ sở bật trên đơn đã duyệt. Người làm chính: sale, quản lý cơ sở.

**Thu chi.** Lập phiếu thu (có thể nhiều đợt), kế toán duyệt, theo dõi còn phải thu, đảo khoản khi sai, số dư giữ lại của khách, phiếu chi và in phiếu chi. Người làm chính: kế toán.

**Khách hàng.** Hồ sơ phụ huynh và học sinh, lịch sử mua và học, cụm khách hàng. Dùng để tra cứu trước khi gọi hay xử lý yêu cầu.

**Đào tạo.** Ghi danh và quỹ giờ, xếp lớp (có hàng chờ), dự báo sắp hết giờ, tái tục. Lớp: tạo, thời khoá biểu, duyệt, lịch buổi. Buổi học: danh sách theo dõi, huỷ, dời, yêu cầu học bù, buổi kẹt chưa hoàn tất. Người làm chính: vận hành, CSKH, quản lý cơ sở.

**Chăm sóc khách hàng.** Ticket và phiếu nghiệp vụ cho khiếu nại, bảo lưu, chuyển lớp, chuyển cơ sở, dừng học, hoàn học phí, chuyển phí, đổi lịch, cập nhật hồ sơ. Có hạn xử lý theo loại, bảng việc cần duyệt, hàng nhận xét chờ gửi phụ huynh. Người làm chính: CSKH, quản lý cơ sở, kế toán.

**Cổng giáo viên.** Hôm nay dạy gì, điểm danh, nội dung buổi và giao bài, chấm từng em theo mẫu nhận xét, chấm bài tập, hoàn tất buổi, xem căn cứ tính lương. Làm gọn cho điện thoại.

**Học tập và phụ huynh.** Học sinh nhận và nộp bài, xem điểm và nhận xét; phụ huynh xem kết quả của con. (Giai đoạn sau; xem tiến độ mới nhất để biết phần nào đã mở.)

**Báo cáo.** Số liệu tuyển sinh, doanh thu, công nợ, tình hình lớp, chăm sóc sau bán. Chỉ hiện dữ liệu trong phạm vi cơ sở của bạn (trừ quản trị).

**Quản trị và cấu hình.** Tạo người dùng, gán vai trò và cơ sở, sửa quyền, danh mục, tham số nghiệp vụ, bảng giá và gói bán, bật hoặc tắt tính năng theo cơ sở, xem nhật ký thao tác, nhập dữ liệu. Chỉ quản trị và người được giao quyền.

## 6. Vai trò và phạm vi

- **Sale, CSKH:** làm việc trên khách hàng và yêu cầu của cơ sở mình.
- **Quản lý cơ sở:** duyệt đơn, duyệt lớp, duyệt cấp một cho phiếu nghiệp vụ, thấy toàn cơ sở.
- **Kế toán:** duyệt thu, duyệt cấp hai cho phiếu hoàn tiền, phiếu chi.
- **Giáo viên, trợ giảng:** chỉ thấy lớp, buổi của mình.
- **Quản trị:** thấy mọi cơ sở, cấu hình hệ thống; không tự duyệt thay các cấp duyệt nghiệp vụ.
- Quyền chi tiết (xem, tạo, sửa, duyệt) nằm trong **ma trận quyền** do quản trị chỉnh. Ai có nhiều cổng thì có màn chọn cổng sau khi đăng nhập.
- Quản trị viên đăng nhập thêm **xác thực hai bước**.

Mỗi tính năng lớn có **công tắc theo cơ sở**; phân hệ chưa bật ở cơ sở của bạn sẽ báo «Phân hệ chưa bật».

## 7. Những việc nối nhau mà bạn nên biết

- **Từ khách hỏi đến học:** lead, gọi và hẹn, cơ hội, kiểm tra đầu vào, báo giá, đơn, duyệt, phiếu thu, kế toán duyệt, ghi danh, xếp lớp, học.
- **Đóng tiền nhiều đợt:** đợt đầu cấp giờ theo tỉ lệ; đủ tiền mới cấp thêm và giờ tặng. Thu nhầm thì đảo khoản, không sửa.
- **Mở lớp đến buổi đầu:** tạo lớp nháp, thời khoá biểu, trình, duyệt, buổi tự sinh, xếp học sinh, tự chốt danh sách.
- **Một buổi học:** vận hành nhắc, giáo viên điểm danh, ghi nội dung và giao bài, chấm từng em, hoàn tất; buổi chuyển Done và trừ giờ.
- **Huỷ, dời, bù:** trung tâm huỷ hay dời buổi; học sinh xin học bù thì quản lý duyệt.
- **Tái tục:** phiếu tự sinh, CSKH gọi tư vấn, báo giá hay đơn mới, thu tiền.
- **Bảo lưu, chuyển lớp, dừng học:** ticket, duyệt, thực hiện; tiền còn lại có thể hoàn hoặc giữ làm số dư.
- **Hoàn tiền:** ticket, hai cấp duyệt, bảng tính hoàn do hệ thống tính, phiếu chi, in phiếu.
- **Khiếu nại:** tiếp nhận, xác minh và phương án, phụ huynh xác nhận, đóng hoặc mở lại.

## 8. Khi gặp sự cố

- Lỗi do hệ thống trả về luôn hiện **câu tiếng Việt** ngay trên màn. Đọc kỹ: đa số cho biết thiếu gì hoặc ai có quyền làm.
- Mạng lỗi thì có nút «Thử lại». Nút lưu khoá khi đang lưu; đừng bấm hai lần.
- Số sai: đừng sửa tay. Dùng điều chỉnh hoặc đảo khoản có lý do, hoặc báo người quản trị.
- Muốn biết ai đã đổi gì: nhờ quản trị xem **nhật ký thao tác**.
- Không đăng nhập được: sai mật khẩu, tài khoản khoá và tài khoản không có đều báo cùng một câu (để bảo mật). Liên hệ quản trị.

## 9. Đọc tiếp

- [Bắt đầu nhanh](/crm/huong-dan/chung-dang-nhap): đăng nhập, mật khẩu, hai bước, menu, chọn cơ sở.
- [Thao tác cơ bản dùng chung](/crm/huong-dan/chung-danh-sach): tìm, lọc, nhóm, lưu bộ lọc, mở và sửa bản ghi.
- Bài theo vai: [Tư vấn tuyển sinh](/crm/huong-dan/theo-vai-tu-van), [CSKH và vận hành lớp](/crm/huong-dan/theo-vai-cskh), [Kế toán](/crm/huong-dan/theo-vai-ke-toan), [Trưởng cơ sở](/crm/huong-dan/theo-vai-truong-co-so), [Giáo viên](/crm/huong-dan/giao-vien), [Quản trị](/crm/huong-dan/quan-tri).
- Tra cứu: [Từ điển thuật ngữ](/crm/huong-dan/tu-dien), [Hỏi đáp và lỗi thường gặp](/crm/huong-dan/hoi-dap).
