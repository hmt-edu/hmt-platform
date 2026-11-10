import { describe, expect, it } from 'vitest';
import type { SessionOverview } from './sessionContent';
import { buildSteps, deadlineText, hoursLeft, nextStep, progressOf } from './sessionSteps';

const base: SessionOverview = {
  session_id: 's1',
  status_code: 'DA_CHOT',
  type_code: 'CHINH',
  type_name: 'Buổi học thường',
  exam: null,
  class_code: 'L1',
  subject_name: 'Toán',
  session_no: 5,
  session_date: '2026-10-24',
  start_time: '18:00:00',
  end_time: '19:30:00',
  lines: [],
  homework_text: null,
  content_version: 0,
  review_scored: 0,
  has_content: false,
  content_lines: 0,
  attendance_total: 4,
  attendance_marked: 4,
  grading_present: 3,
  grading_done: 1,
  grading_missing: ['A', 'B'],
  prev_homework_state: 'CAN_CHAM',
  homework_present: 3,
  homework_done: 1,
  homework_missing: ['A', 'B'],
  deadline_at: '2026-10-24T20:30:00Z',
  pending_reason: null,
};

describe('Các bước của buổi dạy (GV-04)', () => {
  it('buổi chưa chốt: điểm danh và chấm chờ, nội dung nhập được trước', () => {
    const steps = buildSteps({
      ...base,
      status_code: 'NHAP',
      attendance_total: 0,
      attendance_marked: 0,
    });
    expect(steps.map((s) => s.state)).toEqual(['WAIT', 'TODO', 'WAIT', 'WAIT']);
    expect(steps[1]?.detail).toBe('Nhập được trước');
  });

  it('đang chấm dở: điểm danh xong, nội dung xong, chấm đang làm, BTVN buổi trước sắp có', () => {
    const steps = buildSteps({
      ...base,
      has_content: true,
      content_lines: 3,
      homework_text: 'Bài 6',
    });
    expect(steps.map((s) => s.state)).toEqual(['DONE', 'DONE', 'DOING', 'DOING']);
    expect(steps[2]?.detail).toBe('1/3 em có mặt đã chấm đủ');
    expect(steps[3]?.detail).toBe('1/3 em có mặt đã có trạng thái');
    expect(progressOf(steps)).toEqual({ done: 2, total: 4 });
  });

  it('buổi đầu của lớp hoặc buổi trước không giao BTVN: bước 4 bỏ qua và không tính vào tiến độ', () => {
    for (const state of ['DAU_LOP', 'KHONG_GIAO'] as const) {
      const steps = buildSteps({ ...base, has_content: true, prev_homework_state: state });
      expect(steps[3]?.state).toBe('SKIP');
      expect(progressOf(steps).total).toBe(3);
    }
  });

  it('chấm BTVN buổi trước xong khi mọi em có mặt đã có trạng thái; chưa điểm danh thì chờ', () => {
    expect(buildSteps({ ...base, homework_done: 3 })[3]?.state).toBe('DONE');
    expect(buildSteps({ ...base, homework_done: 0 })[3]?.state).toBe('TODO');
    expect(buildSteps({ ...base, attendance_marked: 0 })[3]?.state).toBe('WAIT');
    expect(buildSteps({ ...base, homework_present: 0, homework_done: 0 })[3]?.state).toBe('DONE');
  });

  it('buổi Kiểm tra: nội dung xong khi chỉ có BTVN, tên bước chấm là chấm điểm', () => {
    const steps = buildSteps({ ...base, type_code: 'KIEM_TRA', homework_text: 'Làm lại bài 3' });
    expect(steps[1]?.state).toBe('DONE');
    expect(steps[2]?.title).toBe('Chấm điểm kiểm tra');
  });

  it('chưa điểm danh em nào thì chấm chờ điểm danh', () => {
    const steps = buildSteps({ ...base, attendance_marked: 0 });
    expect(steps[0]?.state).toBe('TODO');
    expect(steps[2]?.state).toBe('WAIT');
  });

  it('việc kế tiếp là bước đầu tiên chưa xong, bỏ qua bước Chờ và Bỏ qua', () => {
    const steps = buildSteps({ ...base, prev_homework_state: 'DAU_LOP' });
    expect(nextStep(steps)?.key).toBe('content');
  });

  it('hạn hoàn tất: còn bao nhiêu giờ, quá hạn bao nhiêu giờ', () => {
    const now = new Date('2026-10-24T15:30:00Z');
    expect(hoursLeft('2026-10-24T20:30:00Z', now)).toBe(5);
    expect(deadlineText('2026-10-24T20:30:00Z', now)).toBe('còn 5 giờ');
    expect(deadlineText('2026-10-24T10:30:00Z', now)).toBe('quá hạn 5 giờ');
  });
});
