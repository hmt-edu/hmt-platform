// BH-08, GD-03: hộp chọn lớp nhắc lệch hình thức học (lớp Offline/Online lệch ghi danh), CHỈ cảnh báo, không chặn (anh Trường chốt 20/11).
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { ClassPicker } from './ClassPicker';
import type { MatchingClass } from './enrollTypes';

const base: MatchingClass = {
  id: 'c1',
  code: 'L-OFF',
  subject_name: 'Đại số',
  class_type_name: 'Cơ bản',
  level_name: null,
  grade_code: 'K09',
  group_id: null,
  group_name: null,
  schedule_text: null,
  teacher_name: null,
  seats_left: 5,
  has_sessions: false,
  class_start_date: '2027-01-05',
  weekdays: [2],
  upcoming: [],
  clash_sessions: 0,
};
const classes: MatchingClass[] = [
  { ...base, id: 'c1', code: 'L-OFF', delivery_mode_code: 'OFF' },
  { ...base, id: 'c2', code: 'L-OMO', delivery_mode_code: 'OMO' },
];

function show(enrollMode: string | null) {
  render(
    <ClassPicker
      classes={classes}
      value={{ classId: null, date: '' }}
      onChange={() => undefined}
      name="t"
      enrollMode={enrollMode}
    />,
  );
}

describe('ClassPicker: cảnh báo lệch hình thức học', () => {
  it('dòng đơn Online: lớp Offline có cảnh báo, lớp OMO không, cả hai vẫn chọn được', () => {
    show('ONL');
    expect(screen.getAllByText(/lệch hình thức học/)).toHaveLength(1);
    expect(screen.getByText(/Lớp học Offline, ghi danh Online/)).toBeTruthy();
    for (const radio of screen.getAllByRole('radio'))
      expect((radio as HTMLInputElement).disabled).toBe(false);
  });
  it('dòng đơn Offline: lớp Offline và lớp OMO đều không cảnh báo', () => {
    show('OFF');
    expect(screen.queryByText(/lệch hình thức học/)).toBeNull();
  });
  it('thiếu hình thức của dòng đơn: không cảnh báo', () => {
    show(null);
    expect(screen.queryByText(/lệch hình thức học/)).toBeNull();
  });
});
