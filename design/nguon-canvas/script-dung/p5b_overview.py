# -*- coding: utf-8 -*-
import sys; sys.path.insert(0, 'scripts')
import p5a_common as CM; CM.OUTD = 'p5b/project/'
from p5a_common import wr
import p5a_overview as O
HEAD, TAIL = O.HEAD, O.TAIL
S = [('GD-01', 'Ghi danh (danh sách)', 'K03', 'B', 'CS BM KT AD', 'GD-02'), ('GD-02', 'Ghi danh (bản ghi)', 'K06', 'A', 'CS BM KT AD', 'GD-03 GD-04 GD-05 BH-05 KH-05'), ('GD-03', 'Xếp lớp (hộp thoại)', 'K08', 'A', 'CS BM AD', 'LOP-02 LOP-04'),
 ('GD-04', 'Sổ giờ', 'K03', 'B', 'BM KT AD', 'BUOI-02 TC-02'), ('GD-05', 'Điều chỉnh giờ (hộp thoại)', 'K08', 'B', 'BM AD', 'GD-04'), ('GD-06', 'Hàng chờ xếp lớp', 'K03', 'B', 'CS BM AD', 'GD-03'), ('GD-07', 'Sắp hết giờ', 'K03', 'B', 'CS BM AD', 'TT-02'),
 ('LOP-01', 'Lớp (danh sách, kanban)', 'K03, K04', 'B', 'BM AD CS', 'LOP-02'), ('LOP-02', 'Lớp (bản ghi)', 'K06', 'A', 'BM AD', 'LOP-03..07'), ('LOP-03', 'Tạo lớp', 'K07', 'B', 'BM AD', 'LOP-04'), ('LOP-04', 'Thời khoá biểu lớp', 'K07', 'A', 'BM AD', 'LOP-08'),
 ('LOP-05..07', 'Trình, xác nhận, duyệt lớp', 'K08', 'B', 'BM AD', 'LOP-02'), ('LOP-08', 'Lịch tuần cơ sở', 'K05', 'A', 'BM CS AD', 'BUOI-02'), ('LOP-09', 'Danh sách học sinh của lớp', 'K03', 'C', 'BM CS AD', 'GD-02'), ('LOP-10', 'Đóng lớp, huỷ lớp', 'K08', 'B', 'BM AD', 'LOP-02'),
 ('BUOI-01..14', 'Buổi học, huỷ buổi, học bù, củng cố, bổ trợ, điểm danh', 'K03 K06 K08 K12', 'A/B/C', 'BM CS GV AD', 'LOP-02 GD-04'),
 ('TT-01..03', 'Tái tục: danh sách, kanban, bản ghi', 'K03 K04 K06', 'B/C', 'CS BM AD', 'GD-07')]
def overview(done=''):
    lv = {'A': 'hmt-tag hmt-tag-success', 'B': 'hmt-tag hmt-tag-info', 'C': 'hmt-tag', 'A/B/C': 'hmt-tag', 'B/C': 'hmt-tag'}
    rows = ''.join('<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td><span class="%s">%s</span></td><td>%s</td><td>%s</td></tr>' % (c, n, k, lv[l], l, u, t) for c, n, k, l, u, t in S)
    left = ('<h1 style="font-family:var(--font-heading);font-size:26px;margin:0 0 4px">P5b · Đào tạo</h1><p class="hmt-help" style="font-size:13px;margin:0 0 10px">Giai đoạn 2, máy tính, vài màn cả điện thoại. Mã màn: GD-01..07, LOP-01..10, BUOI-01..14, TT-01..03. Mức A đủ trạng thái, B một trạng thái chính (danh sách thêm trống, đang tải, không có quyền), C không vẽ. ' + done + '</p>'
            '<div class="hmt-table-wrap"><table class="hmt-table t l"><thead><tr><th>Mã</th><th>Màn</th><th>Khuôn</th><th>Mức</th><th>Ai dùng</th><th>Nối tới</th></tr></thead><tbody>' + rows + '</tbody></table></div>')
    right = ('<h2 class="s" style="margin-top:0">Luật chính thể hiện</h2><p style="font-size:12px;line-height:1.6;margin:0">Một ghi danh = một lớp = một quỹ giờ. Toán lớp 7 trở lên là hai lớp độc lập Đại và Hình, nối bằng “nhóm lớp” (không có mã riêng, có thể có tên chung như 9M1). Lớp duyệt cần thời khoá biểu và tự sinh buổi. Trùng giờ xét theo buổi thật: lớp luân phiên không báo trùng. Sổ giờ chỉ thêm dòng; điều chỉnh bằng dòng ngược dấu kèm lý do. Hết giờ thì chặn điểm danh trừ giờ, trừ “cho học trước”. End Date và hạn gói chỉ để dự báo.</p>'
             '<h2 class="s">Bản đồ nhóm liên quan (A–I)</h2><p style="font-size:12px;line-height:1.6;margin:0">Nhóm D lớp (LOP-01..10) · E buổi, điểm danh (BUOI) · F yêu cầu buổi (BUOI-07..10) · H giáo viên · I hồ sơ phụ huynh, học sinh, đơn hàng (KH-02, KH-05, BH-05). Sửa một màn trong nhóm thì em liệt kê các màn cùng nhóm và hỏi anh trước.</p>'
             '<h2 class="s">Vai trò</h2><p class="hmt-help" style="font-size:12px;margin:0">CS CSKH · BM Trưởng cơ sở · KT Kế toán · GV Giáo viên · AD Admin. Menu con của Đào tạo là em đề xuất (P0 chưa có mục cấp 2).</p>'
             '<h2 class="s">Cách đọc canvas</h2><p style="font-size:12px;line-height:1.6;margin:0">Mỗi hàng là một cụm; tên khung = mã màn + trạng thái. Hộp thoại (K08) nổi trên màn gọi nó. Mọi bản vẽ bấm được. Chỗ lệch khuôn và câu hỏi ở khung cuối canvas.</p>')
    body = '<div style="width:1440px;height:1000px;box-sizing:border-box;padding:32px 40px;background:var(--bg-page);overflow:hidden;display:flex;gap:28px"><div style="flex:0 0 790px">%s</div><div style="flex:1;min-width:0">%s</div></div>' % (left, right)
    return HEAD % 'P5b · Tổng quan' + body + TAIL
if __name__ == '__main__': wr('P5b_Tong_quan', overview())
