// Tab Đơn hàng, Phiếu thu, Tài chính của hồ sơ phụ huynh (khung KH02_don, KH02_phieu_thu, KH02_tai_chinh, canvas 9933).
// Dữ liệu lấy từ list_orders, list_receipts, enrollment_list lọc theo phụ huynh, phân trang ở máy chủ.
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Tag, type Column } from '../../ui/Data';
import type { OrderRow } from '../don-hang/orderTypes';
import { statusTone } from '../ghi-danh/enrollConfig';
import type { EnrollmentRow } from '../ghi-danh/enrollTypes';
import { RECEIPT_STATUS_TONE } from '../phieu-thu/receiptConfig';
import type { ReceiptRow } from '../phieu-thu/receiptTypes';
import { blankColumns, NO_VALUE } from './custColumns';
import { CustSection } from './CustTable';
import type { ParentRecord } from './custTypes';
import { PagedTable } from './PagedTable';

const link = (to: string, text: string) => (
  <Link to={to} className="font-medium text-link hover:underline">
    {text}
  </Link>
);
const orderLink = (r: ReceiptRow) =>
  r.order_id && r.order_code ? link(`/crm/don-hang/${r.order_id}`, r.order_code) : NO_VALUE;
const receiptStatus = (r: ReceiptRow) => (
  <Tag tone={RECEIPT_STATUS_TONE[r.status_code] ?? 'neutral'} dot>
    {r.status ?? r.status_code}
  </Tag>
);

const ORDER_COLUMNS: Column<OrderRow>[] = [
  { key: 'code', header: 'Mã', primary: true, cell: (o) => link(`/crm/don-hang/${o.id}`, o.code) },
  { key: 'student', header: 'Học sinh', cell: (o) => o.student_names.join(', ') || NO_VALUE },
  ...blankColumns<OrderRow>(['Lớp']),
  {
    key: 'total',
    header: 'Tổng tiền (đ)',
    numeric: true,
    cell: (o) => formatNumber(o.total_amount),
  },
  {
    key: 'paid',
    header: 'Đã đóng (đ)',
    numeric: true,
    cell: (o) => (o.paid_amount === undefined ? NO_VALUE : formatNumber(o.paid_amount)),
  },
  { key: 'status', header: 'Tình trạng', cell: (o) => <Tag>{o.status ?? o.status_code}</Tag> },
];

export function ParentOrdersTab({ record }: { record: ParentRecord }) {
  const allowed = useAccess().can('SALES_ORDER', 'XEM');
  return (
    <PagedTable
      caption="Đơn hàng"
      fn="list_orders"
      filters={{ parent_id: record.id }}
      sort="created_desc"
      columns={ORDER_COLUMNS}
      rowKey={(o) => o.id}
      allowed={allowed}
      empty="Chưa có đơn hàng."
      denied="Bạn không có quyền xem đơn hàng."
      total={record.counts.orders}
    />
  );
}

const RECEIPT_COLUMNS: Column<ReceiptRow>[] = [
  { key: 'code', header: 'Mã', primary: true, cell: (r) => link(`/crm/phieu-thu/${r.id}`, r.code) },
  { key: 'order', header: 'Đơn hàng', cell: orderLink },
  { key: 'amount', header: 'Số tiền (đ)', numeric: true, cell: (r) => formatNumber(r.amount) },
  { key: 'method', header: 'Hình thức', cell: (r) => r.payment_method ?? r.payment_method_code },
  { key: 'paid_on', header: 'Ngày nhận', cell: (r) => formatDate(r.paid_on) },
  { key: 'branch', header: 'Cơ sở thu', cell: (r) => r.collect_branch_code },
  { key: 'receiver', header: 'Người nhận tiền', cell: (r) => r.receiver_name ?? NO_VALUE },
  { key: 'status', header: 'Tình trạng', cell: receiptStatus },
];

export function ParentReceiptsTab({ record }: { record: ParentRecord }) {
  const allowed = useAccess().can('RECEIPT', 'XEM');
  return (
    <PagedTable
      caption="Phiếu thu"
      fn="list_receipts"
      filters={{ parent_id: record.id }}
      sort="created_desc"
      columns={RECEIPT_COLUMNS}
      rowKey={(r) => r.id}
      allowed={allowed}
      empty="Chưa có phiếu thu."
      denied="Bạn không có quyền xem phiếu thu."
      total={record.counts.receipts}
    />
  );
}

const ENROLLMENT_COLUMNS: Column<EnrollmentRow>[] = [
  {
    key: 'code',
    header: 'Ghi danh',
    primary: true,
    cell: (e) => link(`/crm/ghi-danh/${e.id}`, e.code),
  },
  { key: 'student', header: 'Học sinh', cell: (e) => e.student_name },
  { key: 'package', header: 'Gói', cell: (e) => e.package_name ?? NO_VALUE },
  { key: 'hours', header: 'Giờ', numeric: true, cell: (e) => formatNumber(e.granted_hours) },
  ...blankColumns<EnrollmentRow>(['Thành tiền'], ['Thành tiền']),
  {
    key: 'status',
    header: 'Trạng thái',
    cell: (e) => (
      <Tag tone={statusTone(e.status_code)} dot>
        {e.status_name}
      </Tag>
    ),
  },
];

const FINANCE_RECEIPT_COLUMNS: Column<ReceiptRow>[] = [
  {
    key: 'code',
    header: 'Mã phiếu',
    primary: true,
    cell: (r) => link(`/crm/phieu-thu/${r.id}`, r.code),
  },
  { key: 'paid_on', header: 'Ngày', cell: (r) => formatDate(r.paid_on) },
  { key: 'order', header: 'Về', cell: orderLink },
  { key: 'method', header: 'Hình thức', cell: (r) => r.payment_method ?? r.payment_method_code },
  { key: 'amount', header: 'Số tiền', numeric: true, cell: (r) => formatNumber(r.amount) },
  { key: 'receiver', header: 'Người thu', cell: (r) => r.receiver_name ?? NO_VALUE },
  { key: 'branch', header: 'Cơ sở', cell: (r) => r.collect_branch_code },
];

export function ParentFinanceTab({ record }: { record: ParentRecord }) {
  const access = useAccess();
  return (
    <div className="flex flex-col gap-3">
      <CustSection title="Đơn đăng ký và ghi danh">
        <PagedTable
          caption="Đơn đăng ký và ghi danh"
          fn="enrollment_list"
          filters={{ parent_id: record.id }}
          sort="code_desc"
          columns={ENROLLMENT_COLUMNS}
          rowKey={(e) => e.id}
          allowed={access.can('ENROLLMENT', 'XEM')}
          empty="Chưa có ghi danh."
          denied="Bạn không có quyền xem ghi danh."
          total={record.counts.enrollments}
        />
      </CustSection>
      <CustSection title="Phiếu thu">
        <PagedTable
          caption="Phiếu thu trong tài chính"
          fn="list_receipts"
          filters={{ parent_id: record.id }}
          sort="created_desc"
          columns={FINANCE_RECEIPT_COLUMNS}
          rowKey={(r) => r.id}
          allowed={access.can('RECEIPT', 'XEM')}
          empty="Chưa có phiếu thu."
          denied="Bạn không có quyền xem phiếu thu."
          total={record.counts.receipts}
        />
      </CustSection>
    </div>
  );
}
