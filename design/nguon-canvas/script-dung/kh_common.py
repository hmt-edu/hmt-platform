# -*- coding: utf-8 -*-
# Dùng chung cho P4 Khách hàng (KH-01…KH-07)
import re, json
P = 'live15/project/'
def read(n): return open(P + n, encoding='utf-8').read()
def write(n, s): open(P + n, 'w', encoding='utf-8').write(s)

def SVG(inner, cls='hmt-ic '): return '<svg class="%s" viewBox="0 0 24 24" aria-hidden="true">%s</svg>' % (cls, inner)
IC = {
 'pencil': '<path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z" /> <path d="m15 5 4 4" />',
 'plus': '<path d="M5 12h14" /> <path d="M12 5v14" />',
 'check': '<path d="M20 6 9 17l-5-5" />',
 'x': '<path d="M18 6 6 18" /> <path d="m6 6 12 12" />',
 'merge': '<circle cx="18" cy="18" r="3" /> <circle cx="6" cy="6" r="3" /> <path d="M6 21V9a9 9 0 0 0 9 9" />',
 'ticket': '<path d="M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z" /> <path d="M13 5v2" /> <path d="M13 17v2" /> <path d="M13 11v2" />',
 'key': '<path d="m15.5 7.5 2.3 2.3a1 1 0 0 0 1.4 0l2.1-2.1a1 1 0 0 0 0-1.4L19 4" /> <path d="m21 2-9.6 9.6" /> <circle cx="7.5" cy="15.5" r="5.5" />',
 'clip': '<path d="M13.234 20.252 21 12.3" /> <path d="m16 6-8.414 8.586a2 2 0 0 0 0 2.828 2 2 0 0 0 2.828 0l8.414-8.586a4 4 0 0 0 0-5.656 4 4 0 0 0-5.656 0l-8.415 8.585a6 6 0 1 0 8.486 8.486" />',
 'grad': '<path d="M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z" /> <path d="M22 10v6" /> <path d="M6 12.5V16a6 3 0 0 0 12 0v-3.5" />',
 'target': '<circle cx="12" cy="12" r="10" /> <circle cx="12" cy="12" r="6" /> <circle cx="12" cy="12" r="2" />',
 'doc': '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z" /> <path d="M14 2v4a2 2 0 0 0 2 2h4" /> <path d="M10 9H8" /> <path d="M16 13H8" /> <path d="M16 17H8" />',
 'receipt': '<path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z" /> <path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8" /> <path d="M12 17.5v-11" />',
 'wallet': '<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1" /> <path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4" />',
 'book': '<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20" />',
 'user': '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" /> <circle cx="12" cy="7" r="4" />',
 'users': '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /> <circle cx="9" cy="7" r="4" /> <path d="M22 21v-2a4 4 0 0 0-3-3.87" /> <path d="M16 3.13a4 4 0 0 1 0 7.75" />',
 'lock': '<rect width="18" height="11" x="3" y="11" rx="2" ry="2" /> <path d="M7 11V7a5 5 0 0 1 10 0v4" />',
 'search': '<circle cx="11" cy="11" r="8" /> <path d="m21 21-4.3-4.3" />',
 'send': '<path d="M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z" /> <path d="m21.854 2.147-10.94 10.939" />',
 'alert': '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3" /> <path d="M12 9v4" /> <path d="M12 17h.01" />',
 'cap': '<path d="M12 2v4" /> <path d="m16.2 7.8 2.9-2.9" /> <path d="M18 12h4" />',
}

def remove_div(s, start):
    """Xoá phần tử <div ...> bắt đầu tại vị trí start (cân bằng thẻ)."""
    assert s.startswith('<div', start), s[start:start+30]
    depth = 0; i = start
    for m in re.finditer(r'<div\b|</div>', s[start:]):
        depth += 1 if m.group(0).startswith('<div') else -1
        if depth == 0:
            return s[:start] + s[start + m.end():], s[start:start + m.end()]
    raise ValueError('div không cân bằng')

def find_div(s, marker):
    i = s.index(marker); j = s.rfind('<div', 0, i + 1)
    return j

def sidebar(s, active=None, hide_kh=False):
    a = s.index('<nav class="hmt-sb'); b = s.index('</nav>', a) + 6
    n = s[a:b].replace(' aria-current="page"', '')
    n = re.sub(r'(title="Tuyển sinh" data-g="1" aria-expanded=")true', r'\1false', n)
    n = re.sub(r'<a class="hmt-sb-l2" href="#" data-p="1"( style="display:none")?', '<a class="hmt-sb-l2" href="#" data-p="1" style="display:none"', n)
    if hide_kh:
        n = re.sub(r'<button class="hmt-sb-l1" type="button" title="Khách hàng".*?</button>', '', n, flags=re.S)
        n = re.sub(r'<a class="hmt-sb-l2" href="#" data-p="2"[^>]*>(Phụ huynh|Học sinh)</a>', '', n)
    else:
        n = re.sub(r'(title="Khách hàng" data-g="2" aria-expanded=")false', r'\1true', n)
        n = re.sub(r'<a class="hmt-sb-l2" href="#" data-p="2"[^>]*>(Phụ huynh|Học sinh)</a>',
                   lambda m: '<a class="hmt-sb-l2" href="#" data-p="2"%s>%s</a>' % (' aria-current="page"' if m.group(1) == active else '', m.group(1)), n)
    return s[:a] + n + s[b:]

def crumb(s, parts):
    chev = SVG('<path d="m9 18 6-6-6-6" />')
    out = ''
    for i, (t, last) in enumerate(parts):
        if i: out += chev
        out += ('<span aria-current="page">%s</span>' % t) if last else ('<a href="#">%s</a>' % t)
    return re.sub(r'(<nav class="hmt-crumb"[^>]*>).*?(</nav>)', lambda m: m.group(1) + out + m.group(2), s, count=1, flags=re.S)

def user(s, name, role, ini):
    s = re.sub(r'<span class="hmt-avatar hmt-avatar-lg">TH</span><span class="hmt-user-n"><b>Trần Thu Hà</b><span>[^<]*</span>',
               '<span class="hmt-avatar hmt-avatar-lg">%s</span><span class="hmt-user-n"><b>%s</b><span>%s</span>' % (ini, name, role), s, count=1)
    return s

def retitle(s, t):
    return re.sub(r'<title>[^<]*</title>', '<title>%s</title>' % t, s, count=1)

SK_CSS = '<style>.sk{display:block;border-radius:6px;background:linear-gradient(90deg,var(--bg-subtle) 25%,var(--divider) 37%,var(--bg-subtle) 63%);background-size:400% 100%;animation:skm 1.4s ease infinite}@keyframes skm{0%{background-position:100% 50%}100%{background-position:0 50%}}</style>'
def sk(w, h, r=None, extra=''):
    return '<i class="sk" style="width:%s;height:%spx;%s%s"></i>' % (w if isinstance(w, str) else '%dpx' % w, h, ('border-radius:%dpx;' % r) if r else '', extra)

def empty_box(icon, title, sub, btn=None, h=300):
    b = ('<button class="hmt-btn hmt-btn-primary" type="button" data-act="%s">%s%s</button>' % (btn[1], SVG(IC[btn[2]]) if len(btn) > 2 else '', btn[0])) if btn else ''
    return ('<div class="hmt-box hmt-empty" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:32px 20px;text-align:center;min-height:%dpx;margin:var(--space-4)">'
            '<span style="color:var(--text-secondary)">%s</span><b style="color:var(--text-primary);font-size:15px">%s</b><span class="hmt-help" style="max-width:460px">%s</span>%s</div>') % (h, SVG(IC[icon], 'hmt-ic hmt-ic-lg'), title, sub, b)

ANCHOR = "if (CFG.init) CFG.init(X());"
def inject(s, title, js):
    assert s.count(ANCHOR) == 1
    s = s.replace(ANCHOR, "// ===== màn " + title + " =====\n(function () {\n" + js + "\n})();\n" + ANCHOR)
    return retitle(s, title)

def replace_cfg(s, cfg_js):
    a = s.index('const CFG = {'); b = s.index('const ROOT = document.querySelector')
    return s[:a] + cfg_js + '\n' + s[b:]
