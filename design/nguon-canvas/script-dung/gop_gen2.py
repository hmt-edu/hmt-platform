import json,collections,shutil,os,re,glob
from gop_newframes import *
from gop_build import helper,out_b,out_n,order,MUC_Y,CHUA_X,CHUA_Y,GC_Y,P4
L=json.load(open('layout.json')); cnt=L['cnt']
M='/tmp/claude-0/-home-claude/a26c5bc7-404f-5046-b19c-da81f56bab94/scratchpad/work/merge/'
W=M[:-6]
unc=json.load(open('unc.json'))
# ---- Muc_luc
rows=[('P0 · Khuôn chung','K1–K5, hộp thoại K4, trạng thái chung, trang chủ, bảng P0 v5',cnt['P0'],'ok','Đã duyệt','K1–K5, K4b–K4e, K07b/c, K09b, K0x. Chờ anh xem: khung bổ sung của K1, K4f.'),
('P1 · Đăng nhập','DN01–DN10, máy tính và điện thoại',cnt['P1'],'ok','Đã duyệt','10 màn. DN06 hoãn. Khung các cổng và Đợt 3: chưa vẽ.'),
('P2 · Cấu hình và phân quyền','Cấu hình, Ma trận quyền',cnt['P2'],'ok','Đã duyệt','Lịch sử phiên bản Ma trận quyền: chờ anh xem. Các màn QT còn lại: chưa vẽ.'),
('P3 · Tuyển sinh (TS)','Lead · Lịch hẹn · Cơ hội · Phiếu kiểm tra · Gộp trùng và Nhập lô',cnt['P3'],'ok','Đã duyệt 16/10 (v48)',''),
('P4 · Khách hàng (KH)','KH-01 đến KH-07',cnt['P4'],'wait','Xong, chờ anh duyệt',''),
('P5a · Bán hàng (BH), Thu chi (TC)','BH-01..09, TC-01..15',cnt['P5a'],'froze','Xong, đóng băng','Chép nguyên từ canvas P5a (v6).'),
('P5b · Đào tạo','Ghi danh (GD), Lớp (LOP), Buổi (BUOI), Tái tục (TT)',cnt['P5b'],'work','Đang làm','GD xong; LOP-01..03 xong; Buổi, Tái tục chưa làm.'),
('Giai đoạn sau (chưa vẽ)','P13 Báo cáo, P14 Tìm kiếm và thông báo, bảng mã màn chưa có khung','2 khung + 1 bảng','none','Chưa vẽ',''),
('Ghi chú cuối','Chỗ lệch, câu hỏi chờ anh, màn dừng','1 khung + 1 ghi chú','none','Ghi chú','')]
tot=sum(r[2] for r in rows[:7])+2+1
tr=''.join('<tr><td><b>%s</b></td><td>%s</td><td style="text-align:right">%s</td><td>%s %s</td></tr>'%(e(a),e(b),c,tag(k,s),e(n)) for a,b,c,k,s,n in rows)
inner=('<div style="padding:36px 48px"><h1 style="font-family:var(--font-heading);font-size:34px;margin:0 0 12px">HMT Platform · Mục lục</h1>'
'<p style="font-size:14px;color:var(--text-secondary);margin:0 0 18px">Canvas gộp P0 đến P5b, đọc từ trên xuống: Mục lục, P0, P1, P2, P3, P4, P5a, P5b, Giai đoạn sau, Ghi chú cuối. Mỗi nhóm có khung tiêu đề (tên, số khung, trạng thái). Số khung không tính khung tiêu đề.</p>'
'<div class="hmt-table-wrap"><table class="hmt-table t"><thead><tr><th>Nhóm</th><th>Nội dung</th><th style="text-align:right">Số khung</th><th>Trạng thái (theo nhật ký Design)</th></tr></thead><tbody>%s</tbody></table></div>'
'<h2 class="s">Lưu ý khi dùng canvas này</h2>'
'<p class="li">· Tên file khung và mã màn (TS01, KH-01…) giữ nguyên như ở ba canvas gốc; chỉ đổi vị trí trên canvas.</p>'
'<p class="li">· P5a và P5b đã chép sang đây; canvas P5a, P5b cũ vẫn giữ nguyên. Bình luận ở hai canvas cũ không chuyển sang đây.</p>'
'<p class="li">· Mã khung có hậu tố (_tai, _trong, _khong_quyen…) là trạng thái khác của cùng một màn.</p>'
'<p class="li">· Mức: A đủ trạng thái, B một trạng thái chính, C không vẽ (theo bản đồ màn hình).</p></div>')%tr
MUC=frame('HMT Platform · Mục lục',1440,1000,inner)
# ---- Chua_ve
ro={'Mức C, không vẽ':0,'Đang làm tiếp (P5b)':1,'Chưa vẽ (giai đoạn đã mở)':2,'Giai đoạn sau':3}
g=collections.OrderedDict()
for o in sorted(unc,key=lambda o:(ro[o['reason']],o['gd'],o['code'].split('-')[0],o['code'])):
    g.setdefault((o['reason'],o['gd']),[]).append(o['code'])
GDN={'0':'Giai đoạn 0 (Đợt 5.2)','1':'Giai đoạn 1 (Đợt 5.3)','2':'Giai đoạn 2 (Đợt 5.4)','3':'Giai đoạn 3 (Đợt 5.5)','4':'Giai đoạn 4 (Đợt 5.6)','5':'Giai đoạn 5 (Đợt 5.7)'}
def rtag(r):
    k={'Mức C, không vẽ':'wait','Đang làm tiếp (P5b)':'work','Chưa vẽ (giai đoạn đã mở)':'none','Giai đoạn sau':'froze'}[r]
    return tag(k,r)
trs=''
for (r,gd),codes in g.items():
    when='Giai đoạn 2, làm tiếp ở P5b' if r=='Đang làm tiếp (P5b)' else GDN[gd]
    trs+='<tr><td>%s</td><td>%s</td><td><span style="font-size:11px;color:var(--text-secondary)">%d mã</span></td><td style="line-height:1.55">%s</td></tr>'%(rtag(r),e(when),len(codes),e(', '.join(codes)))
cn=collections.Counter(o['reason'] for o in unc)
summ=' · '.join('%s: %d'%(k,cn[k]) for k in ro)
CH=frame('Mã màn chưa có khung',1440,1000,('<div style="padding:28px 40px"><h1 style="font-family:var(--font-heading);font-size:28px;margin:0 0 10px">Màn chưa vẽ</h1>'
'<p style="font-size:12.5px;color:var(--text-secondary);margin:0 0 10px;line-height:1.5">Đối chiếu docs/design/ban-do-man-hinh.md (195 mã màn) với canvas: %d mã có khung, <b>%d mã chưa có khung</b> (%s). Mức C của P5a, P5b: BH-04, BH-10, BH-11, TC-06, TC-12, TC-14, TC-16, LOP-09, BUOI-14, TT-03.</p>'
'<div class="hmt-table-wrap"><table class="hmt-table t"><thead><tr><th style="width:190px">Lý do</th><th style="width:170px">Giai đoạn dự kiến</th><th style="width:50px">Số</th><th>Mã màn chưa có khung</th></tr></thead><tbody>%s</tbody></table></div>'
'<p style="font-size:11.5px;color:var(--text-secondary);margin:8px 0 0;line-height:1.5">Mã có khung dưới tên khác, tính là đã có: CHUNG-01..09, 25 = DN01–DN10 · CHUNG-11, 12 = TimKiem · CHUNG-14 = K09b · CHUNG-16 = các khung _khong_quyen · CHUNG-19 = K1_fav · CHUNG-26 = K4 · QT-06, 07, 09, 10 = CauHinh · QT-05 = MaTranQuyen. “Chưa vẽ (giai đoạn đã mở)”: màn thuộc giai đoạn đã vẽ nhưng chưa có lệnh vẽ; chờ anh quyết thứ tự.</p></div>')%(195-len(unc),len(unc),summ,trs))
# ---- Ghi_chu_cuoi
def sec(t,items): return '<h2 class="s">%s</h2>'%e(t)+''.join('<p class="li">%d. %s</p>'%(i+1,e(x)) for i,x in enumerate(items))
GC=frame('Ghi chú cuối',1440,1000,('<div style="padding:30px 44px;display:flex;gap:40px"><div style="flex:1"><h1 style="font-family:var(--font-heading);font-size:28px;margin:0 0 4px">Ghi chú cuối</h1>'
+sec('Chỗ lệch và lưu ý',[
'Mã PH-01, PH-03 và HS-01..07 ghi trên khung P4 là tab của hồ sơ KH-02, KH-05; trùng tên với PH- (cổng phụ huynh) và HT- (cổng học tập) trong bản đồ màn hình.',
'TS-06: nút đổi thành “Mở cơ hội cũ” (18/10). Bản đồ màn hình còn ghi “Gộp vào cơ hội cũ”; câu cảnh báo “Chọn Gộp…” cần xem lại.',
'K4f (hộp Gộp trùng) chưa áp dụng cho TS-10 và KH-07, chờ anh bảo. Điều kiện chặn gộp của KH-07 còn [CHỜ] ở R-CRM-25.',
'TS-18, TS-19 đã bỏ theo gói P3 (xếp lịch gộp vào TS-15, huỷ phiếu nằm ở TS-17): hai khung trống cũ đã gỡ khỏi canvas.',
'Câu mẫu “phân hệ Bán hàng và thu chi” còn ở khung không có quyền của GD-02, GD-04, GD-06, GD-07 (GD-01 đã sửa thành “phân hệ Đào tạo”). Chờ anh OK mới sửa.',
'KH-01, KH-04: danh sách chưa bấm sang bản ghi được. P4: bình luận b2f15525 chưa đóng.'])
+sec('Màn dừng',['DN06 Đặt mật khẩu mới (link từ email): hoãn, giữ để tham khảo, không đưa vào gói bàn giao.','K12 (điểm danh trên điện thoại) và K14 (chấm nhanh): khuôn mới đề xuất; màn dùng chúng phải dừng nếu không có khuôn nào gần.'])+
'</div><div style="flex:1"><h2 class="s" style="margin-top:44px">Câu hỏi chờ anh trả lời “OK”</h2>'+''.join('<p class="li">%d. %s</p>'%(i+1,e(x)) for i,x in enumerate([
'Menu con của Đào tạo (Ghi danh, Hàng chờ xếp lớp, Sắp hết giờ, Tái tục, Lớp học, Lịch tuần cơ sở, Buổi học, Yêu cầu buổi, Điểm danh trong ngày, Buổi chưa hoàn tất): P0 chưa có mục cấp 2, đây là đề xuất của Design.',
'Nút Xuất ở danh sách ghi danh: đề xuất chỉ CS, Trưởng cơ sở, Kế toán, Admin.',
'Chặn môn theo khối khi xếp lớp: đề xuất, chờ anh. Hiện chỉ vẽ nhắc mềm.',
'GD-07, TT: dự báo theo từng ghi danh; hạn gói và End Date chỉ để dự báo, quá hạn gói còn giờ vẫn học (R-GD-07). Chờ duyệt theo 04e mục 3.',
'Mã cũ (Sheet): chỉ ở lớp (LOP-02, ô chỉ đọc cạnh mã lớp; tìm kiếm ở LOP-01 nhận mã cũ) và học sinh. Phụ huynh không có mã cũ.',
'Lớp: “Tình trạng vận hành” chưa có giá trị trong luật (đang vẽ tạm Chưa khai giảng, Đang học, Đã kết thúc); định dạng mã cũ CLS-2609-0014 là mẫu tự đặt. Xem ghi chú cạnh LOP-02.']))+'</div></div>'))
os.makedirs(M+'stage/project',exist_ok=True)
new={'Muc_luc.dc.html':MUC,'Chua_ve.dc.html':CH,'Ghi_chu_cuoi.dc.html':GC}

ST=M+'stage/project/'
shutil.rmtree(M+'stage',ignore_errors=True); os.makedirs(ST)
for f,h in list(helper.items())+list(new.items()): open(ST+f,'w',encoding='utf8').write(h)
for f in glob.glob(M+'live_p5a/project/*.dc.html'): shutil.copy(f,ST)
for f in glob.glob(W+'p5b/project/*.dc.html'): shutil.copy(f,ST)
# sửa duy nhất: GD01_khong_quyen
p=ST+'GD01_khong_quyen.dc.html'; t=open(p,encoding='utf8').read()
old='chưa được cấp quyền xem phân hệ Bán hàng và thu chi.'
assert t.count(old)==1
open(p,'w',encoding='utf8').write(t.replace(old,'chưa được cấp quyền xem phân hệ Đào tạo.'))
boards=dict(out_b)
boards['Muc_luc.dc.html']=dict(x=0,y=MUC_Y,w=1440,h=1000,title='HMT Platform · Mục lục',expand='fill')
boards['Chua_ve.dc.html']=dict(x=CHUA_X,y=CHUA_Y,w=1440,h=1000,title='Mã màn chưa có khung (Giai đoạn sau, mức C)',expand='fill')
boards['Ghi_chu_cuoi.dc.html']=dict(x=1520,y=GC_Y,w=1440,h=1000,title='Ghi chú cuối · chỗ lệch, câu hỏi, màn dừng',expand='fill')
od=['Muc_luc.dc.html']+order[:]
i=od.index('TimKiem.dc.html'); od.insert(i+1,'Chua_ve.dc.html'); od.append('Ghi_chu_cuoi.dc.html')
cv={k:P4[k] for k in ('v','createdOnFiles','title','launch','pages')}
cv['boards']=boards; cv['order']=od; cv['notes']=out_n; cv['designSystems']=P4['designSystems']
assert set(od)==set(boards) and len(od)==len(boards)
json.dump(cv,open(ST+'canvas.json','w'),ensure_ascii=False,indent=2)
print('boards',len(boards),'files',len(os.listdir(ST)))
# kiểm chồng lấn
bs=list(boards.items())
ov=[]
for i in range(len(bs)):
    for j in range(i+1,len(bs)):
        a=bs[i][1];b=bs[j][1]
        if a['x']<b['x']+b['w'] and b['x']<a['x']+a['w'] and a['y']<b['y']+b['h'] and b['y']<a['y']+a['h']: ov.append((bs[i][0],bs[j][0]))
print('overlap',ov[:10],len(ov))
