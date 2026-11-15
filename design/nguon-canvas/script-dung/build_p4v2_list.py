# -*- coding: utf-8 -*-
# KH-01 Phụ huynh (danh sách) và KH-04 Học sinh (danh sách), nền = K1 (TS-07 K1)
import sys, re, json
sys.path.insert(0, 'scripts')
from kh_common import *

PH = [  # mã, tên, sđt, cơ sở tiếp nhận, đang học tại, số con, tình trạng, mã cũ
 ('PH000045', 'Trần Thị Hà', '0900 000 118', 'CS1', 'CS1, CS2', 2, 'Có con đang học', 'KH-1187'),
 ('PH000046', 'Trần Quốc Hưng', '0900 000 175', 'CS2', 'CS2', 1, 'Có con đang học', 'KH-1190'),
 ('PH000047', 'Phạm Thu Hương', '0900 000 123', 'CS1', 'CS1', 2, 'Có con đang học', 'KH-1204'),
 ('PH000048', 'Lê Minh Tuấn', '0900 000 135', 'CS4', '—', 1, 'Chưa có con đang học', 'KH-1211'),
 ('PH000049', 'Vũ Thị Mai', '0900 000 156', 'CS5', 'CS5', 1, 'Có con đang học', 'KH-1230'),
 ('PH000050', 'Đỗ Ngọc Bích', '0900 000 164', 'CS2', 'CS2, CS4', 3, 'Có con đang học', 'KH-1244'),
 ('PH000051', 'Hoàng Văn Đức', '0900 000 101', 'CS1', 'CS1', 1, 'Có con đang học', 'KH-1251'),
 ('PH000052', 'Bùi Thanh Thuỷ', '0900 000 145', 'CS4', 'CS4', 2, 'Có con đang học', 'KH-1262'),
 ('PH000053', 'Ngô Hồng Nhung', '0900 000 130', 'CS5', '—', 1, 'Chưa có con đang học', 'KH-1275'),
 ('PH000054', 'Đinh Quang Vinh', '0900 000 172', 'CS2', 'CS2', 1, 'Có con đang học', 'KH-1288'),
]
PH_MERGED = ('PH000063', 'Phạm T. Hương', '0900 000 123', 'CS1', '—', 0, 'Chưa có con đang học', 'KH-1402', 'PH000047')
HS = [  # mã, tên, khối, tình trạng, cơ sở tiếp nhận, đang học tại, sđt phụ huynh, lớp (để lọc), mã cũ
 ('HS000123', 'Nguyễn Minh Khôi', 'Lớp 9', 'Đang học', 'CS1', 'CS1, CS2', '0900 000 118', 'Toán 9 nâng cao', 'HSC-2231'),
 ('HS000201', 'Nguyễn Gia Hân', 'Lớp 6', 'Tiềm năng', 'CS1', '—', '0900 000 118', '', 'HSC-2232'),
 ('HS000125', 'Trần Gia Hân', 'Lớp 10', 'Đang học', 'CS2', 'CS2', '0900 000 175', 'Toán 10 tăng tốc', 'HSC-2240'),
 ('HS000126', 'Phạm Đức Anh', 'Lớp 8', 'Bảo lưu', 'CS1', '—', '0900 000 123', 'Toán 8 cơ bản', 'HSC-2251'),
 ('HS000127', 'Phạm Khánh Vy', 'Lớp 5', 'Đang học', 'CS1', 'CS1', '0900 000 123', 'Toán 5 nền tảng', 'HSC-2252'),
 ('HS000128', 'Lê Quang Huy', 'Lớp 11', 'Dừng học', 'CS4', '—', '0900 000 135', '', 'HSC-2260'),
 ('HS000129', 'Vũ Hải Đăng', 'Lớp 9', 'Đang học', 'CS5', 'CS5', '0900 000 156', 'Toán 9 nâng cao', 'HSC-2271'),
 ('HS000130', 'Đỗ Phương Thảo', 'Lớp 7', 'Tiềm năng', 'CS2', '—', '0900 000 164', '', 'HSC-2280'),
 ('HS000131', 'Hoàng Gia Bảo', 'Lớp 8', 'Đang học', 'CS1', 'CS1', '0900 000 101', 'Toán 8 cơ bản', 'HSC-2294'),
 ('HS000132', 'Bùi Tuệ Minh', 'Lớp 10', 'Đang học', 'CS4', 'CS4', '0900 000 145', 'Toán 10 tăng tốc', 'HSC-2303'),
]
HS_MERGED = ('HS000138', 'Phạm Đức Anh', 'Lớp 8', 'Tiềm năng', 'CS1', '—', '0900 000 123', '', 'HSC-2399', 'HS000126')
TT_CLS = {'Đang học': 'hmt-tag hmt-tag-success', 'Tiềm năng': 'hmt-tag hmt-tag-info', 'Bảo lưu': 'hmt-tag hmt-tag-warning', 'Dừng học': 'hmt-tag'}
MERGED_TAG = '<span class="hmt-tag" style="background:var(--bg-subtle);border:1px solid var(--divider)">Đã gộp</span>'

def chk(code): return '<td><label class="hmt-hit"><input type="checkbox" aria-label="Chọn %s"></label></td>' % code
def code_cell(code, old): return '<td><span class="hmt-code">%s</span><span style="display:none"> %s</span></td>' % (code, old)

def ph_rows():
    r = ''
    for c, n, p, cs, ht, k, tt, old in PH:
        r += '<tr>' + chk(c) + code_cell(c, old) + '<td><a href="#">%s</a></td><td><span class="%s">%s</span></td><td>%s</td><td>%s</td><td><span class="hmt-num">%s</span></td><td class="r">%d</td></tr>' % (n, PT_CLS[tt], tt, cs, ht, p, k)
    c, n, p, cs, ht, k, tt, old, to = PH_MERGED
    r += ('<tr data-merged="1" style="opacity:.55" title="Đã gộp vào %s">' % to) + chk(c) + code_cell(c, old) + \
         '<td><a href="#">%s</a> %s <span class="hmt-help">vào %s</span></td><td></td><td>%s</td><td>%s</td><td><span class="hmt-num">%s</span></td><td class="r">%d</td></tr>' % (n, MERGED_TAG, to, cs, ht, p, k)
    return r
def hs_rows():
    r = ''
    for c, n, kh, tt, cs, ht, sp, lop, old in HS:
        r += '<tr>' + chk(c) + code_cell(c, old) + '<td><a href="#">%s</a></td><td>%s</td><td><span class="%s">%s</span></td><td>%s</td><td>%s<span style="display:none"> %s</span></td><td><span class="hmt-num">%s</span></td></tr>' % (n, kh, TT_CLS[tt], tt, cs, ht, ('Lớp ' + lop) if lop else '', sp)
    c, n, kh, tt, cs, ht, sp, lop, old, to = HS_MERGED
    r += ('<tr data-merged="1" style="opacity:.55" title="Đã gộp vào %s">' % to) + chk(c) + code_cell(c, old) + \
         '<td><a href="#">%s</a> %s <span class="hmt-help">vào %s</span></td><td>%s</td><td><span class="%s">%s</span></td><td>%s</td><td>%s</td><td><span class="hmt-num">%s</span></td></tr>' % (n, MERGED_TAG, to, kh, TT_CLS[tt], tt, cs, ht, sp)
    return r

CHK_TH = '<th style="width:40px"><label class="hmt-hit"><input type="checkbox" aria-label="Chọn tất cả"></label></th>'
THEAD_PH = CHK_TH + '<th>Mã</th><th>Họ tên</th><th>Tình trạng</th><th>Cơ sở tiếp nhận</th><th>Đang học tại</th><th>SĐT</th><th class="r">Số con</th>'
THEAD_HS = CHK_TH + '<th>Mã</th><th>Họ tên</th><th>Khối</th><th>Tình trạng</th><th>Cơ sở tiếp nhận</th><th>Đang học tại</th><th>SĐT phụ huynh</th>'
PT_CLS = {'Có con đang học': 'hmt-tag hmt-tag-success', 'Chưa có con đang học': 'hmt-tag'}

CFG_PH = r"""const CFG = { layout2:true, stage:'free', noun:'phụ huynh', pcol:'Mã',
  tfields:[{n:'Mã',col:'Mã'},{n:'Họ tên',col:'Họ tên'},{n:'SĐT',col:'SĐT'}],
  favs:[{n:'Phụ huynh CS1 đang có con học',shared:true,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:{'Cơ sở tiếp nhận':['CS1'],'Tình trạng':['Có con đang học']}}},{n:'Phụ huynh chưa có con đang học',shared:false,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:{}}}],
  gfields:[{n:'Cơ sở tiếp nhận',col:'Cơ sở tiếp nhận'},{n:'Số con',col:'Số con',gb:false}], filters:[
    {g:'Trạng thái bản ghi', items:[['Đã gộp','Đã gộp']]},
    {g:'Tình trạng', items:[['Có con đang học','Có con đang học'],['Chưa có con đang học','Chưa có con đang học']]},
    {g:'Cơ sở tiếp nhận', items:[['CS1','CS1'],['CS2','CS2'],['CS4','CS4'],['CS5','CS5']]}], link:'Mở phụ huynh (màn KH-02).', views:{},
  toasts:{'Xuất':'Đang xuất danh sách phụ huynh ra file.'} };"""
CFG_HS = r"""const CFG = { layout2:true, stage:'free', noun:'học sinh', pcol:'Mã',
  tfields:[{n:'Mã',col:'Mã'},{n:'Họ tên',col:'Họ tên'},{n:'SĐT phụ huynh',col:'SĐT phụ huynh'}],
  favs:[{n:'Học sinh đang học CS1',shared:true,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:{'Tình trạng':['Đang học'],'Cơ sở tiếp nhận':['CS1']}}},{n:'Học sinh tiềm năng',shared:false,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:{'Tình trạng':['Tiềm năng']}}}],
  gfields:[{n:'Tình trạng',col:'Tình trạng'},{n:'Khối',col:'Khối'},{n:'Cơ sở tiếp nhận',col:'Cơ sở tiếp nhận'}], filters:[
    {g:'Tình trạng', items:[['Tiềm năng','Tiềm năng'],['Đang học','Đang học'],['Bảo lưu','Bảo lưu'],['Dừng học','Dừng học']]},
    {g:'Khối', items:[['Lớp 5','Lớp 5\\b'],['Lớp 6','Lớp 6\\b'],['Lớp 7','Lớp 7\\b'],['Lớp 8','Lớp 8\\b'],['Lớp 9','Lớp 9\\b'],['Lớp 10','Lớp 10\\b'],['Lớp 11','Lớp 11\\b']]},
    {g:'Cơ sở tiếp nhận', items:[['CS1','CS1'],['CS2','CS2'],['CS4','CS4'],['CS5','CS5']]},
    {g:'Lớp', items:[['Toán 5 nền tảng','Lớp Toán 5 nền tảng'],['Toán 8 cơ bản','Lớp Toán 8 cơ bản'],['Toán 9 nâng cao','Lớp Toán 9 nâng cao'],['Toán 10 tăng tốc','Lớp Toán 10 tăng tốc']]},
    {g:'Trạng thái bản ghi', items:[['Đã gộp','Đã gộp']]}], link:'Mở hồ sơ (màn KH-05) hoặc phụ huynh (màn KH-02).', views:{},
  toasts:{'Xuất':'Đang xuất danh sách học sinh ra file.'} };"""

USERS = {
 'cs': ('Nguyễn Thị Lan', 'CSKH · CS1 Nguyễn Chí Thanh', 'NL'),
 'ad': ('Trần Thu Hà', 'Admin', 'TH'),
 'sa': ('Trần Thu Hà', 'Tuyển sinh · CS1 Nguyễn Chí Thanh', 'TH'),
 'kt': ('Phạm Thị Hồng Nhung', 'Kế toán · CS1 Nguyễn Chí Thanh', 'HN'),
 'gv': ('Lê Văn Phong', 'Giáo viên · CS1 Nguyễn Chí Thanh', 'LP'),
}

def build(kind, state, role='cs'):
    s = read('TS07_K1.dc.html')
    ph = kind == 'ph'
    noun, nouns = ('phụ huynh', 'Phụ huynh') if ph else ('học sinh', 'Học sinh')
    s = sidebar(s, active=nouns, hide_kh=(state == 'quyen'))
    s = crumb(s, [('Khách hàng', False), (nouns, True)])
    s = user(s, *USERS['gv' if state == 'quyen' else role])
    s = s.replace('<h1>Cơ hội</h1>', '<h1>%s</h1>' % nouns, 1)
    # nút trên đầu: Tạo, Xuất (bỏ Nhập); bỏ kiểu xem Kanban
    s = re.sub(r'<button class="hmt-btn " type="button"><svg[^>]*>(?:(?!</svg>).)*</svg>Nhập</button>', '', s, count=1, flags=re.S)
    s = re.sub(r'<span class="hmt-vsep"></span><div class="hmt-seg hmt-seg-ic".*?</div>', '', s, count=1, flags=re.S)
    s = re.sub(r'<button class="hmt-btn hmt-btn-primary" type="button"><svg[^>]*>(?:(?!</svg>).)*</svg>Tạo</button>', '', s, count=1, flags=re.S)
    if role != 'ad':
        s = re.sub(r'<button class="hmt-btn " type="button"><svg[^>]*>(?:(?!</svg>).)*</svg>Xuất</button>', '', s, count=1, flags=re.S)
    # tìm kiếm
    s = s.replace('placeholder="Tìm tên, SĐT, mã (cả mã cũ)…"', 'placeholder="%s"' % ('Tìm tên, SĐT, mã PH, mã cũ…' if ph else 'Tìm tên, SĐT phụ huynh, mã HS, mã cũ…'), 1)
    # bỏ hàng lọc nhanh và thanh chọn nhiều (không có thao tác hàng loạt trong bản đồ)
    i = s.index('<div class="hmt-fbar" aria-label="Lọc nhanh"'); s, _ = remove_div(s, i)
    i = s.index('<div class="hmt-fbar" style="background:var(--brand-50)'); s, _ = remove_div(s, i)
    # bảng
    ta = s.index('<div class="hmt-table-wrap">'); s2, tw = remove_div(s, ta)
    rows = ph_rows() if ph else hs_rows()
    n_vis = len(PH) if ph else len(HS)
    table = '<div class="hmt-table-wrap"><table class="hmt-table"><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (THEAD_PH if ph else THEAD_HS, rows)
    s = s2[:ta] + table + s2[ta:]
    s = s.replace('1–8 / 8', '1–%d / %d' % (n_vis, n_vis), 1)
    # bỏ hộp thoại Assign (không dùng)
    i = s.index('<div class="hmt-scrim"'); s, _ = remove_div(s, i)
    s = s[:i] + '<div class="hmt-scrim" style="position:absolute;inset:0;z-index:50;align-items:center;padding:0;gap:var(--space-6);display:none"><div class="hmt-dialog" role="dialog" aria-label="—" style="width:460px;flex:0 0 460px"><div class="hmt-dialog-h">—</div><div class="hmt-dialog-b"></div></div></div>' + s[i:]
    s = replace_cfg(s, CFG_PH if ph else CFG_HS)
    s = s.replace("GBF.slice().sort(", "GBF.filter(f => f.gb !== false).slice().sort(")
    s = s.replace("toast('Mở bản ghi chỉ đọc CO000128 (đã gộp vào CO000118), giống màn TS-10b.');",
                  ("toast('Mở bản ghi chỉ đọc PH000063 (đã gộp vào PH000047), cùng cách như TS-10b.');" if ph else "toast('Mở bản ghi chỉ đọc HS000138 (đã gộp vào HS000126), cùng cách như TS-10b.');"))
    # không có kết quả: khung rỗng đầy đủ (dùng chung khi tìm không thấy)
    old = "em.className = 'ix-empty hmt-help'; em.style.padding = '24px'; em.style.textAlign = 'center'; em.textContent = 'Không có bản ghi nào khớp bộ lọc.';"
    assert old in s
    hint = 'Thử tìm bằng SĐT, mã PH hoặc mã cũ (không cần gõ dấu).' if ph else 'Thử tìm bằng tên, mã HS hoặc mã cũ (không cần gõ dấu).'
    new = ("em.className = 'ix-empty'; em.style.cssText = 'display:flex;flex-direction:column;align-items:center;gap:10px;padding:40px 20px;text-align:center'; "
           "const tq = sb && sb.value.trim(); em.innerHTML = '<span style=\"color:var(--text-secondary)\">" + SVG(IC['search'], 'hmt-ic hmt-ic-lg').replace("'", "\\'") + "</span><b style=\"color:var(--text-primary);font-size:15px\">Không tìm thấy " + noun + " nào</b>"
           "<span class=\"hmt-help\" style=\"max-width:460px\">' + (tq ? 'Không có kết quả cho “' + tq + '”. ' : 'Không có bản ghi nào khớp bộ lọc. ') + '" + hint + "</span><button class=\"hmt-btn\" type=\"button\" data-clearall>Xoá tìm kiếm và bộ lọc</button>';")
    s = s.replace(old, new)
    title = ('KH-01 · Phụ huynh · danh sách' if ph else 'KH-04 · Học sinh · danh sách')
    extra = ''
    # ----- các trạng thái -----
    a = s.index('<div class="bgblur"'); inner_start = a
    rest = s[a:]
    rest_wo, bg = remove_div(rest, 0)
    if state == 'tai':
        t = bg.index('<div class="hmt-toolbar">')
        head = bg[:t]
        head = head.replace('<button class="hmt-btn hmt-btn-primary" type="button">', '<button class="hmt-btn hmt-btn-primary" type="button" disabled>').replace('<button class="hmt-btn " type="button">', '<button class="hmt-btn " type="button" disabled>').replace('<button class="hmt-btn" type="button"', '<button class="hmt-btn" type="button" disabled')
        rows_sk = ''.join('<div style="display:flex;gap:14px;align-items:center;padding:12px 16px;border-top:1px solid var(--bg-subtle)">' + sk(16, 16) + sk(90, 14) + sk(170, 14) + sk(110, 14) + sk(70, 14) + sk(50, 14) + sk(50, 14) + '<span style="flex:1"></span>' + sk(80, 14) + '</div>' for _ in range(8))
        body = (SK_CSS + '<div class="hmt-content" aria-busy="true" aria-label="Đang tải"><div class="hmt-box" style="overflow:hidden;margin:var(--space-4)"><div style="padding:12px 16px;display:flex;gap:10px">' + sk(240, 28) + sk(80, 28) + sk(90, 28) + sk(90, 28) + '</div>'
                '<div style="display:flex;gap:14px;align-items:center;padding:10px 16px;border-top:1px solid var(--divider);background:var(--bg-subtle)">' + sk(16, 14) + sk(60, 12) + sk(120, 12) + sk(80, 12) + sk(60, 12) + '</div>' + rows_sk + '</div></div>')
        bg = head + body + '</div></div></div>'
        title += ' (đang tải)'
    elif state == 'trong':
        c = bg.index('<div class="hmt-content">')
        txt = ('Chưa có phụ huynh nào' if ph else 'Chưa có học sinh nào', 'Hồ sơ phụ huynh tự sinh khi có cơ hội mới ở phân hệ Tuyển sinh.' if ph else 'Hồ sơ học sinh tự sinh khi có phiếu kiểm tra đầu vào hoặc đơn được duyệt.')
        box = empty_box('users' if ph else 'grad', txt[0], txt[1], None)
        bg = bg[:c] + '<div class="hmt-content">' + box + '</div></div></div></div>'
        bg = bg.replace('1–%d / %d' % (n_vis, n_vis), '0 / 0')
        title += ' (trống)'
    elif state == 'kq0':
        bg = bg.replace('<tbody>' + rows + '</tbody>', '<tbody></tbody>')
        bg = bg.replace('1–%d / %d' % (n_vis, n_vis), '0 / 0')
        title += ' (không có kết quả tìm)'
        extra = "const _i = q('.hmt-search input'); if (_i) { _i.value = '%s'; }\n[80, 400, 900].forEach(ms => setTimeout(() => { try { applyFilters(); } catch (_) {} }, ms));" % ('nguyen van zz' if ph else 'khoi zz')
    elif state == 'quyen':
        h = bg.index('<div class="hmt-header">')
        box = ('<div class="hmt-content"><div class="hmt-box hmt-empty" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:48px 20px;text-align:center;min-height:420px;margin:var(--space-6) auto;max-width:560px">'
               '<span style="color:var(--text-secondary)">' + SVG(IC['lock'], 'hmt-ic hmt-ic-lg') + '</span><b style="color:var(--text-primary);font-size:16px;font-family:var(--font-heading)">Bạn không có quyền xem %s</b>'
               '<span class="hmt-help" style="max-width:420px">Vai trò Giáo viên chưa được cấp quyền xem phân hệ Khách hàng. Nếu cần xem, hãy liên hệ quản trị viên của trung tâm.</span>'
               '<button class="hmt-btn hmt-btn-primary" type="button" data-act="home">Về trang chủ</button></div></div>') % noun
        bg = bg[:h] + box + '</div></div></div>'
        title += ' (không có quyền)'
    if role == 'ad' and state == 'normal': title += (' · Admin' if role == 'ad' else '')
    s = s[:a] + bg + rest_wo
    js = "const _go = ev => { const b = ev.target.closest && ev.target.closest('button[data-act]'); if (!b) return; ev.stopPropagation(); ev.preventDefault(); toast('Về trang chủ theo vai trò (CHUNG-14).'); };\nROOT.addEventListener('click', _go, true);\n" + extra
    return inject(s, title, js)

if __name__ == '__main__':
    out = {}
    for kind, pre in (('ph', 'KH01'), ('hs', 'KH04')):
        for st, suf, role in (('normal', '', 'cs'), ('normal', '_admin', 'ad'), ('trong', '_trong', 'cs'), ('tai', '_tai', 'cs'), ('kq0', '_khong_ket_qua', 'cs'), ('quyen', '_khong_quyen', 'cs')):
            n = pre + suf; write(n + '.dc.html', build(kind, st, role)); out[n] = 1
    print(' '.join(out))
