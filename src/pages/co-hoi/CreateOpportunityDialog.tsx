// TS-06 Tạo cơ hội từ lead (khuôn ③ FormDialog): chép thông tin lead sang cơ hội (R-CRM-27: phụ huynh khớp theo SĐT), cơ hội mới
// luôn ở L1 (R-CRM-36). Lead đã có cơ hội thì cảnh báo kèm mã cũ, xác nhận lần hai mới tạo thêm, hoặc mở cơ hội cũ (R-CRM-01).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { FormDialog } from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { Checkbox } from '../../ui/Field';
import { codeAndName, formatPhone } from '../lead/leadFormat';
import type { LeadCatalogs } from '../lead/useCatalogs';
import type { OpportunityPage } from './oppTypes';

export type OppSource = {
  id: string;
  code: string;
  parent_name: string;
  parent_phone: string;
  student_name: string | null;
  need: string | null;
};

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  lead: OppSource;
  catalogs: LeadCatalogs;
  /** Đã tạo xong (id cơ hội mới, mã). */
  onCreated: (created: { id: string; code: string }) => Promise<void>;
  onOpenExisting: (id: string) => void;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function CreateOpportunityDialog(props: Props) {
  return props.open ? <CreateForm {...props} /> : null;
}

function CreateForm({ onOpenChange, lead, catalogs, onCreated, onOpenExisting }: Props) {
  const supabase = useDb();
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const existing = useQuery({
    queryKey: ['lead-opportunities', lead.id],
    // Cảnh báo phải theo cơ hội hiện có ngay lúc mở hộp, không dùng bản nhớ của lần mở trước.
    gcTime: 0,
    staleTime: 0,
    queryFn: () =>
      rpc<OpportunityPage>(supabase, 'list_opportunities', {
        p_filters: { lead_id: lead.id },
        p_sort: 'created_asc',
        p_limit: null,
        p_offset: 0,
      }),
  });
  const rows = existing.data?.rows ?? [];
  const hasExisting = rows.length > 0;

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const created = await rpc<{ id: string; code: string }>(supabase, 'create_opportunity', {
        p_lead_id: lead.id,
        p_data: {},
        p_confirm_existing: hasExisting && confirm,
      });
      await onCreated(created);
      onOpenChange(false);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={onOpenChange}
      title="Tạo cơ hội từ lead"
      subtitle={`Lead ${lead.code} · ${lead.parent_name}`}
      confirmLabel={hasExisting ? 'Vẫn tạo thêm' : 'Tạo cơ hội'}
      canSubmit={!existing.isPending && (!hasExisting || confirm)}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        {hasExisting && (
          <Alert tone="warning" title={`Lead này đã có ${rows.length} cơ hội đang dùng`}>
            <ul className="mt-1 flex flex-col gap-1">
              {rows.map((r) => (
                <li key={r.id} className="flex items-center justify-between gap-2">
                  <span>
                    <b>{r.code}</b> ·{' '}
                    {codeAndName(r.stage_code, catalogs.name('OPP_STAGE', r.stage_code))}
                    {r.student_name ? ` · ${r.student_name}` : ''}
                  </span>
                  <Button
                    size="sm"
                    icon="arrowRight"
                    onClick={() => {
                      onOpenChange(false);
                      onOpenExisting(r.id);
                    }}
                  >
                    Mở cơ hội cũ
                  </Button>
                </li>
              ))}
            </ul>
            <p className="mt-1">
              Chỉ tạo thêm khi cần cơ hội mới (ví dụ em khác trong nhà cần test). Xác nhận bên dưới
              để tạo thêm.
            </p>
          </Alert>
        )}
        <dl className="grid grid-cols-[120px_minmax(0,1fr)] gap-x-3 gap-y-1.5 rounded-control bg-surface-subtle px-3 py-2.5">
          <dt className="text-fg-muted">Phụ huynh</dt>
          <dd>
            {lead.parent_name} · {formatPhone(lead.parent_phone)}
          </dd>
          <dt className="text-fg-muted">Học sinh</dt>
          <dd>{lead.student_name ?? '—'}</dd>
          <dt className="text-fg-muted">Nhu cầu</dt>
          <dd className="break-words">{lead.need ?? '—'}</dd>
        </dl>
        <p className="text-caption text-fg-muted">
          Cơ hội mới chép thông tin từ lead, bắt đầu ở giai đoạn L1; lead tự chuyển về C4D "Tạo cơ
          hội thành công". Hồ sơ phụ huynh khớp theo số điện thoại, không có thì tạo mới.
        </p>
        {hasExisting && (
          <Checkbox
            label="Tôi xác nhận: vẫn tạo thêm cơ hội mới cho lead này"
            checked={confirm}
            onChange={(e) => setConfirm(e.target.checked)}
          />
        )}
      </div>
    </FormDialog>
  );
}
