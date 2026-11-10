import { describe, expect, it } from 'vitest';
import {
  buildSave,
  cellOf,
  classProgress,
  EMPTY_DRAFT,
  isReviewDirty,
  isReviewEditable,
  pickInsufficient,
  pickLevel,
  previewAverage,
  progressOfStudent,
  setCell,
  type ReviewCriterion,
  type ReviewSheet,
  type ReviewStudent,
} from './review';

const crit = (id: string, enabled = true): ReviewCriterion => ({
  criterion_id: id,
  name: id,
  group_code: 'THAI_DO',
  enabled,
  hint: null,
  levels: null,
});
const student = (id: string, over: Partial<ReviewStudent> = {}): ReviewStudent => ({
  student_id: id,
  full_name: id,
  attendance_code: 'CO_MAT',
  attendance_name: 'Có mặt',
  scores: {},
  comment: null,
  improvement: null,
  average: null,
  ...over,
});
const sheet = (students: ReviewStudent[], criteria: ReviewCriterion[]): ReviewSheet => ({
  session: {
    session_id: 's',
    status_code: 'DA_CHOT',
    type_code: 'CHINH',
    session_no: 1,
    session_date: '2026-10-24',
    start_time: '18:00',
    end_time: '19:30',
    class_code: 'L',
    subject_name: null,
  },
  criteria,
  students,
});

describe('Chấm nhận xét từng em (GV-07)', () => {
  it('bấm lại đúng mức thì về Chưa đánh giá, không phải điểm 0', () => {
    const first = pickLevel({ state: 'CHUA_DANH_GIA', score: null }, 4);
    expect(first).toEqual({ state: 'DA_DANH_GIA', score: 4 });
    expect(pickLevel(first, 4)).toEqual({ state: 'CHUA_DANH_GIA', score: null });
    expect(pickLevel(first, 5).score).toBe(5);
  });

  it('Chưa đủ căn cứ không có điểm và bấm lại thì bỏ', () => {
    const cell = pickInsufficient({ state: 'DA_DANH_GIA', score: 3 });
    expect(cell).toEqual({ state: 'CHUA_DU_CAN_CU', score: null });
    expect(pickInsufficient(cell).state).toBe('CHUA_DANH_GIA');
  });

  it('tiến độ chỉ tính tiêu chí đang bật; Chưa đủ căn cứ vẫn là đã xử lý', () => {
    const a = student('a');
    const criteria = [crit('c1'), crit('c2'), crit('c3', false)];
    let d = setCell(EMPTY_DRAFT, 'a', 'c1', { state: 'DA_DANH_GIA', score: 4 });
    d = setCell(d, 'a', 'c2', { state: 'CHUA_DU_CAN_CU', score: null });
    expect(progressOfStudent(d, a, criteria)).toEqual({ done: 2, total: 2 });
    expect(
      classProgress(d, [a, student('b', { attendance_code: 'VANG_CO_PHEP' })], criteria),
    ).toEqual({ done: 1, total: 1 });
  });

  it('trung bình xem trước chỉ trên ô Đã đánh giá, không làm tròn', () => {
    const a = student('a');
    const criteria = [crit('c1'), crit('c2'), crit('c3')];
    let d = setCell(EMPTY_DRAFT, 'a', 'c1', { state: 'DA_DANH_GIA', score: 4 });
    d = setCell(d, 'a', 'c2', { state: 'DA_DANH_GIA', score: 5 });
    d = setCell(d, 'a', 'c3', { state: 'CHUA_DU_CAN_CU', score: null });
    expect(previewAverage(d, a, criteria)).toBe(4.5);
    expect(previewAverage(EMPTY_DRAFT, a, criteria)).toBeNull();
  });

  it('lô lưu chỉ gồm phần đã đổi; em vắng không được gửi', () => {
    const a = student('a', { scores: { c1: { state: 'DA_DANH_GIA', score: 3 } } });
    const v = student('v', { attendance_code: 'VANG_KHONG_PHEP' });
    const sh = sheet([a, v], [crit('c1'), crit('c2')]);
    let d = setCell(EMPTY_DRAFT, 'a', 'c1', { state: 'DA_DANH_GIA', score: 3 }); // không đổi
    d = setCell(d, 'a', 'c2', { state: 'DA_DANH_GIA', score: 5 });
    d = setCell(d, 'v', 'c1', { state: 'DA_DANH_GIA', score: 5 });
    d = { ...d, notes: { a: { comment: ' tốt ', improvement: '' } }, enabled: { c2: false } };
    expect(buildSave(sh, d)).toEqual({
      criteria: [{ criterion_id: 'c2', enabled: false }],
      scores: [], // c2 đã tắt nên ô c2 không gửi
      notes: [{ student_id: 'a', comment: ' tốt ', improvement: '' }],
    });
    expect(isReviewDirty(sh, EMPTY_DRAFT)).toBe(false);
    expect(isReviewDirty(sh, d)).toBe(true);
  });

  it('ô chưa sửa lấy theo bản đã lưu', () => {
    const a = student('a', { scores: { c1: { state: 'KHONG_AP_DUNG', score: null } } });
    expect(cellOf(EMPTY_DRAFT, a, 'c1').state).toBe('KHONG_AP_DUNG');
    expect(cellOf(EMPTY_DRAFT, a, 'c9').state).toBe('CHUA_DANH_GIA');
  });

  it('chỉ buổi thường Đã chốt chấm được', () => {
    expect(isReviewEditable('DA_CHOT', 'CHINH')).toBe(true);
    expect(isReviewEditable('DA_CHOT', 'KIEM_TRA')).toBe(false);
    expect(isReviewEditable('DONE', 'CHINH')).toBe(false);
  });
});
