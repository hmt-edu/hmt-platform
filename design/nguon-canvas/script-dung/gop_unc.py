import re,json,collections
rows=collections.OrderedDict()
dot=''
for l in open('/home/claude/hmt-platform/docs/design/ban-do-man-hinh.md',encoding='utf8'):
    if l.startswith('## '): dot=l.strip('# \n')
    if not l.startswith('|'): continue
    c=[x.strip() for x in l.strip().strip('|').split('|')]
    if re.fullmatch(r'[A-Z]+-\d+',c[0]) and len(c)>=4:
        rows[c[0]]=dict(name=re.sub(r'\*\*.*','',c[1]).strip(),lvl=c[3],dot=dot)
print(len(rows))
drawn=set('BH-01 BH-02 BH-03 BH-05 BH-06 BH-07 BH-08 BH-09 CHUNG-11 CHUNG-14 GD-01 GD-02 GD-03 GD-04 GD-05 GD-06 GD-07 KH-01 KH-02 KH-03 KH-04 KH-05 KH-06 KH-07 LOP-01 LOP-02 LOP-03 TC-01 TC-02 TC-03 TC-04 TC-05 TC-07 TC-08 TC-09 TC-10 TC-11 TC-13 TC-15 TS-01 TS-02 TS-03 TS-04 TS-06 TS-07 TS-08 TS-09 TS-10 TS-11 TS-13 TS-15 TS-16 TS-17'.split())
# bổ sung theo nội dung khung
drawn|=set('CHUNG-01 CHUNG-02 CHUNG-03 CHUNG-04 CHUNG-05 CHUNG-06 CHUNG-07 CHUNG-08 CHUNG-09 CHUNG-25 CHUNG-12 CHUNG-19 CHUNG-26 CHUNG-16 QT-05 QT-06 QT-07 QT-09 QT-10'.split())
muc_c_user='BH-04 BH-10 BH-11 TC-06 TC-12 TC-14 TC-16 LOP-09 BUOI-14 TT-03'.split()
p5b_tiep=[f'LOP-{i:02d}' for i in (4,5,6,7,8,10)]+[f'BUOI-{i:02d}' for i in range(1,14)]+['TT-01','TT-02']
out=[]
for k,v in rows.items():
    if k in drawn: continue
    m=re.search(r'Đợt (5\.\d)',v['dot']); g=re.search(r'giai đoạn (\d)',v['dot'])
    dot=m.group(1) if m else '?'; gd=g.group(1) if g else '?'
    if k in muc_c_user: r='Mức C, không vẽ'
    elif k in p5b_tiep: r='Đang làm tiếp (P5b)'
    elif v['lvl']=='C' and gd in '012': r='Mức C, không vẽ'
    elif gd in '012': r='Chưa vẽ (giai đoạn đã mở)'
    else: r='Giai đoạn sau'
    out.append(dict(code=k,name=v['name'],lvl=v['lvl'],dot=dot,gd=gd,reason=r))
json.dump(out,open('unc.json','w'),ensure_ascii=False,indent=1)
print(len(out),collections.Counter(o['reason'] for o in out))
for r in ['Mức C, không vẽ','Chưa vẽ (giai đoạn đã mở)','Đang làm tiếp (P5b)']:
    print(r,[ (o['code'],o['gd']) for o in out if o['reason']==r])
print(collections.Counter((o['dot'],o['gd']) for o in out))
