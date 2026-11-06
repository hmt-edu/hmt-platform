import { describe, expect, it } from 'vitest';
import { inputOf, reasonText, receiptSteps, type ReceiptDraft } from './receiptRecord';

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
