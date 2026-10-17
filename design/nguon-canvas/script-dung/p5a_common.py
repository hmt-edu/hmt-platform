# -*- coding: utf-8 -*-
# P5a Bán hàng và Thu chi: hàm dùng chung
import sys, re, json
sys.path.insert(0, 'scripts')
import kh_common as K
import build_p4v2_rec as R
from kh_common import SVG, IC, remove_div, SK_CSS, sk, empty_box
OUTD = 'p5a/project/'
def wr(n, s): open(OUTD + n + '.dc.html', 'w', encoding='utf-8').write(s)

IC.update({
 'lock2': '<rect width="18" height="11" x="3" y="11" rx="2" ry="2" /> <path d="M7 11V7a5 5 0 0 1 10 0v4" />',
 'printer': '<path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" /> <path d="M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6" /> <rect x="6" y="14" width="12" height="8" rx="1" />',
 'ban': '<circle cx="12" cy="12" r="10" /> <path d="m4.9 4.9 14.2 14.2" />',
 'file': '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z" /> <path d="M14 2v4a2 2 0 0 0 2 2h4" />',
 'refresh': '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" /> <path d="M21 3v5h-5" /> <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" /> <path d="M8 16H3v5" />',
 'cal': '<path d="M8 2v4" /> <path d="M16 2v4" /> <rect width="18" height="18" x="3" y="4" rx="2" /> <path d="M3 10h18" />',
 'target': IC['target'], 'link': '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" /> <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />',
 'undo': '<path d="M3 7v6h6" /> <path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13" />',
})

USERS = {
 'sa': ('Trần Thu Hà', 'Tuyển sinh · CS1 Nguyễn Chí Thanh', 'TH'),
 'cs': ('Nguyễn Thị Lan', 'CSKH · CS1 Nguyễn Chí Thanh', 'NL'),
 'bm': ('Lê Văn Phong', 'Trưởng cơ sở · CS1 Nguyễn Chí Thanh', 'LP'),
 'kt': ('Phạm Thị Hồng Nhung', 'Kế toán · Toàn hệ thống', 'HN'),
 'ad': ('Đặng Quốc Việt', 'Admin', 'QV'),
 'gv': ('Nguyễn Văn Nam', 'Giáo viên · CS1 Nguyễn Chí Thanh', 'NN'),
}

def money(n): return '{:,}'.format(n).replace(',', '.') + ' đ'
def num(n): return '{:,}'.format(n).replace(',', '.')
def pct(x): return ('%.1f' % x).replace('.', ',').replace(',0', '') + '%'

def btn(label, kind='', icon=None, attrs='', title=None):
    cls = 'hmt-btn' + (' hmt-btn-' + kind if kind else '')
    return '<button class="%s" type="button"%s>%s%s</button>' % (cls, (' ' + attrs) if attrs else '', SVG(IC[icon]) if icon else '', label)
def tag(txt, kind=''): return '<span class="hmt-tag%s">%s</span>' % (' hmt-tag-' + kind if kind else '', txt)
def alert(kind, html, icon='alert'): return '<div class="hmt-alert hmt-alert-%s" role="alert">%s<span>%s</span></div>' % (kind, SVG(IC[icon]), html)
def link(t, do=None): return '<a href="#"%s>%s</a>' % ((' data-do="%s"' % do) if do else '', t)
def code(t): return '<span class="hmt-code">%s</span>' % t
def numc(t): return '<span class="hmt-num">%s</span>' % t
def sec(t): return '<div class="hmt-csec-t" style="padding:var(--space-2) 0 var(--space-1)">%s</div>' % t
def kv(label, val, hint=None):
    return '<div class="hmt-kv"><dt>%s</dt><dd>%s%s</dd></div>' % (label, val, ('<span class="hmt-auto">%s</span>' % hint) if hint else '')
def fgrid(left, right):
    return '<div class="hmt-fgrid"><dl class="hmt-panel-b" style="padding:0">%s</dl><dl class="hmt-panel-b" style="padding:0">%s</dl></div>' % (''.join(left), ''.join(right))

SM_IC = {'Cơ hội': 'target', 'Báo giá': 'doc', 'Đơn hàng': 'receipt', 'Phiếu thu': 'wallet', 'Ghi danh': 'book', 'Phụ huynh': 'user', 'Học sinh': 'grad',
         'Phiếu chi': 'wallet', 'Khoản tiền vào': 'wallet', 'Ticket': 'ticket', 'Lịch hẹn': 'cal'}
def smart(items):
    out = ''
    for lab, n, *rest in items:
        warn = rest and rest[0] == 'alert'
        dim = (n == 0) or (rest and rest[0] == 'dim')
        attrs = ' aria-disabled="true" style="opacity:.55"' if dim and n == 0 else ''
        out += '<button class="hmt-sbtn%s" type="button"%s data-do="Mở %s liên quan."><svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true">%s</svg><span><b>%s</b><span>%s</span></span></button>' % (' hmt-sbtn-alert' if warn else '', attrs, lab.lower(), IC[SM_IC.get(lab, 'doc')], n, lab)
    return '<div class="hmt-box"><div class="hmt-smart wide">%s</div></div>' % out

def stage(steps, cur, branches=None, note=None, lock_from=None):
    """steps: tên các bước; cur: chỉ số bước hiện tại (hoặc None)."""
    h = ''
    for i, s in enumerate(steps):
        if cur is not None and i < cur: h += '<button class="hmt-step hmt-step-past" type="button">%s%s</button>' % (SVG(IC['lock']), s)
        elif i == cur: h += '<button class="hmt-step" type="button" aria-current="step">%s</button>' % s
        else: h += '<button class="hmt-step" type="button">%s</button>' % s
    br = ''
    if branches or note:
        br = '<div style="display:flex;align-items:center;gap:var(--space-2);padding:var(--space-2) var(--space-3) var(--space-1);font-size:12px;color:var(--text-secondary)">' + \
             ('Nhánh khác:' + ''.join('<span class="hmt-tag hmt-tag-%s">%s</span>' % (k, t) if k else '<span class="hmt-tag">%s</span>' % t for t, k in (branches or []))) + \
             (('<span>· %s</span>' % note) if note else '') + '</div>'
    return '<div class="hmt-box" style="padding:var(--space-3) var(--space-3) var(--space-2)" aria-label="Giai đoạn"><nav class="hmt-stage" aria-label="Giai đoạn">%s</nav>%s</div>' % (h, br)

def msg(who, ini, time, kind, body_html, sys=False, chg=None):
    c = ('<span class="hmt-chg">Trạng thái: <s>%s</s>%s<b>%s</b></span>' % (chg[0], SVG(IC.get('arrow', '<path d="M5 12h14" /> <path d="m12 5 7 7-7 7" />')), chg[1])) if chg else ''
    inner = ('<span>%s</span>' % body_html) if sys else ('<div class="hmt-note">%s</div>' % body_html)
    return '<div class="hmt-msg"><span class="hmt-avatar hmt-avatar-lg%s">%s</span><div class="hmt-msg-b"><span class="hmt-meta"><b>%s</b> · <span class="hmt-num">%s</span> · %s</span>%s%s</div></div>' % (' hmt-avatar-sys' if sys else '', ini, who, time, kind, inner, c)
ARROW = '<path d="M5 12h14" /> <path d="m12 5 7 7-7 7" />'
IC['arrow'] = ARROW
def sysmsg(time, body, chg=None): return msg('Hệ thống', 'HT', time, 'Hệ thống', body, sys=True, chg=chg)

def chatter(days, upcoming=None, readonly=False, follow=True):
    """days: [(nhãn ngày, [msg html])]"""
    h = '<aside class="hmt-right" aria-label="Ghi chú &amp; hoạt động"><div class="hmt-chatter"><div class="hmt-chatter-h"><h3>Ghi chú &amp; hoạt động</h3>%s</div>' % \
        (btn('Theo dõi', 'text', 'eye', 'data-do="Đã bật theo dõi."') if follow else '')
    if not readonly:
        h += '<div class="hmt-csec"><textarea class="hmt-textarea" aria-label="Nội dung ghi chú" placeholder="Viết ghi chú… gõ @ để nhắc đồng nghiệp" rows="3"></textarea><div class="hmt-row"><button class="hmt-btn" type="button">%s Gửi ghi chú</button></div></div>' % SVG(IC['send'])
    if upcoming: h += upcoming
    h += '<div class="hmt-csec"><div class="hmt-csec-t">DÒNG THỜI GIAN</div><div class="hmt-pills" role="group" aria-label="Lọc dòng thời gian"><button type="button" aria-pressed="true">Tất cả</button><button type="button" aria-pressed="false">Ghi chú</button><button type="button" aria-pressed="false">Hệ thống</button></div></div>'
    for d, ms in days:
        h += '<div class="hmt-day">%s</div>' % d + ''.join(ms)
    return h + '<div style="height:var(--space-3)"></div></div></aside>'
IC['eye'] = '<path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0" /> <circle cx="12" cy="12" r="3" />'

def sidebar_bh(s, active=None, group=3, hide=False):
    """group 3 = Bán hàng & thu chi (mặc định), 6 = Báo cáo."""
    a = s.index('<nav class="hmt-sb'); b = s.index('</nav>', a) + 6
    n = s[a:b].replace(' aria-current="page"', '')
    n = re.sub(r'(<button class="hmt-sb-l1"[^>]*aria-expanded=")true', r'\1false', n)
    n = re.sub(r'<a class="hmt-sb-l2"[^>]*>[^<]*</a>', '', n)
    ITEMS = {3: ['Báo giá', 'Đơn hàng', 'Phiếu thu', 'Hàng chờ kế toán duyệt', 'Khoản tiền vào', 'Phiếu chi', 'Công nợ', 'Số dư khách hàng'],
             4: ['Ghi danh', 'Hàng chờ xếp lớp', 'Sắp hết giờ', 'Tái tục', 'Lớp học', 'Lịch tuần cơ sở', 'Buổi học', 'Yêu cầu buổi', 'Điểm danh trong ngày', 'Buổi chưa hoàn tất'],
             6: ['Tổng quan Ban giám đốc', 'Đối soát thu tiền', 'Giờ dạy giáo viên', 'Giáo viên trễ hạn', 'Báo cáo Looker Studio ↗']}
    titles = {3: 'Bán hàng &amp; thu chi', 4: 'Đào tạo', 6: 'Báo cáo'}
    t = titles[group]
    m = re.search(r'<button class="hmt-sb-l1"[^>]*title="%s"[^>]*>.*?</button>' % re.escape(t), n, flags=re.S)
    btnh = m.group(0).replace('aria-expanded="false"', 'aria-expanded="true"')
    its = ''.join('<a class="hmt-sb-l2" href="#" data-p="%d"%s>%s</a>' % (group, ' aria-current="page"' if x == active else '', x) for x in ITEMS[group])
    n = n.replace(m.group(0), btnh + its)
    if hide: n = re.sub(r'<button class="hmt-sb-l1"[^>]*title="Bán hàng &amp; thu chi"[^>]*>.*?</button>(<a class="hmt-sb-l2"[^>]*>[^<]*</a>)*', '', n, flags=re.S)
    return s[:a] + n + s[b:]

def dialog(did, label, head, body, foot, w=480):
    return ('<div class="hmt-scrim" data-dlg="%s" style="position:absolute;inset:0;z-index:50;align-items:center;padding:0;display:none">'
            '<div class="hmt-dialog" role="dialog" aria-label="%s" style="width:%dpx;flex:0 0 %dpx"><div class="hmt-dialog-h">%s<button class="hmt-iconbtn x" type="button" aria-label="Đóng" data-close="1">%s</button></div>'
            '<div class="hmt-dialog-b">%s</div><div class="hmt-dialog-f">%s</div></div></div>') % (did, label, w, w, head, SVG(IC['x']), body, foot)

P5_CSS = '<style>.p5t{table-layout:fixed}.p5t td{white-space:normal;vertical-align:top;height:auto;padding-top:8px;padding-bottom:8px}.p5t td .hmt-help{white-space:normal}.p5t th,.p5t td{padding-left:8px;padding-right:8px}.p5t th:first-child,.p5t td:first-child{padding-left:12px}.p5t .hmt-code{font-size:11px;white-space:normal;word-break:break-all}.p5k{display:grid;grid-template-columns:repeat(4,1fr);gap:12px 20px;padding:var(--space-3) 0}.p5k>div>span{display:block;font-size:12px;color:var(--text-secondary);margin-bottom:2px}.p5k>div>div{font-size:13px}.p5t td.r,.p5t th.r{text-align:right}</style>'
P5_JS = r"""
const DLGS = %(dlgs)s; const SHOW0 = %(show0)s; const APPE = q('.hmt-app');
ROOT.insertAdjacentHTML('beforeend', DLGS);
const dl = id => q('[data-dlg="' + id + '"]');
function openD(id) { const d = dl(id); if (!d) return; qa('[data-dlg]').forEach(x => { x.style.display = 'none'; }); d.style.display = 'flex'; if (APPE) APPE.style.filter = 'blur(1.5px)'; }
function closeD() { qa('[data-dlg]').forEach(x => { x.style.display = 'none'; }); if (APPE) APPE.style.filter = ''; }
if (SHOW0) openD(SHOW0);
ROOT.addEventListener('click', ev => {
  const t = ev.target; const o = t.closest('[data-open]'); if (o && !t.closest('[data-dlg]')) { ev.preventDefault(); ev.stopPropagation(); openD(o.getAttribute('data-open')); const pt = o.getAttribute('data-pane-to'); if (pt) { qa('[data-pane]', dl(o.getAttribute('data-open'))).forEach(x => { x.style.display = x.getAttribute('data-pane') === pt ? '' : 'none'; }); } return; }
  const dg = t.closest('[data-dlg]');
  if (dg) { if (t === dg || t.closest('[data-close]')) { ev.stopPropagation(); closeD(); return; }
    const d = t.closest('[data-dto]'); if (d) { ev.stopPropagation(); if (d.disabled || d.getAttribute('aria-disabled') === 'true') return; closeD(); toast(d.getAttribute('data-dto')); return; }
    const pb = t.closest('.hmt-pills button'); if (pb) { qa('button', pb.parentElement).forEach(x => x.setAttribute('aria-pressed', x === pb ? 'true' : 'false')); ev.stopPropagation(); return; } }
  const pill = !dg && t.closest('.hmt-pills button'); if (pill && !t.closest('.hmt-chatter')) { qa('button', pill.parentElement).forEach(x => x.setAttribute('aria-pressed', x === pill ? 'true' : 'false')); }
  const lk = !dg && t.closest('a[href="#"]'); if (lk && !lk.hasAttribute('data-do')) { ev.preventDefault(); toast('Mở “' + lk.textContent.trim() + '”.'); return; }
  const pg = t.closest('.hmt-pager button'); if (pg) { toast(pg.getAttribute('aria-label') === 'Bản ghi trước' ? 'Chuyển sang bản ghi trước trong danh sách.' : 'Chuyển sang bản ghi sau trong danh sách.'); return; }
  const tb = t.closest('.hmt-tab[data-tab]'); if (tb) { qa('.hmt-tab[data-tab]', tb.parentElement).forEach(x => x.setAttribute('aria-selected', x === tb ? 'true' : 'false')); qa('[data-panel]').forEach(x => { x.style.display = x.getAttribute('data-panel') === tb.getAttribute('data-tab') ? 'flex' : 'none'; }); ev.stopPropagation(); return; }
  const pn = t.closest('[data-pane-to]'); if (pn) { const d2 = pn.closest('[data-dlg]'); qa('[data-pane]', d2).forEach(x => { x.style.display = x.getAttribute('data-pane') === pn.getAttribute('data-pane-to') ? '' : 'none'; }); ev.stopPropagation(); return; }
  const gn = t.closest('button'); if (gn && !dg && /^Gửi ghi chú/.test(gn.textContent.trim())) { const ta = q('.hmt-chatter textarea'); const v = ta.value.trim(); if (!v) { toast('Chưa nhập nội dung ghi chú.'); return; }
    const day = q('.hmt-day'); const m = document.createElement('div'); m.className = 'hmt-msg'; const u = q('.hmt-user-n b'); const av = q('.hmt-user .hmt-avatar'); const d = new Date();
    m.innerHTML = '<span class="hmt-avatar hmt-avatar-lg">' + (av ? av.textContent : '') + '</span><div class="hmt-msg-b"><span class="hmt-meta"><b>' + (u ? u.textContent : '') + '</b> · <span class="hmt-num">' + ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2) + '</span> · Ghi chú</span><div class="hmt-note"></div></div>'; q('.hmt-note', m).textContent = v; day.after(m); ta.value = ''; toast('Đã gửi ghi chú.'); }
}, true);
"""

def page(title, nav, user, crumb_parts, rbar_l, left, aside, pager='1 / 1', dlgs='', show0='', group=3, hide_nav=False, extra_js=''):
    t = R.prep('Main', title, obj='Học sinh')
    t = sidebar_bh(t, nav, group, hide=hide_nav)
    t = K.crumb(t, crumb_parts)
    t = R.set_user(t, *USERS[user])
    a = t.index('<div class="hmt-rbar-l">'); t, _ = remove_div(t, a); t = t[:a] + '<div class="hmt-rbar-l">' + rbar_l + '</div>' + t[a:]
    t = t.replace('12 / 480', pager, 1)
    a = t.index('<div class="hmt-left">'); t, _ = remove_div(t, a); t = t[:a] + '<div class="hmt-left">' + left + '</div>' + t[a:]
    a = t.index('<aside'); b = t.index('</aside>') + 8; t = t[:a] + aside + t[b:]
    js = P5_JS % {'dlgs': json.dumps(dlgs, ensure_ascii=False), 'show0': json.dumps(show0)} + extra_js
    t = t.replace('</helmet>', P5_CSS + '</helmet>', 1)
    assert t.count('// @@ANCHOR@@') == 1
    return t.replace('// @@ANCHOR@@', js + '\n// @@ANCHOR@@', 1)

def menu(items, extra=''):
    """Hành động ▾"""
    its = ''.join('<button class="hmt-opt" type="button"%s>%s%s</button>' % ((' ' + a) if a else '', SVG(IC[i]) if i else '', ' ' + l) for l, i, a in items)
    return ('<span class="push-r" style="position:relative"><button class="hmt-btn hmt-btn-text" type="button" data-hd="1">Hành động<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg></button>'
            '<div class="hmt-menu" role="menu" data-menu style="display:none;position:absolute;right:-8px;top:40px;z-index:30;min-width:220px">%s</div></span>') % its

def rbar_l(title, buttons, menu_items=None):
    return '<h1>%s</h1>%s%s' % (title, ''.join(buttons), menu(menu_items) if menu_items else '')

def sheet(title_html, body_html, tabs=None):
    tb = ''
    if tabs:
        tb = '<div class="hmt-tabs" role="tablist">' + ''.join('<button class="hmt-tab" role="tab" aria-selected="%s" type="button">%s</button>' % ('true' if i == 0 else 'false', x) for i, x in enumerate(tabs)) + '</div>'
    return '<div class="hmt-box hmt-sheet" style="flex:1 1 auto"><h2>%s</h2><div>%s<div style="padding-top:var(--space-3);display:flex;flex-direction:column;gap:16px">%s</div></div></div>' % (title_html, tb, body_html)

def table(heads, rows, nt=True, cls='', widths=None, wrap=False):
    """heads: [(label, 'r'|'')], rows: danh sách list ô html (chuỗi)."""
    th = ''.join('<th%s>%s</th>' % (' class="r"' if r else '', l) for l, r in heads)
    body = ''
    for row in rows:
        body += '<tr>' + ''.join('<td%s>%s</td>' % (' class="r"' if heads[i][1] else '', c) for i, c in enumerate(row)) + '</tr>'
    cg = ('<colgroup>' + ''.join('<col style="width:%dpx">' % w for w in widths) + '</colgroup>') if widths else ''
    return '<div class="hmt-table-wrap"><table class="hmt-table%s%s">%s<thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (' ' + cls if cls else '', ' p5t' if wrap else '', cg, th, body)

def noperm_page(title, noun, role='gv', who_can=None):
    box = ('<div class="hmt-left" style="max-width:none"><div class="hmt-box hmt-empty" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:48px 20px;text-align:center;min-height:460px;margin:var(--space-6) auto;max-width:560px;flex:0 0 auto">'
           '<span style="color:var(--text-secondary)">' + SVG(IC['lock'], 'hmt-ic hmt-ic-lg') + '</span><b style="color:var(--text-primary);font-size:16px;font-family:var(--font-heading)">Bạn không có quyền xem ' + noun + '</b>'
           '<span class="hmt-help" style="max-width:420px">' + (who_can or 'Vai trò Giáo viên chưa được cấp quyền xem phân hệ Bán hàng và thu chi.') + ' Nếu cần xem, hãy liên hệ quản trị viên của trung tâm.</span>'
           '<button class="hmt-btn hmt-btn-primary" type="button" data-do="Về trang chủ theo vai trò (CHUNG-14).">Về trang chủ</button></div></div>')
    t = R.prep('Main', title, obj='Học sinh')
    t = sidebar_bh(t, None, 3, hide=True)
    t = K.crumb(t, [(noun[0].upper() + noun[1:], True)])
    t = R.set_user(t, *USERS[role])
    a = t.index('<div class="hmt-rbar-l">'); t, _ = remove_div(t, a); t = t[:a] + '<div class="hmt-rbar-l"><h1>%s</h1></div>' % (noun[0].upper() + noun[1:]) + t[a:]
    a = t.index('<div class="hmt-rbar-r">'); t, _ = remove_div(t, a); t = t[:a] + '<div class="hmt-rbar-r"></div>' + t[a:]
    a = t.index('<div class="hmt-left">'); t, _ = remove_div(t, a); t = t[:a] + box + t[a:]
    a = t.index('<aside'); b = t.index('</aside>') + 8; t = t[:a] + t[b:]
    js = P5_JS % {'dlgs': json.dumps('', ensure_ascii=False), 'show0': json.dumps('')}
    return t.replace('// @@ANCHOR@@', js + '\n// @@ANCHOR@@', 1)

def loading_page(title, nav, user, crumb_parts, h1):
    t = page(title, nav, user, crumb_parts, '<h1>%s</h1>' % h1, '<div class="hmt-left"></div>', '<aside></aside>')
    t = R.skeleton(t)
    return t

def sheet2(title_html, head_html, panels, alerts=''):
    """panels: [(nhãn, html)] — tab đầu hiện sẵn."""
    tb = '<div class="hmt-tabs" role="tablist">' + ''.join('<button class="hmt-tab" role="tab" data-tab="t%d" aria-selected="%s" type="button">%s</button>' % (i, 'true' if i == 0 else 'false', l) for i, (l, h) in enumerate(panels)) + '</div>'
    pn = ''.join('<div data-panel="t%d"%s style="display:%s;flex-direction:column;gap:16px">%s</div>' % (i, '', 'flex' if i == 0 else 'none', h) for i, (l, h) in enumerate(panels))
    return '<div class="hmt-box hmt-sheet" style="flex:1 1 auto"><h2>%s</h2><div>%s%s<div style="padding-top:var(--space-3);display:flex;flex-direction:column;gap:16px">%s%s</div></div></div>' % (title_html, head_html, tb, alerts, pn)

def kgrid(items):
    """items: [(nhãn, giá trị html)] -> lưới 4 cột gọn"""
    return '<div class="p5k">' + ''.join('<div><span>%s</span><div>%s</div></div>' % (l, v) for l, v in items) + '</div>'

P5_LJS = r"""
const DLGS = %(dlgs)s; const SHOW0 = %(show0)s; const APPE = q('.hmt-app');
if (DLGS) ROOT.insertAdjacentHTML('beforeend', DLGS);
const dl = id => q('[data-dlg="' + id + '"]');
function openD(id) { const d = dl(id); if (!d) return; qa('[data-dlg]').forEach(x => { x.style.display = 'none'; }); d.style.display = 'flex'; if (APPE) APPE.style.filter = 'blur(1.5px)'; }
function closeD() { qa('[data-dlg]').forEach(x => { x.style.display = 'none'; }); if (APPE) APPE.style.filter = ''; }
if (SHOW0) openD(SHOW0);
ROOT.addEventListener('click', ev => {
  const t = ev.target; const dg = t.closest('[data-dlg]');
  if (dg) { if (t === dg || t.closest('[data-close]')) { ev.stopPropagation(); closeD(); return; }
    const pn = t.closest('[data-pane-to]'); if (pn) { qa('[data-pane]', dg).forEach(x => { x.style.display = x.getAttribute('data-pane') === pn.getAttribute('data-pane-to') ? '' : 'none'; }); ev.stopPropagation(); return; }
    const d = t.closest('[data-dto]'); if (d) { ev.stopPropagation(); if (d.disabled || d.getAttribute('aria-disabled') === 'true') return; closeD(); toast(d.getAttribute('data-dto')); return; } return; }
  const o = t.closest('[data-open]'); if (o) { ev.preventDefault(); ev.stopPropagation(); openD(o.getAttribute('data-open')); const pt = o.getAttribute('data-pane-to'); if (pt) { qa('[data-pane]', dl(o.getAttribute('data-open'))).forEach(x => { x.style.display = x.getAttribute('data-pane') === pt ? '' : 'none'; }); } return; }
  const dd = t.closest('[data-do]'); if (dd) { ev.preventDefault(); ev.stopPropagation(); toast(dd.getAttribute('data-do')); }
}, true);
"""
