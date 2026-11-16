// BUOI-09 Tạo yêu cầu học bổ trợ (khuôn K07 giản lược; canvas BUOI09_tao, R-BUOI-05, R-BUOI-10): TẠO TỪ LỚP, không chọn lại lớp (mở từ menu Hành động của bản ghi lớp, ?lop=). Chọn các
// em yếu cần kèm thêm (kèm giờ còn lại), ngày, giờ, giáo viên, phòng. Học bổ trợ không trừ giờ học sinh nhưng vẫn tính vào giờ dạy của giáo viên (căn cứ lương). Lưu nháp hoặc Gửi duyệt
// mới tạo bản ghi và cấp mã YB (app.save_support_request). Quản lý cơ sở duyệt. Chưa làm: gợi ý em yếu theo điểm (chọn tay).
import { useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { errorOf } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextAreaField, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useClassFormOptions, useClassRecord } from '../lop/useClassData';
import { validateSupport, type SupportError } from './requestLogic';
import { useSaveSupport } from './useRequestData';

export function SessionRequestSupportPage() {
  const [params] = useSearchParams();
  const classId = params.get('lop') ?? undefined;
  const record = useClassRecord(classId);
  const back = (
    <Link className="text-link underline" to={classId ? `/crm/lop/${classId}` : '/crm/lop'}>
      Về lớp
    </Link>
  );
  if (classId === undefined)
    return (
      <StateView kind="not-found" title="Chưa chọn lớp" actions={back}>
        Yêu cầu học bổ trợ tạo từ bản ghi lớp: mở lớp rồi chọn Yêu cầu bổ trợ ở menu Hành động.
      </StateView>
    );
  if (record.isPending) return <Spinner />;
  if (record.isError)
    return (
      <StateView kind="error" title="Không tải được lớp" actions={back}>
        {errorOf(record.error).message}
      </StateView>
    );
  if (record.data.status_code !== 'DA_DUYET')
    return (
      <StateView kind="forbidden" title="Lớp chưa ở tình trạng đã duyệt" actions={back}>
        Chỉ lớp đã duyệt mới có yêu cầu học bổ trợ.
      </StateView>
    );
  return (
    <Form
      classId={record.data.id}
      branchId={record.data.branch_id}
      title={`${record.data.subject_name ?? record.data.subject_code} · ${record.data.code}`}
      students={record.data.students}
    />
  );
}

function Form({
  classId,
  branchId,
  title,
  students,
}: {
  classId: string;
  branchId: string;
  title: string;
  students: { student_id: string; full_name: string; hours_left: number }[];
}) {
  const navigate = useNavigate();
  const toast = useToast();
  const save = useSaveSupport();
  const options = useClassFormOptions(branchId);
  const [picked, setPicked] = useState<string[]>([]);
  const [date, setDate] = useState('');
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [teacherId, setTeacherId] = useState('');
  const [roomId, setRoomId] = useState('');
  const [note, setNote] = useState('');
  const [errors, setErrors] = useState<SupportError>({});
  const [error, setError] = useState<string | null>(null);
  const toggle = (id: string) =>
    setPicked((cur) => (cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id]));

  async function submit(send: boolean) {
    const found = validateSupport({ studentIds: picked, date, start, end, teacherId });
    setErrors(found);
    setError(null);
    if (Object.keys(found).length > 0) return;
    try {
      const saved = await save.mutateAsync({
        classId,
        studentIds: picked,
        date,
        start,
        end,
        teacherId,
        roomId: roomId === '' ? null : roomId,
        note: note.trim() === '' ? null : note.trim(),
        submit: send,
      });
      toast({
        tone: 'success',
        title: send ? `Đã gửi duyệt ${saved.code}` : `Đã lưu nháp ${saved.code}`,
      });
      void navigate('/crm/yeu-cau-buoi', { replace: true });
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4">
      <h1 className="text-h2">Tạo yêu cầu học bổ trợ</h1>
      <p className="text-body text-fg-muted">
        Lớp <b>{title}</b> (tạo từ lớp, không chọn lại). Học bổ trợ không trừ giờ của học sinh nhưng
        vẫn tính vào giờ dạy của giáo viên; Trưởng cơ sở duyệt (R-BUOI-05). Chưa lưu: yêu cầu chưa
        có mã.
      </p>
      {error !== null && (
        <Alert tone="danger" title="Chưa lưu được.">
          {error}
        </Alert>
      )}
      <fieldset className="flex flex-col gap-1" aria-label="Em yếu cần bổ trợ">
        <legend className="text-body font-semibold">Em yếu cần bổ trợ *</legend>
        {students.length === 0 ? (
          <p className="text-body text-fg-muted">Lớp chưa có học sinh.</p>
        ) : (
          students.map((s) => (
            <label key={s.student_id} className="flex min-h-11 items-center gap-2">
              <input
                type="checkbox"
                checked={picked.includes(s.student_id)}
                onChange={() => toggle(s.student_id)}
              />
              <span>
                {s.full_name}{' '}
                <span className="text-caption text-fg-muted">
                  · còn {formatNumber(s.hours_left)} giờ
                </span>
              </span>
            </label>
          ))
        )}
        {errors.students && <p className="text-caption text-danger-text">{errors.students}</p>}
      </fieldset>
      <TextField
        label="Ngày"
        type="date"
        required
        value={date}
        error={errors.date}
        onChange={(e) => setDate(e.target.value)}
      />
      <div className="grid grid-cols-2 gap-3">
        <TextField
          label="Giờ bắt đầu"
          type="time"
          required
          value={start}
          error={errors.start}
          onChange={(e) => setStart(e.target.value)}
        />
        <TextField
          label="Giờ kết thúc"
          type="time"
          required
          value={end}
          error={errors.end}
          onChange={(e) => setEnd(e.target.value)}
        />
      </div>
      <OptionalSelect
        label="Giáo viên"
        value={teacherId}
        onChange={setTeacherId}
        options={(options.data?.teachers ?? []).map((u) => ({
          value: u.id,
          label: u.staff_code ? `${u.name} (${u.staff_code})` : u.name,
        }))}
        placeholder="Chọn giáo viên"
        invalid={errors.teacher !== undefined}
      />
      {errors.teacher && <p className="text-caption text-danger-text">{errors.teacher}</p>}
      <OptionalSelect
        label="Phòng"
        value={roomId}
        onChange={setRoomId}
        options={(options.data?.rooms ?? []).map((r) => ({ value: r.id, label: r.name }))}
        placeholder="Chưa chọn phòng"
      />
      <TextAreaField
        label="Ghi chú (không bắt buộc)"
        value={note}
        onChange={(e) => setNote(e.target.value)}
      />
      <div className="flex flex-wrap gap-2">
        <Button variant="primary" loading={save.isPending} onClick={() => void submit(true)}>
          Gửi duyệt
        </Button>
        <Button disabled={save.isPending} onClick={() => void submit(false)}>
          Lưu nháp
        </Button>
        <Button variant="text" onClick={() => void navigate(`/crm/lop/${classId}`)}>
          Huỷ
        </Button>
      </div>
    </div>
  );
}
