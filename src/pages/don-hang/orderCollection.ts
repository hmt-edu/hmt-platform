// Cột «Đã thu», «Còn phải thu», «Thu tiền» của danh sách Đơn hàng (canvas BH06). Hàm thuần: số liệu do máy chủ trả (paid_amount), giao diện chỉ trừ và gán nhãn.
export type OrderCollection = {
  /** Còn phải thu; null (hiện «—») khi đơn chưa Đã duyệt. */
  receivable: number | null;
  /** Nhãn cột «Thu tiền»; null (hiện «—») khi đơn chưa Đã duyệt. */
  label: 'Chưa thu' | 'Thu một phần' | 'Đã thu đủ' | null;
};

export function orderCollection(statusCode: string, total: number, paid: number): OrderCollection {
  if (statusCode !== 'DA_DUYET') return { receivable: null, label: null };
  const receivable = Math.max(total - paid, 0);
  if (paid <= 0) return { receivable, label: 'Chưa thu' };
  return { receivable, label: receivable === 0 ? 'Đã thu đủ' : 'Thu một phần' };
}
