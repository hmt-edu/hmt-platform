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

/** Khối đến nhỏ hơn khối từ (so theo thứ tự trong danh mục): trả câu báo lỗi, ngược lại null. */
export function gradeRangeError(order: string[], from: string, to: string): string | null {
  if (from === '' || to === '' || to === from) return null;
  return order.indexOf(to) < order.indexOf(from) ? 'Khối đến không được nhỏ hơn khối từ.' : null;
}
