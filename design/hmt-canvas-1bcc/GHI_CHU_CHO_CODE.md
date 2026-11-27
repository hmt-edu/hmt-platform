# HMT Việc của tôi: ghi chú cho Code (canvas riêng, 27/11/2026)

Canvas này thay hai thứ ở canvas HMT Platform (9933):
- **TS-11 Lịch hẹn** (TS11_K5, TS11b, TS11c) bị thay bởi **VC01 đến VC07**.
- **Khối «Việc của tôi hôm nay» và các khối rời ở Trang chủ** (K09b, K09c_*) bị thay bởi **CHUNG-14 rút gọn** (CHUNG14_rut_gon, CHUNG14_rut_gon_dt).
- Code **không dựng theo khung cũ** của hai chỗ trên. Canvas 9933 giữ nguyên các khung cũ để đối chiếu, không đổi nhãn.

## Menu
Lấy theo các khung VC: nhóm Tổng quan gồm **Trang chủ**, **Việc của tôi**, **Việc chờ tôi duyệt**. Bỏ «Lịch hẹn» khỏi nhóm Tuyển sinh. Các nhóm còn lại giữ như canvas 9933. «Việc chờ tôi duyệt» (CHUNG-15) là mục có sẵn từ menu cũ; theo VT1 mục 2, `/crm/viec-cho-duyet` giữ làm màn chuyên và thẻ việc duyệt dẫn tới đó.

## Danh sách khung
| Khung | Nội dung |
|---|---|
| VC01_tuyen_sinh | Máy tính, Tư vấn tuyển sinh; không có gạt Cả đội |
| VC01b_cskh | Máy tính, CSKH |
| VC01c_truong_co_so | Máy tính, Trưởng cơ sở: gạt Của tôi / Cả đội + lọc theo người |
| VC06_lich_tuan | Lịch tuần (bỏ lịch tháng), Tạo lịch hẹn |
| VC04, VC04b, VC04c | Hộp «Để sau»; hết lượt hoãn; việc đã để sau |
| VC07, 07b, 07c, 07d | Nhóm trống; không còn việc; đang tải; lỗi tải |
| VC02, VC02b, VC04d, VC04e | Điện thoại 390×844 |
| CHUNG14_rut_gon, _dt | Trang chủ rút gọn |

## Luật thể hiện
- Ba nhóm Làm ngay / Hôm nay / Sắp tới theo trạng thái, không có số giờ trên giao diện; ngưỡng là tham số cấu hình.
- Việc gốc xong thì dòng tự mất, không có nút hoàn thành thủ công riêng.
- «Để sau»: mỗi lần tối đa 3 ngày, mỗi việc tối đa 2 lần. Việc chờ duyệt và buổi chưa điểm danh không có «Để sau».
- Kanban ở trang Cơ hội (tab xem). /crm/lich-hen chuyển hướng sang /crm/viec-cua-toi, mở sẵn Lịch tuần.

## Chữ tạm (Design soạn, chưa duyệt)
Mọi câu «cần làm gì», «vì sao gấp», câu trong hộp «Để sau», câu trống và lỗi. Tên, số điện thoại, số trong khung là dữ liệu giả, số minh hoạ, không chép vào code hay test.

## Khuôn mới đề xuất (chưa có trong P0)
Thẻ một phụ huynh gồm nhiều việc (gập/mở); tiêu đề nhóm có màu + số đếm + thu gọn; lưới lịch tuần.

## Chưa chắc / cần anh chốt
- Chưa vẽ Kế toán, Admin (VT1 không có tín hiệu riêng) và chế độ «Của tôi» cho Trưởng cơ sở.
- Thẻ «Việc chờ duyệt» đang gom theo loại; có thể gom theo người lập.
- Quyền xem cả đội: quyền riêng hay theo phạm vi Xem (VT1 mục 4).
- Menu ở các khung khác của canvas 9933 vẫn là menu cũ.
