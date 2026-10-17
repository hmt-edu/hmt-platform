# -*- coding: utf-8 -*-
import sys; sys.path.insert(0, 'scripts')
from p5a_common import wr

HEAD = '''<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<title>%s</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/hmt/handoff/hmt-tokens.css">
<link rel="stylesheet" href="ds/hmt/components/bundle.css">
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@600;700&amp;family=Inter:wght@400;500;600;700&amp;display=swap&amp;subset=vietnamese">
<style>
body{margin:0;font-family:var(--font-ui);background:var(--bg-page);color:var(--text-primary)}
a{color:var(--text-link)}a:hover{color:var(--brand-800)}
.t td,.t th{white-space:normal;vertical-align:top;height:auto;padding:5px 8px;font-size:12px;line-height:1.4}.t th{height:26px;white-space:nowrap}
.t.l td:not(:last-child),.t.l th{white-space:nowrap}.t.l td{padding:3px 8px}
h2.s{font-family:var(--font-heading);font-size:15px;margin:16px 0 6px}
</style>
</helmet>
'''
TAIL = '''
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":1440,"height":1000}}'>
class Component extends DCLogic {
  renderVals() { return { yes: true }; }
}
</script>
</body>
</html>
'''
# mã, tên, khuôn, mức, vai trò, nối tới, có trên canvas
SCREENS = [
 ('BH-01', 'Báo giá (danh sách)', 'K03', 'B', 'SA CS BM AD', 'BH-02'), ('BH-02', 'Báo giá (bản ghi)', 'K06', 'A', 'SA CS BM AD', 'BH-03 BH-04 BH-05'),
 ('BH-03', 'Bản in báo giá', 'K13', 'B', 'SA CS AD', 'BH-02'), ('BH-04', 'Từ chối báo giá', 'K08', 'C', 'SA CS BM AD', '— (không vẽ)'),
 ('BH-05', 'Đơn hàng (bản ghi)', 'K06', 'A', 'SA CS BM KT AD', 'BH-07 BH-08 BH-09 TC-03 GD-02'), ('BH-06', 'Đơn hàng (danh sách)', 'K03', 'B', 'SA CS BM KT AD', 'BH-05'),
 ('BH-07', 'Duyệt hoặc từ chối đơn', 'K08', 'B', 'BM AD', '—'), ('BH-08', 'Chọn lớp, ngày vào lớp', 'K08', 'A', 'SA CS AD', '—'),
 ('BH-09', 'Cho học trước, đóng tiền sau', 'K08', 'B', 'BM AD', '—'), ('BH-10', 'Huỷ đơn hàng', 'K08', 'C', 'SA BM AD', 'CS-05 (không vẽ)'), ('BH-11', 'Cơ hội đã có đơn nháp', 'K08', 'C', 'SA CS AD', 'BH-05 (không vẽ)'),
 ('TC-01', 'Phiếu thu (danh sách)', 'K03', 'B', 'SA CS BM KT AD', 'TC-02'), ('TC-02', 'Phiếu thu (bản ghi)', 'K06', 'A', 'SA CS BM KT AD', 'TC-05 TC-06 TC-07'),
 ('TC-03', 'Tạo phiếu thu từ đơn', 'K08', 'B', 'SA CS AD', 'TC-02'), ('TC-04', 'Hàng chờ kế toán duyệt', 'K03', 'B', 'KT AD', 'TC-05'),
 ('TC-05', 'Kế toán duyệt, từ chối phiếu thu', 'K08', 'A', 'KT (AD chỉ xem)', 'TC-08 GD-02'), ('TC-06', 'Huỷ phiếu thu', 'K08', 'C', 'SA CS AD', '— (không vẽ)'),
 ('TC-07', 'Bản in biên nhận', 'K13', 'B', 'SA CS KT AD', 'TC-02'), ('TC-08', 'Khoản tiền vào', 'K03', 'B', 'KT BM AD', 'TC-09'), ('TC-09', 'Đảo khoản tiền', 'K08', 'B', 'KT AD', '—'),
 ('TC-10', 'Phiếu chi (danh sách)', 'K03', 'B', 'KT BM AD', 'TC-11'), ('TC-11', 'Phiếu chi (bản ghi)', 'K06', 'B', 'KT AD', 'TC-12'), ('TC-12', 'Bản in phiếu chi', 'K13', 'C', 'KT AD', '— (không vẽ)'),
 ('TC-13', 'Công nợ', 'K03', 'B', 'KT BM SA CS AD', 'BH-05'), ('TC-14', 'Số dư khách hàng', 'K03', 'C', 'KT BM AD', 'KH-02 (không vẽ)'), ('TC-15', 'Đối soát thu tiền', 'K09', 'B', 'KT AD', 'TC-02'), ('TC-16', 'Dùng số dư cho đơn mới', 'K08', 'C', 'KT CS AD', 'BH-05 (không vẽ)')]
GROUPS = [('A', 'Báo giá → đơn → phiếu thu → ghi danh', 'TS-13, BH-02, BH-05..09, TC-02..05, TC-08, TC-13, GD-01, GD-02', 'Dòng đơn một lớp: gói, lớp, ngày vào, giờ, giá, chiết khấu, giờ tặng; tiền đã vào, còn lại'),
          ('B', 'Quỹ giờ theo ghi danh', 'BH-05, BH-08, GD-02..07, LOP-09, TT-02, CS-05..14, KH-05 (HS-02)', 'Giờ đăng ký, đã học, còn lại, Start/End Date (P5b)'),
          ('C', 'Ticket thực hiện, tiền, giờ', 'CS-01..14, TC-10, TC-11, TC-14, TC-16, BH-10, BH-05', 'Hoàn tiền sinh phiếu chi (CS-05 → TC-11); chuyển phí sinh đơn hoặc số dư'),
          ('G', 'Tái tục', 'GD-07, TT-01..03, BH-02, BH-05, TS-13', 'Phiếu tái tục sinh báo giá, đơn'),
          ('I', 'Hồ sơ phụ huynh, học sinh (P4)', 'KH-02, KH-05, GD-02, BH-05, TC-14, CS-04', 'Nút liên kết có số đếm trỏ về các màn trên'),
          ('D, E, F, H', 'Lớp, buổi, điểm danh, yêu cầu buổi, giáo viên', 'P5b, P5d', 'Không thuộc P5a, chỉ nối qua ghi danh và lớp')]

def overview():
    lv = {'A': 'hmt-tag hmt-tag-success', 'B': 'hmt-tag hmt-tag-info', 'C': 'hmt-tag'}
    rows = ''.join('<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td><span class="%s">%s</span></td><td>%s</td><td>%s</td></tr>' % (c, n, k, lv[l], l, u, t) for c, n, k, l, u, t in SCREENS)
    grows = ''.join('<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td>%s</td></tr>' % g for g in GROUPS)
    left = ('<h1 style="font-family:var(--font-heading);font-size:26px;margin:0 0 4px">P5a · Bán hàng và Thu chi</h1><p class="hmt-help" style="font-size:13px;margin:0 0 10px">Giai đoạn 1, máy tính. 27 mã màn: BH-01..BH-11, TC-01..TC-16. Mức A vẽ đủ trạng thái, B một trạng thái chính (danh sách thêm trống, đang tải, không có quyền), C không vẽ. Hai màn in (BH-03 A4, TC-07 A5) dùng khuôn K13 mới đề xuất, anh đã duyệt 17/10.</p>'
            '<div class="hmt-table-wrap"><table class="hmt-table t l"><thead><tr><th>Mã</th><th>Màn</th><th>Khuôn</th><th>Mức</th><th>Ai dùng</th><th>Nối tới</th></tr></thead><tbody>' + rows + '</tbody></table></div>')
    right = ('<h2 class="s" style="margin-top:0">Vai trò</h2><p class="hmt-help" style="font-size:12px;margin:0">SA Tuyển sinh · CS CSKH · BM Trưởng cơ sở · KT Kế toán · AD Admin. Admin không duyệt phiếu thu, đảo khoản, phiếu chi (R-HT-01): nút Duyệt, Đảo chỉ cho Kế toán.</p>'
             '<h2 class="s">Bản đồ nhóm liên quan (nhóm A–I)</h2><div class="hmt-table-wrap"><table class="hmt-table t"><colgroup><col style="width:46px"><col style="width:130px"><col style="width:170px"><col></colgroup><thead><tr><th>Nhóm</th><th>Tên</th><th>Các màn</th><th>Điều phải khớp</th></tr></thead><tbody>' + grows + '</tbody></table></div>'
             '<h2 class="s">Luồng chính (không có nút Tạo tay ở danh sách, R-TIEN-02)</h2><p style="font-size:12px;line-height:1.6;margin:0">Cơ hội → <b>Báo giá</b> (BH-02) → <b>Đơn hàng</b> (BH-05, quản lý duyệt BH-07 thì khoá) → <b>Phiếu thu</b> (TC-03, TC-02; Kế toán duyệt TC-05) → <b>Khoản tiền vào</b> (TC-08, tự sinh) → <b>Ghi danh</b> (GD-02). Hoàn tiền: ticket CS-05 → <b>Phiếu chi</b> (TC-11).</p>'
             '<h2 class="s">Cách đọc canvas</h2><p style="font-size:12px;line-height:1.6;margin:0">Mỗi hàng là một cụm màn; tên khung = mã màn + trạng thái. Hộp thoại (K08) vẽ nổi trên màn gọi nó. Mọi bản vẽ bấm được: nút mở hộp, tab, trạng thái. Ghi chú lệch khuôn và câu hỏi nằm ở khung cuối canvas.</p>'
             '<div class="hmt-alert hmt-alert-warning" style="margin-top:12px"><span><b>Khuôn mới:</b> K13 (bản in A4/A5) chưa có trong P0; anh đã duyệt 17/10, cần ghi vào P0 v5. Dùng ở BH-03, TC-07 (TC-12 mức C cũng dùng).</span></div>')
    body = '<div style="width:1440px;height:1000px;box-sizing:border-box;padding:32px 40px;background:var(--bg-page);overflow:hidden;display:flex;gap:28px"><div style="flex:0 0 790px">%s</div><div style="flex:1;min-width:0">%s</div></div>' % (left, right)
    return HEAD % 'P5a · Tổng quan' + body + TAIL

if __name__ == '__main__':
    wr('P5a_Tong_quan', overview())
