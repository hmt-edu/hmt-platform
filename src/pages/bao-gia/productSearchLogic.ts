// Ô tìm sản phẩm (canvas «HMT Ô tìm sản phẩm»): dựng dòng, lọc gõ không dấu theo Loại lớp, Môn, Khối. Logic thuần, không tính tiền:
// đơn giá là số máy chủ trả từ bảng giá đang hiệu lực.
import { foldText, formatNumber } from '../../lib/format';
import { modesOfPrices } from './quoteEdit';
import { UNIT_LABEL } from './quoteRecord';
import type { SellablePackage, SellablePackages } from './useQuoteData';

export type ProductRow = {
  pkg: SellablePackage;
  type: string;
  subject: string;
  grade: string;
  price: string;
  grades: string[];
  haystack: string;
};

export type ProductFilters = { type: string; subject: string; grade: string };
export const NO_FILTERS: ProductFilters = { type: '', subject: '', grade: '' };

type Names = (catalog: string, code: string) => string | undefined;

export function productRows(data: SellablePackages, name: Names): ProductRow[] {
  const typeName = new Map(data.types.map((t) => [t.code, t.name]));
  return data.packages.map((pkg) => {
    const gradeCodes = pkg.grade_codes?.length
      ? pkg.grade_codes
      : [...new Set([pkg.grade_from_code, pkg.grade_to_code].filter((c): c is string => !!c))];
    // Sản phẩm dùng danh mục khối riêng (có Chuyên sâu, SAT, 5NC…); không thấy mới tra khối của học sinh.
    const gradeNames = gradeCodes.map((c) => name('PRODUCT_GRADE', c) ?? name('GRADE', c) ?? c);
    const grade = pkg.grade_label ?? gradeNames.join(', ');
    const type = typeName.get(pkg.package_type_code) ?? pkg.package_type_code;
    const subject = pkg.subject_code ? (name('SUBJECT', pkg.subject_code) ?? pkg.subject_code) : '';
    const price = modesOfPrices(pkg.prices)
      .map((m) => `${name('STUDY_MODE', m) ?? m} ${formatNumber(pkg.prices[m] ?? 0)}`)
      .join(' · ');
    return {
      pkg,
      type,
      subject,
      grade,
      price: `${price} đ/${UNIT_LABEL[pkg.unit_code]}`,
      grades: gradeNames,
      haystack: foldText([pkg.code, pkg.name, type, subject, grade, ...gradeNames].join(' ')),
    };
  });
}

/** Mọi từ gõ vào đều phải có trong dòng (không phân biệt dấu, thứ tự), cộng các bộ lọc đang chọn. */
export function filterProducts(
  rows: ProductRow[],
  query: string,
  filters: ProductFilters,
): ProductRow[] {
  const tokens = foldText(query).split(' ').filter(Boolean);
  return rows.filter(
    (r) =>
      (filters.type === '' || r.type === filters.type) &&
      (filters.subject === '' || r.subject === filters.subject) &&
      (filters.grade === '' || r.grades.includes(filters.grade)) &&
      tokens.every((t) => r.haystack.includes(t)),
  );
}

export type ProductGroup = { title: string | null; rows: ProductRow[] };

/** Chưa gõ, chưa lọc: «Hay dùng» và «Gợi ý theo cơ hội»; không có cả hai thì liệt kê tất cả để vẫn chọn được. */
export function productGroups(
  rows: ProductRow[],
  data: Pick<SellablePackages, 'popular' | 'suggested'>,
  query: string,
  filters: ProductFilters,
): ProductGroup[] {
  const searching = query.trim() !== '' || Object.values(filters).some((v) => v !== '');
  if (!searching) {
    const byCode = new Map(rows.map((r) => [r.pkg.code, r]));
    const pick = (codes: string[]) =>
      codes.map((c) => byCode.get(c)).filter((r): r is ProductRow => r !== undefined);
    const popular = pick(data.popular);
    const suggested = pick(data.suggested.filter((c) => !data.popular.includes(c)));
    const groups = [
      { title: 'Hay dùng', rows: popular },
      { title: 'Gợi ý theo cơ hội', rows: suggested },
    ].filter((g) => g.rows.length > 0);
    if (groups.length > 0) return groups;
  }
  const found = filterProducts(rows, query, filters);
  return found.length > 0 ? [{ title: null, rows: found }] : [];
}

/** Danh sách giá trị của một chip lọc, lấy từ chính các sản phẩm đang bán. */
export function filterValues(rows: ProductRow[], key: keyof ProductFilters): string[] {
  const values = rows.flatMap((r) => (key === 'grade' ? r.grades : [r[key]]));
  return [...new Set(values.filter((v) => v !== ''))].sort((a, b) =>
    a.localeCompare(b, 'vi', { numeric: true }),
  );
}
