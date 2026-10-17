# -*- coding: utf-8 -*-
# P5a cụm 1: Đơn hàng (BH-05), BH-07, BH-08, BH-09
import sys, re, datetime; sys.path.insert(0, 'scripts')
from p5a_common import *
from kh_common import SK_CSS, sk
from p5a_bh import PH_NAME, PH_CODE, QT

DH = dict(code='DH-CS1-2610-0012', old='SO-2610-0044', co='CO000142', bg=QT['code'], sale='Trần Thu Hà', term='k2', cs='CS1 Nguyễn Chí Thanh')
TERMS = {'': ('Một lần (không chọn)', [(100, 0)]), 'k2': ('2 đợt · 50/50 · cách 30 ngày', [(50, 0), (50, 30)]), 'k3': ('3 đợt · 40/30/30 · cách 30 ngày', [(40, 0), (30, 30), (30, 60)])}
BASE = datetime.date(2026, 10, 10)
def term_sel():
    return ('<select class="hmt-input hmt-select" style="width:100%%;max-width:200px" data-term aria-label="Điều khoản thanh toán">%s</select><div class="hmt-help">danh mục cấu hình; lịch đợt tự hiện ở tab Thanh toán</div>' %
            ''.join('<option value="%s"%s>%s</option>' % (k, ' selected' if k == DH['term'] else '', v[0]) for k, v in TERMS.items()))
def wd(d, m): return ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'][datetime.date(2026, m, d).weekday()] if False else ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'][datetime.date(2026, 11, d).weekday()]
# học sinh, mã, gói, tên gói, hình thức, lớp mã, lớp tên, ngày vào (None = chưa chọn), giờ, tặng, đơn giá, ck%
L1 = ('Phạm Đức Anh', 'HS000126', 'LC-TOAN-K08', 'Offline', 'CS1-2627-DAI-K08-CB-A-001', 'Đại số 8 · T3, T5 18:00', '03/11/2026', 24, 0, 220000, 10)
L2 = ('Phạm Đức Anh', 'HS000126', 'LC-TOAN-K08', 'Offline', 'CS1-2627-HINH-K08-CB-A-001', 'Hình học 8 · T6 18:00', '06/11/2026', 24, 0, 220000, 10)
L3 = ('Phạm Khánh Vy', 'HS000127', 'LC-ANH-K05', 'Offline', 'CS1-2627-ANH-K05-CB-B-002', 'Tiếng Anh 5 · T7 08:30', '07/11/2026', 24, 2, 180000, 5)
L3_TRAN = L3[:10] + (15,)
def lt(l): return int(round(l[7] * l[9] * (100 - l[10]) / 100))
def lpct(l): return l[10] + (l[8] * 100.0 / l[7])
def tot(ls): return sum(lt(l) for l in ls)

def lines_table(ls, mode='lock', miss=None, hl=None):
    """mode: 'edit' | 'lock'. miss: {dòng: ô thiếu}"""
    miss = miss or {}
    rows = []
    for i, l in enumerate(ls):
        hs, hc, g, ht, lc, ln, nv, gio, tang, dg, ck = l
        bad_lop = miss.get(i) == 'lop'
        if mode == 'edit':
            c_hs = '<a href="#" data-do="Mở hồ sơ học sinh (màn KH-05).">%s</a><div class="hmt-help">%s</div>' % (hs, hc)
            c_g = '<b>%s</b><div><select class="hmt-input hmt-select" style="width:84px" aria-label="Hình thức" data-val="%s"><option>Offline</option><option>Online</option></select></div>' % (g, ht)
            if lc:
                c_l = '<span class="hmt-code">%s</span><div class="hmt-help">%s</div><div>%s</div>' % (lc, ln, ('<a href="#" data-open="bh08">Đổi lớp</a> <span class="hmt-help">· vào %s</span>' % nv[:5]))
            else:
                c_l = '<button class="hmt-btn" type="button" data-open="bh08">Chọn lớp và ngày vào…</button>' + (('<span class="ix-err">Dòng %d: chưa chọn lớp, chưa có ngày vào lớp.</span>' % (i + 1)) if bad_lop else '')
            c_h = '<div style="display:flex;gap:6px"><input class="hmt-input" style="width:40px;text-align:right" value="%d" aria-label="Giờ mua"><input class="hmt-input" style="width:38px;text-align:right" value="%d" aria-label="Giờ tặng"></div><div class="hmt-help">mua · tặng</div>' % (gio, tang)
            c_pc = '<span class="hmt-num">%s</span><span class="hmt-help"> đ/giờ</span><div style="display:flex;align-items:center;gap:4px;margin-top:4px"><input class="hmt-input" style="width:40px;text-align:right" value="%d" aria-label="Chiết khấu %%"><span class="hmt-help">%%</span></div><div class="hmt-help" style="%s">cộng dồn %s%%</div>' % (num(dg), ck, 'color:var(--danger-text)' if lpct(l) > 20 else '', ('%.1f' % lpct(l)).replace('.', ','))
            act = btn('', 'text', 'x', 'aria-label="Bỏ dòng" data-do="Đã bỏ dòng khỏi đơn nháp."')
        else:
            c_hs = '<a href="#" data-do="Mở hồ sơ học sinh (màn KH-05).">%s</a><div class="hmt-help">%s</div>' % (hs, hc)
            c_g = '<b>%s</b><div class="hmt-help">%s</div>' % (g, ht)
            c_l = '<span class="hmt-code">%s</span><div class="hmt-help">%s</div><div class="hmt-help">vào %s (%s)</div>' % (lc, ln, nv, wd(int(nv[:2]), 11))
            c_h = '<span class="hmt-num">%d</span> <span class="hmt-help">+ %d tặng</span>' % (gio, tang)
            c_pc = '<span class="hmt-num">%s</span><span class="hmt-help"> đ/giờ</span><div class="hmt-num">giảm %d%%</div>' % (num(dg), ck) + ('<div class="hmt-help" style="color:var(--danger-text)">cộng dồn %s%% · vượt trần</div>' % ('%.1f' % lpct(l)).replace('.', ',') if lpct(l) > 20 else ('<div class="hmt-help">cộng dồn %s%%</div>' % ('%.1f' % lpct(l)).replace('.', ',') if tang else ''))
            act = ''
        row = [c_hs, c_g, c_l, c_h, c_pc, '<span class="hmt-num"><b>%s</b></span>' % num(lt(l))] + ([act] if mode == 'edit' else [])
        rows.append(row)
    heads = [('Học sinh', 0), ('Gói · hình thức', 0), ('Lớp · ngày vào lớp', 0), ('Giờ', 0), ('Giá · chiết khấu', 0), ('Thành tiền (đ)', 1)] + ([('', 0)] if mode == 'edit' else [])
    h = table(heads, rows, cls='', widths=[96, 98, 178, 92, 104, 82] + ([26] if mode == 'edit' else []), wrap=True)
    # hàng nền cho dòng bị thiếu
    if miss:
        h = h.replace('<tr><td><a href="#" data-do="Mở hồ sơ học sinh (màn KH-05).">%s</a>' % ls[min(miss)][0], '<tr style="background:var(--danger-bg,#fdecea)"><td><a href="#" data-do="Mở hồ sơ học sinh (màn KH-05).">%s</a>' % ls[min(miss)][0], 1) if False else h
    return h

def total_bar(ls, paid=0, extra=''):
    t = tot(ls)
    return ('<div style="display:flex;justify-content:flex-end;align-items:baseline;gap:var(--space-6);padding-top:var(--space-2);font-size:13px">%s<span>Tổng thành tiền <b class="hmt-num" style="font-size:16px">%s</b></span><span>Đã vào <b class="hmt-num">%s</b></span><span>Còn lại <b class="hmt-num" style="color:%s">%s</b></span></div>') % (
        extra, money(t), money(paid), 'var(--danger-text)' if t - paid > 0 else 'var(--success-text,#1a7f37)', money(t - paid))

def reminder():
    return ('<div class="hmt-alert hmt-alert-info" role="status">' + SVG(IC['alert']) + '<span><b>Thường học cả Đại và Hình.</b> Phạm Đức Anh (Lớp 8) mới có dòng Đại số. Thêm dòng cho lớp Hình học? '
            '<a href="#" data-do="Đã thêm dòng trống cho Hình học 8 (cùng học sinh, cùng gói).">Thêm dòng Hình học</a> · <span class="hmt-help">chỉ nhắc, không chặn Trình duyệt.</span></span></div>')

def dh_kv(status_tag, paid, extra_r=None, approver=None, tot_=0, edit=False):
    items = [('Phụ huynh', link('%s · %s' % (PH_NAME, PH_CODE), 'Mở phụ huynh (màn KH-02).')), ('Cơ hội', link(DH['co'], 'Mở cơ hội (màn TS-13).')), ('Báo giá', link(DH['bg'], 'Mở báo giá (màn BH-02).')), ('Tình trạng', status_tag),
             ('Người lập · cơ sở', DH['sale'] + ' · CS1'), ('Điều khoản thanh toán', term_sel() if edit else TERMS[DH['term']][0])]
    if extra_r: items += [(re.sub(r'<[^>]+>', '', k), v) for k, v in extra_r]
    return kgrid(items)

def lich_rows(tong, paid, key):
    cfg = TERMS[key][1]; n = len(cfg); out = []; left = paid; amts = [int(round(tong * pc / 100.0)) for pc, _ in cfg]; amts[-1] = tong - sum(amts[:-1])
    for i, ((pc, dd), am) in enumerate(zip(cfg, amts)):
        got = min(left, am); left -= got
        out.append(('Đợt %d/%d' % (i + 1, n) + (' · đặt cọc' if i == 0 and n > 1 else ''), (BASE + datetime.timedelta(days=dd)).strftime('%d/%m/%Y'), pc, am, got))
    return out
def lich_dong_tien(tong, paid=0, key=None, editable=False):
    key = DH['term'] if key is None else key
    rows = []
    for dot, han, pc, am, got in lich_rows(tong, paid, key):
        st = tag('Đã đủ', 'success') if got >= am else (tag('Đã thu một phần', 'warning') if got > 0 else tag('Chưa thu'))
        rows.append([dot, '<span class="hmt-num">%s</span>' % han, '<span class="hmt-num">%d%%</span>' % pc, '<span class="hmt-num">%s</span>' % num(am), '<span class="hmt-num">%s</span>' % num(got), st])
    t = table([('Đợt', 0), ('Hạn đóng', 0), ('Tỉ lệ', 1), ('Số tiền (đ)', 1), ('Đã đóng (đ)', 1), ('Tình trạng', 0)], rows, cls='')
    return '<div data-sched>' + t + '</div><div class="hmt-help">Lịch tự tính từ <b>Điều khoản thanh toán</b> của đơn, chỉ đọc, không nhập tay. Dùng để theo dõi công nợ và nhắc hạn, không chặn học (R-TIEN-07). Đơn không chọn điều khoản thì thanh toán một lần.</div>'

def term_js(tong, paid):
    import json
    return r"""
const TERMS = %s; const TONG = %d, PAID = %d; const BASE = new Date(2026, 9, 10);
const fmt = n => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.'); const two = n => String(n).padStart(2, '0');
function renderSched() { const sel = q('[data-term]'); const tb = q('[data-sched] tbody'); if (!sel || !tb) return; const cfg = TERMS[sel.value]; const n = cfg.length; let left = PAID; let amts = cfg.map(c => Math.round(TONG * c[0] / 100)); amts[n - 1] = TONG - amts.slice(0, n - 1).reduce((a, b) => a + b, 0);
  tb.innerHTML = cfg.map((c, i) => { const got = Math.min(left, amts[i]); left -= got; const d = new Date(BASE.getTime() + c[1] * 86400000); const st = got >= amts[i] ? '<span class="hmt-tag hmt-tag-success">Đã đủ</span>' : got > 0 ? '<span class="hmt-tag hmt-tag-warning">Đã thu một phần</span>' : '<span class="hmt-tag">Chưa thu</span>';
    return '<tr><td>Đợt ' + (i + 1) + '/' + n + (i === 0 && n > 1 ? ' · đặt cọc' : '') + '</td><td><span class="hmt-num">' + two(d.getDate()) + '/' + two(d.getMonth() + 1) + '/' + d.getFullYear() + '</span></td><td class="r"><span class="hmt-num">' + c[0] + '%%</span></td><td class="r"><span class="hmt-num">' + fmt(amts[i]) + '</span></td><td class="r"><span class="hmt-num">' + fmt(got) + '</span></td><td>' + st + '</td></tr>'; }).join(''); }
ROOT.addEventListener('change', ev => { if (ev.target.matches && ev.target.matches('[data-term]')) { renderSched(); toast('Đã đổi điều khoản thanh toán: lịch đợt tự cập nhật ở tab Thanh toán.'); } });
""" % (json.dumps({k: [list(x) for x in v[1]] for k, v in TERMS.items()}), tong, paid)

PT_DATA = [('PT-CS1-2610-0015', '12/10/2026', 7000000, 'Chuyển khoản', 'Đã duyệt', 'success', 'Dòng 1 · Phạm Đức Anh · Đại số 8')]
def phieu_thu_tab(paid_rows):
    if not paid_rows:
        return '<div class="hmt-help">Chưa có phiếu thu. Đơn đã duyệt thì bấm <b>Tạo phiếu thu</b> để lập phiếu nháp.</div>'
    rows = [['<a href="#" data-do="Mở phiếu thu (màn TC-02).">%s</a>' % c, '<span class="hmt-num">%s</span>' % d, '<span class="hmt-num">%s</span>' % num(a), h, cn, tag(st, k)] for c, d, a, h, st, k, cn in paid_rows]
    return table([('Phiếu thu', 0), ('Ngày nhận', 0), ('Số tiền (đ)', 1), ('Hình thức', 0), ('Cấn vào', 0), ('Tình trạng', 0)], rows, cls='')

def ghidanh_tab(rows_in):
    if not rows_in: return '<div class="hmt-help">Chưa có ghi danh. Ghi danh sinh khi tiền đã vào đủ cọc tối thiểu 1.000.000 đ (mỗi dòng đơn một ghi danh).</div>'
    rows = [['<a href="#" data-do="Mở ghi danh (màn GD-02).">%s</a>' % c, n, l, '<span class="hmt-num">%s</span>' % g, tag(s, k)] for c, n, l, g, s, k in rows_in]
    return table([('Ghi danh', 0), ('Học sinh', 0), ('Lớp', 0), ('Giờ cấp', 1), ('Tình trạng', 0)], rows, cls='')

def chia(paid, can=0, ls=None):
    """Tiền cấn vào dòng can (chỉ số) trước, tối đa thành tiền dòng; phần thừa chia tỉ lệ thành tiền các dòng còn lại (R-TIEN-23). Trả [(tiền, giờ cấp)]."""
    ls = ls or [L1, L2, L3]; tt = [lt(l) for l in ls]; out = [0] * len(ls)
    if can is None:
        out = [paid * t / sum(tt) for t in tt]
    else:
        out[can] = min(paid, tt[can]); rest = paid - out[can]; others = [i for i in range(len(ls)) if i != can]; so = sum(tt[i] for i in others)
        for i in others: out[i] = rest * tt[i] / so
    return [(int(round(m)), ls[i][7] * m / tt[i]) for i, m in enumerate(out)]
def hh(x): return ('%.1f' % x).replace('.', ',').replace(',0', '')
CHIA7 = chia(7000000, 0)
GD_ROWS = [('GD000301', 'Phạm Đức Anh', 'CS1-2627-DAI-K08-CB-A-001', hh(CHIA7[0][1]), 'Đã xếp lớp', 'info'), ('GD000302', 'Phạm Đức Anh', 'CS1-2627-HINH-K08-CB-A-001', hh(CHIA7[1][1]), 'Đã xếp lớp', 'info'), ('GD000303', 'Phạm Khánh Vy', 'CS1-2627-ANH-K05-CB-B-002', hh(CHIA7[2][1]), 'Đã xếp lớp', 'info')]

def dh_chatter(state):
    ev = []
    ev.append(('10/10/2026', [sysmsg('10:02', 'Đơn nháp tạo từ báo giá %s.' % DH['bg'])]))
    if state in ('trinh', 'tran', 'duyet', 'duyet_ht', 'thu', 'tu_choi', 'huy'):
        ev[0][1].insert(0, sysmsg('10:40', 'Trình duyệt đơn cho Lê Văn Phong (Trưởng cơ sở).', chg=('Nháp', 'Đã trình')))
    if state == 'tu_choi':
        ev.insert(0, ('11/10/2026', [sysmsg('08:50', 'Lê Văn Phong từ chối. Lý do: Chiết khấu dòng 3 chưa có văn bản phê duyệt, nhập lại.', chg=('Đã trình', 'Nháp'))]))
    if state in ('duyet', 'duyet_ht', 'thu'):
        ev.insert(0, ('11/10/2026', [sysmsg('09:15', 'Lê Văn Phong duyệt đơn. Đơn tự khoá.', chg=('Đã trình', 'Đã duyệt'))]))
    if state == 'duyet_ht':
        ev.insert(0, ('12/10/2026', [sysmsg('11:00', 'Lê Văn Phong bật “Cho học trước, đóng tiền sau”: tối đa 2 buổi chưa đóng tiền.')]))
    if state == 'thu':
        ev.insert(0, ('12/10/2026', [sysmsg('15:30', 'Phiếu thu PT-CS1-2610-0015 (7.000.000 đ) được Kế toán duyệt. Sinh khoản tiền vào KTV-CS1-2610-0009 và ghi danh GD000301 đến GD000303.')]))
    if state == 'huy':
        ev.insert(0, ('11/10/2026', [sysmsg('17:00', 'Huỷ đơn. Lý do: Phụ huynh đổi kế hoạch học, chưa thu tiền.', chg=('Đã trình', 'Huỷ'))]))
    return chatter(ev)

def d_tu_choi_don():
    return ''

# ------------------ hộp thoại ------------------
def d_bh07(ls, tran):
    rows = [[l[0] + '<div class="hmt-help">%s</div>' % l[1], l[2] + ' · ' + l[3], '<span class="hmt-code">%s</span><div class="hmt-help">vào %s</div>' % (l[4], l[6]), '<span class="hmt-num">%d + %d</span>' % (l[7], l[8]),
             '<span class="hmt-num">%s%%</span>' % (('%.1f' % lpct(l)).replace('.', ',')) + (' ' + tag('Vượt trần', 'danger') if lpct(l) > 20 else ''), '<span class="hmt-num">%s</span>' % num(lt(l))] for l in ls]
    t = table([('Học sinh', 0), ('Gói · hình thức', 0), ('Lớp · ngày vào', 0), ('Giờ mua + tặng', 1), ('Chiết khấu cộng dồn', 1), ('Thành tiền (đ)', 1)], rows, cls='')
    al = alert('warning', '<b>Chiết khấu vượt trần 20%.</b> Dòng 3 (Phạm Khánh Vy): giảm 15% cộng giờ tặng 2/24 (8,3%) = 23,3%. Cần quản lý cơ sở duyệt (R-TIEN-29).') if tran else ''
    main = ('<div data-pane="main"><dl style="margin:0 0 var(--space-3);display:grid;grid-template-columns:auto 1fr auto 1fr;gap:6px 16px;font-size:13px"><dt class="hmt-help">Đơn</dt><dd style="margin:0">%s</dd><dt class="hmt-help">Người lập</dt><dd style="margin:0">%s</dd>'
            '<dt class="hmt-help">Phụ huynh</dt><dd style="margin:0">%s · %s</dd><dt class="hmt-help">Tổng thành tiền</dt><dd style="margin:0"><b class="hmt-num">%s</b></dd></dl>%s%s'
            '<p class="hmt-help" style="margin:var(--space-3) 0 0">Duyệt thì đơn tự khoá: không sửa dòng, giá, lớp, ngày vào nữa. Muốn đổi sau thì đi qua xếp lớp, chuyển lớp trên ghi danh.</p></div>') % (DH['code'], DH['sale'], PH_NAME, PH_CODE, money(tot(ls)), al, t)
    rej = ('<div data-pane="reject" style="display:none"><p class="hmt-help" style="margin:0 0 var(--space-3)">Đơn về Nháp, người lập sửa rồi trình lại. Lịch sử giữ lần từ chối và lý do.</p><label class="hmt-field"><span class="hmt-label">Lý do từ chối <span class="hmt-req">*</span></span>'
           '<textarea class="hmt-textarea" rows="3" placeholder="Nêu rõ dòng nào, cần sửa gì"></textarea></label></div>')
    foot = ('<span data-pane="main" style="display:contents">' + btn('Từ chối…', '', 'ban', 'data-pane-to="reject"') + btn('Duyệt', 'primary', 'check', 'data-dto="Đã duyệt đơn. Đơn tự khoá."') + '</span>'
            '<span data-pane="reject" style="display:none">' + btn('Quay lại', '', None, 'data-pane-to="main"') + btn('Xác nhận từ chối', 'danger', None, 'data-dto="Đã từ chối đơn, về Nháp."') + '</span>')
    return dialog('bh07', 'Duyệt hoặc từ chối đơn hàng', '<h2>Duyệt đơn hàng %s</h2>' % DH['code'], main + rej, foot, w=760)

def cls_row(code, ten, lich, gv, si, ok=True, why=None, sel=False):
    dis = ' aria-disabled="true" style="opacity:.55;cursor:not-allowed"' if not ok else ''
    return ('<label class="hmt-opt" style="display:flex;gap:10px;align-items:flex-start;padding:8px 10px;border:1px solid %s;border-radius:8px;margin-bottom:6px;%s"%s><input type="radio" name="lop" %s%s style="margin-top:3px">'
            '<span style="flex:1"><b class="hmt-code">%s</b> <span>%s</span><div class="hmt-help">%s · GV %s · sĩ số %s</div>%s</span></label>') % (
        'var(--brand-500,#e8590c)' if sel else 'var(--divider)', 'background:var(--brand-50);' if sel else '', dis, 'checked' if sel else '', '' if ok else 'disabled', code, ten, lich, gv, si,
        ('<div style="color:var(--danger-text);font-size:12px;margin-top:2px">%s</div>' % why) if why else '')

def d_bh08(state):
    head = '<h2>Chọn lớp và ngày vào lớp</h2>'
    ctx = ('<div style="display:flex;gap:var(--space-3);flex-wrap:wrap;font-size:13px;margin-bottom:var(--space-3)"><span>Dòng 1</span><b>Phạm Đức Anh (Lớp 8)</b><span class="hmt-tag">LC-TOAN-K08</span><span class="hmt-tag">Môn Đại số</span><span class="hmt-tag">Offline</span><span class="hmt-tag">CS1</span></div>')
    foot = btn('Đóng', '', None, 'data-close="1"') + btn('Chọn', 'primary', None, 'data-dto="Đã chọn lớp và ngày vào lớp cho dòng 1."' + (' disabled' if state in ('tai', 'trong', 'chua_buoi') else ''))
    if state == 'tai':
        body = SK_CSS + ctx + ''.join('<div style="display:flex;gap:10px;padding:10px;border:1px solid var(--divider);border-radius:8px;margin-bottom:6px">' + sk(16, 16, 8) + '<div style="flex:1;display:flex;flex-direction:column;gap:6px">' + sk('50%', 14) + sk('80%', 12) + '</div></div>' for _ in range(3))
        return dialog('bh08', 'Chọn lớp', head, '<div aria-busy="true">' + body + '</div>', foot, w=640)
    if state == 'trong':
        body = ctx + empty_inline('Không có lớp phù hợp', 'Chưa có lớp Đại số 8 đã duyệt, còn chỗ ở CS1. Có thể bỏ trống lớp: ghi danh sẽ ở Chờ xếp lớp, vận hành xếp sau (R-GD-06). Đã ẩn 2 lớp vì đủ sĩ số.')
        return dialog('bh08', 'Chọn lớp', head, body, btn('Đóng', '', None, 'data-close="1"') + btn('Để trống lớp', '', None, 'data-dto="Dòng 1 để trống lớp, ghi danh sẽ ở Chờ xếp lớp."'), w=640)
    if state == 'luan_phien':
        ctx2 = ('<div style="display:flex;gap:var(--space-3);flex-wrap:wrap;font-size:13px;margin-bottom:var(--space-3)"><span>Dòng 2</span><b>Phạm Đức Anh (Lớp 8)</b><span class="hmt-tag">LC-TOAN-K08</span><span class="hmt-tag">Môn Hình học</span><span class="hmt-tag">Offline</span><span class="hmt-tag">CS1</span>'
                '<span class="hmt-help">· dòng 1 đã chọn Đại số 8 cơ bản A (Thứ 3 18:00–19:30, lặp mỗi 2 tuần, buổi đầu 03/11/2026)</span></div>')
        lops2 = (cls_row('CS1-2627-HINH-K08-CB-A-003', 'Hình học 8 cơ bản A <span class="hmt-tag hmt-tag-info">Nhóm 8M1</span>', 'Thứ 3 18:00–19:30 · lặp mỗi 2 tuần, buổi đầu 10/11/2026', 'Nguyễn Văn Nam', '12/20', True, None, True) +
                 '<div class="hmt-alert hmt-alert-info" role="status" style="margin:-2px 0 6px">' + SVG(IC['check']) + '<span>Cùng thứ, giờ, phòng với Đại số 8 cơ bản A nhưng <b>luân phiên</b>: Đại học 03/11, 17/11, 01/12…; Hình học học 10/11, 24/11, 08/12…. Không có buổi nào trùng nên chọn được cùng lúc.</span></div>' +
                 cls_row('CS1-2627-HINH-K08-CB-B-004', 'Hình học 8 cơ bản B', 'Thứ 3 18:00–19:30 · lặp hàng tuần, buổi đầu 03/11/2026', 'Lê Thu Trang', '9/20', False, 'Trùng buổi 03/11/2026, 18:00–19:30 với lớp CS1-2627-DAI-K08-CB-A-001 (dòng 1 của đơn này).') +
                 cls_row('CS1-2627-HINH-K08-CB-C-005', 'Hình học 8 cơ bản C', 'Thứ 6 18:00–19:30 · lặp hàng tuần', 'Trần Minh Đức', '15/20'))
        left2 = '<div style="flex:1 1 55%">' + sec('LỚP PHÙ HỢP (3)') + lops2 + '<div class="hmt-help">Chỉ hiện lớp đã duyệt, còn chỗ, đúng môn, khối, cơ sở. Trùng giờ được xét theo từng buổi thật, nên lớp luân phiên không báo trùng (R-GD-15).</div></div>'
        right2 = '<div style="flex:1 1 45%">' + sec('NGÀY VÀO LỚP · BUỔI SẮP TỚI') + ''.join(
            '<label class="hmt-opt" style="display:flex;gap:8px;align-items:center;padding:6px 8px"><input type="radio" name="buoi" %s><span><b>%s</b> · %s <span class="hmt-help">Buổi %d</span></span></label>' % ('checked' if i == 0 else '', d, w, n) for i, (d, w, n) in enumerate([('10/11/2026', 'Thứ 3', 1), ('24/11/2026', 'Thứ 3', 2), ('08/12/2026', 'Thứ 3', 3), ('22/12/2026', 'Thứ 3', 4)])) + '<div class="hmt-help" style="margin-top:var(--space-2)">Lớp luân phiên chỉ có buổi mỗi 2 tuần.</div></div>'
        return dialog('bh08', 'Chọn lớp', head, ctx2 + '<div style="display:flex;gap:var(--space-5)">' + left2 + right2 + '</div>', btn('Đóng', '', None, 'data-close="1"') + btn('Chọn', 'primary', None, 'data-dto="Đã chọn lớp Hình học luân phiên cho dòng 2."'), w=860)
    lops = (cls_row('CS1-2627-DAI-K08-CB-A-001', 'Đại số 8 cơ bản A', 'Thứ 3, Thứ 5 18:00–19:30', 'Nguyễn Văn Nam', '14/20', True, None, True) +
            cls_row('CS1-2627-DAI-K08-CB-B-002', 'Đại số 8 cơ bản B', 'Thứ 2, Thứ 4 19:30–21:00', 'Lê Thu Trang', '9/20') +
            cls_row('CS1-2627-DAI-K08-NC-S-003', 'Đại số 8 nâng cao', 'Thứ 3, Thứ 5 18:30–20:00', 'Nguyễn Văn Nam', '11/15', False, 'Trùng buổi 03/11/2026, 18:30–20:00 với lớp CS1-2627-ANH-K08-CB-B-004 mà Phạm Đức Anh đang học (xét theo từng buổi thật).'))
    left = '<div style="flex:1 1 55%">' + sec('LỚP PHÙ HỢP (3)') + lops + '<div class="hmt-help">Chỉ hiện lớp đã duyệt, còn chỗ, đúng môn, khối, cơ sở. Lớp trùng buổi hiện nhưng không chọn được, lý do ghi theo buổi thật. Đã ẩn 1 lớp đủ sĩ số.</div></div>'
    if state == 'co_buoi':
        right = '<div style="flex:1 1 45%">' + sec('NGÀY VÀO LỚP · BUỔI SẮP TỚI') + ''.join(
            '<label class="hmt-opt" style="display:flex;gap:8px;align-items:center;padding:6px 8px"><input type="radio" name="buoi" %s><span><b>%s</b> · %s <span class="hmt-help">Buổi %d</span></span></label>' % ('checked' if i == 0 else '', d, w, n) for i, (d, w, n) in enumerate([('03/11/2026', 'Thứ 3', 9), ('05/11/2026', 'Thứ 5', 10), ('10/11/2026', 'Thứ 3', 11), ('12/11/2026', 'Thứ 5', 12)])) + \
            '<div class="hmt-help" style="margin-top:var(--space-2)">Lớp đã có buổi: chọn từ danh sách buổi sắp tới (R-GD-06).</div></div>'
    else:
        right = ('<div style="flex:1 1 45%%">' + sec('NGÀY VÀO LỚP') + '<label class="hmt-field"><span class="hmt-label">Ngày vào lớp <span class="hmt-req">*</span></span><input class="hmt-input hmt-input-err" value="15/11/2026" aria-invalid="true" style="width:160px"><span class="ix-err">15/11/2026 là Chủ nhật. Lớp này chỉ học Thứ 3, Thứ 5.</span></label>'
                 '<div class="hmt-help" style="margin-top:var(--space-2)">Lớp khai giảng 17/11/2026, chưa có buổi: nhập ngày đúng thứ có lịch, không trước ngày khai giảng.</div></div>')
        left = left.replace('Đại số 8 cơ bản A', 'Đại số 8 cơ bản A <span class="hmt-tag hmt-tag-info">Khai giảng 17/11</span>')
    return dialog('bh08', 'Chọn lớp', head, ctx + '<div style="display:flex;gap:var(--space-5)">' + left + right + '</div>', foot, w=820)

def empty_inline(t, sub):
    return '<div style="display:flex;flex-direction:column;align-items:center;gap:8px;padding:28px 12px;text-align:center"><span style="color:var(--text-secondary)">%s</span><b>%s</b><span class="hmt-help" style="max-width:440px">%s</span></div>' % (SVG(IC['search'], 'hmt-ic hmt-ic-lg'), t, sub)

def d_bh09():
    body = ('<dl style="margin:0 0 var(--space-3);display:grid;grid-template-columns:auto 1fr;gap:6px 16px;font-size:13px"><dt class="hmt-help">Đơn</dt><dd style="margin:0">%s · đã duyệt, chưa thu tiền</dd><dt class="hmt-help">Học sinh</dt><dd style="margin:0">Phạm Đức Anh, Phạm Khánh Vy</dd><dt class="hmt-help">Hạn mức</dt><dd style="margin:0"><b>2 buổi</b> chưa đóng tiền <span class="hmt-help">(theo cấu hình hệ thống)</span></dd></dl>'
            '<ul style="margin:0;padding-left:18px;font-size:13px;display:flex;flex-direction:column;gap:4px"><li>Ghi danh tạo sớm, quỹ giờ được phép âm đến hạn mức.</li><li>Quá hạn mức: học sinh bị loại khỏi danh sách các buổi sau, kèm cảnh báo cho vận hành và sale.</li><li>Khi thu tiền, các buổi đã học vẫn tính là đã học và trừ vào giờ được cấp.</li></ul>') % DH['code']
    return dialog('bh09', 'Cho học trước, đóng tiền sau', '<h2>Cho học trước, đóng tiền sau</h2>', body, btn('Đóng', '', None, 'data-close="1"') + btn('Bật', 'primary', None, 'data-dto="Đã bật cho học trước. Ghi danh tạo sớm."'), w=560)

def d_tc03(ls, remain):
    opts = '<option>(để trống) chia tỉ lệ theo thành tiền các dòng</option>' + ''.join('<option>Dòng %d · %s · %s</option>' % (i + 1, l[0], l[4]) for i, l in enumerate(ls))
    body = ('<dl style="margin:0 0 var(--space-3);display:grid;grid-template-columns:auto 1fr;gap:6px 16px;font-size:13px"><dt class="hmt-help">Đơn</dt><dd style="margin:0">%s · tổng %s · còn lại <b>%s</b></dd></dl>'
            '<label class="hmt-field"><span class="hmt-label">Số tiền <span class="hmt-req">*</span></span><input class="hmt-input" style="width:180px;text-align:right" value="%s"><span class="hmt-help">gợi ý = số còn lại của đơn, sửa được</span></label>'
            '<label class="hmt-field" style="margin-top:var(--space-3)"><span class="hmt-label">Cấn vào dòng</span><select class="hmt-input hmt-select" style="width:100%%">%s</select>'
            '<span class="hmt-help">Tiền cấn vào dòng được chọn trước, tối đa bằng thành tiền dòng; phần thừa chia tỉ lệ cho các dòng khác. Khoá lựa chọn khi phiếu rời Nháp.</span></label>') % (DH['code'], money(tot(ls)), money(remain), num(remain), opts)
    return dialog('tc03', 'Tạo phiếu thu từ đơn hàng', '<h2>Tạo phiếu thu</h2>', body, btn('Đóng', '', None, 'data-close="1"') + btn('Tạo nháp', 'primary', None, 'data-dto="Đã tạo phiếu thu nháp PT-CS1-2610-0016, mở phiếu (màn TC-02)."'), w=560)

# ------------------ trang đơn hàng ------------------
def build_dh(state, extra_dlg=None, show0='', user=None, title_suffix=None, bh08_state='co_buoi', title_over=None):
    T = {'nhap': 'Nháp (có nhắc Đại và Hình)', 'nhap_loi': 'Nháp (trình bị chặn: báo đúng dòng, ô thiếu)', 'trinh': 'Đã trình (chờ duyệt)', 'tran': 'Đã trình, chiết khấu vượt trần (Quản lý duyệt)', 'tu_choi': 'Bị từ chối (về Nháp)',
         'duyet': 'Đã duyệt (khoá)', 'duyet_ht': 'Đã duyệt, cho học trước', 'thu': 'Đã duyệt, đã có phiếu thu và ghi danh', 'huy': 'Huỷ', 'tai': 'Đang tải', 'quyen': 'Không có quyền'}[state]
    title = title_over or ('BH-05 · Đơn hàng · ' + T)
    crumb = [('Bán hàng &amp; thu chi', False), ('Đơn hàng', False), (DH['code'], True)]
    if state == 'quyen': return noperm_page(title, 'đơn hàng')
    if state == 'tai': return loading_page(title, 'Đơn hàng', 'sa', crumb[:2] + [('Đang tải…', True)], 'Đơn hàng')
    u = user or {'trinh': 'sa', 'tran': 'bm', 'duyet': 'sa', 'duyet_ht': 'bm', 'thu': 'sa'}.get(state, 'sa')
    full = [L1, L2, L3]
    ls_nhap = [L1, L3]
    lines = {'nhap': ls_nhap, 'nhap_loi': [L1, L3[:4] + (None, None) + L3[6:]], 'tu_choi': full, 'tran': [L1, L2, L3_TRAN]}.get(state, full)
    edit = state in ('nhap', 'nhap_loi', 'tu_choi')
    # dòng chưa chọn lớp
    if state == 'nhap_loi':
        l3 = ('Phạm Khánh Vy', 'HS000127', 'LC-ANH-K05', 'Offline', '', '', '', 24, 2, 180000, 5); lines = [L1, l3]
    paid = 7000000 if state == 'thu' else 0
    stg_steps = ['Nháp', 'Đã trình', 'Đã duyệt']
    cur = {'nhap': 0, 'nhap_loi': 0, 'tu_choi': 0, 'trinh': 1, 'tran': 1, 'duyet': 2, 'duyet_ht': 2, 'thu': 2, 'huy': None}[state]
    br = None; note = None
    if state == 'huy': stg = stage(stg_steps, 1, branches=[('Huỷ', 'danger')], note='đơn đã huỷ, chỉ còn xem')
    elif state == 'tu_choi': stg = stage(stg_steps, 0, branches=[('Từ chối', 'danger')], note='bị từ chối thì về Nháp, sửa rồi trình lại')
    elif cur == 2: stg = stage(stg_steps, 2, note='đơn đã khoá; sửa sau này đi qua xếp lớp, chuyển lớp trên ghi danh'); stg = stg.replace('<button class="hmt-step" type="button" aria-current="step">Đã duyệt</button>', '<button class="hmt-step" type="button" aria-current="step">%sĐã duyệt</button>' % SVG(IC['lock']))
    else: stg = stage(stg_steps, cur)
    tag_map = {'nhap': tag('Nháp'), 'nhap_loi': tag('Nháp'), 'tu_choi': tag('Nháp · bị từ chối', 'danger'), 'trinh': tag('Đã trình', 'info'), 'tran': tag('Đã trình', 'info'), 'duyet': tag('Đã duyệt · khoá', 'success'), 'duyet_ht': tag('Đã duyệt · khoá', 'success'), 'thu': tag('Đã duyệt · khoá', 'success'), 'huy': tag('Huỷ', 'danger')}
    ex = [('Tiền đã vào', '<b class="hmt-num">%s</b>' % money(paid)), ('Còn lại', '<b class="hmt-num">%s</b>' % money(tot(lines) - paid))]
    if state in ('duyet', 'duyet_ht', 'thu'): ex.append(('Người duyệt', 'Lê Văn Phong · 11/10/2026'))
    if state == 'duyet_ht': ex.append(('Cho học trước', tag('Đang bật', 'warning') + ' tối đa 2 buổi'))
    if state == 'tu_choi': ex.append(('Lý do từ chối', 'Chiết khấu dòng 3 chưa có văn bản phê duyệt, nhập lại.'))
    if state == 'huy': ex.append(('Lý do huỷ', 'Phụ huynh đổi kế hoạch học, chưa thu tiền.'))
    kvh = dh_kv(tag_map[state], paid, ex, edit=edit)
    al = ''
    if state == 'nhap_loi': al = alert('danger', '<b>Chưa trình được.</b> Dòng 2 (Phạm Khánh Vy · LC-ANH-K05): chưa chọn lớp, chưa có ngày vào lớp. Chọn lớp rồi trình lại.')
    if state == 'tu_choi': al = alert('danger', '<b>Đơn bị từ chối.</b> Lê Văn Phong, 11/10/2026: “Chiết khấu dòng 3 chưa có văn bản phê duyệt, nhập lại.” Sửa rồi bấm Trình lại.')
    if state == 'tran': al = alert('warning', '<b>Chiết khấu vượt trần 20%.</b> Dòng 3 cộng dồn 23,3% (giảm 15% + tặng 2/24 giờ). Quản lý cơ sở xem xét rồi Duyệt hoặc Từ chối.')
    if state == 'trinh': al = alert('info', 'Đơn đã trình, chờ quản lý cơ sở duyệt. Trong lúc chờ không sửa được dòng.', 'lock')
    if state == 'thu': al = alert('info', 'Đã có phiếu thu duyệt 7.000.000 đ (đủ cọc tối thiểu 1.000.000 đ): đã sinh ba ghi danh (mỗi dòng đơn một ghi danh). Giờ cấp theo tỉ lệ tiền đã chia cho từng dòng; giờ tặng chỉ cấp khi đơn thu đủ.', 'check')
    if state == 'duyet_ht': al = alert('warning', 'Đang cho học trước, đóng tiền sau: ghi danh tạo sớm, quỹ giờ được âm tối đa 2 buổi.', 'alert')
    tabs_lines = (al + (reminder() if state == 'nhap' else '') + lines_table(lines, 'edit' if edit else 'lock', miss={1: 'lop'} if state == 'nhap_loi' else None) + total_bar(lines, paid,
                  ('<span class="hmt-help" style="margin-right:auto">Chiết khấu cộng dồn không quá 20%; giờ tặng quy ra % tính vào trần.</span>' if edit else '')))
    panels = [('Dòng đơn (%d)' % len(lines), tabs_lines), ('Thanh toán', sec('LỊCH ĐÓNG TIỀN TỪNG ĐỢT (tự tính, chỉ đọc)') + lich_dong_tien(tot(lines), paid) + sec('PHIẾU THU') + phieu_thu_tab(PT_DATA if state == 'thu' else [])),
              ('Ghi danh%s' % (' (3)' if state == 'thu' else ''), ghidanh_tab(GD_ROWS if state == 'thu' else []))]
    sh = sheet2('Đơn hàng <span class="hmt-code">%s</span> <span class="hmt-help">mã cũ %s</span>' % (DH['code'], DH['old']), kvh, panels)
    # nút
    PRN = None
    bt = {'nhap': [btn('Trình duyệt', 'primary', 'send', 'data-do="Đã trình. Kiểm tra từng dòng đều đủ."'), btn('Lưu', '', 'check', 'data-do="Đã lưu đơn nháp."')],
          'nhap_loi': [btn('Trình duyệt', 'primary', 'send', 'data-do="Chưa trình được: dòng 2 thiếu lớp và ngày vào lớp."'), btn('Lưu', '', 'check', 'data-do="Đã lưu đơn nháp."')],
          'tu_choi': [btn('Sửa và trình lại', 'primary', 'send', 'data-do="Đã trình lại đơn, lần từ chối được giữ trong lịch sử."')],
          'trinh': [], 'tran': [btn('Duyệt', 'primary', 'check', 'data-open="bh07"'), btn('Từ chối', '', 'ban', 'data-open="bh07" data-pane-to="reject"')],
          'duyet': [btn('Tạo phiếu thu', 'primary', 'wallet', 'data-open="tc03"'), btn('Cho học trước', '', 'cal', 'data-open="bh09"')],
          'duyet_ht': [btn('Tạo phiếu thu', 'primary', 'wallet', 'data-open="tc03"'), btn('Tắt học trước', '', 'ban', 'data-do="Đã tắt cho học trước."')],
          'thu': [btn('Tạo phiếu thu', 'primary', 'wallet', 'data-open="tc03"')], 'huy': []}[state]
    menu_items = {'nhap': [('Huỷ đơn', 'ban', 'data-do="Mở hộp Huỷ đơn có lý do (màn BH-10)."')], 'nhap_loi': [('Huỷ đơn', 'ban', 'data-do="Mở hộp Huỷ đơn có lý do (màn BH-10)."')], 'tu_choi': [('Huỷ đơn', 'ban', 'data-do="Mở hộp Huỷ đơn có lý do (màn BH-10)."')],
                  'trinh': [('Huỷ đơn', 'ban', 'data-do="Mở hộp Huỷ đơn có lý do (màn BH-10)."')], 'tran': [], 'duyet': [('Huỷ đơn', 'ban', 'data-do="Mở hộp Huỷ đơn có lý do (màn BH-10)."')], 'duyet_ht': [],
                  'thu': [('Huỷ đơn (đã có tiền: đi qua ticket hoàn tiền)', 'ban', 'data-do="Đơn đã có tiền: không huỷ trực tiếp, lập ticket đề nghị Hoàn tiền (màn CS-05)." aria-disabled="true" style="opacity:.55"')], 'huy': []}[state]
    smt = smart([('Cơ hội', 1), ('Báo giá', 1), ('Phiếu thu', 1 if state == 'thu' else 0), ('Ghi danh', 3 if state == 'thu' else 0)])
    dl = d_bh08('co_buoi') if False else ''
    dlgs = d_bh08(bh08_state) + d_bh07(lines if state != 'nhap' else full, state == 'tran') + d_bh09() + d_tc03(lines, tot(lines) - paid) + (extra_dlg or '')
    # nếu cần bản BH-08 khác, truyền extra_dlg và show0
    t = page(title, 'Đơn hàng', u, crumb, rbar_l('Đơn hàng', bt, menu_items or None), smt + stg + sh, dh_chatter({'nhap': 'nhap', 'nhap_loi': 'nhap'}.get(state, state)), pager='4 / 52', dlgs=dlgs, show0=show0, extra_js=term_js(tot(lines), paid))
    return t

BOARDS = []
def run():
    for st in ('nhap', 'nhap_loi', 'trinh', 'tran', 'tu_choi', 'duyet', 'duyet_ht', 'thu', 'huy', 'tai', 'quyen'):
        wr('BH05_' + st, build_dh(st)); BOARDS.append('BH05_' + st)
    for st, lab in (('co_buoi', 'Lớp đã có buổi'), ('chua_buoi', 'Lớp chưa có buổi, ngày sai thứ'), ('trong', 'Không có lớp phù hợp'), ('tai', 'Đang tải'), ('luan_phien', 'Lớp Đại, Hình luân phiên: chọn được, không báo trùng')):
        wr('BH08_' + st, build_dh('nhap', show0='bh08', bh08_state=st, title_over='BH-08 · Chọn lớp và ngày vào lớp · ' + lab)); BOARDS.append('BH08_' + st)
    wr('BH07_duyet', build_dh('tran', show0='bh07', title_over='BH-07 · Duyệt hoặc từ chối đơn hàng (máy tính)')); BOARDS.append('BH07_duyet')
    wr('BH09_bat', build_dh('duyet', show0='bh09', user='bm', title_over='BH-09 · Bật cho học trước, đóng tiền sau')); BOARDS.append('BH09_bat')
    return BOARDS
if __name__ == '__main__':
    print(' '.join(run()))
