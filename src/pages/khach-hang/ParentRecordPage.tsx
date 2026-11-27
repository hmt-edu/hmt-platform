// KH-02 Phụ huynh (bản ghi, khuôn K06): thông tin, các con, đơn hàng, phiếu thu; nút liên kết có số đếm; ghi chú và hoạt động (Chatter).
// Không có Tạo tay (R-CRM-27). Sửa (KH-03) gọi update_parent; cơ sở tiếp nhận chỉ xem (R-CRM-28, Admin đổi qua ticket Chuyển cơ sở).
// Mọi tab bấm được và luôn hiện đủ cột (khung KH02_*): cột chưa có dữ liệu để gạch; tab Tài chính mới có đầu cột.
import { useState } from 'react';
import { MergeDialog } from '../../features/merge/MergeDialog';
import { formatPhone } from '../lead/leadFormat';
import { Link, useNavigate, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { Button } from '../../ui/Button';
import { HmtError, errorOf, rpc, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { INPUT_CLASS } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { formatDate } from '../../lib/format';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { RecordSummary } from '../../features/record360/RecordSummary';
import type { ChatterFocus } from '../../ui/Chatter';
import { DetailField, DetailSection, RecordDetail, type DetailMode } from '../../record/Detail';
import { newTicketForParentPath } from './custFilters';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { CustTabs } from './CustTabs';
import { CustTickets } from './CustTickets';
import { AppointmentTab, UpsaleTab } from './FollowUpTabs';
import { ParentAccountTab } from './ParentAccountTab';
import { useOpportunityAppointments } from '../../features/appointments/useRecordAppointments';
import { ParentFinanceTab, ParentOrdersTab, ParentReceiptsTab } from './ParentTabs';
import { useOpenTicketCount } from './useCustTickets';
import { parentPath, studentPath } from './custConfig';
import { STUDENT_STATUS_LABEL, type ParentRecord } from './custTypes';
import { useParentRecord, useRefreshCustomers } from './useCustData';
import { FromLink } from '../../layout/FromLink';

const FORMAT = {
  labels: {
    full_name: 'Họ tên',
    phone: 'Số điện thoại',
    phone_2: 'Số điện thoại 2',
    address: 'Địa chỉ',
    relative_name: 'Người thân',
  },
};

type ParentDraft = {
  full_name: string;
  phone: string;
  phone_2: string;
  relative_name: string;
  province_code: string;
  ward_code: string;
  address: string;
};

function toParentDraft(
  r: ParentRecord,
  refs: { ward_code: string | null; province_code: string | null } | null,
): ParentDraft {
  return {
    full_name: r.full_name,
    phone: r.phone,
    phone_2: r.phone_2 ?? '',
    relative_name: r.relative_name ?? '',
    province_code: refs?.province_code ?? '',
    ward_code: refs?.ward_code ?? '',
    address: r.address ?? '',
  };
}

export function ParentRecordPage() {
  const { id } = useParams();
  const query = useParentRecord(id);
  if (query.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (query.isError) {
    const code = query.error instanceof HmtError ? query.error.code : '';
    return (
      <StateView
        kind={
          code === 'HMT_KHONG_CO_QUYEN'
            ? 'forbidden'
            : code === 'HMT_KHONG_TIM_THAY'
              ? 'not-found'
              : 'error'
        }
        title={
          code === 'HMT_KHONG_CO_QUYEN'
            ? 'Bạn không có quyền xem phụ huynh này'
            : code === 'HMT_KHONG_TIM_THAY'
              ? 'Không tìm thấy phụ huynh'
              : 'Không tải được phụ huynh'
        }
        actions={
          <>
            {/* duong-dan-menu: không tải được bản ghi, về danh sách chung */}
            <Link to="/crm/phu-huynh" className="font-medium text-link hover:underline">
              Về danh sách Phụ huynh
            </Link>
            {code === '' && <Button onClick={() => void query.refetch()}>Thử lại</Button>}
          </>
        }
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  return <ParentView key={query.data.id} record={query.data} />;
}

function ParentView({ record }: { record: ParentRecord }) {
  const refresh = useRefreshCustomers();
  const navigate = useNavigate();
  const [tab, setTab] = useState('overview');
  const [focus, setFocus] = useState<ChatterFocus | undefined>();
  useCrumbTail(`${record.full_name} · ${record.code}`);
  const merged = record.record_status === 'DA_GOP';
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const appointments = useOpportunityAppointments({
    opportunityId: '',
    branchId: '',
    label: `${record.code} · ${record.full_name}`,
    catalogs,
    canEdit: access.can('APPOINTMENT', 'SUA') && record.record_status !== 'DA_GOP',
    canCancel: access.can('APPOINTMENT', 'HUY') && record.record_status !== 'DA_GOP',
    refresh: async () => {
      await refresh();
    },
    upcomingOfCustomer: { key: 'parent_id', id: record.id },
  });
  const canEdit = access.can('PARENT', 'SUA') && !merged;
  const openTickets = useOpenTicketCount(
    { key: 'parent_id', id: record.id },
    access.can('TICKET', 'XEM'),
  );
  // Gộp trùng dùng quyền Duyệt (R-CRM-25); bản đã gộp chỉ đọc.
  const canMerge = access.can('PARENT', 'DUYET') && !merged;
  const [mergeOpen, setMergeOpen] = useState(false);
  const [mode, setMode] = useState<DetailMode>('view');
  const [draft, setDraft] = useState<ParentDraft>(() => toParentDraft(record, null));
  const [errors, setErrors] = useState<Partial<Record<keyof ParentDraft, string>>>({});
  const [saving, setSaving] = useState(false);
  const editing = mode !== 'view';
  // Mã phường, tỉnh chỉ lấy khi vào chế độ Sửa (get_parent_record chỉ trả tên): gọi một lần rồi mới mở ô sửa.
  const [baseline, setBaseline] = useState<ParentDraft>(() => toParentDraft(record, null));
  const dirty = editing && JSON.stringify(draft) !== JSON.stringify(baseline);

  async function startEdit() {
    try {
      const refs = await rpc<{ ward_code: string | null; province_code: string | null }>(
        supabase,
        'get_parent_edit_refs',
        { p_id: record.id },
      );
      const initial = toParentDraft(record, refs);
      setBaseline(initial);
      setDraft(initial);
      setErrors({});
      setMode('edit');
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    }
  }
  function cancelEdit() {
    setErrors({});
    setMode('view');
  }
  function set<K extends keyof ParentDraft>(key: K, value: ParentDraft[K]) {
    setDraft((d) => ({ ...d, [key]: value }));
  }
  async function save() {
    // Luật: họ tên, số điện thoại bắt buộc; số còn lại để hàm DB kiểm.
    const found: Partial<Record<keyof ParentDraft, string>> = {};
    if (draft.full_name.trim() === '') found.full_name = 'Bắt buộc nhập họ tên';
    if (draft.phone.trim() === '') found.phone = 'Bắt buộc nhập số điện thoại';
    setErrors(found);
    if (Object.keys(found).length > 0) return;
    setSaving(true);
    try {
      await rpc<null>(supabase, 'update_parent', {
        p_id: record.id,
        p_data: {
          full_name: draft.full_name,
          phone: draft.phone,
          phone_2: draft.phone_2,
          relative_name: draft.relative_name,
          province_code: draft.province_code === '' ? null : draft.province_code,
          ward_code: draft.ward_code === '' ? null : draft.ward_code,
          address: draft.address,
        },
      });
      await refresh();
      setMode('view');
      toast({ title: 'Đã lưu.' });
    } catch (e) {
      const error = errorOf(e);
      if (error.code === 'HMT_SDT_SAI' || error.code === 'HMT_SDT_TRUNG')
        setErrors((x) => ({ ...x, phone: error.message }));
      else if (error.code === 'HMT_THIEU_THONG_TIN')
        setErrors((x) => ({ ...x, full_name: error.message }));
      else toast({ tone: 'danger', title: error.message });
    } finally {
      setSaving(false);
    }
  }
  const text = (
    key: Exclude<keyof ParentDraft, 'province_code' | 'ward_code'>,
    label: string,
    required = false,
  ) => (
    <DetailField
      mode={mode}
      label={label}
      required={required}
      value={String(record[key] ?? '')}
      error={errors[key] ?? null}
      editor={
        <input
          aria-label={label}
          value={draft[key]}
          onChange={(e) => set(key, e.target.value)}
          aria-invalid={errors[key] ? true : undefined}
          className={INPUT_CLASS}
        />
      }
    />
  );

  return (
    <>
      <RecordDetail
        kind="Phụ huynh"
        title={`${record.full_name} · ${record.code}`}
        mode={mode}
        dirty={dirty}
        saving={saving}
        readOnly={!canEdit}
        onEdit={() => void startEdit()}
        onSave={() => void save()}
        onCancel={cancelEdit}
        onRefresh={() => refresh()}
        menu={{
          label: 'Hành động',
          items: [
            {
              kind: 'action',
              label: 'Sửa',
              onSelect: () => void startEdit(),
              ...(canEdit
                ? {}
                : {
                    unavailable: merged
                      ? 'Hồ sơ đã gộp chỉ xem được'
                      : 'Bạn không có quyền sửa phụ huynh',
                  }),
            },
            {
              kind: 'action',
              label: 'Gộp',
              onSelect: () => setMergeOpen(true),
              ...(canMerge
                ? {}
                : {
                    unavailable: merged
                      ? 'Hồ sơ đã gộp chỉ xem được'
                      : 'Bạn không có quyền gộp (cần quyền Duyệt)',
                  }),
            },
            {
              kind: 'action',
              label: 'Tạo ticket',
              onSelect: () => void navigate(newTicketForParentPath(record.id, record.code)),
              ...(access.can('TICKET', 'TAO') && !merged
                ? {}
                : {
                    unavailable: merged
                      ? 'Hồ sơ đã gộp chỉ xem được'
                      : 'Bạn không có quyền tạo ticket',
                  }),
            },
          ],
        }}
        summary={
          <RecordSummary
            entityType="PARENT"
            entityId={record.id}
            label={`${record.code} · ${record.full_name}`}
            readOnly={merged}
            ticketPath={newTicketForParentPath(record.id, record.code)}
            // «Thiếu nhận xét» mở tab Các con.
            onFlag={(t) =>
              setTab(t === 'finance' || t === 'tickets' || t === 'upsale' ? t : 'children')
            }
            onChatter={(target) => setFocus((f) => ({ target, seq: (f?.seq ?? 0) + 1 }))}
          />
        }
        smart={[
          {
            key: 'con',
            label: 'Con',
            icon: 'training',
            count: record.counts.children,
            onOpen: () => setTab('children'),
          },
          {
            key: 'co-hoi',
            label: 'Cơ hội',
            icon: 'results',
            count: record.counts.opportunities,
            hidden: !access.can('OPPORTUNITY', 'XEM'),
            unavailable: 'Mở cơ hội từ menu Tuyển sinh',
            onOpen: () => undefined,
          },
          {
            key: 'phieu-test',
            label: 'Phiếu test',
            icon: 'results',
            count: record.counts.tests,
            hidden: !access.can('STUDENT_TEST', 'XEM'),
            unavailable: 'Mở phiếu test từ menu Tuyển sinh',
            onOpen: () => undefined,
          },
          {
            key: 'ghi-danh',
            label: 'Ghi danh',
            icon: 'training',
            count: record.counts.enrollments,
            hidden: !access.can('ENROLLMENT', 'XEM'),
            onOpen: () => setTab('finance'),
          },
          {
            key: 'ticket-mo',
            label: 'Ticket mở',
            icon: 'results',
            count: openTickets ?? 0,
            hidden: openTickets === undefined,
            onOpen: () => setTab('tickets'),
          },
          {
            key: 'phieu-thu',
            label: 'Phiếu thu',
            icon: 'results',
            count: record.counts.receipts,
            hidden: !access.can('RECEIPT', 'XEM'),
            onOpen: () => setTab('receipts'),
          },
        ]}
        aside={
          <RecordChatter
            entityType="PARENT"
            entityId={record.id}
            format={FORMAT}
            createdText="Tạo phụ huynh."
            canWrite={!merged}
            focus={focus}
            upcoming={access.can('APPOINTMENT', 'XEM') ? appointments.upcoming : undefined}
          />
        }
        asideLabel="Ghi chú và hoạt động"
      >
        {merged && (
          <p role="status" className="rounded-control bg-canvas p-3">
            Hồ sơ này đã gộp vào hồ sơ khác.{' '}
            {record.merged_into_id && (
              <FromLink
                className="font-medium text-link hover:underline"
                to={`/crm/phu-huynh/${record.merged_into_id}`}
              >
                Mở hồ sơ đích
              </FromLink>
            )}
          </p>
        )}
        <div className="flex flex-wrap items-center gap-2">
          <Tag tone={record.is_studying ? 'success' : 'neutral'}>
            {record.is_studying ? 'Có con đang học' : 'Chưa có con đang học'}
          </Tag>
        </div>
        <CustTabs
          active={tab}
          onChange={setTab}
          tabs={[
            { key: 'overview', label: 'Tổng quan' },
            { key: 'children', label: 'Các con' },
            { key: 'orders', label: 'Đơn hàng' },
            { key: 'receipts', label: 'Phiếu thu' },
            { key: 'tickets', label: 'Ticket' },
            { key: 'finance', label: 'Tài chính' },
            { key: 'upsale', label: 'Tái tục' },
            { key: 'appointments', label: 'Lịch hẹn' },
            { key: 'account', label: 'Tài khoản' },
          ]}
        />
        {tab === 'overview' && (
          <DetailSection title="Thông tin phụ huynh">
            {text('full_name', 'Họ tên', true)}
            {text('phone', 'Số điện thoại', true)}
            {text('phone_2', 'Số điện thoại 2')}
            {text('relative_name', 'Người thân')}
            <DetailField
              mode={mode}
              label="Tỉnh/Thành phố"
              value={record.province_name ?? ''}
              editor={
                <OptionalSelect
                  label="Tỉnh/Thành phố"
                  value={draft.province_code}
                  onChange={(v) => setDraft((d) => ({ ...d, province_code: v, ward_code: '' }))}
                  options={catalogs.options('PROVINCE', draft.province_code || undefined)}
                  placeholder="Chọn tỉnh/thành phố"
                />
              }
            />
            <DetailField
              mode={mode}
              label="Phường/Xã"
              value={record.ward_name ?? ''}
              editor={
                <OptionalSelect
                  label="Phường/Xã"
                  value={draft.ward_code}
                  onChange={(v) => set('ward_code', v)}
                  options={catalogs.childrenOf(
                    'WARD',
                    'PROVINCE',
                    draft.province_code,
                    draft.ward_code || undefined,
                  )}
                  placeholder="Chọn phường/xã"
                  disabled={draft.province_code === ''}
                />
              }
            />
            {text('address', 'Địa chỉ')}
            <DetailField
              mode="view"
              label="Cơ sở tiếp nhận"
              hint="cố định, chỉ Admin sửa"
              value={record.branch_code}
            />
            <DetailField
              mode="view"
              label="Đang học tại"
              hint="tự tính từ ghi danh của các con"
              value={record.studying_at.join(', ')}
            />
            <DetailField mode="view" label="Ngày tạo" value={formatDate(record.created_at)} />
          </DetailSection>
        )}
        {tab === 'children' &&
          (record.children.length === 0 ? (
            <p className="py-2 text-fg-muted">Chưa có học sinh.</p>
          ) : (
            <ul className="flex flex-col divide-y divide-border">
              {record.children.map((c) => (
                <li key={c.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
                  <button
                    type="button"
                    className="text-left font-medium text-link hover:underline"
                    onClick={() => void navigate(studentPath(c.id))}
                  >
                    {c.full_name}
                  </button>
                  <span className="text-caption text-fg-muted">
                    {c.code}
                    {c.grade ? ` · Lớp ${c.grade}` : ''} · {STUDENT_STATUS_LABEL[c.status]}
                  </span>
                </li>
              ))}
            </ul>
          ))}
        {tab === 'orders' && <ParentOrdersTab record={record} />}
        {tab === 'receipts' && <ParentReceiptsTab record={record} />}
        {tab === 'tickets' && <CustTickets owner={{ key: 'parent_id', id: record.id }} />}
        {tab === 'finance' && <ParentFinanceTab record={record} />}
        {tab === 'upsale' && <UpsaleTab owner={{ key: 'parent_id', id: record.id }} />}
        {tab === 'appointments' && <AppointmentTab owner={{ key: 'parent_id', id: record.id }} />}
        {tab === 'account' && <ParentAccountTab record={record} />}
      </RecordDetail>
      {appointments.dialogs}
      {canMerge && (
        <MergeDialog
          open={mergeOpen}
          onOpenChange={setMergeOpen}
          entity="PARENT"
          current={{
            id: record.id,
            code: record.code,
            label: record.full_name,
            phone: formatPhone(record.phone),
          }}
          onMerged={(keepId, keepCode) => {
            toast({ title: `Đã gộp vào ${keepCode}.` });
            if (keepId === record.id) void refresh();
            else void navigate(parentPath(keepId), { replace: true });
          }}
        />
      )}
    </>
  );
}
