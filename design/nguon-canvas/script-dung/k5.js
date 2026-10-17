class Component extends DCLogic {
  renderVals() { return { yes: true }; }
  componentDidMount() {
    const ROOT = document.querySelector('.hmt-app'); if (!ROOT) return;
    ROOT.style.position = 'relative';
    const q = (s, r) => (r || ROOT).querySelector(s), qa = (s, r) => Array.from((r || ROOT).querySelectorAll(s));
    const tx = e => ((e && e.textContent) || '').replace(/\s+/g, ' ').trim();
    const st = document.createElement('style');
    st.textContent = '.ix-toast{position:absolute;left:50%;bottom:28px;transform:translateX(-50%);background:var(--neutral-900);color:var(--neutral-0);padding:10px 16px;border-radius:var(--radius-md);font-size:13px;z-index:400;opacity:0;pointer-events:none;transition:opacity .15s;max-width:760px;text-align:center}.ix-toast.on{opacity:1}.ix-pop{position:absolute;z-index:300;min-width:200px;background:var(--bg-surface);border:1px solid var(--divider);border-radius:var(--radius-md);box-shadow:var(--shadow-md);max-height:360px;overflow:auto;padding:4px;display:flex;flex-direction:column}.ix-pop .hmt-opt{display:block;width:100%;text-align:left}.ix-pop .ix-h{padding:6px 10px 2px;font-size:11px;font-weight:600;color:var(--text-label);text-transform:uppercase}.hmt-ev.ix-off{display:none}.ix-empty{position:absolute;left:56px;right:0;top:120px;text-align:center;color:var(--text-secondary);font-size:13px;pointer-events:none}';
    ROOT.appendChild(st);
    const tEl = document.createElement('div'); tEl.className = 'ix-toast'; ROOT.appendChild(tEl); let tt;
    const toast = m => { tEl.textContent = m; tEl.classList.add('on'); clearTimeout(tt); tt = setTimeout(() => tEl.classList.remove('on'), 2600); };
    const closePops = () => qa('.ix-pop').forEach(p => p.remove());
    const scale = () => { const r = ROOT.getBoundingClientRect(); return r.width / (ROOT.offsetWidth || r.width) || 1; };
    function pop(anchor, build) {
      closePops(); const p = document.createElement('div'); p.className = 'ix-pop'; ROOT.appendChild(p); build(p);
      const sc = scale(), ar = anchor.getBoundingClientRect(), rr = ROOT.getBoundingClientRect();
      let left = (ar.left - rr.left) / sc, top = (ar.bottom - rr.top) / sc + 4;
      if (left + p.offsetWidth > ROOT.offsetWidth - 8) left = ROOT.offsetWidth - 8 - p.offsetWidth;
      p.style.left = left + 'px'; p.style.top = top + 'px'; p.addEventListener('click', e => e.stopPropagation()); return p;
    }
    const opt = (p, label, on, fn) => { const b = document.createElement('button'); b.type = 'button'; b.className = 'hmt-opt'; b.textContent = (on === true ? '✓  ' : on === false ? '     ' : '') + label; b.addEventListener('click', ev => { ev.stopPropagation(); fn(b); }); p.appendChild(b); return b; };
    const head = (p, t) => { const h = document.createElement('div'); h.className = 'ix-h'; h.textContent = t; p.appendChild(h); };

    /* ---- state ---- */
    const TYPES = { 'Gọi điện': 'hmt-ev-call', 'Zalo': 'hmt-ev-zalo', 'Email': 'hmt-ev-email', 'Gặp trực tiếp': 'hmt-ev-meet', 'Thu tiền': 'hmt-ev-pay' };
    const STAT = { 'Hoàn thành': 'hmt-ev-done', 'Huỷ': 'hmt-ev-cancel' };
    const S = { types: new Set(), stats: new Set(), mine: true, group: 'Không nhóm', range: 'Tất cả thời gian', field: 'Thời gian', off: 0 };
    const BASE = new Date(2026, 9, 12), TODAY = new Date(2026, 9, 13);
    const fmt = d => ('0' + d.getDate()).slice(-2) + '/' + ('0' + (d.getMonth() + 1)).slice(-2) + '/' + d.getFullYear();
    const DN = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    /* ---- chips ---- */
    const facets = q('.hmt-facets'), endBox = q('.end', facets);
    function chipX(onX) { const b = document.createElement('button'); b.type = 'button'; b.setAttribute('aria-label', 'Bỏ điều kiện'); b.innerHTML = '<svg class="hmt-ic" viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>'; b.addEventListener('click', ev => { ev.stopPropagation(); onX(); }); return b; }
    function renderChips() {
      qa('.hmt-chip-f', facets).forEach(c => c.remove());
      const add = (label, val, onX) => { const c = document.createElement('span'); c.className = 'hmt-chip hmt-chip-f'; c.innerHTML = '<span><b></b> </span>'; q('b', c).textContent = label + ':'; q('span', c).appendChild(document.createTextNode(val)); c.appendChild(chipX(onX)); facets.insertBefore(c, endBox); };
      if (S.mine) add('Của tôi', 'Tôi là sale', () => { S.mine = false; refresh(); });
      if (S.types.size) add('Loại hoạt động', Array.from(S.types).join(', '), () => { S.types.clear(); refresh(); });
      if (S.stats.size) add('Trạng thái', Array.from(S.stats).join(', '), () => { S.stats.clear(); refresh(); });
      if (S.group !== 'Không nhóm') add('Nhóm theo', S.group, () => { S.group = 'Không nhóm'; refresh(); });
      if (S.range !== 'Tất cả thời gian') add(S.field, S.range, () => { S.range = 'Tất cả thời gian'; refresh(); });
      facets.style.display = '';
    }
    /* ---- calendar render ---- */
    function renderCal() {
      const wk = S.off !== 0 || /^(Hôm qua|Tháng trước|Tuần trước)/.test(S.range);
      const days = qa('.hmt-calv-h');
      days.forEach((h, i) => { const d = new Date(BASE.getTime() + (S.off * 7 + i) * 86400000); q('span', h).textContent = DN[d.getDay()]; q('b', h).textContent = d.getDate(); h.classList.toggle('today', d.toDateString() === TODAY.toDateString()); });
      qa('.hmt-calv-col').forEach((c, i) => { const d = new Date(BASE.getTime() + (S.off * 7 + i) * 86400000); c.classList.toggle('today', d.toDateString() === TODAY.toDateString()); });
      const a = new Date(BASE.getTime() + S.off * 7 * 86400000), b = new Date(a.getTime() + 6 * 86400000);
      q('.hmt-calv-bar h2').textContent = fmt(a) + ' – ' + fmt(b);
      const now = q('.hmt-calv-now'), nl = q('.hmt-calv-nowlbl'); if (now) now.style.display = S.off === 0 ? '' : 'none'; if (nl) nl.style.display = S.off === 0 ? '' : 'none';
      let shown = 0;
      qa('.hmt-ev').forEach(e => {
        let ok = S.off === 0;
        const cl = e.className; const ty = Object.keys(TYPES).find(k => cl.indexOf(TYPES[k]) >= 0);
        if (S.types.size && !(ty && S.types.has(ty))) ok = false;
        if (S.stats.size) { const stt = Object.keys(STAT).find(k => cl.indexOf(STAT[k]) >= 0); if (!(stt && S.stats.has(stt))) ok = false; }
        e.classList.toggle('ix-off', !ok); if (ok) shown++;
      });
      let em = q('.ix-empty'); if (!em) { em = document.createElement('div'); em.className = 'ix-empty'; q('.hmt-calv-grid').parentElement.appendChild(em); }
      em.style.display = shown ? 'none' : ''; em.textContent = 'Không có lịch hẹn nào khớp điều kiện đang lọc.';
      if (!shown) { const m = q('.hmt-calv .hmt-menu'); if (m) m.style.display = 'none'; }
    }
    function refresh() {
      renderChips(); renderCal();
      const fb = qa('.hmt-toolbar > .hmt-btn').find(b => /Filters/.test(tx(b))); const n = S.types.size + S.stats.size;
      if (fb) fb.style.borderColor = n ? 'var(--brand-600)' : '';
      const gb = qa('.hmt-toolbar > .hmt-btn').find(b => /Group By/.test(tx(b))); if (gb) gb.style.borderColor = S.group !== 'Không nhóm' ? 'var(--brand-600)' : '';
      const rb = q('.hmt-toolbar [aria-label="Khoảng thời gian"]'); if (rb) { q('span', rb).textContent = S.range; rb.style.borderColor = S.range !== 'Tất cả thời gian' ? 'var(--brand-600)' : ''; }
      const fl = q('.hmt-toolbar [aria-label="Lọc theo cột thời gian"] span'); if (fl) fl.textContent = S.field;
    }
    /* ---- toolbar ---- */
    const tb = q('.hmt-toolbar');
    const btnBy = re => qa('button', tb).find(b => re.test(tx(b)) || re.test(b.getAttribute('aria-label') || ''));
    const bField = q('[aria-label="Lọc theo cột thời gian"]', tb), bRange = q('[aria-label="Khoảng thời gian"]', tb), bFilt = btnBy(/^Filters/), bGrp = btnBy(/^Group By/), bFav = btnBy(/^Favorites/);
    bField.addEventListener('click', ev => { ev.stopPropagation(); pop(bField, p => { head(p, 'Lọc theo cột thời gian'); ['Thời gian', 'Ngày tạo', 'Ngày cập nhật'].forEach(f => opt(p, f, f === S.field, () => { S.field = f; closePops(); refresh(); })); }); });
    bRange.addEventListener('click', ev => { ev.stopPropagation(); pop(bRange, p => { ['Tất cả thời gian', 'Hôm nay', 'Tuần này', 'Tuần trước', 'Tháng này', 'Tháng trước'].forEach(r => opt(p, r, r === S.range, () => { S.range = r; S.off = r === 'Tuần trước' ? -1 : 0; closePops(); if (r === 'Tháng này' || r === 'Tháng trước') toast('Chế độ Tháng của calendar chưa vẽ trong wireframe này; bộ lọc vẫn được ghi nhận.'); refresh(); })); }); });
    bFilt.addEventListener('click', ev => { ev.stopPropagation(); pop(bFilt, p => {
      const draw = () => { p.innerHTML = ''; head(p, 'Loại hoạt động'); Object.keys(TYPES).forEach(k => opt(p, k, S.types.has(k), () => { S.types.has(k) ? S.types.delete(k) : S.types.add(k); refresh(); draw(); }));
        head(p, 'Trạng thái'); Object.keys(STAT).forEach(k => opt(p, k, S.stats.has(k), () => { S.stats.has(k) ? S.stats.delete(k) : S.stats.add(k); refresh(); draw(); }));
        head(p, 'Của tôi'); opt(p, 'Tôi là sale', S.mine, () => { S.mine = !S.mine; refresh(); draw(); });
        const ad = opt(p, '+ Thêm bộ lọc tuỳ chỉnh…', null, () => { closePops(); toast('Hộp “Thêm bộ lọc tuỳ chỉnh” giống TS-01/TS-11b (xem Lịch hẹn dạng danh sách).'); }); ad.style.color = 'var(--text-link)'; };
      draw(); }); });
    bGrp.addEventListener('click', ev => { ev.stopPropagation(); pop(bGrp, p => { ['Không nhóm', 'Loại hoạt động', 'Trạng thái', 'Người phụ trách'].forEach(g => opt(p, g, g === S.group, () => { S.group = g; closePops(); if (g !== 'Không nhóm') toast('Calendar không chia hàng theo nhóm; nhóm theo “' + g + '” áp dụng khi chuyển sang Danh sách.'); refresh(); })); }); });
    bFav.addEventListener('click', ev => { ev.stopPropagation(); pop(bFav, p => { head(p, 'Bộ lọc đã lưu'); opt(p, 'Việc quá hạn của tôi', null, () => { S.mine = true; S.types.clear(); S.stats = new Set(['Huỷ']); closePops(); toast('Đã áp dụng bộ lọc yêu thích (minh hoạ).'); refresh(); }); opt(p, 'Gặp trực tiếp tuần này', null, () => { S.mine = true; S.stats.clear(); S.types = new Set(['Gặp trực tiếp']); S.off = 0; closePops(); refresh(); }); const sv = opt(p, '+ Lưu điều kiện hiện tại…', null, () => { closePops(); toast('Đã lưu điều kiện hiện tại vào Favorites (minh hoạ).'); }); sv.style.color = 'var(--text-link)'; }); });
    const colBtn = btnBy(/^Cột/); if (colBtn) colBtn.addEventListener('click', ev => { ev.stopPropagation(); toast('Calendar không có cột; chọn cột hiển thị ở dạng Danh sách.'); });
    /* ---- facets end buttons ---- */
    const [bClear, bSave] = qa('button', endBox);
    bClear.addEventListener('click', () => { S.types.clear(); S.stats.clear(); S.mine = false; S.group = 'Không nhóm'; S.range = 'Tất cả thời gian'; refresh(); });
    bSave.addEventListener('click', () => toast('Đã lưu điều kiện vào Favorites (minh hoạ).'));
    /* ---- calendar bar ---- */
    const cb = q('.hmt-calv-bar');
    const [bToday, bPrev, bNext] = qa('button', cb);
    bToday.addEventListener('click', () => { S.off = 0; refresh(); });
    bPrev.addEventListener('click', () => { S.off--; refresh(); });
    bNext.addEventListener('click', () => { S.off++; refresh(); });
    qa('.hmt-seg', cb).forEach(seg => qa('button', seg).forEach(b => b.addEventListener('click', () => {
      qa('button', seg).forEach(x => x.setAttribute('aria-pressed', x === b ? 'true' : 'false'));
      const t = tx(b); if (/Ngày|Tháng/.test(t)) toast('Wireframe chỉ vẽ chế độ Tuần; chế độ “' + t + '” sẽ có cùng cách lọc.'); if (/người|phòng/.test(t)) toast('“' + t + '” chia cột theo ' + (/người/.test(t) ? 'người phụ trách' : 'phòng') + ' khi có dữ liệu thật.');
    })));
    /* ---- view switch (Danh sách / Kanban / Calendar) ---- */
    qa('.hmt-seg-ic button').forEach(b => b.addEventListener('click', () => { const l = b.getAttribute('aria-label'); if (l !== 'Calendar') toast('Chuyển sang ' + l + ' (xem Lịch hẹn dạng ' + l.toLowerCase() + ' ở vùng bên trái).'); }));
    /* ---- event popup ---- */
    const menu = q('.hmt-calv .hmt-menu'); const grid = q('.hmt-calv-grid');
    qa('.hmt-ev').forEach(e => e.addEventListener('click', ev => {
      ev.preventDefault(); ev.stopPropagation(); if (!menu) return;
      const sc = scale(), er = e.getBoundingClientRect(), gr = grid.getBoundingClientRect();
      const title = e.getAttribute('title') || ''; const m = /^([^:]+): ([^·,]+)(?: · ([^,·]+))?/.exec(title);
      menu.style.display = ''; menu.dataset.ev = '1'; menu._ev = e;
      const bt = q('b', menu); if (bt && m) bt.textContent = m[1] + ' · ' + (m[2] || '').trim();
      const lk = q('a', menu); if (lk && m) lk.textContent = (m[3] || '').trim() + ' · ' + (m[2] || '').trim();
      const hp = q('.hmt-help', menu); if (hp) hp.textContent = title.split(', ').pop();
      let left = (er.left - gr.left) / sc + er.width / sc + 6; if (left + 340 > grid.offsetWidth) left = (er.left - gr.left) / sc - 346;
      menu.style.left = Math.max(60, left) + 'px'; menu.style.top = Math.max(0, (er.top - gr.top) / sc) + 'px';
    }));
    const [mDone, mMove, mCancel] = qa('button', menu || ROOT);
    if (menu) {
      menu.addEventListener('click', ev => ev.stopPropagation());
      mDone.addEventListener('click', () => { const e = menu._ev; if (e) { e.className = e.className.replace(/hmt-ev-(call|zalo|email|meet|pay|cancel)/, 'hmt-ev-done'); } menu.style.display = 'none'; toast('Đã đánh dấu Hoàn thành.'); refresh(); });
      mMove.addEventListener('click', () => { menu.style.display = 'none'; toast('Mở hộp thoại Dời lịch hẹn.'); });
      mCancel.addEventListener('click', () => { const e = menu._ev; if (e) { e.className = e.className.replace(/hmt-ev-(call|zalo|email|meet|pay|done)/, 'hmt-ev-cancel'); } menu.style.display = 'none'; toast('Đã huỷ lịch hẹn.'); refresh(); });
    }
    const onDoc = ev => { closePops(); if (menu && !ev.target.closest('.hmt-ev') && !ev.target.closest('.hmt-menu')) menu.style.display = 'none'; const l2 = ev.target.closest && ev.target.closest('.hmt-sb-l2'); if (l2) { ev.preventDefault(); toast('Mở màn “' + tx(l2) + '” (màn khác, không nằm trong canvas này).'); } };
    const onKey = ev => { if (ev.key === 'Escape' && ROOT.isConnected) { closePops(); if (menu) menu.style.display = 'none'; } };
    document.addEventListener('click', onDoc); document.addEventListener('keydown', onKey);
    this._off = () => { document.removeEventListener('click', onDoc); document.removeEventListener('keydown', onKey); };
    refresh();
  }
  componentWillUnmount() { if (this._off) this._off(); }
}
