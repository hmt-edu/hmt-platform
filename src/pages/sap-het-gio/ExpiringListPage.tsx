// GD-07 Sắp hết giờ (danh sách dự báo chỉ đọc) theo khuôn K03 (canvas 9933 GD07): thanh công cụ Filters, lọc nhanh Tình trạng, tìm, làm mới, cột chọn được,
// phân trang «1–n / tổng». ĐỀ XUẤT docs/spec/de-xuat-luat-a.md: mỗi dòng một (học sinh, lớp); giờ còn, hết giờ dự kiến, hạn gói (dự báo, R-GD-07: không chặn gì),
// tình trạng gợi ý. Không sinh phiếu tái tục (R-V2-25), không có nút tạo tay (R-TIEN-02). Phân hệ SAP_HET_GIO tắt mặc định (cờ theo cơ sở).
// Máy chủ quyết quyền, cờ và tính toán (app.list_expiring_enrollments); phân trang ở máy chủ. Cột «Phiếu tái tục» (canvas GD07, F51) lấy mã phiếu đang mở do máy chủ trả (migration 561).
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
  expiringIntro,
  noUpsaleText,
  EXPIRING_GROUP_FIELD_OF,
  expiringGroupFilter,
} from './expiringLogic';
import { useExpiringGroupCounts, useExpiringPage } from './useExpiringData';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { useToast } from '../../ui/toastContext';
import { formatDate } from '../../lib/format';
import { vnToday } from '../../list/calendarLogic';

const STATUS_OPTIONS: { value: ExpiringStatus; label: string }[] = [
  { value: 'SAP_HET_GIO', label: statusName('SAP_HET_GIO') },
  { value: 'HET_GIO', label: statusName('HET_GIO') },
  { value: 'SAP_HET_HAN_GOI', label: statusName('SAP_HET_HAN_GOI') },
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
    {
      key: 'upsale',
      label: 'Phiếu tái tục',
      render: (r) =>
        r.upsale_id && r.upsale_code ? (
          <Link className="text-link hover:underline" to={`/crm/tai-tuc/${r.upsale_id}`}>
            {r.upsale_code}
          </Link>
        ) : (
          <span className="text-fg-muted">{noUpsaleText(r.status_code)}</span>
        ),
    },
  ],
  quickGroups: [{ key: 'status', label: 'Tình trạng', options: STATUS_OPTIONS }],
  filterFields: [],
  // Canvas GD07: nhóm Tình trạng (máy chủ đếm, migration 614).
  groupFields: [{ key: 'status', label: 'Tình trạng', value: (r) => r.status_code }],
  dateFields: [],
  views: ['list'],
};

export function ExpiringListPage() {
  const pageSize = useIntSetting('list_page_size_default');
  const hoursThreshold = useIntSetting('upsale_hours_left_threshold');
  const daysThreshold = useIntSetting('upsale_days_left_threshold');
  const [state, setState] = useState<ListState>(EMPTY_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const search = useDebounced(state.search).trim();
  const status = state.quick.status ?? [];
  const statusKey = status.join(',');
  const pagingKey = `${search}|${statusKey}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  // Group By ở máy chủ: số đếm từ expiring_group_counts, dòng tải khi mở nhóm lá (list_expiring_enrollments).
  const toast = useToast();
  const groupFields = state.group.flatMap((k) =>
    EXPIRING_GROUP_FIELD_OF[k] ? [EXPIRING_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const filters = useMemo(
    () => ({ status: status.length > 0 ? status : null, search }),
    // statusKey đổi khi bộ lọc nhanh đổi.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [statusKey, search],
  );
  const list = useExpiringPage(filters.status, search, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useExpiringGroupCounts(filters, groupFields);
  const leaves = useLeafRows<ExpiringRow>(
    filters,
    null,
    pageSize,
    `${pagingKey}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_expiring_enrollments',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<ExpiringRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            expiringGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const query = grouped ? counts : list;
  const rows = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
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
      onRefresh={() => {
        setTick((t) => t + 1);
        void query.refetch();
      }}
      groupTree={grouping?.tree}
      onGroupToggle={(key, open) => {
        const spec = grouping?.specs.get(key);
        if (spec) leaves.toggle(key, spec.filters, open);
      }}
      pager={
        grouped
          ? undefined
          : {
              from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
              to: page * (pageSize ?? 0) + rows.length,
              total,
              ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
              ...(page * (pageSize ?? 0) + rows.length < total
                ? { onNext: () => setPage(page + 1) }
                : {}),
            }
      }
      belowToolbar={
        <p className="px-4 pt-2 text-caption text-fg-muted">
          {expiringIntro(hoursThreshold, daysThreshold, formatDate(vnToday()))}
        </p>
      }
      sort={null}
      onSortChange={() => undefined}
      emptyMessage={{
        title: 'Chưa có học sinh sắp hết giờ',
        hint: 'Dự báo theo từng ghi danh (từng lớp). Hạn gói chỉ để dự báo: quá hạn gói mà còn giờ vẫn học.',
      }}
    />
  );
}
