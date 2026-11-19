import { describe, expect, it } from 'vitest';
import {
  approverLine,
  approverWarning,
  submitBlockOf,
  canCancelOrder,
  canSubmitOrder,
  editedFromQuotationNote,
  editedSinceRejection,
  errorLineNumbers,
  expectedApproverText,
  lastRejection,
  orderSteps,
  waitingApproverName,
} from './orderRecord';
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
      'chưa có quản lý trực tiếp và cơ sở chưa có Trưởng cơ sở',
    );
    expect(expectedApproverText({ ...base, expected_route: 'THIEU' }, true)).toBe(
      'Người duyệt: chưa có · bạn chưa có quản lý trực tiếp và cơ sở chưa có Trưởng cơ sở',
    );
    // R-V2-12 (Q-114): chưa có quản lý trực tiếp thì Trưởng cơ sở duyệt; người xem là người lập thì nói "bạn".
    expect(expectedApproverText({ ...base, expected_route: 'TRUONG_CS' })).toBe(
      'Người duyệt: Trưởng cơ sở · người lập chưa có quản lý trực tiếp',
    );
    expect(expectedApproverText({ ...base, expected_route: 'TRUONG_CS' }, true)).toBe(
      'Người duyệt: Trưởng cơ sở · bạn chưa có quản lý trực tiếp',
    );
    expect(
      expectedApproverText({ ...base, status_code: 'DA_TRINH', expected_route: null }),
    ).toBeNull();
  });

  it('Q-63: expected_block chọn đúng câu; bị khoá khác với thiếu quyền; máy chủ cũ (không có cờ) vẫn suy từ trường cũ', () => {
    const base = {
      status_code: 'NHAP' as const,
      expected_route: 'QUAN_LY' as const,
      expected_approver_name: 'Lê Văn Phong',
      expected_approver_can_approve: false,
    };
    expect(approverWarning({ ...base, expected_block: 'NGUOI_DUYET_BI_KHOA' })).toBe(
      'Quản lý trực tiếp của người lập đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đặt lại Quản lý trực tiếp.',
    );
    expect(approverWarning({ ...base, expected_block: 'NGUOI_DUYET_THIEU_QUYEN' })).toContain(
      'chưa có quyền Duyệt đơn hàng',
    );
    expect(approverWarning({ ...base, expected_block: 'KHONG_CO_QUAN_LY' })).toContain(
      'chưa có Trưởng cơ sở nào đang hoạt động',
    );
    expect(
      approverWarning({ ...base, expected_block: null, expected_approver_can_approve: true }),
    ).toBeNull();
    // Không có expected_block: suy từ trường cũ như trước.
    expect(approverWarning(base)).toContain('chưa có quyền Duyệt đơn hàng');
  });

  it('cảnh báo: thiếu quản lý, hoặc người duyệt chưa có quyền Duyệt (Đ205)', () => {
    const base = { status_code: 'NHAP' as const, expected_approver_name: 'Lê Văn Phong' };
    expect(
      approverWarning({ ...base, expected_route: 'THIEU', expected_approver_can_approve: null }),
    ).toContain('chưa có Trưởng cơ sở nào đang hoạt động');
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

  it('nút Trình: chỉ đơn Nháp, có quyền Sửa, Bán hàng bật, không phải điện thoại', () => {
    const ok = { edit: true, featureOn: true, phone: false };
    expect(canSubmitOrder({ status_code: 'NHAP' }, ok)).toBe(true);
    expect(canSubmitOrder({ status_code: 'DA_TRINH' }, ok)).toBe(false);
    expect(canSubmitOrder({ status_code: 'NHAP' }, { ...ok, edit: false })).toBe(false);
    expect(canSubmitOrder({ status_code: 'NHAP' }, { ...ok, featureOn: false })).toBe(false);
    expect(canSubmitOrder({ status_code: 'NHAP' }, { ...ok, phone: true })).toBe(false);
  });

  it('R-TIEN-38: Nháp chỉ người lập huỷ; Đã trình, Đã duyệt do người duyệt đã chốt hoặc người duyệt thay', () => {
    const me = {
      userId: 'u1',
      canCancel: true,
      featureOn: true,
      approvesInstead: false,
      phone: false,
    };
    const rec = (status_code: 'NHAP' | 'DA_TRINH' | 'DA_DUYET' | 'HUY') => ({
      status_code,
      created_by: 'u1',
      assigned_approver_id: 'u2',
    });
    expect(canCancelOrder(rec('NHAP'), me)).toBe(true);
    expect(canCancelOrder(rec('NHAP'), { ...me, userId: 'u3' })).toBe(false);
    expect(canCancelOrder(rec('DA_TRINH'), me)).toBe(false);
    expect(canCancelOrder(rec('DA_TRINH'), { ...me, userId: 'u2' })).toBe(true);
    expect(canCancelOrder(rec('DA_DUYET'), { ...me, approvesInstead: true })).toBe(true);
    expect(canCancelOrder(rec('HUY'), { ...me, approvesInstead: true })).toBe(false);
    expect(canCancelOrder(rec('NHAP'), { ...me, canCancel: false })).toBe(false);
    expect(canCancelOrder(rec('NHAP'), { ...me, featureOn: false })).toBe(false);
    expect(canCancelOrder(rec('NHAP'), { ...me, phone: true })).toBe(false);
  });

  it('chỉ đúng dòng trong câu lỗi của máy chủ', () => {
    expect(
      errorLineNumbers('Dòng 2: thiếu năm sinh của em; Dòng 5: thiếu họ tên của em. Bổ sung.'),
    ).toEqual([2, 5]);
    expect(errorLineNumbers('Chọn điều khoản thanh toán trước khi trình đơn.')).toEqual([]);
  });

  it('sự kiện SUA không làm mất trạng thái bị từ chối; sửa sau từ chối thì "đã sửa"', () => {
    const base = { status_code: 'NHAP' as const };
    const rejected = { ...base, events: [ev(1, 'TAO'), ev(2, 'TRINH'), ev(3, 'TU_CHOI')] };
    expect(lastRejection(rejected)?.seq).toBe(3);
    expect(editedSinceRejection(rejected)).toBe(false);
    const edited = { ...base, events: [...rejected.events, ev(4, 'SUA')] };
    expect(lastRejection(edited)?.seq).toBe(3);
    expect(editedSinceRejection(edited)).toBe(true);
    // Sửa TRƯỚC lần từ chối cuối không tính; chưa từng bị từ chối thì không có.
    const before = {
      ...base,
      events: [ev(1, 'TAO'), ev(2, 'SUA'), ev(3, 'TRINH'), ev(4, 'TU_CHOI')],
    };
    expect(editedSinceRejection(before)).toBe(false);
    expect(editedSinceRejection({ ...base, events: [ev(1, 'TAO'), ev(2, 'SUA')] })).toBe(false);
  });

  it('dòng nhật ký "Đơn đã sửa so với báo giá" gần nhất (Q-31)', () => {
    const e = (seq: number, note: string | null): OrderEvent => ({ ...ev(seq, 'SUA'), note });
    expect(editedFromQuotationNote({ events: [ev(1, 'TAO')] })).toBeNull();
    expect(editedFromQuotationNote({ events: [e(2, 'Sửa đơn: dòng 1')] })).toBeNull();
    expect(
      editedFromQuotationNote({
        events: [
          e(2, 'Đơn đã sửa so với báo giá BG-1: dòng 1 số giờ 6 → 8'),
          e(3, 'Đơn đã sửa so với báo giá BG-1: dòng 1 số giờ 8 → 9'),
        ],
      }),
    ).toBe('Đơn đã sửa so với báo giá BG-1: dòng 1 số giờ 8 → 9');
  });
});

describe('Q-77: một dòng cạnh nút Trình, ba ca bị chặn', () => {
  const base = {
    status_code: 'NHAP' as const,
    expected_route: 'QUAN_LY' as const,
    expected_approver_name: 'Lê Văn Phong',
    expected_approver_can_approve: true,
    created_by_name: 'Trần Thu Hà',
    expected_block: null,
  };
  it('(a) quản lý bị khoá: dòng là câu "Nhờ Admin…", nút bị chặn', () => {
    const r = { ...base, expected_block: 'NGUOI_DUYET_BI_KHOA' as const };
    expect(submitBlockOf(r)).toBe('NGUOI_DUYET_BI_KHOA');
    expect(approverLine(r)).toContain('đang bị khoá nên chưa trình được. Nhờ Admin');
  });
  it('(b) quản lý thiếu quyền duyệt: dòng nêu tên và câu thiếu quyền', () => {
    const r = { ...base, expected_block: 'NGUOI_DUYET_THIEU_QUYEN' as const };
    expect(submitBlockOf(r)).toBe('NGUOI_DUYET_THIEU_QUYEN');
    expect(approverLine(r)).toContain('Lê Văn Phong chưa có quyền Duyệt đơn hàng');
  });
  it('(c) chưa có quản lý và cơ sở chưa có Trưởng cơ sở (R-V2-12): dòng nêu rõ, nút bị chặn', () => {
    const r = {
      ...base,
      expected_route: 'THIEU' as const,
      expected_block: 'KHONG_CO_QUAN_LY' as const,
    };
    expect(submitBlockOf(r)).toBe('KHONG_CO_QUAN_LY');
    expect(approverLine(r, true)).toBe(
      'Người duyệt: chưa có · bạn chưa có quản lý trực tiếp và cơ sở chưa có Trưởng cơ sở',
    );
  });
  it('(d) R-V2-12: chưa có quản lý nhưng cơ sở có Trưởng cơ sở thì KHÔNG bị chặn, dòng nói Trưởng cơ sở duyệt', () => {
    const r = { ...base, expected_route: 'TRUONG_CS' as const, expected_approver_name: null };
    expect(submitBlockOf(r)).toBeNull();
    expect(approverLine(r, true)).toBe('Người duyệt: Trưởng cơ sở · bạn chưa có quản lý trực tiếp');
  });
  it('không bị chặn: dòng người duyệt như cũ; không phải đơn Nháp thì không có dòng và không chặn', () => {
    expect(submitBlockOf(base)).toBeNull();
    expect(approverLine(base)).toBe(
      'Người duyệt: Lê Văn Phong · quản lý trực tiếp của Trần Thu Hà',
    );
    const sent = { ...base, status_code: 'DA_TRINH' as const };
    expect(submitBlockOf(sent)).toBeNull();
    expect(approverLine(sent)).toBeNull();
  });
});

describe('R-V2-12: đơn Đã trình chờ Trưởng cơ sở (Q-117)', () => {
  it('route TRUONG_CS không chốt một người nên gọi chung "Trưởng cơ sở"', () => {
    expect(waitingApproverName({ approval_route: 'TRUONG_CS', approver_name: null })).toBe(
      'Trưởng cơ sở',
    );
  });
  it('route khác giữ tên người duyệt đã chốt', () => {
    expect(waitingApproverName({ approval_route: 'QUAN_LY', approver_name: 'Lê Văn Phong' })).toBe(
      'Lê Văn Phong',
    );
    expect(waitingApproverName({ approval_route: null, approver_name: null })).toBeNull();
  });
});

describe('Dòng chặn trình dùng chung cho phiếu thu (C16 cụm 1)', () => {
  const base = {
    status_code: 'NHAP' as const,
    expected_route: 'QUAN_LY' as const,
    expected_approver_can_approve: false,
    expected_approver_name: 'Lê Văn Phong',
    expected_block: 'NGUOI_DUYET_THIEU_QUYEN' as const,
    created_by_name: 'Người lập',
  };
  it('gọi đúng tên loại chứng từ khi người duyệt thiếu quyền', () => {
    expect(approverWarning(base)).toContain('quyền Duyệt đơn hàng');
    expect(approverWarning(base, 'phiếu thu')).toContain('quyền Duyệt phiếu thu');
  });
  it('dòng cạnh nút Trình của phiếu thu nêu phiếu thu', () => {
    expect(approverLine(base, true, 'phiếu thu')).toContain('phiếu thu');
  });
});
