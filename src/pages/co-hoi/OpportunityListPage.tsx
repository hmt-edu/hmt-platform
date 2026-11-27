// TS-07 Cơ hội (danh sách) và Kanban L1–L8: khuôn K1 và K2 nối với các hàm Cơ hội trong cơ sở dữ liệu.
// Lọc, sắp xếp, phân trang, Group By, số đếm Kanban đều tính ở máy chủ; trình duyệt chỉ giữ trang đang xem.
// Không có nút Tạo (cơ hội chỉ tạo từ trang Lead, TS-06) và Nhập (P3f). Kéo thẻ Kanban chỉ đi tới (R-CRM-02), L6 do hệ thống
// chuyển (R-CRM-13); thả vào cột hợp lệ mở hộp TS-09.
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router';
import { AssignDialog } from '../../features/assign/AssignDialog';
import { KanbanBoard } from '../../list/Kanban';
import { forwardOnlyRule } from '../../list/kanbanLogic';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { BulkActionBar, Code, Tag, type SortState } from '../../ui/Data';
import { Avatar, Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { downloadText, toCsv } from '../lead/csv';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { GROUP_FIELD_OF, buildLeadFilters } from '../lead/leadFilters';
import { appointmentTag, codeAndName, formatPhone } from '../lead/leadFormat';
import { useLeafRows } from '../lead/useLeadData';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { EMPTY_OPP_STATE, buildOppConfig, oppTitle } from './oppConfig';
import { OPP_STAGE_ORDER, SYSTEM_STAGE } from './oppStage';
import type { OppBoardCard, OppBoardColumn, OpportunityRow } from './oppTypes';
import { StageMoveHost } from './StageMoveHost';
import {
  assignOpportunities,
  exportOpportunities,
  useOppBoard,
  useOppGroupCounts,
  useOppPage,
  useRefreshOpps,
} from './useOppData';
import { FromLink } from '../../layout/FromLink';

const NOTE =
  'Cơ hội chỉ đi tới, không lùi. L6 do hệ thống chuyển khi phiếu Test Hoàn thành; L8 chọn tay sau khi đã thu tiền. Kéo thẻ vào cột phía trước thì hiện hộp chuyển giai đoạn.';

const BAR_SEGMENTS = [
  { key: 'upcoming', label: 'Sắp tới', tone: 'success' },
  { key: 'today', label: 'Hôm nay', tone: 'warning' },
  { key: 'overdue', label: 'Quá hạn', tone: 'danger' },
  { key: 'none', label: 'Chưa có lịch', tone: 'neutral' },
] as const;

const EXPORT_COLUMNS = [
  { key: 'code', label: 'Mã' },
  { key: 'lead', label: 'Lead gốc' },
  { key: 'parent_name', label: 'Phụ huynh' },
  { key: 'parent_phone', label: 'SĐT' },
  { key: 'student_name', label: 'Học sinh' },
  { key: 'student_birth_year', label: 'Năm sinh' },
  { key: 'school', label: 'Trường' },
  { key: 'need', label: 'Nhu cầu' },
  { key: 'source_type', label: 'Loại nguồn' },
  { key: 'source', label: 'Source' },
  { key: 'channel', label: 'Sub-source' },
  { key: 'campaign', label: 'Chiến dịch' },
  { key: 'stage', label: 'Stage' },
  { key: 'substage', label: 'Sub-stage' },
  { key: 'owner', label: 'Sale phụ trách' },
  { key: 'supporter', label: 'Người hỗ trợ' },
  { key: 'branch', label: 'Cơ sở' },
  { key: 'next_appointment_at', label: 'Lịch hẹn kế tiếp' },
  { key: 'created_at', label: 'Ngày tạo' },
  { key: 'record_status', label: 'Trạng thái' },
];

/** Sắp xếp: các kiểu máy chủ hỗ trợ (mới nhất, cũ nhất, lịch hẹn gần nhất, tên học sinh A-Z); khác thì mặc định. */
function sortParam(sort: SortState): string | undefined {
  if (!sort) return undefined;
  if (sort.key === 'created') return sort.direction === 'asc' ? 'created_asc' : 'created_desc';
  if (sort.key === 'next' && sort.direction === 'asc') return 'next_appointment_asc';
  if (sort.key === 'opportunity' && sort.direction === 'asc') return 'name_asc';
  return undefined;
}

export function OpportunityListPage() {
  const supabase = useDb();
  const openFrom = useNavigateFrom();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshOpps();
  const catalogs = useLeadCatalogs();
  const config = useMemo(() => buildOppConfig(catalogs, access), [catalogs, access]);

  const pageSize = useIntSetting('list_page_size_default');
  const maxPage = useIntSetting('list_page_size_max');
  const cardsPerColumn = useIntSetting('kanban_cards_per_column');

  // Mở từ nút "Cơ hội" của trang Lead: chỉ cơ hội của lead đó (bỏ chip thì về danh sách chung).
  const [params, setParams] = useSearchParams();
  const parentLead = params.get('lead');
  const parentCode = params.get('ma') ?? '';
  const [state, setState] = useState<ListState>(EMPTY_OPP_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [selectedInfo, setSelectedInfo] = useState<Map<string, { code: string; branch: string }>>(
    new Map(),
  );
  const [paging, setPaging] = useState({ key: '', page: 0, more: 0 });
  const [assignOpen, setAssignOpen] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [tick, setTick] = useState(0);
  const [moving, setMoving] = useState<{ id: string; to: string } | null>(null);

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => ({
      ...buildLeadFilters({ ...state, search: debouncedSearch }),
      ...(parentLead ? { lead_id: parentLead } : {}),
    }),
    [state, debouncedSearch, parentLead],
  );
  const filtersKey = JSON.stringify(filters);
  const sortValue = sortParam(sort);
  const groupFields = state.group.flatMap((k) => (GROUP_FIELD_OF[k] ? [GROUP_FIELD_OF[k]] : []));
  const grouped = groupFields.length > 0;

  const pagingKey = `${filtersKey}|${sortValue}`;
  const current = paging.key === pagingKey ? paging : { key: pagingKey, page: 0, more: 0 };
  const page = current.page;
  const moreCards = current.more;
  const setPage = (next: number) => setPaging({ ...current, page: next });

  const list = useOppPage(
    filters,
    sortValue,
    page * (pageSize ?? 0),
    pageSize,
    view === 'list' && !grouped,
  );
  const counts = useOppGroupCounts(filters, groupFields, view === 'list');
  const cardLimit =
    cardsPerColumn === null
      ? null
      : Math.min(cardsPerColumn * (moreCards + 1), maxPage ?? cardsPerColumn);
  const board = useOppBoard(filters, cardLimit, view === 'kanban');
  const leaves = useLeafRows<OpportunityRow>(
    filters,
    sortValue,
    pageSize,
    `${filtersKey}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_opportunities',
  );

  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<OpportunityRow>(counts.data, groupFields, leaves.leaves, (key, spec) =>
            leaves.more(key, spec.filters),
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );

  const listRows: OpportunityRow[] = useMemo(
    () =>
      grouping
        ? grouping.tree
            .flatMap((g) => (g.children.length > 0 ? g.children : [g]))
            .flatMap((g) => g.rows)
        : (list.data?.rows ?? []),
    [grouping, list.data],
  );

  const select = (next: Set<string>) => {
    setSelected(next);
    setSelectedInfo((prev) => {
      const info = new Map<string, { code: string; branch: string }>();
      for (const id of next) {
        const row = listRows.find((r) => r.id === id);
        const old = prev.get(id);
        if (row) info.set(id, { code: row.code, branch: row.branch_code });
        else if (old) info.set(id, old);
      }
      return info;
    });
  };

  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = view === 'kanban' ? board : grouped ? counts : list;
  const errorText = activeQuery.isError ? errorOf(activeQuery.error).message : null;

  const refresh = () => {
    setTick((t) => t + 1);
    void refreshData();
  };

  async function exportFile() {
    if (exporting) return;
    setExporting(true);
    try {
      const result = await exportOpportunities(supabase, filters);
      const rows = result.rows.map((r) => ({
        ...r,
        next_appointment_at: r.next_appointment_at
          ? formatDateTime(String(r.next_appointment_at))
          : '',
        created_at: formatDateTime(String(r.created_at)),
        record_status: r.record_status === 'DA_GOP' ? 'Đã gộp' : 'Đang dùng',
      }));
      downloadText(`co-hoi-${vnDayBounds().dateKey}.csv`, toCsv(rows, EXPORT_COLUMNS));
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

  const toggleAppointment = (key: string) => {
    const currentKeys = state.quick.appt ?? [];
    const next = currentKeys.includes(key)
      ? currentKeys.filter((v) => v !== key)
      : [...currentKeys, key];
    const quick = { ...state.quick };
    if (next.length === 0) delete quick.appt;
    else quick.appt = next;
    setState({ ...state, quick });
  };

  const columns = (board.data ?? []).map((c: OppBoardColumn) => ({
    code: c.stage_code,
    label: `${c.stage_code} ${c.name}`,
    cards: c.rows,
    total: c.total,
  }));
  const shownCards = columns.reduce((sum, c) => sum + c.cards.length, 0);
  const boardTotal = columns.reduce((sum, c) => sum + (c.total ?? 0), 0);

  const selectedCodes = [...selectedInfo.values()].map((i) => i.code);
  const selectedBranches = [...selectedInfo.values()].map((i) => i.branch);

  const canExport = access.can('OPPORTUNITY', 'XUAT');
  const canAssign = access.can('OPPORTUNITY', 'GIAO_VIEC');
  const canEdit = access.can('OPPORTUNITY', 'SUA');

  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={listRows}
        rowKey={(r) => r.id}
        rowLabel={(r) => `${r.code} ${r.parent_name}`}
        loading={
          view === 'kanban'
            ? board.isPending
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
            : grouped
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
        onSortChange={(next) => setSort(next && sortParam(next) ? next : null)}
        selected={selected}
        onSelectedChange={select}
        bulk={
          view === 'list' ? (
            <BulkActionBar count={selected.size} onClear={() => select(new Set())}>
              {canAssign && (
                <Button icon="user" onClick={() => setAssignOpen(true)}>
                  Assign
                </Button>
              )}
            </BulkActionBar>
          ) : undefined
        }
        emptyMessage={{
          title: 'Chưa có cơ hội',
          hint: 'Cơ hội được tạo từ trang Lead. Khi có cơ hội, danh sách sẽ hiện ở đây.',
        }}
        parent={
          parentLead
            ? {
                entityLabel: 'Lead',
                code: parentCode,
                childLabel: 'Cơ hội',
                onOpenParent: () => void openFrom(`/crm/lead/${parentLead}`),
                onClear: () => setParams({}),
              }
            : undefined
        }
        groupTree={grouping?.tree}
        onGroupToggle={(key, open) => {
          const spec = grouping?.specs.get(key);
          if (spec) leaves.toggle(key, spec.filters, open);
        }}
        rowMuted={(r) => r.record_status === 'DA_GOP'}
        onRowClick={(r) => openFrom(`/crm/co-hoi/${r.id}`)}
        kanban={
          board.isPending ? (
            <Spinner label="Đang tải Kanban…" />
          ) : (
            <KanbanBoard
              columns={columns}
              cardKey={(c) => c.id}
              cardLabel={(c) => c.code}
              rule={forwardOnlyRule(OPP_STAGE_ORDER, [SYSTEM_STAGE])}
              bar={{
                segments: BAR_SEGMENTS.map((s) => ({ ...s })),
                of: (c) => {
                  const tag = appointmentTag(c.next_appointment_at);
                  return tag.tone === 'danger'
                    ? 'overdue'
                    : tag.tone === 'warning'
                      ? 'today'
                      : tag.tone === 'success'
                        ? 'upcoming'
                        : 'none';
                },
                counts: (code) => {
                  const bar = board.data?.find((c) => c.stage_code === code)?.bar;
                  return bar
                    ? { upcoming: bar.ok, today: bar.today, overdue: bar.overdue, none: bar.none }
                    : undefined;
                },
              }}
              barActive={state.quick.appt ?? []}
              onBarSelect={toggleAppointment}
              onMove={(card, _from, to) => {
                if (!canEdit) {
                  toast({ tone: 'warning', title: 'Bạn không có quyền đổi giai đoạn cơ hội.' });
                  return;
                }
                setMoving({ id: card.id, to });
              }}
              onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
              onLoadMore={() => setPaging({ ...current, more: moreCards + 1 })}
              note={NOTE}
              renderCard={(c) => <OppCard card={c} catalogs={catalogs} />}
            />
          )
        }
      />
      {moving && (
        <StageMoveHost
          key={`${moving.id}:${moving.to}`}
          id={moving.id}
          target={moving.to}
          onClose={() => setMoving(null)}
          onDone={(stageName) => {
            setMoving(null);
            refresh();
            toast({ title: `Đã chuyển sang ${stageName}.` });
          }}
          onFillMissing={(id) => openFrom(`/crm/co-hoi/${id}`)}
          onOpenTest={(testId) => openFrom(`/crm/phieu-kiem-tra/${testId}`)}
        />
      )}
      <AssignDialog
        open={assignOpen}
        onOpenChange={setAssignOpen}
        entityType="OPPORTUNITY"
        noun="cơ hội"
        codes={selectedCodes}
        branchCodes={selectedBranches}
        onAssign={async (ownerId, ownerName) => {
          const n = await assignOpportunities(supabase, [...selected], ownerId);
          select(new Set());
          refresh();
          toast({ title: `Đã giao ${n} cơ hội cho ${ownerName}.` });
        }}
      />
    </>
  );
}

function OppCard({
  card,
  catalogs,
}: {
  card: OppBoardCard;
  catalogs: ReturnType<typeof useLeadCatalogs>;
}) {
  const tag = appointmentTag(card.next_appointment_at);
  const source = [
    catalogs.name('SOURCE', card.source_code),
    catalogs.name('SOURCE_CHANNEL', card.channel_code),
  ]
    .filter(Boolean)
    .join(' · ');
  return (
    <div className="flex flex-col gap-1.5">
      <Code>{card.code}</Code>
      <FromLink to={`/crm/co-hoi/${card.id}`} className="font-semibold hover:underline">
        {oppTitle(card)}
      </FromLink>
      <p className="text-caption text-fg-muted">
        {formatPhone(card.parent_phone)} · {card.branch_code}
      </p>
      {source && <p className="text-caption text-fg-muted">{source}</p>}
      {card.substage_code && (
        <span>
          <Tag tone="brand">
            {codeAndName(card.substage_code, catalogs.name('OPP_SUBSTAGE', card.substage_code))}
          </Tag>
        </span>
      )}
      <div className="flex items-center justify-between gap-2">
        <Tag tone={tag.tone} dot>
          {tag.label}
        </Tag>
        {card.owner_name && <Avatar name={card.owner_name} />}
      </div>
    </div>
  );
}
