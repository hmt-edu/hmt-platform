import re,json
B='live15/project/'
s0=open(B+'TS16.dc.html',encoding='utf-8').read()
def rep(s,a,b,cnt=1):
    assert s.count(a)==cnt,(a[:70],s.count(a)); return s.replace(a,b)
# ---- dữ liệu chung
ROOM={'PKT000105':'P101','PKT000112':'P102','PKT000118':'Online','PKT000119':'','PKT000121':'P101','PKT000103':'P102','PKT000099':'P201','PKT000122':'Online'}
def addroom(m):
    r=m.group(0); code=re.search(r'PKT\d+',r).group(0)
    r=r.replace('<tr>','<tr data-room="%s">'%ROOM[code],1)
    if code=='PKT000119': r=r.replace('<td class="hmt-num"><span class="hmt-help">Chưa có lịch</span></td>','<td class="hmt-num">13/10/2026 17:00</td>',1)
    return r
b0=s0.find('<tbody'); b1=s0.find('</tbody>')
if 'data-room' not in s0:
    s0=s0[:b0]+re.sub(r'<tr><td><label.*?</tr>',addroom,s0[b0:b1],flags=re.S)+s0[b1:]
# ---- nút Kanban trong nhóm Kiểu xem
KSVG='<svg class="hmt-ic " viewBox="0 0 24 24" aria-hidden="true"><path d="M6 5v11" /> <path d="M12 5v6" /> <path d="M18 5v14" /></svg>'
if 'aria-label="Kanban"' not in s0:
    s0=rep(s0,'<button type="button" aria-label="Calendar" title="Calendar">','<button type="button" aria-label="Kanban" title="Kanban">'+KSVG+'</button><button type="button" aria-label="Calendar" title="Calendar">')
s0=re.sub(r"views:\{[^}]*\}","views:{'Kanban':'Chuyển sang Kanban phiếu kiểm tra (TS-16b, xem vùng bên cạnh).','Calendar':'Chuyển sang Calendar phiếu kiểm tra (TS-16c, xem vùng bên cạnh).'}",s0,count=1)
open(B+'TS16.dc.html','w',encoding='utf-8').write(s0)
common=open('scripts/ts16_common.js',encoding='utf-8').read()
def variant(kind):
    s=s0
    a=s.index('<div class="hmt-content"><div class="hmt-table-wrap">'); b=s.index('</tbody></table></div></div>',a)+len('</tbody></table></div></div>')
    tbl=s[a:b].replace('<div class="hmt-content"><div class="hmt-table-wrap">','<div class="hmt-table-wrap" style="display:none">',1)
    tbl=tbl[:tbl.rindex('</div>')]
    host='<div class="hmt-kan" style="min-height:0"></div>' if kind=='b' else '<div class="hmt-calhost"></div>'
    s=s[:a]+'<div class="hmt-content" style="min-height:0;overflow:auto">'+host+tbl+'</div>'+s[b:]
    s=rep(s,'<button type="button" aria-label="Danh sách" title="Danh sách" aria-pressed="true">','<button type="button" aria-label="Danh sách" title="Danh sách">')
    tgt='Kanban' if kind=='b' else 'Calendar'
    s=rep(s,'<button type="button" aria-label="%s" title="%s">'%(tgt,tgt),'<button type="button" aria-label="%s" title="%s" aria-pressed="true">'%(tgt,tgt))
    s=re.sub(r"views:\{[^}]*\}","views:{'Danh sách':'Chuyển sang Danh sách (TS-16, xem vùng bên cạnh).','%s':'Chuyển sang %s phiếu kiểm tra (%s, xem vùng bên cạnh).'}"%(('Calendar','Calendar','TS-16c') if kind=='b' else ('Kanban','Kanban','TS-16b')),s,count=1)
    s=re.sub(r'<title>[^<]*</title>','<title>TS-16%s Phiếu kiểm tra %s</title>'%(kind,'Kanban' if kind=='b' else 'Calendar'),s,count=1)
    s=rep(s,"    tr.style.display = show ? '' : 'none'; if (show) { vis++; gcount++; }","    tr._show = show; tr.style.display = show ? '' : 'none'; if (show) { vis++; gcount++; }")
    s=rep(s,"  pagerSync(vis);\n  let em = q('.ix-empty');","  pagerSync(vis);\n  if (CFG.calSync) CFG.calSync(vis);\n  let em = q('.ix-empty');")
    logic=open('scripts/ts16%s_logic.js'%kind,encoding='utf-8').read()
    m="document.addEventListener('click', sbClick);"; assert s.count(m)==1
    s=s.replace(m,m+"\n"+common+"\n"+logic)
    open(B+'TS16%s.dc.html'%kind,'w',encoding='utf-8').write(s)
variant('b'); variant('c')
c=json.load(open(B+'canvas.json',encoding='utf-8'))
base=c['boards']['TS15.dc.html']
for k,x,t in [('TS16b.dc.html',4560,'TS-16b · Phiếu kiểm tra · kanban'),('TS16c.dc.html',6080,'TS-16c · Phiếu kiểm tra · calendar')]:
    nb=dict(base); nb['x']=x; nb['title']=t; c['boards'][k]=nb
    if k not in c['order']: c['order'].append(k)
json.dump(c,open(B+'canvas.json','w',encoding='utf-8'),ensure_ascii=False,indent=1)
print('ok')
