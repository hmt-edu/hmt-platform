// Time Table theo thứ, dùng chung cho LOP-02 bản ghi lớp (chỉ đọc) và LOP-03 tạo, sửa lớp (ô sửa trong dòng): hàng tab Thứ 2 … Chủ nhật kèm số khung,
// mỗi tab một bảng cùng cột. Anh Trường chốt 28/11/2026: màn tạo, sửa giống bản ghi (thay 7 khối xếp dọc ở khung LOP03_*).
import type { ReactNode } from 'react';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Tabs } from '../../ui/Overlays';
import { WEEKDAY_LABEL } from './classLabels';

const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7];

export type TimeTableCells<Row> = Record<
  'time' | 'teacher' | 'assistant' | 'room' | 'repeat' | 'first',
  (row: Row) => ReactNode
>;

const HEADERS: { key: keyof TimeTableCells<unknown>; header: string }[] = [
  { key: 'time', header: 'Giờ' },
  { key: 'teacher', header: 'Giáo viên' },
  { key: 'assistant', header: 'Trợ giảng' },
  { key: 'room', header: 'Phòng' },
  { key: 'repeat', header: 'Cách lặp' },
  { key: 'first', header: 'Buổi đầu tiên' },
];

export function ClassTimeTable<Row extends { weekday: number }>({
  rows,
  day,
  onDayChange,
  rowKey,
  cells,
  action,
  below,
  errorCount,
  footer,
}: {
  rows: Row[];
  day: string;
  onDayChange: (day: string) => void;
  rowKey: (row: Row) => string;
  cells: TimeTableCells<Row>;
  /** Cột nút cuối dòng (xoá dòng) khi đang sửa. */
  action?: ((row: Row) => ReactNode) | undefined;
  /** Hàng phụ dưới dòng: lỗi, cảnh báo. */
  below?: ((row: Row) => ReactNode) | undefined;
  /** Số dòng lỗi của một thứ, ghi ngay trên tab để không bị khuất. */
  errorCount?: ((weekday: number) => number) | undefined;
  /** Dưới bảng của thứ đang chọn (nút thêm khung giờ). */
  footer?: ((weekday: number) => ReactNode) | undefined;
}) {
  const columns: LineColumn<Row>[] = HEADERS.map((h) => ({
    key: h.key,
    header: h.header,
    cell: cells[h.key],
  }));
  if (action) columns.push({ key: 'action', header: '', headerSrOnly: 'Xoá', cell: action });

  return (
    <Tabs
      label="Time Table theo thứ"
      value={day}
      onChange={onDayChange}
      items={WEEKDAYS.map((weekday) => {
        const name = WEEKDAY_LABEL[weekday] ?? '';
        const own = rows.filter((x) => x.weekday === weekday);
        const bad = errorCount?.(weekday) ?? 0;
        return {
          value: String(weekday),
          label: bad > 0 ? `${name} · ${bad} lỗi` : name,
          count: own.length > 0 ? own.length : undefined,
          content: (
            <div className="flex flex-col items-start gap-2">
              {own.length === 0 ? (
                <p className="py-2 text-fg-muted">{name} không có khung giờ.</p>
              ) : (
                <div className="w-full min-w-0">
                  <LineTable
                    caption={`Khung giờ ${name}`}
                    rows={own}
                    rowKey={rowKey}
                    columns={columns}
                    below={below}
                    // Bảng chỉ đọc không có ô nào bấm được: vùng cuộn phải nhận bàn phím.
                    scrollFocusable={!action}
                  />
                </div>
              )}
              {footer?.(weekday)}
            </div>
          ),
        };
      })}
    />
  );
}
