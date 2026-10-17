# -*- coding: utf-8 -*-
import sys; sys.path.insert(0, 'scripts')
from p5a_common import wr
from p5a_overview import HEAD, TAIL
Q = [
 ('Duyệt khuôn K13 (bản in A4/A5 dọc).', 'Anh duyệt 17/10 khuôn K13 (bản in A4/A5, mới đề xuất, ghi vào P0 v5). Đã vẽ BH-03 (A4) và TC-07 (A5). TC-12 vẫn mức C, không vẽ.', 'Đã chốt, đã vẽ'),
 ('Báo giá Toán khối 7+.', 'Anh SỬA 17/10: hai dòng riêng Đại số, Hình học, mỗi dòng giờ, giá, chiết khấu riêng; học một môn thì một dòng; chuyển thành đơn thì thẳng thành hai dòng đơn. Đã sửa BH-02 (mọi trạng thái). Báo giá vẫn không chọn học sinh (câu 6).', 'Đã chốt, đã sửa'),
 ('Nút Xuất, màn điện thoại BH-07, ô bắt buộc phiếu thu, TC-15 không biểu đồ, Admin xem TC-04 và TC-08.', 'Anh OK 17/10 (câu 3, 4, 5, 7, 8). Giữ như đang vẽ.', 'Đã chốt'),
 ('Luồng phiếu chi, tài khoản nhận tiền hoàn, tỉ lệ phí.', 'Anh OK 17/10 (câu 9, 10, 12). Số hoàn tiền dùng đúng ví dụ luật: 48 giờ × 220.000 đ, chiết khấu 10%, đóng 9.504.000 đ, học 20 giờ (4.400.000 đ), còn 5.104.000 đ, phí 10%, hoàn 4.593.600 đ. Đã sửa TC-11.', 'Đã chốt, đã sửa'),
 ('Lịch đóng từng đợt (câu 11).', 'Anh SỬA 17/10: không nhập tay. BH-05 có ô chọn "Điều khoản thanh toán" (danh mục cấu hình: số đợt, % mỗi đợt, số ngày đến hạn); chọn xong lịch đợt (đợt, hạn, số tiền) tự hiện ở tab Thanh toán, chỉ đọc; không chọn thì thanh toán một lần. TC-13 đọc lịch này. Đã sửa BH-05 và TC-13.', 'Đã chốt, đã sửa'),
 ('Màn danh mục "Điều khoản thanh toán".', 'Anh OK 17/10: em chỉ vẽ ô chọn ở BH-05; danh mục (mã, tên, số đợt, % mỗi đợt, số ngày đến hạn) anh sẽ thêm vào P2 v5.', 'Đã chốt'),
 ('Tiền phiếu thu trả đợt nào.', 'Anh OK 17/10: tiền đã vào tính từ đợt cũ nhất, chỉ để theo dõi công nợ, không đổi cách chia tiền về dòng đơn. Đã vẽ ở BH-05 và TC-13.', 'Đã chốt')]
DEV = [
 'Không có nút Tạo trên danh sách báo giá, đơn, phiếu thu, phiếu chi (R-TIEN-02, R-TIEN-28); chỉ tạo từ cơ hội, báo giá, đơn, ticket.',
 'Hộp thoại dùng khuôn K08, vẽ nổi trên màn gọi nó; mỗi trạng thái hộp có một khung riêng khi cần (TC-05, BH-08).',
 'Danh sách dựng từ khuôn K03 của P3: bỏ nút Tạo, Nhập; bỏ cột chọn ở TC-04, TC-08, TC-10, TC-13 vì không có thao tác hàng loạt.',
 'Bảng dòng đơn dùng cột cố định, số căn phải; ô giờ nhập tay từng dòng, không có phân bổ hay chia đều.',
 'TC-15 dựng từ khuôn K09 (báo cáo) không có biểu đồ; thêm cột chọn và nút Đánh dấu đã khớp.',
 'Phiếu chi hiện bảng tính hoàn trong cùng tab với thông tin, để Kế toán thấy cách tính khi duyệt.',
 'BH-05: Điều khoản thanh toán là ô chọn (danh mục cấu hình), lịch đợt chỉ đọc; công nợ TC-13 đọc lịch này. BH-08 có thêm ví dụ lớp Đại, Hình luân phiên (không báo trùng); lý do trùng ghi theo buổi thật.',
 'K13 (bản in): khuôn mới đề xuất, anh đã duyệt; cần ghi vào P0 v5. Xem trước là khổ giấy thật thu nhỏ, kèm nút In, Tải PDF.',
 'Dữ liệu mẫu hoàn toàn giả.']
STOPS = []
def notes():
    q = ''.join('<tr><td><b>%d</b></td><td><b>%s</b><br>%s</td><td style="white-space:nowrap">%s</td></tr>' % (i + 1, a, b, st) for i, (a, b, st) in enumerate(Q))
    d = ''.join('<li style="margin-bottom:3px">%s</li>' % x for x in DEV)
    s = ''.join('<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td>%s</td></tr>' % x for x in STOPS)
    left = ('<h1 style="font-family:var(--font-heading);font-size:24px;margin:0 0 6px">P5a · Ghi chú cuối canvas</h1><h2 class="s" style="margin-top:6px">Câu hỏi: tất cả đã chốt 17/10, không còn câu treo</h2>'
            '<div class="hmt-table-wrap"><table class="hmt-table t"><colgroup><col style="width:28px"><col><col style="width:70px"></colgroup><thead><tr><th>#</th><th>Câu hỏi và đề xuất</th><th>Anh</th></tr></thead><tbody>' + q + '</tbody></table></div>')
    right = ('<h2 class="s" style="margin-top:0">Chỗ lệch khuôn hoặc luật</h2><ul style="font-size:12px;line-height:1.5;margin:0;padding-left:18px">' + d + '</ul>'
             '<h2 class="s">Màn đã dừng</h2><p style="font-size:12px;line-height:1.5;margin:0">Không còn màn dừng. BH-03 và TC-07 đã vẽ theo khuôn K13 mới đề xuất (anh duyệt 17/10).</p>'
             '<h2 class="s">Mức C (không vẽ), dựng từ khuôn</h2><p style="font-size:12px;line-height:1.5;margin:0">BH-04, BH-10, BH-11, TC-06, TC-16: hộp K08 (có lý do hoặc xác nhận). TC-14: danh sách K03. TC-12 (bản in phiếu chi): K13.</p>'
             '<h2 class="s">Luật chính đã thể hiện</h2><p style="font-size:12px;line-height:1.5;margin:0">Mỗi dòng đơn một lớp một ghi danh; Toán 7+ hai dòng Đại và Hình, nhắc mềm không chặn; đơn đã duyệt khoá; Trình duyệt báo đúng dòng, ô thiếu. Chọn lớp: lớp trùng giờ hiện mờ kèm lý do. Phiếu thu cấn vào dòng, Kế toán duyệt sinh khoản tiền vào và ghi danh; Admin không duyệt (R-HT-01). Khoản tiền vào chỉ đọc, chỉ Kế toán đảo, chặn đảo hai lần. Phiếu chi chỉ từ ticket hoàn tiền đã duyệt.</p>')
    body = '<div style="width:1440px;height:1000px;box-sizing:border-box;padding:28px 40px;background:var(--bg-page);overflow:hidden;display:flex;gap:28px"><div style="flex:0 0 840px">%s</div><div style="flex:1;min-width:0">%s</div></div>' % (left, right)
    return HEAD % 'P5a · Ghi chú' + body + TAIL
if __name__ == '__main__': wr('P5a_Ghi_chu', notes())
