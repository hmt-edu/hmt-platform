import { describe, expect, it } from 'vitest';
import {
  gradeError,
  gradeText,
  nextUngraded,
  resubmitText,
  scoreToSend,
  scoreWillBeDropped,
  type GradingListRow,
} from './lmsGrading';

const row = (id: string, graded: boolean): GradingListRow => ({
  student_id: id,
  student_code: id,
  full_name: id,
  submit_state: 'DA_NOP',
  is_late: false,
  attempt_count: 1,
  submitted_at: null,
  grade_status_code: graded ? 'DA_CHAM' : null,
  score: graded ? 4 : null,
  graded,
});

describe('nhãn chấm', () => {
  it('«Đã chấm · 4», «Không làm», «Chưa chấm»', () => {
    expect(gradeText({ grade_status_code: 'DA_CHAM', score: 4, graded: true })).toBe('Đã chấm · 4');
    expect(gradeText({ grade_status_code: 'KHONG_LAM', score: null, graded: true })).toBe(
      'Không làm',
    );
    expect(gradeText({ grade_status_code: null, score: null, graded: false })).toBe('Chưa chấm');
  });
  it('nộp lại: từ lần nộp thứ hai', () => {
    expect(resubmitText(1)).toBeNull();
    expect(resubmitText(0)).toBeNull();
    expect(resubmitText(2)).toBe('Nộp lại 1 lần');
  });
});

describe('nextUngraded (Q8: chỉ em chưa chấm)', () => {
  const rows = [row('a', false), row('b', true), row('c', false), row('d', true)];
  it('lấy em chưa chấm kế tiếp, bỏ qua em đã chấm', () => {
    expect(nextUngraded(rows, 'a')?.student_id).toBe('c');
  });
  it('hết phía sau thì quay lại đầu danh sách', () => {
    expect(nextUngraded(rows, 'c')?.student_id).toBe('a');
  });
  it('không còn em nào chưa chấm thì null', () => {
    expect(nextUngraded([row('a', true), row('b', true)], 'a')).toBeNull();
    expect(nextUngraded([row('a', false)], 'a')).toBeNull();
  });
});

describe('điểm theo trạng thái (R-GV-11, Q5)', () => {
  it('Đã chấm và Làm chưa xong cần điểm; trạng thái khác thì bỏ điểm', () => {
    expect(scoreToSend('DA_CHAM', 5)).toBe(5);
    expect(scoreToSend('LAM_CHUA_XONG', 3)).toBe(3);
    expect(scoreToSend('KHONG_LAM', 4)).toBeNull();
    expect(scoreToSend('NOP_SAU', 4)).toBeNull();
    expect(scoreToSend('KHONG_AP_DUNG', 4)).toBeNull();
  });
  it('lỗi nhập: chưa chọn trạng thái, thiếu điểm', () => {
    expect(gradeError(null, null)).toBe('Chọn một trạng thái BTVN.');
    expect(gradeError('DA_CHAM', null)).toBe('Chọn điểm từ 1 đến 5 cho trạng thái này.');
    expect(gradeError('DA_CHAM', 3)).toBeNull();
    expect(gradeError('KHONG_LAM', null)).toBeNull();
  });
  it('điểm đã chọn mà trạng thái không có điểm thì báo sẽ bị bỏ', () => {
    expect(scoreWillBeDropped('KHONG_LAM', 4)).toBe(true);
    expect(scoreWillBeDropped('DA_CHAM', 4)).toBe(false);
    expect(scoreWillBeDropped('KHONG_LAM', null)).toBe(false);
    expect(scoreWillBeDropped(null, 4)).toBe(false);
  });
});
