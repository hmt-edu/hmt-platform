// Hàm thuần của màn «Điểm danh»: khoảng ngày chọn nhanh, dựng cây nhóm từ số đếm của máy chủ, khoá chọn một dòng.
import { addDays } from '../lop/weekLogic';
import type { TableGroup } from '../../ui/Data';
import type { BoardRow, GroupCount } from './attendanceTypes';

export type RangePreset = 'today' | 'yesterday' | 'week';

export const PRESETS: { key: RangePreset; label: string }[] = [
  { key: 'today', label: 'Hôm nay' },
  { key: 'yesterday', label: 'Hôm qua' },
  { key: 'week', label: '7 ngày qua' },
];

export function presetRange(preset: RangePreset, today: string): { from: string; to: string } {
  if (preset === 'today') return { from: today, to: today };
  if (preset === 'yesterday') {
    const day = addDays(today, -1);
    return { from: day, to: day };
  }
  return { from: addDays(today, -6), to: today }; // allow-number: «7 ngày qua» gồm cả hôm nay
}

export const rowKey = (r: { session_id: string; student_id: string }) =>
  `${r.session_id}:${r.student_id}`;

/**
 * Cây nhóm của trang đang xem: máy chủ đã xếp dòng theo nhóm và trả số đếm của cả bộ lọc, ở đây chỉ gắn dòng của trang vào nhóm.
 * Nhóm không có dòng nào ở trang này thì không hiện.
 */
export function boardGroups(
  rows: BoardRow[],
  counts: GroupCount[],
  fields: string[],
  label: (field: string, key: string) => string,
): TableGroup<BoardRow>[] {
  const [f1, f2] = fields;
  if (!f1) return [];
  const total = (k1: string, k2?: string) =>
    counts
      .filter((c) => (c.k1 ?? '') === k1 && (k2 === undefined || (c.k2 ?? '') === k2))
      .reduce((sum, c) => sum + c.count, 0);
  const tree: TableGroup<BoardRow>[] = [];
  for (const row of rows) {
    const k1 = row.k1 ?? '';
    let top = tree.at(-1);
    const topKey = `g:${f1}=${k1}`;
    if (top?.key !== topKey) {
      top = { key: topKey, label: label(f1, k1), count: total(k1), children: [], rows: [] };
      tree.push(top);
    }
    if (!f2) {
      top.rows.push(row);
      continue;
    }
    const k2 = row.k2 ?? '';
    const subKey = `${topKey}/${f2}=${k2}`;
    let sub = top.children.at(-1);
    if (sub?.key !== subKey) {
      sub = { key: subKey, label: label(f2, k2), count: total(k1, k2), children: [], rows: [] };
      top.children.push(sub);
    }
    sub.rows.push(row);
  }
  return tree;
}

export const isMismatch = (r: BoardRow) =>
  r.ops_status_code !== null &&
  r.teacher_status_code !== null &&
  r.ops_status_code !== r.teacher_status_code;

/** Chữ trên bốn nút «Vận hành» (canvas): tên đầy đủ vẫn là nhãn đọc và chú giải của nút. */
export function shortStatus(code: string, name: string): string {
  const short: Record<string, string> = {
    CO_MAT: 'Có',
    DI_MUON: 'Muộn',
    VANG_CO_PHEP: 'VP',
    VANG_KHONG_PHEP: 'KP',
  };
  return short[code] ?? name;
}
