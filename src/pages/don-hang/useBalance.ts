// TC-16: số tiền được cấn tối đa (hàm thuần, có kiểm thử).

/** Số tiền được cấn tối đa: nhỏ hơn của số dư và phần còn thu; không âm. */
export function maxApplicable(balance: number, remaining: number): number {
  return Math.max(0, Math.min(balance, remaining));
}
