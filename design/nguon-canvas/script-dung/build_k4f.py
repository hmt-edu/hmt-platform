# -*- coding: utf-8 -*-
# K4f · Hộp thoại "Gộp trùng" (P0 v5). Dùng cho TS-10 (lead, cơ hội) và KH-07 (phụ huynh, học sinh).
import re, sys
sys.path.insert(0, 'scripts')
from kh_common import SVG, IC
REPO = '/home/claude/hmt-platform/design/nguon-canvas/p4-hmt-platform/project/'
s = open(REPO + 'K4c.dc.html', encoding='utf-8').read()
pre = s[:s.index('<div style="padding:24px')]
pre = re.sub(r'<title>[^<]*</title>', '<title>K4f · Hộp thoại gộp trùng</title>', pre, count=1)
tail = s[s.index('\n</x-dc>'):]
tail = tail.replace("renderVals() {\n    return { yes: true };\n  }", """renderVals() {
    return { yes: true };
  }
  componentDidMount() {
    const R = document.querySelector('[data-ix=root]'); if (!R) return;
    let t = null;
    const toast = m => { let e = R.querySelector('.ix-toast'); if (!e) { e = document.createElement('div'); e.className = 'ix-toast'; R.appendChild(e); } e.textContent = m; e.classList.add('on'); clearTimeout(t); t = setTimeout(() => e.classList.remove('on'), 2600); };
    R.addEventListener('change', ev => {
      const d = ev.target.closest('[data-merge]'); if (!d) return;
      if (ev.target.matches('input[type=radio]')) { d.querySelectorAll('[data-card]').forEach(c => c.classList.toggle('sel', c.contains(ev.target) && ev.target.checked)); const k = d.querySelector('[data-keep]'); if (k) k.textContent = ev.target.getAttribute('data-code'); const o = d.querySelector('[data-other]'); if (o) o.textContent = ev.target.getAttribute('data-other'); }
      const ck = d.querySelector('[data-ack]'), go = d.querySelector('[data-go]'); if (ck && go && !go.hasAttribute('data-blocked')) go.disabled = !ck.checked;
    });
    R.addEventListener('click', ev => { const g = ev.target.closest('[data-go]'); if (g && !g.disabled) { toast('Đã gộp. Bản bị gộp chuyển sang trạng thái Đã gộp, chỉ đọc.'); return; } const c = ev.target.closest('[data-cancel]'); if (c) toast('Đã huỷ, không gộp.'); const o = ev.target.closest('[data-open-rec]'); if (o) { ev.preventDefault(); toast(o.getAttribute('data-open-rec')); } });
  }""", 1)
CSS = '<style>.mg-card{border:var(--border-1) solid var(--divider);border-radius:var(--radius-lg);background:var(--bg-surface);flex:1 1 0;min-width:0;overflow:hidden}.mg-card.sel{border-color:var(--brand-500);box-shadow:0 0 0 1px var(--brand-500)}.mg-h{display:flex;align-items:center;gap:var(--space-2);padding:10px 14px;background:var(--bg-subtle);font-weight:600;font-size:13px}.mg-r{display:flex;gap:var(--space-3);padding:8px 14px;border-top:var(--border-1) solid var(--divider);font-size:13px}.mg-r>span:first-child{flex:0 0 120px;color:var(--text-secondary)}.mg-r>span:last-child{min-width:0;overflow-wrap:anywhere}.mg-diff{background:var(--warning-bg)}.mg-pv td,.mg-pv th{padding:6px 12px}</style>'
def row(k, a, diff=False): return '<div class="mg-r%s"><span>%s</span><span>%s</span></div>' % (' mg-diff' if diff else '', k, a)
def card(n, sel, code, other, name, rows):
    return ('<div class="mg-card%s" data-card><label class="mg-h" style="cursor:pointer"><input type="radio" name="keep%d"%s data-code="%s" data-other="%s"> Giữ bản này <span class="hmt-code" style="margin-left:auto">%s</span></label>' % (' sel' if sel else '', n, ' checked' if sel else '', code, other, code)) + ''.join(rows) + '</div>'
def cols(n, kind='lead'):
    if kind == 'co':
        a = card(n, True, 'CO000121', 'CO000140', '', [row('Học sinh', 'Nguyễn Hà My'), row('Môn · khối', 'Toán · lớp 9'), row('Giai đoạn', '<span class="hmt-tag hmt-tag-brand">L5A</span>'), row('Người phụ trách', 'Trần Thu Hà', True), row('Báo giá', '—', True), row('Đơn hàng', '—', True), row('Ngày tạo', '03/10/2026')])
        b = card(n, False, 'CO000140', 'CO000121', '', [row('Học sinh', 'Nguyễn Hà My'), row('Môn · khối', 'Toán · lớp 9'), row('Giai đoạn', '<span class="hmt-tag hmt-tag-brand">L8A</span>'), row('Người phụ trách', 'Hoàng Mai Anh', True), row('Báo giá', 'BG-CS1-2610-0007', True), row('Đơn hàng', 'DH-CS1-2610-0012', True), row('Ngày tạo', '12/10/2026')])
        return '<div style="display:flex;gap:var(--space-4)">' + a + b + '</div><div class="hmt-help">Dòng nền vàng là trường khác nhau: sau khi gộp, giá trị của bản giữ lại được dùng.</div>'
    a = card(n, True, 'LD000227', 'LD000231', 'Nguyễn Thị Hương', [row('Họ tên', 'Nguyễn Thị Hương'), row('Số điện thoại', '0900 000 120'), row('Cơ sở', 'CS1'), row('Người phụ trách', 'Trần Thu Hà', True), row('Nguồn', 'Facebook Ads · Lead Form', True), row('Ngày tạo', '03/10/2026'), row('Tình trạng', '<span class="hmt-tag hmt-tag-info">Đã có cơ hội</span>')])
    b = card(n, False, 'LD000231', 'LD000227', 'Nguyễn Thị Hương', [row('Họ tên', 'Nguyễn Thị Hương'), row('Số điện thoại', '0900 000 120'), row('Cơ sở', 'CS1'), row('Người phụ trách', 'Hoàng Mai Anh', True), row('Nguồn', 'Hotline', True), row('Ngày tạo', '12/10/2026'), row('Tình trạng', '<span class="hmt-tag">Mới</span>')])
    return '<div style="display:flex;gap:var(--space-4)">' + a + b + '</div><div class="hmt-help">Dòng nền vàng là trường khác nhau: sau khi gộp, giá trị của bản giữ lại được dùng.</div>'
def preview(kind='lead'):
    k1, k2 = ('LD000227', 'LD000231') if kind == 'lead' else ('CO000121', 'CO000140')
    rows = [('Cơ hội', '1', 'chuyển sang <b data-keep>LD000227</b>'), ('Phiếu test', '1', 'chuyển'), ('Lịch hẹn', '3', 'chuyển'), ('Ghi chú và hoạt động', '5', 'chuyển, giữ nguyên thời gian'), ('Ticket, khiếu nại', '0', '—')] if kind == 'lead' else [('Báo giá', '1', '<span class="hmt-tag hmt-tag-danger">chặn gộp</span> BG-CS1-2610-0007'), ('Đơn hàng', '1', '<span class="hmt-tag hmt-tag-danger">chặn gộp</span> DH-CS1-2610-0012'), ('Lịch hẹn', '2', 'chuyển sang <b data-keep>CO000121</b>'), ('Phiếu kiểm tra', '1', 'chuyển'), ('Ghi chú và hoạt động', '7', 'chuyển, giữ nguyên thời gian')]
    return ('<div><div class="hmt-csec-t" style="padding:0 0 var(--space-1)">SẼ CHUYỂN SANG BẢN GIỮ LẠI</div><div class="hmt-table-wrap"><table class="hmt-table mg-pv"><thead><tr><th>Dữ liệu</th><th class="r" style="width:80px">Số lượng</th><th>Xử lý</th></tr></thead><tbody>' +
            ''.join('<tr><td>%s</td><td class="r"><span class="hmt-num">%s</span></td><td>%s</td></tr>' % r for r in rows) + '</tbody></table></div><div class="hmt-help" style="margin-top:6px">Bản <b data-other>%s</b> chuyển sang trạng thái Đã gộp: chỉ đọc, ẩn khỏi danh sách mặc định, vẫn tìm được bằng mã.</div></div>') % k2
def warn(txt): return '<div class="hmt-alert hmt-alert-warning" role="alert">%s<span>%s</span></div>' % (SVG(IC['alert']), txt)
def dng(txt): return '<div class="hmt-alert hmt-alert-danger" role="alert">%s<span>%s</span></div>' % (SVG(IC['alert']), txt)
def dialog(n, label, alerts, ticked, blocked, kind='lead'):
    ack = '<label class="hmt-check"><input type="checkbox" data-ack%s%s> Tôi hiểu việc gộp <b>không hoàn tác được</b></label>' % (' checked' if ticked else '', ' disabled' if blocked else '')
    go = '<button class="hmt-btn hmt-btn-danger" type="button" data-go%s%s>Gộp</button>' % (' data-blocked="1"' if blocked else '', '' if ticked and not blocked else ' disabled')
    return ('<div class="hmt-dialog" data-merge role="dialog" aria-label="%s" style="width:1040px;flex:0 0 1040px"><div class="hmt-dialog-h">Gộp trùng</div><div class="hmt-dialog-b">'
            '<div style="display:flex;gap:var(--space-3);align-items:center;flex-wrap:wrap"><span>Chọn <b>một bản giữ lại</b>. Bản còn lại gộp vào bản giữ lại. Đang so hai %s.</span><span class="hmt-tag hmt-tag-info" style="margin-left:auto">%s · TS-10</span></div>' % (label, 'lead trùng số điện thoại' if kind == 'lead' else 'cơ hội của cùng một học sinh', 'Gộp lead' if kind == 'lead' else 'Gộp cơ hội')
            + alerts + cols(n, kind) + preview(kind) + ack + '</div><div class="hmt-dialog-f"><button class="hmt-btn" type="button" data-cancel>Huỷ</button>' + go + '</div></div>')
def wrap(num, title, sub, d):
    return '<div class="hmt-col" style="gap:var(--space-2)"><div style="font-size:13px;font-weight:600">%s %s <span style="font-weight:400;color:var(--text-secondary)">· %s</span></div><div style="background:var(--bg-subtle);border-radius:var(--radius-lg);padding:var(--space-6);display:flex;justify-content:center;align-items:flex-start">%s</div></div>' % (num, title, sub, d)
body = CSS + ('<div style="padding:24px;display:flex;flex-direction:column;gap:var(--space-5);background:var(--bg-page);height:100%;box-sizing:border-box;overflow-y:auto"><div><h1 style="font-family:var(--font-heading);font-size:20px;line-height:28px;font-weight:600;margin:0">K4f · Hộp thoại “Gộp trùng”</h1>'
    '<span class="hmt-help" style="font-size:13px">Hai cột so sánh hai hồ sơ (chọn bản giữ lại), khối xem trước những gì chuyển sang, cảnh báo và điều kiện chặn, ô tick “không hoàn tác được” bắt buộc trước nút Gộp. TS-10 (gộp lead, cơ hội) và KH-07 (gộp phụ huynh, học sinh) dùng chung; chỉ đổi dòng trường và dòng xem trước. Ví dụ vẽ: gộp lead.</span></div>'
    + wrap('①', 'Chưa tick, nút Gộp mờ', 'cảnh báo khác người phụ trách', dialog(1, 'Gộp trùng', warn('<b>Hai bản khác người phụ trách.</b> Sau khi gộp, người phụ trách là Trần Thu Hà (bản giữ lại). Chuyển người khác thì giao lại sau khi gộp.'), False, False))
    + wrap('②', 'Đã tick, nút Gộp bật', 'bấm Gộp thì đóng hộp và báo kết quả', dialog(2, 'Gộp trùng', warn('<b>Hai bản khác người phụ trách.</b> Sau khi gộp, người phụ trách là Trần Thu Hà (bản giữ lại). Chuyển người khác thì giao lại sau khi gộp.'), True, False))
    + wrap('③', 'Bị chặn, không gộp được', 'ví dụ gộp cơ hội: nêu mã báo giá, đơn hàng gây chặn kèm liên kết mở; ô tick và nút Gộp khoá', dialog(3, 'Gộp trùng', dng('<b>Chưa gộp được.</b> Bản bị gộp CO000140 đã có báo giá <a href="#" data-open-rec="Mở báo giá BG-CS1-2610-0007 (màn BH-02).">BG-CS1-2610-0007</a> và đơn hàng <a href="#" data-open-rec="Mở đơn hàng DH-CS1-2610-0012 (màn BH-05).">DH-CS1-2610-0012</a>. Không gộp cơ hội đã có báo giá hoặc đơn hàng (R-CRM-22).'), False, True, 'co')) + '</div>')
open(REPO + 'K4f.dc.html', 'w', encoding='utf-8').write(pre + body + '</div>' + tail)
print('ok', len(pre + body + tail))
