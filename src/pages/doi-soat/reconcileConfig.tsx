// Cấu hình màn TC-15 Đối soát thu tiền (khuôn K03/K09): cột theo canvas 9933 khung TC15. Lọc, tìm, sắp xếp, phân trang ở máy chủ.
import { Link } from 'react-router';
import { formatDate, formatNumber } from '../../lib/format';
import type { ListConfig } from '../../list/types';
import { Tag } from '../../ui/Data';
import { NO_ACCOUNT, type ReconcileRow } from './reconcile';

export const RECONCILE_SCREEN_CODE = 'TC-15';

type Option = { value: string; label: string };

export function buildReconcileConfig(opts: {
  branches: Option[];
  methods: Option[];
  accounts: Option[];
  methodName: (code: string) => string;
  accountName: (code: string | null) => string;
}): ListConfig<ReconcileRow> {
  return {
    screenCode: RECONCILE_SCREEN_CODE,
    title: 'Đối soát thu tiền',
    searchPlaceholder: 'Tìm mã giao dịch hoặc mã phiếu thu…',
    columns: [
      {
        key: 'paid',
        label: 'Ngày',
        sortable: true,
        render: (r) => <span className="tabular">{formatDate(r.paid_on)}</span>,
      },
      {
        key: 'code',
        label: 'Phiếu thu',
        locked: true,
        primary: true,
        render: (r) => (
          <Link to={`/crm/phieu-thu/${r.id}`} className="font-medium text-link hover:underline">
            {r.code}
          </Link>
        ),
      },
      { key: 'branch', label: 'Cơ sở thu', render: (r) => r.collect_branch_code },
      { key: 'receiver', label: 'Người nhận tiền', render: (r) => r.receiver_name ?? '—' },
      { key: 'parent', label: 'Phụ huynh', render: (r) => r.parent_name ?? '—' },
      { key: 'method', label: 'Hình thức', render: (r) => opts.methodName(r.payment_method_code) },
      {
        key: 'account',
        label: 'Tài khoản nhận',
        render: (r) => opts.accountName(r.receiving_account_code),
      },
      { key: 'txn', label: 'Mã giao dịch', render: (r) => r.txn_ref ?? '—' },
      {
        key: 'amount',
        label: 'Số tiền (đ)',
        numeric: true,
        sortable: true,
        render: (r) => <span className="tabular">{formatNumber(r.amount)}</span>,
      },
      {
        key: 'matched',
        label: 'Sao kê',
        render: (r) => (
          <Tag tone={r.matched ? 'success' : 'warning'}>{r.matched ? 'Đã khớp' : 'Chưa khớp'}</Tag>
        ),
      },
    ],
    quickGroups: [
      {
        key: 'matched',
        label: 'Sao kê',
        options: [
          { value: 'KHOP', label: 'Đã khớp' },
          { value: 'CHUA', label: 'Chưa khớp' },
        ],
      },
      { key: 'method', label: 'Hình thức', options: opts.methods },
      {
        key: 'account',
        label: 'Tài khoản nhận',
        options: [...opts.accounts, { value: NO_ACCOUNT, label: 'Chưa ghi tài khoản' }],
      },
    ],
    filterFields: [
      { key: 'branch', label: 'Cơ sở', type: 'select', ops: ['eq'], options: opts.branches },
    ],
    groupFields: [],
    dateFields: [{ key: 'paid', label: 'Thời gian' }],
    views: ['list'],
  };
}
