import { describe, expect, it } from 'vitest';
import {
  EMPTY_PARENT_MESSAGE_STATE,
  buildParentMessageFilters,
  keepOneStatus,
  clipMessage,
  messageCard,
  sessionLabel,
} from './parentMessageTypes';

describe('CS-16 bộ lọc', () => {
  it('mặc định là Chờ gửi', () => {
    expect(buildParentMessageFilters(EMPTY_PARENT_MESSAGE_STATE)).toEqual({ status: 'CHO_GUI' });
  });
  it('chip Đã gửi, tìm kiếm và cơ sở', () => {
    const f = buildParentMessageFilters({
      ...EMPTY_PARENT_MESSAGE_STATE,
      search: ' Khôi ',
      quick: { status: ['DA_GUI'] },
      conditions: [{ id: '1', field: 'branch', op: 'eq', value: 'b1' }],
    });
    expect(f).toEqual({ status: 'DA_GUI', q: 'Khôi', branch_id: 'b1' });
  });
});
describe('CS-16 nhóm Trạng thái chỉ một ô (lỗi ra soát 02:51)', () => {
  const base = EMPTY_PARENT_MESSAGE_STATE;
  it('đang chọn Chờ gửi, bấm thêm Đã gửi thì còn đúng Đã gửi và máy chủ lọc Đã gửi', () => {
    const prev = { ...base, quick: { status: ['CHO_GUI'] } };
    const next = { ...base, quick: { status: ['CHO_GUI', 'DA_GUI'] } };
    const kept = keepOneStatus(prev, next);
    expect(kept.quick.status).toEqual(['DA_GUI']);
    expect(buildParentMessageFilters(kept).status).toBe('DA_GUI');
  });
  it('đang chọn Đã gửi, bấm thêm Chờ gửi thì còn Chờ gửi', () => {
    const prev = { ...base, quick: { status: ['DA_GUI'] } };
    const next = { ...base, quick: { status: ['DA_GUI', 'CHO_GUI'] } };
    expect(keepOneStatus(prev, next).quick.status).toEqual(['CHO_GUI']);
  });
  it('một ô hoặc bỏ chọn thì giữ nguyên', () => {
    const one = { ...base, quick: { status: ['DA_GUI'] } };
    expect(keepOneStatus(base, one)).toBe(one);
    const none = { ...base, quick: { status: [] } };
    expect(keepOneStatus(one, none)).toBe(none);
  });
});
describe('CS-16 hiển thị', () => {
  it('nhãn buổi', () => {
    expect(sessionLabel(9, '2026-11-10')).toBe('Buổi 9 · 10/11');
    expect(sessionLabel(null, '2026-11-10')).toBe('10/11');
  });
  it('cắt lời nhắn bằng «…»', () => {
    expect(clipMessage('Chào chị,   em học tốt', 100)).toBe('Chào chị, em học tốt');
    expect(clipMessage('abcdefghij', 5)).toBe('abcde…');
  });
  it('phiếu ảnh chỉ có lời nhắn, không điểm', () => {
    const c = messageCard({
      attendance_id: 'a',
      student_name: 'Em A',
      class_code: 'LC-1',
      session_no: 2,
      session_date: '2026-11-10',
      parent_name: 'Chị B',
      message: 'Chào chị.',
      sent: false,
      sent_at: null,
    });
    expect(c.message).toBe('Chào chị.');
    expect(c.sections).toEqual([]);
    expect(c.title).toBe('LC-1 · Buổi 2 · 10/11');
  });
});
