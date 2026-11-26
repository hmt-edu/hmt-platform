// TS-16 Kiểm tra đầu vào (danh sách), TS16b (Kanban), TS16c (Lịch): khuôn K1, K2, K5 nối các hàm phiếu trong cơ sở dữ liệu.
// Lọc, sắp xếp, phân trang, Group By, số đếm Kanban đều tính ở máy chủ. Phiếu chỉ tạo từ trang Cơ hội (TS-15, R-CRM-05) nên không
// có nút Tạo; đổi trạng thái bằng nút trên thẻ (Bắt đầu test, Nộp bài) hoặc ở trang phiếu, không kéo thả.
import { useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { CalendarView, type CalendarKind, type CalendarMode } from '../../list/Calendar';
import { calendarWindowVn, vnToday, type CalendarEvent } from '../../list/calendarLogic';
import { KanbanBoard } from '../../list/Kanban';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { useAuth } from '../../lib/auth/authContext';
import { useDebounced } from '../../lib/useDebounced';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { Button, ButtonLink } from '../../ui/Button';
import { Code, Tag, type SortState } from '../../ui/Data';
import { Alert, Spinner } from '../../ui/Feedback';
import { Icon } from '../../ui/icons';
import { useToast } from '../../ui/toastContext';
import { downloadText, toCsv } from '../lead/csv';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { EMPTY_TEST_STATE, TEST_TONE, buildTestConfig } from './testConfig';
import { TEST_GROUP_FIELD_OF, buildTestFilters, testGroupFilter } from './testFilters';
import { formatScore } from './testLogic';
import { STATUS_LABEL, type TestBoardCard, type TestRow } from './testTypes';
import {
  exportTests,
  startTest,
  submitTest,
  useRefreshTests,
  useTestBoard,
  useTestCalendar,
  useTestGroupCounts,
  useTestPage,
} from './useTestData';

const NOTE =
  'Phiếu đổi trạng thái bằng nút trên thẻ (Bắt đầu test, Nộp bài) hoặc trong trang phiếu; không kéo thả. Phiếu tạo từ trang Cơ hội (từ L5 trở đi).';
const BLOCKED = 'Phiếu đổi trạng thái bằng nút trên thẻ hoặc trong trang phiếu, không kéo thả.';

const BAR_SEGMENTS = [
  { key: 'upcoming', label: 'Sắp tới', tone: 'success' },
  { key: 'today', label: 'Hôm nay', tone: 'warning' },
  { key: 'overdue', label: 'Quá giờ', tone: 'danger' },
] as const;

const EXPORT_COLUMNS = [
  { key: 'code', label: 'Mã PKT' },
  { key: 'opportunity', label: 'Cơ hội' },
  { key: 'student_name', label: 'Học sinh' },
  { key: 'student_birth_year', label: 'Năm sinh' },
  { key: 'parent_name', label: 'Phụ huynh' },
  { key: 'parent_phone', label: 'SĐT' },
  { key: 'subject', label: 'Môn' },
  { key: 'grade', label: 'Khối' },
  { key: 'mode', label: 'Hình thức' },
  { key: 'level', label: 'Cấp độ' },
  { key: 'exam_name', label: 'Đề test' },
  { key: 'scheduled_at', label: 'Ngày giờ test' },
  { key: 'status', label: 'Trạng thái' },
  { key: 'branch', label: 'Cơ sở' },
  { key: 'test_branch', label: 'Cơ sở test' },
  { key: 'room', label: 'Phòng' },
  { key: 'grader', label: 'GV chấm' },
  { key: 'owner', label: 'Người phụ trách' },
  { key: 'created_by', label: 'Người tạo' },
  { key: 'score', label: 'Điểm' },
  { key: 'suggested_level', label: 'Trình độ đề xuất' },
  { key: 'suggested_framework', label: 'Phân loại đề xuất' },
  { key: 'cancel_reason', label: 'Lý do huỷ' },
  { key: 'created_at', label: 'Ngày tạo' },
];

// Phiếu chỉ có giờ bắt đầu: khối trên lưới Lịch vẽ cao một giờ, chỉ để hiển thị (không lưu).
const EVENT_MINUTES = 60; // allow-number: độ cao hiển thị của một phiếu trên lưới Lịch
const MS_PER_MINUTE = 60_000; // allow-number: số mili giây trong một phút
const CALENDAR_START_HOUR = 7; // allow-number: giờ đầu của lưới Lịch
const CALENDAR_END_HOUR = 21; // allow-number: giờ cuối của lưới Lịch
const CALENDAR_MAX_PAGES = 5; // allow-number: số trang tối đa tải cho một cửa sổ Lịch (hơn thì báo thu hẹp bộ lọc)

const KINDS: CalendarKind[] = [
  { key: 'DRAFT', label: 'Nháp', icon: 'edit', tone: 'neutral' },
  { key: 'TESTING', label: 'Đang test', icon: 'results', tone: 'info' },
  { key: 'TEACHER_REVIEW', label: 'Chờ giáo viên chấm', icon: 'clock', tone: 'warning' },
];
const CAL_STATUS = {
  DRAFT: 'open',
  TESTING: 'open',
  TEACHER_REVIEW: 'open',
  COMPLETED: 'done',
  CANCELLED: 'cancelled',
} as const;

function windowOf(mode: CalendarMode, anchor: Date): { from: Date; to: Date } {
  return calendarWindowVn(mode, anchor);
}

function sortParam(sort: SortState): string {
  return sort?.key === 'time' && sort.direction === 'desc' ? 'time_desc' : 'time_asc';
}

export function TestListPage() {
  const supabase = useDb();
  const navigate = useNavigate();
  const access = useAccess();
  const toast = useToast();
  const { claims } = useAuth();
  const refreshData = useRefreshTests();
  const catalogs = useLeadCatalogs();

  const pageSize = useIntSetting('list_page_size_default');
  const maxPage = useIntSetting('list_page_size_max');
  const cardsPerColumn = useIntSetting('kanban_cards_per_column');

  // Mở từ nút "Kiểm tra" của trang Cơ hội: chỉ phiếu của cơ hội đó, mọi thời gian (bỏ chip thì về danh sách chung).
  const [params, setParams] = useSearchParams();
  const parentOpp = params.get('co-hoi');
  const parentCode = params.get('ma') ?? '';
  const [state, setState] = useState<ListState>(() =>
    parentOpp ? { ...EMPTY_TEST_STATE, datePreset: '' } : EMPTY_TEST_STATE,
  );
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0, more: 0 });
  const [calMode, setCalMode] = useState<CalendarMode>('week');
  const [anchor, setAnchor] = useState(() => vnToday());
  const [busyId, setBusyId] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [tick, setTick] = useState(0);

  const canEdit = access.can('STUDENT_TEST', 'SUA');
  const canExport = access.can('STUDENT_TEST', 'XUAT');
  const canAssign = access.can('STUDENT_TEST', 'GIAO_VIEC');
  const staff = useAssignableStaff('STUDENT_TEST', null, canAssign);
  const people = useMemo(
    () => (staff.data ?? []).map((s) => ({ value: s.id, label: s.display_name })),
    [staff.data],
  );
  const config = useMemo(
    () => buildTestConfig(catalogs, access, people),
    [catalogs, access, people],
  );

  const debounced = useDebounced(state.search);
  const searchState = useMemo(() => ({ ...state, search: debounced }), [state, debounced]);
  const parentFilter = useMemo(() => (parentOpp ? { opportunity_id: parentOpp } : {}), [parentOpp]);
  const window = useMemo(() => windowOf(calMode, anchor), [calMode, anchor]);
  const filters = useMemo(
    () => ({ ...buildTestFilters(searchState), ...parentFilter }),
    [searchState, parentFilter],
  );
  const calendarFilters = useMemo(
    () => ({ ...buildTestFilters(searchState, new Date(), window), ...parentFilter }),
    [searchState, window, parentFilter],
  );
  const filtersKey = JSON.stringify(filters);
  const sortValue = sortParam(sort);
  const groupFields = state.group.flatMap((k) =>
    TEST_GROUP_FIELD_OF[k] ? [TEST_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;

  const pagingKey = `${filtersKey}|${sortValue}`;
  const current = paging.key === pagingKey ? paging : { key: pagingKey, page: 0, more: 0 };
  const page = current.page;
  const moreCards = current.more;
  const setPage = (next: number) => setPaging({ ...current, page: next });

  const list = useTestPage(
    filters,
    sortValue,
    page * (pageSize ?? 0),
    pageSize,
    view === 'list' && !grouped,
  );
  const counts = useTestGroupCounts(filters, groupFields, view === 'list');
  const cardLimit =
    cardsPerColumn === null
      ? null
      : Math.min(cardsPerColumn * (moreCards + 1), maxPage ?? cardsPerColumn);
  const board = useTestBoard(filters, cardLimit, view === 'kanban');
  const calendar = useTestCalendar(
    calendarFilters,
    maxPage,
    CALENDAR_MAX_PAGES,
    view === 'calendar',
  );
  const leaves = useLeafRows<TestRow>(
    filters,
    sortValue,
    pageSize,
    `${filtersKey}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_student_tests',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<TestRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            testGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );

  const listRows: TestRow[] = useMemo(
    () =>
      grouping
        ? grouping.tree
            .flatMap((g) => (g.children.length > 0 ? g.children : [g]))
            .flatMap((g) => g.rows)
        : (list.data?.rows ?? []),
    [grouping, list.data],
  );
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery =
    view === 'kanban' ? board : view === 'calendar' ? calendar : grouped ? counts : list;
  const errorText = activeQuery.isError ? errorOf(activeQuery.error).message : null;

  const refresh = () => {
    setTick((t) => t + 1);
    void refreshData();
  };

  async function step(card: TestBoardCard, action: 'start' | 'submit') {
    if (busyId !== null) return;
    setBusyId(card.id);
    try {
      if (action === 'start') await startTest(supabase, card.id);
      else await submitTest(supabase, card.id);
      refresh();
      toast({ title: action === 'start' ? 'Đã bắt đầu test.' : 'Đã nộp bài, chờ giáo viên chấm.' });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setBusyId(null);
    }
  }

  async function exportFile() {
    if (exporting) return;
    setExporting(true);
    try {
      const result = await exportTests(supabase, filters);
      const rows = result.rows.map((r) => ({
        ...r,
        scheduled_at: r.scheduled_at ? formatDateTime(String(r.scheduled_at)) : '',
        created_at: formatDateTime(String(r.created_at)),
      }));
      downloadText(`phieu-kiem-tra-${vnDayBounds().dateKey}.csv`, toCsv(rows, EXPORT_COLUMNS));
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

  const { start: dayStart, end: dayEnd } = vnDayBounds();
  const barKey = (c: TestBoardCard): string => {
    const at = new Date(c.scheduled_at);
    if (c.status_code === 'DRAFT' && at < dayStart) return 'overdue';
    if (at >= dayEnd) return 'upcoming';
    return at >= dayStart ? 'today' : 'none';
  };
  const columns = (board.data ?? []).map((c) => ({
    code: c.status_code,
    label: STATUS_LABEL[c.status_code],
    cards: c.rows,
    total: c.total,
  }));
  const shownCards = columns.reduce((sum, c) => sum + c.cards.length, 0);
  const boardTotal = columns.reduce((sum, c) => sum + (c.total ?? 0), 0);

  const calendarRows = calendar.data?.rows ?? [];
  const subjectMode = (r: { subject_code: string; mode_code: string }) =>
    [catalogs.name('SUBJECT', r.subject_code), catalogs.name('TEST_MODE', r.mode_code)]
      .filter(Boolean)
      .join(' · ');
  const events: CalendarEvent[] = calendarRows.map((r) => {
    const startAt = new Date(r.scheduled_at);
    return {
      id: r.id,
      title: r.student_name,
      start: startAt,
      end: new Date(startAt.getTime() + EVENT_MINUTES * MS_PER_MINUTE),
      kind: r.status_code,
      status: CAL_STATUS[r.status_code],
      subtitle: subjectMode(r),
    };
  });

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view={view}
      onViewChange={setView}
      rows={listRows}
      rowKey={(r) => r.id}
      rowLabel={(r) => `${r.code} ${r.student_name}`}
      loading={
        view === 'kanban'
          ? board.isPending
          : view === 'calendar'
            ? calendar.isPending
            : activeQuery.isPending || activeQuery.isPlaceholderData
      }
      error={errorText}
      onRetry={() => void activeQuery.refetch()}
      actions={
        canExport
          ? [
              {
                label: 'Xuất',
                icon: 'download' as const,
                onClick: () => void exportFile(),
                loading: exporting,
              },
            ]
          : []
      }
      onRefresh={refresh}
      pager={
        view === 'kanban'
          ? { from: shownCards === 0 ? 0 : 1, to: shownCards, total: boardTotal }
          : view === 'calendar' || grouped
            ? undefined
            : {
                from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
                to: page * (pageSize ?? 0) + listRows.length,
                total,
                ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
                ...(page * (pageSize ?? 0) + listRows.length < total
                  ? { onNext: () => setPage(page + 1) }
                  : {}),
              }
      }
      sort={sort}
      onSortChange={(next) => setSort(next?.key === 'time' ? next : null)}
      emptyMessage={{
        title: 'Chưa có phiếu Test',
        hint: 'Phiếu được tạo từ trang Cơ hội (từ L5 trở đi). Khi có phiếu, danh sách sẽ hiện ở đây.',
      }}
      parent={
        parentOpp
          ? {
              entityLabel: 'Cơ hội',
              code: parentCode,
              childLabel: 'Phiếu Test',
              onOpenParent: () => void navigate(`/crm/co-hoi/${parentOpp}`),
              onClear: () => setParams({}),
            }
          : undefined
      }
      groupTree={grouping?.tree}
      onGroupToggle={(key, open) => {
        const spec = grouping?.specs.get(key);
        if (spec) leaves.toggle(key, spec.filters, open);
      }}
      onRowClick={(r) => void navigate(`/crm/phieu-kiem-tra/${r.id}`)}
      kanban={
        board.isPending ? (
          <Spinner label="Đang tải Kanban…" />
        ) : (
          <KanbanBoard
            columns={columns}
            cardKey={(c) => c.id}
            cardLabel={(c) => c.code}
            rule={() => ({ ok: false, reason: BLOCKED })}
            bar={{
              segments: BAR_SEGMENTS.map((s) => ({ ...s })),
              of: barKey,
              counts: (code) => {
                const column = board.data?.find((c) => c.status_code === code);
                return column?.bar
                  ? {
                      upcoming: column.bar.upcoming,
                      today: column.bar.today,
                      overdue: column.bar.overdue,
                    }
                  : undefined;
              },
            }}
            onMove={() => undefined}
            onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
            onLoadMore={() => setPaging({ ...current, more: moreCards + 1 })}
            note={NOTE}
            renderCard={(c) => (
              <TestCard
                card={c}
                catalogs={catalogs}
                meId={claims?.userId ?? null}
                canEdit={canEdit}
                busy={busyId === c.id}
                dayStart={dayStart}
                onStep={(action) => void step(c, action)}
              />
            )}
          />
        )
      }
      calendar={
        <div className="flex flex-col gap-3">
          {calendar.data?.truncated && (
            <Alert tone="warning">
              Khoảng này có {calendar.data.total} phiếu, đang hiện {calendarRows.length}. Thêm bộ
              lọc để thu hẹp.
            </Alert>
          )}
          <CalendarView
            events={events}
            kinds={KINDS}
            mode={calMode}
            onModeChange={setCalMode}
            anchor={anchor}
            onAnchorChange={setAnchor}
            startHour={CALENDAR_START_HOUR}
            endHour={CALENDAR_END_HOUR}
            now={new Date()}
            renderDetail={(event) => {
              const row = calendarRows.find((r) => r.id === event.id);
              return row ? <TestDetail row={row} subtitle={subjectMode(row)} /> : null;
            }}
          />
        </div>
      }
    />
  );
}

function TestCard({
  card,
  catalogs,
  meId,
  canEdit,
  busy,
  dayStart,
  onStep,
}: {
  card: TestBoardCard;
  catalogs: ReturnType<typeof useLeadCatalogs>;
  meId: string | null;
  canEdit: boolean;
  busy: boolean;
  dayStart: Date;
  onStep: (action: 'start' | 'submit') => void;
}) {
  const overdue = card.status_code === 'DRAFT' && new Date(card.scheduled_at) < dayStart;
  const kind = [
    catalogs.name('SUBJECT', card.subject_code),
    catalogs.name('TEST_MODE', card.mode_code),
    catalogs.name('TEST_LEVEL', card.level_code),
  ]
    .filter(Boolean)
    .join(' · ');
  // Nhãn "Tôi": tôi tạo, tôi phụ trách, hoặc tôi chấm bài (bản vẽ TS16b).
  const mine =
    meId !== null &&
    (card.owner_id === meId || card.created_by === meId || card.grader_id === meId);
  return (
    <div className="flex flex-col gap-1.5">
      <Code>{card.code}</Code>
      <Link
        to={`/crm/phieu-kiem-tra/${card.id}`}
        className="font-semibold text-link hover:underline"
      >
        {card.student_name}
      </Link>
      <p className="text-caption text-fg-muted">{kind}</p>
      <p
        className={
          overdue
            ? 'tabular text-caption font-medium text-on-danger-subtle'
            : 'tabular text-caption'
        }
      >
        <Icon name="calendar" size={16} className="mr-1 inline-block align-text-bottom" />
        {formatDateTime(card.scheduled_at)}
        {overdue ? ' · Quá giờ' : ''}
      </p>
      <p className="text-caption text-fg-muted">
        {card.test_branch_code}
        {card.grader_name ? ` · GV chấm: ${card.grader_name}` : ''}
      </p>
      <div className="flex items-center justify-between gap-2">
        {mine ? <Tag tone="brand">Tôi</Tag> : <span />}
        {card.status_code === 'DRAFT' && canEdit && (
          <Button size="sm" variant="primary" loading={busy} onClick={() => onStep('start')}>
            Bắt đầu test
          </Button>
        )}
        {card.status_code === 'TESTING' && canEdit && (
          <Button size="sm" variant="primary" loading={busy} onClick={() => onStep('submit')}>
            Nộp bài
          </Button>
        )}
        {card.status_code === 'COMPLETED' && card.score !== null && (
          <Tag tone="success">{formatScore(card.score)}</Tag>
        )}
      </div>
    </div>
  );
}

function TestDetail({ row, subtitle }: { row: TestRow; subtitle: string }) {
  return (
    <div className="flex w-[320px] max-w-full flex-col gap-2 p-3">
      <div className="flex items-start justify-between gap-2">
        <p className="font-semibold">{row.student_name}</p>
        <Tag tone={TEST_TONE[row.status_code]}>{STATUS_LABEL[row.status_code]}</Tag>
      </div>
      <p className="text-body">
        <Code>{row.code}</Code> {subtitle}
      </p>
      <p className="text-caption text-fg-muted">
        {formatDateTime(row.scheduled_at)} · {row.test_branch_code}
        {row.room_name ? ` · ${row.room_name}` : ''}
        {row.owner_name ? ` · ${row.owner_name}` : ''}
      </p>
      <p className="text-caption text-fg-muted">Tạo {formatDate(row.created_at)}</p>
      <ButtonLink variant="primary" icon="arrowRight" to={`/crm/phieu-kiem-tra/${row.id}`}>
        Mở phiếu {row.code}
      </ButtonLink>
    </div>
  );
}
