// TS-11 Lịch hẹn: danh sách (TS11b), Kanban (TS11c), Lịch ngày, tuần, tháng (TS11_K5) trên khuôn K1, K2, K5.
// Lọc, sắp xếp, phân trang, tìm kiếm làm ở máy chủ. Hoàn thành, Dời, Huỷ, Mở lại là thao tác một bấm hoặc một hộp thoại
// (R-CRM-04); không đổi giai đoạn, không tạo việc, không báo ai. Tạo từ đây gắn với một lead (cơ hội thêm khi có TS-08).
import { useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { Button, ButtonLink } from '../../ui/Button';
import {
  activityIcon,
  cancelAppointment,
  completeAppointment,
  createLeadAppointment,
  createOpportunityAppointment,
  reopenAppointment,
  rescheduleAppointment,
} from '../../features/appointments/appointmentApi';
import { AppointmentDialog } from '../../features/appointments/AppointmentDialog';
import {
  CompleteAppointmentDialog,
  type CompleteArgs,
} from '../../features/appointments/CompleteAppointmentDialog';
import { useUndoAppointment } from '../../features/appointments/useUndoAppointment';
import { RecordPicker, type PickedRecord } from '../../features/appointments/RecordPicker';
import { AssignDialog } from '../../features/assign/AssignDialog';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { KanbanBoard } from '../../list/Kanban';
import { CalendarView, type CalendarKind, type CalendarMode } from '../../list/Calendar';
import { calendarWindowVn, vnToday, type CalendarEvent } from '../../list/calendarLogic';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { BulkActionBar, Code, Tag, type SortState } from '../../ui/Data';
import { BlockingDialog, ConfirmDialog, ReasonDialog } from '../../ui/Dialogs';
import { Alert, Avatar, Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { downloadText, toCsv } from '../lead/csv';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { EMPTY_APPOINTMENT_STATE, buildAppointmentConfig } from './appointmentConfig';
import { AppointmentButtons, RecordLink, type RowActions } from './AppointmentParts';
import { peopleWithAppointments } from './appointmentPeople';
import { STATUS_TONE } from './appointmentTone';
import {
  APPOINTMENT_GROUP_FIELD_OF,
  appointmentGroupFilter,
  buildAppointmentFilters,
  hiddenOverdueBefore,
} from './appointmentFilters';
import {
  STATUS_LABEL,
  type AppointmentRow,
  type AssignAppointmentsResult,
} from './appointmentTypes';
import {
  KANBAN_STATUSES,
  assignAppointments,
  exportAppointments,
  useAppointmentColumns,
  useAppointmentGroupCounts,
  useAppointmentPage,
  useCalendarAppointments,
  useOverdueBefore,
  useRefreshAppointments,
} from './useAppointmentData';

const NOTE =
  'Lịch hẹn đổi trạng thái bằng nút trên thẻ: Hoàn thành, Huỷ, Mở lại. Hoàn thành và Huỷ không chuyển thẳng cho nhau, phải Mở lại trước (R-CRM-04).';
const BLOCKED =
  'Lịch hẹn đổi trạng thái bằng nút Hoàn thành, Huỷ hoặc Mở lại trên thẻ, không kéo thả.';

const BAR_SEGMENTS = [
  { key: 'upcoming', label: 'Sắp tới', tone: 'success' },
  { key: 'today', label: 'Hôm nay', tone: 'warning' },
  { key: 'overdue', label: 'Quá hạn', tone: 'danger' },
  { key: 'none', label: 'Khác', tone: 'neutral' },
] as const;

// Lịch hẹn chỉ có giờ bắt đầu: khối trên lưới Lịch vẽ cao nửa giờ, chỉ để hiển thị (không lưu).
const EVENT_MINUTES = 30; // allow-number: độ cao hiển thị của một lịch hẹn trên lưới Lịch
const MS_PER_MINUTE = 60_000; // allow-number: số mili giây trong một phút
// Khoảng giờ hiện trên lưới Lịch ngày, tuần (lịch ngoài khoảng được kẹp vào mép).
const CALENDAR_START_HOUR = 7; // allow-number: giờ đầu của lưới Lịch
const CALENDAR_END_HOUR = 21; // allow-number: giờ cuối của lưới Lịch
const CALENDAR_MAX_PAGES = 5; // allow-number: số trang tối đa tải cho một cửa sổ Lịch (hơn thì báo thu hẹp bộ lọc)

// Cột của file xuất (tên cột tiếng Việt; dữ liệu là tên danh mục do hàm xuất trả về).
const EXPORT_COLUMNS = [
  { key: 'kind', label: 'Loại hồ sơ' },
  { key: 'record_code', label: 'Mã hồ sơ' },
  { key: 'record_label', label: 'Hồ sơ' },
  { key: 'activity', label: 'Loại hoạt động' },
  { key: 'title', label: 'Nội dung' },
  { key: 'scheduled_at', label: 'Giờ hẹn' },
  { key: 'status', label: 'Trạng thái' },
  { key: 'owner', label: 'Người phụ trách' },
  { key: 'branch', label: 'Cơ sở' },
  { key: 'auto_reminder', label: 'Lịch nhắc tự sinh' },
  { key: 'cancel_reason', label: 'Lý do huỷ' },
  { key: 'cancel_note', label: 'Ghi chú huỷ' },
  { key: 'created_at', label: 'Ngày tạo' },
];

const ACTIVITY_TONE: Record<string, CalendarKind['tone']> = {
  GOI_DIEN: 'info',
  ZALO: 'brand',
  EMAIL: 'neutral',
  GAP_TRUC_TIEP: 'success',
  NHAC_THU_TIEN: 'warning',
};

const CAL_STATUS = { CHUA_LAM: 'open', HOAN_THANH: 'done', HUY: 'cancelled' } as const;

type Bucket = 'overdue' | 'past' | 'today' | 'upcoming';
const BUCKET_LABEL: Record<Bucket, string> = {
  overdue: 'Quá hạn',
  past: 'Đã qua',
  today: 'Hôm nay',
  upcoming: 'Sắp tới',
};
const BUCKET_ORDER: Bucket[] = ['overdue', 'past', 'today', 'upcoming'];

function bucketOf(row: AppointmentRow, start: Date, end: Date): Bucket {
  const at = new Date(row.scheduled_at);
  if (at < start) return row.status === 'CHUA_LAM' ? 'overdue' : 'past';
  return at < end ? 'today' : 'upcoming';
}

function windowOf(mode: CalendarMode, anchor: Date): { from: Date; to: Date } {
  return calendarWindowVn(mode, anchor);
}

function sortParam(sort: SortState): string {
  return sort?.key === 'time' && sort.direction === 'desc' ? 'time_desc' : 'time_asc';
}

export function AppointmentListPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshAppointments();
  const undoAppointment = useUndoAppointment(refreshData);
  const catalogs = useLeadCatalogs();

  const pageSize = useIntSetting('list_page_size_default');
  const maxPage = useIntSetting('list_page_size_max');
  const cardsPerColumn = useIntSetting('kanban_cards_per_column');

  const navigate = useNavigate();
  // Mở từ nút "Lịch hẹn" của trang Lead: chỉ lịch hẹn của lead đó, mọi thời gian (bỏ chip thì về danh sách chung).
  const [params, setParams] = useSearchParams();
  const parentLead = params.get('lead');
  const parentOpp = params.get('co-hoi');
  const parentTest = params.get('phieu');
  const parentCode = params.get('ma') ?? '';
  const hasParent = parentLead !== null || parentOpp !== null || parentTest !== null;
  const parentFilter = parentLead
    ? { lead_id: parentLead }
    : parentOpp
      ? { opportunity_id: parentOpp }
      : parentTest
        ? { student_test_id: parentTest }
        : {};
  const [state, setState] = useState<ListState>(() =>
    hasParent ? { ...EMPTY_APPOINTMENT_STATE, datePreset: '' } : EMPTY_APPOINTMENT_STATE,
  );
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0, more: 0 });
  const [calMode, setCalMode] = useState<CalendarMode>('week');
  const [anchor, setAnchor] = useState(() => vnToday());
  const [tick, setTick] = useState(0);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  // Mã và cơ sở của các dòng đã chọn (hộp Giao nêu mã dù đổi trang hay nhóm); cập nhật khi chọn.
  const [selectedInfo, setSelectedInfo] = useState<Map<string, { code: string; branch: string }>>(
    new Map(),
  );
  const [assignOpen, setAssignOpen] = useState(false);
  const [assignResult, setAssignResult] = useState<AssignAppointmentsResult | null>(null);
  const [exporting, setExporting] = useState(false);
  const [resourceMode, setResourceMode] = useState<'all' | 'people'>('all');
  const [creating, setCreating] = useState(false);
  const [picked, setPicked] = useState<PickedRecord | null>(null);
  const [moving, setMoving] = useState<AppointmentRow | null>(null);
  const [canceling, setCanceling] = useState<AppointmentRow | null>(null);
  const [completing, setCompleting] = useState<AppointmentRow | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [reopening, setReopening] = useState<AppointmentRow | null>(null);
  const [reopenBusy, setReopenBusy] = useState(false);
  const [reopenError, setReopenError] = useState<string | null>(null);

  const canEdit = access.can('APPOINTMENT', 'SUA');
  const canCancel = access.can('APPOINTMENT', 'HUY');
  const canCreate = access.can('APPOINTMENT', 'TAO');
  const canAssign = access.can('APPOINTMENT', 'GIAO_VIEC');
  const canExport = access.can('APPOINTMENT', 'XUAT');
  const staff = useAssignableStaff('APPOINTMENT', null, canAssign);

  const debounced = useDebounced(state.search);
  const searchState = useMemo(() => ({ ...state, search: debounced }), [state, debounced]);
  const window = useMemo(() => windowOf(calMode, anchor), [calMode, anchor]);
  const filters = useMemo(
    () => ({
      ...buildAppointmentFilters(searchState),
      ...parentFilter,
    }),
    // parentFilter suy ra từ hai tham số địa chỉ.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [searchState, parentLead, parentOpp, parentTest],
  );
  const calendarFilters = useMemo(
    () => ({
      ...buildAppointmentFilters(searchState, new Date(), window),
      ...parentFilter,
    }),
    // parentFilter suy ra từ hai tham số địa chỉ.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [searchState, window, parentLead, parentOpp, parentTest],
  );
  const sortValue = sortParam(sort);
  const filtersKey = JSON.stringify(filters);
  // Group By ở máy chủ (Đ35): khi chọn trường nhóm, danh sách thành cây nhóm có số đếm; không chọn thì giữ nhóm theo thời gian.
  const groupFields = state.group.flatMap((k) =>
    APPOINTMENT_GROUP_FIELD_OF[k] ? [APPOINTMENT_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const pagingKey = `${filtersKey}|${sortValue}`;
  const current = paging.key === pagingKey ? paging : { key: pagingKey, page: 0, more: 0 };
  const page = current.page;
  const moreCards = current.more;
  const setPage = (next: number) => setPaging({ ...current, page: next });

  const list = useAppointmentPage(
    filters,
    sortValue,
    page * (pageSize ?? 0),
    pageSize,
    view === 'list' && !grouped,
  );
  const counts = useAppointmentGroupCounts(filters, groupFields, view === 'list');
  const leaves = useLeafRows<AppointmentRow>(
    filters,
    sortValue,
    pageSize,
    `${filtersKey}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_appointments',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<AppointmentRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            appointmentGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const cardLimit =
    cardsPerColumn === null
      ? null
      : Math.min(cardsPerColumn * (moreCards + 1), maxPage ?? cardsPerColumn);
  const board = useAppointmentColumns(filters, cardLimit, view === 'kanban');
  const calendar = useCalendarAppointments(
    calendarFilters,
    maxPage,
    CALENDAR_MAX_PAGES,
    view === 'calendar',
  );
  const hiddenBefore = hiddenOverdueBefore(state);
  const overdue = useOverdueBefore(
    view === 'calendar' ? null : hiddenBefore,
    (state.quick.mine ?? []).includes('owner'),
  );

  const pageRows = list.data?.rows ?? [];
  const rows: AppointmentRow[] = useMemo(
    () =>
      grouping
        ? grouping.tree
            .flatMap((g) => (g.children.length > 0 ? g.children : [g]))
            .flatMap((g) => g.rows)
        : pageRows,
    // pageRows suy ra từ list.data.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouping, list.data],
  );
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery =
    view === 'kanban'
      ? board.find((q) => q.isError)
      : view === 'calendar'
        ? calendar
        : grouped
          ? counts
          : list;
  const errorText = activeQuery?.isError ? errorOf(activeQuery.error).message : null;
  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;

  const branchIdOf = (code: string) =>
    access.teachingBranches.find((b) => b.code === code)?.id ?? '';

  /** Hộp «Hoàn thành lịch hẹn» (TS-11): lỗi ném lại để hộp hiện câu lỗi. */
  async function completeWith(id: string, args: CompleteArgs) {
    await completeAppointment(supabase, id, args);
    await refreshData();
    toast({ title: 'Đã hoàn thành lịch hẹn.', action: undoAppointment(id) });
  }

  const actions: RowActions = {
    canEdit,
    canCancel,
    busyId: null,
    onComplete: (row) => setCompleting(row),
    onReschedule: setMoving,
    onCancel: (row) => {
      setCancelError(null);
      setCanceling(row);
    },
    onReopen: (row) => {
      setReopenError(null);
      setReopening(row);
    },
  };

  const config = useMemo(
    () =>
      buildAppointmentConfig(
        catalogs,
        access,
        actions,
        (staff.data ?? []).map((s) => ({ value: s.id, label: s.display_name })),
      ),
    // actions đổi mỗi lần vẽ nhưng chỉ chứa các hàm gọi lại ổn định theo trạng thái dưới đây.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [catalogs, access, staff.data, canEdit, canCancel],
  );

  const { start, end } = vnDayBounds();
  const bucketTree = useMemo(() => {
    const byBucket = new Map<Bucket, AppointmentRow[]>();
    for (const row of pageRows) {
      const bucket = bucketOf(row, start, end);
      byBucket.set(bucket, [...(byBucket.get(bucket) ?? []), row]);
    }
    return BUCKET_ORDER.flatMap((b) => {
      const items = byBucket.get(b) ?? [];
      return items.length === 0
        ? []
        : [{ key: b, label: BUCKET_LABEL[b], count: items.length, children: [], rows: items }];
    });
    // start, end đổi theo ngày; pageRows đổi theo dữ liệu.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [list.data]);

  const columns = KANBAN_STATUSES.map((status, i) => ({
    code: status,
    label: STATUS_LABEL[status],
    cards: board[i]?.data?.rows ?? [],
    total: board[i]?.data?.total ?? 0,
  }));
  const shownCards = columns.reduce((sum, c) => sum + c.cards.length, 0);
  const boardTotal = columns.reduce((sum, c) => sum + c.total, 0);
  const boardPending = board.some((q) => q.isPending);

  const kinds: CalendarKind[] = catalogs.options('ACTIVITY_TYPE').map((o) => ({
    key: o.value,
    label: o.label,
    icon: activityIcon(o.value),
    tone: ACTIVITY_TONE[o.value] ?? 'neutral',
  }));
  const calendarRows = calendar.data?.rows ?? [];
  const events: CalendarEvent[] = calendarRows.map((r) => {
    const startAt = new Date(r.scheduled_at);
    return {
      id: r.id,
      title: r.record_label ?? r.title,
      start: startAt,
      end: new Date(startAt.getTime() + EVENT_MINUTES * MS_PER_MINUTE),
      kind: r.activity_code,
      status: CAL_STATUS[r.status],
      subtitle: r.record_code ?? undefined,
      resource: r.owner_name ?? undefined,
    };
  });
  // "Theo người" (Đ34, Đ38): chỉ người có lịch hẹn trong ngày đang xem, xếp theo tên, trong phạm vi lịch mà người xem được xem
  // theo ma trận quyền (không thu hẹp quyền xem của Tuyển sinh, CSKH).
  const people = peopleWithAppointments(calendarRows);

  const refresh = () => {
    setTick((t) => t + 1);
    void refreshData();
  };

  const select = (next: Set<string>) => {
    setSelected(next);
    setSelectedInfo((prev) => {
      const info = new Map<string, { code: string; branch: string }>();
      for (const id of next) {
        const row = rows.find((r) => r.id === id);
        const old = prev.get(id);
        if (row) info.set(id, { code: row.record_code ?? row.title, branch: row.branch_code });
        else if (old) info.set(id, old);
      }
      return info;
    });
  };
  const selectedCodes = [...selectedInfo.values()].map((i) => i.code);
  const selectedBranches = [...selectedInfo.values()].map((i) => i.branch);

  async function exportFile() {
    if (exporting) return;
    setExporting(true);
    try {
      const result = await exportAppointments(supabase, filters);
      const exportRows = result.rows.map((r) => ({
        ...r,
        scheduled_at: formatDateTime(r.scheduled_at),
        created_at: formatDateTime(r.created_at),
        auto_reminder: r.auto_reminder ? 'Có' : '',
      }));
      downloadText(`lich-hen-${vnDayBounds().dateKey}.csv`, toCsv(exportRows, EXPORT_COLUMNS));
      toast(
        result.truncated
          ? {
              tone: 'warning',
              title: `Đã xuất ${result.exported} trên ${result.total} dòng (quá giới hạn mỗi lần xuất). Thêm bộ lọc để xuất phần còn lại.`,
            }
          : { title: `Đã xuất ${result.exported} dòng.` },
      );
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setExporting(false);
    }
  }

  function showOverdue() {
    setState({ ...state, datePreset: '', quick: { ...state.quick, overdue: ['overdue'] } });
  }

  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => `${activityName(r.activity_code)} ${r.title}`}
        loading={
          view === 'kanban'
            ? boardPending
            : view === 'calendar'
              ? calendar.isPending
              : grouped
                ? counts.isPending || counts.isPlaceholderData
                : list.isPending || list.isPlaceholderData
        }
        error={errorText}
        onRetry={() => void activeQuery?.refetch()}
        actions={[
          ...(canCreate
            ? [
                {
                  label: 'Tạo',
                  icon: 'plus' as const,
                  primary: true,
                  onClick: () => {
                    setPicked(null);
                    setCreating(true);
                  },
                },
              ]
            : []),
          ...(canExport
            ? [
                {
                  label: 'Xuất',
                  icon: 'download' as const,
                  onClick: () => void exportFile(),
                  loading: exporting,
                },
              ]
            : []),
        ]}
        onRefresh={refresh}
        pager={
          view === 'list' && !grouped
            ? {
                from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
                to: page * (pageSize ?? 0) + rows.length,
                total,
                ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
                ...(page * (pageSize ?? 0) + rows.length < total
                  ? { onNext: () => setPage(page + 1) }
                  : {}),
              }
            : view === 'kanban'
              ? { from: shownCards === 0 ? 0 : 1, to: shownCards, total: boardTotal }
              : undefined
        }
        sort={sort}
        onSortChange={(next) => setSort(next?.key === 'time' ? next : null)}
        {...(canAssign && view === 'list' ? { selected, onSelectedChange: select } : {})}
        bulk={
          canAssign && view === 'list' ? (
            <BulkActionBar count={selected.size} onClear={() => select(new Set())}>
              <Button icon="user" onClick={() => setAssignOpen(true)}>
                Assign
              </Button>
            </BulkActionBar>
          ) : undefined
        }
        emptyMessage={{
          title: 'Chưa có lịch hẹn',
          hint: 'Không có lịch hẹn nào trong bộ lọc này. Đổi bộ lọc hoặc bấm Tạo để thêm lịch hẹn.',
        }}
        parent={
          hasParent
            ? {
                entityLabel: parentLead ? 'Lead' : parentOpp ? 'Cơ hội' : 'Phiếu',
                code: parentCode,
                childLabel: 'Lịch hẹn',
                onOpenParent: () =>
                  void navigate(
                    parentLead
                      ? `/crm/lead/${parentLead}`
                      : parentOpp
                        ? `/crm/co-hoi/${parentOpp}`
                        : `/crm/phieu-kiem-tra/${parentTest}`,
                  ),
                onClear: () => setParams({}),
              }
            : undefined
        }
        groupTree={grouped ? grouping?.tree : bucketTree}
        onGroupToggle={(key, open) => {
          const spec = grouping?.specs.get(key);
          if (spec) leaves.toggle(key, spec.filters, open);
        }}
        groupsOpenByDefault={!grouped}
        kanban={
          boardPending ? (
            <Spinner label="Đang tải Kanban…" />
          ) : (
            <KanbanBoard
              columns={columns}
              cardKey={(c) => c.id}
              cardLabel={(c) => c.title}
              rule={() => ({ ok: false, reason: BLOCKED })}
              bar={{
                segments: BAR_SEGMENTS.map((s) => ({ ...s })),
                of: (c) => {
                  if (c.status !== 'CHUA_LAM') return 'none';
                  const bucket = bucketOf(c, start, end);
                  return bucket === 'overdue' ? 'overdue' : bucket;
                },
              }}
              onMove={() => undefined}
              onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
              onLoadMore={() => setPaging({ ...current, more: moreCards + 1 })}
              note={NOTE}
              renderCard={(c) => (
                <AppointmentCard
                  row={c}
                  activity={activityName(c.activity_code)}
                  actions={actions}
                />
              )}
            />
          )
        }
        calendar={
          <div className="flex flex-col gap-3">
            {calMode === 'day' && resourceMode === 'people' && people.length === 0 && (
              <Alert tone="info">
                Không có lịch hẹn nào trong ngày này nên chưa có cột người nào.
              </Alert>
            )}
            {calendar.data?.truncated && (
              <Alert tone="warning">
                Khoảng này có {calendar.data.total} lịch hẹn, đang hiện {calendarRows.length}. Thêm
                bộ lọc để thu hẹp.
              </Alert>
            )}
            <CalendarView
              events={events}
              kinds={kinds}
              mode={calMode}
              onModeChange={setCalMode}
              anchor={anchor}
              onAnchorChange={setAnchor}
              startHour={CALENDAR_START_HOUR}
              endHour={CALENDAR_END_HOUR}
              resources={{ people, rooms: [] }}
              resourceMode={resourceMode}
              onResourceModeChange={(m) => setResourceMode(m === 'rooms' ? 'all' : m)}
              now={new Date()}
              renderDetail={(event, close) => {
                const row = calendarRows.find((r) => r.id === event.id);
                if (!row) return null;
                return (
                  <CalendarDetail
                    row={row}
                    activity={activityName(row.activity_code)}
                    actions={{
                      ...actions,
                      onComplete: (r) => {
                        close();
                        actions.onComplete(r);
                      },
                      onReschedule: (r) => {
                        close();
                        actions.onReschedule(r);
                      },
                      onCancel: (r) => {
                        close();
                        actions.onCancel(r);
                      },
                      onReopen: (r) => {
                        close();
                        actions.onReopen(r);
                      },
                    }}
                  />
                );
              }}
            />
          </div>
        }
        belowToolbar={
          overdue.data && overdue.data > 0 ? (
            <div className="flex items-center gap-2">
              <Alert tone="warning" className="flex-1">
                <b>Còn {overdue.data} lịch Quá hạn</b> chưa làm, đang bị ẩn bởi bộ lọc thời gian.
              </Alert>
              <Button onClick={showOverdue}>Xem</Button>
            </div>
          ) : undefined
        }
      />

      <CompleteAppointmentDialog
        open={completing !== null}
        onOpenChange={(o) => !o && setCompleting(null)}
        target={
          completing
            ? {
                id: completing.id,
                activityCode: completing.activity_code,
                label: `${activityName(completing.activity_code)} · ${completing.title}`,
                context: [
                  completing.record_code,
                  completing.record_label,
                  formatDateTime(completing.scheduled_at),
                ]
                  .filter(Boolean)
                  .join(' · '),
              }
            : null
        }
        resultOptions={catalogs.options('APPOINTMENT_RESULT')}
        onComplete={completeWith}
      />
      <AppointmentDialog
        open={creating}
        onOpenChange={setCreating}
        target={picked}
        targetPicker={<RecordPicker value={picked} onChange={setPicked} />}
        activityOptions={catalogs.options('ACTIVITY_TYPE')}
        onCreate={async (args) => {
          if (!picked) return;
          const noteText = args.note.trim();
          const args2 = {
            activityCode: args.activityCode,
            scheduledAt: args.scheduledAt,
            title: noteText === '' ? activityName(args.activityCode) : noteText,
            ownerId: args.ownerId,
          };
          if (picked.kind === 'OPPORTUNITY') {
            await createOpportunityAppointment(supabase, {
              ...args2,
              opportunityId: picked.recordId,
            });
          } else {
            await createLeadAppointment(supabase, { ...args2, leadId: picked.recordId });
          }
          await refreshData();
          toast({ title: 'Đã tạo lịch hẹn.' });
        }}
        onReschedule={() => Promise.resolve()}
      />
      {moving && (
        <AppointmentDialog
          open
          onOpenChange={(open) => !open && setMoving(null)}
          target={{ label: moving.record_label ?? '', branchId: branchIdOf(moving.branch_code) }}
          activityOptions={[]}
          reschedule={{
            id: moving.id,
            label:
              moving.title === activityName(moving.activity_code)
                ? moving.title
                : `${activityName(moving.activity_code)} · ${moving.title}`,
            scheduledAt: moving.scheduled_at,
            ownerId: moving.owner_id,
            ownerName: moving.owner_name,
            branchId: branchIdOf(moving.branch_code),
          }}
          onCreate={() => Promise.resolve()}
          onReschedule={async (args) => {
            await rescheduleAppointment(supabase, args);
            await refreshData();
            toast({ title: 'Đã dời lịch hẹn.' });
          }}
        />
      )}
      <ReasonDialog
        open={canceling !== null}
        onOpenChange={(open) => !open && setCanceling(null)}
        title="Huỷ lịch hẹn"
        description={
          canceling ? `${activityName(canceling.activity_code)} · ${canceling.title}` : undefined
        }
        options={catalogs.options('APPOINTMENT_CANCEL_REASON').map((o) => ({
          ...o,
          needsNote: catalogs.requiresNote('APPOINTMENT_CANCEL_REASON', o.value),
        }))}
        confirmLabel="Huỷ lịch hẹn"
        busy={cancelBusy}
        error={cancelError}
        onConfirm={(result) => {
          if (!canceling) return;
          setCancelBusy(true);
          setCancelError(null);
          void cancelAppointment(supabase, canceling.id, result.option, result.note)
            .then(refreshData)
            .then(() => {
              setCanceling(null);
              toast({ title: 'Đã huỷ lịch hẹn.', action: undoAppointment(canceling.id) });
            })
            .catch((e: unknown) => setCancelError(errorOf(e).message))
            .finally(() => setCancelBusy(false));
        }}
      />
      <ConfirmDialog
        open={reopening !== null}
        onOpenChange={(open) => !open && setReopening(null)}
        title="Mở lại lịch hẹn?"
        description={
          reopening
            ? `${activityName(reopening.activity_code)} · ${reopening.title} đang ${STATUS_LABEL[reopening.status].toLowerCase()}. Mở lại sẽ đưa về Chưa làm, không đổi giai đoạn, không tạo việc, không gửi thông báo. Lịch sử có ghi lần mở lại.`
            : undefined
        }
        confirmLabel="Mở lại"
        busy={reopenBusy}
        error={reopenError}
        onConfirm={() => {
          if (!reopening) return;
          setReopenBusy(true);
          setReopenError(null);
          void reopenAppointment(supabase, reopening.id)
            .then(refreshData)
            .then(() => {
              setReopening(null);
              toast({ title: 'Đã mở lại lịch hẹn.' });
            })
            .catch((e: unknown) => setReopenError(errorOf(e).message))
            .finally(() => setReopenBusy(false));
        }}
      />
      <AssignDialog
        open={assignOpen}
        onOpenChange={setAssignOpen}
        entityType="APPOINTMENT"
        noun="lịch hẹn"
        codes={selectedCodes}
        branchCodes={selectedBranches}
        onAssign={async (ownerId, ownerName) => {
          const result = await assignAppointments(supabase, [...selected], ownerId);
          select(new Set());
          refresh();
          if (result.skipped === 0) {
            toast({ title: `Đã giao ${result.assigned} lịch hẹn cho ${ownerName}.` });
          } else {
            // Lô chọn lẫn (Đ33): nêu rõ số giao được, số bị bỏ và lý do từng nhóm; không im lặng bỏ dòng.
            setAssignResult({ ...result, reasons: result.reasons });
            toast({
              tone: result.assigned > 0 ? 'info' : 'warning',
              title: `Đã giao ${result.assigned} lịch hẹn cho ${ownerName}, bỏ qua ${result.skipped}.`,
            });
          }
        }}
      />
      <BlockingDialog
        open={assignResult !== null}
        onOpenChange={(open) => {
          if (!open) setAssignResult(null);
        }}
        title={`Đã giao ${assignResult?.assigned ?? 0} trên ${assignResult?.requested ?? 0} lịch hẹn`}
        message={`Bỏ qua ${assignResult?.skipped ?? 0} lịch hẹn vì các lý do dưới đây. Những lịch này giữ nguyên người phụ trách.`}
        items={(assignResult?.reasons ?? []).map((r) => ({
          left: r.message,
          right: `${r.count} lịch hẹn`,
        }))}
      />
    </>
  );
}

function timeTone(row: AppointmentRow, start: Date, end: Date) {
  const bucket = bucketOf(row, start, end);
  return row.status !== 'CHUA_LAM'
    ? STATUS_TONE[row.status]
    : bucket === 'overdue'
      ? 'danger'
      : bucket === 'today'
        ? 'warning'
        : 'success';
}

function AppointmentCard({
  row,
  activity,
  actions,
}: {
  row: AppointmentRow;
  activity: string;
  actions: RowActions;
}) {
  const { start, end } = vnDayBounds();
  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center justify-between gap-2 text-caption text-fg-muted">
        <span>{activity}</span>
        <RecordLink row={row} />
      </div>
      <p
        className={
          row.status === 'HUY' ? 'font-semibold text-fg-muted line-through' : 'font-semibold'
        }
      >
        {row.title}
      </p>
      {row.record_label && <p className="text-caption text-fg-muted">{row.record_label}</p>}
      <div className="flex items-center justify-between gap-2">
        <Tag tone={timeTone(row, start, end)} dot>
          {formatDateTime(row.scheduled_at)}
        </Tag>
        {row.owner_name && <Avatar name={row.owner_name} />}
      </div>
      <AppointmentButtons row={row} actions={actions} />
    </div>
  );
}

function CalendarDetail({
  row,
  activity,
  actions,
}: {
  row: AppointmentRow;
  activity: string;
  actions: RowActions;
}) {
  return (
    <div className="flex w-[320px] max-w-full flex-col gap-2 p-3">
      <div className="flex items-start justify-between gap-2">
        <p className="font-semibold">
          {activity} · {row.title}
        </p>
        <Tag tone={STATUS_TONE[row.status]}>{STATUS_LABEL[row.status]}</Tag>
      </div>
      {row.record_label && (
        <p className="text-body">
          <Code>{row.record_code ?? ''}</Code> {row.record_label}
        </p>
      )}
      <p className="text-caption text-fg-muted">
        {formatDateTime(row.scheduled_at)}
        {row.owner_name ? ` · ${row.owner_name}` : ''}
      </p>
      {(row.lead_id || row.opportunity_id) && (
        <ButtonLink
          variant="primary"
          icon="arrowRight"
          to={row.lead_id ? `/crm/lead/${row.lead_id}` : `/crm/co-hoi/${row.opportunity_id}`}
        >
          {row.lead_id ? `Mở lead ${row.lead_code}` : `Mở cơ hội ${row.opportunity_code}`}
        </ButtonLink>
      )}
      <AppointmentButtons row={row} actions={actions} />
    </div>
  );
}
