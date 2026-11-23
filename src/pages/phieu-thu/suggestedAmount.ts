// Số tiền gợi ý khi lập phiếu thu từ đơn (T2-04): theo điều khoản thanh toán của đơn, gợi ý đợt tới hạn đầu tiên chưa thu đủ
// (ví dụ «Cọc rồi đóng phần còn lại» gợi ý khoản cọc), không gợi ý cả đơn. Chỉ là gợi ý để điền sẵn; máy chủ vẫn kiểm mức thu tối đa (R-TIEN-01).
export type InstallmentLike = { seq: number; amount: number };

export function suggestedReceiptAmount(
  installments: readonly InstallmentLike[],
  paid: number,
  receivable: number | null,
): number | null {
  if (receivable === null || receivable <= 0) return null;
  let cumulative = 0;
  for (const i of [...installments].sort((a, b) => a.seq - b.seq)) {
    cumulative += i.amount;
    if (paid < cumulative) return Math.min(cumulative - paid, receivable);
  }
  return receivable;
}
