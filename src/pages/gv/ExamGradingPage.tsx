import { useState } from 'react';
import { Link, Navigate, useParams } from 'react-router';
import { Button, ButtonLink } from '../../ui/Button';
import { UnsavedGuard } from '../../ui/Dialogs';
import { INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { errorOf, FORBIDDEN_CODE } from '../../lib/db';
import { formatDate } from '../../lib/format';
import {
  anyDirty,
  buildExamSave,
  entryOf,
  GROUPS,
  gradedProgress,
  initialDraft,
  isExamEditable,
  isPresent,
  statusOf,
  type ExamConfig,
  type ExamDraft,
  type ExamDrafts,
  type ExamSheet,
  type ExamStudent,
} from './exam';
import { buildExamCard } from './exportCard';
import { ExportPanel } from './ExportPanel';
import { useExportedStudents } from './useExported';
import { useExamSheet, useSaveExam } from './useExam';

/**
 * GV-07K · Chấm kiểm tra (buổi Kiểm tra). Điểm tổng hoặc 3 nhóm Ghi nhớ, Hiểu, Vận dụng theo cấu hình do vận hành đặt; tổng tự cộng.
 * Ô trống là chưa chấm, khác điểm 0. Em vắng không nhập điểm, không tự nhận 0. Không tự lưu: bấm Lưu (cả lớp) (R-V2-20, R-GV-04).
 */
export function ExamGradingPage() {
  const { sessionId } = useParams();
  const query = useExamSheet(sessionId);

  if (query.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (query.isError) {
    const error = errorOf(query.error);
    const forbidden = error.code === FORBIDDEN_CODE;
    return (
      <StateView
        kind={forbidden ? 'forbidden' : 'error'}
        title={forbidden ? 'Bạn không xem được buổi này' : 'Không mở được màn chấm kiểm tra'}
        actions={
          forbidden ? (
            <ButtonLink to="/gv" variant="primary">
              Về trang Hôm nay
            </ButtonLink>
          ) : (
            <Button variant="primary" onClick={() => void query.refetch()}>
              Thử lại
            </Button>
          )
        }
      >
        {forbidden
          ? 'Giáo viên và trợ giảng chỉ thấy buổi của lớp mình được phân công.'
          : error.message}
      </StateView>
    );
  }
  // Buổi thường chấm bằng 9 tiêu chí, không ở màn này.
  if (query.data.session.review_form !== 'DIEM') {
    return <Navigate to={`/gv/buoi/${query.data.session.session_id}/cham-nhan-xet`} replace />;
  }
  return <ExamForm key={query.data.session.session_id} sheet={query.data} />;
}

function ExamForm({ sheet }: { sheet: ExamSheet }) {
  const toast = useToast();
  const sessionId = sheet.session.session_id;
  const save = useSaveExam(sessionId);
  const [drafts, setDrafts] = useState<ExamDrafts>({});
  const [saveError, setSaveError] = useState<string | null>(null);
  const [tried, setTried] = useState(false);
  // Điện thoại (canvas GV-07K): chấm từng em một; máy tính giữ danh sách cả lớp (K14).
  const phone = useMedia(NARROW_TABLE);
  const [selected, setSelected] = useState(0);
  const exam = sheet.exam;
  const editable = isExamEditable(sheet.session.status_code, exam);
  const done = sheet.session.status_code === 'DONE';
  const dirty = anyDirty(sheet, drafts);
  const progress = gradedProgress(sheet);
  const unmarked = sheet.students.some((s) => s.attendance_code === null);
  const exported = useExportedStudents(sessionId);
  const exportedSet = new Set(exported.data ?? []);

  const draftOf = (s: ExamStudent): ExamDraft => drafts[s.student_id] ?? initialDraft(s);
  const setDraft = (s: ExamStudent, next: ExamDraft) =>
    setDrafts((current) => ({ ...current, [s.student_id]: next }));

  function submit(next?: number) {
    setTried(true);
    const payload = buildExamSave(sheet, drafts);
    if (payload === null) return;
    setSaveError(null);
    save.mutate(payload, {
      onSuccess: () => {
        setTried(false);
        setDrafts({});
        toast({ tone: 'success', title: 'Đã lưu điểm kiểm tra' });
        if (next !== undefined) setSelected(next);
      },
      onError: (error) => {
        const e = errorOf(error);
        // Canvas GV-07K (loi_luu): lỗi mạng báo rõ dữ liệu vừa nhập vẫn còn trên màn hình.
        setSaveError(
          e.code === 'HMT_MANG'
            ? 'Mạng bị gián đoạn. Dữ liệu em vừa nhập vẫn còn trên màn hình.'
            : e.message,
        );
      },
    });
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
      <UnsavedGuard when={dirty} />
      <nav aria-label="Đường dẫn" className="text-caption text-fg-muted">
        <Link to="/gv" className="underline">
          Hôm nay
        </Link>
        {' › '}
        <Link to={`/gv/buoi/${sessionId}`} className="underline">
          Buổi dạy
        </Link>
        {' › Chấm kiểm tra'}
      </nav>
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-caption text-fg-muted uppercase">
            {sheet.session.class_code}
            {sheet.session.subject_name ? ` · ${sheet.session.subject_name}` : ''}
          </p>
          <h1 className="text-h3">
            {sheet.session.session_no ? `Buổi ${sheet.session.session_no} · ` : ''}Chấm kiểm tra
          </h1>
          <p className="text-caption text-fg-muted">
            {formatDate(sheet.session.session_date)} · {sheet.session.start_time.slice(0, 5)}–
            {sheet.session.end_time.slice(0, 5)} · Loại buổi: Kiểm tra
          </p>
        </div>
        <div className="flex items-center gap-3">
          {dirty && <span className="text-caption text-fg-muted">Chưa lưu</span>}
          {done && <span className="text-caption text-fg-muted">Buổi đã Hoàn thành</span>}
          <Button
            variant="primary"
            loading={save.isPending}
            disabled={!editable || !dirty}
            onClick={() => submit()}
          >
            Lưu
          </Button>
        </div>
      </header>

      {exam ? (
        <section aria-labelledby="gv07k-config" className="flex flex-col gap-1">
          <h2 id="gv07k-config" className="text-h4">
            Phạm vi kiến thức
          </h2>
          <p>{exam.scope_text ?? 'Chưa nhập phạm vi kiến thức.'}</p>
          <p className="text-caption text-fg-muted">
            Điểm tối đa {exam.max_score} · Cách nhập:{' '}
            {exam.entry_mode === 'NHOM'
              ? `3 nhóm: Ghi nhớ ${exam.max_memory} · Hiểu ${exam.max_understand} · Vận dụng ${exam.max_apply}`
              : 'điểm tổng'}
            . Do người xếp lịch đặt, giáo viên chỉ xem.
          </p>
        </section>
      ) : (
        <Alert tone="warning" title="Buổi kiểm tra chưa đặt điểm tối đa và cách nhập điểm.">
          Nhờ người xếp lịch đặt cấu hình buổi kiểm tra trước, rồi mới nhập điểm được.
        </Alert>
      )}
      {done && (
        <Alert tone="info" title="Buổi đã Hoàn thành: giáo viên không sửa được điểm.">
          Cần sửa thì tạo ticket gửi quản lý đào tạo; chỉ quản lý đào tạo sửa điểm và phải ghi lý
          do.{' '}
          <ButtonLink to="/gv/ticket/tao" size="sm">
            Tạo ticket sửa điểm
          </ButtonLink>
        </Alert>
      )}
      {unmarked && !done && (
        <Alert tone="info" title="Chưa điểm danh.">
          Điểm danh trước thì mới biết em nào làm bài, em nào vắng.{' '}
          <ButtonLink to={`/gv/buoi/${sessionId}/diem-danh`} size="sm">
            Đi điểm danh
          </ButtonLink>
        </Alert>
      )}
      {saveError && (
        <Alert tone="danger" title="Chưa lưu được điểm.">
          {saveError}{' '}
          <Button size="sm" onClick={() => submit()}>
            Thử lại
          </Button>
        </Alert>
      )}

      <p className="text-caption text-fg-muted">
        Đã chấm {progress.done}/{progress.total} em có mặt. Ô trống là chưa chấm, khác điểm 0. Em
        vắng lấy từ điểm danh, không tự nhận 0. Không tự lưu: bấm Lưu (cả lớp).
      </p>

      {exam && (
        <ExportPanel
          sessionId={sessionId}
          classCode={sheet.session.class_code}
          sessionDate={sheet.session.session_date}
          currentStudentId={null}
          showOne={false}
          dirty={dirty}
          items={sheet.students.map((s) => ({
            studentId: s.student_id,
            name: s.full_name,
            card: buildExamCard(sheet, s),
            exported: exportedSet.has(s.student_id),
          }))}
        />
      )}

      {exam && phone && sheet.students.length > 0 && (
        <section aria-label="Chấm từng em" className="flex flex-col gap-2">
          {(() => {
            const index = Math.min(selected, sheet.students.length - 1);
            const s = sheet.students[index] as ExamStudent;
            const last = index >= sheet.students.length - 1;
            return (
              <>
                <div className="flex items-center justify-between gap-2">
                  <p className="text-body font-medium">
                    Em {index + 1}/{sheet.students.length} · {s.full_name}
                  </p>
                  <div className="flex gap-1.5">
                    <Button
                      size="sm"
                      onClick={() => setSelected(Math.max(index - 1, 0))}
                      disabled={index === 0}
                    >
                      ‹ Em trước
                    </Button>
                    <Button
                      size="sm"
                      onClick={() => setSelected(Math.min(index + 1, sheet.students.length - 1))}
                      disabled={last}
                    >
                      Em kế ›
                    </Button>
                  </div>
                </div>
                <ul className="flex flex-col gap-2" aria-label="Học sinh">
                  <StudentRow
                    key={s.student_id}
                    student={s}
                    exam={exam}
                    draft={draftOf(s)}
                    editable={editable}
                    showErrors={tried}
                    onChange={(next) => setDraft(s, next)}
                  />
                </ul>
                {editable && dirty && !last && (
                  <Button
                    variant="primary"
                    loading={save.isPending}
                    onClick={() => submit(index + 1)}
                  >
                    Lưu và em tiếp theo
                  </Button>
                )}
              </>
            );
          })()}
        </section>
      )}

      {exam && !phone && (
        <ul className="flex flex-col gap-2" aria-label="Học sinh">
          {sheet.students.map((s) => (
            <StudentRow
              key={s.student_id}
              student={s}
              exam={exam}
              draft={draftOf(s)}
              editable={editable}
              showErrors={tried}
              onChange={(next) => setDraft(s, next)}
            />
          ))}
        </ul>
      )}
    </div>
  );
}

function StudentRow({
  student,
  exam,
  draft,
  editable,
  showErrors,
  onChange,
}: {
  student: ExamStudent;
  exam: ExamConfig;
  draft: ExamDraft;
  editable: boolean;
  showErrors: boolean;
  onChange: (next: ExamDraft) => void;
}) {
  const present = isPresent(student);
  const entry = entryOf(draft, exam);
  return (
    <li className="flex flex-col gap-2 rounded-lg border border-border p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <p className="text-body font-medium">{student.full_name}</p>
          <p className="text-caption text-fg-muted">
            {student.attendance_name ?? 'Chưa điểm danh'}
          </p>
        </div>
        <span className="rounded-full border border-border px-2 py-0.5 text-caption">
          {statusOf(student, draft, exam)}
        </span>
      </div>
      {!present ? (
        <p className="text-caption text-fg-muted">
          {student.attendance_code === null
            ? 'Chưa điểm danh nên chưa nhập điểm.'
            : 'Vắng: không nhập điểm, không tự tính 0.'}
        </p>
      ) : (
        <>
          <div className="flex flex-wrap items-end gap-3">
            {exam.entry_mode === 'TONG' ? (
              <label className="flex flex-col gap-1 text-caption">
                Điểm tổng (tối đa {exam.max_score})
                <input
                  className={INPUT_CLASS}
                  inputMode="decimal"
                  aria-label={`Điểm tổng của ${student.full_name}`}
                  value={draft.total}
                  disabled={!editable}
                  aria-invalid={showErrors && entry.error !== null ? true : undefined}
                  onChange={(event) => onChange({ ...draft, total: event.target.value })}
                />
              </label>
            ) : (
              GROUPS.filter((g) => (exam[g.maxKey] as number) > 0).map((g) => (
                <label key={g.key} className="flex flex-col gap-1 text-caption">
                  {g.label} (tối đa {exam[g.maxKey] as number})
                  <input
                    className={INPUT_CLASS}
                    inputMode="decimal"
                    aria-label={`${g.label} của ${student.full_name}`}
                    value={draft[g.key]}
                    disabled={!editable}
                    aria-invalid={showErrors && entry.error !== null ? true : undefined}
                    onChange={(event) => onChange({ ...draft, [g.key]: event.target.value })}
                  />
                </label>
              ))
            )}
            <p className="pb-2 text-body">
              Tổng {entry.total === null ? '—' : entry.total.toLocaleString('vi-VN')}/
              {exam.max_score}
            </p>
          </div>
          {entry.error && (
            <p role="alert" className="text-caption text-danger">
              {entry.error}
            </p>
          )}
          <TextAreaField
            label="Nhận xét chung"
            help="Không bắt buộc"
            value={draft.comment}
            disabled={!editable}
            onChange={(event) => onChange({ ...draft, comment: event.target.value })}
          />
          <TextAreaField
            label="Định hướng cải thiện"
            help="Không bắt buộc"
            value={draft.improvement}
            disabled={!editable}
            onChange={(event) => onChange({ ...draft, improvement: event.target.value })}
          />
        </>
      )}
    </li>
  );
}
