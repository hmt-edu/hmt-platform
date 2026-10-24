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

export function entityNoun(entity: MergeEntity): string {
  return entity === 'LEAD' ? 'lead' : 'cơ hội';
}

/** Câu dưới tiêu đề: lead trùng khi cùng SĐT, cơ hội trùng khi cùng phụ huynh (hàm gợi ý của cơ sở dữ liệu). */
export function matchSentence(entity: MergeEntity, phoneLabel: string): string {
  const noun = entityNoun(entity);
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
