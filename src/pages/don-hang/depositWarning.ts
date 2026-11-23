// B-23-14 (anh chốt 23/11): đợt 1 theo lịch nhỏ hơn tiền cọc tối thiểu thì CẢNH BÁO (không tự đổi tiền): thu đủ đợt 1 mà tổng tiền đã vào vẫn chưa tới cọc tối thiểu thì đơn không sinh ghi danh (R-TIEN-20).
// Hàm thuần: số cọc tối thiểu đọc từ Cài đặt (deposit_min_amount), không viết cứng.
import type { OrderInstallment } from './orderTypes';

export type DepositWarning = { firstAmount: number; depositMin: number };

/** Đơn Nháp, Đã trình: lịch có đợt 1 nhỏ hơn cọc tối thiểu thì trả số liệu để cảnh báo; ngược lại null. Chưa có lịch hoặc chưa đọc được tham số thì không cảnh báo. */
export function depositWarning(
  status: string,
  installments: OrderInstallment[],
  depositMin: number | null,
): DepositWarning | null {
  if (!['NHAP', 'DA_TRINH'].includes(status)) return null;
  if (depositMin === null || depositMin <= 0) return null;
  const first = [...installments].sort((a, b) => a.seq - b.seq)[0];
  if (!first || first.amount >= depositMin) return null;
  return { firstAmount: first.amount, depositMin };
}
