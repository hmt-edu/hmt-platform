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
import { useUndoAppointment } from '../../features/appointments/useUndoAppointment';
import { RecordPicker, type PickedRecord } from '../../features/appointments/RecordPicker';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { KanbanBoard } from '../../list/Kanban';
import { CalendarView, type CalendarKind, type CalendarMode } from '../../list/Calendar';
import {
  addDays,
  monthGrid,
  startOfDay,
  weekDays,
  type CalendarEvent,
} from '../../list/calendarLogic';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { Code, Tag, type SortState } from '../../ui/Data';
import { ConfirmDialog, ReasonDialog } from '../../ui/Dialogs';
import { Alert, Avatar, Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { EMPTY_APPOINTMENT_STATE, buildAppointmentConfig } from './appointmentConfig';
import { AppointmentButtons, RecordLink, type RowActions } from './AppointmentParts';
import { STATUS_TONE } from './appointmentTone';
import { buildAppointmentFilters, hiddenOverdueBefore } from './appointmentFilters';
import { STATUS_LABEL, type AppointmentRow } from './appointmentTypes';
import {
  KANBAN_STATUSES,
  useAppointmentColumns,
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
  if (mode === 'day') return { from: startOfDay(anchor), to: addDays(anchor, 1) };
  const days = mode === 'week' ? weekDays(anchor) : monthGrid(anchor);
  return { from: days[0] ?? startOfDay(anchor), to: addDays(days[days.length - 1] ?? anchor, 1) };
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
  const [anchor, setAnchor] = useState(() => startOfDay(new Date()));
  const [busyId, setBusyId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [picked, setPicked] = useState<PickedRecord | null>(null);
  const [moving, setMoving] = useState<AppointmentRow | null>(null);
  const [canceling, setCanceling] = useState<AppointmentRow | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [reopening, setReopening] = useState<AppointmentRow | null>(null);
  const [reopenBusy, setReopenBusy] = useState(false);
  const [reopenError, setReopenError] = useState<string | null>(null);

  const canEdit = access.can('APPOINTMENT', 'SUA');
  const canCancel = access.can('APPOINTMENT', 'HUY');
  const canCreate = access.can('APPOINTMENT', 'TAO');
  const canAssign = access.can('APPOINTMENT', 'GIAO_VIEC');
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
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const current = paging.key === pagingKey ? paging : { key: pagingKey, page: 0, more: 0 };
  const page = current.page;
  const moreCards = current.more;
  const setPage = (next: number) => setPaging({ ...current, page: next });

  const list = useAppointmentPage(
    filters,
    sortValue,
    page * (pageSize ?? 0),
    pageSize,
    view === 'list',
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

  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const activeQuery =
    view === 'kanban' ? board.find((q) => q.isError) : view === 'calendar' ? calendar : list;
  const errorText = activeQuery?.isError ? errorOf(activeQuery.error).message : null;
  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;

  const branchIdOf = (code: string) =>
    access.teachingBranches.find((b) => b.code === code)?.id ?? '';

  async function run(
    row: AppointmentRow,
    action: () => Promise<void>,
    success: string,
    undoable = false,
  ) {
    if (busyId !== null) return;
    setBusyId(row.id);
    try {
      await action();
      await refreshData();
      toast({ title: success, ...(undoable ? { action: undoAppointment(row.id) } : {}) });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setBusyId(null);
    }
  }

  const actions: RowActions = {
    canEdit,
    canCancel,
    busyId,
    onComplete: (row) =>
      void run(row, () => completeAppointment(supabase, row.id), 'Đã hoàn thành lịch hẹn.', true),
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
    [catalogs, access, staff.data, busyId, canEdit, canCancel],
  );

  const { start, end } = vnDayBounds();
  const groupTree = useMemo(() => {
    const byBucket = new Map<Bucket, AppointmentRow[]>();
    for (const row of rows) {
      const bucket = bucketOf(row, start, end);
      byBucket.set(bucket, [...(byBucket.get(bucket) ?? []), row]);
    }
    return BUCKET_ORDER.flatMap((b) => {
      const items = byBucket.get(b) ?? [];
      return items.length === 0
        ? []
        : [{ key: b, label: BUCKET_LABEL[b], count: items.length, children: [], rows: items }];
    });
    // start, end đổi theo ngày; rows đổi theo dữ liệu.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rows]);

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
    };
  });

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
              : list.isPending || list.isPlaceholderData
        }
        error={errorText}
        onRetry={() => void activeQuery?.refetch()}
        actions={
          canCreate
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
            : []
        }
        onRefresh={() => void refreshData()}
        pager={
          view === 'list'
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
        groupTree={groupTree}
        groupsOpenByDefault
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
