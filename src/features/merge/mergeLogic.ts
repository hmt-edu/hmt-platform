// Phần thuần của hộp Gộp trùng (TS-10): chọn bản giữ lại, câu mô tả, số mục còn lại không liệt kê hết.
import type { MergeEntity } from './mergeApi';

export type KeepSide = 'current' | 'other';

/** Hồ sơ nào giữ lại, hồ sơ nào gộp vào (hồ sơ đang mở luôn nằm bên trái của hộp). */
export function keepAndMerge(
  keepSide: KeepSide,
  currentId: string,
  otherId: string | null,
): { keepId: string | null; mergeId: string | null } {
  if (otherId === null) return { keepId: null, mergeId: null };
  return keepSide === 'current'
    ? { keepId: currentId, mergeId: otherId }
    : { keepId: otherId, mergeId: currentId };
}

const NOUN: Record<MergeEntity, string> = {
  LEAD: 'lead',
  OPPORTUNITY: 'cơ hội',
  PARENT: 'phụ huynh',
  STUDENT: 'học sinh',
};

export function entityNoun(entity: MergeEntity): string {
  return NOUN[entity];
}

/** Tiêu đề hộp: "Gộp lead trùng", "Gộp phụ huynh trùng"… */
export function dialogTitle(entity: MergeEntity): string {
  return `Gộp ${NOUN[entity]} trùng`;
}

const MOVE_LABEL: Record<string, string> = {
  leads: 'Lead',
  opportunities: 'Cơ hội',
  students: 'Học sinh',
  quotations: 'Báo giá',
  orders: 'Đơn hàng',
  receipts: 'Phiếu thu',
  enrollments: 'Ghi danh',
  attendance: 'Dòng điểm danh',
  balance_entries: 'Dòng số dư khách hàng',
  tests: 'Phiếu Test',
  notes: 'Ghi chú',
};

/** Nhóm dữ liệu sẽ chuyển sang bản giữ lại (chỉ nhóm có dòng), theo thứ tự cố định: dùng cho phụ huynh, học sinh. */
export function moveLines(move: Record<string, number>): { label: string; count: number }[] {
  return Object.keys(MOVE_LABEL)
    .filter((k) => (move[k] ?? 0) > 0)
    .map((k) => ({ label: MOVE_LABEL[k] ?? k, count: move[k] ?? 0 }));
}

/** Câu dưới tiêu đề: lead trùng khi cùng SĐT, cơ hội trùng khi cùng phụ huynh (hàm gợi ý của cơ sở dữ liệu). */
export function matchSentence(
  entity: MergeEntity,
  phoneLabel: string,
  hasCandidate = true,
): string {
  const noun = entityNoun(entity);
  // Chưa có bản trùng gợi ý thì không khẳng định «hai bản cùng SĐT» (câu sai khi người dùng tự tìm bản để gộp).
  if (!hasCandidate) {
    return `Tìm bản ${noun} muốn gộp với bản này. Chọn bản giữ lại; dữ liệu của bản kia chuyển sang bản giữ lại.`;
  }
  if (entity === 'PARENT') {
    return `Hai phụ huynh cùng SĐT ${phoneLabel}. Chọn bản giữ lại; mọi dữ liệu (lead, cơ hội, học sinh, đơn, phiếu thu, số dư, ghi danh, ghi chú) của bản kia chuyển sang bản giữ lại.`;
  }
  if (entity === 'STUDENT') {
    return `Hai học sinh cùng phụ huynh (SĐT ${phoneLabel}). Chọn bản giữ lại; mọi dữ liệu (ghi danh, điểm danh, phiếu Test, số dư, ghi chú) của bản kia chuyển sang bản giữ lại.`;
  }
  const why = entity === 'LEAD' ? `cùng SĐT ${phoneLabel}` : `cùng phụ huynh (SĐT ${phoneLabel})`;
  return `Hai ${noun} ${why}. Chọn bản giữ lại; lịch hẹn và ghi chú của bản kia chuyển sang bản giữ lại.`;
}

/** "và 3 mục nữa" khi danh sách liệt kê ít hơn số thật (hạn mức hiện của cơ sở dữ liệu). */
export function moreItems(total: number, shown: number): string | null {
  const rest = total - shown;
  return rest > 0 ? `và ${rest} mục nữa` : null;
}

/** Ghi chú cuối hộp, nêu rõ điều gì xảy ra với hai bản. */
export function afterMergeNote(keepCode: string, mergeCode: string): string {
  return `Thông tin của ${keepCode} được giữ nguyên. ${mergeCode} chuyển sang trạng thái “Đã gộp”: chỉ đọc, có dòng “Đã gộp vào ${keepCode}”, ẩn khỏi danh sách mặc định, vẫn tìm được bằng mã. Việc gộp ghi vào lịch sử của cả hai bản.`;
}
