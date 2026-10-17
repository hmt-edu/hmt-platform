# -*- coding: utf-8 -*-
import sys, json; sys.path.insert(0, 'scripts')
import p5a_canvas as K
K.P = 'p5b/project/'
from p5a_canvas import B, NOTE, build
def ls(p): return [B(p), B(p + '_trong'), B(p + '_tai'), B(p + '_khong_quyen')]
def c1():
    return [dict(title='P5b · ĐÀO TẠO', sub='Giai đoạn 2, máy tính. Cụm 1: Ghi danh. Mọi màn bấm được (hộp thoại, tab, trạng thái). Ghi chú lệch khuôn và câu hỏi: khung cuối canvas (khi xong hết các cụm).', items=[B('P5b_Tong_quan')]),
            dict(title='GD · GHI DANH (danh sách, bản ghi)', items=ls('GD01')),
            dict(items=[B('GD02_' + x) for x in ('dang_hoc', 'da_xep', 'cho_xep', 'bao_luu', 'het_gio', 'hoc_truoc', 'hoan_phi', 'tai')]),
            dict(items=[B('GD02_quyen'), B('GD05_dieu_chinh')]),
            dict(title='GD · XẾP LỚP (hộp thoại GD-03)', items=[B('GD03_' + x) for x in ('nhom', 'le', 'trung_gio', 'nhac_mem', 'trong', 'tai')]),
            dict(title='GD · SỔ GIỜ (GD-04)', items=ls('GD04')),
            dict(title='GD · HÀNG CHỜ XẾP LỚP (GD-06), SẮP HẾT GIỜ (GD-07)', items=ls('GD06')),
            dict(items=ls('GD07'))]
def write(rws, extra_order=None):
    boards, order, notes = build(rws)
    idx = dict(v=3, createdOnFiles=dict(v=1, at='2026-10-17T10:30:00Z'), title='P5b Đào tạo', launch=dict(view='canvas'), pages=[], boards=boards, order=order, notes=notes,
               designSystems=[dict(title='HMT Platform', namespace='hmt', artifact='https://claude.ai/artifact/3Yco5qmVbyDiyfZm9HcJqN', version='1792124962-8639', copiedAt='2026-10-17T10:30:00Z')])
    json.dump(idx, open('p5b/project/canvas.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1); return order
if __name__ == '__main__': print(len(write(c1())), 'boards')
