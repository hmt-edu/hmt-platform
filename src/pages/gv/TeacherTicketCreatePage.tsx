// GV-14 Tạo ticket (cổng giáo viên, biểu mẫu K07, ưu tiên điện thoại): Nhóm, Nhóm con, Tính chất (chỉ đọc, tự gắn theo nhóm con), Lớp, Học sinh (bắt buộc theo nhóm con),
// Tiêu đề, Mô tả. Ô Ảnh «Làm sau» (Q-233): chưa tải ảnh. Không tự lưu: bấm Tạo mới gửi (app.teacher_create_ticket); chỉ tạo cho lớp mình (R-CS-10).
// Chưa làm: hộp «Chưa lưu thay đổi» khi rời màn (canvas GV14); ghi vào PR.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextAreaField, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import {
  groupsOf,
  natureText,
  validateTicket,
  type FormError,
  type TicketOptions,
} from './ticketLogic';

export function TeacherTicketCreatePage() {
  const supabase = useDb();
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();
  const options = useQuery({
    queryKey: ['gv-ticket-options'],
    retry: false,
    queryFn: () => rpc<TicketOptions>(supabase, 'teacher_ticket_options'),
  });
  const [groupCode, setGroupCode] = useState('');
  const [categoryCode, setCategoryCode] = useState('');
  const [classId, setClassId] = useState('');
  const [studentId, setStudentId] = useState('');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [errors, setErrors] = useState<FormError>({});
  const [error, setError] = useState<string | null>(null);
  const create = useMutation({
    mutationFn: (data: Record<string, string>) =>
      rpc<{ id: string; code: string }>(supabase, 'teacher_create_ticket', { p_data: data }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ['gv-tickets'] }),
  });
  const back = (
    <Link className="text-link underline" to="/gv/ticket">
      Về ticket
    </Link>
  );
  if (options.isPending) return <Spinner />;
  if (options.isError)
    return errorOf(options.error).code === 'HMT_TINH_NANG_TAT' ? (
      <StateView kind="forbidden" title="Phân hệ chưa bật" actions={back}>
        {errorOf(options.error).message}
      </StateView>
    ) : (
      <StateView kind="error" title="Không tải được form" actions={back}>
        {errorOf(options.error).message}
      </StateView>
    );
  const { categories, classes } = options.data;
  const groups = groupsOf(categories);
  const subgroups = categories.filter((c) => c.group_code === groupCode);
  const category = categories.find((c) => c.code === categoryCode);
  const students = classes.find((k) => k.id === classId)?.students ?? [];

  async function submit() {
    const found = validateTicket({ groupCode, category, classId, studentId, title, description });
    setErrors(found);
    setError(null);
    if (Object.keys(found).length > 0 || category === undefined) return;
    try {
      const saved = await create.mutateAsync({
        category_code: category.code,
        class_id: classId,
        student_id: studentId,
        title: title.trim(),
        description: description.trim(),
      });
      toast({ tone: 'success', title: `Đã tạo ticket ${saved.code}` });
      void navigate('/gv/ticket', { replace: true });
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4 p-3">
      <p className="text-caption text-fg-muted">{back} › Tạo ticket</p>
      <h1 className="text-h2">Tạo ticket</h1>
      {error !== null && (
        <Alert tone="danger" title="Chưa tạo được.">
          {error}
        </Alert>
      )}
      <OptionalSelect
        label="Nhóm"
        value={groupCode}
        onChange={(v) => {
          setGroupCode(v);
          setCategoryCode('');
        }}
        options={groups.map((g) => ({ value: g.code, label: g.name }))}
        placeholder="Chọn nhóm"
        invalid={errors.group !== undefined}
      />
      {errors.group && <p className="text-caption text-danger-text">{errors.group}</p>}
      <OptionalSelect
        label="Nhóm con"
        value={categoryCode}
        onChange={setCategoryCode}
        options={subgroups.map((c) => ({ value: c.code, label: c.name }))}
        placeholder="Chọn nhóm con"
        invalid={errors.category !== undefined}
      />
      {errors.category && <p className="text-caption text-danger-text">{errors.category}</p>}
      <div>
        <p className="text-body font-semibold">Tính chất</p>
        <p className="text-body" data-testid="tinh-chat">
          {natureText(category?.nature_code)}
        </p>
        <p className="text-caption text-fg-muted">Tự gắn theo nhóm con, giáo viên không chọn.</p>
      </div>
      <OptionalSelect
        label="Lớp"
        value={classId}
        onChange={(v) => {
          setClassId(v);
          setStudentId('');
        }}
        options={classes.map((k) => ({
          value: k.id,
          label: k.subject_name ? `${k.subject_name} · ${k.code}` : k.code,
        }))}
        placeholder="Chọn lớp"
        invalid={errors.class !== undefined}
      />
      {errors.class && <p className="text-caption text-danger-text">{errors.class}</p>}
      <OptionalSelect
        label="Học sinh"
        value={studentId}
        onChange={setStudentId}
        options={students.map((s) => ({ value: s.id, label: s.name }))}
        placeholder={classId === '' ? 'Chọn lớp trước' : 'Chọn học sinh'}
        invalid={errors.student !== undefined}
      />
      {errors.student && <p className="text-caption text-danger-text">{errors.student}</p>}
      <TextField
        label="Tiêu đề"
        required
        value={title}
        error={errors.title}
        onChange={(e) => setTitle(e.target.value)}
      />
      <TextAreaField
        label="Mô tả"
        required
        value={description}
        error={errors.description}
        onChange={(e) => setDescription(e.target.value)}
      />
      <div>
        <p className="text-body font-semibold">Ảnh</p>
        <p className="text-caption text-fg-muted">
          Làm sau: bản 17/11 chưa tải ảnh, ticket chỉ gõ chữ.
        </p>
        <Button disabled>Chọn ảnh</Button>
      </div>
      <div className="flex flex-wrap gap-2">
        <Button variant="primary" loading={create.isPending} onClick={() => void submit()}>
          Tạo ticket
        </Button>
        <Button variant="text" onClick={() => void navigate('/gv/ticket')}>
          Huỷ
        </Button>
      </div>
    </div>
  );
}
