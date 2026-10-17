import sys,re
ENGINE = r'''
// ---------- hoàn thành / huỷ / mở lại (sửa được khi bấm nhầm) ----------
let APDEF = '';
function apDef() { if (!APDEF) { const c = qa('tbody tr:not(.ghead)').map(r => r.children[7]).find(x => x && q('button', x) && tx(q('button', x)) === 'Hoàn thành'); APDEF = c ? c.innerHTML : '<span style="display:inline-flex;gap:var(--space-1)"><button class="hmt-btn hmt-btn-sm" type="button">Hoàn thành</button><button class="hmt-btn hmt-btn-sm" type="button">Dời</button><button class="hmt-btn hmt-btn-sm hmt-btn-danger" type="button">Huỷ</button></span>'; } return APDEF; }
function apStamp() { return '16/10/2026 ' + (typeof nowHM === 'function' ? nowHM() : '16:20'); }
function toastU(m, undo) {
  let t = q('.ix-toast'); if (!t) { t = document.createElement('div'); t.className = 'ix-toast'; ROOT.appendChild(t); }
  t.textContent = m + ' '; const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Hoàn tác (8s)';
  b.style.cssText = 'margin-left:8px;background:none;border:0;color:var(--neutral-0);text-decoration:underline;cursor:pointer;font:inherit;pointer-events:auto';
  b.addEventListener('click', ev => { ev.stopPropagation(); t.classList.remove('on'); undo(); });
  t.appendChild(b); t.classList.add('on'); clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('on'), 8000);
}
function actFix() {
  if (hdrIdx('Gắn với') < 0) return;
  qa('tbody tr:not(.ghead)').forEach(tr => { const c = tr.children[7]; if (!c || !tr.children[6]) return;
    const tg = q('.hmt-tag', tr.children[6]); const st = tx(tr.children[6]); const done = /Hoàn thành|Huỷ/.test(st); const has = q('button', c) ? tx(q('button', c)) : '';
    if (tg && (done || /hmt-tag-success/.test(tg.className))) tg.className = 'hmt-tag' + (/Hoàn thành/.test(st) ? ' hmt-tag-success' : '');
    if (done && has !== 'Mở lại') c.innerHTML = '<button class="hmt-btn hmt-btn-sm" type="button" title="Bấm nhầm? Mở lại để làm tiếp">Mở lại</button>';
    else if (!done && has !== 'Hoàn thành') c.innerHTML = apDef(); });
}
function apLog(tr, txt) { (tr._log = tr._log || []).push(apStamp() + ' · Trần Thu Hà · ' + txt); }
function apSet(tr, st, why) {
  const tg = q('.hmt-tag', tr.children[6]); if (!tg) return;
  tg.textContent = st; apLog(tr, st === 'Huỷ' ? 'Huỷ, lý do: ' + why : 'Hoàn thành'); if (st === 'Huỷ') tr._why = why;
  actFix(); applyFilters();
  toastU(st === 'Hoàn thành' ? 'Đã hoàn thành lịch hẹn.' : 'Đã huỷ lịch hẹn.', () => apReopen(tr, true));
}
function apReopen(tr, quiet) {
  const tg = q('.hmt-tag', tr.children[6]); if (!tg) return; tg.textContent = 'Chưa làm'; apLog(tr, quiet ? 'Hoàn tác' : 'Mở lại');
  actFix(); applyFilters(); toast(quiet ? 'Đã hoàn tác, lịch hẹn về “Chưa làm”.' : 'Đã mở lại lịch hẹn, trạng thái “Chưa làm”. Lịch sử vẫn giữ kết quả/lý do cũ.');
}
function apAsk(name, onOk) {
  const el = document.createElement('div'); el.className = 'hmt-scrim ix-ap'; el.style.cssText = 'position:absolute;inset:0;z-index:140;align-items:center;padding:0;display:flex';
  el.innerHTML = '<div class="hmt-dialog" role="dialog" aria-label="Huỷ lịch hẹn" style="width:480px;flex:0 0 480px"><div class="hmt-dialog-h">Huỷ lịch hẹn</div><div class="hmt-dialog-b"><div style="font-size:13px;margin-bottom:8px"><b>' + name + '</b></div><label class="hmt-label">Lý do huỷ <span style="color:var(--danger-text)">*</span></label><input class="hmt-input" placeholder="Ví dụ: PH báo bận, hẹn lại sau"><div class="hmt-pills" style="margin-top:8px"><button type="button">PH báo bận</button><button type="button">Không liên lạc được</button><button type="button">Tạo nhầm</button></div><div class="hmt-help" style="margin-top:8px">Huỷ nhầm vẫn mở lại được bất cứ lúc nào.</div></div><div class="hmt-dialog-f"><button class="hmt-btn" type="button" data-a="x">Đóng</button><button class="hmt-btn hmt-btn-danger" type="button" data-a="ok">Huỷ lịch hẹn</button></div></div>';
  ROOT.appendChild(el); const inp = q('input', el);
  el.addEventListener('click', ev => { ev.stopPropagation(); if (ev.target === el) { el.remove(); return; } const p = ev.target.closest('.hmt-pills button'); if (p) { inp.value = tx(p); inp.classList.remove('hmt-input-err'); return; }
    const b = ev.target.closest('button[data-a]'); if (!b) return; if (b.getAttribute('data-a') === 'x') { el.remove(); return; }
    if (!inp.value.trim()) { inp.classList.add('hmt-input-err'); if (!q('.ix-err', el)) { const e = document.createElement('div'); e.className = 'ix-err'; e.textContent = 'Nhập lý do huỷ.'; inp.parentElement.appendChild(e); } return; }
    const v = inp.value.trim(); el.remove(); onOk(v); });
}
'''
def patch(path):
    s=open(path,encoding='utf-8').read(); o=s
    if 'function apSet(' in s: print('already',path); return
    # engine functions before onClick
    if 'function onClick(' not in s: print('no engine',path); return
    s=s.replace('function onClick(', ENGINE+'function onClick(',1)
    # applyFilters hook
    if 'function applyFilters() { gwInit();' in s: s=s.replace('function applyFilters() { gwInit();','function applyFilters() { gwInit(); actFix();',1)
    elif 'function applyFilters() {' in s: s=s.replace('function applyFilters() {','function applyFilters() { actFix();',1)
    # table row branch
    a="/^(Hoàn thành|Huỷ|Dời)$/.test(label)) {\n    if (label === 'Dời') { CFG.lastRow = tr;"
    if a in s:
        s=s.replace(a,"/^(Hoàn thành|Huỷ|Dời|Mở lại)$/.test(label)) {\n    if (label === 'Mở lại') { apReopen(tr, false); return; }\n    if (label === 'Huỷ') { apAsk(tx(tr.children[2]), v => apSet(tr, 'Huỷ', v)); return; }\n    if (label === 'Hoàn thành') { apSet(tr, 'Hoàn thành'); return; }\n    if (label === 'Dời') { CFG.lastRow = tr;",1)
    # activity row branch
    m=re.search(r"    if \(/Hoàn thành\|Huỷ/\.test\(label\)\) \{\n      const c = q\('\.hmt-csec-t', btn\.closest\('\.hmt-csec'\)\); a2\.remove\(\);\n      const n = qa\('\.hmt-act'\)\.length; if \(c\) c\.textContent = 'HOẠT ĐỘNG SẮP TỚI \(' \+ n \+ '\)';\n      toast\([^\n]*\n    \}",s)
    if m:
        new='''    if (/Hoàn thành|Huỷ|Mở lại/.test(label)) {
      const sec = btn.closest('.hmt-csec'); const bx = q('.hmt-act-btns', a2); const tg = q('.hmt-tag', a2); const ttl = q('.hmt-act-main b', a2);
      const cnt = () => { const c = q('.hmt-csec-t', sec); if (c) c.textContent = 'HOẠT ĐỘNG SẮP TỚI (' + qa('.hmt-act').filter(x => !x._done).length + ')'; };
      const mark = (st, why) => { if (!a2._btns) a2._btns = bx.innerHTML; a2._done = st; if (tg) tg.textContent = st; if (ttl) ttl.style.textDecoration = st === 'Huỷ' ? 'line-through' : ''; a2.style.opacity = st === 'Huỷ' ? '.75' : '';
        bx.innerHTML = '<button class="hmt-btn" type="button" title="Bấm nhầm? Mở lại để làm tiếp">Mở lại</button>' + (why ? ' <span class="hmt-help">Lý do: ' + why + '</span>' : ''); cnt();
        toastU(st === 'Hoàn thành' ? 'Đã hoàn thành lịch hẹn.' : 'Đã huỷ lịch hẹn.', () => reo(true)); };
      const reo = quiet => { a2._done = ''; if (tg) tg.textContent = 'Chưa làm'; if (ttl) ttl.style.textDecoration = ''; a2.style.opacity = ''; if (a2._btns) bx.innerHTML = a2._btns; cnt(); toast(quiet ? 'Đã hoàn tác, lịch hẹn về “Chưa làm”.' : 'Đã mở lại lịch hẹn, trạng thái “Chưa làm”.'); };
      if (label === 'Mở lại') reo(false); else if (label === 'Huỷ') apAsk(ttl ? tx(ttl) : 'Lịch hẹn', v => mark('Huỷ', v)); else mark('Hoàn thành');
    }'''
        s=s[:m.start()]+new+s[m.end():]
    # evOpen
    s=s.replace("(done ? '' : '<button class=\"hmt-btn\" type=\"button\" data-a=\"act\" data-l=\"Dời\">Dời</button>","(done ? '<button class=\"hmt-btn\" type=\"button\" data-a=\"act\" data-l=\"Mở lại\">Mở lại</button>' : '<button class=\"hmt-btn\" type=\"button\" data-a=\"act\" data-l=\"Dời\">Dời</button>",1)
    s=s.replace("row('Kết quả', done ? 'Đã ghi nhận trong lịch sử '","row('Kết quả', done ? (/Huỷ/.test(c[6]) && tr._why ? 'Lý do huỷ: ' + tr._why + '. ' : '') + 'Đã ghi nhận trong lịch sử '",1)
    s=s.replace("row('Người tạo', 'Trần Thu Hà · tạo lúc 10/10/2026 08:30')","row('Người tạo', 'Trần Thu Hà · tạo lúc 10/10/2026 08:30') + (tr._log ? row('Lịch sử thao tác', tr._log.join('<br>')) : '')",1)
    open(path,'w',encoding='utf-8').write(s); print('patched',path, len(s)-len(o))
for p in sys.argv[1:]: patch(p)
