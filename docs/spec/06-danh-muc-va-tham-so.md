# HMT Platform: danh mục và tham số (chốt 12/10/2026)

> Ghi chú của repo: chép nguyên từ `HMT_DANH_MUC_VA_THAM_SO.md` của anh Trường. Tên tham số trong code (key): xem bảng ở `docs/spec/04-luat-nghiep-vu.md` mục 8. Chỗ khác với dữ liệu đã nạp: `docs/nghiep-vu/doi-chieu-luat-1210.md`.

Mọi danh mục lý do có "Khác"; chọn "Khác" thì bắt buộc ghi chú. Danh mục số 31, 32, 33 xếp sau số 30 về nghĩa; thứ tự dòng trong bảng không quan trọng.

Dùng cho QT-07 (danh mục) và QT-09 (Cài đặt). Giá trị ở đây là dữ liệu thật để nạp sẵn, không phải dữ liệu mẫu.

## 1. Danh mục

**Loại khoá:**
- **Khoá:** mã dùng trong luật hoặc trong mã đối tượng, nên chỉ được đổi tên hiển thị. Không thêm, không ngừng.
- **Khoá mục cha:** mục cấp 1 khoá; mục con thêm, đổi tên, ngừng được.
- **Mở:** thêm, đổi tên, đổi thứ tự, ngừng được.

Không danh mục nào được xoá hay đổi mã.

| # | Danh mục | Cấp | Khoá | Giá trị nạp sẵn |
|---|---|---|---|---|
| 1 | Cơ sở | 1 | Khoá | CS1 Nguyễn Chí Thanh, CS2 Đỗ Quang, CS3 Hội sở, CS4 Hà Đông, CS5 Mỹ Đình. **(chốt 12/10)** Không thêm, không ngừng trên giao diện (mở cơ sở mới qua migration); sửa được tên hiển thị, địa chỉ, hotline |
| 2 | Phòng học | 1, theo cơ sở | Mở | Theo từng cơ sở (CS3 không có) |
| 3 | Môn | 1 | Khoá | TOAN, DAI, HINH, LY, HOA, VAN, ANH, KHTN, TRUNG, SAT |
| 4 | Khối | 1 | Khoá | K02–K12 |
| 5 | Phân loại lớp | 1 | Khoá | CB Cơ bản, NC Nâng cao, LR Lớp riêng |
| 6 | Trình độ | 1 | Khoá | S, A, B, C |
| 7 | Hình thức học | 1 | Khoá | Offline, Online |
| 8 | Loại gói | 1 | Khoá | LC Lớp chung, VIP VIP 1:1 và 1:2, VNN VIP nhóm nhỏ, KR Kèm riêng, DV Dịch vụ, TL Tài liệu |
| 9 | Nguồn lead | 3 (loại → nguồn → kênh) | Mở | Xem 1.1 |
| 10 | Giai đoạn lead | 2 | Khoá mục cha; C4D khoá | Xem 1.2 |
| 11 | Giai đoạn cơ hội | 2 | Khoá mục cha; L5C–L5O nối với lý do huỷ test (L5P không nối) | Xem 1.3 |
| 12 | Giai đoạn phiếu tái tục | 2 | Khoá mục cha | Xem 1.4 |
| 13 | Lý do huỷ test | 1 | Mở, mỗi lý do nối một nhóm con L5 | Như các nhóm con L5C–L5O ở 1.3 |
| 14 | Hình thức test | 1 | Mở | Offline, Online |
| 15 | Cấp độ đề test | 1 | Mở | Cơ bản, Nâng cao |
| 16 | Loại hoạt động (lịch hẹn) | 1 | Mở | Gọi điện, Zalo, Email, Gặp trực tiếp, SMS, Nhắc thu tiền (**chốt 12/10**: giữ 6 mục đã nạp trong repo) |
| 17 | Lý do liên hệ khi điểm danh | 1 | Mở | Không nghe máy, Đã nhắc vào lớp, Đã vào lớp, Xin nghỉ học, Khác |
| 18 | Trạng thái BTVN | 1 | Khoá | Đã chấm, Làm chưa xong, Không làm, Nộp sau, Không áp dụng |
| 19 | Nhóm, nhóm con đề nghị | 2 | Khoá mục cha và các nhóm con gắn nghiệp vụ | Theo R-CS-03, thêm nhóm con "Dừng học" |
| 20 | Nhóm, nhóm con khiếu nại | 2 | Mở | Theo R-CS-04 |
| 21 | Mức độ khiếu nại | 1 | Khoá | Thấp, Trung bình, Cao, Nghiêm trọng |
| 22 | Kênh tiếp nhận ticket | 1 | Mở | Gọi điện, Zalo, Trực tiếp, Email, Giáo viên báo, Khác |
| 23 | Lý do huỷ buổi | 1 | Mở | Trung tâm: Nghỉ lễ đột xuất, Giáo viên nghỉ, Sự cố cơ sở vật chất, Thời tiết. Học sinh: Ốm, Việc gia đình, Thi ở trường, Khác |
| 24 | Lý do từ chối, có cột "Áp dụng cho" (báo giá, đơn, phiếu thu, lớp, ticket, yêu cầu buổi) | 1 | Mở | Thiếu thông tin, Sai số tiền, Sai chứng từ, Không đúng chính sách, Khác |
| 25 | Lý do điều chỉnh giờ | 1 | Mở | Sửa sai danh sách/điểm danh, Bù giờ do lỗi trung tâm, Tặng giờ chăm sóc (cần duyệt), Chuyển dữ liệu từ hệ thống cũ, Khác (bắt buộc ghi chú) |
| 26 | Hình thức thu tiền | 1 | Mở | Tiền mặt, Chuyển khoản, Quẹt thẻ |
| 27 | Tài khoản nhận tiền | 1, theo cơ sở | Mở | Do Kế toán khai |
| 28 | Lý do không tái tục | 1 | Mở | Học phí, Chất lượng, Lịch học, Chuyển nhà, Học nơi khác, Đủ mục tiêu, Khác |
| 31 | Lý do đảo khoản tiền | 1 | Mở | Nhập sai số tiền, Trùng phiếu, Sai đơn hoặc sai khách, Khác |
| 32 | Lý do khoá tài khoản | 1 | Mở | Nghỉ việc, Dừng học, Tạm nghỉ, Nghi lộ mật khẩu, Khác |
| 33 | Lý do bỏ qua test **(16/10)** | 1 | Mở, luôn có "Khác" (bắt buộc ghi chú) | Học sinh cũ đã biết trình độ, Phụ huynh không muốn test, Đã có kết quả test nơi khác, Khác |
| 29 | Tỉnh, phường | 2 | Mở | Nạp từ file seed (126 phường, xã của Hà Nội; **chốt 12/10**: lấy theo số đã nạp trong repo) |
| 30 | Tên hiển thị các bước trạng thái (lớp, buổi, ghi danh, đơn, phiếu thu, ticket…) | 1 | Khoá | Danh sách tên ở `docs/design/luat-cho-thiet-ke.md`; nạp dần theo từng giai đoạn có trạng thái đó |

### 1.1 Nguồn lead (loại → nguồn → kênh)
| Loại | Nguồn | Kênh |
|---|---|---|
| Marketing | Facebook Ads | Chat · Comment · Inbox · Lead Form |
| Marketing | Google Ads, Website, Hotline, Walk-in, Zalo | (không có kênh con) |
| Telemarketing | Cold Call | Buy · Crawl · Flyer |
| Event | Event | Indoor · Outdoor |
| Referral | Referral | By Customer · By HMT |
| Upsale | Upsale | Renew Lost · New Opp · Cross-Sale |
| Ban Giám Đốc | Ban Giám Đốc | (không có kênh con) |

### 1.2 Giai đoạn lead
| Mã | Tên | Nhóm con |
|---|---|---|
| C1 | Data mới | (không có) |
| C2 | Chưa liên hệ được | C2A Không nghe máy · C2B Không liên lạc được · C2C Bận gọi lại sau |
| C3 | Không có nhu cầu | C3A Không có nhu cầu · C3B Chưa có nhu cầu ở thời điểm hiện tại · C3C Đang học ở nơi khác · C3D Không phù hợp về sản phẩm · C3E Không phù hợp về giá · C3F Không phù hợp về độ tuổi · C3G Không phù hợp về địa điểm · C3H Không nghe máy nhiều lần |
| C4 | Khách hàng tiềm năng | C4A Cần gửi thêm thông tin · C4B Cần trao đổi thêm · C4C Đủ điều kiện tạo cơ hội · C4D Tạo cơ hội thành công (hệ thống tự gắn) |

Không có C3K.

### 1.3 Giai đoạn cơ hội (chỉ đi tới)

**Chốt 12/10:** tên giai đoạn con ở 1.2, 1.3 lấy theo tên đã nạp trong repo. Chỉ đổi hai chỗ ở bước 4: C4C, C4D dùng chữ "cơ hội" thay cho "opp" (bảng 1.2 đã ghi tên mới); L5B thành "Đã xếp lịch test" (bảng 1.3 đã ghi tên mới).
| Mã | Tên | Nhóm con |
|---|---|---|
| L1 | Khách hàng mới | (không có) |
| L2 | Chưa liên hệ được | L2A Không nghe máy · L2B Không liên lạc được · L2C Bận gọi lại sau |
| L3 | Không có nhu cầu | L3A Không có nhu cầu · L3B Chưa có nhu cầu ở thời điểm hiện tại · L3C Đang học ở nơi khác · L3D Không phù hợp về sản phẩm · L3E Không phù hợp về giá · L3F Không phù hợp về độ tuổi · L3G Không phù hợp về địa điểm · L3H Không nghe máy nhiều lần |
| L4 | Khách hàng tiềm năng | L4A Tiềm năng, cần gửi thêm thông tin · L4B Tiềm năng, cần tư vấn thêm · L4C Tiềm năng, cần tham khảo ý kiến · L4D Tiềm năng, cần gọi lại vào dịp khác |
| L5 | Đồng ý tham gia test | L5A Đồng ý tham gia test · L5B Đã xếp lịch test · L5P Đã làm bài, chờ giáo viên chấm **(16/10, hệ thống tự gắn, không nối lý do huỷ test)** · L5C Huỷ test, không liên hệ được · L5D Huỷ test, PH bận không đưa đón được · L5E Huỷ test, con bận không tham gia được · L5F Huỷ test, con không muốn tham gia · L5G Huỷ test, con đang ôn thi · L5H Huỷ test, con ốm · L5I Huỷ test, gia đình đi du lịch · L5K Huỷ test, thời tiết không thuận lợi · L5N Huỷ test, con đang ở quê · L5M Huỷ test, lý do khác · L5O Huỷ test nhiều lần |
| L6 | Đã tham gia test | **(16/10, L6 chỉ do hệ thống chuyển, R-CRM-13)** L6A Có kết quả, cần phân loại · L6B Học xuất sắc · L6C Học tốt · L6D Học khá · L6E Học trung bình · L6F Học yếu |
| L7 | Tư vấn | L7A Cần đặt lịch tư vấn · L7B Đã tư vấn, khách hàng tiềm năng · L7C Đã tư vấn, dự thu · L7D Đã tư vấn, cần trao đổi thêm · L7E Đã tư vấn, PH cân nhắc học phí · L7F Đã tư vấn, PH cân nhắc chương trình học · L7G Đã tư vấn, PH cân nhắc thời gian học · L7H Đã tư vấn, PH cân nhắc địa điểm học · L7I Đã tư vấn, PH cân nhắc hình thức học · L7K Đã tư vấn, PH cần trao đổi với người thân · L7L Đã tư vấn, PH cần trao đổi với con |
| L8 | Đăng ký học | L8A PH đặt cọc · L8B PH thanh toán chia để trả · L8C PH hoàn thành 100% học phí. **(16/10)** Cả ba chọn tay được lúc bấm L8 (R-CRM-16); tự nâng lên L8C theo R-CRM-17 |


### 1.4 Giai đoạn phiếu tái tục
| Mã | Tên | Ghi chú |
|---|---|---|
| L1 | Chờ tái tục | L1A Hệ thống sinh tự động · L1B Tạo thủ công |
| L2 | Đã liên hệ | |
| L3 | Đang tư vấn | Có lịch hẹn tư vấn |
| L4 | Đang cân nhắc | |
| L5 | Không tái tục | Kết thúc, bắt buộc chọn lý do (danh mục 28) |
| L6 | Đồng ý tái tục | |
| L7 | Dự thu | L7A Đã gửi báo giá · L7B Đã có đơn, chờ đóng tiền |
| L8 | Hoàn thành tái tục | L8A Đã đóng đủ, đã cộng quỹ giờ |

## 2. Tham số Cài đặt

**Ghi đè theo cơ sở:**
- **Có:** cơ sở được đặt giá trị riêng; trống thì dùng giá trị chung.
- **Không:** một giá trị cho toàn hệ thống. Các tham số về tiền, giá, chiết khấu và đăng nhập luôn là "Không", vì giá và chính sách như nhau ở mọi cơ sở.

| Nhóm | Tham số | Mặc định | Khoảng cho phép | Ghi đè theo cơ sở |
|---|---|---|---|---|
| Bán hàng | Hạn hiệu lực báo giá | 14 ngày | 1–90 | Không |
| Bán hàng | Tiền cọc tối thiểu để ghi danh | 1.000.000 đ | 0–100.000.000 | Không |
| Bán hàng | Trần chiết khấu tổng (gồm giờ tặng) | 20% | 0–100% | Không |
| Bán hàng | Phí xử lý hoàn phí | 10% | 0–100% | Không |
| Ghi danh | Thời hạn gói (chỉ dự báo) | 6 tháng | 1–24 | Không |
| Ghi danh | Bảo lưu tối đa mỗi lần | 6 tháng | 1–24 | Không |
| Ghi danh | Cho học trước tối đa | 2 buổi | 0–10 | Có |
| Ghi danh | Khối tách Đại, Hình | 7 | 2–12 | Không |
| Tái tục | Ngưỡng giờ còn | 10 giờ | 0–100 | Có |
| Tái tục | Ngưỡng ngày hết giờ dự kiến | 30 ngày | 0–180 | Có |
| Tái tục | Số buổi vắng gắn cờ rủi ro | 3 buổi | 1–20 | Có |
| Tái tục | Khoảng thời gian đếm buổi vắng (mới) | 30 ngày gần nhất | 7–180 | Có |
| Buổi học | Tự chốt danh sách: chu kỳ quét | 30 phút | 0–240 | Không |
| Buổi học | Tự chốt danh sách: các buổi bắt đầu trong | 2 giờ tới | 1–24 | Có |
| Buổi học | Học thử tối đa mỗi cơ hội (mới) | 2 buổi | 0–5 | Có |
| Giáo viên | Hạn hoàn tất buổi | 8 giờ | 1–72 | Không |
| CSKH | SLA phản hồi, xử lý (từng loại, mức độ) | Theo R-CS-08 | Phản hồi 1–168 giờ; xử lý xong 1–30 ngày (hoàn tiền 1–60 ngày) | Không |
| CSKH | Mở lại khiếu nại trong | 7 ngày | 0–90 | Không |
| CSKH | Hạn phụ huynh xác nhận phương án (mới) | 3 ngày | 1–14 | Không |
| Đăng nhập | Số lần sai trước khi tạm khoá | 10 lần | 3–50 | Không |
| Đăng nhập | Thời gian tạm khoá | 15 phút | 1–1.440 | Không |
| Đăng nhập | Tự đăng xuất nhân viên | 60 phút | 5–1.440 | Không |
| Đăng nhập | Tự đăng xuất giáo viên, trợ giảng | 7 ngày | 5 phút–14 ngày (lưu bằng phút: 5–20.160; màn Cài đặt hiện theo ngày) | Không |
| Đăng nhập | Tự đăng xuất học sinh | 7 ngày | 5 phút–14 ngày (lưu bằng phút: 5–20.160; màn Cài đặt hiện theo ngày) | Không |

**Chốt 12/10:** khoảng cho phép lấy theo cơ sở dữ liệu đã có (bảng trên đã sửa cho khớp); ba tham số "(mới)" dùng khoảng ghi ở đây. Cột "Ghi đè theo cơ sở" theo bảng này, cơ sở dữ liệu sửa theo ở bước 4. "Tự chốt danh sách: chu kỳ quét" là tham số `session_autoclose_before_minutes`: tên hiển thị và mô tả trong cơ sở dữ liệu đang ghi "trước giờ học", sửa cho đúng nghĩa ở bước 4.
