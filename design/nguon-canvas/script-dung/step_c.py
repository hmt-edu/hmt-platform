import json,os,sys,shutil
D=sys.argv[1]; P=D+'/canvas/project'; DS=D+'/ds-art/project'
def rep(path,old,new,count=1):
    s=open(path,encoding='utf-8').read(); n=s.count(old)
    assert n==count,(path,old[:60],n)
    open(path,'w',encoding='utf-8').write(s.replace(old,new))
A=lambda n:f'{P}/{n}.dc.html'
# DN03
for n in ['DN03_pc_code','DN03_pc_code_err','DN03_mb_code','DN03_mb_code_err']:
    rep(A(n),'<div class="lg-lnk"><a href="#">Mất điện thoại? Dùng mã dự phòng</a></div>','<span class="lg-note lg-ctr">Mất điện thoại? Liên hệ quản trị viên để đặt lại xác thực hai bước</span>')
# DN04
for d in ['pc','mb']:
    rep(A(f'DN04_{d}_s1'),'<span class="on"></span><span class=""></span><span class=""></span>','<span class="on"></span><span class=""></span>')
    rep(A(f'DN04_{d}_s1'),'BƯỚC 1/3 · QUÉT MÃ','BƯỚC 1/2 · QUÉT MÃ')
    rep(A(f'DN04_{d}_s2'),'<span class="on"></span><span class="on"></span><span class=""></span>','<span class="on"></span><span class="on"></span>')
    rep(A(f'DN04_{d}_s2'),'BƯỚC 2/3 · NHẬP MÃ','BƯỚC 2/2 · NHẬP MÃ')
    rep(A(f'DN04_{d}_s2'),'<button class="lg-btn pri" type="button">Xác nhận</button>','<button class="lg-btn pri" type="button">Hoàn tất</button>')
    rep(A(f'DN04_{d}_s2'),'· Bước 2</title>','· Bước 2 (cuối)</title>')
# DN05
for d,dn in [('pc','Máy tính'),('mb','Điện thoại')]:
    f=A(f'DN05_{d}_form'); s=open(f,encoding='utf-8').read()
    a=s.index('<p class="lg-sub">Nhập email đăng nhập.'); b=s.index('<div class="lg-lnk"><a href="#">Quay lại đăng nhập</a></div>',a)+len('<div class="lg-lnk"><a href="#">Quay lại đăng nhập</a></div>')
    s=s[:a]+'<p class="lg-sub">Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm.</p><button class="lg-btn pri lg-full" type="button">Quay lại đăng nhập</button>'+s[b:]
    open(f,'w',encoding='utf-8').write(s)
    rep(f,f'<title>Quên mật khẩu · {dn} · Nhập email</title>',f'<title>Quên mật khẩu · {dn} · Liên hệ quản trị viên</title>')
# DN08 -> one screen per device
for d,dn in [('pc','Máy tính'),('mb','Điện thoại')]:
    src=A(f'DN08_{d}_perm'); dst=A(f'DN08_{d}_lock'); shutil.copy(src,dst)
    rep(dst,'<h2 class="lg-h">Tài khoản đã bị khoá</h2>','<h2 class="lg-h">Không thể đăng nhập</h2>')
    rep(dst,'Tài khoản này không còn được dùng (ví dụ đã nghỉ việc hoặc dừng học). Nếu bạn nghĩ đây là nhầm lẫn, liên hệ quản trị viên của trung tâm.','Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm.')
    rep(dst,f'<title>Tài khoản bị khoá · {dn} · Khoá hẳn</title>',f'<title>Không thể đăng nhập · {dn} · Một câu chung</title>')
    for st in ['perm','temp']: os.remove(A(f'DN08_{d}_{st}'))
for d in ['pc','mb']:
    for st in ['backup','backup_err']: os.remove(A(f'DN03_{d}_{st}'))
    os.remove(A(f'DN04_{d}_s3')); os.remove(A(f'DN05_{d}_sent'))
# CauHinh
rep(A('CauHinh'),'<label style="font-size:12px;color:var(--text-secondary)">Có hiệu lực từ</label><input class="hmt-input" type="date" value="2026-10-15" aria-label="Có hiệu lực từ" style="width:150px">','')
rep(A('CauHinh'),'Sửa một tham số thì có hiệu lực từ ngày chọn, bản cũ vẫn giữ trong lịch sử.','Sửa một tham số thì có hiệu lực ngay; giá trị cũ vẫn giữ trong lịch sử thay đổi.')
# tokens.json
t=json.load(open(DS+'/tokens.json',encoding='utf-8'))
ct=t['color']['tokens']; i=[x['name'] for x in ct].index('info-border')+1
ct[i:i]=[
 {"name":"success-border","value":"#BAD9C4","usage":"Thêm 16/10 (v4). Viền thông báo trạng thái thành công (toast, banner, nhãn) trên success-bg. Pha 21% success-solid vào success-bg, cùng cách với info-border."},
 {"name":"warning-border","value":"#F2DE9D","usage":"Thêm 16/10 (v4). Viền thông báo trạng thái cảnh báo trên warning-bg. Pha 21% warning-solid vào warning-bg."},
 {"name":"danger-border","value":"#ECBBC2","usage":"Thêm 16/10 (v4). Viền thông báo trạng thái lỗi trên danger-bg. Pha 21% danger-solid vào danger-bg."}]
st=t['size']['tokens']; i=[x['name'] for x in st].index('stage-height')+1
st[i:i]=[
 {"name":"table-head-height","value":"32px","usage":"Thêm 16/10 (v4). Chiều cao hàng tiêu đề bảng (hmt-table th). Trước đây viết thẳng 32px trong bundle.css."},
 {"name":"table-row-height","value":"36px","usage":"Thêm 16/10 (v4). Chiều cao hàng dữ liệu bảng (hmt-table td) trên máy tính. Trước đây viết thẳng 36px trong bundle.css."}]
t['version']=4
json.dump(t,open(DS+'/tokens.json','w',encoding='utf-8'),ensure_ascii=False,indent=1)
# hmt-tokens.css
c=P+'/ds/hmt/handoff/hmt-tokens.css'
rep(c,'  --info-border: #B9CFEC;\n','  --info-border: #B9CFEC;\n  --success-border: #BAD9C4;\n  --warning-border: #F2DE9D;\n  --danger-border: #ECBBC2;\n')
rep(c,'  --stage-height: 34px;\n','  --stage-height: 34px;\n  --table-head-height: 32px;\n  --table-row-height: 36px;\n')
# bundle.css
b=DS+'/components/bundle.css'
rep(b,'padding: 0 10px; height: 32px; white-space: nowrap; }','padding: 0 10px; height: var(--table-head-height); white-space: nowrap; }')
rep(b,'.hmt-table td { padding: 0 10px; height: 36px;','.hmt-table td { padding: 0 10px; height: var(--table-row-height);')
os.makedirs(P+'/ds/hmt/components',exist_ok=True)
shutil.copy(b,P+'/ds/hmt/components/bundle.css'); shutil.copy(DS+'/tokens.json',P+'/ds/hmt/tokens.json')
print('ok')
