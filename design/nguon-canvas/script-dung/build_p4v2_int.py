# -*- coding: utf-8 -*-
# Làm các màn hồ sơ bấm được: tab, nút, bộ lọc, ghi chú, Sửa/Lưu, hộp Gộp
import sys, json, re
sys.path.insert(0, 'scripts')
import build_p4v2_rec as R
import build_p4v2_merge as M
from kh_common import remove_div, SVG, IC

KEY = '<div style="padding-top:var(--space-3);display:flex;flex-direction:column;gap:16px">'
def inner(t):
    a = t.index(KEY); _, blk = remove_div(t, a); return blk[len(KEY):-6]

def panels():
    hs = {}; ph = {}
    hs['tq'] = inner(R.prep('Main', 'x'))
    hs['ht'] = inner(R.prep('HS_HocTap', 'x'))
    hs['ht_mo'] = R.dim_panel([('Lớp', 0), ('Giáo viên', 0), ('Lịch học', 0), ('Start Date', 0), ('End Date', 0), ('Tình trạng', 0), ('Giờ đăng ký', 1), ('Đã học', 1), ('Còn lại', 1)])
    hs['dkt'] = inner(R.cut_block(R.prep('HS_DiemKiemTra', 'x'), 'ĐIỂM THEO THÁNG'))
    hs['cs'] = inner(R.prep('HS_ChamSoc', 'x'))
    hs['dn'] = inner(R.prep('HS_KhieuNai', 'x'))
    hs['ct'] = inner(R.prep('HS_DiemDanhChiTiet', 'x'))
    hs['dd'] = inner(R.prep('HS_DiemDanh', 'x'))
    hs['dd_mo'] = R.dim_panel([('Lớp', 0), ('Buổi đã học', 1), ('Có mặt', 1), ('Muộn', 1), ('Vắng phép', 1), ('Vắng KP', 1), ('Chuyên cần', 1)])
    hs['dkt_mo'] = R.dim_panel([('Bài kiểm tra', 0), ('Ngày', 0), ('Môn', 0), ('Điểm', 1), ('Thang', 1), ('Nhận xét', 0)])
    hs['cs_mo'] = R.dim_panel([('Ticket', 0), ('Loại', 0), ('Hạn', 0), ('Người phụ trách', 0), ('Trạng thái', 0)])
    hs['dn_mo'] = R.dim_panel([('Mã', 0), ('Loại', 0), ('Tiêu đề', 0), ('Hạn xử lý', 0), ('Trạng thái', 0)])
    # chế độ Sửa
    tHS = R.edit_mode(R.prep('Main', 'x'), R.HS_FIELDS, None, 'Học sinh'); hs['edit'] = inner(tHS)
    t = R.prep('PH_TongQuan', 'x', obj='Phụ huynh'); ph['tq'] = inner(t)
    ph['cc'] = R.CHILD_HTML.replace('<div class="hmt-csec-t" style="padding:var(--space-2) 0 var(--space-1)">CÁC CON</div>', '')
    ph['tc'] = inner(R.prep('PH_TaiChinh', 'x', obj='Phụ huynh'))
    ph['tc_mo'] = R.dim_panel([('Ghi danh', 0), ('Con', 0), ('Gói', 0), ('Giờ', 1), ('Thành tiền', 1), ('Trạng thái', 0)])
    ph['edit'] = inner(R.edit_mode(R.prep('PH_TongQuan', 'x', obj='Phụ huynh'), R.PH_FIELDS, None, 'Phụ huynh'))
    return hs, ph

INT_JS = r"""
const PN = %(panels)s; const KIND = '%(kind)s'; const STAGE = '%(stage)s';
const CONT = q('.hmt-sheet > div > div[style*="padding-top"]');
const TABMAP = KIND === 'hs'
  ? { 'Tổng quan': 'tq', 'Học tập': STAGE === 's1' ? 'ht_mo' : 'ht', 'Điểm danh': STAGE === 's1' ? 'dd_mo' : 'dd', 'Điểm kiểm tra': STAGE === 's1' ? 'dkt_mo' : 'dkt', 'Chăm sóc': STAGE === 's1' ? 'cs_mo' : 'cs', 'Đề nghị & khiếu nại': STAGE === 's1' ? 'dn_mo' : 'dn' }
  : { 'Tổng quan': 'tq', 'Các con': 'cc', 'Tài chính': STAGE === 's1' ? 'tc_mo' : 'tc' };
let editing = false; let rbarSaved = null;
{ const st = qa('.hmt-tab').find(b => b.getAttribute('aria-selected') === 'true'); if (st && CONT && TABMAP[tx0(st)]) CONT.setAttribute('data-p', TABMAP[tx0(st)]); }
const VALS = {};
function showPanel(key) { if (!CONT) return; CONT.innerHTML = PN[key]; CONT.setAttribute('data-p', key); qa('[data-val]', CONT).forEach(e => { e.value = e.getAttribute('data-val'); }); applyVals(); }
function applyVals() { qa('.hmt-kv', CONT).forEach(kv => { const dt = tx0(q('dt', kv)); if (VALS[dt] != null && !q('input,select', kv)) { const dd = q('dd', kv); if (dd && !q('a', dd)) dd.textContent = VALS[dt]; } }); }
function tx0(e) { return ((e && e.textContent) || '').replace(/[\s*]+$/, '').replace(/\s+/g, ' ').trim(); }
function selectTab(label) { qa('.hmt-tab').forEach(b => b.setAttribute('aria-selected', tx0(b).replace(/&amp;/, '&') === label ? 'true' : 'false')); }
function goTab(label) { const k = TABMAP[label]; if (!k) return; if (editing) endEdit(false); selectTab(label); showPanel(k); }
function startEdit() {
  if (editing || !CONT) return; goTab('Tổng quan'); editing = true; showPanel('edit'); const bar = q('.hmt-rbar-l'); rbarSaved = bar.innerHTML;
  const sb = q('.hmt-btn-primary', bar);
  sb.outerHTML = '<button class="hmt-btn hmt-btn-primary" type="button" data-act="save">' + CHK + 'Lưu</button><button class="hmt-btn hmt-btn-danger" type="button" data-act="cancel">' + XX + 'Huỷ</button>';
}
function endEdit(save) {
  if (!editing) return;
  if (save) {
    const reqs = qa('input[data-req]', CONT); let bad = []; reqs.forEach(i => { const v = i.value.trim(); i.classList.toggle('hmt-input-err', !v); const nx = i.nextElementSibling; if (nx && nx.classList.contains('ix-err')) nx.remove(); if (!v) { const s = document.createElement('span'); s.className = 'ix-err'; s.textContent = i.getAttribute('data-req'); i.after(s); bad.push(tx0(i.closest('.hmt-kv').querySelector('dt'))); } });
    const old = q('.ix-al', CONT); if (old) old.remove();
    if (bad.length) { const al = document.createElement('div'); al.className = 'hmt-alert hmt-alert-danger ix-al'; al.setAttribute('role', 'alert'); al.innerHTML = ALERT + '<span><b>Còn ' + bad.length + ' ô bắt buộc chưa điền:</b> ' + bad.join(', ') + '. Điền xong rồi bấm Lưu.</span>'; CONT.insertBefore(al, CONT.firstChild); return; }
    qa('.hmt-kv', CONT).forEach(kv => { const i = q('input:not([readonly]),select', kv); if (i) VALS[tx0(q('dt', kv))] = i.value; });
  }
  editing = false; q('.hmt-rbar-l').innerHTML = rbarSaved; showPanel('tq'); if (save) toast('Đã lưu. Ghi vào Ghi chú & hoạt động: "Cập nhật hồ sơ".');
}
const CHK = '%(chk)s', XX = '%(xx)s', ALERT = '%(alert)s';
const SMART = KIND === 'hs'
  ? { 'Ghi danh': ['Học tập'], 'Lớp': ['Học tập'], 'Ticket mở': ['Đề nghị & khiếu nại'], 'Khiếu nại': ['Đề nghị & khiếu nại'], 'Phiếu test': ['T', 'Mở phiếu kiểm tra đầu vào PKT000231 (phân hệ Tuyển sinh, màn TS-17).'], 'Phụ huynh': ['T', 'Mở hồ sơ phụ huynh PH000045 (màn KH-02).'] }
  : { 'Con': ['Các con'], 'Cơ hội': ['T', 'Mở cơ hội CO000133 (phân hệ Tuyển sinh, màn TS-08).'], 'Phiếu test': ['T', 'Mở phiếu kiểm tra đầu vào (phân hệ Tuyển sinh, màn TS-17).'], 'Ghi danh': ['Tài chính'], 'Ticket mở': ['T', 'Làm ở phân hệ sau'], 'Phiếu thu': ['Tài chính'] };
function filterRows(scope) {
  const groups = qa('.hmt-pills', scope).filter(g => !g.closest('.hmt-chatter'));
  const rows = qa('tbody tr', scope); if (!groups.length || !rows.length) return;
  const KW = { 'Đại số 9A': 'Đại số', 'Hình học 9B': 'Hình học', 'Khiếu nại': 'Khiếu nại', 'Đề nghị': 'Đề nghị', 'Đang mở': '(Quá hạn|Đang)', 'Đã đóng': '(Đã đóng|Hoàn thành)', 'Chỉ buổi vắng, muộn': '(Vắng|muộn)', 'Chỉ buổi có nhận xét': 'Xem nhận xét', 'BTVN chưa chấm': 'chưa xong' };
  rows.forEach(r => { let ok = true; const t = r.textContent; groups.forEach(g => { const on = q('button[aria-pressed="true"]', g); if (!on) return; const l = tx0(on); if (l === 'Tất cả' || l === 'Tất cả buổi') return; const kw = KW[l] || l; if (!new RegExp(kw).test(t)) ok = false; }); r.style.display = ok ? '' : 'none'; });
}
ROOT.addEventListener('click', ev => {
  const t = ev.target; if (t.closest('.ix-ov, .ix-ap')) return;
  const a = t.closest('[data-act]'); const act = a && a.getAttribute('data-act');
  if (act === 'edit') { ev.stopPropagation(); ev.preventDefault(); startEdit(); return; }
  if (act === 'save') { ev.stopPropagation(); ev.preventDefault(); endEdit(true); return; }
  if (act === 'cancel') { ev.stopPropagation(); ev.preventDefault(); endEdit(false); toast('Đã huỷ, chưa lưu thay đổi.'); return; }
  const tab = t.closest('.hmt-tab'); if (tab) { ev.stopPropagation(); ev.preventDefault(); goTab(tx0(tab)); return; }
  const sb = t.closest('.hmt-sbtn'); if (sb && !sb.hasAttribute('data-later')) { const lab = tx0(sb.querySelector('span > span')); const m = SMART[lab]; ev.stopPropagation(); ev.preventDefault(); if (!m) { toast('Mở ' + lab.toLowerCase() + ' liên quan.'); return; } if (m[0] === 'T') toast(m[1]); else goTab(m[0]); return; }
  const gc = t.closest('[data-go-ct]'); if (gc) { ev.stopPropagation(); showPanel('ct'); return; }
  const ddr = CONT && CONT.getAttribute('data-p') === 'dd' && t.closest('tbody tr'); if (ddr) { ev.preventDefault(); ev.stopPropagation(); showPanel('ct'); return; }
  const back = t.closest('a'); if (back && /Quay lại tổng quan/.test(tx0(back))) { ev.preventDefault(); showPanel('dd'); return; }
  const pill = t.closest('.hmt-pills button'); if (pill) {
    const g = pill.parentElement; qa('button', g).forEach(b => b.setAttribute('aria-pressed', b === pill ? 'true' : 'false'));
    if (g.closest('.hmt-chatter')) { const l = tx0(pill); qa('.hmt-msg').forEach(m => { const meta = tx0(q('.hmt-meta', m)); m.style.display = (l === 'Tất cả' || meta.indexOf('· ' + l) > -1) ? '' : 'none'; }); }
    else filterRows(CONT);
    ev.stopPropagation(); return; }
  const btn = t.closest('button'); if (btn) {
    const lab = tx0(btn);
    if (/^Gửi ghi chú/.test(lab)) { const ta = q('.hmt-chatter textarea'); const v = ta.value.trim(); if (!v) { toast('Chưa nhập nội dung ghi chú.'); return; } const day = q('.hmt-day'); const m = document.createElement('div'); m.className = 'hmt-msg'; const u = q('.hmt-user-n b'); const av = q('.hmt-user .hmt-avatar');
      const d = new Date(); const hm = ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2);
      m.innerHTML = '<span class="hmt-avatar hmt-avatar-lg">' + (av ? av.textContent : '') + '</span><div class="hmt-msg-b"><span class="hmt-meta"><b>' + (u ? u.textContent : '') + '</b> · <span class="hmt-num">' + hm + '</span> · Ghi chú</span><div class="hmt-note"></div></div>'; q('.hmt-note', m).textContent = v; day.after(m); ta.value = ''; toast('Đã gửi ghi chú.'); ev.stopPropagation(); return; }
    if (/Theo dõi$/.test(lab) || /Đang theo dõi/.test(lab)) { const on = !/Đang theo dõi/.test(lab); btn.lastChild.textContent = on ? 'Đang theo dõi' : 'Theo dõi'; toast(on ? 'Đã bật theo dõi hồ sơ này.' : 'Đã tắt theo dõi.'); ev.stopPropagation(); return; }
    if (lab === 'Ghi nhận liên hệ') { ev.stopPropagation(); dlgContact(); return; }
    const card = btn.closest('.hmt-act');
    if (card && /^Hoàn thành$/.test(lab)) { const title = tx0(q('.hmt-act-main b', card)); const sec = card.parentElement; card.remove(); const h = q('.hmt-csec-t', sec); if (h) { const n = qa('.hmt-act', sec).length; h.textContent = 'HOẠT ĐỘNG SẮP TỚI (' + n + ')'; } toast('Đã hoàn thành: ' + title); ev.stopPropagation(); return; }
    if (card && /^Dời$/.test(lab)) { ev.stopPropagation(); dlgMove(card); return; }
    if (card && /^Huỷ$/.test(lab)) { ev.stopPropagation(); const title = tx0(q('.hmt-act-main b', card)); dlgReason('Huỷ lịch hẹn', title, ['PH báo bận', 'Không liên lạc được', 'Tạo nhầm', 'Khác'], 'Huỷ lịch hẹn', why => { const sec = card.parentElement; card.remove(); const h = q('.hmt-csec-t', sec); if (h) h.textContent = 'HOẠT ĐỘNG SẮP TỚI (' + qa('.hmt-act', sec).length + ')'; toast('Đã huỷ lịch hẹn. Lý do: ' + why); }, 'Huỷ nhầm vẫn mở lại được bất cứ lúc nào.'); return; }
    if (btn.closest('.hmt-pager')) { toast(btn.getAttribute('aria-label') === 'Bản ghi trước' ? 'Chuyển sang hồ sơ trước trong danh sách.' : 'Chuyển sang hồ sơ sau trong danh sách.'); ev.stopPropagation(); return; }
    if (btn.getAttribute('aria-label') === 'Làm mới') { toast('Đã làm mới hồ sơ.'); ev.stopPropagation(); return; }
    if (/▾$/.test(lab) && !btn.hasAttribute('data-hd')) { toast('Mở danh sách chọn "' + lab.replace(/\s*▾$/, '') + '".'); ev.stopPropagation(); return; }
  }
  const lk = t.closest('a'); if (lk && lk.getAttribute('href') === '#') { ev.preventDefault(); const l = tx0(lk);
    if (/^HS\d{6}/.test(l) || /Nguyễn (Minh Khôi|Gia Hân)/.test(l)) toast('Mở hồ sơ học sinh ' + l + ' (màn KH-05).'); else if (/Trần Thị Hà/.test(l)) toast('Mở hồ sơ phụ huynh PH000045 (màn KH-02).');
    else if (/^PKT/.test(l)) toast('Mở phiếu kiểm tra ' + l + ' (phân hệ Tuyển sinh, màn TS-17).'); else if (/^CO/.test(l)) toast('Mở cơ hội ' + l + ' (phân hệ Tuyển sinh, màn TS-08).');
    else if (/Xem nhận xét/.test(l)) toast('Mở nhận xét của giáo viên (App Giáo viên).'); else if (/^(TOAN|GD|PT-|KN-|DN-|CS-)/.test(l)) toast('Mở ' + l + ' (phân hệ khác, làm ở phân hệ sau).');
    else if (/^(Khách hàng|Phụ huynh|Học sinh)$/.test(l)) toast('Về danh sách ' + (l === 'Học sinh' ? 'học sinh (KH-04)' : l === 'Phụ huynh' ? 'phụ huynh (KH-01)' : 'khách hàng') + '.');
    else toast('Mở “' + l + '”.'); ev.stopPropagation(); return; }
}, true);
"""


DLG_JS = r"""
const SVGX = '<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18" /> <path d="m6 6 12 12" /></svg>';
function mkScrim(w, label, head, body, foot) {
  const el = document.createElement('div'); el.className = 'hmt-scrim ix-ap ix-ov2'; el.style.cssText = 'position:absolute;inset:0;z-index:140;align-items:center;padding:0;display:flex';
  el.innerHTML = '<div class="hmt-dialog" role="dialog" aria-label="' + label + '" style="width:' + w + 'px;flex:0 0 ' + w + 'px"><div class="hmt-dialog-h">' + head + '<button class="hmt-iconbtn x" type="button" aria-label="Đóng" data-a="x">' + SVGX + '</button></div><div class="hmt-dialog-b">' + body + '</div><div class="hmt-dialog-f">' + foot + '</div></div>';
  ROOT.appendChild(el); return el;
}
function fieldErr(inp, msg) { inp.classList.add('hmt-input-err'); const h = inp.closest('.hmt-field'); if (h && !q('.ix-err', h)) { const sp = document.createElement('span'); sp.className = 'ix-err'; sp.textContent = msg; h.appendChild(sp); } }
function fieldOk(inp) { inp.classList.remove('hmt-input-err'); const h = inp.closest('.hmt-field'); if (h) qa('.ix-err', h).forEach(x => x.remove()); }
function pillsOf(el) { el.addEventListener('click', ev => { const b = ev.target.closest('.hmt-pills button'); if (!b) return; qa('button', b.parentElement).forEach(x => x.setAttribute('aria-pressed', x === b ? 'true' : 'false')); }); }
function dlgReason(title, head, list, okLabel, onOk, foot) {
  const CH = '<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>';
  const body = '<div style="font-size:13px;margin-bottom:8px"><b>' + head + '</b></div><div class="hmt-field" style="min-width:0;position:relative"><label>Lý do <span class="hmt-req">*</span></label><button class="hmt-input hmt-select" type="button" data-rsel aria-haspopup="listbox"><span class="hmt-ph">Chọn lý do…</span>' + CH + '</button><div class="hmt-menu ix-rs" role="listbox" style="display:none;position:absolute;left:0;right:0;top:64px;z-index:5;max-height:240px;overflow:auto">' + list.map(r => '<button type="button" class="hmt-opt" role="option" data-r="' + r + '">' + r + '</button>').join('') + '</div></div><div class="hmt-field ix-khac" style="min-width:0;display:none;margin-top:8px"><label>Ghi chú <span class="hmt-req">*</span></label><textarea class="hmt-textarea" rows="2" placeholder="Ghi rõ lý do"></textarea><span class="hmt-help">Bắt buộc khi chọn “Khác”.</span></div>' + (foot ? '<div class="hmt-help" style="margin-top:8px">' + foot + '</div>' : '');
  const el = mkScrim(480, title, title, body, '<button class="hmt-btn" type="button" data-a="x">Đóng</button><button class="hmt-btn hmt-btn-danger" type="button" data-a="ok" disabled>' + okLabel + '</button>');
  let pick = ''; const ta = q('textarea', el), okb = q('button[data-a=ok]', el), kh = q('.ix-khac', el); const isK = () => /khác/i.test(pick);
  const sync = () => { okb.disabled = !(pick && (!isK() || ta.value.trim())); };
  el.addEventListener('input', ev => { ev.stopPropagation(); sync(); });
  el.addEventListener('click', ev => { ev.stopPropagation(); if (ev.target === el) { el.remove(); return; }
    if (ev.target.closest('button[data-rsel]')) { const m = q('.ix-rs', el); m.style.display = m.style.display === 'none' ? '' : 'none'; return; }
    const r = ev.target.closest('button[data-r]'); if (r) { pick = r.getAttribute('data-r'); const sp = q('button[data-rsel] span', el); sp.textContent = pick; sp.classList.remove('hmt-ph'); q('.ix-rs', el).style.display = 'none'; kh.style.display = isK() ? '' : 'none'; sync(); return; }
    const b = ev.target.closest('button[data-a]'); if (!b) return; if (b.getAttribute('data-a') === 'x') { el.remove(); return; }
    if (b.disabled) return; const note = ta.value.trim(); el.remove(); onOk(pick + (isK() && note ? ' · ' + note : '')); });
}
function dlgMove(card) {
  const meta = q('.hmt-meta', card); const title = tx0(q('.hmt-act-main b', card));
  const body = '<span class="hmt-help">' + title + '</span><div class="hmt-sum"><div><span>Lịch hiện tại</span><b class="hmt-num">' + tx0(q('.hmt-late, .hmt-meta span', card)).replace(/^Quá hạn · /, '') + '</b></div></div><div style="display:grid;grid-template-columns:1fr 1fr;gap:var(--space-3)"><div class="hmt-field" style="min-width:0"><label>Ngày mới <span class="hmt-req">*</span></label><input class="hmt-input" type="date" value="2026-10-19" aria-label="Ngày mới"></div><div class="hmt-field" style="min-width:0"><label>Giờ mới <span class="hmt-req">*</span></label><input class="hmt-input" type="time" value="09:00" aria-label="Giờ mới"></div></div>'
    + '<div class="hmt-field" style="min-width:0"><label>Chọn nhanh ngày</label><div class="hmt-pills" role="group"><button type="button" aria-pressed="false" data-d="2026-10-17">Hôm nay</button><button type="button" aria-pressed="false" data-d="2026-10-18">Ngày mai</button><button type="button" aria-pressed="false" data-d="2026-10-19">Ngày kia</button><button type="button" aria-pressed="false" data-d="2026-10-24">Tuần sau</button></div></div>'
    + '<div class="hmt-field" style="min-width:0"><label>Chọn nhanh giờ</label><div class="hmt-pills" role="group"><button type="button" aria-pressed="false">08:00</button><button type="button" aria-pressed="false">09:00</button><button type="button" aria-pressed="false">10:00</button><button type="button" aria-pressed="false">14:00</button><button type="button" aria-pressed="false">15:30</button><button type="button" aria-pressed="false">17:00</button></div></div><div class="hmt-field" style="min-width:0"><label>Ghi chú</label><textarea class="hmt-textarea" rows="2" placeholder="Không bắt buộc"></textarea></div>';
  const el = mkScrim(480, 'Dời lịch hẹn', 'Dời lịch hẹn', body, '<button class="hmt-btn" type="button" data-a="x">Huỷ</button><button class="hmt-btn hmt-btn-primary" type="button" data-a="ok">Dời lịch</button>');
  const di = q('input[type=date]', el), ti = q('input[type=time]', el);
  el.addEventListener('click', ev => { ev.stopPropagation(); if (ev.target === el) { el.remove(); return; }
    const pb = ev.target.closest('.hmt-pills button'); if (pb) { qa('button', pb.parentElement).forEach(x => x.setAttribute('aria-pressed', x === pb ? 'true' : 'false')); if (pb.getAttribute('data-d')) di.value = pb.getAttribute('data-d'); else ti.value = tx0(pb); fieldOk(di); fieldOk(ti); return; }
    const b = ev.target.closest('button[data-a]'); if (!b) return; if (b.getAttribute('data-a') === 'x') { el.remove(); return; }
    let bad = false; if (!di.value) { fieldErr(di, 'Bắt buộc nhập'); bad = true; } else if (di.value < '2026-10-17') { fieldErr(di, 'Ngày hẹn không được trước hôm nay'); bad = true; } else fieldOk(di);
    if (!ti.value) { fieldErr(ti, 'Bắt buộc nhập'); bad = true; } else fieldOk(ti); if (bad) return;
    const dd = di.value.split('-'); const when = dd[2] + '/' + dd[1] + '/' + dd[0] + ' ' + ti.value; el.remove();
    const late = q('.hmt-late', card); if (late) { late.className = 'hmt-num'; late.textContent = 'Hẹn · ' + when; } else { const mm = q('.hmt-meta', card); if (mm) mm.firstChild.textContent = 'Hẹn · ' + when; }
    toast('Đã dời lịch sang ' + when + '.'); });
}
function dlgContact() {
  const body = '<div class="hmt-field" style="min-width:0"><label>Kênh liên hệ <span class="hmt-req">*</span></label><div class="hmt-pills" role="group" aria-label="Kênh liên hệ"><button type="button" aria-pressed="true">Gọi điện</button><button type="button" aria-pressed="false">Zalo</button><button type="button" aria-pressed="false">Tin nhắn</button><button type="button" aria-pressed="false">Gặp trực tiếp</button></div></div>'
    + '<div class="hmt-field" style="min-width:0"><label>Nội dung <span class="hmt-req">*</span></label><textarea class="hmt-textarea" rows="3" placeholder="Đã trao đổi gì với phụ huynh, học sinh" aria-label="Nội dung"></textarea></div>'
    + '<div style="display:grid;grid-template-columns:1fr 1fr;gap:var(--space-3)"><div class="hmt-field" style="min-width:0"><label>Ngày <span class="hmt-req">*</span></label><input class="hmt-input" type="date" value="2026-10-17" aria-label="Ngày"></div><div class="hmt-field" style="min-width:0"><label>Giờ <span class="hmt-req">*</span></label><input class="hmt-input" type="time" value="15:20" aria-label="Giờ"></div></div>';
  const el = mkScrim(480, 'Ghi nhận liên hệ', 'Ghi nhận liên hệ', body, '<button class="hmt-btn" type="button" data-a="x">Huỷ</button><button class="hmt-btn hmt-btn-primary" type="button" data-a="ok">Ghi nhận</button>');
  pillsOf(el); const ta = q('textarea', el), di = q('input[type=date]', el), ti = q('input[type=time]', el);
  el.addEventListener('click', ev => { ev.stopPropagation(); if (ev.target === el) { el.remove(); return; }
    const b = ev.target.closest('button[data-a]'); if (!b) return; if (b.getAttribute('data-a') === 'x') { el.remove(); return; }
    let bad = false; [ta, di, ti].forEach(i => { if (!i.value.trim()) { fieldErr(i, 'Bắt buộc nhập'); bad = true; } else fieldOk(i); }); if (bad) return;
    const ch = tx0(q('.hmt-pills button[aria-pressed="true"]', el)); const dd = di.value.split('-'); const when = dd[2] + '/' + dd[1] + ' · ' + ti.value; const txt = ta.value.trim(); el.remove();
    const day = q('.hmt-day'); if (day) { const m = document.createElement('div'); m.className = 'hmt-msg'; const u = q('.hmt-user-n b'); const av = q('.hmt-user .hmt-avatar');
      m.innerHTML = '<span class="hmt-avatar hmt-avatar-lg">' + (av ? av.textContent : '') + '</span><div class="hmt-msg-b"><span class="hmt-meta"><b>' + (u ? u.textContent : '') + '</b> · <span class="hmt-num">' + when + '</span> · Liên hệ</span><div class="hmt-note"></div></div>'; q('.hmt-note', m).textContent = ch + ': ' + txt; day.after(m); }
    toast('Đã ghi nhận liên hệ (' + ch + ').'); });
}
"""

def wire(t, kind, stage, hs, ph, merge_mode):
    P = hs if kind == 'hs' else ph
    js = INT_JS % {'panels': json.dumps(P, ensure_ascii=False), 'kind': kind, 'stage': stage,
                   'chk': SVG(IC['check']).replace("'", "\\'"), 'xx': SVG(IC['x']).replace("'", "\\'"), 'alert': SVG(IC['alert']).replace("'", "\\'")}
    t = t.replace('// @@ANCHOR@@', js + '\n' + DLG_JS + '\n// @@ANCHOR@@', 1)
    return t

def run():
    hs, ph = panels()
    out = R.build_all()
    cfg = {  # tên: (loại, giai đoạn)
        'KH05': ('hs', 's1'), 'KH05_day_du': ('hs', 'full'), 'KH05_trong': ('hs', 's1'), 'KH05_hoc_tap': ('hs', 'full'), 'KH05_hoc_tap_mo': ('hs', 's1'),
        'KH05_diem_danh': ('hs', 'full'), 'KH05_diem_danh_chi_tiet': ('hs', 'full'), 'KH05_diem_kiem_tra': ('hs', 'full'), 'KH05_cham_soc': ('hs', 'full'), 'KH05_de_nghi': ('hs', 'full'),
        'KH02': ('ph', 's1'), 'KH02_cac_con': ('ph', 's1'), 'KH02_tai_chinh': ('ph', 'full'), 'KH02_tai_chinh_mo': ('ph', 's1'), 'KH02_kt': ('ph', 'full'),
    }
    for n, (kind, stage) in cfg.items():
        t = wire(out[n], kind, stage, hs, ph, None)
        # hộp Gộp mở được từ menu Hành động (ẩn lúc đầu)
        if n != 'KH02_kt':
            t = M.build(None, 'normal', kind if False else ('ph' if kind == 'ph' else 'hs'), '—', False, show0='false', text=t)
            t = re.sub(r'<title>[^<]*</title>', '<title>%s</title>' % R_TITLE(out[n]), t, count=1)
        out[n] = t
    return out

def R_TITLE(t): return re.search(r'<title>([^<]*)</title>', t).group(1)

if __name__ == '__main__':
    out = run()
    for n, s in out.items(): R.wr(n, s)
    print(len(out))
