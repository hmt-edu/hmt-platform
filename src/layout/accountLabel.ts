// Nhãn đọc của nút tài khoản (AccountMenu). Luật axe `label-content-name-mismatch` (@axe-core/playwright 4.14): tên đọc của nút phải CHỨA chữ đang hiện trên nút.
// Trên màn rộng nút hiện «tên» và dòng «vai trò · cơ sở»; nên nhãn gồm cả hai (chữ hiển thị đứng ĐẦU nhãn, liền nhau, ngăn bằng dấu cách như hai khối chữ; «Tài khoản» đặt SAU để nhãn bắt đầu bằng đúng chữ nhìn thấy). Dạng gọn (chỉ ảnh đại diện) hoặc màn hẹp (chữ bị ẩn): chỉ có tên.
export function accountLabel(name: string, roleLines: string[], compact: boolean): string {
  const shown = compact ? [name] : [name, ...roleLines];
  return `${shown.filter((part) => part.trim() !== '').join(' ')} Tài khoản`;
}
