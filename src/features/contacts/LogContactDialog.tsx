// Hộp «Ghi nhận liên hệ» (khung KH02_ghi_nhan_lien_he, KH05_dt_ghi_nhan; khuôn K08 FormDialog).
// Luật chặn thật ở app.log_contact (migration 694, R-CRM-43); giao diện chỉ kiểm sớm.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, toHmtError, useDb } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Field, INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { combineVn } from '../appointments/appointmentTime';
import { contactErrors, type ContactDraft } from './contactForm';

const CATALOGS = ['CONTACT_CHANNEL', 'CONTACT_RESULT'];
type CatalogOption = { catalog_code: string; code: string; name: string };

function useContactOptions() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['contact-catalogs'],
    queryFn: async () => {
      const { data, error } = await supabase
        .schema('app')
        .from('catalog_item')
        .select('catalog_code, code, name')
        .in('catalog_code', CATALOGS)
        .eq('is_active', true)
        .order('sort_order');
      if (error) throw toHmtError(error);
      const rows: CatalogOption[] = data ?? [];
      return rows;
    },
  });
}

export function LogContactDialog({
  entityType,
  entityId,
  onClose,
  onSaved,
  initialChannel = '',
}: {
  entityType: string;
  entityId: string;
  onClose: () => void;
  onSaved: () => Promise<void>;
  /** Kênh chọn sẵn (nút «Gọi» ở hàng Làm nhanh). */
  initialChannel?: string | undefined;
}) {
  const supabase = useDb();
  const options = useContactOptions();
  const [draft, setDraft] = useState<ContactDraft>({
    channel: initialChannel,
    result: '',
    body: '',
    nextDate: null,
    nextTime: '',
  });
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const nextAt = combineVn(draft.nextDate, draft.nextTime);
  const errors = contactErrors(draft, nextAt, new Date());
  const list = (catalog: string) =>
    (options.data ?? [])
      .filter((o) => o.catalog_code === catalog)
      .map((o) => ({ value: o.code, label: o.name }));

  const submit = () => {
    setShow(true);
    if (Object.keys(errors).length > 0) return;
    setBusy(true);
    setError(null);
    rpc(supabase, 'log_contact', {
      p_entity_type: entityType,
      p_entity_id: entityId,
      p_channel_code: draft.channel,
      p_result_code: draft.result,
      p_body: draft.body,
      p_next_at: nextAt?.toISOString() ?? null,
    })
      .then(async () => {
        await onSaved();
        onClose();
      })
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };

  const problem = (text: string | undefined) =>
    show && text ? <p className="text-caption text-on-danger-subtle">{text}</p> : null;

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && !busy && onClose()}
      title="Ghi nhận liên hệ"
      confirmLabel="Lưu liên hệ"
      canSubmit={!busy && !options.isPending}
      busy={busy}
      error={error ?? (options.isError ? errorOf(options.error).message : null)}
      onSubmit={submit}
    >
      <OptionalSelect
        label="Kênh *"
        value={draft.channel}
        onChange={(v) => setDraft((d) => ({ ...d, channel: v }))}
        options={list('CONTACT_CHANNEL')}
        placeholder="Chọn kênh"
        invalid={show && errors.channel !== undefined}
      />
      {problem(errors.channel)}
      <OptionalSelect
        label="Kết quả *"
        value={draft.result}
        onChange={(v) => setDraft((d) => ({ ...d, result: v }))}
        options={list('CONTACT_RESULT')}
        placeholder="Chọn kết quả"
        invalid={show && errors.result !== undefined}
      />
      {problem(errors.result)}
      <TextAreaField
        label="Nội dung *"
        placeholder="Nội dung trao đổi"
        value={draft.body}
        onChange={(e) => setDraft((d) => ({ ...d, body: e.target.value }))}
      />
      {problem(errors.body)}
      <div className="grid grid-cols-2 gap-3">
        <DateInput
          label="Hẹn lần sau (không bắt buộc)"
          value={draft.nextDate}
          onChange={(d) => setDraft((s) => ({ ...s, nextDate: d }))}
        />
        <Field label="Giờ">
          {(field) => (
            <input
              {...field}
              type="time"
              value={draft.nextTime}
              onChange={(e) => setDraft((s) => ({ ...s, nextTime: e.target.value }))}
              className={INPUT_CLASS}
            />
          )}
        </Field>
      </div>
      {problem(errors.next)}
    </FormDialog>
  );
}
