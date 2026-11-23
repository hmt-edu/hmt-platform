import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import {
  EMPTY_APPROVAL_STATE,
  KIND_LABELS,
  approvalFilters,
  approvalPath,
  waitingText,
} from './approvalsLogic';

const NOW = new Date('2026-11-18T12:00:00Z');
const ago = (hours: number) => new Date(NOW.getTime() - hours * 3_600_000);

describe('việc chờ tôi duyệt (CHUNG-15)', () => {
  it('thời gian chờ: dưới 1 giờ, giờ, ngày, ngày kèm giờ', () => {
    expect(waitingText(ago(0.2), NOW)).toBe('dưới 1 giờ');
    expect(waitingText(ago(22), NOW)).toBe('22 giờ');
    expect(waitingText(ago(72), NOW)).toBe('3 ngày');
    expect(waitingText(ago(28), NOW)).toBe('1 ngày 4 giờ');
    expect(waitingText(ago(-3), NOW)).toBe('dưới 1 giờ');
  });
  it('đường mở bản ghi theo loại', () => {
    expect(approvalPath({ kind: 'DON_HANG', open_id: 'a' })).toBe('/crm/don-hang/a');
    expect(approvalPath({ kind: 'PHIEU_THU', open_id: 'a' })).toBe('/crm/phieu-thu/a');
    expect(approvalPath({ kind: 'LOP', open_id: 'a' })).toBe('/crm/lop/a');
    expect(approvalPath({ kind: 'YEU_CAU_BUOI', open_id: 'a' })).toBe('/crm/yeu-cau-buoi');
    expect(approvalPath({ kind: 'PHIEU_NGHIEP_VU', open_id: 'a' })).toBe('/crm/phieu-nghiep-vu/a');
    for (const k of ['HOAN_PHI', 'DUNG_HOC', 'BAO_LUU', 'CHUYEN_LOP'] as const)
      expect(approvalPath({ kind: k, open_id: 'e1' })).toBe('/crm/ghi-danh/e1');
  });
  it('bộ lọc: một loại và một cơ sở; nhiều loại thì không gửi', () => {
    const one: ListState = {
      ...EMPTY_APPROVAL_STATE,
      quick: { kind: ['PHIEU_THU'] },
      conditions: [{ id: 'c', field: 'branch', op: 'eq', value: 'b1' }],
    };
    expect(approvalFilters(one)).toEqual({ kind: 'PHIEU_THU', branch_id: 'b1' });
    expect(
      approvalFilters({ ...EMPTY_APPROVAL_STATE, quick: { kind: ['LOP', 'PHIEU_THU'] } }),
    ).toEqual({});
    expect(approvalFilters({ ...EMPTY_APPROVAL_STATE, quick: { kind: ['KHONG_CO'] } })).toEqual({});
  });
  it('không có loại «chiết khấu vượt trần» (R-V2-11 bỏ)', () => {
    expect(Object.keys(KIND_LABELS)).not.toContain('CHIET_KHAU');
  });
});

import { detailText } from './approvalsLogic';

describe('detailText: không lộ mã kỹ thuật ở «Nội dung»', () => {
  it('phiếu nghiệp vụ hiện tên việc tiếng Việt', () => {
    expect(detailText({ kind: 'PHIEU_NGHIEP_VU', detail: 'CAP_NHAT_HO_SO' })).toBe(
      'Cập nhật hồ sơ',
    );
    expect(detailText({ kind: 'PHIEU_NGHIEP_VU', detail: 'BAO_LUU' })).toBe(
      'Bảo lưu, tiếp tục học',
    );
  });
  it('loại lạ giữ nguyên, loại việc khác không đổi, rỗng giữ rỗng', () => {
    expect(detailText({ kind: 'PHIEU_NGHIEP_VU', detail: 'LOAI_MOI' })).toBe('LOAI_MOI');
    expect(detailText({ kind: 'DON_HANG', detail: 'Đơn 3 dòng' })).toBe('Đơn 3 dòng');
    expect(detailText({ kind: 'LOP', detail: null })).toBeNull();
  });
});
