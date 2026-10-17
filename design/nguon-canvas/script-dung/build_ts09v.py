# Sinh TS09a/b/c (biến thể hộp thoại chuyển giai đoạn) từ TS09.dc.html
import re
P='live15/project/'
base=open('scripts/ts09_base.dc.html').read()
X='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18" /> <path d="m6 6 12 12" /></svg>'
CHEV='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>'
DANGER='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10" /> <path d="m15 9-6 6" /> <path d="m9 9 6 6" /></svg>'
WARN='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3" /> <path d="M12 9v4" /> <path d="M12 17h.01" /></svg>'
OKI='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10" /> <path d="m9 12 2 2 4-4" /></svg>'
ARROW='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14" /> <path d="m12 5 7 7-7 7" /></svg>'
def dlg(title,to,body,ok,dis=True):
    return ('<div class="hmt-dialog" role="dialog" aria-label="%s" data-to="%s" style="width:540px;flex:0 0 540px"><div class="hmt-dialog-h">%s<button class="hmt-iconbtn x" type="button" aria-label="Đóng">%s</button></div>'
            '<div class="hmt-dialog-b">%s</div><div class="hmt-dialog-f"><button class="hmt-btn " type="button">Huỷ</button><button class="hmt-btn hmt-btn-primary" type="button" data-ok %s>%s</button></div></div>') % (title,to,title,X,body,'disabled="{{yes}}"' if dis else '',ok)
def sel(label,ph,req=True,help_=''):
    return '<div class="hmt-field" style="min-width:0"><label>%s%s</label><button class="hmt-input hmt-select" type="button"><span class="hmt-ph" style="color:var(--text-subtle)">%s</span>%s</button>%s</div>' % (label,' <span class="hmt-req">*</span>' if req else '',ph,CHEV,'<span class="hmt-help">%s</span>'%help_ if help_ else '')
def note(ph,khac=False):
    return '<div class="hmt-field" style="min-width:0"><label>Ghi chú%s</label><textarea class="hmt-textarea" rows="2" placeholder="%s" aria-label="Ghi chú"></textarea>%s</div>' % (' <span class="hmt-req" data-khac style="display:none">*</span>' if khac else '',ph,'<span class="hmt-help">Bắt buộc khi chọn “Khác”.</span>' if khac else '')
FOOT='<span class="hmt-help">Giai đoạn đã qua bị khoá, cơ hội chỉ đi tới, không có Hoàn tác. L6 do hệ thống tự đổi. L8 chọn tay sau khi đã thu tiền.</span>'
V={}
V['TS09']=dict(stage=6, sub='L6A Có kết quả, cần phân loại', title='Chuyển sang L7 Tư vấn', to='L7', ok='Chuyển giai đoạn', dis=False, nkt=1,
 head='Chị Lê Thu Hằng · Lê Gia Huy · Toán lớp 9',
 body='<span class="hmt-help">Cơ hội CO000121 · Chị Lê Thu Hằng · Toán lớp 9 · đang ở L6 Đã tham gia test (L6A Có kết quả, cần phân loại)</span>'
 '<div class="hmt-alert" role="status" style="background:var(--success-bg);color:var(--success-text);border-color:var(--success-border, var(--divider))">'+OKI+'<span>Phiếu <b class="hmt-code" style="color:inherit">PKT000105</b> đã Hoàn thành (điểm 7,5/10). Cơ hội không còn phiếu dang dở nên chuyển được sang L7.</span></div>'
 +sel('Sub-stage','Chọn sub-stage L7…',False,'Chọn khi chuyển sang L7. Có thể để trống.').replace('class="hmt-input hmt-select"','class="hmt-input hmt-select" data-optional',1)
 +note('Ví dụ: hẹn PH tư vấn kết quả test tối thứ 6')+FOOT)
V['TS09a']=dict(nkt=1, stage=5, sub='L5A Đồng ý tham gia test', title='Chuyển sang L7 Tư vấn', to='L7', ok='Chuyển giai đoạn',
 head='Anh Phạm Văn Tú · Phạm Minh Khôi · Toán lớp 6', old=True,
 body='<span class="hmt-help">Cơ hội CO000124 · Anh Phạm Văn Tú · Toán lớp 6 · đang ở L5 Đồng ý tham gia test</span>'
 '<div class="hmt-alert hmt-alert-danger" role="alert">'+DANGER+'<div style="display:flex;flex-direction:column;gap:6px;flex:1"><b>Chưa chuyển sang L7 được. Cơ hội còn phiếu kiểm tra dang dở:</b>'
 '<ul><li><b class="hmt-code" style="color:inherit">PKT000112</b> · Đang test · Toán · 15/10/2026 17:30 · CS1</li></ul>'
 '<span>Hoàn thành phiếu, hoặc Huỷ phiếu, rồi chuyển lại.</span><div><button class="hmt-btn hmt-btn-sm" type="button" data-openpkt>'+ARROW+'Mở phiếu PKT000112</button></div></div></div>'
 '<span class="hmt-help">Chặn khi chuyển sang L7 hoặc L8 mà cơ hội còn phiếu ở trạng thái Nháp, Đang test hoặc Chờ GV chấm. Mỗi phiếu dang dở được nêu mã.</span>'+FOOT)
V['TS09b']=dict(nkt=0, stage=4, sub='L4C Tiềm năng, cần tham khảo ý kiến', title='Chuyển sang L7 Tư vấn', to='L7', ok='Chuyển giai đoạn',
 head='Chị Trần Thị Mai · Trần Bảo Long · Toán lớp 9',
 body='<span class="hmt-help">Cơ hội CO000127 · Chị Trần Thị Mai · Toán lớp 9 · đang ở L4 Khách hàng tiềm năng</span>'
 '<div class="hmt-alert hmt-alert-warning" role="alert">'+WARN+'<span>Cơ hội chưa có phiếu kiểm tra (hoặc mọi phiếu đều Huỷ). Chọn lý do bỏ qua test để chuyển tiếp.</span></div>'
 +sel('Lý do bỏ qua test','Chọn lý do…',True,'Áp dụng khi chuyển sang L7 hoặc L8.')+note('Ví dụ: đã test ở trung tâm khác, điểm 8/10',True)
 +'<span class="hmt-help">Lý do bỏ qua test được ghi vào lịch sử cơ hội.</span>'+FOOT)
V['TS09c']=dict(nkt=1, stage=7, sub='L7C Đã tư vấn, dự thu', title='Chuyển sang L8 Đăng ký học', to='L8', ok='Chuyển L8',
 head='Chị Lý Ngọc Anh · Lý Thanh Hương · Toán lớp 10',
 body='<span class="hmt-help">Cơ hội CO000112 · Chị Lý Ngọc Anh · Toán lớp 10 · đang ở L7 Tư vấn. L8 chọn tay sau khi đã thu tiền.</span>'
 +sel('Sub-stage','Chọn L8A, L8B hoặc L8C…',True,'Bắt buộc khi chuyển sang L8.')
 +'<div class="hmt-alert hmt-alert-warning" role="alert">'+WARN+'<span><b>Chuyển L8 không hoàn tác được.</b> Sau khi chuyển, cơ hội không quay lại L7 và không có thanh Hoàn tác.</span></div>'
 '<label style="display:flex;gap:8px;align-items:flex-start;font-size:14px;cursor:pointer"><input type="checkbox" data-ix="l8ok" style="margin-top:3px"> <span>Tôi xác nhận: Chuyển L8 không hoàn tác được</span></label>'
 +note('Ví dụ: PH đã chuyển khoản đặt cọc 2.000.000đ')+FOOT)
CFG_TPL = r"""    const CFG = { ts09:true, link:'Mở bản ghi.',
  step:(b, x) => { x.toast('Biến thể hộp thoại chuyển giai đoạn: xem hộp đang mở.'); return true; },
  onPick:(l, v, d, x) => { CHK(d); },
  dlgAction:(b, d, i, x) => { if (b.hasAttribute('data-openpkt')) { x.toast('Mở phiếu PKT000112 (TS-17).'); return true; } return false; },
  check:(l, d, x) => { const r = x.q('.hmt-select span', d); const rv = r ? x.tx(r) : ''; const nt = x.q('textarea', d); const cb = x.q('input[data-ix=l8ok]', d);
    if (/^Khác$/.test(rv) && !(nt && nt.value.trim())) return 'Chọn “Khác” thì phải ghi chú.'; if (cb && !cb.checked) return 'Tick xác nhận “Chuyển L8 không hoàn tác được”.'; return ''; },
  after:(l, i, d, x) => { const to = d.getAttribute('data-to'); const st = x.qa('.hmt-stage .hmt-step').filter(z => x.tx(z).indexOf(to) === 0)[0]; if (st) { x.qa('.hmt-stage .hmt-step').forEach(z => z.removeAttribute('aria-current')); st.setAttribute('aria-current', 'step'); }
    const r = x.q('.hmt-select span', d); return 'Đã chuyển sang ' + (st ? x.tx(st) : to) + (r ? ' (' + x.tx(r) + ')' : '') + '. Lịch sử đã ghi, không có Hoàn tác.'; },
  init:x => { const sc = () => { const c = x.q('.hmt-stage [aria-current]'); if (c) c.parentElement.scrollLeft = Math.max(0, c.offsetLeft - 240); }; sc(); setTimeout(sc, 300); setTimeout(sc, 900); ['input', 'change'].forEach(t => document.addEventListener(t, e => { const tg = (e.composedPath && e.composedPath()[0]) || e.target; const d = tg && tg.closest && tg.closest('.hmt-dialog'); if (d) { CHK(d); setTimeout(() => CHK(d), 40); } }, true)); x.qa('.hmt-dialog').forEach(d => CHK(d)); setTimeout(() => x.qa('.hmt-dialog').forEach(d => CHK(d)), 300); } };
function CHK(d) { const ok = d.querySelector('[data-ok]'); if (!ok) return; const sp = d.querySelector('.hmt-select span'); if (!sp) return; const v = sp.classList.contains('hmt-ph') ? '' : (sp.textContent || '').trim();
  const kh = d.querySelector('[data-khac]'); if (kh) kh.style.display = /^Khác$/.test(v) ? '' : 'none';
  const nt = d.querySelector('textarea'); const cb = d.querySelector('input[data-ix=l8ok]');
  const opt = !!d.querySelector('[data-optional]'); ok.disabled = !((v || opt) && (!/^Khác$/.test(v) || (nt && nt.value.trim())) && (!cb || cb.checked)); }
function SETSTAGE(x) { const n = __STAGE__; const lock = __LOCK__; x.qa('.hmt-stage .hmt-step').forEach((b, k) => { const i = k + 1; const lb = x.tx(b); b.removeAttribute('aria-current');
    if (i < n) { b.className = 'hmt-step hmt-step-past'; b.title = lb + ': đã qua, cơ hội không lùi giai đoạn'; if (!b.querySelector('svg')) b.insertAdjacentHTML('afterbegin', lock); }
    else { if (i === 6) return; b.className = 'hmt-step'; const sv = b.querySelector('svg'); if (sv) sv.remove(); if (i === n) b.setAttribute('aria-current', 'step'); } });
  const ss = x.q('#sub-st span'); if (ss) ss.textContent = __SUB__; }
"""
lock=open('lockpath.txt').read()
NAMES=['L1 Khách hàng mới','L2 Chưa liên hệ được','L3 Không có nhu cầu','L4 Khách hàng tiềm năng','L5 Đồng ý tham gia test','L6 Đã tham gia test','L7 Tư vấn','L8 Đăng ký học']
def STATIC(s,n,sub,nkt):
    h_end=s.find('<script type="text/x-dc"'); h=s[:h_end]; rest=s[h_end:]
    i=h.find('<nav class="hmt-stage"'); i=h.find('>',i)+1; j=h.find('</nav>',i)
    bs=[]
    for k,nm in enumerate(NAMES,1):
        if k<n: bs.append('<button class="hmt-step hmt-step-past" type="button" title="%s: đã qua, cơ hội không lùi giai đoạn">%s%s</button>'%(nm,lock,nm))
        elif k==n: bs.append('<button class="hmt-step" type="button" aria-current="step">%s</button>'%nm)
        elif k==6: bs.append('<button class="hmt-step hmt-step-past" type="button" title="%s: hệ thống tự đổi khi phiếu test Hoàn thành">%s%s</button>'%(nm,lock,nm))
        elif k==8: bs.append('<button class="hmt-step" type="button" title="%s: chọn tay sau khi đã thu tiền">%s</button>'%(nm,nm))
        else: bs.append('<button class="hmt-step" type="button">%s</button>'%nm)
    h=h[:i]+''.join(bs)+h[j:]
    h=re.sub(r'(<button id="sub-st"[^>]*><span>)[^<]*(</span>)',lambda m:m.group(1)+sub+m.group(2),h,count=1)
    h=h.replace('<span><b>1</b><span>Kiểm tra</span></span>','<span><b>%d</b><span>Kiểm tra</span></span>'%nkt,1).replace('Kiểm tra đầu vào (1)','Kiểm tra đầu vào (%d)'%nkt,1)
    if n<5:
        k=h.find('Tạo lịch Test</button>'); b=h.rfind('<button',0,k)
        tag=h[b:h.find('>',b)+1]
        h=h[:b]+tag.replace('<button','<button disabled title="Chuyển cơ hội sang L5 trước"',1)+h[h.find('>',b)+1:]
    return h+rest

i0=base.find('    const CFG = { ts09:true'); i1=base.find("const ROOT = document.querySelector('[data-ix=root]');")
s0=base.find('<div class="hmt-scrim"'); s1=base.find('</x-dc>')
scrim_open=base[s0:base.find('>',s0)+1]
for name,v in V.items():
    s=base
    cfg=CFG_TPL.replace('__STAGE__',str(v['stage'])).replace('__LOCK__',repr(lock)).replace('__SUB__',repr(v['sub']))
    s=s[:i0]+cfg+s[i1:]
    s0=s.find('<div class="hmt-scrim"'); s1=s.find('</x-dc>')
    # giữ nguyên khung ngoài: scrim + dialog + đóng div của trang
    tail=s[s0:s1]; close_count=tail.count('<div')-tail.count('</div')  # should be 0
    s=s[:s0]+scrim_open+dlg(v['title'],v['to'],v['body'],v['ok'],v.get('dis',True))+'</div></div>\n'+s[s1:]
    s=STATIC(s,v['stage'],v['sub'],v['nkt'])
    s=s.replace('Chị Lê Thu Hằng · Lê Gia Huy · Toán lớp 9',v['head'])
    open(P+name+'.dc.html','w').write(s); print('wrote',name)
# TS09d: hộp cũ "sang L5, thiếu tên và năm sinh học sinh" trên một cơ hội khác ở L4, chưa có học sinh
s=base
s=s.replace('Cơ hội CO000121 · Chị Lê Thu Hằng · Toán lớp 9 · đang ở L4 Khách hàng tiềm năng','Cơ hội CO000137 · Chị Phan Thu Hà · Toán lớp 7 · đang ở L4 Khách hàng tiềm năng')
s=s.replace("'Đã chuyển CO000121 sang L5 Đồng ý tham gia test. Lịch sử đã ghi.'","'Đã chuyển CO000137 sang L5 Đồng ý tham gia test. Lịch sử đã ghi, không có Hoàn tác.'")
s=s.replace('Chị Lê Thu Hằng · Lê Gia Huy · Toán lớp 9','Chị Phan Thu Hà · Toán lớp 7')
h_end=s.find('<script type="text/x-dc"'); s=s[:h_end].replace('Chị Lê Thu Hằng','Chị Phan Thu Hà').replace('0912 000 121','0983 000 137')+s[h_end:]
s=s[:h_end if False else 0]+s
h_end=s.find('<script type="text/x-dc"'); s=s[:h_end].replace('Chị Hằng','Chị Hà').replace('Gửi báo giá lớp Toán 9','Gửi báo giá lớp Toán 7')+s[h_end:]
s=STATIC(s,4,'L4B Tiềm năng, cần tư vấn thêm',0)
open(P+'TS09d.dc.html','w').write(s); print('wrote TS09d')

import sys
if 'ts15' in sys.argv:
    t=open(P+'TS15.dc.html').read(); t=STATIC(t,6,'L6A Có kết quả, cần phân loại',1); open(P+'TS15.dc.html','w').write(t); print('TS15 bg L6A')
