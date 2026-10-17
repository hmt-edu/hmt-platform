
// ---------- luồng phiếu test: stage chỉ đọc, đổi bằng nút; Huỷ/Từ chối trong menu Hành động ----------
const PSN = ['Nháp', 'Đang test', 'Chờ giáo viên chấm', 'Hoàn thành'];
const FL = { ps: 0, end: '', why: '', gv: '', room: '', score: '', nx: '', nxImg: 0, bai: false, de: false, deOn: false, lvl: '', cat: '', cls: '', edit: false, log: [] };
const fx = {};
function fxHTML() {
  const A = '<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14" /> <path d="m12 5 7 7-7 7" /></svg>';
  return A;
}
function fAddLog(txt, from, to) {
  const t = (typeof nowHM === 'function' ? nowHM() : '16:20'); const day = q('.hmt-day'); if (!day) return;
  let top = day; if (!/Hôm nay/.test(tx(day))) { top = document.createElement('div'); top.className = 'hmt-day'; top.textContent = 'Hôm nay · 16/10/2026'; day.parentNode.insertBefore(top, day); }
  const m = document.createElement('div'); m.className = 'hmt-msg';
  m.innerHTML = '<span class="hmt-avatar hmt-avatar-lg hmt-avatar-sys">HT</span><div class="hmt-msg-b"><span class="hmt-meta"><b>Hệ thống</b> · <span class="hmt-num">' + t + '</span> · Hệ thống</span><span>' + txt + '</span>' + (from ? '<span class="hmt-chg">Trạng thái: <s>' + from + '</s>' + fxHTML() + '<b>' + to + '</b></span>' : '') + '</div>';
  top.insertAdjacentElement('afterend', m);
}
function fReady() {
  const miss = []; if (!FL.gv) miss.push('GV chấm'); if (FL.score === '' || isNaN(+FL.score)) miss.push('Điểm'); if (!FL.bai) miss.push('Bài làm'); if (!FL.nx.trim() && !FL.nxImg) miss.push('Nhận xét'); if (FL.deOn && !FL.de) miss.push('Đề riêng');
  return miss;
}
function fGo(to, verb, undoable) {
  const from = PSN[FL.ps]; FL.ps = to; FL.edit = false; fAddLog(verb, from, PSN[to]); fRender();
  if (undoable) toastU(verb + '.', () => { const f2 = PSN[FL.ps]; FL.ps = to - 1; fAddLog('Hoàn tác', f2, PSN[FL.ps]); fRender(); });
}
function fReason(title, list, danger, onOk) {
  const el = document.createElement('div'); el.className = 'hmt-scrim ix-ap'; el.style.cssText = 'position:absolute;inset:0;z-index:140;align-items:center;padding:0;display:flex';
  el.innerHTML = '<div class="hmt-dialog" role="dialog" aria-label="' + title + '" style="width:480px;flex:0 0 480px"><div class="hmt-dialog-h">' + title + '</div><div class="hmt-dialog-b"><label class="hmt-label">Lý do <span class="hmt-req">*</span></label><div class="ix-rs" style="display:flex;flex-direction:column;gap:4px;max-height:230px;overflow:auto">' + list.map(r => '<button type="button" class="hmt-opt" data-r="' + r + '" style="text-align:left">' + r + '</button>').join('') + '</div><label class="hmt-label" style="margin-top:8px">Ghi chú</label><textarea class="hmt-textarea" rows="2" placeholder="Ghi chú thêm (bắt buộc nếu lý do khác)"></textarea><div class="hmt-help ix-rm" style="margin-top:6px"></div></div><div class="hmt-dialog-f"><button class="hmt-btn" type="button" data-a="x">Giữ lại</button><button class="hmt-btn ' + (danger ? 'hmt-btn-danger' : 'hmt-btn-primary') + '" type="button" data-a="ok">Xác nhận</button></div></div>';
  ROOT.appendChild(el); let pick = '';
  el.addEventListener('click', ev => { ev.stopPropagation(); if (ev.target === el) { el.remove(); return; }
    const r = ev.target.closest('button[data-r]'); if (r) { pick = r.getAttribute('data-r'); qa('button[data-r]', el).forEach(x => { x.style.background = x === r ? 'var(--brand-50)' : ''; x.style.fontWeight = x === r ? '600' : ''; }); q('.ix-rm', el).textContent = ''; return; }
    const b = ev.target.closest('button[data-a]'); if (!b) return; if (b.getAttribute('data-a') === 'x') { el.remove(); return; }
    const note = q('textarea', el).value.trim(); if (!pick) { q('.ix-rm', el).textContent = 'Chọn 1 lý do.'; q('.ix-rm', el).style.color = 'var(--danger-text)'; return; }
    if (/khác/i.test(pick) && !note) { q('.ix-rm', el).textContent = 'Lý do khác: nhập ghi chú.'; q('.ix-rm', el).style.color = 'var(--danger-text)'; return; }
    el.remove(); onOk(pick + (note ? ' · ' + note : '')); });
}
function fKv(l, v) { return '<div class="hmt-kv"><dt>' + l + '</dt><dd>' + v + '</dd></div>'; }
function fSel(id, ph, val) { return '<button class="hmt-input hmt-select" type="button" data-fs="' + id + '"><span' + (val ? '' : ' class="hmt-ph"') + '>' + (val || ph) + '</span><svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg></button>'; }
function fFile(id, label, on, name, size) { return on ? '<span class="hmt-rowl" style="display:inline-flex;gap:8px;align-items:center"><span>' + name + '</span><span class="hmt-help">' + size + '</span><button class="hmt-btn hmt-btn-sm" type="button" data-ff="' + id + '">Gỡ</button></span>' : '<button class="hmt-btn hmt-btn-sm" type="button" data-ff="' + id + '">' + label + '</button>'; }
function fRender() {
  const ps = FL.ps, fin = ps === 3 && !FL.edit; const dls = qa('.hmt-sheet dl.hmt-panel-b');
  // thanh stage chỉ đọc
  const nav = q('.hmt-stage'); if (nav) { nav.innerHTML = PSN.map((n, k) => '<button class="hmt-step' + (k < ps ? ' hmt-step-past' : '') + '" type="button"' + (k === ps ? ' aria-current="step"' : '') + ' style="cursor:default" title="Giai đoạn đổi bằng nút bên dưới">' + (k < ps ? LOCK : '') + n + '</button>').join(''); }
  // hàng ghi chú dưới stage
  const note = q('[aria-label="Giai đoạn"].hmt-box > div:last-child'); if (note) { note.innerHTML = FL.end ? '<span class="hmt-tag hmt-tag-danger">' + (FL.end === 'Huỷ' ? 'Đã huỷ' : 'Đã từ chối') + '</span><span>Lý do: ' + FL.why + '. Nhầm thì Hành động → Mở lại.</span>' : '<span>Stage chỉ đọc, đổi bằng nút bên dưới. Huỷ và Từ chối nằm trong menu Hành động.</span>'; }
  // thanh nút nghiệp vụ
  const bar = q('[aria-label="Nút nghiệp vụ và Sub-stage"]'); const B = (l, pri, dis, tip) => '<button class="hmt-btn' + (pri ? ' hmt-btn-primary' : '') + '" type="button"' + (dis ? ' disabled' : '') + (tip ? ' title="' + tip + '"' : '') + '>' + l + '</button>';
  if (bar) { let h = ''; if (FL.end) h = '<span class="hmt-help">Phiếu đã ' + (FL.end === 'Huỷ' ? 'huỷ' : 'bị từ chối') + ', không còn thao tác tiếp. Mở lại ở menu Hành động.</span>';
    else if (ps === 0) h = B('Bắt đầu test', true) + B('Đổi lịch'); else if (ps === 1) h = B('Nộp bài', true); else if (ps === 2) { const m = fReady(); h = B('Gợi ý lớp') + B('Hoàn thành', true, m.length > 0, m.length ? 'Còn thiếu: ' + m.join(', ') : '') + (m.length ? '<span class="hmt-help">Còn thiếu: ' + m.join(', ') + '</span>' : ''); }
    else h = B('Gợi ý lớp'); bar.innerHTML = h; }
  // menu Hành động
  const menu = q('.hmt-rbar-l .hmt-menu'); if (menu) { let h = ''; if (FL.end) h = '<button class="hmt-opt" type="button">Mở lại phiếu</button>'; else { if (ps > 0) h += '<button class="hmt-opt" type="button">Lùi về ' + PSN[ps - 1] + '</button><div style="border-top:1px solid var(--divider);margin:4px 0"></div>'; h += '<button class="hmt-opt" type="button" style="color:var(--danger-text)">Huỷ phiếu</button><button class="hmt-opt" type="button" style="color:var(--danger-text)">Từ chối phiếu</button>'; } menu.innerHTML = h; }
  // tiêu đề nút Sửa: chỉ ở Hoàn thành
  const sua = qa('.hmt-rbar-l > button').find(b => /^Sửa|^Lưu/.test(tx(b))); if (sua) { sua.style.display = ps === 3 || FL.edit ? '' : 'none'; const sv = q('svg', sua); sua.innerHTML = (sv ? sv.outerHTML : '') + (FL.edit ? 'Lưu' : 'Sửa'); }
  if (dls.length < 2) return;
  // cột trái: phòng, GV chấm
  const L = dls[0]; const kvs = qa('.hmt-kv', L); kvs.forEach(k => { const dt = tx(q('dt', k)); const dd = q('dd', k);
    if (dt === 'Ngày giờ xác nhận') dd.innerHTML = '<span class="hmt-num">15/10/2026 17:00</span>';
    if (dt === 'Phòng') dd.innerHTML = (ps < 3 || FL.edit) && !FL.end ? fSel('room', 'Chọn phòng (chọn sau)', FL.room) : (FL.room || 'P101 · 12 chỗ · CS1');
    if (dt === 'GV chấm') dd.innerHTML = (ps < 3 || FL.edit) && !FL.end ? fSel('gv', 'Chọn GV chấm (chọn sau)', FL.gv) : (FL.gv || 'Nguyễn Thị Lan · GV2007'); });
  // cột phải: kết quả + đính kèm
  const R = dls[1]; const T = '<div class="hmt-csec-t" style="padding:var(--space-2) 0 var(--space-1)">';
  const editor = ps === 2 || FL.edit;
  let h = T + 'KẾT QUẢ</div>';
  if (editor && !FL.end) {
    h += fKv('Điểm <span class="hmt-req">*</span>', '<input class="hmt-input" type="number" min="0" max="10" step="0.5" data-fi="score" placeholder="0 – 10" style="width:110px" aria-label="Điểm"> <span class="hmt-help">/ 10</span>')
      + fKv('Trình độ đề xuất', fSel('lvl', 'Chọn trình độ', FL.lvl)) + fKv('Phân loại đề xuất', fSel('cat', 'Chọn phân loại', FL.cat)) + fKv('Lớp đề xuất', fSel('cls', 'Chọn lớp (hoặc Gợi ý lớp)', FL.cls))
      + fKv('Nhận xét <span class="hmt-req">*</span>', '<textarea class="hmt-textarea" rows="3" data-fi="nx" placeholder="Nhận xét về bài làm" aria-label="Nhận xét"></textarea><div style="margin-top:6px;display:flex;gap:8px;align-items:center"><button class="hmt-btn hmt-btn-sm" type="button" data-ff="nxImg">+ Ảnh nhận xét</button><span class="hmt-help">' + (FL.nxImg ? FL.nxImg + ' ảnh đã đính kèm' : 'Chưa có ảnh') + '</span></div>');
    h += T + 'ĐÍNH KÈM</div>' + fKv('Bài làm <span class="hmt-req">*</span>', fFile('bai', 'Tải bài làm (ảnh/PDF)', FL.bai, 'bai-lam-le-gia-huy.pdf', '2,1 MB'))
      + fKv('Đề test', '<span class="hmt-help">Chọn từ danh mục đề test khi tạo phiếu.</span><br><label style="display:inline-flex;gap:6px;align-items:center;margin-top:4px"><input type="checkbox" data-fi="deOn"> Dùng đề riêng</label>' + (FL.deOn ? '<div style="margin-top:6px">' + fFile('de', 'Tải đề riêng (ảnh/PDF)', FL.de, 'de-rieng-pkt000105.pdf', '184 KB') + '</div>' : ''));
  } else if (ps >= 3 && !FL.end) {
    h += fKv('Điểm', '<b class="hmt-num" style="font-size:18px">' + (FL.score !== '' ? FL.score.toString().replace('.', ',') : '7,5') + '</b> <span class="hmt-help">/ 10</span>') + fKv('Trình độ đề xuất', '<span class="hmt-tag hmt-tag-success">' + (FL.lvl || 'A') + '</span>') + fKv('Phân loại đề xuất', FL.cat || 'CB · Cơ bản') + fKv('Lớp đề xuất', '<span class="hmt-code">' + (FL.cls || 'CS1-2627-TOAN-K09-CB-A-001') + '</span>') + fKv('Nhận xét', FL.nx || 'Nắm chắc phần Đại số, yếu phần Hình.')
      + T + 'ĐÍNH KÈM</div>' + fKv('Bài làm', 'bai-lam-le-gia-huy.pdf <span class="hmt-help">2,1 MB</span>') + (FL.deOn ? fKv('Đề riêng', 'de-rieng-pkt000105.pdf') : '');
  } else { h += '<div class="hmt-help" style="padding:var(--space-2) 0">' + (FL.end ? 'Phiếu không có kết quả.' : 'Chưa có kết quả. Điểm, bài làm, nhận xét nhập ở bước Chờ giáo viên chấm.') + '</div>'; }
  R.innerHTML = h;
  const sc = q('[data-fi=score]', R), nx = q('[data-fi=nx]', R); if (sc) sc.value = FL.score; if (nx) nx.value = FL.nx; const dc = q('[data-fi=deOn]', R); if (dc) dc.checked = FL.deOn;
}
(function () {
  const sel = { gv: ['Nguyễn Thị Lan · GV2007', 'Lê Hoài Nam · GV2011', 'Trần Văn Hùng · GV2015'], room: ['P101 · 12 chỗ · CS1', 'P102 · 8 chỗ · CS1', 'P201 · 10 chỗ · CS1', 'Online'], lvl: ['A', 'B', 'C', 'D'], cat: ['CB · Cơ bản', 'NC · Nâng cao'], cls: ['CS1-2627-TOAN-K09-CB-A-001 · 9A1', 'CS1-2627-TOAN-K09-CB-B-002 · 9A2'] };
  ROOT.addEventListener('click', e => {
    const b = e.target.closest && e.target.closest('button'); if (!b || !ROOT.contains(b)) return;
    if (b.closest('.ix-pop') || b.closest('.ix-ap')) return;
    const l = tx(b);
    const fs = b.getAttribute('data-fs'); if (fs) { e.stopPropagation(); closePops(); openPop(b, sel[fs], v => { FL[fs] = v; fRender(); }); return; }
    const ff = b.getAttribute('data-ff'); if (ff) { e.stopPropagation(); if (ff === 'nxImg') FL.nxImg++; else FL[ff] = !FL[ff]; fRender(); return; }
    if (b.hasAttribute('data-ff') || !b.closest('.hmt-box, .hmt-rbar-l')) return;
    if (b.closest('.hmt-rbar-l .hmt-menu')) {
      if (/^Lùi về/.test(l)) { e.stopPropagation(); b.closest('.hmt-menu').style.display = 'none'; const to = FL.ps - 1, from = PSN[FL.ps]; FL.ps = to; FL.edit = false; fAddLog('Lùi bước (bấm nhầm hoặc cần sửa lại)', from, PSN[to]); fRender(); toast('Đã lùi về ' + PSN[to] + '. Chỉ ghi log, không cần lý do.'); }
      else if (l === 'Huỷ phiếu' || l === 'Từ chối phiếu') { e.stopPropagation(); b.closest('.hmt-menu').style.display = 'none'; const kind = l === 'Huỷ phiếu' ? 'Huỷ' : 'Từ chối'; fReason(l, kind === 'Huỷ' ? REASONS_HUY : REASONS_TC, true, v => { FL.end = kind; FL.why = v; fAddLog('Phiếu ' + (kind === 'Huỷ' ? 'bị huỷ' : 'bị từ chối') + ', lý do: ' + v, PSN[FL.ps], kind); fRender(); toastU('Đã ' + (kind === 'Huỷ' ? 'huỷ' : 'từ chối') + ' phiếu.', () => { FL.end = ''; FL.why = ''; fAddLog('Hoàn tác ' + kind.toLowerCase(), kind, PSN[FL.ps]); fRender(); }); }); }
      else if (l === 'Mở lại phiếu') { e.stopPropagation(); b.closest('.hmt-menu').style.display = 'none'; const k = FL.end; FL.end = ''; FL.why = ''; fAddLog('Mở lại phiếu', k, PSN[FL.ps]); fRender(); toast('Đã mở lại phiếu, về ' + PSN[FL.ps] + '.'); }
      return; }
    if (b.closest('.hmt-rbar-l') && /^(Sửa|Lưu)$/.test(l)) { e.stopPropagation(); if (FL.edit) { const m = fReady(); if (m.length) { toast('Còn thiếu: ' + m.join(', ') + '.'); return; } FL.edit = false; fAddLog('Trần Thu Hà sửa thông tin phiếu (ghi log, không khoá phiếu)'); fRender(); toast('Đã lưu. Mỗi lần sửa ghi log: ai, lúc nào, ô nào.'); } else { FL.edit = true; fRender(); } return; }
    if (b.closest('[aria-label="Nút nghiệp vụ và Sub-stage"]')) { e.stopPropagation(); if (b.disabled) return;
      if (l === 'Bắt đầu test') fGo(1, 'Học sinh bắt đầu làm bài', true);
      else if (l === 'Nộp bài') fGo(2, 'Học sinh nộp bài, chờ giáo viên chấm', true);
      else if (l === 'Hoàn thành') { const m = fReady(); if (m.length) { toast('Còn thiếu: ' + m.join(', ') + '.'); return; } fGo(3, 'Nhập đủ kết quả, hoàn thành phiếu', true); }
      else if (l === 'Đổi lịch') toast('Mở hộp thoại Đổi lịch: dùng lại hộp thoại Tạo phiếu kiểm tra (TS-15), ngày giờ điền sẵn.');
      else if (l === 'Gợi ý lớp') { FL.lvl = 'A'; FL.cat = 'CB · Cơ bản'; FL.cls = 'CS1-2627-TOAN-K09-CB-A-001 · 9A1'; fRender(); toast('Đã gợi ý lớp theo trình độ, phân loại và cơ sở.'); }
      return; } }, true);
  ROOT.addEventListener('input', e => { const t = e.target; const k = t.getAttribute && t.getAttribute('data-fi'); if (!k) return; if (k === 'deOn') { FL.deOn = t.checked; fRender(); return; } FL[k] = t.value; const m = fReady(); const hb = qa('[aria-label="Nút nghiệp vụ và Sub-stage"] button').find(x => tx(x) === 'Hoàn thành'); if (hb) { hb.disabled = m.length > 0; hb.title = m.length ? 'Còn thiếu: ' + m.join(', ') : ''; } });
  ROOT.addEventListener('change', e => { const t = e.target; if (t.getAttribute && t.getAttribute('data-fi') === 'deOn') { FL.deOn = t.checked; fRender(); } });
  setTimeout(fRender, 0);
})();
