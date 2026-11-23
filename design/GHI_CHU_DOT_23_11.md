# Ghi chú cho Code · đợt Design 23/11/2026 (chốt 15:58)

## Bỏ
- Bỏ hẳn bản «xem gọn» (dải 4 ô, một nút chính theo giai đoạn) cho Ticket, Lead, Cơ hội, Đơn hàng, Phiếu thu. 4 khung CSN03_gon_* gỡ khỏi canvas Đào tạo & Giáo viên; 13 khung CSN03_* cũ bỏ nhãn «BẢN CŨ, KHÔNG LÀM». Các màn này giữ bố cục hiện tại.
- Khiếu nại: giữ 7 bước chung như ticket thường, chỉ có nút «Mở lại». Không vẽ bước riêng. Không có CSN04_nang_cap / mo_lai.

## Mới (canvas chuẩn 9933)
- TS-11 Hoàn thành lịch hẹn (K08 FormDialog): TS11_hoan_thanh_trong / da_dien / dang_luu / loi / dt.
  - Kết quả (bắt buộc, danh sách chọn): Đã tư vấn quan tâm; Hẹn gọi lại; Không nghe máy; Khách từ chối; Sai số; Đã chốt đăng ký. Danh sách này là gợi ý, nên đọc từ danh mục.
  - Hẹn lần sau (tuỳ chọn, ngày + giờ): có giá trị thì hệ thống tự tạo lịch hẹn kế. Ngày giờ trước hiện tại thì báo lỗi dưới ô.
  - Ghi chú (tuỳ chọn). Nút Huỷ / Hoàn thành; Hoàn thành mờ đến khi chọn Kết quả. Đang lưu: khoá ô và hai nút.
  - Điện thoại: toàn màn, nút 48px.
- CHUNG21_chatter_chon_anh / da_gui: nút Đính kèm ảnh trong ô ghi chú, ảnh thu nhỏ có nút ×, ảnh đang tải có thanh tiến độ, ảnh lỗi có «Thử lại». Giới hạn theo CHUNG-21 (JPG, PNG, 10 MB mỗi ảnh, 5 ảnh mỗi lần). Ghi chú đã gửi hiện ảnh thu nhỏ. Ảnh trong khung là ô giữ chỗ.
- K09c_tuyen_sinh / truong_co_so / cskh / ke_toan: trang chủ theo vai trò, thay K09b (K09b gắn nhãn BẢN CŨ). Vai trò hiển thị «Tuyển sinh». Không có thẻ «Nhận xét chờ gửi» (CS-16 đã bỏ).

## Mới (canvas bổ sung abea)
- BH05_chua_chon_dk: «Chưa chọn điều khoản», thanh toán một lần (R-TIEN-07).
- BH05_dot1_nho_hon_coc: đợt 1 (680.400 đ) nhỏ hơn cọc tối thiểu (1.000.000 đ): cảnh báo vàng, chưa chặn. Số là số minh hoạ.
- TC17_duyet, TC17_tu_choi: thêm dòng «Phụ huynh».
- Lệch sẵn có: BH05 trong abea ghi tổng 13.608.000 ở bảng nhưng script ghi 8.856.000. Chỉ sửa ở hai khung mới.

## Mới (canvas Đào tạo & Giáo viên 9189)
- CSN07_duyet_chuyen_lop: hộp duyệt phiếu chuyển lớp có tóm tắt lớp mới (lớp cũ → lớp mới, lịch, giáo viên, ngày bắt đầu, giờ còn lại). Không có tiền. Số minh hoạ.
- GV điện thoại: GV07_gon_dt (Lưu ở thanh dưới, 9 tiêu chí mỗi tiêu chí một dòng nút 44px, cấu hình tiêu chí và Xuất PDF gập), GV02_gon_dt (câu «Có n việc quá hạn · Xem», theo R-V2-37), GV05_buoc_tiep_dt và GV06_buoc_tiep_dt (nút Bước tiếp sau khi lưu).

## Chưa làm / còn thiếu
- BC-02..07, BC-10, CS-10: chưa có khung. Chưa vẽ.
- Thông báo (CHUNG-12): chờ anh quyết.
