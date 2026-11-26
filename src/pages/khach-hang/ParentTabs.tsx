// Tab Đơn hàng, Phiếu thu, Tài chính của hồ sơ phụ huynh (khung KH02_don, KH02_phieu_thu, KH02_tai_chinh_mo, canvas 9933).
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Tag, type Column } from '../../ui/Data';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { CustSection, CustTable } from './CustTable';
import { blankColumns, NO_VALUE } from './custColumns';
import type { ParentRecord } from './custTypes';

export function ParentOrdersTab({ record }: { record: ParentRecord }) {
  const allowed = useAccess().can('SALES_ORDER', 'XEM');
  const catalogs = useLeadCatalogs();
  type Row = ParentRecord['orders'][number];
  const columns: Column<Row>[] = [
    {
      key: 'code',
      header: 'Mã',
      primary: true,
      cell: (o) => (
        <Link to={`/crm/don-hang/${o.id}`} className="font-medium text-link hover:underline">
          {o.code}
        </Link>
      ),
    },
    ...blankColumns<Row>(['Học sinh', 'Lớp']),
    {
      key: 'total',
      header: 'Tổng tiền (đ)',
      numeric: true,
      cell: (o) => formatNumber(o.total_amount),
    },
    ...blankColumns<Row>(['Đã đóng (đ)'], ['Đã đóng (đ)']),
    {
      key: 'status',
      header: 'Tình trạng',
      cell: (o) => <Tag>{catalogs.name('ORDER_STATUS', o.status_code) ?? o.status_code}</Tag>,
    },
  ];
  return (
    <CustTable
      caption="Đơn hàng"
      columns={columns}
      rows={allowed ? record.orders : []}
      rowKey={(o) => o.id}
      empty={allowed ? 'Chưa có đơn hàng.' : 'Bạn không có quyền xem đơn hàng.'}
    />
  );
}

export function ParentReceiptsTab({ record }: { record: ParentRecord }) {
  const allowed = useAccess().can('RECEIPT', 'XEM');
  const catalogs = useLeadCatalogs();
  type Row = ParentRecord['receipts'][number];
  const columns: Column<Row>[] = [
    {
      key: 'code',
      header: 'Mã',
      primary: true,
      cell: (r) => (
        <Link to={`/crm/phieu-thu/${r.id}`} className="font-medium text-link hover:underline">
          {r.code}
        </Link>
      ),
    },
    ...blankColumns<Row>(['Đơn hàng']),
    { key: 'amount', header: 'Số tiền (đ)', numeric: true, cell: (r) => formatNumber(r.amount) },
    ...blankColumns<Row>(['Hình thức']),
    {
      key: 'paid_on',
      header: 'Ngày nhận',
      cell: (r) => (r.paid_on ? formatDate(r.paid_on) : NO_VALUE),
    },
    ...blankColumns<Row>(['Cơ sở thu', 'Người nhận tiền']),
    {
      key: 'status',
      header: 'Tình trạng',
      cell: (r) => <Tag>{catalogs.name('RECEIPT_STATUS', r.status_code) ?? r.status_code}</Tag>,
    },
  ];
  return (
    <CustTable
      caption="Phiếu thu"
      columns={columns}
      rows={allowed ? record.receipts : []}
      rowKey={(r) => r.id}
      empty={allowed ? 'Chưa có phiếu thu.' : 'Bạn không có quyền xem phiếu thu.'}
    />
  );
}

export function ParentFinanceTab() {
  return (
    <div className="flex flex-col gap-3">
      <CustSection title="Đơn đăng ký và ghi danh">
        <CustTable<never>
          caption="Đơn đăng ký và ghi danh"
          columns={blankColumns(
            ['Ghi danh', 'Học sinh', 'Gói', 'Giờ', 'Thành tiền', 'Trạng thái'],
            ['Giờ', 'Thành tiền'],
          )}
          rows={[]}
          rowKey={(r) => r}
          empty="Chưa có dữ liệu."
        />
      </CustSection>
      <CustSection title="Phiếu thu">
        <CustTable<never>
          caption="Phiếu thu trong tài chính"
          columns={blankColumns(
            ['Mã phiếu', 'Ngày', 'Về', 'Hình thức', 'Số tiền', 'Người thu', 'Cơ sở'],
            ['Số tiền'],
          )}
          rows={[]}
          rowKey={(r) => r}
          empty="Chưa có dữ liệu."
        />
      </CustSection>
    </div>
  );
}
