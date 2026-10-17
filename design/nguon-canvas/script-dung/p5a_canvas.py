# -*- coding: utf-8 -*-
import json, re, os, datetime
P = 'p5a/project/'
def ttl(n): return re.search(r'<title>([^<]*)</title>', open(P + n + '.dc.html', encoding='utf-8').read()).group(1).replace('&amp;', '&')
def NOTE(**k): return ('note', k)
def B(n): return ('board', n)
STOP_K13 = ('DỪNG · BH-03 Bản in báo giá (khuôn K13). P0 chưa có khuôn bản in. Khuôn gần nhất: K06 (bản ghi). Còn thiếu: khổ giấy A4 và ảnh gửi tin nhắn, đầu trang logo cơ sở, khối thông tin phụ huynh và bảng dòng gói, hạn hiệu lực, chỗ ký, nút In và Tải PDF. Chưa vẽ, chờ anh duyệt khuôn K13 (xem câu hỏi 1).')
STOP_TC07 = ('DỪNG · TC-07 Bản in phiếu thu, biên nhận (khuôn K13). P0 chưa có khuôn bản in. Khuôn gần nhất: K06 (bản ghi). Còn thiếu: khổ A5 và A4, đầu trang logo cơ sở, thông tin phụ huynh, số tiền bằng số và bằng chữ, hình thức, ngày nhận, chỗ ký người nộp và người thu, nút In và Tải PDF. Chưa vẽ, chờ anh duyệt khuôn K13 (xem câu hỏi 1).')
def cluster2():
    R = []
    R.append(dict(title='TC · PHIẾU THU (danh sách, bản ghi, tạo từ đơn)', items=[B('TC01'), B('TC01_trong'), B('TC01_tai'), B('TC01_khong_quyen')]))
    R.append(dict(items=[B('TC02_' + x) for x in ('nhap', 'nhap_loi', 'trinh', 'trinh_kt', 'trinh_ad', 'duyet', 'tu_choi', 'huy')]))
    R.append(dict(items=[B('TC02_tai'), B('TC02_quyen'), B('TC03_tao'), B('TC07_in')]))
    R.append(dict(title='TC · KẾ TOÁN DUYỆT, TỪ CHỐI (TC-05, hộp thoại)', items=[B('TC05_' + x) for x in ('du_coc', 'chua_du', 'qua_buoi', 'tu_choi', 'admin', 'tai')]))
    R.append(dict(title='TC · HÀNG CHỜ KẾ TOÁN DUYỆT (TC-04)', items=[B('TC04'), B('TC04_trong'), B('TC04_tai'), B('TC04_khong_quyen'), B('TC04_admin')]))
    R.append(dict(title='TC · KHOẢN TIỀN VÀO, ĐẢO KHOẢN (TC-08, TC-09)', items=[B('TC08'), B('TC08_trong'), B('TC08_tai'), B('TC08_khong_quyen'), B('TC08_bm'), B('TC09_dao'), B('TC09_chan')]))
    R.append(dict(title='TC · ĐỐI SOÁT THU TIỀN (TC-15, khuôn K09)', items=[B('TC15'), B('TC15_trong'), B('TC15_tai'), B('TC15_khong_quyen')]))
    return R

def cluster3():
    return [dict(title='TC · PHIẾU CHI (danh sách, bản ghi từ ticket hoàn tiền)', items=[B('TC10'), B('TC10_trong'), B('TC10_tai'), B('TC10_khong_quyen'), B('TC11'), B('TC11_tai'), B('TC11_khong_quyen')]),
            dict(title='TC · CÔNG NỢ (TC-13)', items=[B('TC13'), B('TC13_trong'), B('TC13_tai'), B('TC13_khong_quyen')]),
            dict(title='GHI CHÚ CUỐI CANVAS: chỗ lệch, câu hỏi, màn dừng', items=[B('P5a_Ghi_chu')])]

def rows(extra=()):
    R = []
    R.append(dict(title='P5a · BÁN HÀNG VÀ THU CHI', sub='Giai đoạn 1, máy tính. Cụm 1: Báo giá, Đơn hàng. Cụm 2: Phiếu thu, Kế toán duyệt, Khoản tiền vào, Đối soát. Cụm 3: Phiếu chi, Công nợ. Mọi màn bấm được (hộp thoại, tab, trạng thái). Ghi chú lệch khuôn và câu hỏi: khung cuối canvas.', items=[B('P5a_Tong_quan'),
        NOTE(text='MỨC C, KHÔNG VẼ (chỉ ghi dựng từ khuôn nào): BH-04 Từ chối báo giá = hộp K08 có lý do (giống hộp Từ chối ở P3). BH-10 Huỷ đơn = hộp K08 có lý do, đơn có tiền thì chỉ dẫn đi ticket CS-05. BH-11 Cơ hội đã có đơn nháp = hộp K08 xác nhận hai nút. TC-06 Huỷ phiếu thu = hộp K08 có lý do. TC-12 Bản in phiếu chi = K13 (khuôn mới đề xuất, đã duyệt). TC-14 Số dư khách hàng = danh sách K03. TC-16 Dùng số dư = hộp K08 xác nhận.', fill='orange', w=900, maxH=420, size='m')]))
    R.append(dict(title='BH · BÁO GIÁ', items=[B('BH01'), B('BH01_trong'), B('BH01_tai'), B('BH01_khong_quyen'), B('BH03_in')]))
    R.append(dict(items=[B('BH02_' + x) for x in ('nhap', 'sua', 'gui', 'don', 'tu_choi', 'het_han', 'tai', 'quyen')]))
    R.append(dict(title='BH · ĐƠN HÀNG', items=[B('BH06'), B('BH06_trong'), B('BH06_tai'), B('BH06_khong_quyen')]))
    R.append(dict(items=[B('BH05_' + x) for x in ('nhap', 'nhap_loi', 'trinh', 'tran', 'tu_choi', 'duyet', 'duyet_ht', 'thu')]))
    R.append(dict(items=[B('BH05_huy'), B('BH05_tai'), B('BH05_quyen'), B('BH07_duyet'), B('BH09_bat')]))
    R.append(dict(title='BH · CHỌN LỚP VÀ NGÀY VÀO LỚP (hộp thoại)', items=[B('BH08_' + x) for x in ('co_buoi', 'luan_phien', 'chua_buoi', 'trong', 'tai')]))
    for r in extra: R.append(r)
    return R

def build(rws):
    boards = {}; order = []; notes = {}; y = 0; ni = 0
    for r in rws:
        if r.get('title'):
            y_t = y; notes['t%d' % ni] = dict(x=0, y=y_t, text=r['title'], kind='title1', maxW=12080); ni += 1
            if r.get('sub'): notes['s%d' % ni] = dict(x=0, y=y_t + 100, text=r['sub'], fill='orange', w=1400, maxH=150); ni += 1
            y += 300
        x = 0
        for kind, it in r['items']:
            if kind == 'board':
                boards[it + '.dc.html'] = dict(x=x, y=y, w=1440, h=1000, title=ttl(it), expand='fill', is_interactive=True); order.append(it + '.dc.html'); x += 1520
            else:
                d = dict(x=x, y=y, **it); notes['n%d' % ni] = d; ni += 1; x += it.get('w', 700) + 80
        y += 1120
    return boards, order, notes

def write(rws):
    boards, order, notes = build(rws)
    idx = dict(v=3, createdOnFiles=dict(v=1, at='2026-10-17T09:40:00Z'), title='P5a Bán hàng và Thu chi', launch=dict(view='canvas'), pages=[], boards=boards, order=order, notes=notes,
               designSystems=[dict(title='HMT Platform', namespace='hmt', artifact='https://claude.ai/artifact/3Yco5qmVbyDiyfZm9HcJqN', version='1792124962-8639', copiedAt='2026-10-17T09:40:00Z')])
    json.dump(idx, open(P + 'canvas.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    return order

if __name__ == '__main__':
    o = write(rows(cluster2() + cluster3())); print(len(o), 'boards')
