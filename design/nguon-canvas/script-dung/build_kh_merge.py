# -*- coding: utf-8 -*-
# KH-07 Gộp phụ huynh / học sinh trùng: hộp thoại K4 (K8 trong bản đồ), cùng cách làm với TS-10
import sys, re, json
sys.path.insert(0, 'scripts')
from kh_common import *

OVJS = r"""
const OV = document.createElement('div'); OV.className = 'ix-ov'; OV.style.cssText = 'position:absolute;inset:0;z-index:150;display:flex;align-items:center;justify-content:center;background:rgba(33,28,22,.32)';
OV.innerHTML = HTML; ROOT.appendChild(OV);
const APP = q('.hmt-app'); const show = on => { OV.style.display = on ? 'flex' : 'none'; if (APP) APP.style.filter = on ? 'blur(1.5px)' : ''; }; show(true);
['input', 'change', 'keydown', 'mousedown', 'keyup'].forEach(t => OV.addEventListener(t, ev => ev.stopPropagation()));
const $ = (s, r) => (r || OV).querySelector(s), $$ = (s, r) => Array.from((r || OV).querySelectorAll(s));
"""
X = SVG('<path d="M18 6 6 18" /> <path d="m6 6 12 12" />')
HTML = ('<div class="hmt-dialog" role="dialog" aria-label="Gộp trùng" style="width:880px;flex:0 0 880px;max-height:940px"><div class="hmt-dialog-h"><span data-ttl>Gộp phụ huynh trùng</span><button class="hmt-iconbtn x" type="button" aria-label="Đóng">' + X + '</button></div>'
 '<div class="hmt-dialog-b" style="gap:var(--space-3);overflow:auto">'
 '<div style="display:flex;align-items:center;gap:var(--space-3)"><div class="hmt-pills" role="group" aria-label="Loại hồ sơ" style="flex:0 0 auto;flex-wrap:nowrap;white-space:nowrap"><button type="button" aria-pressed="true" data-mode="ph">Phụ huynh</button><button type="button" aria-pressed="false" data-mode="hs">Học sinh</button></div><span class="hmt-help" data-sub></span></div>'
 '<div data-pick></div>'
 '<div data-cards style="display:grid;grid-template-columns:1fr 1fr;gap:var(--space-3)"></div>'
 '<div data-block></div>'
 '<div data-move style="border:1px solid var(--divider);border-radius:var(--radius-md);padding:var(--space-3);display:flex;flex-direction:column;gap:6px"></div>'
 '<span class="hmt-help" data-note></span>'
 '<label style="display:flex;gap:8px;align-items:flex-start;font-size:14px;cursor:pointer"><input type="checkbox" data-cf style="margin-top:3px;accent-color:var(--action-primary-bg)"> <span data-cft></span></label></div>'
 '<div class="hmt-dialog-f"><span class="hmt-help" data-xb style="margin-right:auto;display:flex;align-items:center;gap:6px;color:var(--text-primary)"></span><button class="hmt-btn " type="button">Huỷ</button><button class="hmt-btn hmt-btn-primary" type="button" data-merge>Gộp</button></div></div>')

DATA = {
 'ph': {'ttl': 'Gộp phụ huynh trùng', 'noun': 'phụ huynh', 'sub': 'Hai phụ huynh cùng SĐT 0903 456 789. Chọn hồ sơ giữ lại; con, đơn, phiếu thu và ghi chú của hồ sơ kia chuyển sang hồ sơ giữ lại.',
  'rec': [
   {'code': 'PH000045', 'name': 'Chị Nguyễn Thị Lan Anh', 'cs': 'CS1', 'kv': [['SĐT', '0903 456 789'], ['Cơ sở', 'CS1 Nguyễn Chí Thanh'], ['Số con', '2'], ['Số đơn', '1'], ['Cập nhật', '16/10/2026'], ['Ngày tạo', '08/10/2026']],
    'move': {}},
   {'code': 'PH000072', 'name': 'Nguyễn Thị Lan Anh', 'cs': 'CS1', 'kv': [['SĐT', '0903 456 789'], ['Cơ sở', 'CS1 Nguyễn Chí Thanh'], ['Số con', '1'], ['Số đơn', '1'], ['Cập nhật', '15/10/2026'], ['Ngày tạo', '15/10/2026']],
    'move': {'CÁC CON': ['HS000141 · Nguyễn Minh Khôi · 2012 · Lớp 9'], 'ĐƠN': ['DH-CS1-2610-0009 · Đã duyệt · 3.200.000đ'], 'PHIẾU THU': ['PT-CS1-2610-0014 · 1.000.000đ · 15/10/2026'], 'GHI CHÚ': ['Nguyễn Văn Nam · 15/10 16:20 · “PH nhắn Zalo hỏi lịch học thử.”', 'Nguyễn Văn Nam · 15/10 16:25 · “Hẹn gọi lại sáng thứ 5.”']}}],
  'sugg': [['PH000072', 'Nguyễn Thị Lan Anh', '0903 456 789 · CS1', 'Cùng SĐT'], ['PH000081', 'Nguyễn Thị Lan Anh', '0903 456 789 · CS2', 'Cùng SĐT, khác cơ sở']],
  'conf': []},
 'hs': {'ttl': 'Gộp học sinh trùng', 'noun': 'học sinh', 'sub': 'Hai học sinh cùng tên, cùng năm sinh 2012, cùng phụ huynh. Chọn hồ sơ giữ lại; ghi danh, phiếu kiểm tra và ghi chú của hồ sơ kia chuyển sang hồ sơ giữ lại.',
  'rec': [
   {'code': 'HS000123', 'name': 'Nguyễn Minh Khôi', 'cs': 'CS1', 'kv': [['Năm sinh · Khối', '2012 · Lớp 9'], ['Trường', 'THCS Giảng Võ'], ['Phụ huynh', 'PH000045 · Chị Nguyễn Thị Lan Anh'], ['Tình trạng', 'Đang học'], ['Cơ sở', 'CS1 Nguyễn Chí Thanh'], ['Lớp đang học', 'Toán 9 nâng cao (T9N1) · T3, T5 18:30–20:00']],
    'move': {}},
   {'code': 'HS000141', 'name': 'Nguyễn Minh Khôi', 'cs': 'CS1', 'kv': [['Năm sinh · Khối', '2012 · Lớp 9'], ['Trường', 'THCS Giảng Võ'], ['Phụ huynh', 'PH000045 · Chị Nguyễn Thị Lan Anh'], ['Tình trạng', 'Tiềm năng'], ['Cơ sở', 'CS1 Nguyễn Chí Thanh'], ['Lớp đang học', 'Chưa xếp lớp']],
    'move': {'GHI DANH': ['GD000092 · Toán 9 cơ bản · còn 24 giờ · chưa xếp lớp'], 'PHIẾU KIỂM TRA': ['PKT000110 · Hoàn thành · 05/10/2026 · điểm 6,0/10'], 'GHI CHÚ': ['Nguyễn Văn Nam · 06/10 11:02 · “PH muốn học nhóm nhỏ.”']}}],
  'sugg': [['HS000141', 'Nguyễn Minh Khôi', '2012 · Lớp 9 · CS1', 'Cùng tên, năm sinh, phụ huynh']],
  'conf': ['Học sinh đang học hai lớp trùng giờ: <b>T9N1 Toán 9 nâng cao</b> (HS000123) và <b>T9C2 Toán 9 cơ bản</b> (HS000141, sau khi xếp lớp) cùng T3, T5 18:30–20:00.']},
}
# hs xung đột: HS000141 đã được xếp lớp T9C2 trùng giờ
CONF_HS = DATA['hs']['rec'][1]
JS = OVJS + r"""
const D = %(data)s; const CASE = '%(case)s'; const MODE0 = '%(mode)s'; const SHOWTOG = %(tog)s; const XBN = 'Chỉ Admin gộp được hồ sơ của hai cơ sở khác nhau';
const LOCK = '%(lock)s'; const ALERT = '%(alert)s'; const SKC = '%(skcss)s';
let mode = MODE0, keep = 0, picked = (CASE !== 'trong');
const sk = (w, h) => '<i class="sk" style="width:' + w + ';height:' + h + 'px"></i>';
function render() {
  const m = D[mode]; let k = m.rec[keep], o = m.rec[1 - keep];
  const xb = CASE === 'xb', chan = CASE === 'chan', tai = CASE === 'tai';
  if (xb) { o = Object.assign({}, o, { code: mode === 'ph' ? 'PH000081' : o.code, cs: 'CS2' }); }
  $('[data-ttl]').textContent = m.ttl; $('[data-sub]').textContent = m.sub;
  $('[data-mode]', OV); $$('[data-mode]').forEach(b => { b.setAttribute('aria-pressed', b.getAttribute('data-mode') === mode ? 'true' : 'false'); b.style.display = SHOWTOG ? '' : 'none'; });
  $('[data-sub]').style.display = '';
  // chọn hồ sơ trùng
  const cardOf = (r, i, role) => '<label data-keep="' + i + '" style="cursor:' + (picked ? 'pointer' : 'default') + ';border:' + (picked && i === keep ? '2px solid var(--action-primary-bg)' : '1px solid var(--divider)') + ';border-radius:var(--radius-md);padding:var(--space-3);display:flex;flex-direction:column;gap:6px;background:' + (picked && i === keep ? 'var(--brand-50)' : 'var(--bg-surface)') + '">'
    + '<span style="display:flex;align-items:center;gap:8px">' + (picked ? '<input type="radio" name="ix-keep" style="accent-color:var(--action-primary-bg)" ' + (i === keep ? 'checked' : '') + '>' : '') + '<b class="hmt-code" style="color:inherit">' + r.code + '</b><b>' + r.name + '</b>' + (picked ? (i === keep ? '<span class="hmt-tag hmt-tag-brand" style="margin-left:auto">Giữ lại</span>' : '<span class="hmt-tag" style="margin-left:auto">Gộp vào bản giữ lại</span>') : '<span class="hmt-tag" style="margin-left:auto">Đang mở</span>') + '</span>'
    + r.kv.map(x => '<span style="display:flex;gap:8px;font-size:13px"><span class="hmt-help" style="width:120px;flex:0 0 120px">' + x[0] + '</span><span>' + (x[0] === 'Cơ sở' && xb && r.cs === 'CS2' ? 'CS2 Đỗ Quang' : x[1]) + '</span></span>').join('') + '</label>';
  const recs = [m.rec[0], xb ? Object.assign({}, m.rec[1], { code: mode === 'ph' ? 'PH000081' : m.rec[1].code, cs: 'CS2', kv: m.rec[1].kv.map(x => x[0] === 'Cơ sở' ? ['Cơ sở', 'CS2 Đỗ Quang'] : x) }) : m.rec[1]];
  if (!picked) {
    $('[data-pick]').innerHTML = '<div style="display:flex;flex-direction:column;gap:8px"><span class="hmt-cap">HỒ SƠ ĐANG MỞ</span>' + cardOf(m.rec[0], 0).replace('data-keep="0"', 'data-keep="x"') + '<div class="hmt-field" style="min-width:0"><label>Hồ sơ trùng cần gộp vào <span class="hmt-req">*</span></label><input class="hmt-input" aria-label="Tìm hồ sơ trùng" placeholder="Tìm theo tên, SĐT, ' + (mode === 'ph' ? 'mã PH' : 'mã HS') + ', mã cũ…"></div>'
      + '<span class="hmt-cap">GỢI Ý TRÙNG</span>' + m.sugg.map(s => '<button type="button" class="hmt-opt" data-sugg="' + s[0] + '" style="display:flex;align-items:center;gap:10px;border:1px solid var(--divider);border-radius:var(--radius-md);padding:8px 12px;text-align:left"><b class="hmt-code" style="color:inherit">' + s[0] + '</b><b>' + s[1] + '</b><span class="hmt-help">' + s[2] + '</span><span class="hmt-tag" style="margin-left:auto">' + s[3] + '</span></button>').join('') + '</div>';
    $('[data-cards]').innerHTML = ''; $('[data-move]').style.display = 'none'; $('[data-block]').innerHTML = ''; $('[data-note]').textContent = 'Chọn hồ sơ trùng để xem sẽ chuyển những gì. Chưa chọn thì chưa gộp được.';
    $('[data-cft]').innerHTML = 'Tôi xác nhận: <b>Gộp không hoàn tác được</b>'; const cf0 = $('[data-cf]'); cf0.disabled = true; cf0.checked = false; $('[data-merge]').disabled = true; $('[data-merge]').textContent = 'Gộp'; $('[data-xb]').innerHTML = ''; return;
  }
  $('[data-pick]').innerHTML = '';
  $('[data-cards]').innerHTML = recs.map((r, i) => cardOf(r, i)).join('');
  k = recs[keep]; o = recs[1 - keep];
  const mv = o.move || {}; const keys = Object.keys(mv);
  $('[data-move]').style.display = 'flex';
  if (tai) {
    $('[data-move]').innerHTML = SKC + '<b style="font-size:13px">Đang kiểm tra xung đột và đếm dữ liệu sẽ chuyển…</b>' + [200, 320, 260, 340].map(w => '<span style="display:block">' + sk(w + 'px', 12) + '</span>').join('');
    $('[data-block]').innerHTML = ''; $('[data-note]').textContent = 'Vui lòng đợi, chưa bấm Gộp được.'; $('[data-cft]').innerHTML = 'Tôi xác nhận: <b>Gộp không hoàn tác được</b>'; const cf1 = $('[data-cf]'); cf1.disabled = true; cf1.checked = false; $('[data-merge]').disabled = true; $('[data-merge]').textContent = 'Gộp'; $('[data-xb]').innerHTML = ''; return;
  }
  $('[data-move]').innerHTML = '<b style="font-size:13px">Chuyển từ ' + o.code + ' sang ' + k.code + '</b>' + (keys.length ? keys.map(t => '<span class="hmt-cap" style="margin-top:4px">' + t + ' (' + mv[t].length + ')</span>' + mv[t].map(a => '<span style="font-size:13px">• ' + a + '</span>').join('')).join('') : '<span class="hmt-help">Hồ sơ ' + o.code + ' không có dữ liệu để chuyển. Hồ sơ giữ lại ' + k.code + ' vẫn đủ thông tin.</span>');
  const conflicts = chan ? m.conf : [];
  const blocked = conflicts.length > 0 || xb;
  $('[data-block]').innerHTML = conflicts.length ? '<div class="hmt-alert hmt-alert-danger" role="alert">' + ALERT + '<div style="display:flex;flex-direction:column;gap:4px"><b>Không gộp được: còn ' + conflicts.length + ' chỗ vướng.</b>' + conflicts.map(c => '<span style="font-size:13px">• ' + c + ' <a href="#" data-goto="Mở lớp (phân hệ Đào tạo, làm sau).">Mở lớp</a></span>').join('') + '<span style="font-size:13px">Xử lý chỗ vướng (đổi lịch hoặc chuyển lớp) rồi gộp lại.</span></div></div>' : '';
  $('[data-move]').style.opacity = blocked ? '.5' : '';
  $('[data-note]').textContent = 'Thông tin của ' + k.code + ' được giữ nguyên. ' + o.code + ' chuyển sang trạng thái “Đã gộp”: chỉ đọc, có dòng “Đã gộp vào ' + k.code + '”, ẩn khỏi danh sách mặc định, vẫn tìm được bằng mã cũ và mã ' + o.code + '. Việc gộp ghi vào lịch sử của cả hai hồ sơ, kèm tên người gộp (Trần Thu Hà) và thời điểm.';
  $('[data-cft]').innerHTML = 'Tôi xác nhận: <b>Gộp không hoàn tác được</b>. Sau khi gộp, ' + o.code + ' không tách lại được.';
  $('[data-merge]').textContent = 'Gộp vào ' + k.code; const cf = $('[data-cf]'); cf.disabled = blocked; if (blocked) cf.checked = false; $('[data-merge]').disabled = blocked || !cf.checked;
  $('[data-xb]').innerHTML = xb ? LOCK + XBN : '';
  if (xb) { $('[data-merge]').title = XBN; $('[data-merge]').setAttribute('aria-disabled', 'true'); }
}
const SRCH = '%(search)s';
render();
OV.addEventListener('change', ev => { if (ev.target.matches && ev.target.matches('[data-cf]')) render(); });
OV.addEventListener('click', ev => { ev.stopPropagation(); const t = ev.target;
  if (t.closest('[data-cf]')) { setTimeout(render, 0); return; }
  const md = t.closest('[data-mode]'); if (md) { mode = md.getAttribute('data-mode'); keep = 0; $('[data-cf]').checked = false; render(); return; }
  const sg = t.closest('[data-sugg]'); if (sg) { picked = true; keep = 0; $('[data-cf]').checked = false; render(); return; }
  const kp = t.closest('[data-keep]'); if (kp && picked) { ev.preventDefault(); keep = +kp.getAttribute('data-keep'); $('[data-cf]').checked = false; render(); return; }
  const ga = t.closest('[data-goto]'); if (ga) { ev.preventDefault(); toast(ga.getAttribute('data-goto')); return; }
  if (t.closest('[aria-label="Đóng"]')) { show(false); return; }
  const b = t.closest('.hmt-dialog-f button'); if (!b) return;
  if (b.textContent.trim() === 'Huỷ') { show(false); toast('Đã đóng. Bấm Gộp ở bản ghi để mở lại.'); return; }
  if (b.disabled || b.getAttribute('aria-disabled') === 'true') { if (b.title) toast(b.title); return; }
  const m = D[mode], r1 = m.rec[keep], o = m.rec[1 - keep]; const mv = o.move || {}; const parts = Object.keys(mv).map(t => mv[t].length + ' ' + t.toLowerCase());
  show(false); toast('Đã gộp ' + o.code + ' vào ' + r1.code + (parts.length ? ': chuyển ' + parts.join(', ') : '') + '. ' + o.code + ' chuyển sang “Đã gộp” (chỉ đọc, vẫn tìm được bằng mã). Lịch sử ghi tên người gộp.'); });
ROOT.addEventListener('click', ev => { const b = ev.target.closest && ev.target.closest('button[data-act="merge"]'); if (b && !OV.contains(b)) { ev.stopPropagation(); picked = (CASE !== 'trong'); keep = 0; $('[data-cf]').checked = false; render(); show(true); } }, true);
"""

def build(src, case, mode, title, tog):
    s = read(src)
    js = ("const HTML = " + json.dumps(HTML, ensure_ascii=False) + ";\n" + JS) % {
        'data': json.dumps(DATA, ensure_ascii=False), 'case': case, 'mode': mode, 'tog': 'true' if tog else 'false',
        'lock': SVG(IC['lock']).replace("'", "\\'"), 'alert': SVG(IC['alert']).replace("'", "\\'"), 'skcss': SK_CSS.replace("'", "\\'"), 'search': SVG(IC['search']).replace("'", "\\'")}
    return inject(s, title, js)

if __name__ == '__main__':
    # chặn: HS000141 đã xếp lớp T9C2 trùng giờ
    boards = [
        ('KH07', 'KH02', 'normal', 'ph', 'KH-07 · Gộp trùng · phụ huynh / học sinh (chọn được hai loại)', True),
        ('KH07_trong', 'KH02', 'trong', 'ph', 'KH-07 · Gộp trùng · chưa chọn hồ sơ trùng', False),
        ('KH07_tai', 'KH02', 'tai', 'ph', 'KH-07 · Gộp trùng · đang kiểm tra xung đột', False),
        ('KH07_hs', 'KH05', 'normal', 'hs', 'KH-07 · Gộp trùng · học sinh', False),
        ('KH07_chan', 'KH05', 'chan', 'hs', 'KH-07 · Gộp trùng · bị chặn: học sinh cùng đang học hai lớp trùng giờ', False),
        ('KH07_khac_co_so', 'KH02', 'xb', 'ph', 'KH-07 · Gộp trùng · hai hồ sơ khác cơ sở (không phải Admin)', False),
    ]
    for n, src, case, mode, title, tog in boards:
        write(n + '.dc.html', build(src + '.dc.html', case, mode, title, tog))
    print(' '.join(b[0] for b in boards))
