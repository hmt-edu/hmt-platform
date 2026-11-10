import { describe, expect, it } from 'vitest';
import { formFromRecord } from './classForm';
import {
  EMPTY_FORM,
  createPayload,
  firstDateOnOrAfter,
  infoPayload,
  isoWeekday,
  newSlot,
  slotsPayload,
  validateForm,
  type ClassFormState,
} from './classForm';

const valid: ClassFormState = {
  ...EMPTY_FORM,
  branchId: 'b1',
  yearCode: '2627',
  subjectCode: 'DAI',
  gradeCode: 'K09',
  typeCode: 'CB',
  levelCode: 'A',
  totalSessions: '24',
  startDate: '2026-11-17',
  slots: [{ ...newSlot(2, '2026-11-17'), key: 's1', firstDate: '2026-11-17' }],
};

describe('Biểu mẫu tạo / sửa lớp (LOP-03)', () => {
  it('thứ ISO và buổi đầu mặc định đúng thứ', () => {
    expect(isoWeekday('2026-11-17')).toBe(2); // thứ Ba
    expect(isoWeekday('2026-11-22')).toBe(7); // Chủ nhật
    expect(firstDateOnOrAfter('2026-11-17', 2)).toBe('2026-11-17');
    expect(firstDateOnOrAfter('2026-11-17', 5)).toBe('2026-11-20');
    expect(firstDateOnOrAfter('2026-11-17', 1)).toBe('2026-11-23');
    expect(firstDateOnOrAfter('', 1)).toBe('');
  });

  it('hợp lệ thì không lỗi', () => {
    expect(validateForm(valid, true, false)).toEqual({});
  });

  it('thiếu trường bắt buộc thì báo từng trường', () => {
    const e = validateForm({ ...EMPTY_FORM }, true, false);
    for (const key of [
      'branchId',
      'yearCode',
      'subjectCode',
      'gradeCode',
      'typeCode',
      'totalSessions',
      'startDate',
    ])
      expect(e[key]).toBeTruthy();
  });

  it('lớp riêng không cần trình độ, lớp thường cần', () => {
    expect(
      validateForm({ ...valid, typeCode: 'LR', levelCode: '' }, true, false).levelCode,
    ).toBeUndefined();
    expect(validateForm({ ...valid, levelCode: '' }, true, false).levelCode).toBeTruthy();
  });

  it('nhóm lớp chỉ cho Đại số và Hình học (R-LOP-14)', () => {
    expect(
      validateForm({ ...valid, subjectCode: 'TOAN', groupMode: 'NEW' }, true, false).groupMode,
    ).toBeTruthy();
    expect(
      validateForm({ ...valid, groupMode: 'EXISTING', groupId: '' }, true, false).groupId,
    ).toBeTruthy();
  });

  it('khung giờ: giờ kết thúc sau giờ bắt đầu, buổi đầu đúng thứ, cách lặp từ 1', () => {
    const slot = valid.slots[0]!;
    expect(
      validateForm({ ...valid, slots: [{ ...slot, end: '17:00' }] }, true, false)['slot-s1'],
    ).toBeTruthy();
    expect(
      validateForm({ ...valid, slots: [{ ...slot, firstDate: '2026-11-18' }] }, true, false)[
        'slot-s1'
      ],
    ).toBeTruthy();
    expect(
      validateForm({ ...valid, slots: [{ ...slot, repeatWeeks: '0' }] }, true, false)['slot-s1'],
    ).toBeTruthy();
  });

  it('lớp Đã duyệt bắt buộc ngày áp dụng Time Table', () => {
    expect(validateForm({ ...valid, applyFrom: '' }, false, true).applyFrom).toBeTruthy();
    expect(
      validateForm({ ...valid, applyFrom: '2026-11-24' }, false, true).applyFrom,
    ).toBeUndefined();
  });

  it('dữ liệu gửi tạo lớp: lớp riêng không gửi trình độ, giá trị trống thành null', () => {
    const p = createPayload({ ...valid, typeCode: 'LR', levelCode: 'A', maxStudents: '' }, null);
    expect(p.level_code).toBeNull();
    expect(p.max_students).toBe(0);
    expect(p.cskh_id).toBeNull();
    expect(p.slots).toEqual(slotsPayload(valid.slots));
  });

  it('lớp Đã duyệt chỉ gửi CSKH và sĩ số tối đa (R-LOP-02)', () => {
    expect(Object.keys(infoPayload({ ...valid, maxStudents: '12' }, 'DA_DUYET')).sort()).toEqual([
      'cskh_id',
      'max_students',
    ]);
    expect(Object.keys(infoPayload(valid, 'NHAP'))).toContain('start_date');
  });

  it('dựng biểu mẫu từ hồ sơ lớp', () => {
    const f = formFromRecord({
      id: 'c1',
      code: 'X',
      legacy_ref: null,
      branch_id: 'b1',
      branch_code: 'CS1',
      subject_code: 'DAI',
      subject_name: null,
      grade_code: 'K09',
      class_type_code: 'CB',
      class_type_name: null,
      level_code: 'A',
      level_name: null,
      status_code: 'NHAP',
      status_name: null,
      operating_status: null,
      max_students: 20,
      seats_left: 20,
      start_date: '2026-11-17',
      expected_end_date: null,
      total_sessions: 24,
      group_name: null,
      schedule: [],
      teacher_names: null,
      year_code: '2627',
      curriculum_ref: null,
      start_lesson: null,
      cskh_id: null,
      group_id: 'g1',
      slots: [
        {
          id: 's1',
          weekday: 2,
          start_time: '18:00:00',
          end_time: '19:30:00',
          repeat_weeks: 2,
          first_date: '2026-11-17',
          teacher_id: 't1',
          assistant_id: null,
          room_id: null,
          teacher_name: null,
          assistant_name: null,
          room_name: null,
        },
      ],
      students: [],
      session_counts: {},
      sessions: [],
      clash_warnings: [],
      events: [],
    });
    expect(f.groupMode).toBe('EXISTING');
    expect(f.slots[0]).toMatchObject({
      weekday: 2,
      start: '18:00',
      end: '19:30',
      teacherId: 't1',
      repeatWeeks: '2',
    });
  });
});
