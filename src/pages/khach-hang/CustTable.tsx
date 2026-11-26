// Bảng trong tab của hồ sơ phụ huynh (KH-02) và học sinh (KH-05): luôn hiện đủ cột theo khung, kể cả khi trống hoặc không có quyền.
import type { ReactNode } from 'react';
import { Table, type Column } from '../../ui/Data';

export function CustTable<Row>({
  caption,
  columns,
  rows,
  rowKey,
  empty,
  loading = false,
}: {
  caption: string;
  columns: Column<Row>[];
  rows: Row[];
  rowKey: (row: Row) => string;
  /** Câu trạng thái khi không có dòng nào ("Chưa có …", "Bạn không có quyền xem …"). */
  empty: ReactNode;
  loading?: boolean | undefined;
}) {
  return (
    <Table
      caption={caption}
      columns={columns}
      rows={rows}
      rowKey={rowKey}
      rowLabel={rowKey}
      loading={loading}
      keepHeader
      scrollFocusable
      empty={<p className="px-4 py-3 text-fg-muted">{empty}</p>}
    />
  );
}

/** Khối có tiêu đề bọc một bảng (không dùng DetailSection vì khối đó là danh sách nhãn và giá trị). */
export function CustSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="flex min-w-0 flex-col">
      <h2 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
        {title}
      </h2>
      {children}
    </section>
  );
}
