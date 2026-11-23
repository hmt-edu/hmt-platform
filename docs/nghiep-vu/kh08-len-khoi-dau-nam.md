# KH-08 Lên khối đầu năm học (Code F, 19/11/2026; thẻ F73)

Luật anh Trường chốt 19/11/2026 23:17 (bản đồ màn hình KH-08, trước đó «chưa có luật chi tiết»):
1. **Admin bấm tay** chạy «Lên khối đầu năm»; không tự chạy theo lịch.
2. **Em đủ điều kiện**: đã có khối (1 đến 12), chưa tốt nghiệp và **đang học** (có ghi danh Chờ xếp lớp, Đã xếp lớp hoặc Đang học; cùng định nghĩa `app.student_status`). Bỏ qua, không đổi khối: em bảo lưu, đã dừng học, tiềm năng (chưa ghi danh), chưa có khối, đã tốt nghiệp.
3. **Lên một khối**; **lớp 12 tốt nghiệp**: ghi `app.student.graduated_on` (ngày giờ Việt Nam), giữ khối 12.
4. **Xem trước từng em** (khối cũ → khối mới, hoặc Tốt nghiệp) và **loại trừ** từng em (bỏ tick) trước khi xác nhận; lọc theo cơ sở, tìm tên hoặc mã HS.
5. **Hoàn tác cả đợt** trong `grade_promotion_undo_days` ngày (mặc định 7, 1 đến 30, chỉnh ở Cài đặt). Em đã được sửa khối tay sau đợt thì giữ nguyên, không đè. **Nhật ký từng em**: bảng dòng đợt (`app.grade_promotion_item`: khối cũ, khối mới) và nhật ký thao tác của học sinh (trigger khung chung).

## Hàm DB (migration 566)
| Hàm | Làm gì | Lỗi |
|---|---|---|
| `app.preview_grade_promotion(p_filters, p_limit, p_offset)` | số em đủ điều kiện, tốt nghiệp, số em bỏ qua theo lý do; danh sách từng em phân trang máy chủ | `HMT_KHONG_CO_QUYEN` |
| `app.run_grade_promotion(p_filters, p_excluded)` | chạy một đợt trong một giao dịch; trả `batch_id`, số lên khối, tốt nghiệp, loại trừ | `HMT_KHONG_CO_QUYEN`, `HMT_KHONG_CO_EM_LEN_KHOI` |
| `app.undo_grade_promotion(p_batch_id)` | hoàn tác cả đợt trong hạn | `HMT_DOT_DA_HOAN_TAC`, `HMT_QUA_HAN_HOAN_TAC`, `HMT_KHONG_TIM_THAY` |
| `app.list_grade_promotion_batches()` | các đợt đã chạy kèm hạn hoàn tác | `HMT_KHONG_CO_QUYEN` |

Chỉ Admin đã xác thực hai bước (Quản trị · Sửa để chạy và hoàn tác, Quản trị · Xem để xem). Bảng đợt, dòng đợt: bật RLS, đọc cho Admin, ghi chỉ qua hàm; khung chung (người, giờ, nhật ký, không xoá).

## Giao diện
`/crm/len-khoi-dau-nam` (menu Khách hàng, mục «Lên khối đầu năm», chỉ Admin): danh sách xem trước K03 (Mã HS, Học sinh, Cơ sở, Khối hiện tại, Khối mới, Loại trừ), chọn dòng rồi «Loại trừ khỏi đợt» hoặc «Bỏ loại trừ»; dòng tóm tắt số em sẽ chạy; nút «Xác nhận lên khối» mở hộp xác nhận K08; bên dưới bảng «Các đợt đã chạy» có nút Hoàn tác trong hạn. Bản đồ màn hình ghi «hộp thoại K08»; làm thành trang vì cần danh sách phân trang và lịch sử đợt (ghi chú để anh biết).

## Còn mở
- Em loại trừ chỉ giữ trên trình duyệt trong lúc xem; đổi bộ lọc cơ sở vẫn giữ danh sách loại trừ.
- Chặn chạy lần hai trong năm học: xem mục «Chặn lần hai» (migration 635). Danh mục «năm học» thật chưa có; đang dùng tham số tạm.

## Hiệu năng
`app.grade_promotion_candidates` trên 30.000 học sinh giả, một nửa có ghi danh: 14 ms. Xem trước phân trang ở máy chủ (50 dòng).

## Chặn lần hai trong năm học (migration 635, anh chốt 23/11/2026)
- «Năm học này» = từ ngày 1 của tháng `school_year_start_month` (INT 1..12, mặc định 6, chỉnh ở Cài đặt, ghi đè theo cơ sở được) gần nhất tính đến hôm nay (giờ Việt Nam). Đây là định nghĩa tạm theo tham số; anh Trường đổi tháng khi cần.
- Em có dòng đợt chưa hoàn tác của một đợt «Đã chạy» tạo từ ngày đó thì bị bỏ qua ở xem trước và khi chạy (theo cơ sở hay mọi cơ sở đều vậy). Hoàn tác đợt (7 ngày) thì em chạy lại được.
- Hàm: `app.school_year_start(branch)`, `app.grade_promotion_done_this_year(branch)` (nội bộ); `app.grade_promotion_candidates` loại em đã lên khối năm nay; xem trước thêm `skipped.da_len_khoi_nam_nay`, `last_run_at`; chạy báo `HMT_DA_LEN_KHOI_NAM_NAY` (kèm ngày chạy lần trước) khi không còn em nào mà có em đã lên khối năm nay.
- pgTAP: `635_kh08_chan_len_khoi_lan_hai.test.sql`.
