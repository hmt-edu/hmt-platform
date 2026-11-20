import { describe, expect, it } from 'vitest';
import { classNotes } from './classLabels';

describe('classNotes (câu theo tình trạng duyệt, LOP-02)', () => {
  it('Nháp chưa có khung giờ: báo chưa trình được và chỉ cách thêm', () => {
    const n = classNotes('NHAP', 0);
    expect(n.top?.tone).toBe('warning');
    expect(n.top?.text).toMatch(/chưa trình được/);
    expect(n.bottom).toMatch(/R-LOP-03/);
  });
  it('Nháp đã có khung giờ: chỉ nhắc sửa được thông tin', () => {
    expect(classNotes('NHAP', 2).top?.text).toBe('Lớp ở Nháp: sửa được thông tin.');
  });
  it('Đã trình: chỉ sửa Time Table (R-LOP-02)', () => {
    expect(classNotes('DA_TRINH', 1).top?.text).toMatch(/R-LOP-02/);
  });
  it('Đã duyệt: câu R-LOP-11 dưới Time Table, không có dòng trên đầu', () => {
    const n = classNotes('DA_DUYET', 3);
    expect(n.bottom).toMatch(/R-LOP-11/);
    expect(n.top).toBeUndefined();
  });
  it('Đã đóng, Huỷ: không có câu', () => {
    expect(classNotes('DA_DONG', 3)).toEqual({});
    expect(classNotes('HUY', 0)).toEqual({});
  });
});
