// Các dòng bảng tính hoàn trên bản in phiếu chi (TC-12, R-TIEN-28, R-TIEN-08): cùng cách tính và cùng nhãn với bảng ở bản ghi (TC-11).
// Số do máy chủ trả (chụp lúc tạo yêu cầu); ở đây chỉ ghép dòng để in, không tính lại tiền.
import { formatNumber } from '../../lib/format';
import type { VoucherRecord } from './voucherTypes';

export type PrintRow = { key: string; label: string; amount: number };

export function voucherPrintRows(r: VoucherRecord['refund']): PrintRow[] {
  const n = formatNumber;
  const head: PrintRow[] =
    r.kind_code === 'TOAN_BO'
      ? [
          { key: 'paid', label: 'Phụ huynh đã đóng cho ghi danh', amount: r.paid_amount },
          {
            key: 'used',
            label: `Giờ đã học × giá gốc (${n(r.hours_used)} giờ × ${n(r.unit_price_base)} đ)`,
            amount: -r.used_amount,
          },
          ...(r.prior_refund_amount > 0
            ? [{ key: 'prior', label: 'Đã hoàn các lần trước', amount: -r.prior_refund_amount }]
            : []),
        ]
      : [
          {
            key: 'hours',
            label: `Giờ hoàn × giá sau chiết khấu (${n(r.hours_refund)} giờ × ${n(r.unit_price_net)} đ)`,
            amount: r.base_amount,
          },
        ];
  return [
    ...head,
    {
      key: 'base',
      label:
        r.kind_code === 'TOAN_BO' ? 'Còn lại sau khi trừ giờ đã học' : 'Số tiền hoàn trước phí',
      amount: r.base_amount,
    },
    { key: 'fee', label: `Phí xử lý (${n(r.fee_percent)}%)`, amount: -r.fee_amount },
    { key: 'refund', label: 'Số tiền hoàn', amount: r.refund_amount },
  ];
}
