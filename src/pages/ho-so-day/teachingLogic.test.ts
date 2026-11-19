import { describe, expect, it } from 'vitest';
import {
  EMPTY_TEACHING_STATE,
  NOTE_MAX_LENGTH,
  buildTeachingFilters,
  noteError,
  profilePayload,
  toggleCode,
} from './teachingLogic';

describe('buildTeachingFilters', () => {
  it('trạng thái rỗng thì không có bộ lọc', () => {
    expect(buildTeachingFilters(EMPTY_TEACHING_STATE)).toEqual({});
  });
  it('tìm, lọc nhanh Loại và Tình trạng (chỉ khi chọn đúng một giá trị)', () => {
    expect(
      buildTeachingFilters({
        ...EMPTY_TEACHING_STATE,
        search: ' lan ',
        quick: { kind: ['GV'], active: ['DANG_DAY'] },
      }),
    ).toEqual({ search: 'lan', kind: 'GV', active: true });
    expect(
      buildTeachingFilters({
        ...EMPTY_TEACHING_STATE,
        quick: { kind: ['GV', 'TG'], active: ['NGUNG'] },
      }),
    ).toEqual({ active: false });
  });
  it('điều kiện nâng cao: môn, khối, cơ sở', () => {
    expect(
      buildTeachingFilters({
        ...EMPTY_TEACHING_STATE,
        conditions: [
          { id: 'c1', field: 'subject', op: 'eq', value: 'TOAN' },
          { id: 'c2', field: 'grade', op: 'eq', value: 'K06' },
          { id: 'c3', field: 'branch', op: 'eq', value: 'b1' },
          { id: 'c4', field: 'subject', op: 'ne', value: 'ANH' },
        ],
      }),
    ).toEqual({ subject: 'TOAN', grade: 'K06', branch_id: 'b1' });
  });
});

describe('toggleCode', () => {
  it('thêm và bỏ một mã, không trùng', () => {
    expect(toggleCode(['A'], 'B', true)).toEqual(['A', 'B']);
    expect(toggleCode(['A', 'B'], 'B', true)).toEqual(['A', 'B']);
    expect(toggleCode(['A', 'B'], 'A', false)).toEqual(['B']);
  });
});

describe('noteError, profilePayload', () => {
  it('ghi chú quá dài bị báo', () => {
    expect(noteError('x'.repeat(NOTE_MAX_LENGTH))).toBeNull();
    expect(noteError('x'.repeat(NOTE_MAX_LENGTH + 1))).toContain('tối đa');
  });
  it('dữ liệu gửi: thêm có user_id, sửa có id; ghi chú trống là null', () => {
    expect(
      profilePayload({ userId: 'u1', subjects: ['TOAN'], grades: [], branchIds: ['b'], note: ' ' }),
    ).toEqual({
      user_id: 'u1',
      subject_codes: ['TOAN'],
      grade_codes: [],
      branch_ids: ['b'],
      note: null,
    });
    expect(
      profilePayload({ id: 'p1', subjects: [], grades: [], branchIds: [], note: 'Dạy tối' }),
    ).toMatchObject({
      id: 'p1',
      note: 'Dạy tối',
    });
  });
});
