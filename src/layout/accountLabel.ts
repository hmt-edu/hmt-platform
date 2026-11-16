// Nhãn đọc của nút tài khoản (AccountMenu). Luật axe `label-content-name-mismatch` (@axe-core/playwright 4.14): tên đọc của nút phải CHỨA chữ đang hiện trên nút.
// Trên màn rộng nút hiện «tên» và dòng «vai trò · cơ sở»; nên nhãn gồm cả hai (sau tiền tố «Tài khoản:»). Dạng gọn (chỉ ảnh đại diện) hoặc màn hẹp (chữ bị ẩn): chỉ có tên.
export function accountLabel(name: string, roleLine: string, compact: boolean): string {
  const shown = compact ? [name] : [name, roleLine];
  return `Tài khoản: ${shown.filter((part) => part.trim() !== '').join(' ')}`;
}
