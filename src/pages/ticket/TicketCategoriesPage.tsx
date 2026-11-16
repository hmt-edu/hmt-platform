// CSN-08 Cấu hình ticket: nhóm và nhóm con theo loại (Đề nghị, Khiếu nại, Ticket giáo viên); thêm, sửa, ngừng. Không xoá, mã không đổi.
// Chỉ Quản trị · Sửa lưu được; ghi qua app.save_ticket_category (AS-05, AS-08, AS-10).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, rpc, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Checkbox, INPUT_CLASS } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { Tabs } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  NEW_CATEGORY_DRAFT,
  buildCategoryPayload,
  categoryErrors,
  draftOf,
  type CategoryDraft,
  type CategoryRow,
} from './ticketCategoryForm';

const TYPES = [
  { value: 'DN', label: 'Đề nghị' },
  { value: 'KN', label: 'Khiếu nại' },
  { value: 'GV', label: 'Ticket giáo viên' },
] as const;
const BUSINESS = [
  { value: 'CAP_NHAT_HO_SO', label: 'Cập nhật hồ sơ' },
  { value: 'DOI_LICH', label: 'Đổi lịch, học bù' },
  { value: 'CHUYEN_LOP', label: 'Chuyển lớp, chuyển cơ sở' },
  { value: 'BAO_LUU', label: 'Bảo lưu, tiếp tục học' },
  { value: 'DUNG_HOC', label: 'Dừng học' },
  { value: 'HOAN_PHI', label: 'Hoàn học phí' },
  { value: 'CHUYEN_PHI', label: 'Chuyển phí' },
];
const NATURE = [
  { value: 'HO_TRO', label: 'Cần hỗ trợ' },
  { value: 'PHAN_ANH', label: 'Phản ánh' },
];

type Editing = {
  creating: boolean;
  kind: 'GROUP' | 'SUBGROUP';
  parentCode: string | null;
  ticketType: string;
};

export function TicketCategoriesPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const queryClient = useQueryClient();
  const catalogs = useLeadCatalogs();
  const [type, setType] = useState<string>('DN');
  const [editing, setEditing] = useState<Editing | null>(null);
  const [draft, setDraft] = useState<CategoryDraft>(NEW_CATEGORY_DRAFT);
  const [showErrors, setShowErrors] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  useCrumbTail('Nhóm ticket');

  const data = useQuery({
    queryKey: ['ticket-categories-all'],
    queryFn: async () => {
      const { data: rows, error } = await supabase
        .schema('app')
        .from('ticket_category')
        .select(
          'code, name, kind, parent_code, ticket_type, nature_code, default_priority, default_team, business_type, requires_student, requires_class, sort_order, is_active',
        )
        .order('sort_order')
        .order('code')
        .returns<CategoryRow[]>();
      if (error) throw errorOf(error);
      return rows;
    },
  });
  const canEdit = access.can('ADMIN', 'SUA');
  if (data.isPending) return <Spinner label="Đang tải nhóm ticket…" />;
  if (data.isError) return <StateView kind="error" title="Chưa tải được nhóm ticket" />;

  const all = data.data;
  const groups = all.filter((c) => c.kind === 'GROUP' && c.ticket_type === type);
  const errors = categoryErrors(draft, editing?.creating ?? false);
  const hasErrors = Object.keys(errors).length > 0;

  const open = (next: Editing, from: CategoryDraft) => {
    setDraft(from);
    setEditing(next);
    setShowErrors(false);
    setFailure(null);
  };

  const save = async () => {
    if (editing === null) return;
    setShowErrors(true);
    if (hasErrors) return;
    setBusy(true);
    setFailure(null);
    try {
      await rpc(supabase, 'save_ticket_category', { p_data: buildCategoryPayload(draft, editing) });
      setEditing(null);
      toast({ tone: 'success', title: 'Đã lưu nhóm ticket.' });
      await queryClient.invalidateQueries({ queryKey: ['ticket-categories-all'] });
      await queryClient.invalidateQueries({ queryKey: ['ticket-categories'] });
    } catch (cause) {
      setFailure(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const row = (c: CategoryRow) => (
    <li key={c.code} className="flex flex-wrap items-center gap-3 py-1">
      <span className="min-w-56 font-medium">{c.name}</span>
      <span className="text-caption text-fg-muted">{c.code}</span>
      {c.business_type && <Tag>NV</Tag>}
      {c.nature_code && <Tag>{c.nature_code === 'HO_TRO' ? 'Cần hỗ trợ' : 'Phản ánh'}</Tag>}
      <span className="text-caption">
        {catalogs.name('TICKET_PRIORITY', c.default_priority) ?? '—'}
      </span>
      <span className="text-caption">{catalogs.name('TICKET_TEAM', c.default_team) ?? '—'}</span>
      {!c.is_active && <Tag>Ngừng</Tag>}
      {canEdit && (
        <Button
          onClick={() =>
            open(
              {
                creating: false,
                kind: c.kind,
                parentCode: c.parent_code,
                ticketType: c.ticket_type,
              },
              draftOf(c),
            )
          }
        >
          Sửa
        </Button>
      )}
    </li>
  );

  const panel = (
    <div className="flex flex-col gap-6">
      {groups.length === 0 && <p className="text-fg-muted">Chưa có nhóm nào.</p>}
      {groups.map((g) => {
        const subs = all.filter((c) => c.kind === 'SUBGROUP' && c.parent_code === g.code);
        return (
          <section key={g.code} aria-label={g.name}>
            <div className="flex flex-wrap items-center gap-3">
              <h2 className="text-h4">{g.name}</h2>
              <span className="text-caption text-fg-muted">{subs.length} nhóm con</span>
              {!g.is_active && <Tag>Ngừng</Tag>}
              {canEdit && (
                <>
                  <Button
                    onClick={() =>
                      open(
                        {
                          creating: false,
                          kind: 'GROUP',
                          parentCode: null,
                          ticketType: g.ticket_type,
                        },
                        draftOf(g),
                      )
                    }
                  >
                    Sửa nhóm
                  </Button>
                  <Button
                    onClick={() =>
                      open(
                        {
                          creating: true,
                          kind: 'SUBGROUP',
                          parentCode: g.code,
                          ticketType: g.ticket_type,
                        },
                        NEW_CATEGORY_DRAFT,
                      )
                    }
                  >
                    Thêm nhóm con
                  </Button>
                </>
              )}
            </div>
            <ul className="mt-1 flex flex-col">{subs.map(row)}</ul>
          </section>
        );
      })}
    </div>
  );

  return (
    <div className="flex flex-col gap-4 p-4">
      <header className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-h2">Cấu hình ticket</h1>
        {canEdit && (
          <Button
            variant="primary"
            icon="plus"
            onClick={() =>
              open(
                { creating: true, kind: 'GROUP', parentCode: null, ticketType: type },
                NEW_CATEGORY_DRAFT,
              )
            }
          >
            Thêm nhóm
          </Button>
        )}
      </header>
      {!canEdit && <Alert tone="info">Bạn chỉ xem được; chỉ Quản trị sửa được nhóm ticket.</Alert>}
      <Tabs
        label="Loại ticket"
        value={type}
        onChange={setType}
        items={TYPES.map((t) => ({ value: t.value, label: t.label, content: panel }))}
      />
      <FormDialog
        open={editing !== null}
        onOpenChange={(o) => !o && setEditing(null)}
        title={`${editing?.creating ? 'Thêm' : 'Sửa'} ${editing?.kind === 'GROUP' ? 'nhóm' : 'nhóm con'}`}
        subtitle={editing?.creating ? undefined : draft.code}
        confirmLabel="Lưu"
        canSubmit={!showErrors || !hasErrors}
        busy={busy}
        error={failure}
        onSubmit={() => void save()}
      >
        {editing?.creating && (
          <label className="flex flex-col gap-1">
            <span className="text-caption font-semibold text-fg-label">Mã *</span>
            <input
              aria-label="Mã"
              value={draft.code}
              onChange={(e) => setDraft((d) => ({ ...d, code: e.target.value.toUpperCase() }))}
              aria-invalid={showErrors && errors.code ? true : undefined}
              className={INPUT_CLASS}
            />
            {showErrors && errors.code && (
              <span className="text-caption text-on-danger-subtle">{errors.code}</span>
            )}
          </label>
        )}
        <label className="flex flex-col gap-1">
          <span className="text-caption font-semibold text-fg-label">Tên *</span>
          <input
            aria-label="Tên"
            value={draft.name}
            onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))}
            aria-invalid={showErrors && errors.name ? true : undefined}
            className={INPUT_CLASS}
          />
          {showErrors && errors.name && (
            <span className="text-caption text-on-danger-subtle">{errors.name}</span>
          )}
        </label>
        {editing?.kind === 'SUBGROUP' && (
          <>
            <OptionalSelect
              label="Mức độ mặc định"
              value={draft.priority}
              onChange={(v) => setDraft((d) => ({ ...d, priority: v }))}
              options={catalogs.options('TICKET_PRIORITY', draft.priority)}
              placeholder="Chưa chọn"
            />
            <OptionalSelect
              label="Đội mặc định"
              value={draft.team}
              onChange={(v) => setDraft((d) => ({ ...d, team: v }))}
              options={catalogs.options('TICKET_TEAM', draft.team)}
              placeholder="Chưa chọn"
            />
            <OptionalSelect
              label="Phiếu nghiệp vụ"
              value={draft.business}
              onChange={(v) => setDraft((d) => ({ ...d, business: v }))}
              options={BUSINESS}
              placeholder="Không có"
            />
            {editing.ticketType === 'GV' && (
              <OptionalSelect
                label="Tính chất"
                value={draft.nature}
                onChange={(v) => setDraft((d) => ({ ...d, nature: v }))}
                options={NATURE}
                placeholder="Chưa chọn"
              />
            )}
            <Checkbox
              label="Bắt buộc chọn học sinh"
              checked={draft.requiresStudent}
              onChange={(e) => setDraft((d) => ({ ...d, requiresStudent: e.target.checked }))}
            />
            <Checkbox
              label="Bắt buộc chọn lớp"
              checked={draft.requiresClass}
              onChange={(e) => setDraft((d) => ({ ...d, requiresClass: e.target.checked }))}
            />
          </>
        )}
        <label className="flex flex-col gap-1">
          <span className="text-caption font-semibold text-fg-label">Thứ tự</span>
          <input
            aria-label="Thứ tự"
            inputMode="numeric"
            value={draft.sortOrder}
            onChange={(e) => setDraft((d) => ({ ...d, sortOrder: e.target.value }))}
            aria-invalid={showErrors && errors.sortOrder ? true : undefined}
            className={INPUT_CLASS}
          />
          {showErrors && errors.sortOrder && (
            <span className="text-caption text-on-danger-subtle">{errors.sortOrder}</span>
          )}
        </label>
        <Checkbox
          label="Đang dùng"
          checked={draft.active}
          onChange={(e) => setDraft((d) => ({ ...d, active: e.target.checked }))}
        />
        {editing?.kind === 'GROUP' && !editing.creating && (
          <p className="text-caption text-fg-muted">
            Ngừng nhóm thì các nhóm con cũng ngừng; bật lại nhóm không tự bật lại nhóm con.
          </p>
        )}
      </FormDialog>
    </div>
  );
}
