import { describe, expect, it } from 'vitest';
import {
  EMPTY_CLASS_STUDENT_STATE,
  buildClassStudentFilters,
  classStudentSortParam,
  classTitleLabel,
} from './classStudents';
import { studentStateLabel } from './classStudentsConfig';

describe('LOP-09 học sinh của lớp', () => {
  it('bộ lọc: tìm, tình trạng, hình thức học', () => {
    expect(buildClassStudentFilters(EMPTY_CLASS_STUDENT_STATE)).toEqual({});
    expect(
      buildClassStudentFilters({
        ...EMPTY_CLASS_STUDENT_STATE,
        search: '  Hân ',
        quick: { state: ['DA_ROI'], delivery: ['OFF'] },
      }),
    ).toEqual({ search: 'Hân', state: ['DA_ROI'], delivery: ['OFF'] });
  });
  it('sắp xếp: mặc định theo tên; ngày vào mới nhất; giờ còn ít nhất', () => {
    expect(classStudentSortParam(null, null)).toBe('name_asc');
    expect(classStudentSortParam('start', 'desc')).toBe('start_desc');
    expect(classStudentSortParam('hours', 'asc')).toBe('hours_asc');
    expect(classStudentSortParam('start', 'asc')).toBe('name_asc');
  });
  it('tình trạng: đã rời thì Đã rời, còn thì tình trạng ghi danh', () => {
    const name = (c: string) => (c === 'DANG_HOC' ? 'Đang học' : undefined);
    expect(studentStateLabel({ end_date: '2026-10-01', enrollment_status: 'DANG_HOC' }, name)).toBe(
      'Đã rời',
    );
    expect(studentStateLabel({ end_date: null, enrollment_status: 'DANG_HOC' }, name)).toBe(
      'Đang học',
    );
    expect(studentStateLabel({ end_date: null, enrollment_status: 'X' }, name)).toBe('X');
  });
});

describe('classTitleLabel (tiêu đề LOP-09)', () => {
  const base = {
    subject_name: 'Đại số',
    subject_code: 'DAI',
    grade_code: 'K09',
    class_type_name: 'Cơ bản',
    level_name: 'A',
  };
  it('«Đại số 9 · cơ bản A» theo canvas LOP09', () => {
    expect(classTitleLabel(base)).toBe('Đại số 9 · cơ bản A');
  });
  it('lớp riêng không có trình độ', () => {
    expect(classTitleLabel({ ...base, class_type_name: 'Lớp riêng', level_name: null })).toBe(
      'Đại số 9 · lớp riêng',
    );
  });
  it('thiếu tên môn thì dùng mã môn', () => {
    expect(classTitleLabel({ ...base, subject_name: null })).toBe('DAI 9 · cơ bản A');
  });
});
