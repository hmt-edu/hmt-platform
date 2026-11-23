import { useState } from 'react';
import { Link, Navigate, useParams } from 'react-router';
import { Button, ButtonLink } from '../../ui/Button';
import { StickyActionBar } from '../../ui/StickyActionBar';
import { UnsavedGuard } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { cn } from '../../ui/cn';
import { useToast } from '../../ui/toastContext';
import { errorOf, FORBIDDEN_CODE } from '../../lib/db';
import { formatDate } from '../../lib/format';
import {
  buildSave,
  cellOf,
  countCellStates,
  classProgress,
  EMPTY_DRAFT,
  GROUP_LABEL,
  GROUP_ORDER,
  isEnabled,
  isPresent,
  isReviewDirty,
  isReviewEditable,
  LEVELS,
  noteOf,
  pickInsufficient,
  clearCell,
  pickLevel,
  previewAverage,
  progressOfStudent,
  savedCell,
  setCell,
  type Cell,
  type ReviewCriterion,
  type ReviewDraft,
  type ReviewSheet,
  type ReviewStudent,
} from './review';
import { buildReviewCard } from './exportCard';
import { ExportPanel } from './ExportPanel';
import { useExportedStudents } from './useExported';
import { useOpenReview, useParentHint, useReviewSheet, useSaveReview } from './useReview';

/**
 * GV-07 · Chấm nhận xét từng em (bố cục «Theo em»). Mỗi ô có 4 trạng thái: Đã đánh giá (1–5), Không áp dụng (cả buổi, công tắc tiêu chí),
 * Chưa đủ căn cứ (từng em), Chưa đánh giá (mặc định, khác điểm 0). Em vắng không chấm. Không tự lưu: bấm Lưu (R-V2-19, R-GV-02, R-GV-04).
 * Buổi Kiểm tra chấm bằng điểm ở GV-07K. Chưa làm: «Theo tiêu chí» (chấm theo cột), «Cả lớp», xuất nhận xét, chống ghi đè nhận xét (sau 17/11).
 */
export function ReviewGradingPage() {
  const { sessionId } = useParams();
  const query = useReviewSheet(sessionId);

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
        title={forbidden ? 'Bạn không xem được buổi này' : 'Không mở được màn chấm nhận xét'}
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
  // Buổi Kiểm tra chấm bằng điểm ở màn GV-07K.
  if (query.data.session.review_form === 'DIEM') {
    return <Navigate to={`/gv/buoi/${query.data.session.session_id}/cham-kiem-tra`} replace />;
  }
  return <ReviewForm key={query.data.session.session_id} sheet={query.data} />;
}

function ReviewForm({ sheet }: { sheet: ReviewSheet }) {
  const toast = useToast();
  const sessionId = sheet.session.session_id;
  const save = useSaveReview(sessionId);
  const open = useOpenReview(sessionId);
  const [draft, setDraft] = useState<ReviewDraft>(EMPTY_DRAFT);
  const [selected, setSelected] = useState(0);
  const [showHint, setShowHint] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const editable = isReviewEditable(sheet.session.status_code, sheet.session.review_form);
  const dirty = isReviewDirty(sheet, draft);
  const progress = classProgress(draft, sheet.students, sheet.criteria);
  const student = sheet.students[Math.min(selected, sheet.students.length - 1)];
  const hint = useParentHint(sessionId, student?.student_id ?? null, showHint && !dirty);
  const exported = useExportedStudents(sessionId);
  const exportedSet = new Set(exported.data ?? []);

  function submit(next?: number) {
    setSaveError(null);
    save.mutate(buildSave(sheet, draft), {
      onSuccess: () => {
        setDraft(EMPTY_DRAFT);
        toast({ tone: 'success', title: 'Đã lưu nhận xét' });
        if (next !== undefined) setSelected(next);
      },
      onError: (error) => setSaveError(errorOf(error).message),
    });
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
      <UnsavedGuard when={dirty} />
      <nav aria-label="Đường dẫn" className="text-caption text-fg-muted">
        <Link to="/gv" className="inline-flex min-h-11 items-center underline">
          Hôm nay
        </Link>
        {' › '}
        <Link to={`/gv/buoi/${sessionId}`} className="inline-flex min-h-11 items-center underline">
          Buổi dạy
        </Link>
        {' › Chấm nhận xét'}
      </nav>
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-caption text-fg-muted uppercase">
            {sheet.session.class_code}
            {sheet.session.subject_name ? ` · ${sheet.session.subject_name}` : ''}
          </p>
          <h1 className="text-h3">
            {sheet.session.session_no ? `Buổi ${sheet.session.session_no} · ` : ''}Chấm nhận xét
          </h1>
          <p className="text-caption text-fg-muted">
            {formatDate(sheet.session.session_date)} · {sheet.session.start_time.slice(0, 5)}–
            {sheet.session.end_time.slice(0, 5)}
          </p>
        </div>
      </header>

      {!editable && (
        <Alert tone="info">
          Buổi này đã Done hoặc chưa chốt danh sách nên chỉ xem. Cần sửa thì tạo ticket cho vận
          hành.
        </Alert>
      )}
      {saveError && (
        <Alert tone="danger">
          {saveError}{' '}
          <Button size="sm" onClick={() => submit()}>
            Thử lại
          </Button>
        </Alert>
      )}

      {sheet.criteria.length === 0 ? (
        <StateView kind="empty" title="Chưa mở nhận xét của buổi">
          Mở nhận xét để dùng 9 tiêu chí của môn này (3 tiêu chí thái độ chung mọi môn, 3 tiêu chí
          tiếp thu, 3 tiêu chí vận dụng).
          {editable && (
            <span className="mt-2 block">
              <Button variant="primary" loading={open.isPending} onClick={() => open.mutate()}>
                Mở nhận xét của buổi
              </Button>
            </span>
          )}
        </StateView>
      ) : (
        <>
          <section aria-labelledby="gv07-progress" className="rounded-lg border border-border p-3">
            <h2 id="gv07-progress" className="text-h4">
              Tiến độ nhận xét
            </h2>
            <p className="text-caption text-fg-muted">
              Đủ {progress.done}/{progress.total} em có mặt
            </p>
          </section>

          <section aria-labelledby="gv07-students" className="flex flex-col gap-2">
            <h2 id="gv07-students" className="text-h4">
              Học sinh · {sheet.students.length}
            </h2>
            <ul className="flex flex-wrap gap-1.5">
              {sheet.students.map((s, index) => (
                <li key={s.student_id}>
                  <Button
                    size="sm"
                    variant={index === selected ? 'primary' : 'secondary'}
                    aria-pressed={index === selected}
                    onClick={() => setSelected(index)}
                  >
                    {s.full_name} · {studentTag(draft, s, sheet.criteria)}
                    {exportedSet.has(s.student_id) ? ' · Đã xuất' : ''}
                  </Button>
                </li>
              ))}
            </ul>
          </section>

          {student && (
            <StudentCard
              key={student.student_id}
              sheet={sheet}
              student={student}
              index={selected}
              draft={draft}
              setDraft={setDraft}
              editable={editable}
              onNext={() =>
                setSelected((current) => Math.min(current + 1, sheet.students.length - 1))
              }
              onSaveNext={() => submit(Math.min(selected + 1, sheet.students.length - 1))}
              saving={save.isPending}
              onPrev={() => setSelected((current) => Math.max(current - 1, 0))}
              showHint={showHint}
              toggleHint={() => setShowHint((v) => !v)}
              hintQuery={hint}
              dirty={dirty}
            />
          )}

          <CriteriaSwitches
            criteria={sheet.criteria}
            draft={draft}
            setDraft={setDraft}
            editable={editable}
          />
          <ExportPanel
            sessionId={sessionId}
            classCode={sheet.session.class_code}
            sessionDate={sheet.session.session_date}
            currentStudentId={student?.student_id ?? null}
            dirty={dirty}
            items={sheet.students.map((s) => ({
              studentId: s.student_id,
              name: s.full_name,
              card: buildReviewCard(sheet, s),
              exported: exportedSet.has(s.student_id),
            }))}
          />

          <StickyActionBar>
            {dirty && <span className="text-caption text-fg-muted">Chưa lưu</span>}
            {!dirty && editable && (
              <ButtonLink to={`/gv/buoi/${sessionId}`}>Bước tiếp ›</ButtonLink>
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
        </>
      )}
    </div>
  );
}

function studentTag(
  draft: ReviewDraft,
  student: ReviewStudent,
  criteria: ReviewCriterion[],
): string {
  if (student.attendance_code === null) return 'Chưa điểm danh';
  if (!isPresent(student)) return 'Vắng: không có điểm';
  const p = progressOfStudent(draft, student, criteria);
  return p.total > 0 && p.done === p.total ? 'Đủ' : `${p.done}/${p.total}`;
}

function StudentCard({
  sheet,
  student,
  index,
  draft,
  setDraft,
  editable,
  onNext,
  onSaveNext,
  saving,
  onPrev,
  showHint,
  toggleHint,
  hintQuery,
  dirty,
}: {
  sheet: ReviewSheet;
  student: ReviewStudent;
  index: number;
  draft: ReviewDraft;
  setDraft: (next: ReviewDraft) => void;
  editable: boolean;
  onNext: () => void;
  /** Lưu cả phiếu rồi sang em kế (canvas GV-07 điện thoại: «Lưu và em tiếp theo»). */
  onSaveNext: () => void;
  saving: boolean;
  onPrev: () => void;
  showHint: boolean;
  toggleHint: () => void;
  hintQuery: ReturnType<typeof useParentHint>;
  dirty: boolean;
}) {
  const present = isPresent(student);
  const avg = previewAverage(draft, student, sheet.criteria);
  const note = noteOf(draft, student);
  const progress = progressOfStudent(draft, student, sheet.criteria);
  const counts = countCellStates(draft, student, sheet.criteria);

  return (
    <section
      aria-label={`Thẻ chấm ${student.full_name}`}
      className="flex flex-col gap-3 rounded-lg border border-border p-3"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <p className="text-body font-medium">
            Em {index + 1}/{sheet.students.length} · {student.full_name}
          </p>
          <p className="text-caption text-fg-muted">
            {student.attendance_name ?? 'Chưa điểm danh'}
            {present && ` · Đã chấm ${progress.done}/${progress.total}`}
            {present &&
              avg !== null &&
              ` · Điểm trung bình ${avg.toLocaleString('vi-VN', { maximumFractionDigits: 1 })}`}
          </p>
        </div>
        <div className="flex gap-1.5">
          <Button size="sm" onClick={onPrev} disabled={index === 0}>
            ‹ Em trước
          </Button>
          <Button size="sm" onClick={onNext} disabled={index >= sheet.students.length - 1}>
            Em kế ›
          </Button>
          {editable && dirty && index < sheet.students.length - 1 && (
            <Button size="sm" variant="primary" loading={saving} onClick={onSaveNext}>
              Lưu và em tiếp theo
            </Button>
          )}
        </div>
      </div>

      {!present ? (
        <>
          <Alert tone="info">
            {student.attendance_code === null
              ? 'Em chưa được điểm danh. Điểm danh em này trước khi chấm. Chưa biết em có mặt hay vắng nên chưa chấm được.'
              : student.attendance_code === 'VANG_CO_PHEP'
                ? 'Em vắng có phép: không chấm. Không nhập điểm, không cần nhận xét.'
                : 'Em vắng: không chấm nhận xét.'}
          </Alert>
          {student.attendance_code === null ? (
            <div>
              <ButtonLink to={`/gv/buoi/${sheet.session.session_id}/diem-danh`} variant="primary">
                Điểm danh em này
              </ButtonLink>
            </div>
          ) : (
            <ul className="flex flex-col gap-1.5">
              {sheet.criteria.map((criterion) => {
                const saved = savedCell(student, criterion.criterion_id);
                const kept = saved.state === 'DA_DANH_GIA' && saved.score !== null;
                return (
                  <li
                    key={criterion.criterion_id}
                    className="flex items-center justify-between gap-2 rounded-lg border border-dashed border-border p-2 text-body"
                  >
                    <span>{criterion.name}</span>
                    <span className="text-caption text-fg-muted">
                      {kept ? `Giữ, không tính · Mức ${saved.score}` : 'Không chấm'}
                    </span>
                  </li>
                );
              })}
            </ul>
          )}
        </>
      ) : (
        <>
          <div
            role="group"
            aria-label="Thống kê ô của em này"
            className="grid grid-cols-2 gap-2 rounded-lg border border-border p-2 text-caption sm:grid-cols-4"
          >
            <span>{counts.DA_DANH_GIA} Đã đánh giá</span>
            <span>{counts.CHUA_DANH_GIA} Chưa đánh giá</span>
            <span>{counts.CHUA_DU_CAN_CU} Chưa đủ căn cứ</span>
            <span>{counts.KHONG_AP_DUNG} Không áp dụng</span>
          </div>
          {GROUP_ORDER.map((group) => {
            const items = sheet.criteria.filter((c) => c.group_code === group);
            if (items.length === 0) return null;
            return (
              <fieldset key={group} className="flex flex-col gap-2">
                <legend className="text-caption font-semibold text-fg-muted uppercase">
                  {GROUP_LABEL[group] ?? group}
                </legend>
                {items.map((criterion) => (
                  <CriterionRow
                    key={criterion.criterion_id}
                    criterion={criterion}
                    enabled={isEnabled(draft, criterion)}
                    cell={cellOf(draft, student, criterion.criterion_id)}
                    editable={editable}
                    onChange={(cell) =>
                      setDraft(setCell(draft, student.student_id, criterion.criterion_id, cell))
                    }
                    studentName={student.full_name}
                  />
                ))}
              </fieldset>
            );
          })}
          <TextAreaField
            label="Nhận xét chung"
            help="Không bắt buộc"
            value={note.comment}
            disabled={!editable}
            onChange={(event) =>
              setDraft({
                ...draft,
                notes: {
                  ...draft.notes,
                  [student.student_id]: { ...note, comment: event.target.value },
                },
              })
            }
          />
          <TextAreaField
            label="Định hướng cải thiện"
            help="Không bắt buộc"
            value={note.improvement}
            disabled={!editable}
            onChange={(event) =>
              setDraft({
                ...draft,
                notes: {
                  ...draft.notes,
                  [student.student_id]: { ...note, improvement: event.target.value },
                },
              })
            }
          />
          <div className="flex flex-col gap-2">
            <div>
              <Button size="sm" onClick={toggleHint}>
                {showHint ? 'Ẩn lời nhắn phụ huynh' : 'Xem trước lời nhắn phụ huynh'}
              </Button>
            </div>
            {showHint &&
              (dirty ? (
                <p className="text-caption text-fg-muted">
                  Lưu trước để xem gợi ý theo điểm đã lưu.
                </p>
              ) : hintQuery.isPending ? (
                <Spinner />
              ) : hintQuery.data && hintQuery.data.phrases.length > 0 ? (
                <ul className="list-disc pl-5 text-body">
                  {hintQuery.data.phrases.map((phrase) => (
                    <li key={phrase}>{phrase}</li>
                  ))}
                </ul>
              ) : (
                <p className="text-caption text-fg-muted">Chưa có điểm để gợi ý lời nhắn.</p>
              ))}
          </div>
        </>
      )}
    </section>
  );
}

function CriterionRow({
  criterion,
  enabled,
  cell,
  editable,
  onChange,
  studentName,
}: {
  criterion: ReviewCriterion;
  enabled: boolean;
  cell: Cell;
  editable: boolean;
  onChange: (cell: Cell) => void;
  studentName: string;
}) {
  if (!enabled) {
    return (
      <div className="rounded-lg border border-dashed border-border p-2">
        <p className="text-body">{criterion.name}</p>
        <p className="text-caption text-fg-muted">
          Không áp dụng cả buổi (tắt ở Tiêu chí của buổi). Không tính điểm.
        </p>
      </div>
    );
  }
  const levelText =
    cell.state === 'DA_DANH_GIA' && cell.score ? criterion.levels?.[cell.score - 1] : null;
  return (
    <div className="flex flex-col gap-1.5 rounded-lg border border-border p-2">
      <p className="text-body font-medium">{criterion.name}</p>
      {criterion.hint && <p className="text-caption text-fg-muted">{criterion.hint}</p>}
      <div
        role="group"
        aria-label={`${criterion.name} của ${studentName}`}
        className="flex flex-wrap items-center gap-1.5"
      >
        {LEVELS.map((level) => (
          <Button
            key={level}
            size="sm"
            variant={cell.state === 'DA_DANH_GIA' && cell.score === level ? 'primary' : 'secondary'}
            className="h-11 min-w-11 justify-center"
            aria-pressed={cell.state === 'DA_DANH_GIA' && cell.score === level}
            aria-label={`Mức ${level}`}
            disabled={!editable}
            onClick={() => onChange(pickLevel(cell, level))}
          >
            {level}
          </Button>
        ))}
        <Button
          size="sm"
          variant={cell.state === 'CHUA_DU_CAN_CU' ? 'primary' : 'secondary'}
          className="h-11"
          aria-pressed={cell.state === 'CHUA_DU_CAN_CU'}
          disabled={!editable}
          onClick={() => onChange(pickInsufficient(cell))}
        >
          Chưa đủ căn cứ
        </Button>
        {cell.state !== 'CHUA_DANH_GIA' && (
          <Button
            size="sm"
            variant="text"
            className="h-11"
            disabled={!editable}
            onClick={() => onChange(clearCell())}
          >
            Chấm lại ô này
          </Button>
        )}
      </div>
      <p
        className={cn('text-caption', cell.state === 'CHUA_DANH_GIA' ? 'text-fg-muted' : 'text-fg')}
      >
        {cell.state === 'DA_DANH_GIA'
          ? `Đã đánh giá · Mức ${cell.score}${levelText ? ` · ${levelText}` : ''}`
          : cell.state === 'CHUA_DU_CAN_CU'
            ? 'Chưa đủ căn cứ (không tính điểm)'
            : 'Chưa đánh giá (khác điểm 0)'}
      </p>
    </div>
  );
}

function CriteriaSwitches({
  criteria,
  draft,
  setDraft,
  editable,
}: {
  criteria: ReviewCriterion[];
  draft: ReviewDraft;
  setDraft: (next: ReviewDraft) => void;
  editable: boolean;
}) {
  const active = criteria.filter((c) => isEnabled(draft, c)).length;
  return (
    <section
      aria-labelledby="gv07-criteria"
      className="flex flex-col gap-2 rounded-lg border border-border p-3"
    >
      <div className="flex items-center justify-between gap-2">
        <h2 id="gv07-criteria" className="text-h4">
          Tiêu chí của buổi
        </h2>
        <span className="text-caption text-fg-muted">
          Đang áp dụng {active}/{criteria.length}
        </span>
      </div>
      <p className="text-caption text-fg-muted">
        Tắt tiêu chí nào thì cả lớp ghi Không áp dụng cho tiêu chí đó. Chỉ tắt khi buổi không có
        hoạt động cho tiêu chí; em làm không được thì chấm điểm thấp, không tắt. Phải còn ít nhất
        một tiêu chí.
      </p>
      <ul className="flex flex-col gap-1.5">
        {criteria.map((criterion) => {
          const on = isEnabled(draft, criterion);
          return (
            <li key={criterion.criterion_id} className="flex items-center justify-between gap-2">
              <span className="text-body">
                {criterion.name}{' '}
                <span className="text-caption text-fg-muted">
                  · {GROUP_LABEL[criterion.group_code] ?? criterion.group_code}
                </span>
              </span>
              <Button
                size="sm"
                variant={on ? 'secondary' : 'primary'}
                aria-pressed={!on}
                aria-label={`${on ? 'Đang áp dụng' : 'Không áp dụng cả buổi'}: ${on ? 'Tắt' : 'Bật'} tiêu chí ${criterion.name}`}
                disabled={!editable || (on && active <= 1)}
                onClick={() =>
                  setDraft({
                    ...draft,
                    enabled: { ...draft.enabled, [criterion.criterion_id]: !on },
                  })
                }
              >
                {on ? 'Đang áp dụng' : 'Không áp dụng cả buổi'}
              </Button>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
