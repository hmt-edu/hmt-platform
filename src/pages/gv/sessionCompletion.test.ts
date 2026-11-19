import { describe, expect, it } from 'vitest';
import type { SessionOverview } from './sessionContent';
import { buildMissing, stampOf, unmarkedNames } from './sessionCompletion';
import type { AttendanceStudent } from './attendanceLogic';

const full: SessionOverview = {
  session_id: 's1',
  status_code: 'DA_CHOT',
  type_code: 'CHINH',
  review_form: 'TIEU_CHI',
  type_name: null,
  exam: null,
  class_code: 'L1',
  subject_name: null,
  session_no: 2,
  session_date: '2026-11-10',
  start_time: '18:00:00',
  end_time: '19:30:00',
  lines: ['a'],
  homework_text: 'BTVN',
  content_version: 1,
  review_scored: 0,
  has_content: true,
  content_lines: 1,
  attendance_total: 4,
  attendance_marked: 4,
  grading_present: 3,
  grading_done: 3,
  grading_missing: [],
  prev_homework_state: 'CAN_CHAM',
  homework_present: 3,
  homework_done: 3,
  homework_missing: [],
  deadline_at: '2026-11-10T20:30:00Z',
  pending_reason: null,
};

describe('Hoàn tất buổi (GV-09): việc còn thiếu', () => {
  it('đủ hết: không còn mục nào', () => {
    expect(buildMissing(full, null)).toEqual([]);
  });

  it('thiếu điểm danh 1 em: liệt kê em đó, có đường Đi tới điểm danh', () => {
    const o = { ...full, attendance_marked: 3 };
    const items = buildMissing(o, ['Em An']);
    expect(items).toHaveLength(1);
    expect(items[0]).toMatchObject({
      key: 'attendance',
      summary: '1 em chưa điểm danh',
      names: ['Em An'],
      more: 0,
      path: '/gv/buoi/s1/diem-danh',
    });
  });

  it('chưa tải tên điểm danh: chỉ hiện số em, không báo «và n em nữa»', () => {
    const items = buildMissing({ ...full, attendance_marked: 2 }, null);
    expect(items[0]).toMatchObject({ summary: '2 em chưa điểm danh', names: [], more: 0 });
  });

  it('chưa chấm và thiếu BTVN: tên lấy từ máy chủ, phần quá 10 tên ghi «và n em nữa»', () => {
    const o = {
      ...full,
      grading_present: 12,
      grading_done: 1,
      grading_missing: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'],
      homework_done: 2,
      homework_missing: ['K'],
    };
    const items = buildMissing(o, null);
    expect(items.map((i) => i.key)).toEqual(['grading', 'homework']);
    expect(items[0]).toMatchObject({
      summary: '11 em có mặt chưa chấm đủ',
      more: 1,
      path: '/gv/buoi/s1/cham-nhan-xet',
    });
    expect(items[1]).toMatchObject({ names: ['K'], more: 0, path: '/gv/buoi/s1/cham-btvn' });
  });

  it('chưa điểm danh thì chấm và BTVN ở trạng thái Chờ: không liệt kê riêng', () => {
    const o = { ...full, attendance_marked: 0, grading_done: 0, homework_done: 0 };
    expect(buildMissing(o, ['A']).map((i) => i.key)).toEqual(['attendance']);
  });

  it('buổi trước không giao BTVN: bước BTVN bỏ qua, không đòi', () => {
    const o = { ...full, prev_homework_state: 'KHONG_GIAO' as const, homework_done: 0 };
    expect(buildMissing(o, null)).toEqual([]);
  });

  it('chưa có nội dung: báo thiếu nội dung', () => {
    const items = buildMissing(
      { ...full, has_content: false, content_lines: 0, homework_text: null },
      null,
    );
    expect(items[0]).toMatchObject({ key: 'content', path: '/gv/buoi/s1/noi-dung' });
  });

  it('các bước đủ nhưng máy chủ còn lý do: hiện lý do, không có nút Đi tới', () => {
    const items = buildMissing({ ...full, pending_reason: 'Còn lý do khác.' }, null);
    expect(items).toEqual([
      {
        key: 'other',
        title: 'Việc khác',
        summary: 'Còn lý do khác.',
        names: [],
        more: 0,
        path: null,
      },
    ]);
  });

  it('unmarkedNames chỉ lấy em chưa có trạng thái', () => {
    const students = [
      { full_name: 'A', teacher_status_code: null },
      { full_name: 'B', teacher_status_code: 'CO_MAT' },
    ] as AttendanceStudent[];
    expect(unmarkedNames(students)).toEqual(['A']);
  });
});

describe('Hoàn tất buổi (GV-09): dấu hạn', () => {
  it('trước hạn: Đúng hạn', () => {
    expect(stampOf(full, new Date('2026-11-10T19:00:00Z'))).toEqual({
      kind: 'ON_TIME',
      text: 'Đúng hạn',
    });
  });
  it('quá hạn 3 giờ: Trễ hạn 3 giờ', () => {
    expect(stampOf(full, new Date('2026-11-10T23:30:00Z'))).toEqual({
      kind: 'LATE',
      text: 'Trễ hạn 3 giờ',
    });
  });
  it('buổi đã Done: không đóng dấu (DB chưa có dấu lúc Done)', () => {
    expect(stampOf({ ...full, status_code: 'DONE' }, new Date('2026-11-10T19:00:00Z'))).toBeNull();
  });
});
