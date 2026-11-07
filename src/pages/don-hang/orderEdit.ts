// Phần thuần của chế độ sửa đơn Nháp (UI-O3, anh chốt 06/11): nháp sửa từng dòng, so với bản ghi để chỉ gửi phần đổi, tóm tắt chính sách chiết khấu.
// Giao diện KHÔNG tính tiền (R-TIEN-13): thành tiền, % tổng, trần do máy chủ tính lại ở app.edit_order.
import type { OrderLine, OrderLineDiscount, OrderRecord } from './orderTypes';

/** Một chính sách chiết khấu đang chọn trên dòng: giá trị chỉ nhập với chính sách không cố định (% hoặc giờ tặng). */
export type DraftDiscount = { policy_id: string; value: number | null };

export type LineDraft = {
  quantity: number | null;
  mode: string;
  discounts: DraftDiscount[];
  removed: boolean;
};

export type OrderDraft = { termId: string; lines: Record<number, LineDraft> };

/** Nháp ban đầu lấy từ bản ghi: số giờ, hình thức, chính sách hiện có (chính sách cố định không giữ giá trị). */
export function draftOf(
  record: Pick<OrderRecord, 'lines'>,
  termId: string,
  fixedPolicyIds: ReadonlySet<string>,
): OrderDraft {
  const lines: Record<number, LineDraft> = {};
  for (const l of record.lines) {
    lines[l.line_no] = {
      quantity: l.quantity,
      mode: l.delivery_mode_code,
      discounts: l.discounts.map((d) => ({
        policy_id: d.policy_id,
        value: fixedPolicyIds.has(d.policy_id) ? null : d.applied_value,
      })),
      removed: false,
    };
  }
  return { termId, lines };
}

export type LineEdit = {
  line_no: number;
  quantity?: number;
  delivery_mode_code?: string;
  discounts?: DraftDiscount[];
  remove?: boolean;
};

const sameDiscounts = (a: DraftDiscount[], b: OrderLineDiscount[], fixed: ReadonlySet<string>) =>
  a.length === b.length &&
  a.every((x) => {
    const old = b.find((d) => d.policy_id === x.policy_id);
    return old !== undefined && (fixed.has(x.policy_id) || x.value === old.applied_value);
  });

/** Chỉ các dòng có thay đổi so với bản ghi (số giờ, hình thức, chính sách, bỏ dòng); dòng quà tặng chỉ bỏ được. */
export function buildEdits(
  lines: OrderLine[],
  draft: OrderDraft,
  fixedPolicyIds: ReadonlySet<string>,
): LineEdit[] {
  const edits: LineEdit[] = [];
  for (const l of lines) {
    const d = draft.lines[l.line_no];
    if (!d) continue;
    if (d.removed) {
      edits.push({ line_no: l.line_no, remove: true });
      continue;
    }
    if (l.line_kind === 'GIFT') continue;
    const edit: LineEdit = { line_no: l.line_no };
    if (d.quantity !== null && d.quantity !== l.quantity) edit.quantity = d.quantity;
    if (d.mode !== l.delivery_mode_code) edit.delivery_mode_code = d.mode;
    if (!sameDiscounts(d.discounts, l.discounts, fixedPolicyIds)) edit.discounts = d.discounts;
    if (Object.keys(edit).length > 1) edits.push(edit);
  }
  return edits;
}

/** Có thay đổi chưa lưu: điều khoản khác ban đầu, hoặc ít nhất một dòng bị sửa. */
export function hasChanges(
  lines: OrderLine[],
  draft: OrderDraft,
  initialTermId: string,
  fixedPolicyIds: ReadonlySet<string>,
): boolean {
  return draft.termId !== initialTermId || buildEdits(lines, draft, fixedPolicyIds).length > 0;
}

/** Lỗi nhập tại chỗ (null là hợp lệ): số giờ phải lớn hơn 0; không bỏ hết dòng. */
export function lineError(draft: LineDraft): string | null {
  if (draft.removed) return null;
  return draft.quantity === null || draft.quantity <= 0 ? 'Nhập số lượng lớn hơn 0.' : null;
}

export function allRemoved(draft: OrderDraft): boolean {
  const all = Object.values(draft.lines);
  return all.length > 0 && all.every((l) => l.removed);
}
