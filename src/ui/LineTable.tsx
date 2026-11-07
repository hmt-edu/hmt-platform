import { Fragment, type ReactNode } from 'react';
import { cn } from './cn';

/**
 * Bảng dòng dùng chung cho Báo giá và Đơn hàng (Q-72, Q-73): MỘT HÀNG MỘT DÒNG, chữ không xuống hàng,
 * cột không vừa thì cuộn ngang trong khung (không bẻ hàng, không thành thẻ, kể cả điện thoại).
 * Khớp khung canvas BH02_* (HMT Platform v146) và BH05_* (canvas bổ sung): bảng rộng theo nội dung, tối thiểu bằng khung.
 *
 * - Ô không bao giờ xuống hàng; cột nào có chữ dài thì đặt `truncate` (bề rộng tối đa, cắt bằng …) và `title`.
 * - `below` vẽ một hàng phụ ngay dưới dòng (lỗi, cảnh báo, ghi chú của dòng) trải hết bề ngang.
 * - Khung cuộn có `relative` để chữ sr-only không thoát ra ngoài vùng cuộn làm trang tràn ngang (nguyên nhân Đơn sửa 1280 tràn 90px).
 */
export type LineColumn<Row> = {
  key: string;
  header: ReactNode;
  /** Cột không có tiêu đề nhìn thấy (nút bỏ dòng): chỉ đọc cho trình đọc màn hình. */
  headerSrOnly?: string;
  align?: 'left' | 'right' | 'center';
  /** Bề rộng cố định của cột (lớp Tailwind, ví dụ 'w-24'). */
  width?: string;
  /** Cột cắt chữ dài: bề rộng tối đa của chữ (lớp Tailwind, ví dụ 'max-w-56'). */
  truncate?: string;
  /** Chữ đầy đủ của ô cắt (hiện khi rê chuột). */
  title?: (row: Row) => string;
  cell: (row: Row, index: number) => ReactNode;
};

const ALIGN = { left: 'text-left', right: 'text-right', center: 'text-center' } as const;

export function LineTable<Row>({
  caption,
  columns,
  rows,
  rowKey,
  rowClassName,
  below,
  scrollFocusable = false,
  empty,
}: {
  caption: string;
  columns: LineColumn<Row>[];
  rows: Row[];
  rowKey: (row: Row) => string;
  rowClassName?: ((row: Row) => string | undefined) | undefined;
  /** Hàng phụ dưới dòng; trả null thì không có hàng phụ. */
  below?: ((row: Row, index: number) => ReactNode) | undefined;
  /** Vùng cuộn nhận bàn phím (bảng chỉ đọc, không ô nào bấm được). */
  scrollFocusable?: boolean | undefined;
  empty?: ReactNode | undefined;
}) {
  if (rows.length === 0 && empty !== undefined) {
    return <div className="rounded-box border border-border bg-surface">{empty}</div>;
  }
  return (
    <div
      className="relative overflow-x-auto rounded-box border border-border bg-surface"
      {...(scrollFocusable ? { tabIndex: 0, role: 'region', 'aria-label': caption } : {})}
    >
      <table aria-label={caption} className="w-max min-w-full border-collapse text-body">
        <thead className="bg-surface-subtle text-caption font-semibold text-fg-label">
          <tr className="h-table-head">
            {columns.map((c) => (
              <th
                key={c.key}
                scope="col"
                className={cn(
                  'px-2.5 whitespace-nowrap first:pl-4 last:pr-4',
                  ALIGN[c.align ?? 'left'],
                  c.width,
                )}
              >
                {c.headerSrOnly ? <span className="sr-only">{c.headerSrOnly}</span> : c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => {
            const extra = below?.(row, index);
            return (
              <Fragment key={rowKey(row)}>
                <tr className={cn('border-t border-border', rowClassName?.(row))}>
                  {columns.map((c) => (
                    <td
                      key={c.key}
                      className={cn(
                        'px-2.5 py-2 align-middle whitespace-nowrap first:pl-4 last:pr-4',
                        ALIGN[c.align ?? 'left'],
                        c.width,
                      )}
                    >
                      {c.truncate ? (
                        <span
                          className={cn('block truncate', c.truncate)}
                          {...(c.title ? { title: c.title(row) } : {})}
                        >
                          {c.cell(row, index)}
                        </span>
                      ) : (
                        c.cell(row, index)
                      )}
                    </td>
                  ))}
                </tr>
                {extra ? (
                  <tr>
                    <td colSpan={columns.length} className="px-4 pt-0 pb-2 text-caption">
                      {extra}
                    </td>
                  </tr>
                ) : null}
              </Fragment>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
