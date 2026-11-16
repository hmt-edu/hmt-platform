// CSN-08 Cấu hình nhóm ticket: nháp biểu mẫu nhóm, nhóm con và dữ liệu gửi app.save_ticket_category (luật kiểm cuối ở hàm DB: AS-05, AS-08, AS-10).
export type CategoryRow = {
  code: string;
  name: string;
  kind: 'GROUP' | 'SUBGROUP';
  parent_code: string | null;
  ticket_type: 'DN' | 'KN' | 'GV';
  nature_code: 'HO_TRO' | 'PHAN_ANH' | null;
  default_priority: string | null;
  default_team: string | null;
  business_type: string | null;
  requires_student: boolean;
  requires_class: boolean;
  sort_order: number;
  is_active: boolean;
};

export type CategoryDraft = {
  code: string;
  name: string;
  priority: string;
  team: string;
  business: string;
  nature: string;
  requiresStudent: boolean;
  requiresClass: boolean;
  sortOrder: string;
  active: boolean;
};

export const NEW_CATEGORY_DRAFT: CategoryDraft = {
  code: '',
  name: '',
  priority: '',
  team: '',
  business: '',
  nature: '',
  requiresStudent: false,
  requiresClass: false,
  sortOrder: '',
  active: true,
};

export const draftOf = (c: CategoryRow): CategoryDraft => ({
  code: c.code,
  name: c.name,
  priority: c.default_priority ?? '',
  team: c.default_team ?? '',
  business: c.business_type ?? '',
  nature: c.nature_code ?? '',
  requiresStudent: c.requires_student,
  requiresClass: c.requires_class,
  sortOrder: String(c.sort_order),
  active: c.is_active,
});

/** Mã: chữ hoa, số, gạch dưới (khớp cách đặt mã danh mục); sửa nhóm đã có thì không đổi mã. */
export const CODE_PATTERN = /^[A-Z][A-Z0-9_]{1,39}$/; // allow-number: độ dài mã 2 đến 40 ký tự

export function categoryErrors(
  draft: CategoryDraft,
  creating: boolean,
): Partial<Record<'code' | 'name' | 'sortOrder', string>> {
  const errors: Partial<Record<'code' | 'name' | 'sortOrder', string>> = {};
  if (creating && !CODE_PATTERN.test(draft.code))
    errors.code = 'Mã gồm chữ hoa, số, gạch dưới, bắt đầu bằng chữ.';
  if (draft.name.trim() === '') errors.name = 'Nhập tên.';
  if (draft.sortOrder.trim() !== '' && !Number.isInteger(Number(draft.sortOrder)))
    errors.sortOrder = 'Thứ tự là số nguyên.';
  return errors;
}

/** Dữ liệu gửi hàm DB. Nhóm cha không có mức độ, tính chất, phiếu nghiệp vụ nên không gửi các ô đó. */
export function buildCategoryPayload(
  draft: CategoryDraft,
  ctx: {
    creating: boolean;
    kind: 'GROUP' | 'SUBGROUP';
    parentCode: string | null;
    ticketType: string;
  },
) {
  return {
    code: draft.code,
    name: draft.name.trim(),
    ...(ctx.creating && {
      kind: ctx.kind,
      ...(ctx.kind === 'SUBGROUP'
        ? { parent_code: ctx.parentCode }
        : { ticket_type: ctx.ticketType }),
    }),
    is_active: draft.active,
    ...(draft.sortOrder.trim() !== '' && { sort_order: Number(draft.sortOrder) }),
    ...(ctx.kind === 'SUBGROUP' && {
      default_priority: draft.priority,
      default_team: draft.team,
      business_type: draft.business,
      requires_student: draft.requiresStudent,
      requires_class: draft.requiresClass,
      ...(ctx.ticketType === 'GV' && { nature_code: draft.nature }),
    }),
  };
}
