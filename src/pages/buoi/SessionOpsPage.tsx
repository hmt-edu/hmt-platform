// BUOI-03 Điểm danh trong ngày (biểu mẫu K12, đường dẫn /crm/diem-danh/buoi/:id): vận hành ghi trạng thái trung tâm, lý do liên hệ và ghi chú cho từng em; cột giáo viên
// chỉ đọc (R-DD-02, R-DD-03). Không tự lưu: bấm Lưu mới ghi (app.set_attendance_ops). Buổi Nháp: chưa có danh sách (R-GIO-08). Buổi Done: chỉ xem; sửa sau Done ở BUOI-14 (cụm sau).
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { UnsavedGuard } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Field } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import {
  buildOpsEntries,
  cellOf,
  countOpsMarked,
  missingNote,
  patchDraft,
  type OpsDraft,
} from './opsLogic';
import { classLabel, sessionNoLabel } from './sessionLogic';
import { useOpsSheet, useSaveOps } from './useSessionData';

export function SessionOpsPage() {
  const { id } = useParams();
  const query = useOpsSheet(id);
  const save = useSaveOps(id ?? '');
  const toast = useToast();
  const [draft, setDraft] = useState<OpsDraft>({});
  const [error, setError] = useState<string | null>(null);
  const s = query.data?.session;
  useCrumbTail(s ? `Điểm danh trong ngày · ${classLabel(s.subject_name, s.class_code)}` : null);

  if (query.isPending) return <Spinner />;
  if (query.isError || !query.data) {
    const err = errorOf(query.error);
    const forbidden = err.code === 'HMT_KHONG_CO_QUYEN';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : 'not-found'}
        title={
          forbidden ? 'Bạn không có quyền ghi điểm danh trong ngày' : 'Không tìm thấy buổi học'
        }
      >
        {forbidden
          ? 'Chỉ CSKH và Admin ghi điểm danh phía vận hành. Giáo viên điểm danh ở cổng giáo viên. Nếu cần, hãy liên hệ quản trị viên của trung tâm.'
          : err.message}
      </StateView>
    );
  }
  const sheet = query.data;
  const sess = sheet.session;
  const done = sess.status_code === 'DONE';
  const dirty = Object.keys(draft).length > 0;
  const noteMissing = missingNote(sheet, draft);
  const total = sheet.students.length;

  async function doSave() {
    setError(null);
    try {
      await save.mutateAsync(buildOpsEntries(sheet.students, draft));
      setDraft({});
      toast({ tone: 'success', title: 'Đã lưu điểm danh vận hành' });
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <UnsavedGuard
        when={dirty}
        title="Chưa lưu thay đổi"
        description="Bạn đã sửa nhưng chưa bấm Lưu. Rời màn bây giờ thì các thay đổi này mất."
        stayLabel="Ở lại để lưu"
        leaveLabel="Rời đi, bỏ thay đổi"
      />
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="text-title font-semibold">
          Điểm danh trong ngày · {classLabel(sess.subject_name, sess.class_code)} ·{' '}
          {sessionNoLabel(sess.session_no)} · {formatDate(sess.session_date)}
        </h2>
        {sheet.listed && (
          <Tag tone="neutral">
            Đã ghi {countOpsMarked(sheet.students, draft)}/{total} học sinh
          </Tag>
        )}
        {dirty && <Tag tone="warning">Chưa lưu</Tag>}
        {!done && sheet.listed && (
          <Button
            variant="primary"
            loading={save.isPending}
            disabled={!dirty || save.isPending || noteMissing.length > 0}
            onClick={() => void doSave()}
          >
            Lưu
          </Button>
        )}
        <Link to={`/crm/buoi-hoc/${sess.id}`} className="focus-ring text-link hover:underline">
          Về bản ghi buổi
        </Link>
      </div>

      {!sheet.listed && (
        <StateView kind="empty" title="Buổi chưa chốt danh sách">
          Buổi đang ở Nháp nên chưa có dòng điểm danh. Dòng điểm danh sinh khi buổi chuyển sang Đã
          chốt. Hệ thống tự chốt trước giờ bắt đầu; bấm Chốt danh sách ở bản ghi buổi để chốt ngay.
        </StateView>
      )}
      {done && (
        <Alert tone="info">
          Buổi đã Hoàn thành, đã trừ giờ: điểm danh trong ngày chỉ còn xem. Sai thì Trưởng cơ sở sửa
          kèm lý do ở bản ghi buổi.
        </Alert>
      )}
      {sheet.listed && !done && (
        <p className="text-caption text-fg-muted">
          Mỗi học sinh một thẻ. Chưa chọn nghĩa là chưa làm. Ô Giáo viên (chính thức) chỉ đọc.
        </p>
      )}
      {sheet.listed && (
        <ul className="flex flex-col gap-2" aria-label="Danh sách học sinh">
          {sheet.students.map((st) => {
            const c = cellOf(st, draft);
            const teacher = sheet.statuses.find((x) => x.code === st.teacher_status_code)?.name;
            const mismatch =
              st.teacher_status_code !== null &&
              c.status !== null &&
              c.status !== st.teacher_status_code;
            return (
              <li
                key={st.student_id}
                className="grid gap-3 rounded-control border border-border bg-surface p-3 lg:grid-cols-[14rem_1fr_1fr_1fr_1fr] lg:items-end"
              >
                <div>
                  <p className="font-semibold">{st.full_name}</p>
                  <p className="text-caption text-fg-muted">{st.student_code}</p>
                </div>
                <OptionalSelect
                  label={`Trung tâm điểm danh · ${st.full_name}`}
                  value={c.status ?? ''}
                  onChange={(v) =>
                    setDraft((d) => patchDraft(d, st, { status: v === '' ? null : v }))
                  }
                  options={sheet.statuses.map((x) => ({ value: x.code, label: x.name }))}
                  placeholder="Chưa điểm danh"
                  disabled={done}
                />
                <p className="text-body">
                  <span className="block text-caption text-fg-muted">Giáo viên (chính thức)</span>
                  {teacher ?? <span className="text-fg-muted">—</span>}{' '}
                  {mismatch && <Tag tone="warning">Lệch</Tag>}
                </p>
                <OptionalSelect
                  label={`Lý do liên hệ · ${st.full_name}`}
                  value={c.reason ?? ''}
                  onChange={(v) =>
                    setDraft((d) => patchDraft(d, st, { reason: v === '' ? null : v }))
                  }
                  options={sheet.reasons.map((x) => ({ value: x.code, label: x.name }))}
                  placeholder="Chọn lý do…"
                  disabled={done}
                />
                <Field label={`Ghi chú · ${st.full_name}`}>
                  {(field) => (
                    <input
                      {...field}
                      value={c.note}
                      disabled={done}
                      onChange={(e) => setDraft((d) => patchDraft(d, st, { note: e.target.value }))}
                      className="focus-ring h-control w-full rounded-control border border-border bg-surface px-2.5 text-body"
                    />
                  )}
                </Field>
              </li>
            );
          })}
        </ul>
      )}
      {noteMissing.length > 0 && (
        <Alert tone="warning">Lý do liên hệ "Khác" cần ghi chú: {noteMissing.join(', ')}.</Alert>
      )}
      {error && <Alert tone="danger">{error}</Alert>}
      <p className="text-caption text-fg-muted">
        Cột Giáo viên (chính thức) chỉ đọc: ô của giáo viên quyết định trạng thái chính thức. Lý do
        liên hệ ghi được cho mọi trạng thái. Học sinh chưa chọn nghĩa là chưa làm.
      </p>
    </div>
  );
}
