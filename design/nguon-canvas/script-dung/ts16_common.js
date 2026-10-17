/* ===== TS-16b/c dùng chung: dữ liệu phiếu từ bảng ẩn, đổi giai đoạn bằng nút (có Hoàn tác 8s), Huỷ có lý do từ danh mục ===== */
const WHY = {};
const PK = {
  byCode: c => qa('tbody tr', tbl()).filter(r => r.children.length > 6).find(r => tx(r.children[hdrIdx('Mã PKT')]) === c),
  H: n => hdrIdx(n),
  rows: () => qa('tbody tr', tbl()).filter(r => r.children.length > 6),
  c: (r, n) => r.children[hdrIdx(n)],
  st: r => tx(PK.c(r, 'Trạng thái')),
  name: r => tx(PK.c(r, 'Học sinh')),
  code: r => tx(PK.c(r, 'Mã PKT')),
  own: r => tx(PK.c(r, 'Người phụ trách')),
  cre: r => tx(PK.c(r, 'Người tạo')),
  ME: 'Trần Thu Hà',
  chips: r => {
    const o = PK.own(r), c = PK.cre(r), me = n => n === PK.ME;
    const I1 = '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>';
    const I2 = '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="m16 11 2 2 4-4"/></svg>';
    const ch = (ic, n, bg, col, tip) => '<span title="' + tip + '" style="display:inline-flex;align-items:center;gap:4px;padding:2px 7px;border-radius:999px;white-space:nowrap;font-size:12px;line-height:16px;background:' + bg + ';color:' + col + ';' + (me(n) ? 'font-weight:600' : '') + '">' + ic + (me(n) ? 'Tôi' : n) + '</span>';
    const N = ['var(--bg-sunken, #F1EDE7)', 'var(--text-secondary, #6B6157)'], A = ['#FFE4D3', '#8C3510'];
    if (o === c) return '<span style="display:inline-flex;gap:4px;flex-wrap:wrap">' + ch(I1 + I2, o, A[0], A[1], 'Người tạo phiếu và phụ trách care lịch test: ' + o) + '</span>';
    return '<span style="display:inline-flex;gap:4px;flex-wrap:wrap">' + ch(I1, c, N[0], N[1], 'Người tạo phiếu: ' + c) + ch(I2, o, A[0], A[1], 'Người phụ trách care lịch test: ' + o) + '</span>';
  },
  gv: r => tx(PK.c(r, 'GV chấm')),
  cs: r => tx(PK.c(r, 'Cơ sở test')),
  score: r => tx(PK.c(r, 'Điểm')),
  meta: r => tx(PK.c(r, 'Môn')) + ' · ' + tx(PK.c(r, 'Hình thức')) + ' · ' + tx(PK.c(r, 'Cấp độ')),
  when: r => tx(PK.c(r, 'Ngày giờ test')),
  dt: r => { const m = /(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2})/.exec(PK.when(r)); return m ? new Date(+m[3], +m[2] - 1, +m[1], +m[4], +m[5]) : null; },
  BK: { 'Quá giờ': ['bad', 'var(--danger-text)'], 'Hôm nay': ['warn', 'var(--warning-text)'], 'Sắp tới': ['ok', 'var(--success-text)'] },
  bk: r => { const d = PK.dt(r); if (!d || /Hoàn thành|Huỷ/.test(PK.st(r))) return ''; const k = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate(); return k < 20261014 || PK.late(r) ? 'Quá giờ' : k === 20261014 ? 'Hôm nay' : 'Sắp tới'; },
  late: r => { const d = PK.dt(r); return PK.st(r) === 'Nháp' && d && d < new Date(2026, 9, 14, 10, 30); },
  ini: n => n.split(' ').slice(-2).map(w => w[0]).join('').toUpperCase(),
  TAG: { 'Nháp': '', 'Đang test': 'hmt-tag-info', 'Chờ giáo viên chấm': 'hmt-tag-warning', 'Hoàn thành': 'hmt-tag-success', 'Huỷ': 'hmt-tag-danger' },
  set(r, st) { const t = q('.hmt-tag', PK.c(r, 'Trạng thái')); if (t) { t.textContent = st; t.className = 'hmt-tag ' + PK.TAG[st]; } },
  act: st => ({ 'Nháp': ['Bắt đầu test', 'Đang test', 'Học sinh đã bắt đầu làm bài.'], 'Đang test': ['Nộp bài', 'Chờ giáo viên chấm', 'Học sinh đã nộp bài, chờ giáo viên chấm.'], 'Chờ giáo viên chấm': ['Nhập kết quả', null], 'Huỷ': ['Mở lại', 'Nháp', 'Đã mở lại phiếu, về Nháp.'], 'Từ chối': ['Mở lại', 'Nháp', 'Đã mở lại phiếu, về Nháp.'] })[st] || null,
  dlg(title, body, okLabel, onOk, danger) {
    const el = document.createElement('div'); el.className = 'hmt-scrim ix-kd'; el.style.cssText = 'position:absolute;inset:0;z-index:130;align-items:center;padding:0;display:flex';
    el.innerHTML = '<div class="hmt-dialog" role="dialog" aria-label="' + title + '" style="width:480px;flex:0 0 480px"><div class="hmt-dialog-h">' + title + '</div><div class="hmt-dialog-b">' + body + '</div><div class="hmt-dialog-f"><button class="hmt-btn" type="button" data-a="x">Đóng</button><button class="hmt-btn ' + (danger ? 'hmt-btn-danger' : 'hmt-btn-primary') + '" type="button" data-a="ok">' + okLabel + '</button></div></div>';
    ROOT.appendChild(el); el.addEventListener('input', ev => ev.stopPropagation());
    el.addEventListener('click', ev => { ev.stopPropagation(); if (ev.target === el) { el.remove(); return; } const b = ev.target.closest('button[data-a]'); if (!b) return; if (b.getAttribute('data-a') === 'x') { el.remove(); return; }
      const inp = q('[data-req]', el); if (inp && !inp.value.trim()) { inp.classList.add('hmt-input-err'); let e = q('.ix-err', el); if (!e) { e = document.createElement('div'); e.className = 'ix-err'; e.textContent = inp.getAttribute('data-req'); inp.parentElement.appendChild(e); } return; }
      el.remove(); onOk(inp ? inp.value.trim() : ''); });
    return el;
  },
  /* chạy nút chính của giai đoạn; redraw() vẽ lại view */
  go(r, redraw) {
    const st = PK.st(r), a = PK.act(st); if (!a) return;
    if (!a[1]) { toast('Mở phiếu ' + PK.code(r) + ' (TS-17): nhập GV chấm, điểm, bài làm, nhận xét rồi bấm Hoàn thành.'); return; }
    PK.set(r, a[1]); applyFilters(); redraw(); toastU(a[2], () => { PK.set(r, st); applyFilters(); redraw(); });
  },
  end(r, kind, redraw) {
    const name = PK.name(r), from = PK.st(r);
    ixReason('Huỷ phiếu kiểm tra', PK.code(r) + ' · ' + name, REASONS_HUY, 'Huỷ phiếu', why => { PK.set(r, 'Huỷ'); WHY[PK.code(r)] = why; applyFilters(); redraw(); toastU('Đã huỷ phiếu ' + PK.code(r) + '.', () => { PK.set(r, from); applyFilters(); redraw(); }); }, 'Danh mục “Lý do huỷ test”. Chọn “Lý do khác” thì bắt ghi chú.');
  }

};
