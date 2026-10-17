/* ===== TS-11c Kanban Lịch hẹn: cột = trạng thái (Chưa làm | Hoàn thành | Huỷ); mốc Quá hạn/Hôm nay/Sắp tới = màu + thanh lọc ===== */
{
  const board = q('.hmt-kan'); const STS = ['Chưa làm', 'Hoàn thành', 'Huỷ'];
  const BK = { 'Quá hạn': ['bad', 'danger'], 'Hôm nay': ['warn', 'warning'], 'Sắp tới': ['ok', 'success'] };
  const COLV = { 'Quá hạn': 'var(--danger-text)', 'Hôm nay': 'var(--warning-text)', 'Sắp tới': 'var(--success-text)' };
  const rowsAll = () => qa('tbody tr', tbl()).filter(r => !r.classList.contains('ghead') && r.children.length > 6);
  const stOf = r => { const t = tx(r.children[6]); return /Hoàn thành/.test(t) ? 'Hoàn thành' : /Huỷ/.test(t) ? 'Huỷ' : 'Chưa làm'; };
  const bkOf = r => { const m = /(\d{2})\/(\d{2})\/(\d{4})/.exec(tx(r.children[4])); if (!m) return ''; const k = m[3] + m[2] + m[1]; return k < '20261014' ? 'Quá hạn' : k === '20261014' ? 'Hôm nay' : 'Sắp tới'; };
  const initials = n => n.split(' ').slice(-2).map(w => w[0]).join('').toUpperCase();
  const pill = b => qa('.hmt-pills[aria-label="Lịch hẹn"] button').find(x => tx(x) === b);
  function dlg(title, body, okLabel, onOk, danger) {
    const el = document.createElement('div'); el.className = 'hmt-scrim ix-kd'; el.style.cssText = 'position:absolute;inset:0;z-index:130;align-items:center;padding:0;display:flex';
    el.innerHTML = '<div class="hmt-dialog" role="dialog" aria-label="' + title + '" style="width:480px;flex:0 0 480px"><div class="hmt-dialog-h">' + title + '</div><div class="hmt-dialog-b">' + body + '</div><div class="hmt-dialog-f"><button class="hmt-btn" type="button" data-a="x">Đóng</button><button class="hmt-btn ' + (danger ? 'hmt-btn-danger' : 'hmt-btn-primary') + '" type="button" data-a="ok">' + okLabel + '</button></div></div>';
    ROOT.appendChild(el);
    el.addEventListener('click', ev => { ev.stopPropagation(); if (ev.target === el) { el.remove(); return; } const b = ev.target.closest('button[data-a]'); if (!b) return; if (b.getAttribute('data-a') === 'x') { el.remove(); return; }
      const inp = q('[data-req]', el); if (inp && !inp.value.trim()) { inp.classList.add('hmt-input-err'); let e = q('.ix-err', el); if (!e) { e = document.createElement('div'); e.className = 'ix-err'; e.textContent = inp.getAttribute('data-req'); inp.parentElement.appendChild(e); } return; }
      el.remove(); onOk(inp ? inp.value.trim() : ''); });
    return el;
  }
  function setStatus(r, st, why) { const t = q('.hmt-tag', r.children[6]); if (t) t.textContent = st; apLog(r, st === 'Huỷ' ? 'Huỷ, lý do: ' + why : st === 'Chưa làm' ? 'Mở lại' : 'Hoàn thành'); if (st === 'Huỷ') r._why = why; actFix(); applyFilters(); }
  function move(r, to) {
    const from = stOf(r), name = tx(r.children[2]); if (from === to) return;
    if (from === 'Chưa làm' && to === 'Hoàn thành') dlg('Hoàn thành lịch hẹn', '<div style="font-size:13px;margin-bottom:8px"><b>' + name + '</b></div><label class="hmt-label">Kết quả buổi hẹn <span style="color:var(--danger-text)">*</span></label><textarea class="hmt-input" rows="3" data-req="Nhập kết quả buổi hẹn." placeholder="Ví dụ: PH đồng ý cho bé học thử, hẹn lịch kiểm tra đầu vào."></textarea>', 'Hoàn thành', v => { setStatus(r, 'Hoàn thành'); toastU('Đã chuyển sang Hoàn thành; kết quả được ghi vào lịch sử.', () => apReopen(r, true)); });
    else if (from === 'Chưa làm' && to === 'Huỷ') apAsk(name, v => { setStatus(r, 'Huỷ', v); toast('Đã huỷ lịch hẹn; lý do được ghi vào lịch sử. Huỷ nhầm thì bấm Mở lại.'); });
    else if (to === 'Chưa làm') dlg('Mở lại lịch hẹn?', '<div style="font-size:13px"><b>' + name + '</b> sẽ chuyển về “Chưa làm”. Kết quả/lý do đã ghi vẫn giữ trong lịch sử.</div>', 'Mở lại', () => { setStatus(r, 'Chưa làm'); toast('Đã mở lại lịch hẹn.'); });
    else toast('Không chuyển trực tiếp giữa Hoàn thành và Huỷ; hãy mở lại về “Chưa làm” trước.');
  }
  function render() {
    const rows = rowsAll().filter(r => r._show !== false); board.innerHTML = '';
    STS.forEach(st => {
      const rs = rows.filter(r => stOf(r) === st);
      const col = document.createElement('section'); col.className = 'hmt-kcol'; col.style.cssText = 'flex:0 0 300px;width:300px'; col.setAttribute('data-st', st);
      let h = '<div class="hmt-kcol-h">' + st + '<span class="n">' + rs.length + '</span></div>';
      if (st === 'Chưa làm') { const cnt = { 'Quá hạn': 0, 'Hôm nay': 0, 'Sắp tới': 0 }; rs.forEach(r => cnt[bkOf(r)]++); const tot = rs.length || 1;
        h += '<div class="hmt-kbar" role="group" aria-label="Lọc theo mốc thời gian" style="cursor:pointer">' + ['Sắp tới', 'Hôm nay', 'Quá hạn'].map(k => '<i class="' + BK[k][0] + '" data-bk="' + k + '" title="' + k + ': ' + cnt[k] + ' — bấm để lọc" style="width:' + (cnt[k] / tot * 100) + '%;' + (pill(k) && pill(k).getAttribute('aria-pressed') === 'true' ? 'outline:2px solid var(--text-primary);outline-offset:1px' : '') + '"></i>').join('') + '</div>'
          + '<div class="hmt-help" style="display:flex;gap:10px;font-size:11px;margin:-2px 0 6px">' + ['Sắp tới', 'Hôm nay', 'Quá hạn'].map(k => '<span data-bk="' + k + '" style="cursor:pointer;color:' + COLV[k] + '">' + k + ' ' + cnt[k] + '</span>').join('') + '</div>'; }
      else h += '<div class="hmt-kbar" aria-hidden="true" style="visibility:hidden"></div><div style="height:22px"></div>';
      col.innerHTML = h;
      rs.forEach(r => {
        const bk = bkOf(r), code = tx(q('.hmt-code', r.children[3])), kind = tx(q('.hmt-help', r.children[3])), when = tx(r.children[4]).replace('/2026', ''); const own = tx(r.children[5]);
        const a = document.createElement('article'); a.className = 'hmt-kcard'; a.draggable = true; a._row = r; a.style.cursor = 'grab';
        if (st === 'Chưa làm' && bk) { a.style.borderLeft = '4px solid ' + COLV[bk]; a.style.background = 'color-mix(in srgb, ' + COLV[bk] + ' 6%, var(--bg-surface))'; }
        if (st === 'Huỷ') a.style.opacity = '.7';
        const tagCls = st === 'Chưa làm' && bk ? 'hmt-tag-' + BK[bk][1] : '';
        a.innerHTML = '<span style="display:flex;justify-content:space-between;align-items:center"><span class="hmt-kcard-m">' + tx(r.children[1]) + '</span><a href="#" class="hmt-code" data-code="1" style="color:var(--text-link);text-decoration:underline" title="Mở ' + kind.toLowerCase() + ' ' + code + ' (tab Lịch sử)">' + code + '</a></span><a href="#" data-ttl="1"' + (st === 'Huỷ' ? ' style="text-decoration:line-through"' : '') + '>' + tx(r.children[2]) + '</a><span class="hmt-kcard-m">' + kind + '</span><div class="hmt-kcard-f"><span class="hmt-tag ' + tagCls + '"><span class="hmt-dot"></span>' + (st === 'Chưa làm' && bk === 'Quá hạn' ? 'Quá hạn ' : st === 'Chưa làm' && bk === 'Hôm nay' ? 'Hôm nay ' : '') + when + '</span><span class="hmt-avatar" title="' + own + '" aria-label="Phụ trách: ' + own + '">' + initials(own) + '</span></div>' + (st === 'Chưa làm' ? '<div style="display:flex;gap:6px;margin-top:8px"><button type="button" class="hmt-btn hmt-btn-sm" data-act="Hoàn thành">Hoàn thành</button><button type="button" class="hmt-btn hmt-btn-sm" data-act="Dời">Dời</button><button type="button" class="hmt-btn hmt-btn-sm hmt-btn-danger" data-act="Huỷ">Huỷ</button></div>' : '<div style="display:flex;gap:6px;margin-top:8px"><button type="button" class="hmt-btn hmt-btn-sm" data-act="Mở lại" title="Bấm nhầm? Mở lại để làm tiếp">Mở lại</button></div>');
        col.appendChild(a);
      });
      if (!rs.length) { const e = document.createElement('div'); e.className = 'hmt-help'; e.style.cssText = 'text-align:center;padding:18px 8px'; e.textContent = 'Không có lịch hẹn.'; col.appendChild(e); }
      board.appendChild(col);
    });
  }
  let drag = null;
  board.addEventListener('dragstart', e => { const c = e.target.closest('.hmt-kcard'); if (c) { drag = c; try { e.dataTransfer.setData('text/plain', 'x'); } catch (_) {} } });
  board.addEventListener('dragover', e => { const col = e.target.closest('.hmt-kcol'); if (col && drag) { e.preventDefault(); qa('.hmt-kcol', board).forEach(c => { c.style.outline = c === col ? '2px dashed var(--brand-500)' : ''; }); } });
  board.addEventListener('drop', e => { const col = e.target.closest('.hmt-kcol'); qa('.hmt-kcol', board).forEach(c => { c.style.outline = ''; }); if (col && drag) { e.preventDefault(); const r = drag._row; drag = null; move(r, col.getAttribute('data-st')); } });
  board.addEventListener('dragend', () => { drag = null; qa('.hmt-kcol', board).forEach(c => { c.style.outline = ''; }); });
  board.addEventListener('click', e => {
    e.stopPropagation(); const t = e.target; if (!t.closest('.ix-pop')) closePops();
    const act = t.closest('button[data-act]'); if (act) { const r = act.closest('.hmt-kcard')._row; const ab = qa('button', r.children[7]).find(x => tx(x) === act.getAttribute('data-act')); if (ab) { ab.click(); applyFilters(); } return; }
    const seg = t.closest('[data-bk]'); if (seg) { const p = pill(seg.getAttribute('data-bk')); if (p) { p.click(); fxChips(); applyFilters(); } return; }
    const ttl = t.closest('a[data-ttl]'); if (ttl) { e.preventDefault(); evOpen(ttl.closest('.hmt-kcard')._row); return; }
    const cd = t.closest('a[data-code]'); if (cd) { e.preventDefault(); const r = cd.closest('.hmt-kcard')._row; const code = tx(cd); toast('Mở Chi tiết ' + (/^LD/.test(code) ? 'Lead' : 'Cơ hội') + ' ' + code + ' › tab Lịch sử, cuộn tới lịch hẹn “' + tx(r.children[2]) + '” (màn Chi tiết, không nằm trong canvas này).'); }
  });
  CFG.calSync = render;
  { const st = document.createElement('style'); st.textContent = '.hmt-toolbar .hmt-pager{display:none !important}.hmt-kan{padding:var(--space-3)}'; ROOT.appendChild(st); }
  applyFilters();
}
