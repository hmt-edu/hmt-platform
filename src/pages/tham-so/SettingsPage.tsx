// QT-09 Cài đặt tham số nghiệp vụ, khuôn K10 (nhóm bên trái, bảng tham số bên phải). Canvas bổ sung v2 `1794124725-dc47` (QT09_*), chỉ Admin, chỉ máy tính.
// Sửa: ô nhập có kiểm khoảng ngay (nút Lưu khoá khi ngoài khoảng), bấm Lưu thì hộp xác nhận giá trị cũ → mới. Ghi đè theo cơ sở chỉ ở tham số cho phép.
// VÊNH CANVAS (ghi ở PR): canvas vẽ 26 tham số / 8 nhóm theo spec 06 §2; DB có đủ tham số nên màn hiện TẤT CẢ, nhóm theo module của tham số.
// Lịch sử thay đổi (QT09_lich_su): nút «Lịch sử» ở mỗi dòng xem một tham số; nút ở đầu trang xem mọi tham số (canvas chỉ vẽ hộp theo một tham số). Dữ liệu từ nhật ký (QT-11).
import { useMemo, useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { cn } from '../../ui/cn';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { Field, TextField } from '../../ui/Field';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { SettingHistoryDialog } from './SettingHistoryDialog';
import {
  buildGroups,
  formatSetting,
  formatSettingValue,
  fromInputText,
  inputError,
  rangeLabel,
  toInputText,
  unitLabel,
  type SettingDef,
  type SettingOverride,
} from './settingsLogic';
import {
  clearOverride,
  saveSetting,
  useRefreshSettings,
  useSettingDefs,
  useSettingOverrides,
} from './useSettingsData';
import { PageFrame, PageHeader } from '../../ui/PageHeader';

type Target = { def: SettingDef; branchId: string | null };

export function SettingsPage() {
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshSettings();
  const defs = useSettingDefs();
  const overrides = useSettingOverrides();
  const [search, setSearch] = useState('');
  const [picked, setPicked] = useState<string | null>(null);
  const [editing, setEditing] = useState<Target | null>(null);
  // Hộp lịch sử: một tham số, 'all' = mọi tham số, null = đóng.
  const [history, setHistory] = useState<SettingDef | 'all' | null>(null);
  const [confirming, setConfirming] = useState<(Target & { next: string }) | null>(null);
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const canEdit = access.can('ADMIN', 'SUA');
  const branches = access.teachingBranches;
  const branchCode = (id: string) => branches.find((b) => b.id === id)?.code ?? id;

  const groups = useMemo(() => buildGroups(defs.data ?? [], search), [defs.data, search]);
  const selected = groups.find((g) => g.code === picked) ?? groups[0] ?? null;
  const overridesOf = (key: string) => (overrides.data ?? []).filter((o) => o.setting_key === key);
  const total = (defs.data ?? []).length;

  const run = async (action: () => Promise<void>, message: string, after: () => void) => {
    setBusy(true);
    setSaveError(null);
    try {
      await action();
      await refresh();
      after();
      toast({ title: message });
    } catch (e) {
      setSaveError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  };

  const columns: LineColumn<SettingDef>[] = [
    {
      key: 'name',
      header: 'Tham số',
      width: 'min-w-60',
      cell: (d) => (
        <div className="flex flex-col">
          <span className="font-semibold">{d.name}</span>
          <span className="text-caption text-fg-muted">{d.description}</span>
        </div>
      ),
    },
    {
      key: 'value',
      header: 'Giá trị hiện tại',
      align: 'right',
      width: 'w-32',
      cell: (d) => <b>{formatSettingValue(d, d.value)}</b>,
    },
    {
      key: 'unit',
      header: 'Đơn vị',
      width: 'w-24',
      cell: (d) => unitLabel(d) || '—',
    },
    {
      key: 'range',
      header: 'Khoảng cho phép',
      width: 'w-36',
      cell: (d) => {
        return rangeLabel(d) || '—';
      },
    },
    {
      key: 'override',
      header: 'Ghi đè theo cơ sở',
      width: 'w-44',
      cell: (d) => {
        if (!d.allow_branch_override) return <span className="text-fg-muted">Không</span>;
        const list = overridesOf(d.key);
        return list.length === 0 ? (
          <span className="text-fg-muted">Có · Chưa cơ sở nào ghi đè</span>
        ) : (
          <ul className="flex flex-wrap gap-1">
            {list.map((o) => (
              <li key={o.branch_id}>
                <OverrideChip
                  def={d}
                  override={o}
                  code={branchCode(o.branch_id)}
                  canEdit={canEdit}
                  onEdit={() => setEditing({ def: d, branchId: o.branch_id })}
                  onClear={() =>
                    void run(
                      () => clearOverride(supabase, d.key, o.branch_id),
                      `Đã bỏ ghi đè ${branchCode(o.branch_id)}.`,
                      () => undefined,
                    )
                  }
                />
              </li>
            ))}
          </ul>
        );
      },
    },
    {
      key: 'actions',
      header: 'Thao tác',
      headerSrOnly: 'Thao tác',
      cell: (d) => (
        <div className="flex flex-col items-start gap-1 whitespace-nowrap xl:flex-row">
          {canEdit && (
            <Button variant="text" onClick={() => setEditing({ def: d, branchId: null })}>
              Sửa
            </Button>
          )}
          {canEdit && d.allow_branch_override && (
            <Button variant="text" onClick={() => setEditing({ def: d, branchId: '' })}>
              Ghi đè cơ sở
            </Button>
          )}
          <Button variant="text" onClick={() => setHistory(d)}>
            Lịch sử
          </Button>
        </div>
      ),
    },
  ];

  return (
    <PageFrame>
      <PageHeader
        title="Cài đặt tham số nghiệp vụ"
        actions={
          <Button icon="history" onClick={() => setHistory('all')}>
            Lịch sử thay đổi
          </Button>
        }
      />
      <div className="grid gap-4 xl:grid-cols-[240px_minmax(0,1fr)]">
        <nav
          aria-label="Nhóm tham số"
          className="flex flex-col rounded-box border border-border bg-surface"
        >
          <div className="flex flex-col gap-3 p-3">
            <p className="text-body text-fg-muted">
              <b className="text-h2 text-fg">{total}</b> tham số
            </p>
            <TextField
              label="Tìm tham số"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Tìm tham số"
            />
          </div>
          {defs.isPending ? (
            <div className="p-3">
              <Spinner />
            </div>
          ) : groups.length === 0 ? (
            <div className="p-3 text-body text-fg-muted">Không có tham số nào khớp.</div>
          ) : (
            <ul className="border-t border-border">
              {groups.map((g) => (
                <li key={g.code} className="border-b border-border last:border-b-0">
                  <button
                    type="button"
                    aria-current={g.code === selected?.code ? 'true' : undefined}
                    onClick={() => setPicked(g.code)}
                    className={cn(
                      'focus-ring flex w-full items-center justify-between gap-2 border-l-[3px] px-3 py-3 text-left hover:bg-hover',
                      g.code === selected?.code
                        ? 'border-l-brand-600 bg-brand-50'
                        : 'border-l-transparent',
                    )}
                  >
                    <span className="text-body font-semibold">{g.label}</span>
                    <Tag tone="neutral">{g.items.length}</Tag>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </nav>
        <section
          aria-label="Tham số của nhóm"
          className="min-w-0 rounded-box border border-border bg-surface"
        >
          {defs.isError ? (
            <div className="p-4">
              <StateView
                kind="error"
                title="Không tải được tham số"
                actions={<Button onClick={() => void defs.refetch()}>Thử lại</Button>}
              >
                {errorOf(defs.error).message}
              </StateView>
            </div>
          ) : selected ? (
            <>
              <h2 className="border-b border-border px-4 py-3 text-h2">
                {selected.label}{' '}
                <span className="text-body font-normal text-fg-muted">
                  · {selected.items.length} tham số
                </span>
              </h2>
              <LineTable
                wrap
                caption={`Tham số nhóm ${selected.label}`}
                columns={columns}
                rows={selected.items}
                rowKey={(d) => d.key}
                rowLabel={(d) => d.name}
              />
            </>
          ) : (
            <div className="p-4">
              <Spinner label="Đang tải tham số…" />
            </div>
          )}
        </section>
      </div>
      <SettingHistoryDialog
        open={history !== null}
        onOpenChange={(o) => !o && setHistory(null)}
        target={history === 'all' ? null : history}
        defs={defs.data ?? []}
      />
      {editing && (
        <EditDialog
          key={`${editing.def.key}:${editing.branchId ?? ''}`}
          target={editing}
          branches={branches}
          overrides={overridesOf(editing.def.key)}
          onClose={() => setEditing(null)}
          onNext={(t, next) => {
            setEditing(null);
            setSaveError(null);
            setConfirming({ ...t, next });
          }}
        />
      )}
      <ConfirmDialog
        open={confirming !== null}
        onOpenChange={(open) => {
          if (!open) setConfirming(null);
        }}
        title="Lưu thay đổi tham số"
        summary={
          confirming
            ? [
                { label: 'Tham số', value: confirming.def.name },
                {
                  label: 'Phạm vi',
                  value: confirming.branchId
                    ? `Ghi đè cơ sở ${branchCode(confirming.branchId)}`
                    : 'Giá trị chung',
                },
                {
                  label: 'Giá trị cũ',
                  value: formatSetting(confirming.def, currentOf(confirming, overrides.data ?? [])),
                },
                { label: 'Giá trị mới', value: formatSetting(confirming.def, confirming.next) },
              ]
            : undefined
        }
        note="Mọi lần sửa ghi nhật ký (ai sửa, lúc nào, giá trị cũ, giá trị mới)."
        confirmLabel="Lưu"
        busy={busy}
        error={saveError}
        onConfirm={() => {
          if (!confirming) return;
          void run(
            () => saveSetting(supabase, confirming.def.key, confirming.next, confirming.branchId),
            'Đã lưu tham số.',
            () => setConfirming(null),
          );
        }}
      />
    </PageFrame>
  );
}

/** Giá trị đang có của phạm vi được sửa (ghi đè của cơ sở nếu có, không thì giá trị chung). */
function currentOf(t: Target, overrides: SettingOverride[]): string {
  const o = t.branchId
    ? overrides.find((x) => x.setting_key === t.def.key && x.branch_id === t.branchId)
    : undefined;
  return o ? o.value : t.def.value;
}

function OverrideChip({
  def,
  override,
  code,
  canEdit,
  onEdit,
  onClear,
}: {
  def: SettingDef;
  override: SettingOverride;
  code: string;
  canEdit: boolean;
  onEdit: () => void;
  onClear: () => void;
}) {
  return (
    <span className="inline-flex items-center gap-1 rounded-control bg-canvas px-2 py-0.5 text-caption">
      <b>{code}</b>: {formatSetting(def, override.value)}
      {canEdit && (
        <>
          <button type="button" className="focus-ring text-link hover:underline" onClick={onEdit}>
            Sửa
          </button>
          <button
            type="button"
            className="focus-ring text-link hover:underline"
            aria-label={`Bỏ ghi đè ${code}`}
            onClick={onClear}
          >
            Bỏ
          </button>
        </>
      )}
    </span>
  );
}

function EditDialog({
  target,
  branches,
  overrides,
  onClose,
  onNext,
}: {
  target: Target;
  branches: { id: string; code: string; name: string }[];
  overrides: SettingOverride[];
  onClose: () => void;
  onNext: (target: Target, next: string) => void;
}) {
  const { def } = target;
  const isOverride = target.branchId !== null;
  const [branchId, setBranchId] = useState(target.branchId ?? '');
  const startValue =
    isOverride && branchId !== ''
      ? (overrides.find((o) => o.branch_id === branchId)?.value ?? def.value)
      : def.value;
  const [text, setText] = useState(toInputText(def, startValue));
  const error = def.value_type === 'BOOL' ? null : inputError(def, text);
  const stored = fromInputText(def, text);
  const unit = unitLabel(def);
  const range = rangeLabel(def);
  const changed = stored !== null && stored !== startValue;
  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={isOverride ? 'Ghi đè theo cơ sở' : 'Sửa giá trị chung'}
      subtitle={def.name}
      confirmLabel="Lưu"
      canSubmit={error === null && changed && (!isOverride || branchId !== '')}
      onSubmit={() => {
        if (stored !== null) onNext({ def, branchId: isOverride ? branchId : null }, stored);
      }}
    >
      <div className="flex flex-col gap-3">
        {isOverride && (
          <Field label="Cơ sở" required>
            {(field) => (
              <Select
                id={field.id}
                label="Cơ sở"
                value={branchId}
                onChange={(v) => {
                  setBranchId(v);
                  const o = overrides.find((x) => x.branch_id === v);
                  setText(toInputText(def, o ? o.value : def.value));
                }}
                options={branches.map((b) => ({ value: b.id, label: `${b.code} · ${b.name}` }))}
              />
            )}
          </Field>
        )}
        {def.value_type === 'BOOL' ? (
          <Field label="Giá trị" required>
            {(field) => (
              <Select
                id={field.id}
                label="Giá trị"
                value={text}
                onChange={setText}
                options={[
                  { value: 'true', label: 'Bật' },
                  { value: 'false', label: 'Tắt' },
                ]}
              />
            )}
          </Field>
        ) : (
          <TextField
            label={unit ? `Giá trị (${unit})` : 'Giá trị'}
            required
            value={text}
            onChange={(e) => setText(e.target.value)}
            invalid={error !== null}
            error={error ?? undefined}
            help={range ? `Cho phép ${range}${unit ? ` ${unit}` : ''}` : undefined}
            inputMode={def.value_type === 'TEXT' ? 'text' : 'decimal'}
          />
        )}
        <Alert tone="info">{def.description}</Alert>
      </div>
    </FormDialog>
  );
}
