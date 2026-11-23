import { describe, expect, it } from 'vitest';
import {
  buildEntries,
  countMarked,
  effectiveStatus,
  fillRemaining,
  isAbsent,
  needsAbsenceConfirm,
  otherEditorLabel,
  setDraft,
  sheetTitle,
  sheetWhen,
  summarizeStatuses,
  type AttendanceStudent,
} from './attendanceLogic';

const mk = (id: string, status: string | null, review = false): AttendanceStudent => ({
  student_id: id,
  student_code: id,
  full_name: `Em ${id}`,
  is_trial: false,
  contact_reason_name: null,
  teacher_status_code: status,
  teacher_marked_at: status ? `2026-11-10T08:00:0${id}Z` : null,
  has_review: review,
});
const students = [mk('1', 'CO_MAT', true), mk('2', null), mk('3', 'VANG_CO_PHEP'), mk('4', null)];

describe('GV-05: bản nháp điểm danh', () => {
  it('đếm số em đã điểm danh kể cả bản nháp', () => {
    expect(countMarked(students, {})).toBe(2);
    expect(countMarked(students, { '2': 'CO_MAT' })).toBe(3);
    expect(countMarked(students, { '1': null })).toBe(1);
  });
  it('đặt đúng giá trị đã lưu thì không còn là thay đổi', () => {
    const d = setDraft({}, students[0]!, 'DI_MUON');
    expect(d).toEqual({ '1': 'DI_MUON' });
    expect(setDraft(d, students[0]!, 'CO_MAT')).toEqual({});
  });
  it('trạng thái đang hiện lấy bản nháp trước', () => {
    expect(effectiveStatus(students[0]!, { '1': 'DI_MUON' })).toBe('DI_MUON');
    expect(effectiveStatus(students[0]!, {})).toBe('CO_MAT');
    expect(effectiveStatus(students[0]!, { '1': null })).toBeNull();
  });
  it('"Còn lại: Có mặt" chỉ đặt em còn trống, giữ em đã có trạng thái', () => {
    expect(fillRemaining(students, {}, 'CO_MAT')).toEqual({ '2': 'CO_MAT', '4': 'CO_MAT' });
    expect(fillRemaining(students, { '2': 'VANG_KHONG_PHEP' }, 'CO_MAT')).toEqual({
      '2': 'VANG_KHONG_PHEP',
      '4': 'CO_MAT',
    });
  });
  it('danh sách gửi máy chủ chỉ gồm ô đã đổi, kèm giờ ghi lúc mở màn; xoá ô gửi chuỗi rỗng', () => {
    const base = { '1': '2026-11-10T08:00:01Z', '2': null };
    expect(buildEntries(students, { '1': 'DI_MUON', '2': null }, base)).toEqual([
      { student_id: '1', status_code: 'DI_MUON', base_marked_at: '2026-11-10T08:00:01Z' },
      { student_id: '2', status_code: '', base_marked_at: null },
    ]);
  });
});

describe('GV-05: hộp xác nhận Có mặt → Vắng (R-V2-36)', () => {
  it('hỏi khi em đã có điểm nhận xét và đổi từ Có mặt sang Vắng', () => {
    expect(needsAbsenceConfirm(students[0]!, {}, 'VANG_CO_PHEP')).toBe(true);
    expect(needsAbsenceConfirm(students[0]!, { '1': 'DI_MUON' }, 'VANG_KHONG_PHEP')).toBe(true);
  });
  it('không hỏi khi em chưa có điểm, hoặc đổi giữa hai trạng thái có mặt, hoặc đã là Vắng, hoặc ô trống', () => {
    expect(needsAbsenceConfirm(mk('9', 'CO_MAT', false), {}, 'VANG_CO_PHEP')).toBe(false);
    expect(needsAbsenceConfirm(students[0]!, {}, 'DI_MUON')).toBe(false);
    expect(
      needsAbsenceConfirm(
        { ...students[0]!, teacher_status_code: 'VANG_CO_PHEP' },
        {},
        'VANG_KHONG_PHEP',
      ),
    ).toBe(false);
    expect(needsAbsenceConfirm(mk('8', null, true), {}, 'VANG_CO_PHEP')).toBe(false);
    expect(needsAbsenceConfirm(students[0]!, {}, null)).toBe(false);
  });
  it('nhận ra trạng thái Vắng theo mã', () => {
    expect(isAbsent('VANG_CO_PHEP')).toBe(true);
    expect(isAbsent('VANG_KHONG_PHEP')).toBe(true);
    expect(isAbsent('DI_MUON')).toBe(false);
  });
});

describe('GV-05: chữ hiển thị', () => {
  const conflict = (name: string | null) => ({
    student_id: '1',
    full_name: 'Em 1',
    current_status_code: 'DI_MUON',
    marked_by_name: name,
    marked_at: null,
  });
  it('nút "Lấy của …"', () => {
    expect(otherEditorLabel([conflict('Lê Thu Hà')])).toBe('Lấy của Lê Thu Hà');
    expect(otherEditorLabel([conflict('Lê Thu Hà'), conflict('Lê Thu Hà')])).toBe(
      'Lấy của Lê Thu Hà',
    );
    expect(otherEditorLabel([conflict('A'), conflict('B')])).toBe('Lấy của người kia');
  });
  it('tiêu đề và giờ của buổi', () => {
    const session = {
      id: 'x',
      status_code: 'DA_CHOT',
      type_code: 'CHINH',
      session_no: 5,
      session_date: '2026-10-24',
      start_time: '18:00',
      end_time: '19:30',
      class_code: 'L',
      subject_name: 'Đại số 9',
      class_type_name: 'cơ bản',
      level_name: 'A',
    };
    expect(sheetTitle(session)).toBe('Đại số 9 · cơ bản A · Buổi 5');
    expect(
      sheetTitle({ ...session, level_name: null, class_type_name: 'riêng', session_no: null }),
    ).toBe('Đại số 9 · riêng');
    expect(sheetWhen(session)).toBe('24/10 18:00–19:30');
  });
});

describe('GV-05: dòng tóm tắt sau khi lưu (GV05_buoc_tiep)', () => {
  const statuses = [
    { code: 'CO_MAT', name: 'Có mặt' },
    { code: 'DI_MUON', name: 'Đi muộn' },
    { code: 'VANG_CO_PHEP', name: 'Vắng có phép' },
  ];
  it('đếm theo từng trạng thái theo thứ tự danh mục, bỏ trạng thái không em nào', () => {
    expect(summarizeStatuses(students, statuses, {})).toBe('Có mặt 1 · Vắng có phép 1');
  });
  it('tính cả bản nháp; chưa em nào được điểm danh thì chuỗi rỗng', () => {
    expect(summarizeStatuses(students, statuses, { '2': 'CO_MAT' })).toBe(
      'Có mặt 2 · Vắng có phép 1',
    );
    expect(summarizeStatuses([mk('9', null)], statuses, {})).toBe('');
  });
});
