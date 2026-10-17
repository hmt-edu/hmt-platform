# -*- coding: utf-8 -*-
# P5b cụm Ghi danh: GD-01..GD-07
import sys, re; sys.path.insert(0, 'scripts')
from p5b_common import *

GD_ST = {'Chờ xếp lớp': 'warning', 'Đã xếp lớp': 'info', 'Đang học': 'success', 'Bảo lưu': 'warning', 'Hoàn thành': '', 'Chuyển lớp': '', 'Dừng': 'danger', 'Hoàn phí': 'danger'}
# mã, học sinh, mã HS, gói, hình thức, lớp mã, giờ cấp, đã học, tình trạng, End Date
GDL = [('GD000288', 'Nguyễn Minh Khôi', 'LC-TOAN-K06', 'Offline', 'CS1-2627-TOAN-K06-CB-A-001', 48, 20, 'Đang học', '08/12/2026'),
       ('GD000301', 'Phạm Đức Anh', 'LC-TOAN-K08', 'Offline', 'CS1-2627-DAI-K08-CB-A-001', 24, 0, 'Đã xếp lớp', '29/12/2026'),
       ('GD000302', 'Phạm Đức Anh', 'LC-TOAN-K08', 'Offline', 'CS1-2627-HINH-K08-CB-A-001', 24, 0, 'Đã xếp lớp', '—'),
       ('GD000303', 'Phạm Khánh Vy', 'LC-ANH-K05', 'Offline', 'CS1-2627-ANH-K05-CB-B-002', 0, 0, 'Đã xếp lớp', '—'),
       ('GD000291', 'Mai Anh Tuấn', 'LC-TOAN-K09', 'Offline', '—', 24, 0, 'Chờ xếp lớp', '—'),
       ('GD000289', 'Lê Bảo Nam', 'LC-TOAN-K09', 'Offline', '—', 24, 0, 'Chờ xếp lớp', '—'),
       ('GD000290', 'Lê Bảo Nam', 'LC-TOAN-K09', 'Offline', '—', 24, 0, 'Chờ xếp lớp', '—'),
       ('GD000279', 'Hoàng Gia Bảo', 'LC-ANH-K05', 'Online', 'CS1-2627-ANH-K05-CB-A-001', 24, 9, 'Bảo lưu', '—'),
       ('GD000270', 'Nguyễn Hà My', 'LC-ANH-K03', 'Offline', 'CS1-2627-ANH-K03-CB-A-001', 24, 24, 'Hoàn thành', 'hết giờ'),
       ('GD000262', 'Trần Thị Mai', 'LC-TOAN-K07', 'Offline', 'CS1-2627-DAI-K07-CB-B-002', 24, 6, 'Chuyển lớp', '—'),
       ('GD000250', 'Lê Thu Hà', 'LC-TOAN-K05', 'Offline', 'CS1-2627-TOAN-K05-CB-A-001', 48, 20, 'Hoàn phí', '—')]
def cfg_gd01():
    def conl(g, d): return g - d
    return dict(code='GD-01', h1='Ghi danh', nav='Ghi danh', group=4, crumb=[('Đào tạo', False), ('Ghi danh', True)], ph='Tìm mã ghi danh, học sinh, mã lớp, mã cũ…', noun='ghi danh', total=312, nochk=True,
        heads=[('Mã', 0), ('Học sinh', 0), ('Gói · hình thức', 0), ('Lớp', 0), ('Giờ cấp', 1), ('Đã học', 1), ('Còn lại', 1), ('Tình trạng', 0)],
        rows=[[C(c), L(h), g + ' · ' + ht, ('<span class="hmt-code">%s</span>' % lop) if lop != '—' else '<span class="hmt-help">chưa có lớp</span>', N(hh(cap)), N(hh(d)), N(hh(round(cap - d, 1))), tag(st, GD_ST[st])] for c, h, g, ht, lop, cap, d, st, ed in GDL],
        tfields=[('Mã', 'Mã'), ('Học sinh', 'Học sinh'), ('Lớp', 'Lớp')], favs=[('Chờ xếp lớp', True, "{'Tình trạng':['Chờ xếp lớp']}"), ('Đang học', False, "{'Tình trạng':['Đang học']}")],
        gfields=[('Tình trạng', 'Tình trạng', False), ('Gói', 'Gói · hình thức', False)],
        filters=[('Tình trạng', [(k, k) for k in GD_ST]), ('Hình thức', [('Offline', 'Offline'), ('Online', 'Online')])], link='Mở ghi danh (màn GD-02).',
        toasts="{'Xuất':'Đang xuất danh sách ghi danh ra file.'}", hint='Thử tìm bằng mã ghi danh, tên học sinh hoặc mã lớp (gõ được cả mã cũ).', eicon='book', etitle='Chưa có ghi danh nào',
        esub='Ghi danh tự sinh khi Kế toán duyệt phiếu thu đủ cọc (mỗi dòng đơn một ghi danh). Danh sách này không có nút Tạo (R-TIEN-02).', export=('cs', 'bm', 'kt', 'ad'))

# ---------- GD-04 sổ giờ ----------
SO = [('12/10/2026', 'Cấp từ phiếu thu', 'PT-CS1-2610-0014', 48, 48), ('14/09/2026', 'Trừ buổi', 'Buổi 1 · 14/09', -2, 46), ('16/09/2026', 'Trừ buổi', 'Buổi 2 · 16/09', -2, 44)]
SOL = [('13/10/2026', 'Trừ buổi', 'TOAN-K06-CB-A-001 · Buổi 2 · 13/10', -2, 28), ('08/10/2026', 'Trừ buổi', 'TOAN-K06-CB-B-002 · Buổi 8 · 08/10', -2, 30), ('06/10/2026', 'Trừ buổi', 'TOAN-K06-CB-B-002 · Buổi 7 · 06/10', -2, 32),
       ('01/10/2026', 'Điều chỉnh', 'Điều chỉnh bởi Lê Văn Phong · Lý do: Buổi 5 điểm danh nhầm', 2, 34), ('29/09/2026', 'Trừ buổi', 'TOAN-K06-CB-B-002 · Buổi 5 · 29/09', -2, 32), ('27/09/2026', 'Trừ buổi', 'TOAN-K06-CB-B-002 · Buổi 4 · 27/09', -2, 34),
       ('01/09/2026', 'Cấp từ phiếu thu', 'PT-CS1-2610-0014 · KTV-CS1-2610-0008', 48, 48)]
def cfg_gd04():
    ty = {'Cấp từ phiếu thu': 'success', 'Trừ buổi': '', 'Điều chỉnh': 'warning', 'Chuyển phí': 'info'}
    return dict(code='GD-04', h1='Sổ giờ', nav='Ghi danh', group=4, crumb=[('Đào tạo', False), ('Ghi danh', False), ('GD000288', False), ('Sổ giờ', True)], ph='Tìm theo nguồn: buổi, phiếu thu, ticket…', noun='dòng sổ giờ', total=11, nochk=True,
        heads=[('Ngày', 0), ('Loại', 0), ('Nguồn', 0), ('Giờ +/−', 1), ('Số dư (giờ)', 1)],
        rows=[[N(d), tag(t, ty[t]), '<a href="#">%s</a>' % src, sgn(h), N(hh(sd))] for d, t, src, h, sd in SOL],
        tfields=[('Nguồn', 'Nguồn')], favs=[('Chỉ điều chỉnh', False, "{'Loại':['Điều chỉnh']}")], gfields=[('Loại', 'Loại', False)], filters=[('Loại', [('Cấp từ phiếu thu', 'Cấp từ phiếu thu'), ('Trừ buổi', 'Trừ buổi'), ('Điều chỉnh', 'Điều chỉnh'), ('Chuyển phí', 'Chuyển phí')])],
        link='Mở nguồn của dòng (buổi, phiếu thu hoặc ticket).', toasts="{'Xuất':'Đang xuất sổ giờ ra file.'}", hint='Thử tìm theo mã buổi, mã phiếu thu hoặc mã ticket.', eicon='book', etitle='Chưa có dòng sổ giờ nào',
        esub='Sổ giờ chỉ thêm dòng, không sửa dòng cũ (R-GD-04). Dòng đầu tiên sinh khi phiếu thu được duyệt.', export=('bm', 'kt', 'ad'))

# ---------- GD-06 hàng chờ xếp lớp, GD-07 sắp hết giờ ----------
CHO_LD = {'Chưa có lớp': '', 'Mới xếp một lớp (Toán 7+)': 'info', 'Học trước, chưa đóng tiền': 'warning'}
GD6 = [('GD000289', 'Lê Bảo Nam', 'Toán 9 · Đại số', 'Offline', 'Chưa có lớp', '12/10/2026'), ('GD000290', 'Lê Bảo Nam', 'Toán 9 · Hình học', 'Offline', 'Chưa có lớp', '12/10/2026'),
       ('GD000291', 'Mai Anh Tuấn', 'Toán 9 · Hình học', 'Offline', 'Mới xếp một lớp (Toán 7+)', '13/10/2026'), ('GD000303', 'Phạm Khánh Vy', 'Tiếng Anh 5', 'Offline', 'Học trước, chưa đóng tiền', '12/10/2026'),
       ('GD000296', 'Vũ Hải Nam', 'Tiếng Anh 7', 'Online', 'Chưa có lớp', '15/10/2026'), ('GD000298', 'Đinh Gia Linh', 'Toán 6', 'Offline', 'Chưa có lớp', '16/10/2026')]
def cfg_gd06(dlgs='', show0='', role='cs'):
    return dict(code='GD-06', h1='Hàng chờ xếp lớp', nav='Hàng chờ xếp lớp', group=4, crumb=[('Đào tạo', False), ('Hàng chờ xếp lớp', True)], ph='Tìm mã ghi danh, học sinh…', noun='ghi danh chờ xếp lớp', total=6, nochk=True,
        heads=[('Ghi danh', 0), ('Học sinh', 0), ('Môn', 0), ('Hình thức', 0), ('Lý do chờ', 0), ('Chờ từ', 0), ('Xử lý', 0)],
        rows=[[C(c), L(h), m, ht, tag(ld, CHO_LD[ld]), N(d), '<button class="hmt-btn hmt-btn-primary" type="button" data-open="gd03">Xếp lớp</button>'] for c, h, m, ht, ld, d in GD6],
        tfields=[('Mã', 'Ghi danh'), ('Học sinh', 'Học sinh')], favs=[('Chưa có lớp', True, "{'Lý do chờ':['Chưa có lớp']}")], gfields=[('Lý do chờ', 'Lý do chờ', False), ('Hình thức', 'Hình thức', False)],
        filters=[('Lý do chờ', [(k, k) for k in CHO_LD]), ('Hình thức', [('Offline', 'Offline'), ('Online', 'Online')])], link='Mở ghi danh (màn GD-02).',
        toasts="{'Xuất':'Đang xuất hàng chờ xếp lớp ra file.'}", hint='Thử tìm bằng mã ghi danh hoặc tên học sinh.', eicon='check', etitle='Không có ghi danh nào chờ xếp lớp', esub='Ghi danh chưa có lớp, Toán 7+ mới xếp một lớp, hoặc đang học trước chưa đóng tiền sẽ hiện ở đây.', dlgs=dlgs or d_gd03('nhom'), show0=show0, export=('cs', 'bm', 'ad'))

GD7_ST = {'Sắp hết giờ': 'warning', 'Sắp hết hạn gói': 'warning', 'Quá hạn gói, còn giờ': 'info', 'Hết giờ': 'danger'}
GD7 = [('GD000288', 'Nguyễn Minh Khôi', 'CS1-2627-TOAN-K06-CB-A-001', 28, '08/12/2026', '14/03/2027', 'Sắp hết giờ', 'DN'), ('GD000270', 'Nguyễn Hà My', 'CS1-2627-ANH-K03-CB-A-001', 0, '17/10/2026', '30/11/2026', 'Hết giờ', 'TT000041'),
       ('GD000255', 'Đỗ Quang Huy', 'CS1-2627-ANH-K06-CB-A-002', 3, '27/10/2026', '10/10/2026', 'Quá hạn gói, còn giờ', ''), ('GD000262', 'Trần Thị Mai', 'CS1-2627-DAI-K07-CB-B-002', 4, '03/11/2026', '15/11/2026', 'Sắp hết giờ', 'TT000044'),
       ('GD000301', 'Phạm Đức Anh', 'CS1-2627-DAI-K08-CB-A-001', 24, '29/12/2026', '05/11/2026', 'Sắp hết hạn gói', '')]
def cfg_gd07():
    def act(tt): return (L(tt) if tt.startswith('TT') else '') or '<button class="hmt-btn" type="button" data-do="Tạo phiếu tái tục (màn TT-02).">Tạo phiếu tái tục</button>'
    return dict(code='GD-07', h1='Sắp hết giờ', nav='Sắp hết giờ', group=4, crumb=[('Đào tạo', False), ('Sắp hết giờ', True)], ph='Tìm mã ghi danh, học sinh, lớp…', noun='ghi danh sắp hết giờ', total=18, nochk=True,
        heads=[('Ghi danh', 0), ('Học sinh', 0), ('Lớp', 0), ('Giờ còn', 1), ('Hết giờ dự kiến', 0), ('Hạn gói (dự báo)', 0), ('Tình trạng', 0), ('Phiếu tái tục', 0)],
        rows=[[C(c), L(h), '<span class="hmt-code">%s</span>' % lop, N(hh(g)), N(dk), N(hg), tag(st, GD7_ST[st]), act(tt if tt != 'DN' else '')] for c, h, lop, g, dk, hg, st, tt in GD7],
        tfields=[('Ghi danh', 'Ghi danh'), ('Học sinh', 'Học sinh')], favs=[('Hết giờ', True, "{'Tình trạng':['Hết giờ']}"), ('Sắp hết giờ', False, "{'Tình trạng':['Sắp hết giờ']}")], gfields=[('Tình trạng', 'Tình trạng', False)],
        filters=[('Tình trạng', [(k, k) for k in GD7_ST])], link='Mở ghi danh (màn GD-02).', toasts="{'Xuất':'Đang xuất danh sách sắp hết giờ ra file.'}", hint='Thử tìm bằng mã ghi danh hoặc tên học sinh.', eicon='check', etitle='Chưa có ghi danh nào sắp hết giờ',
        esub='Dự báo theo từng ghi danh (từng lớp). Hạn gói chỉ để dự báo: quá hạn gói mà còn giờ vẫn học (R-GD-07).', export=('cs', 'bm', 'ad'))

# ---------- hộp thoại GD-03, GD-05 ----------
def d_gd03(variant='nhom'):
    ctx = lambda hs, extra: '<div style="display:flex;gap:var(--space-3);flex-wrap:wrap;font-size:13px;margin-bottom:var(--space-3)"><span>%s</span><span class="hmt-tag">Offline</span><span class="hmt-tag">CS1</span>%s</div>' % (hs, extra)
    foot = lambda dis=False: btn('Đóng', '', None, 'data-close="1"') + btn('Xếp lớp', 'primary', None, 'data-dto="Đã xếp lớp. Ghi danh chuyển sang Đã xếp lớp."' + (' disabled' if dis else ''))
    head = '<h2>Xếp lớp cho ghi danh</h2>'
    if variant == 'tai':
        body = SK_CSS + ctx('Ghi danh GD000291', '') + ''.join('<div style="display:flex;gap:10px;padding:10px;border:1px solid var(--divider);border-radius:8px;margin-bottom:6px">' + sk(16, 16, 8) + '<div style="flex:1;display:flex;flex-direction:column;gap:6px">' + sk('50%', 14) + sk('80%', 12) + '</div></div>' for _ in range(3))
        return dialog('gd03', 'Xếp lớp', head, '<div aria-busy="true">' + body + '</div>', foot(True), w=700)
    if variant == 'trong':
        return dialog('gd03', 'Xếp lớp', head, ctx('Ghi danh GD000298 · Đinh Gia Linh · Toán 6', '') + empty_inline('Không có lớp phù hợp', 'Chưa có lớp Toán 6 đã duyệt, còn chỗ ở CS1. Ghi danh vẫn ở Chờ xếp lớp; có thể tạo lớp mới (LOP-03) hoặc xếp sau (R-GD-06).'), btn('Đóng', '', None, 'data-close="1"'), w=700)
    sw = lambda a: ('<div style="display:flex;gap:6px;margin-bottom:var(--space-3)">' + btn('Theo nhóm lớp', 'primary' if a == 'nhom' else '', None, 'data-pane-to="nhom"') + btn('Một lớp lẻ', 'primary' if a == 'le' else '', None, 'data-pane-to="le"') + '</div>')
    dates = lambda ds: ''.join('<label class="hmt-opt" style="display:flex;gap:8px;align-items:center;padding:4px 8px"><input type="radio" name="n%s" %s><span><b>%s</b> · %s <span class="hmt-help">%s</span></span></label>' % (k, 'checked' if i == 0 else '', d, w, b) for i, (k, (d, w, b)) in enumerate(ds))
    if variant == 'nhom':
        grp = ('<label class="hmt-opt" style="display:flex;gap:10px;align-items:flex-start;padding:8px 10px;border:1px solid var(--brand-500,#e8590c);background:var(--brand-50);border-radius:8px;margin-bottom:6px"><input type="radio" name="grp" checked style="margin-top:3px"><span style="flex:1"><b>Nhóm 9M1</b> <span class="hmt-tag hmt-tag-info">luân phiên Đại, Hình</span>'
               '<div class="hmt-help">Đại số 9 cơ bản A <span class="hmt-code">CS1-2627-DAI-K09-CB-A-001</span> · Thứ 3 18:00–19:30, lặp mỗi 2 tuần, buổi đầu 03/11</div><div class="hmt-help">Hình học 9 cơ bản A <span class="hmt-code">CS1-2627-HINH-K09-CB-A-001</span> · Thứ 3 18:00–19:30, lặp mỗi 2 tuần, buổi đầu 10/11</div></span></label>'
               '<div class="hmt-alert hmt-alert-info" role="status" style="margin-bottom:6px">' + SVG(IC['check']) + '<span>Hai lớp cùng thứ, giờ, phòng nhưng <b>luân phiên</b>: không có buổi nào trùng, xếp được cả hai (R-GD-15).</span></div>'
               '<label class="hmt-opt" style="display:flex;gap:10px;padding:8px 10px;border:1px solid var(--divider);border-radius:8px"><input type="radio" name="grp" style="margin-top:3px"><span><b>Nhóm 9M2</b><div class="hmt-help">Đại số 9 cơ bản B · Hình học 9 cơ bản B · Thứ 2, Thứ 4 19:30–21:00</div></span></label>')
        map_ = ('<div style="margin-top:var(--space-3)">' + sec('XẾP VÀO') + table([('Ghi danh', 0), ('Môn', 0), ('Lớp', 0), ('Ngày vào lớp', 0)], [['GD000289', 'Đại số 9', gcode('CS1-2627-DAI-K09-CB-A-001'), '<span class="hmt-num">03/11/2026</span> <span class="hmt-help">Thứ 3, buổi 1</span>'], ['GD000290', 'Hình học 9', gcode('CS1-2627-HINH-K09-CB-A-001'), '<span class="hmt-num">10/11/2026</span> <span class="hmt-help">Thứ 3, buổi 1</span>']], cls='', widths=[88, 90, 280, 190], wrap=True) + '</div>')
        body = ctx('Lê Bảo Nam (Lớp 9) · <b>2 ghi danh</b> GD000289 Đại số, GD000290 Hình học', '<span class="hmt-tag">LC-TOAN-K09</span>') + sw('nhom') + '<div data-pane="nhom">' + sec('NHÓM LỚP PHÙ HỢP (2)') + grp + map_ + '<div class="hmt-help" style="margin-top:6px">Chọn nhóm thì ghi danh Đại vào lớp DAI, ghi danh Hình vào lớp HINH. Học sinh chỉ có một ghi danh thì chỉ xếp lớp tương ứng.</div></div>' + \
               '<div data-pane="le" style="display:none"><div class="hmt-help">Chọn từng ghi danh một lớp: dùng khi học sinh không học theo nhóm.</div></div>'
        return dialog('gd03', 'Xếp lớp', head, body, foot(), w=760)
    # le, trung_gio, nhac_mem
    if variant == 'trung_gio':
        lops = (cls_row('CS1-2627-HINH-K09-CB-B-002', 'Hình học 9 cơ bản B', 'Thứ 2, Thứ 4 19:30–21:00', 'Lê Thu Trang', '9/20', True, None, True) +
                cls_row('CS1-2627-HINH-K09-CB-A-004', 'Hình học 9 cơ bản A', 'Thứ 3 18:00–19:30 · hàng tuần', 'Nguyễn Văn Nam', '11/20', False, 'Trùng buổi 03/11/2026, 18:00–19:30 với lớp CS1-2627-DAI-K09-CB-A-001 mà em đang học (xét theo từng buổi thật).') +
                cls_row('CS1-2627-HINH-K09-NC-S-003', 'Hình học 9 nâng cao', 'Thứ 5 18:30–20:00', 'Trần Minh Đức', '12/15', False, 'Trùng buổi 05/11/2026, 18:30–20:00 với lớp CS1-2627-ANH-K09-CB-A-001 mà em đang học.'))
        hs = 'Phạm Khánh Vy (Lớp 9) · ghi danh GD000305 Hình học'
        al = ''
    elif variant == 'nhac_mem':
        lops = (cls_row('CS1-2627-HINH-K09-CB-A-001', 'Hình học 9 cơ bản A <span class="hmt-tag hmt-tag-info">Nhóm 9M1</span>', 'Thứ 3 18:00–19:30 · lặp mỗi 2 tuần', 'Nguyễn Văn Nam', '12/20', True, None, True) + cls_row('CS1-2627-HINH-K09-CB-B-002', 'Hình học 9 cơ bản B', 'Thứ 2, Thứ 4 19:30–21:00', 'Lê Thu Trang', '9/20'))
        hs = 'Mai Anh Tuấn (Lớp 9) · ghi danh GD000291 Hình học'
        al = '<div class="hmt-alert hmt-alert-info" role="status" style="margin-bottom:var(--space-3)">' + SVG(IC['alert']) + '<span><b>Thường học cả Đại và Hình.</b> Em mới có ghi danh Hình học, chưa có Đại số. Chỉ nhắc, không chặn xếp lớp.</span></div>'
    else:
        lops = (cls_row('CS1-2627-HINH-K09-CB-A-001', 'Hình học 9 cơ bản A', 'Thứ 3 18:00–19:30', 'Nguyễn Văn Nam', '12/20', True, None, True) + cls_row('CS1-2627-HINH-K09-CB-B-002', 'Hình học 9 cơ bản B', 'Thứ 2, Thứ 4 19:30–21:00', 'Lê Thu Trang', '9/20'))
        hs = 'Mai Anh Tuấn (Lớp 9) · ghi danh GD000291 Hình học'; al = ''
    body = ctx(hs, '<span class="hmt-tag">LC-TOAN-K09</span><span class="hmt-tag">Môn Hình học</span>') + al + sw('le') + '<div data-pane="nhom" style="display:none"><div class="hmt-help">Nhóm lớp chỉ có tác dụng khi học sinh có ghi danh cho cả hai môn.</div></div>' + \
           '<div data-pane="le"><div style="display:flex;gap:var(--space-5)"><div style="flex:1 1 56%">' + sec('LỚP PHÙ HỢP (%d)' % (3 if variant == 'trung_gio' else 2)) + lops + '<div class="hmt-help">Chỉ hiện lớp đã duyệt, còn chỗ, đúng môn, loại lớp, cơ sở. Lớp có buổi trùng vẫn hiện nhưng không chọn được (R-GD-15).</div></div>' + \
           '<div style="flex:1 1 44%">' + sec('NGÀY VÀO LỚP') + dates([('a', ('04/11/2026', 'Thứ 4', 'Buổi 5')), ('b', ('09/11/2026', 'Thứ 2', 'Buổi 6')), ('c', ('11/11/2026', 'Thứ 4', 'Buổi 7'))]) + '<div class="hmt-help" style="margin-top:6px">Chọn buổi sắp tới của lớp (R-GD-06).</div></div></div></div>'
    return dialog('gd03', 'Xếp lớp', head, body, foot(variant == 'trung_gio' and False), w=820)

def d_gd05():
    body = ('<dl style="margin:0 0 var(--space-3);display:grid;grid-template-columns:auto 1fr;gap:6px 16px;font-size:13px"><dt class="hmt-help">Ghi danh</dt><dd style="margin:0">GD000288 · Nguyễn Minh Khôi · Toán 6 · quỹ hiện tại <b class="hmt-num">28</b> giờ</dd></dl>'
            '<div style="display:flex;gap:var(--space-4);margin-bottom:var(--space-3)"><label class="hmt-opt" style="display:flex;gap:6px;align-items:center"><input type="radio" name="loai" checked> Cộng giờ</label><label class="hmt-opt" style="display:flex;gap:6px;align-items:center"><input type="radio" name="loai"> Trừ giờ</label></div>'
            '<label class="hmt-field"><span class="hmt-label">Số giờ <span class="hmt-req">*</span></span><input class="hmt-input" style="width:120px;text-align:right" value="2" aria-label="Số giờ"></label>'
            '<label class="hmt-field" style="margin-top:var(--space-3)"><span class="hmt-label">Lý do <span class="hmt-req">*</span></span><textarea class="hmt-textarea" rows="3" placeholder="Nêu rõ vì sao điều chỉnh"></textarea></label>'
            '<div class="hmt-alert hmt-alert-info" role="status" style="margin-top:var(--space-3)">' + SVG(IC['alert']) + '<span>Hệ thống ghi thêm <b>một dòng mới</b> vào sổ giờ (dòng ngược dấu), không sửa dòng cũ. Quỹ sau điều chỉnh: 28 → 30 giờ. Muốn chuyển giờ sang ghi danh khác, tạo ticket Đề nghị nhóm “Chuyển phí” (R-GD-18).</span></div>')
    return dialog('gd05', 'Điều chỉnh giờ', '<h2>Điều chỉnh giờ</h2>', body, btn('Đóng', '', None, 'data-close="1"') + btn('Xác nhận', 'primary', None, 'data-dto="Đã thêm dòng điều chỉnh vào sổ giờ."'), w=560)

# ---------- GD-02 bản ghi ----------
def lt_rows(rows):
    rows = [[r[0].replace('class="hmt-code"', 'class="hmt-code" style="white-space:nowrap;font-size:11px"')] + r[1:] for r in rows]
    return table([('Lớp', 0), ('Ngày vào', 0), ('Ngày rời', 0), ('Giờ đã học tại lớp', 1), ('Tình trạng', 0)], rows, cls='', widths=[260, 92, 92, 110, 100], wrap=True)
G = {
 'dang_hoc': dict(ma='GD000288', hs='Nguyễn Minh Khôi', hsc='HS000123', ph='Trần Thị Hà', phc='PH000045', goi='LC-TOAN-K06', ht='Offline', don='DH-CS1-2610-0011', st='Đang học', cur=2, cap=48, tang=0, hoc=20, start='14/09/2026', end='08/12/2026', het='08/12/2026', hangoi='14/03/2027', ngay='01/09/2026', old='ENR-2609-0212',
        lines=[[gcode('CS1-2627-TOAN-K06-CB-B-002', 'Toán 6 cơ bản B'), N('14/09/2026'), N('12/10/2026'), N('16'), tag('Đã chuyển lớp', '')], [gcode('CS1-2627-TOAN-K06-CB-A-001', 'Toán 6 cơ bản A'), N('13/10/2026'), '<span class="hmt-help">—</span>', N('4'), tag('Đang học', 'success')]], user='bm'),
 'da_xep': dict(ma='GD000301', hs='Phạm Đức Anh', hsc='HS000126', ph=PH_NAME, phc=PH_CODE, goi='LC-TOAN-K08', ht='Offline', don='DH-CS1-2610-0012', st='Đã xếp lớp', cur=1, cap=24, tang=0, hoc=0, start='03/11/2026', end='29/12/2026', het='29/12/2026', hangoi='05/11/2027', ngay='12/10/2026', old='ENR-2610-0301',
        lines=[[gcode('CS1-2627-DAI-K08-CB-A-001', 'Đại số 8 cơ bản A'), N('03/11/2026'), '<span class="hmt-help">—</span>', N('0'), tag('Đã xếp lớp', 'info')]], user='cs'),
 'cho_xep': dict(ma='GD000291', hs='Mai Anh Tuấn', hsc='HS000140', ph='Mai Thị Lan', phc='PH000058', goi='LC-TOAN-K09', ht='Offline', don='DH-CS1-2610-0013', st='Chờ xếp lớp', cur=0, cap=24, tang=0, hoc=0, start='—', end='—', het='—', hangoi='—', ngay='13/10/2026', old='ENR-2610-0291', lines=[], user='cs'),
 'bao_luu': dict(ma='GD000279', hs='Hoàng Gia Bảo', hsc='HS000119', ph='Hoàng Văn Đức', phc='PH000049', goi='LC-ANH-K05', ht='Online', don='DH-CS1-2610-0005', st='Bảo lưu', cur=None, br=('Bảo lưu', 'warning'), cap=24, tang=0, hoc=9, start='01/09/2026', end='—', het='tạm dừng', hangoi='—', ngay='28/08/2026', old='ENR-2608-0179',
        lines=[[gcode('CS1-2627-ANH-K05-CB-A-001', 'Tiếng Anh 5 cơ bản A'), N('01/09/2026'), N('01/10/2026'), N('9'), tag('Bảo lưu', 'warning')]], user='cs'),
 'het_gio': dict(ma='GD000270', hs='Nguyễn Hà My', hsc='HS000108', ph='Nguyễn Văn Long', phc='PH000041', goi='LC-ANH-K03', ht='Offline', don='DH-CS1-2610-0010', st='Đang học', cur=2, cap=24, tang=0, hoc=24, start='01/09/2026', end='17/10/2026', het='17/10/2026', hangoi='30/11/2026', ngay='28/08/2026', old='ENR-2608-0170',
        lines=[[gcode('CS1-2627-ANH-K03-CB-A-001', 'Tiếng Anh 3 cơ bản A'), N('01/09/2026'), '<span class="hmt-help">—</span>', N('24'), tag('Đang học', 'success')]], user='bm'),
 'hoc_truoc': dict(ma='GD000303', hs='Phạm Khánh Vy', hsc='HS000127', ph=PH_NAME, phc=PH_CODE, goi='LC-ANH-K05', ht='Offline', don='DH-CS1-2610-0012', st='Đang học', cur=2, cap=0, tang=0, hoc=3, start='07/11/2026', end='—', het='—', hangoi='—', ngay='12/10/2026', old='ENR-2610-0303',
        lines=[[gcode('CS1-2627-ANH-K05-CB-B-002', 'Tiếng Anh 5 cơ bản B'), N('07/11/2026'), '<span class="hmt-help">—</span>', N('3'), tag('Đang học', 'success')]], user='bm'),
 'hoan_phi': dict(ma='GD000250', hs='Lê Thu Hà', hsc='HS000099', ph='Lê Văn Cường', phc='PH000033', goi='LC-TOAN-K05', ht='Offline', don='DH-CS1-2610-0004', st='Hoàn phí', cur=None, br=('Hoàn phí', 'danger'), cap=48, tang=0, hoc=20, start='01/09/2026', end='—', het='—', hangoi='—', ngay='28/08/2026', old='ENR-2608-0150',
        lines=[[gcode('CS1-2627-TOAN-K05-CB-A-001', 'Toán 5 cơ bản A'), N('01/09/2026'), N('14/10/2026'), N('20'), tag('Đã rời lớp', '')]], user='cs'),
}
def gd_chatter(state):
    ev = {'dang_hoc': [('13/10/2026', [sysmsg('18:00', 'Buổi 2 · Toán 6 cơ bản A Done: trừ 2 giờ khỏi quỹ.')]), ('12/10/2026', [sysmsg('09:30', 'Chuyển lớp từ Toán 6 cơ bản B sang Toán 6 cơ bản A (ticket DN-CS1-2610-0003). Giờ còn lại đi theo ghi danh.')]), ('01/09/2026', [sysmsg('09:00', 'Ghi danh sinh khi phiếu thu PT-CS1-2610-0014 được duyệt. Cấp 48 giờ.')])],
          'da_xep': [('12/10/2026', [sysmsg('15:30', 'Ghi danh sinh khi phiếu thu PT-CS1-2610-0015 được duyệt. Cấp 24 giờ; xếp vào Đại số 8 cơ bản A, vào lớp 03/11/2026.')])],
          'cho_xep': [('13/10/2026', [sysmsg('10:00', 'Ghi danh sinh khi phiếu thu được duyệt. Chưa có lớp: chờ xếp lớp.')])],
          'bao_luu': [('01/10/2026', [sysmsg('14:00', 'Thực hiện bảo lưu 01/10 đến 31/10/2026 (ticket DN-CS1-2610-0002). Giờ giữ nguyên; em ra khỏi danh sách buổi.', chg=('Đang học', 'Bảo lưu'))])],
          'het_gio': [('17/10/2026', [sysmsg('08:00', 'Quỹ giờ về 0. Hệ thống chặn điểm danh trừ giờ vào lớp này (R-GD-18).')])],
          'hoc_truoc': [('12/10/2026', [sysmsg('11:00', 'Bật “Cho học trước, đóng tiền sau” trên đơn DH-CS1-2610-0012: ghi danh tạo sớm, quỹ được âm tối đa 2 buổi.')])],
          'hoan_phi': [('14/10/2026', [sysmsg('16:00', 'Phiếu chi PC-CS1-2610-0001 được duyệt. Ghi danh chuyển sang Hoàn phí.', chg=('Đang học', 'Hoàn phí'))])]}
    return chatter(ev.get(state, []))
def so_gio_tab(g, state):
    rows = {'dang_hoc': SOL[:4], 'da_xep': [('12/10/2026', 'Cấp từ phiếu thu', 'PT-CS1-2610-0015', 24, 24)], 'cho_xep': [('13/10/2026', 'Cấp từ phiếu thu', 'PT-CS1-2610-0020', 24, 24)],
            'bao_luu': [('01/09/2026', 'Cấp từ phiếu thu', 'PT-CS1-2608-0044', 24, 24)], 'het_gio': [('17/10/2026', 'Trừ buổi', 'Buổi 24 · 15/10', -1.5, 0), ('15/10/2026', 'Trừ buổi', 'Buổi 23 · 13/10', -1.5, 1.5)],
            'hoc_truoc': [('15/10/2026', 'Trừ buổi', 'Buổi 2 · 15/10 (học trước)', -1.5, -3), ('13/10/2026', 'Trừ buổi', 'Buổi 1 · 13/10 (học trước)', -1.5, -1.5)], 'hoan_phi': [('14/10/2026', 'Hoàn phí', 'PC-CS1-2610-0001', -28, 0)]}[state]
    ty = {'Cấp từ phiếu thu': 'success', 'Trừ buổi': '', 'Điều chỉnh': 'warning', 'Hoàn phí': 'danger'}
    t = table([('Ngày', 0), ('Loại', 0), ('Nguồn', 0), ('Giờ +/−', 1), ('Số dư (giờ)', 1)], [[N(d), tag(t_, ty[t_]), '<a href="#">%s</a>' % s, sgn(h), N(hh(sd))] for d, t_, s, h, sd in rows], cls='', widths=[110, 150, 320, 110, 110], wrap=True)
    return t + '<div class="hmt-help">Sổ giờ chỉ thêm dòng, không sửa dòng cũ. <a href="#" data-do="Mở sổ giờ đầy đủ (màn GD-04).">Mở sổ giờ đầy đủ</a></div>'
def tk_tab(state):
    rows = {'dang_hoc': [['DN-CS1-2610-0003', 'Chuyển lớp', tag('Đã thực hiện', 'success'), N('12/10/2026')], ['DN-CS1-2610-0004', 'Hoàn tiền', tag('Đã duyệt', 'info'), N('16/10/2026')]], 'bao_luu': [['DN-CS1-2610-0002', 'Bảo lưu', tag('Đã thực hiện', 'success'), N('01/10/2026')]], 'hoan_phi': [['DN-CS1-2610-0001', 'Hoàn tiền', tag('Đã thực hiện', 'success'), N('13/10/2026')]]}.get(state)
    if not rows: return '<div class="hmt-help">Chưa có ticket nào liên quan. Bấm <b>Tạo ticket</b> để lập đề nghị (bảo lưu, dừng học, chuyển lớp, chuyển phí, hoàn tiền).</div>'
    return table([('Ticket', 0), ('Nhóm đề nghị', 0), ('Tình trạng', 0), ('Ngày', 0)], [[L(a), b, c, d] for a, b, c, d in rows], cls='', widths=[160, 160, 140, 110], wrap=True)
def build_gd(state, show0='', title_over=None, dlg='gd03'):
    T = {'dang_hoc': 'Đang học (quỹ giờ, chuyển lớp)', 'da_xep': 'Đã xếp lớp, chưa có buổi Done', 'cho_xep': 'Chờ xếp lớp', 'bao_luu': 'Bảo lưu', 'het_gio': 'Hết giờ (chặn điểm danh trừ giờ)', 'hoc_truoc': 'Học trước, quỹ âm trong hạn mức', 'hoan_phi': 'Hoàn phí (chỉ đọc)', 'tai': 'Đang tải', 'quyen': 'Không có quyền'}[state]
    title = title_over or 'GD-02 · Ghi danh · ' + T
    crumb = [('Đào tạo', False), ('Ghi danh', False), ('GD000288' if state in ('tai',) else G.get(state, G['dang_hoc'])['ma'], True)]
    if state == 'quyen': return noperm_page(title, 'ghi danh')
    if state == 'tai': return loading_page(title, 'Ghi danh', 'cs', crumb[:2] + [('Đang tải…', True)], 'Ghi danh')
    g = G[state]; u = g['user']
    stg = stage(['Chờ xếp lớp', 'Đã xếp lớp', 'Đang học', 'Hoàn thành'], g['cur'], branches=[g['br']] if g.get('br') else None, note='bảo lưu, dừng học, hoàn phí thao tác ở cấp ghi danh' if state == 'bao_luu' else None)
    if state == 'hoan_phi': stg = stage(['Chờ xếp lớp', 'Đã xếp lớp', 'Đang học', 'Hoàn thành'], 2, branches=[('Hoàn phí', 'danger')], note='đã hoàn phí, chỉ còn xem')
    con = round(g['cap'] + g['tang'] - g['hoc'], 1)
    stt = tag(g['st'], GD_ST[g['st']])
    head = kgrid([('Học sinh', link('%s · %s' % (g['hs'], g['hsc']), 'Mở hồ sơ học sinh (màn KH-05).')), ('Phụ huynh', link('%s · %s' % (g['ph'], g['phc']), 'Mở phụ huynh (màn KH-02).')), ('Gói · hình thức', '%s · %s' % (g['goi'], g['ht'])), ('Đơn hàng', link(g['don'], 'Mở đơn hàng (màn BH-05).')),
                  ('Tình trạng', stt), ('Cơ sở', 'CS1 Nguyễn Chí Thanh'), ('Ngày ghi danh', numc(g['ngay'])), ('Start Date', numc(g['start'])), ('End Date (dự kiến, chỉ dự báo)', numc(g['end'])), ('Hạn gói (chỉ dự báo)', numc(g['hangoi']))])
    al = ''
    if state == 'het_gio': al = alert('danger', '<b>Quỹ giờ bằng 0.</b> Hết phí ở lớp này: học sinh không được điểm danh trừ giờ, hệ thống chặn, không cho âm (R-GD-18). Muốn học tiếp: lập phiếu tái tục, hoặc chuyển giờ từ ghi danh khác qua ticket “Chuyển phí”.')
    if state == 'hoc_truoc': al = alert('warning', '<b>Đang học trước, chưa đóng tiền.</b> Quỹ giờ được âm tối đa 2 buổi (3 giờ), hiện −3 giờ. Quá hạn mức thì em bị loại khỏi danh sách các buổi sau, kèm cảnh báo cho vận hành và sale (R-GD-12).')
    if state == 'cho_xep': al = alert('info', '<b>Chưa có lớp.</b> Bấm Xếp lớp để chọn lớp và ngày vào lớp. Em mới có ghi danh Hình học, chưa có Đại số: chỉ nhắc, không chặn.', 'alert')
    if state == 'bao_luu': al = alert('warning', 'Đang bảo lưu 01/10 đến 31/10/2026. Giờ còn lại giữ nguyên, em ra khỏi danh sách các buổi trong thời gian này (R-GD-09).', 'lock')
    if state == 'hoan_phi': al = alert('info', 'Ghi danh đã hoàn phí theo phiếu chi PC-CS1-2610-0001. Không sửa được nữa.', 'lock')
    if state == 'da_xep': al = alert('info', 'Ghi danh sinh từ dòng 1 của đơn %s. Chuyển sang Đang học khi buổi Done đầu tiên diễn ra (R-GD-05).' % g['don'], 'check')
    cards = count4([('Giờ cấp', '<b class="hmt-num">%s</b>' % hh(g['cap']), False), ('Giờ tặng', '<b class="hmt-num">%s</b>' % hh(g['tang']), False), ('Đã học', '<b class="hmt-num">%s</b>' % hh(g['hoc']), False), ('Còn lại', '<b class="hmt-num"%s>%s</b>' % (' style="color:var(--danger-text)"' if con <= 0 else '', ('−' if con < 0 else '') + hh(abs(con)) + ' giờ'), True)])
    dkien = '<div class="hmt-help">Ngày hết giờ dự kiến %s: cộng lịch của lớp đang học, chỉ để dự báo, không chặn gì.</div>' % (g['het'] if g['het'] not in ('—',) else 'chưa có (chưa có lớp)')
    ltable = lt_rows(g['lines']) if g['lines'] else '<div class="hmt-help">Chưa có dòng xếp lớp. Bấm <b>Xếp lớp</b> để chọn lớp và ngày vào lớp.</div>'
    p1 = al + cards + sec('LỚP ĐANG HỌC VÀ LỊCH SỬ CHUYỂN LỚP (dòng xếp lớp)') + ltable + dkien
    sh = sheet2('Ghi danh <span class="hmt-code">%s</span> <span class="hmt-help">mã cũ %s</span>' % (g['ma'], g['old']), head, [('Quỹ giờ và lớp', p1), ('Sổ giờ', so_gio_tab(g, state)), ('Ticket liên quan', tk_tab(state))])
    BT = {'dang_hoc': [btn('Điều chỉnh giờ', '', 'refresh', 'data-open="gd05"'), btn('Tạo ticket', '', 'ticket', 'data-do="Mở biểu mẫu tạo ticket cho ghi danh này (màn CS-04)."')],
          'da_xep': [btn('Tạo ticket', '', 'ticket', 'data-do="Mở biểu mẫu tạo ticket (màn CS-04)."')], 'cho_xep': [btn('Xếp lớp', 'primary', 'users', 'data-open="gd03"'), btn('Tạo ticket', '', 'ticket', 'data-do="Mở biểu mẫu tạo ticket (màn CS-04)."')],
          'bao_luu': [btn('Tạo ticket', '', 'ticket', 'data-do="Mở biểu mẫu tạo ticket (màn CS-04)."')], 'het_gio': [btn('Tạo phiếu tái tục', 'primary', 'doc', 'data-do="Tạo phiếu tái tục cho ghi danh này (màn TT-02)."'), btn('Điều chỉnh giờ', '', 'refresh', 'data-open="gd05"'), btn('Tạo ticket', '', 'ticket', 'data-do="Mở biểu mẫu tạo ticket (màn CS-04)."')],
          'hoc_truoc': [btn('Điều chỉnh giờ', '', 'refresh', 'data-open="gd05"'), btn('Tạo ticket', '', 'ticket', 'data-do="Mở biểu mẫu tạo ticket (màn CS-04)."')], 'hoan_phi': []}[state]
    smt = smart([('Học sinh', 1), ('Đơn hàng', 1), ('Ticket', len(re.findall('<tr>', tk_tab(state))) - 1 if '<tr>' in tk_tab(state) else 0)])
    dlgs = d_gd03('nhac_mem' if state == 'cho_xep' else 'le') + d_gd05()
    return page(title, 'Ghi danh', u, crumb, rbar_l('Ghi danh', BT), smt + stg + sh, gd_chatter(state), pager='12 / 312', dlgs=dlgs, show0=show0, group=4)

def run():
    out = []
    out += run_list(cfg_gd01(), 'GD01', 'cs')
    for st in ('dang_hoc', 'da_xep', 'cho_xep', 'bao_luu', 'het_gio', 'hoc_truoc', 'hoan_phi', 'tai', 'quyen'):
        wr('GD02_' + st, build_gd(st)); out.append('GD02_' + st)
    for v, lab in (('nhom', 'Xếp theo nhóm lớp (luân phiên Đại, Hình)'), ('le', 'Xếp một lớp lẻ'), ('trung_gio', 'Lớp trùng buổi: hiện mờ kèm lý do'), ('nhac_mem', 'Nhắc mềm: mới có ghi danh Hình'), ('trong', 'Không có lớp phù hợp'), ('tai', 'Đang tải')):
        c = cfg_gd06(d_gd03(v), 'gd03'); t = PL.build_list(c, 'normal', 'cs').replace('<title>GD-06 · Hàng chờ xếp lớp · danh sách</title>', '<title>GD-03 · Xếp lớp cho ghi danh · %s</title>' % lab)
        wr('GD03_' + v, t); out.append('GD03_' + v)
    c = cfg_gd04(); out += run_list(c, 'GD04', 'bm')
    wr('GD05_dieu_chinh', build_gd('dang_hoc', show0='gd05', title_over='GD-05 · Điều chỉnh giờ (dòng ngược dấu, bắt buộc lý do)')); out.append('GD05_dieu_chinh')
    out += run_list(cfg_gd06(), 'GD06', 'cs')
    out += run_list(cfg_gd07(), 'GD07', 'cs')
    return out
if __name__ == '__main__': print(' '.join(run()))
