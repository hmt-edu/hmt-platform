// BUOI-07 Tạo yêu cầu học bù (khuôn K07 giản lược). Luật R-BUOI-03 thắng canvas BUOI07: duyệt thì SINH BUỔI MỚI loại Học bù, không chọn buổi có sẵn của lớp khác.
// Tạo từ lớp (?lop=): chọn các em học bù, ngày, giờ, giáo viên (tuỳ chọn; bỏ trống thì lấy giáo viên khung giờ của lớp), phòng, LÝ DO bắt buộc.
// Không trừ giờ, không gắn buổi gốc. Lưu nháp hoặc Gửi duyệt mới cấp mã YB (app.save_makeup_request); quản lý cơ sở duyệt (R-BUOI-10).
import { useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextAreaField, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useClassFormOptions, useClassRecord } from '../lop/useClassData';
import { validateMakeup, type MakeupError } from './requestLogic';
import { useSaveMakeup } from './useRequestData';
import { ExamBlock } from './ExamBlock';
import { EMPTY_EXAM, validateExam, type ExamError, type ExamInput } from './examFields';

export function SessionRequestMakeupPage() {
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
        Yêu cầu học bù tạo từ bản ghi lớp: mở lớp rồi chọn Yêu cầu học bù ở menu Hành động.
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
        Chỉ lớp đã duyệt mới có yêu cầu học bù.
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
  students: { student_id: string; full_name: string }[];
}) {
  const navigate = useNavigate();
  const toast = useToast();
  const save = useSaveMakeup();
  const options = useClassFormOptions(branchId);
  const [picked, setPicked] = useState<string[]>([]);
  const [date, setDate] = useState('');
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [teacherId, setTeacherId] = useState('');
  const [roomId, setRoomId] = useState('');
  const [reason, setReason] = useState('');
  const [errors, setErrors] = useState<MakeupError>({});
  const [error, setError] = useState<string | null>(null);
  const [examOn, setExamOn] = useState(false);
  const [exam, setExam] = useState<ExamInput>(EMPTY_EXAM);
  const [examErrors, setExamErrors] = useState<ExamError>({});
  const toggle = (id: string) =>
    setPicked((cur) => (cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id]));

  async function submit(send: boolean) {
    const found = validateMakeup({ studentIds: picked, date, start, end, reason });
    setErrors(found);
    setError(null);
    const examFound = examOn ? validateExam(exam) : {};
    setExamErrors(examFound);
    if (Object.keys(found).length > 0 || Object.keys(examFound).length > 0) return;
    try {
      const saved = await save.mutateAsync({
        exam: examOn ? exam : null,
        classId,
        studentIds: picked,
        date,
        start,
        end,
        teacherId: teacherId === '' ? null : teacherId,
        roomId: roomId === '' ? null : roomId,
        reason: reason.trim(),
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
      <h1 className="text-h2">Tạo yêu cầu học bù</h1>
      <p className="text-body text-fg-muted">
        Lớp <b>{title}</b> (tạo từ lớp, không chọn lại). Học bù không trừ giờ của học sinh, không
        gắn với buổi gốc; Trưởng cơ sở duyệt thì hệ thống sinh buổi mới (R-BUOI-03). Chưa lưu: yêu
        cầu chưa có mã.
      </p>
      {error !== null && (
        <Alert tone="danger" title="Chưa lưu được.">
          {error}
        </Alert>
      )}
      <fieldset className="flex flex-col gap-1" aria-label="Em học bù">
        <legend className="text-body font-semibold">Em học bù *</legend>
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
              <span>{s.full_name}</span>
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
        label="Giáo viên (không bắt buộc)"
        value={teacherId}
        onChange={setTeacherId}
        options={(options.data?.teachers ?? []).map((u) => ({
          value: u.id,
          label: u.staff_code ? `${u.name} (${u.staff_code})` : u.name,
        }))}
        placeholder="Theo khung giờ của lớp"
      />
      <OptionalSelect
        label="Phòng"
        value={roomId}
        onChange={setRoomId}
        options={(options.data?.rooms ?? []).map((r) => ({ value: r.id, label: r.name }))}
        placeholder="Chưa chọn phòng"
      />
      <TextAreaField
        label="Lý do học bù"
        required
        value={reason}
        error={errors.reason}
        onChange={(e) => setReason(e.target.value)}
      />
      <ExamBlock
        kind="HOC_BU"
        enabled={examOn}
        onEnabled={setExamOn}
        value={exam}
        onChange={setExam}
        errors={examErrors}
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
