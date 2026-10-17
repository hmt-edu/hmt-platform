# -*- coding: utf-8 -*-
# P5a: danh sách (K03 = TS07_K1) dùng chung cho BH-01, BH-06, TC-01, TC-04, TC-08, TC-10, TC-13
import sys, re, json; sys.path.insert(0, 'scripts')
from p5a_common import *
import kh_common as K
from kh_common import SK_CSS, sk, empty_box, inject, replace_cfg, retitle

CHK_TH = '<th style="width:40px"><label class="hmt-hit"><input type="checkbox" aria-label="Chọn tất cả"></label></th>'
def chk(c): return '<td><label class="hmt-hit"><input type="checkbox" aria-label="Chọn %s"></label></td>' % c

def cfg_js(c):
    favs = ','.join("{n:'%s',shared:%s,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:%s}}" % (n, 'true' if sh else 'false', fx) for n, sh, fx in c['favs'])
    tf = ','.join("{n:'%s',col:'%s'}" % (n, col) for n, col in c['tfields'])
    gf = ','.join("{n:'%s',col:'%s'%s}" % (n, col, ',gb:false' if nb else '') for n, col, nb in c['gfields'])
    fl = ','.join("{g:'%s', items:[%s]}" % (g, ','.join("['%s','%s']" % (a, b) for a, b in items)) for g, items in c['filters'])
    return ("const CFG = { layout2:true, stage:'free', noun:'%s', pcol:'Mã',\n  tfields:[%s],\n  favs:[%s],\n  gfields:[%s], filters:[%s], link:'%s', views:{},\n  toasts:%s };" % (c['noun'], tf, favs, gf, fl, c['link'], c['toasts']))

def build_list(c, state, role):
    c = dict(c)
    s = K.read('TS07_K1.dc.html')
    s = sidebar_bh(s, c['nav'], c.get('group', 3), hide=(state == 'quyen'))
    s = K.crumb(s, c['crumb'])
    s = K.user(s, *USERS['gv' if state == 'quyen' else role][:2], USERS['gv' if state == 'quyen' else role][2])
    s = s.replace('<h1>Cơ hội</h1>', '<h1>%s</h1>' % c['h1'], 1)
    s = re.sub(r'<button class="hmt-btn " type="button"><svg[^>]*>(?:(?!</svg>).)*</svg>Nhập</button>', '', s, count=1, flags=re.S)
    s = re.sub(r'<span class="hmt-vsep"></span><div class="hmt-seg hmt-seg-ic".*?</div>', '', s, count=1, flags=re.S)
    s = re.sub(r'<button class="hmt-btn hmt-btn-primary" type="button"><svg[^>]*>(?:(?!</svg>).)*</svg>Tạo</button>', '', s, count=1, flags=re.S)
    if role not in c.get('export', ('kt', 'bm', 'ad')):
        s = re.sub(r'<button class="hmt-btn " type="button"><svg[^>]*>(?:(?!</svg>).)*</svg>Xuất</button>', '', s, count=1, flags=re.S)
    s = s.replace('placeholder="Tìm tên, SĐT, mã (cả mã cũ)…"', 'placeholder="%s"' % c['ph'], 1)
    i = s.index('<div class="hmt-fbar" aria-label="Lọc nhanh"'); s, _ = remove_div(s, i)
    i = s.index('<div class="hmt-fbar" style="background:var(--brand-50)'); s, _ = remove_div(s, i)
    ta = s.index('<div class="hmt-table-wrap">'); s2, tw = remove_div(s, ta)
    rows = ''.join('<tr>' + ('' if c.get('nochk') else chk(re.sub('<[^>]+>', '', r[0]))) + ''.join('<td%s>%s</td>' % (' class="r"' if c['heads'][j][1] else '', cell) for j, cell in enumerate(r)) + '</tr>' for r in c['rows'])
    thead = ('' if c.get('nochk') else CHK_TH) + ''.join('<th%s>%s</th>' % (' class="r"' if r else '', h) for h, r in c['heads'])
    table_html = '<div class="hmt-table-wrap"><table class="hmt-table"><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (thead, rows)
    s = s2[:ta] + table_html + s2[ta:]
    n = len(c['rows'])
    s = s.replace('1–8 / 8', '1–%d / %d' % (n, c['total']), 1)
    i = s.index('<div class="hmt-scrim"'); s, _ = remove_div(s, i)
    s = s[:i] + '<div class="hmt-scrim" style="position:absolute;inset:0;z-index:50;align-items:center;padding:0;gap:var(--space-6);display:none"><div class="hmt-dialog" role="dialog" aria-label="—" style="width:460px;flex:0 0 460px"><div class="hmt-dialog-h">—</div><div class="hmt-dialog-b"></div></div></div>' + s[i:]
    s = replace_cfg(s, cfg_js(c))
    s = s.replace("GBF.slice().sort(", "GBF.filter(f => f.gb !== false).slice().sort(")
    old = "em.className = 'ix-empty hmt-help'; em.style.padding = '24px'; em.style.textAlign = 'center'; em.textContent = 'Không có bản ghi nào khớp bộ lọc.';"
    assert old in s
    new = ("em.className = 'ix-empty'; em.style.cssText = 'display:flex;flex-direction:column;align-items:center;gap:10px;padding:40px 20px;text-align:center'; "
           "const tq = sb && sb.value.trim(); em.innerHTML = '<span style=\"color:var(--text-secondary)\">" + SVG(IC['search'], 'hmt-ic hmt-ic-lg').replace("'", "\\'") + "</span><b style=\"color:var(--text-primary);font-size:15px\">Không tìm thấy " + c['noun'] + " nào</b>"
           "<span class=\"hmt-help\" style=\"max-width:460px\">' + (tq ? 'Không có kết quả cho “' + tq + '”. ' : 'Không có bản ghi nào khớp bộ lọc. ') + '" + c['hint'] + "</span><button class=\"hmt-btn\" type=\"button\" data-clearall>Xoá tìm kiếm và bộ lọc</button>';")
    s = s.replace(old, new)
    title = c['code'] + ' · ' + c['h1'] + ' · danh sách'
    a = s.index('<div class="bgblur"')
    rest = s[a:]; rest_wo, bg = remove_div(rest, 0)
    if state == 'tai':
        t = bg.index('<div class="hmt-toolbar">'); head = bg[:t]
        head = head.replace('<button class="hmt-btn hmt-btn-primary" type="button">', '<button class="hmt-btn hmt-btn-primary" type="button" disabled>').replace('<button class="hmt-btn " type="button">', '<button class="hmt-btn " type="button" disabled>')
        rows_sk = ''.join('<div style="display:flex;gap:14px;align-items:center;padding:12px 16px;border-top:1px solid var(--bg-subtle)">' + sk(16, 16) + sk(120, 14) + sk(170, 14) + sk(110, 14) + sk(70, 14) + sk(80, 14) + '<span style="flex:1"></span>' + sk(80, 14) + '</div>' for _ in range(8))
        body = (SK_CSS + '<div class="hmt-content" aria-busy="true" aria-label="Đang tải"><div class="hmt-box" style="overflow:hidden;margin:var(--space-4)"><div style="padding:12px 16px;display:flex;gap:10px">' + sk(240, 28) + sk(80, 28) + sk(90, 28) + sk(90, 28) + '</div>'
                '<div style="display:flex;gap:14px;align-items:center;padding:10px 16px;border-top:1px solid var(--divider);background:var(--bg-subtle)">' + sk(16, 14) + sk(60, 12) + sk(120, 12) + sk(80, 12) + sk(60, 12) + '</div>' + rows_sk + '</div></div>')
        bg = head + body + '</div></div></div>'; title += ' (đang tải)'
    elif state == 'trong':
        cc = bg.index('<div class="hmt-content">')
        bg = bg[:cc] + '<div class="hmt-content">' + empty_box(c['eicon'], c['etitle'], c['esub'], None) + '</div></div></div></div>'
        bg = bg.replace('1–%d / %d' % (n, c['total']), '0 / 0'); title += ' (trống)'
    elif state == 'quyen':
        h = bg.index('<div class="hmt-header">')
        box = ('<div class="hmt-content"><div class="hmt-box hmt-empty" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:48px 20px;text-align:center;min-height:420px;margin:var(--space-6) auto;max-width:560px">'
               '<span style="color:var(--text-secondary)">' + SVG(IC['lock'], 'hmt-ic hmt-ic-lg') + '</span><b style="color:var(--text-primary);font-size:16px;font-family:var(--font-heading)">Bạn không có quyền xem %s</b>'
               '<span class="hmt-help" style="max-width:420px">Vai trò Giáo viên chưa được cấp quyền xem phân hệ Bán hàng và thu chi. Nếu cần xem, hãy liên hệ quản trị viên của trung tâm.</span>'
               '<button class="hmt-btn hmt-btn-primary" type="button" data-act="home">Về trang chủ</button></div></div>') % c['noun']
        bg = bg[:h] + box + '</div></div></div>'; title += ' (không có quyền)'
    s = s[:a] + bg + rest_wo
    dj = (P5_LJS % {'dlgs': json.dumps(c.get('dlgs', ''), ensure_ascii=False), 'show0': json.dumps(c.get('show0', ''))}) if c.get('dlgs') else ''
    js = dj + ("const _go = ev => { const b = ev.target.closest && ev.target.closest('button[data-act]'); if (!b) return; ev.stopPropagation(); ev.preventDefault(); toast('Về trang chủ theo vai trò (CHUNG-14).'); };\nROOT.addEventListener('click', _go, true);\n" + c.get('js', ''))
    return inject(s, title, js)

def run_list(c, pre, role='bm', extra=()):
    out = []
    for st, suf, r in (('normal', '', role), ('trong', '_trong', role), ('tai', '_tai', role), ('quyen', '_khong_quyen', role)) + tuple(extra):
        wr(pre + suf, build_list(c, st, r)); out.append(pre + suf)
    return out

def L(t, do=None): return '<a href="#">%s</a>' % t
def N(t): return '<span class="hmt-num">%s</span>' % t
def C(t): return '<span class="hmt-code">%s</span>' % t
def M(n): return N(num(n))

# ---------------- BH-01 Báo giá ----------------
BG_ST = {'Nháp': '', 'Đã gửi': 'info', 'Đã chuyển đơn': 'success', 'Từ chối': 'danger', 'Hết hạn': 'warning'}
BG = [('BG-CS1-2610-0007', 'Phạm Thu Hương', 'CO000142', 'CS1', 13608000, '24/10/2026', 'Đã gửi', 'Trần Thu Hà'), ('BG-CS1-2610-0006', 'Trần Thị Hà', 'CO000139', 'CS1', 9504000, '22/10/2026', 'Đã chuyển đơn', 'Trần Thu Hà'),
      ('BG-CS1-2610-0005', 'Nguyễn Văn Long', 'CO000131', 'CS1', 5280000, '—', 'Nháp', 'Nguyễn Thị Lan'), ('BG-CS2-2610-0004', 'Trần Quốc Hưng', 'CO000127', 'CS2', 7920000, '15/10/2026', 'Hết hạn', 'Hoàng Mai Anh'),
      ('BG-CS2-2610-0003', 'Đỗ Ngọc Bích', 'CO000120', 'CS2', 14256000, '19/10/2026', 'Đã gửi', 'Hoàng Mai Anh'), ('BG-CS4-2610-0002', 'Bùi Thanh Thuỷ', 'CO000118', 'CS4', 6336000, '—', 'Từ chối', 'Vũ Đức Minh'),
      ('BG-CS5-2610-0002', 'Vũ Thị Mai', 'CO000114', 'CS5', 9504000, '28/10/2026', 'Đã gửi', 'Lê Thanh Hà'), ('BG-CS1-2610-0004', 'Hoàng Văn Đức', 'CO000110', 'CS1', 4752000, '—', 'Nháp', 'Trần Thu Hà'),
      ('BG-CS4-2610-0001', 'Lê Minh Tuấn', 'CO000105', 'CS4', 11088000, '20/10/2026', 'Đã chuyển đơn', 'Vũ Đức Minh'), ('BG-CS5-2610-0001', 'Ngô Hồng Nhung', 'CO000101', 'CS5', 3960000, '12/10/2026', 'Hết hạn', 'Lê Thanh Hà')]
def cfg_bg():
    return dict(code='BH-01', h1='Báo giá', nav='Báo giá', crumb=[('Bán hàng &amp; thu chi', False), ('Báo giá', True)], ph='Tìm mã báo giá, phụ huynh, mã cơ hội…', noun='báo giá', total=86,
        heads=[('Mã', 0), ('Phụ huynh', 0), ('Cơ hội', 0), ('Cơ sở', 0), ('Tổng tiền (đ)', 1), ('Hạn hiệu lực', 0), ('Tình trạng', 0), ('Người lập', 0)],
        rows=[[C(c), L(p), L(co), cs, M(t), N(h), tag(st, BG_ST[st]), u] for c, p, co, cs, t, h, st, u in BG],
        tfields=[('Mã', 'Mã'), ('Phụ huynh', 'Phụ huynh'), ('Cơ hội', 'Cơ hội')], favs=[('Báo giá đã gửi CS1', True, "{'Tình trạng':['Đã gửi'],'Cơ sở':['CS1']}"), ('Báo giá sắp hết hạn', False, "{'Tình trạng':['Đã gửi']}")],
        gfields=[('Tình trạng', 'Tình trạng', False), ('Cơ sở', 'Cơ sở', False), ('Người lập', 'Người lập', False)],
        filters=[('Tình trạng', [(k, k) for k in BG_ST]), ('Cơ sở', [(x, x) for x in ('CS1', 'CS2', 'CS4', 'CS5')])], link='Mở báo giá (màn BH-02).',
        toasts="{'Xuất':'Đang xuất danh sách báo giá ra file.'}", hint='Thử tìm bằng mã báo giá, tên phụ huynh hoặc mã cơ hội.', eicon='doc', etitle='Chưa có báo giá nào',
        esub='Báo giá sinh từ cơ hội: mở cơ hội rồi bấm Tạo báo giá. Danh sách này không có nút Tạo (R-TIEN-02).')

# ---------------- BH-06 Đơn hàng ----------------
DH_ST = {'Nháp': '', 'Đã trình': 'info', 'Đã duyệt · khoá': 'success', 'Từ chối': 'danger', 'Huỷ': 'danger'}
THU = {'Chưa thu': '', 'Thu một phần': 'warning', 'Đã thu đủ': 'success', '—': ''}
DHL = [('DH-CS1-2610-0012', 'Phạm Thu Hương', 'Phạm Đức Anh, Phạm Khánh Vy', 'CS1', 'Trần Thu Hà', 13608000, 7000000, 'Đã duyệt · khoá', 'Thu một phần'),
       ('DH-CS1-2610-0011', 'Trần Thị Hà', 'Nguyễn Minh Khôi', 'CS1', 'Trần Thu Hà', 9504000, 9504000, 'Đã duyệt · khoá', 'Đã thu đủ'), ('DH-CS1-2610-0010', 'Nguyễn Văn Long', 'Nguyễn Hà My', 'CS1', 'Nguyễn Thị Lan', 5280000, 0, 'Nháp', '—'),
       ('DH-CS2-2610-0009', 'Trần Quốc Hưng', 'Trần Gia Hân', 'CS2', 'Hoàng Mai Anh', 7920000, 0, 'Đã trình', '—'), ('DH-CS2-2610-0008', 'Đỗ Ngọc Bích', 'Đỗ Phương Thảo', 'CS2', 'Hoàng Mai Anh', 14256000, 2000000, 'Đã duyệt · khoá', 'Thu một phần'),
       ('DH-CS4-2610-0007', 'Bùi Thanh Thuỷ', 'Bùi Tuệ Minh', 'CS4', 'Vũ Đức Minh', 6336000, 0, 'Từ chối', '—'), ('DH-CS5-2610-0006', 'Vũ Thị Mai', 'Vũ Hải Đăng', 'CS5', 'Lê Thanh Hà', 9504000, 0, 'Đã duyệt · khoá', 'Chưa thu'),
       ('DH-CS1-2610-0005', 'Hoàng Văn Đức', 'Hoàng Gia Bảo', 'CS1', 'Trần Thu Hà', 4752000, 0, 'Huỷ', '—'), ('DH-CS4-2610-0004', 'Lê Minh Tuấn', 'Lê Quang Huy', 'CS4', 'Vũ Đức Minh', 11088000, 11088000, 'Đã duyệt · khoá', 'Đã thu đủ'),
       ('DH-CS5-2610-0003', 'Ngô Hồng Nhung', 'Ngô Bảo Châu', 'CS5', 'Lê Thanh Hà', 3960000, 1000000, 'Đã duyệt · khoá', 'Thu một phần')]
def cfg_dh():
    return dict(code='BH-06', h1='Đơn hàng', nav='Đơn hàng', crumb=[('Bán hàng &amp; thu chi', False), ('Đơn hàng', True)], ph='Tìm mã đơn, phụ huynh, học sinh…', noun='đơn hàng', total=214,
        heads=[('Mã', 0), ('Phụ huynh', 0), ('Học sinh', 0), ('Cơ sở', 0), ('Sale', 0), ('Tổng tiền (đ)', 1), ('Đã thu (đ)', 1), ('Tình trạng', 0), ('Thu tiền', 0)],
        rows=[[C(c), L(p), h, cs, sa, M(t), M(d), tag(st, DH_ST[st]), tag(th, THU[th]) if th != '—' else '<span class="hmt-help">—</span>'] for c, p, h, cs, sa, t, d, st, th in DHL],
        tfields=[('Mã', 'Mã'), ('Phụ huynh', 'Phụ huynh'), ('Học sinh', 'Học sinh')], favs=[('Đơn đã duyệt chưa thu đủ', True, "{'Tình trạng':['Đã duyệt · khoá'],'Thu tiền':['Chưa thu','Thu một phần']}"), ('Đơn nháp của tôi', False, "{'Tình trạng':['Nháp']}")],
        gfields=[('Tình trạng', 'Tình trạng', False), ('Cơ sở', 'Cơ sở', False), ('Sale', 'Sale', False)],
        filters=[('Tình trạng', [(k, k) for k in DH_ST]), ('Thu tiền', [('Chưa thu', 'Chưa thu'), ('Thu một phần', 'Thu một phần'), ('Đã thu đủ', 'Đã thu đủ')]), ('Cơ sở', [(x, x) for x in ('CS1', 'CS2', 'CS4', 'CS5')])], link='Mở đơn hàng (màn BH-05).',
        toasts="{'Xuất':'Đang xuất danh sách đơn hàng ra file.'}", hint='Thử tìm bằng mã đơn, tên phụ huynh hoặc tên học sinh.', eicon='receipt', etitle='Chưa có đơn hàng nào',
        esub='Đơn hàng sinh từ cơ hội hoặc từ báo giá. Danh sách này không có nút Tạo (R-TIEN-02).')

if __name__ == '__main__':
    o = run_list(cfg_bg(), 'BH01', 'sa') + run_list(cfg_dh(), 'BH06', 'bm')
    print(' '.join(o))
