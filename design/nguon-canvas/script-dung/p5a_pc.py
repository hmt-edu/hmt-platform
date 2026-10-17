# -*- coding: utf-8 -*-
# P5a cụm 3: Phiếu chi (TC-10, TC-11), Công nợ (TC-13)
import sys, re; sys.path.insert(0, 'scripts')
from p5a_common import *
from p5a_list import *
import p5a_list as PL

PC = dict(code='PC-CS1-2610-0003', dh='DH-CS1-2610-0011', ph='Trần Thị Hà', hs='Nguyễn Minh Khôi', tk='DN-CS1-2610-0004', gd='GD000288', hoan=4593600)
PC_ST = {'Nháp': '', 'Đã trình': 'info', 'Đã duyệt': 'success', 'Từ chối': 'danger', 'Huỷ': 'danger'}
PCL = [('PC-CS1-2610-0003', 'DN-CS1-2610-0004', 'Trần Thị Hà', 4593600, 'Chuyển khoản', '17/10/2026', 'CS1', 'Đã trình'), ('PC-CS1-2610-0002', 'DN-CS1-2610-0002', 'Hoàng Văn Đức', 3168000, 'Chuyển khoản', '14/10/2026', 'CS1', 'Đã duyệt'),
       ('PC-CS2-2610-0002', 'DN-CS2-2610-0003', 'Đỗ Ngọc Bích', 1980000, 'Tiền mặt', '16/10/2026', 'CS2', 'Nháp'), ('PC-CS5-2610-0001', 'DN-CS5-2610-0001', 'Vũ Thị Mai', 5702400, 'Chuyển khoản', '12/10/2026', 'CS5', 'Đã duyệt'),
       ('PC-CS4-2610-0001', 'DN-CS4-2610-0002', 'Bùi Thanh Thuỷ', 2217600, 'Chuyển khoản', '13/10/2026', 'CS4', 'Từ chối'), ('PC-CS1-2610-0001', 'DN-CS1-2610-0001', 'Nguyễn Văn Long', 1584000, 'Tiền mặt', '09/10/2026', 'CS1', 'Huỷ')]
def cfg_pc():
    return dict(code='TC-10', h1='Phiếu chi', nav='Phiếu chi', crumb=[('Bán hàng &amp; thu chi', False), ('Phiếu chi', True)], ph='Tìm mã phiếu chi, ticket hoàn tiền, phụ huynh…', noun='phiếu chi', total=37, nochk=True,
        heads=[('Mã', 0), ('Ticket hoàn tiền', 0), ('Phụ huynh', 0), ('Số tiền hoàn (đ)', 1), ('Hình thức', 0), ('Ngày lập', 0), ('Cơ sở', 0), ('Tình trạng', 0)],
        rows=[[C(c), L(t), L(p), M(n), h, N(d), cs, tag(st, PC_ST[st])] for c, t, p, n, h, d, cs, st in PCL],
        tfields=[('Mã', 'Mã'), ('Phụ huynh', 'Phụ huynh'), ('Ticket hoàn tiền', 'Ticket hoàn tiền')], favs=[('Phiếu chi chờ duyệt', True, "{'Tình trạng':['Đã trình']}"), ('Phiếu chi nháp', False, "{'Tình trạng':['Nháp']}")],
        gfields=[('Tình trạng', 'Tình trạng', False), ('Cơ sở', 'Cơ sở', False), ('Hình thức', 'Hình thức', False)],
        filters=[('Tình trạng', [(k, k) for k in PC_ST]), ('Hình thức', [('Chuyển khoản', 'Chuyển khoản'), ('Tiền mặt', 'Tiền mặt')]), ('Cơ sở', [(x, x) for x in ('CS1', 'CS2', 'CS4', 'CS5')])], link='Mở phiếu chi (màn TC-11).',
        toasts="{'Xuất':'Đang xuất danh sách phiếu chi ra file.'}", hint='Thử tìm bằng mã phiếu chi, mã ticket hoàn tiền hoặc tên phụ huynh.', eicon='wallet', etitle='Chưa có phiếu chi nào',
        esub='Phiếu chi chỉ lập từ ticket hoàn tiền đã duyệt (nút Thực hiện ở màn Ticket, CS-05). Danh sách này không có nút Tạo (R-TIEN-28).', export=('kt', 'bm', 'ad'))

def calc_table():
    rows = [['Phụ huynh đã đóng cho ghi danh', numc(num(9504000)), '48 giờ × 220.000 đ = 10.560.000 đ, chiết khấu 10% = 9.504.000 đ (KTV-CS1-2610-0008)'],
            ['Giờ đã học × giá gốc', numc(num(4400000)), '20 giờ × 220.000 đ, giá gốc, <b>không</b> chiết khấu'],
            ['Còn lại sau khi trừ giờ đã học', numc(num(5104000)), '9.504.000 − 4.400.000'],
            ['Phí xử lý (10%)', numc('−' + num(510400)), '10% của 5.104.000'],
            ['<b>Số tiền hoàn</b>', '<b class="hmt-num">%s</b>' % num(PC['hoan']), '5.104.000 − 510.400']]
    h = table([('Khoản', 0), ('Số tiền (đ)', 1), ('Cách tính', 0)], rows, widths=[250, 130, 380], wrap=True)
    return h + '<div class="hmt-help">Giờ tặng (nếu có) không hoàn tiền. Sau khi chi, ghi danh chuyển sang Hoàn phí.</div>'

def pc_fields():
    return kgrid([('Số tiền hoàn (tự tính, khoá)', '<b class="hmt-num">%s</b>' % money(PC['hoan'])), ('Hình thức chi', 'Chuyển khoản'), ('Tài khoản nhận', 'Techcombank …5544'), ('Ngày chi dự kiến', numc('17/10/2026'))])

def build_pc(state):
    T = {'main': 'Đã trình (Kế toán)', 'tai': 'Đang tải', 'quyen': 'Không có quyền'}[state]
    title = 'TC-11 · Phiếu chi · ' + T
    crumb = [('Bán hàng &amp; thu chi', False), ('Phiếu chi', False), (PC['code'], True)]
    if state == 'quyen': return noperm_page(title, 'phiếu chi')
    if state == 'tai': return loading_page(title, 'Phiếu chi', 'kt', crumb[:2] + [('Đang tải…', True)], 'Phiếu chi')
    stg = stage(['Nháp', 'Đã trình', 'Đã duyệt'], 1)
    head = kgrid([('Ticket hoàn tiền', link(PC['tk'], 'Mở ticket hoàn tiền (màn CS-05).')), ('Đơn hàng', link(PC['dh'], 'Mở đơn hàng (màn BH-05).')), ('Phụ huynh', link(PC['ph'] + ' · PH000052', 'Mở phụ huynh (màn KH-02).')),
                  ('Ghi danh hoàn phí', link(PC['gd'], 'Mở ghi danh (màn GD-02).')), ('Tình trạng', tag('Đã trình', 'info')), ('Người lập · cơ sở', 'Trần Thu Hà · CS1')])
    al = '<div class="hmt-help">Sinh từ ticket hoàn tiền đã duyệt, không tạo tay (R-TIEN-28). Số tiền hoàn tự tính theo bảng dưới, không sửa tay.</div>'
    p1 = al + pc_fields()
    p2 = calc_table()
    sh = sheet2('Phiếu chi <span class="hmt-code">%s</span>' % PC['code'], head, [('Thông tin phiếu và bảng tính hoàn', p1 + p2)])
    bt = [btn('Duyệt', 'primary', 'check', 'data-do="Đã duyệt phiếu chi, sinh khoản chi và chuyển ghi danh sang Hoàn phí."'), btn('Từ chối', '', 'ban', 'data-do="Mở hộp Từ chối có lý do."'), btn('In', '', 'printer', 'data-do="Mở bản in phiếu chi (chưa vẽ: chờ khuôn K13)."')]
    d = [('16/10/2026', [sysmsg('14:10', 'Ticket hoàn tiền %s đã duyệt (Trưởng cơ sở).' % PC['tk'])]), ('17/10/2026', [sysmsg('09:00', 'Phiếu chi nháp tự lập từ ticket %s. Số tiền hoàn 4.593.600 đ.' % PC['tk']), sysmsg('09:15', 'Trình kế toán duyệt.', chg=('Nháp', 'Đã trình'))])]
    smt = smart([('Ticket', 1), ('Đơn hàng', 1), ('Ghi danh', 1)])
    return page(title, 'Phiếu chi', 'kt', crumb, rbar_l('Phiếu chi', bt), smt + stg + sh, chatter(d), pager='3 / 37')

# ---------------- TC-13 Công nợ ----------------
CN_ST = {'Chưa đến hạn': '', 'Sắp đến hạn': 'warning', 'Quá hạn': 'danger'}
CNL = [('DH-CS2-2610-0008', 'Đỗ Ngọc Bích', 'CS2', 'Hoàng Mai Anh', 'Đợt 1/2', '03/10/2026', 7128000, 2000000, 'Quá hạn'), ('DH-CS5-2610-0006', 'Vũ Thị Mai', 'CS5', 'Lê Thanh Hà', 'Đợt 1/3', '12/10/2026', 3801600, 0, 'Quá hạn'),
       ('DH-CS5-2610-0003', 'Ngô Hồng Nhung', 'CS5', 'Lê Thanh Hà', 'Đợt 1/2', '18/10/2026', 1980000, 1000000, 'Sắp đến hạn'), ('DH-CS2-2610-0008', 'Đỗ Ngọc Bích', 'CS2', 'Hoàng Mai Anh', 'Đợt 2/2', '02/11/2026', 7128000, 0, 'Chưa đến hạn'),
       ('DH-CS1-2610-0012', 'Phạm Thu Hương', 'CS1', 'Trần Thu Hà', 'Đợt 2/2', '09/11/2026', 6804000, 196000, 'Chưa đến hạn'), ('DH-CS5-2610-0006', 'Vũ Thị Mai', 'CS5', 'Lê Thanh Hà', 'Đợt 2/3', '11/11/2026', 2851200, 0, 'Chưa đến hạn')]
def cfg_cn():
    day = {'Quá hạn': lambda d: {'03/10/2026': 14, '12/10/2026': 5}[d]}
    def stc(st, d):
        if st == 'Quá hạn': return tag('Quá hạn %d ngày' % day['Quá hạn'](d), 'danger')
        return tag(st, CN_ST[st])
    return dict(code='TC-13', h1='Công nợ', nav='Công nợ', crumb=[('Bán hàng &amp; thu chi', False), ('Công nợ', True)], ph='Tìm mã đơn hàng, phụ huynh…', noun='khoản công nợ', total=29, nochk=True,
        heads=[('Đơn hàng', 0), ('Phụ huynh', 0), ('Cơ sở', 0), ('Sale', 0), ('Đợt', 0), ('Hạn đóng', 0), ('Phải đóng (đ)', 1), ('Đã đóng (đ)', 1), ('Còn nợ (đ)', 1), ('Tình trạng', 0)],
        rows=[[L(d), L(p), cs, sa, dot, N(h), M(t), M(da), M(t - da), stc(st, h)] for d, p, cs, sa, dot, h, t, da, st in CNL],
        tfields=[('Đơn hàng', 'Đơn hàng'), ('Phụ huynh', 'Phụ huynh')], favs=[('Quá hạn', True, "{'Tình trạng':['Quá hạn']}"), ('Sắp đến hạn 7 ngày', False, "{'Tình trạng':['Sắp đến hạn']}")],
        gfields=[('Cơ sở', 'Cơ sở', False), ('Sale', 'Sale', False), ('Tình trạng', 'Tình trạng', False)], pcol='Đơn hàng',
        filters=[('Tình trạng', [('Chưa đến hạn', 'Chưa đến hạn'), ('Sắp đến hạn', 'Sắp đến hạn'), ('Quá hạn', 'Quá hạn')]), ('Cơ sở', [(x, x) for x in ('CS1', 'CS2', 'CS4', 'CS5')]), ('Sale', [(x, x) for x in ('Trần Thu Hà', 'Hoàng Mai Anh', 'Lê Thanh Hà', 'Vũ Đức Minh')])], link='Mở đơn hàng (màn BH-05).',
        toasts="{'Xuất':'Đang xuất danh sách công nợ ra file.'}", hint='Thử tìm bằng mã đơn hàng hoặc tên phụ huynh.', eicon='wallet', etitle='Không có công nợ nào',
        esub='Công nợ đọc từ lịch đợt tự tính theo Điều khoản thanh toán của đơn đã duyệt (BH-05). Đợt nào đóng đủ thì biến khỏi danh sách.', export=('kt', 'bm', 'ad'))

def run():
    out = []
    out += PL.run_list(cfg_pc(), 'TC10', 'kt')
    for s in ('main', 'tai', 'quyen'):
        n = 'TC11' + {'main': '', 'tai': '_tai', 'quyen': '_khong_quyen'}[s]; wr(n, build_pc(s)); out.append(n)
    out += PL.run_list(cfg_cn(), 'TC13', 'kt')
    return out
if __name__ == '__main__': print(' '.join(run()))
