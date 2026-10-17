# -*- coding: utf-8 -*-
# P5a: khuôn K13 (bản in, MỚI ĐỀ XUẤT, anh duyệt 17/10): BH-03 Bản in báo giá (A4), TC-07 Bản in biên nhận (A5)
import sys; sys.path.insert(0, 'scripts')
from p5a_common import *
from p5a_overview import HEAD
import p5a_bh as B
import p5a_dh as D

CSS = '''<style>
.k13-bar{display:flex;align-items:center;gap:12px;height:56px;padding:0 20px;background:var(--bg-surface);border-bottom:1px solid var(--divider)}
.k13-bar h1{font-family:var(--font-heading);font-size:18px;margin:0}
.k13-wrap{display:flex;gap:24px;justify-content:center;align-items:flex-start;padding:20px 24px;background:var(--bg-subtle);height:924px;box-sizing:border-box;overflow:hidden}
.k13-paper{background:#fff;color:#1f1b16;box-shadow:0 1px 3px rgba(0,0,0,.18),0 6px 20px rgba(0,0,0,.08);box-sizing:border-box;flex:0 0 auto;font-size:12.5px;line-height:1.45;position:relative}
.k13-paper h2{font-family:var(--font-heading);margin:0}
.k13-h{display:flex;align-items:center;gap:14px;border-bottom:2px solid #e8590c;padding-bottom:12px}
.k13-logo{width:56px;height:56px;border-radius:10px;background:#e8590c;color:#fff;display:flex;align-items:center;justify-content:center;font-family:var(--font-heading);font-weight:700;font-size:20px;flex:0 0 auto}
.k13-t{font-family:var(--font-heading);font-size:24px;font-weight:700;letter-spacing:.5px;text-align:right;flex:1}
.k13-meta{display:grid;grid-template-columns:1fr 1fr;gap:6px 24px;margin:14px 0}
.k13-meta span{color:#6b645c;font-size:11px;display:block}
.k13-paper table{width:100%;border-collapse:collapse;margin-top:6px}
.k13-paper th{background:#f6f1ea;text-align:left;font-size:11px;padding:6px 8px;border-top:1px solid #d9d2c8;border-bottom:1px solid #d9d2c8;white-space:nowrap}
.k13-paper td{padding:7px 8px;border-bottom:1px solid #ebe5dc;vertical-align:top}
.k13-paper .r{text-align:right;font-variant-numeric:tabular-nums}
.k13-sum{display:flex;justify-content:flex-end;gap:24px;margin-top:10px;font-size:14px}
.k13-words{margin-top:4px;text-align:right;font-style:italic;color:#4a443d}
.k13-sign{display:flex;justify-content:space-around;margin-top:30px;text-align:center}
.k13-sign b{display:block}.k13-sign i{display:block;color:#6b645c;font-size:11px;margin-bottom:44px}
.k13-foot{position:absolute;left:0;right:0;bottom:12px;text-align:center;color:#8b847b;font-size:10.5px}
.k13-side{width:280px;flex:0 0 280px;background:var(--bg-surface);border:1px solid var(--divider);border-radius:10px;padding:14px 16px;font-size:12.5px}
.k13-side h3{font-family:var(--font-heading);font-size:14px;margin:0 0 8px}
.k13-tst{position:absolute;left:50%;bottom:24px;transform:translateX(-50%);background:#1f1b16;color:#fff;padding:9px 16px;border-radius:8px;font-size:13px;opacity:0;pointer-events:none;transition:opacity .2s;z-index:60}
.k13-tst.on{opacity:1}
</style>'''
JS = r'''
    componentDidMount() { const ROOT = document.querySelector('[data-ix=root]'); if (!ROOT) return;
      function toast(m) { const t = ROOT.querySelector('.k13-tst'); t.textContent = m; t.classList.add('on'); clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('on'), 2600); }
      ROOT.addEventListener('click', ev => { const d = ev.target.closest('[data-do]'); if (d) { ev.preventDefault(); toast(d.getAttribute('data-do')); } });
    }
'''
def shell(title, h1, back, paper, side, n):
    bar = ('<div class="k13-bar"><a href="#" data-do="Quay lại %s.">‹ %s</a><h1>%s</h1><span class="hmt-tag hmt-tag-info">Khuôn K13 · mới đề xuất</span><span style="flex:1"></span>' % (back[1], back[0], h1)
           + btn('Tải PDF', '', 'file', 'data-do="Đang tạo file PDF để tải về."') + btn('In', 'primary', 'printer', 'data-do="Mở hộp in của trình duyệt."') + '</div>')
    body = '<div data-ix="root" style="width:1440px;height:1000px;position:relative;background:var(--bg-page);overflow:hidden">' + bar + '<div class="k13-wrap">' + paper + side + '</div><div class="k13-tst" role="status"></div></div>'
    tail = '\n</x-dc>\n<script type="text/x-dc" data-dc-script data-props=\'{"$preview":{"width":1440,"height":1000}}\'>\nclass Component extends DCLogic {\n  renderVals() { return { yes: true }; }\n' + JS + '}\n</script>\n</body>\n</html>\n'
    return (HEAD % title).replace('</helmet>', CSS + '</helmet>', 1) + body + tail

def header(cs, ten_ct, ma, old, ngay, extra='', ts=24):
    return ('<div class="k13-h"><div class="k13-logo">HMT</div><div><h2 style="font-size:15px">Hoà Ma Toán · %s</h2><div style="color:#6b645c;font-size:11px">Số 12 Nguyễn Chí Thanh, Đống Đa, Hà Nội · 024 3999 0000</div></div>'
            '<div class="k13-t" style="font-size:%dpx;white-space:nowrap">%s<div style="font-size:12px;font-weight:500;letter-spacing:0;font-family:var(--font-ui)">%s%s</div></div></div>') % (cs, ts, ten_ct, ma, ('<br><span style="color:#8b847b;font-size:10.5px">mã cũ %s</span>' % old) if old else '')

def words(n): return n
def sidebox(rows):
    return ('<div class="k13-side"><h3>Khuôn K13 · bản in</h3><p style="margin:0 0 8px;color:#6b645c">Khuôn <b>mới đề xuất</b>, chờ ghi vào P0 v5. Dùng chung cho báo giá (A4), biên nhận (A5), phiếu chi (TC-12, chưa vẽ).</p>'
            '<dl style="margin:0;display:grid;grid-template-columns:auto 1fr;gap:6px 12px">%s</dl>'
            '<p style="margin:12px 0 0;color:#6b645c">Gồm: đầu trang logo cơ sở, khối thông tin, bảng dòng, tổng bằng số và bằng chữ, chỗ ký, nút In và Tải PDF. Bản xem trước là khổ giấy thật thu nhỏ.</p></div>') % ''.join('<dt class="hmt-help">%s</dt><dd style="margin:0">%s</dd>' % r for r in rows)

def bh03():
    rows = ''
    for i, (g, n, ht, h, d, ck, t) in enumerate(B.QLINES):
        rows += '<tr><td>%d</td><td><b>%s</b><div style="color:#6b645c;font-size:11px">%s</div></td><td>%s</td><td class="r">%d</td><td class="r">%d</td><td class="r">%s</td><td class="r">%d%%</td><td class="r"><b>%s</b></td></tr>' % (i + 1, g, n, ht, h, t, num(d), ck, num(B.line_total(h, d, ck)))
    tong = sum(B.line_total(h, d, ck) for g, n, ht, h, d, ck, t in B.QLINES)
    paper = ('<div class="k13-paper" style="width:794px;height:1123px;zoom:.8;padding:44px 48px">' + header('CS1 Nguyễn Chí Thanh', 'BÁO GIÁ', B.QT['code'], B.QT['old'], '') +
             '<div class="k13-meta"><div><span>Phụ huynh</span><b>%s</b> · %s</div><div><span>Điện thoại</span>%s</div><div><span>Ngày lập</span>10/10/2026</div><div><span>Hạn hiệu lực</span>24/10/2026</div><div><span>Người lập</span>%s</div><div><span>Cơ hội</span>%s</div></div>' % (B.PH_NAME, B.PH_CODE, B.QT['phone'], B.QT['sale'], B.QT['co']) +
             '<table><thead><tr><th>#</th><th>Gói</th><th>Hình thức</th><th class="r">Giờ mua</th><th class="r">Giờ tặng</th><th class="r">Đơn giá (đ/giờ)</th><th class="r">Chiết khấu</th><th class="r">Thành tiền (đ)</th></tr></thead><tbody>' + rows + '</tbody></table>'
             '<div class="k13-sum"><span>Tổng thành tiền</span><b style="font-size:18px">%s đ</b></div><div class="k13-words">Bằng chữ: Mười ba triệu sáu trăm lẻ tám nghìn đồng</div>' % num(tong) +
             '<p style="margin-top:18px;color:#4a443d">Toán khối 7 trở lên gồm hai phần Đại số và Hình học, tính tiền riêng từng phần. Báo giá có hiệu lực đến 24/10/2026; học sinh và lớp học được xác nhận khi lập đơn hàng.</p>'
             '<div class="k13-sign"><div><b>Phụ huynh xác nhận</b><i>(ký, ghi rõ họ tên)</i></div><div><b>Người lập báo giá</b><i>(ký, ghi rõ họ tên)</i>%s</div></div><div class="k13-foot">Trang 1/1 · In ngày 17/10/2026</div></div>' % B.QT['sale'])
    side = sidebox([('Khổ giấy', 'A4 dọc'), ('Màn nguồn', 'BH-02 Báo giá'), ('Số dòng', '3 (Đại số, Hình học, Tiếng Anh)')])
    return shell('BH-03 · Bản in báo giá (khuôn K13, A4)', 'Bản in báo giá', ('Báo giá ' + B.QT['code'], 'báo giá (màn BH-02)'), paper, side, 3)

def tc07():
    ch = D.chia(7000000, 0); ls = [D.L1, D.L2, D.L3]
    rows = ''.join('<tr><td>%d</td><td><b>%s</b><div style="color:#6b645c;font-size:11px">%s</div></td><td class="r">%s</td><td class="r">%s</td></tr>' % (i + 1, l[0], l[5].split(' · ')[0], num(ch[i][0]), D.hh(ch[i][1])) for i, l in enumerate(ls))
    paper = ('<div class="k13-paper" style="width:559px;height:794px;zoom:1.07;padding:32px 34px;font-size:12px">' + header('CS1 Nguyễn Chí Thanh', 'BIÊN NHẬN', 'PT-CS1-2610-0015', 'RCP-2610-0052', '', ts=20) +
             '<div class="k13-meta"><div><span>Người nộp (phụ huynh)</span><b>%s</b> · %s</div><div><span>Ngày nhận</span>12/10/2026</div><div><span>Đơn hàng</span>%s</div><div><span>Hình thức</span>Chuyển khoản</div><div><span>Tài khoản nhận</span>Vietcombank …3456</div><div><span>Mã giao dịch</span>FT26285123456</div></div>' % (B.PH_NAME, B.PH_CODE, D.DH['code']) +
             '<div class="k13-sum" style="justify-content:space-between"><span>Số tiền đã nhận</span><b style="font-size:20px">7.000.000 đ</b></div><div class="k13-words" style="text-align:left">Bằng chữ: Bảy triệu đồng</div>'
             '<div style="margin-top:12px;font-weight:600">Tiền về các dòng đơn</div><table><thead><tr><th>#</th><th>Học sinh · lớp</th><th class="r">Tiền chia (đ)</th><th class="r">Giờ cấp</th></tr></thead><tbody>' + rows + '</tbody></table>'
             '<p style="margin-top:10px;color:#6b645c;font-size:11px">Phiếu đã được Kế toán duyệt ngày 12/10/2026. Khoản tiền vào KTV-CS1-2610-0009.</p>'
             '<div class="k13-sign" style="margin-top:8px;font-size:11.5px"><div><b>Người nộp tiền</b><i>(ký, ghi rõ họ tên)</i></div><div><b>Người thu tiền</b><i>(ký, ghi rõ họ tên)</i>Trần Thu Hà</div></div><div class="k13-foot">In ngày 17/10/2026</div></div>')
    side = sidebox([('Khổ giấy', 'A5 dọc'), ('Màn nguồn', 'TC-02 Phiếu thu'), ('Mã cũ', 'RCP-2610-0052 (chỉ phiếu thu)')])
    return shell('TC-07 · Bản in biên nhận (khuôn K13, A5)', 'Bản in biên nhận', ('Phiếu thu PT-CS1-2610-0015', 'phiếu thu (màn TC-02)'), paper, side, 3)

if __name__ == '__main__':
    wr('BH03_in', bh03()); wr('TC07_in', tc07())
