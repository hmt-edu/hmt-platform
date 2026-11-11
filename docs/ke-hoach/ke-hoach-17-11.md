# Kế hoạch tới 17/11/2026

Cập nhật 10/11/2026 (Chat). Hai Code làm việc (Code 1, Code 2). Chat là nơi sửa file này; Code đọc đầu mỗi phiên và sau mỗi lần xong một PR.

## 1. Mục tiêu 17/11, cơ sở 5

LÕI gồm 28 màn, bắt buộc xong. Một học sinh mới đi trọn đường trên màn hình, không dùng SQL: phiếu thu duyệt, chọn lớp, ghi danh, xếp lớp, lớp, buổi, điểm danh. Giáo viên điểm danh, ghi nội dung buổi, chấm nhận xét và chấm BTVN.

| Cụm | Màn |
| --- | --- |
| Ghi danh | BH-08, GD-01, GD-02, GD-03, GD-04, GD-06 |
| Lớp | LOP-01, LOP-02, LOP-03, LOP-05, LOP-06, LOP-08 |
| Buổi | BUOI-01, BUOI-02, BUOI-03, BUOI-04, BUOI-05, BUOI-11, BUOI-12 |
| Khách hàng | KH-01, KH-02, KH-04, KH-05 |
| Thu tiền | TC-08, TC-13 |
| Giáo viên | GV-05, GV-07, GV-08 (GV-01, 02 đã code, PR #232 chờ gộp sau #228; GV-04, 06 do Code 2 làm, chưa mở PR tính đến 10/11) |

Để sau 17/11: ticket (CS), quản trị (QT-04, 05, 08, 09, 10), GV-09 đến GV-12, GV-14, GV-16, báo cáo, cổng học tập, cổng phụ huynh, hoàn tiền, bảo lưu, chuyển lớp, gộp trùng, đối soát.

## 2. Hàng đợi từng Code (theo thứ tự, đều ĐÃ DUYỆT)

### Code 1 (VS Code)

1. PR tài liệu: hai file quy tắc và kế hoạch này, cập nhật `docs/TIEN-DO.md`, thêm dòng đọc hai file vào `CLAUDE.md`. Làm trước nhất.
2. GV-05, mở PR trước tối 11/11. Route `/gv/buoi/:id/diem-danh` nằm trong PR này. Không sửa #228. Cần hàm đọc mới thì dùng migration 111.
3. Cụm Ghi danh (một PR), mở PR trước trưa 13/11.
4. Cụm Buổi A (một PR): BUOI-01, 02, 03, 11. Mở PR trước sáng 14/11.
5. Cụm Buổi B (một PR): BUOI-04, 05, 12. Mở PR trước tối 15/11.
6. Sửa lỗi từ buổi diễn tập staging.

### Code 2 (Terminal)

1. #228: đẩy commit gộp sau khi `check:all` xanh, điền file kiểm.
2. Một PR gồm GV-04, GV-06, migration 109 và 110. Mở trước sáng 11/11. Migration 110 đứng sau 109.
3. Cụm Lớp (một PR), mở PR trước tối 12/11.
4. Cụm Khách hàng (một PR), mở PR trước tối 13/11.
5. GV-08 (migration 121) và GV-07 (một PR), mở PR trước trưa 15/11.
6. Cụm Thu tiền (một PR), mở PR trước tối 15/11.
7. Sửa lỗi từ buổi diễn tập; cột lưu dấu Đúng hạn/Trễ hạn.
8. Đưa vào báo cáo: danh sách tham số và cờ cần đặt sẵn cho CS5 khi lên production, cách đặt bằng migration.

## 3. Mốc

| Ngày | Mốc |
| --- | --- |
| Thứ Sáu 13/11, 12:00 | Chat đếm tiến độ LÕI. Dưới 60% thì báo anh Trường chọn: chạy 17/11 với phần đã xong, hoặc lùi ngày nạp dữ liệu |
| Thứ Bảy 14/11 | Deploy staging, diễn tập nạp dữ liệu, anh Trường thử bằng tay |
| Thứ Hai 16/11, 12:00 | Đóng băng, hết nhận màn mới |
| Thứ Hai 16/11, tối | Anh Trường sao lưu và deploy production |
| Thứ Ba 17/11 | Nạp dữ liệu cơ sở 5, chạy thật |

Cuối tuần vẫn làm việc.

## 4. Quyết định có hiệu lực

- Q-267: gộp migration 109 và 110 thành một PR.
- Q-272: bước chấm BTVN buổi trước chặn Done khi tham số `session_done_requires_review` Bật, không chặn khi Tắt. Giai đoạn đầu để Tắt.
- Chuỗi gộp: #228, rồi PR 109+110, rồi các cụm theo hàng đợi. #232 gộp sau #228 (dùng hàm của #228). #230 không phụ thuộc #228 (nhánh đã gộp main, CI xanh, chờ ĐÃ KIỂM). #233 độc lập.
- Anh Trường tự quyết: deploy production, nạp dữ liệu thật, OK ĐƯA VÀO LUẬT, OK ĐÓNG GÓI, OK ĐĂNG, bình luận OK trên PR. Chat duyệt các quyết định nhỏ còn lại (Q-270).
