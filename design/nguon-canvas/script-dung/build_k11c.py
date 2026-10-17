import re
B='live13/project/'
tb=open(B+'TS11b.dc.html',encoding='utf-8').read()
def rep(s,a,b,cnt=1):
    assert s.count(a)==cnt,(a[:60],s.count(a)); return s.replace(a,b)
s=tb
a=s.index('<div class="hmt-content"><div class="hmt-table-wrap">'); b=s.index('</tbody></table></div></div>',a)+len('</tbody></table></div></div>')
tbl=s[a:b]
tbl=tbl.replace('<div class="hmt-content"><div class="hmt-table-wrap">','<div class="hmt-table-wrap" style="display:none">',1)
tbl=tbl[:tbl.rindex('</div>')]  # drop closing of .hmt-content
newc='<div class="hmt-content"><div class="hmt-kan" style="min-height:0"></div>'+tbl+'</div>'
s=s[:a]+newc+s[b:]
# toggle: Danh sách | Kanban* | Calendar
s=rep(s,'<button type="button" aria-label="Danh sách" title="Danh sách" aria-pressed="true">','<button type="button" aria-label="Danh sách" title="Danh sách">')
s=rep(s,'<button type="button" aria-label="Kanban" title="Kanban">','<button type="button" aria-label="Kanban" title="Kanban" aria-pressed="true">') if '<button type="button" aria-label="Kanban" title="Kanban">' in s else s
s=re.sub(r'<title>[^<]*</title>','<title>TS-11c Lịch hẹn Kanban</title>',s,count=1)
s=rep(s,'aria-label="Của tôi"><button type="button" aria-pressed="false">Tôi phụ trách','aria-label="Của tôi"><button type="button" aria-pressed="true">Tôi phụ trách')
s=rep(s,"    tr.style.display = show ? '' : 'none'; if (show) { vis++; gcount++; }","    tr._show = show; tr.style.display = show ? '' : 'none'; if (show) { vis++; gcount++; }")
s=rep(s,"  pagerSync(vis);\n  let em = q('.ix-empty');","  pagerSync(vis);\n  if (CFG.calSync) CFG.calSync(vis);\n  let em = q('.ix-empty');")
s=re.sub(r"views:\{'Calendar':'[^']*'(?:,'Kanban':'[^']*')?\}","views:{'Danh sách':'Chuyển sang Danh sách (TS-11b, xem vùng bên cạnh).','Calendar':'Chuyển sang Calendar (TS-11 · K5, xem vùng bên cạnh).'}",s,count=1)
logic=open('scripts/k11c_logic.js',encoding='utf-8').read()
m="document.addEventListener('click', sbClick);"; assert s.count(m)==1
s=s.replace(m,m+"\n"+logic)
open(B+'TS11c.dc.html','w',encoding='utf-8').write(s)
print('ok')
