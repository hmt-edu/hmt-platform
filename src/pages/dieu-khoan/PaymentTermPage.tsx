// CH-09 Điều khoản thanh toán (canvas 9933: CH09_chinh, CH09_loi, ...): danh sách bên trái, các đợt của điều khoản đang chọn bên phải, hộp Thêm điều khoản.
// Điều khoản đã tạo KHÔNG sửa được: «Tạo bản mới» mở hộp với mã cũ (version + 1); Ngừng, Dùng lại. Luật R-TIEN-07; DB kiểm lại luật chia đợt.
// Vênh nhỏ với canvas (làm theo luật DB): các đợt sau đợt 1 chia theo % của TỔNG ĐƠN khi đợt 1 cũng là %, chỉ chia «phần còn lại sau đợt 1» khi đợt 1 là số tiền cố định.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { formatDate, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button, IconButton } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { cn } from '../../ui/cn';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { FormDialog } from '../../ui/Dialogs';
import { Field, TextField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import {
  codeFromName,
  dateToIso,
  describeInstallments,
  installmentsError,
  shareLabel,
  toPayload,
  type Draft,
  type PaymentTerm,
  type TermInstallment,
} from './termLogic';
import { createTerm, setTermActive, useRefreshTerms, useTerms } from './useTermData';
import { PageFrame, PageHeader } from '../../ui/PageHeader';

export function PaymentTermPage() {
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshTerms();
  const terms = useTerms();
  const [picked, setPicked] = useState<string | null>(null);
  const [creating, setCreating] = useState<{ from: PaymentTerm | null } | null>(null);
  const [busy, setBusy] = useState(false);
  const canCreate = access.can('CONFIG_SALES', 'TAO');
  const canEdit = access.can('CONFIG_SALES', 'SUA');
  const list = terms.data ?? [];
  const selected = list.find((t) => t.id === picked) ?? list[0] ?? null;

  const toggle = async (t: PaymentTerm) => {
    setBusy(true);
    try {
      await setTermActive(supabase, t.id, !t.is_active);
      await refresh();
      toast({ title: t.is_active ? 'Đã ngừng điều khoản.' : 'Đã dùng lại điều khoản.' });
    } catch (e) {
      toast({ title: errorOf(e).message, tone: 'danger' });
    } finally {
      setBusy(false);
    }
  };

  const columns: LineColumn<TermInstallment>[] = [
    { key: 'seq', header: 'Đợt', width: 'w-20', cell: (i) => `Đợt ${i.seq}` },
    {
      key: 'how',
      header: 'Cách chia',
      cell: (i) =>
        shareLabel(i, selected?.installments.some((x) => x.fixed_amount !== null) ?? false),
    },
    {
      key: 'value',
      header: 'Giá trị',
      align: 'right',
      width: 'w-36',
      cell: (i) =>
        i.fixed_amount !== null
          ? `${formatNumber(i.fixed_amount)} đ`
          : `${formatNumber(i.share_percent ?? 0)}%`,
    },
    {
      key: 'due',
      header: 'Số ngày đến hạn',
      align: 'right',
      width: 'w-40',
      cell: (i) => i.due_days,
    },
  ];

  return (
    <PageFrame>
      <PageHeader
        title="Điều khoản thanh toán"
        actions={
          canCreate && (
            <Button variant="primary" icon="plus" onClick={() => setCreating({ from: null })}>
              Thêm điều khoản
            </Button>
          )
        }
      />
      {terms.isError ? (
        <StateView
          kind="error"
          title="Không tải được điều khoản"
          actions={<Button onClick={() => void terms.refetch()}>Thử lại</Button>}
        >
          {errorOf(terms.error).message}
        </StateView>
      ) : !terms.data ? (
        <Spinner label="Đang tải điều khoản…" />
      ) : (
        <div className="grid gap-4 lg:grid-cols-[320px_minmax(0,1fr)]">
          <nav
            aria-label="Danh sách điều khoản"
            className="flex flex-col rounded-box border border-border bg-surface"
          >
            <p className="p-3 text-body text-fg-muted">
              <b className="text-h2 text-fg">{list.length}</b> điều khoản
            </p>
            {list.length === 0 ? (
              <p className="border-t border-border p-3 text-body text-fg-muted">
                Chưa có điều khoản nào.
              </p>
            ) : (
              <ul className="border-t border-border">
                {list.map((t) => (
                  <li key={t.id} className="border-b border-border last:border-b-0">
                    <button
                      type="button"
                      aria-current={t.id === selected?.id ? 'true' : undefined}
                      onClick={() => setPicked(t.id)}
                      className={cn(
                        'focus-ring flex w-full flex-col gap-1 border-l-[3px] px-3 py-3 text-left hover:bg-hover',
                        t.id === selected?.id
                          ? 'border-l-brand-600 bg-brand-50'
                          : 'border-l-transparent',
                      )}
                    >
                      <span className="flex items-center justify-between gap-2">
                        <span className="text-body font-semibold">{t.name}</span>
                        <Tag tone={t.is_active ? 'success' : 'neutral'}>
                          {t.is_active ? 'Đang dùng' : 'Ngừng'}
                        </Tag>
                      </span>
                      <span className="text-caption text-fg-muted">
                        {describeInstallments(t.installments)} · bản {t.version} · từ{' '}
                        {formatDate(t.valid_from)}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </nav>
          <section
            aria-label="Các đợt của điều khoản"
            className="min-w-0 rounded-box border border-border bg-surface"
          >
            {selected ? (
              <>
                <div className="flex flex-wrap items-center justify-between gap-2 border-b border-border px-4 py-3">
                  <h2 className="text-h2">
                    {selected.name}{' '}
                    <span className="text-body font-normal text-fg-muted">
                      · bản {selected.version} · từ {formatDate(selected.valid_from)}
                    </span>
                  </h2>
                  <div className="flex gap-1">
                    {canCreate && (
                      <Button onClick={() => setCreating({ from: selected })}>Tạo bản mới</Button>
                    )}
                    {canEdit && (
                      <Button loading={busy} onClick={() => void toggle(selected)}>
                        {selected.is_active ? 'Ngừng' : 'Dùng lại'}
                      </Button>
                    )}
                  </div>
                </div>
                <LineTable
                  wrap
                  caption={`Các đợt của ${selected.name}`}
                  columns={columns}
                  rows={[...selected.installments].sort((a, b) => a.seq - b.seq)}
                  rowKey={(i) => String(i.seq)}
                />
                <p className="p-4 text-caption text-fg-muted">
                  Điều khoản đã tạo không sửa được. Muốn đổi, tạo bản mới; đơn cũ giữ lịch đóng đã
                  sinh. Lịch dùng để theo dõi công nợ, nhắc sắp đến hạn và quá hạn; không chặn học.
                  Số ngày đến hạn tính từ ngày duyệt đơn.
                </p>
              </>
            ) : (
              <p className="p-4 text-body text-fg-muted">Chọn hoặc thêm một điều khoản.</p>
            )}
          </section>
        </div>
      )}
      {creating && (
        <TermForm
          key={creating.from?.id ?? 'new'}
          from={creating.from}
          onClose={() => setCreating(null)}
          onSaved={async () => {
            setCreating(null);
            await refresh();
            toast({ title: 'Đã lưu điều khoản.' });
          }}
        />
      )}
    </PageFrame>
  );
}

const MODE_OPTIONS = [
  { value: 'PERCENT', label: '%' },
  { value: 'FIXED', label: 'Số tiền cố định' },
];

function draftsOf(from: PaymentTerm | null): Draft[] {
  if (!from) {
    return [
      { mode: 'PERCENT', value: '', dueDays: '0' },
      { mode: 'PERCENT', value: '', dueDays: '' },
    ];
  }
  return [...from.installments]
    .sort((a, b) => a.seq - b.seq)
    .map((i) => ({
      mode: i.fixed_amount !== null ? 'FIXED' : 'PERCENT',
      value: String(i.fixed_amount ?? i.share_percent ?? ''),
      dueDays: String(i.due_days),
    }));
}

function TermForm({
  from,
  onClose,
  onSaved,
}: {
  from: PaymentTerm | null;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const supabase = useDb();
  const [name, setName] = useState(from?.name ?? '');
  const [validFrom, setValidFrom] = useState<Date | null>(null);
  const [drafts, setDrafts] = useState<Draft[]>(draftsOf(from));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const tableError = installmentsError(drafts);
  const code = from?.code ?? codeFromName(name);
  const set = (i: number, patch: Partial<Draft>) =>
    setDrafts((list) => list.map((d, k) => (k === i ? { ...d, ...patch } : d)));
  return (
    <FormDialog
      open
      wide
      onOpenChange={(open) => !open && onClose()}
      title={from ? `Tạo bản mới: ${from.name}` : 'Thêm điều khoản thanh toán'}
      subtitle={from ? `Mã ${from.code}, bản ${from.version + 1}` : undefined}
      confirmLabel="Lưu"
      canSubmit={name.trim() !== '' && code !== '' && validFrom !== null && tableError === null}
      busy={busy}
      error={error}
      onSubmit={() => {
        if (!validFrom) return;
        setBusy(true);
        setError(null);
        void createTerm(supabase, {
          code,
          name,
          validFrom: dateToIso(validFrom),
          installments: toPayload(drafts),
        })
          .then(onSaved)
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <div className="grid gap-3 sm:grid-cols-2">
          <TextField
            label="Tên điều khoản"
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
          <DateInput label="Hiệu lực từ" required value={validFrom} onChange={setValidFrom} />
        </div>
        <ul className="flex flex-col gap-2" aria-label="Các đợt">
          {drafts.map((d, i) => (
            <li key={i} className="grid items-end gap-2 sm:grid-cols-[72px_1fr_1fr_1fr_40px]">
              <span className="pb-2 text-body font-semibold">Đợt {i + 1}</span>
              <Field label="Cách chia">
                {(field) => (
                  <Select
                    id={field.id}
                    label={`Cách chia đợt ${i + 1}`}
                    value={d.mode}
                    disabled={i > 0}
                    onChange={(v) => set(i, { mode: v === 'FIXED' ? 'FIXED' : 'PERCENT' })}
                    options={MODE_OPTIONS}
                  />
                )}
              </Field>
              <TextField
                label={d.mode === 'FIXED' ? 'Số tiền (đ)' : 'Giá trị (%)'}
                value={d.value}
                inputMode="decimal"
                onChange={(e) => set(i, { value: e.target.value })}
              />
              <TextField
                label="Số ngày đến hạn"
                value={d.dueDays}
                inputMode="numeric"
                onChange={(e) => set(i, { dueDays: e.target.value })}
              />
              {drafts.length > 1 ? (
                <IconButton
                  icon="close"
                  label={`Bỏ đợt ${i + 1}`}
                  onClick={() => setDrafts((list) => list.filter((_, k) => k !== i))}
                />
              ) : (
                <span />
              )}
            </li>
          ))}
        </ul>
        <div>
          <Button
            icon="plus"
            onClick={() => setDrafts((l) => [...l, { mode: 'PERCENT', value: '', dueDays: '' }])}
          >
            Thêm đợt
          </Button>
        </div>
        {tableError && drafts.some((d) => d.value.trim() !== '') && (
          <Alert tone="danger">{tableError}</Alert>
        )}
        <p className="text-caption text-fg-muted">
          Các đợt đánh số liên tục từ 1. Chỉ đợt 1 được chọn Số tiền cố định. Điều khoản đã tạo
          không sửa; thay đổi là tạo bản mới.
        </p>
      </div>
    </FormDialog>
  );
}
