import { describe, expect, it } from 'vitest';
import { FORBIDDEN_CODE, HmtError } from '../lib/db';
import { queryErrorSpec } from './queryError';

describe('màn lỗi tải dữ liệu', () => {
  it('không quyền thì không có nút Thử lại', () => {
    const s = queryErrorSpec(new HmtError(FORBIDDEN_CODE, 'x'), 'ticket');
    expect(s).toEqual({
      kind: 'forbidden',
      title: 'Bạn không có quyền xem ticket',
      canRetry: false,
    });
  });
  it('không tìm thấy thì không có nút Thử lại', () => {
    const s = queryErrorSpec(new HmtError('HMT_KHONG_TIM_THAY', 'x'), 'phiếu');
    expect(s).toEqual({ kind: 'not-found', title: 'Không tìm thấy phiếu', canRetry: false });
  });
  it('lỗi khác (mạng) thì có nút Thử lại', () => {
    const s = queryErrorSpec(new Error('Failed to fetch'), 'cấu hình SLA');
    expect(s).toEqual({ kind: 'error', title: 'Chưa tải được cấu hình SLA', canRetry: true });
  });
});
