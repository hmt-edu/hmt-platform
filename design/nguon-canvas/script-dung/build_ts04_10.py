# Sinh TS-04 (Nhập lead từ file, nền TS-01, hộp K4b 3 bước) và TS-10 (Gộp lead/cơ hội trùng, nền TS-02)
import re, json
P='live15/project/'
ANCHOR="if (CFG.init) CFG.init(X());"
def inject(base, title, html, js):
    s=open(P+base).read()
    assert s.count(ANCHOR)==1
    s=s.replace(ANCHOR, "// ===== màn " + title + " =====\n(function () {\nconst HTML = " + json.dumps(html, ensure_ascii=False) + ";\n" + js + "\n})();\n" + ANCHOR)
    s=re.sub(r'<title>[^<]*</title>','<title>'+title+'</title>',s,count=1)
    return s
OVJS = r"""
const OV = document.createElement('div'); OV.className = 'ix-ov'; OV.style.cssText = 'position:absolute;inset:0;z-index:150;display:flex;align-items:center;justify-content:center;background:rgba(33,28,22,.32)';
OV.innerHTML = HTML; ROOT.appendChild(OV);
const APP = q('.hmt-app'); const show = on => { OV.style.display = on ? 'flex' : 'none'; if (APP) APP.style.filter = on ? 'blur(1.5px)' : ''; }; show(true);
['input', 'change', 'keydown', 'mousedown'].forEach(t => OV.addEventListener(t, ev => ev.stopPropagation()));
const $ = (s, r) => (r || OV).querySelector(s), $$ = (s, r) => Array.from((r || OV).querySelectorAll(s));
function menu(anchor, items, pick) { $$('.ix-ovm').forEach(m => m.remove()); const m = document.createElement('div'); m.className = 'hmt-menu ix-ovm'; m.setAttribute('role', 'listbox');
  m.style.cssText = 'position:absolute;z-index:5;left:0;right:0;top:calc(100% + 4px);max-height:220px;overflow:auto;padding:4px;display:flex;flex-direction:column';
  items.forEach(t => { const b = document.createElement('button'); b.type = 'button'; b.className = 'hmt-opt'; b.textContent = t; b.addEventListener('click', ev => { ev.stopPropagation(); m.remove(); pick(t); }); m.appendChild(b); });
  const h = anchor.parentElement; h.style.position = 'relative'; h.appendChild(m); }
"""
CHECK='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10" /> <path d="m9 12 2 2 4-4" /></svg>'
# ---------------- TS-04 ----------------
d1=open('k4b_d1.html').read(); d2=open('k4b_d2.html').read(); d3=open('k4b_d3.html').read()
def wide(d,i): return re.sub(r'style="width:\d+px;flex:0 0 \d+px"','style="width:720px;flex:0 0 720px;max-height:900px" data-step="%d"'%i,d,count=1)
d1=wide(d1,1).replace('<div class="hmt-drop">','<div class="hmt-drop" style="min-height:180px;justify-content:center;align-items:center;text-align:center">').replace('<a href="#">chọn file</a>','<a href="#" data-pickfile>chọn file</a>')
d1=d1.replace('<span class="hmt-help">leads-thang-10.xlsx · 128 dòng</span>','<span class="hmt-help">leads-thang-10.xlsx · 128 dòng · 8 cột</span>')
d1=d1.replace('</div></div><div class="hmt-dialog-f">','</div><span class="hmt-help">Nhận file Excel (.xlsx) hoặc CSV. Dòng đầu là tên cột.</span></div><div class="hmt-dialog-f">',1)
d2=wide(d2,2); d3=wide(d3,3).replace('<div class="hmt-table-wrap" style="max-height:330px">','<div class="hmt-table-wrap" style="max-height:420px">')
for k,lab in [('112','ok'),('9','dup'),('7','err')]:
    pass
d3=re.sub(r'<div style="flex:1;border:1px solid var\(--divider\)','<div data-cnt style="cursor:pointer;flex:1;border:1px solid var(--divider)',d3)
d3=d3.replace('<span class="hmt-help">Hiển thị 7 dòng đầu;','<span class="hmt-help">Bấm ô đếm để lọc bảng. Hiển thị 7 dòng đầu;')
TS04_JS = OVJS + r"""
let step = 1; const go = n => { step = n; $$('.hmt-dialog').forEach(d => d.style.display = +d.getAttribute('data-step') === n ? '' : 'none'); }; go(1);
const FIELDS = ['Tên phụ huynh', 'SĐT', 'Tên học sinh', 'Source', 'Sub-source', 'Chiến dịch', 'Ghi chú', 'Không nhập'];
const OKI = '""" + CHECK.replace("'", "\\'") + r"""';
function sync2() { const d = $('[data-step="2"]'); const rows = $$('tbody tr', d); const miss = rows.filter(r => $('.hmt-select span', r).classList.contains('hmt-ph')).map(r => r.cells[0].textContent.trim());
  const al = $('.hmt-alert', d); if (al) { al.style.display = miss.length ? '' : 'none'; const t = al.querySelector('div'); if (t) t.innerHTML = miss.length + ' cột chưa ghép: ' + miss.map(m => '<b>' + m + '</b>').join(', ') + '. Dữ liệu của ' + miss.length + ' cột này không được nhập vào hệ thống.'; } }
OV.addEventListener('click', ev => { ev.stopPropagation(); const t = ev.target; if (!t.closest('.ix-ovm')) $$('.ix-ovm').forEach(m => m.remove());
  if (t.closest('[data-pickfile]')) { ev.preventDefault(); toast('Chọn file từ máy (Excel hoặc CSV). Mẫu đang dùng: leads-thang-10.xlsx · 128 dòng.'); return; }
  const sel = t.closest('.hmt-select'); if (sel && step === 2) { menu(sel, FIELDS, v => { const sp = $('span', sel); sp.textContent = v; sp.classList.remove('hmt-ph'); sel.classList.remove('hmt-input-err'); const st = sel.closest('tr').cells[3];
      st.innerHTML = v === 'Không nhập' ? '<span class="hmt-tag">Không nhập</span>' : '<span style="color:var(--success-text);display:inline-flex">' + OKI + '</span>'; sync2(); }); return; }
  const cnt = t.closest('[data-cnt]'); if (cnt) { const all = $$('[data-cnt]'); const k = all.indexOf(cnt); const on = cnt.getAttribute('aria-pressed') !== 'true'; all.forEach(c => { c.setAttribute('aria-pressed', 'false'); c.style.outline = ''; }); if (on) { cnt.setAttribute('aria-pressed', 'true'); cnt.style.outline = '2px solid var(--focus-ring, #EF6926)'; }
    const cls = ['hmt-tag-success', 'hmt-tag-warning', 'hmt-tag-danger'][k]; $$('[data-step="3"] tbody tr').forEach(r => { r.style.display = !on || r.querySelector('.' + cls) ? '' : 'none'; }); return; }
  const b = t.closest('.hmt-dialog-f button'); if (!b) return; const l = b.textContent.trim();
  if (l === 'Huỷ') { show(false); toast('Đã đóng. Bấm Nhập trên thanh công cụ để mở lại.'); return; }
  if (l === 'Quay lại') { go(step - 1); return; }
  if (l === 'Tiếp') { if (step === 2) { const need = ['Tên phụ huynh', 'SĐT']; const have = $$('[data-step="2"] .hmt-select span').map(s => s.textContent.trim()); const lack = need.filter(n => have.indexOf(n) < 0); if (lack.length) { toast('Phải ghép cột cho: ' + lack.join(', ') + '.'); return; } } go(step + 1); return; }
  if (l === 'Nhập') { show(false); toast('Đã nhập 112 · Bỏ qua 9 trùng SĐT · 7 dòng lỗi'); return; } });
ROOT.addEventListener('click', ev => { const b = ev.target.closest && ev.target.closest('button'); if (b && !OV.contains(b) && b.textContent.trim() === 'Nhập' && OV.style.display === 'none') { ev.stopPropagation(); go(1); show(true); } }, true);
"""
html04='<div style="display:flex">'+d1+d2+d3+'</div>'
s=inject('TS01.dc.html','TS-04 · Nhập lead từ file',html04,TS04_JS)
open(P+'TS04.dc.html','w').write(s)
# ---------------- TS-10 ----------------
X='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18" /> <path d="m6 6 12 12" /></svg>'
html10=('<div class="hmt-dialog" role="dialog" aria-label="Gộp trùng" style="width:860px;flex:0 0 860px;max-height:920px"><div class="hmt-dialog-h"><span data-ttl>Gộp lead trùng</span><button class="hmt-iconbtn x" type="button" aria-label="Đóng">'+X+'</button></div>'
 '<div class="hmt-dialog-b" style="gap:var(--space-3);overflow:auto">'
 '<div style="display:flex;align-items:center;gap:var(--space-3)"><div class="hmt-pills" role="group" aria-label="Loại bản ghi" style="flex:0 0 auto;flex-wrap:nowrap;white-space:nowrap"><button type="button" aria-pressed="true" data-mode="lead">Lead</button><button type="button" aria-pressed="false" data-mode="opp">Cơ hội</button></div><span class="hmt-help" data-sub></span></div>'
 '<div data-cards style="display:grid;grid-template-columns:1fr 1fr;gap:var(--space-3)"></div>'
 '<div data-move style="border:1px solid var(--divider);border-radius:var(--radius-md);padding:var(--space-3);display:flex;flex-direction:column;gap:6px"></div>'
 '<div data-block></div><span class="hmt-help" data-note></span>'
 '<label style="display:flex;gap:8px;align-items:flex-start;font-size:14px;cursor:pointer"><input type="checkbox" data-cf style="margin-top:3px;accent-color:var(--action-primary-bg)"> <span>Tôi xác nhận: <b>Gộp không hoàn tác được</b></span></label></div>'
 '<div class="hmt-dialog-f"><button class="hmt-btn " type="button">Huỷ</button><button class="hmt-btn hmt-btn-primary" type="button" data-merge>Gộp</button></div></div>')
TS10_JS = OVJS + r"""
const D = {
 lead: { ttl: 'Gộp lead trùng', sub: 'Hai lead cùng SĐT 0912 000 121. Chọn bản giữ lại; lịch hẹn và ghi chú của bản kia chuyển sang bản giữ lại.', noun: 'lead',
  rec: [ { code: 'LD000227', name: 'Chị Lê Thu Hằng', kv: [['SĐT', '0912 000 121'], ['Học sinh', 'Lê Gia Huy'], ['Source', 'Facebook Ads · Lead Form'], ['Sale phụ trách', 'Trần Thu Hà'], ['Cơ sở', 'CS1'], ['Ngày tạo', '08/10/2026'], ['Cơ hội', '1 (CO000121)']],
          appts: ['Gọi điện · Gọi lại hỏi lịch học · 11/10/2026 09:00 · Chưa làm', 'Email · Gửi báo giá lớp Toán 9 · 13/10/2026 14:00 · Chưa làm'], notes: ['Trần Thu Hà · 13/10 10:04 · “Chị Hằng muốn con học tối T3, T5; hỏi có học thử được không.”'], pkts: [], quotes: [] },
        { code: 'LD000241', name: 'Lê Thu Hằng', kv: [['SĐT', '0912 000 121'], ['Học sinh', '—'], ['Source', 'Zalo'], ['Sale phụ trách', 'Trần Thu Hà'], ['Cơ sở', 'CS2'], ['Ngày tạo', '14/10/2026'], ['Cơ hội', '0']],
          appts: ['Gọi điện · Gọi tư vấn lớp Toán 9 · 15/10/2026 09:00 · Chưa làm'], notes: ['Nguyễn Văn Nam · 14/10 16:20 · “PH nhắn Zalo hỏi học phí lớp 9.”', 'Nguyễn Văn Nam · 14/10 16:25 · “Hẹn gọi lại sáng thứ 5.”'], pkts: [], quotes: [] } ] },
 opp: { ttl: 'Gộp cơ hội trùng', sub: 'Hai cơ hội của lead LD000227 cùng học sinh Lê Gia Huy, cùng môn Toán lớp 9. Chọn bản giữ lại; lịch hẹn và ghi chú của bản kia chuyển sang bản giữ lại.', noun: 'cơ hội',
  rec: [ { code: 'CO000121', name: 'Toán lớp 9 · Lê Gia Huy', kv: [['Giai đoạn', 'L6 Đã tham gia test · L6A'], ['Sale phụ trách', 'Trần Thu Hà'], ['Cơ sở', 'CS1'], ['Source', 'Facebook Ads · Lead Form'], ['Ngày tạo', '08/10/2026'], ['Kiểm tra', '1 (PKT000105 Hoàn thành)']],
          appts: ['Gọi điện · Gọi lại hỏi lịch học · 11/10/2026 09:00 · Chưa làm', 'Email · Gửi báo giá lớp Toán 9 · 13/10/2026 14:00 · Chưa làm'], notes: ['Trần Thu Hà · 13/10 10:04 · “Chị Hằng muốn con học tối T3, T5.”'], pkts: ['PKT000105 · Hoàn thành · 12/10/2026 18:30 · điểm 7,5/10'], quotes: [] },
        { code: 'CO000136', name: 'Toán lớp 9 · Lê Gia Huy', kv: [['Giai đoạn', 'L4 Khách hàng tiềm năng'], ['Sale phụ trách', 'Lê Mai Anh'], ['Cơ sở', 'CS5'], ['Source', 'Hotline'], ['Ngày tạo', '15/10/2026'], ['Kiểm tra', '0'], ['Báo giá · đơn hàng', 'BG000045 (Nháp)']],
          appts: ['Gọi điện · Gọi xác nhận nhu cầu · 16/10/2026 10:00 · Chưa làm'], notes: ['Lê Mai Anh · 15/10 11:02 · “PH gọi hotline hỏi lớp Toán 9 buổi tối.”'], pkts: [], quotes: ['BG000045 (báo giá, Nháp)'] } ] } };
let mode = 'lead', keep = 0;
function render() { const m = D[mode], k = m.rec[keep], o = m.rec[1 - keep];
  $('[data-ttl]').textContent = m.ttl; $('[data-sub]').textContent = m.sub;
  $$('[data-mode]').forEach(b => b.setAttribute('aria-pressed', b.getAttribute('data-mode') === mode ? 'true' : 'false'));
  $('[data-cards]').innerHTML = m.rec.map((r, i) => '<label data-keep="' + i + '" style="cursor:pointer;border:' + (i === keep ? '2px solid var(--action-primary-bg)' : '1px solid var(--divider)') + ';border-radius:var(--radius-md);padding:var(--space-3);display:flex;flex-direction:column;gap:6px;background:' + (i === keep ? 'var(--brand-50)' : 'var(--bg-surface)') + '">'
    + '<span style="display:flex;align-items:center;gap:8px"><input type="radio" name="ix-keep" style="accent-color:var(--action-primary-bg)" ' + (i === keep ? 'checked' : '') + '><b class="hmt-code" style="color:inherit">' + r.code + '</b><b>' + r.name + '</b>' + (i === keep ? '<span class="hmt-tag hmt-tag-brand" style="margin-left:auto">Giữ lại</span>' : '<span class="hmt-tag" style="margin-left:auto">Gộp vào bản giữ lại</span>') + '</span>'
    + r.kv.map(x => '<span style="display:flex;gap:8px;font-size:13px"><span class="hmt-help" style="width:110px;flex:0 0 110px">' + x[0] + '</span><span>' + x[1] + '</span></span>').join('')
    + '<span style="display:flex;gap:8px;font-size:13px"><span class="hmt-help" style="width:110px;flex:0 0 110px">Lịch hẹn · ghi chú</span><span>' + r.appts.length + ' lịch hẹn · ' + r.notes.length + ' ghi chú</span></span></label>').join('');
  $('[data-move]').innerHTML = '<b style="font-size:13px">Chuyển từ ' + o.code + ' sang ' + k.code + '</b>'
    + '<span class="hmt-cap" style="margin-top:4px">LỊCH HẸN (' + o.appts.length + ')</span>' + o.appts.map(a => '<span style="font-size:13px">• ' + a + '</span>').join('')
    + '<span class="hmt-cap" style="margin-top:4px">GHI CHÚ (' + o.notes.length + ')</span>' + o.notes.map(a => '<span style="font-size:13px">• ' + a + '</span>').join('')
    + (o.pkts.length ? '<span class="hmt-cap" style="margin-top:4px">PHIẾU KIỂM TRA (' + o.pkts.length + ')</span>' + o.pkts.map(a => '<span style="font-size:13px">• ' + a + '</span>').join('') : '');
  const blocked = mode === 'opp' && o.quotes.length > 0;
  $('[data-block]').innerHTML = blocked ? '<div class="hmt-alert hmt-alert-danger" role="alert"><span><b>Không gộp được: ' + o.code + ' đã có ' + o.quotes.join(', ') + '.</b> Chỉ gộp được cơ hội chưa có báo giá hoặc đơn hàng. Chọn ' + o.code + ' làm bản giữ lại, hoặc xử lý báo giá/đơn hàng trước.</span></div>' : '';
  $('[data-move]').style.opacity = blocked ? '.5' : '';
  $('[data-note]').textContent = 'Thông tin của ' + k.code + ' được giữ nguyên. ' + o.code + ' chuyển sang trạng thái “Đã gộp”: chỉ đọc, có dòng “Đã gộp vào ' + k.code + '”, ẩn khỏi danh sách mặc định, vẫn tìm được bằng mã. Việc gộp ghi vào lịch sử của cả hai bản.';
  $('[data-merge]').textContent = 'Gộp vào ' + k.code; const cf = $('[data-cf]'); cf.disabled = blocked; if (blocked) cf.checked = false; $('[data-merge]').disabled = blocked || !cf.checked; }
render();
OV.addEventListener('change', ev => { if (ev.target.matches && ev.target.matches('[data-cf]')) render(); });
OV.addEventListener('click', ev => { ev.stopPropagation(); const t = ev.target;
  if (t.closest('[data-cf]')) { setTimeout(render, 0); return; }
  const md = t.closest('[data-mode]'); if (md) { mode = md.getAttribute('data-mode'); keep = 0; $('[data-cf]').checked = false; render(); return; }
  const kp = t.closest('[data-keep]'); if (kp) { ev.preventDefault(); keep = +kp.getAttribute('data-keep'); $('[data-cf]').checked = false; render(); return; }
  if (t.closest('[aria-label="Đóng"]')) { show(false); return; }
  const b = t.closest('.hmt-dialog-f button'); if (!b) return;
  if (b.textContent.trim() === 'Huỷ') { show(false); toast('Đã đóng. Hành động → Gộp trùng để mở lại.'); return; }
  if (b.disabled) return; const m = D[mode], k = m.rec[keep], o = m.rec[1 - keep]; show(false); toast('Đã gộp ' + o.code + ' vào ' + k.code + ': chuyển ' + o.appts.length + ' lịch hẹn, ' + o.notes.length + ' ghi chú' + (o.pkts.length ? ', ' + o.pkts.length + ' phiếu kiểm tra' : '') + '. ' + o.code + ' chuyển sang “Đã gộp” (xem TS-10b).'); });
ROOT.addEventListener('click', ev => { const b = ev.target.closest && ev.target.closest('button'); if (b && !OV.contains(b) && b.textContent.trim() === 'Gộp trùng') { ev.stopPropagation(); const mm = b.closest('.hmt-menu'); if (mm) mm.style.display = 'none'; mode = 'lead'; keep = 0; render(); show(true); } }, true);
"""

NOTE_OLD="Việc gộp ghi vào lịch sử của cả hai bản.'"
NOTE_NEW="Việc gộp ghi vào lịch sử của cả hai bản, kèm tên người gộp.'"
assert NOTE_OLD in TS10_JS
TS10_JS=TS10_JS.replace(NOTE_OLD,NOTE_NEW)
# TS-10: hai hồ sơ cùng cơ sở CS1 (người dùng không phải Admin chỉ gộp được hồ sơ cùng cơ sở)
J1=TS10_JS.replace("['Cơ sở', 'CS2'], ['Ngày tạo', '14/10/2026'], ['Cơ hội', '0']","['Cơ sở', 'CS1'], ['Ngày tạo', '14/10/2026'], ['Cơ hội', '0']").replace("['Cơ sở', 'CS5'], ['Source', 'Hotline']","['Cơ sở', 'CS1'], ['Source', 'Hotline']")
assert J1.count("'CS2'")==0 and J1.count("'CS5'")==0
s=inject('TS02.dc.html','TS-10 · Gộp lead / cơ hội trùng',html10,J1)
open(P+'TS10.dc.html','w').write(s)
# TS-10c: hai hồ sơ khác cơ sở, người dùng không phải Admin: nút Gộp mờ + chú thích
XB=r"""
const XBNOTE = 'Chỉ Admin gộp được hồ sơ của hai cơ sở khác nhau';
const _render = render;
render = function () { _render(); const m = D[mode], k = m.rec[keep], o = m.rec[1 - keep]; const diff = k.kv.some(x => x[0] === 'Cơ sở') && (k.kv.filter(x => x[0] === 'Cơ sở')[0][1] !== o.kv.filter(x => x[0] === 'Cơ sở')[0][1]);
  const f = $('.hmt-dialog-f'); let n = $('[data-xb]'); if (!n) { n = document.createElement('span'); n.setAttribute('data-xb', '1'); n.className = 'hmt-help'; n.style.cssText = 'margin-right:auto;display:flex;align-items:center;gap:6px;color:var(--text-primary)'; f.insertBefore(n, f.firstChild); }
  n.innerHTML = diff ? '<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><rect width="18" height="11" x="3" y="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" /></svg>' + XBNOTE : '';
  const cf = $('[data-cf]'), mg = $('[data-merge]'); if (diff) { cf.disabled = true; cf.checked = false; mg.disabled = true; mg.title = XBNOTE; $('[data-move]').style.opacity = '.5'; } else { mg.removeAttribute('title'); } };
render();
"""
# trong TS10_JS gốc, "function render()" là khai báo hàm; đổi thành biến để ghi đè
JX=TS10_JS.replace("function render() {","let render = function () {",1)
JX=JX.replace("\nrender();\nOV.addEventListener('change'","\nrender();\nOV.addEventListener('change'",1)
# chèn XB sau lần render() đầu tiên
idx=JX.index("\nrender();\nOV.addEventListener('change'")
JX=JX[:idx]+"\n"+XB+JX[idx+len("\nrender();"):]
JX=JX.replace("<span data-ttl>Gộp lead trùng</span>","<span data-ttl>Gộp lead trùng</span>")
s=inject('TS02.dc.html','TS-10c · Gộp trùng: hai hồ sơ khác cơ sở (không phải Admin)',html10,JX)
open(P+'TS10c.dc.html','w').write(s)
print('ok')

# ---------------- TS-10b: bản ghi ở trạng thái "Đã gộp" (LD000241) ----------------
J10B = r"""
const KV = { 'Họ tên': 'Lê Thu Hằng', 'Số điện thoại': '0912 000 121', 'Phường/Xã': '—', 'Tỉnh/Thành phố': 'Hà Nội', 'Địa chỉ': '—', 'Nhu cầu': 'Hỏi học phí lớp 9 (qua Zalo)', 'Tên học sinh': '—', 'Ngày sinh': '—', 'Năm sinh': '—', 'Trường học': '—', 'Học lực tự đánh giá': '—', 'Mục tiêu': '—', 'Cơ sở': 'CS1 Nguyễn Chí Thanh', 'Nhân sự phụ trách': 'Trần Thu Hà', 'Nhân sự hỗ trợ': '—', 'Source': 'Zalo', 'Sub-source': '—', 'Chiến dịch': '—' };
function apply() {
  const walk = (n) => { if (n.nodeType === 3) { if (/Chị Lê Thu Hằng · Lê Gia Huy/.test(n.nodeValue)) n.nodeValue = n.nodeValue.replace('Chị Lê Thu Hằng · Lê Gia Huy', 'Lê Thu Hằng · LD000241'); } else n.childNodes.forEach(walk); };
  walk(ROOT);
  qa('.hmt-sheet .hmt-kv').forEach(k => { const dt = tx(q('dt', k)); if (KV[dt] !== undefined) q('dd', k).textContent = KV[dt]; });
  const rb = q('.hmt-rbar-l'); if (rb && !rb._m) { rb._m = 1; qa(':scope > button, :scope > .push-r, :scope > .hmt-menu', rb).forEach(e => e.style.display = 'none'); rb.insertAdjacentHTML('beforeend', '<span class="hmt-tag" style="background:var(--bg-subtle);border:1px solid var(--divider)">Đã gộp · chỉ đọc</span>'); }
  const L = qa('.hmt-left > .hmt-box');
  if (L[0] && !L[0]._m) { L[0]._m = 1; L[0].insertAdjacentHTML('beforebegin', '<div class="hmt-alert" role="status" style="background:var(--bg-subtle);border:1px solid var(--divider);color:var(--text-primary)"><svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="M8 3v18" /><path d="M16 3v6a4 4 0 0 1-4 4H8" /></svg><div style="display:flex;flex-direction:column;gap:4px"><b>Đã gộp vào <a href="#" data-goto>LD000227 · Chị Lê Thu Hằng</a></b><span style="font-size:13px">Trần Thu Hà gộp lúc 16/10/2026 21:50. Bản ghi chỉ đọc; lịch hẹn và ghi chú đã chuyển sang LD000227. Không hiện trong danh sách mặc định, vẫn tìm được bằng mã LD000241.</span></div></div>');
    qa('.hmt-step', L[0]).forEach(b => { b.classList.add('hmt-step-past'); b.style.cursor = 'default'; b.removeAttribute('aria-current'); }); L[0].style.opacity = '.6'; }
  if (L[1]) L[1].style.display = 'none';
  if (L[2]) qa('.hmt-sbtn b', L[2]).forEach(b => b.textContent = '0');
  const ch = q('.hmt-chatter'); if (ch && !ch._m) { ch._m = 1; const kids = Array.from(ch.children); if (kids[1]) kids[1].style.display = 'none'; if (kids[2]) kids[2].style.display = 'none';
    if (kids[3]) kids[3].innerHTML = '<div class="hmt-cap" style="padding:var(--space-3) var(--space-4) 0">HOẠT ĐỘNG SẮP TỚI (0)</div><div class="hmt-help" style="padding:var(--space-2) var(--space-4) var(--space-3)">Không còn hoạt động. Lịch hẹn đã chuyển sang LD000227.</div>';
    qa('.hmt-msg, .hmt-day', ch).forEach(e => e.style.display = 'none');
    const tl = kids[4]; if (tl) tl.insertAdjacentHTML('afterend', '<div class="hmt-day">16/10/2026</div><div class="hmt-msg"><span class="hmt-avatar hmt-avatar-lg hmt-avatar-sys">HT</span><div class="hmt-msg-b"><span class="hmt-meta"><b>Hệ thống</b> · <span class="hmt-num">21:50</span> · Hệ thống</span><span>Trần Thu Hà gộp LD000241 vào LD000227. Chuyển 1 lịch hẹn, 2 ghi chú. Trạng thái: <b>Đã gộp</b> (không hoàn tác).</span></div></div><div class="hmt-day">14/10/2026</div><div class="hmt-msg"><span class="hmt-avatar hmt-avatar-lg hmt-avatar-sys">HT</span><div class="hmt-msg-b"><span class="hmt-meta"><b>Hệ thống</b> · <span class="hmt-num">16:10</span> · Hệ thống</span><span>Tạo lead từ Zalo. Sale phụ trách: Trần Thu Hà · CS1</span></div></div>'); }
}
apply(); [80, 300, 800, 1500].forEach(ms => setTimeout(apply, ms));
ROOT.addEventListener('click', ev => { const a = ev.target.closest && ev.target.closest('[data-goto]'); if (a) { ev.preventDefault(); ev.stopPropagation(); toast('Mở LD000227 (bản giữ lại, TS-02).'); } }, true);
"""
s=inject('TS02.dc.html','TS-10b · Lead ở trạng thái Đã gộp',"",J10B)
open(P+'TS10b.dc.html','w').write(s)
print('ok 10b')
