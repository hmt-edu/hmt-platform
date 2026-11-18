# -*- coding: utf-8 -*-
# P5a cụm 1: Báo giá (BH-02) và các dialog liên quan
import sys; sys.path.insert(0, 'scripts')
from p5a_common import *

PH_NAME = 'Phạm Thu Hương'; PH_CODE = 'PH000047'
QT = dict(code='BG-CS1-2610-0007', old='UPS-2610-0031', co='CO000142', phone='0912 888 345', sale='Trần Thu Hà', cs='CS1 Nguyễn Chí Thanh')
QLINES = [  # gói, tên, hình thức, giờ, đơn giá, ck%, giờ tặng
 ('LC-TOAN-K08', 'Toán 8 · Đại số', 'Offline', 24, 220000, 10, 0),
 ('LC-TOAN-K08', 'Toán 8 · Hình học', 'Offline', 24, 220000, 10, 0),
 ('LC-ANH-K05', 'Tiếng Anh 5 · lớp chung', 'Offline', 24, 180000, 5, 2)]
def line_total(g, d, ck): return int(round(g * d * (100 - ck) / 100))
def gift_pct(g, tang): return tang * 100.0 / g if g else 0

def qlines_html(editable=False, errs=None):
    errs = errs or {}
    rows = []
    for i, (g, n, ht, h, d, ck, tang) in enumerate(QLINES):
        tot = line_total(h, d, ck)
        if editable:
            hinp = '<input class="hmt-input%s" style="width:64px;text-align:right" value="%s" aria-label="Giờ mua">' % (' hmt-input-err' if errs.get((i, 'h')) else '', h if not errs.get((i, 'h')) else '')
            row = ['<b>%s</b><div class="hmt-help">%s</div>' % (g, n), '<select class="hmt-input hmt-select" style="width:92px" aria-label="Hình thức" data-val="%s"><option>Offline</option><option>Online</option></select>' % ht, hinp + (('<span class="ix-err">%s</span>' % errs[(i, 'h')]) if errs.get((i, 'h')) else ''),
                   '<input class="hmt-input" style="width:64px;text-align:right" value="%d" aria-label="Giờ tặng">' % tang, '<span class="hmt-num">%s</span>' % num(d), '<input class="hmt-input" style="width:56px;text-align:right" value="%d" aria-label="Chiết khấu %%">' % ck,
                   '<span class="hmt-num">%s</span>' % num(tot), btn('', 'text', 'x', 'aria-label="Bỏ dòng" data-do="Đã bỏ dòng khỏi báo giá nháp."')]
        else:
            row = ['<b>%s</b><div class="hmt-help">%s</div>' % (g, n), ht, '<span class="hmt-num">%d</span>' % h, '<span class="hmt-num">%d</span>' % tang, '<span class="hmt-num">%s</span>' % num(d), '<span class="hmt-num">%d%%</span>' % ck, '<span class="hmt-num">%s</span>' % num(tot)]
        rows.append(row)
    heads = [('Gói', 0), ('Hình thức', 0), ('Giờ mua', 1), ('Giờ tặng', 1), ('Đơn giá (đ/giờ)', 1), ('Chiết khấu', 1), ('Thành tiền (đ)', 1)]
    if editable: heads.append(('', 0))
    return heads, rows

def qtable(editable=False, errs=None):
    heads, rows = qlines_html(editable, errs)
    tot = sum(line_total(h, d, ck) for g, n, ht, h, d, ck, t in QLINES)
    t = table(heads, rows, cls='')
    foot = ('<div style="display:flex;justify-content:flex-end;gap:var(--space-6);padding-top:var(--space-2);font-size:13px"><span class="hmt-help">Tổng chiết khấu mỗi dòng cộng dồn, không quá 20%% (giờ tặng tính vào trần).</span>'
            '<span>Tổng thành tiền <b class="hmt-num" style="font-size:16px">%s</b></span></div>') % money(tot)
    note = '<div class="hmt-help">Toán khối 7 trở lên: Đại số và Hình học là <b>hai dòng riêng</b>, mỗi dòng có giờ, giá, chiết khấu riêng; học một môn thì một dòng. Báo giá không chọn học sinh. Khi chuyển thành đơn, mỗi dòng thành một dòng đơn (chọn học sinh và lớp ở đơn).</div>'
    return t + foot + note

def q_kv(valid, status_tag, extra=None, edit=False, valid_err=False):
    L = [kv('Mã báo giá', code(QT['code']) , 'cấp khi Lưu, không sửa'), kv('Phụ huynh', link('%s · %s' % (PH_NAME, PH_CODE), 'Mở phụ huynh (màn KH-02).')), kv('Cơ hội', link(QT['co'], 'Mở cơ hội (màn TS-13).')), kv('Cơ sở', QT['cs'])]
    R = [kv('Tình trạng', status_tag), kv('Ngày lập', numc('10/10/2026')), kv('Hạn hiệu lực', valid), kv('Người lập', QT['sale'])]
    if extra: R += extra
    return fgrid(L, R)

def q_stage(cur, branch=None, note=None):
    return stage(['Nháp', 'Đã gửi', 'Đã chuyển đơn'], cur, branches=branch, note=note)

def q_chatter(state):
    days = [('10/10/2026', [sysmsg('09:12', 'Báo giá tạo từ cơ hội CO000142.', chg=None)])]
    if state in ('gui', 'don', 'tu_choi', 'het_han'):
        days[0][1].insert(0, sysmsg('09:40', 'Gửi báo giá cho phụ huynh qua tin nhắn.', chg=('Nháp', 'Đã gửi')))
    if state == 'don':
        days.insert(0, ('12/10/2026', [sysmsg('14:05', 'Chuyển thành đơn DH-CS1-2610-0012.', chg=('Đã gửi', 'Đã chuyển đơn'))]))
    if state == 'tu_choi':
        days.insert(0, ('12/10/2026', [sysmsg('16:20', 'Từ chối báo giá. Lý do: Phụ huynh chọn trung tâm khác gần nhà hơn.', chg=('Đã gửi', 'Từ chối'))]))
    if state == 'het_han':
        days.insert(0, ('25/10/2026', [sysmsg('00:00', 'Báo giá hết hạn hiệu lực (14 ngày).', chg=('Đã gửi', 'Hết hạn'))]))
    # ngày hiển thị ngược: mới trước
    return chatter(days, readonly=(state in ('quyen',)))

def d_tu_choi():
    return dialog('tuchoi', 'Từ chối báo giá', '<h2>Từ chối báo giá</h2>', 
        '<p class="hmt-help" style="margin:0 0 var(--space-3)">Báo giá %s sẽ chuyển sang Từ chối và chỉ còn xem. Cơ hội vẫn giữ để lập báo giá khác.</p><label class="hmt-field"><span class="hmt-label">Lý do từ chối <b style="color:var(--danger-text)">*</b></span><textarea class="hmt-textarea" rows="3" placeholder="Ví dụ: phụ huynh chọn trung tâm khác"></textarea></label>' % QT['code'],
        btn('Đóng', '', None, 'data-close="1"') + btn('Xác nhận từ chối', 'danger', None, 'data-dto="Đã từ chối báo giá."'))

def build_bg(state):
    user = 'sa'
    title = {'nhap': 'BH-02 · Báo giá · Nháp', 'sua': 'BH-02 · Báo giá · Sửa nháp (có lỗi)', 'gui': 'BH-02 · Báo giá · Đã gửi', 'don': 'BH-02 · Báo giá · Đã chuyển đơn', 'tu_choi': 'BH-02 · Báo giá · Từ chối',
             'het_han': 'BH-02 · Báo giá · Hết hạn', 'tai': 'BH-02 · Báo giá · Đang tải', 'quyen': 'BH-02 · Báo giá · Không có quyền'}[state]
    crumb = [('Bán hàng &amp; thu chi', False), ('Báo giá', False), (QT['code'], True)]
    valid = '<span class="hmt-num">24/10/2026</span><span class="hmt-auto">14 ngày từ ngày gửi</span>'
    PRN = btn('In', '', 'printer', 'data-do="Mở bản in báo giá (màn BH-03)."')
    if state == 'quyen':
        return noperm_page(title, 'báo giá')
    if state == 'tai':
        return loading_page(title, 'Báo giá', 'sa', crumb[:2] + [('Đang tải…', True)], 'Báo giá')
    errs = {(0, 'h'): 'Bắt buộc nhập số giờ'} if state == 'sua' else None
    tag_map = {'nhap': tag('Nháp'), 'sua': tag('Nháp'), 'gui': tag('Đã gửi', 'info'), 'don': tag('Đã chuyển đơn', 'success'), 'tu_choi': tag('Từ chối', 'danger'), 'het_han': tag('Hết hạn', 'warning')}
    cur = {'nhap': 0, 'sua': 0, 'gui': 1, 'don': 2, 'tu_choi': None, 'het_han': None}[state]
    if state in ('tu_choi', 'het_han'):
        stg = stage(['Nháp', 'Đã gửi', 'Đã chuyển đơn'], 1, branches=[('Từ chối' if state == 'tu_choi' else 'Hết hạn', 'danger' if state == 'tu_choi' else 'warning')], note='báo giá dừng ở đây, chỉ còn xem')
    else:
        stg = q_stage(cur)
    extra = None
    if state == 'tu_choi': extra = [kv('Lý do từ chối', 'Phụ huynh chọn trung tâm khác gần nhà hơn.')]
    if state == 'don': extra = [kv('Đơn hàng', link('DH-CS1-2610-0012', 'Mở đơn hàng (màn BH-05).') + '<span class="hmt-auto">3 dòng báo giá thành 3 dòng đơn</span>')]
    if state == 'het_han': valid = '<span class="hmt-num" style="color:var(--danger-text)">24/10/2026</span><span class="hmt-auto">đã quá hạn 1 ngày</span>'
    editable = state in ('nhap', 'sua')
    if state == 'sua':
        kvb = q_kv('<input class="hmt-input" style="width:140px" value="24/10/2026" aria-label="Hạn hiệu lực">', tag_map[state])
    else:
        kvb = q_kv(valid, tag_map[state], extra)
    alerts = ''
    if state == 'sua': alerts = alert('danger', '<b>Chưa lưu được.</b> Dòng 1 (LC-TOAN-K08 · Toán 8 Đại số) thiếu số giờ mua.')
    if state == 'het_han': alerts = alert('warning', 'Báo giá đã hết hạn nên không gửi hay chuyển đơn được. Bấm <b>Tạo lại</b> để sinh báo giá mới từ báo giá này (giá lấy theo bảng giá hiện hành).')
    if state == 'gui': alerts = alert('info', 'Đã gửi cho phụ huynh. Báo giá còn hiệu lực đến 24/10/2026; hết hạn thì tự chuyển sang Hết hạn.', 'file')
    body = alerts + sec('DÒNG GÓI') + qtable(editable, errs)
    sh = sheet('Báo giá <span class="hmt-code">%s</span>' % QT['code'] + (' <span class="hmt-help">mã cũ %s</span>' % QT['old']), kvb + body)
    btns = {
      'nhap': [btn('Sửa', 'primary', 'pencil', 'data-do="Mở khuôn Sửa báo giá nháp."'), btn('Gửi', '', 'send', 'data-do="Đã gửi báo giá cho phụ huynh."'), PRN],
      'sua': [btn('Lưu', 'primary', 'check', 'data-do="Chưa lưu: dòng 1 thiếu số giờ."'), btn('Huỷ', '', None, 'data-do="Bỏ thay đổi, quay lại xem báo giá."')],
      'gui': [btn('Chuyển thành đơn', 'primary', 'receipt', 'data-do="Tạo đơn nháp từ báo giá: dòng Đại số, Hình học thành hai dòng đơn riêng, mở đơn (màn BH-05)."'), btn('Từ chối', '', 'ban', 'data-open="tuchoi"'), PRN],
      'don': [PRN], 'tu_choi': [PRN],
      'het_han': [btn('Tạo lại', 'primary', 'refresh', 'data-do="Đã tạo báo giá mới BG-CS1-2610-0009 từ báo giá này."'), PRN]}[state]
    left = smart([('Cơ hội', 1), ('Đơn hàng', 1 if state == 'don' else 0), ('Phiếu thu', 0)]) + stg + sh
    t = page(title, 'Báo giá', user, crumb, rbar_l('Báo giá', btns), left, q_chatter(state), pager='3 / 18', dlgs=d_tu_choi(), show0='')
    return t


if __name__ == '__main__':
    for st in ('nhap','sua','gui','don','tu_choi','het_han','tai','quyen'):
        wr('BH02_' + st, build_bg(st))
