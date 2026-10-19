/** Số mã hiện tối đa trong dòng "n bản ghi đã chọn" (còn lại gộp thành "và n bản khác"). */
const LISTED_CODES = 5; // allow-number: số mã liệt kê trên giao diện, không phải số nghiệp vụ

/** "3 lead đã chọn: LD1, LD2, LD3"; nhiều hơn năm mã thì "… và n lead khác". */
export function selectedSummary(noun: string, codes: string[]): string {
  const shown = codes.slice(0, LISTED_CODES).join(', ');
  const rest = codes.length - LISTED_CODES;
  return `${codes.length} ${noun} đã chọn: ${shown}${rest > 0 ? ` và ${rest} ${noun} khác` : ''}`;
}
