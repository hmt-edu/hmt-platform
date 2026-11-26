# Sản phẩm (trước gọi là «gói»): cấu trúc và dòng chứng từ (migration 674, 675)

Anh Trường chốt 26/11: giao diện gọi «Sản phẩm»; mã và tên chỉ để tìm; tên bảng, hàm trong cơ sở dữ liệu giữ `*package*`.

## Luật
- Mã chỉ cần đúng dạng chữ in và gạch nối, không trùng, không đổi; **không còn ép Loại-Môn-Khối**.
- Sản phẩm giờ học bắt buộc có môn, không bắt buộc khối. Dịch vụ, tài liệu không gắn môn, khối.
- Khối: `grade_codes` (danh mục `PRODUCT_GRADE`) và `grade_label`. Mã bắt đầu `Kxx` thuộc khối xx khi ghép lớp; có mã khác (Chuyên sâu, Toán tiếng Anh, SAT) thì không ràng khối. Các khối phải liền nhau.
- Loại lớp, môn, khối của sản phẩm không đổi sau khi tạo.
- Giờ mỗi tháng, sĩ số chuẩn, giờ mỗi buổi, buổi mỗi tuần, ghi chú là thông tin gợi ý, không tự điền vào đơn (R-TIEN-36).
- Dòng báo giá, đơn chụp môn và **khối đã chọn**; máy chủ kiểm khối nằm trong khối của sản phẩm; sản phẩm một khối thì tự điền. Đơn từ báo giá sao nguyên (R-TIEN-14).

## Hàm
| Hàm | Thay đổi |
|---|---|
| `app.save_sales_package` | nhận `grade_codes`, `grade_label`, `hours_per_month`, `standard_class_size`, `hours_per_session`, `sessions_per_week`, `note`; cách cũ `grade_from_code`/`grade_to_code` vẫn dùng được |
| `app.tg_sales_package_rules` | luật ở trên; mã lỗi mới `HMT_KHOI_KHONG_LIEN` |
| `app.product_base_grade` | mới: khối Kxx của một mã khối sản phẩm |
| `app.tg_sales_line_snapshot` | mới: chụp môn, khối; mã lỗi `HMT_KHOI_KHONG_THUOC_SAN_PHAM` |
| `app.save_quotation`, `app.order_write_priced_lines`, `app.order_add_priced_line`, `app.create_order_from_upsale_ticket` | nhận `grade_code` trên từng dòng |
| `app.list_sellable_packages` | trả thêm `grade_codes`, `grade_label`; trả mọi sản phẩm bán, sắp theo mã |

## Còn lại
Sản phẩm dải khối chưa bắt buộc chọn khối (giao diện cũ chưa gửi); bắt buộc khi giao diện mới có ô Khối.
