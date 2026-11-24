# Bản kê nghiệp vụ cần bài hướng dẫn (A-23-41, 24/11/2026)

Mục đích: liệt kê **mọi luồng nghiệp vụ** của từng phân hệ cần có bài hướng dẫn chi tiết (từng bước, có ảnh, có video), đối chiếu với tài liệu hiện có, để Chat chia việc viết cho cả đội. Chỉ là bản kê, không sửa bài hướng dẫn nào.

**Nguồn đối chiếu:** `docs/design/ban-do-man-hinh.md` (mã màn), `docs/huong-dan/` (00 đến 05, 03-* theo vai, `giao-vien.md`, `quan-tri.md`), `public/huong-dan/` (75 ảnh, 6 video). Đã đọc tiêu đề từng bài; **chưa** mở từng bài để chấm độ sâu, nên cột «Phủ» ở mức tiêu đề (xem chú thích). Mã màn lấy theo bản đồ màn hình; vài màn bản đồ ghi «C» (dựng từ khuôn) vẫn có trong luồng.

**Chú thích cột Phủ:** ✅ đã có mục riêng (cần rà từng bước, ảnh) · ◐ chỉ có một đoạn ngắn hoặc nằm chung mục khác · ❌ chưa có.
**Ưu tiên:** P1 = cần cho CS5 vào dùng (Tư vấn, Kế toán, CSKH, Trưởng cơ sở, Giáo viên làm việc hằng ngày) · P2 = dùng thường xuyên nhưng không chặn ngày đầu · P3 = hiếm, quản trị hoặc ngoại lệ.
**Ảnh/video hiện có:** chỉ ghi tên ngắn; «—» là chưa có. Ảnh hiện có phần lớn là ảnh trang danh sách/bản ghi, chưa phải ảnh từng bước có khung nổi bật.

## 1. Tuyển sinh (lead, cơ hội, lịch hẹn, kiểm tra đầu vào)
| # | Luồng | Vai | Màn | Phủ (bài hiện có) | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| TS1 | Tạo lead nhanh, xử lý cảnh báo trùng SĐT | SA, CS | TS-03, TS-14 | ◐ 03-tu-van §1 | lead-ban-ghi, video tu-van-tong-quan | P1 |
| TS2 | Nhập lead từ file CSV (ghép cột, xem trước, dòng lỗi) | SA, CS, BM | TS-04, QT-18 | ❌ | — | P1 |
| TS3 | Chăm sóc lead: đổi giai đoạn C1–C4, nhóm con, ghi chú | SA, CS | TS-01, TS-02 | ✅ 03-tu-van §1 | lead-ds, lead-giai-doan | P1 |
| TS4 | Giao người phụ trách (một hoặc nhiều lead, cơ hội) | BM, CS | TS-05 | ❌ | — | P2 |
| TS5 | Tạo cơ hội từ lead (cảnh báo đã có cơ hội: mở cũ / thêm em / ...) | SA, CS | TS-06 | ◐ §2 | lead-tao-co-hoi | P1 |
| TS6 | Đi cơ hội qua L1–L8 (chỉ đi tới, nhóm con, lý do, tên và năm sinh học sinh từ L5) | SA, CS | TS-07, TS-08, TS-09 | ✅ §2 | co-hoi-thanh-giai-doan, co-hoi-lien-ket | P1 |
| TS7 | Kanban cơ hội: kéo thả chỉ đi tới | SA | TS-07 | ◐ 02 §2.7 | chuyen-kanban | P2 |
| TS8 | Gộp lead / cơ hội trùng | SA, CS, BM | TS-10 | ❌ | — | P2 |
| TS9 | Lịch hẹn: tạo, dời, hoàn thành 1 bấm, huỷ | SA, CS | TS-11, TS-13 | ✅ §3 | lich-hen-ds, lich-hen-bang-the, lich-tuan | P1 |
| TS10 | Tạo phiếu kiểm tra từ cơ hội (môn, khối, hình thức, lịch) | SA, CS | TS-15 | ❌ | — | P1 |
| TS11 | Phiếu kiểm tra: Nháp → Đang test → Chờ GV chấm → Hoàn thành; huỷ; gợi ý lớp | SA, CS | TS-16, TS-17 | ❌ | — | P1 |
| TS12 | Giáo viên chấm kiểm tra đầu vào | GV | GV-15 | ◐ giao-vien §13 | — | P2 |
| TS13 | Chiến dịch marketing (xem và gắn vào lead) | AD, SA | CH-08 | ❌ | — | P3 |

## 2. Khách hàng (phụ huynh, học sinh)
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| KH1 | Tìm khách, xem hồ sơ phụ huynh và học sinh 360° | SA, CS, BM, KT | KH-01, KH-02, KH-04, KH-05 | ✅ 03-cskh §1 | phu-huynh-ds, hoc-sinh-ho-so | P1 |
| KH2 | Sửa phụ huynh, sửa học sinh (không có Tạo tay) | SA, CS | KH-03, KH-06 | ◐ 03-cskh §8 (qua phiếu Cập nhật hồ sơ) | — | P2 |
| KH3 | Gộp phụ huynh / học sinh trùng | SA, CS, BM | KH-07 | ❌ | — | P2 |
| KH4 | Lên khối đầu năm học hàng loạt | AD | KH-08 | ❌ | — | P3 |

## 3. Bán hàng (báo giá, đơn hàng, duyệt)
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| BH1 | Lập báo giá, dòng gói, in và gửi phụ huynh | SA, CS | BH-01, BH-02, BH-03 | ✅ §4 | — | P1 |
| BH2 | Từ chối báo giá (lý do) | SA, CS, BM | BH-04 | ❌ | — | P2 |
| BH3 | Lập đơn hàng; chọn lớp và ngày vào lớp cho dòng đơn | SA, CS | BH-05, BH-06, BH-08, BH-11 | ✅ §5 | ke-toan-don-hang | P1 |
| BH4 | Trình và duyệt / từ chối đơn hàng | BM, AD | BH-07 | ✅ 03-truong-co-so §4 | don-hang-duyet | P1 |
| BH5 | Bật «Cho học trước, đóng tiền sau» | BM, AD | BH-09 | ◐ (nhắc trong 03-truong-co-so) | — | P2 |
| BH6 | Huỷ đơn hàng (lý do) | SA, BM | BH-10 | ❌ | — | P2 |
| BH7 | Ưu đãi linh hoạt, chiết khấu trên dòng đơn | SA, BM | BH-05 | ❌ | — | P2 |

## 4. Thu chi (phiếu thu, tiền vào, phiếu chi, số dư, công nợ)
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| TC1 | Tạo phiếu thu từ đơn hàng (đợt, hạn, hình thức) | SA, CS | TC-03, TC-01, TC-02 | ✅ §6 | phieu-thu-cho-ke-toan | P1 |
| TC2 | Quản lý (Trưởng cơ sở) duyệt phiếu thu | BM | TC-17 | ✅ 03-truong-co-so §5 | phieu-thu-duyet-quan-ly | P1 |
| TC3 | Kế toán duyệt / từ chối phiếu thu | KT | TC-04, TC-05 | ✅ 03-ke-toan §3 | ke-toan-phieu-thu-ds, video ke-toan-phieu-thu | P1 |
| TC4 | Huỷ phiếu thu (lý do) | SA, CS | TC-06 | ❌ | — | P2 |
| TC5 | Bản in phiếu thu / biên nhận | SA, CS, KT | TC-07 | ❌ | — | P2 |
| TC6 | Khoản tiền vào (sổ thu tiền) và đảo khoản | KT, BM | TC-08, TC-09 | ✅ 03-ke-toan §4 | khoan-tien-vao-ds | P1 |
| TC7 | Công nợ và thu nợ đầu kỳ | KT, BM, SA, CS | TC-13 | ✅ 03-ke-toan §5 | cong-no | P1 |
| TC8 | Đối soát thu tiền | KT | TC-15 | ❌ | — | P2 |
| TC9 | Phiếu chi: lập, duyệt, in (kể cả chi hoàn học phí) | KT, BM | TC-10, TC-11, TC-12 | ✅ 03-ke-toan §6 | phieu-chi-ban-ghi | P1 |
| TC10 | Số dư khách hàng và dùng số dư cho đơn mới | KT, CS | TC-14, TC-16 | ✅ 03-ke-toan §7 | so-du-ds | P2 |

## 5. Đào tạo (ghi danh, xếp lớp, lớp, buổi, giờ)
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| DT1 | Ghi danh: xem danh sách, bản ghi, số giờ | CS, BM | GD-01, GD-02, GD-04 | ◐ 03-cskh §2 | ghi-danh-so-gio | P1 |
| DT2 | Xếp lớp cho ghi danh (theo nhóm hoặc theo lớp), hàng chờ xếp lớp | CS, BM | GD-03, GD-06 | ✅ 03-cskh §2 | ghi-danh-cho-xep, ghi-danh-xep-lop | P1 |
| DT3 | Học sinh hai ghi danh cùng lớp (trừ giờ theo ghi danh cũ trước) | CS | GD-02, GD-04 | ❌ | — | P3 |
| DT4 | Điều chỉnh giờ (dòng ngược dấu, lý do) | BM | GD-05 | ✅ 03-truong-co-so §9 | — | P2 |
| DT5 | Sắp hết giờ / dự báo hết giờ | CS, SA | GD-07 | ❌ | — | P2 |
| DT6 | Tái tục: phiếu tái tục (danh sách, kanban L1–L8, tạo thủ công) | CS, SA | TT-01, TT-02, TT-03 | ❌ | — | P1 |
| DT7 | Tạo / sửa lớp, thời khoá biểu, trình duyệt | CS | LOP-03, LOP-04, LOP-05 | ✅ 03-cskh §3 | lop-trinh | P1 |
| DT8 | Duyệt / từ chối lớp | BM | LOP-05 | ✅ 03-truong-co-so §6 | lop-duyet | P1 |
| DT9 | Đóng / huỷ lớp (liệt kê lý do bị chặn) | BM | LOP-06 | ✅ 03-truong-co-so §7 | — | P2 |
| DT10 | Đổi giáo viên, đổi lịch cố định của lớp đã duyệt | CS, BM | LOP-07, LOP-10 | ❌ | — | P2 |
| DT11 | Lịch tuần cơ sở (theo phòng, giáo viên); danh sách học sinh của lớp | CS, BM | LOP-08, LOP-09 | ◐ | lich-tuan | P2 |
| DT12 | Buổi học: danh sách hôm nay, bản ghi; theo dõi buổi chưa Done | CS, BM | BUOI-01, BUOI-02, BUOI-12 | ✅ 03-cskh §4 | — | P1 |
| DT13 | Điểm danh vận hành trong ngày (gọi nhắc, lý do liên hệ) | CS | BUOI-03, BUOI-11 | ✅ 03-cskh §4 | diem-danh-trong-ngay | P1 |
| DT14 | Huỷ buổi, dời một buổi | CS, BM | BUOI-04, BUOI-05 | ✅ 03-truong-co-so §8 | — | P1 |
| DT15 | Thêm học sinh học thử vào buổi | CS, SA | BUOI-06 | ❌ | — | P2 |
| DT16 | Yêu cầu học bù, buổi củng cố, học bổ trợ; duyệt yêu cầu buổi | CS, BM, GV | BUOI-07..10 | ◐ 03-cskh §14 | — | P2 |
| DT17 | Đổi giáo viên / trợ giảng cho một buổi; sửa điểm danh sau Done | CS, BM | BUOI-13, BUOI-14 | ✅ 03-truong-co-so §8 | — | P2 |
| DT18 | Ngày nghỉ lễ | AD, BM | QT-14 | ❌ | — | P3 |

## 6. Aftersale / CSKH (ticket, phiếu nghiệp vụ, khiếu nại)
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| CS1 | Tạo ticket (loại, nhóm, nhóm con) và xử lý | CS, SA | CS-01, CS-02, CS-04 | ✅ 03-cskh §5 | ticket-ds, ticket-ban-ghi, ticket-kanban | P1 |
| CS2 | Khiếu nại: xử lý, nâng cấp, mở lại | CS, BM | CS-03, CS-13 | ✅ §6 | — | P1 |
| CS3 | Phiếu nghiệp vụ, cách làm chung và duyệt từng cấp | CS, BM, KT | CS-08 | ✅ §7 | phieu-nghiep-vu-cho-toi, phieu-nghiep-vu-duyet | P1 |
| CS4 | Phiếu Cập nhật hồ sơ | CS | CS-04, CS-08 | ✅ §8 | — | P1 |
| CS5 | Phiếu Bảo lưu (mới, gia hạn, quay lại) | CS | CS-09 | ✅ §9 | — | P2 |
| CS6 | Phiếu Chuyển lớp, Chuyển cơ sở (hai cơ sở duyệt) | CS, BM | CS-06, CS-07 | ✅ §10 | — | P2 |
| CS7 | Phiếu Dừng học (xử lý tiền) | CS, BM | CS-14 | ✅ §11 | — | P2 |
| CS8 | Phiếu Hoàn học phí (bảng tính hoàn) | CS, KT, BM | CS-05 | ✅ §12 | — | P2 |
| CS9 | Phiếu Chuyển phí | CS, KT | CS-10 | ✅ §13 | — | P2 |
| CS10 | Phiếu Đổi lịch, học bù | CS | CS-11 | ✅ §14 | — | P2 |
| CS11 | Từ chối / khách huỷ ticket (lý do) | CS, BM | CS-12 | ◐ §5 | — | P2 |
| CS12 | Hàng nhận xét chờ gửi phụ huynh | CS | CS-16 | ✅ §15 | nhan-xet-cho-gui | P1 |
| CS13 | Cấu hình người duyệt ticket theo nhóm con | AD | QT-15 | ❌ | — | P3 |

## 7. Giáo viên (cổng điện thoại)
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| GV1 | Hôm nay: xem buổi, việc sắp trễ hạn | GV, TG | GV-01, GV-02 | ✅ giao-vien §1 | thanh-duoi-giao-vien | P1 |
| GV2 | Lịch dạy (tuần, tháng) | GV, TG | GV-03 | ✅ §2 | — | P2 |
| GV3 | Điểm danh (4 trạng thái, lưu) | GV, TG | GV-05 | ✅ §3 | — | P1 |
| GV4 | Nội dung buổi và giao BTVN | GV, TG | GV-06 | ✅ §4 | — | P1 |
| GV5 | Chấm nhận xét từng em; xuất nhận xét | GV, TG | GV-07 | ✅ §5, §15 | — | P1 |
| GV6 | Chấm BTVN của buổi trước (5 trạng thái) | GV, TG | GV-08 | ✅ §6 | — | P1 |
| GV7 | Kiểm còn thiếu và Hoàn tất buổi (Done ngay) | GV, TG | GV-09 | ✅ §7 | — | P1 |
| GV8 | Việc cần làm / quá hạn | GV, TG | GV-12 | ✅ §9 | viec-cua-toi-hom-nay | P1 |
| GV9 | Lớp của tôi, chi tiết lớp, hồ sơ rút gọn học sinh | GV, TG | GV-10, GV-11, GV-13 | ✅ §10 | — | P2 |
| GV10 | Giờ dạy của tôi (căn cứ lương) | GV, TG | GV-16 | ✅ §11 | — | P2 |
| GV11 | Tạo ticket từ cổng giáo viên, ticket lớp tôi | GV | GV-14 | ✅ §8, §12 | — | P2 |
| GV12 | Giao bài trên LMS và chấm bài nộp | GV, TG | GV-17, GV-18 | ◐ §14 | — | P2 |
| GV13 | Chấm kiểm tra buổi | GV | (buổi kiểm tra) | ✅ §13 | — | P2 |

## 8. Quản trị
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| QT1 | Tạo người dùng; sửa email; đặt lại mật khẩu; khoá / mở | AD | QT-01..03 | ✅ quan-tri §1, §2 | — | P1 |
| QT2 | Vai trò và ma trận quyền (xem, đổi) | AD | QT-04, QT-05 | ◐ §6 | — | P2 |
| QT3 | Danh mục (thêm, đổi tên, thứ tự, ngừng) | AD | QT-06, QT-07 | ✅ §3 | — | P2 |
| QT4 | Cơ sở và phòng học | AD | QT-08 | ❌ | — | P1 |
| QT5 | Tham số nghiệp vụ | AD | QT-09 | ✅ §4 | — | P2 |
| QT6 | Công tắc tính năng theo cơ sở | AD | QT-10 | ✅ §5 | — | P1 |
| QT7 | Nhật ký thao tác; nhật ký đăng nhập và xuất file | AD | QT-11, QT-12 | ✅ §7 | — | P3 |
| QT8 | Nhập dữ liệu cũ (CSV: chọn loại, xem trước, nạp) | AD | QT-18 | ❌ | — | P1 |
| QT9 | Gói bán, bảng giá có ngày hiệu lực, chiết khấu, điều khoản thanh toán | AD | CH-01..04, CH-09 | ❌ | — | P1 |
| QT10 | Khung chương trình, rubric nhận xét | AD | CH-05..07 | ✅ qt10a, qt10b | — | P2 |
| QT11 | Hồ sơ giáo viên, trợ giảng | AD, BM | QT-16 | ❌ | — | P2 |
| QT12 | Tài khoản học sinh, phụ huynh (cấp, khoá, đặt lại) | CS, AD | QT-13, QT-17 | ❌ | — | P2 |
| QT13 | Dữ liệu mẫu của tôi (tạo, xoá, phiếu chờ người khác duyệt) | tất cả NV | du-lieu-mau | ✅ 01 và 02 (đã bổ sung 24/11) | video du-lieu-mau | P2 |
| QT14 | Xoá bản ghi nhập nhầm (chỉ Admin) | AD | CHUNG-20 | ❌ | — | P3 |

## 9. Chung (mọi vai): vào hệ thống, thao tác, duyệt
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| CH1 | Đăng nhập, đổi mật khẩu lần đầu, quên mật khẩu, hết phiên | tất cả | CHUNG-01..09 | ✅ 01 §1.1–1.2 | dang-nhap-*, quen-mat-khau, video dang-nhap | P1 |
| CH2 | Xác thực hai bước (chỉ Admin) | AD | CHUNG-02, 03 | ✅ 01 §1.3 | — | P1 |
| CH3 | Menu, chọn cơ sở, đổi cổng, đăng xuất | tất cả | CHUNG-10, 25 | ✅ 01 §1.4–1.7 | menu-crm, chon-co-so, menu-tai-khoan | P1 |
| CH4 | Danh sách: tìm, Filters, Group By, Favorites, cột, phân trang | tất cả | khuôn K03 | ✅ 02 §2.1–2.8 | danh-sach-*, video danh-sach | P1 |
| CH5 | Bản ghi: mở, tạo, sửa, lưu; ghi chú; nhật ký | tất cả | K06, K07, CHUNG-22 | ✅ 02 §2.9–2.10 | ban-ghi-*, video ghi-chu | P1 |
| CH6 | Tìm kiếm toàn hệ thống; thông báo | tất cả | CHUNG-11, 12 | ✅ 02 §2.2, §2.11 | thong-bao | P2 |
| CH7 | Việc chờ tôi duyệt (gộp mọi loại) | BM, KT, AD | CHUNG-15 | ✅ 01 §1.6, 02 §2.12 | viec-cho-toi-duyet-* | P1 |
| CH8 | Trang chủ theo vai trò | SA, CS, BM, KT | CHUNG-14 | ✅ theo từng vai | ke-toan-trang-chu, truong-co-so-trang-chu | P1 |
| CH9 | Xuất file (có nhật ký); đính kèm tệp | có quyền | CHUNG-18, 21 | ❌ | — | P2 |
| CH10 | Gặp lỗi: không có quyền, phân hệ chưa bật, không tìm thấy; mã lỗi HMT_… | tất cả | CHUNG-16, 17, 24 | ◐ 05-hoi-dap | — | P1 |

## 10. Học sinh, Phụ huynh, Báo cáo
| # | Luồng | Vai | Màn | Phủ | Ảnh/video | Ưu tiên |
|---|---|---|---|---|---|---|
| HS1 | Đăng nhập học sinh (mã HS), đổi mật khẩu lần đầu | HS | CHUNG-06, 07 | ◐ 03-hoc-sinh | dang-nhap-hoc-sinh | P2 |
| HS2 | Trang chủ, bài tập, nộp bài (chụp ảnh, tải tệp), kết quả | HS | HT-01..05 | ✅ 03-hoc-sinh §1–2 | — | P2 |
| HS3 | Lịch học, kết quả học tập, nhận xét các buổi | HS | HT-06..08 | ✅ §3–4 | — | P2 |
| PH1 | Đăng nhập phụ huynh | PH | CHUNG-23 | ◐ 03-phu-huynh | dang-nhap-phu-huynh | P2 |
| PH2 | Xem kết quả, nhận xét, học phí và giờ, lịch học của con | PH | PH-01..03, 05 | ✅ 03-phu-huynh §1–4 | — | P2 |
| PH3 | Gửi đề nghị / khiếu nại và theo dõi | PH | PH-04 | ◐ (ghi «Màn sắp có») | — | P3 |
| BC1 | Tổng quan Ban giám đốc | AD, BM | BC-01 | ❌ | — | P3 |
| BC2 | Báo cáo tuyển sinh, tái tục, sĩ số/chuyên cần, BTVN, ticket | AD, BM, CS | BC-02, 05, 06, 07, 10 | ❌ | — | P3 |
| BC3 | Báo cáo doanh thu, thu tiền và giờ chưa dạy | AD, KT, BM | BC-03, 04 | ❌ | — | P3 |
| BC4 | Giáo viên trễ hạn; giờ dạy giáo viên (căn cứ lương) | AD, KT, BM | BC-08, 09 | ❌ | — | P2 |

## Tổng kết số lượng
| Phân hệ | Luồng | P1 | P2 | P3 | ❌ chưa có bài | ◐ sơ |
|---|---|---|---|---|---|---|
| 1 Tuyển sinh | 13 | 8 | 4 | 1 | 6 | 4 |
| 2 Khách hàng | 4 | 1 | 2 | 1 | 2 | 1 |
| 3 Bán hàng | 7 | 3 | 4 | 0 | 3 | 1 |
| 4 Thu chi | 10 | 6 | 4 | 0 | 3 | 0 |
| 5 Đào tạo | 18 | 8 | 8 | 2 | 6 | 3 |
| 6 Aftersale | 13 | 5 | 7 | 1 | 1 | 1 |
| 7 Giáo viên | 13 | 7 | 6 | 0 | 0 | 1 |
| 8 Quản trị | 14 | 5 | 7 | 2 | 7 | 1 |
| 9 Chung | 10 | 8 | 2 | 0 | 1 | 1 |
| 10 HS, PH, Báo cáo | 10 | 0 | 6 | 4 | 4 | 3 |
| **Cộng** | **112** | **51** | **50** | **11** | **33** | **16** |

(Số tổng kết tính tay từ các bảng trên ngày 24/11; nếu thêm bớt dòng thì cập nhật.)

## Ước lượng khối lượng
- **Số bài:** khoảng **100 bài** (mỗi luồng một bài; các luồng cùng màn nhỏ có thể gộp một bài). Có 33 luồng ❌ cần viết mới, 16 luồng ◐ cần viết lại đủ bước, 63 luồng ✅ cần **rà lại từng bước, thêm ảnh khung nổi bật và bảng lỗi HMT_…**.
- **Ảnh:** trung bình 4 ảnh một bài (mỗi bước chính một ảnh có khung nổi bật): khoảng **400 ảnh**. Đã có 75 ảnh (nhiều ảnh là ảnh danh sách/bản ghi, chưa phải ảnh từng bước); cần thêm khoảng 330. Dung lượng hiện 8,5 MB cho 75 ảnh (≈ 113 KB/ảnh).
- **Video (độ dài theo nội dung cần truyền đạt, không cố định; anh chốt 24/11; chỉ luồng chính P1):** khoảng **25 video** (51 luồng P1, gộp video theo nhóm: ví dụ Tư vấn 4, Kế toán 3, CSKH 5, Trưởng cơ sở 3, Giáo viên 4, Quản trị 3, Chung 3). Đã có 6 video; cần thêm khoảng 19.
- **Dung lượng:** video mp4 nén hiện có 116–272 KB mỗi cái (26–60 giây); đặt trần **≤ 1 MB mỗi video** (mục tiêu ≤ 400 KB) thì 25 video ≤ 10 MB (thực tế ~5 MB). Ảnh nên xuất PNG tối ưu hoặc WebP **≤ 80 KB/ảnh**: 400 ảnh ≈ 32 MB. **Tổng `public/huong-dan/` dự kiến ≤ 45 MB** (hiện 9,6 MB). Đề xuất đặt trần cứng 60 MB cho thư mục này; vượt thì chuyển video sang Cloudflare R2 (giai đoạn 4 theo CLAUDE.md) chứ không đẩy vào repo. Cloudflare Pages gói Free chấp nhận (giới hạn 20.000 tệp, mỗi tệp 25 MB); mỗi lần build tải lên ~45 MB tĩnh, không ảnh hưởng băng thông Supabase.
- **Rủi ro cần anh chốt:** (1) ảnh chụp tự động (`npm run chup-anh`) hiện lưu ngoài repo và chỉ chụp trang danh sách/bản ghi; ảnh từng bước trong hộp thoại cần mở hộp thoại tự động, chưa làm; (2) video quay trên bản thử nghiệm phải dùng dữ liệu giả, không tên thật; (3) mỗi lần đổi giao diện phải chụp lại ảnh liên quan (nên gắn tên ảnh với mã màn để biết ảnh nào cũ).

## Mẫu một bài (bản 24/11, thay mẫu cũ; theo báo cáo đánh giá mục 5)

Mọi bài dùng cùng khuôn. Tên tệp theo vai và luồng (ví dụ `tu-van/lap-don-hang.md`); **mục lục tự sinh từ phần đầu**, xem `README.md` cùng thư mục. Chữ trong «…» phải **chép đúng chữ trên màn** (công cụ kiểm sẽ dò). Luật viết bằng lời thường; mã luật (R-…) chỉ ghi trong phiếu kiểm, không đưa cho người học.

```
---
title: Lập đơn hàng cho khách đã đóng tiền
group: vai
slug: tu-van-lap-don-hang
order: 50
role: Tư vấn tuyển sinh
portals: [crm]
priority: P1
flow: bh3
screens: [BH-05, BH-08]
checked: 2026-11-26
checked_commit: <mã commit main lúc đi thử>
author: <người viết>
tested_by: <người đi thử>
---

# Lập đơn hàng cho khách đã đóng tiền

**Làm xong bạn có:** một đơn hàng đã trình, chờ quản lý của bạn duyệt.
**Ai làm:** Tư vấn tuyển sinh, CSKH. **Màn:** Cơ hội → bản ghi cơ hội.

> Video: [VIDEO: bh3]  (độ dài theo nội dung)
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Ô «Cơ sở» ở thanh trên đúng cơ sở của khách.
- [ ] Cơ hội đang ở **L8 Đăng ký học**; chưa ở L8 thì nút «Tạo đơn hàng» mờ.
- [ ] Mỗi em trong «Danh sách em» có đủ họ tên và năm sinh.

## Luật cần nhớ (lời thường, tối đa 3 gạch)
- Phụ huynh đóng tiền trước, rồi mới ghi đơn trên hệ thống.
- Một lớp một dòng đơn. Không chọn lớp cũng được: em nằm ở «Chờ xếp lớp».

## Các bước (tối đa 7; dài hơn thì tách bài)
1. Bấm «Tạo đơn hàng».
   *Bạn thấy:* trang đơn mới, khối «Dòng đơn» trống.
   [ẢNH: bh05-bh3-b1]
2. Bấm «Chọn gói…», chọn gói, nhập «Số lượng».
   *Bạn thấy:* dòng đơn có giá; «Tổng tiền» tự tính, không sửa tay.
   [ẢNH: bh05-bh3-b2]

⚠ **Bước N không hoàn tác bằng nút.** (đặt cảnh báo nổi bật ngay trước bước không hoàn tác)

## Sau bước này
- **Ai làm tiếp:** quản lý trực tiếp của bạn duyệt đơn.
- **Bạn xem ở đâu để biết đã xong:** Đơn hàng → lọc «Của tôi».

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Đơn còn Nháp | sửa thẳng, hoặc «Huỷ đơn hàng» |
| Đơn đã trình | nhờ người duyệt «Từ chối» → đơn về Nháp → sửa → trình lại |

## Lỗi hay gặp (3–5 dòng; đủ ở trang «Tra mã lỗi»)
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|

## Tập trên dữ liệu mẫu
- **Cần:** số tài khoản và vai (luồng có người duyệt thì cần ít nhất hai tài khoản).
- **Dùng:** bản ghi «[MẪU] …» trong «Dữ liệu mẫu của tôi».

## Tự kiểm: bạn làm được khi
- [ ] Có một bản ghi «[MẪU]» của bạn ở đúng trạng thái kết quả (nhìn thấy được trên hệ thống).
- [ ] Bạn nói được ai làm tiếp và bạn làm gì khi bị từ chối.

**Bước trước:** … · **Bước sau:** …
```

Quy ước: mỗi bước một dòng «Bạn thấy»; ảnh cắt vùng quanh khung đánh dấu, tên `<mã màn>-<mã luồng>-b<số>`; ảnh điện thoại chụp 390×844; ghi `checked`, `checked_commit`, `tested_by` sau khi đi thử xong. Phần đầu có thêm khoá khác ngoài danh sách ở `README.md` thì công cụ bỏ qua, không lỗi.

## Gợi ý chia việc
1. **Đợt 1 (P1, 51 luồng)** theo vai để mỗi người một tệp: Tư vấn (TS1–3, 5, 6, 9–11; BH1, 3), Kế toán (TC1–3, 6, 7, 9), CSKH (DT1, 2, 6, 7, 12, 13; CS1–4, 12), Trưởng cơ sở (BH4, TC2, DT8, 14), Giáo viên (GV1, 3–8), Quản trị (QT1, 4, 6, 8, 9), Chung (CH1–5, 7, 8, 10).
2. **Đợt 2 (P2, 50 luồng)** sau khi CS5 đã chạy được một tuần (lấy câu hỏi thật làm bài Hỏi đáp).
3. **Đợt 3 (P3, 11 luồng)** chỉ khi có người dùng hỏi.
