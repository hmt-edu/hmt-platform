# -*- coding: utf-8 -*-
# P5b cụm Lớp: LOP-01 (danh sách, kanban), LOP-02 (bản ghi), LOP-03 (biểu mẫu tạo/sửa) + hộp thoại K08 (LOP-05, 06, 07, 10)
import sys, re, json; sys.path.insert(0, 'scripts')
from p5b_common import *
import kh_common as KC

LOP_DUYET = {'Nháp': '', 'Đã trình': 'info', 'Đã xác nhận': 'brand', 'Đã duyệt': 'success', 'Từ chối': 'danger', 'Đã đóng': '', 'Huỷ': 'danger'}
LOP_VH = {'Chưa khai giảng': 'warning', 'Đang học': 'success', 'Đã kết thúc': '', '—': ''}
# mã, tên chung nhóm, môn, khối, cơ sở, giáo viên, sĩ số, tối đa, duyệt, vận hành, mã cũ
LOPL = [('CS1-2627-DAI-K09-CB-A-001', '9M1', 'Đại số', '9', 'CS1', 'Nguyễn Văn Nam', 12, 20, 'Đã duyệt', 'Đang học', 'CLS-2609-0014'),
        ('CS1-2627-HINH-K09-CB-A-001', '9M1', 'Hình học', '9', 'CS1', 'Lê Thu Trang', 11, 20, 'Đã duyệt', 'Đang học', 'CLS-2609-0015'),
        ('CS1-2627-TOAN-K06-CB-A-001', '', 'Toán', '6', 'CS1', 'Trần Minh Đức', 16, 20, 'Đã duyệt', 'Đang học', 'CLS-2608-0006'),
        ('CS1-2627-TOAN-K06-CB-B-002', '', 'Toán', '6', 'CS1', 'Trần Minh Đức', 9, 20, 'Đã duyệt', 'Đang học', 'CLS-2608-0007'),
        ('CS1-2627-DAI-K08-CB-A-001', '8M2', 'Đại số', '8', 'CS1', 'Phạm Hải Yến', 6, 20, 'Đã duyệt', 'Chưa khai giảng', ''),
        ('CS1-2627-DAI-K09-CB-B-002', '9M2', 'Đại số', '9', 'CS1', 'Nguyễn Văn Nam', 0, 20, 'Đã trình', 'Chưa khai giảng', ''),
        ('CS1-2627-HINH-K09-CB-B-002', '9M2', 'Hình học', '9', 'CS1', 'Lê Thu Trang', 0, 20, 'Nháp', 'Chưa khai giảng', ''),
        ('CS1-2627-ANH-K07-CB-A-001', '', 'Tiếng Anh', '7', 'CS1', 'Đỗ Mai Phương', 0, 18, 'Đã xác nhận', 'Chưa khai giảng', ''),
        ('CS1-2627-ANH-K04-CB-A-001', '', 'Tiếng Anh', '4', 'CS1', '—', 0, 18, 'Nháp', 'Chưa khai giảng', ''),
        ('CS2-2627-TOAN-K09-LR-014', '', 'Toán', '9', 'CS2', 'Hoàng Mai Anh', 1, 1, 'Đã duyệt', 'Đang học', ''),
        ('CS4-2627-ANH-K06-CB-A-001', '', 'Tiếng Anh', '6', 'CS4', 'Vũ Thị Hằng', 0, 18, 'Từ chối', 'Chưa khai giảng', ''),
        ('CS1-2627-ANH-K02-CB-A-001', '', 'Tiếng Anh', '2', 'CS1', 'Đỗ Mai Phương', 14, 18, 'Đã đóng', 'Đã kết thúc', 'CLS-2608-0002'),
        ('CS5-2627-ANH-K06-CB-A-002', '', 'Tiếng Anh', '6', 'CS5', '—', 0, 18, 'Huỷ', '—', '')]
def lop_code_cell(c, grp, old):
    return '<span class="hmt-code">%s</span>' % c + ('<div class="hmt-help">tên chung %s</div>' % grp if grp else '') + ('<div class="hmt-help">mã cũ %s</div>' % old if old else '')
def cfg_lop01():
    return dict(code='LOP-01', h1='Lớp học', nav='Lớp học', group=4, crumb=[('Đào tạo', False), ('Lớp học', True)], create=True,
        ph='Tìm mã lớp, tên chung nhóm, giáo viên, mã cũ (Sheet)…', noun='lớp', total=47, nochk=True,
        heads=[('Mã lớp', 0), ('Môn', 0), ('Khối', 0), ('Cơ sở', 0), ('Giáo viên', 0), ('Sĩ số', 1), ('Còn chỗ', 1), ('Tình trạng duyệt', 0), ('Vận hành', 0)],
        rows=[[lop_code_cell(c, g, o), m, k, cs, gv, N('%d/%d' % (s, mx)), N(mx - s), tag(d, LOP_DUYET[d]), tag(v, LOP_VH[v]) if v != '—' else '<span class="hmt-help">—</span>'] for c, g, m, k, cs, gv, s, mx, d, v, o in LOPL],
        tfields=[('Mã lớp', 'Mã lớp'), ('Giáo viên', 'Giáo viên')], favs=[('Lớp chờ tôi duyệt', True, "{'Tình trạng duyệt':['Đã trình','Đã xác nhận']}"), ('Lớp đang học', False, "{'Vận hành':['Đang học']}")],
        gfields=[('Tình trạng duyệt', 'Tình trạng duyệt', False), ('Vận hành', 'Vận hành', False), ('Cơ sở', 'Cơ sở', False), ('Môn', 'Môn', False)],
        filters=[('Tình trạng duyệt', [(k, k) for k in LOP_DUYET]), ('Vận hành', [(k, k) for k in ('Chưa khai giảng', 'Đang học', 'Đã kết thúc')]), ('Cơ sở', [(x, x) for x in ('CS1', 'CS2', 'CS4', 'CS5')]),
                 ('Môn', [(x, x) for x in ('Toán', 'Đại số', 'Hình học', 'Tiếng Anh')]), ('Khối', [(str(i), str(i)) for i in range(2, 13)])],
        link='Mở lớp (màn LOP-02).', toasts="{'Tạo':'Mở biểu mẫu tạo lớp (màn LOP-03).','Xuất':'Đang xuất danh sách lớp ra file.'}",
        hint='Thử tìm bằng mã lớp, tên chung của nhóm, tên giáo viên hoặc mã cũ trong Sheet (ví dụ CLS-2609-0014).', eicon='book', etitle='Chưa có lớp nào',
        esub='Bấm Tạo để lập lớp nháp (LOP-03). Lớp phải qua các bước trình, xác nhận, duyệt mới sinh buổi học (R-LOP-01, R-LOP-03).', export=('cs', 'bm', 'ad'),
        who='Vai trò Giáo viên chưa được cấp quyền xem danh sách và hồ sơ lớp học.')

# ---------- LOP-01 kanban (K04) ----------
KAN = [('Nháp', ''), ('Đã trình', 'info'), ('Đã xác nhận', 'brand'), ('Đã duyệt', 'success'), ('Đã đóng', ''), ('Từ chối', 'danger'), ('Huỷ', 'danger')]
def kan_card(c, g, m, k, cs, gv, s, mx, d, v, o, ini):
    nm = {'DAI': 'Đại số', 'HINH': 'Hình học'}
    name = '%s %s' % (m, k) + (' · cơ bản ' + c.split('-')[-2] if '-CB-' in c else ' · lớp riêng')
    return ('<article class="hmt-kcard"><span class="hmt-code">%s</span><a href="#">%s</a><span class="hmt-kcard-m">%s · %s</span><span class="hmt-kcard-m">Sĩ số %d/%d%s</span>%s'
            '<div class="hmt-kcard-f">%s<span class="hmt-avatar" title="Người soạn" aria-label="Người soạn: %s">%s</span></div></article>') % (
            c, name, gv if gv != '—' else 'Chưa có giáo viên', cs, s, mx, (' · nhóm ' + g) if g else '', '' if not g else '', tag(v, LOP_VH[v]) if v != '—' else '<span class="hmt-tag">Đã huỷ</span>', ini, ini)
def kan_html():
    ini = {'CS1': 'NL', 'CS2': 'HA', 'CS4': 'VH', 'CS5': 'TL'}
    cols = ''
    for st, kind in KAN:
        rs = [r for r in LOPL if r[8] == st]
        full = sum(1 for r in rs if r[6] >= r[7]); near = sum(1 for r in rs if r[7] and r[6] < r[7] and r[6] / r[7] >= .9)
        n = max(len(rs), 1)
        bar = '<div class="hmt-kbar" role="img" aria-label="Sĩ số các lớp trong cột"><i class="ok" style="width:%d%%"></i><i class="warn" style="width:%d%%"></i><i class="bad" style="width:%d%%"></i></div>' % (100 * (len(rs) - full - near) // n if rs else 0, 100 * near // n, 100 * full // n)
        cols += '<section class="hmt-kcol" style="flex:0 0 256px;width:256px"><div class="hmt-kcol-h">%s<span class="n">%d</span><button class="hmt-iconbtn" type="button" aria-label="Tạo lớp nháp" data-do="Mở biểu mẫu tạo lớp (màn LOP-03).">%s</button></div>%s%s</section>' % (
            st, len(rs), SVG(IC['plus']), bar, ''.join(kan_card(*r, ini[r[4]]) for r in rs))
    return '<div class="hmt-kan">' + cols + '</div><span class="hmt-help">Kéo thẻ sang bước kế tiếp sẽ mở hộp xác nhận (LOP-05), không đổi thẳng. Duyệt bắt buộc có thời khoá biểu. Từ chối và Huỷ chọn bằng nút trên bản ghi, không kéo.</span>'
def build_kanban(role='bm'):
    s = KC.read('TS07_K2.dc.html')
    s = sidebar_bh(s, 'Lớp học', 4)
    s = KC.crumb(s, [('Đào tạo', False), ('Lớp học', True)])
    s = KC.user(s, *USERS[role][:2], USERS[role][2])
    s = s.replace('<h1>Cơ hội</h1>', '<h1>Lớp học</h1>', 1)
    s = re.sub(r'<button class="hmt-btn" type="button"><svg[^>]*>(?:(?!</svg>).)*</svg>Nhập</button>', '', s, count=1, flags=re.S)
    s = s.replace('placeholder="Tìm tên, SĐT, mã (cả mã cũ)…"', 'placeholder="Tìm mã lớp, tên chung nhóm, giáo viên, mã cũ (Sheet)…"', 1)
    s = s.replace('<span>Ngày tạo</span>', '<span>Ngày khai giảng</span>', 1)
    s = s.replace('1–16 / 16', '1–%d / 47' % len(LOPL), 1)
    s = s.replace('Làm mới</button>', 'Làm mới</button>', 1)
    i = s.index('<div class="hmt-kan">'); s, _ = remove_div(s, i)
    s = re.sub(r'<span class="hmt-help">Kéo thẻ chỉ thả được[^<]*</span>', '', s, count=1)
    s = s[:i] + kan_html() + s[i:]
    s = s.replace('renderVals() {\n    return { yes: true };\n  }', "renderVals() {\n    return { yes: true };\n  }\n  componentDidMount() { const R = document.querySelector('[data-ix=root]'); if (!R) return; let t = null; const toast = m => { let e = R.querySelector('.ix-toast'); if (!e) { e = document.createElement('div'); e.className = 'ix-toast'; e.style.cssText = 'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);background:var(--text-primary);color:#fff;padding:10px 16px;border-radius:8px;font-size:13px;z-index:90'; R.appendChild(e); } e.textContent = m; e.style.display = 'block'; clearTimeout(t); t = setTimeout(() => { e.style.display = 'none'; }, 2600); };\n    R.addEventListener('click', ev => { const a = ev.target.closest('.hmt-kcard a'); if (a) { ev.preventDefault(); toast('Mở lớp (màn LOP-02).'); return; } const d = ev.target.closest('[data-do]'); if (d) { ev.preventDefault(); toast(d.getAttribute('data-do')); return; } const b = ev.target.closest('.hmt-seg button'); if (b) toast(b.getAttribute('title') === 'Danh sách' ? 'Chuyển sang dạng danh sách (LOP-01).' : b.getAttribute('title') === 'Calendar' ? 'Lớp học không có dạng lịch; xem Lịch tuần cơ sở (LOP-08).' : 'Đang ở dạng Kanban.'); }, true); }", 1)
    return KC.retitle(s, 'LOP-01 · Lớp học · kanban theo bước duyệt')

# ---------- hộp thoại K08 ----------
def d_ctx(code, extra=''):
    return '<div style="display:flex;gap:var(--space-3);flex-wrap:wrap;align-items:center;font-size:13px;margin-bottom:var(--space-3)"><span class="hmt-code">%s</span><span>Đại số 9 · cơ bản A · CS1</span>%s</div>' % (code, extra)
def reason(label='Lý do', req=True):
    return '<label class="hmt-field" style="margin-top:var(--space-3)"><span class="hmt-label">%s%s</span><textarea class="hmt-textarea" rows="3" placeholder="Nêu rõ lý do"></textarea></label>' % (label, ' <span class="hmt-req">*</span>' if req else '')
FOOT_C = btn('Đóng', '', None, 'data-close="1"')
def d_lop05(kind, code='CS1-2627-DAI-K09-CB-A-001'):
    T = {'trinh': ('Trình lớp', 'Trình lớp', 'Đã trình lớp. Chờ quản lý cơ sở xác nhận.'), 'xacnhan': ('Xác nhận lớp', 'Xác nhận', 'Đã xác nhận lớp. Chờ duyệt.'),
         'duyet': ('Duyệt lớp', 'Duyệt', 'Đã duyệt lớp. Hệ thống đang sinh 24 buổi học từ thời khoá biểu.'), 'tuchoi': ('Từ chối lớp', 'Từ chối', 'Đã từ chối. Lớp quay về Nháp để sửa.'), 'venhap': ('Đưa lớp về Nháp', 'Đưa về Nháp', 'Lớp đã về Nháp, sửa được.')}[kind]
    if kind == 'trinh':
        body = d_ctx(code) + alert('info', 'Vận hành soạn và trình; <b>quản lý cơ sở</b> xác nhận rồi duyệt (R-LOP-02). Sau khi trình, lớp bị khoá sửa cho tới khi được duyệt hoặc từ chối.', 'alert')
    elif kind == 'xacnhan':
        body = d_ctx(code) + alert('info', 'Xác nhận là bước kiểm lần một. Duyệt ở bước sau mới sinh buổi học.', 'check')
    elif kind == 'duyet':
        body = (d_ctx(code, '<span class="hmt-tag hmt-tag-success">Có thời khoá biểu</span>') + sec('XEM TRƯỚC CÁC BUỔI SẼ SINH') +
                '<div class="hmt-kvs" style="display:grid;grid-template-columns:auto 1fr;gap:6px 16px;font-size:13px;margin-bottom:var(--space-3)"><span class="hmt-help">Số buổi</span><b class="hmt-num">24</b><span class="hmt-help">Buổi đầu</span><span class="hmt-num">Thứ 3, 03/11/2026</span><span class="hmt-help">Ngày kết thúc dự kiến</span><span class="hmt-num">05/03/2027</span><span class="hmt-help">Đã bỏ ngày nghỉ lễ</span><span>7 ngày (bảng ngày nghỉ)</span></div>' +
                alert('info', 'Duyệt xong hệ thống <b>tự sinh buổi</b> theo thời khoá biểu và cách lặp từng khung (R-LOP-03, R-LOP-13). Không còn nút sinh buổi bằng tay.', 'check'))
    elif kind == 'tuchoi':
        body = d_ctx(code) + reason('Lý do từ chối') + '<div class="hmt-help" style="margin-top:6px">Lớp về Nháp, người soạn thấy lý do này để sửa.</div>'
    else:
        body = d_ctx(code) + alert('info', 'Lớp bị Từ chối quay về Nháp để sửa rồi trình lại (R-LOP-01). Thông tin lớp sửa được ở Nháp và Từ chối.', 'alert')
    dis = ' disabled' if kind == 'duyet_loi' else ''
    foot = FOOT_C + btn(T[1], 'danger' if kind == 'tuchoi' else 'primary', None, 'data-dto="%s"' % T[2])
    return dialog('lop05_' + kind, T[0], '<h2>%s</h2>' % T[0], body, foot, w=560)
def d_lop05_thieu_tkb(code='CS1-2627-ANH-K07-CB-A-001'):
    body = d_ctx(code) + alert('danger', '<b>Chưa duyệt được: lớp chưa có thời khoá biểu.</b> Duyệt bắt buộc có thời khoá biểu để hệ thống tự sinh buổi (R-LOP-03). Thêm ít nhất một khung giờ ở màn Thời khoá biểu (LOP-04).', 'alert')
    return dialog('lop05_duyet', 'Duyệt lớp', '<h2>Duyệt lớp</h2>', body, FOOT_C + btn('Mở thời khoá biểu', '', None, 'data-do="Mở thời khoá biểu lớp (màn LOP-04)."') + btn('Duyệt', 'primary', None, 'disabled'), w=560)
def d_lop06(kind, blocked=False, code='CS1-2627-DAI-K09-CB-A-001'):
    if kind == 'dong':
        head, ok = 'Đóng lớp', 'Đã đóng lớp.'
        if blocked:
            rows = [['Trần Gia Hân', 'GD000310', N('36')], ['Đỗ Phương Thảo', 'GD000311', N('40')], ['Bùi Tuệ Minh', 'GD000312', N('32')], ['Vũ Hải Đăng', 'GD000313', N('4')]]
            body = d_ctx(code) + alert('danger', '<b>Chưa đóng được: còn 4 học sinh còn giờ.</b> Chuyển lớp hoặc xử lý giờ cho các em trước (R-LOP-04).', 'alert') + table([('Học sinh', 0), ('Ghi danh', 0), ('Giờ còn', 1)], [[L(a), C(b), c] for a, b, c in rows], cls='', widths=[220, 140, 100], wrap=True)
            foot = FOOT_C + btn('Đóng lớp', 'primary', None, 'disabled')
        else:
            body = d_ctx(code) + alert('info', 'Lớp không còn học sinh còn giờ. Đóng lớp là bước cuối, không mở lại.', 'check') + reason('Ghi chú', False)
            foot = FOOT_C + btn('Đóng lớp', 'primary', None, 'data-dto="%s"' % ok)
    else:
        head, ok = 'Huỷ lớp', 'Đã huỷ lớp.'
        if blocked:
            body = d_ctx(code) + alert('danger', '<b>Chưa huỷ được: lớp đã có 4 buổi Done.</b> Lớp đã dạy thì đóng lớp, không huỷ (R-LOP-04).', 'alert')
            foot = FOOT_C + btn('Huỷ lớp', 'danger', None, 'disabled')
        else:
            body = d_ctx(code) + alert('warning', 'Huỷ lớp là bước cuối: các buổi chưa diễn ra cũng bị huỷ.', 'alert') + reason('Lý do huỷ')
            foot = FOOT_C + btn('Huỷ lớp', 'danger', None, 'data-dto="%s"' % ok)
    return dialog('lop06_' + kind + ('_chan' if blocked else ''), head, '<h2>%s</h2>' % head, body, foot, w=600)
def d_lop07(code='CS1-2627-DAI-K09-CB-A-001'):
    rows = [['Thứ 3', '17/11/2026', '18:00–19:30', 'Nguyễn Văn Nam', 'Phạm Hải Yến'], ['Thứ 6', '20/11/2026', '18:00–19:30', 'Nguyễn Văn Nam', 'Phạm Hải Yến'], ['Thứ 6', '27/11/2026', '18:00–19:30', 'Nguyễn Văn Nam', 'Phạm Hải Yến']]
    body = (d_ctx(code) + '<div style="display:flex;gap:var(--space-4);margin-bottom:var(--space-3)"><label class="hmt-field" style="flex:1"><span class="hmt-label">Giáo viên mới <span class="hmt-req">*</span></span><select class="hmt-input hmt-select"><option>Phạm Hải Yến</option><option>Trần Minh Đức</option></select></label>'
            '<label class="hmt-field" style="width:180px"><span class="hmt-label">Từ ngày <span class="hmt-req">*</span></span><input class="hmt-input" value="17/11/2026" aria-label="Từ ngày"></label></div>' +
            sec('XEM TRƯỚC: 14 BUỔI CHƯA DIỄN RA SẼ SINH LẠI (hiện 3 buổi đầu)') + table([('Thứ', 0), ('Ngày', 0), ('Giờ', 0), ('Giáo viên cũ', 0), ('Giáo viên mới', 0)], [[a, N(b), N(c), d, '<b>%s</b>' % e] for a, b, c, d, e in rows], cls='', widths=[70, 110, 110, 160, 160], wrap=True) +
            '<div class="hmt-alert hmt-alert-info" role="status" style="margin-top:var(--space-3)">' + SVG(IC['alert']) + '<span>Các buổi đã Done giữ nguyên giáo viên cũ. Đổi giáo viên <b>một buổi</b> (dạy thay) sửa ngay trên buổi đó (BUOI-13) (R-LOP-10, R-LOP-11).</span></div>')
    return dialog('lop07', 'Đổi giáo viên', '<h2>Đổi giáo viên và sinh lại buổi chưa diễn ra</h2>', body, FOOT_C + btn('Xác nhận', 'primary', None, 'data-dto="Đã đổi giáo viên và sinh lại 14 buổi chưa diễn ra."'), w=760)
def d_lop10(code='CS1-2627-DAI-K09-CB-A-001'):
    rows = [['Thứ 3 → Thứ 4', '17/11/2026', '18:00–19:30', 'P201 → P201'], ['Thứ 3 → Thứ 4', '01/12/2026', '18:00–19:30', 'P201 → P201'], ['Thứ 6 → Thứ 6', '20/11/2026', '18:00–19:30', 'P201 → P203']]
    body = (d_ctx(code) + '<div style="display:flex;gap:var(--space-4);margin-bottom:var(--space-3)"><label class="hmt-field" style="flex:1"><span class="hmt-label">Khung giờ cần đổi <span class="hmt-req">*</span></span><select class="hmt-input hmt-select"><option>Thứ 3 · 18:00–19:30 · lặp mỗi 2 tuần</option><option>Thứ 6 · 18:00–19:30 · hàng tuần</option></select></label>'
            '<label class="hmt-field" style="width:120px"><span class="hmt-label">Thứ mới</span><select class="hmt-input hmt-select"><option>Thứ 4</option></select></label><label class="hmt-field" style="width:150px"><span class="hmt-label">Phòng mới</span><select class="hmt-input hmt-select"><option>P201</option><option>P203</option></select></label></div>' +
            sec('XEM TRƯỚC: 14 BUỔI CHƯA DIỄN RA SẼ ĐỔI (hiện 3 buổi đầu)') + table([('Thay đổi', 0), ('Ngày', 0), ('Giờ', 0), ('Phòng', 0)], [[a, N(b), N(c), d] for a, b, c, d in rows], cls='', widths=[140, 110, 110, 160], wrap=True) +
            alert('warning', 'Trùng phòng chỉ <b>cảnh báo</b>, không chặn; kiểm ở cấp buổi thật. Phòng P203 ngày 20/11 đã có lớp khác: vẫn cho lưu (R-LOP-08).', 'alert'))
    return dialog('lop10', 'Đổi lịch cố định', '<h2>Đổi lịch cố định của lớp đã duyệt</h2>', body, FOOT_C + btn('Xác nhận', 'primary', None, 'data-dto="Đã đổi lịch cố định và sinh lại các buổi chưa diễn ra."'), w=760)

# ---------- LOP-02 bản ghi ----------
TKB = [('Thứ 3', '18:00–19:30', 'Nguyễn Văn Nam', 'Phạm Hải Yến', 'P201', 'Mỗi 2 tuần', '03/11/2026'), ('Thứ 6', '18:00–19:30', 'Nguyễn Văn Nam', 'Phạm Hải Yến', 'P201', 'Hàng tuần', '06/11/2026')]
LP = {
 'nhap': dict(code='CS1-2627-ANH-K04-CB-A-001', old='', grp='', name='Tiếng Anh 4 · cơ bản A', mon='Tiếng Anh', khoi='4', pl='Lớp chung · cơ bản', td='A', gv='—', mx=18, kg='ANH-K04-CB-2627 · bản 1', bd='Bài 1', kgd='02/11/2026', end='chưa tính (chưa có thời khoá biểu)', duyet='Nháp', vh='Chưa khai giảng', cur=0, user='cs', tkb=[], hs=[], sobuoi=0),
 'da_trinh': dict(code='CS1-2627-DAI-K09-CB-B-002', old='', grp='9M2', name='Đại số 9 · cơ bản B', mon='Đại số', khoi='9', pl='Lớp chung · cơ bản', td='B', gv='Nguyễn Văn Nam', mx=20, kg='DAI-K09-CB-2627 · bản 2', bd='Bài 1', kgd='10/11/2026', end='12/03/2027', duyet='Đã trình', vh='Chưa khai giảng', cur=1, user='bm', tkb=[('Thứ 2', '19:30–21:00', 'Nguyễn Văn Nam', '—', 'P202', 'Hàng tuần', '16/11/2026')], hs=[], sobuoi=24),
 'da_xac_nhan': dict(code='CS1-2627-ANH-K07-CB-A-001', old='', grp='', name='Tiếng Anh 7 · cơ bản A', mon='Tiếng Anh', khoi='7', pl='Lớp chung · cơ bản', td='A', gv='Đỗ Mai Phương', mx=18, kg='ANH-K07-CB-2627 · bản 1', bd='Bài 1', kgd='09/11/2026', end='', duyet='Đã xác nhận', vh='Chưa khai giảng', cur=2, user='bm', tkb=[], hs=[], sobuoi=0),
 'da_duyet': dict(code='CS1-2627-DAI-K09-CB-A-001', old='CLS-2609-0014', grp='9M1', name='Đại số 9 · cơ bản A', mon='Đại số', khoi='9', pl='Lớp chung · cơ bản', td='A', gv='Nguyễn Văn Nam', mx=20, kg='DAI-K09-CB-2627 · bản 2', bd='Bài 1', kgd='15/09/2026', end='05/03/2027', duyet='Đã duyệt', vh='Đang học', cur=3, user='bm', tkb=TKB, sobuoi=24,
                  hs=[('GD000310', 'Trần Gia Hân', '15/09/2026', '36', 'Đang học'), ('GD000311', 'Đỗ Phương Thảo', '15/09/2026', '40', 'Đang học'), ('GD000312', 'Bùi Tuệ Minh', '22/09/2026', '32', 'Đang học'), ('GD000313', 'Vũ Hải Đăng', '15/09/2026', '4', 'Đang học')]),
 'tu_choi': dict(code='CS4-2627-ANH-K06-CB-A-001', old='', grp='', name='Tiếng Anh 6 · cơ bản A', mon='Tiếng Anh', khoi='6', pl='Lớp chung · cơ bản', td='A', gv='Vũ Thị Hằng', mx=18, kg='ANH-K06-CB-2627 · bản 1', bd='Bài 1', kgd='02/11/2026', end='05/02/2027', duyet='Từ chối', vh='Chưa khai giảng', cur=0, user='cs', tkb=[('Thứ 5', '18:00–19:30', 'Vũ Thị Hằng', '—', 'P102', 'Hàng tuần', '05/11/2026')], hs=[], sobuoi=24),
 'da_dong': dict(code='CS1-2627-ANH-K02-CB-A-001', old='CLS-2608-0002', grp='', name='Tiếng Anh 2 · cơ bản A', mon='Tiếng Anh', khoi='2', pl='Lớp chung · cơ bản', td='A', gv='Đỗ Mai Phương', mx=18, kg='ANH-K02-CB-2627 · bản 1', bd='Bài 1', kgd='01/09/2026', end='30/09/2026', duyet='Đã đóng', vh='Đã kết thúc', cur=4, user='bm', tkb=[('Thứ 7', '09:00–10:30', 'Đỗ Mai Phương', '—', 'P101', 'Hàng tuần', '05/09/2026')], sobuoi=12,
                 hs=[('GD000205', 'Nguyễn Bảo Ngọc', '05/09/2026', '0', 'Hoàn thành'), ('GD000206', 'Lê Hà Anh', '05/09/2026', '0', 'Hoàn thành')]),
 'huy': dict(code='CS5-2627-ANH-K06-CB-A-002', old='', grp='', name='Tiếng Anh 6 · cơ bản A', mon='Tiếng Anh', khoi='6', pl='Lớp chung · cơ bản', td='A', gv='—', mx=18, kg='ANH-K06-CB-2627 · bản 1', bd='Bài 1', kgd='02/11/2026', end='', duyet='Huỷ', vh='—', cur=None, user='bm', tkb=[], hs=[], sobuoi=0),
}
LP_T = {'nhap': 'Nháp (chưa có thời khoá biểu)', 'da_trinh': 'Đã trình', 'da_xac_nhan': 'Đã xác nhận (chưa duyệt được: thiếu thời khoá biểu)', 'da_duyet': 'Đã duyệt, đang học (nhóm luân phiên Đại, Hình)', 'tu_choi': 'Từ chối', 'da_dong': 'Đã đóng (chỉ đọc)', 'huy': 'Huỷ (chỉ đọc)', 'tai': 'Đang tải', 'quyen': 'Không có quyền'}
def lop_buoi_tab(g, state):
    if g['duyet'] != 'Đã duyệt' and g['duyet'] != 'Đã đóng':
        return '<div class="hmt-help">Chưa có buổi học. Khi lớp được <b>duyệt</b>, hệ thống tự sinh %s buổi theo thời khoá biểu (R-LOP-03).</div>' % (g['sobuoi'] or 'các')
    rows = {'da_duyet': [(1, '15/09/2026', 'Thứ 3', '18:00–19:30', 'P201', 'Done'), (2, '18/09/2026', 'Thứ 6', '18:00–19:30', 'P201', 'Done'), (3, '29/09/2026', 'Thứ 3', '18:00–19:30', 'P201', 'Done'), (4, '02/10/2026', 'Thứ 6', '18:00–19:30', 'P201', 'Done'), (5, '20/10/2026', 'Thứ 3', '18:00–19:30', 'P201', 'Đã chốt')],
            'da_dong': [(11, '19/09/2026', 'Thứ 7', '09:00–10:30', 'P101', 'Done'), (12, '26/09/2026', 'Thứ 7', '09:00–10:30', 'P101', 'Done')]}[state]
    bt = {'Done': 'success', 'Đã chốt': 'info'}
    return table([('Buổi', 1), ('Ngày', 0), ('Thứ', 0), ('Giờ', 0), ('Phòng', 0), ('Tình trạng', 0)], [[N(a), N(b), c, N(d), e, tag(f, bt[f])] for a, b, c, d, e, f in rows], cls='', widths=[70, 110, 80, 120, 90, 110], wrap=True) + '<div class="hmt-help">Chỉ hiện vài buổi. <a href="#" data-do="Mở danh sách buổi của lớp (màn BUOI-01).">Mở danh sách buổi đầy đủ</a></div>'
def lop_chatter(state):
    s = lambda t, m, chg_=None: sysmsg(t, m, chg=chg_)
    ev = {'nhap': [('16/10/2026', [s('09:10', 'Lớp được tạo ở trạng thái Nháp. Mã lớp tự cấp: CS1-2627-ANH-K04-CB-A-001.')])],
          'da_trinh': [('17/10/2026', [s('10:20', 'Nguyễn Thị Lan trình lớp. Chờ quản lý cơ sở xác nhận.', ('Nháp', 'Đã trình'))]), ('16/10/2026', [s('15:00', 'Lớp được tạo cùng nhóm 9M2 (tên chung 9M2).')])],
          'da_xac_nhan': [('17/10/2026', [s('14:30', 'Lê Văn Phong xác nhận lớp.', ('Đã trình', 'Đã xác nhận')), s('09:00', 'Nguyễn Thị Lan trình lớp.', ('Nháp', 'Đã trình'))])],
          'da_duyet': [('14/09/2026', [s('08:00', 'Lê Văn Phong duyệt lớp. Hệ thống tự sinh 24 buổi theo thời khoá biểu.', ('Đã xác nhận', 'Đã duyệt'))]), ('13/09/2026', [s('16:00', 'Lê Văn Phong xác nhận lớp.', ('Đã trình', 'Đã xác nhận'))])],
          'tu_choi': [('16/10/2026', [s('11:45', 'Lê Văn Phong từ chối: Phòng P102 thứ 5 18:00 đã có lớp khác, xem lại thời khoá biểu.', ('Đã trình', 'Từ chối'))])],
          'da_dong': [('30/09/2026', [s('17:00', 'Lê Văn Phong đóng lớp. Không còn học sinh còn giờ.', ('Đã duyệt', 'Đã đóng'))])],
          'huy': [('16/10/2026', [s('10:00', 'Lê Văn Phong huỷ lớp. Lý do: Không đủ học sinh khai giảng.', ('Nháp', 'Huỷ'))])]}
    return chatter(ev.get(state, []), readonly=state in ('da_dong', 'huy'))
def build_lop(state, show0='', title_over=None):
    title = title_over or 'LOP-02 · Lớp · ' + LP_T[state]
    if state == 'quyen': return noperm_page(title, 'lớp học', who_can='Vai trò Giáo viên chưa được cấp quyền xem hồ sơ lớp học.')
    if state == 'tai': return loading_page(title, 'Lớp học', 'bm', [('Đào tạo', False), ('Lớp học', False), ('Đang tải…', True)], 'Lớp học')
    g = LP[state]; u = g['user']
    crumb = [('Đào tạo', False), ('Lớp học', False), (g['code'], True)]
    br = None; note = None
    if g['duyet'] == 'Từ chối': br = [('Từ chối', 'danger')]; note = 'quay về Nháp để sửa rồi trình lại'
    if g['duyet'] == 'Huỷ': br = [('Huỷ', 'danger')]; note = 'đã huỷ, chỉ còn xem'
    stg = stage(['Nháp', 'Đã trình', 'Đã xác nhận', 'Đã duyệt', 'Đã đóng'], g['cur'] if g['cur'] is not None else 0, branches=br, note=note)
    if g['duyet'] == 'Từ chối': stg = stage(['Nháp', 'Đã trình', 'Đã xác nhận', 'Đã duyệt', 'Đã đóng'], 0, branches=br, note=note)
    if g['duyet'] == 'Huỷ': stg = stage(['Nháp', 'Đã trình', 'Đã xác nhận', 'Đã duyệt', 'Đã đóng'], None, branches=br, note=note)
    code_html = '<span class="hmt-code">%s</span>' % g['code']
    sub = ('<span class="hmt-help">tên chung nhóm %s</span>' % g['grp']) if g['grp'] else ''
    oldf = ('<span class="hmt-num">%s</span><span class="hmt-auto">chỉ xem, Admin sửa được</span>' % g['old']) if g['old'] else '<span class="hmt-help">— (lớp mới, không có mã cũ)</span>'
    head = fgrid([kv('Mã cũ (Sheet)', oldf), kv('Môn', g['mon']), kv('Khối', numc(g['khoi'])), kv('Phân loại', g['pl']), kv('Trình độ', g['td']), kv('Cơ sở', 'CS' + g['code'][2] + (' Nguyễn Chí Thanh' if g['code'][2] == '1' else ''))],
                 [kv('Giáo viên', link(g['gv'], 'Mở hồ sơ giáo viên (màn QT-16).') if g['gv'] != '—' else '<span class="hmt-help">chưa chọn</span>'), kv('Sĩ số tối đa', numc(g['mx'])), kv('Khung chương trình', g['kg']), kv('Bài bắt đầu', g['bd']), kv('Ngày khai giảng', numc(g['kgd'])), kv('Ngày kết thúc dự kiến', (numc(g['end']) if g['end'] and g['end'][0].isdigit() else '<span class="hmt-help">%s</span>' % (g['end'] or 'chưa tính')), 'hệ thống tự tính, chỉ để dự báo')])
    # nhóm lớp
    if g['grp']:
        other = {'CS1-2627-DAI-K09-CB-A-001': ('CS1-2627-HINH-K09-CB-A-001', 'Hình học 9 · cơ bản A', 'Lê Thu Trang'), 'CS1-2627-DAI-K09-CB-B-002': ('CS1-2627-HINH-K09-CB-B-002', 'Hình học 9 · cơ bản B', 'Lê Thu Trang')}[g['code']]
        nhom = (sec('NHÓM LỚP') + '<div style="display:flex;gap:var(--space-3);align-items:center;flex-wrap:wrap;font-size:13px"><span>Lớp còn lại của nhóm:</span><a href="#" data-do="Mở lớp còn lại của nhóm (màn LOP-02).">%s</a><span class="hmt-code">%s</span><span class="hmt-help">GV %s</span>%s</div>' % (other[1], other[0], other[2], tag('Nháp' if '-B-' in g['code'] else 'Đã duyệt', '' if '-B-' in g['code'] else 'success')) +
                '<div class="hmt-help">Nhóm không có mã riêng. Mỗi lớp trong nhóm vẫn độc lập: giáo viên, lịch, sĩ số, bước duyệt riêng (R-LOP-14).</div>')
    else:
        nhom = sec('NHÓM LỚP') + '<div class="hmt-help">Lớp không thuộc nhóm nào. Lớp Đại số, Hình học cùng khối, cùng cơ sở có thể gắn vào một nhóm khi tạo hoặc sửa lớp (LOP-03).</div>'
    al = ''
    if state == 'nhap': al = alert('info', 'Lớp ở Nháp: sửa được thông tin. <b>Chưa có thời khoá biểu</b>, nên chưa duyệt được. Thêm khung giờ ở tab Thời khoá biểu rồi bấm Trình.', 'alert')
    if state == 'da_xac_nhan': al = alert('warning', '<b>Chưa có thời khoá biểu.</b> Bước Duyệt bắt buộc có thời khoá biểu để tự sinh buổi (R-LOP-03). Bấm Duyệt sẽ báo thiếu.', 'alert')
    if state == 'tu_choi': al = alert('danger', '<b>Bị từ chối bởi Lê Văn Phong (16/10/2026):</b> Phòng P102 thứ 5 18:00 đã có lớp khác, xem lại thời khoá biểu. Sửa được; bấm “Đưa về Nháp” hoặc sửa rồi trình lại.', 'alert')
    if state == 'da_dong': al = alert('info', 'Lớp đã đóng ngày 30/09/2026. Chỉ xem, không sửa (R-LOP-04).', 'lock')
    if state == 'huy': al = alert('info', 'Lớp đã huỷ ngày 16/10/2026. Lý do: Không đủ học sinh khai giảng. Chỉ xem.', 'lock')
    if state == 'da_trinh': al = alert('info', 'Lớp đã trình, đang chờ quản lý cơ sở xác nhận. Không sửa được thông tin cho tới khi được duyệt hoặc từ chối (R-LOP-02).', 'lock')
    thong_tin = al + head + nhom
    tk_rows = [[a, N(b), c, d, e, f, N(gg)] for a, b, c, d, e, f, gg in g['tkb']]
    editable = state in ('nhap', 'tu_choi')
    tk = (table([('Thứ', 0), ('Giờ', 0), ('Giáo viên', 0), ('Trợ giảng', 0), ('Phòng', 0), ('Cách lặp', 0), ('Buổi đầu tiên', 0)], tk_rows, cls='', widths=[70, 120, 160, 150, 80, 110, 120], wrap=True) if tk_rows else
          '<div class="hmt-help">Chưa có khung giờ nào. Duyệt bắt buộc có thời khoá biểu (R-LOP-03).</div>')
    if g['grp'] and state == 'da_duyet': tk += '<div class="hmt-help">Khung Thứ 3 luân phiên với lớp Hình học 9 cơ bản A: cùng thứ, giờ, phòng, lặp mỗi 2 tuần, buổi đầu cách nhau 1 tuần (R-LOP-13). Không báo trùng.</div>'
    tk += '<div>' + (btn('Mở thời khoá biểu', '', 'cal', 'data-do="Mở thời khoá biểu lớp (màn LOP-04)."') if g['duyet'] not in ('Đã đóng', 'Huỷ') else '') + '</div>'
    hs_t = (table([('Ghi danh', 0), ('Học sinh', 0), ('Ngày vào lớp', 0), ('Giờ còn', 1), ('Tình trạng', 0)], [[C(a), L(b), N(c), N(d), tag(e, 'success' if e == 'Đang học' else '')] for a, b, c, d, e in g['hs']], cls='', widths=[120, 200, 120, 100, 120], wrap=True) if g['hs'] else
            '<div class="hmt-help">Chưa có học sinh được xếp vào lớp. Xếp lớp làm ở Hàng chờ xếp lớp (GD-06) sau khi lớp được duyệt.</div>')
    panels = [('Thông tin', thong_tin), ('Thời khoá biểu', tk), ('Học sinh', hs_t), ('Buổi học', lop_buoi_tab(g, state))]
    sh = sheet2('Lớp %s %s<div style="font-size:13px;font-weight:400;color:var(--text-secondary)">%s%s</div>' % (code_html, tag(g['duyet'], LOP_DUYET[g['duyet']]) + ' ' + (tag(g['vh'], LOP_VH[g['vh']]) if g['vh'] != '—' else ''), g['name'], (' · ' + sub) if sub else ''), '', panels)
    # nút
    B = {'nhap': [btn('Trình', 'primary', 'send', 'data-open="lop05_trinh"'), btn('Sửa', '', 'pencil', 'data-do="Mở biểu mẫu sửa lớp (màn LOP-03)."'), btn('Huỷ lớp', 'danger', None, 'data-open="lop06_huy"')],
         'da_trinh': [btn('Xác nhận', 'primary', 'check', 'data-open="lop05_xacnhan"'), btn('Từ chối', 'danger', None, 'data-open="lop05_tuchoi"'), btn('Huỷ lớp', '', None, 'data-open="lop06_huy"')],
         'da_xac_nhan': [btn('Duyệt', 'primary', 'check', 'data-open="lop05_duyet"'), btn('Từ chối', 'danger', None, 'data-open="lop05_tuchoi"'), btn('Huỷ lớp', '', None, 'data-open="lop06_huy"')],
         'da_duyet': [btn('Đổi giáo viên', '', 'users', 'data-open="lop07"'), btn('Đổi lịch cố định', '', 'cal', 'data-open="lop10"'), btn('Yêu cầu bổ trợ', '', 'plus', 'data-do="Mở yêu cầu buổi bổ trợ (màn BUOI-09)."'), btn('Đóng lớp', '', None, 'data-open="lop06_dong_chan"'), btn('Huỷ lớp', '', None, 'data-open="lop06_huy_chan"')],
         'tu_choi': [btn('Đưa về Nháp', 'primary', None, 'data-open="lop05_venhap"'), btn('Sửa', '', 'pencil', 'data-do="Mở biểu mẫu sửa lớp (màn LOP-03)."'), btn('Huỷ lớp', 'danger', None, 'data-open="lop06_huy"')],
         'da_dong': [], 'huy': []}[state]
    smt = smart([('Học sinh', len(g['hs'])), ('Buổi học', g['sobuoi'] if g['duyet'] in ('Đã duyệt', 'Đã đóng') else 0), ('Ghi danh', len(g['hs']))])
    dl = {'nhap': d_lop05('trinh', g['code']) + d_lop06('huy', False, g['code']), 'da_trinh': d_lop05('xacnhan', g['code']) + d_lop05('tuchoi', g['code']) + d_lop06('huy', False, g['code']),
          'da_xac_nhan': d_lop05_thieu_tkb(g['code']) + d_lop05('tuchoi', g['code']) + d_lop06('huy', False, g['code']),
          'da_duyet': d_lop07() + d_lop10() + d_lop06('dong', True) + d_lop06('huy', True), 'tu_choi': d_lop05('venhap', g['code']) + d_lop06('huy', False, g['code']), 'da_dong': '', 'huy': ''}[state]
    return page(title, 'Lớp học', u, crumb, rbar_l('Lớp', B), smt + stg + sh, lop_chatter(state), pager='3 / 47', dlgs=dl, show0=show0, group=4)

# ---------- LOP-03 biểu mẫu ----------
def inp(lab, val='', req=False, err=None, ph=''):
    e = (' hmt-input-err" aria-invalid="true' if err else '')
    return kv(lab + (' <span class="hmt-req">*</span>' if req else ''), '<input class="hmt-input%s" aria-label="%s" value="%s" placeholder="%s">' % (e, lab, val, ph) + (('<span class="ix-err">%s</span>' % err) if err else ''))
def sel(lab, opts, cur, req=False, err=None, hint=None, dis=False):
    o = ''.join('<option%s>%s</option>' % (' selected' if x == cur else '', x) for x in opts)
    e = (' hmt-input-err" aria-invalid="true' if err else '')
    return kv(lab + (' <span class="hmt-req">*</span>' if req else ''), '<select class="hmt-input hmt-select%s" aria-label="%s"%s>%s</select>' % (e, lab, ' disabled' if dis else '', o) + (('<span class="ix-err">%s</span>' % err) if err else ''), hint)
FORM_CSS = '<style>.ix-err{display:block;margin-top:4px;color:var(--danger-text);font-size:12px}</style>'
def build_form(variant):
    T = {'tao': 'Tạo lớp mới (nhóm lớp luân phiên Đại, Hình)', 'rieng': 'Tạo lớp riêng (khung chương trình tuỳ chọn)', 'sua': 'Sửa lớp bị từ chối', 'loi': 'Lỗi nhập liệu', 'tai': 'Đang tải', 'quyen': 'Không có quyền'}[variant]
    title = 'LOP-03 · Tạo / sửa lớp · ' + T
    if variant == 'quyen': return noperm_page(title, 'biểu mẫu tạo lớp', who_can='Chỉ CSKH, Trưởng cơ sở và Admin tạo và sửa lớp.')
    if variant == 'tai': return loading_page(title, 'Lớp học', 'cs', [('Đào tạo', False), ('Lớp học', False), ('Đang tải…', True)], 'Lớp')
    ed = variant == 'sua'
    crumb = [('Đào tạo', False), ('Lớp học', False), (('Sửa lớp CS4-2627-ANH-K06-CB-A-001') if ed else 'Tạo lớp', True)]
    L1 = ['CS1 Nguyễn Chí Thanh']
    mons = ['Toán', 'Đại số', 'Hình học', 'Tiếng Anh']
    e = variant == 'loi'
    if variant == 'rieng':
        mon, khoi, pl, td, nhom_sel, kg, ten = 'Toán', 'Lớp 9', 'Lớp riêng', '—', 'none', '(không bắt buộc)', ''
    elif ed:
        mon, khoi, pl, td, nhom_sel, kg, ten = 'Tiếng Anh', 'Lớp 6', 'Lớp chung', 'A', 'none', 'ANH-K06-CB-2627 · bản 1', ''
    else:
        mon, khoi, pl, td, nhom_sel, kg, ten = 'Đại số', 'Lớp 9', 'Lớp chung', 'A', 'new', 'DAI-K09-CB-2627 · bản 2', '9M1'
    cs_opts = ['CS1 Nguyễn Chí Thanh'] if variant != 'sua' else ['CS4']
    left = [sel('Cơ sở', cs_opts, cs_opts[0], True, hint='chỉ cơ sở của bạn; Admin chọn mọi cơ sở', dis=True), sel('Năm học', ['2026-2027'], '2026-2027', True), sel('Môn', mons, mon, True, hint='mã môn: TOAN, DAI, HINH, ANH…'), sel('Khối', ['Lớp %d' % i for i in range(2, 13)], khoi, True),
            sel('Phân loại', ['Lớp chung', 'Lớp riêng'], pl, True), sel('Trình độ', ['A', 'B', 'C', '—'], td, pl != 'Lớp riêng'), inp('Sĩ số tối đa', '1' if pl == 'Lớp riêng' else '20', True, 'Bắt buộc nhập sĩ số tối đa' if e else None)]
    if e: left[-1] = inp('Sĩ số tối đa', '', True, 'Bắt buộc nhập sĩ số tối đa')
    right = [kv('Mã lớp', '<span class="hmt-help">Hệ thống tự cấp khi lưu (không sửa được)</span>'),
             sel('Khung chương trình', ['(chưa chọn)', 'DAI-K09-CB-2627 · bản 2', 'ANH-K06-CB-2627 · bản 1', '(không bắt buộc)'], ('(chưa chọn)' if e else kg), pl != 'Lớp riêng', 'Lớp chung bắt buộc có khung chương trình' if e else None, 'bắt buộc với lớp chung, tuỳ chọn với lớp riêng'),
             sel('Bài bắt đầu', ['Bài 1', 'Bài 5', 'Bài 9'], 'Bài 1', False, hint='chỉ chọn khi lớp mở giữa chừng khung'), inp('Ngày khai giảng', '' if e else '10/11/2026', True, 'Bắt buộc nhập ngày khai giảng' if e else None, 'dd/mm/yyyy')]
    form = '<div>' + sec('THÔNG TIN LỚP') + '<div class="hmt-fgrid"><dl class="hmt-panel-b" style="padding:0">%s</dl><dl class="hmt-panel-b" style="padding:0">%s</dl></div></div>' % (''.join(left), ''.join(right))
    # nhóm lớp
    chk_ = lambda v, lab: '<label style="display:flex;gap:6px;align-items:center;font-size:13px"><input type="radio" name="nhom"%s> %s</label>' % (' checked' if nhom_sel == v else '', lab)
    nh = (sec('NHÓM LỚP (tuỳ chọn)') + '<div style="display:flex;gap:var(--space-5);flex-wrap:wrap;margin-bottom:var(--space-3)">' + chk_('none', 'Không thuộc nhóm') + chk_('old', 'Gắn vào nhóm có sẵn') + chk_('new', 'Tạo nhóm mới') + '</div>')
    if nhom_sel == 'new':
        nh += ('<div style="display:flex;gap:var(--space-4);align-items:flex-end;flex-wrap:wrap"><label class="hmt-field" style="width:260px"><span class="hmt-label">Tên chung của nhóm (không bắt buộc)</span><input class="hmt-input" aria-label="Tên chung của nhóm" value="%s"></label>' % ten +
               btn('Tạo lớp còn lại cho nhóm này', '', 'plus', 'data-do="Lưu lớp này, rồi mở biểu mẫu lớp Hình học 9 cùng cơ sở, cùng nhóm (đã điền sẵn)."') + '</div>')
        nh += '<div class="hmt-help" style="margin-top:6px">Nhóm không có mã riêng; tên chung chỉ là tham chiếu (ví dụ tên cũ 9M1), hiện nhỏ dưới mã lớp. Mỗi lớp trong nhóm vẫn độc lập (R-LOP-14).</div>'
    if nhom_sel == 'none' and variant != 'sua':
        nh += '<div class="hmt-help">Lớp riêng không gắn nhóm. Nhóm chỉ dành cho hai lớp Đại số và Hình học cùng khối, cùng cơ sở.</div>'
    if variant == 'sua': nh += '<div class="hmt-help">Lớp Tiếng Anh không thuộc nhóm.</div>'
    rem = alert('info', '<b>Nhắc nhẹ:</b> từ khối 7 lớp chung thường tách thành Đại số và Hình học; dưới khối 7 dùng Toán chung. Hiện chỉ nhắc, không chặn. <span class="hmt-tag hmt-tag-warning">chờ anh quyết</span>', 'alert') if variant in ('tao', 'rieng') else ''
    banner = alert('danger', '<b>Lớp bị từ chối bởi Lê Văn Phong:</b> Phòng P102 thứ 5 18:00 đã có lớp khác, xem lại thời khoá biểu. Sửa rồi bấm Lưu nháp, sau đó trình lại.', 'alert') if ed else ''
    erra = alert('danger', 'Còn 3 chỗ chưa hợp lệ. Sửa các ô đỏ rồi bấm Lưu nháp lại.', 'alert') if e else ''
    sh = '<div class="hmt-box hmt-sheet" style="flex:1 1 auto"><h2>%s</h2><div style="display:flex;flex-direction:column;gap:16px;padding-top:var(--space-2)">%s</div></div>' % (('Sửa lớp' if ed else 'Tạo lớp mới') + (' <span class="hmt-tag hmt-tag-danger">Từ chối</span>' if ed else ' <span class="hmt-tag">Nháp</span>'), erra + banner + form + nh + rem + '<div class="hmt-help">Lưu xong lớp ở trạng thái Nháp. Thêm thời khoá biểu ở màn Thời khoá biểu (LOP-04), rồi trình duyệt (R-LOP-02).</div>')
    B = [btn('Lưu nháp', 'primary', None, 'data-do="Đã lưu nháp. Lớp ở trạng thái Nháp."'), btn('Huỷ', 'danger', None, 'data-do="Huỷ bỏ, quay lại danh sách lớp."')]
    t = page(title, 'Lớp học', 'cs', crumb, rbar_l('Lớp', B), sh, chatter([]), pager='1 / 1', group=4)
    return t.replace('</helmet>', FORM_CSS + '</helmet>', 1)

def run():
    out = []
    out += run_list(cfg_lop01(), 'LOP01', 'bm')
    wr('LOP01_kanban', build_kanban()); out.append('LOP01_kanban')
    for st in LP_T:
        wr('LOP02_' + st, build_lop(st)); out.append('LOP02_' + st)
    for v in ('tao', 'rieng', 'sua', 'loi', 'tai', 'quyen'):
        wr('LOP03_' + v, build_form(v)); out.append('LOP03_' + v)
    return out
if __name__ == '__main__': print(' '.join(run()))
