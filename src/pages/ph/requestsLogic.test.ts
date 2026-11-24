import { describe, expect, it } from 'vitest';
import { buildSteps, sentSubtitle, statusText } from './requestsLogic';

describe('PH-04 chữ và bước theo dõi', () => {
  it('trạng thái cho phụ huynh dùng chữ tiếng Việt', () => {
    expect(statusText('CHO_XAC_NHAN')).toBe('Chờ xác nhận');
    expect(statusText('DANG_XU_LY')).toBe('Đang xử lý');
    expect(statusText('DA_XONG')).toBe('Đã xong');
  });
  it('dòng phụ: ngày gửi và loại', () => {
    expect(sentSubtitle({ created_at: '2026-11-19T01:40:00Z', ticket_type: 'DN' })).toBe(
      'Gửi 19/11 · Đề nghị',
    );
    expect(sentSubtitle({ created_at: '2026-11-12T01:40:00Z', ticket_type: 'KN' })).toContain(
      'Khiếu nại',
    );
  });
  it('bước 2: bước 1 xong, bước 2 đang làm, còn lại chưa', () => {
    expect(buildSteps(2).map((s) => s.state)).toEqual(['done', 'current', 'todo', 'todo']);
  });
  it('bước 4: tất cả xong', () => {
    expect(buildSteps(4).map((s) => s.state)).toEqual(['done', 'done', 'done', 'done']);
  });
});
