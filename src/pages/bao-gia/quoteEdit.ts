// Trạng thái và hàm thuần của lưới sửa Nháp BH-02 (khuôn K06c). Giao diện KHÔNG tính tiền, giờ hay chiết khấu: ở đây chỉ dựng dòng gửi
// cho app.save_quotation, kiểm các ô bắt buộc theo khung (số lượng) và so sánh để biết có thay đổi chưa lưu. Có kiểm thử.
import type { QuotationLine, QuotationLineDiscount, QuotationRecord } from './quoteTypes';

/** Một dòng đang sửa. `quantity` giữ chữ người gõ ("10", "1,5") cho tới khi lưu. */
export type EditRow = {
  key: string;
  kind: 'ENROL' | 'GIFT';
  /** Mã em trong danh sách em của cơ hội; rỗng là chưa chọn. */
  studentId: string;
  packageId: string;
  packageCode: string;
  packageName: string;
  unitCode: QuotationLine['unit_code'] | '';
  /** Hình thức gói bán (từ bảng giá); rỗng là chưa biết (dòng cũ, chưa nạp gói): cho chọn mọi hình thức, máy chủ kiểm lúc lưu. */
  modes: string[];
  mode: string;
  quantity: string;
  /** Chính sách chiết khấu giữ nguyên khi chưa sửa (PR sau mới cho sửa). */
  discounts: { policyId: string; name: string; value: number }[];
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
  return String(q).replace(/\.0+$/, '').replace(/(\.\d*?)0+$/, '$1').replace('.', ',');
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
    unitCode: l.unit_code,
    modes: [],
    mode: l.delivery_mode_code,
    quantity: quantityToText(l.quantity),
    discounts: l.discounts.map((d: QuotationLineDiscount) => ({
      policyId: d.policy_id,
      name: d.policy_name,
      value: d.applied_value,
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
    if (row.kind === 'ENROL' && row.packageId !== '' && parseQuantity(row.quantity) === null) {
      const label = `${row.packageCode} · ${row.packageName}`;
      issues.push({
        rowKey: row.key,
        lineNo: i + 1,
        message: 'Bắt buộc nhập số lượng.',
        summary: `Dòng ${String(i + 1)} (${label}) thiếu số lượng.`,
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
          discounts: row.discounts.map((d) => ({ policy_id: d.policyId, value: d.value })),
        },
  );
}

/** Có đổi gì so với lúc bắt đầu sửa chưa (để hỏi khi rời trang, bật nút Lưu). Bỏ qua khoá nội bộ và số tính sẵn. */
export function rowsSignature(rows: EditRow[]): string {
  return JSON.stringify(rows.map(({ key: _key, calc: _calc, modes: _modes, ...rest }) => rest));
}

/** Hình thức chọn được của một gói: các hình thức có giá, OFF trước ONL. */
export function modesOfPrices(prices: Record<string, number>): string[] {
  return Object.keys(prices).sort((a, b) => (a === 'OFF' ? -1 : b === 'OFF' ? 1 : a.localeCompare(b)));
}
