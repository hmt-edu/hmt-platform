import { useState, type FormEvent } from 'react';
import { checkPassword } from '../../../supabase/functions/_shared/login-rules.ts';
import { useAuth } from '../../lib/auth/authContext';
import { policyHint, usePasswordPolicy } from '../../lib/auth/usePasswordPolicy';
import { Button } from '../../ui/Button';
import { Alert } from '../../ui/Feedback';
import { PasswordInput } from '../../ui/Field';

/** Tên đăng nhập để trình quản lý mật khẩu lưu đúng tài khoản: học sinh là mã HS, còn lại là email. */
function loginNameOf(email: string | undefined): string {
  if (!email) return '';
  const [local = '', domain = ''] = email.split('@');
  return domain.startsWith('hocsinh.') ? local.toUpperCase() : email;
}

/**
 * Ô đặt mật khẩu mới (dùng cho đổi lần đầu, đặt lại từ email, đổi trong hồ sơ cá nhân).
 * `afterAuthUpdate`: việc phải làm thêm sau khi Supabase Auth nhận mật khẩu mới.
 */
export function NewPasswordForm({
  submitLabel,
  afterAuthUpdate,
  onDone,
}: {
  submitLabel: string;
  afterAuthUpdate?: () => Promise<string | null>;
  onDone: () => void;
}) {
  const { supabase, session, refresh } = useAuth();
  const policy = usePasswordPolicy();
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [fieldError, setFieldError] = useState<{
    password: string | undefined;
    confirm: string | undefined;
  }>({
    password: undefined,
    confirm: undefined,
  });
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!supabase || !policy) return;
    const problems = {
      password: checkPassword(password, policy) ?? undefined,
      confirm: password === confirm ? undefined : 'Hai lần nhập mật khẩu không khớp.',
    };
    setFieldError(problems);
    if (problems.password || problems.confirm) return;
    setBusy(true);
    setError(null);
    const { error: authError } = await supabase.auth.updateUser({ password });
    if (authError) {
      setBusy(false);
      return setError('Không đổi được mật khẩu. Mật khẩu mới phải khác mật khẩu cũ.');
    }
    const problem = afterAuthUpdate ? await afterAuthUpdate() : null;
    await refresh();
    setBusy(false);
    if (problem) return setError(problem);
    setPassword('');
    setConfirm('');
    onDone();
  }

  return (
    <form onSubmit={(e) => void submit(e)} noValidate className="flex flex-col gap-4">
      {/* Ô tên đăng nhập ẩn: để Chrome, ứng dụng Mật khẩu gắn mật khẩu mới vào đúng tài khoản. */}
      <input
        type="text"
        name="username"
        autoComplete="username"
        value={loginNameOf(session?.user.email)}
        readOnly
        tabIndex={-1}
        aria-hidden="true"
        className="sr-only"
      />
      <PasswordInput
        label="Mật khẩu mới"
        name="new-password"
        autoComplete="new-password"
        required
        help={policyHint(policy)}
        error={fieldError.password}
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      <PasswordInput
        label="Nhập lại mật khẩu mới"
        name="confirm-password"
        autoComplete="new-password"
        required
        error={fieldError.confirm}
        value={confirm}
        onChange={(e) => setConfirm(e.target.value)}
      />
      {error && <Alert tone="danger">{error}</Alert>}
      <Button type="submit" variant="primary" fullWidth loading={busy} disabled={!policy}>
        {submitLabel}
      </Button>
    </form>
  );
}
