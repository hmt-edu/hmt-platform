/* ===== TS-16c Calendar Phiếu kiểm tra: Tuần (cột = ngày) / Ngày (cột = phòng), kéo = mở Đổi lịch. Phiếu nào cũng có lịch nên không có khay Chưa có lịch ===== */
{
  const host = q('.hmt-calhost'); const BASE = new Date(2026, 9, 12), TODAY = new Date(2026, 9, 14), NOW_H = 10.5; const H0 = 8, H1 = 21, PX = 48, DUR = 60;
  const CAL = { mode: 'Tuần', off: 0, day: new Date(TODAY) };
  const DN = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']; const pz = n => (n < 10 ? '0' : '') + n; const fD = d => pz(d.getDate()) + '/' + pz(d.getMonth() + 1) + '/' + d.getFullYear();
  const same = (a, b) => a.toDateString() === b.toDateString(); const hm = m => pz(Math.floor(m / 60)) + ':' + pz(m % 60);
  const CLS = { 'Nháp': 'hmt-ev-email', 'Đang test': 'hmt-ev-call', 'Chờ giáo viên chấm': 'hmt-ev-pay', 'Hoàn thành': 'hmt-ev-done', 'Huỷ': 'hmt-ev-cancel' };
  const ROOMS = ['P101', 'P102', 'P201', 'Online', 'Chưa gán phòng'];
  const scale = () => { const r = ROOT.getBoundingClientRect(); return r.width / (ROOT.offsetWidth || r.width) || 1; };
  const wk0 = () => new Date(BASE.getTime() + CAL.off * 7 * 86400000);
  let cur = null;
  function lanes(items) { items.sort((a, b) => a.s - b.s); const out = []; let cl = [], end = 0;
    const flush = () => { const L = []; cl.forEach(it => { let k = 0; while (L[k] !== undefined && L[k] > it.s) k++; L[k] = it.e; it.k = k; }); const n = L.length || 1; cl.forEach(it => { it.n = n; out.push(it); }); cl = []; };
    items.forEach(it => { if (cl.length && it.s >= end) { flush(); end = 0; } cl.push(it); end = Math.max(end, it.e); }); if (cl.length) flush(); return out; }
  function evHTML(it) {
    const r = it.r, st = PK.st(r), top = (it.s / 60 - H0) * PX, h = Math.max(22, (it.e - it.s) / 60 * PX - 2), w = 100 / it.n;
    const late = PK.late(r);
    return '<a class="hmt-ev ' + CLS[st] + (h < 40 ? ' hmt-ev-short' : '') + '" href="#" draggable="true" data-c="' + PK.code(r) + '" title="' + PK.code(r) + ' · ' + PK.name(r) + ' · ' + st + '" style="top:' + top + 'px;height:' + h + 'px;left:calc(' + (it.k * w) + '% + 2px);width:calc(' + w + '% - 4px);right:auto;' + (late ? 'border-left:4px solid var(--danger-text);' : '') + '"><b>' + PK.name(r) + '</b><span class="t">' + hm(it.s) + '–' + hm(it.e) + '</span>' + (h >= 46 ? '<span class="t">' + PK.meta(r).split(' · ').slice(0, 2).join(' · ') + '</span>' : '') + '</a>';
  }
  function render() {
    const rows = PK.rows().filter(r => r._show !== false); const week = CAL.mode === 'Tuần';
    const items = []; const tray = [];
    rows.forEach(r => { const st = PK.st(r), d = PK.dt(r); if (!d) { if (!/Huỷ/.test(st)) tray.push(r); return; } const s = d.getHours() * 60 + d.getMinutes(); items.push({ r, d, s, e: s + DUR, room: r.dataset.room || '' }); });
    let cols = [], heads = [];
    if (week) { for (let i = 0; i < 7; i++) { const d = new Date(wk0().getTime() + i * 86400000); cols.push(items.filter(x => same(x.d, d))); heads.push('<div class="hmt-calv-h' + (same(d, TODAY) ? ' today' : '') + '"><span>' + DN[d.getDay()] + '</span><b>' + d.getDate() + '</b></div>'); } }
    else { const day = items.filter(x => same(x.d, CAL.day)); ROOMS.forEach(rm => { cols.push(day.filter(x => (x.room || 'Chưa gán phòng') === rm)); heads.push('<div class="hmt-calv-h"><span>Phòng</span><b style="font-size:14px">' + rm + '</b></div>'); }); }
    const showNow0 = (week ? CAL.off === 0 : same(CAL.day, TODAY));
    const tcol = '<div class="hmt-calv-time" style="height:' + (H1 - H0) * PX + 'px">' + Array.from({ length: H1 - H0 - 1 }, (_, i) => '<span style="top:' + (i + 1) * PX + 'px">' + pz(H0 + i + 1) + ':00</span>').join('') + (showNow0 ? '<span class="hmt-calv-nowlbl" style="left:4px;right:auto;top:' + (NOW_H - H0) * PX + 'px">' + pz(Math.floor(NOW_H)) + ':' + pz(Math.round((NOW_H % 1) * 60)) + '</span>' : '') + '</div>';
    const showNow = (week ? CAL.off === 0 : same(CAL.day, TODAY));
    const colsH = cols.map((c, i) => { const isT = week ? same(new Date(wk0().getTime() + i * 86400000), TODAY) : false; return '<div class="hmt-calv-col' + (isT ? ' today' : '') + '" data-i="' + i + '" style="height:' + (H1 - H0) * PX + 'px;position:relative">' + (showNow && (isT || !week) ? '<div class="hmt-calv-now" style="top:' + (NOW_H - H0) * PX + 'px"></div>' : '') + lanes(c).map(evHTML).join('') + '</div>'; }).join('');
    const title = week ? fD(wk0()) + ' – ' + fD(new Date(wk0().getTime() + 6 * 86400000)) : DN[CAL.day.getDay()] + ', ' + fD(CAL.day);
    const nEv = cols.reduce((a, c) => a + c.length, 0);
    host.innerHTML = '<div class="hmt-calv" style="overflow:visible;position:relative;flex:1 1 0;min-width:0"><div class="hmt-calv-bar"><button class="hmt-btn" type="button" data-nav="0">Hôm nay</button><button class="hmt-iconbtn" type="button" aria-label="Trước" data-nav="-1"><svg class="hmt-ic" viewBox="0 0 24 24" aria-hidden="true"><path d="m15 18-6-6 6-6"/></svg></button><button class="hmt-iconbtn" type="button" aria-label="Sau" data-nav="1"><svg class="hmt-ic" viewBox="0 0 24 24" aria-hidden="true"><path d="m9 18 6-6-6-6"/></svg></button><h2>' + title + '</h2><div class="end"><div class="hmt-seg" role="group" aria-label="Phạm vi">' + ['Ngày', 'Tuần', 'Tháng'].map(m => '<button type="button" data-mode="' + m + '"' + (m === CAL.mode ? ' aria-pressed="true"' : '') + '>' + m + '</button>').join('') + '</div></div></div>'
      + '<div class="hmt-calv-legend">' + [['Nháp', 'var(--bg-surface)', '1px solid var(--input-border)'], ['Đang test', 'var(--info-bg)', '1px solid var(--info-border)'], ['Chờ giáo viên chấm', 'var(--warning-bg)', '1px solid var(--warning-text)'], ['Hoàn thành', 'var(--bg-subtle)', '1px solid var(--divider)'], ['Huỷ', 'var(--bg-subtle)', '1px dashed var(--input-border)']].map(l => '<span><i style="background:' + l[1] + ';border:' + l[2] + '"></i>' + l[0] + '</span>').join('') + '<span><i style="background:var(--bg-surface);border-left:4px solid var(--danger-text)"></i>Quá giờ chưa bắt đầu</span></div>'
      + '<div class="hmt-calv-grid" style="grid-template-columns:56px repeat(' + cols.length + ', minmax(0, 1fr))"><div class="hmt-calv-corner"></div>' + heads.join('') + tcol + colsH + '</div>'
      + (nEv ? '' : '<div class="hmt-help" style="position:absolute;left:56px;right:0;top:160px;text-align:center;pointer-events:none">Không có phiếu nào khớp bộ lọc trong khoảng này.</div>') + '</div>';
  }
  const byCode = PK.byCode;
  function popover(a, r) {
    closeMenu(); const cal = q('.hmt-calv', host), cr = cal.getBoundingClientRect(), er = a.getBoundingClientRect(), sc = scale(); const st = PK.st(r), act = PK.act(st);
    const m = document.createElement('div'); m.className = 'hmt-menu ix-evm'; m.setAttribute('role', 'dialog'); m.style.cssText = 'position:absolute;z-index:40;width:300px;padding:12px;display:flex;flex-direction:column;gap:6px';
    m.innerHTML = '<span style="display:flex;justify-content:space-between;align-items:center"><b>' + PK.name(r) + '</b><span class="hmt-tag ' + PK.TAG[st] + '">' + st + '</span></span><span class="hmt-help">' + PK.code(r) + ' · ' + PK.meta(r) + '</span><span style="font-size:13px">' + PK.when(r) + ' · ' + PK.cs(r) + (r.dataset.room ? ' · ' + r.dataset.room : '') + '</span><span style="display:flex;align-items:center;gap:6px;flex-wrap:wrap">' + PK.chips(r) + (PK.gv(r) && PK.gv(r) !== '—' ? '<span class="hmt-help">GV chấm: ' + PK.gv(r) + '</span>' : '') + '</span>'
      + (act ? '<button class="hmt-btn hmt-btn-primary" type="button" data-pgo style="width:100%">' + act[0] + '</button>' : '') + '<div class="hmt-row" style="flex-wrap:wrap;gap:6px"><button class="hmt-btn" type="button" data-pop="open">Mở phiếu</button>' + (/^(Nháp|Đang test)$/.test(st) ? '<button class="hmt-btn" type="button" data-pop="move">Đổi lịch</button>' : '') + '</div>';
    cal.appendChild(m); let left = (er.left - cr.left) / sc + er.width / sc + 6; if (left + 310 > cal.offsetWidth) left = (er.left - cr.left) / sc - 306; m.style.left = Math.max(60, left) + 'px'; m.style.top = Math.max(0, (er.top - cr.top) / sc) + 'px'; m._r = r;
  }
  const closeMenu = () => qa('.ix-evm', host).forEach(x => x.remove());
  host.addEventListener('click', e => {
    e.stopPropagation(); const t = e.target; if (!t.closest('.ix-pop')) closePops();
    const nv = t.closest('[data-nav]'); if (nv) { const n = +nv.getAttribute('data-nav'); if (CAL.mode === 'Tuần') CAL.off = n === 0 ? 0 : CAL.off + n; else CAL.day = n === 0 ? new Date(TODAY) : new Date(CAL.day.getTime() + n * 86400000); render(); return; }
    const md = t.closest('[data-mode]'); if (md) { const m = md.getAttribute('data-mode'); if (m === 'Tháng') { toast('Wireframe vẽ chế độ Ngày và Tuần; chế độ Tháng cùng cách lọc.'); return; } CAL.mode = m; if (m === 'Ngày') CAL.day = same(wk0(), BASE) && CAL.off === 0 ? new Date(TODAY) : wk0(); render(); return; }
    const pm = t.closest('.ix-evm'); if (pm) { const r = pm._r; const b = t.closest('button'); if (!b) return; closeMenu(); if (b.hasAttribute('data-pgo')) PK.go(r, render); else if (b.getAttribute('data-pop') === 'open') toast('Mở phiếu ' + PK.code(r) + ' (TS-17).'); else toast('Mở hộp thoại Đổi lịch (TS-15), ngày giờ điền sẵn: ' + PK.when(r) + '.'); return; }
    const ev = t.closest('.hmt-ev'); if (ev) { e.preventDefault(); const r = byCode(ev.getAttribute('data-c')); if (r) popover(ev, r); return; }
    const tr = t.closest('[data-tray]'); if (tr) { const r = byCode(tr.getAttribute('data-tray')); if (t.closest('[data-sched]')) toast('Mở hộp thoại Đổi lịch (TS-15) cho ' + PK.code(r) + ': chọn ngày, giờ, cơ sở.'); else toast('Mở phiếu ' + PK.code(r) + ' (TS-17).'); return; }
    const col = t.closest('.hmt-calv-col'); if (col) { closeMenu(); const rc = col.getBoundingClientRect(), sc = scale(); const mins = Math.round(((t.getBoundingClientRect ? e.clientY - rc.top : 0) / sc / PX * 60 + H0 * 60) / 30) * 30; const i = +col.getAttribute('data-i'); const d = CAL.mode === 'Tuần' ? new Date(wk0().getTime() + i * 86400000) : CAL.day; toast('Mở Tạo phiếu kiểm tra (TS-15): ngày ' + fD(d) + ', giờ ' + hm(mins) + (CAL.mode === 'Ngày' ? ', ' + ROOMS[i] : '') + ', cơ sở của bạn điền sẵn.'); return; }
    closeMenu();
  });
  let drag = null; host.addEventListener('dragstart', e => { const a = e.target.closest('.hmt-ev'); if (a) { drag = a; closeMenu(); try { e.dataTransfer.setData('text/plain', 'x'); } catch (_) {} } });
  host.addEventListener('dragover', e => { if (drag && e.target.closest('.hmt-calv-col')) e.preventDefault(); });
  host.addEventListener('drop', e => { const col = e.target.closest('.hmt-calv-col'); if (!col || !drag) return; e.preventDefault(); const r = byCode(drag.getAttribute('data-c')); drag = null; const rc = col.getBoundingClientRect(), sc = scale(); const mins = Math.round(((e.clientY - rc.top) / sc / PX * 60 + H0 * 60) / 30) * 30; const i = +col.getAttribute('data-i'); const d = CAL.mode === 'Tuần' ? new Date(wk0().getTime() + i * 86400000) : CAL.day;
    if (r && /^(Nháp|Đang test)$/.test(PK.st(r))) toast('Mở hộp thoại Đổi lịch (TS-15): ' + PK.code(r) + ' sang ' + fD(d) + ' ' + hm(mins) + '. Chưa đổi cho tới khi bấm Lưu.'); else toast('Phiếu đã ' + (PK.st(r) === 'Hoàn thành' ? 'hoàn thành' : 'tới bước chấm') + ', không đổi lịch được.'); });
  CFG.calSync = render;
  { const st = document.createElement('style'); st.textContent = '.hmt-toolbar .hmt-pager{display:none !important}.hmt-calhost{padding:var(--space-3);display:flex;gap:var(--space-3);align-items:flex-start}.hmt-calhost .hmt-kcol{align-self:flex-start}'; ROOT.appendChild(st); }
  applyFilters();
}
