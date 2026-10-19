// Khuôn K1 Danh sách: tiêu đề + nút hành động, tìm kiếm, kiểu xem (danh sách, Kanban, Calendar), Ngày, Filters,
// Group By, Favorites, Cột, chip điều kiện, bảng (có nhóm hai cấp), phân trang. Mọi nội dung nghiệp vụ do
// cấu hình truyền vào; khung không viết cứng bộ lọc của màn nào.
import { useState, type ReactNode } from 'react';
import { Button, IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Table, type Column, type SortState, type TableGroup } from '../ui/Data';
import { StateView } from '../ui/Feedback';
import { Icon, type IconName } from '../ui/icons';
import { Select } from '../ui/Overlays';
import { useMedia } from '../ui/useMedia';
import { FavoritesList, SaveFilterForm } from './Favorites';
import { AdvancedDialog, ColumnsPanel, GroupPanel, PanelHost, QuickFilterPanel } from './Panels';
import {
  DATE_PRESETS,
  activeCount,
  buildGroupTree,
  chipsOf,
  clearFilters,
  emptyState,
  removeChip,
  summarize,
  visibleColumnKeys,
} from './state';
import type { ListConfig, ListState, ViewMode } from './types';

const VIEW_ICON: Record<ViewMode, { icon: IconName; label: string }> = {
  list: { icon: 'viewList', label: 'Danh sách' },
  kanban: { icon: 'viewKanban', label: 'Kanban' },
  calendar: { icon: 'calendar', label: 'Calendar' },
};

type Action = {
  label: string;
  icon?: IconName;
  onClick: () => void;
  primary?: boolean;
  loading?: boolean;
};

export function ListScreen<Row>({
  config,
  state,
  onStateChange,
  view,
  onViewChange,
  rows,
  rowKey,
  rowLabel,
  loading = false,
  error,
  onRetry,
  actions = [],
  onRefresh,
  searchHint,
  pager,
  sort,
  onSortChange,
  selected,
  onSelectedChange,
  bulk,
  kanban,
  calendar,
  emptyMessage,
  parent,
  groupTree,
  onGroupToggle,
  rowMuted,
  onRowClick,
}: {
  config: ListConfig<Row>;
  state: ListState;
  onStateChange: (next: ListState) => void;
  view: ViewMode;
  onViewChange: (view: ViewMode) => void;
  rows: Row[];
  rowKey: (row: Row) => string;
  rowLabel: (row: Row) => string;
  loading?: boolean | undefined;
  error?: string | null | undefined;
  onRetry?: (() => void) | undefined;
  actions?: Action[] | undefined;
  onRefresh?: (() => void) | undefined;
  searchHint?: string | undefined;
  /** Phân trang kiểu "1–8 / 8" ở thanh trên; không truyền thì ẩn. */
  pager?:
    | { from: number; to: number; total: number; onPrev?: () => void; onNext?: () => void }
    | undefined;
  sort?: SortState | undefined;
  onSortChange?: ((sort: SortState) => void) | undefined;
  selected?: ReadonlySet<string> | undefined;
  onSelectedChange?: ((selected: Set<string>) => void) | undefined;
  /** Thanh thao tác hàng loạt khi có dòng được chọn. */
  bulk?: ReactNode;
  kanban?: ReactNode;
  calendar?: ReactNode;
  emptyMessage?: { title: string; hint: string } | undefined;
  /**
   * Group By ở máy chủ: cây nhóm do màn dựng từ số đếm của máy chủ (nhóm lá tải dòng khi mở). Có thì khung không tự nhóm
   * `rows` ở trình duyệt, mọi nhóm đóng tới khi mở; `rows` chỉ là các dòng đã tải (để chọn tất cả).
   */
  groupTree?: TableGroup<Row>[] | undefined;
  onGroupToggle?: ((key: string, open: boolean) => void) | undefined;
  /** Dòng làm mờ (bản "Đã gộp": chỉ đọc). */
  rowMuted?: ((row: Row) => boolean) | undefined;
  /** Bấm cả dòng để mở bản ghi (giữ liên kết ở cột tên cho bàn phím, trình đọc màn hình). */
  onRowClick?: ((row: Row) => void) | undefined;
  /**
   * Danh sách mở từ nút liên kết (smart button) của một bản ghi cha: hiện đường dẫn "Cơ hội / CO000121 / Lịch hẹn"
   * (bấm mã để quay lại bản ghi) và chip lọc "Cơ hội: CO000121" (bỏ chip thì bỏ lọc theo bản ghi cha).
   */
  parent?:
    | {
        entityLabel: string;
        code: string;
        childLabel: string;
        onOpenParent: () => void;
        onClear: () => void;
      }
    | undefined;
}) {
  const sheet = useMedia('(max-width: 639px)');
  const [open, setOpen] = useState<'filters' | 'group' | 'cols' | 'fav' | 'save' | null>(null);
  const [advanced, setAdvanced] = useState(false);
  // Điện thoại: thay đổi nằm trong bản nháp tới khi bấm Áp dụng.
  const [draft, setDraft] = useState<ListState>(state);
  const working = sheet ? draft : state;
  const change = (next: ListState) => (sheet ? setDraft(next) : onStateChange(next));
  const openPanel = (name: typeof open) => {
    setDraft(state);
    setOpen(name);
  };
  const close = () => setOpen(null);
  const apply = () => {
    onStateChange(draft);
    close();
  };

  const chips = chipsOf(state, config);
  const columnKeys = visibleColumnKeys(config, state);
  const columns: Column<Row>[] = columnKeys.flatMap((key) => {
    const c = config.columns.find((x) => x.key === key);
    return c
      ? [
          {
            key: c.key,
            header: c.label,
            cell: c.render,
            numeric: c.numeric,
            sortable: c.sortable,
            primary: c.primary,
          },
        ]
      : [];
  });
  const tree =
    groupTree ??
    (state.group.length > 0 ? buildGroupTree(rows, state.group, config.groupFields) : undefined);

  const sheetFooter = (
    <>
      <Button
        onClick={() => {
          setDraft(clearFilters(draft));
        }}
      >
        Xoá lọc
      </Button>
      <Button variant="primary" onClick={apply}>
        Áp dụng
      </Button>
    </>
  );
  const colsFooter = (
    <Button variant="primary" onClick={apply}>
      Áp dụng
    </Button>
  );

  const triggerClass = 'w-full';
  const filterButtons = (
    <>
      <PanelHost
        sheet={sheet}
        open={open === 'filters'}
        onOpenChange={(o) => (o ? openPanel('filters') : close())}
        title="Filters"
        footer={sheetFooter}
        trigger={
          <Button icon="filter" className={sheet ? triggerClass : undefined}>
            Filters
          </Button>
        }
      >
        <QuickFilterPanel
          config={config}
          state={working}
          onChange={change}
          onAdvanced={() => {
            close();
            setAdvanced(true);
          }}
        />
      </PanelHost>
      <PanelHost
        sheet={sheet}
        open={open === 'group'}
        onOpenChange={(o) => (o ? openPanel('group') : close())}
        title="Group By"
        footer={sheetFooter}
        trigger={
          <Button icon="groupBy" className={sheet ? triggerClass : undefined}>
            Group By
          </Button>
        }
      >
        <GroupPanel config={config} state={working} onChange={change} />
      </PanelHost>
      <PanelHost
        sheet={sheet}
        open={open === 'fav' || open === 'save'}
        onOpenChange={(o) => (o ? openPanel('fav') : close())}
        title="Favorites"
        width="w-[22rem]"
        trigger={
          <Button icon="star" className={sheet ? triggerClass : undefined}>
            Favorites
          </Button>
        }
      >
        {open === 'save' ? (
          <SaveFilterForm
            screenCode={config.screenCode}
            state={state}
            summary={summarize(state, config)}
            onDone={close}
          />
        ) : (
          <FavoritesList
            screenCode={config.screenCode}
            onApply={(filters) => {
              onStateChange({ ...emptyState(config), ...filters });
              close();
            }}
            onSaveCurrent={() => setOpen('save')}
          />
        )}
      </PanelHost>
    </>
  );

  const visibleView = config.views.includes(view) ? view : 'list';

  return (
    <div className="flex flex-col gap-3">
      {parent && (
        <nav aria-label="Đường dẫn" className="text-body text-fg-muted">
          <ol className="flex flex-wrap items-center gap-1.5">
            <li>{parent.entityLabel}</li>
            <Icon name="chevronRight" size={16} />
            <li>
              <button
                type="button"
                onClick={parent.onOpenParent}
                className="focus-ring rounded-tag font-medium text-link hover:underline"
              >
                {parent.code}
              </button>
            </li>
            <Icon name="chevronRight" size={16} />
            <li aria-current="page" className="font-semibold text-fg">
              {parent.childLabel}
            </li>
          </ol>
        </nav>
      )}
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="mr-1 font-display text-h2">{config.title}</h1>
        {actions.map((a) => (
          <Button
            key={a.label}
            variant={a.primary ? 'primary' : 'secondary'}
            icon={a.icon}
            loading={a.loading}
            onClick={a.onClick}
          >
            {a.label}
          </Button>
        ))}
        <div className="relative order-last min-w-60 flex-1 basis-full md:order-none md:basis-0">
          <Icon
            name="search"
            size={16}
            className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-fg-muted"
          />
          <input
            type="search"
            aria-label={searchHint ?? config.searchPlaceholder}
            placeholder={config.searchPlaceholder}
            value={state.search}
            onChange={(e) => onStateChange({ ...state, search: e.target.value })}
            className="focus-ring tap h-[34px] w-full rounded-control border border-border-strong bg-surface pr-2.5 pl-8 text-body placeholder:text-fg-muted focus-visible:border-focus"
          />
        </div>
        <div className="ml-auto flex items-center gap-2">
          {onRefresh && (
            <Button icon="refresh" onClick={onRefresh}>
              Làm mới
            </Button>
          )}
          {visibleView === 'list' && (
            <PanelHost
              sheet={sheet}
              open={open === 'cols'}
              onOpenChange={(o) => (o ? openPanel('cols') : close())}
              title="Cột hiển thị"
              footer={colsFooter}
              trigger={<Button icon="columns">Cột</Button>}
            >
              <ColumnsPanel config={config} state={working} onChange={change} />
            </PanelHost>
          )}
          {config.views.length > 1 && (
            <div
              role="group"
              aria-label="Kiểu xem"
              className="inline-flex overflow-hidden rounded-control border border-border-strong"
            >
              {config.views.map((v) => (
                <button
                  key={v}
                  type="button"
                  aria-pressed={visibleView === v}
                  aria-label={VIEW_ICON[v].label}
                  title={VIEW_ICON[v].label}
                  onClick={() => onViewChange(v)}
                  className={cn(
                    'focus-ring tap flex size-[34px] items-center justify-center border-r border-border last:border-r-0 max-md:size-11',
                    visibleView === v ? 'bg-selected text-brand-800' : 'bg-surface hover:bg-hover',
                  )}
                >
                  <Icon name={VIEW_ICON[v].icon} />
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {config.dateFields.length > 0 && (
          <div className="inline-flex gap-0">
            <Select
              label="Trường ngày"
              icon="calendar"
              value={state.dateField}
              onChange={(dateField) => onStateChange({ ...state, dateField })}
              options={config.dateFields.map((f) => ({ value: f.key, label: f.label }))}
              className="rounded-r-none"
            />
            <Select
              label="Khoảng thời gian"
              value={state.datePreset === '' ? 'all' : state.datePreset}
              onChange={(v) => onStateChange({ ...state, datePreset: v === 'all' ? '' : v })}
              options={DATE_PRESETS.map((p) => ({
                value: p.key === '' ? 'all' : p.key,
                label: p.label,
              }))}
              className="-ml-px rounded-l-none"
            />
          </div>
        )}
        <div className={cn('ml-auto flex flex-wrap items-center gap-2', sheet && 'w-full')}>
          {sheet ? (
            <div className="grid w-full grid-cols-3 gap-2">{filterButtons}</div>
          ) : (
            filterButtons
          )}
          {pager && (
            <div
              className="tabular flex items-center gap-1 text-body text-fg-label"
              aria-live="polite"
            >
              <span>
                {pager.from}–{pager.to} / {pager.total}
              </span>
              <IconButton
                icon="chevronLeft"
                label="Trang trước"
                disabled={!pager.onPrev}
                onClick={pager.onPrev}
              />
              <IconButton
                icon="chevronRight"
                label="Trang sau"
                disabled={!pager.onNext}
                onClick={pager.onNext}
              />
            </div>
          )}
        </div>
      </div>

      {(chips.length > 0 || parent) && (
        <div
          className="flex flex-wrap items-center gap-2 border-t border-surface-subtle pt-2"
          aria-label="Điều kiện đang áp dụng"
        >
          {parent && (
            <span className="inline-flex h-control-sm items-center gap-1 rounded-full border border-brand-200 bg-brand-50 pr-1 pl-2.5 text-caption font-medium text-brand-800">
              {parent.entityLabel}: {parent.code}
              <button
                type="button"
                aria-label={`Bỏ điều kiện: ${parent.entityLabel}: ${parent.code}`}
                onClick={parent.onClear}
                className="focus-ring inline-flex size-5 items-center justify-center rounded-full hover:bg-selected"
              >
                <Icon name="close" size={16} />
              </button>
            </span>
          )}
          {chips.map((chip) => (
            <span
              key={chip.id}
              className={cn(
                'inline-flex h-control-sm items-center gap-1 rounded-full border pr-1 pl-2.5 text-caption font-medium',
                chip.kind === 'group'
                  ? 'border-info-border bg-info-subtle text-on-info-subtle'
                  : chip.kind === 'search' || chip.kind === 'date'
                    ? 'border-border bg-surface-subtle text-fg'
                    : 'border-brand-200 bg-brand-50 text-brand-800',
              )}
            >
              {chip.label}
              <button
                type="button"
                aria-label={`Bỏ điều kiện: ${chip.label}`}
                onClick={() => onStateChange(removeChip(state, chip.id))}
                className="focus-ring inline-flex size-5 items-center justify-center rounded-full hover:bg-selected"
              >
                <Icon name="close" size={16} />
              </button>
            </span>
          ))}
          <span className="ml-auto flex items-center gap-4">
            <Button variant="text" onClick={() => onStateChange(clearFilters(state))}>
              Xoá tất cả
            </Button>
            <Button variant="text" onClick={() => openPanel('fav')}>
              Save to Favorites
            </Button>
          </span>
        </div>
      )}
      <p className="sr-only" aria-live="polite">
        {activeCount(state, config)} điều kiện đang áp dụng
      </p>

      {bulk}

      {error ? (
        <div className="rounded-box border border-border bg-surface">
          <StateView
            kind="error"
            title="Không tải được danh sách"
            headingLevel={2}
            actions={onRetry && <Button onClick={onRetry}>Thử lại</Button>}
          >
            {error}
          </StateView>
        </div>
      ) : visibleView === 'kanban' && kanban ? (
        kanban
      ) : visibleView === 'calendar' && calendar ? (
        calendar
      ) : (
        <Table
          caption={config.title}
          columns={columns}
          rows={rows}
          rowKey={rowKey}
          rowLabel={rowLabel}
          loading={loading}
          groups={tree}
          groupsDefaultOpen={groupTree === undefined}
          onGroupToggle={onGroupToggle}
          rowMuted={rowMuted}
          onRowClick={onRowClick}
          sort={sort}
          onSortChange={onSortChange}
          selected={selected}
          onSelectedChange={onSelectedChange}
          empty={
            <StateView
              kind="empty"
              title={
                chips.length > 0
                  ? 'Không có kết quả khớp bộ lọc'
                  : parent
                    ? `Chưa có ${parent.childLabel.toLowerCase()}`
                    : (emptyMessage?.title ?? 'Chưa có dữ liệu')
              }
              headingLevel={2}
              actions={
                chips.length > 0 ? (
                  <Button onClick={() => onStateChange(clearFilters(state))}>Xoá bộ lọc</Button>
                ) : undefined
              }
            >
              {chips.length > 0
                ? 'Thử bớt điều kiện hoặc đổi từ khoá.'
                : parent
                  ? `${parent.entityLabel} ${parent.code} chưa có ${parent.childLabel.toLowerCase()} nào.`
                  : (emptyMessage?.hint ?? 'Khi có dữ liệu, danh sách sẽ hiện ở đây.')}
            </StateView>
          }
        />
      )}

      <AdvancedDialog
        open={advanced}
        onOpenChange={setAdvanced}
        config={config}
        conditions={state.conditions}
        onApply={(conditions) => onStateChange({ ...state, conditions })}
      />
    </div>
  );
}
