// Phần thuần của màn Gói bán (CH-01): ghép mã gói và kiểm ô nhập. Luật chính thức do DB kiểm (trigger sales_package_rules, spec 02).

/** Loại gói tính theo giờ: có môn và khối, mã = Loại-Môn-Khối (hoặc Loại-Môn-KhốiđầuKhốicuối). Dịch vụ, tài liệu: mã Loại-TÊN. */
const HOUR_TYPES = ['LC', 'VIP', 'VNN', 'KR'];

export const isHourType = (type: string) => HOUR_TYPES.includes(type);

export type PackageDraft = {
  type: string;
  subject: string;
  gradeFrom: string;
  /** Rỗng = chỉ một khối (bằng khối từ). */
  gradeTo: string;
  /** Phần tên sau tiền tố của gói dịch vụ, tài liệu (CSGK, MATOAN). */
  suffix: string;
};

/** Mã gói tự ghép (rỗng khi chưa đủ ô). Khối đến bằng khối từ thì coi như một khối. */
export function buildPackageCode(d: PackageDraft): string {
  if (d.type === '') return '';
  if (!isHourType(d.type)) {
    const suffix = d.suffix
      .trim()
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, '');
    return suffix === '' ? '' : `${d.type}-${suffix}`;
  }
  if (d.subject === '' || d.gradeFrom === '') return '';
  const to = d.gradeTo !== '' && d.gradeTo !== d.gradeFrom ? d.gradeTo : '';
  return `${d.type}-${d.subject}-${d.gradeFrom}${to}`;
}

/** Chữ hộp thoại Gói bán theo canvas dc47 (CH01_sua_ten, CH01_ngung); giữ một chỗ để bài kiểm khoá chữ. */
export const packageDialogText = {
  editTitle: (code: string) => `Sửa gói ${code}`,
  codeHelp: 'Mã không đổi được.',
  legacyHelp: 'Mã cũ trên Sheet, dùng để tìm kiếm. Sửa được; mã gói vẫn khoá.',
  nameHelp: 'Đổi tên không đổi mã.',
  stopTitle: (code: string) => `Ngừng bán gói ${code}?`,
  stopBody: (code: string) =>
    `Gói ${code} sẽ không hiện ở ô chọn khi tạo báo giá, đơn mới. Đơn đã tạo vẫn giữ gói này. Muốn bán lại, bấm Dùng lại.`,
};

/** Khối đến nhỏ hơn khối từ (so theo thứ tự trong danh mục): trả câu báo lỗi, ngược lại null. */
export function gradeRangeError(order: string[], from: string, to: string): string | null {
  if (from === '' || to === '' || to === from) return null;
  return order.indexOf(to) < order.indexOf(from) ? 'Khối đến không được nhỏ hơn khối từ.' : null;
}
