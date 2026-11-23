// CS-07 «Phiếu chuyển cơ sở đến»: danh sách phiếu chờ quản lý cơ sở ĐÍCH (đến lượt) chọn lớp và duyệt. Chưa có khung riêng: dựng từ khuôn danh sách K03 (chờ Design xác nhận).
import { useNavigate } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import type { ListConfig, ListState } from '../../list/types';
import { errorOf } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useState } from 'react';
import type { DestinationRow } from './destinationTypes';
import { useDestinationList } from './useDestination';

const CONFIG: ListConfig<DestinationRow> = {
  screenCode: 'CS-07',
  title: 'Phiếu chuyển cơ sở đến',
  searchPlaceholder: 'Tìm mã phiếu hoặc học sinh…',
  columns: [
    {
      key: 'code',
      label: 'Mã phiếu',
      locked: true,
      primary: true,
      render: (r) => <span className="font-medium">{r.code}</span>,
    },
    { key: 'student', label: 'Học sinh', render: (r) => r.student_name ?? '—' },
    { key: 'from', label: 'Cơ sở đi', render: (r) => r.from_branch_code },
    { key: 'dest', label: 'Cơ sở mới', render: (r) => r.dest_branch_code },
    { key: 'ticket', label: 'Ticket gốc', render: (r) => r.ticket_code },
    { key: 'created', label: 'Ngày tạo', render: (r) => formatDateTime(r.created_at) },
  ],
  quickGroups: [],
  filterFields: [],
  groupFields: [],
  dateFields: [],
  views: ['list'],
};
const EMPTY: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export function TaskDestinationListPage() {
  const navigate = useNavigate();
  const [state, setState] = useState<ListState>(EMPTY);
  const list = useDestinationList();
  const q = state.search.trim().toLowerCase();
  // Danh sách do máy chủ giới hạn số dòng (tối đa một trang); tìm nhanh trên các dòng đã tải.
  const rows = (list.data ?? []).filter(
    (r) =>
      q === '' ||
      r.code.toLowerCase().includes(q) ||
      (r.student_name ?? '').toLowerCase().includes(q) ||
      r.ticket_code.toLowerCase().includes(q),
  );
  return (
    <ListScreen
      config={CONFIG}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.code} ${r.student_name ?? ''}`}
      onRowClick={(r) => void navigate(`/crm/phieu-chuyen-co-so-den/${r.id}`)}
      loading={list.isPending}
      error={list.isError ? errorOf(list.error).message : null}
      onRetry={() => void list.refetch()}
      onRefresh={() => void list.refetch()}
      pager={{ from: rows.length === 0 ? 0 : 1, to: rows.length, total: rows.length }}
      emptyMessage={{
        title: 'Chưa có phiếu chuyển cơ sở nào chờ bạn',
        hint: 'Phiếu hiện ở đây khi quản lý cơ sở đi đã duyệt và đến lượt cơ sở của bạn chọn lớp mới.',
      }}
    />
  );
}
