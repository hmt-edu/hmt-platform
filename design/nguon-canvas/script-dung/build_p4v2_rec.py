# -*- coding: utf-8 -*-
# P4 v2: hồ sơ học sinh (KH-05) và phụ huynh (KH-02) dựng từ wireframe đã duyệt 17/10
import re, sys
sys.path.insert(0, 'scripts')
from kh_common import SVG, IC, SK_CSS, sk, remove_div
WF = 'wf/project/'; OUT = 'live15/project/'
def rd(n): return open(WF + n + '.dc.html', encoding='utf-8').read()
def wr(n, s): open(OUT + n + '.dc.html', 'w', encoding='utf-8').write(s)

LATER = ' aria-disabled="true" title="Làm ở phân hệ sau" data-later="1" style="opacity:.55;cursor:not-allowed"'
LATER_STYLE = 'opacity:.55;cursor:not-allowed'
HELM = ('<style>.ix-toast{position:absolute;left:50%;bottom:28px;transform:translateX(-50%) translateY(20px);background:var(--neutral-900,#1f1b16);color:#fff;padding:10px 16px;border-radius:8px;font-size:13px;opacity:0;pointer-events:none;transition:.2s;z-index:90;max-width:560px}.ix-toast.on{opacity:1;transform:translateX(-50%)}'
        '.hmt-table td:first-child a{white-space:nowrap}.ix-err{display:block;margin-top:4px;color:var(--danger-text);font-size:12px}.hmt-tab[aria-disabled=true]{opacity:.5;cursor:not-allowed}.hmt-sbtn[aria-disabled=true]{opacity:.55;cursor:not-allowed}</style>')

USERS = {'cs': ('Nguyễn Thị Lan', 'CSKH · CS1 Nguyễn Chí Thanh', 'NL'),
         'kt': ('Phạm Thị Hồng Nhung', 'Kế toán · CS1 Nguyễn Chí Thanh', 'HN'),
         'gv': ('Lê Văn Phong', 'Giáo viên · CS1 Nguyễn Chí Thanh', 'LP')}

JS = r"""
const ROOT = document.querySelector('[data-ix=root]'); if (!ROOT) return;
const q = (s, r) => (r || ROOT).querySelector(s);
const qa = (s, r) => Array.from((r || ROOT).querySelectorAll(s));
function toast(m) { let t = q('.ix-toast'); if (!t) { t = document.createElement('div'); t.className = 'ix-toast'; ROOT.appendChild(t); } t.textContent = m; t.classList.add('on'); clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('on'), 2600); }
qa('[data-val]').forEach(e => { e.value = e.getAttribute('data-val'); });
ROOT.addEventListener('click', ev => {
  const t = ev.target; const m = q('[data-menu]');
  const later = t.closest('[data-later]'); if (later) { ev.preventDefault(); ev.stopPropagation(); toast('Làm ở phân hệ sau'); return; }
  const hb = t.closest('[data-hd]'); if (hb) { if (m) m.style.display = m.style.display === 'none' ? 'flex' : 'none'; return; }
  if (m && !t.closest('[data-menu]')) m.style.display = 'none';
  const dd = t.closest('[data-do]'); if (dd && !dd.hasAttribute('data-act')) { if (m) m.style.display = 'none'; toast(dd.getAttribute('data-do')); return; }
}, true);
// @@ANCHOR@@
"""

def prep(n, title, role='cs', obj='Học sinh', who=None):
    t = rd(n)
    t = re.sub(r'<title>[^<]*</title>', '<title>%s</title>' % title, t, count=1)
    t = re.sub(r'<div class="wfn">.*?</div>', '', t, flags=re.S)
    t = re.sub(r'<div class="wfai">.*?</div>', '', t, flags=re.S)
    # ghi chú ngắn trong tiêu đề khối: bỏ (đã ghi ở tài liệu)
    t = re.sub(r'(<div class="hmt-csec-t"[^>]*>[^<]*?)\s*<span class="hmt-auto">[^<]*</span>', r'\1', t)
    t = t.replace('<helmet>', '<helmet>' + HELM, 1)
    t = t.replace('<div style="position:relative;width:1440px;height:1000px;overflow:hidden">', '<div data-ix="root" style="position:relative;width:1440px;height:1000px;overflow:hidden">', 1)
    # nút mờ ở giai đoạn 1
    t = re.sub(r'<button class="(hmt-btn[^"]*)" type="button" disabled>', lambda m: '<button class="%s" type="button"%s>' % (m.group(1), LATER), t)
    # chatter: Tạo ticket mờ
    t = t.replace('<button class="hmt-btn" type="button" style="opacity:.5">', '<button class="hmt-btn" type="button"' + LATER + '>')
    # menu Hành động
    menu = ('<div class="hmt-menu" role="menu" data-menu style="display:none;position:absolute;right:-8px;top:40px;z-index:30;min-width:200px">'
            '<button class="hmt-opt" type="button" data-act="merge" data-do="Mở hộp Gộp trùng (màn KH-07).">%s Gộp</button>'
            '<button class="hmt-opt" type="button"' % SVG(IC['merge']) + LATER.replace('style="opacity:.55;cursor:not-allowed"', 'style="opacity:.55;cursor:not-allowed;width:100%"') + '>' + SVG(IC['ticket']) + 'Tạo ticket</button></div>')
    t = re.sub(r'<span class="push-r"><button class="hmt-btn hmt-btn-text" type="button">(Hành động<svg.*?</svg>)</button></span>',
               lambda m: '<span class="push-r" style="position:relative"><button class="hmt-btn hmt-btn-text" type="button" data-hd="1">' + m.group(1) + '</button>' + menu + '</span>', t, count=1, flags=re.S)
    # nút Sửa
    t = t.replace('<button class="hmt-btn hmt-btn-primary" type="button"><svg', '<button class="hmt-btn hmt-btn-primary" type="button" data-act="edit" data-do="Mở khuôn Sửa (màn %s)."><svg' % ('KH-06' if obj == 'Học sinh' else 'KH-03'), 1)
    # script
    t = re.sub(r'<script type="text/x-dc" data-dc-script data-props=\'([^\']*)\'>.*?</script>',
               lambda m: '<script type="text/x-dc" data-dc-script data-props=\'' + m.group(1) + '\'>class Component extends DCLogic { renderVals() { return {}; } componentDidMount() {' + JS + '} }</script>', t, flags=re.S)
    if obj == 'Phụ huynh':   # 17/10: bỏ tab Chăm sóc ở hồ sơ phụ huynh (xem chăm sóc ở hồ sơ học sinh)
        t = re.sub(r'<button class="hmt-tab"[^>]*type="button">Chăm sóc</button>', '', t)
        t = re.sub(r'(<button class="hmt-tab" role="tab" aria-selected="(?:true|false)" type="button">Tổng quan</button>)', r'\1<button class="hmt-tab" role="tab" aria-selected="false" type="button">Các con</button>', t, count=1)
        if n == 'PH_TongQuan': t = CHILDREN_SPLIT(t)
    if n == 'Main':   # 17/10 (R-CRM-33): ô Mã cũ (Sheet) cạnh mã HS, chỉ xem; chỉ ở Tổng quan, các tab con không lặp lại
        k = '<div class="hmt-kv"><dt>Họ tên</dt>'
        assert t.count(k) == 1
        t = t.replace(k, '<div class="hmt-kv"><dt>Mã cũ (Sheet)</dt><dd><span class="hmt-num">STU-2609-0123</span><span class="hmt-auto">chỉ xem, Admin sửa được</span></dd></div>' + k, 1)
    if who: t = set_user(t, *USERS[who])
    return t

CHILD_HTML = ''
def CHILDREN_SPLIT(t):
    # lưu khối CÁC CON ở biến toàn cục rồi bỏ khỏi Tổng quan
    global CHILD_HTML
    i = t.index('<div class="hmt-csec-t" style="padding:var(--space-2) 0 var(--space-1)">CÁC CON'); j = t.rfind('<div>', 0, i)
    t2, blk = remove_div(t, j); CHILD_HTML = blk
    return t2

def set_user(t, name, role, ini):
    return re.sub(r'<span class="hmt-avatar hmt-avatar-lg">NL</span><span class="hmt-user-n"><b>[^<]*</b><span>[^<]*</span>',
                  '<span class="hmt-avatar hmt-avatar-lg">%s</span><span class="hmt-user-n"><b>%s</b><span>%s</span>' % (ini, name, role), t, count=1)

def dim_smart(t, labels, zero=True):
    def f(m):
        full = m.group(0); lab = re.search(r'<span><b>[^<]*</b><span>([^<]*)</span>', full).group(1)
        if lab not in labels: return full
        full = full.replace(' hmt-sbtn-alert', '')
        if zero: full = re.sub(r'<b>[^<]*</b>', '<b>0</b>', full, count=1)
        return full.replace('type="button">', 'type="button"' + LATER + '>', 1)
    return re.sub(r'<button class="hmt-sbtn[^"]*" type="button">.*?</button>', f, t, flags=re.S)

def dim_tabs(t, labels):
    def f(m):
        full = m.group(0); lab = re.search(r'>([^<]*)</button>', full).group(1)
        if lab.replace('&amp;', '&') not in labels: return full
        return full.replace('type="button">', 'type="button" data-dim="1" title="Làm ở phân hệ sau" style="opacity:.5">', 1)
    return re.sub(r'<button class="hmt-tab"[^>]*type="button">[^<]*</button>', f, t)

def rm_all(t, marker):
    while marker in t:
        i = t.index(marker); j = t.rfind('<div', 0, i + 1)
        if not t[j:].startswith(marker.split('"')[0]) and False: pass
        t, _ = remove_div(t, t.rfind('<div', 0, i + len(marker)) if t.startswith('<div', i) else j)
    return t

def sheet_body_replace(t, new_inner):
    """thay phần nội dung dưới thanh tab (khối padding-top:var(--space-3)) trong .hmt-sheet"""
    key = '<div style="padding-top:var(--space-3);display:flex;flex-direction:column;gap:16px">'
    a = t.index(key); t2, _ = remove_div(t, a)
    return t2[:a] + key + new_inner + '</div>' + t2[a:]

def dim_panel(cols, text='Làm ở phân hệ sau'):
    th = ''.join('<th%s>%s</th>' % (' class="r"' if r else '', c) for c, r in cols)
    return ('<div class="hmt-table-wrap" style="opacity:.55"><table class="hmt-table nt"><thead><tr>' + th + '</tr></thead><tbody><tr><td colspan="%d" style="text-align:center;height:120px;color:var(--text-secondary)">'
            '<div style="display:flex;flex-direction:column;align-items:center;gap:8px">%s<b style="color:var(--text-primary)">Chưa có dữ liệu</b><span>%s. Dữ liệu sẽ hiện ở đây khi phân hệ này được làm.</span></div></td></tr></tbody></table></div>' % (len(cols), SVG(IC['lock'], 'hmt-ic hmt-ic-lg'), text))

# ---------------- khung xương / không có quyền / chỉ xem ----------------
def skeleton(t):
    a = t.index('<div class="hmt-wrap hmt-wrap-scroll">'); b = t.index('</div></div></div></x-dc>') if '</div></div></div></x-dc>' in t else None
    # vùng nội dung: từ hmt-wrap tới hết aside
    end = t.index('</aside>') + len('</aside>') + len('</div>')  # đóng hmt-wrap
    left = ('<div class="hmt-left"><div class="hmt-box" style="padding:14px;display:flex;gap:18px">' + ''.join(sk(110, 34) for _ in range(6)) + '</div>'
            '<div class="hmt-box hmt-sheet" style="flex:1 1 auto;padding:var(--space-4);display:flex;flex-direction:column;gap:14px">' + sk(360, 24) + '<div style="display:flex;gap:18px">' + ''.join(sk(80, 16) for _ in range(5)) + '</div>'
            '<div style="display:grid;grid-template-columns:1fr 1fr;gap:28px;margin-top:10px">' + ''.join('<div style="display:flex;flex-direction:column;gap:18px">' + ''.join(sk('90%', 14) for _ in range(5)) + '</div>' for _ in range(2)) + '</div></div></div>')
    right = ('<aside class="hmt-right" aria-label="Ghi chú &amp; hoạt động"><div class="hmt-chatter" style="padding:var(--space-4);display:flex;flex-direction:column;gap:14px">' + sk(150, 18) + sk('100%', 70) + ''.join('<div style="display:flex;gap:10px">' + sk(28, 28, 14) + '<div style="flex:1;display:flex;flex-direction:column;gap:6px">' + sk('70%', 12) + sk('95%', 12) + '</div></div>' for _ in range(4)) + '</div></aside>')
    wrap = '<div class="hmt-wrap hmt-wrap-scroll" aria-busy="true" aria-label="Đang tải">' + left + right + '</div>'
    # chuyển nút thanh trên thành mờ
    t = t[:a] + wrap + t[end:]
    t = t.replace('<script', SK_CSS + '<script', 1) if False else t.replace('</helmet>', SK_CSS + '</helmet>', 1)
    t = re.sub(r'(<div class="hmt-rbar-l"><h1>[^<]*</h1>).*?(</div><div class="hmt-rbar-r">)', lambda m: m.group(1) + '<i class="sk" style="width:60px;height:30px;border-radius:6px"></i>' + m.group(2), t, count=1, flags=re.S)
    t = re.sub(r'<div class="hmt-pager">.*?</div>', '', t, count=1, flags=re.S)
    return crumb_loading(t)

def crumb_loading(t):
    return re.sub(r'(<span aria-current="page">)[^<]*(</span></nav>)', r'\1Đang tải…\2', t, count=1)

def noperm(t, noun):
    t = re.sub(r'<button class="hmt-sb-l1" type="button" title="Khách hàng".*?</button><a class="hmt-sb-l2"[^>]*>Phụ huynh</a><a class="hmt-sb-l2"[^>]*>Học sinh</a>', '', t, count=1, flags=re.S)
    a = t.index('<div class="hmt-wrap hmt-wrap-scroll">'); end = t.index('</aside>') + len('</aside>') + len('</div>')
    box = ('<div class="hmt-wrap hmt-wrap-scroll"><div class="hmt-left" style="max-width:none"><div class="hmt-box hmt-empty" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:48px 20px;text-align:center;min-height:460px;margin:var(--space-6) auto;max-width:560px;flex:0 0 auto">'
           '<span style="color:var(--text-secondary)">' + SVG(IC['lock'], 'hmt-ic hmt-ic-lg') + '</span><b style="color:var(--text-primary);font-size:16px;font-family:var(--font-heading)">Bạn không có quyền xem ' + noun + '</b>'
           '<span class="hmt-help" style="max-width:420px">Vai trò Giáo viên chưa được cấp quyền xem phân hệ Khách hàng. Nếu cần xem, hãy liên hệ quản trị viên của trung tâm.</span>'
           '<button class="hmt-btn hmt-btn-primary" type="button" data-do="Về trang chủ theo vai trò.">Về trang chủ</button></div></div></div>')
    t = t[:a] + box + t[end:]
    t = re.sub(r'(<div class="hmt-rbar-l"><h1>[^<]*</h1>).*?(</div><div class="hmt-rbar-r">)', r'\1\2', t, count=1, flags=re.S)
    t = re.sub(r'<div class="hmt-pager">.*?</div>', '', t, count=1, flags=re.S)
    t = re.sub(r'<div class="hmt-rbar-r"><button[^>]*aria-label="Làm mới".*?</button></div>', '<div class="hmt-rbar-r"></div>', t, count=1, flags=re.S)
    t = re.sub(r'(<span aria-current="page">)[^<]*(</span></nav>)', r'\1' + noun.capitalize() + r'\2', t, count=1)
    # đường dẫn: bỏ cấp tên bản ghi
    t = re.sub(r'<svg[^>]*><path d="m9 18 6-6-6-6" ?/></svg><span aria-current="page">[^<]*</span></nav>', '</nav>', t, count=1)
    t = set_user(t, *USERS['gv'])
    return t

def view_only(t, keep_pager=True):
    """Kế toán: chỉ xem, không Sửa, không Hành động, không soạn ghi chú"""
    t = re.sub(r'<button class="hmt-btn hmt-btn-primary" type="button"[^>]*><svg.*?</svg>Sửa</button>', '', t, count=1, flags=re.S)
    t = re.sub(r'<span class="push-r".*?</span>(?=</div><div class="hmt-rbar-r">)', '', t, count=1, flags=re.S)
    for mk in ('<div style="padding:0 var(--space-4) var(--space-3);border-bottom', '<div class="hmt-csec"><textarea'):
        if mk in t:
            i = t.index(mk); t, _ = remove_div(t, i)
    t = re.sub(r'<div class="hmt-act-btns".*?</div>', '', t, flags=re.S)
    return set_user(t, *USERS['kt'])

# ---------------- chế độ Sửa ----------------
def err_msg(lab): return 'Bắt buộc nhập ' + lab.lower().replace('số điện thoại', 'số điện thoại')

def edit_mode(t, fields, err, obj):
    for lab, kind, val, req, ro in fields:
        pat = re.compile(r'<div class="hmt-kv"><dt>' + re.escape(lab) + r'</dt><dd>(.*?)</dd></div>', re.S)
        m = pat.search(t); assert m, lab
        cur = m.group(1)
        star = ' <span class="hmt-req">*</span>' if req else ''
        bad = err and lab in err
        if ro:
            dd = cur
        elif kind == 'select':
            dd = '<select class="hmt-input hmt-select" aria-label="%s" data-val="%s">%s</select>' % (lab, val, ''.join('<option>%s</option>' % o for o in SEL[lab]))
        else:
            dd = '<input class="hmt-input%s" aria-label="%s" data-val="%s"%s%s>' % (' hmt-input-err' if bad else '', lab, '' if bad else val, ' aria-invalid="true"' if bad else '', ' data-req="%s"' % (err_msg(lab)) if req else '') + ('<span class="ix-err">%s</span>' % err[lab] if bad else '')
        t = t[:m.start()] + '<div class="hmt-kv"><dt>%s%s</dt><dd>%s</dd></div>' % (lab, star, dd) + t[m.end():]
    # thanh nút: Lưu / Huỷ thay Sửa
    t = re.sub(r'<button class="hmt-btn hmt-btn-primary" type="button" [^>]*><svg.*?</svg>Sửa</button>',
               '<button class="hmt-btn hmt-btn-primary" type="button" data-do="Đã lưu (mẫu: bản vẽ chỉ minh hoạ).">' + SVG(IC['check']) + 'Lưu</button><button class="hmt-btn hmt-btn-danger" type="button" data-do="Huỷ sửa, quay lại hồ sơ.">' + SVG(IC['x']) + 'Huỷ</button>', t, count=1, flags=re.S)
    if err:
        names = ', '.join(err.keys())
        al = '<div class="hmt-alert hmt-alert-danger" role="alert">' + SVG(IC['alert']) + '<span><b>Còn %d ô bắt buộc chưa điền:</b> %s. Điền xong rồi bấm Lưu.</span></div>' % (len(err), names)
        key = '<div style="padding-top:var(--space-3);display:flex;flex-direction:column;gap:16px">'
        t = t.replace(key, key + al, 1)
    return t

SEL = {'Khối': ['Lớp %d' % i for i in range(2, 13)]}
HS_FIELDS = [('Mã cũ (Sheet)', 'input', 'STU-2609-0123', 0, 1), ('Họ tên', 'input', 'Nguyễn Minh Khôi', 1, 0), ('Ngày sinh', 'input', '15/03/2011', 1, 0), ('Năm sinh', 'input', '2011', 0, 1), ('Khối', 'select', 'Lớp 9', 0, 0),
             ('Trường học', 'input', 'THCS Lê Lợi', 0, 0), ('Mục tiêu', 'input', 'Đỗ vào lớp 10 trường chuyên', 0, 0), ('Phụ huynh', 'input', '', 0, 1), ('Tình trạng', 'input', '', 0, 1),
             ('Cơ sở tiếp nhận', 'input', '', 0, 1), ('Đang học tại', 'input', '', 0, 1)]
PH_FIELDS = [('Họ tên', 'input', 'Trần Thị Hà', 1, 0), ('Số điện thoại', 'input', '0912 345 456', 1, 0), ('Phường/Xã', 'input', 'Thanh Xuân Trung', 0, 0), ('Tỉnh/Thành phố', 'input', 'Hà Nội', 0, 0),
             ('Địa chỉ', 'input', 'Số 12, ngõ 45, đường Nguyễn Trãi', 0, 0), ('Nhu cầu', 'input', 'Ôn thi vào lớp 10, học buổi tối', 0, 0), ('Cơ sở tiếp nhận', 'input', '', 0, 1), ('Đang học tại', 'input', '', 0, 1)]
HS_ERR = {'Họ tên': 'Bắt buộc nhập họ tên', 'Ngày sinh': 'Bắt buộc nhập ngày sinh'}
PH_ERR = {'Họ tên': 'Bắt buộc nhập họ tên', 'Số điện thoại': 'Bắt buộc nhập số điện thoại'}

def cut_block(t, text):
    i = t.index(text); j = t.rfind('<div>', 0, i)
    t2, _ = remove_div(t, j); return t2

def build_all():
    out = {}
    # ======= HỌC SINH =======
    S1_SMART = {'Ghi danh', 'Lớp', 'Ticket mở', 'Khiếu nại'}
    S1_TABS = {'Học tập', 'Điểm danh', 'Điểm kiểm tra', 'Chăm sóc', 'Đề nghị & khiếu nại'}
    t = prep('Main', 'KH-05 · Học sinh · Tổng quan (giai đoạn 1)', obj='Học sinh')
    out['KH05'] = dim_tabs(dim_smart(t, S1_SMART), S1_TABS)
    out['KH05_day_du'] = prep('Main', 'KH-05 · Học sinh · Tổng quan (đầy đủ)')
    # trống: hồ sơ vừa sinh, chưa có hoạt động
    t = out['KH05']
    t = t.replace('<b>2</b><span>Ticket mở', '<b>0</b><span>Ticket mở')
    out['KH05_trong'] = chatter_empty(t, 'Tạo học sinh từ phiếu test PKT000231.')
    out['KH05_hoc_tap'] = prep('HS_HocTap', 'KH-05 · Học sinh · Học tập')
    t = prep('HS_HocTap', 'KH-05 · Học sinh · Học tập (giai đoạn 1: mờ)')
    t = dim_tabs(dim_smart(t, S1_SMART), S1_TABS)
    out['KH05_hoc_tap_mo'] = sheet_body_replace(t, dim_panel([('Lớp', 0), ('Giáo viên', 0), ('Lịch học', 0), ('Start Date', 0), ('End Date', 0), ('Tình trạng', 0), ('Giờ đăng ký', 1), ('Đã học', 1), ('Còn lại', 1)]))
    out['KH05_diem_danh'] = prep('HS_DiemDanh', 'KH-05 · Học sinh · Điểm danh, tổng quan các lớp')
    out['KH05_diem_danh_chi_tiet'] = prep('HS_DiemDanhChiTiet', 'KH-05 · Học sinh · Điểm danh, chi tiết một lớp')
    t = prep('HS_DiemKiemTra', 'KH-05 · Học sinh · Điểm kiểm tra')
    out['KH05_diem_kiem_tra'] = cut_block(t, 'ĐIỂM THEO THÁNG')
    out['KH05_cham_soc'] = prep('HS_ChamSoc', 'KH-05 · Học sinh · Chăm sóc')
    out['KH05_de_nghi'] = prep('HS_KhieuNai', 'KH-05 · Học sinh · Đề nghị và khiếu nại')
    out['KH05_tai'] = skeleton(prep('Main', 'KH-05 · Học sinh · Đang tải'))
    out['KH05_khong_quyen'] = noperm(prep('Main', 'KH-05 · Học sinh · Không có quyền'), 'học sinh')
    base = dim_tabs(dim_smart(prep('Main', 'KH-06 · Học sinh · Sửa'), S1_SMART), S1_TABS)
    out['KH06'] = edit_mode(base, HS_FIELDS, None, 'Học sinh')
    base = dim_tabs(dim_smart(prep('Main', 'KH-06 · Học sinh · Sửa, lỗi bắt buộc nhập'), S1_SMART), S1_TABS)
    out['KH06_loi'] = edit_mode(base, HS_FIELDS, HS_ERR, 'Học sinh')
    # ======= PHỤ HUYNH =======
    P1_SMART = {'Ghi danh', 'Ticket mở', 'Phiếu thu'}
    t = prep('PH_TongQuan', 'KH-02 · Phụ huynh · Tổng quan (giai đoạn 1)', obj='Phụ huynh')
    out['KH02'] = dim_tabs(dim_smart(t, P1_SMART), {'Tài chính'})
    t = prep('PH_TongQuan', 'KH-02 · Phụ huynh · Các con', obj='Phụ huynh')
    t = t.replace('aria-selected="true" type="button">Tổng quan', 'aria-selected="false" type="button">Tổng quan', 1).replace('aria-selected="false" type="button">Các con', 'aria-selected="true" type="button">Các con', 1)
    key = '<div style="padding-top:var(--space-3);display:flex;flex-direction:column;gap:16px">'
    a2 = t.index(key); t2, _ = remove_div(t, a2)
    kids = CHILD_HTML.replace('<div class="hmt-csec-t" style="padding:var(--space-2) 0 var(--space-1)">CÁC CON</div>', '')
    out['KH02_cac_con'] = dim_tabs(dim_smart(t2[:a2] + key + kids + '</div>' + t2[a2:], P1_SMART), {'Tài chính'})
    out['KH02_tai_chinh'] = prep('PH_TaiChinh', 'KH-02 · Phụ huynh · Tài chính', obj='Phụ huynh')
    t = dim_tabs(dim_smart(prep('PH_TaiChinh', 'KH-02 · Phụ huynh · Tài chính (giai đoạn 1: mờ)', obj='Phụ huynh'), P1_SMART), {'Tài chính'})
    out['KH02_tai_chinh_mo'] = sheet_body_replace(t, dim_panel([('Ghi danh', 0), ('Con', 0), ('Gói', 0), ('Giờ', 1), ('Thành tiền', 1), ('Trạng thái', 0)]))
    out['KH02_tai'] = skeleton(prep('PH_TongQuan', 'KH-02 · Phụ huynh · Đang tải', obj='Phụ huynh'))
    out['KH02_khong_quyen'] = noperm(prep('PH_TongQuan', 'KH-02 · Phụ huynh · Không có quyền', obj='Phụ huynh'), 'phụ huynh')
    out['KH02_kt'] = view_only(prep('PH_TaiChinh', 'KH-02 · Phụ huynh · Kế toán xem (chỉ đọc)', obj='Phụ huynh'))
    base = dim_tabs(dim_smart(prep('PH_TongQuan', 'KH-03 · Phụ huynh · Sửa', obj='Phụ huynh'), P1_SMART), {'Tài chính'})
    out['KH03'] = edit_mode(base, PH_FIELDS, None, 'Phụ huynh')
    base = dim_tabs(dim_smart(prep('PH_TongQuan', 'KH-03 · Phụ huynh · Sửa, lỗi bắt buộc nhập', obj='Phụ huynh'), P1_SMART), {'Tài chính'})
    out['KH03_loi'] = edit_mode(base, PH_FIELDS, PH_ERR, 'Phụ huynh')
    return out

def chatter_empty(t, sys_msg):
    # bỏ khối Hoạt động sắp tới và các tin trừ dòng hệ thống tạo hồ sơ
    i = t.index('<div class="hmt-csec"><div class="hmt-csec-t">HOẠT ĐỘNG SẮP TỚI'); t, _ = remove_div(t, i)
    a = t.index('<div class="hmt-day">')
    b = t.index('<div style="height:var(--space-3)"></div></div></aside>')
    msg = ('<div class="hmt-msg"><span class="hmt-avatar hmt-avatar-lg hmt-avatar-sys">HT</span><div class="hmt-msg-b"><span class="hmt-meta"><b>Hệ thống</b> · <span class="hmt-num">17/10 · 09:40</span> · Hệ thống</span><span>%s</span></div></div>' % sys_msg)
    return t[:a] + '<div class="hmt-day">Hôm nay · 17/10/2026</div>' + msg + t[b:]

if __name__ == '__main__':
    out = build_all()
    for n, s in out.items(): wr(n, s)
    print(' '.join(out))
