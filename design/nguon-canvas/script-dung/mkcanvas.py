import json,re,os,sys
P=sys.argv[1]
def title(f):
    s=open(os.path.join(P,f),encoding='utf-8').read()
    m=re.search(r'<title>(.*?)</title>',s,re.S); t=m.group(1).strip() if m else ''
    code=f[:-8]
    return t if t.startswith(code) else (f"{code} · {t}" if t else code)
PC=(1440,1000); MB=(390,844)
def mob(n): return '_mb_' in n or n.startswith('K1m_') or n.startswith('K4e')
boards={}; order=[]; notes={}
y=0
def row(names,y):
    x=0
    for n in names:
        f=n+'.dc.html'; w,h=MB if mob(n) else PC
        e={"x":x,"y":y,"w":w,"h":h,"title":title(f)}
        if mob(n): e["radius"]=28
        else: e["expand"]="fill"
        boards[f]=e; order.append(f); x+=w+80
    return x-80
def region(rid,name,status,rows,y):
    width=0; y0=y
    for i,r in enumerate(rows):
        width=max(width,row(r,y)); y+=1430
    notes[rid+"_t"]={"x":0,"y":y0-300,"text":name,"kind":"title1","maxW":max(width,1840)}
    notes[rid+"_s"]={"x":0,"y":y0-200,"text":status,"fill":"orange","w":1400,"maxH":150}
    return y+700
regions=[
 ("P0","P0 · KHUÔN CHUNG","Đã duyệt: K1–K5, K4b–K4e, K07b/c, K09b, K0x. Các khung bổ sung của K1 (Filters, Group By, Cột, Favorites, ô tìm toàn hệ thống, chuông): chờ anh xem.",[
  ["K1","K2","K3","K4","K5"],
  ["K4b","K4c","K4d","K07b","K07c","K09b","K0x","K4e1","K4e3","K4e2"],
  ["K1_loc","K1_loc_chip","K1_loc_nc","K1_loc_nc0","K1_nhom","K1_nhom_bang","K1_nhom0","K1_cot"],
  ["K1_fav","K1_fav_luu","K1_fav0","K1_tim","K1_tim_go","K1_tim0","K1_chuong","K1_chuong0"],
  ["K1m_loc","K1m_nhom","K1m_cot","K1m_fav","K1m_tim_dong","K1m_tim","K1m_tim0"]]),
 ("P1","P1 · ĐĂNG NHẬP & KHUNG CỔNG","Đã duyệt 10 màn đăng nhập (dựng lại nguyên trạng v3). Khung các cổng và Đợt 3 (không có quyền, module chưa bật, 404, lỗi hệ thống): chưa vẽ.",[]),
 ("P2","P2 · QUẢN TRỊ & CHUNG","Đã duyệt: Cấu hình, Ma trận quyền. Lịch sử phiên bản Ma trận quyền: chờ anh xem. Các màn QT còn lại: chưa vẽ.",[["CauHinh","MaTranQuyen","MaTranQuyen_ls","MaTranQuyen_ct"]]),
]
files=sorted(f[:-8] for f in os.listdir(P) if f.endswith('.dc.html'))
dn=[]
for k in range(1,11):
    g=[f for f in files if f.startswith(f"DN{k:02d}_")]
    dn.append([f for f in g if '_pc_' in f]+[f for f in g if '_mb_' in f])
regions[1]=(regions[1][0],regions[1][1],regions[1][2],dn)
y=0
for r in regions: y=region(*r,y)
assert len(boards)==len(files)==84, (len(boards),len(files), set(files)-set(b[:-8] for b in boards))
out={"v":3,"createdOnFiles":{"v":1,"at":"2026-10-16T04:10:00Z"},"title":"HMT Platform","launch":{"view":"canvas"},"pages":[],
 "boards":boards,"order":order,"notes":notes,
 "designSystems":[{"title":"HMT Platform","namespace":"hmt","artifact":"https://claude.ai/artifact/3Yco5qmVbyDiyfZm9HcJqN","version":"1792122824-3516","copiedAt":"2026-10-16T04:10:00Z"}]}
json.dump(out,open(os.path.join(P,'canvas.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print(len(boards), y)
