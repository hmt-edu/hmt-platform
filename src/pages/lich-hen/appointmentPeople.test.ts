import { describe, expect, it } from 'vitest';
import { peopleWithAppointments } from './appointmentPeople';

describe('peopleWithAppointments (Đ34, Đ38)', () => {
  it('chỉ người có lịch hẹn, mỗi người một lần, xếp theo tên tiếng Việt', () => {
    expect(
      peopleWithAppointments([
        { owner_name: 'Trần Thu Hà' },
        { owner_name: 'Ân Nguyễn' },
        { owner_name: 'Trần Thu Hà' },
        { owner_name: 'Bùi Quang' },
      ]),
    ).toEqual(['Ân Nguyễn', 'Bùi Quang', 'Trần Thu Hà']);
  });
  it('bỏ lịch hẹn không có tên người phụ trách; không có lịch thì không có cột', () => {
    expect(peopleWithAppointments([{ owner_name: null }])).toEqual([]);
    expect(peopleWithAppointments([])).toEqual([]);
  });
});
