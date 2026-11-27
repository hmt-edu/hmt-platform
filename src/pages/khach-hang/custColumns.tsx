// Ô và cột chưa có dữ liệu của các bảng hồ sơ khách hàng.
import type { Column } from '../../ui/Data';

/** Ô chưa có dữ liệu: để trống bằng gạch, không điền chữ trông như giá trị thật. */
export const NO_VALUE = <span className="text-fg-muted">—</span>;

/** Cột chỉ có đầu cột: dữ liệu chưa có ở hàm đọc hiện tại. */
export function blankColumns<Row>(headers: string[], numeric: string[] = []): Column<Row>[] {
  return headers.map((header) => ({
    key: header,
    header,
    numeric: numeric.includes(header),
    cell: () => NO_VALUE,
  }));
}
