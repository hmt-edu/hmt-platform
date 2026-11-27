// TS-01 Lead (danh sách) và TS-01b (Kanban): khuôn K1 và K2 nối với các hàm Lead trong cơ sở dữ liệu.
// Lọc, sắp xếp, phân trang, Group By, số đếm Kanban đều tính ở máy chủ; trình duyệt chỉ giữ trang đang xem.
// Nút Tạo, Nhập và dấu "+" ở cột C1 hiện cho ai có quyền Lead · Tạo (Tạo mở màn Tạo, P3c-2; Nhập mở hộp TS-04, P3f; CSKH nhập được).
import { useMemo, useRef, useState } from 'react';
import { AssignDialog } from '../../features/assign/AssignDialog';
import { KanbanBoard } from '../../list/Kanban';
import { freeMoveRule } from '../../list/kanbanLogic';
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
import { ImportLeadsDialog } from './ImportLeadsDialog';
import { importSummary } from './importMapping';
import { downloadText, toCsv } from './csv';
import { buildLeadGroupTree } from './leadGroups';
import { EMPTY_LEAD_STATE, buildLeadConfig } from './leadConfig';
import { GROUP_FIELD_OF, buildLeadFilters, nextSort, sortParam } from './leadFilters';
import { appointmentTag, formatPhone, leadTitle } from './leadFormat';
import type { BoardCard, BoardColumn, LeadRow } from './leadTypes';
import { useLeadCatalogs } from './useCatalogs';
import { LeadStageDialog } from './LeadStageDialog';
import { canRestore, selectableSubstages } from './leadStage';
import {
  assignLeads,
  changeLeadStage,
  exportLeads,
  useGroupCounts,
  useLeadBoard,
  useLeadPage,
  useLeafRows,
  useRefreshLeads,
} from './useLeadData';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { FromLink } from '../../layout/FromLink';

const NOTE =
  'Lead kéo thả tự do hai chiều giữa C1–C4, mọi lần đổi đều ghi lịch sử. C4D do hệ thống tự gắn khi tạo cơ hội thành công.';

/** Giai đoạn con do hệ thống gắn (R-CRM-09): đã rời khỏi thì không đặt lại bằng tay, nên không có Hoàn tác. */

const BAR_SEGMENTS = [
  { key: 'upcoming', label: 'Sắp tới', tone: 'success' },
  { key: 'today', label: 'Hôm nay', tone: 'warning' },
  { key: 'overdue', label: 'Quá hạn', tone: 'danger' },
  { key: 'none', label: 'Chưa có lịch', tone: 'neutral' },
] as const;

const EXPORT_COLUMNS = [
  { key: 'code', label: 'Mã' },
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

export function LeadListPage() {
  const supabase = useDb();
  const openFrom = useNavigateFrom();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshLeads();
  const catalogs = useLeadCatalogs();
  const config = useMemo(() => buildLeadConfig(catalogs, access), [catalogs, access]);

  const pageSize = useIntSetting('list_page_size_default');
  const maxPage = useIntSetting('list_page_size_max');
  const cardsPerColumn = useIntSetting('kanban_cards_per_column');

  const [state, setState] = useState<ListState>(EMPTY_LEAD_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [sort, setSort] = useState<SortState>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  // Mã và cơ sở của các dòng đã chọn (hộp Giao nêu mã dù đổi trang hay nhóm); cập nhật khi chọn.
  const [selectedInfo, setSelectedInfo] = useState<Map<string, { code: string; branch: string }>>(
    new Map(),
  );
  // Trang và số thẻ Kanban đã tải thêm gắn với bộ lọc: đổi bộ lọc hay sắp xếp thì về trang đầu (không cần effect).
  const [paging, setPaging] = useState({ key: '', page: 0, more: 0 });
  const [assignOpen, setAssignOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [tick, setTick] = useState(0);
  const moving = useRef(false);
  // Thẻ đang chờ chọn nhóm con của giai đoạn đích (R-CRM-41).
  const [stageMove, setStageMove] = useState<{
    card: BoardCard;
    from: string;
    to: string;
    fromName: string;
  } | null>(null);

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildLeadFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
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

  const list = useLeadPage(
    filters,
    sortValue,
    page * (pageSize ?? 0),
    pageSize,
    view === 'list' && !grouped,
  );
  const counts = useGroupCounts(filters, groupFields, view === 'list');
  const cardLimit =
    cardsPerColumn === null
      ? null
      : Math.min(cardsPerColumn * (moreCards + 1), maxPage ?? cardsPerColumn);
  const board = useLeadBoard(filters, cardLimit, view === 'kanban');
  const leaves = useLeafRows(
    filters,
    sortValue,
    pageSize,
    `${filtersKey}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
  );

  // Nhóm: số đếm từ máy chủ, dòng tải khi mở từng nhóm lá.
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree(counts.data, groupFields, leaves.leaves, (key, spec) =>
            leaves.more(key, spec.filters),
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );

  const listRows: LeadRow[] = useMemo(
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
      const result = await exportLeads(supabase, filters);
      const rows = result.rows.map((r) => ({
        ...r,
        next_appointment_at: r.next_appointment_at
          ? formatDateTime(String(r.next_appointment_at))
          : '',
        created_at: formatDateTime(String(r.created_at)),
        record_status:
          r.record_status === 'DA_GOP'
            ? 'Đã gộp'
            : r.record_status === 'DA_HUY'
              ? 'Đã huỷ'
              : 'Đang dùng',
      }));
      downloadText(`lead-${vnDayBounds().dateKey}.csv`, toCsv(rows, EXPORT_COLUMNS));
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

  // Chuyển thẻ (kéo thả hoặc menu ⋮): giai đoạn có nhóm con chọn tay thì hỏi nhóm con trước (R-CRM-41), không thì đổi luôn.
  function requestMove(card: BoardCard, from: string, to: string, fromName: string) {
    if (moving.current) return;
    if (from === to) return;
    if (selectableSubstages(catalogs, to).length > 0) setStageMove({ card, from, to, fromName });
    else void moveCard(card, from, to, fromName, null);
  }

  async function moveCard(
    card: BoardCard,
    from: string,
    to: string,
    fromName: string,
    substage: string | null,
    throwOnError = false,
  ) {
    if (moving.current) return;
    moving.current = true;
    const previousSubstage = card.substage_code;
    try {
      // Nhóm con do người dùng chọn (R-CRM-41); C4D không bao giờ do người đặt (R-CRM-09).
      await changeLeadStage(supabase, card.id, to, substage);
      refresh();
      const canUndo = canRestore(catalogs, from, previousSubstage);
      toast({
        title: `Đã chuyển ${card.code} sang ${to}.`,
        ...(canUndo
          ? {
              action: {
                label: 'Hoàn tác',
                onClick: () => {
                  void changeLeadStage(supabase, card.id, from, previousSubstage)
                    .then(() => {
                      refresh();
                      toast({ title: `Đã hoàn tác, ${card.code} về ${fromName}.` });
                    })
                    .catch((e: unknown) =>
                      toast({
                        tone: 'danger',
                        title: errorOf(e).message,
                      }),
                    );
                },
              },
            }
          : {}),
      });
    } catch (e) {
      if (throwOnError) throw e;
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      moving.current = false;
    }
  }

  const toggleAppointment = (key: string) => {
    const current = state.quick.appt ?? [];
    const next = current.includes(key) ? current.filter((v) => v !== key) : [...current, key];
    const quick = { ...state.quick };
    if (next.length === 0) delete quick.appt;
    else quick.appt = next;
    setState({ ...state, quick });
  };

  const columns = (board.data ?? []).map((c: BoardColumn) => ({
    code: c.stage_code,
    label: `${c.stage_code} ${c.name}`,
    cards: c.rows,
    total: c.total,
  }));
  const shownCards = columns.reduce((sum, c) => sum + c.cards.length, 0);
  const boardTotal = columns.reduce((sum, c) => sum + (c.total ?? 0), 0);

  const selectedCodes = [...selectedInfo.values()].map((i) => i.code);
  const selectedBranches = [...selectedInfo.values()].map((i) => i.branch);

  const canExport = access.can('LEAD', 'XUAT');
  const canAssign = access.can('LEAD', 'GIAO_VIEC');
  const canCreate = access.can('LEAD', 'TAO');

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
        actions={[
          ...(canCreate
            ? [
                {
                  label: 'Tạo',
                  icon: 'plus' as const,
                  primary: true,
                  onClick: () => openFrom('/crm/lead/moi'),
                },
              ]
            : []),
          ...(canCreate
            ? [
                {
                  label: 'Nhập',
                  icon: 'upload' as const,
                  onClick: () => setImportOpen(true),
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
        onSortChange={(next) => setSort(nextSort(next))}
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
        emptyMessage={{ title: 'Chưa có lead', hint: 'Khi có lead, danh sách sẽ hiện ở đây.' }}
        groupTree={grouping?.tree}
        onGroupToggle={(key, open) => {
          const spec = grouping?.specs.get(key);
          if (spec) leaves.toggle(key, spec.filters, open);
        }}
        rowMuted={(r) => r.record_status !== 'DANG_DUNG'}
        onRowClick={(r) => openFrom(`/crm/lead/${r.id}`)}
        kanban={
          board.isPending ? (
            <Spinner label="Đang tải Kanban…" />
          ) : (
            <KanbanBoard
              columns={columns}
              cardKey={(c) => c.id}
              cardLabel={(c) => c.code}
              rule={freeMoveRule()}
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
              onMove={(card, from, to) =>
                requestMove(card, from, to, columns.find((c) => c.code === from)?.label ?? from)
              }
              onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
              onLoadMore={() => setPaging({ ...current, more: moreCards + 1 })}
              {...(canCreate
                ? {
                    onAdd: () => openFrom('/crm/lead/moi'),
                    // Lead mới luôn bắt đầu ở C1 (R-CRM-39): dấu "+" chỉ ở cột đầu.
                    showAdd: (code: string) => code === columns[0]?.code,
                  }
                : {})}
              note={NOTE}
              renderCard={(c) => <LeadCard card={c} catalogs={catalogs} />}
            />
          )
        }
      />
      {stageMove && (
        <LeadStageDialog
          open
          onOpenChange={(open) => !open && setStageMove(null)}
          subtitle={`${stageMove.card.code} · đang ở ${stageMove.fromName}`}
          stageLabel={columns.find((c) => c.code === stageMove.to)?.label ?? stageMove.to}
          stageCode={stageMove.to}
          options={selectableSubstages(catalogs, stageMove.to)}
          onSubmit={(substage) =>
            moveCard(
              stageMove.card,
              stageMove.from,
              stageMove.to,
              stageMove.fromName,
              substage,
              true,
            )
          }
        />
      )}
      <ImportLeadsDialog
        open={importOpen}
        onOpenChange={setImportOpen}
        onImported={(result) => {
          void refreshData();
          toast({ title: importSummary(result) });
        }}
      />
      <AssignDialog
        open={assignOpen}
        onOpenChange={setAssignOpen}
        entityType="LEAD"
        noun="lead"
        codes={selectedCodes}
        branchCodes={selectedBranches}
        onAssign={async (ownerId, ownerName) => {
          const n = await assignLeads(supabase, [...selected], ownerId);
          select(new Set());
          refresh();
          toast({ title: `Đã giao ${n} lead cho ${ownerName}.` });
        }}
      />
    </>
  );
}

function LeadCard({
  card,
  catalogs,
}: {
  card: BoardCard;
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
      <FromLink to={`/crm/lead/${card.id}`} className="font-semibold hover:underline">
        {leadTitle(card)}
      </FromLink>
      <p className="text-caption text-fg-muted">
        {formatPhone(card.parent_phone)} · {card.branch_code}
      </p>
      {source && <p className="text-caption text-fg-muted">{source}</p>}
      {card.substage_code && (
        <span>
          <Tag tone="brand">
            {card.substage_code} {catalogs.name('LEAD_SUBSTAGE', card.substage_code)}
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
