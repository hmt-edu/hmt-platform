/* ===== K5 Calendar: dùng chung bộ lọc với TS-11b, lịch là một "cách nhìn" của cùng dữ liệu ===== */
{
  const calEl = q('.hmt-calv'); const bar = q('.hmt-calv-bar', calEl); const grid = q('.hmt-calv-grid', calEl); const menu = q('.hmt-menu', calEl);
  const evs = qa('.hmt-ev', calEl); const CAL = { off: 0 };
  const BASE = new Date(2026, 9, 12), TODAYC = new Date(2026, 9, 13);
  const DNm = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  const pz = n => (n < 10 ? '0' : '') + n;
  const fmtD = d => pz(d.getDate()) + '/' + pz(d.getMonth() + 1) + '/' + d.getFullYear();
  const isoD = d => d.getFullYear() + '-' + pz(d.getMonth() + 1) + '-' + pz(d.getDate());
  const dayAt = i => new Date(BASE.getTime() + (CAL.off * 7 + i) * 86400000);
  const nowLine = q('.hmt-calv-now', calEl), nowLbl = q('.hmt-calv-nowlbl', calEl);
  const emp = document.createElement('div'); emp.className = 'ix-empty hmt-help'; emp.style.cssText = 'position:absolute;left:56px;right:0;top:140px;text-align:center;pointer-events:none;display:none'; emp.textContent = 'Không có lịch hẹn nào khớp bộ lọc.'; grid.style.position = grid.style.position || 'relative'; grid.appendChild(emp);
  function calHead() {
    qa('.hmt-calv-h', calEl).forEach((h, i) => { const d = dayAt(i); q('span', h).textContent = DNm[d.getDay()]; q('b', h).textContent = d.getDate(); h.classList.toggle('today', d.toDateString() === TODAYC.toDateString()); });
    qa('.hmt-calv-col', calEl).forEach((c, i) => c.classList.toggle('today', dayAt(i).toDateString() === TODAYC.toDateString()));
    q('h2', bar).textContent = fmtD(dayAt(0)) + ' – ' + fmtD(dayAt(6));
    if (nowLine) nowLine.style.display = CAL.off === 0 ? '' : 'none'; if (nowLbl) nowLbl.style.display = CAL.off === 0 ? '' : 'none';
  }
  CFG.calSync = function () {
    const o = PSEL && PER[PSEL];
    if (o && perActive(o)) { if (o.from && o.to) CAL.off = Math.floor((new Date(o.from + 'T00:00:00') - BASE) / (7 * 86400000)); else if (o.pre.indexOf('Tuần này') >= 0 || o.pre.indexOf('Hôm nay') >= 0) CAL.off = 0; }
    const ok = {}; qa('tbody tr', tbl()).filter(r => r.dataset.ev !== undefined).forEach(r => { ok[r.dataset.ev] = r._show !== false; });
    let shown = 0; evs.forEach((e, i) => { const v = !!ok[i] && CAL.off === 0; e.classList.toggle('ix-off', !v); if (v) shown++; });
    calHead(); emp.style.display = shown ? 'none' : ''; if (!shown && menu) menu.style.display = 'none';
  };
  /* tuần ⇄ bộ lọc Thời gian ở toolbar */
  function calGo(off) {
    CAL.off = off; const o = perOf(PSEL || CFG.pcol); o.pre = []; o.m = []; o.q = []; o.y = []; o.from = ''; o.to = '';
    if (off === 0) o.pre = ['Tuần này']; else { o.from = isoD(dayAt(0)); o.to = isoD(dayAt(6)); o.ft = '00:00'; o.tt = '23:59'; }
    timeSync(); fxChips(); applyFilters();
  }
  const [bToday, bPrev, bNext] = qa('button', bar);
  bToday.addEventListener('click', () => calGo(0)); bPrev.addEventListener('click', () => calGo(CAL.off - 1)); bNext.addEventListener('click', () => calGo(CAL.off + 1));
  qa('.hmt-seg', bar).forEach(seg => qa('button', seg).forEach(b => b.addEventListener('click', () => {
    qa('button', seg).forEach(x => x.setAttribute('aria-pressed', x === b ? 'true' : 'false')); const t = tx(b);
    if (/Ngày|Tháng/.test(t)) toast('Wireframe chỉ vẽ chế độ Tuần; chế độ “' + t + '” có cùng cách lọc.'); if (/người|phòng/.test(t)) toast('“' + t + '” chia cột theo ' + (/người/.test(t) ? 'người phụ trách' : 'phòng') + ' khi có dữ liệu thật.');
  })));
  /* thẻ chi tiết lịch hẹn */
  const scale = () => { const r = ROOT.getBoundingClientRect(); return r.width / (ROOT.offsetWidth || r.width) || 1; };
  const PH = { 'Vũ Gia Bảo': 'Vũ Thị Lan', 'Lê Gia Huy': 'Lê Văn Hùng', 'Bùi Khánh Linh': 'Bùi Thu Trang', 'Phạm Minh Khôi': 'Phạm Quốc Việt', 'Đặng Minh Châu': 'Đặng Thị Hoa', 'Đinh Quốc Bảo': 'Đinh Thị Mai', 'Trần Bảo Long': 'Trần Văn Đức', 'Lý Thanh Hương': 'Lý Văn Sơn' };
  let curEv = null;
  const ob = document.createElement('button'); ob.type = 'button'; ob.className = 'hmt-btn hmt-btn-primary'; ob.style.cssText = 'width:100%;margin-bottom:4px';
  ob.innerHTML = '<svg class="hmt-ic" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/></svg><span></span>';
  if (menu) { menu.insertBefore(ob, q('.hmt-row', menu)); q('.hmt-row', menu).style.flexWrap = 'wrap'; }
  const goDetail = () => { const t = tx(q('b', menu)); menu.style.display = 'none'; toast('Mở Chi tiết ' + menu._kind + ' ' + menu._code + ' › tab Lịch sử, cuộn tới lịch hẹn “' + t + '” (màn Chi tiết, không nằm trong canvas này).'); };
  ob.addEventListener('click', goDetail); if (menu) { const l = q('a', menu); l.addEventListener('click', e => { e.preventDefault(); goDetail(); }); }
  const mo = document.createElement('button'); mo.type = 'button'; mo.className = 'hmt-btn'; mo.style.cssText = 'display:none;width:100%;margin-bottom:4px'; mo.textContent = 'Mở lại lịch hẹn (bấm nhầm thì sửa lại)';
  if (menu) menu.insertBefore(mo, q('.hmt-row', menu));
  const evSt = e => /hmt-ev-done/.test(e.className) ? 'Hoàn thành' : /hmt-ev-cancel/.test(e.className) ? 'Huỷ' : 'Chưa làm';
  function menuMode(e) { const done = evSt(e) !== 'Chưa làm'; mo.style.display = done ? '' : 'none'; if (menu) qa('.hmt-row button', menu).forEach(b => { b.style.display = done ? 'none' : ''; }); }
  function setStatus(e, st, why) {
    const i = evs.indexOf(e); const r = qa('tbody tr', tbl()).find(x => x.dataset.ev === String(i));
    if (!e._orig) { const mm = /hmt-ev-(call|zalo|email|meet|pay)/.exec(e.className); if (mm) e._orig = mm[0]; }
    if (r) { const t = q('.hmt-tag', r.children[6]); if (t) t.textContent = st; apLog(r, st === 'Huỷ' ? 'Huỷ, lý do: ' + why : st === 'Chưa làm' ? 'Mở lại' : 'Hoàn thành'); if (st === 'Huỷ') r._why = why; }
    e.className = e.className.replace(/hmt-ev-(call|zalo|email|meet|pay|done|cancel)/, st === 'Hoàn thành' ? 'hmt-ev-done' : st === 'Huỷ' ? 'hmt-ev-cancel' : (e._orig || 'hmt-ev-call')); actFix(); applyFilters();
  }
  mo.addEventListener('click', ev => { ev.stopPropagation(); menu.style.display = 'none'; if (curEv) { setStatus(curEv, 'Chưa làm'); toast('Đã mở lại lịch hẹn, trạng thái “Chưa làm”.'); } });
  calEl.addEventListener('click', ev => {
    const t = ev.target; ev.stopPropagation(); if (!t.closest('.ix-pop')) closePops();
    const e = t.closest('.hmt-ev');
    if (e) { ev.preventDefault(); if (!menu) return; curEv = e; const er = e.getBoundingClientRect(), gr = grid.getBoundingClientRect(), sc = scale();
      const title = e.getAttribute('title') || ''; const m = /^([^:]+): ([^·,]+?)(?: · ([^,·]+?))?(?: ·|,|$)/.exec(title); const code = (/(CO|LD)\d{6}/.exec(title) || [''])[0]; const sn = m ? m[2].trim() : '';
      menu._code = code; menu._kind = /^LD/.test(code) ? 'lead' : 'cơ hội'; menu.style.display = ''; menuMode(e);
      const bt = q('b', menu); if (bt && m) bt.textContent = m[1] + ' · ' + sn; const lk = q('a', menu); lk.textContent = code + ' · ' + sn; lk.title = 'Học sinh: ' + sn + ' · Phụ huynh: ' + (PH[sn] || '—'); lk.style.cursor = 'pointer';
      q('span', ob).textContent = 'Mở ' + menu._kind + ' ' + code; ob.title = lk.title; const hp = q('.hmt-help', menu); if (hp) hp.textContent = title.split(', ').pop();
      let left = (er.left - gr.left) / sc + er.width / sc + 6; if (left + 340 > grid.offsetWidth) left = (er.left - gr.left) / sc - 346; menu.style.left = Math.max(60, left) + 'px'; menu.style.top = Math.max(0, (er.top - gr.top) / sc) + 'px'; return; }
    if (menu && t.closest('.hmt-menu') === menu) { const b = t.closest('button'); const lab = b && tx(b);
      if (lab === 'Hoàn thành') { menu.style.display = 'none'; const ce = curEv; if (ce) { setStatus(ce, 'Hoàn thành'); toastU('Đã hoàn thành lịch hẹn.', () => setStatus(ce, 'Chưa làm')); } } else if (lab === 'Huỷ') { menu.style.display = 'none'; const ce = curEv; if (ce) apAsk((q('b', menu) || {}).textContent || 'Lịch hẹn', v => { setStatus(ce, 'Huỷ', v); toastU('Đã huỷ lịch hẹn.', () => setStatus(ce, 'Chưa làm')); }); } else if (lab === 'Dời') { menu.style.display = 'none'; toast('Mở hộp thoại Dời lịch hẹn (TS-13).'); }
      return; }
    if (menu) menu.style.display = 'none';
  });
  document.addEventListener('keydown', ev => { if (ev.key === 'Escape' && ROOT.isConnected && menu && !q('.ix-pop') && !CFEL) menu.style.display = 'none'; });
  { const st = document.createElement('style'); st.textContent = '.hmt-toolbar .hmt-pager{display:none !important}'; ROOT.appendChild(st); }
  { const cb = qa('.hmt-header .sz button').find(b => /^Cột/.test(tx(b))); if (cb) cb.style.display = 'none'; }
  { const e0 = evs.find(e => /gửi báo giá/.test(e.getAttribute('title') || '')); if (e0 && menu) { curEv = e0; menu._code = 'CO000121'; menu._kind = 'cơ hội'; q('span', ob).textContent = 'Mở cơ hội CO000121'; ob.title = 'Học sinh: Lê Gia Huy · Phụ huynh: Lê Văn Hùng'; q('a', menu).title = ob.title; } }
  calHead(); CFG.calSync();
}
