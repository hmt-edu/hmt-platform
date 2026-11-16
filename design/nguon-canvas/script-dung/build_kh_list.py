# -*- coding: utf-8 -*-
# KH-01 Phụ huynh (danh sách) và KH-04 Học sinh (danh sách), nền = K1 (TS-07 K1)
import sys, re, json
sys.path.insert(0, 'scripts')
from kh_common import *

PH = [  # mã, tên, sđt, cơ sở, con, đơn, cập nhật, mã cũ
 ('PH000045', 'Chị Nguyễn Thị Lan Anh', '0900 000 104', 'CS1', 2, 1, '16/10/2026', 'KH-1187'),
 ('PH000046', 'Anh Trần Quốc Hưng', '0900 000 175', 'CS2', 1, 2, '15/10/2026', 'KH-1190'),
 ('PH000047', 'Chị Phạm Thu Hương', '0900 000 123', 'CS1', 2, 3, '14/10/2026', 'KH-1204'),
 ('PH000048', 'Anh Lê Minh Tuấn', '0900 000 135', 'CS4', 1, 0, '13/10/2026', 'KH-1211'),
 ('PH000049', 'Chị Vũ Thị Mai', '0900 000 156', 'CS5', 1, 1, '12/10/2026', 'KH-1230'),
 ('PH000050', 'Chị Đỗ Ngọc Bích', '0900 000 164', 'CS2', 3, 4, '10/10/2026', 'KH-1244'),
 ('PH000051', 'Anh Hoàng Văn Đức', '0900 000 101', 'CS1', 1, 1, '09/10/2026', 'KH-1251'),
 ('PH000052', 'Chị Bùi Thanh Thuỷ', '0900 000 145', 'CS4', 2, 2, '08/10/2026', 'KH-1262'),
 ('PH000053', 'Chị Ngô Hồng Nhung', '0900 000 130', 'CS5', 1, 0, '07/10/2026', 'KH-1275'),
 ('PH000054', 'Anh Đinh Quang Vinh', '0900 000 172', 'CS2', 1, 1, '05/10/2026', 'KH-1288'),
]
PH_MERGED = ('PH000063', 'Phạm T. Hương', '0900 000 123', 'CS1', 0, 0, '14/10/2026', 'KH-1402', 'PH000047')
HS = [  # mã, tên, năm sinh, khối, trường, mã PH, tên PH, tình trạng, cơ sở, lớp, mã cũ
 ('HS000123', 'Nguyễn Minh Khôi', 2012, 'Lớp 9', 'THCS Giảng Võ', 'PH000045', 'Chị Nguyễn Thị Lan Anh', 'Đang học', 'CS1', 'Toán 9 nâng cao', 'HSC-2231'),
 ('HS000124', 'Nguyễn Bảo Ngọc', 2015, 'Lớp 6', 'THCS Ngọc Khánh', 'PH000045', 'Chị Nguyễn Thị Lan Anh', 'Tiềm năng', 'CS1', '', 'HSC-2232'),
 ('HS000125', 'Trần Gia Hân', 2011, 'Lớp 10', 'THPT Chu Văn An', 'PH000046', 'Anh Trần Quốc Hưng', 'Đang học', 'CS2', 'Toán 10 tăng tốc', 'HSC-2240'),
 ('HS000126', 'Phạm Đức Anh', 2013, 'Lớp 8', 'THCS Thăng Long', 'PH000047', 'Chị Phạm Thu Hương', 'Bảo lưu', 'CS1', 'Toán 8 cơ bản', 'HSC-2251'),
 ('HS000127', 'Phạm Khánh Vy', 2016, 'Lớp 5', 'TH Ba Đình', 'PH000047', 'Chị Phạm Thu Hương', 'Đang học', 'CS1', 'Toán 5 nền tảng', 'HSC-2252'),
 ('HS000128', 'Lê Quang Huy', 2010, 'Lớp 11', 'THPT Việt Đức', 'PH000048', 'Anh Lê Minh Tuấn', 'Dừng học', 'CS4', '', 'HSC-2260'),
 ('HS000129', 'Vũ Hải Đăng', 2012, 'Lớp 9', 'THCS Đống Đa', 'PH000049', 'Chị Vũ Thị Mai', 'Đang học', 'CS5', 'Toán 9 nâng cao', 'HSC-2271'),
 ('HS000130', 'Đỗ Phương Thảo', 2014, 'Lớp 7', 'THCS Cầu Giấy', 'PH000050', 'Chị Đỗ Ngọc Bích', 'Tiềm năng', 'CS2', '', 'HSC-2280'),
 ('HS000131', 'Hoàng Gia Bảo', 2013, 'Lớp 8', 'THCS Nguyễn Trãi', 'PH000051', 'Anh Hoàng Văn Đức', 'Đang học', 'CS1', 'Toán 8 cơ bản', 'HSC-2294'),
 ('HS000132', 'Bùi Tuệ Minh', 2011, 'Lớp 10', 'THPT Kim Liên', 'PH000052', 'Chị Bùi Thanh Thuỷ', 'Đang học', 'CS4', 'Toán 10 tăng tốc', 'HSC-2303'),
]
HS_MERGED = ('HS000138', 'Phạm Đức Anh', 2013, 'Lớp 8', 'THCS Thăng Long', 'PH000047', 'Chị Phạm Thu Hương', 'Tiềm năng', 'CS1', '', 'HSC-2399', 'HS000126')
TT_CLS = {'Đang học': 'hmt-tag hmt-tag-success', 'Tiềm năng': 'hmt-tag hmt-tag-info', 'Bảo lưu': 'hmt-tag hmt-tag-warning', 'Dừng học': 'hmt-tag'}
MERGED_TAG = '<span class="hmt-tag" style="background:var(--bg-subtle);border:1px solid var(--divider)">Đã gộp</span>'

def chk(code): return '<td><label class="hmt-hit"><input type="checkbox" aria-label="Chọn %s"></label></td>' % code
def code_cell(code, old): return '<td><span class="hmt-code">%s</span><span style="display:none"> %s</span></td>' % (code, old)

def ph_rows():
    r = ''
    for c, n, p, cs, k, d, up, old in PH:
        r += '<tr>' + chk(c) + code_cell(c, old) + '<td><a href="#">%s</a></td><td><span class="hmt-num">%s</span></td><td>%s</td><td>%d</td><td>%d</td><td>%s</td></tr>' % (n, p, cs, k, d, up)
    c, n, p, cs, k, d, up, old, to = PH_MERGED
    r += ('<tr data-merged="1" style="opacity:.55" title="Đã gộp vào %s">' % to) + chk(c) + code_cell(c, old) + \
         '<td><a href="#">%s</a> %s <span class="hmt-help">vào %s</span></td><td><span class="hmt-num">%s</span></td><td>%s</td><td>%d</td><td>%d</td><td>%s</td></tr>' % (n, MERGED_TAG, to, p, cs, k, d, up)
    return r
def hs_rows():
    r = ''
    for c, n, y, kh, tr, mp, tp, tt, cs, lop, old in HS:
        r += '<tr>' + chk(c) + code_cell(c, old) + '<td><a href="#">%s</a></td><td>%d</td><td>%s</td><td>%s</td><td><span style="display:flex;flex-direction:column;gap:2px;padding:6px 0"><a href="#">%s</a><span class="hmt-help">%s</span></span></td><td><span class="%s">%s</span><span style="display:none"> %s</span></td><td>%s</td></tr>' % (n, y, kh, tr, tp, mp, TT_CLS[tt], tt, ('Lớp ' + lop) if lop else '', cs)
    c, n, y, kh, tr, mp, tp, tt, cs, lop, old, to = HS_MERGED
    r += ('<tr data-merged="1" style="opacity:.55" title="Đã gộp vào %s">' % to) + chk(c) + code_cell(c, old) + \
         '<td><a href="#">%s</a> %s <span class="hmt-help">vào %s</span></td><td>%d</td><td>%s</td><td>%s</td><td><span style="display:flex;flex-direction:column;gap:2px;padding:6px 0"><a href="#">%s</a><span class="hmt-help">%s</span></span></td><td>%s</td><td>%s</td></tr>' % (n, MERGED_TAG, to, y, kh, tr, tp, mp, MERGED_TAG, cs)
    return r

THEAD_PH = '<th style="width:40px"><label class="hmt-hit"><input type="checkbox" aria-label="Chọn tất cả"></label></th><th>Mã</th><th>Họ tên</th><th>SĐT</th><th>Cơ sở</th><th>Số con</th><th>Số đơn</th><th>Cập nhật</th>'
THEAD_HS = '<th style="width:40px"><label class="hmt-hit"><input type="checkbox" aria-label="Chọn tất cả"></label></th><th>Mã</th><th>Họ tên</th><th>Năm sinh</th><th>Khối</th><th>Trường</th><th>Phụ huynh</th><th>Tình trạng</th><th>Cơ sở</th>'

CFG_PH = r"""const CFG = { layout2:true, stage:'free', noun:'phụ huynh', pcol:'Cập nhật',
  tfields:[{n:'Mã',col:'Mã'},{n:'Họ tên',col:'Họ tên'},{n:'SĐT',col:'SĐT'}],
  favs:[{n:'Phụ huynh CS1 đã có đơn',shared:true,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:{'Cơ sở':['CS1']}}},{n:'Phụ huynh chưa có đơn',shared:false,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:{}}}],
  gfields:[{n:'Cơ sở',col:'Cơ sở'},{n:'Số con',col:'Số con',gb:false},{n:'Số đơn',col:'Số đơn',gb:false},{n:'Cập nhật',col:'Cập nhật',kind:'date',gb:false}], filters:[
    {g:'Trạng thái bản ghi', items:[['Đã gộp','Đã gộp']]},
    {g:'Cơ sở', items:[['CS1','CS1'],['CS2','CS2'],['CS4','CS4'],['CS5','CS5']]}], link:'Mở phụ huynh (màn KH-02).', views:{},
  toasts:{'Tạo':'Mở khuôn Chi tiết trống: phụ huynh mới (màn KH-03).','Xuất':'Đang xuất danh sách phụ huynh ra file.'} };"""
CFG_HS = r"""const CFG = { layout2:true, stage:'free', noun:'học sinh', pcol:'Năm sinh',
  tfields:[{n:'Mã',col:'Mã'},{n:'Họ tên',col:'Họ tên'},{n:'Trường',col:'Trường'},{n:'Phụ huynh',col:'Phụ huynh'}],
  favs:[{n:'Học sinh đang học CS1',shared:true,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:{'Tình trạng':['Đang học'],'Cơ sở':['CS1']}}},{n:'Học sinh tiềm năng',shared:false,def:false,s:{pills:{'Của tôi':[],'Lịch hẹn':[]},FX:{'Tình trạng':['Tiềm năng']}}}],
  gfields:[{n:'Tình trạng',col:'Tình trạng'},{n:'Khối',col:'Khối'},{n:'Cơ sở',col:'Cơ sở'}], filters:[
    {g:'Tình trạng', items:[['Tiềm năng','Tiềm năng'],['Đang học','Đang học'],['Bảo lưu','Bảo lưu'],['Dừng học','Dừng học']]},
    {g:'Khối', items:[['Lớp 5','Lớp 5\\b'],['Lớp 6','Lớp 6\\b'],['Lớp 7','Lớp 7\\b'],['Lớp 8','Lớp 8\\b'],['Lớp 9','Lớp 9\\b'],['Lớp 10','Lớp 10\\b'],['Lớp 11','Lớp 11\\b']]},
    {g:'Cơ sở', items:[['CS1','CS1'],['CS2','CS2'],['CS4','CS4'],['CS5','CS5']]},
    {g:'Lớp', items:[['Toán 5 nền tảng','Lớp Toán 5 nền tảng'],['Toán 8 cơ bản','Lớp Toán 8 cơ bản'],['Toán 9 nâng cao','Lớp Toán 9 nâng cao'],['Toán 10 tăng tốc','Lớp Toán 10 tăng tốc']]},
    {g:'Trạng thái bản ghi', items:[['Đã gộp','Đã gộp']]}], link:'Mở hồ sơ (màn KH-05) hoặc phụ huynh (màn KH-02).', views:{},
  toasts:{'Tạo':'Mở khuôn Chi tiết trống: học sinh mới (màn KH-06).','Xuất':'Đang xuất danh sách học sinh ra file.'} };"""

USERS = {
 'sa': ('Trần Thu Hà', 'Tuyển sinh · CS1 Nguyễn Chí Thanh', 'TH'),
 'kt': ('Phạm Thị Hồng Nhung', 'Kế toán · CS1 Nguyễn Chí Thanh', 'HN'),
 'gv': ('Lê Văn Phong', 'Giáo viên · CS1 Nguyễn Chí Thanh', 'LP'),
}

def build(kind, state, role='sa'):
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
    if role != 'sa' and state != 'quyen':   # Kế toán, Trưởng cơ sở chỉ xem: không có nút Tạo
        s = re.sub(r'<button class="hmt-btn hmt-btn-primary" type="button"><svg[^>]*>(?:(?!</svg>).)*</svg>Tạo</button>', '', s, count=1, flags=re.S)
        s = s.replace('<div class="bz"><button class="hmt-btn " type="button">', '<div class="bz"><button class="hmt-btn " type="button">', 1)
    # tìm kiếm
    s = s.replace('placeholder="Tìm tên, SĐT, mã (cả mã cũ)…"', 'placeholder="%s"' % ('Tìm tên, SĐT, mã PH, mã cũ…' if ph else 'Tìm tên, mã HS, mã cũ…'), 1)
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
        txt = ('Chưa có phụ huynh nào' if ph else 'Chưa có học sinh nào', 'Phụ huynh được tạo ở đây hoặc khi chốt cơ hội. Bấm Tạo để thêm phụ huynh đầu tiên.' if ph else 'Học sinh được tạo ở đây, hoặc từ nút Thêm con trong hồ sơ phụ huynh. Bấm Tạo để thêm học sinh đầu tiên.')
        box = empty_box('users' if ph else 'grad', txt[0], txt[1], ('Tạo', 'tao', 'plus') if role == 'sa' else None)
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
    if role != 'sa' and state == 'normal': title += (' · Kế toán xem' if role == 'kt' else '')
    s = s[:a] + bg + rest_wo
    js = "const _go = ev => { const b = ev.target.closest && ev.target.closest('button[data-act]'); if (!b) return; ev.stopPropagation(); ev.preventDefault(); toast(b.getAttribute('data-act') === 'home' ? 'Về trang chủ theo vai trò (CHUNG-14).' : '%s'); };\nROOT.addEventListener('click', _go, true);\n%s" % (CFG_PH.split("'Tạo':'")[1].split("'")[0] if ph else CFG_HS.split("'Tạo':'")[1].split("'")[0], extra)
    return inject(s, title, js)

if __name__ == '__main__':
    out = {}
    for kind, pre in (('ph', 'KH01'), ('hs', 'KH04')):
        for st, suf, role in (('normal', '', 'sa'), ('trong', '_trong', 'sa'), ('tai', '_tai', 'sa'), ('kq0', '_khong_ket_qua', 'sa'), ('quyen', '_khong_quyen', 'sa')) + ((('normal', '_kt', 'kt'),) if kind == 'ph' else ()):
            n = pre + suf; write(n + '.dc.html', build(kind, st, role)); out[n] = 1
    print(' '.join(out))
