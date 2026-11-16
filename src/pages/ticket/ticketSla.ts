// CSN-09 Cấu hình SLA: dựng phần thay đổi chưa lưu từ giá trị gốc và giá trị đang sửa (luật kiểm cuối cùng ở app.save_ticket_sla, AS-07).
export type SlaRule = {
  ticket_type: 'DN' | 'KN' | 'GV';
  priority_code: 'KHAN' | 'CAO' | 'THUONG' | 'THAP';
  response_hours: number;
  resolve_hours: number;
};
export type SlaOverride = { code: string; name: string; resolve_hours_override: number | null };

/** Giá trị đang gõ theo khoá; chuỗi rỗng là chưa gõ gì (giữ nguyên gốc). */
export type SlaEdits = {
  rules: Record<string, { response?: string; resolve?: string }>;
  overrides: Record<string, string | null>;
};
export const EMPTY_SLA_EDITS: SlaEdits = { rules: {}, overrides: {} };
export const ruleKey = (r: Pick<SlaRule, 'ticket_type' | 'priority_code'>) =>
  `${r.ticket_type}:${r.priority_code}`;

const same = (typed: string | undefined, original: number) =>
  typed === undefined || typed.trim() === '' || Number(typed) === original;

/** Bảng hạn: chỉ những dòng có ô thật sự khác gốc. */
export function changedRules(rules: SlaRule[], edits: SlaEdits) {
  return rules.flatMap((r) => {
    const e = edits.rules[ruleKey(r)];
    if (!e || (same(e.response, r.response_hours) && same(e.resolve, r.resolve_hours))) return [];
    return [
      {
        ticket_type: r.ticket_type,
        priority_code: r.priority_code,
        ...(!same(e.response, r.response_hours) && { response_hours: Number(e.response) }),
        ...(!same(e.resolve, r.resolve_hours) && { resolve_hours: Number(e.resolve) }),
      },
    ];
  });
}

/** Hạn riêng nhóm con: null là «Bỏ hạn riêng»; số là đặt hạn. Chỉ gửi nhóm con có đổi so với gốc. */
export function changedOverrides(overrides: SlaOverride[], edits: SlaEdits) {
  return Object.entries(edits.overrides).flatMap(([code, typed]) => {
    const original = overrides.find((o) => o.code === code)?.resolve_hours_override ?? null;
    const next = typed === null || typed.trim() === '' ? null : Number(typed);
    return next === original ? [] : [{ category_code: code, resolve_hours: next }];
  });
}

export const countChanges = (rules: SlaRule[], overrides: SlaOverride[], edits: SlaEdits) =>
  changedRules(rules, edits).length + changedOverrides(overrides, edits).length;

/** Số giờ nguyên dương (khớp luật ở hàm DB); trả thông báo hoặc null. */
export function slaFieldError(typed: string | undefined): string | null {
  if (typed === undefined || typed.trim() === '') return null;
  const n = Number(typed);
  return Number.isInteger(n) && n >= 1 ? null : 'Nhập số giờ nguyên từ 1 trở lên.';
}
