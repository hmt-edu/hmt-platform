import { describe, expect, it } from 'vitest';
import {
  createPayload,
  dueIso,
  giveableSessions,
  lmsState,
  nextSessionOf,
  validateLmsForm,
  vnParts,
  type LmsFormValues,
  type LmsSessionLite,
} from './lms';

const NOW = new Date('2026-11-20T10:00:00Z');
const base: LmsFormValues = {
  title: 'Bài 1',
  description: 'Làm bài 1',
  date: '2026-11-25',
  time: '18:00',
  audience: 'CA_LOP',
  studentIds: [],
  hasDefaultDue: true,
};

describe('lmsState (trạng thái bài giao)', () => {
  const row = {
    status: 'DANG_GIAO' as const,
    due_at: '2026-11-25T11:00:00Z',
    targets: 3,
    graded: 0,
  };
  it('đang mở, quá hạn, đã chấm hết, đã gỡ', () => {
    expect(lmsState(row, NOW)).toBe('DANG_MO');
    expect(lmsState({ ...row, due_at: '2026-11-19T11:00:00Z' }, NOW)).toBe('QUA_HAN');
    expect(lmsState({ ...row, graded: 3 }, NOW)).toBe('CHAM_HET');
    expect(lmsState({ ...row, status: 'DA_GO' }, NOW)).toBe('DA_GO');
  });
  it('hạn đúng bằng bây giờ coi là quá hạn; không em nhận bài thì không «chấm hết»', () => {
    expect(lmsState({ ...row, due_at: NOW.toISOString() }, NOW)).toBe('QUA_HAN');
    expect(lmsState({ ...row, targets: 0 }, NOW)).toBe('DANG_MO');
  });
});

describe('hạn nộp theo giờ Việt Nam', () => {
  it('ghép ngày giờ thành thời điểm +07:00; thiếu một nửa thì null', () => {
    expect(dueIso('2026-11-25', '18:00')).toBe('2026-11-25T18:00:00+07:00');
    expect(dueIso('', '18:00')).toBeNull();
    expect(dueIso('2026-11-25', '')).toBeNull();
  });
  it('tách ngày giờ ngược lại đúng múi giờ', () => {
    expect(vnParts('2026-11-25T11:00:00Z')).toEqual({ date: '2026-11-25', time: '18:00' });
    expect(vnParts('2026-11-25T20:30:00Z')).toEqual({ date: '2026-11-26', time: '03:30' });
  });
});

describe('buổi giao và buổi sau', () => {
  const s = (id: string, no: number, date: string, status = 'DA_CHOT'): LmsSessionLite => ({
    id,
    session_no: no,
    session_date: date,
    start_time: '18:00:00',
    status_code: status,
  });
  const sessions = [
    s('a', 1, '2026-11-02'),
    s('b', 2, '2026-11-09'),
    s('c', 3, '2026-11-16', 'HUY_KHONG_PHI'),
    s('d', 4, '2026-11-23'),
  ];
  it('buổi huỷ không giao được; buổi sau bỏ qua buổi huỷ', () => {
    expect(giveableSessions(sessions).map((x) => x.id)).toEqual(['a', 'b', 'd']);
    expect(nextSessionOf(sessions, 'b')?.id).toBe('d');
  });
  it('buổi cuối của lớp không có buổi sau (Q10)', () => {
    expect(nextSessionOf(sessions, 'd')).toBeNull();
    expect(nextSessionOf(sessions, 'không-có')).toBeNull();
  });
});

describe('validateLmsForm', () => {
  it('form đủ thì không có lỗi', () => {
    expect(validateLmsForm(base, NOW)).toEqual({});
  });
  it('thiếu tiêu đề, mô tả', () => {
    const e = validateLmsForm({ ...base, title: '  ', description: '' }, NOW);
    expect(e.title).toBe('Cần nhập tiêu đề bài.');
    expect(e.description).toBe('Cần nhập mô tả, đề bài.');
  });
  it('hạn trong quá khứ, hạn thiếu giờ', () => {
    expect(validateLmsForm({ ...base, date: '2026-11-19' }, NOW).due).toBe(
      'Hạn nộp không được trước thời điểm giao.',
    );
    expect(validateLmsForm({ ...base, time: '' }, NOW).due).toBe(
      'Chọn đủ ngày và giờ của hạn nộp.',
    );
  });
  it('hạn bỏ trống: được khi lớp có buổi sau, bắt buộc khi không có (Q10)', () => {
    expect(validateLmsForm({ ...base, date: '', time: '' }, NOW).due).toBeUndefined();
    expect(validateLmsForm({ ...base, date: '', time: '', hasDefaultDue: false }, NOW).due).toBe(
      'Lớp chưa có buổi sau: hãy chọn hạn nộp.',
    );
  });
  it('chọn từng em mà chưa chọn em nào (Q11)', () => {
    expect(validateLmsForm({ ...base, audience: 'CHON_EM' }, NOW).students).toBe(
      'Chọn ít nhất một em đang học để giao bài.',
    );
    expect(
      validateLmsForm({ ...base, audience: 'CHON_EM', studentIds: ['x'] }, NOW).students,
    ).toBeUndefined();
  });
});

describe('createPayload', () => {
  it('cả lớp, hạn đủ: có due_at, không có student_ids; cắt khoảng trắng', () => {
    const p = createPayload('s1', { ...base, title: ' Bài 1 ' }, true, false);
    expect(p).toEqual({
      session_id: 's1',
      title: 'Bài 1',
      description: 'Làm bài 1',
      audience: 'CA_LOP',
      allow_resubmit: true,
      allow_late: false,
      due_at: '2026-11-25T18:00:00+07:00',
    });
  });
  it('hạn bỏ trống thì không gửi due_at; chọn từng em thì gửi danh sách em', () => {
    const p = createPayload(
      's1',
      { ...base, date: '', time: '', audience: 'CHON_EM', studentIds: ['a', 'b'] },
      true,
      true,
    );
    expect('due_at' in p).toBe(false);
    expect(p.student_ids).toEqual(['a', 'b']);
    expect(p.allow_late).toBe(true);
  });
});
