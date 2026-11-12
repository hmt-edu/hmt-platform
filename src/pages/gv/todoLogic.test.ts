import { describe, expect, it } from 'vitest';
import type { LateItem } from './homework';
import type { MySession } from './todayLogic';
import {
  deadlineLeftText,
  groupLate,
  isOverdue,
  latestSessionPerClass,
  sortByDeadline,
} from './todoLogic';

const mk = (over: Partial<MySession>): MySession => ({
  session_id: 's1',
  class_id: 'c1',
  class_code: 'L1',
  subject_name: 'Toán',
  session_no: 1,
  session_date: '2026-11-10',
  start_time: '18:00:00',
  end_time: '19:30:00',
  type_code: 'CHINH',
  status_code: 'DA_CHOT',
  my_role: 'GIAO_VIEN',
  has_content: true,
  deadline_at: '2026-11-10T20:30:00Z',
  pending_reason: null,
  ...over,
});

describe('Cần làm (GV-12): buổi chưa hoàn tất', () => {
  it('xếp quá hạn lâu nhất lên đầu', () => {
    const rows = [
      mk({ session_id: 'b', deadline_at: '2026-11-12T00:00:00Z' }),
      mk({ session_id: 'a', deadline_at: '2026-11-10T00:00:00Z' }),
    ];
    expect(sortByDeadline(rows).map((r) => r.session_id)).toEqual(['a', 'b']);
  });

  it('hạn: còn bao nhiêu giờ hoặc quá hạn bao nhiêu giờ (làm tròn lên, tối thiểu 1)', () => {
    const now = new Date('2026-11-10T12:00:00Z');
    expect(deadlineLeftText('2026-11-10T15:00:00Z', now)).toBe('Còn 3 giờ');
    expect(deadlineLeftText('2026-11-10T12:10:00Z', now)).toBe('Còn 1 giờ');
    expect(deadlineLeftText('2026-11-10T07:00:00Z', now)).toBe('Quá hạn 5 giờ');
    expect(deadlineLeftText('2026-11-10T11:50:00Z', now)).toBe('Quá hạn 1 giờ');
  });

  it('hạn đúng bằng bây giờ coi là quá hạn', () => {
    const now = new Date('2026-11-10T12:00:00Z');
    expect(isOverdue('2026-11-10T12:00:00Z', now)).toBe(true);
    expect(isOverdue('2026-11-10T12:00:01Z', now)).toBe(false);
  });
});

describe('Cần làm (GV-12): bài Nộp sau', () => {
  it('mỗi lớp lấy buổi mới nhất không sau hôm nay', () => {
    const rows = [
      mk({ session_id: 'a1', class_id: 'A', class_code: 'A', session_date: '2026-11-03' }),
      mk({ session_id: 'a2', class_id: 'A', class_code: 'A', session_date: '2026-11-10' }),
      mk({ session_id: 'a3', class_id: 'A', class_code: 'A', session_date: '2026-11-17' }),
      mk({ session_id: 'b1', class_id: 'B', class_code: 'B', session_date: '2026-11-09' }),
    ];
    expect(latestSessionPerClass(rows, '2026-11-10').map((s) => s.session_id)).toEqual([
      'a2',
      'b1',
    ]);
  });

  const late = (assigned: string, no: number, date: string, name: string): LateItem => ({
    assigned_session_id: assigned,
    session_no: no,
    session_date: date,
    homework_text: 'BT',
    student_id: name,
    full_name: name,
    version: 0,
    inferred: true,
  });

  it('không có bài Nộp sau: không có nhóm', () => {
    expect(groupLate(mk({}), [])).toBeNull();
  });

  it('gom theo buổi giao bài, giữ tên em, mở màn GV-08 của buổi mới nhất', () => {
    const group = groupLate(mk({ session_id: 'latest' }), [
      late('x2', 2, '2026-11-05', 'Bình'),
      late('x1', 1, '2026-11-01', 'An'),
      late('x2', 2, '2026-11-05', 'Chi'),
    ]);
    expect(group).toMatchObject({ openSessionId: 'latest', title: 'Toán · L1', total: 3 });
    expect(group?.items).toEqual([
      { assignedSessionId: 'x1', sessionNo: 1, date: '2026-11-01', names: ['An'] },
      { assignedSessionId: 'x2', sessionNo: 2, date: '2026-11-05', names: ['Bình', 'Chi'] },
    ]);
  });
});
