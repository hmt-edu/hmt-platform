// TS-10 Gộp lead / cơ hội trùng (hộp K08 FormDialog): chọn bản kia (gợi ý theo SĐT hoặc phụ huynh, hoặc tìm tay), chọn bản giữ
// lại, xem số và danh sách lịch hẹn, ghi chú chuyển sang, điều kiện chặn và cảnh báo, xác nhận "không hoàn tác" rồi gộp.
// Luật (R-CRM-22, 37), quyền Duyệt và phạm vi cơ sở do hàm trong cơ sở dữ liệu kiểm; hộp chỉ hiện kết quả và lỗi của hàm.
import { useQuery } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatDate, formatDateTime, formatMoney } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { formatPhone } from '../../pages/lead/leadFormat';
import { useLeadCatalogs } from '../../pages/lead/useCatalogs';
import type { LeadPage } from '../../pages/lead/leadTypes';
import { STATUS_LABEL, type AppointmentStatus } from '../../pages/lich-hen/appointmentTypes';
import type { OpportunityPage } from '../../pages/co-hoi/oppTypes';
import type { ParentPage, StudentPage } from '../../pages/khach-hang/custTypes';
import { cn } from '../../ui/cn';
import { FormDialog } from '../../ui/Dialogs';
import { Alert, Spinner } from '../../ui/Feedback';
import { Checkbox } from '../../ui/Field';
import { Combobox, type ComboOption } from '../../ui/Inputs';
import { Tag } from '../../ui/Data';
import {
  isPeopleEntity,
  mergeRecords,
  useMergeCandidates,
  useMergePreview,
  type MergeEntity,
  type MergeSide,
} from './mergeApi';
import {
  afterMergeNote,
  dialogTitle,
  entityNoun,
  keepAndMerge,
  matchSentence,
  moreItems,
  moveLines,
  type KeepSide,
} from './mergeLogic';

export type MergeCurrent = {
  id: string;
  code: string;
  /** Tên hiện trên thẻ: phụ huynh (và học sinh). */
  label: string;
  /** SĐT đã định dạng, dùng trong câu mô tả. */
  phone: string;
};

export type MergeDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  entity: MergeEntity;
  current: MergeCurrent;
  /** Gộp xong: mã và id của bản giữ lại (trang quyết định ở lại hay mở bản giữ lại). */
  onMerged: (keepId: string, keepCode: string) => void;
};

/** Mỗi lần mở là một lần gộp mới (chọn lại từ đầu, chưa tick xác nhận). */
export function MergeDialog(props: MergeDialogProps) {
  return props.open ? <MergeForm {...props} /> : null;
}

type FoundRow = { id: string; label: string; branch_code: string; keywords: string };

/** Tìm tay bản để gộp: lead, cơ hội theo danh sách của TS; phụ huynh, học sinh theo danh sách KH-01, KH-04 (phân trang ở máy chủ, 8 dòng). */
async function searchRecords(
  supabase: ReturnType<typeof useDb>,
  entity: MergeEntity,
  q: string,
): Promise<FoundRow[]> {
  const base = { p_sort: 'created_desc', p_limit: 8, p_offset: 0 };
  if (entity === 'PARENT') {
    const page = await rpc<ParentPage>(supabase, 'list_parents', {
      ...base,
      p_sort: 'name_asc',
      p_filters: { search: q },
    });
    return page.rows.map((r) => ({
      id: r.id,
      label: `${r.code} · ${r.full_name}`,
      branch_code: r.branch_code,
      keywords: `${r.code} ${r.full_name} ${r.phone}`,
    }));
  }
  if (entity === 'STUDENT') {
    const page = await rpc<StudentPage>(supabase, 'list_students', {
      ...base,
      p_sort: 'name_asc',
      p_filters: { search: q },
    });
    return page.rows.map((r) => ({
      id: r.id,
      label: `${r.code} · ${r.full_name} · ${r.parent_name}`,
      branch_code: r.branch_code,
      keywords: `${r.code} ${r.full_name} ${r.parent_name}`,
    }));
  }
  const page = await rpc<LeadPage | OpportunityPage>(
    supabase,
    entity === 'LEAD' ? 'list_leads' : 'list_opportunities',
    {
      ...base,
      p_filters: { q },
    },
  );
  return page.rows
    .filter((r) => r.record_status === 'DANG_DUNG')
    .map((r) => ({
      id: r.id,
      label: `${r.code} · ${r.student_name ? `${r.student_name} · ` : ''}${r.parent_name}`,
      branch_code: r.branch_code,
      keywords: `${r.code} ${r.parent_name} ${r.parent_phone}`,
    }));
}

function MergeForm({ open, onOpenChange, entity, current, onMerged }: MergeDialogProps) {
  const supabase = useDb();
  const noun = entityNoun(entity);
  const catalogs = useLeadCatalogs();
  const candidates = useMergeCandidates(entity, current.id, true);
  const [query, setQuery] = useState('');
  const q = useDebounced(query).trim();
  const [picked, setPicked] = useState<ComboOption | null>(null);
  const [chosenId, setChosenId] = useState<string | null>(null);
  const [keepSide, setKeepSide] = useState<KeepSide>('current');
  const [confirmed, setConfirmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Tìm tay ở máy chủ khi người dùng gõ (lead, cơ hội, phụ huynh, học sinh theo tên, SĐT, mã).
  const search = useQuery({
    queryKey: ['merge-search', entity, q],
    enabled: q !== '',
    staleTime: 0,
    gcTime: 0,
    queryFn: (): Promise<FoundRow[]> => searchRecords(supabase, entity, q),
  });

  const suggested: ComboOption[] = (candidates.data ?? []).map((c) => ({
    value: c.id,
    label: `${c.code} · ${c.label}`,
    hint: c.branch_code,
    keywords: c.code,
    ...(c.can_merge ? {} : { disabledReason: c.blocker_message ?? 'Không gộp được với bản này.' }),
  }));
  const found: ComboOption[] = (q === '' ? [] : (search.data ?? []))
    .filter((r) => r.id !== current.id)
    .map((r) => ({ value: r.id, label: r.label, hint: r.branch_code, keywords: r.keywords }));
  const options = [...(q === '' ? suggested : found)];
  if (picked && !options.some((o) => o.value === picked.value)) options.unshift(picked);

  // Chưa chọn thì lấy bản gợi ý đầu tiên gộp được (không cần effect: suy ra từ dữ liệu).
  const firstMergeable = candidates.data?.find((c) => c.can_merge)?.id ?? null;
  const otherId = chosenId ?? firstMergeable;

  const { keepId, mergeId } = keepAndMerge(keepSide, current.id, otherId);
  const preview = useMergePreview(entity, keepId, mergeId);
  const data = preview.data;
  const blockers = data?.blockers ?? [];
  const keepCode = data?.keep_code ?? '';
  const mergeCode = data?.merge_code ?? '';
  const sideOf = (which: KeepSide): MergeSide | undefined =>
    data === undefined ? undefined : which === keepSide ? data.sides.keep : data.sides.merge;
  const move = data?.move ?? {};
  const noRecord =
    candidates.isSuccess && candidates.data.length === 0 && q === '' && otherId === null;
  const candidateError = candidates.isError ? errorOf(candidates.error).message : null;
  const previewError = preview.isError ? errorOf(preview.error).message : null;

  async function submit() {
    if (keepId === null || mergeId === null) return;
    setBusy(true);
    setError(null);
    try {
      const result = await mergeRecords(supabase, entity, keepId, mergeId);
      onOpenChange(false);
      onMerged(keepId, result.keep_code);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      wide
      title={dialogTitle(entity)}
      subtitle={matchSentence(entity, current.phone, !noRecord)}
      confirmLabel={keepCode ? `Gộp vào ${keepCode}` : 'Gộp'}
      canSubmit={data !== undefined && blockers.length === 0 && confirmed && !preview.isFetching}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        <Combobox
          label={`Bản ${noun} trùng`}
          options={options}
          value={otherId ? [otherId] : []}
          onChange={(v) => {
            const id = v[0] ?? null;
            setChosenId(id);
            setPicked(options.find((o) => o.value === id) ?? null);
            setConfirmed(false);
          }}
          placeholder={candidates.isPending ? 'Đang tìm bản trùng…' : `Chọn ${noun} cần gộp`}
          loading={q !== '' && search.isFetching}
          onSearch={setQuery}
          help="Gõ tên, SĐT hoặc mã để tìm bản khác."
          error={candidateError}
        />
        {noRecord && (
          <Alert tone="info">
            Không thấy {noun} nào trùng với {current.code} trong phạm vi của bạn. Gõ tên, SĐT hoặc
            mã ở ô trên để tìm bản khác.
          </Alert>
        )}
        {otherId !== null && (preview.isPending || preview.isFetching) && (
          <Spinner label="Đang xem trước…" />
        )}
        {previewError && <Alert tone="danger">{previewError}</Alert>}
        {data && (
          <>
            <div className="grid gap-3 md:grid-cols-2">
              <SideCard
                entity={entity}
                title={current.code}
                kept={keepSide === 'current'}
                onKeep={() => {
                  setKeepSide('current');
                  setConfirmed(false);
                }}
                side={sideOf('current')}
                stageName={catalogs.name}
              />
              <SideCard
                entity={entity}
                title={sideOf('other')?.code ?? ''}
                kept={keepSide === 'other'}
                onKeep={() => {
                  setKeepSide('other');
                  setConfirmed(false);
                }}
                side={sideOf('other')}
                stageName={catalogs.name}
              />
            </div>
            {blockers.map((b) => (
              <Alert key={b.code} tone="danger">
                {b.message}
              </Alert>
            ))}
            {data.warnings.map((w) => (
              <Alert key={w.code} tone="warning">
                {w.message}
              </Alert>
            ))}
            <section
              aria-label="Chuyển sang bản giữ lại"
              className="flex flex-col gap-2 rounded-control border border-border p-3"
            >
              <h3 className="text-body font-semibold">
                Chuyển từ {mergeCode} sang {keepCode}
              </h3>
              {isPeopleEntity(entity) ? (
                <>
                  <ul className="flex list-disc flex-col gap-0.5 pl-5 text-body">
                    {moveLines(move).map((l) => (
                      <li key={l.label}>
                        {l.label}: {l.count}
                      </li>
                    ))}
                    {moveLines(move).length === 0 && <li>Không có dữ liệu nào cần chuyển.</li>}
                  </ul>
                  {data.money && data.money.balance !== 0 && (
                    <Alert tone="info">
                      Số dư khách hàng {formatMoney(data.money.balance)} đ của {mergeCode} cộng vào{' '}
                      {keepCode}. Hệ thống kiểm tổng số dư, tiền, giờ trước và sau khi gộp; lệch thì
                      huỷ gộp.
                    </Alert>
                  )}
                </>
              ) : (
                <>
                  {entity === 'LEAD' && (move.opportunities ?? 0) > 0 && (
                    <p className="text-body">
                      Cơ hội ({move.opportunities}) cũng chuyển sang {keepCode}.
                    </p>
                  )}
                  {entity === 'OPPORTUNITY' && (move.tests ?? 0) > 0 && (
                    <p className="text-body">
                      Phiếu Test ({move.tests}) cũng chuyển sang {keepCode}.
                    </p>
                  )}
                  <ItemList
                    title={`Lịch hẹn (${move.appointments ?? 0})`}
                    more={moreItems(move.appointments ?? 0, data.items.appointments.length)}
                  >
                    {data.items.appointments.map((a, i) => (
                      <li key={i}>
                        {a.title} · {formatDateTime(a.scheduled_at)} ·{' '}
                        {STATUS_LABEL[a.status as AppointmentStatus] ?? a.status}
                      </li>
                    ))}
                  </ItemList>
                  <ItemList
                    title={`Ghi chú (${move.notes ?? 0})`}
                    more={moreItems(move.notes ?? 0, data.items.notes.length)}
                  >
                    {data.items.notes.map((n, i) => (
                      <li key={i}>
                        {n.author ?? 'Hệ thống'} · {formatDateTime(n.created_at)} · “{n.body}”
                      </li>
                    ))}
                  </ItemList>
                </>
              )}
            </section>
            <p className="text-caption text-fg-muted">{afterMergeNote(keepCode, mergeCode)}</p>
            <Checkbox
              checked={confirmed}
              onChange={(e) => setConfirmed(e.target.checked)}
              label={
                <span>
                  Tôi xác nhận: <b>Gộp không hoàn tác được</b>
                </span>
              }
            />
          </>
        )}
      </div>
    </FormDialog>
  );
}

function sideRows(
  entity: MergeEntity,
  side: MergeSide,
  stageName: (catalog: string, code: string | null | undefined) => string | undefined,
): [string, ReactNode][] {
  if (entity === 'PARENT') {
    const c = side.counts ?? {};
    return [
      ['SĐT', formatPhone(side.phone)],
      ['SĐT 2', side.phone_2 ? formatPhone(side.phone_2) : '—'],
      ['Cơ sở', side.branch_code],
      ['Ngày tạo', formatDate(side.created_at)],
      [
        'Học sinh · lead · cơ hội',
        `${c.students ?? 0} · ${c.leads ?? 0} · ${c.opportunities ?? 0}`,
      ],
      [
        'Đơn · phiếu thu · ghi danh',
        `${c.orders ?? 0} · ${c.receipts ?? 0} · ${c.enrollments ?? 0}`,
      ],
      ['Ghi chú', String(side.notes)],
    ];
  }
  if (entity === 'STUDENT') {
    const c = side.counts ?? {};
    return [
      ['Phụ huynh', `${side.parent_name} · ${formatPhone(side.phone)}`],
      ['Năm sinh', side.birth_year ? String(side.birth_year) : '—'],
      ['Khối', side.grade ? String(side.grade) : '—'],
      ['Cơ sở', side.branch_code],
      ['Ngày tạo', formatDate(side.created_at)],
      ['Ghi danh · phiếu Test', `${c.enrollments ?? 0} · ${c.tests ?? 0}`],
      ['Dòng điểm danh · ghi chú', `${c.attendance ?? 0} · ${side.notes}`],
    ];
  }
  return [
    ['SĐT', formatPhone(side.phone)],
    ['Học sinh', side.student_name ?? '—'],
    entity === 'LEAD'
      ? ['Source', side.source ?? '—']
      : [
          'Giai đoạn',
          side.stage_code
            ? `${side.stage_code} ${stageName('OPP_STAGE', side.stage_code) ?? ''}`.trim()
            : '—',
        ],
    ['Sale phụ trách', side.owner ?? '—'],
    ['Cơ sở', side.branch_code],
    ['Ngày tạo', formatDate(side.created_at)],
    entity === 'LEAD'
      ? ['Cơ hội', String(side.opportunities ?? 0)]
      : ['Phiếu Test', String(side.tests ?? 0)],
    ['Lịch hẹn · ghi chú', `${side.appointments} lịch hẹn · ${side.notes} ghi chú`],
  ];
}

function SideCard({
  entity,
  title,
  kept,
  onKeep,
  side,
  stageName,
}: {
  entity: MergeEntity;
  title: string;
  kept: boolean;
  onKeep: () => void;
  side: MergeSide | undefined;
  stageName: (catalog: string, code: string | null | undefined) => string | undefined;
}) {
  const rows: [string, ReactNode][] = side === undefined ? [] : sideRows(entity, side, stageName);
  return (
    <label
      className={cn(
        'flex cursor-pointer flex-col gap-2 rounded-control border p-3',
        kept ? 'border-2 border-brand-500 bg-brand-50' : 'border-border bg-surface',
      )}
    >
      <span className="flex items-center gap-2">
        <input
          type="radio"
          name="merge-keep"
          checked={kept}
          onChange={onKeep}
          aria-label={`Giữ lại ${title}`}
          className="size-4 accent-[var(--action-primary-bg)]"
        />
        <span className="tabular text-caption text-fg-muted">{title}</span>
        <span className="min-w-0 flex-1 truncate font-semibold">
          {entity === 'STUDENT' ? side?.student_name : side?.parent_name}
        </span>
        <Tag tone={kept ? 'brand' : 'neutral'}>{kept ? 'Giữ lại' : 'Gộp vào bản giữ lại'}</Tag>
      </span>
      <dl className="grid grid-cols-[8.5rem_1fr] gap-x-2 gap-y-1 text-body">
        {rows.map(([k, v]) => (
          <div key={k} className="contents">
            <dt className="text-fg-muted">{k}</dt>
            <dd>{v}</dd>
          </div>
        ))}
      </dl>
    </label>
  );
}

function ItemList({
  title,
  more,
  children,
}: {
  title: string;
  more: string | null;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-1">
      <h4 className="text-caption font-semibold text-fg-label uppercase">{title}</h4>
      <ul className="flex list-disc flex-col gap-0.5 pl-5 text-body">{children}</ul>
      {more && <p className="text-caption text-fg-muted">{more}</p>}
    </div>
  );
}
