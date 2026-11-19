import { describe, expect, it } from 'vitest';
import {
  anyDirty,
  buildExamSave,
  entryOf,
  gradedProgress,
  initialDraft,
  isExamEditable,
  parseScore,
  statusOf,
  type ExamConfig,
  type ExamSheet,
  type ExamStudent,
} from './exam';

const TONG: ExamConfig = {
  scope_text: null,
  max_score: 10,
  entry_mode: 'TONG',
  max_memory: 0,
  max_understand: 0,
  max_apply: 0,
};
const NHOM: ExamConfig = {
  ...TONG,
  entry_mode: 'NHOM',
  max_memory: 3,
  max_understand: 4,
  max_apply: 3,
};
const st = (id: string, over: Partial<ExamStudent> = {}): ExamStudent => ({
  student_id: id,
  full_name: id,
  attendance_code: 'CO_MAT',
  attendance_name: 'Có mặt',
  score: null,
  comment: null,
  improvement: null,
  ...over,
});
const sheet = (exam: ExamConfig | null, students: ExamStudent[]): ExamSheet => ({
  session: {
    session_id: 's',
    status_code: 'DA_CHOT',
    type_code: 'KIEM_TRA',
    review_form: 'DIEM',
    session_no: 6,
    session_date: '2026-10-31',
    start_time: '18:00',
    end_time: '19:30',
    class_code: 'L',
    subject_name: null,
  },
  exam,
  students,
});
const draft = (over: Partial<ReturnType<typeof initialDraft>>) => ({
  ...initialDraft(st('x')),
  ...over,
});

describe('Chấm kiểm tra (GV-07K)', () => {
  it('đọc số có dấu phẩy; ô trống không phải 0', () => {
    expect(parseScore('8,5')).toBe(8.5);
    expect(parseScore(' ')).toBeNull();
    expect(parseScore('abc')).toBeNull();
    expect(entryOf(draft({}), TONG).empty).toBe(true);
    expect(entryOf(draft({ total: '0' }), TONG)).toEqual({ total: 0, error: null, empty: false });
  });

  it('điểm tổng: ngoài 0 đến tối đa là lỗi', () => {
    expect(entryOf(draft({ total: '11' }), TONG).error).toBe('Điểm phải từ 0 đến 10.');
    expect(entryOf(draft({ total: '-1' }), TONG).error).not.toBeNull();
    expect(entryOf(draft({ total: '9' }), TONG).total).toBe(9);
  });

  it('3 nhóm: tổng tự cộng, nhóm vượt tối đa hoặc thiếu là lỗi', () => {
    expect(entryOf(draft({ memory: '3', understand: '4', apply: '2' }), NHOM).total).toBe(9);
    expect(entryOf(draft({ memory: '4', understand: '4', apply: '2' }), NHOM).error).toBe(
      'Điểm Ghi nhớ phải từ 0 đến 3.',
    );
    expect(entryOf(draft({ memory: '3', understand: '4' }), NHOM).error).toBe(
      'Nhập điểm Vận dụng (0 đến 3).',
    );
  });

  it('nhóm không có đề (tối đa 0) được bỏ qua', () => {
    const cfg = { ...NHOM, max_apply: 0, max_memory: 5, max_understand: 5 };
    expect(entryOf(draft({ memory: '5', understand: '5' }), cfg).total).toBe(10);
  });

  it('lô lưu: chỉ em có mặt đã sửa; em vắng không gửi', () => {
    const a = st('a');
    const v = st('v', { attendance_code: 'VANG_CO_PHEP' });
    const sh = sheet(TONG, [a, v]);
    const save = buildExamSave(sh, {
      a: draft({ total: '9', comment: 'tốt' }),
      v: draft({ total: '5' }),
    });
    expect(save).toEqual({
      scores: [{ student_id: 'a', total: 9 }],
      notes: [{ student_id: 'a', comment: 'tốt', improvement: '' }],
    });
  });

  it('theo 3 nhóm gửi từng nhóm', () => {
    const sh = sheet(NHOM, [st('a')]);
    expect(
      buildExamSave(sh, { a: draft({ memory: '3', understand: '4', apply: '2' }) })?.scores,
    ).toEqual([{ student_id: 'a', memory: 3, understand: 4, apply: 2 }]);
  });

  it('dòng sai hoặc xoá hết điểm đã chấm thì không lưu được', () => {
    const graded = st('g', {
      score: { total: 8, memory: null, understand: null, apply: null, graded: true },
    });
    expect(buildExamSave(sheet(TONG, [st('a')]), { a: draft({ total: '99' }) })).toBeNull();
    expect(buildExamSave(sheet(TONG, [graded]), { g: draft({ total: '' }) })).toBeNull();
  });

  it('nhận ra thay đổi chưa lưu, tiến độ và tình trạng', () => {
    const g = st('g', {
      score: { total: 8, memory: null, understand: null, apply: null, graded: true },
    });
    const sh = sheet(TONG, [g, st('b'), st('c', { attendance_code: null })]);
    expect(anyDirty(sh, {})).toBe(false);
    expect(anyDirty(sh, { b: draft({ total: '7' }) })).toBe(true);
    expect(gradedProgress(sh)).toEqual({ done: 1, total: 2 });
    expect(statusOf(g, initialDraft(g), TONG)).toBe('Đã chấm');
    expect(statusOf(sh.students[1]!, initialDraft(sh.students[1]!), TONG)).toBe('Chưa chấm');
    expect(statusOf(sh.students[2]!, initialDraft(sh.students[2]!), TONG)).toBe('Chưa điểm danh');
  });

  it('chỉ chấm được khi Đã chốt và đã có cấu hình', () => {
    expect(isExamEditable('DA_CHOT', TONG)).toBe(true);
    expect(isExamEditable('DA_CHOT', null)).toBe(false);
    expect(isExamEditable('DONE', TONG)).toBe(false);
  });
});
