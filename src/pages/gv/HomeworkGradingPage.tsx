import { useState, type KeyboardEvent } from 'react';
import { Link, useParams } from 'react-router';
import { Button, ButtonLink } from '../../ui/Button';
import { UnsavedGuard } from '../../ui/Dialogs';
import { INPUT_CLASS } from '../../ui/Field';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { cn } from '../../ui/cn';
import { useToast } from '../../ui/toastContext';
import { errorOf, FORBIDDEN_CODE } from '../../lib/db';
import { formatDate } from '../../lib/format';
import {
  anyDirty,
  buildSaveItems,
  CONFLICT_CODE,
  countWithStatus,
  draftError,
  HOMEWORK_STATUSES,
  initialDraft,
  isGradingEditable,
  LATE_STATUSES,
  needsScore,
  SCORES,
  withStatus,
  type Draft,
  type GradingRow,
  type GradingSheet,
  type HomeworkStatus,
  type LateItem,
} from './homework';
import { useGradingSheet, useSaveGrading, useUpdateLate } from './useHomework';

/**
 * GV-08 · Chấm BTVN buổi trước. Mỗi em có mặt một trong 5 trạng thái; điểm 1–5 chỉ cho Đã chấm và Làm chưa xong. Không tự lưu: bấm Lưu.
 * Em vắng buổi giao bài: đặt sẵn Không áp dụng. Em vắng buổi này: không bắt buộc, bài vào Nộp sau, cập nhật ngay trên màn này (R-GV-11).
 * Hai người cùng sửa một ô: máy chủ từ chối lưu và báo «người khác» (không nêu tên, Chat duyệt 10/11).
 */
export function HomeworkGradingPage() {
  const { sessionId } = useParams();
  const query = useGradingSheet(sessionId);
  // Bản nháp giữ lại qua lần tải lại sau xung đột («Giữ của tôi»).
  const [carry, setCarry] = useState<Record<string, Draft>>({});

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
        title={forbidden ? 'Bạn không xem được buổi này' : 'Không mở được màn chấm BTVN'}
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
  const sheet = query.data;
  // key theo phiên bản các dòng: tải lại sau xung đột hoặc sau khi lưu thì dựng lại bản nháp theo máy chủ.
  const versions = sheet.students.map((s) => `${s.student_id}:${s.result?.version ?? 0}`).join(',');
  return (
    <GradingForm
      key={`${sheet.session.session_id}|${versions}|${sheet.late.length}`}
      sheet={sheet}
      carried={carry}
      reload={(keep) => {
        setCarry(keep);
        return query.refetch().then(() => undefined);
      }}
    />
  );
}

function GradingForm({
  sheet,
  carried,
  reload,
}: {
  sheet: GradingSheet;
  carried: Record<string, Draft>;
  reload: (keep: Record<string, Draft>) => Promise<void>;
}) {
  const toast = useToast();
  const sessionId = sheet.session.session_id;
  const save = useSaveGrading(sessionId);
  const [drafts, setDrafts] = useState<Record<string, Draft>>(carried);
  const [saveError, setSaveError] = useState<{ code: string; message: string } | null>(null);
  const [tried, setTried] = useState(false);
  const editable = isGradingEditable(sheet.session.status_code);
  const canGrade = sheet.state === 'CAN_CHAM';
  const dirty = anyDirty(sheet.students, drafts);
  const items = buildSaveItems(sheet.students, drafts);
  const withStatusCount = countWithStatus(sheet.students, drafts);
  const conflict = saveError?.code === CONFLICT_CODE;

  function draftOf(row: GradingRow): Draft {
    return drafts[row.student_id] ?? initialDraft(row);
  }
  function setDraft(row: GradingRow, next: Draft) {
    setDrafts((current) => ({ ...current, [row.student_id]: next }));
  }

  // Dùng mutateAsync: khi màn dựng lại giữa lúc lưu (khoá màn đổi theo phiên bản), lời gọi mutate mất các hàm onSuccess, onError nên thông báo
  // «Đã lưu» biến mất và bản nháp cũ vẫn hiện; lời hứa của mutateAsync vẫn chạy tiếp (toast ở nhà cung cấp phía trên, không mất).
  async function submit(batch = items) {
    setTried(true);
    if (batch === null) return;
    if (batch.length === 0) return;
    setSaveError(null);
    try {
      await save.mutateAsync(batch);
      setTried(false);
      setDrafts({});
      toast({ tone: 'success', title: 'Đã lưu chấm BTVN' });
    } catch (error) {
      setSaveError(errorOf(error));
    }
  }

  // «Giữ của tôi»: tải bản mới của máy chủ (phiên bản mới), giữ nguyên bản nháp đang có để giáo viên bấm Lưu lại.
  async function keepMine() {
    setSaveError(null);
    await reload(drafts);
  }

  function onKey(row: GradingRow, event: KeyboardEvent<HTMLLIElement>) {
    if (!editable || (event.target as HTMLElement).tagName === 'INPUT') return;
    const index = Number(event.key) - 1;
    const choice = HOMEWORK_STATUSES[index];
    if (choice) setDraft(row, withStatus(draftOf(row), choice.code));
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
        {' › Chấm BTVN buổi trước'}
      </nav>
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-caption text-fg-muted uppercase">
            {sheet.session.class_code}
            {sheet.session.subject_name ? ` · ${sheet.session.subject_name}` : ''}
          </p>
          <h1 className="text-h3">
            {sheet.session.session_no ? `Buổi ${sheet.session.session_no} · ` : ''}Chấm BTVN buổi
            trước
          </h1>
          <p className="text-caption text-fg-muted">
            {formatDate(sheet.session.session_date)} · {sheet.session.start_time.slice(0, 5)}–
            {sheet.session.end_time.slice(0, 5)}
          </p>
        </div>
        {canGrade && (
          <div className="flex items-center gap-3">
            {dirty && <span className="text-caption text-fg-muted">Chưa lưu</span>}
            <Button
              variant="primary"
              loading={save.isPending}
              disabled={!editable || !dirty}
              onClick={() => void submit()}
            >
              Lưu
            </Button>
          </div>
        )}
      </header>

      {sheet.state === 'DAU_LOP' && (
        <StateView kind="empty" title="Buổi đầu của lớp">
          Lớp chưa có buổi trước nên không có BTVN để chấm. Bước này tự bỏ qua, không chặn Hoàn
          thành và không chặn dấu thời hạn.
          <span className="mt-2 block">
            <ButtonLink to={`/gv/buoi/${sessionId}`}>Về các bước của buổi</ButtonLink>
          </span>
        </StateView>
      )}
      {sheet.state === 'KHONG_GIAO' && (
        <StateView kind="empty" title="Buổi trước không giao BTVN">
          Không có bài để chấm. Bước này tự bỏ qua, không chặn Hoàn thành.
          <span className="mt-2 block">
            <ButtonLink to={`/gv/buoi/${sessionId}`}>Về các bước của buổi</ButtonLink>
          </span>
        </StateView>
      )}

      {canGrade && sheet.prev && (
        <>
          <Alert tone="info">
            BTVN giao ở Buổi {sheet.prev.session_no ?? ''} ({formatDate(sheet.prev.session_date)}):{' '}
            {sheet.prev.homework_text}. Chấm trong hạn hoàn tất của buổi này.
          </Alert>
          {!editable && (
            <Alert tone="info">
              Buổi này đã Done hoặc chưa chốt danh sách nên chỉ xem. Bài Nộp sau vẫn cập nhật được ở
              dưới.
            </Alert>
          )}
          {saveError && (
            <Alert
              tone={conflict ? 'warning' : 'danger'}
              title={conflict ? 'Có ô vừa được người khác sửa' : undefined}
            >
              {saveError.message}{' '}
              {conflict ? (
                <span className="inline-flex flex-wrap gap-2">
                  <Button size="sm" variant="primary" onClick={() => void keepMine()}>
                    Giữ của tôi
                  </Button>
                  <Button
                    size="sm"
                    onClick={() => {
                      setSaveError(null);
                      setDrafts({});
                      void reload({});
                    }}
                  >
                    Lấy của người khác
                  </Button>
                </span>
              ) : (
                <Button size="sm" onClick={() => void submit()}>
                  Thử lại
                </Button>
              )}
            </Alert>
          )}

          <section aria-labelledby="gv08-list" className="flex flex-col gap-2">
            <div className="flex items-center justify-between gap-2">
              <h2 id="gv08-list" className="text-h4">
                Học sinh có mặt · {sheet.students.length}
              </h2>
              <span className="text-caption text-fg-muted">
                Có trạng thái {withStatusCount}/{sheet.students.length}
              </span>
            </div>
            {sheet.students.length === 0 && (
              <p className="text-caption text-fg-muted">Chưa có em nào có mặt ở buổi này.</p>
            )}
            <ul className="flex flex-col gap-2">
              {sheet.students.map((row) => {
                const draft = draftOf(row);
                const error = tried && drafts[row.student_id] ? draftError(draft) : null;
                return (
                  <li
                    key={row.student_id}
                    onKeyDown={(event) => onKey(row, event)}
                    className="flex flex-col gap-2 rounded-lg border border-border p-3"
                  >
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="text-body font-medium">{row.full_name}</span>
                      {row.absent_at_assignment && (
                        <span className="rounded-full border border-border px-2 py-0.5 text-caption">
                          Vắng buổi giao bài
                        </span>
                      )}
                    </div>
                    {row.absent_at_assignment && (
                      <p className="text-caption text-fg-muted">
                        Em vắng buổi giao bài (Buổi {sheet.prev?.session_no ?? ''},{' '}
                        {sheet.prev ? formatDate(sheet.prev.session_date) : ''}): đặt sẵn Không áp
                        dụng, không tính vào tỉ lệ làm bài. Bạn đổi được nếu em vẫn làm bài.
                      </p>
                    )}
                    <StatusButtons
                      name={row.full_name}
                      value={draft.status}
                      options={HOMEWORK_STATUSES}
                      disabled={!editable}
                      onPick={(code) => setDraft(row, withStatus(draft, code))}
                    />
                    {needsScore(draft.status) && (
                      <ScoreButtons
                        name={row.full_name}
                        value={draft.score}
                        disabled={!editable}
                        onPick={(score) => setDraft(row, { ...draft, score })}
                      />
                    )}
                    <input
                      aria-label={`Ghi chú cho ${row.full_name}`}
                      className={INPUT_CLASS}
                      placeholder="Ghi chú (không bắt buộc)"
                      value={draft.note}
                      disabled={!editable}
                      onChange={(event) => setDraft(row, { ...draft, note: event.target.value })}
                    />
                    {error && (
                      <p role="alert" className="text-caption text-danger">
                        {error}
                      </p>
                    )}
                  </li>
                );
              })}
            </ul>
            <p className="text-caption text-fg-muted">
              Bấm 1–5 chọn trạng thái (1 Đã chấm · 2 Làm chưa xong · 3 Không làm · 4 Nộp sau · 5
              Không áp dụng), điểm nhập khi là Đã chấm hoặc Làm chưa xong. Không làm không phải điểm
              0. Không tự lưu: bấm Lưu.
            </p>
          </section>

          {sheet.absent_now.length > 0 && (
            <section aria-labelledby="gv08-absent" className="flex flex-col gap-2">
              <h2 id="gv08-absent" className="text-h4">
                Em vắng buổi này · {sheet.absent_now.length}
              </h2>
              <p className="text-caption text-fg-muted">
                Không phải chấm ở buổi này. Bài của em vào mục Bài Nộp sau chờ cập nhật; khi em nộp
                bài, chấm ở đó.
              </p>
              <ul className="flex flex-col gap-1">
                {sheet.absent_now.map((a) => (
                  <li key={a.student_id} className="rounded-lg border border-border p-3 text-body">
                    {a.full_name}{' '}
                    <span className="text-caption text-fg-muted">
                      · {a.attendance_name ?? 'Vắng'}
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}

      {sheet.late.length > 0 && (
        <section aria-labelledby="gv08-late" className="flex flex-col gap-2">
          <h2 id="gv08-late" className="text-h4">
            Bài Nộp sau chờ cập nhật · {sheet.late.length}
          </h2>
          <p className="text-caption text-fg-muted">
            Cập nhật ở đây, không mở lại buổi cũ (R-GV-11).
          </p>
          <ul className="flex flex-col gap-2">
            {sheet.late.map((item) => (
              <LateRow
                key={`${item.assigned_session_id}:${item.student_id}`}
                item={item}
                sessionId={sessionId}
              />
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}

function StatusButtons({
  name,
  value,
  options,
  disabled,
  onPick,
}: {
  name: string;
  value: HomeworkStatus | null;
  options: { code: HomeworkStatus; label: string }[];
  disabled: boolean;
  onPick: (code: HomeworkStatus) => void;
}) {
  return (
    <div role="group" aria-label={`Trạng thái BTVN của ${name}`} className="flex flex-wrap gap-1.5">
      {options.map((option, index) => (
        <Button
          key={option.code}
          size="sm"
          variant={value === option.code ? 'primary' : 'secondary'}
          aria-pressed={value === option.code}
          disabled={disabled}
          onClick={() => onPick(option.code)}
        >
          {options.length === HOMEWORK_STATUSES.length ? `${index + 1} ` : ''}
          {option.label}
        </Button>
      ))}
    </div>
  );
}

function ScoreButtons({
  name,
  value,
  disabled,
  onPick,
}: {
  name: string;
  value: number | null;
  disabled: boolean;
  onPick: (score: number) => void;
}) {
  return (
    <div
      role="group"
      aria-label={`Điểm 1–5 của ${name}`}
      className="flex flex-wrap items-center gap-1.5"
    >
      <span className="text-caption text-fg-muted">Điểm 1–5</span>
      {SCORES.map((score) => (
        <Button
          key={score}
          size="sm"
          variant={value === score ? 'primary' : 'secondary'}
          className={cn('min-w-9 justify-center')}
          aria-pressed={value === score}
          disabled={disabled}
          onClick={() => onPick(score)}
        >
          {score}
        </Button>
      ))}
    </div>
  );
}

function LateRow({ item, sessionId }: { item: LateItem; sessionId: string }) {
  const toast = useToast();
  const update = useUpdateLate(sessionId);
  const [status, setStatus] = useState<HomeworkStatus | null>(null);
  const [score, setScore] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const invalid = status === null || (needsScore(status) && score === null);

  function submit() {
    if (invalid || status === null) return;
    setError(null);
    update.mutate(
      {
        assignedSessionId: item.assigned_session_id,
        studentId: item.student_id,
        status,
        score: needsScore(status) ? score : null,
        version: item.version,
      },
      {
        onSuccess: () => toast({ tone: 'success', title: 'Đã cập nhật bài Nộp sau' }),
        onError: (e) => setError(errorOf(e).message),
      },
    );
  }

  return (
    <li className="flex flex-col gap-2 rounded-lg border border-border p-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-body font-medium">{item.full_name}</span>
        <span className="text-caption text-fg-muted">
          BTVN Buổi {item.session_no ?? ''} ({formatDate(item.session_date)})
        </span>
        {item.inferred && (
          <span className="rounded-full border border-border px-2 py-0.5 text-caption">
            Vắng buổi chấm
          </span>
        )}
      </div>
      <StatusButtons
        name={item.full_name}
        value={status}
        options={LATE_STATUSES}
        disabled={update.isPending}
        onPick={(code) => {
          setStatus(code);
          if (!needsScore(code)) setScore(null);
        }}
      />
      {needsScore(status) && (
        <ScoreButtons
          name={item.full_name}
          value={score}
          disabled={update.isPending}
          onPick={setScore}
        />
      )}
      <div>
        <Button
          size="sm"
          variant="primary"
          loading={update.isPending}
          disabled={invalid}
          onClick={submit}
        >
          Cập nhật
        </Button>
      </div>
      {error && (
        <p role="alert" className="text-caption text-danger">
          {error}
        </p>
      )}
    </li>
  );
}
