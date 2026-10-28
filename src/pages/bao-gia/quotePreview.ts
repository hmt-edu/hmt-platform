// Chọn dòng đủ điều kiện để xem thử giá và đổi kết quả của app.preview_quotation_lines về từng dòng đang sửa. Giao diện KHÔNG tính gì:
// chỉ gửi dòng, nhận số. Hàm thuần, có kiểm thử.
import { buildSaveLines, parseQuantity, type EditRow } from './quoteEdit';

/** Kết quả hiện trên một dòng. */
export type RowCalc =
  | {
      status: 'ok';
      unitPrice: number;
      discountAmount: number;
      lineTotal: number;
      /** Tổng chiết khấu quy ra % (chiết khấu và giờ tặng) do máy chủ trả. */
      totalPercent: number;
      overCap: boolean;
    }
  | { status: 'error'; message: string }
  | { status: 'pending' }
  /** Chưa chọn em: chưa tính giá (hệ thống báo HMT_DONG_THIEU như khi lưu). */
  | { status: 'needs-student' }
  /** Chưa đủ gói, hình thức, số lượng. */
  | { status: 'incomplete' };

/** Dòng gói đã đủ gói, hình thức, số lượng (chưa kể em). */
export function isComplete(row: EditRow): boolean {
  return (
    row.kind === 'ENROL' &&
    row.packageId !== '' &&
    row.mode !== '' &&
    parseQuantity(row.quantity) !== null &&
    row.discounts.every((d) => d.value.trim() === '' || parseQuantity(d.value) !== null)
  );
}

/** Trạng thái ban đầu của dòng chưa gửi đi xem thử. */
export function waitingStatus(row: EditRow): RowCalc {
  if (row.kind !== 'ENROL' || !isComplete(row)) return { status: 'incomplete' };
  return row.studentId === '' ? { status: 'needs-student' } : { status: 'pending' };
}

/** Dòng gửi xem thử: chỉ dòng đã đủ em, gói, hình thức, số lượng (dòng quà chưa gửi ở bản này). */
export function previewCandidates(
  rows: EditRow[],
): { rowKey: string; line: Record<string, unknown> }[] {
  const lines = buildSaveLines(rows);
  const out: { rowKey: string; line: Record<string, unknown> }[] = [];
  rows.forEach((row, i) => {
    const line = lines[i];
    if (line && isComplete(row) && row.studentId !== '') out.push({ rowKey: row.key, line });
  });
  return out;
}

/** Số dòng nêu trong câu lỗi của máy chủ ("Dòng 2: …"); không có thì null. */
export function errorLineNo(message: string): number | null {
  const m = /^Dòng (\d+)\b/.exec(message);
  return m ? Number(m[1]) : null;
}

/** Đổi số dòng trong câu lỗi (số thứ tự trong lần xem thử) về số dòng thật trên màn. */
export function remapLineNo(message: string, realLineNo: number): string {
  return message.replace(/^Dòng \d+/, `Dòng ${String(realLineNo)}`);
}

/** Số thập phân kiểu Việt: 23,3 */
export function percentText(value: number): string {
  return String(value).replace('.', ',');
}
