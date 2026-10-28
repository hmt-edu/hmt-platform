import { describe, expect, it } from 'vitest';
import { approverWarning, expectedApproverText, lastRejection, orderSteps } from './orderRecord';
import type { OrderEvent } from './orderTypes';

const ev = (seq: number, code: OrderEvent['event_code']): OrderEvent => ({
  seq,
  event_code: code,
  from_status: null,
  to_status: null,
  reason_code: null,
  note: null,
  on_behalf: false,
  created_at: '2026-10-11T00:00:00Z',
  actor_name: 'Lê Văn Phong',
});

describe('bản ghi đơn (BH-05)', () => {
  it('thanh tình trạng: luồng thường và nhánh Huỷ', () => {
    expect(orderSteps({ status_code: 'NHAP' })).toEqual(['NHAP', 'DA_TRINH', 'DA_DUYET']);
    expect(orderSteps({ status_code: 'HUY' })).toEqual(['NHAP', 'HUY']);
  });

  it('R-TIEN-06: Nháp mà sự kiện gần nhất là từ chối thì "bị từ chối"', () => {
    const events = [ev(1, 'TAO'), ev(2, 'TRINH'), ev(3, 'TU_CHOI')];
    expect(lastRejection({ status_code: 'NHAP', events })?.seq).toBe(3);
  });

  it('đã trình lại sau khi bị từ chối thì không còn nhãn bị từ chối', () => {
    const events = [ev(1, 'TAO'), ev(2, 'TRINH'), ev(3, 'TU_CHOI'), ev(4, 'TRINH')];
    expect(lastRejection({ status_code: 'DA_TRINH', events })).toBeNull();
  });

  it('Nháp mới tạo chưa từng bị từ chối', () => {
    expect(lastRejection({ status_code: 'NHAP', events: [ev(1, 'TAO')] })).toBeNull();
  });

  it('người duyệt dự kiến theo đường duyệt (R-HT-06)', () => {
    const base = {
      status_code: 'NHAP' as const,
      expected_approver_name: 'Lê Văn Phong',
      created_by_name: 'Trần Thu Hà',
    };
    expect(expectedApproverText({ ...base, expected_route: 'QUAN_LY' })).toBe(
      'Người duyệt: Lê Văn Phong · quản lý trực tiếp của Trần Thu Hà',
    );
    expect(expectedApproverText({ ...base, expected_route: 'TU_DUYET' })).toContain('tự duyệt');
    expect(expectedApproverText({ ...base, expected_route: 'THIEU' })).toContain(
      'chưa có quản lý trực tiếp',
    );
    expect(
      expectedApproverText({ ...base, status_code: 'DA_TRINH', expected_route: null }),
    ).toBeNull();
  });

  it('cảnh báo: thiếu quản lý, hoặc người duyệt chưa có quyền Duyệt (Đ205)', () => {
    const base = { status_code: 'NHAP' as const, expected_approver_name: 'Lê Văn Phong' };
    expect(
      approverWarning({ ...base, expected_route: 'THIEU', expected_approver_can_approve: null }),
    ).toContain('Chưa có quản lý trực tiếp');
    expect(
      approverWarning({ ...base, expected_route: 'QUAN_LY', expected_approver_can_approve: false }),
    ).toContain('chưa có quyền Duyệt đơn hàng');
    expect(
      approverWarning({ ...base, expected_route: 'QUAN_LY', expected_approver_can_approve: true }),
    ).toBeNull();
    expect(
      approverWarning({
        status_code: 'DA_TRINH',
        expected_route: null,
        expected_approver_can_approve: null,
        expected_approver_name: null,
      }),
    ).toBeNull();
  });
});
