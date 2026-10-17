# -*- coding: utf-8 -*-
# P5a cụm 2: Phiếu thu (TC-01..TC-05, TC-08, TC-09, TC-15)
import sys, re; sys.path.insert(0, 'scripts')
from p5a_common import *
from kh_common import SK_CSS, sk, empty_box
import p5a_dh as D
from p5a_dh import DH, L1, L2, L3, lt, tot, chia, hh, empty_inline
from p5a_bh import PH_NAME, PH_CODE
from p5a_list import *
import p5a_list as PL

PT = dict(code='PT-CS1-2610-0015', old='RCP-2610-0052', dh=DH['code'], tien=7000000, ht='Chuyển khoản', ngay='12/10/2026', tk='Vietcombank · 0011 0012 3456 (HMT CS1)', gd='FT26285123456', anh='chung_tu_ck_1210.jpg', ktv='KTV-CS1-2610-0009')
LINES = [L1, L2, L3]

def chia_table(paid, can, note='', actual=False):
    ch = chia(paid, can)
    rows = []
    for i, l in enumerate(LINES):
        t, g = ch[i]
        rows.append(['<b>Dòng %d</b> · %s<div class="hmt-help">%s</div>' % (i + 1, l[0], l[5].split(' · ')[0]), '<span class="hmt-num">%s</span>' % num(lt(l)),
                     '<span class="hmt-num">%s</span>' % num(t) + (' ' + tag('Cấn', 'info') if can == i else ''), '<span class="hmt-num">%s</span>' % hh(g) + ('<span class="hmt-help"> / %d giờ</span>' % l[7])])
    h = table([('Dòng đơn', 0), ('Thành tiền (đ)', 1), ('Tiền chia về dòng (đ)', 1), ('Giờ cấp', 1)], rows, cls='', widths=[260, 130, 170, 120], wrap=True)
    return h + '<div class="hmt-help">%s</div>' % (note or 'Tiền cấn vào dòng được chọn trước, tối đa bằng thành tiền dòng; phần thừa chia tỉ lệ cho các dòng khác (R-TIEN-23). Giờ cấp = giờ dòng × tiền chia ÷ thành tiền dòng (R-TIEN-21). Giờ tặng chỉ cấp khi đơn thu đủ (R-TIEN-24).')

def anh_box(locked=True):
    return ('<div style="display:flex;gap:10px;align-items:center"><span style="width:88px;height:60px;border:1px solid var(--divider);border-radius:6px;background:var(--bg-subtle);display:flex;align-items:center;justify-content:center;color:var(--text-secondary)">%s</span>'
            '<span><a href="#" data-do="Mở ảnh chứng từ.">%s</a><div class="hmt-help">1,2 MB · tải lên 12/10/2026</div></span>%s</div>') % (SVG(IC['file'], 'hmt-ic hmt-ic-lg'), PT['anh'], '' if locked else btn('Đổi ảnh', 'text', None, 'data-do="Chọn ảnh chứng từ khác."'))

def pt_fields(state):
    ed = state in ('nhap', 'nhap_loi')
    err = state == 'nhap_loi'
    def inp(v, w=180, bad=False, aria=''): return '<input class="hmt-input%s" style="width:%dpx" value="%s" aria-label="%s"%s>' % (' hmt-input-err' if bad else '', w, '' if bad else v, aria, ' aria-invalid="true"' if bad else '')
    if ed:
        L = [kv('Số tiền <span class="hmt-req">*</span>', '<input class="hmt-input" style="width:160px;text-align:right" value="%s" aria-label="Số tiền"> <span class="hmt-help">đ</span>' % num(PT['tien'])),
             kv('Hình thức <span class="hmt-req">*</span>', '<select class="hmt-input hmt-select" style="width:180px" aria-label="Hình thức" data-val="Chuyển khoản"><option>Chuyển khoản</option><option>Tiền mặt</option><option>Quẹt thẻ</option></select>'),
             kv('Ngày nhận <span class="hmt-req">*</span>', inp('12/10/2026', 140, False, 'Ngày nhận')),
             kv('Cấn vào dòng', '<select class="hmt-input hmt-select" style="width:100%%;max-width:300px" aria-label="Cấn vào dòng" data-val="Dòng 1 · Phạm Đức Anh · Đại số 8"><option>(để trống) chia tỉ lệ</option>%s</select>' % ''.join('<option>Dòng %d · %s · %s</option>' % (i + 1, l[0], l[5].split(' · ')[0]) for i, l in enumerate(LINES)), 'khoá khi rời Nháp')]
        R = [kv('Tài khoản nhận <span class="hmt-req">*</span>', '<select class="hmt-input hmt-select" style="width:100%%;max-width:300px" aria-label="Tài khoản nhận" data-val="%s"><option>%s</option><option>Techcombank · 1903 8800 1122 (HMT CS2)</option><option>Tiền mặt tại quỹ CS1</option></select>' % (PT['tk'], PT['tk'])),
             kv('Mã giao dịch <span class="hmt-req">*</span>', inp(PT['gd'], 200, err, 'Mã giao dịch') + (('<span class="ix-err">Bắt buộc nhập mã giao dịch với chuyển khoản.</span>') if err else '')),
             kv('Ảnh chứng từ', anh_box(False))]
    else:
        lock = '<span class="hmt-auto">%s khoá</span>' % SVG(IC['lock'])
        L = [kv('Số tiền', '<b class="hmt-num">%s</b>' % money(PT['tien'])), kv('Hình thức', PT['ht']), kv('Ngày nhận', numc(PT['ngay'])),
             kv('Cấn vào dòng', 'Dòng 1 · Phạm Đức Anh · Đại số 8', 'khoá khi rời Nháp')]
        R = [kv('Tài khoản nhận', PT['tk']), kv('Mã giao dịch', code(PT['gd'])), kv('Ảnh chứng từ', anh_box(True))]
    return '<dl class="hmt-panel-b" style="padding:0;max-width:620px">%s</dl>' % ''.join(L + R)

def tc02_chatter(state):
    d = [('10/10/2026', [sysmsg('10:05', 'Phiếu thu nháp tạo từ đơn %s.' % DH['code'])])]
    if state in ('trinh', 'trinh_kt', 'trinh_ad', 'duyet', 'tu_choi', 'huy'):
        d[0][1].insert(0, sysmsg('11:20', 'Trình kế toán duyệt.', chg=('Nháp', 'Đã trình')))
    if state == 'tu_choi':
        d.insert(0, ('11/10/2026', [sysmsg('09:00', 'Phạm Thị Hồng Nhung từ chối. Lý do: Mã giao dịch không khớp sao kê, kiểm tra lại.', chg=('Đã trình', 'Nháp'))]))
    if state == 'duyet':
        d.insert(0, ('12/10/2026', [sysmsg('15:30', 'Phạm Thị Hồng Nhung duyệt. Sinh khoản tiền vào %s (7.000.000 đ) và ba ghi danh GD000301 đến GD000303.' % PT['ktv'], chg=('Đã trình', 'Đã duyệt'))]))
    if state == 'huy':
        d.insert(0, ('11/10/2026', [sysmsg('16:45', 'Huỷ phiếu thu. Lý do: Nhập nhầm đơn, phụ huynh chưa chuyển tiền.', chg=('Đã trình', 'Huỷ'))]))
    return chatter(d)

def d_tc05(variant):
    p = PT
    sumv = ('<dl style="margin:0 0 var(--space-3);display:grid;grid-template-columns:auto 1fr auto 1fr;gap:6px 16px;font-size:13px">'
            '<dt class="hmt-help">Phiếu thu</dt><dd style="margin:0">%s</dd><dt class="hmt-help">Đơn hàng</dt><dd style="margin:0">%s</dd>'
            '<dt class="hmt-help">Số tiền</dt><dd style="margin:0"><b class="hmt-num">%s</b> · %s</dd><dt class="hmt-help">Ngày nhận</dt><dd style="margin:0">%s</dd>'
            '<dt class="hmt-help">Tài khoản nhận</dt><dd style="margin:0">%s</dd><dt class="hmt-help">Mã giao dịch</dt><dd style="margin:0">%s</dd></dl>')
    tien = 500000 if variant == 'chua_du' else p['tien']
    s1 = sumv % (p['code'], p['dh'], money(tien), p['ht'], p['ngay'], p['tk'], p['gd'])
    s1 += '<label style="display:flex;gap:8px;align-items:center;font-size:13px;margin-bottom:var(--space-3)"><input type="checkbox" checked> Đã đối chiếu với sao kê ngân hàng (khớp số tiền, mã giao dịch, ngày)</label>'
    if variant == 'chua_du':
        eff = ('<ol style="margin:0;padding-left:18px;display:flex;flex-direction:column;gap:6px;font-size:13px"><li>Sinh khoản tiền vào <b>KTV-CS1-2610-0009</b>: 500.000 đ.</li>'
               '<li>Tổng tiền đã vào của đơn 500.000 đ <b>chưa đủ</b> cọc tối thiểu 1.000.000 đ: <b>chưa sinh ghi danh</b>, chưa cấp giờ. Còn thiếu 500.000 đ để đủ cọc.</li></ol>')
    else:
        eff = ('<ol style="margin:0;padding-left:18px;display:flex;flex-direction:column;gap:6px;font-size:13px"><li>Sinh khoản tiền vào <b>%s</b>: %s.</li>'
               '<li>Tổng tiền đã vào của đơn 7.000.000 đ ≥ cọc tối thiểu 1.000.000 đ: sinh <b>3 ghi danh</b> (mỗi dòng đơn một ghi danh).</li><li>Cấp giờ theo tỉ lệ tiền đã chia cho từng dòng:</li></ol>' % (p['ktv'], money(tien)))
        eff += '<div style="margin-top:var(--space-2)">' + chia_table(7000000, 0, note=' ') + '</div>'
    warn = ''
    if variant == 'qua_buoi':
        warn = alert('warning', '<b>Đã qua 2 buổi.</b> Hôm nay 06/11/2026, dòng 1 (Phạm Đức Anh · Đại số 8) vào lớp từ 03/11/2026. Giữ nguyên ngày vào lớp; em không bị trừ các buổi đã qua vì không có tên trong danh sách các buổi đó (R-TIEN-27). Kế toán xem lại trước khi duyệt.')
    main = '<div data-pane="main">' + warn + s1 + sec('KHI DUYỆT, HỆ THỐNG SẼ') + eff + '</div>'
    err = variant == 'tu_choi'
    rej = ('<div data-pane="reject" style="display:%s"><p class="hmt-help" style="margin:0 0 var(--space-3)">Phiếu về Nháp, người lập sửa rồi trình lại. Lịch sử giữ lần từ chối và lý do (R-TIEN-06).</p><label class="hmt-field"><span class="hmt-label">Lý do từ chối <span class="hmt-req">*</span></span>'
           '<textarea class="hmt-textarea%s" rows="3" placeholder="Ví dụ: mã giao dịch không khớp sao kê"></textarea>%s</label></div>') % ('block' if err else 'none', ' hmt-input-err' if err else '', '<span class="ix-err">Bắt buộc nhập lý do từ chối.</span>' if err else '')
    if err: main = main.replace('<div data-pane="main">', '<div data-pane="main" style="display:none">')
    foot = ('<span data-pane="main" style="display:%s;gap:8px">' % ('none' if err else 'contents') + btn('Từ chối…', '', 'ban', 'data-pane-to="reject"') + btn('Duyệt', 'primary', 'check', 'data-dto="Đã duyệt phiếu thu. Sinh khoản tiền vào và ghi danh."') + '</span>'
            '<span data-pane="reject" style="display:%s;gap:8px">' % ('contents' if err else 'none') + btn('Quay lại', '', None, 'data-pane-to="main"') + btn('Xác nhận từ chối', 'danger', None, 'data-dto="Đã từ chối phiếu thu, về Nháp."') + '</span>')
    head = '<h2>Duyệt phiếu thu %s</h2>' % p['code']
    if variant == 'tai':
        body = SK_CSS + '<div aria-busy="true">' + sk('60%', 16) + '<div style="height:10px"></div>' + sk('90%', 14) + '<div style="height:8px"></div>' + sk('80%', 14) + '<div style="height:16px"></div>' + sk('100%', 90) + '</div>'
        return dialog('tc05', 'Duyệt phiếu thu', head, body, btn('Đóng', '', None, 'data-close="1"') + btn('Duyệt', 'primary', None, 'disabled'), w=720)
    if variant == 'admin':
        body = alert('info', '<b>Admin chỉ xem.</b> Duyệt phiếu thu là việc của Kế toán (R-HT-01). Kế toán vắng thì Admin gán tạm vai trò Kế toán cho người làm thay, có nhật ký và có thời hạn.', 'lock') + '<div style="height:var(--space-3)"></div>' + s1.replace(' checked>', ' disabled>') + sec('KHI KẾ TOÁN DUYỆT, HỆ THỐNG SẼ') + eff
        return dialog('tc05', 'Phiếu thu chờ Kế toán duyệt', '<h2>Phiếu thu %s · chờ Kế toán duyệt</h2>' % p['code'], body, btn('Đóng', '', None, 'data-close="1"'), w=720)
    return dialog('tc05', 'Duyệt hoặc từ chối phiếu thu', head, main + rej, foot, w=720)

def build_pt(state, show0='', title_over=None, dlg_variant='du_coc', user=None):
    T = {'nhap': 'Nháp', 'nhap_loi': 'Nháp (trình bị chặn: báo đúng ô thiếu)', 'trinh': 'Đã trình (người lập xem)', 'trinh_kt': 'Đã trình (Kế toán)', 'trinh_ad': 'Đã trình (Admin chỉ xem)', 'duyet': 'Đã duyệt',
         'tu_choi': 'Bị từ chối (về Nháp)', 'huy': 'Huỷ', 'tai': 'Đang tải', 'quyen': 'Không có quyền'}[state]
    title = title_over or ('TC-02 · Phiếu thu · ' + T)
    crumb = [('Bán hàng &amp; thu chi', False), ('Phiếu thu', False), (PT['code'], True)]
    if state == 'quyen': return noperm_page(title, 'phiếu thu')
    if state == 'tai': return loading_page(title, 'Phiếu thu', 'sa', crumb[:2] + [('Đang tải…', True)], 'Phiếu thu')
    u = user or {'trinh_kt': 'kt', 'trinh_ad': 'ad', 'duyet': 'kt'}.get(state, 'sa')
    steps = ['Nháp', 'Đã trình', 'Đã duyệt']
    cur = {'nhap': 0, 'nhap_loi': 0, 'tu_choi': 0, 'trinh': 1, 'trinh_kt': 1, 'trinh_ad': 1, 'duyet': 2, 'huy': None}[state]
    if state == 'huy': stg = stage(steps, 1, branches=[('Huỷ', 'danger')], note='phiếu đã huỷ, chỉ còn xem')
    elif state == 'tu_choi': stg = stage(steps, 0, branches=[('Từ chối', 'danger')], note='bị từ chối thì về Nháp, sửa rồi trình lại')
    else: stg = stage(steps, cur)
    tg = {'nhap': tag('Nháp'), 'nhap_loi': tag('Nháp'), 'tu_choi': tag('Nháp · bị từ chối', 'danger'), 'trinh': tag('Đã trình', 'info'), 'trinh_kt': tag('Đã trình', 'info'), 'trinh_ad': tag('Đã trình', 'info'), 'duyet': tag('Đã duyệt', 'success'), 'huy': tag('Huỷ', 'danger')}[state]
    items = [('Đơn hàng', link(PT['dh'], 'Mở đơn hàng (màn BH-05).')), ('Phụ huynh', link('%s · %s' % (PH_NAME, PH_CODE), 'Mở phụ huynh (màn KH-02).')), ('Tình trạng', tg), ('Người lập · cơ sở', 'Trần Thu Hà · CS1')]
    if state == 'duyet': items += [('Duyệt bởi', 'Phạm Thị Hồng Nhung · 12/10/2026'), ('Khoản tiền vào', link(PT['ktv'], 'Mở khoản tiền vào (màn TC-08).'))]
    if state == 'tu_choi': items += [('Lý do từ chối', 'Mã giao dịch không khớp sao kê, kiểm tra lại.')]
    if state == 'huy': items += [('Lý do huỷ', 'Nhập nhầm đơn, phụ huynh chưa chuyển tiền.')]
    head = kgrid(items)
    al = ''
    if state == 'nhap_loi': al = alert('danger', '<b>Chưa trình được.</b> Còn 1 ô bắt buộc: Mã giao dịch (chuyển khoản). Điền xong rồi bấm Trình kế toán.')
    if state == 'tu_choi': al = alert('danger', '<b>Phiếu bị từ chối.</b> Phạm Thị Hồng Nhung, 11/10/2026: “Mã giao dịch không khớp sao kê, kiểm tra lại.” Sửa rồi bấm Trình lại. Cấn vào dòng được mở khoá vì phiếu đã về Nháp.')
    if state == 'trinh': al = alert('info', 'Đã trình, chờ Kế toán duyệt. Trong lúc chờ không sửa được; còn Huỷ được khi phiếu chưa duyệt.', 'lock')
    if state == 'trinh_kt': al = alert('info', 'Phiếu chờ bạn duyệt. Đối chiếu sao kê rồi bấm Duyệt hoặc Từ chối.', 'file')
    if state == 'trinh_ad': al = alert('info', '<b>Admin chỉ xem.</b> Duyệt phiếu thu là việc của Kế toán (R-HT-01). Kế toán vắng thì Admin gán tạm vai trò Kế toán cho người làm thay, có nhật ký, có thời hạn.', 'lock')
    if state == 'duyet': al = alert('info', 'Đã duyệt: sinh khoản tiền vào %s và ba ghi danh. Phiếu không sửa được nữa; sai thì Kế toán đảo khoản (TC-09).' % PT['ktv'], 'check')
    p1 = al + pt_fields(state)
    can = 0
    p2 = chia_table(PT['tien'], can) if state != 'nhap_loi' else chia_table(PT['tien'], can)
    sh = sheet2('Phiếu thu <span class="hmt-code">%s</span> <span class="hmt-help">mã cũ %s</span>' % (PT['code'], PT['old']), head, [('Thông tin phiếu', p1), ('Chia về các dòng đơn', p2 if state != 'huy' else '<div class="hmt-help">Phiếu đã huỷ, không chia tiền.</div>')])
    PRN = btn('In', '', 'printer', 'data-do="Mở bản in biên nhận (màn TC-07, chưa vẽ: chờ khuôn K13)."')
    bt = {'nhap': [btn('Trình kế toán', 'primary', 'send', 'data-do="Đã trình kế toán duyệt."'), btn('Sửa', '', 'pencil', 'data-do="Phiếu nháp đang ở chế độ sửa."'), PRN],
          'nhap_loi': [btn('Trình kế toán', 'primary', 'send', 'data-do="Chưa trình được: thiếu mã giao dịch."'), btn('Lưu', '', 'check', 'data-do="Đã lưu phiếu nháp.')],
          'tu_choi': [btn('Sửa và trình lại', 'primary', 'send', 'data-do="Đã trình lại phiếu thu, lần từ chối được giữ trong lịch sử."')],
          'trinh': [PRN], 'trinh_kt': [btn('Duyệt', 'primary', 'check', 'data-open="tc05"'), btn('Từ chối', '', 'ban', 'data-open="tc05" data-pane-to="reject"'), PRN], 'trinh_ad': [PRN],
          'duyet': [PRN], 'huy': []}[state]
    bt = [b.replace('data-do="Đã lưu phiếu nháp.\'', 'data-do="Đã lưu phiếu nháp."') for b in bt]
    menu_items = {'nhap': [('Huỷ phiếu thu', 'ban', 'data-do="Mở hộp Huỷ phiếu thu có lý do (màn TC-06)."')], 'nhap_loi': [('Huỷ phiếu thu', 'ban', 'data-do="Mở hộp Huỷ phiếu thu có lý do (màn TC-06)."')], 'tu_choi': [('Huỷ phiếu thu', 'ban', 'data-do="Mở hộp Huỷ phiếu thu có lý do (màn TC-06)."')],
                  'trinh': [('Huỷ phiếu thu', 'ban', 'data-do="Mở hộp Huỷ phiếu thu có lý do (màn TC-06)."')], 'trinh_kt': [], 'trinh_ad': [], 'duyet': [], 'huy': []}[state]
    smt = smart([('Đơn hàng', 1), ('Khoản tiền vào', 1 if state == 'duyet' else 0), ('Ghi danh', 3 if state == 'duyet' else 0)])
    dl = d_tc05(dlg_variant)
    return page(title, 'Phiếu thu', u, crumb, rbar_l('Phiếu thu', bt, menu_items or None), smt + stg + sh, tc02_chatter(state), pager='15 / 138', dlgs=dl, show0=show0)

def d_tc09(variant='ok'):
    chan = variant == 'chan'
    body = ('<dl style="margin:0 0 var(--space-3);display:grid;grid-template-columns:auto 1fr auto 1fr;gap:6px 16px;font-size:13px"><dt class="hmt-help">Khoản gốc</dt><dd style="margin:0">%s</dd><dt class="hmt-help">Phiếu thu</dt><dd style="margin:0">%s</dd>'
            '<dt class="hmt-help">Số tiền gốc</dt><dd style="margin:0"><b class="hmt-num">%s</b></dd><dt class="hmt-help">Đơn hàng</dt><dd style="margin:0">%s</dd></dl>') % (PT['ktv'] if not chan else 'KTV-CS5-2610-0004', PT['code'] if not chan else 'PT-CS5-2610-0005', money(PT['tien'] if not chan else 3960000), DH['code'] if not chan else 'DH-CS5-2610-0006')
    if chan:
        body += alert('danger', '<b>Không đảo được.</b> Khoản này đã được đảo bằng KTV-CS5-2610-0006 (−3.960.000 đ). Mỗi khoản chỉ đảo một lần (R-TIEN-26).')
    else:
        body += ('<label class="hmt-field"><span class="hmt-label">Lý do đảo <span class="hmt-req">*</span></span><select class="hmt-input hmt-select" aria-label="Lý do đảo" style="width:100%"><option>Chọn lý do…</option><option>Nhập sai số tiền</option><option>Chuyển khoản không về</option><option>Phụ huynh yêu cầu hoàn lại</option><option>Nhầm đơn hàng</option></select><span class="hmt-help">Chọn từ danh mục (R-TIEN-26).</span></label>'
                 '<div style="margin:var(--space-3) 0 var(--space-2)">' + alert('warning', 'Giữ nguyên khoản gốc, thêm một khoản âm <b>−7.000.000 đ</b> trỏ về khoản gốc, ghi “Đảo của %s” (cùng dãy mã KTV). Giờ đã cấp sẽ <b>tính lại</b> theo tiền còn lại của đơn.' % PT['ktv']) + '</div>'
                 + sec('GIỜ SẼ TÍNH LẠI') + chia_table(0, None, note='Sau khi đảo đơn còn 0 đ đã vào: giờ cấp của ba ghi danh về 0 (các buổi đã học vẫn tính là đã học, quỹ có thể âm nếu đã học).').replace('Tiền chia về dòng (đ)', 'Tiền còn lại sau đảo (đ)'))
    foot = btn('Đóng', '', None, 'data-close="1"') + btn('Xác nhận đảo', 'danger', 'undo', ('disabled' if chan else 'data-dto="Đã đảo khoản. Thêm khoản âm KTV-CS1-2610-0010, giờ cấp tính lại."'))
    return dialog('tc09', 'Đảo khoản tiền', '<h2>Đảo khoản tiền</h2>', body, foot, w=680)

# ---------------- danh sách ----------------
PT_ST = {'Nháp': '', 'Đã trình': 'info', 'Đã duyệt': 'success', 'Từ chối': 'danger', 'Huỷ': 'danger'}
PTL = [('PT-CS1-2610-0016', 'DH-CS1-2610-0012', 'Phạm Thu Hương', 3000000, 'Tiền mặt', '16/10/2026', 'CS1', 'Trần Thu Hà', 'Nháp'), (PT['code'], DH['code'], 'Phạm Thu Hương', 7000000, 'Chuyển khoản', '12/10/2026', 'CS1', 'Trần Thu Hà', 'Đã duyệt'),
       ('PT-CS1-2610-0014', 'DH-CS1-2610-0011', 'Trần Thị Hà', 9504000, 'Chuyển khoản', '11/10/2026', 'CS1', 'Trần Thu Hà', 'Đã duyệt'), ('PT-CS2-2610-0013', 'DH-CS2-2610-0008', 'Đỗ Ngọc Bích', 2000000, 'Chuyển khoản', '15/10/2026', 'CS2', 'Hoàng Mai Anh', 'Đã trình'),
       ('PT-CS5-2610-0012', 'DH-CS5-2610-0003', 'Ngô Hồng Nhung', 1000000, 'Quẹt thẻ', '15/10/2026', 'CS5', 'Lê Thanh Hà', 'Đã trình'), ('PT-CS4-2610-0011', 'DH-CS4-2610-0004', 'Lê Minh Tuấn', 11088000, 'Chuyển khoản', '10/10/2026', 'CS4', 'Vũ Đức Minh', 'Đã duyệt'),
       ('PT-CS5-2610-0010', 'DH-CS5-2610-0006', 'Vũ Thị Mai', 9504000, 'Chuyển khoản', '09/10/2026', 'CS5', 'Lê Thanh Hà', 'Từ chối'), ('PT-CS1-2610-0009', 'DH-CS1-2610-0005', 'Hoàng Văn Đức', 4752000, 'Tiền mặt', '08/10/2026', 'CS1', 'Trần Thu Hà', 'Huỷ'),
       ('PT-CS2-2610-0008', 'DH-CS2-2610-0009', 'Trần Quốc Hưng', 3960000, 'Chuyển khoản', '16/10/2026', 'CS2', 'Hoàng Mai Anh', 'Đã trình'), ('PT-CS4-2610-0007', 'DH-CS4-2610-0007', 'Bùi Thanh Thuỷ', 2000000, 'Tiền mặt', '16/10/2026', 'CS4', 'Vũ Đức Minh', 'Nháp')]
def cfg_pt():
    return dict(code='TC-01', h1='Phiếu thu', nav='Phiếu thu', crumb=[('Bán hàng &amp; thu chi', False), ('Phiếu thu', True)], ph='Tìm mã phiếu thu, đơn hàng, phụ huynh, mã giao dịch…', noun='phiếu thu', total=138,
        heads=[('Mã', 0), ('Đơn hàng', 0), ('Phụ huynh', 0), ('Số tiền (đ)', 1), ('Hình thức', 0), ('Ngày nhận', 0), ('Cơ sở', 0), ('Người lập', 0), ('Tình trạng', 0)],
        rows=[[C(c), L(d), L(p), M(t), h, N(n), cs, u, tag(st, PT_ST[st])] for c, d, p, t, h, n, cs, u, st in PTL],
        tfields=[('Mã', 'Mã'), ('Đơn hàng', 'Đơn hàng'), ('Phụ huynh', 'Phụ huynh')], favs=[('Phiếu thu chờ kế toán duyệt', True, "{'Tình trạng':['Đã trình']}"), ('Phiếu thu nháp của tôi', False, "{'Tình trạng':['Nháp']}")],
        gfields=[('Tình trạng', 'Tình trạng', False), ('Hình thức', 'Hình thức', False), ('Cơ sở', 'Cơ sở', False)],
        filters=[('Tình trạng', [(k, k) for k in PT_ST] + [('Chờ kế toán duyệt', 'Đã trình')]), ('Hình thức', [('Chuyển khoản', 'Chuyển khoản'), ('Tiền mặt', 'Tiền mặt'), ('Quẹt thẻ', 'Quẹt thẻ')]), ('Cơ sở', [(x, x) for x in ('CS1', 'CS2', 'CS4', 'CS5')])], link='Mở phiếu thu (màn TC-02).',
        toasts="{'Xuất':'Đang xuất danh sách phiếu thu ra file.'}", hint='Thử tìm bằng mã phiếu thu, mã đơn, tên phụ huynh hoặc mã giao dịch.', eicon='wallet', etitle='Chưa có phiếu thu nào',
        esub='Phiếu thu lập từ đơn hàng đã duyệt (nút Tạo phiếu thu trên đơn). Danh sách này không có nút Tạo (R-TIEN-02).')

CHO = [('PT-CS2-2610-0013', 'DH-CS2-2610-0008', 'Đỗ Ngọc Bích', 'CS2', 2000000, 'Chuyển khoản', 'Techcombank · …1122', 'FT26288456721', '15/10/2026', 'Chưa khớp'),
       ('PT-CS5-2610-0012', 'DH-CS5-2610-0003', 'Ngô Hồng Nhung', 'CS5', 1000000, 'Quẹt thẻ', 'POS Mỹ Đình · …0045', 'POS884201', '15/10/2026', 'Đã khớp'),
       ('PT-CS2-2610-0008', 'DH-CS2-2610-0009', 'Trần Quốc Hưng', 'CS2', 3960000, 'Chuyển khoản', 'Techcombank · …1122', 'FT26290011873', '16/10/2026', 'Chưa khớp'),
       ('PT-CS1-2610-0015', 'DH-CS1-2610-0012', 'Phạm Thu Hương', 'CS1', 7000000, 'Chuyển khoản', 'Vietcombank · …3456', 'FT26285123456', '12/10/2026', 'Đã khớp'),
       ('PT-CS4-2610-0006', 'DH-CS4-2610-0005', 'Lê Minh Tuấn', 'CS4', 5280000, 'Chuyển khoản', 'Vietcombank · …7788', 'FT26291002244', '16/10/2026', 'Chưa khớp')]
def cfg_cho(role='kt'):
    act = lambda c: ('<button class="hmt-btn hmt-btn-primary" type="button" data-open="tc05">Duyệt</button> <button class="hmt-btn" type="button" data-open="tc05" data-pane-to="reject">Từ chối</button>' if role == 'kt' else '<span class="hmt-help">chỉ Kế toán duyệt</span>')
    dlg = d_tc05('du_coc')
    return dict(code='TC-04', h1='Hàng chờ kế toán duyệt', nav='Hàng chờ kế toán duyệt', crumb=[('Bán hàng &amp; thu chi', False), ('Hàng chờ kế toán duyệt', True)], ph='Tìm mã phiếu thu, mã giao dịch, phụ huynh…', noun='phiếu thu chờ duyệt', total=5,
        heads=[('Mã', 0), ('Đơn hàng', 0), ('Phụ huynh', 0), ('Cơ sở', 0), ('Số tiền (đ)', 1), ('Hình thức', 0), ('Mã giao dịch', 0), ('Ngày nhận', 0), ('Sao kê', 0), ('Xử lý', 0)],
        rows=[[C(c), L(d), L(p), cs, M(t), h, N(gd), N(n), tag(sk_, 'success' if sk_ == 'Đã khớp' else 'warning'), act(c)] for c, d, p, cs, t, h, tk, gd, n, sk_ in CHO], nochk=True,
        tfields=[('Mã', 'Mã'), ('Phụ huynh', 'Phụ huynh'), ('Mã giao dịch', 'Mã giao dịch')], favs=[('Chưa khớp sao kê', True, "{'Sao kê':['Chưa khớp']}"), ('Chuyển khoản CS2', False, "{'Hình thức':['Chuyển khoản'],'Cơ sở':['CS2']}")],
        gfields=[('Cơ sở', 'Cơ sở', False), ('Hình thức', 'Hình thức', False), ('Sao kê', 'Sao kê', False)],
        filters=[('Sao kê', [('Đã khớp', 'Đã khớp'), ('Chưa khớp', 'Chưa khớp')]), ('Hình thức', [('Chuyển khoản', 'Chuyển khoản'), ('Tiền mặt', 'Tiền mặt'), ('Quẹt thẻ', 'Quẹt thẻ')]), ('Cơ sở', [(x, x) for x in ('CS1', 'CS2', 'CS4', 'CS5')])], link='Mở phiếu thu (màn TC-02).',
        toasts="{'Xuất':'Đang xuất hàng chờ ra file.'}", hint='Thử tìm bằng mã phiếu thu, mã giao dịch hoặc tên phụ huynh.', eicon='check', etitle='Không có phiếu thu nào chờ duyệt',
        esub='Phiếu thu do sale, CSKH trình sẽ hiện ở đây, mọi cơ sở.', dlgs=dlg, export=('kt', 'ad'))

KT_ST = {'Thu': '', 'Đảo': 'danger'}
KTVL = [('KTV-CS1-2610-0009', 'PT-CS1-2610-0015', 'DH-CS1-2610-0012', 'Phạm Thu Hương', 7000000, '12/10/2026', 'CS1', '', 'ok'), ('KTV-CS1-2610-0008', 'PT-CS1-2610-0014', 'DH-CS1-2610-0011', 'Trần Thị Hà', 9504000, '11/10/2026', 'CS1', '', 'ok'),
        ('KTV-CS2-2610-0007', 'PT-CS2-2610-0010', 'DH-CS2-2610-0008', 'Đỗ Ngọc Bích', 2000000, '10/10/2026', 'CS2', '', 'ok'), ('KTV-CS5-2610-0006', 'PT-CS5-2610-0005', 'DH-CS5-2610-0006', 'Vũ Thị Mai', -3960000, '10/10/2026', 'CS5', 'Đảo của …0004', 'dao'),
        ('KTV-CS4-2610-0005', 'PT-CS4-2610-0011', 'DH-CS4-2610-0004', 'Lê Minh Tuấn', 11088000, '10/10/2026', 'CS4', '', 'ok'), ('KTV-CS5-2610-0004', 'PT-CS5-2610-0005', 'DH-CS5-2610-0006', 'Vũ Thị Mai', 3960000, '08/10/2026', 'CS5', 'Đã đảo bằng …0006', 'da_dao'),
        ('KTV-CS1-2610-0003', 'PT-CS1-2610-0004', 'DH-CS1-2610-0003', 'Nguyễn Văn Long', 5280000, '07/10/2026', 'CS1', '', 'ok'), ('KTV-CS2-2610-0002', 'PT-CS2-2610-0003', 'DH-CS2-2610-0002', 'Trần Quốc Hưng', 1000000, '06/10/2026', 'CS2', '', 'ok')]
def cfg_ktv(role='kt'):
    def act(st, m):
        if st != 'ok': return '<span class="hmt-help">—</span>'
        return '<button class="hmt-btn hmt-btn-text" type="button" data-open="tc09">Đảo khoản</button>' if role == 'kt' else '<span class="hmt-help">chỉ Kế toán đảo</span>'
    def amt(n): return '<span class="hmt-num"%s>%s</span>' % (' style="color:var(--danger-text)"' if n < 0 else '', ('−' + num(-n)) if n < 0 else num(n))
    return dict(code='TC-08', h1='Khoản tiền vào', nav='Khoản tiền vào', crumb=[('Bán hàng &amp; thu chi', False), ('Khoản tiền vào', True)], ph='Tìm mã khoản, phiếu thu, đơn hàng, phụ huynh…', noun='khoản tiền vào', total=412,
        heads=[('Mã', 0), ('Phiếu thu', 0), ('Đơn hàng', 0), ('Phụ huynh', 0), ('Số tiền (đ)', 1), ('Ngày', 0), ('Cơ sở', 0), ('Ghi chú', 0), ('Đảo', 0)], nochk=True,
        rows=[[C(c), L(p), L(d), L(ph), amt(t), N(n), cs, gc, act(st, 0)] for c, p, d, ph, t, n, cs, gc, st in KTVL],
        tfields=[('Mã', 'Mã'), ('Phụ huynh', 'Phụ huynh'), ('Đơn hàng', 'Đơn hàng')], favs=[('Khoản đảo', True, "{'Loại':['Đảo']}"), ('Khoản CS1', False, "{'Cơ sở':['CS1']}")],
        gfields=[('Cơ sở', 'Cơ sở', False), ('Ngày', 'Ngày', False)],
        filters=[('Loại', [('Khoản đảo', 'Đảo của'), ('Đã bị đảo', 'Đã đảo bằng')]), ('Cơ sở', [(x, x) for x in ('CS1', 'CS2', 'CS4', 'CS5')])], link='Mở phiếu thu hoặc đơn hàng của khoản (màn TC-02, BH-05).',
        toasts="{'Xuất':'Đang xuất sổ khoản tiền vào ra file.'}", hint='Thử tìm bằng mã khoản, mã phiếu thu, mã đơn hoặc tên phụ huynh.', eicon='wallet', etitle='Chưa có khoản tiền vào nào',
        esub='Khoản tiền vào tự sinh khi Kế toán duyệt phiếu thu, không ai tạo tay. Sổ này chỉ đọc (R-TIEN-01).', dlgs=d_tc09('ok'), export=('kt', 'bm', 'ad'))

# ---------------- TC-15 Đối soát thu tiền (K09) ----------------
def tc15(state='normal'):
    t = open('render/BaoCao.dc.html', encoding='utf-8').read()
    t = re.sub(r'<title>[^<]*</title>', '<title>TC-15 · Đối soát thu tiền%s</title>' % {'normal': '', 'trong': ' · trống', 'tai': ' · đang tải', 'quyen': ' · không có quyền'}[state], t, 1)
    t = t.replace('<span class="hmt-avatar hmt-avatar-lg">CT</span><span class="hmt-user-n"><b>Cao Trường</b><span>Admin · Tất cả cơ sở</span></span>', '<span class="hmt-avatar hmt-avatar-lg">%s</span><span class="hmt-user-n"><b>%s</b><span>%s</span></span>' % (USERS['kt'][2] if state != 'quyen' else USERS['gv'][2], USERS['kt'][0] if state != 'quyen' else USERS['gv'][0], 'Kế toán · Toàn hệ thống' if state != 'quyen' else USERS['gv'][1]))
    # lọc: theo ngày, tài khoản nhận, hình thức, mã giao dịch
    a = t.index('<div style="display:flex;gap:var(--space-3);padding:0 var(--space-5) var(--space-3);background:var(--bg-surface)">'); b = t.index('<div class="hmt-content">')
    sel = lambda lab, v: '<div class="hmt-field" style="min-width:0;flex:1"><label>%s</label><button class="hmt-input hmt-select" type="button" data-do="Chọn %s."><span>%s</span><svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg></button></div>' % (lab, lab.lower(), v)
    flt = '<div style="display:flex;gap:var(--space-3);padding:0 var(--space-5) var(--space-3);background:var(--bg-surface)">' + sel('Thời gian', '7 ngày gần nhất') + sel('Cơ sở', 'Tất cả cơ sở') + sel('Tài khoản nhận', 'Mọi tài khoản') + sel('Hình thức', 'Mọi hình thức') + \
          '<div class="hmt-field" style="min-width:0;flex:1.2"><label>Mã giao dịch</label><input class="hmt-input" placeholder="Gõ mã giao dịch…" aria-label="Mã giao dịch"></div>' + sel('Sao kê', 'Tất cả') + '</div>'
    rows = [('12/10/2026', 'PT-CS1-2610-0015', 'Phạm Thu Hương', 'Chuyển khoản', 'Vietcombank …3456', 'FT26285123456', 7000000, 1), ('15/10/2026', 'PT-CS2-2610-0013', 'Đỗ Ngọc Bích', 'Chuyển khoản', 'Techcombank …1122', 'FT26288456721', 2000000, 0),
            ('15/10/2026', 'PT-CS5-2610-0012', 'Ngô Hồng Nhung', 'Quẹt thẻ', 'POS Mỹ Đình …0045', 'POS884201', 1000000, 1), ('16/10/2026', 'PT-CS2-2610-0008', 'Trần Quốc Hưng', 'Chuyển khoản', 'Techcombank …1122', 'FT26290011873', 3960000, 0),
            ('16/10/2026', 'PT-CS4-2610-0006', 'Lê Minh Tuấn', 'Chuyển khoản', 'Vietcombank …7788', 'FT26291002244', 5280000, 0), ('16/10/2026', 'PT-CS1-2610-0016', 'Phạm Thu Hương', 'Tiền mặt', 'Quỹ tiền mặt CS1', '—', 3000000, 0)]
    cnt = lambda lab, v, hl=False: '<div class="hmt-count%s" style="flex:1"><span class="hmt-count-t">%s</span><span class="hmt-count-v">%s</span></div>' % (' hmt-count-hl' if hl else '', lab, v)
    trs = ''.join('<tr><td><label class="hmt-hit"><input type="checkbox" aria-label="Chọn %s"%s></label></td><td>%s</td><td><a href="#" data-do="Mở phiếu thu (màn TC-02).">%s</a></td><td>%s</td><td>%s</td><td>%s</td><td><span class="hmt-code">%s</span></td><td class="r">%s</td><td data-st>%s</td></tr>' % (c, ' disabled' if k else '', d, c, p, h, tk, g, num(n), tag('Đã khớp', 'success') if k else tag('Chưa khớp', 'warning')) for d, c, p, h, tk, g, n, k in rows)
    tbl = ('<div class="hmt-table-wrap"><table class="hmt-table"><thead><tr><th style="width:40px"><label class="hmt-hit"><input type="checkbox" aria-label="Chọn tất cả"></label></th><th>Ngày</th><th>Phiếu thu</th><th>Phụ huynh</th><th>Hình thức</th><th>Tài khoản nhận</th><th>Mã giao dịch</th><th class="r">Số tiền (đ)</th><th>Sao kê</th></tr></thead><tbody>%s</tbody></table></div>') % trs
    tot_ = sum(r[6] for r in rows); kh = sum(r[6] for r in rows if r[7])
    content = ('<div class="hmt-content"><div style="display:flex;gap:var(--space-3)">' + cnt('Tổng tiền thu', money(tot_), True) + cnt('Đã khớp sao kê', money(kh)) + cnt('Chưa khớp', money(tot_ - kh)) + cnt('Số phiếu chưa khớp', '4') + '</div>'
               '<div style="display:flex;align-items:center;gap:var(--space-3)"><button class="hmt-btn hmt-btn-primary" type="button" id="markbtn" disabled>%s Đánh dấu đã khớp</button><span class="hmt-help" id="markhint">Tích chọn các phiếu thu đã thấy trên sao kê, rồi bấm Đánh dấu đã khớp.</span></div>%s</div></div></div></div></div>') % (SVG(IC['check']), tbl)
    if state == 'trong': content = '<div class="hmt-content">' + empty_box('search', 'Không có phiếu thu nào trong khoảng đã lọc', 'Đổi khoảng thời gian, tài khoản nhận hoặc hình thức để xem phiếu thu cần đối soát.', None) + '</div></div></div></div></div>'
    if state == 'tai': content = SK_CSS + '<div class="hmt-content" aria-busy="true"><div style="display:flex;gap:var(--space-3)">' + ''.join('<div class="hmt-count" style="flex:1">%s%s</div>' % (sk(110, 12), sk(150, 26)) for _ in range(4)) + '</div><div class="hmt-box" style="overflow:hidden">' + ''.join('<div style="display:flex;gap:14px;padding:12px 16px;border-top:1px solid var(--bg-subtle)">' + sk(16, 16) + sk(90, 14) + sk(120, 14) + sk(120, 14) + sk(100, 14) + sk(140, 14) + '</div>' for _ in range(7)) + '</div></div></div></div></div>'
    if state == 'quyen': content = ('<div class="hmt-content"><div class="hmt-box hmt-empty" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:48px 20px;text-align:center;min-height:420px;margin:var(--space-6) auto;max-width:560px"><span style="color:var(--text-secondary)">' + SVG(IC['lock'], 'hmt-ic hmt-ic-lg') +
                                    '</span><b style="font-size:16px;font-family:var(--font-heading)">Bạn không có quyền xem đối soát thu tiền</b><span class="hmt-help" style="max-width:420px">Đối soát thu tiền dành cho Kế toán và Admin. Nếu cần xem, hãy liên hệ quản trị viên.</span></div></div></div></div></div>')
    t = t[:a] + flt + content + t[t.index('</x-dc>'):] if False else t[:a] + flt + content + '\n</x-dc>' + t[t.index('</x-dc>') + 7:]
    t = t.replace('<div class="sz"><button class="hmt-btn" type="button">', '<div class="sz"><button class="hmt-btn" type="button" data-do="Đang xuất bảng đối soát ra file.">', 1)
    js = r"""
    componentDidMount() { const ROOT = document.querySelector('[data-ix=root]'); if (!ROOT) return; const q = (s, r) => (r || ROOT).querySelector(s); const qa = (s, r) => Array.from((r || ROOT).querySelectorAll(s));
      function toast(m) { let t = q('.ix-toast'); if (!t) { t = document.createElement('div'); t.className = 'ix-toast'; ROOT.appendChild(t); } t.textContent = m; t.classList.add('on'); clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('on'), 2600); }
      const mb = q('#markbtn'); const upd = () => { if (!mb) return; const n = qa('tbody input:checked').length; mb.disabled = n === 0; mb.lastChild.textContent = ' Đánh dấu đã khớp' + (n ? ' (' + n + ')' : ''); };
      ROOT.addEventListener('change', ev => { const c = ev.target; if (c.matches && c.matches('thead input')) { qa('tbody input:not(:disabled)').forEach(x => { x.checked = c.checked; }); } upd(); });
      ROOT.addEventListener('click', ev => { const t = ev.target; const dd = t.closest('[data-do]'); if (dd) { ev.preventDefault(); toast(dd.getAttribute('data-do')); return; }
        if (t.closest('#markbtn') && mb && !mb.disabled) { const rows = qa('tbody input:checked').map(x => x.closest('tr')); rows.forEach(r => { q('[data-st]', r).innerHTML = '<span class="hmt-tag hmt-tag-success">Đã khớp</span>'; const i = q('input', r); i.checked = false; i.disabled = true; }); upd(); toast('Đã đánh dấu ' + rows.length + ' phiếu thu khớp sao kê.'); } });
    }
"""
    t = re.sub(r'class Component extends DCLogic \{.*?\n\}\n</script>', lambda m: 'class Component extends DCLogic {\n  renderVals() { return { yes: true }; }\n' + js + '}\n</script>', t, count=1, flags=re.S)
    return t

def run():
    out = []
    boards = {}
    for st in ('nhap', 'nhap_loi', 'trinh', 'trinh_kt', 'trinh_ad', 'duyet', 'tu_choi', 'huy', 'tai', 'quyen'):
        wr('TC02_' + st, build_pt(st)); out.append('TC02_' + st)
    for v, lab, bg in (('du_coc', 'Duyệt, đủ cọc: sinh khoản tiền vào và ghi danh', 'trinh_kt'), ('chua_du', 'Duyệt, chưa đủ cọc: chưa sinh ghi danh', 'trinh_kt'), ('qua_buoi', 'Cảnh báo đã qua N buổi', 'trinh_kt'),
                       ('tu_choi', 'Từ chối, thiếu lý do', 'trinh_kt'), ('admin', 'Admin chỉ xem, không có nút Duyệt', 'trinh_ad'), ('tai', 'Đang tải', 'trinh_kt')):
        wr('TC05_' + v, build_pt(bg, show0='tc05', dlg_variant=v, title_over='TC-05 · Kế toán duyệt, từ chối phiếu thu · ' + lab)); out.append('TC05_' + v)
    wr('TC03_tao', D.build_dh('duyet', show0='tc03', title_over='TC-03 · Tạo phiếu thu từ đơn hàng')); out.append('TC03_tao')
    out += PL.run_list(cfg_pt(), 'TC01', 'kt')
    out += PL.run_list(cfg_cho(), 'TC04', 'kt')
    c = cfg_cho('ad'); c['dlgs'] = ''; wr('TC04_admin', PL.build_list(c, 'normal', 'ad')); out.append('TC04_admin')
    out += PL.run_list(cfg_ktv(), 'TC08', 'kt')
    c = cfg_ktv('bm'); c['dlgs'] = ''; wr('TC08_bm', PL.build_list(c, 'normal', 'bm')); out.append('TC08_bm')
    c = cfg_ktv(); c['show0'] = 'tc09'; wr('TC09_dao', PL.build_list(c, 'normal', 'kt').replace('<title>TC-08 · Khoản tiền vào · danh sách</title>', '<title>TC-09 · Đảo khoản tiền</title>')); out.append('TC09_dao')
    c = cfg_ktv(); c['dlgs'] = d_tc09('chan'); c['show0'] = 'tc09'; wr('TC09_chan', PL.build_list(c, 'normal', 'kt').replace('<title>TC-08 · Khoản tiền vào · danh sách</title>', '<title>TC-09 · Đảo khoản tiền · đã đảo, chặn đảo hai lần</title>')); out.append('TC09_chan')
    for st in ('normal', 'trong', 'tai', 'quyen'):
        n = 'TC15' + {'normal': '', 'trong': '_trong', 'tai': '_tai', 'quyen': '_khong_quyen'}[st]; wr(n, tc15(st)); out.append(n)
    return out

if __name__ == '__main__':
    print(' '.join(run()))
