// TS-08 Trang Cơ hội (xem, Sửa): khuôn K3 nối cơ sở dữ liệu. Đọc bằng get_opportunity (một lần gọi), sửa bằng update_opportunity
// (chỉ thông tin học sinh, nhu cầu, người hỗ trợ; phụ huynh và nguồn sửa ở nơi khác, R-CRM-27), đổi giai đoạn bằng
// change_opportunity_stage qua hộp TS-09 (chỉ đi tới, không Hoàn tác, R-CRM-02). Lịch hẹn ở cột phải (TS-13, R-CRM-04).
// Nút Tạo báo giá, Tạo đơn hàng (P5), Đính kèm (giai đoạn 4), Gộp trùng (P3f) chưa dùng được nên mờ hoặc ẩn.
import { useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { AssignDialog } from '../../features/assign/AssignDialog';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { MergeDialog } from '../../features/merge/MergeDialog';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { useOpportunityAppointments } from '../../features/appointments/useRecordAppointments';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { ProspectStudents } from '../../features/prospect/ProspectStudents';
import { emSaveFailedText, unsavedEmText } from '../../features/prospect/prospectLogic';
import { saveEm, useEmEditing } from '../../features/prospect/useEmEditing';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf, rpc, useDb } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail, type DetailMode } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { StateView, Spinner } from '../../ui/Feedback';
import { INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { Icon } from '../../ui/icons';
import { DateInput } from '../../ui/Inputs';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { Tabs } from '../../ui/Overlays';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { CreateTestDialog } from '../phieu/CreateTestDialog';
import { appointmentTag, codeAndName, formatPhone } from '../lead/leadFormat';
import { dateToIso, isoToDate } from '../lead/leadRecord';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { oppTitle } from './oppConfig';
import {
  OPP_FIELD_LABELS,
  oppHistoryValue,
  oppPayload,
  toOppDraft,
  validateOppDraft,
  type OppDraft,
  type OppDraftErrors,
} from './oppRecord';
import {
  lockedStageReason,
  planStageChange,
  stageIndex,
  substageDisplayCodes,
  substageRule,
} from './oppStage';
import type { OppRecord, OppTest } from './oppTypes';
import { StageDialog, type StageSubmit } from './StageDialog';
import {
  assignOpportunities,
  changeOpportunityStage,
  useOpportunity,
  useRefreshOppRecord,
} from './useOppData';

export function OpportunityRecordPage() {
  const { id } = useParams<{ id: string }>();
  const query = useOpportunity(id);
  if (query.isPending) return <Spinner label="Đang tải cơ hội…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem cơ hội này'
            : missing
              ? 'Không tìm thấy cơ hội'
              : 'Không tải được cơ hội'
        }
        actions={
          <>
            {/* duong-dan-menu: không tải được bản ghi, về danh sách chung */}
            <Link to="/crm/co-hoi" className="font-medium text-link hover:underline">
              Về danh sách Cơ hội
            </Link>
            {!forbidden && !missing && (
              <Button onClick={() => void query.refetch()}>Thử lại</Button>
            )}
          </>
        }
      >
        {errorOf(error).message}
      </StateView>
    );
  }
  return <OpportunityView key={query.data.id} record={query.data} />;
}

function OpportunityView({ record }: { record: OppRecord }) {
  const supabase = useDb();
  const navigate = useNavigate();
  const openFrom = useNavigateFrom();
  const toast = useToast();
  const access = useAccess();
  const catalogs = useLeadCatalogs();
  const refreshRecord = useRefreshOppRecord(record.id);
  const queryClient = useQueryClient();

  const merged = record.record_status === 'DA_GOP';
  // Tạo báo giá (R-CRM-19): cần quyền lập báo giá, phân hệ Bán hàng bật, cơ hội chưa gộp; máy chủ kiểm lại khi Lưu.
  const quoteReason: { ok: true } | { ok: false; reason: string } = merged
    ? { ok: false, reason: 'Cơ hội đã gộp vào bản khác, không tạo báo giá.' }
    : !access.can('QUOTATION', 'TAO')
      ? { ok: false, reason: 'Bạn không có quyền lập báo giá.' }
      : !access.featureOn('BAN_HANG')
        ? { ok: false, reason: 'Phân hệ Bán hàng chưa bật ở cơ sở này.' }
        : { ok: true };
  // Tạo đơn hàng (R-CRM-16): cơ hội ở L8, chưa gộp, có quyền tạo đơn, Bán hàng bật; máy chủ kiểm lại khi Lưu.
  const orderReason: { ok: true } | { ok: false; reason: string } = merged
    ? { ok: false, reason: 'Cơ hội đã gộp vào bản khác, không tạo đơn hàng.' }
    : record.stage_code !== 'L8'
      ? { ok: false, reason: 'Chỉ tạo đơn hàng khi cơ hội ở L8' }
      : !access.can('SALES_ORDER', 'TAO')
        ? { ok: false, reason: 'Bạn không có quyền tạo đơn hàng.' }
        : !access.featureOn('BAN_HANG')
          ? { ok: false, reason: 'Phân hệ Bán hàng chưa bật ở cơ sở này.' }
          : { ok: true };
  const canEdit = access.can('OPPORTUNITY', 'SUA') && !merged;
  const canAssign = access.can('OPPORTUNITY', 'GIAO_VIEC') && !merged;
  // Gộp trùng dùng quyền Duyệt trên phân hệ Cơ hội (R-CRM-22); bản đã gộp chỉ đọc.
  const canMerge = access.can('OPPORTUNITY', 'DUYET') && !merged;
  const canAppt = access.can('APPOINTMENT', 'TAO') && !merged;
  const canCreateTest = access.can('STUDENT_TEST', 'TAO') && !merged;

  const initial = useMemo<OppDraft>(() => toOppDraft(record), [record]);
  const [mode, setMode] = useState<DetailMode>('view');
  const [draft, setDraft] = useState<OppDraft>(initial);
  const [errors, setErrors] = useState<OppDraftErrors>({});
  const [saving, setSaving] = useState(false);
  const [tab, setTab] = useState('source');
  const [assignOpen, setAssignOpen] = useState(false);
  const [mergeOpen, setMergeOpen] = useState(false);
  const [moveTo, setMoveTo] = useState<string | null>(null);
  const [testOpen, setTestOpen] = useState(false);

  const editing = mode !== 'view';
  const ems = useEmEditing(record.students ?? []);
  const dirty =
    editing && (JSON.stringify(draft) !== JSON.stringify(initial) || ems.dirtyIds.length > 0);
  const view: OppDraft = editing ? draft : initial;
  const set = <K extends keyof OppDraft>(key: K, value: OppDraft[K]) => {
    setDraft((d) => ({ ...d, [key]: value }));
    setErrors((e) => ({ ...e, [key]: undefined }));
  };

  const staff = useAssignableStaff('OPPORTUNITY', record.branch_id, editing && canAssign);
  const staffOptions = (staff.data ?? []).map((s) => ({ value: s.id, label: s.display_name }));

  const title = oppTitle({
    parent_name: record.parent_name,
    student_name: view.student_name || null,
  });
  useCrumbTail(title);

  const appointments = useOpportunityAppointments({
    opportunityId: record.id,
    branchId: record.branch_id,
    label: [record.code, record.parent_name, record.student_name].filter(Boolean).join(' · '),
    catalogs,
    canEdit: access.can('APPOINTMENT', 'SUA') && !merged,
    canCancel: access.can('APPOINTMENT', 'HUY') && !merged,
    refresh: refreshRecord,
  });

  // ---- Lưu thông tin ----
  async function save() {
    const found = validateOppDraft(draft, record.stage_code);
    setErrors(found);
    if (Object.keys(found).length > 0) {
      // Ô lỗi của em đầu nằm ở thẻ em đầu: mở thẻ đó để người dùng thấy.
      if (found.student_name || found.student_birth_year) ems.select(null);
      return;
    }
    const em = ems.pending(stageIndex(record.stage_code) >= stageIndex('L5'));
    if (em?.error) {
      toast({ tone: 'danger', title: em.error });
      return;
    }
    setSaving(true);
    try {
      await rpc<null>(supabase, 'update_opportunity', {
        p_id: record.id,
        p_data: oppPayload(draft),
      });
      if (em) {
        try {
          await saveEm(supabase, em);
        } catch (e) {
          // Giữ thẻ và bản nháp của em đó; phần cơ hội đã lưu nên bản nháp của trang lấy theo dữ liệu mới.
          await refreshRecord();
          const saved = queryClient.getQueryData<OppRecord>(['opp-record', record.id]);
          if (saved) setDraft(toOppDraft(saved));
          toast({ tone: 'danger', title: emSaveFailedText('cơ hội', em.name, errorOf(e).message) });
          return;
        }
      }
      const others = ems.othersAfterSave();
      await refreshRecord();
      if (em) ems.discard(em.id);
      if (others.length === 0) {
        setMode('view');
        toast({ title: 'Đã lưu.' });
      } else {
        // Còn em khác chưa lưu: ở lại chế độ sửa, bản nháp của trang lấy theo dữ liệu vừa lưu.
        const fresh = queryClient.getQueryData<OppRecord>(['opp-record', record.id]);
        if (fresh) setDraft(toOppDraft(fresh));
        toast({ title: `Đã lưu. ${unsavedEmText(others)}` });
      }
    } catch (e) {
      const error = errorOf(e);
      if (error.code === 'HMT_THIEU_HOC_SINH') {
        ems.select(null);
        setErrors((x) => ({ ...x, student_name: error.message }));
      } else toast({ tone: 'danger', title: error.message });
    } finally {
      setSaving(false);
    }
  }

  function cancelEdit() {
    ems.reset();
    setDraft(initial);
    setErrors({});
    setMode('view');
  }

  // ---- Đổi giai đoạn, nhóm con (TS-09) ----
  const stageName = (code: string) => codeAndName(code, catalogs.name('OPP_STAGE', code));
  const plan = moveTo ? planStageChange(record, moveTo) : null;
  const lastCompleted: OppTest | null =
    record.tests.find((t) => t.status_code === 'COMPLETED') ?? null;

  async function submitStage(data: StageSubmit) {
    if (!moveTo) return;
    await changeOpportunityStage(supabase, {
      id: record.id,
      stage: moveTo,
      substage: data.substage,
      skipReason: data.skipReason,
      skipNote: data.skipReason ? (data.note.trim() === '' ? null : data.note.trim()) : null,
      confirmL8: data.confirmL8,
    });
    // Ghi chú của hộp (không phải lý do bỏ qua test) gắn vào cơ hội như một ghi chú thường.
    if (!data.skipReason && data.note.trim() !== '') {
      try {
        await rpc<string>(supabase, 'add_note', {
          p_entity_type: 'OPPORTUNITY',
          p_entity_id: record.id,
          p_body: data.note.trim(),
        });
      } catch (e) {
        toast({
          tone: 'warning',
          title: `Đã chuyển giai đoạn nhưng chưa lưu ghi chú: ${errorOf(e).message}`,
        });
      }
    }
    await refreshRecord();
    toast({ title: `Đã chuyển sang ${stageName(moveTo)}.` });
  }

  async function changeSubstage(next: string) {
    try {
      await changeOpportunityStage(supabase, {
        id: record.id,
        stage: record.stage_code,
        substage: next === '' ? null : next,
      });
      await refreshRecord();
      toast({ title: 'Đã đổi nhóm con.' });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    }
  }

  const stageSteps: StageStep[] = catalogs.options('OPP_STAGE').map((o) => {
    const reason = lockedStageReason(o.value);
    return { code: o.value, label: o.label, ...(reason ? { lockedReason: reason } : {}) };
  });
  const substageCodes = catalogs
    .childrenOf('OPP_SUBSTAGE', 'OPP_STAGE', record.stage_code)
    .map((o) => o.value);
  const rule = substageRule(record.stage_code, record.substage_code, substageCodes);
  const substageOptions = substageDisplayCodes(
    substageCodes,
    rule.allowed,
    record.substage_code,
  ).map((code) => ({
    value: code,
    label: codeAndName(code, catalogs.name('OPP_SUBSTAGE', code)),
  }));
  const showSubstage = substageCodes.length > 0 || record.substage_code !== null;

  // ---- Ô nhập ----
  const text = (
    key: 'student_name' | 'school' | 'self_rating' | 'goal',
    label: string,
    extra?: { hint?: string; placeholder?: string },
  ) => (
    <DetailField
      label={label}
      hint={extra?.hint}
      mode={mode}
      value={view[key]}
      error={errors[key] ?? null}
      editor={
        <input
          aria-label={label}
          value={draft[key]}
          placeholder={extra?.placeholder}
          onChange={(e) => set(key, e.target.value)}
          aria-invalid={errors[key] ? true : undefined}
          className={INPUT_CLASS}
        />
      }
    />
  );
  const tag = appointmentTag(record.next_appointment_at);
  const sourceName = catalogs.name('SOURCE', record.source_code);
  const sourceType = catalogs.name('SOURCE_TYPE', record.source_type_code);

  return (
    <>
      <RecordDetail
        kind="Cơ hội"
        title={title}
        mode={mode}
        dirty={dirty}
        saving={saving}
        readOnly={!canEdit}
        onEdit={() => {
          ems.reset();
          setDraft(initial);
          setErrors({});
          setMode('edit');
        }}
        onSave={() => void save()}
        onCancel={cancelEdit}
        headerActions={
          canAssign ? (
            <Button icon="user" onClick={() => setAssignOpen(true)}>
              Assign
            </Button>
          ) : undefined
        }
        menu={
          canAssign || canMerge
            ? {
                label: 'Hành động',
                items: [
                  ...(canAssign
                    ? [
                        {
                          kind: 'action' as const,
                          label: 'Giao người phụ trách',
                          onSelect: () => setAssignOpen(true),
                        },
                      ]
                    : []),
                  ...(canMerge
                    ? [
                        {
                          kind: 'action' as const,
                          label: 'Gộp trùng',
                          onSelect: () => setMergeOpen(true),
                        },
                      ]
                    : []),
                ],
              }
            : undefined
        }
        onRefresh={() => void refreshRecord()}
        stage={
          stageSteps.length > 0
            ? {
                steps: stageSteps,
                current: record.stage_code,
                forwardOnly: true,
                onSelect: (step) => {
                  if (merged) return;
                  setMoveTo(step.code);
                },
                onLockedClick: (_step, reason) => toast({ tone: 'warning', title: reason }),
              }
            : undefined
        }
        quietEdit
        businessActions={
          <>
            {/* R-CRM-19, R-TIEN-02: Tạo báo giá chỉ nằm ở bản ghi cơ hội, bấm chỉ mở form trắng. Có cả trên điện thoại (B-27-09). */}
            <Button
              variant={!orderReason.ok && quoteReason.ok ? 'primary' : 'secondary'}
              disabled={!quoteReason.ok}
              title={quoteReason.ok ? undefined : quoteReason.reason}
              onClick={() => openFrom(`/crm/bao-gia/tao?co-hoi=${record.id}`)}
            >
              Tạo báo giá
            </Button>
            {/* R-CRM-16, R-CRM-19, R-TIEN-39: Tạo đơn hàng chỉ ở cơ hội L8, bấm chỉ mở form trắng. Có cả trên điện thoại (B-27-09). */}
            <Button
              variant={orderReason.ok ? 'primary' : 'secondary'}
              disabled={!orderReason.ok}
              title={orderReason.ok ? undefined : orderReason.reason}
              onClick={() => openFrom(`/crm/don-hang/tao?co-hoi=${record.id}`)}
            >
              Tạo đơn hàng
            </Button>
          </>
        }
        subStage={
          showSubstage ? (
            <>
              <span className="text-caption font-semibold text-fg-label">Sub-stage</span>
              {rule.lockedReason ? (
                <span className="relative" title={rule.lockedReason}>
                  <input
                    readOnly
                    aria-label="Sub-stage"
                    value={
                      record.substage_code
                        ? codeAndName(
                            record.substage_code,
                            catalogs.name('OPP_SUBSTAGE', record.substage_code),
                          )
                        : 'Chưa có'
                    }
                    className={`${INPUT_CLASS} w-72 pr-8`}
                  />
                  <Icon
                    name="forbidden"
                    size={16}
                    className="pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 text-fg-muted"
                  />
                </span>
              ) : (
                <OptionalSelect
                  label="Sub-stage"
                  value={record.substage_code ?? ''}
                  onChange={(v) => void changeSubstage(v)}
                  options={substageOptions}
                  placeholder="Chưa có"
                  disabled={!canEdit}
                />
              )}
            </>
          ) : undefined
        }
        smart={[
          {
            key: 'lich-hen',
            label: 'Lịch hẹn',
            icon: 'calendar',
            count: record.appointments_total,
            onOpen: () =>
              openFrom(`/crm/lich-hen?co-hoi=${record.id}&ma=${encodeURIComponent(record.code)}`),
          },
          {
            key: 'kiem-tra',
            label: 'Kiểm tra',
            icon: 'results',
            count: record.tests_total,
            onOpen: (target) => {
              // Một phiếu thì mở thẳng phiếu; nhiều phiếu thì mở danh sách đã lọc theo cơ hội (K3, smart button).
              const only = record.tests[0];
              if (target === 'record' && only) openFrom(`/crm/phieu-kiem-tra/${only.id}`);
              else
                openFrom(
                  `/crm/phieu-kiem-tra?co-hoi=${record.id}&ma=${encodeURIComponent(record.code)}`,
                );
            },
          },
          {
            key: 'bao-gia',
            label: 'Báo giá',
            icon: 'payment',
            // Mã báo giá (BG-…) còn hiệu lực của cơ hội; sales_documents gộp cả mã đơn (DH-…), tách theo tiền tố mã (docs/spec/02).
            count: (record.sales_documents ?? []).filter((c) => c.startsWith('BG-')).length,
            hidden: !access.can('QUOTATION', 'XEM'),
            // Danh sách báo giá đã lọc theo cơ hội (chỉ có mã, chưa có id nên một bản ghi cũng mở danh sách).
            onOpen: () =>
              openFrom(`/crm/bao-gia?co-hoi=${record.id}&ma=${encodeURIComponent(record.code)}`),
          },
          {
            key: 'don-hang',
            label: 'Đơn hàng',
            icon: 'file',
            count: (record.sales_documents ?? []).filter((c) => c.startsWith('DH-')).length,
            hidden: !access.can('SALES_ORDER', 'XEM'),
            onOpen: () =>
              openFrom(`/crm/don-hang?co-hoi=${record.id}&ma=${encodeURIComponent(record.code)}`),
          },
          {
            key: 'phu-huynh',
            label: 'Phụ huynh',
            icon: 'user',
            count: 1,
            onOpen: () => openFrom(`/crm/phu-huynh/${record.parent_id}`),
          },
          {
            key: 'lead-goc',
            label: 'Lead gốc',
            icon: 'recruit',
            count: 1,
            // Cơ hội tạo trực tiếp không có lead gốc (R-CRM-01).
            hidden: record.lead_id === null,
            onOpen: () => openFrom(`/crm/lead/${record.lead_id}`),
          },
        ]}
        aside={
          <RecordChatter
            entityType="OPPORTUNITY"
            entityId={record.id}
            createdText="Tạo cơ hội."
            format={{ labels: OPP_FIELD_LABELS, value: oppHistoryValue(catalogs, record) }}
            canWrite={!merged}
            actions={
              <>
                {canAppt && (
                  <Button icon="calendar" onClick={appointments.openCreate}>
                    Lên lịch hẹn
                  </Button>
                )}
                {!merged && (
                  <Button
                    icon="results"
                    disabled={!canCreateTest || stageIndex(record.stage_code) < stageIndex('L5')}
                    title={
                      stageIndex(record.stage_code) < stageIndex('L5')
                        ? 'Chỉ tạo phiếu khi cơ hội ở L5 trở đi'
                        : !canCreateTest
                          ? 'Bạn không có quyền tạo phiếu kiểm tra'
                          : undefined
                    }
                    onClick={() => setTestOpen(true)}
                  >
                    Tạo lịch Test
                  </Button>
                )}
              </>
            }
            upcoming={appointments.upcoming}
          />
        }
      >
        {merged && record.merged_into_code && (
          <p className="mb-4 rounded-control bg-surface-subtle px-3 py-2 text-fg-muted">
            <Tag>Đã gộp</Tag> Cơ hội này đã gộp vào <b>{record.merged_into_code}</b>, chỉ đọc.
          </p>
        )}
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin phụ huynh">
            <DetailField label="Họ tên" mode="view" value={record.parent_name} />
            <DetailField
              label="Số điện thoại"
              mode="view"
              value={formatPhone(record.parent_phone)}
            />
            <DetailField
              label="Tỉnh/Thành phố"
              mode="view"
              value={catalogs.name('PROVINCE', record.parent_province_code) ?? ''}
            />
            <DetailField
              label="Phường/Xã"
              mode="view"
              value={catalogs.name('WARD', record.parent_ward_code) ?? ''}
            />
            <DetailField label="Địa chỉ" mode="view" value={record.parent_address ?? ''} />
            <DetailField
              label="Nhu cầu"
              mode={mode}
              value={view.need}
              editor={
                <TextAreaField
                  label="Nhu cầu"
                  value={draft.need}
                  placeholder="Nhu cầu của phụ huynh"
                  onChange={(e) => set('need', e.target.value)}
                />
              }
            />
          </DetailSection>
          <ProspectStudents
            entity="OPPORTUNITY"
            recordId={record.id}
            students={record.students ?? []}
            parent={{ id: record.parent_id, code: record.parent_code, name: record.parent_name }}
            requireYear={stageIndex(record.stage_code) >= stageIndex('L5')}
            canEdit={canEdit}
            mode={mode}
            ems={ems}
            onChanged={() => void refreshRecord()}
            firstFields={
              <>
                {text('student_name', 'Tên học sinh', {
                  hint: 'bắt buộc từ L5',
                  placeholder: 'Tên (bắt buộc từ L5)',
                })}
                <DetailField
                  label="Ngày sinh"
                  mode={mode}
                  value={
                    view.student_birth_date
                      ? formatDate(`${view.student_birth_date}T00:00:00+07:00`)
                      : ''
                  }
                  editor={
                    <DateInput
                      label="Ngày sinh"
                      compact
                      value={isoToDate(draft.student_birth_date)}
                      onChange={(d) => set('student_birth_date', dateToIso(d))}
                    />
                  }
                />
                <DetailField
                  label="Năm sinh"
                  hint="bắt buộc từ L5"
                  mode={mode}
                  value={view.student_birth_year}
                  error={errors.student_birth_year ?? null}
                  editor={
                    <input
                      aria-label="Năm sinh"
                      inputMode="numeric"
                      value={draft.student_birth_year}
                      placeholder="VD 2012 (bắt buộc từ L5)"
                      onChange={(e) => set('student_birth_year', e.target.value)}
                      aria-invalid={errors.student_birth_year ? true : undefined}
                      className={INPUT_CLASS}
                    />
                  }
                />
                {text('school', 'Trường học', {
                  placeholder: 'Tên trường',
                })}
                {text('self_rating', 'Học lực tự đánh giá', {
                  placeholder: 'VD Khá, yếu phần Hình',
                })}
                {text('goal', 'Mục tiêu', {
                  placeholder: 'Mục tiêu của học sinh',
                })}
              </>
            }
          />
        </div>
        <div className="mt-6">
          <Tabs
            label="Nội dung bản ghi"
            value={tab}
            onChange={setTab}
            items={[
              {
                value: 'source',
                label: 'Nguồn và phụ trách',
                content: (
                  <div className="grid grid-cols-1 gap-x-10 lg:grid-cols-2">
                    <dl className="flex flex-col">
                      <DetailField
                        label="Cơ sở"
                        mode="view"
                        value={`${record.branch_code} ${record.branch_name}`}
                      />
                      <DetailField
                        label="Nhân sự phụ trách"
                        mode="view"
                        value={record.owner_name ?? ''}
                      />
                      <DetailField
                        label="Nhân sự hỗ trợ"
                        mode={mode}
                        value={record.supporter_name ?? ''}
                        editor={
                          <OptionalSelect
                            label="Nhân sự hỗ trợ"
                            value={draft.supporter_id}
                            onChange={(v) => set('supporter_id', v)}
                            options={staffOptions}
                            placeholder="Chọn nhân sự"
                          />
                        }
                      />
                    </dl>
                    <dl className="flex flex-col">
                      <DetailField
                        label="Source"
                        mode="view"
                        value={
                          <>
                            {sourceName ?? record.source_code}
                            {sourceType && (
                              <span className="ml-1.5 text-caption text-fg-muted">
                                ({sourceType})
                              </span>
                            )}
                          </>
                        }
                      />
                      <DetailField
                        label="Sub-source"
                        mode="view"
                        value={catalogs.name('SOURCE_CHANNEL', record.channel_code) ?? ''}
                      />
                      <DetailField
                        label="Chiến dịch"
                        mode="view"
                        value={record.campaign_name ?? ''}
                      />
                    </dl>
                  </div>
                ),
              },
              {
                value: 'time',
                label: 'Mốc thời gian',
                content: (
                  <dl className="grid grid-cols-1 gap-x-10 lg:grid-cols-2">
                    <DetailField
                      label="Ngày tạo"
                      mode="view"
                      value={`${formatDateTime(record.created_at)}${record.created_by_name ? ` · ${record.created_by_name}` : ''}`}
                    />
                    <DetailField
                      label="Cập nhật lần cuối"
                      mode="view"
                      value={`${formatDateTime(record.updated_at)}${record.updated_by_name ? ` · ${record.updated_by_name}` : ''}`}
                    />
                    <DetailField
                      label="Ngày giao"
                      mode="view"
                      value={formatDateTime(record.assigned_at)}
                    />
                    <DetailField
                      label="Lịch hẹn kế tiếp"
                      mode="view"
                      value={
                        <Tag tone={tag.tone} dot>
                          {tag.label}
                        </Tag>
                      }
                    />
                    <DetailField
                      label="Lead gốc"
                      mode="view"
                      value={record.lead_code ?? 'Không có (tạo trực tiếp)'}
                    />
                    {record.legacy_ref && (
                      <DetailField label="Mã cũ (Sheet)" mode="view" value={record.legacy_ref} />
                    )}
                  </dl>
                ),
              },
            ]}
          />
        </div>
      </RecordDetail>

      {canMerge && (
        <MergeDialog
          open={mergeOpen}
          onOpenChange={setMergeOpen}
          entity="OPPORTUNITY"
          current={{
            id: record.id,
            code: record.code,
            label: oppTitle(record),
            phone: formatPhone(record.parent_phone),
          }}
          onMerged={(keepId, keepCode) => {
            toast({ title: `Đã gộp vào ${keepCode}.` });
            if (keepId === record.id) void refreshRecord();
            // duong-dan-menu: bản đang xem đã gộp, không còn để quay lại
            else void navigate(`/crm/co-hoi/${keepId}`, { replace: true });
          }}
        />
      )}
      <AssignDialog
        open={assignOpen}
        onOpenChange={setAssignOpen}
        entityType="OPPORTUNITY"
        noun="cơ hội"
        codes={[record.code]}
        branchCodes={[record.branch_code]}
        onAssign={async (ownerId, ownerName) => {
          await assignOpportunities(supabase, [record.id], ownerId);
          await refreshRecord();
          toast({ title: `Đã giao ${record.code} cho ${ownerName}.` });
        }}
      />
      {appointments.dialogs}
      <CreateTestDialog
        open={testOpen}
        onOpenChange={setTestOpen}
        opportunity={{
          id: record.id,
          code: record.code,
          student_name: record.student_name,
          students: record.students ?? [],
          parent_name: record.parent_name,
          branch_id: record.branch_id,
        }}
        catalogs={catalogs}
        onCreated={async (created) => {
          await refreshRecord();
          toast({ title: `Đã tạo phiếu ${created.code}.` });
          openFrom(`/crm/phieu-kiem-tra/${created.id}`);
        }}
      />
      {moveTo && plan && (
        <StageDialog
          open
          onOpenChange={(open) => !open && setMoveTo(null)}
          subtitle={`Cơ hội ${record.code} · ${oppTitle(record)} · đang ở ${stageName(record.stage_code)}${
            record.substage_code
              ? ` (${codeAndName(record.substage_code, catalogs.name('OPP_SUBSTAGE', record.substage_code))})`
              : ''
          }`}
          target={moveTo}
          plan={plan}
          catalogs={catalogs}
          lastCompleted={lastCompleted}
          onFillMissing={() => {
            setDraft(initial);
            setErrors(validateOppDraft(initial, moveTo));
            setMode('edit');
          }}
          onOpenTest={(testId) => openFrom(`/crm/phieu-kiem-tra/${testId}`)}
          onSubmit={submitStage}
        />
      )}
    </>
  );
}
