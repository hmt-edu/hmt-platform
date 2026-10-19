import json,re,os,shutil,collections,html
from gop_newframes import *
W='/tmp/claude-0/-home-claude/a26c5bc7-404f-5046-b19c-da81f56bab94/scratchpad/work/'
M=W+'merge/'
P4=json.load(open(M+'live_p4/project/canvas.json'))
P5A=json.load(open(M+'live_p5a/project/canvas.json'))
P5B=json.load(open(M+'live_p5b/project/canvas.json'))
DROP={'TS18.dc.html','TS19.dc.html'}
K4F=dict(x=0,y=0,w=1440,h=1000,title='K4f · Hộp thoại gộp trùng',expand='fill')
B={}  # name -> (board, source)
for n,v in P4['boards'].items():
    if n in DROP: continue
    B[n]=(dict(v),'p4')
B['K4f.dc.html']=(dict(K4F),'p4')
for n,v in P5A['boards'].items(): B[n]=(dict(v),'p5a')
for n,v in P5B['boards'].items(): B[n]=(dict(v),'p5b')
N={}
for k,v in P4['notes'].items(): N[k]=(dict(v),'p4')
for k,v in P5A['notes'].items(): N['p5a_'+k]=(dict(v),'p5a')
for k,v in P5B['notes'].items(): N['p5b_'+k]=(dict(v),'p5b')
def nm(b): return b[:-8]
def names(pred): return [n for n in B if pred(nm(n))]
G={}
G['P0']=dict(b=names(lambda s:re.match(r'K\d|K0x',s) and s!='K4f'),n=['P0_s'])
G['P1']=dict(b=names(lambda s:s.startswith('DN')),n=['P1_s','dn06_hoan'])
G['P2']=dict(b=names(lambda s:s=='CauHinh' or s.startswith('MaTran')),n=['P2_s'])
G['P4']=dict(b=names(lambda s:s.startswith('KH')),n=['P4_s'])
cnt={k:len(v['b']) for k,v in G.items()}
cnt['P0']+=2
# P3
P3S=[('Lead','Nhom_P3_Lead','Lead','TS-01, 02, 03, 13',['TS01','TS01b','TS02','TS03','TS13'],[]),
 ('Lịch hẹn','Nhom_P3_LichHen','Lịch hẹn','TS-11',['TS11_K5','TS11b','TS11c'],['ts11']),
 ('Cơ hội','Nhom_P3_CoHoi','Cơ hội','TS-06 đến TS-09d',['TS06','TS07_K1','TS07_K2','TS08_K3','TS08b_K3','TS09','TS09a','TS09b','TS09c','TS09d'],['ts0708']),
 ('Phiếu kiểm tra','Nhom_P3_PhieuKT','Phiếu kiểm tra','TS-15 đến TS-17',['TS15','TS16','TS16b','TS16c','TS17'],[]),
 ('Gộp trùng và Nhập lô','Nhom_P3_GopTrung','Gộp trùng và Nhập lô','TS-04, TS-10',['TS04','TS10','TS10b','TS10c'],[])]
cnt['P3']=sum(len(s[4]) for s in P3S)
assert all(x+'.dc.html' in B for s in P3S for x in s[4])
# P5a
a=lambda n:B[n][0]['y']
p5a_all=[n for n in B if B[n][1]=='p5a']
GHI='P5a_Ghi_chu.dc.html'
p5a_head=['P5a_Tong_quan.dc.html']
p5a_bh=[n for n in p5a_all if nm(n).startswith('BH')]
p5a_tc=[n for n in p5a_all if nm(n).startswith('TC')]
assert len(p5a_head)+len(p5a_bh)+len(p5a_tc)+1==86
p5a_nh=['p5a_s1','p5a_n2']; p5a_nbh=['p5a_t3','p5a_t4','p5a_t5']; p5a_ntc=['p5a_t%d'%i for i in range(6,13)]
cnt['P5a']=len(p5a_head)+len(p5a_bh)+len(p5a_tc)
# P5b
p5b_all=[n for n in B if B[n][1]=='p5b']
p5b_head=['P5b_Tong_quan.dc.html']
p5b_gd=[n for n in p5b_all if nm(n).startswith('GD')]
p5b_lop=[n for n in p5b_all if nm(n).startswith('LOP')]
assert len(p5b_head)+len(p5b_gd)+len(p5b_lop)==53
cnt['P5b']=53
cnt_sau=2
# ---- layout
out_b={}   # name -> board
out_n={}
order=[]
helper={}  # name->html
cur=0
def add_helper(fname,html_,w,h,title,x=0,y=None):
    global cur
    y=cur if y is None else y
    out_b[fname]=dict(x=x,y=y,w=w,h=h,title=title,expand='fill',is_interactive=True) if False else dict(x=x,y=y,w=w,h=h,title=title,expand='fill')
    helper[fname]=html_; order.append(fname)
def put(bnames,nnames,top,xshift=0):
    """đặt khối: giữ vị trí tương đối, dịch sao cho đỉnh = top. trả đáy."""
    ys=[B[n][0]['y'] for n in bnames]+[N[k][0]['y'] for k in nnames]
    dy=top-min(ys); bot=top
    for n in bnames:
        b=dict(B[n][0]); b['y']+=dy; out_b[n]=b; order.append(n); bot=max(bot,b['y']+b['h'])
    for k in nnames:
        v=dict(N[k][0]); v['y']+=dy; out_n[k]=v; bot=max(bot,v['y']+v.get('maxH',100))
    return bot
def title(fname,html_,h,title_):
    global cur
    add_helper(fname,html_,1440,h,title_); cur+=h+80
def sub(fname,name,count_txt,note=''):
    global cur
    add_helper(fname,sub_frame(name,count_txt,note),1440,140,'Nhóm con · '+name); cur+=140+60
# 1 mở đầu (nội dung dựng sau, cần số đếm)
MUC_Y=cur; cur+=1000+300
# P0
title('Nhom_P0.dc.html',title_frame('P0 · Khuôn chung','%d khung'%cnt['P0'],'ok','Đã duyệt','K1–K5, K4b–K4e, K07b/c, K09b, K0x. Chờ anh xem: các khung bổ sung của K1, K4f.'),220,'Nhóm · P0 Khuôn chung')
bot=put(G['P0']['b'],G['P0']['n'],cur)+120
for i,nme in enumerate(['K4f.dc.html','P0_v5.dc.html']):
    bd=dict(B[nme][0]); bd['x']=i*1520; bd['y']=bot; out_b[nme]=bd; order.append(nme)
cur=bot+1000+300
title('Nhom_P1.dc.html',title_frame('P1 · Đăng nhập','%d khung'%cnt['P1'],'ok','Đã duyệt','10 màn đăng nhập, máy tính và điện thoại. DN06 hoãn.'),220,'Nhóm · P1 Đăng nhập')
cur=put(G['P1']['b'],G['P1']['n'],cur)+300
title('Nhom_P2.dc.html',title_frame('P2 · Cấu hình và phân quyền','%d khung'%cnt['P2'],'ok','Đã duyệt','Cấu hình, Ma trận quyền. Lịch sử phiên bản Ma trận quyền: chờ anh xem.'),220,'Nhóm · P2 Cấu hình và phân quyền')
cur=put(G['P2']['b'],G['P2']['n'],cur)+300
# P3
title('Nhom_P3.dc.html',title_frame('P3 · Tuyển sinh (TS)','%d khung'%cnt['P3'],'ok','Đã duyệt 16/10 (v48)','Lead, Lịch hẹn, Cơ hội, Phiếu kiểm tra, Gộp trùng và Nhập lô.'),220,'Nhóm · P3 Tuyển sinh')
for lab,fn,nm_,codes,bl,nl in P3S:
    add_helper(fn+'.dc.html',sub_frame(nm_,'%d khung'%len(bl),codes),1440,140,'Nhóm con · '+nm_)
    for k in nl:
        v=dict(N[k][0]); v['x']=1520; v['y']=cur; out_n[k]=v
    cur+=140+60
    for i,x in enumerate(bl):
        bd=dict(B[x+'.dc.html'][0]); bd['x']=(i%6)*1520; bd['y']=cur+(i//6)*1120; out_b[x+'.dc.html']=bd; order.append(x+'.dc.html')
    cur+=((len(bl)-1)//6+1)*1120+200
cur+=100
title('Nhom_P4.dc.html',title_frame('P4 · Khách hàng (KH)','%d khung'%cnt['P4'],'wait','Xong, chờ anh duyệt','KH-01 đến KH-07: phụ huynh, học sinh, gộp trùng.'),220,'Nhóm · P4 Khách hàng')
cur=put(G['P4']['b'],G['P4']['n'],cur)+300
# P5a
title('Nhom_P5a.dc.html',title_frame('P5a · Bán hàng (BH) và Thu chi (TC)','%d khung'%cnt['P5a'],'froze','Xong, đóng băng','Chép nguyên từ canvas P5a (v6), không sửa.'),220,'Nhóm · P5a Bán hàng và Thu chi')
cur=put(p5a_head,p5a_nh,cur)+300
sub('Nhom_P5a_BH.dc.html','Bán hàng (BH)','%d khung'%len(p5a_bh),'Báo giá, đơn hàng, chọn lớp và ngày vào lớp')
cur=put(p5a_bh,p5a_nbh,cur)+300
sub('Nhom_P5a_TC.dc.html','Thu chi (TC)','%d khung'%len(p5a_tc),'Phiếu thu, kế toán duyệt, khoản tiền vào, đối soát, phiếu chi, công nợ')
cur=put(p5a_tc,p5a_ntc+['p5a_n2'] if False else p5a_ntc,cur)+300
# P5b
title('Nhom_P5b.dc.html',title_frame('P5b · Đào tạo','%d khung'%cnt['P5b'],'work','Đang làm','Ghi danh xong; Lớp mới xong LOP-01 đến LOP-03; Buổi, Tái tục chưa làm.'),220,'Nhóm · P5b Đào tạo')
cur=put(p5b_head,['p5b_s1'],cur)+300
sub('Nhom_P5b_GD.dc.html','Ghi danh (GD)','%d khung'%len(p5b_gd),'GD-01 đến GD-07, xong')
cur=put(p5b_gd,['p5b_t2','p5b_t3','p5b_t4','p5b_t5'],cur)+300
sub('Nhom_P5b_LOP.dc.html','Lớp (LOP)','%d khung'%len(p5b_lop),'LOP-01 đến LOP-03 xong; LOP-04 đến LOP-10 làm tiếp')
cur=put(p5b_lop,['p5b_t6','p5b_n7','p5b_t8'],cur)+300
sub('Nhom_P5b_BUOI.dc.html','Buổi (BUOI)','0 khung','BUOI-01 đến BUOI-14: chưa làm, làm tiếp trong canvas này')
cur+=300
sub('Nhom_P5b_TT.dc.html','Tái tục (TT)','0 khung','TT-01 đến TT-03: chưa làm, làm tiếp trong canvas này')
cur+=300
# Giai đoạn sau
title('Nhom_Sau.dc.html',title_frame('Giai đoạn sau (chưa vẽ)','%d khung + 1 bảng tổng hợp'%cnt_sau,'none','Chưa vẽ','P13 Báo cáo, P14 Tìm kiếm và thông báo (giữ nguyên) và bảng các mã màn chưa có khung.'),220,'Nhóm · Giai đoạn sau (chưa vẽ)')
for k,x in (('p13s',0),('p14s',1520)):
    v=dict(N[k][0]); v['x']=x; v['y']=cur; out_n[k]=v
cur+=170
for nme,x in (('BaoCao.dc.html',0),('TimKiem.dc.html',1520)):
    bd=dict(B[nme][0]); bd['x']=x; bd['y']=cur; out_b[nme]=bd; order.append(nme)
CHUA_X=3040; CHUA_Y=cur
cur+=1000+300
# Ghi chú cuối
title('Nhom_GhiChu.dc.html',title_frame('Ghi chú cuối','2 khung','none','Ghi chú','Chỗ lệch, câu hỏi chờ anh, màn dừng. Khung P5a_Ghi_chu giữ nguyên từ P5a.'),220,'Nhóm · Ghi chú cuối')
GHI_Y=cur
v=dict(N['p5a_t13'][0]); v['x']=0; v['y']=cur; out_n['p5a_t13']=v
cur+=120
bd=dict(B[GHI][0]); bd['x']=0; bd['y']=cur; out_b[GHI]=bd; order.append(GHI)
GC_Y=cur
json.dump(dict(cnt=cnt,MUC_Y=MUC_Y,CHUA=(CHUA_X,CHUA_Y),GC=(1520,GC_Y),total_b=len(out_b),helpers=len(helper),order=order,b=out_b,n=out_n),open('layout.json','w'),ensure_ascii=False)
print(cnt,len(out_b),len(helper),len(out_n),len(order))
