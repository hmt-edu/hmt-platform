// CSN-03 Tạo mới ticket (đề nghị, khiếu nại): biểu mẫu tiếp nhận. Ticket giáo viên do giáo viên tạo từ cổng Giáo viên, không ở đây.
// Mã cấp tự động khi lưu (AS-01); hạn phản hồi, hạn xử lý tính ở máy chủ lúc tạo (AS-07).
import { useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Alert, Spinner } from '../../ui/Feedback';
import { INPUT_CLASS, TEXTAREA_CLASS } from '../../ui/Field';
import { Combobox, type ComboOption } from '../../ui/Inputs';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  EMPTY_TICKET_DRAFT,
  buildCreatePayload,
  groupsOf,
  subgroupsOf,
  validateTicketDraft,
  type TicketDraft,
} from './ticketCreate';
import { createTicket, useTicketCategories } from './useTicketData';

type Person = {
  id: string;
  code: string;
  full_name: string;
  phone?: string | null;
  parent_name?: string;
};

/** Tìm phụ huynh hoặc học sinh ở máy chủ (list_parents, list_students); chỉ lấy trang đầu theo cỡ trang mặc định. */
function usePeople(fn: 'list_parents' | 'list_students', query: string, enabled: boolean) {
  const supabase = useDb();
  const limit = useIntSetting('list_page_size_default');
  return useQuery({
    queryKey: ['ticket-people', fn, query, limit],
    enabled: enabled && limit !== null,
    queryFn: () =>
      rpc<{ rows: Person[] }>(supabase, fn, {
        p_filters: query === '' ? {} : { search: query },
        p_limit: limit,
        p_offset: 0,
      }),
  });
}

const toOption = (p: Person): ComboOption => ({
  value: p.id,
  label: p.full_name,
  hint: [p.code, p.parent_name ? `PH ${p.parent_name}` : p.phone].filter(Boolean).join(' · '),
  keywords: p.code,
});

export function TicketCreatePage() {
  const supabase = useDb();
  const navigate = useNavigate();
  const catalogs = useLeadCatalogs();
  const categories = useTicketCategories();
  // Mở từ nút «Tạo ticket hoàn tiền» của Đơn hàng (BH05_huy_chan): điền sẵn phụ huynh (tìm theo mã) và nhóm Hoàn tiền; người dùng sửa được.
  const [query] = useSearchParams();
  const [draft, setDraft] = useState<TicketDraft>(() => ({
    ...EMPTY_TICKET_DRAFT,
    parentId: query.get('phu-huynh') ?? '',
    groupCode: query.get('nhom') ?? '',
  }));
  const [errors, setErrors] = useState<ReturnType<typeof validateTicketDraft>>({});
  const [saving, setSaving] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  // Id ticket vừa tạo: có thì bỏ cờ "chưa lưu" rồi mới chuyển trang (không hỏi Rời trang).
  const [createdId, setCreatedId] = useState<string | null>(null);
  const [parentQuery, setParentQuery] = useState(query.get('ma') ?? '');
  const [studentQuery, setStudentQuery] = useState('');
  const parentQ = useDebounced(parentQuery).trim();
  const studentQ = useDebounced(studentQuery).trim();
  const parents = usePeople('list_parents', parentQ, true);
  const students = usePeople('list_students', studentQ, true);
  useCrumbTail('Tạo mới');
  useEffect(() => {
    if (createdId !== null) void navigate(`/crm/ticket/${createdId}`);
  }, [createdId, navigate]);

  const all = categories.data ?? [];
  const category = all.find((c) => c.code === draft.categoryCode) ?? null;
  const set = <K extends keyof TicketDraft>(key: K, value: TicketDraft[K]) =>
    setDraft((d) => ({ ...d, [key]: value }));

  const parentOptions = useMemo(() => (parents.data?.rows ?? []).map(toOption), [parents.data]);
  const studentOptions = useMemo(() => (students.data?.rows ?? []).map(toOption), [students.data]);

  if (categories.isPending) return <Spinner label="Đang tải biểu mẫu…" />;

  const save = async () => {
    const found = validateTicketDraft(draft, category);
    setErrors(found);
    if (Object.keys(found).length > 0) return;
    setSaving(true);
    setFailure(null);
    try {
      const created = await createTicket(supabase, buildCreatePayload(draft));
      setCreatedId(created.id);
    } catch (cause) {
      setFailure(errorOf(cause).message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <RecordDetail
      kind="Ticket"
      title=""
      mode="create"
      dirty={createdId === null && JSON.stringify(draft) !== JSON.stringify(EMPTY_TICKET_DRAFT)}
      saving={saving}
      onEdit={() => undefined}
      onSave={() => void save()}
      onCancel={() => void navigate('/crm/ticket')}
      aside={null}
    >
      {failure && <Alert tone="danger">{failure}</Alert>}
      <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
        <DetailSection title="Thông tin ticket">
          <DetailField
            label="Mã"
            mode="create"
            value=""
            editor={<span className="text-fg-muted">Cấp tự động khi lưu, không sửa được.</span>}
          />
          <DetailField
            label="Loại"
            required
            mode="create"
            value=""
            editor={
              <OptionalSelect
                label="Loại"
                value={draft.type}
                onChange={(v) =>
                  setDraft((d) => ({
                    ...d,
                    type: v === 'KN' ? 'KN' : 'DN',
                    groupCode: '',
                    categoryCode: '',
                  }))
                }
                options={[
                  { value: 'DN', label: 'Đề nghị' },
                  { value: 'KN', label: 'Khiếu nại' },
                ]}
                placeholder="Chọn loại"
              />
            }
          />
          <DetailField
            label="Tiêu đề"
            required
            mode="create"
            value=""
            error={errors.title}
            editor={
              <input
                aria-label="Tiêu đề"
                value={draft.title}
                onChange={(e) => set('title', e.target.value)}
                className={INPUT_CLASS}
              />
            }
          />
          <DetailField
            label="Kênh"
            required
            mode="create"
            value=""
            error={errors.channel}
            editor={
              <OptionalSelect
                label="Kênh"
                value={draft.channel}
                onChange={(v) => set('channel', v)}
                options={catalogs.options('TICKET_CHANNEL')}
                placeholder="Chọn kênh"
              />
            }
          />
          <DetailField
            label="Người gửi"
            required
            mode="create"
            value=""
            error={errors.parentId}
            editor={
              <Combobox
                label="Phụ huynh"
                options={parentOptions}
                value={draft.parentId ? [draft.parentId] : []}
                onChange={(v) => set('parentId', v[0] ?? '')}
                onSearch={setParentQuery}
                loading={parents.isFetching}
                placeholder="Tìm phụ huynh theo tên, số điện thoại, mã"
              />
            }
          />
          <DetailField
            label="Nhóm"
            required
            mode="create"
            value=""
            editor={
              <OptionalSelect
                label="Nhóm"
                value={draft.groupCode}
                onChange={(v) => setDraft((d) => ({ ...d, groupCode: v, categoryCode: '' }))}
                options={groupsOf(all, draft.type).map((c) => ({ value: c.code, label: c.name }))}
                placeholder="Chọn nhóm"
              />
            }
          />
          <DetailField
            label="Nhóm con"
            required
            mode="create"
            value=""
            error={errors.categoryCode}
            editor={
              <OptionalSelect
                label="Nhóm con"
                value={draft.categoryCode}
                onChange={(v) => set('categoryCode', v)}
                options={subgroupsOf(all, draft.groupCode).map((c) => ({
                  value: c.code,
                  label: c.name,
                }))}
                placeholder="Chọn nhóm con"
                disabled={draft.groupCode === ''}
              />
            }
          />
          <DetailField
            label="Mô tả"
            required
            mode="create"
            value=""
            error={errors.description}
            editor={
              <textarea
                aria-label="Mô tả"
                rows={4}
                value={draft.description}
                onChange={(e) => set('description', e.target.value)}
                className={TEXTAREA_CLASS}
              />
            }
          />
        </DetailSection>
        <DetailSection title="Liên kết và mức độ">
          <DetailField
            label="Học sinh"
            required={category?.requires_student === true}
            mode="create"
            value=""
            error={errors.studentId}
            editor={
              <Combobox
                label="Học sinh"
                options={studentOptions}
                value={draft.studentId ? [draft.studentId] : []}
                onChange={(v) => set('studentId', v[0] ?? '')}
                onSearch={setStudentQuery}
                loading={students.isFetching}
                placeholder="Tìm học sinh theo tên, mã"
              />
            }
          />
          <DetailField
            label="Mức độ"
            hint={
              category?.default_priority
                ? `mặc định ${catalogs.name('TICKET_PRIORITY', category.default_priority) ?? ''}`
                : undefined
            }
            mode="create"
            value=""
            editor={
              <OptionalSelect
                label="Mức độ"
                value={draft.priority}
                onChange={(v) => set('priority', v)}
                options={catalogs.options('TICKET_PRIORITY')}
                placeholder="Theo nhóm con"
              />
            }
          />
        </DetailSection>
      </div>
    </RecordDetail>
  );
}
