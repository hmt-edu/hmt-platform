/* ===== TS-16b Kanban Phiếu kiểm tra: cột = giai đoạn, không kéo thả, nút chính trên thẻ ===== */
{
  const board = q('.hmt-kan'); const COLS = ['Nháp', 'Đang test', 'Chờ giáo viên chấm', 'Hoàn thành']; let endOpen = false;
  const ICON = { cal: '<svg class="hmt-ic" viewBox="0 0 24 24" aria-hidden="true" style="width:14px;height:14px"><path d="M8 2v4"/><path d="M16 2v4"/><rect width="18" height="18" x="3" y="4" rx="2"/><path d="M3 10h18"/></svg>' };
  function card(r, st) {
    const a = document.createElement('article'); a.className = 'hmt-kcard'; a._code = PK.code(r); a.style.cursor = 'pointer';
    const late = PK.late(r), act = PK.act(st), when = PK.when(r), noDate = /Chưa có lịch/.test(when);
    const bk = PK.bk(r); if (bk) { const cv = PK.BK[bk][1]; a.style.borderLeft = '4px solid ' + cv; a.style.background = 'color-mix(in srgb, ' + cv + ' 6%, var(--bg-surface))'; }
    if (st === 'Huỷ' || st === 'Từ chối') a.style.opacity = '.75';
    const sc = PK.score(r);
    a.innerHTML = '<span style="display:flex;justify-content:space-between;align-items:center"><span class="hmt-code">' + PK.code(r) + '</span>'
      + (st === 'Hoàn thành' ? '' : '<button class="hmt-iconbtn" type="button" data-more aria-label="Thêm" title="Huỷ phiếu" style="width:28px;height:28px">⋯</button>') + '</span>'
      + '<b style="display:block;margin-top:2px"><a href="#" data-open style="color:var(--text-link);text-decoration:none">' + PK.name(r) + '</a></b>'
      + '<span class="hmt-help" style="display:block">' + PK.meta(r) + '</span>'
      + '<span style="display:flex;align-items:center;gap:6px;margin-top:6px;font-size:12px;' + (late ? 'color:var(--danger-text);font-weight:600' : noDate ? 'color:var(--text-secondary)' : '') + '">' + ICON.cal + when + (late ? ' · Quá giờ' : '') + '</span>'
      + '<span class="hmt-help" style="display:block;margin-top:2px">' + PK.cs(r) + (PK.gv(r) && PK.gv(r) !== '—' ? ' · GV chấm: ' + PK.gv(r) : '') + '</span>'
      + ((st === 'Hủy' || st === 'Huỷ' || st === 'Từ chối') && WHY[PK.code(r)] ? '<span class="hmt-help" style="display:block;margin-top:2px">Lý do: ' + WHY[PK.code(r)] + '</span>' : '')
      + '<span style="display:flex;justify-content:space-between;align-items:center;margin-top:8px">' + PK.chips(r)
      + (st === 'Hoàn thành' && sc && sc !== '—' ? '<span class="hmt-tag hmt-tag-success">' + sc + '/10</span>' : act ? '<button class="hmt-btn hmt-btn-sm' + (st === 'Huỷ' || st === 'Từ chối' ? '' : ' hmt-btn-primary') + '" type="button" data-go>' + act[0] + '</button>' : '') + '</span>';
    return a;
  }
  function render() {
    const rows = PK.rows().filter(r => r._show !== false); board.innerHTML = '';
    COLS.forEach(st => {
      const rs = rows.filter(r => PK.st(r) === st); const col = document.createElement('section'); col.className = 'hmt-kcol'; col.style.cssText = 'flex:0 0 280px;width:280px'; col.setAttribute('data-st', st);
      let h = '<div class="hmt-kcol-h">' + st + '<span class="n">' + rs.length + '</span></div>';
      if (st !== 'Hoàn thành') { const cnt = { 'Quá giờ': 0, 'Hôm nay': 0, 'Sắp tới': 0 }; rs.forEach(r => { const k = PK.bk(r); if (k) cnt[k]++; }); const real = cnt['Quá giờ'] + cnt['Hôm nay'] + cnt['Sắp tới'], tot = real || 1;
        h += '<div class="hmt-kbar" role="group" aria-label="Mốc thời gian" style="cursor:default;background:transparent' + (real ? '' : ';visibility:hidden') + '">' + ['Sắp tới', 'Hôm nay', 'Quá giờ'].map(k => '<i class="' + PK.BK[k][0] + '" title="' + k + ': ' + cnt[k] + '" style="width:' + (cnt[k] / tot * 100) + '%"></i>').join('') + '</div>'
          + '<div class="hmt-help" style="display:flex;gap:10px;font-size:11px;margin:-2px 0 6px">' + ['Sắp tới', 'Hôm nay', 'Quá giờ'].map(k => '<span style="color:' + PK.BK[k][1] + '">' + k + ' ' + cnt[k] + '</span>').join('') + '</div>'; }
      else h += '<div class="hmt-kbar" aria-hidden="true" style="visibility:hidden"></div><div style="height:22px"></div>';
      col.innerHTML = h;
      rs.sort((a, b) => (PK.dt(a) || 9e15) - (PK.dt(b) || 9e15)).forEach(r => col.appendChild(card(r, st)));
      if (!rs.length) { const e = document.createElement('div'); e.className = 'hmt-help'; e.style.cssText = 'text-align:center;padding:18px 8px'; e.textContent = 'Không có phiếu.'; col.appendChild(e); }
      board.appendChild(col);
    });
    const ends = rows.filter(r => /Huỷ|Từ chối/.test(PK.st(r))); const ec = document.createElement('section'); ec.className = 'hmt-kcol'; ec.setAttribute('data-end', '1');
    if (!endOpen) { ec.style.cssText = 'flex:0 0 52px;width:52px;cursor:pointer;align-items:center'; ec.innerHTML = '<div class="hmt-kcol-h" style="flex-direction:column;gap:6px;padding:10px 0;justify-content:flex-start"><span class="n">' + ends.length + '</span><span style="writing-mode:vertical-rl;font-size:12px;white-space:nowrap">Đã huỷ</span></div>'; }
    else { ec.style.cssText = 'flex:0 0 280px;width:280px'; ec.innerHTML = '<div class="hmt-kcol-h" style="cursor:pointer" data-toggle>Đã huỷ<span class="n">' + ends.length + '</span></div>'; ends.forEach(r => ec.appendChild(card(r, PK.st(r)))); if (!ends.length) { const e = document.createElement('div'); e.className = 'hmt-help'; e.style.cssText = 'text-align:center;padding:18px 8px'; e.textContent = 'Không có phiếu.'; ec.appendChild(e); } }
    board.appendChild(ec);
  }
  board.addEventListener('click', e => {
    e.stopPropagation(); const t = e.target; if (!t.closest('.ix-pop')) closePops();
    const ce = t.closest('[data-end]'); if (ce && !endOpen) { endOpen = true; render(); return; } if (t.closest('[data-toggle]')) { endOpen = false; render(); return; }
    const cd = t.closest('.hmt-kcard'); if (!cd) return; const r = PK.byCode(cd._code); if (!r) return;
    if (t.closest('[data-go]')) { PK.go(r, render); return; }
    const mo = t.closest('[data-more]'); if (mo) { openPop(mo, ['Huỷ phiếu'], v => PK.end(r, 'Huỷ', render)); return; }
    e.preventDefault(); toast('Mở phiếu ' + PK.code(r) + ' · ' + PK.name(r) + ' (TS-17).');
  });
  CFG.calSync = render;
  { const st = document.createElement('style'); st.textContent = '.hmt-toolbar .hmt-pager{display:none !important}.hmt-kan{padding:var(--space-3)}'; ROOT.appendChild(st); }
  applyFilters();
}
