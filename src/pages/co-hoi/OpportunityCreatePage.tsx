// TS-07 Tạo cơ hội trực tiếp, không qua lead (khung TS07_tao, TS07_tao_trung; R-CRM-01, R-CRM-23, R-CRM-27): khuôn bản ghi
// chế độ Tạo. Lưu bằng create_opportunity_direct (một giao dịch); trùng số điện thoại thì hộp TS-14: gắn vào phụ huynh có sẵn
// hoặc vẫn tạo mới. Cơ hội mới luôn ở L1. Quyền Cơ hội · Tạo (máy chủ kiểm lại).
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { ProspectStudents } from '../../features/prospect/ProspectStudents';
import { useEmEditing } from '../../features/prospect/useEmEditing';
import { useCrumbTail } from '../../layout/CrumbTail';
import { FromLink } from '../../layout/FromLink';
import { useAuth } from '../../lib/auth/authContext';
import { errorOf, rpc, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Chatter } from '../../ui/Chatter';
import { DuplicateDialog } from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { duplicateGroups, type Duplicate } from '../lead/duplicates';
import { formatPhone } from '../lead/leadFormat';
import { dateToIso, isoToDate } from '../lead/leadRecord';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  BLANK_OPP_DRAFT,
  oppCreateArgs,
  validateOppDraft,
  type OppDraft,
  type OppDraftErrors,
} from './oppCreate';

const FIRST_STAGE = 'L1';
const STAGE_NOTE = 'Cơ hội mới luôn bắt đầu ở L1. Các giai đoạn sau đổi trên bản ghi cơ hội.';

export function OpportunityCreatePage() {
  const supabase = useDb();
  const navigate = useNavigate();
  const location = useLocation();
  const toast = useToast();
  const access = useAccess();
  const { claims } = useAuth();
  const queryClient = useQueryClient();
  const catalogs = useLeadCatalogs();
  const myBranch = access.teachingBranches.find((b) => b.code === claims?.branchCode);

  const [draft, setDraft] = useState<OppDraft>(BLANK_OPP_DRAFT);
  const [touched, setTouched] = useState(false);
  const [errors, setErrors] = useState<OppDraftErrors>({});
  const [saving, setSaving] = useState(false);
  const [duplicates, setDuplicates] = useState<Duplicate[] | null>(null);
  const [inlineDup, setInlineDup] = useState<{ phone: string; rows: Duplicate[] } | null>(null);
  // Rời trang có chủ ý (tạo xong, Huỷ): bỏ cờ "chưa lưu" rồi mới chuyển.
  const [exitTo, setExitTo] = useState<string | null>(null);
  useEffect(() => {
    if (exitTo !== null) void navigate(exitTo, { replace: true, state: location.state as unknown });
  }, [exitTo, navigate, location.state]);
  useCrumbTail('Tạo mới');

  const ems = useEmEditing([]);
  // Cơ sở và người phụ trách mặc định: cơ sở đang làm việc và chính người tạo.
  const branchId = draft.branch_id || (myBranch?.id ?? '');
  const ownerId = draft.owner_id || (claims?.userId ?? '');
  const filled: OppDraft = { ...draft, branch_id: branchId, owner_id: ownerId };
  const set = <K extends keyof OppDraft>(key: K, value: OppDraft[K]) => {
    setTouched(true);
    setDraft((d) => ({ ...d, [key]: value }));
    setErrors((e) => ({ ...e, [key]: undefined }));
  };
  const patch = (next: Partial<OppDraft>) => {
    setTouched(true);
    setDraft((d) => ({ ...d, ...next }));
  };

  const staff = useAssignableStaff('OPPORTUNITY', branchId || null, branchId !== '');
  const staffOptions = (staff.data ?? []).map((s) => ({ value: s.id, label: s.display_name }));
  const canAssign = access.can('OPPORTUNITY', 'GIAO_VIEC');
  const sourceOptions = catalogs.childrenOf('SOURCE', 'SOURCE_TYPE', draft.source_type_code);
  const channelOptions = catalogs.childrenOf('SOURCE_CHANNEL', 'SOURCE', draft.source_code);
  const wardOptions = catalogs.childrenOf('WARD', 'PROVINCE', draft.province_code);
  const phone = draft.parent_phone.replace(/[\s.-]/g, '');
  const empty = (key: keyof OppDraft, needed = true) =>
    needed && filled[key].trim() === '' && !errors[key];

  const findDuplicates = () =>
    rpc<Duplicate[]>(supabase, 'find_duplicate_contacts', {
      p_phone: phone,
      p_exclude_lead_id: null,
    });

  async function checkPhoneDuplicate() {
    if (!/^0[0-9]{9}$/.test(phone) || inlineDup?.phone === phone) return;
    try {
      setInlineDup({ phone, rows: await findDuplicates() });
    } catch {
      // Lỗi ở bước dò sớm: bỏ qua, lúc bấm Lưu máy chủ vẫn chặn trùng.
      setInlineDup(null);
    }
  }

  async function save(confirmDuplicate = false, parentId: string | null = null) {
    const found = validateOppDraft(filled, { channelRequired: channelOptions.length > 0 });
    setErrors(found);
    if (Object.keys(found).length > 0) {
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
    setSaving(true);
    try {
      const { data, students } = oppCreateArgs(filled);
      const created = await rpc<{ id: string; code: string }>(
        supabase,
        'create_opportunity_direct',
        {
          p_data: data,
          p_students: students,
          p_confirm_duplicate: confirmDuplicate,
          p_parent_id: parentId,
        },
      );
      await Promise.all(
        ['opp-list', 'opp-board', 'opp-groups'].map((key) =>
          queryClient.invalidateQueries({ queryKey: [key] }),
        ),
      );
      toast({ title: `Đã tạo cơ hội ${created.code}.` });
      setExitTo(`/crm/co-hoi/${created.id}`);
    } catch (e) {
      const error = errorOf(e);
      if (error.code === 'HMT_SDT_TRUNG') {
        // Không dò được danh sách (thiếu quyền xem lead) thì vẫn hiện hộp để người dùng quyết định.
        setDuplicates(await findDuplicates().catch(() => []));
      } else if (error.code === 'HMT_SDT_SAI')
        setErrors((x) => ({ ...x, parent_phone: error.message }));
      else toast({ tone: 'danger', title: error.message });
    } finally {
      setSaving(false);
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
    extra?: { required?: boolean; hint?: string; placeholder?: string; onBlur?: () => void },
  ) => (
    <DetailField
      label={label}
      required={extra?.required}
      hint={extra?.hint}
      mode="create"
      value={draft[key]}
      error={errors[key] ?? null}
      editor={
        <input
          aria-label={label}
          value={draft[key]}
          placeholder={extra?.placeholder}
          onBlur={extra?.onBlur}
          onChange={(e) => set(key, e.target.value)}
          aria-invalid={errors[key] ? true : undefined}
          data-required-empty={extra?.required && empty(key) ? 'true' : undefined}
          className={INPUT_CLASS}
        />
      }
    />
  );

  const select = (
    key:
      | 'province_code'
      | 'ward_code'
      | 'branch_id'
      | 'owner_id'
      | 'supporter_id'
      | 'source_type_code'
      | 'source_code'
      | 'channel_code'
      | 'campaign_id',
    label: string,
    options: { value: string; label: string }[],
    extra: {
      placeholder: string;
      required?: boolean;
      disabled?: boolean;
      clear?: Partial<OppDraft>;
    },
  ) => (
    <DetailField
      label={label}
      required={extra.required}
      mode="create"
      value=""
      error={errors[key] ?? null}
      editor={
        <OptionalSelect
          label={label}
          value={filled[key]}
          onChange={(v) => {
            patch({ ...extra.clear, [key]: v });
            setErrors((x) => ({ ...x, [key]: undefined }));
          }}
          options={options}
          placeholder={extra.placeholder}
          disabled={extra.disabled ?? false}
          invalid={Boolean(errors[key])}
          requiredEmpty={extra.required ? empty(key) : false}
        />
      }
    />
  );

  const sameDup = inlineDup !== null && inlineDup.phone === phone && inlineDup.rows.length > 0;
  const firstVisible = sameDup ? inlineDup.rows.find((d) => d.visible) : undefined;
  const parentMatch = (duplicates ?? []).find((d) => d.kind === 'PARENT' && d.visible);

  return (
    <>
      <RecordDetail
        kind="Cơ hội"
        title=""
        mode="create"
        dirty={touched && exitTo === null}
        saving={saving}
        onEdit={() => undefined}
        onSave={() => void save()}
        onCancel={() => setExitTo('/crm/co-hoi')}
        stage={{
          steps: catalogs.options('OPP_STAGE').map((o) => ({ code: o.value, label: o.label })),
          current: FIRST_STAGE,
          forwardOnly: true,
          onSelect: () => undefined,
        }}
        stageNote={STAGE_NOTE}
        aside={
          <Chatter
            entries={[]}
            status="ready"
            disabled
            onSend={() => Promise.resolve()}
            searchPeople={() => Promise.resolve([])}
          />
        }
      >
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin phụ huynh">
            {text('parent_name', 'Họ tên', { required: true, placeholder: 'Họ tên phụ huynh' })}
            {text('parent_phone', 'Số điện thoại', {
              required: true,
              placeholder: 'Nhập số điện thoại',
              onBlur: () => void checkPhoneDuplicate(),
            })}
            {sameDup && (
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
                  {firstVisible && (
                    <FromLink
                      to={
                        firstVisible.kind === 'LEAD'
                          ? `/crm/lead/${firstVisible.id}`
                          : `/crm/phu-huynh/${firstVisible.id}`
                      }
                      className="font-medium text-link hover:underline"
                    >
                      Mở bản ghi trùng
                    </FromLink>
                  )}
                </div>
              </Alert>
            )}
            {select('province_code', 'Tỉnh/Thành phố', catalogs.options('PROVINCE'), {
              placeholder: 'Chọn tỉnh/thành phố',
              clear: { ward_code: '' },
            })}
            {select('ward_code', 'Phường/Xã', wardOptions, {
              placeholder: 'Chọn phường/xã',
              disabled: draft.province_code === '',
            })}
            {text('address', 'Địa chỉ', { placeholder: 'Số nhà, ngõ, đường' })}
            <DetailField
              label="Nhu cầu"
              mode="create"
              value={draft.need}
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
            students={[]}
            requireYear={false}
            canEdit
            mode="create"
            ems={ems}
            onChanged={() => undefined}
            firstFields={
              <>
                {text('student_name', 'Tên học sinh', {
                  hint: 'bắt buộc từ L5',
                  placeholder: 'Tên (bắt buộc từ L5)',
                })}
                <DetailField
                  label="Ngày sinh"
                  mode="create"
                  value=""
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
                  mode="create"
                  value=""
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
                {text('school', 'Trường học', { placeholder: 'Tên trường' })}
                {text('self_rating', 'Học lực tự đánh giá', {
                  placeholder: 'Ví dụ: Khá, yếu phần Hình',
                })}
                {text('goal', 'Mục tiêu', { placeholder: 'Mục tiêu của học sinh' })}
              </>
            }
          />
        </div>
        <h3 className="mt-6 mb-2 text-caption font-semibold tracking-wide text-fg-muted uppercase">
          Nguồn và phụ trách
        </h3>
        <div className="grid grid-cols-1 gap-x-10 lg:grid-cols-2">
          <dl className="flex flex-col">
            {access.seesAllBranches ? (
              select(
                'branch_id',
                'Cơ sở',
                access.teachingBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
                { placeholder: 'Chọn cơ sở', clear: { owner_id: '', supporter_id: '' } },
              )
            ) : (
              <DetailField
                label="Cơ sở"
                mode="create"
                value=""
                editor={
                  <input
                    readOnly
                    aria-label="Cơ sở"
                    value={myBranch ? `${myBranch.code} ${myBranch.name}` : ''}
                    className={INPUT_CLASS}
                  />
                }
              />
            )}
            {select(
              'owner_id',
              'Nhân sự phụ trách',
              staffOptions.length > 0
                ? staffOptions
                : claims
                  ? [{ value: claims.userId, label: 'Bạn' }]
                  : [],
              { placeholder: 'Chọn nhân sự', required: true, disabled: !canAssign },
            )}
            {select('supporter_id', 'Nhân sự hỗ trợ', staffOptions, {
              placeholder: 'Chọn nhân sự',
            })}
          </dl>
          <dl className="flex flex-col">
            {select('source_type_code', 'Source type', catalogs.options('SOURCE_TYPE'), {
              placeholder: 'Chọn source type',
              required: true,
              clear: { source_code: '', channel_code: '' },
            })}
            {select('source_code', 'Source', sourceOptions, {
              placeholder: draft.source_type_code === '' ? 'Chọn source type trước' : 'Chọn source',
              required: true,
              disabled: draft.source_type_code === '',
              clear: { channel_code: '' },
            })}
            {select('channel_code', 'Medium', channelOptions, {
              placeholder: draft.source_code === '' ? 'Chọn source trước' : 'Chọn medium',
              required: channelOptions.length > 0,
              disabled: channelOptions.length === 0,
            })}
            {select('campaign_id', 'Chiến dịch', catalogs.campaigns, {
              placeholder: 'Chọn chiến dịch',
            })}
          </dl>
        </div>
      </RecordDetail>
      <DuplicateDialog
        open={duplicates !== null}
        onOpenChange={(open) => !open && setDuplicates(null)}
        title="Số điện thoại này đã có khách hàng"
        phone={formatPhone(phone)}
        groups={duplicateGroups(duplicates ?? [])}
        canAttach={Boolean(parentMatch)}
        onAttach={() => {
          setDuplicates(null);
          // Đã xem hồ sơ trùng và chọn gắn vào: gửi kèm xác nhận.
          void save(true, parentMatch?.id ?? null);
        }}
        onCreateNew={() => {
          setDuplicates(null);
          void save(true);
        }}
      />
    </>
  );
}
