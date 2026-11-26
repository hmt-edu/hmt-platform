// LOP-02 Lớp (bản ghi, khuôn K06): thanh duyệt, thông tin, thời khoá biểu, học sinh (dòng xếp lớp), buổi, lịch sử, cảnh báo trùng.
// Thao tác trong menu Hành động theo tình trạng duyệt (LOP-05: Trình, Xác nhận, Duyệt, Từ chối, Đưa về Nháp, Huỷ; LOP-06: Đóng, Huỷ,
// bị chặn thì hộp thoại hiện lý do máy chủ trả, có tên học sinh). Sửa dẫn tới LOP-03. Quyền thật do máy chủ kiểm.
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { Button } from '../../ui/Button';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { LineTable } from '../../ui/LineTable';
import { Tabs, type MenuItem } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { editKind, transitionsFrom, type Transition } from './classTransitions';
import {
  NO_GROUP_TEXT,
  WEEKDAY_LABEL,
  classNotes,
  recordSlotSummary,
  timeText,
} from './classLabels';
import { editClassPath } from './classConfig';
import { organizationText, remainingClassPath } from './classForm';
import { OPERATING_LABEL, type ClassRecord } from './classTypes';
import { transitionClass, useClassRecord, useRefreshClasses } from './useClassData';

export function ClassRecordPage() {
  const { id } = useParams();
  const query = useClassRecord(id);
  if (query.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : 'error'}
        title={forbidden ? 'Bạn không có quyền xem lớp này' : 'Không tải được lớp'}
        actions={
          <>
            <Link to="/crm/lop" className="font-medium text-link hover:underline">
              Về danh sách Lớp
            </Link>
            {!forbidden && <Button onClick={() => void query.refetch()}>Thử lại</Button>}
          </>
        }
      >
        {errorOf(error).message}
      </StateView>
    );
  }
  return <ClassView key={query.data.id} record={query.data} />;
}

function ClassView({ record }: { record: ClassRecord }) {
  const supabase = useDb();
  const toast = useToast();
  const access = useAccess();
  const navigate = useNavigate();
  const refresh = useRefreshClasses();
  const [pending, setPending] = useState<Transition | null>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useCrumbTail(record.code);

  const edit = editKind(record.status_code);
  const allowed = (action: Transition['action']) => access.can('CLASS', action);
  const menu: MenuItem[] = [
    // BUOI-09, BUOI-07: yêu cầu học bổ trợ (R-BUOI-05) và học bù (R-BUOI-03) tạo từ lớp đã duyệt; có quyền tạo yêu cầu buổi và phân hệ YEU_CAU_BUOI bật.
    ...(record.status_code === 'DA_DUYET' &&
    access.can('SESSION', 'TAO') &&
    access.featureOn('YEU_CAU_BUOI')
      ? [
          {
            kind: 'action' as const,
            label: 'Yêu cầu bổ trợ',
            onSelect: () => void navigate(`/crm/yeu-cau-buoi/tao-bo-tro?lop=${record.id}`),
          },
          {
            kind: 'action' as const,
            label: 'Yêu cầu học bù',
            onSelect: () => void navigate(`/crm/yeu-cau-buoi/tao-hoc-bu?lop=${record.id}`),
          },
        ]
      : []),
    ...transitionsFrom(record.status_code)
      .filter((t) => allowed(t.action))
      .map((t) => ({
        kind: 'action' as const,
        label: t.label,
        onSelect: () => {
          setNote('');
          setError(null);
          setPending(t);
        },
      })),
  ];

  async function run() {
    if (!pending || busy) return;
    setBusy(true);
    setError(null);
    try {
      const result = await transitionClass(
        supabase,
        record.id,
        pending.to,
        note.trim() === '' ? null : note.trim(),
      );
      void refresh();
      setPending(null);
      toast({
        title:
          result.sessions_created && result.sessions_created > 0
            ? `${pending.label} xong. Đã sinh ${result.sessions_created} buổi.`
            : `${pending.label} xong.`,
      });
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  const clash = Array.isArray(record.clash_warnings) ? record.clash_warnings : [];
  const counts = Object.entries(record.session_counts);
  const notes = classNotes(record.status_code, record.slots.length);
  const summary = recordSlotSummary(record.slots);
  const [dayTab, setDayTab] = useState(() => String(record.slots[0]?.weekday ?? 1));

  return (
    <>
      <RecordDetail
        kind="Lớp"
        title={record.code}
        mode="view"
        readOnly
        showEdit={Boolean(edit) && allowed('SUA')}
        editLabel="Sửa"
        onEdit={() => void navigate(editClassPath(record.id))}
        onSave={() => undefined}
        onCancel={() => undefined}
        onRefresh={() => void refresh()}
        menu={menu.length > 0 ? { label: 'Hành động', items: menu } : undefined}
        asideLabel="Ghi chú và hoạt động"
        aside={
          <RecordChatter
            entityType="CLASS"
            entityId={record.id}
            format={CHATTER_FORMAT}
            createdText="Tạo lớp."
            canWrite
            events={record.events.map((e, i) => ({
              kind: 'system' as const,
              id: `ev-${i}`,
              at: e.created_at,
              author: '',
              text: `${EVENT_LABEL[e.event_code] ?? e.event_code}${e.note ? `: ${e.note}` : ''}`,
            }))}
          />
        }
        smart={[
          {
            key: 'hoc-sinh',
            label: 'Học sinh',
            icon: 'training',
            count: record.students.length,
            onOpen: () => void navigate(`/crm/lop/${record.id}/hoc-sinh`),
          },
          {
            key: 'buoi-hoc',
            label: 'Buổi học',
            icon: 'calendar',
            count: counts.reduce((sum, [, n]) => sum + n, 0),
            onOpen: () => void navigate(`/crm/buoi-hoc?lop=${record.id}`),
          },
        ]}
        stageShowCode={false}
        stage={{
          steps: ['NHAP', 'DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET', 'DA_DONG'].map((code) => ({
            code,
            label: STEP_LABEL[code] ?? code,
          })),
          current: record.status_code === 'TU_CHOI' ? 'NHAP' : record.status_code,
          // Thanh duyệt chỉ đọc, đổi bằng menu Hành động (khung LOP-02: «Stage chỉ đọc, đổi bằng nút bên dưới»).
          onSelect: () => undefined,
        }}
      >
        {notes.top && (
          <Alert tone={notes.top.tone} className="mb-4">
            {notes.top.text}
          </Alert>
        )}
        {clash.length > 0 && (
          <Alert tone="warning" title="Cảnh báo trùng phòng hoặc giáo viên">
            Có buổi trùng phòng hoặc giáo viên với lớp khác (chỉ cảnh báo, không chặn).
          </Alert>
        )}
        <div className="grid gap-x-8 gap-y-4 md:grid-cols-2">
          <DetailSection title="Thông tin chung">
            <DetailField mode="view" label="Mã lớp" value={record.code} />
            <DetailField mode="view" label="Mã cũ (Sheet)" value={record.legacy_ref ?? ''} />
            <DetailField
              mode="view"
              label="Tình trạng duyệt"
              value={<Tag>{record.status_name ?? record.status_code}</Tag>}
            />
            <DetailField
              mode="view"
              label="Vận hành"
              value={record.operating_status ? OPERATING_LABEL[record.operating_status] : ''}
            />
            <DetailField
              mode="view"
              label="Cơ sở"
              value={access.branchName(record.branch_code) ?? record.branch_code}
            />
            <DetailField
              mode="view"
              label="Môn"
              value={record.subject_name ?? record.subject_code}
            />
            <DetailField mode="view" label="Khối" value={record.grade_code.replace(/^K0?/, '')} />
            <DetailField mode="view" label="Phân loại" value={record.class_type_name ?? ''} />
            <DetailField mode="view" label="Trình độ" value={record.level_name ?? ''} />
            <DetailField
              mode="view"
              label="Hình thức học"
              value={record.delivery_mode_name ?? record.delivery_mode_code ?? ''}
            />
            <DetailField
              mode="view"
              label="Tổ chức lớp"
              value={organizationText(record.class_type_code)}
            />
            <DetailField
              mode="view"
              label="Nhóm lớp"
              value={record.group_id === null ? NO_GROUP_TEXT : (record.group_name ?? '')}
            />
          </DetailSection>
          <DetailSection title="Thời gian và địa điểm">
            <DetailField mode="view" label="Khai giảng" value={formatDate(record.start_date)} />
            <DetailField
              mode="view"
              label="Kết thúc dự kiến"
              value={
                record.expected_end_date
                  ? formatDate(record.expected_end_date)
                  : record.slots.length === 0
                    ? 'chưa tính (chưa có thời khoá biểu)'
                    : 'chưa tính'
              }
            />
            <DetailField mode="view" label="Lịch học" value={summary.schedule} />
            <DetailField mode="view" label="Phòng học" value={summary.rooms} />
            <DetailField mode="view" label="Giáo viên" value={summary.teachers} />
            <DetailField mode="view" label="Trợ giảng" value={summary.assistants} />
            <DetailField mode="view" label="Số buổi" value={record.total_sessions} />
            <DetailField
              mode="view"
              label="Sĩ số tối đa"
              value={record.max_students > 0 ? record.max_students : 'Không giới hạn'}
            />
            <DetailField
              mode="view"
              label="Còn chỗ"
              value={record.seats_left === null ? 'Không giới hạn' : record.seats_left}
            />
            <DetailField
              mode="view"
              label="Khung chương trình"
              value={record.curriculum_ref ?? ''}
            />
            <DetailField mode="view" label="Bài bắt đầu" value={record.start_lesson ?? ''} />
          </DetailSection>
        </div>

        {record.group_id !== null && (
          <div className="mt-6">
            <DetailSection title="Nhóm lớp">
              <DetailField mode="view" label="Cùng nhóm" value={record.group_name ?? 'Nhóm lớp'} />
              <ul className="flex flex-col gap-1 py-1">
                {(record.group_classes ?? []).map((g) => (
                  <li key={g.id} className="flex flex-wrap items-center gap-x-3">
                    <span className="text-caption text-fg-muted">Lớp còn lại của nhóm:</span>
                    <Link className="font-medium text-link underline" to={`/crm/lop/${g.id}`}>
                      {[g.subject_name, g.code].filter(Boolean).join(' · ')}
                    </Link>
                    {g.teacher_names && <span className="text-fg-muted">GV {g.teacher_names}</span>}
                    <Tag>{g.status_name ?? g.status_code}</Tag>
                  </li>
                ))}
              </ul>
              {/* «Tạo lớp còn lại cho nhóm này» (anh Trường chốt 20/11): chỉ điền sẵn nhóm, cơ sở, năm, khối, phân loại; để trống môn, giáo viên, lịch. */}
              {access.can('CLASS', 'TAO') &&
                (record.group_classes ?? []).every((g) => g.status_code === 'HUY') && (
                  <div className="py-1">
                    <Button
                      variant="secondary"
                      onClick={() => void navigate(remainingClassPath(record))}
                    >
                      Tạo lớp còn lại cho nhóm này
                    </Button>
                  </div>
                )}
              <p className="text-caption text-fg-muted">
                Nhóm không có mã riêng. Mỗi lớp trong nhóm vẫn độc lập: giáo viên, lịch, sĩ số, bước
                duyệt riêng.
              </p>
            </DetailSection>
          </div>
        )}

        <div className="mt-6">
          <DetailSection title="Time Table">
            <p className="text-caption text-fg-muted">
              Bốn ô Lịch học, Phòng, Giáo viên, Trợ giảng của lớp tự sinh từ Time Table này.
            </p>
            <Tabs
              label="Time Table theo thứ"
              value={dayTab}
              onChange={setDayTab}
              items={[1, 2, 3, 4, 5, 6, 7].map((day) => {
                const slots = record.slots.filter((x) => x.weekday === day);
                return {
                  value: String(day),
                  label: WEEKDAY_LABEL[day] ?? '',
                  count: slots.length > 0 ? slots.length : undefined,
                  content:
                    slots.length === 0 ? (
                      <p className="py-2 text-fg-muted">{WEEKDAY_LABEL[day]} không có khung giờ.</p>
                    ) : (
                      <LineTable
                        caption={`Khung giờ ${WEEKDAY_LABEL[day]}`}
                        rows={slots}
                        rowKey={(x) => x.id}
                        columns={[
                          {
                            key: 'time',
                            header: 'Giờ',
                            cell: (x) => `${timeText(x.start_time)}–${timeText(x.end_time)}`,
                          },
                          {
                            key: 'teacher',
                            header: 'Giáo viên',
                            cell: (x) => x.teacher_name ?? '—',
                          },
                          {
                            key: 'assistant',
                            header: 'Trợ giảng',
                            cell: (x) => x.assistant_name ?? '—',
                          },
                          { key: 'room', header: 'Phòng', cell: (x) => x.room_name ?? '—' },
                          {
                            key: 'repeat',
                            header: 'Cách lặp',
                            cell: (x) =>
                              x.repeat_weeks > 1 ? `Mỗi ${x.repeat_weeks} tuần` : 'Hàng tuần',
                          },
                          {
                            key: 'first',
                            header: 'Buổi đầu tiên',
                            cell: (x) => formatDate(x.first_date),
                          },
                        ]}
                      />
                    ),
                };
              })}
            />
            {notes.bottom && <p className="text-caption text-fg-muted">{notes.bottom}</p>}
          </DetailSection>
        </div>
      </RecordDetail>

      {pending?.dialog === 'confirm' && (
        <ConfirmDialog
          open
          onOpenChange={(open) => !open && !busy && setPending(null)}
          title={pending.title}
          description={
            pending.to === 'DA_DUYET'
              ? `${pending.description} Dự kiến sinh ${record.total_sessions} buổi theo Time Table (bỏ ngày nghỉ lễ)${
                  record.expected_end_date
                    ? `, kết thúc dự kiến ${formatDate(record.expected_end_date)}`
                    : ''
                }.`
              : pending.description
          }
          confirmLabel={pending.label}
          tone={pending.danger ? 'danger' : 'primary'}
          busy={busy}
          error={error}
          onConfirm={() => void run()}
        />
      )}
      {pending?.dialog === 'note' && (
        <FormDialog
          open
          onOpenChange={(open) => !open && !busy && setPending(null)}
          title={pending.title}
          subtitle={pending.description}
          confirmLabel={pending.label}
          canSubmit={!pending.noteRequired || note.trim() !== ''}
          busy={busy}
          error={error}
          onSubmit={() => void run()}
        >
          <TextAreaField
            label={pending.noteRequired ? 'Lý do' : 'Ghi chú'}
            required={pending.noteRequired}
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
        </FormDialog>
      )}
    </>
  );
}

const STEP_LABEL: Record<string, string> = {
  NHAP: 'Nháp',
  DA_TRINH: 'Đã trình',
  DA_XAC_NHAN: 'Đã xác nhận',
  DA_DUYET: 'Đã duyệt',
  DA_DONG: 'Đã đóng',
};

// Tên trường và giá trị trong lịch sử thay đổi của lớp (không hiện mã thô như DA_DUYET).
const CHATTER_FORMAT = {
  coveredByEvents: ['status_code'],
  labels: { status_code: 'Tình trạng', max_students: 'Sĩ số tối đa', start_date: 'Ngày bắt đầu' },
  value: (column: string, value: unknown): string | null =>
    column === 'status_code' && typeof value === 'string' ? (STEP_LABEL[value] ?? null) : null,
};

const EVENT_LABEL: Record<string, string> = {
  TAO: 'Tạo lớp',
  SUA: 'Sửa thông tin',
  SUA_LICH: 'Đổi lịch',
  TRINH: 'Trình',
  XAC_NHAN: 'Xác nhận',
  DUYET: 'Duyệt',
  TU_CHOI: 'Từ chối',
  VE_NHAP: 'Đưa về Nháp',
  DONG: 'Đóng lớp',
  HUY: 'Huỷ lớp',
};
