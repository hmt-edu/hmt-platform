// CSN-09 Cấu hình SLA: hạn phản hồi đầu và hạn xử lý xong theo loại × mức độ; hạn riêng của nhóm con (đè lên bảng).
// Chỉ Quản trị · Sửa lưu được (AS-07). Ticket đã tạo giữ hạn đã chụp; số mới áp cho ticket tạo sau khi lưu.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, rpc, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { UnsavedGuard } from '../../ui/Dialogs';
import { Alert, Spinner } from '../../ui/Feedback';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { INPUT_CLASS } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  EMPTY_SLA_EDITS,
  changedOverrides,
  changedRules,
  countChanges,
  ruleKey,
  slaFieldError,
  type SlaEdits,
  type SlaOverride,
  type SlaRule,
} from './ticketSla';

const TYPE_ORDER = ['DN', 'KN', 'GV'] as const;
const TYPE_NAME = { DN: 'Đề nghị', KN: 'Khiếu nại', GV: 'Ticket giáo viên' } as const;
const PRIORITY_ORDER = ['KHAN', 'CAO', 'THUONG', 'THAP'] as const;

function useSlaData() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['ticket-sla'],
    queryFn: async () => {
      const [rules, cats] = await Promise.all([
        supabase
          .schema('app')
          .from('ticket_sla_rule')
          .select('ticket_type, priority_code, response_hours, resolve_hours')
          .returns<SlaRule[]>(),
        supabase
          .schema('app')
          .from('ticket_category')
          .select('code, name, resolve_hours_override')
          .eq('kind', 'SUBGROUP')
          .eq('is_active', true)
          .order('sort_order')
          .returns<SlaOverride[]>(),
      ]);
      if (rules.error) throw errorOf(rules.error);
      if (cats.error) throw errorOf(cats.error);
      return { rules: rules.data, categories: cats.data };
    },
  });
}

const days = (hours: number) => `= ${Math.round((hours / 24) * 10) / 10} ngày`; // allow-number: đổi giờ sang ngày để đọc

export function TicketSlaPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const queryClient = useQueryClient();
  const catalogs = useLeadCatalogs();
  const data = useSlaData();
  const [edits, setEdits] = useState<SlaEdits>(EMPTY_SLA_EDITS);
  const [saving, setSaving] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [adding, setAdding] = useState('');
  useCrumbTail('SLA ticket');

  const rules = useMemo(() => data.data?.rules ?? [], [data.data]);
  const categories = useMemo(() => data.data?.categories ?? [], [data.data]);
  const changes = countChanges(rules, categories, edits);
  const canEdit = access.can('ADMIN', 'SUA');

  if (data.isPending) return <Spinner label="Đang tải cấu hình SLA…" />;
  if (data.isError)
    return (
      <QueryErrorView
        error={data.error}
        subject="cấu hình SLA"
        onRetry={() => void data.refetch()}
      />
    );

  // Nhóm con đang có hạn riêng (gốc hoặc vừa thêm), trừ nhóm con vừa bị bỏ trong lần sửa này vẫn hiện để hoàn tác.
  const overridden = categories.filter(
    (c) => c.resolve_hours_override !== null || edits.overrides[c.code] !== undefined,
  );
  const addable = categories.filter((c) => !overridden.some((o) => o.code === c.code));

  const setRule = (key: string, field: 'response' | 'resolve', value: string) =>
    setEdits((e) => ({ ...e, rules: { ...e.rules, [key]: { ...e.rules[key], [field]: value } } }));
  const setOverride = (code: string, value: string | null) =>
    setEdits((e) => ({ ...e, overrides: { ...e.overrides, [code]: value } }));

  const hasFieldError = [
    ...Object.values(edits.rules).flatMap((r) => [r.response, r.resolve]),
    ...Object.values(edits.overrides).map((v) => v ?? undefined),
  ].some((v) => slaFieldError(v) !== null);

  const save = async () => {
    setSaving(true);
    setFailure(null);
    try {
      await rpc<null>(supabase, 'save_ticket_sla', {
        p_rules: changedRules(rules, edits),
        p_overrides: changedOverrides(categories, edits),
      });
      setEdits(EMPTY_SLA_EDITS);
      toast({ tone: 'success', title: 'Đã lưu cấu hình SLA.' });
      await queryClient.invalidateQueries({ queryKey: ['ticket-sla'] });
    } catch (cause) {
      setFailure(errorOf(cause).message);
    } finally {
      setSaving(false);
    }
  };

  const hourInput = (
    label: string,
    original: number,
    typed: string | undefined,
    onChange: (v: string) => void,
  ) => (
    <span className="flex items-center gap-2">
      <input
        aria-label={label}
        inputMode="numeric"
        disabled={!canEdit}
        value={typed ?? String(original)}
        onChange={(e) => onChange(e.target.value)}
        aria-invalid={slaFieldError(typed) !== null ? true : undefined}
        className={`${INPUT_CLASS} w-20`}
      />
      <span className="text-caption text-fg-muted">giờ</span>
      <span className="text-caption text-fg-muted">
        {days(Number(typed ?? original) || original)}
      </span>
    </span>
  );

  return (
    <div className="flex flex-col gap-6 p-4">
      <UnsavedGuard when={changes > 0 && !saving} />
      <header className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-h2">Cấu hình SLA</h1>
        <div className="flex items-center gap-2">
          {changes > 0 && <span className="text-fg-muted">{changes} thay đổi chưa lưu</span>}
          <Button disabled={changes === 0 || saving} onClick={() => setEdits(EMPTY_SLA_EDITS)}>
            Bỏ thay đổi
          </Button>
          <Button
            variant="primary"
            loading={saving}
            disabled={!canEdit || changes === 0 || hasFieldError}
            onClick={() => void save()}
          >
            Lưu
          </Button>
        </div>
      </header>
      {failure && <Alert tone="danger">{failure}</Alert>}
      {!canEdit && <Alert tone="info">Bạn chỉ xem được; chỉ Quản trị sửa được cấu hình SLA.</Alert>}
      <section aria-label="Hạn theo loại và mức độ">
        <h2 className="mb-2 text-h4">Hạn theo loại và mức độ</h2>
        <table className="w-full text-left">
          <thead>
            <tr>
              <th scope="col">Loại ticket</th>
              <th scope="col">Mức độ</th>
              <th scope="col">Phản hồi đầu tiên</th>
              <th scope="col">Xử lý xong</th>
            </tr>
          </thead>
          <tbody>
            {TYPE_ORDER.flatMap((type) =>
              PRIORITY_ORDER.map((priority) => {
                const rule = rules.find(
                  (r) => r.ticket_type === type && r.priority_code === priority,
                );
                if (!rule) return null;
                const key = ruleKey(rule);
                const e = edits.rules[key];
                const name = `${TYPE_NAME[type]} ${catalogs.name('TICKET_PRIORITY', priority) ?? priority}`;
                return (
                  <tr key={key}>
                    <td>{priority === 'KHAN' ? TYPE_NAME[type] : ''}</td>
                    <td>{catalogs.name('TICKET_PRIORITY', priority) ?? priority}</td>
                    <td>
                      {hourInput(
                        `Phản hồi đầu tiên, ${name}`,
                        rule.response_hours,
                        e?.response,
                        (v) => setRule(key, 'response', v),
                      )}
                    </td>
                    <td>
                      {hourInput(`Xử lý xong, ${name}`, rule.resolve_hours, e?.resolve, (v) =>
                        setRule(key, 'resolve', v),
                      )}
                    </td>
                  </tr>
                );
              }),
            )}
          </tbody>
        </table>
      </section>
      <section aria-label="Hạn riêng theo nhóm con">
        <h2 className="mb-2 text-h4">Hạn riêng theo nhóm con (đè lên bảng trên)</h2>
        {overridden.length === 0 && (
          <p className="text-fg-muted">Chưa có nhóm con nào có hạn riêng.</p>
        )}
        <ul className="flex flex-col gap-2">
          {overridden.map((c) => {
            const typed = edits.overrides[c.code];
            const removed = typed === null;
            return (
              <li key={c.code} className="flex flex-wrap items-center gap-3">
                <span className="min-w-48">{c.name}</span>
                {removed ? (
                  <span className="text-fg-muted">Bỏ hạn riêng (chưa lưu)</span>
                ) : (
                  hourInput(
                    `Xử lý xong, ${c.name}`,
                    c.resolve_hours_override ?? 0,
                    typed ?? undefined,
                    (v) => setOverride(c.code, v),
                  )
                )}
                {canEdit && (
                  <Button
                    onClick={() =>
                      setOverride(c.code, removed ? String(c.resolve_hours_override ?? '') : null)
                    }
                  >
                    {removed ? 'Hoàn tác' : 'Bỏ hạn riêng'}
                  </Button>
                )}
              </li>
            );
          })}
        </ul>
        {canEdit && addable.length > 0 && (
          <div className="mt-3 flex items-end gap-2">
            <OptionalSelect
              label="Thêm hạn riêng"
              value={adding}
              onChange={(v) => {
                setAdding('');
                if (v !== '') setOverride(v, '');
              }}
              options={addable.map((c) => ({ value: c.code, label: c.name }))}
              placeholder="Chọn nhóm con"
            />
          </div>
        )}
      </section>
    </div>
  );
}
