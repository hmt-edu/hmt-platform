import { describe, expect, it } from 'vitest';
import { editKind, transitionsFrom } from './classTransitions';

const to = (status: string) => transitionsFrom(status).map((t) => t.to);

describe('Chuyển tình trạng lớp (LOP-05, LOP-06, R-LOP-01)', () => {
  it('đúng các đường đi', () => {
    expect(to('NHAP')).toEqual(['DA_TRINH', 'HUY']);
    expect(to('DA_TRINH')).toEqual(['DA_XAC_NHAN', 'TU_CHOI', 'NHAP', 'HUY']);
    expect(to('DA_XAC_NHAN')).toEqual(['DA_DUYET', 'TU_CHOI', 'NHAP', 'HUY']);
    expect(to('DA_DUYET')).toEqual(['DA_DONG', 'HUY']);
    expect(to('TU_CHOI')).toEqual(['NHAP', 'HUY']);
  });

  it('lớp Đã đóng hoặc Huỷ không đi tiếp', () => {
    expect(to('DA_DONG')).toEqual([]);
    expect(to('HUY')).toEqual([]);
  });

  it('Từ chối bắt buộc ghi lý do; Huỷ và Đóng là thao tác nguy hiểm', () => {
    const reject = transitionsFrom('DA_TRINH').find((t) => t.to === 'TU_CHOI');
    expect(reject?.noteRequired).toBe(true);
    expect(transitionsFrom('DA_DUYET').every((t) => t.danger)).toBe(true);
  });

  it('kiểu sửa theo tình trạng', () => {
    expect(editKind('NHAP')).toBe('FULL');
    expect(editKind('TU_CHOI')).toBe('FULL');
    expect(editKind('DA_DUYET')).toBe('TIMETABLE');
    expect(editKind('DA_DONG')).toBeNull();
  });
});
