import { describe, expect, it } from 'vitest';
import {
  editedSinceRejection,
  inputOf,
  lastRejection,
  reasonText,
  receiptSteps,
  rejectedByAccountant,
  type ReceiptDraft,
} from './receiptRecord';
import type { ReceiptEvent } from './receiptTypes';

const draft: ReceiptDraft = {
  amount: 7000000,
  paymentMethod: 'CHUYEN_KHOAN',
  paidOn: '2026-10-12',
  txnRef: ' ',
  receiverId: '',
  receiverName: '',
  collectBranchId: 'b1',
  targetLineId: '',
  note: '',
};

describe('receiptRecord', () => {
  it('thanh tình trạng: Huỷ thay cho Đã duyệt', () => {
    expect(receiptSteps('NHAP').at(-1)).toBe('DA_DUYET');
    expect(receiptSteps('HUY').at(-1)).toBe('HUY');
  });
  it('dữ liệu gửi: ô trống thành null', () => {
    expect(inputOf(draft)).toMatchObject({
      amount: 7000000,
      txn_ref: null,
      receiver_id: null,
      target_line_id: null,
      note: null,
    });
  });
  it('lý do kèm ghi chú', () => {
    expect(reasonText('Sai chứng từ', '')).toBe('Sai chứng từ');
    expect(reasonText('Sai chứng từ', ' kiểm lại ')).toBe('Sai chứng từ: kiểm lại');
  });
});

describe('trình lại phiếu thu bị từ chối (Q-58, R-TIEN-06)', () => {
  const ev = (code: ReceiptEvent['event_code'], from: string | null = null): ReceiptEvent => ({
    event_code: code,
    from_status: from,
    to_status: 'NHAP',
    note: null,
    at: '2026-11-07T01:00:00Z',
    by_name: null,
  });
  it('chưa từng bị từ chối: không có lần từ chối, không coi là chưa sửa', () => {
    const record = { status_code: 'NHAP' as const, events: [ev('TAO')] };
    expect(lastRejection(record)).toBeNull();
    expect(editedSinceRejection(record)).toBe(false);
    expect(rejectedByAccountant(record)).toBe(false);
  });
  it('bị từ chối rồi chưa sửa: chưa sửa từ lần từ chối; có SUA sau đó thì đã sửa', () => {
    const rejected = {
      status_code: 'NHAP' as const,
      events: [ev('TAO'), ev('GUI'), ev('TU_CHOI', 'DA_GUI')],
    };
    expect(lastRejection(rejected)?.index).toBe(2);
    expect(editedSinceRejection(rejected)).toBe(false);
    expect(editedSinceRejection({ ...rejected, events: [...rejected.events, ev('SUA')] })).toBe(
      true,
    );
    // SUA trước lần từ chối không tính.
    expect(
      editedSinceRejection({ status_code: 'NHAP', events: [ev('SUA'), ev('TU_CHOI', 'DA_GUI')] }),
    ).toBe(false);
  });
  it('kế toán từ chối (từ Chờ kế toán) thì nhắc trình lại đi từ bước quản lý; quản lý từ chối thì không', () => {
    expect(
      rejectedByAccountant({ status_code: 'NHAP', events: [ev('TU_CHOI', 'CHO_KE_TOAN')] }),
    ).toBe(true);
    expect(rejectedByAccountant({ status_code: 'NHAP', events: [ev('TU_CHOI', 'DA_GUI')] })).toBe(
      false,
    );
  });
  it('phiếu không còn Nháp: không có lần từ chối để hỏi lại', () => {
    expect(lastRejection({ status_code: 'DA_GUI', events: [ev('TU_CHOI', 'DA_GUI')] })).toBeNull();
  });
});
