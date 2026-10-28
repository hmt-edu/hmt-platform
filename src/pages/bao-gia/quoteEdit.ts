// Trạng thái và hàm thuần của lưới sửa Nháp BH-02 (khuôn K06c). Giao diện KHÔNG tính tiền, giờ hay chiết khấu: ở đây chỉ dựng dòng gửi
// cho app.save_quotation, kiểm các ô bắt buộc theo khung (số lượng) và so sánh để biết có thay đổi chưa lưu. Có kiểm thử.
import type { QuotationLine, QuotationLineDiscount, QuotationRecord } from './quoteTypes';

/** Một dòng đang sửa. `quantity` giữ chữ người gõ ("10", "1,5") cho tới khi lưu. */
export type EditDiscount = { policyId: string; name: string; value: string };

export type EditRow = {
  key: string;
  kind: 'ENROL' | 'GIFT';
  /** Mã em trong danh sách em của cơ hội; rỗng là chưa chọn. */
  studentId: string;
  packageId: string;
  packageCode: string;
  packageName: string;
  /** Loại gói (LC, VIP, …) để lọc chính sách theo loại gói. */
  packageType: string;
  unitCode: QuotationLine['unit_code'] | '';
  /** Hình thức gói bán (từ bảng giá); rỗng là chưa biết (dòng cũ, chưa nạp gói): cho chọn mọi hình thức, máy chủ kiểm lúc lưu. */
  modes: string[];
  mode: string;
  quantity: string;
  /** Chính sách chiết khấu của dòng. `value` là chữ người gõ: mức % (để trống = mức tối đa) hoặc số giờ tặng; chính sách "áp đúng mức" không nhập. */
  discounts: EditDiscount[];
  giftPolicyId: string;
  giftPolicyName: string;
  /** Số tính sẵn của bản đã lưu; null khi dòng đã đổi (không hiện số cũ). */
  calc: { unitPrice: number; discountAmount: number; lineTotal: number } | null;
};

let counter = 0;
export function newRowKey(): string {
  counter += 1;
  return `row-${String(counter)}`;
}

export function blankRow(): EditRow {
  return {
    key: newRowKey(),
    kind: 'ENROL',
    studentId: '',
    packageId: '',
    packageCode: '',
    packageName: '',
    packageType: '',
    unitCode: '',
    modes: [],
    mode: '',
    quantity: '',
    discounts: [],
    giftPolicyId: '',
    giftPolicyName: '',
    calc: null,
  };
}

function quantityToText(q: number): string {
  return String(q)
    .replace(/\.0+$/, '')
    .replace(/(\.\d*?)0+$/, '$1')
    .replace('.', ',');
}

/** Dòng quà tặng mới từ một chính sách quà tặng (R-TIEN-30): gắn một em (chọn trên dòng), số lượng nhân viên điền. */
export function giftRow(policy: {
  id: string;
  name: string;
  gift_package: {
    id: string;
    code: string;
    name: string;
    package_type_code: string;
    unit_code: QuotationLine['unit_code'];
  };
}): EditRow {
  return {
    ...blankRow(),
    kind: 'GIFT',
    packageId: policy.gift_package.id,
    packageCode: policy.gift_package.code,
    packageName: policy.gift_package.name,
    packageType: policy.gift_package.package_type_code,
    unitCode: policy.gift_package.unit_code,
    mode: 'OFF',
    giftPolicyId: policy.id,
    giftPolicyName: policy.name,
  };
}

/** Thêm dòng gói mới: đặt trước các dòng quà (dòng quà đánh số tiếp theo dòng gói). */
export function insertPackageRow(rows: EditRow[], row: EditRow): EditRow[] {
  const firstGift = rows.findIndex((r) => r.kind === 'GIFT');
  return firstGift === -1
    ? [...rows, row]
    : [...rows.slice(0, firstGift), row, ...rows.slice(firstGift)];
}

/** Dòng sửa từ bản ghi đã lưu. */
export function rowsFromRecord(record: Pick<QuotationRecord, 'lines'>): EditRow[] {
  return record.lines.map((l) => ({
    key: newRowKey(),
    kind: l.line_kind,
    studentId: l.prospect_student_id ?? '',
    packageId: l.package_id,
    packageCode: l.package_code,
    packageName: l.package_name,
    packageType: l.package_type_code,
    unitCode: l.unit_code,
    modes: [],
    mode: l.delivery_mode_code,
    quantity: quantityToText(l.quantity),
    discounts: l.discounts.map((d: QuotationLineDiscount) => ({
      policyId: d.policy_id,
      name: d.policy_name,
      value: String(d.applied_value).replace(/\.0+$/, '').replace('.', ','),
    })),
    giftPolicyId: l.gift_policy_id ?? '',
    giftPolicyName: l.gift_policy_name ?? '',
    calc: { unitPrice: l.unit_price, discountAmount: l.discount_amount, lineTotal: l.line_total },
  }));
}

/** Đọc số lượng người gõ ("10", "1,5", "1.5"); sai hoặc không dương thì null. */
export function parseQuantity(text: string): number | null {
  const t = text.trim().replace(',', '.');
  if (t === '' || !/^\d+(\.\d{1,2})?$/.test(t)) return null;
  const n = Number(t);
  return n > 0 ? n : null;
}

/** Lỗi ô theo khung (BH02_sua): thiếu số lượng. Em, gói, hình thức do máy chủ kiểm lúc lưu và nêu đúng dòng. */
export type RowIssue = { rowKey: string; lineNo: number; message: string; summary: string };

export function validateRows(rows: EditRow[]): RowIssue[] {
  const issues: RowIssue[] = [];
  rows.forEach((row, i) => {
    const named = row.kind === 'GIFT' ? row.giftPolicyId !== '' : row.packageId !== '';
    if (named && parseQuantity(row.quantity) === null) {
      const label = `${row.packageCode} · ${row.packageName}`;
      issues.push({
        rowKey: row.key,
        lineNo: i + 1,
        message: 'Bắt buộc nhập số lượng.',
        summary: `Dòng ${String(i + 1)} (${label}) thiếu số lượng.`,
      });
    }
  });
  // Mức chiết khấu hoặc giờ tặng gõ sai (chữ, quá hai chữ số thập phân): báo ngay ở dòng, không gửi lên máy chủ.
  rows.forEach((row, i) => {
    if (row.discounts.some((d) => d.value.trim() !== '' && parseQuantity(d.value) === null)) {
      issues.push({
        rowKey: row.key,
        lineNo: i + 1,
        message: 'Mức chiết khấu hoặc giờ tặng không hợp lệ.',
        summary: `Dòng ${String(i + 1)} có mức chiết khấu hoặc giờ tặng không hợp lệ.`,
      });
    }
  });
  return issues;
}

/** Mảng dòng cho app.save_quotation (cùng khuôn với xem thử): {kind, prospect_student_id, package_id, delivery_mode_code, quantity, discounts}. */
export function buildSaveLines(rows: EditRow[]): Record<string, unknown>[] {
  return rows.map((row) =>
    row.kind === 'GIFT'
      ? {
          kind: 'GIFT',
          prospect_student_id: row.studentId === '' ? null : row.studentId,
          gift_policy_id: row.giftPolicyId,
          quantity: parseQuantity(row.quantity),
        }
      : {
          kind: 'ENROL',
          prospect_student_id: row.studentId === '' ? null : row.studentId,
          package_id: row.packageId === '' ? null : row.packageId,
          delivery_mode_code: row.mode === '' ? null : row.mode,
          quantity: parseQuantity(row.quantity),
          discounts: row.discounts.map((d) => ({
            policy_id: d.policyId,
            value: parseQuantity(d.value),
          })),
        },
  );
}

/** Có đổi gì so với lúc bắt đầu sửa chưa (để hỏi khi rời trang, bật nút Lưu). Bỏ qua khoá nội bộ và số tính sẵn. */
export function rowsSignature(rows: EditRow[]): string {
  return JSON.stringify(
    rows.map((r) => [
      r.kind,
      r.studentId,
      r.packageId,
      r.mode,
      r.quantity.trim(),
      r.giftPolicyId,
      r.discounts.map((d) => [d.policyId, d.value]),
    ]),
  );
}

/** Hình thức chọn được của một gói: các hình thức có giá, OFF trước ONL. */
export function modesOfPrices(prices: Record<string, number>): string[] {
  return Object.keys(prices).sort((a, b) =>
    a === 'OFF' ? -1 : b === 'OFF' ? 1 : a.localeCompare(b),
  );
}

/** Sau khi sửa dòng: bỏ lỗi của những dòng nay đã hợp lệ (lỗi tự mất khi nhập đúng), giữ lỗi của dòng còn sai. */
export function pruneIssues(issues: RowIssue[], rows: EditRow[]): RowIssue[] {
  const still = new Set(validateRows(rows).map((i) => i.rowKey));
  return issues.filter((i) => still.has(i.rowKey));
}
