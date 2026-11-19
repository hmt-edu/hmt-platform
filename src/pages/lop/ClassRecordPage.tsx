// LOP-02 Lớp (bản ghi, khuôn K06): thanh duyệt, thông tin, thời khoá biểu, học sinh (dòng xếp lớp), buổi, lịch sử, cảnh báo trùng.
// Thao tác trong menu Hành động theo tình trạng duyệt (LOP-05: Trình, Xác nhận, Duyệt, Từ chối, Đưa về Nháp, Huỷ; LOP-06: Đóng, Huỷ,
// bị chặn thì hộp thoại hiện lý do máy chủ trả, có tên học sinh). Sửa dẫn tới LOP-03. Quyền thật do máy chủ kiểm.
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { Button } from '../../ui/Button';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import type { MenuItem } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { editKind, transitionsFrom, type Transition } from './classTransitions';
import { SESSION_STATUS_LABEL, WEEKDAY_LABEL, timeText } from './classLabels';
import { editClassPath } from './classConfig';
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
    ...(edit && allowed('SUA')
      ? [
          {
            kind: 'action' as const,
            label: edit === 'FULL' ? 'Sửa' : 'Sửa thời khoá biểu',
            onSelect: () => void navigate(editClassPath(record.id)),
          },
        ]
      : []),
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

  return (
    <>
      <RecordDetail
        kind="Lớp"
        title={record.code}
        mode="view"
        readOnly
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        onRefresh={() => void refresh()}
        menu={menu.length > 0 ? { label: 'Hành động', items: menu } : undefined}
        asideLabel="Lịch sử lớp"
        aside={
          record.events.length === 0 ? (
            <p className="p-3 text-fg-muted">Chưa có lịch sử.</p>
          ) : (
            <ul className="flex flex-col divide-y divide-border p-3">
              {record.events.map((e, i) => (
                <li key={i} className="flex flex-col gap-0.5 py-1.5">
                  <span>
                    {EVENT_LABEL[e.event_code] ?? e.event_code}
                    {e.note ? `: ${e.note}` : ''}
                  </span>
                  <span className="text-caption text-fg-muted">{formatDateTime(e.created_at)}</span>
                </li>
              ))}
            </ul>
          )
        }
        smart={[
          {
            key: 'hoc-sinh',
            label: 'Học sinh',
            icon: 'training',
            count: record.students.length,
            unavailable: 'Danh sách học sinh của lớp hiện ở bên dưới',
            onOpen: () => undefined,
          },
          {
            key: 'buoi-hoc',
            label: 'Buổi học',
            icon: 'calendar',
            count: counts.reduce((sum, [, n]) => sum + n, 0),
            unavailable: 'Màn Buổi học sắp có (BUOI-01)',
            onOpen: () => undefined,
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
        {clash.length > 0 && (
          <Alert tone="warning" title="Cảnh báo trùng phòng hoặc giáo viên">
            Có buổi trùng phòng hoặc giáo viên với lớp khác (chỉ cảnh báo, không chặn).
          </Alert>
        )}
        <div className="grid gap-x-8 gap-y-4 md:grid-cols-2">
          <DetailSection title="Thông tin lớp">
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
              value={record.operating_status ? OPERATING_LABEL[record.operating_status] : '—'}
            />
            <DetailField mode="view" label="Cơ sở" value={record.branch_code} />
            <DetailField
              mode="view"
              label="Môn"
              value={record.subject_name ?? record.subject_code}
            />
            <DetailField mode="view" label="Khối" value={record.grade_code.replace(/^K0?/, '')} />
            <DetailField
              mode="view"
              label="Phân loại"
              value={[record.class_type_name, record.level_name].filter(Boolean).join(' · ')}
            />
            <DetailField mode="view" label="Nhóm lớp" value={record.group_name ?? ''} />
          </DetailSection>
          <DetailSection title="Lịch và sĩ số">
            <DetailField mode="view" label="Khai giảng" value={formatDate(record.start_date)} />
            <DetailField
              mode="view"
              label="Kết thúc dự kiến"
              value={record.expected_end_date ? formatDate(record.expected_end_date) : ''}
            />
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

        <DetailSection title="Thời khoá biểu">
          {record.slots.length === 0 ? (
            <p className="py-2 text-fg-muted">Chưa có khung giờ.</p>
          ) : (
            <ul className="flex flex-col gap-1 py-1">
              {record.slots.map((s) => (
                <li key={s.id} className="flex flex-wrap gap-x-3">
                  <span className="font-medium">
                    {WEEKDAY_LABEL[s.weekday]} {timeText(s.start_time)}–{timeText(s.end_time)}
                  </span>
                  <span className="text-fg-muted">
                    {[
                      s.teacher_name && `GV ${s.teacher_name}`,
                      s.assistant_name && `TG ${s.assistant_name}`,
                      s.room_name,
                      s.repeat_weeks > 1 ? `lặp mỗi ${s.repeat_weeks} tuần` : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </DetailSection>

        <DetailSection title={`Học sinh (${record.students.length})`}>
          {record.students.length === 0 ? (
            <p className="py-2 text-fg-muted">Chưa có học sinh xếp vào lớp.</p>
          ) : (
            <ul className="flex flex-col divide-y divide-border">
              {record.students.map((s) => (
                <li key={s.enrollment_id} className="flex flex-wrap justify-between gap-2 py-1.5">
                  <span>
                    <span className="font-medium">{s.full_name}</span>{' '}
                    <span className="text-caption text-fg-muted">{s.student_code}</span>
                  </span>
                  <span className="text-caption text-fg-muted">
                    Vào lớp {formatDate(s.start_date)} · còn {s.hours_left} giờ
                  </span>
                </li>
              ))}
            </ul>
          )}
        </DetailSection>

        <DetailSection title="Buổi học">
          <p className="py-1 text-fg-muted">
            {counts.length === 0
              ? 'Chưa có buổi (sinh khi lớp được duyệt).'
              : counts.map(([k, n]) => `${SESSION_STATUS_LABEL[k] ?? k}: ${n}`).join(' · ')}
          </p>
          {record.sessions.length > 0 && (
            <ul className="flex max-h-72 flex-col divide-y divide-border overflow-y-auto">
              {record.sessions.map((s) => (
                <li key={s.id} className="flex flex-wrap justify-between gap-2 py-1.5">
                  <span>
                    {s.session_no ? `Buổi ${s.session_no} · ` : ''}
                    {formatDate(s.session_date)} {timeText(s.start_time)}–{timeText(s.end_time)}
                  </span>
                  <span className="text-caption text-fg-muted">
                    {SESSION_STATUS_LABEL[s.status_code] ?? s.status_code}
                    {s.teacher_name ? ` · ${s.teacher_name}` : ''}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </DetailSection>
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
