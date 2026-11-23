import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { StickyActionBar } from '../../ui/StickyActionBar';
import { Button, ButtonLink } from '../../ui/Button';
import { UnsavedGuard } from '../../ui/Dialogs';
import { Dialog } from '../../ui/Overlays';
import { INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { errorOf, FORBIDDEN_CODE } from '../../lib/db';
import { formatDate } from '../../lib/format';
import {
  cleanLines,
  CONFLICT_CODE,
  conflictCells,
  EXAM_FORM,
  initialLines,
  isContentEditable,
  isDirty,
  saveBlocker,
  type SessionOverview,
} from './sessionContent';
import { useSaveSessionContent, useSessionOverview } from './useSessionContent';
import { SessionStepBar } from './SessionStepBar';

/**
 * GV-06 · Nội dung buổi và BTVN. Lưu bằng nút Lưu (không tự lưu). Cần ít nhất một dòng nội dung; BTVN để trống nghĩa là buổi này
 * không giao, không có ô "không giao BTVN" (R-V2-35). Hai người cùng sửa: máy chủ từ chối lưu và báo tải lại (Q-243, trước 17/11).
 */
export function SessionContentPage() {
  const { sessionId } = useParams();
  const query = useSessionOverview(sessionId);

  if (query.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (query.isError) {
    const error = errorOf(query.error);
    return (
      <StateView
        kind={error.code === FORBIDDEN_CODE ? 'forbidden' : 'error'}
        title={
          error.code === FORBIDDEN_CODE ? 'Bạn không có quyền xem buổi này' : 'Không mở được buổi'
        }
        actions={
          error.code === FORBIDDEN_CODE ? undefined : (
            <Button variant="primary" onClick={() => void query.refetch()}>
              Thử lại
            </Button>
          )
        }
      >
        {error.message}
      </StateView>
    );
  }
  // key chỉ theo buổi: khi máy chủ có bản mới (người khác sửa) thì giữ bản nháp của bạn để hộp xung đột cho chọn bên nào được ghi.
  return (
    <ContentForm
      key={query.data.session_id}
      overview={query.data}
      reload={() => void query.refetch()}
    />
  );
}

function ContentForm({ overview, reload }: { overview: SessionOverview; reload: () => void }) {
  const toast = useToast();
  const save = useSaveSessionContent(overview.session_id);
  const [lines, setLines] = useState(() => initialLines(overview.lines));
  const [homework, setHomework] = useState(overview.homework_text ?? '');
  const [saveError, setSaveError] = useState<{ code: string; message: string } | null>(null);
  const [tried, setTried] = useState(false);
  const editable = isContentEditable(overview.status_code);
  // Bản đã lưu mà bạn đang sửa trên đó (snap) và số phiên bản của nó (base). Máy chủ có bản mới hơn (người khác sửa):
  // chưa sửa gì thì tự lấy bản mới; đã sửa thì giữ bản nháp, chờ bạn chọn ở hộp xung đột (GV06_xung_dot).
  const [snap, setSnap] = useState({ lines: overview.lines, homework: overview.homework_text });
  const [base, setBase] = useState(overview.content_version);
  const [conflictOpen, setConflictOpen] = useState(false);
  const dirty = isDirty(snap, { lines, homework });
  if (overview.content_version !== base && !dirty && !conflictOpen) {
    setBase(overview.content_version);
    setSnap({ lines: overview.lines, homework: overview.homework_text });
    setLines(initialLines(overview.lines));
    setHomework(overview.homework_text ?? '');
  }
  const isExam = overview.review_form === EXAM_FORM;
  const blocker = saveBlocker(lines, overview.review_form);
  const conflict = saveError?.code === CONFLICT_CODE;
  // Đã lấy được bản của người kia (phiên bản máy chủ khác bản bạn đang sửa trên đó).
  const theirsLoaded = overview.content_version !== base;
  const cells = theirsLoaded
    ? conflictCells(
        { lines, homework },
        { lines: overview.lines, homework: overview.homework_text },
      )
    : [];

  function setLine(index: number, value: string) {
    setLines((current) => current.map((line, i) => (i === index ? value : line)));
  }

  function submit(version = base) {
    setTried(true);
    if (blocker) return;
    setSaveError(null);
    save.mutate(
      { lines: cleanLines(lines), homework, version },
      {
        onSuccess: (newVersion) => {
          setTried(false);
          setConflictOpen(false);
          setSnap({ lines: cleanLines(lines), homework });
          setBase(typeof newVersion === 'number' ? newVersion : version);
          toast({ tone: 'success', title: 'Đã lưu nội dung buổi' });
        },
        onError: (error) => {
          const { code, message } = errorOf(error);
          setSaveError({ code, message });
          if (code === CONFLICT_CODE) {
            setConflictOpen(true);
            reload(); // lấy bản của người kia để hiện trong hộp; bản nháp của bạn vẫn giữ
          }
        },
      },
    );
  }

  /** «Giữ của tôi»: ghi bản của bạn lên trên bản vừa lấy. */
  function keepMine() {
    setConflictOpen(false);
    submit(overview.content_version);
  }

  /** «Lấy của người kia»: bỏ bản nháp, dùng bản máy chủ. */
  function takeTheirs() {
    setLines(initialLines(overview.lines));
    setHomework(overview.homework_text ?? '');
    setSnap({ lines: overview.lines, homework: overview.homework_text });
    setBase(overview.content_version);
    setSaveError(null);
    setConflictOpen(false);
  }

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-4 p-4">
      <UnsavedGuard when={dirty} />
      <nav aria-label="Đường dẫn" className="text-caption text-fg-muted">
        <Link to="/gv" className="inline-flex min-h-11 items-center underline">
          Hôm nay
        </Link>
        {' › '}
        <Link
          to={`/gv/buoi/${overview.session_id}`}
          className="inline-flex min-h-11 items-center underline"
        >
          Buổi dạy
        </Link>
        {' › Nội dung buổi và BTVN'}
      </nav>
      <SessionStepBar
        current={2}
        done={
          overview.attendance_total > 0 && overview.attendance_marked === overview.attendance_total
            ? [1]
            : []
        }
      />
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-caption text-fg-muted uppercase">
            {overview.class_code}
            {overview.subject_name ? ` · ${overview.subject_name}` : ''}
          </p>
          <h1 className="text-h3">
            {overview.session_no ? `Buổi ${overview.session_no} · ` : ''}
            {isExam ? 'Phạm vi kiểm tra và BTVN' : 'Nội dung buổi và BTVN'}
          </h1>
          <p className="text-caption text-fg-muted">
            {formatDate(overview.session_date)} · {overview.start_time.slice(0, 5)}–
            {overview.end_time.slice(0, 5)}
          </p>
          {overview.type_name && (
            <span
              className="mt-1 inline-block rounded-full border border-border px-2 py-0.5 text-caption"
              title="Loại buổi do người xếp lịch chọn, giáo viên chỉ xem"
            >
              Loại buổi: {overview.type_name}
            </span>
          )}
        </div>
      </header>

      {editable && overview.review_scored > 0 && (
        <Alert tone="info" title="Sửa nội dung sau khi đã chấm.">
          Trước khi Done vẫn thêm, sửa, xoá dòng nội dung được. Điểm 9 tiêu chí của các em không
          đổi.
        </Alert>
      )}
      {!editable && (
        <Alert tone="info">
          Buổi này đã Done hoặc đã đóng nên chỉ xem. Cần sửa thì tạo ticket cho vận hành.
        </Alert>
      )}
      {saveError && (
        <Alert tone={conflict ? 'warning' : 'danger'}>
          {saveError.message}{' '}
          {conflict ? (
            <Button size="sm" variant="primary" onClick={() => setConflictOpen(true)}>
              Chọn bản
            </Button>
          ) : (
            <Button size="sm" onClick={() => submit()}>
              Thử lại
            </Button>
          )}
        </Alert>
      )}

      {isExam && overview.exam && (
        <section aria-labelledby="gv06-exam" className="flex flex-col gap-1">
          <h2 id="gv06-exam" className="text-h4">
            Phạm vi kiến thức
          </h2>
          <p>{overview.exam.scope_text ?? 'Chưa nhập phạm vi kiến thức.'}</p>
          <p className="text-caption text-fg-muted">
            Điểm tối đa {overview.exam.max_score}
            {overview.exam.entry_mode === 'NHOM'
              ? ` · Theo 3 nhóm: Ghi nhớ ${overview.exam.max_memory} · Hiểu ${overview.exam.max_understand} · Vận dụng ${overview.exam.max_apply}`
              : ' · Nhập tổng điểm'}
            . Do người xếp lịch đặt, giáo viên chỉ xem.
          </p>
        </section>
      )}

      <section aria-labelledby="gv06-lines" className="flex flex-col gap-2">
        <h2 id="gv06-lines" className="text-h4">
          Nội dung buổi
        </h2>
        <p className="text-caption text-fg-muted">
          {isExam
            ? 'Buổi kiểm tra: dòng nội dung tuỳ giáo viên.'
            : 'Cần ít nhất một dòng nội dung.'}
        </p>
        <ul className="flex flex-col gap-2">
          {lines.map((line, index) => (
            <li key={index} className="flex items-center gap-2">
              <input
                aria-label={`Dòng nội dung ${index + 1}`}
                aria-invalid={tried && blocker !== null && index === 0 ? true : undefined}
                className={INPUT_CLASS}
                value={line}
                disabled={!editable}
                onChange={(event) => setLine(index, event.target.value)}
              />
              {editable && lines.length > 1 && (
                <Button
                  size="sm"
                  aria-label={`Xoá dòng ${index + 1}`}
                  onClick={() => setLines((current) => current.filter((_, i) => i !== index))}
                >
                  Xoá
                </Button>
              )}
            </li>
          ))}
        </ul>
        {tried && blocker && (
          <p role="alert" className="text-caption text-danger">
            {blocker}
          </p>
        )}
        {editable && (
          <div>
            <Button icon="plus" onClick={() => setLines((current) => [...current, ''])}>
              Thêm dòng
            </Button>
          </div>
        )}
      </section>

      <section aria-labelledby="gv06-homework" className="flex flex-col gap-2">
        <div className="flex items-center gap-2">
          <h2 id="gv06-homework" className="text-h4">
            Giao BTVN cho buổi sau
          </h2>
          <span className="rounded-full border border-border px-2 py-0.5 text-caption">
            Không bắt buộc
          </span>
        </div>
        <TextAreaField
          label="Bài tập về nhà giao mới"
          help="Giao bài về nhà là tuỳ giáo viên. Để trống nếu buổi này không giao; không ảnh hưởng việc hoàn thành bước 2."
          value={homework}
          disabled={!editable}
          onChange={(event) => setHomework(event.target.value)}
        />
      </section>

      <p className="text-caption text-fg-muted">
        {isExam
          ? 'Dòng nội dung và BTVN đều tuỳ giáo viên. Không tự lưu.'
          : 'Cần ít nhất một dòng nội dung. BTVN tuỳ giáo viên. Không tự lưu.'}
      </p>
      <StickyActionBar>
        {dirty && <span className="text-caption text-fg-muted">Chưa lưu</span>}
        {!dirty && editable && (
          <ButtonLink to={`/gv/buoi/${overview.session_id}`}>Bước tiếp ›</ButtonLink>
        )}
        <Button
          variant="primary"
          loading={save.isPending}
          disabled={!editable || !dirty}
          onClick={() => submit()}
        >
          Lưu
        </Button>
      </StickyActionBar>

      {/* GV06_xung_dot: có người lưu trước bạn. Chọn bên nào thì bên đó được ghi. */}
      <Dialog
        open={conflictOpen}
        onOpenChange={setConflictOpen}
        title="Có ô vừa được người khác sửa"
        description="Từ lúc bạn mở màn, có người đã sửa các ô dưới đây. Chọn bên nào sẽ được ghi."
        dismissible
        footer={
          <>
            <Button onClick={takeTheirs} disabled={!theirsLoaded}>
              Lấy của người kia
            </Button>
            <Button variant="primary" onClick={keepMine} disabled={!theirsLoaded}>
              Giữ của tôi
            </Button>
          </>
        }
      >
        {theirsLoaded ? (
          <ul className="flex flex-col gap-2 text-body">
            {cells.map((c) => (
              <li key={c.key}>
                <b>{c.label}</b>
                <br />
                Của bạn: {c.mine || 'trống'}
                <br />
                Của người kia: {c.theirs || 'trống'}
              </li>
            ))}
          </ul>
        ) : (
          <Spinner label="Đang lấy bản mới" />
        )}
      </Dialog>
    </div>
  );
}
