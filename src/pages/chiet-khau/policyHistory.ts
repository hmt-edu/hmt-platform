// CH-04 Lịch sử thay đổi chính sách (canvas 9933: nút «Lịch sử thay đổi» ở CH04_chinh): kiểu dòng nhật ký và câu mô tả thay đổi. Hàm thuần, có kiểm thử.
// Dữ liệu từ app.list_policy_history (migration 601): changes dạng {"cột":[cũ,mới]}.

export type PolicyHistoryRow = {
  id: number;
  at: string;
  kind: 'DISCOUNT' | 'GIFT';
  code: string;
  name: string;
  action: 'I' | 'U';
  changes: Record<string, [unknown, unknown]> | null;
  actor_name: string | null;
};

export type PolicyHistoryPage = { total: number; rows: PolicyHistoryRow[] };

export const POLICY_KIND_LABEL: Record<PolicyHistoryRow['kind'], string> = {
  DISCOUNT: 'Chiết khấu',
  GIFT: 'Quà tặng',
};

const FIELD_LABEL: Record<string, string> = {
  name: 'Tên',
  max_value: 'Mức tối đa',
  max_quantity: 'Mức tối đa',
  fixed_value: 'Áp đúng mức',
  requires_approval: 'Cần duyệt',
  valid_from: 'Hiệu lực từ',
  valid_to: 'Hiệu lực đến',
  package_type_codes: 'Nhóm gói',
  branch_ids: 'Cơ sở',
  applies_to: 'Áp dụng cho',
  is_active: 'Trạng thái',
};

const APPLIES_LABEL: Record<string, string> = {
  BAO_GIA: 'Báo giá',
  DON: 'Đơn',
  PHIEU_THU: 'Phiếu thu',
};

/** Cách hiện một giá trị trong câu mô tả (số, ngày, đúng/sai, danh sách); rỗng hiện «—». */
export function formatPolicyValue(field: string, value: unknown): string {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'boolean') {
    return field === 'is_active' ? (value ? 'Đang dùng' : 'Ngừng') : value ? 'Có' : 'Không';
  }
  if (Array.isArray(value)) {
    if (value.length === 0) return field === 'branch_ids' ? 'Tất cả cơ sở' : '—';
    return value
      .map((v) => (field === 'applies_to' ? (APPLIES_LABEL[String(v)] ?? String(v)) : String(v)))
      .join(', ');
  }
  return typeof value === 'string' || typeof value === 'number'
    ? String(value)
    : JSON.stringify(value);
}

/** Câu mô tả một dòng lịch sử: «Tạo mới» hoặc «Mức tối đa: 8 → 9; Trạng thái: Đang dùng → Ngừng». */
export function describePolicyChange(row: Pick<PolicyHistoryRow, 'action' | 'changes'>): string {
  if (row.action === 'I') return 'Tạo mới';
  const parts = Object.entries(row.changes ?? {}).map(
    ([field, pair]) =>
      `${FIELD_LABEL[field] ?? field}: ${formatPolicyValue(field, pair[0])} → ${formatPolicyValue(field, pair[1])}`,
  );
  return parts.length > 0 ? parts.join('; ') : 'Sửa';
}
