---
title: Tạo phiếu Test từ cơ hội
group: vai
slug: tu-van-ts10
order: 47
role: Tư vấn tuyển sinh
portals: [crm]
priority: P1
flow: ts10
screens: [TS-08, TS-15, TS-16]
checked: 2026-11-24
---

# Tạo phiếu Test từ cơ hội

**Làm xong bạn có:** một phiếu Test ở trạng thái «Nháp», có ngày giờ test và một lịch hẹn nhắc phụ huynh.
**Ai làm:** Tư vấn tuyển sinh, CSKH. **Màn:** Cơ hội → bản ghi cơ hội.

> Video: [VIDEO: ts10]
> Không xem được video? Làm theo các bước dưới là đủ.

## Trước khi bắt đầu, kiểm
- [ ] Ô chọn cơ sở ở thanh trên đúng cơ sở của khách.
- [ ] Cơ hội đang ở giai đoạn **L5 trở đi** (xem thanh giai đoạn đầu bản ghi). Chưa tới L5 thì nút «Tạo lịch Test» mờ; rê chuột sẽ thấy «Chỉ tạo phiếu khi cơ hội ở L5 trở đi».
- [ ] Cơ hội đã có tên và năm sinh của học sinh cần test (khối «Danh sách học sinh»). Chưa có học sinh thì thêm học sinh trước.
- [ ] Bạn có quyền tạo phiếu Test. Không có thì nút mờ kèm «Bạn không có quyền tạo phiếu kiểm tra».

## Luật cần nhớ (lời thường)
- Một phiếu cho **một học sinh**. Nếu cơ hội có hai học sinh cần test thì tạo hai phiếu; một cơ hội có thể có nhiều phiếu.
- Cơ hội chưa biết khối, nên **khối chọn ngay lúc tạo phiếu** (ô tên «Lớp»).
- **Ngày giờ test là bắt buộc và phải ở tương lai.** Chưa chọn thì nút «Tạo phiếu» chưa bật.
- Cơ sở test phải là cơ sở dạy học (không phải Hội sở).
- Tạo phiếu xong, hồ sơ học sinh của học sinh tự sinh (hoặc dùng hồ sơ có sẵn nếu trùng tên, năm sinh và phụ huynh).
- Phòng test và giáo viên chấm **chọn sau**, ở trang phiếu.

## Các bước
1. Mở **Cơ hội**, mở cơ hội cần test, bấm **«Tạo lịch Test»** ở đầu bản ghi.
   *Bạn thấy:* hộp «Tạo phiếu Test», dòng phụ ghi mã cơ hội và tên phụ huynh.
   [ẢNH: ts08-ts10-b1] [CHƯA CHỤP: cần chụp trên staging CS5]
2. Ô **«Học sinh»**: chọn học sinh cần test (hiện tên và năm sinh). Không thấy học sinh? Đóng hộp, bấm «+ Thêm học sinh» ở khối thông tin học sinh rồi quay lại.
   *Bạn thấy:* tên học sinh hiện trong ô.
   [ẢNH: ts15-ts10-b2] [CHƯA CHỤP: cần chụp trên staging CS5]
3. Chọn lần lượt **«Lớp»** (khối của học sinh), **«Môn»**, **«Hình thức test»**, **«Cấp độ đề»**, **«Cơ sở test»**.
   *Bạn thấy:* năm ô đều có giá trị; ô bỏ trống làm nút «Tạo phiếu» chưa bật.
4. **«Đề test»** (không bắt buộc): gõ tên đề, ví dụ «Toán 9 cơ bản – đề 2». Không cần tải file đề. **«Người phụ trách»** mặc định là «Bạn»; đổi nếu người khác theo dõi buổi test.
   *Bạn thấy:* ô «Người phụ trách» có tên.
5. Chọn **«Ngày test»** và **«Giờ test»**. Có thể bấm nhanh ở hàng «Chọn nhanh ngày» và «Chọn nhanh giờ».
   *Bạn thấy:* nếu chọn giờ đã qua, dòng đỏ «Giờ test phải ở tương lai.»; nút «Tạo phiếu» chưa bật.
   [ẢNH: ts15-ts10-b5] [CHƯA CHỤP: cần chụp trên staging CS5]
6. Xem khối **«Lịch hẹn nhắc (tạo cùng phiếu)»**: hệ thống tự điền «Ngày nhắc» và «Giờ nhắc» (thường 17:00 ngày hôm trước; test trong 24 giờ tới thì nhắc trước 2 giờ). Sửa được, nhưng giờ nhắc phải **trước** giờ test.
   *Bạn thấy:* dòng «Nhắc lúc …».
7. Bấm **«Tạo phiếu»**.
   *Bạn thấy:* thông báo tạo xong, trang phiếu mới ở trạng thái **Nháp**; cơ hội có thêm một dòng ở thẻ «Kiểm tra».
   [ẢNH: ts17-ts10-b7] [CHƯA CHỤP: cần chụp trên staging CS5]

⚠ Sau bước 7 **không sửa được** môn, khối, hình thức bằng ô trên phiếu. Muốn đổi các ô đó, huỷ phiếu rồi tạo phiếu mới (xem bài «Vòng đời phiếu Test»). Riêng ngày giờ đổi bằng nút «Đổi lịch» khi phiếu còn Nháp.

## Sau bước này
- **Ai làm tiếp:** bạn hoặc CSKH chọn **phòng** và **GV chấm** ở trang phiếu; đến giờ test bạn bấm «Bắt đầu test» (bài «Vòng đời phiếu Test»).
- **Bạn xem ở đâu:** menu **Tuyển sinh → Phiếu Test** (lọc «Tôi tạo», «Tôi phụ trách»), hoặc nút «Kiểm tra» trên cơ hội. Lịch hẹn nhắc hiện ở **Lịch hẹn**.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Chọn sai ngày giờ test | Mở phiếu (còn Nháp) → bấm «Đổi lịch» → chọn «Ngày mới», «Giờ mới» |
| Chọn sai học sinh, môn, khối, hình thức | Huỷ phiếu (menu «Hành động» → «Huỷ phiếu», chọn lý do) rồi tạo phiếu mới |
| Tạo phiếu cho cơ hội chưa đúng | Huỷ phiếu; không ảnh hưởng giai đoạn cơ hội đã đi tới |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Giờ test phải ở tương lai.» (HMT_GIO_TEST_QUA_KHU) | giờ đã qua | chọn lại ngày giờ |
| «Giờ nhắc phải trước giờ test.» (HMT_GIO_NHAC_SAI) | giờ nhắc sau giờ test | sửa «Ngày nhắc», «Giờ nhắc» |
| «Chỉ tạo phiếu kiểm tra khi cơ hội đang ở L5 trở đi. Chuyển cơ hội sang L5 trước.» (HMT_CO_HOI_CHUA_DEN_L5) | cơ hội chưa tới L5 | chuyển giai đoạn trước (bài «Đi cơ hội qua L1–L8») |
| «Cơ hội chưa có em. Thêm em ở hồ sơ cơ hội trước khi tạo phiếu kiểm tra.» (HMT_CO_HOI_CHUA_CO_EM) | thiếu học sinh | thêm học sinh ở khối thông tin học sinh |
| «Cơ sở test phải là cơ sở dạy học, không phải Hội sở.» (HMT_CO_SO_VAN_PHONG) | chọn nhầm Hội sở | chọn cơ sở dạy học |
| «Cơ hội này đã gộp vào bản khác, không tạo phiếu được.» (HMT_BAN_GHI_DA_GOP) | cơ hội đã gộp | mở cơ hội còn lại |

## Hỏi đáp
- **Tạo hai phiếu cho hai học sinh được không?** Được, mỗi học sinh một phiếu từ cùng cơ hội.
- **Phiếu có tải đề được không?** Chưa. Chỉ ghi tên đề vào ô «Đề test».
- **Không thấy nút «Tạo lịch Test»?** Kiểm bạn đang ở bản ghi cơ hội (không phải lead) và cơ hội chưa bị gộp.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản `tvts1–3.cs5` (hoặc `cskh1–3.cs5`).
- **Dùng:** cơ hội «[MẪU] …» đã ở L5 trở đi trong bộ dữ liệu mẫu của bạn (Menu tài khoản → «Dữ liệu mẫu của tôi»). Bộ mẫu chưa có cơ hội L5: đi một cơ hội «[MẪU]» tới L5 bằng bài «Đi cơ hội qua L1–L8» (nhớ điền tên và năm sinh học sinh từ L5).

## Tự kiểm: bạn làm được khi
- [ ] Có một phiếu «[MẪU]» ở «Nháp», ngày test ở tương lai.
- [ ] Bạn nói được vì sao khối chọn ở hộp tạo phiếu và nút mờ khi cơ hội dưới L5.

**Bước trước:** Đi cơ hội qua L1–L8 · **Bước sau:** Vòng đời phiếu Test
