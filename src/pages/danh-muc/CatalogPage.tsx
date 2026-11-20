// QT-06 Danh mục (cột trái: danh sách danh mục, tìm theo tên) và QT-07 (bảng bên phải: sửa các mục), khuôn K10. Canvas bổ sung v2 `1794108604-3066`.
// Ba kiểu danh mục: Mở (thêm, đổi tên, đổi thứ tự ▲▼, Ngừng, Dùng lại), Khoá (chỉ đổi tên: Giai đoạn lead, Giai đoạn cơ hội và nhóm con; R-V2-42),
// Chỉ xem (Tỉnh, phường nạp từ file chuẩn; Q-110). Mã không đổi, không xoá. Nút Lịch sử thay đổi mở hộp lịch sử của danh mục đang chọn (nhật ký QT-11).
// Luật và quyền do hàm DB kiểm; giao diện chỉ ẩn nút cho đúng kiểu danh mục.
import { useMemo, useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { foldText } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { cn } from '../../ui/cn';
import { useAccess } from '../../nav/AccessContext';
import { Button, IconButton } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { useToast } from '../../ui/toastContext';
import {
  catalogMode,
  childLevelName,
  flattenTree,
  MODE_LABEL,
  rootLabel,
  summaryLine,
  type CatalogMode,
  type CatalogNode,
  type CatalogSummary,
  type CatalogTree,
  type TreeRow,
  SESSION_TYPE_CATALOG,
  sessionFormLabel,
} from './catalogLogic';
import { CatalogHistoryDialog } from './CatalogHistoryDialog';
import {
  AddItemDialog,
  EditSessionFormDialog,
  RenameItemDialog,
  StopItemDialog,
  type AddTarget,
} from './CatalogDialogs';
import {
  moveCatalogItem,
  setCatalogItemActive,
  useCatalogSummary,
  useCatalogTree,
  useSessionTypeForms,
  useRefreshCatalogs,
} from './useCatalogData';

const MODE_TONE: Record<CatalogMode, 'neutral' | 'warning' | 'info'> = {
  open: 'neutral',
  locked: 'warning',
  view: 'info',
};

export function CatalogPage() {
  const access = useAccess();
  const toast = useToast();
  const supabase = useDb();
  const refresh = useRefreshCatalogs();
  const [search, setSearch] = useState('');
  const q = useDebounced(search);
  const summary = useCatalogSummary();
  // Tìm theo tên hiển thị (Nguồn lead, Tỉnh, phường) hoặc tên trong DB, không dấu; danh sách chỉ khoảng 50 danh mục nên lọc ở máy khách.
  const key = foldText(q.trim());
  const list = (summary.data ?? []).filter(
    (c) =>
      key === '' ||
      foldText(rootLabel(c.code, c.name)).includes(key) ||
      foldText(c.name).includes(key),
  );
  const [picked, setPicked] = useState<string | null>(null);
  // Chưa chọn (hoặc danh mục đang chọn bị lọc mất): lấy danh mục đầu của danh sách.
  const selectedCode = list.some((c) => c.code === picked) ? picked : (list[0]?.code ?? null);
  const selected = list.find((c) => c.code === selectedCode) ?? null;
  const tree = useCatalogTree(selectedCode);
  const canEdit = access.can('ADMIN', 'SUA');
  const [adding, setAdding] = useState<AddTarget | null>(null);
  const [renaming, setRenaming] = useState<CatalogNode | null>(null);
  const [editingForm, setEditingForm] = useState<CatalogNode | null>(null);
  const typeForms = useSessionTypeForms();
  const formOf = (code: string) => typeForms.data?.find((f) => f.type_code === code)?.form_code;
  const [stopping, setStopping] = useState<CatalogNode | null>(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);

  const done = (message: string) => {
    void refresh();
    toast({ title: message });
  };
  const act = async (id: string, action: () => Promise<unknown>, message: string) => {
    setBusyId(id);
    try {
      await action();
      done(message);
    } catch (e) {
      toast({ title: errorOf(e).message, tone: 'danger' });
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-h1">Danh mục</h1>
        <Button icon="history" disabled={selected === null} onClick={() => setHistoryOpen(true)}>
          Lịch sử thay đổi
        </Button>
      </div>
      <div className="grid gap-4 lg:grid-cols-[240px_minmax(0,1fr)]">
        <CatalogList
          list={list}
          loading={summary.isPending}
          error={summary.isError ? errorOf(summary.error).message : null}
          onRetry={() => void summary.refetch()}
          search={search}
          onSearch={setSearch}
          selectedCode={selectedCode}
          onPick={setPicked}
        />
        <section
          aria-label="Các mục của danh mục"
          className="min-w-0 rounded-box border border-border bg-surface"
        >
          {selected && tree.data ? (
            <CatalogPanel
              summary={selected}
              tree={tree.data}
              canEdit={canEdit}
              busyId={busyId}
              onAdd={setAdding}
              onRename={setRenaming}
              formOf={formOf}
              onEditForm={setEditingForm}
              onStop={setStopping}
              onReuse={(node) =>
                void act(
                  node.id,
                  () => setCatalogItemActive(supabase, node.id, true),
                  `Đã dùng lại mục ${node.code}.`,
                )
              }
              onMove={(node, dir) =>
                void act(node.id, () => moveCatalogItem(supabase, node.id, dir), 'Đã đổi thứ tự.')
              }
            />
          ) : tree.isError ? (
            <div className="p-4">
              <StateView
                kind="error"
                title="Không tải được danh mục"
                actions={<Button onClick={() => void tree.refetch()}>Thử lại</Button>}
              >
                {errorOf(tree.error).message}
              </StateView>
            </div>
          ) : (
            <div className="p-4">
              <Spinner label="Đang tải danh mục…" />
            </div>
          )}
        </section>
      </div>
      <CatalogHistoryDialog
        open={historyOpen}
        onOpenChange={setHistoryOpen}
        rootCode={selectedCode}
        rootLabel={selected ? rootLabel(selected.code, selected.name) : ''}
      />
      <AddItemDialog target={adding} onOpenChange={(o) => !o && setAdding(null)} onDone={done} />
      <RenameItemDialog
        node={renaming}
        onOpenChange={(o) => !o && setRenaming(null)}
        onDone={done}
      />
      <EditSessionFormDialog
        node={editingForm}
        formCode={editingForm ? (formOf(editingForm.code) ?? 'TIEU_CHI') : 'TIEU_CHI'}
        onOpenChange={(o) => !o && setEditingForm(null)}
        onDone={done}
      />
      <StopItemDialog
        node={stopping}
        childCount={
          stopping && tree.data
            ? tree.data.items.filter((i) => i.parent_id === stopping.id && i.is_active).length
            : 0
        }
        onOpenChange={(o) => !o && setStopping(null)}
        onDone={done}
      />
    </div>
  );
}

function CatalogList({
  list,
  loading,
  error,
  onRetry,
  search,
  onSearch,
  selectedCode,
  onPick,
}: {
  list: CatalogSummary[];
  loading: boolean;
  error: string | null;
  onRetry: () => void;
  search: string;
  onSearch: (value: string) => void;
  selectedCode: string | null;
  onPick: (code: string) => void;
}) {
  return (
    <nav
      aria-label="Danh sách danh mục"
      className="flex flex-col rounded-box border border-border bg-surface"
    >
      <div className="flex flex-col gap-3 p-3">
        <p className="text-body text-fg-muted">
          <b className="text-h2 text-fg">{list.length}</b> danh mục
        </p>
        <TextField
          label="Tìm danh mục"
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          placeholder="Tìm danh mục"
        />
      </div>
      {error ? (
        <div className="p-3">
          <StateView
            kind="error"
            title="Không tải được danh sách"
            actions={<Button onClick={onRetry}>Thử lại</Button>}
          >
            {error}
          </StateView>
        </div>
      ) : loading ? (
        <div className="p-3">
          <Spinner />
        </div>
      ) : list.length === 0 ? (
        <div className="p-3 text-body text-fg-muted">Không có danh mục nào khớp.</div>
      ) : (
        <ul className="max-h-[70vh] overflow-y-auto border-t border-border">
          {list.map((c) => {
            const mode = catalogMode(c);
            const active = c.code === selectedCode;
            return (
              <li key={c.code} className="border-b border-border last:border-b-0">
                <button
                  type="button"
                  aria-current={active ? 'true' : undefined}
                  onClick={() => onPick(c.code)}
                  className={cn(
                    'focus-ring flex w-full flex-col gap-1 border-l-[3px] px-3 py-3 text-left hover:bg-hover',
                    active ? 'border-l-brand-600 bg-brand-50' : 'border-l-transparent',
                  )}
                >
                  <span className="flex items-center justify-between gap-2">
                    <span className="text-body font-semibold">{rootLabel(c.code, c.name)}</span>
                    <Tag tone={MODE_TONE[mode]}>{MODE_LABEL[mode]}</Tag>
                  </span>
                  <span className="text-caption text-fg-muted">{summaryLine(c)}</span>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </nav>
  );
}

function CatalogPanel({
  summary,
  tree,
  canEdit,
  busyId,
  onAdd,
  onRename,
  formOf,
  onEditForm,
  onStop,
  onReuse,
  onMove,
}: {
  summary: CatalogSummary;
  tree: CatalogTree;
  canEdit: boolean;
  busyId: string | null;
  onAdd: (target: AddTarget) => void;
  onRename: (node: CatalogNode) => void;
  formOf: (code: string) => string | undefined;
  onEditForm: (node: CatalogNode) => void;
  onStop: (node: CatalogNode) => void;
  onReuse: (node: CatalogNode) => void;
  onMove: (node: CatalogNode, dir: 'LEN' | 'XUONG') => void;
}) {
  const mode = catalogMode(tree.root);
  const rows = useMemo(() => flattenTree(tree.items), [tree.items]);
  const levels = tree.levels;
  const nested = levels.length > 1;
  const writable = canEdit && mode === 'open';
  const levelOf = (node: CatalogNode) => levels.findIndex((l) => l.code === node.catalog_code);
  const rootName = rootLabel(tree.root.code, tree.root.name);

  const addTarget = (levelIdx: number, parent: CatalogNode | null): AddTarget => {
    const level = levels[levelIdx];
    const parentLevel = levels[levelIdx - 1];
    const siblings = tree.items.filter(
      (i) => i.catalog_code === level?.code && i.parent_id === (parent?.id ?? null),
    );
    return {
      catalogCode: level?.code ?? tree.root.code,
      levelName: nested ? (level?.name ?? 'mục').toLowerCase() : 'mục',
      catalogName: rootName,
      parent,
      parents: parentLevel ? tree.items.filter((i) => i.catalog_code === parentLevel.code) : [],
      parentLevelName: parentLevel?.name ?? '',
      nextOrder: siblings.length + 1,
    };
  };

  const topLabel = nested ? `Thêm ${(levels[0]?.name ?? 'mục').toLowerCase()}` : 'Thêm mục';
  const meta =
    mode === 'view'
      ? 'Nạp từ file chuẩn, chỉ xem'
      : nested
        ? mode === 'locked'
          ? summaryLine(summary).replace(' · chỉ đổi tên', '')
          : `Nhiều cấp: ${levels.map((l) => l.name.toLowerCase()).join(' → ')}`
        : `${summary.levels[0]?.total ?? 0} mục · chỉ Admin sửa`;

  const code = (r: TreeRow) => (
    <span className="flex items-center gap-1" style={{ paddingLeft: `${r.depth * 16}px` }}>
      {r.depth > 0 && (
        <span aria-hidden="true" className="text-fg-muted">
          ↳
        </span>
      )}
      <span className={r.node.is_active ? undefined : 'text-fg-label'}>{r.node.code}</span>
    </span>
  );
  const status = (r: TreeRow) =>
    r.node.is_active ? <Tag tone="success">Đang dùng</Tag> : <Tag tone="neutral">Ngừng</Tag>;

  const columns: LineColumn<TreeRow>[] =
    mode === 'view'
      ? [
          { key: 'code', header: 'Mã', cell: code },
          { key: 'name', header: 'Tên', cell: (r: TreeRow) => r.node.name },
          {
            key: 'level',
            header: 'Cấp',
            cell: (r: TreeRow) => levels[levelOf(r.node)]?.name ?? '',
          },
          { key: 'status', header: 'Trạng thái', cell: status },
        ]
      : [
          { key: 'code', header: 'Mã (không đổi)', cell: code },
          {
            key: 'name',
            header: 'Tên hiển thị',
            cell: (r: TreeRow) => (
              <span
                className={cn(
                  nested && r.depth === 0 && 'font-semibold',
                  !r.node.is_active && 'text-fg-label',
                )}
              >
                {r.node.name}
              </span>
            ),
          },
          {
            key: 'order',
            header: 'Thứ tự',
            align: 'right',
            cell: (r: TreeRow) => (
              <span className="flex items-center justify-end gap-1">
                <span className="tabular-nums">{r.rank}</span>
                {writable && (
                  <>
                    <IconButton
                      icon="chevronUp"
                      bordered
                      className="!size-6"
                      label={`Chuyển ${r.node.code} lên`}
                      disabled={r.first || busyId === r.node.id}
                      onClick={() => onMove(r.node, 'LEN')}
                    />
                    <IconButton
                      icon="chevronDown"
                      bordered
                      className="!size-6"
                      label={`Chuyển ${r.node.code} xuống`}
                      disabled={r.last || busyId === r.node.id}
                      onClick={() => onMove(r.node, 'XUONG')}
                    />
                  </>
                )}
              </span>
            ),
          },
          ...(tree.root.code === SESSION_TYPE_CATALOG
            ? [
                {
                  key: 'form',
                  header: 'Form nhận xét',
                  cell: (r: TreeRow) => sessionFormLabel(formOf(r.node.code)),
                },
              ]
            : []),
          { key: 'status', header: 'Trạng thái', cell: status },
          {
            key: 'actions',
            header: '',
            cell: (r: TreeRow) => {
              if (!canEdit) return null;
              const childName = childLevelName(levels, r.depth);
              return (
                <span className="flex flex-nowrap justify-end gap-1.5 whitespace-nowrap">
                  {r.node.is_active || mode === 'locked' ? (
                    <Button size="sm" onClick={() => onRename(r.node)}>
                      Đổi tên
                    </Button>
                  ) : null}
                  {tree.root.code === SESSION_TYPE_CATALOG && r.node.is_active && (
                    <Button size="sm" onClick={() => onEditForm(r.node)}>
                      Sửa form
                    </Button>
                  )}
                  {writable && r.node.is_active && childName && (
                    <Button size="sm" onClick={() => onAdd(addTarget(r.depth + 1, r.node))}>
                      Thêm {childName.toLowerCase()}
                    </Button>
                  )}
                  {writable &&
                    (r.node.is_active ? (
                      <Button size="sm" onClick={() => onStop(r.node)}>
                        Ngừng
                      </Button>
                    ) : (
                      <Button
                        size="sm"
                        loading={busyId === r.node.id}
                        onClick={() => onReuse(r.node)}
                      >
                        Dùng lại
                      </Button>
                    ))}
                </span>
              );
            },
          },
        ];

  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border p-4">
        <div className="flex flex-wrap items-baseline gap-2">
          <h2 className="text-h2">{rootName}</h2>
          <Tag tone={MODE_TONE[mode]}>{MODE_LABEL[mode]}</Tag>
          <span className="text-body text-fg-muted">{meta}</span>
        </div>
        {writable && (
          <Button variant="primary" icon="plus" onClick={() => onAdd(addTarget(0, null))}>
            {topLabel}
          </Button>
        )}
      </div>
      <div className="flex flex-col gap-3 p-4">
        {mode === 'locked' && <Alert tone="info">Khoá: chỉ đổi tên hiển thị.</Alert>}
        {mode === 'view' && <Alert tone="info">Nạp từ file chuẩn, chỉ xem.</Alert>}
        {mode === 'open' && nested && (
          <Alert tone="info">
            Danh mục nhiều cấp: mỗi {(levels[0]?.name ?? '').toLowerCase()} có các{' '}
            {(levels[1]?.name ?? '').toLowerCase()} con. Thêm, đổi tên, đổi thứ tự, Ngừng ở từng
            cấp. Không xoá, không đổi mã.
          </Alert>
        )}
        <LineTable<TreeRow>
          caption={`Các mục của ${rootName}`}
          rows={rows}
          rowKey={(r) => r.node.id}
          rowLabel={(r) => r.node.code}
          empty={
            <StateView kind="empty" title="Danh mục này chưa có mục nào" headingLevel={2}>
              {writable ? `Bấm ${topLabel} để tạo mục đầu tiên.` : 'Chưa có mục nào để hiện.'}
            </StateView>
          }
          columns={columns}
        />
        {mode === 'open' && !nested && (
          <p className="text-caption text-fg-muted">
            Không xoá mục: chỉ Ngừng. Mục Ngừng không hiện ở ô chọn mới, dữ liệu cũ vẫn giữ.
          </p>
        )}
      </div>
    </>
  );
}
