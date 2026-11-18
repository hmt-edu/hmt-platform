// BH-08: lớp, ngày vào lớp chọn trong lúc Sửa đơn chỉ nằm ở bản đang sửa; lưu khi bấm Lưu đơn (khung BH08). Hàm thuần ghép với lớp đã lưu ở máy chủ để bảng dòng đơn hiện đúng.
import type { OrderLineClass } from '../ghi-danh/enrollTypes';

export type PendingClass = {
  /** null: bỏ chọn lớp (ghi danh sẽ chờ xếp lớp). */
  classId: string | null;
  date: string | null;
  classCode: string | null;
};

export function mergeLineClasses(
  saved: OrderLineClass[],
  pending: Record<number, PendingClass>,
): Record<number, OrderLineClass> {
  const out: Record<number, OrderLineClass> = Object.fromEntries(saved.map((c) => [c.line_no, c]));
  for (const [key, p] of Object.entries(pending)) {
    const lineNo = Number(key);
    if (p.classId === null) {
      delete out[lineNo];
    } else {
      out[lineNo] = {
        line_no: lineNo,
        class_id: p.classId,
        class_code: p.classCode ?? '',
        enrol_start_date: p.date ?? '',
      };
    }
  }
  return out;
}
