import re,sys
B='live13/project/'
tb=open(B+'TS11b.dc.html',encoding='utf-8').read()
k5=open('artifact-files/c87a9b88-5e30-4b22-a9db-0a33e933374b/project/TS11_K5.dc.html',encoding='utf-8').read()  # original static K5 (v with markup)
def rep(s,a,b,cnt=1):
    assert s.count(a)==cnt,(a[:60],s.count(a)); return s.replace(a,b)
# ---- calendar markup from static K5
i=k5.index('<div class="hmt-calv"'); 
# simpler: balanced scan returning end index of final </div>
depth=0; pos=i
for m in re.finditer(r'</?div\b[^>]*>',k5[i:]):
    depth += -1 if m.group(0).startswith('</') else 1
    if depth==0: pos=i+m.end(); break
cal=k5[i:pos].replace('<span class="hmt-tag">Mới</span>','<span class="hmt-tag">Chưa làm</span>')
# ---- events -> mirror rows
cols=re.split(r'<div class="hmt-calv-col',cal)[1:]
evs=[]
TY=['Gọi điện','Zalo','Email','Gặp trực tiếp','Thu tiền']
cls2ty={'hmt-ev-call':'Gọi điện','hmt-ev-zalo':'Zalo','hmt-ev-email':'Email','hmt-ev-meet':'Gặp trực tiếp','hmt-ev-pay':'Thu tiền'}
cyc=0
for ci,c in enumerate(cols):
    for m in re.finditer(r'<a class="hmt-ev ([^"]*)"[^>]*title="([^"]+)"',c):
        cl,title=m.group(1),m.group(2)
        mm=re.match(r'^([^:]+): ([^·,]+?)(?: · ([^,·]+?))?(?: · ([^,]+?))?, (\d\d:\d\d)–(\d\d:\d\d)$',title)
        assert mm,title
        st,name,code,extra,t1,t2=mm.groups()
        if st in('Hoàn thành','Huỷ'):
            ty=TY[cyc%5]; cyc+=1; status=st
        else:
            ty=st; status='Chưa làm'
        if extra and extra.startswith('CS'): extra=None
        if not code or not re.match(r'(CO|LD)\d{6}',code): code=extra if extra and re.match(r'(CO|LD)',extra or '') else code
        evs.append(dict(ci=ci,ty=ty,status=status,name=name.strip(),code=code,extra=extra,t1=t1))
def row(i,e):
    d=12+e['ci']; kind='Lead' if e['code'].startswith('LD') else 'Cơ hội'
    title=e['extra'] if e['extra'] and not re.match(r'(CO|LD)\d',e['extra']) else e['ty']+' '+e['name']
    title=title[0].upper()+title[1:]
    return ('<tr data-ev="%d"><td><label class="hmt-hit"><input type="checkbox" aria-label="Chọn"></label></td><td><span style="display:inline-flex;align-items:center;gap:6px">%s</span></td><td><a href="#">%s</a></td><td><span class="hmt-help">%s</span> <span class="hmt-code">%s</span></td><td class="hmt-num">%02d/10/2026 %s</td><td>Trần Thu Hà</td><td><span class="hmt-tag ">%s</span></td><td></td></tr>'%(i,e['ty'],title,kind,e['code'],d,e['t1'],e['status']))
rows=''.join(row(i,e) for i,e in enumerate(evs))
# ---- content region of TS11b
a=tb.index('<div class="hmt-content"><div class="hmt-table-wrap">'); b=tb.index('</tbody></table></div></div>',a)+len('</tbody></table></div></div>')
t_head=re.search(r'<thead>.*?</thead>',tb[a:b],re.S).group(0)
newc='<div class="hmt-content" style="min-height:0;overflow:auto"><div class="hmt-table-wrap" style="display:none"><table class="hmt-table">'+t_head+'<tbody>'+rows+'</tbody></table></div>'+cal+'</div>'
s=tb[:a]+newc+tb[b:]
# ---- header: keep K5's Tạo/Nhập/Xuất and 2-view toggle (Danh sách + Calendar*)
hb=re.search(r'<div class="bz">.*?</div>',k5,re.S).group(0)
s=re.sub(r'<div class="bz">.*?</div>',lambda m:hb,s,count=1,flags=re.S)
s=rep(s,'<button type="button" aria-label="Danh sách" title="Danh sách" aria-pressed="true">','<button type="button" aria-label="Danh sách" title="Danh sách">')
s=rep(s,'<button type="button" aria-label="Calendar" title="Calendar">','<button type="button" aria-label="Calendar" title="Calendar" aria-pressed="true">')
# default chip "Của tôi: Tôi phụ trách" like TS-01
s=rep(s,'aria-label="Của tôi"><button type="button" aria-pressed="false">Tôi phụ trách','aria-label="Của tôi"><button type="button" aria-pressed="true">Tôi phụ trách')
s=rep(s,'<title>','<title>',1) if '<title>' in s else s
s=re.sub(r'<title>[^<]*</title>','<title>K5 Calendar (Lịch hẹn, tuần)</title>',s,count=1)
# ---- engine patches
s=rep(s,"const TODAY = '14/10/2026';","const TODAY = '13/10/2026';")
s=rep(s,"const TODAYD = new Date(2026, 9, 14);","const TODAYD = new Date(2026, 9, 13);")
s=rep(s,"t = dayN(new Date(2026, 9, 14))","t = dayN(new Date(2026, 9, 13))")
s=rep(s,"function rowCat(tr, gname) {\n  const cells = qa('td', tr);","function rowCat(tr, gname) {\n  const cells = qa('td', tr);\n  if (CFG.calendar) { if (/Hoàn thành|Huỷ/.test(tx(cells[6]))) return ''; const m = /(\\d{2})\\/(\\d{2})\\/(\\d{4})/.exec(tx(cells[4])); if (!m) return ''; const k = m[3] + m[2] + m[1]; return k < '20261013' ? 'Quá hạn' : k === '20261013' ? 'Hôm nay' : 'Sắp tới'; }")
s=rep(s,"    tr.style.display = show ? '' : 'none'; if (show) { vis++; gcount++; }","    tr._show = show; tr.style.display = show ? '' : 'none'; if (show) { vis++; gcount++; }")
s=rep(s,"  pagerSync(vis);\n  let em = q('.ix-empty');","  pagerSync(vis);\n  if (CFG.calSync) CFG.calSync(vis);\n  let em = q('.ix-empty');")
# CFG: calendar flag
s=rep(s,"layout2:true, noun:'lịch hẹn',","layout2:true, calendar:true, noun:'lịch hẹn',")
s=re.sub(r"views:\{'Calendar':'[^']*','Kanban':'[^']*'\}","views:{'Danh sách':'Chuyển sang Danh sách (TS-11b, xem vùng bên cạnh).','Kanban':'Chuyển sang Kanban (TS-11c, xem vùng bên cạnh).'}",s,count=1)
s=rep(s,"const d = new Date(2026, 9, 14 + (wk - dayN(TODAYD)) + k);","const d = new Date(2026, 9, 13 + (wk - dayN(TODAYD)) + k);")
s=rep(s,"if (/Hôm nay/.test(s)) return new Date(2026, 9, 14, hh, mi);","if (/Hôm nay/.test(s)) return new Date(2026, 9, 13, hh, mi);")
s=rep(s,"{ 'Hôm nay': '2026-10-14', 'Ngày mai': '2026-10-15', 'Ngày kia': '2026-10-16',","{ 'Hôm nay': '2026-10-13', 'Ngày mai': '2026-10-14', 'Ngày kia': '2026-10-15',")
# scripts: calendar logic appended before end of componentDidMount
logic=open('scripts/k5_logic.js',encoding='utf-8').read()
marker="document.addEventListener('click', sbClick);"
assert s.count(marker)==1
s=s.replace(marker,marker+"\n"+logic)
open(B+'TS11_K5.dc.html','w',encoding='utf-8').write(s)
print('events',len(evs)); 
for e in evs: print(e)
