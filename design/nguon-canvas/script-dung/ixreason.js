function ixReason(title, head, list, okLabel, onOk, foot) {
  // Hộp lý do dùng chung: chọn lý do trong danh sách (bắt buộc); chọn "Khác"/"Lý do khác" thì hiện ô ghi chú và bắt buộc ghi.
  const el = document.createElement('div'); el.className = 'hmt-scrim ix-ap'; el.style.cssText = 'position:absolute;inset:0;z-index:140;align-items:center;padding:0;display:flex';
  const CH = '<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>';
  el.innerHTML = '<div class="hmt-dialog" role="dialog" aria-label="' + title + '" style="width:480px;flex:0 0 480px"><div class="hmt-dialog-h">' + title + '</div><div class="hmt-dialog-b">' + (head ? '<div style="font-size:13px;margin-bottom:8px"><b>' + head + '</b></div>' : '')
    + '<div class="hmt-field" style="min-width:0;position:relative"><label>Lý do <span class="hmt-req">*</span></label><button class="hmt-input hmt-select" type="button" data-rsel aria-haspopup="listbox"><span class="hmt-ph">Chọn lý do…</span>' + CH + '</button>'
    + '<div class="hmt-menu ix-rs" role="listbox" style="display:none;position:absolute;left:0;right:0;top:64px;z-index:5;max-height:240px;overflow:auto">' + list.map(r => '<button type="button" class="hmt-opt" role="option" data-r="' + r + '">' + r + '</button>').join('') + '</div></div>'
    + '<div class="hmt-field ix-khac" style="min-width:0;display:none;margin-top:8px"><label>Ghi chú <span class="hmt-req">*</span></label><textarea class="hmt-textarea" rows="2" placeholder="Ghi rõ lý do"></textarea><span class="hmt-help">Bắt buộc khi chọn “Khác”.</span></div>'
    + (foot ? '<div class="hmt-help" style="margin-top:8px">' + foot + '</div>' : '') + '</div><div class="hmt-dialog-f"><button class="hmt-btn" type="button" data-a="x">Đóng</button><button class="hmt-btn hmt-btn-danger" type="button" data-a="ok" disabled>' + okLabel + '</button></div></div>';
  ROOT.appendChild(el); let pick = '';
  const ta = el.querySelector('textarea'), okb = el.querySelector('button[data-a=ok]'), kh = el.querySelector('.ix-khac');
  const isK = () => /khác/i.test(pick);
  const sync = () => { okb.disabled = !(pick && (!isK() || ta.value.trim())); };
  el.addEventListener('input', ev => { ev.stopPropagation(); sync(); });
  el.addEventListener('click', ev => { ev.stopPropagation(); if (ev.target === el) { el.remove(); return; }
    if (ev.target.closest('button[data-rsel]')) { const m = el.querySelector('.ix-rs'); m.style.display = m.style.display === 'none' ? '' : 'none'; return; }
    const r = ev.target.closest('button[data-r]'); if (r) { pick = r.getAttribute('data-r'); const sp = el.querySelector('button[data-rsel] span'); sp.textContent = pick; sp.classList.remove('hmt-ph'); el.querySelector('.ix-rs').style.display = 'none'; kh.style.display = isK() ? '' : 'none'; sync(); return; }
    const b = ev.target.closest('button[data-a]'); if (!b) return; if (b.getAttribute('data-a') === 'x') { el.remove(); return; }
    if (b.disabled) return; const note = ta.value.trim(); el.remove(); onOk(pick + (isK() && note ? ' · ' + note : '')); });
  sync();
}
