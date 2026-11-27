// TC-14 Số dư khách hàng (xem lịch sử): số dư hiện tại và sổ các dòng của một phụ huynh, mới nhất trước. Chỉ xem; số do máy chủ trả.
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf } from '../../lib/db';
import { formatDate, formatMoney, formatNumber } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Table } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { BALANCE_ENTRY_NAME, type BalanceHistory } from './balanceTypes';
import { useBalanceHistory } from './useBalanceData';

export function BalanceHistoryPage() {
  const { parentId } = useParams<{ parentId: string }>();
  const query = useBalanceHistory(parentId);
  if (query.isPending) return <Spinner label="Đang tải lịch sử số dư…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem số dư này'
            : missing
              ? 'Không tìm thấy phụ huynh'
              : 'Không tải được lịch sử số dư'
        }
        actions={
          <>
            {/* duong-dan-menu: không tải được bản ghi, về danh sách chung */}
            <Link to="/crm/so-du-khach-hang" className="font-medium text-link hover:underline">
              Về danh sách Số dư khách hàng
            </Link>
            {!forbidden && !missing && (
              <Button onClick={() => void query.refetch()}>Thử lại</Button>
            )}
          </>
        }
      >
        {errorOf(error).message}
      </StateView>
    );
  }
  return <History data={query.data} />;
}

function History({ data }: { data: BalanceHistory }) {
  useCrumbTail(data.parent.name);
  return (
    <div className="flex flex-col gap-4">
      {/* duong-dan-menu: nút về danh sách */}
      <Link to="/crm/so-du-khach-hang" className="font-medium text-link hover:underline">
        ‹ Số dư khách hàng
      </Link>
      <h1 className="text-h2">{data.parent.name}</h1>
      <p className="text-body text-fg-muted">
        {data.parent.code} · {data.parent.branch_code}
      </p>
      <p className="text-body">
        Số dư hiện tại: <b className="tabular">{formatMoney(data.balance)}</b>
      </p>
      <Table
        caption="Lịch sử sổ số dư"
        rows={data.entries}
        rowKey={(e) => e.id}
        rowLabel={(e) => `${BALANCE_ENTRY_NAME[e.entry_type]} ${formatDate(e.entry_date)}`}
        empty="Chưa có dòng sổ nào."
        columns={[
          { key: 'date', header: 'Ngày', cell: (e) => formatDate(e.entry_date) },
          { key: 'type', header: 'Loại', cell: (e) => BALANCE_ENTRY_NAME[e.entry_type] },
          {
            key: 'amount',
            header: 'Số tiền (đ)',
            cell: (e) => <span className="tabular">{formatNumber(e.amount)}</span>,
          },
          { key: 'student', header: 'Học sinh', cell: (e) => e.student_name ?? '—' },
          { key: 'enrollment', header: 'Ghi danh', cell: (e) => e.enrollment_code ?? '—' },
          { key: 'note', header: 'Ghi chú', cell: (e) => e.note ?? e.source_ref ?? '—' },
        ]}
      />
    </div>
  );
}
