// CH-04 Chính sách chiết khấu và quà tặng: logic thuần (tình trạng theo ngày, kiểm biểu mẫu, mã từ tên). Luật R-TIEN-29 (chiết khấu: % hoặc giờ tặng, cộng dồn, có trần),
// R-TIEN-30 (quà tặng giá 0 đ, không tính vào trần), R-TIEN-14 (đơn đã tạo giữ giá trị đã chụp), R-TIEN-36 (giờ tặng nhân viên điền). Hàm DB save_*_policy kiểm lại.
import { foldText } from '../../lib/format';

export type DiscountPolicy = {
  id: string;
  code: string;
  name: string;
  kind: 'PERCENT' | 'GIFT_HOURS';
  max_value: number;
  fixed_value: boolean;
  requires_approval: boolean;
  valid_from: string;
  valid_to: string | null;
  package_type_codes: string[];
  branch_ids: string[];
  is_active: boolean;
  is_flexible: boolean;
  applies_to: string[];
};

export type GiftPolicy = {
  id: string;
  code: string;
  name: string;
  gift_package_id: string;
  max_quantity: number;
  requires_approval: boolean;
  valid_from: string;
  valid_to: string | null;
  package_type_codes: string[];
  branch_ids: string[];
  is_active: boolean;
  gift_package: { code: string; name: string; package_type_code: string } | null;
};

export type PolicyStatus = 'ACTIVE' | 'UPCOMING' | 'EXPIRED' | 'STOPPED';

export const STATUS_LABEL: Record<PolicyStatus, string> = {
  ACTIVE: 'Đang áp dụng',
  UPCOMING: 'Chưa tới hạn',
  EXPIRED: 'Hết hạn',
  STOPPED: 'Ngừng',
};

/** Tình trạng theo ngày (yyyy-mm-dd, giờ Việt Nam): Ngừng thắng, rồi Chưa tới hạn, Hết hạn, Đang áp dụng. */
export function statusOf(
  p: { is_active: boolean; valid_from: string; valid_to: string | null },
  today: string,
): PolicyStatus {
  if (!p.is_active) return 'STOPPED';
  if (p.valid_from > today) return 'UPCOMING';
  if (p.valid_to !== null && p.valid_to < today) return 'EXPIRED';
  return 'ACTIVE';
}

/** Ngày hôm nay theo giờ Việt Nam (yyyy-mm-dd). */
export function todayVn(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' }).format(now);
}

export const dateToIso = (d: Date): string =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; // allow-number: định dạng yyyy-mm-dd

export function isoToDate(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y ?? 0, (m ?? 1) - 1, d ?? 1);
}

/** Mã chính sách từ tên: hoa, không dấu, gạch dưới ("Đóng cả năm" → "DONG_CA_NAM"). */
export function policyCode(name: string): string {
  return foldText(name)
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

const MAX_PERCENT = 100; // allow-number: phần trăm tối đa (cùng luật DB)

export type FormValues = {
  appliesTo: string[];
  name: string;
  kind: 'PERCENT' | 'GIFT_HOURS';
  maxValue: string;
  fixedValue: boolean;
  requiresApproval: boolean;
  validFrom: Date | null;
  validTo: Date | null;
  packageTypes: string[];
  branchIds: string[];
};

export type FormErrors = Partial<
  Record<'name' | 'maxValue' | 'validFrom' | 'validTo' | 'packageTypes', string>
>;

/** Lỗi từng ô (câu theo khung CH04_loi). Rỗng khi hợp lệ. `quantity`: ô mức tối đa là số lượng quà, không giới hạn 100. */
export function formErrors(v: FormValues, quantity = false): FormErrors {
  const errors: FormErrors = {};
  if (v.name.trim() === '') errors.name = 'Nhập tên chính sách.';
  const max = Number(v.maxValue.replace(',', '.'));
  if (v.maxValue.trim() === '' || !Number.isFinite(max))
    errors.maxValue = 'Bắt buộc nhập mức tối đa';
  else if (max <= 0) errors.maxValue = 'Mức tối đa phải lớn hơn 0.';
  else if (!quantity && v.kind === 'PERCENT' && max > MAX_PERCENT) {
    errors.maxValue = `Phần trăm không quá ${MAX_PERCENT}.`;
  }
  if (v.validFrom === null) errors.validFrom = 'Chọn ngày bắt đầu hiệu lực.';
  if (v.validFrom && v.validTo && v.validTo <= v.validFrom) {
    errors.validTo = 'Hiệu lực đến phải sau hiệu lực từ';
  }
  if (v.packageTypes.length === 0) errors.packageTypes = 'Chọn ít nhất một nhóm gói';
  return errors;
}

/** Câu tóm tắt lỗi đầu biểu mẫu: "Chưa lưu được: còn 3 chỗ cần sửa (mức tối đa, hiệu lực đến, nhóm gói)." */
export function errorSummary(errors: FormErrors): string | null {
  const labels: Record<keyof FormErrors, string> = {
    name: 'tên',
    maxValue: 'mức tối đa',
    validFrom: 'hiệu lực từ',
    validTo: 'hiệu lực đến',
    packageTypes: 'nhóm gói',
  };
  const keys = (Object.keys(labels) as (keyof FormErrors)[]).filter((k) => errors[k]);
  return keys.length === 0
    ? null
    : `Chưa lưu được: còn ${keys.length} chỗ cần sửa (${keys.map((k) => labels[k]).join(', ')}).`;
}

/** Phạm vi cơ sở: rỗng là «Tất cả cơ sở». */
export function branchesLabel(ids: string[], code: (id: string) => string): string {
  return ids.length === 0 ? 'Tất cả cơ sở' : ids.map(code).join(', ');
}

/** Mức tối đa hiển thị: "10%", "4 giờ", "1 bộ / đơn" do nơi gọi ghép đơn vị. */
export const APPLIES_TO_OPTIONS = [
  { code: 'BAO_GIA', name: 'Báo giá' },
  { code: 'DON', name: 'Đơn' },
  { code: 'PHIEU_THU', name: 'Phiếu thu' },
] as const;

/** Cột «Áp dụng cho» ("Báo giá, Đơn, Phiếu thu"), theo thứ tự cố định. */
export function appliesToLabel(p: Pick<DiscountPolicy, 'applies_to'>): string {
  return APPLIES_TO_OPTIONS.filter((o) => p.applies_to.includes(o.code))
    .map((o) => o.name)
    .join(', ');
}

/** Cột «Giá trị»: mức áp đúng khi chính sách áp đúng mức; còn lại nhân viên chọn nên hiện «Tuỳ chọn». Cột «Mức tối đa» luôn là trần. */
export function discountAppliedLabel(p: DiscountPolicy): string {
  return p.fixed_value ? discountValueLabel(p) : 'Tuỳ chọn';
}

export function discountValueLabel(p: DiscountPolicy): string {
  const n = p.max_value.toLocaleString('vi-VN');
  return p.kind === 'PERCENT' ? `${n}%` : `${n} giờ`;
}
