// GD-07 Sắp hết giờ (danh sách dự báo chỉ đọc) theo khuôn K03 (canvas 9933 GD07): thanh công cụ Filters, lọc nhanh Tình trạng, tìm, làm mới, cột chọn được,
// phân trang «1–n / tổng». ĐỀ XUẤT docs/spec/de-xuat-luat-a.md: mỗi dòng một (học sinh, lớp); giờ còn, hết giờ dự kiến, hạn gói (dự báo, R-GD-07: không chặn gì),
// tình trạng gợi ý. Không sinh phiếu tái tục (R-V2-25), không có nút tạo tay (R-TIEN-02). Phân hệ SAP_HET_GIO tắt mặc định (cờ theo cơ sở).
// Máy chủ quyết quyền, cờ và tính toán (app.list_expiring_enrollments); phân trang ở máy chủ. Cột «Phiếu tái tục» của canvas chờ máy chủ trả mã phiếu (đề xuất riêng).
import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import type { ListConfig, ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { Tag } from '../../ui/Data';
import { StateView } from '../../ui/Feedback';
import {
  dateText,
  hoursText,
  statusName,
  statusTone,
  type ExpiringRow,
  type ExpiringStatus,
} from './expiringLogic';
import { useExpiringPage } from './useExpiringData';

const STATUS_OPTIONS: { value: ExpiringStatus; label: string }[] = [
  { value: 'SAP_HET_GIO', label: statusName('SAP_HET_GIO') },
  { value: 'HET_GIO', label: statusName('HET_GIO') },
  { value: 'QUA_HAN_CON_GIO', label: statusName('QUA_HAN_CON_GIO') },
];

const EMPTY_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

const CONFIG: ListConfig<ExpiringRow> = {
  screenCode: 'GD-07',
  title: 'Sắp hết giờ',
  searchPlaceholder: 'Tìm tên học sinh hoặc mã lớp',
  columns: [
    {
      key: 'student',
      label: 'Học sinh',
      locked: true,
      primary: true,
      render: (r) => <span className="font-medium">{r.student_name}</span>,
    },
    {
      key: 'class',
      label: 'Lớp',
      render: (r) => (
        <Link className="text-link hover:underline" to={`/crm/lop/${r.class_id}`}>
          {r.class_code}
        </Link>
      ),
    },
    {
      key: 'enrollments',
      label: 'Ghi danh',
      render: (r) => r.enrollment_codes.join(', '),
    },
    { key: 'hours', label: 'Giờ còn', numeric: true, render: (r) => hoursText(r.hours_left) },
    {
      key: 'end',
      label: 'Hết giờ dự kiến',
      render: (r) => <span className="tabular">{dateText(r.projected_end)}</span>,
    },
    {
      key: 'validity',
      label: 'Hạn gói (dự báo)',
      render: (r) => <span className="tabular">{dateText(r.validity_date)}</span>,
    },
    {
      key: 'status',
      label: 'Tình trạng',
      render: (r) => <Tag tone={statusTone(r.status_code)}>{statusName(r.status_code)}</Tag>,
    },
  ],
  quickGroups: [{ key: 'status', label: 'Tình trạng', options: STATUS_OPTIONS }],
  filterFields: [],
  groupFields: [],
  dateFields: [],
  views: ['list'],
};

export function ExpiringListPage() {
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const search = useDebounced(state.search).trim();
  const status = state.quick.status ?? [];
  const statusKey = status.join(',');
  const pagingKey = `${search}|${statusKey}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const query = useExpiringPage(
    status.length > 0 ? status : null,
    search,
    page * (pageSize ?? 0),
    pageSize,
  );
  const rows = query.data?.rows ?? [];
  const total = query.data?.total ?? 0;
  const config = useMemo(() => CONFIG, []);

  // Phân hệ chưa bật ở cơ sở này: câu riêng, không phải lỗi chung.
  if (query.isError && errorOf(query.error).code === 'HMT_TINH_NANG_TAT') {
    return (
      <StateView kind="forbidden" title="Phân hệ chưa bật" headingLevel={2}>
        {errorOf(query.error).message}
      </StateView>
    );
  }

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={(r) => `${r.student_id}:${r.class_id}`}
      rowLabel={(r) => `${r.student_name} · ${r.class_code}`}
      loading={query.isPending || query.isPlaceholderData}
      error={query.isError ? errorOf(query.error).message : null}
      onRetry={() => void query.refetch()}
      actions={[]}
      onRefresh={() => void query.refetch()}
      pager={{
        from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
        to: page * (pageSize ?? 0) + rows.length,
        total,
        ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
        ...(page * (pageSize ?? 0) + rows.length < total
          ? { onNext: () => setPage(page + 1) }
          : {}),
      }}
      sort={null}
      onSortChange={() => undefined}
      emptyMessage={{
        title: 'Chưa có học sinh sắp hết giờ',
        hint: 'Không có học sinh nào khớp bộ lọc này.',
      }}
    />
  );
}
