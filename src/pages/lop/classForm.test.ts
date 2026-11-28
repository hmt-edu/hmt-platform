import { describe, expect, it } from 'vitest';
import { formFromRecord } from './classForm';
import {
  EMPTY_FORM,
  createPayload,
  firstDateOnOrAfter,
  infoPayload,
  isoWeekday,
  newSlot,
  organizationText,
  prefillFromParams,
  remainingClassPath,
  longSlotWarning,
  defaultDayTab,
  slotSummary,
  errorSummary,
  teacherOptionLabel,
  slotsPayload,
  validateForm,
  type ClassFormState,
  type SlotDraft,
} from './classForm';

const valid: ClassFormState = {
  ...EMPTY_FORM,
  branchId: 'b1',
  yearCode: '2627',
  subjectCode: 'DAI',
  gradeCode: 'K09',
  typeCode: 'CB',
  levelCode: 'A',
  curriculumRef: 'DAI-K09-CB-2627',
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

describe('slotSummary (tóm tắt tự sinh từ Time Table, LOP-03)', () => {
  const slot = (o: Partial<SlotDraft>): SlotDraft => ({
    key: 'k',
    weekday: 1,
    start: '18:00',
    end: '19:30',
    teacherId: '',
    assistantId: '',
    roomId: '',
    repeatWeeks: '1',
    firstDate: '',
    ...o,
  });
  const opt = {
    teachers: [{ id: 't1', name: 'Cô Lan' }],
    assistants: [{ id: 'a1', name: 'Anh Nam' }],
    rooms: [{ id: 'r1', name: 'P201' }],
  };
  it('chưa có khung giờ thì báo rõ', () => {
    expect(slotSummary([], opt)).toEqual({
      schedule: 'Chưa có khung giờ',
      rooms: '—',
      teachers: '—',
      assistants: '—',
    });
  });
  it('sắp theo thứ rồi giờ, gộp phòng và người trùng', () => {
    const out = slotSummary(
      [
        slot({ key: 'a', weekday: 4, start: '08:00', end: '09:30', teacherId: 't1', roomId: 'r1' }),
        slot({ key: 'b', weekday: 2, teacherId: 't1', assistantId: 'a1', roomId: 'r1' }),
      ],
      opt,
    );
    expect(out.schedule).toBe('Thứ 3 18:00–19:30; Thứ 5 08:00–09:30');
    expect(out.rooms).toBe('P201');
    expect(out.teachers).toBe('Cô Lan');
    expect(out.assistants).toBe('Anh Nam');
  });
});

describe('longSlotWarning (nhắc khung giờ quá dài, không chặn)', () => {
  it('khung 18:00–19:30 không nhắc', () => {
    expect(longSlotWarning('18:00', '19:30')).toBeNull();
  });
  it('khung 12:30–23:30 nhắc 11 giờ', () => {
    expect(longSlotWarning('12:30', '23:30')).toContain('11 giờ');
  });
  it('giờ trống hoặc kết thúc không sau bắt đầu thì không nhắc (đã có lỗi riêng)', () => {
    expect(longSlotWarning('', '23:30')).toBeNull();
    expect(longSlotWarning('20:00', '19:00')).toBeNull();
  });
});

describe('teacherOptionLabel (gợi ý từ hồ sơ dạy)', () => {
  it('chưa biết hồ sơ thì chỉ tên; chưa có hồ sơ thì ghi rõ nhưng vẫn chọn được', () => {
    expect(teacherOptionLabel({ name: 'Cô Lan' })).toBe('Cô Lan');
    expect(teacherOptionLabel({ name: 'Cô Lan', has_profile: false })).toBe(
      'Cô Lan (chưa có hồ sơ dạy)',
    );
  });
  it('có hồ sơ thì kèm môn, khối', () => {
    expect(
      teacherOptionLabel({
        name: 'Cô Lan',
        has_profile: true,
        subject_names: ['Toán', 'Tiếng Anh'],
        grade_names: ['Lớp 6'],
      }),
    ).toBe('Cô Lan · Toán, Tiếng Anh · Lớp 6');
    expect(teacherOptionLabel({ name: 'Cô Lan', has_profile: true })).toBe('Cô Lan');
  });

  it('Time Table: buổi đầu rơi đúng thứ, kể cả khi khai giảng đúng thứ đó hoặc là Chủ nhật', () => {
    expect(firstDateOnOrAfter('2026-11-17', 2)).toBe('2026-11-17'); // thứ Ba khai giảng thứ Ba
    expect(firstDateOnOrAfter('2026-11-17', 1)).toBe('2026-11-23'); // thứ Hai kế tiếp
    expect(firstDateOnOrAfter('2026-11-22', 7)).toBe('2026-11-22'); // Chủ nhật
    expect(firstDateOnOrAfter('', 2)).toBe('');
    expect(isoWeekday('2026-11-22')).toBe(7);
  });

  it('Time Table: dữ liệu gửi đổi ô trống thành null và cách lặp thành số, giữ nhiều khung một ngày', () => {
    const a: SlotDraft = {
      ...newSlot(2, '2026-11-17'),
      key: 'a',
      teacherId: 't1',
      repeatWeeks: '2',
    };
    const b: SlotDraft = { ...newSlot(2, '2026-11-17'), key: 'b', start: '19:30', end: '21:00' };
    const out = slotsPayload([a, b]);
    expect(out).toHaveLength(2);
    expect(out[0]).toMatchObject({
      weekday: 2,
      teacher_id: 't1',
      assistant_id: null,
      room_id: null,
      repeat_weeks: 2,
    });
    expect(out[1]).toMatchObject({
      start_time: '19:30',
      end_time: '21:00',
      teacher_id: null,
      repeat_weeks: 1,
    });
  });
});

describe('Hình thức học, Tổ chức lớp, Tạo lớp còn lại (LOP-02/03, anh Trường chốt 20/11)', () => {
  it('mặc định Offline và gửi delivery_mode_code khi tạo, khi sửa Nháp; lớp Đã duyệt không gửi', () => {
    expect(EMPTY_FORM.deliveryModeCode).toBe('OFF');
    expect(createPayload({ ...valid, deliveryModeCode: 'OMO' }, null).delivery_mode_code).toBe(
      'OMO',
    );
    expect(infoPayload({ ...valid, deliveryModeCode: 'ONL' }, 'NHAP')).toMatchObject({
      delivery_mode_code: 'ONL',
    });
    expect(infoPayload(valid, 'DA_DUYET')).not.toHaveProperty('delivery_mode_code');
  });
  it('bắt buộc chọn hình thức học khi tạo lớp', () => {
    expect(validateForm({ ...valid, deliveryModeCode: '' }, true, false).deliveryModeCode).toBe(
      'Chọn hình thức học.',
    );
  });
  it('Tổ chức lớp tự suy từ Phân loại: Lớp riêng là Học riêng, còn lại Học chung, chưa chọn thì trống', () => {
    expect(organizationText('LR')).toBe('Học riêng');
    expect(organizationText('CB')).toBe('Học chung');
    expect(organizationText('')).toBe('');
  });
  it('Tạo lớp còn lại: chỉ điền nhóm, cơ sở, năm, khối, phân loại; để trống môn, trình độ, lịch', () => {
    const path = remainingClassPath({
      group_id: 'g1',
      branch_id: 'b1',
      year_code: '2627',
      grade_code: 'K09',
      class_type_code: 'CB',
    });
    const prefill = prefillFromParams(new URL(path, 'http://x').searchParams);
    expect(prefill).toEqual({
      groupMode: 'EXISTING',
      groupId: 'g1',
      branchId: 'b1',
      yearCode: '2627',
      gradeCode: 'K09',
      typeCode: 'CB',
    });
    expect(prefill).not.toHaveProperty('subjectCode');
    expect(prefill).not.toHaveProperty('levelCode');
  });
  it('địa chỉ không có tham số thì không điền sẵn gì', () => {
    expect(prefillFromParams(new URLSearchParams(''))).toEqual({});
  });
});

describe('errorSummary (câu tóm tắt lỗi, LOP-03)', () => {
  it('không lỗi thì không hiện', () => {
    expect(errorSummary({}, [], 'Lưu nháp')).toBeNull();
  });
  it('đếm riêng thông tin lớp và thời khoá biểu theo thứ', () => {
    const slots = [
      { key: 'a', weekday: 6 },
      { key: 'b', weekday: 3 },
      { key: 'c', weekday: 1 },
    ];
    expect(errorSummary({ startDate: 'x', 'slot-a': 'y', 'slot-b': 'z' }, slots, 'Lưu nháp')).toBe(
      'Còn 3 chỗ chưa hợp lệ (1 ở thông tin lớp, 2 ở thời khoá biểu: Thứ 4, Thứ 7). Sửa các ô đỏ rồi bấm Lưu nháp lại.',
    );
  });
});

describe('R-LOP-07: khung chương trình theo phân loại', () => {
  it('lớp chung bắt buộc có khung, lớp riêng thì không', () => {
    const common = validateForm({ ...EMPTY_FORM, typeCode: 'CB' }, true, false);
    expect(common.curriculumRef).toBe('Lớp chung bắt buộc có khung chương trình.');
    const own = validateForm({ ...EMPTY_FORM, typeCode: 'LR' }, true, false);
    expect(own.curriculumRef).toBeUndefined();
  });
  it('lớp đã trình, đã duyệt không đòi lại khung', () => {
    expect(
      validateForm({ ...EMPTY_FORM, typeCode: 'CB' }, false, true).curriculumRef,
    ).toBeUndefined();
  });
});

describe('defaultDayTab (tab Time Table mở sẵn)', () => {
  it('mở thứ đầu tuần có khung giờ', () => {
    expect(defaultDayTab([{ weekday: 7 }, { weekday: 3 }])).toBe('3');
  });
  it('chưa có khung giờ thì Thứ 2', () => {
    expect(defaultDayTab([])).toBe('1');
  });
});
