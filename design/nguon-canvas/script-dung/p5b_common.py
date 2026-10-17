# -*- coding: utf-8 -*-
# P5b Đào tạo: dùng lại bộ dựng P5a, ghi vào p5b/project
import sys; sys.path.insert(0, 'scripts')
import p5a_common as CM
CM.OUTD = 'p5b/project/'
from p5a_common import *
from p5a_list import *
import p5a_list as PL
from p5a_dh import cls_row, empty_inline
from p5a_bh import PH_NAME, PH_CODE

def hh(x): return ('%.1f' % x).replace('.', ',').replace(',0', '') if isinstance(x, float) else str(x)
def sgn(n, unit=''):  # số có dấu, căn phải
    s = hh(abs(n)); return '<span class="hmt-num"%s>%s%s</span>' % (' style="color:var(--danger-text)"' if n < 0 else '', ('−' if n < 0 else '+') + s, unit)
def count4(items):
    return '<div style="display:flex;gap:var(--space-3)">' + ''.join('<div class="hmt-count%s" style="flex:1;min-width:0"><span class="hmt-count-t">%s</span><span class="hmt-count-v">%s</span></div>' % (' hmt-count-hl' if hl else '', t, v) for t, v, hl in items) + '</div>'
def gcode(c, name=None, grp=None):
    return '<span class="hmt-code">%s</span>' % c + (('<div class="hmt-help">%s%s</div>' % (name, (' · nhóm ' + grp) if grp else '')) if name else '')
