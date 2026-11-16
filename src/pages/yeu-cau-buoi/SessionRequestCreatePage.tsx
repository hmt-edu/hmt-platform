// BUOI-08 Tạo yêu cầu buổi củng cố (khuôn K07 giản lược; canvas BUOI08_tao, R-BUOI-04, R-BUOI-10, R-CRM-19): bấm Tạo chỉ mở form trắng; Lưu nháp hoặc Gửi duyệt mới tạo
// bản ghi và cấp mã YB (app.save_session_request, app.submit_session_request). Cả lớp tham gia (buổi củng cố trừ giờ như buổi thường). Duyệt thì chèn buổi và dời nhãn bài
// các buổi sau (máy chủ). Chưa làm: ô chọn "Học sinh" riêng từng em và bảng xem trước dời nhãn bài của khung (lệch khung, ghi trong PR); không bắt ghi nhận phụ huynh đồng ý (R-BUOI-10).
// Điện thoại giữ bản chỉ đọc cho nút duyệt (R-HT-05) nhưng form tạo dùng được.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { TextAreaField, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useClassFormOptions } from '../lop/useClassData';
import type { ClassPage } from '../lop/classTypes';
import { validateDraft, type DraftError } from './requestLogic';
import { useSaveRequest } from './useRequestData';

const CLASS_LIMIT = 100; // allow-number: trần số lớp liệt kê trong ô chọn (tối đa 100 một lần gọi, quy ước phân trang)

export function SessionRequestCreatePage() {
  const supabase = useDb();
  const navigate = useNavigate();
  const toast = useToast();
  const save = useSaveRequest();
  const [classId, setClassId] = useState('');
  const [search, setSearch] = useState('');
  const [date, setDate] = useState('');
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [roomId, setRoomId] = useState('');
  const [note, setNote] = useState('');
  const [errors, setErrors] = useState<DraftError>({});
  const [error, setError] = useState<string | null>(null);
  // Chỉ lớp đã duyệt mới chèn thêm buổi (R-BUOI-04): lọc ở máy chủ.
  const classes = useQuery({
    queryKey: ['request-classes', search],
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ClassPage>(supabase, 'list_classes', {
        p_filters:
          search.trim() === ''
            ? { status: ['DA_DUYET'] }
            : { status: ['DA_DUYET'], search: search.trim() },
        p_sort: 'code_desc',
        p_limit: CLASS_LIMIT,
        p_offset: 0,
      }),
  });
  const chosen = classes.data?.rows.find((c) => c.id === classId);
  const options = useClassFormOptions(chosen?.branch_id ?? '');

  async function submit(send: boolean) {
    const found = validateDraft({ classId, date, start, end });
    setErrors(found);
    setError(null);
    if (Object.keys(found).length > 0) return;
    try {
      const saved = await save.mutateAsync({
        id: null,
        classId,
        date,
        start,
        end,
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

  if (classes.isPending && classes.data === undefined) return <Spinner />;
  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4">
      <h1 className="text-h2">Tạo yêu cầu buổi củng cố</h1>
      <p className="text-body text-fg-muted">
        Chưa lưu: yêu cầu chưa có mã. Bấm Lưu nháp hoặc Gửi duyệt để tạo. Buổi củng cố tính tiền như
        buổi thường (trừ giờ) nên cần Trưởng cơ sở duyệt; duyệt thì chèn buổi vào lịch của lớp và
        dời nhãn bài các buổi sau (R-BUOI-04).
      </p>
      {error !== null && (
        <Alert tone="danger" title="Chưa lưu được.">
          {error}
        </Alert>
      )}
      {classes.isError && <Alert tone="danger">{errorOf(classes.error).message}</Alert>}
      <TextField
        label="Tìm lớp"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        help="Gõ mã lớp hoặc tên môn để thu hẹp danh sách (lớp đã duyệt, mới nhất trước)."
      />
      <OptionalSelect
        label="Lớp"
        value={classId}
        onChange={(v) => {
          setClassId(v);
          setRoomId('');
        }}
        options={(classes.data?.rows ?? []).map((c) => ({
          value: c.id,
          label: `${c.subject_name ?? c.subject_code} · ${c.code}`,
        }))}
        placeholder="Chọn lớp"
        invalid={errors.class !== undefined}
      />
      {errors.class && <p className="text-caption text-danger-text">{errors.class}</p>}
      <p className="text-body">
        Học sinh: <b>cả lớp</b>
        {chosen ? ` (${chosen.enrolled} em đang học)` : ''}
      </p>
      <TextField
        label="Ngày buổi củng cố"
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
        label="Phòng"
        value={roomId}
        onChange={setRoomId}
        options={(options.data?.rooms ?? []).map((r) => ({ value: r.id, label: r.name }))}
        placeholder="Chưa chọn phòng"
        disabled={chosen === undefined}
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
        <Button variant="text" onClick={() => void navigate('/crm/yeu-cau-buoi')}>
          Huỷ
        </Button>
      </div>
    </div>
  );
}
