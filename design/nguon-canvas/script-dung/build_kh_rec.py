# -*- coding: utf-8 -*-
# KH-02 Phụ huynh (bản ghi), KH-03 Tạo phụ huynh (khuôn trống), KH-05 Học sinh (hồ sơ 360°), KH-06 Tạo học sinh. Nền = K3 (TS-02)
import sys, re, json
sys.path.insert(0, 'scripts')
from kh_common import *
from build_kh_list import USERS

CHEV = SVG('<path d="M5 12h14" /> <path d="m12 5 7 7-7 7" />')
EYE = SVG('<path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0" /> <circle cx="12" cy="12" r="3" />')
def av(ini, sys_=False): return '<span class="hmt-avatar hmt-avatar-lg%s">%s</span>' % (' hmt-avatar-sys' if sys_ else '', ini)
def note_msg(who, ini, hm, text): return '<div class="hmt-msg">%s<div class="hmt-msg-b"><span class="hmt-meta"><b>%s</b> · <span class="hmt-num">%s</span> · Ghi chú</span><div class="hmt-note">%s</div></div></div>' % (av(ini), who, hm, text)
def sys_msg(hm, text, chg=''): return '<div class="hmt-msg">%s<div class="hmt-msg-b"><span class="hmt-meta"><b>Hệ thống</b> · <span class="hmt-num">%s</span> · Hệ thống</span><span>%s</span>%s</div></div>' % (av('HT', True), hm, text, chg)
def chg(label, a, b): return '<span class="hmt-chg">%s: <s>%s</s>%s%s</span>' % (label, a, CHEV, b)

def chatter(msgs, dim=False, hint=''):
    h = ('<div class="hmt-chatter"%s>' % (' style="opacity:.45;pointer-events:none" title="Có sau khi Lưu"' if dim else ''))
    h += '<div class="hmt-chatter-h"><h3>Ghi chú &amp; hoạt động</h3><button class="hmt-btn hmt-btn-text" type="button">%sTheo dõi</button></div>' % EYE
    h += '<div class="hmt-csec"><textarea class="hmt-textarea" aria-label="Nội dung ghi chú" placeholder="Viết ghi chú… gõ @ để nhắc đồng nghiệp" rows="3"></textarea><div class="hmt-row"><button class="hmt-btn" type="button">%sGửi ghi chú</button><button class="hmt-btn hmt-btn-text" type="button">%sĐính kèm</button></div></div>' % (SVG(IC['send']), SVG(IC['clip']))
    h += '<div class="hmt-csec"><div class="hmt-csec-t">DÒNG THỜI GIAN</div><div class="hmt-pills" role="group" aria-label="Lọc dòng thời gian"><button type="button" aria-pressed="true">Tất cả</button><button type="button">Ghi chú</button><button type="button">Hệ thống</button></div></div>'
    if dim: h += '<div class="hmt-help" style="padding:var(--space-3) var(--space-4)">%s</div>' % hint
    for day, items in msgs:
        h += '<div class="hmt-day">%s</div>' % day + ''.join(items)
    return h + '<div style="height:var(--space-3)"></div></div>'

def smart(items, dim_all=False):
    """items: (icon, count, label, on)"""
    n = len(items)
    b = ''
    for ic, cnt, lab, on in items:
        dim = dim_all or not on
        title = ' title="Có sau khi Lưu"' if dim_all else (' title="Làm ở phân hệ sau" data-later="1"' if not on else '')
        b += '<button class="hmt-sbtn" type="button" data-sb="%s"%s%s>%s<span><b>%s</b><span>%s</span></span></button>' % (lab, ' style="opacity:.55;cursor:not-allowed"' if dim else '', title, SVG(IC[ic]), cnt, lab)
    st = '' if n == 6 else ' style="grid-template-columns:repeat(%d,minmax(0,1fr));width:calc(%d*100%%/6)"' % (n, n)
    return '<div class="hmt-box"><div class="hmt-smart wide"%s>%s</div></div>' % (st, b)

SK = SK_CSS

def kvs_tab(rows): return '<dl class="hmt-panel-b" style="padding:0">' + ''.join('<div class="hmt-kv"><dt>%s</dt><dd>%s</dd></div>' % r for r in rows) + '</dl>'

# ------------------------- dữ liệu mẫu -------------------------
CS_OPTS = ['CS1 Nguyễn Chí Thanh', 'CS2 Đỗ Quang', 'CS4 Cầu Giấy', 'CS5 Hà Đông']
PH_SPEC = {
 'cols': [
  {'t': 'THÔNG TIN LIÊN HỆ', 'fields': [
    {'k': 'name', 'l': 'Họ tên', 'req': 1, 'ph': 'Ví dụ: Chị Nguyễn Thị Lan Anh', 'e': 'Bắt buộc nhập họ tên'},
    {'k': 'phone', 'l': 'Số điện thoại', 'req': 1, 'ph': 'Ví dụ: 0903 456 789', 'e': 'Bắt buộc nhập số điện thoại', 'num': 1},
    {'k': 'ward', 'l': 'Phường/Xã', 't': 'select', 'opts': ['Phường Giảng Võ', 'Phường Ngọc Khánh', 'Phường Kim Mã', 'Phường Láng Hạ', 'Phường Thành Công']},
    {'k': 'prov', 'l': 'Tỉnh/Thành phố', 't': 'select', 'opts': ['Hà Nội', 'Hải Phòng', 'Bắc Ninh', 'Hưng Yên']},
    {'k': 'addr', 'l': 'Địa chỉ', 'ph': 'Số nhà, ngõ, phố'}]},
  {'t': 'QUẢN LÝ', 'fields': [
    {'k': 'cs', 'l': 'Cơ sở', 't': 'select', 'opts': CS_OPTS, 'auto': 'mặc định cơ sở người tạo'},
    {'k': 'upd', 'l': 'Cập nhật', 'ro': 1, 'auto': 'tự tính'},
    {'k': 'cre', 'l': 'Ngày tạo', 'ro': 1, 'auto': 'tự tính'}]}],
}
HS_SPEC = {
 'cols': [
  {'t': 'THÔNG TIN HỌC SINH', 'fields': [
    {'k': 'name', 'l': 'Họ tên', 'req': 1, 'ph': 'Ví dụ: Nguyễn Minh Khôi', 'e': 'Bắt buộc nhập họ tên học sinh'},
    {'k': 'year', 'l': 'Năm sinh', 'req': 1, 'ph': 'Ví dụ: 2012', 'e': 'Bắt buộc nhập năm sinh', 'num': 1},
    {'k': 'grade', 'l': 'Khối', 't': 'select', 'opts': ['Lớp %d' % i for i in range(2, 13)]},
    {'k': 'school', 'l': 'Trường', 'ph': 'Ví dụ: THCS Giảng Võ'}]},
  {'t': 'PHỤ HUYNH VÀ QUẢN LÝ', 'fields': [
    {'k': 'ph', 'l': 'Phụ huynh', 'req': 1, 'ph': 'Tìm phụ huynh theo tên, SĐT, mã PH', 'e': 'Bắt buộc chọn phụ huynh', 'link': 1},
    {'k': 'tt', 'l': 'Tình trạng', 'ro': 1, 'auto': 'tự tính từ ghi danh', 'tag': 1},
    {'k': 'cs', 'l': 'Cơ sở', 't': 'select', 'opts': CS_OPTS, 'auto': 'mặc định cơ sở người tạo'}]}],
}

REC_JS = r"""
const SPEC = %(spec)s; const OPT = %(opt)s;
const esc = v => String(v == null ? '' : v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
const $q = (s, r) => (r || ROOT).querySelector(s);
let mode = OPT.create ? 'edit' : 'view'; let vals = Object.assign({}, OPT.vals); let errs = {}; let saved = Object.assign({}, OPT.vals);
const TT = { 'Đang học': 'hmt-tag hmt-tag-success', 'Tiềm năng': 'hmt-tag hmt-tag-info', 'Bảo lưu': 'hmt-tag hmt-tag-warning', 'Dừng học': 'hmt-tag' };
const ic = p => '<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true">' + p + '</svg>';
const IC = %(ic)s;
function kv(f) {
  const v = vals[f.k] == null ? '' : vals[f.k]; const req = (f.req && mode === 'edit') ? ' <span class="hmt-req">*</span>' : ''; let dd;
  if (mode === 'view' || f.ro) {
    if (f.tag) dd = '<span class="' + (TT[v] || 'hmt-tag') + '">' + esc(v || 'Tiềm năng') + '</span>' + (f.auto ? ' <span class="hmt-auto">' + f.auto + '</span>' : '');
    else if (f.link && v) dd = '<a href="#" data-go="Mở hồ sơ phụ huynh (màn KH-02).">' + esc(v) + '</a> <span class="hmt-code">' + esc(OPT.phCode || '') + '</span>';
    else dd = (f.num ? '<span class="hmt-num">' + esc(v) + '</span>' : esc(v || '—')) + (f.auto && (f.ro || mode === 'view' && f.k === 'cs' ? false : false) ? '' : '') + (f.ro && f.auto ? ' <span class="hmt-auto">' + f.auto + '</span>' : '');
  } else if (f.t === 'select') {
    dd = '<select class="hmt-input hmt-select" aria-label="' + f.l + '" data-k="' + f.k + '">' + f.opts.map(o => '<option' + (o === v ? ' selected' : '') + '>' + o + '</option>').join('') + '</select>' + (f.auto && OPT.create ? ' <span class="hmt-auto">' + f.auto + '</span>' : '');
  } else {
    dd = '<input class="hmt-input' + (errs[f.k] ? ' hmt-input-err' : '') + '" aria-label="' + f.l + '" data-k="' + f.k + '" placeholder="' + esc(f.ph || '') + '"' + (errs[f.k] ? ' aria-invalid="true"' : '') + '>' + (errs[f.k] ? '<span class="ix-err" style="display:block;margin-top:4px">' + f.e + '</span>' : '');
  }
  return '<div class="hmt-kv"><dt>' + f.l + req + '</dt><dd>' + dd + '</dd></div>';
}
function drawFields() {
  const F = $q('[data-fields]'); if (!F) return;
  const bad = Object.keys(errs).length;
  let al = '';
  if (bad) { const names = []; SPEC.cols.forEach(c => c.fields.forEach(f => { if (errs[f.k]) names.push(f.l); })); al = '<div class="hmt-alert hmt-alert-danger" role="alert" style="margin-bottom:var(--space-3)">' + ic(IC.alert) + '<span><b>Còn ' + bad + ' ô bắt buộc chưa điền:</b> ' + names.join(', ') + '. Điền xong rồi bấm Lưu.</span></div>'; }
  F.innerHTML = al + '<div class="hmt-fgrid">' + SPEC.cols.map(c => '<dl class="hmt-panel-b" style="padding:0"><div class="hmt-csec-t" style="padding:var(--space-2) 0 var(--space-1)">' + c.t + '</div>' + c.fields.map(kv).join('') + '</dl>').join('') + '</div>';
  qa('[data-k]', F).forEach(i => { if (i.tagName === 'INPUT') i.value = vals[i.getAttribute('data-k')] || ''; });
}
function btn(cls, icon, label, act, extra) { return '<button class="hmt-btn ' + cls + '" type="button" data-act="' + act + '"' + (extra || '') + '>' + (icon ? ic(IC[icon]) : '') + label + '</button>'; }
function drawBar() {
  const b = $q('.hmt-rbar-l'); const keep = b.querySelector('h1').outerHTML; let h = keep;
  if (mode === 'edit') h += btn('hmt-btn-primary', 'check', 'Lưu', 'save') + btn('hmt-btn-danger', 'x', 'Huỷ', 'cancel');
  else {
    const p = OPT.perm;
    if (p.edit) h += btn('hmt-btn-primary', 'pencil', 'Sửa', 'edit');
    OPT.buttons.forEach(x => { if (x.need && !p[x.need]) return; h += btn('', x.icon, x.label, x.act, x.later ? ' aria-disabled="true" title="Làm ở phân hệ sau" data-later="1"' : ''); });
    h += '<span class="push-r"><button class="hmt-btn hmt-btn-text" type="button" data-act="attach">' + ic(IC.clip) + 'Đính kèm</button></span>';
  }
  b.innerHTML = h;
  const ttl = $q('.hmt-sheet h2'); if (ttl && OPT.create) ttl.innerHTML = mode === 'edit' ? OPT.newTitle : ttl.innerHTML;
}
function validate() {
  errs = {}; SPEC.cols.forEach(c => c.fields.forEach(f => { if (f.req && !String(vals[f.k] || '').trim()) errs[f.k] = f.e; }));
  return !Object.keys(errs).length;
}
function readInputs() { qa('.hmt-sheet [data-k]').forEach(i => { vals[i.getAttribute('data-k')] = i.value; }); }
function setMode(m) { mode = m; drawBar(); drawFields(); }
drawBar(); drawFields();
if (OPT.err) { validate(); drawFields(); }
['input', 'change', 'keydown', 'mousedown', 'keyup'].forEach(t => ROOT.addEventListener(t, ev => { if (ev.target.closest && ev.target.closest('.hmt-sheet')) ev.stopPropagation(); }, true));
ROOT.addEventListener('click', ev => {
  const t = ev.target; if (t.closest && t.closest('.hmt-sb')) return;
  const go = t.closest && t.closest('a[data-go]'); if (go) { ev.preventDefault(); ev.stopPropagation(); toast(go.getAttribute('data-go')); return; }
  const sb = t.closest && t.closest('.hmt-sbtn'); if (sb) { ev.preventDefault(); ev.stopPropagation(); const l = sb.getAttribute('data-sb');
    if (OPT.create) { toast('Có sau khi Lưu.'); return; }
    if (sb.getAttribute('data-later')) { toast('Làm ở phân hệ sau.'); return; }
    toast((OPT.sb && OPT.sb[l]) || ('Mở danh sách ' + l.toLowerCase() + ' của hồ sơ này.')); return; }
  const b = t.closest && t.closest('button[data-act]'); if (!b) return;
  ev.preventDefault(); ev.stopPropagation(); const a = b.getAttribute('data-act');
  if (b.getAttribute('data-later')) { toast('Làm ở phân hệ sau.'); return; }
  if (a === 'edit') { setMode('edit'); toast('Chế độ sửa: bấm Lưu để lưu, Huỷ để bỏ thay đổi.'); return; }
  if (a === 'cancel') { if (OPT.create) { toast('Đã huỷ, không tạo bản ghi. Quay lại danh sách.'); return; } vals = Object.assign({}, saved); errs = {}; setMode('view'); toast('Đã huỷ, không lưu thay đổi.'); return; }
  if (a === 'save') { readInputs(); if (!validate()) { drawFields(); toast('Còn ' + Object.keys(errs).length + ' ô bắt buộc chưa điền.'); return; }
    errs = {}; saved = Object.assign({}, vals);
    if (OPT.create) { toast(OPT.createdMsg); return; }
    setMode('view'); toast('Đã lưu. Lịch sử thay đổi đã ghi (ai, lúc nào, ô nào).'); return; }
  if (a === 'attach') { toast('Đính kèm file vào hồ sơ.'); return; }
  toast((OPT.acts && OPT.acts[a]) || ('Đã thực hiện: ' + b.textContent.trim()));
}, true);
"""

def rbar_swap(s, title, pager):
    s = re.sub(r'(<div class="hmt-rbar-l"[^>]*>).*?(</div>)(\s*<div class="hmt-rbar-r">)', lambda m: m.group(1) + '<h1>' + title + '</h1>' + m.group(2) + m.group(3), s, count=1, flags=re.S)
    if pager is None:
        s = re.sub(r'<div class="hmt-pager">.*?</div>', '', s, count=1, flags=re.S)
    else:
        s = s.replace('<span>3 / 250</span>', '<span>%s</span>' % pager, 1)
    return s

def tabs_sheet(h2, extra_inside=''):
    return h2

def base(kind, role, active, crumb_parts, state_title):
    s = read('TS02.dc.html')
    s = sidebar(s, active=active, hide_kh=(role == 'gv'))
    s = crumb(s, crumb_parts)
    s = user(s, *USERS[role])
    return s

def finish(s, title, wrap, opt_js, closers='</div></div></div>', cfg=None):
    a = s.index('<div class="hmt-wrap hmt-wrap-scroll">'); b = s.index('<div class="hmt-scrim"')
    s = s[:a] + wrap + closers + s[b:]
    i = s.index('<div class="hmt-scrim"'); s, _ = remove_div(s, i)
    s = s[:i] + '<div class="hmt-scrim" style="position:absolute;inset:0;z-index:50;align-items:center;padding:0;gap:var(--space-6);display:none"><div class="hmt-dialog" role="dialog" aria-label="—" style="width:460px;flex:0 0 460px"><div class="hmt-dialog-h">—</div><div class="hmt-dialog-b"></div></div></div>' + s[i:]
    s = replace_cfg(s, "const CFG = { stage:'free', link:'Mở bản ghi liên quan.', toasts:{} };")
    return inject(s, title, opt_js)

def skeleton_wrap(two_col=True):
    left = ('<div class="hmt-left">' + SK + '<div class="hmt-box"><div style="display:flex;gap:0">' + ''.join('<div style="flex:1;padding:12px;display:flex;gap:10px;align-items:center;border-right:1px solid var(--divider)">' + sk(24, 24, 6) + '<div style="display:flex;flex-direction:column;gap:6px">' + sk(30, 14) + sk(60, 10) + '</div></div>' for _ in range(6)) + '</div></div>'
            '<div class="hmt-box hmt-sheet" style="flex:1 1 auto;padding:var(--space-4);display:flex;flex-direction:column;gap:14px">' + sk(320, 22) + '<div style="display:grid;grid-template-columns:1fr 1fr;gap:28px">' + ''.join('<div style="display:flex;flex-direction:column;gap:14px">' + ''.join('<div style="display:flex;gap:16px">' + sk(110, 12) + sk(150 + (i * 20) % 60, 12) + '</div>' for i in range(5)) + '</div>' for _ in range(2)) + '</div>' + sk('100%', 120) + '</div></div>')
    right = '<aside class="hmt-right" aria-label="Ghi chú &amp; hoạt động"><div class="hmt-chatter" style="padding:var(--space-4);display:flex;flex-direction:column;gap:14px">' + sk(150, 18) + sk('100%', 70) + ''.join('<div style="display:flex;gap:10px">' + sk(28, 28, 14) + '<div style="display:flex;flex-direction:column;gap:6px;flex:1">' + sk(160, 12) + sk('90%', 12) + '</div></div>' for _ in range(3)) + '</div></aside>'
    return '<div class="hmt-wrap hmt-wrap-scroll" aria-busy="true" aria-label="Đang tải">' + left + right + '</div>'

def noperm_wrap(noun):
    return ('<div class="hmt-wrap hmt-wrap-scroll"><div class="hmt-left" style="max-width:none"><div class="hmt-box hmt-empty" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:48px 20px;text-align:center;min-height:460px;margin:var(--space-6) auto;max-width:560px;flex:0 0 auto">'
            '<span style="color:var(--text-secondary)">' + SVG(IC['lock'], 'hmt-ic hmt-ic-lg') + '</span><b style="color:var(--text-primary);font-size:16px;font-family:var(--font-heading)">Bạn không có quyền xem ' + noun + '</b>'
            '<span class="hmt-help" style="max-width:420px">Vai trò Giáo viên chưa được cấp quyền xem phân hệ Khách hàng. Nếu cần xem, hãy liên hệ quản trị viên của trung tâm.</span>'
            '<button class="hmt-btn hmt-btn-primary" type="button" data-act="home">Về trang chủ</button></div></div></div>')

# ------------------------- PHỤ HUYNH -------------------------
CHILD_ROWS = [('HS000123', 'Nguyễn Minh Khôi', '2012', 'Lớp 9', 'THCS Giảng Võ', 'Đang học', 'hmt-tag hmt-tag-success'), ('HS000124', 'Nguyễn Bảo Ngọc', '2015', 'Lớp 6', 'THCS Ngọc Khánh', 'Tiềm năng', 'hmt-tag hmt-tag-info')]
def children_table(rows, can_add):
    if not rows:
        return '<div class="hmt-help" style="padding:var(--space-4) 0;display:flex;flex-direction:column;gap:8px;align-items:flex-start"><b style="color:var(--text-primary)">Chưa có học sinh nào</b><span>Phụ huynh này chưa có con trong hệ thống. %s</span></div>' % ('Bấm Thêm con ở trên để thêm.' if can_add else '')
    return '<table class="hmt-table"><thead><tr><th>Mã</th><th>Họ tên</th><th>Năm sinh</th><th>Khối</th><th>Trường</th><th>Tình trạng</th></tr></thead><tbody>' + ''.join('<tr><td><span class="hmt-code">%s</span></td><td><a href="#" data-go="Mở hồ sơ học sinh %s (màn KH-05).">%s</a></td><td>%s</td><td>%s</td><td>%s</td><td><span class="%s">%s</span></td></tr>' % (c, c, n, y, g, sc, cl, tt) for c, n, y, g, sc, tt, cl in rows) + '</tbody></table>'

def build_ph(state):
    role = {'kt': 'kt', 'quyen': 'gv'}.get(state, 'sa')
    create = state in ('tao', 'loi'); empty_rec = state == 'trong'
    name = 'Chị Nguyễn Thị Lan Anh'; code = 'PH000045'
    if empty_rec: name, code = 'Chị Hồ Thanh Mai', 'PH000064'
    cp = [('Khách hàng', False), ('Phụ huynh', False), ('Phụ huynh mới' if create else ('Đang tải…' if state == 'tai' else name), True)]
    if state == 'quyen': cp = [('Khách hàng', False), ('Phụ huynh', True)]
    s = base('ph', role, 'Phụ huynh', cp, state)
    s = rbar_swap(s, 'Phụ huynh', None if create else '1 / 10')
    perm = {'edit': role == 'sa', 'merge': role == 'sa'}
    vals = {'name': name, 'phone': '0903 456 789', 'ward': 'Phường Giảng Võ', 'prov': 'Hà Nội', 'addr': 'Số 12, ngõ 31 phố Núi Trúc', 'cs': 'CS1 Nguyễn Chí Thanh', 'upd': '16/10/2026 10:12', 'cre': '08/10/2026 10:02'}
    rows = CHILD_ROWS; nchild = 2
    if empty_rec: vals.update({'name': name, 'phone': '0966 120 345', 'addr': 'Số 5 phố Kim Mã', 'ward': 'Phường Kim Mã', 'upd': '17/10/2026 09:40', 'cre': '17/10/2026 09:40'}); rows = []; nchild = 0
    if create: vals = {'cs': 'CS1 Nguyễn Chí Thanh', 'ward': 'Phường Giảng Võ', 'prov': 'Hà Nội'}
    sm = [('grad', nchild, 'Học sinh', nchild > 0), ('target', 1 if not empty_rec else 0, 'Cơ hội', not empty_rec), ('doc', 1 if not empty_rec else 0, 'Đơn', False), ('receipt', 1 if not empty_rec else 0, 'Phiếu thu', False), ('wallet', 0, 'Số dư', False), ('ticket', 0, 'Ticket', False)]
    if empty_rec: sm[0] = ('grad', 0, 'Học sinh', False)
    if create: sm = [(i, 0, l, o) for i, c, l, o in sm]
    h2 = '<h2>%s · <span class="hmt-code">%s</span></h2>' % (name, code) if not create else '<h2>Phụ huynh mới <span class="hmt-auto">mã tự cấp khi Lưu</span></h2>'
    tabs = ('<div><div class="hmt-tabs" role="tablist" style="padding:0"><button class="hmt-tab" role="tab" aria-selected="true" type="button" data-tab="0">Các con (%d)</button><button class="hmt-tab" role="tab" type="button" data-tab="1">Mốc thời gian</button></div>'
            '<div data-tabp="0" style="padding-top:var(--space-3)">%s</div><div class="hmt-fgrid" data-tabp="1" style="padding-top:var(--space-3);display:none">%s%s</div></div>') % (
        nchild, children_table(rows, perm['edit']),
        kvs_tab([('Ngày tạo', '<span class="hmt-num">%s</span>' % vals.get('cre', '')), ('Cập nhật gần nhất', '<span class="hmt-num">%s</span>' % vals.get('upd', ''))]),
        kvs_tab([('Người tạo', 'Trần Thu Hà'), ('Nguồn tạo', 'Tạo trực tiếp')]))
    if create:
        tabs = ('<div><div class="hmt-tabs" role="tablist" style="padding:0"><button class="hmt-tab" role="tab" aria-selected="true" type="button">Các con (0)</button></div><div class="hmt-help" style="padding:var(--space-3) 0">Lưu phụ huynh rồi mới thêm con được.</div></div>')
    sheet = '<div class="hmt-box hmt-sheet" style="flex:1 1 auto" aria-label="Thông tin phụ huynh">' + h2 + '<div data-fields></div>' + tabs + '</div>'
    left = '<div class="hmt-left">' + smart(sm, dim_all=create) + sheet + '</div>'
    if create:
        right_msgs = []; ch = chatter(right_msgs, dim=True, hint='Ghi chú và dòng thời gian mở sau khi Lưu.')
    elif empty_rec:
        ch = chatter([('17/10/2026', [sys_msg('09:40', 'Tạo phụ huynh %s' % code)])])
    else:
        ch = chatter([('Hôm nay · 16/10/2026', [note_msg('Trần Thu Hà', 'TH', '10:12', 'Chị Lan Anh nhờ xếp lịch học thử cho bé Khôi vào tối thứ ba.'), sys_msg('10:10', 'Thêm con: Nguyễn Bảo Ngọc (HS000124)')]),
                      ('08/10/2026', [sys_msg('10:02', 'Tạo phụ huynh PH000045'), sys_msg('10:02', 'Thêm con: Nguyễn Minh Khôi (HS000123)')])])
    wrap = '<div class="hmt-wrap hmt-wrap-scroll">' + left + '<aside class="hmt-right" aria-label="Ghi chú &amp; hoạt động">' + ch + '</aside></div>'
    opt = {'vals': vals, 'perm': perm, 'create': create, 'err': state == 'loi', 'newTitle': 'Phụ huynh mới <span class="hmt-auto">mã tự cấp khi Lưu</span>',
           'createdMsg': 'Đã tạo phụ huynh PH000064. Mở bản ghi vừa tạo (màn KH-02): giai đoạn không có, smart button và ghi chú hết mờ.',
           'buttons': [{'icon': 'plus', 'label': 'Thêm con', 'act': 'addchild', 'need': 'edit'}, {'icon': 'ticket', 'label': 'Tạo ticket', 'act': 'ticket', 'later': 1}, {'icon': 'merge', 'label': 'Gộp', 'act': 'merge', 'need': 'merge'}],
           'acts': {'addchild': 'Mở khuôn Chi tiết trống: học sinh mới, phụ huynh %s điền sẵn (màn KH-06).' % code, 'merge': 'Mở hộp thoại Gộp phụ huynh trùng (màn KH-07).', 'home': 'Về trang chủ theo vai trò (CHUNG-14).'},
           'sb': {'Học sinh': 'Mở danh sách học sinh của phụ huynh này (KH-04, đã lọc).', 'Cơ hội': 'Mở danh sách cơ hội của phụ huynh này (TS-07, đã lọc).'}}
    title = {'normal': 'KH-02 · Phụ huynh · bản ghi', 'trong': 'KH-02 · Phụ huynh · bản ghi chưa có con', 'kt': 'KH-02 · Phụ huynh · Kế toán chỉ xem', 'tao': 'KH-03 · Phụ huynh · khuôn trống (tạo)', 'loi': 'KH-03 · Phụ huynh · khuôn trống, lỗi bắt buộc nhập', 'tai': 'KH-02 · Phụ huynh · đang tải', 'quyen': 'KH-02 · Phụ huynh · không có quyền'}[state]
    if state == 'tai':
        wrap = skeleton_wrap(); opt_js = "const _g = ev => { const b = ev.target.closest && ev.target.closest('button[data-act]'); if (b) { ev.stopPropagation(); toast('Đang tải…'); } };"
        s = s.replace('<span>1 / 10</span>', '<span>… / 10</span>')
        s = re.sub(r'(<div class="hmt-rbar-l"[^>]*>)<h1>Phụ huynh</h1>', r'\1<h1>Phụ huynh</h1>' + '<span style="display:inline-block;margin-left:12px;vertical-align:middle">' + sk(180, 22) + '</span>', s, count=1)
        return finish(s, title, wrap, SK_CSS.replace('\n', ' ') and "// đang tải")
    if state == 'quyen':
        wrap = noperm_wrap('phụ huynh'); s = re.sub(r'<div class="hmt-rbar hmt-rbar-cols">.*?(<div class="hmt-wrap hmt-wrap-scroll">)', r'\1', s, count=1, flags=re.S)
        a = s.index('<div class="hmt-wrap hmt-wrap-scroll">')
        return finish(s, title, wrap, "ROOT.addEventListener('click', ev => { const b = ev.target.closest && ev.target.closest('button[data-act]'); if (b) { ev.stopPropagation(); toast('Về trang chủ theo vai trò (CHUNG-14).'); } }, true);")
    js = REC_JS % {'spec': json.dumps(PH_SPEC, ensure_ascii=False), 'opt': json.dumps(opt, ensure_ascii=False), 'ic': json.dumps({k: IC[k] for k in IC}, ensure_ascii=False)}
    return finish(s, title, wrap, js)

if __name__ == '__main__':
    names = {}
    for st, n in (('normal', 'KH02'), ('trong', 'KH02_trong'), ('tai', 'KH02_tai'), ('quyen', 'KH02_khong_quyen'), ('kt', 'KH02_kt'), ('tao', 'KH03'), ('loi', 'KH03_loi')):
        write(n + '.dc.html', build_ph(st)); names[n] = 1
    print(' '.join(names))

# ------------------------- HỌC SINH -------------------------
LATER_CARDS = [('GHI DANH', ['Mã', 'Gói', 'Ngày vào', 'Trạng thái']), ('QUỸ GIỜ', ['Cấp', 'Đã dùng', 'Còn', 'Tặng']), ('LỚP ĐANG HỌC', ['Lớp', 'Giáo viên', 'Lịch học']), ('ĐIỂM DANH', ['Có mặt', 'Vắng', 'Học bù']),
               ('NHẬN XÉT', ['Buổi', 'Nội dung']), ('BÀI TẬP VỀ NHÀ', ['Bài', 'Hạn nộp', 'Tình trạng']), ('TICKET', ['Mã', 'Loại', 'Tình trạng']), ('TÀI KHOẢN HỌC TẬP', ['Tên đăng nhập', 'Tình trạng'])]
def later_cards():
    h = '<div style="display:grid;grid-template-columns:1fr 1fr;gap:var(--space-3)" title="Làm ở phân hệ sau">'
    for t, cols in LATER_CARDS:
        h += '<div class="hmt-box" style="padding:var(--space-3);opacity:.5;cursor:not-allowed;display:flex;flex-direction:column;gap:6px"><div class="hmt-csec-t">%s</div><div style="display:flex;gap:16px;font-size:12px;color:var(--text-label);border-bottom:1px solid var(--divider);padding-bottom:4px">%s</div><div class="hmt-help">Chưa có dữ liệu</div></div>' % (t, ''.join('<span>%s</span>' % c for c in cols))
    return h + '</div>'

def pkt_block(has):
    if not has:
        return '<div class="hmt-box hmt-box-pad" aria-label="Phiếu kiểm tra đầu vào gần nhất"><div class="hmt-csec-t">PHIẾU KIỂM TRA ĐẦU VÀO GẦN NHẤT</div><div class="hmt-help" style="padding-top:var(--space-2)">Chưa có phiếu kiểm tra đầu vào. Phiếu được tạo từ cơ hội của học sinh.</div></div>'
    kv = [('Mã phiếu', '<a href="#" data-go="Mở phiếu kiểm tra PKT000105 (màn TS-17).">PKT000105</a>'), ('Ngày giờ test', '<span class="hmt-num">12/10/2026 18:30</span>'), ('Điểm', '<b>7,5</b> / 10'), ('Trình độ', 'Khá'), ('Lớp đề xuất', 'Toán 9 nâng cao')]
    return '<div class="hmt-box hmt-box-pad" aria-label="Phiếu kiểm tra đầu vào gần nhất"><div class="hmt-csec-t">PHIẾU KIỂM TRA ĐẦU VÀO GẦN NHẤT</div><div style="display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:var(--space-3);padding-top:var(--space-2)">' + ''.join('<div style="display:flex;flex-direction:column;gap:2px"><span class="hmt-help">%s</span><span>%s</span></div>' % (a, b) for a, b in kv) + '</div></div>'

def build_hs(state):
    role = 'gv' if state == 'quyen' else 'sa'
    create = state in ('tao', 'loi'); nopkt = state == 'trong'
    name = 'Nguyễn Minh Khôi'; code = 'HS000123'
    if nopkt: name, code = 'Đỗ Phương Thảo', 'HS000130'
    cp = [('Khách hàng', False), ('Học sinh', False), ('Học sinh mới' if create else ('Đang tải…' if state == 'tai' else name), True)]
    if state == 'quyen': cp = [('Khách hàng', False), ('Học sinh', True)]
    s = base('hs', role, 'Học sinh', cp, state)
    s = rbar_swap(s, 'Học sinh', None if create else '1 / 10')
    perm = {'edit': True, 'merge': True}
    vals = {'name': name, 'year': '2012', 'grade': 'Lớp 9', 'school': 'THCS Giảng Võ', 'ph': 'Chị Nguyễn Thị Lan Anh', 'tt': 'Đang học', 'cs': 'CS1 Nguyễn Chí Thanh'}
    phcode = 'PH000045'
    if nopkt: vals = {'name': name, 'year': '2014', 'grade': 'Lớp 7', 'school': 'THCS Cầu Giấy', 'ph': 'Chị Đỗ Ngọc Bích', 'tt': 'Tiềm năng', 'cs': 'CS2 Đỗ Quang'}; phcode = 'PH000050'
    if create: vals = {'cs': 'CS1 Nguyễn Chí Thanh', 'grade': 'Lớp 9', 'tt': 'Tiềm năng'}
    n_opp = 0 if create else 1
    sm = [('target', n_opp, 'Cơ hội', not create), ('book', 0, 'Ghi danh', False), ('cap', 0, 'Lớp', False), ('ticket', 0, 'Ticket', False), ('key', 0, 'Tài khoản', False)]
    sm[2] = ('users', 0, 'Lớp', False)
    h2 = ('<h2>%s · <span class="hmt-code">%s</span></h2>' % (name, code)) if not create else '<h2>Học sinh mới <span class="hmt-auto">mã tự cấp khi Lưu</span></h2>'
    sheet = '<div class="hmt-box hmt-sheet" style="flex:0 0 auto" aria-label="Thông tin học sinh">' + h2 + '<div data-fields></div></div>'
    dimbox = lambda inner: ('<div style="opacity:.45;pointer-events:none" title="Có sau khi Lưu">' + inner + '</div>') if create else inner
    left = '<div class="hmt-left">' + smart(sm, dim_all=create) + sheet + dimbox(pkt_block(not nopkt and not create)) + later_cards() + '</div>'
    if create:
        ch = chatter([], dim=True, hint='Ghi chú và dòng thời gian mở sau khi Lưu.')
    elif nopkt:
        ch = chatter([('15/10/2026', [sys_msg('14:05', 'Tạo học sinh %s, phụ huynh %s' % (code, phcode))])])
    else:
        ch = chatter([('Hôm nay · 16/10/2026', [note_msg('Trần Thu Hà', 'TH', '09:50', 'Phụ huynh hỏi lịch học lớp Toán 9 nâng cao buổi tối.'), sys_msg('09:48', 'Cập nhật học sinh', chg('Khối', 'Lớp 8', 'Lớp 9'))]), ('08/10/2026', [sys_msg('10:02', 'Tạo học sinh %s, phụ huynh %s' % (code, phcode))])])
    wrap = '<div class="hmt-wrap hmt-wrap-scroll">' + left + '<aside class="hmt-right" aria-label="Ghi chú &amp; hoạt động">' + ch + '</aside></div>'
    opt = {'vals': vals, 'perm': perm, 'create': create, 'err': state == 'loi', 'newTitle': 'Học sinh mới <span class="hmt-auto">mã tự cấp khi Lưu</span>', 'phCode': phcode,
           'createdMsg': 'Đã tạo học sinh HS000142. Mở bản ghi vừa tạo (màn KH-05): smart button và ghi chú hết mờ.',
           'buttons': [{'icon': 'ticket', 'label': 'Tạo ticket', 'act': 'ticket', 'later': 1}, {'icon': 'key', 'label': 'Cấp tài khoản', 'act': 'account', 'later': 1}, {'icon': 'merge', 'label': 'Gộp', 'act': 'merge', 'need': 'merge'}],
           'acts': {'merge': 'Mở hộp thoại Gộp học sinh trùng (màn KH-07).'},
           'sb': {'Cơ hội': 'Mở danh sách cơ hội của học sinh này (TS-07, đã lọc).'}}
    title = {'normal': 'KH-05 · Học sinh · hồ sơ 360°', 'trong': 'KH-05 · Học sinh · chưa có phiếu kiểm tra', 'tao': 'KH-06 · Học sinh · khuôn trống (tạo)', 'loi': 'KH-06 · Học sinh · khuôn trống, lỗi bắt buộc nhập', 'tai': 'KH-05 · Học sinh · đang tải', 'quyen': 'KH-05 · Học sinh · không có quyền'}[state]
    if state == 'tai':
        s = s.replace('<span>1 / 10</span>', '<span>… / 10</span>')
        s = re.sub(r'(<div class="hmt-rbar-l"[^>]*>)<h1>Học sinh</h1>', r'\1<h1>Học sinh</h1>' + '<span style="display:inline-block;margin-left:12px;vertical-align:middle">' + sk(180, 22) + '</span>', s, count=1)
        return finish(s, title, skeleton_wrap(), "// đang tải")
    if state == 'quyen':
        s = re.sub(r'<div class="hmt-rbar hmt-rbar-cols">.*?(<div class="hmt-wrap hmt-wrap-scroll">)', r'\1', s, count=1, flags=re.S)
        return finish(s, title, noperm_wrap('học sinh'), "ROOT.addEventListener('click', ev => { const b = ev.target.closest && ev.target.closest('button[data-act]'); if (b) { ev.stopPropagation(); toast('Về trang chủ theo vai trò (CHUNG-14).'); } }, true);")
    js = REC_JS % {'spec': json.dumps(HS_SPEC, ensure_ascii=False), 'opt': json.dumps(opt, ensure_ascii=False), 'ic': json.dumps({k: IC[k] for k in IC}, ensure_ascii=False)}
    return finish(s, title, wrap, js)

if __name__ == '__main__':
    for st, n in (('normal', 'KH05'), ('trong', 'KH05_trong'), ('tai', 'KH05_tai'), ('quyen', 'KH05_khong_quyen'), ('tao', 'KH06'), ('loi', 'KH06_loi')):
        write(n + '.dc.html', build_hs(st))
    print('hs ok')
