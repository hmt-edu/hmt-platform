// TS-02 Trang Lead (xem, Sửa) và TS-03 Tạo lead nhanh: khuôn K3 nối cơ sở dữ liệu. Thông tin đọc bằng get_lead (một lần gọi),
// lưu bằng create_lead, update_lead; đổi giai đoạn bằng change_lead_stage (tự do hai chiều, có Hoàn tác, R-CRM-09);
// lịch hẹn ở cột phải (TS-13, R-CRM-04, R-CRM-38). Nút Tạo cơ hội mở hộp TS-06 (P3d); Hành động → Gộp trùng mở hộp TS-10 (P3f); Đính kèm (giai đoạn 4),
// phân trang "n / tổng" chưa có nên chưa hiện.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams, useLocation } from 'react-router';
import { AssignDialog } from '../../features/assign/AssignDialog';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { MergeDialog } from '../../features/merge/MergeDialog';
import {
  cancelAppointment,
  completeAppointment,
  createLeadAppointment,
  rescheduleAppointment,
  useLeadUpcoming,
  useRefreshLeadRecord,
  type UpcomingAppointment,
} from '../../features/appointments/appointmentApi';
import { AppointmentDialog } from '../../features/appointments/AppointmentDialog';
import {
  CompleteAppointmentDialog,
  type CompleteArgs,
} from '../../features/appointments/CompleteAppointmentDialog';
import { useUndoAppointment } from '../../features/appointments/useUndoAppointment';
import { UpcomingActivities } from '../../features/appointments/UpcomingActivities';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { HmtError, rpc, errorOf, useDb } from '../../lib/db';
import { CreateOpportunityDialog } from '../co-hoi/CreateOpportunityDialog';
import type { OpportunityPage } from '../co-hoi/oppTypes';
import { formatDate, formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { ProspectStudents } from '../../features/prospect/ProspectStudents';
import { emSaveFailedText, unsavedEmText } from '../../features/prospect/prospectLogic';
import { saveEm, useEmEditing } from '../../features/prospect/useEmEditing';
import { DetailField, DetailSection, RecordDetail, type DetailMode } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Chatter } from '../../ui/Chatter';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, DuplicateDialog, ReasonDialog } from '../../ui/Dialogs';
import { Alert, StateView, Spinner } from '../../ui/Feedback';
import { INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { Icon } from '../../ui/icons';
import { DateInput } from '../../ui/Inputs';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { Tabs } from '../../ui/Overlays';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { useCrumbTail } from '../../layout/CrumbTail';
import { useAuth } from '../../lib/auth/authContext';
import { appointmentTag, codeAndName, formatPhone, leadTitle } from './leadFormat';
import {
  BLANK_DRAFT,
  LEAD_FIELD_LABELS,
  dateToIso,
  draftPayload,
  isoToDate,
  leadHistoryValue,
  toDraft,
  validateDraft,
  type DraftErrors,
  type LeadDraft,
  type LeadRecord,
} from './leadRecord';
import { changeLeadStage } from './useLeadData';
import { LeadStageDialog } from './LeadStageDialog';
import { CancelLeadDialog } from './CancelLeadDialog';
import { SYSTEM_SUBSTAGE, canRestore, selectableSubstages } from './leadStage';
import { useLeadCatalogs } from './useCatalogs';
import { FromLink } from '../../layout/FromLink';

/** Giai đoạn con do hệ thống gắn (R-CRM-09): ô khoá, không đặt lại bằng tay nên rời khỏi thì không có Hoàn tác. */
const CREATE_OPP_BLOCKED_REASON =
  'Lead cần ở nhóm con C4C "Đủ điều kiện tạo cơ hội" mới tạo được cơ hội. Đổi giai đoạn của lead trước.';
/** Lead tạo cơ hội được khi ở C4C, hoặc C4D (đã có cơ hội, tạo thêm có xác nhận lần hai, R-CRM-01). */
const canOpenOpp = (substage: string | null) => substage === 'C4C' || substage === SYSTEM_SUBSTAGE;

// E67: hồ sơ ngoài phạm vi (visible = false) máy chủ KHÔNG trả id, mã, tên, cơ sở; người xem chỉ biết «đã có trong hệ thống».
type Duplicate = {
  kind: 'LEAD' | 'PARENT';
  id: string | null;
  code: string | null;
  label: string | null;
  branch_code: string | null;
  visible: boolean;
};

function useLead(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['lead-record', id],
    enabled: id !== undefined,
    queryFn: () => rpc<LeadRecord>(supabase, 'get_lead', { p_id: id }),
    retry: false,
  });
}

export function LeadRecordPage({ creating = false }: { creating?: boolean }) {
  const { id } = useParams<{ id: string }>();
  const query = useLead(creating ? undefined : id);
  if (creating) return <LeadRecordView record={null} />;
  if (query.isPending) return <Spinner label="Đang tải lead…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem lead này'
            : missing
              ? 'Không tìm thấy lead'
              : 'Không tải được lead'
        }
        actions={
          <>
            {/* duong-dan-menu: không tải được bản ghi, về danh sách chung */}
            <Link to="/crm/lead" className="font-medium text-link hover:underline">
              Về danh sách Lead
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
  return <LeadRecordView key={query.data.id} record={query.data} />;
}

function LeadRecordView({ record }: { record: LeadRecord | null }) {
  const supabase = useDb();
  const navigate = useNavigate();
  const location = useLocation();
  const openFrom = useNavigateFrom();
  const toast = useToast();
  const access = useAccess();
  const { claims } = useAuth();
  const queryClient = useQueryClient();
  const catalogs = useLeadCatalogs();

  const creating = record === null;
  const merged = record?.record_status === 'DA_GOP';
  // Lead đã huỷ nhập nhầm (CHUNG-20) cũng chỉ xem, như bản đã gộp.
  const cancelled = record?.record_status === 'DA_HUY';
  const locked = merged || cancelled;
  const canCancelLead = access.can('ADMIN', 'TAO') && record?.record_status === 'DANG_DUNG';
  const [cancelOpen, setCancelOpen] = useState(false);
  const canEdit = access.can('LEAD', 'SUA') && !locked;
  const canAssign = access.can('LEAD', 'GIAO_VIEC') && !locked;
  const canCreate = access.can('LEAD', 'TAO');
  // Gộp trùng dùng quyền Duyệt trên phân hệ Lead (R-CRM-22); bản đã gộp chỉ đọc.
  const canMerge = access.can('LEAD', 'DUYET') && !locked;
  const canAppt = access.can('APPOINTMENT', 'TAO') && !locked;
  const canCreateOpp = access.can('OPPORTUNITY', 'TAO') && !locked;
  const refreshRecord = useRefreshLeadRecord(record?.id ?? '');
  const undoAppointment = useUndoAppointment(refreshRecord);

  const myBranch = access.teachingBranches.find((b) => b.code === claims?.branchCode);
  const initial = useMemo<LeadDraft>(
    () =>
      record
        ? toDraft(record)
        : { ...BLANK_DRAFT, branch_id: myBranch?.id ?? '', owner_id: claims?.userId ?? '' },
    [record, myBranch?.id, claims?.userId],
  );
  const [mode, setMode] = useState<DetailMode>(creating ? 'create' : 'view');
  const [draft, setDraft] = useState<LeadDraft>(initial);
  const [errors, setErrors] = useState<DraftErrors>({});
  const [saving, setSaving] = useState(false);
  const [tab, setTab] = useState('source');
  const [duplicates, setDuplicates] = useState<Duplicate[] | null>(null);
  // TS-03 (canvas): cảnh báo trùng SĐT ngay dưới ô Số điện thoại khi rời ô, trước khi bấm Lưu. Hộp thoại lúc Lưu vẫn là lớp chặn thứ hai.
  const [inlineDup, setInlineDup] = useState<{ phone: string; rows: Duplicate[] } | null>(null);
  const [confirmPhone, setConfirmPhone] = useState(false);
  const [assignOpen, setAssignOpen] = useState(false);
  const [mergeOpen, setMergeOpen] = useState(false);
  const [apptOpen, setApptOpen] = useState(false);
  const [oppOpen, setOppOpen] = useState(false);
  // Giai đoạn đang chờ chọn nhóm con (R-CRM-41): mở hộp chọn Sub-stage.
  const [stagePick, setStagePick] = useState<string | null>(null);
  const [moving, setMoving] = useState<AppointmentRow | null>(null);
  const [canceling, setCanceling] = useState<UpcomingAppointment | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [completing, setCompleting] = useState<UpcomingAppointment | null>(null);
  // Rời trang có chủ ý (tạo xong, Huỷ khi Tạo): bỏ cờ "chưa lưu" rồi mới chuyển, để hộp hỏi rời trang không hiện.
  const [exitTo, setExitTo] = useState<string | null>(null);
  useEffect(() => {
    // Bản ghi mới thay tầng «Tạo mới», giữ chuỗi nơi mở.
    if (exitTo !== null) void navigate(exitTo, { replace: true, state: location.state as unknown });
  }, [exitTo, navigate, location.state]);

  const editing = mode !== 'view';
  const ems = useEmEditing(record?.students ?? []);
  const dirty =
    editing &&
    exitTo === null &&
    (JSON.stringify(draft) !== JSON.stringify(initial) || ems.dirtyIds.length > 0);
  const view: LeadDraft = editing ? draft : initial;
  const set = <K extends keyof LeadDraft>(key: K, value: LeadDraft[K]) => {
    setDraft((d) => ({ ...d, [key]: value }));
    setErrors((e) => ({ ...e, [key]: undefined }));
  };

  const branchId = draft.branch_id || record?.branch_id || '';
  const staff = useAssignableStaff('LEAD', branchId || null, editing && branchId !== '');
  const staffOptions = (staff.data ?? []).map((s) => ({ value: s.id, label: s.display_name }));
  const upcoming = useLeadUpcoming(record?.id ?? null);

  // R-V2-43: bản ghi cũ vẫn hiện nguồn và kênh đã lưu dù đã Ngừng (hoặc nguồn cha đã Ngừng); ô chọn mới không hiện mục Ngừng.
  const channelOptions = catalogs.childrenOf(
    'SOURCE_CHANNEL',
    'SOURCE',
    draft.source_code,
    record?.channel_code,
  );
  const sourceOptions = catalogs.options('SOURCE', record?.source_code);
  const wardOptions = catalogs.childrenOf('WARD', 'PROVINCE', draft.province_code);

  // ---- Lưu ----
  async function save(confirmDuplicate = false, parentId: string | null = null) {
    const found = validateDraft(draft, { creating, channelRequired: channelOptions.length > 0 });
    setErrors(found);
    if (Object.keys(found).length > 0) {
      // Ô lỗi của em đầu nằm ở thẻ em đầu: mở thẻ đó trước khi đưa con trỏ tới.
      if (found.student_name || found.student_birth_year) ems.select(null);
      // T2-01: báo ngay ở đầu trang và đưa con trỏ tới ô lỗi đầu tiên, không để lỗi nằm im dưới màn hình.
      toast({
        tone: 'danger',
        title: `Chưa lưu được: còn ${Object.keys(found).length} ô cần điền hoặc sửa (báo đỏ).`,
      });
      requestAnimationFrame(() => {
        const first = document.querySelector<HTMLElement>('[aria-invalid="true"]');
        first?.scrollIntoView({ block: 'center' });
        first?.focus();
      });
      return;
    }
    const em = ems.pending(false);
    if (em?.error) {
      toast({ tone: 'danger', title: em.error });
      return;
    }
    setSaving(true);
    try {
      const payload = draftPayload(draft, catalogs, { creating });
      if (creating) {
        const created = await rpc<{ id: string; code: string }>(supabase, 'create_lead', {
          p_data: payload,
          p_confirm_duplicate: confirmDuplicate,
          p_parent_id: parentId,
        });
        await queryClient.invalidateQueries({ queryKey: ['lead-list'] });
        await queryClient.invalidateQueries({ queryKey: ['lead-board'] });
        toast({ title: `Đã tạo lead ${created.code}.` });
        setExitTo(`/crm/lead/${created.id}`);
      } else if (record) {
        await rpc<null>(supabase, 'update_lead', {
          p_id: record.id,
          p_data: payload,
          p_confirm_duplicate: confirmDuplicate,
        });
        if (em) {
          try {
            await saveEm(supabase, em);
          } catch (e) {
            // Giữ thẻ và bản nháp của em đó; phần lead đã lưu nên bản nháp của trang lấy theo dữ liệu mới.
            await refreshRecord();
            const saved = queryClient.getQueryData<LeadRecord>(['lead-record', record.id]);
            if (saved) setDraft(toDraft(saved));
            toast({ tone: 'danger', title: emSaveFailedText('lead', em.name, errorOf(e).message) });
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
          const fresh = queryClient.getQueryData<LeadRecord>(['lead-record', record.id]);
          if (fresh) setDraft(toDraft(fresh));
          toast({ title: `Đã lưu. ${unsavedEmText(others)}` });
        }
      }
    } catch (e) {
      const error = errorOf(e);
      if (error.code === 'HMT_SDT_TRUNG') {
        if (creating) {
          const rows = await rpc<Duplicate[]>(supabase, 'find_duplicate_contacts', {
            p_phone: draft.parent_phone.replace(/[\s.-]/g, ''),
            p_exclude_lead_id: null,
          });
          setDuplicates(rows);
        } else setConfirmPhone(true);
      } else if (error.code === 'HMT_SDT_SAI')
        setErrors((x) => ({ ...x, parent_phone: error.message }));
      else if (error.code === 'HMT_THIEU_NGUON')
        setErrors((x) => ({ ...x, source_code: error.message }));
      else toast({ tone: 'danger', title: error.message });
    } finally {
      setSaving(false);
    }
  }

  function cancelEdit() {
    ems.reset();
    setDraft(initial);
    setErrors({});
    if (creating) setExitTo('/crm/lead');
    else setMode('view');
  }

  // ---- Đổi giai đoạn, nhóm con (R-CRM-09) ----
  async function moveStage(stage: string, substage: string | null, throwOnError = false) {
    if (!record) return;
    const previous = { stage: record.stage_code, substage: record.substage_code };
    try {
      await changeLeadStage(supabase, record.id, stage, substage);
      await refreshRecord();
      toast({
        title: `Đã chuyển sang ${codeAndName(stage, catalogs.name('LEAD_STAGE', stage))}.`,
        ...(canRestore(catalogs, previous.stage, previous.substage)
          ? {
              action: {
                label: 'Hoàn tác',
                onClick: () => {
                  void changeLeadStage(supabase, record.id, previous.stage, previous.substage)
                    .then(refreshRecord)
                    .then(() => toast({ title: 'Đã hoàn tác.' }))
                    .catch((e: unknown) =>
                      toast({
                        tone: 'danger',
                        title: errorOf(e).message,
                      }),
                    );
                },
              },
            }
          : {}),
      });
    } catch (e) {
      if (throwOnError) throw e;
      toast({ tone: 'danger', title: errorOf(e).message });
    }
  }

  // Chọn giai đoạn: có nhóm con chọn tay thì hỏi nhóm con trước (R-CRM-41), không thì đổi luôn.
  function requestStage(stage: string) {
    if (selectableSubstages(catalogs, stage).length > 0) setStagePick(stage);
    else void moveStage(stage, null);
  }

  async function changeSubstage(next: string) {
    if (!record) return;
    const previous = record.substage_code;
    try {
      await changeLeadStage(supabase, record.id, record.stage_code, next === '' ? null : next);
      await refreshRecord();
      toast({
        title: 'Đã đổi nhóm con.',
        action: {
          label: 'Hoàn tác',
          onClick: () => {
            void changeLeadStage(supabase, record.id, record.stage_code, previous)
              .then(refreshRecord)
              .then(() => toast({ title: 'Đã hoàn tác.' }))
              .catch((e: unknown) => toast({ tone: 'danger', title: errorOf(e).message }));
          },
        },
      });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    }
  }

  // ---- Lịch hẹn (R-CRM-04) ----
  /** Hộp «Hoàn thành lịch hẹn» (TS-11): lỗi ném lại để hộp hiện câu lỗi. */
  async function completeWith(id: string, args: CompleteArgs) {
    await completeAppointment(supabase, id, args);
    await refreshRecord();
    toast({ title: 'Đã hoàn thành lịch hẹn.', action: undoAppointment(id) });
  }

  /** Nút "Cơ hội": một cơ hội thì mở thẳng bản ghi, nhiều thì mở danh sách đã lọc theo lead (K3, smart button). */
  async function openOpportunities(rec: LeadRecord, target: 'list' | 'record' | 'empty-list') {
    if (target === 'record') {
      try {
        const page = await rpc<OpportunityPage>(supabase, 'list_opportunities', {
          p_filters: { lead_id: rec.id },
          p_sort: 'created_asc',
          p_limit: 1,
          p_offset: 0,
        });
        const only = page.rows[0];
        if (only) {
          openFrom(`/crm/co-hoi/${only.id}`);
          return;
        }
      } catch (e) {
        toast({ tone: 'danger', title: errorOf(e).message });
        return;
      }
    }
    openFrom(`/crm/co-hoi?lead=${rec.id}&ma=${encodeURIComponent(rec.code)}`);
  }

  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;
  const target = record
    ? {
        label: [record.code, record.parent_name, record.student_name].filter(Boolean).join(' · '),
        branchId: record.branch_id,
      }
    : null;

  const stageSteps: StageStep[] = catalogs.options('LEAD_STAGE').map((o) => ({
    code: o.value,
    label: o.label,
  }));
  const substageOptions = record ? selectableSubstages(catalogs, record.stage_code) : [];
  const lockedSubstage = record?.substage_code === SYSTEM_SUBSTAGE;

  const title = creating ? '' : [view.parent_name, view.student_name].filter(Boolean).join(' · ');
  useCrumbTail(creating ? 'Tạo mới' : title);

  // ---- Ô nhập ----
  // Ô bắt buộc còn trống (chưa báo lỗi): viền cam, nền cam nhạt như bản vẽ; báo lỗi thì viền đỏ.
  const emptyRequired = (key: keyof LeadDraft, needed = true) =>
    editing && needed && draft[key].trim() === '' && !errors[key];

  async function checkPhoneDuplicate() {
    if (!creating) return;
    const phone = draft.parent_phone.replace(/[\s.-]/g, '');
    if (!/^0[0-9]{9}$/.test(phone) || inlineDup?.phone === phone) return;
    try {
      const rows = await rpc<Duplicate[]>(supabase, 'find_duplicate_contacts', {
        p_phone: phone,
        p_exclude_lead_id: null,
      });
      setInlineDup({ phone, rows });
    } catch {
      // Lỗi mạng ở bước dò sớm: bỏ qua, lúc bấm Lưu máy chủ vẫn chặn trùng.
      setInlineDup(null);
    }
  }

  const text = (
    key:
      | 'parent_name'
      | 'parent_phone'
      | 'address'
      | 'student_name'
      | 'school'
      | 'self_rating'
      | 'goal',
    label: string,
    extra?: {
      required?: boolean;
      hint?: string;
      placeholder?: string;
      show?: (value: string) => string;
      onBlur?: () => void;
    },
  ) => (
    <DetailField
      label={label}
      required={extra?.required}
      hint={extra?.hint}
      mode={mode}
      value={extra?.show ? extra.show(view[key]) : view[key]}
      error={errors[key] ?? null}
      editor={
        <input
          aria-label={label}
          value={draft[key]}
          placeholder={extra?.placeholder}
          onBlur={extra?.onBlur}
          onChange={(e) => set(key, e.target.value)}
          aria-invalid={errors[key] ? true : undefined}
          data-required-empty={extra?.required && emptyRequired(key) ? 'true' : undefined}
          className={INPUT_CLASS}
        />
      }
    />
  );

  const sourceView = [
    catalogs.name('SOURCE', view.source_code),
    catalogs.name('SOURCE_TYPE', catalogs.parentCode('SOURCE', view.source_code, 'SOURCE_TYPE')),
  ];

  return (
    <>
      <RecordDetail
        kind="Lead"
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
          <>
            {canCreate && (
              <Button
                icon="plus"
                // duong-dan-menu: lead mới không thuộc bản ghi đang xem
                onClick={() => void navigate('/crm/lead/moi')}
              >
                Tạo
              </Button>
            )}
            {canAssign && (
              <Button icon="user" onClick={() => setAssignOpen(true)}>
                Assign
              </Button>
            )}
          </>
        }
        menu={
          (canAssign || canMerge || canCancelLead) && record
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
                  ...(canCancelLead
                    ? [
                        {
                          kind: 'action' as const,
                          label: 'Huỷ lead nhập nhầm',
                          onSelect: () => setCancelOpen(true),
                        },
                      ]
                    : []),
                ],
              }
            : undefined
        }
        onRefresh={() => refreshRecord()}
        stage={
          stageSteps.length > 0
            ? {
                steps: stageSteps,
                // Lead mới chưa lưu: luôn bắt đầu ở giai đoạn đầu C1 (R-CRM-39), nêu mờ; người dùng không chọn lúc tạo.
                current: record?.stage_code ?? stageSteps[0]?.code ?? '',
                forwardOnly: false,
                onSelect: (step) => requestStage(step.code),
              }
            : undefined
        }
        quietEdit
        businessActions={
          record && canCreateOpp ? (
            // Luật mới 26/10: chỉ tạo cơ hội khi lead ở C4C (hoặc C4D, tạo thêm có xác nhận). Nút mờ chỉ là gợi ý; chặn thật ở hàm.
            canOpenOpp(record.substage_code) ? (
              <Button variant="primary" onClick={() => setOppOpen(true)}>
                Tạo cơ hội
              </Button>
            ) : (
              <Button disabled title={CREATE_OPP_BLOCKED_REASON}>
                Tạo cơ hội
              </Button>
            )
          ) : undefined
        }
        subStage={
          record === null ? (
            // Lead mới chưa lưu (R-CRM-39: bắt đầu ở C1, chưa có nhóm con): ô Sub-stage "Chưa có", mờ cùng cả hàng (khuôn K3).
            <>
              <span className="text-caption font-semibold text-fg-label">Sub-stage</span>
              <input
                readOnly
                aria-label="Sub-stage"
                value="Chưa có"
                className={`${INPUT_CLASS} w-60`}
              />
            </>
          ) : substageOptions.length > 0 || lockedSubstage ? (
            <>
              <span className="text-caption font-semibold text-fg-label">Sub-stage</span>
              {lockedSubstage ? (
                <span
                  className="relative"
                  title="Nhóm con do hệ thống tự gắn khi tạo cơ hội thành công, không đổi được."
                >
                  <input
                    readOnly
                    aria-label="Sub-stage"
                    value={codeAndName(
                      SYSTEM_SUBSTAGE,
                      catalogs.name('LEAD_SUBSTAGE', SYSTEM_SUBSTAGE),
                    )}
                    className={`${INPUT_CLASS} w-60 pr-8`}
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
                  options={substageOptions.map((o) => ({
                    value: o.value,
                    label: `${o.value} ${o.label}`,
                  }))}
                  placeholder="Chưa có"
                  disabled={!canEdit}
                />
              )}
            </>
          ) : undefined
        }
        smart={
          record
            ? [
                {
                  key: 'lich-hen',
                  label: 'Lịch hẹn',
                  icon: 'calendar',
                  count: record.appointments_total,
                  onOpen: () =>
                    openFrom(
                      `/crm/lich-hen?lead=${record.id}&ma=${encodeURIComponent(record.code)}`,
                    ),
                },
                {
                  key: 'co-hoi',
                  label: 'Cơ hội',
                  icon: 'sales',
                  count: record.opportunities_total,
                  onOpen: (target) => void openOpportunities(record, target),
                },
              ]
            : [
                {
                  key: 'lich-hen',
                  label: 'Lịch hẹn',
                  icon: 'calendar',
                  count: 0,
                  onOpen: () => undefined,
                },
                {
                  key: 'co-hoi',
                  label: 'Cơ hội',
                  icon: 'sales',
                  count: 0,
                  onOpen: () => undefined,
                },
              ]
        }
        aside={
          record ? (
            <RecordChatter
              entityType="LEAD"
              entityId={record.id}
              createdText="Tạo lead."
              format={{
                labels: LEAD_FIELD_LABELS,
                value: leadHistoryValue(catalogs, record),
              }}
              canWrite={!locked}
              actions={
                canAppt ? (
                  <Button icon="calendar" onClick={() => setApptOpen(true)}>
                    Lên lịch hẹn
                  </Button>
                ) : undefined
              }
              upcoming={
                <UpcomingActivities
                  rows={upcoming.data?.rows ?? []}
                  activityName={activityName}
                  canEdit={access.can('APPOINTMENT', 'SUA') && !locked}
                  canCancel={access.can('APPOINTMENT', 'HUY') && !locked}
                  busyId={null}
                  onComplete={(row) => setCompleting(row)}
                  onReschedule={(row) => setMoving({ ...row, branchId: record.branch_id })}
                  onCancel={(row) => {
                    setCancelError(null);
                    setCanceling(row);
                  }}
                />
              }
            />
          ) : (
            <Chatter
              entries={[]}
              status="ready"
              disabled
              onSend={() => Promise.resolve()}
              searchPeople={() => Promise.resolve([])}
            />
          )
        }
      >
        {cancelled && (
          <p className="mb-4 rounded-control bg-surface-subtle px-3 py-2 text-fg-muted">
            <Tag tone="danger">Đã huỷ</Tag> Lead nhập nhầm, đã huỷ
            {record?.cancel_reason ? (
              <>
                : <b>{record.cancel_reason}</b>
              </>
            ) : null}
            . Chỉ đọc.
          </p>
        )}
        {merged && record?.merged_into_code && (
          <p className="mb-4 rounded-control bg-surface-subtle px-3 py-2 text-fg-muted">
            <Tag>Đã gộp</Tag> Lead này đã gộp vào <b>{record.merged_into_code}</b>, chỉ đọc.
          </p>
        )}
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin phụ huynh">
            {text('parent_name', 'Họ tên', { required: true })}
            {text('parent_phone', 'Số điện thoại', {
              required: true,
              show: formatPhone,
              placeholder: 'Nhập số điện thoại',
              onBlur: () => void checkPhoneDuplicate(),
            })}
            {creating &&
              inlineDup !== null &&
              inlineDup.rows.length > 0 &&
              inlineDup.phone === draft.parent_phone.replace(/[\s.-]/g, '') && (
                <Alert tone="warning" title="Số điện thoại này đã có trong hệ thống">
                  <div className="flex flex-col gap-2">
                    {duplicateGroups(inlineDup.rows).map((g) => (
                      <div key={g.title}>
                        <div className="font-medium">{g.title}</div>
                        <ul className="list-inside list-disc">
                          {g.lines.map((l, i) => (
                            <li key={i}>{l}</li>
                          ))}
                        </ul>
                      </div>
                    ))}
                    {(() => {
                      const first = inlineDup.rows.find((d) => d.visible);
                      return first ? (
                        <FromLink
                          to={
                            first.kind === 'LEAD'
                              ? `/crm/lead/${first.id}`
                              : `/crm/phu-huynh/${first.id}`
                          }
                          className="font-medium text-link hover:underline"
                        >
                          Mở bản ghi trùng
                        </FromLink>
                      ) : null;
                    })()}
                  </div>
                </Alert>
              )}
            <DetailField
              label="Tỉnh/Thành phố"
              mode={mode}
              value={catalogs.name('PROVINCE', view.province_code) ?? ''}
              editor={
                <OptionalSelect
                  label="Tỉnh/Thành phố"
                  value={draft.province_code}
                  onChange={(v) => setDraft((d) => ({ ...d, province_code: v, ward_code: '' }))}
                  options={catalogs.options('PROVINCE')}
                  placeholder="Chọn tỉnh/thành phố"
                />
              }
            />
            <DetailField
              label="Phường/Xã"
              mode={mode}
              value={catalogs.name('WARD', view.ward_code) ?? ''}
              editor={
                <OptionalSelect
                  label="Phường/Xã"
                  value={draft.ward_code}
                  onChange={(v) => set('ward_code', v)}
                  options={wardOptions}
                  placeholder="Chọn phường/xã"
                  disabled={draft.province_code === ''}
                />
              }
            />
            {text('address', 'Địa chỉ', { placeholder: 'Số nhà, ngõ, đường' })}
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
            entity="LEAD"
            recordId={record?.id}
            students={record?.students ?? []}
            requireYear={false}
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
                      placeholder="Nhập 4 chữ số (bắt buộc từ L5)"
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
                  placeholder: 'Ví dụ: Khá, yếu phần Hình',
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
                        mode={mode}
                        value={
                          record
                            ? `${record.branch_code} ${record.branch_name}`
                            : myBranch
                              ? `${myBranch.code} ${myBranch.name}`
                              : ''
                        }
                        error={errors.branch_id ?? null}
                        editor={
                          creating && access.seesAllBranches ? (
                            <OptionalSelect
                              label="Cơ sở"
                              value={draft.branch_id}
                              onChange={(v) =>
                                setDraft((d) => ({
                                  ...d,
                                  branch_id: v,
                                  owner_id: '',
                                  supporter_id: '',
                                }))
                              }
                              options={access.teachingBranches.map((b) => ({
                                value: b.id,
                                label: `${b.code} ${b.name}`,
                              }))}
                              placeholder="Chọn cơ sở"
                              invalid={Boolean(errors.branch_id)}
                            />
                          ) : (
                            <input
                              readOnly
                              aria-label="Cơ sở"
                              title="Cơ sở của lead không đổi được"
                              value={
                                record
                                  ? `${record.branch_code} ${record.branch_name}`
                                  : myBranch
                                    ? `${myBranch.code} ${myBranch.name}`
                                    : ''
                              }
                              className={INPUT_CLASS}
                            />
                          )
                        }
                      />
                      <DetailField
                        label="Nhân sự phụ trách"
                        required={creating}
                        mode={mode}
                        value={record?.owner_name ?? ''}
                        error={errors.owner_id ?? null}
                        editor={
                          creating ? (
                            <OptionalSelect
                              label="Nhân sự phụ trách"
                              value={draft.owner_id}
                              onChange={(v) => set('owner_id', v)}
                              options={
                                staffOptions.length > 0
                                  ? staffOptions
                                  : claims
                                    ? [{ value: claims.userId, label: 'Bạn' }]
                                    : []
                              }
                              placeholder="Chọn nhân sự"
                              invalid={Boolean(errors.owner_id)}
                              requiredEmpty={emptyRequired('owner_id')}
                            />
                          ) : (
                            <input
                              readOnly
                              aria-label="Nhân sự phụ trách"
                              title="Đổi người phụ trách bằng nút Assign"
                              value={record?.owner_name ?? ''}
                              className={INPUT_CLASS}
                            />
                          )
                        }
                      />
                      <DetailField
                        label="Nhân sự hỗ trợ"
                        mode={mode}
                        value={record?.supporter_name ?? ''}
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
                        required
                        mode={mode}
                        value={
                          <>
                            {sourceView[0]}
                            {sourceView[1] && (
                              <span className="ml-1.5 text-caption text-fg-muted">
                                ({sourceView[1]})
                              </span>
                            )}
                          </>
                        }
                        error={errors.source_code ?? null}
                        editor={
                          <OptionalSelect
                            label="Source"
                            value={draft.source_code}
                            onChange={(v) =>
                              setDraft((d) => ({ ...d, source_code: v, channel_code: '' }))
                            }
                            options={sourceOptions}
                            placeholder="Chọn source"
                            invalid={Boolean(errors.source_code)}
                            requiredEmpty={emptyRequired('source_code')}
                          />
                        }
                      />
                      <DetailField
                        label="Sub-source"
                        required={channelOptions.length > 0}
                        mode={mode}
                        value={catalogs.name('SOURCE_CHANNEL', view.channel_code) ?? ''}
                        error={errors.channel_code ?? null}
                        editor={
                          <OptionalSelect
                            label="Sub-source"
                            value={draft.channel_code}
                            onChange={(v) => set('channel_code', v)}
                            options={channelOptions}
                            placeholder={
                              draft.source_code === '' ? 'Chọn source trước' : 'Chọn sub-source'
                            }
                            disabled={channelOptions.length === 0}
                            invalid={Boolean(errors.channel_code)}
                            requiredEmpty={emptyRequired('channel_code', channelOptions.length > 0)}
                          />
                        }
                      />
                      <DetailField
                        label="Chiến dịch"
                        mode={mode}
                        value={catalogs.campaignName(view.campaign_id) ?? ''}
                        editor={
                          <OptionalSelect
                            label="Chiến dịch"
                            value={draft.campaign_id}
                            onChange={(v) => set('campaign_id', v)}
                            options={catalogs.campaigns}
                            placeholder="Chọn chiến dịch"
                          />
                        }
                      />
                    </dl>
                  </div>
                ),
              },
              {
                value: 'time',
                label: 'Mốc thời gian',
                content: record ? (
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
                      value={<NextAppointment at={record.next_appointment_at} />}
                    />
                    {record.legacy_ref && (
                      <DetailField label="Mã cũ (Sheet)" mode="view" value={record.legacy_ref} />
                    )}
                  </dl>
                ) : (
                  <p className="text-fg-muted">Mốc thời gian có sau khi lưu.</p>
                ),
              },
            ]}
          />
        </div>
      </RecordDetail>

      {record && canCancelLead && (
        <CancelLeadDialog
          leadId={record.id}
          summary={`${record.code} · ${leadTitle(record)} · ${formatPhone(record.parent_phone)}`}
          open={cancelOpen}
          onClose={() => setCancelOpen(false)}
          onCancelled={() => {
            toast({ title: 'Đã huỷ lead nhập nhầm.' });
            void refreshRecord();
          }}
        />
      )}
      {record && canMerge && (
        <MergeDialog
          open={mergeOpen}
          onOpenChange={setMergeOpen}
          entity="LEAD"
          current={{
            id: record.id,
            code: record.code,
            label: leadTitle(record),
            phone: formatPhone(record.parent_phone),
          }}
          onMerged={(keepId, keepCode) => {
            toast({ title: `Đã gộp vào ${keepCode}.` });
            if (keepId === record.id) void refreshRecord();
            // duong-dan-menu: bản đang xem đã gộp, không còn để quay lại
            else void navigate(`/crm/lead/${keepId}`, { replace: true });
          }}
        />
      )}
      {record && (
        <AssignDialog
          open={assignOpen}
          onOpenChange={setAssignOpen}
          entityType="LEAD"
          noun="lead"
          codes={[record.code]}
          branchCodes={[record.branch_code]}
          onAssign={async (ownerId, ownerName) => {
            await rpc<number>(supabase, 'assign_owner', {
              p_entity_type: 'LEAD',
              p_ids: [record.id],
              p_owner_id: ownerId,
            });
            await refreshRecord();
            toast({ title: `Đã giao ${record.code} cho ${ownerName}.` });
          }}
        />
      )}

      <CompleteAppointmentDialog
        open={completing !== null}
        onOpenChange={(o) => !o && setCompleting(null)}
        target={
          completing && record
            ? {
                id: completing.id,
                activityCode: completing.activity_code,
                isAutoReminder: completing.is_auto_reminder,
                label: `${activityName(completing.activity_code)} · ${completing.title}`,
                context: `Lead ${record.code} · ${formatDateTime(completing.scheduled_at)} · ${leadTitle(record)}`,
              }
            : null
        }
        resultOptions={catalogs.options('APPOINTMENT_RESULT')}
        onComplete={completeWith}
      />

      {record && target && (
        <AppointmentDialog
          open={apptOpen}
          onOpenChange={setApptOpen}
          target={target}
          activityOptions={catalogs.options('ACTIVITY_TYPE')}
          onCreate={async (args) => {
            const noteText = args.note.trim();
            await createLeadAppointment(supabase, {
              leadId: record.id,
              activityCode: args.activityCode,
              scheduledAt: args.scheduledAt,
              // Bản vẽ không có ô "Nội dung": ghi chú là nội dung hiện ở danh sách; để trống thì lấy tên loại hoạt động.
              title: noteText === '' ? activityName(args.activityCode) : noteText,
              ownerId: args.ownerId,
            });
            await refreshRecord();
            toast({ title: 'Đã tạo lịch hẹn.' });
          }}
          onReschedule={() => Promise.resolve()}
        />
      )}
      {record && target && moving && (
        <AppointmentDialog
          open
          onOpenChange={(open) => !open && setMoving(null)}
          target={target}
          activityOptions={[]}
          reschedule={{
            id: moving.id,
            label:
              moving.title === activityName(moving.activity_code)
                ? moving.title
                : `${activityName(moving.activity_code)} · ${moving.title}`,
            scheduledAt: moving.scheduled_at,
            ownerId: moving.owner_id,
            ownerName: moving.owner_name,
            branchId: moving.branchId,
          }}
          onCreate={() => Promise.resolve()}
          onReschedule={async (args) => {
            await rescheduleAppointment(supabase, args);
            await refreshRecord();
            toast({ title: 'Đã dời lịch hẹn.' });
          }}
        />
      )}

      <ReasonDialog
        open={canceling !== null}
        onOpenChange={(open) => !open && setCanceling(null)}
        title="Huỷ lịch hẹn"
        description={
          canceling ? `${activityName(canceling.activity_code)} · ${canceling.title}` : undefined
        }
        options={catalogs.options('APPOINTMENT_CANCEL_REASON').map((o) => ({
          ...o,
          needsNote: catalogs.requiresNote('APPOINTMENT_CANCEL_REASON', o.value),
        }))}
        confirmLabel="Huỷ lịch hẹn"
        busy={cancelBusy}
        error={cancelError}
        onConfirm={(result) => {
          if (!canceling) return;
          setCancelBusy(true);
          setCancelError(null);
          void cancelAppointment(supabase, canceling.id, result.option, result.note)
            .then(refreshRecord)
            .then(() => {
              setCanceling(null);
              toast({ title: 'Đã huỷ lịch hẹn.', action: undoAppointment(canceling.id) });
            })
            .catch((e: unknown) => setCancelError(errorOf(e).message))
            .finally(() => setCancelBusy(false));
        }}
      />

      {record && stagePick !== null && (
        <LeadStageDialog
          open
          onOpenChange={(open) => !open && setStagePick(null)}
          subtitle={`${record.code} · ${view.parent_name} · đang ở ${codeAndName(record.stage_code, catalogs.name('LEAD_STAGE', record.stage_code))}`}
          stageLabel={codeAndName(stagePick, catalogs.name('LEAD_STAGE', stagePick))}
          stageCode={stagePick}
          options={selectableSubstages(catalogs, stagePick)}
          onSubmit={(substage) => moveStage(stagePick, substage, true)}
        />
      )}
      {record && (
        <CreateOpportunityDialog
          open={oppOpen}
          onOpenChange={setOppOpen}
          lead={record}
          catalogs={catalogs}
          onCreated={async (created) => {
            await refreshRecord();
            await queryClient.invalidateQueries({ queryKey: ['opp-list'] });
            await queryClient.invalidateQueries({ queryKey: ['opp-board'] });
            toast({ title: `Đã tạo cơ hội ${created.code}.` });
            openFrom(`/crm/co-hoi/${created.id}`);
          }}
          onOpenExisting={(id) => openFrom(`/crm/co-hoi/${id}`)}
        />
      )}

      <DuplicateDialog
        open={duplicates !== null}
        onOpenChange={(open) => !open && setDuplicates(null)}
        title="Số điện thoại này đã có khách hàng"
        phone={formatPhone(draft.parent_phone.replace(/[\s.-]/g, ''))}
        groups={duplicateGroups(duplicates ?? [])}
        canAttach={(duplicates ?? []).some((d) => d.kind === 'PARENT' && d.visible)}
        onAttach={() => {
          const parent = (duplicates ?? []).find((d) => d.kind === 'PARENT' && d.visible);
          void save(false, parent?.id ?? null);
        }}
        onCreateNew={() => void save(true)}
      />
      <ConfirmDialog
        open={confirmPhone}
        onOpenChange={setConfirmPhone}
        title="Số điện thoại này đã có hồ sơ"
        description="Đã có lead hoặc phụ huynh dùng số này. Xác nhận nếu vẫn muốn dùng số này cho lead đang sửa."
        confirmLabel="Vẫn dùng số này"
        onConfirm={() => {
          setConfirmPhone(false);
          void save(true);
        }}
      />
    </>
  );
}

type AppointmentRow = UpcomingAppointment & { branchId: string };

function NextAppointment({ at }: { at: string | null }) {
  const tag = appointmentTag(at);
  return (
    <Tag tone={tag.tone} dot>
      {tag.label}
    </Tag>
  );
}

/** Hai nhóm của hộp trùng SĐT (TS-14): lead đã có, phụ huynh đã có; hồ sơ ngoài phạm vi chỉ lộ mã và cơ sở. */
function duplicateGroups(rows: Duplicate[]) {
  const line = (d: Duplicate) =>
    d.visible ? (
      d.kind === 'LEAD' ? (
        <FromLink to={`/crm/lead/${d.id}`} className="font-medium text-link hover:underline">
          {d.code} · {d.label}
        </FromLink>
      ) : (
        `${d.code} · ${d.label}`
      )
    ) : (
      'Hồ sơ ngoài phạm vi bạn xem (không hiện mã, tên, cơ sở)'
    );
  return [
    { title: 'Lead đã có', lines: rows.filter((d) => d.kind === 'LEAD').map(line) },
    { title: 'Phụ huynh đã có', lines: rows.filter((d) => d.kind === 'PARENT').map(line) },
  ].filter((g) => g.lines.length > 0);
}
