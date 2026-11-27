// CH-06 Khung chương trình, danh sách bài học (khuôn K10, canvas 1aab CH06_*; Admin sửa, người khác chỉ xem, máy tính).
// Luật R-LOP-07 (18/11/2026): chưa khoá sửa bài kể cả khi đã có lớp dùng; không xoá bài; mã bài cấp một lần, không đổi khi đổi thứ tự; tên bài dùng làm nhãn bài từng buổi.
// Khác khung: khung vẽ «kéo tay nắm để đổi thứ tự»; bản này đổi bằng nút Lên, Xuống (dùng được bằng bàn phím, không thêm thư viện), ghi vào PR. Nút «Nhập từ file» chỉ là nút mờ: khung chưa có hộp thoại (thiếu khuôn T5).
import { useCrumbTail } from '../../layout/CrumbTail';
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { errorOf, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { Spinner, StateView } from '../../ui/Feedback';
import { TextAreaField, TextField } from '../../ui/Field';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { useToast } from '../../ui/toastContext';
import { STATUS_NAME, yearLabel } from './frameLogic';
import { moveLesson, nextLessonCode, type Lesson } from './lessonLogic';
import { reorderLessons, saveLesson, useFrameDetail, useRefreshFrame } from './useFrameData';

export function LessonListPage() {
  const { id } = useParams();
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshFrame();
  const detail = useFrameDetail(id);
  useCrumbTail(detail.data?.frame.code ?? null);
  const [adding, setAdding] = useState(false);
  const [editing, setEditing] = useState<Lesson | null>(null);
  const [draft, setDraft] = useState({ title: '', hint: '' });
  const [busy, setBusy] = useState(false);
  const [rowError, setRowError] = useState<string | null>(null);
  const canView = access.can('CONFIG_TRAINING', 'XEM');
  const canEdit = access.can('CONFIG_TRAINING', 'SUA');

  if (!canView) {
    return (
      <div className="min-w-0">
        <StateView
          kind="forbidden"
          title="Bạn không có quyền xem màn này"
          actions={
            <Link className="text-link underline" to="/crm">
              Về Trang chủ
            </Link>
          }
        >
          Khung chương trình dành cho Admin và Trưởng cơ sở (chỉ xem). Liên hệ quản trị viên nếu bạn
          cần quyền.
        </StateView>
      </div>
    );
  }
  if (detail.isError) {
    return (
      <div className="min-w-0">
        <StateView
          kind="error"
          title="Không tải được khung chương trình"
          actions={<Button onClick={() => void detail.refetch()}>Thử lại</Button>}
        >
          {errorOf(detail.error).message}
        </StateView>
      </div>
    );
  }
  if (!detail.data) {
    return (
      <div className="p-6">
        <Spinner label="Đang tải bài học…" />
      </div>
    );
  }
  const { frame, lessons } = detail.data;

  async function move(index: number, delta: -1 | 1) {
    if (!id) return;
    setBusy(true);
    setRowError(null);
    try {
      await reorderLessons(supabase, id, moveLesson(lessons, index, delta));
      await refresh();
    } catch (e) {
      setRowError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  async function saveRow() {
    if (!id || !editing) return;
    setBusy(true);
    setRowError(null);
    try {
      await saveLesson(supabase, { frameId: id, lessonId: editing.id, ...draft });
      await refresh();
      setEditing(null);
      toast({ title: 'Đã lưu bài.' });
    } catch (e) {
      setRowError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  const columns: LineColumn<Lesson>[] = [
    { key: 'no', header: 'Bài số', width: 'w-24', cell: (l) => `Bài ${l.position}` },
    { key: 'code', header: 'Mã bài', cell: (l) => <span className="tabular">{l.code}</span> },
    {
      key: 'title',
      header: 'Tên bài',
      cell: (l) =>
        editing?.id === l.id ? (
          <TextField
            label="Tên bài"
            required
            value={draft.title}
            onChange={(e) => setDraft({ ...draft, title: e.target.value })}
          />
        ) : (
          l.title
        ),
    },
    {
      key: 'hint',
      header: 'Nội dung gợi ý',
      cell: (l) =>
        editing?.id === l.id ? (
          <TextField
            label="Nội dung gợi ý"
            value={draft.hint}
            onChange={(e) => setDraft({ ...draft, hint: e.target.value })}
          />
        ) : (
          (l.hint ?? '')
        ),
    },
    {
      key: 'actions',
      header: 'Thao tác',
      headerSrOnly: 'Thao tác',
      width: 'w-64',
      cell: (l, index) =>
        !canEdit ? null : editing?.id === l.id ? (
          <div className="flex gap-1">
            <Button variant="text" disabled={busy} onClick={() => setEditing(null)}>
              Huỷ
            </Button>
            <Button
              variant="primary"
              loading={busy}
              disabled={draft.title.trim() === ''}
              onClick={() => void saveRow()}
            >
              Lưu
            </Button>
          </div>
        ) : (
          <div className="flex gap-1">
            <Button
              variant="text"
              disabled={busy}
              onClick={() => {
                setEditing(l);
                setDraft({ title: l.title, hint: l.hint ?? '' });
                setRowError(null);
              }}
            >
              Sửa
            </Button>
            <Button
              variant="text"
              aria-label={`Đưa ${l.code} lên`}
              disabled={busy || index === 0}
              onClick={() => void move(index, -1)}
            >
              Lên
            </Button>
            <Button
              variant="text"
              aria-label={`Đưa ${l.code} xuống`}
              disabled={busy || index === lessons.length - 1}
              onClick={() => void move(index, 1)}
            >
              Xuống
            </Button>
          </div>
        ),
    },
  ];

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <nav aria-label="Đường dẫn" className="text-caption text-fg-muted">
        <Link className="underline" to="/crm/cau-hinh/khung-chuong-trinh">
          Khung chương trình
        </Link>
      </nav>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <h1 className="font-display text-h2 tabular">{frame.code}</h1>
          <Tag tone={frame.status_code === 'DANG_DUNG' ? 'success' : 'neutral'}>
            {STATUS_NAME[frame.status_code]}
          </Tag>
        </div>
        {canEdit && (
          <div className="flex gap-2">
            <Button disabled aria-describedby="nhap-file-ghi-chu">
              Nhập từ file
            </Button>
            <Button variant="primary" icon="plus" onClick={() => setAdding(true)}>
              Thêm bài
            </Button>
          </div>
        )}
      </div>
      <p className="text-body text-fg-muted">
        {frame.subject_name} · {frame.grade_name} · {frame.level_name} · Năm học{' '}
        {yearLabel(frame.year_code)} · {lessons.length} bài
      </p>
      {canEdit && (
        <p id="nhap-file-ghi-chu" className="sr-only">
          Nhập từ file chưa dùng được.
        </p>
      )}
      {!canEdit && (
        <p className="text-body text-fg-muted">Bạn chỉ xem được khung chương trình. Admin sửa.</p>
      )}
      {rowError !== null && (
        <p role="alert" className="text-body text-danger">
          {rowError}
        </p>
      )}
      <section
        aria-label="Danh sách bài học"
        className="min-w-0 rounded-box border border-border bg-surface"
      >
        <LineTable
          wrap
          caption={`Bài học của ${frame.code}`}
          columns={columns}
          rows={lessons}
          rowKey={(l) => l.id}
          rowLabel={(l) => l.title}
          empty={
            <div className="p-4">
              <StateView kind="empty" title="Khung này chưa có bài nào" headingLevel={2}>
                Thêm từng bài hoặc nhập từ file. Tên bài dùng làm nhãn bài cho từng buổi của lớp.
              </StateView>
            </div>
          }
        />
      </section>
      <p className="text-caption text-fg-muted">
        Đổi thứ tự bằng nút Lên, Xuống. Tên bài dùng làm nhãn bài cho từng buổi.
      </p>
      {adding && id && (
        <AddDialog
          frameId={id}
          frameCode={frame.code}
          lessons={lessons}
          onClose={() => setAdding(false)}
          onSaved={async () => {
            setAdding(false);
            await refresh();
            toast({ title: 'Đã thêm bài.' });
          }}
        />
      )}
    </div>
  );
}

function AddDialog({
  frameId,
  frameCode,
  lessons,
  onClose,
  onSaved,
}: {
  frameId: string;
  frameCode: string;
  lessons: Lesson[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const supabase = useDb();
  const [title, setTitle] = useState('');
  const [hint, setHint] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={`Thêm bài vào ${frameCode}`}
      confirmLabel="Thêm bài"
      canSubmit={title.trim() !== ''}
      busy={busy}
      error={error}
      onSubmit={() => {
        setBusy(true);
        setError(null);
        void saveLesson(supabase, { frameId, lessonId: null, title, hint })
          .then(() => onSaved())
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          <b>Bài {lessons.length + 1}</b> ·{' '}
          <span className="tabular">{nextLessonCode(frameCode, lessons)}</span>
        </p>
        <p className="text-caption text-fg-muted">
          Bài mới thêm vào cuối danh sách; đổi thứ tự bằng Lên, Xuống.
        </p>
        <TextField
          label="Tên bài"
          required
          placeholder="Nhập tên bài"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />
        <TextAreaField
          label="Nội dung gợi ý"
          placeholder="Không bắt buộc"
          value={hint}
          onChange={(e) => setHint(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}
