import { describe, expect, it } from 'vitest';
import { classNotes, recordSlotSummary } from './classLabels';

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
  it('Đã đóng, Huỷ: chỉ còn xem', () => {
    expect(classNotes('DA_DONG', 3).top?.text).toBe('Lớp đã đóng, chỉ còn xem.');
    expect(classNotes('HUY', 0).top?.text).toBe('Lớp đã huỷ, chỉ còn xem.');
  });
  it('Đã xác nhận: câu trên đầu chờ duyệt; Từ chối có khung giờ: nhắc Đưa về Nháp', () => {
    expect(classNotes('DA_XAC_NHAN', 1).top?.text).toMatch(/chờ quản lý cơ sở duyệt/);
    expect(classNotes('TU_CHOI', 1).top?.text).toMatch(/Đưa về Nháp/);
  });
});

describe('recordSlotSummary (bốn ô tự sinh từ Time Table, LOP-02)', () => {
  it('gom lịch, phòng, giáo viên, trợ giảng không trùng, sắp theo thứ rồi giờ', () => {
    const r = recordSlotSummary([
      {
        weekday: 5,
        start_time: '18:00:00',
        end_time: '19:30:00',
        teacher_name: 'An',
        room_name: 'P201',
      },
      {
        weekday: 2,
        start_time: '18:00:00',
        end_time: '19:30:00',
        teacher_name: 'An',
        assistant_name: 'Bình',
        room_name: 'P201',
      },
    ]);
    expect(r.schedule).toBe('Thứ 3 18:00–19:30 · Thứ 6 18:00–19:30');
    expect(r.rooms).toBe('P201');
    expect(r.teachers).toBe('An');
    expect(r.assistants).toBe('Bình');
  });
  it('chưa có khung giờ: câu theo canvas, không có giáo viên thì Chưa phân công', () => {
    const r = recordSlotSummary([]);
    expect(r.schedule).toBe('Chưa có lịch học (chưa có Time Table)');
    expect(r.teachers).toBe('Chưa phân công');
    expect(r.assistants).toBe('Không có');
  });
});
