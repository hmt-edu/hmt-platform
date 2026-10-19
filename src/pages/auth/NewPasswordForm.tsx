import { useState, type FormEvent } from 'react';
import {
  checkPassword,
  type PasswordPolicy,
} from '../../../supabase/functions/_shared/login-rules.ts';
import { useAuth } from '../../lib/auth/authContext';
import { usePasswordPolicy } from '../../lib/auth/usePasswordPolicy';
import { Button } from '../../ui/Button';
import { Icon } from '../../ui/icons';
import { cn } from '../../ui/cn';
import { AuthAlert, AuthNote } from './authParts';
import { PasswordInput } from '../../ui/Field';

/** Tên đăng nhập để trình quản lý mật khẩu lưu đúng tài khoản: học sinh là mã HS, còn lại là email. */
function loginNameOf(email: string | undefined): string {
  if (!email) return '';
  const [local = '', domain = ''] = email.split('@');
  return domain.startsWith('hocsinh.') ? local.toUpperCase() : email;
}

/** Các điều kiện hiện thành danh sách có dấu tích (DN07); số ký tối thiểu lấy từ luật mật khẩu trong Cài đặt. */
function passwordRules(password: string, policy: PasswordPolicy) {
  const rules = [
    { label: `Tối thiểu ${policy.minLength} ký tự`, ok: password.length >= policy.minLength },
  ];
  if (policy.requireLetterDigit)
    rules.push(
      { label: 'Có chữ cái', ok: /\p{L}/u.test(password) },
      { label: 'Có chữ số', ok: /\d/.test(password) },
    );
  return rules;
}

/**
 * Ô đặt mật khẩu mới (dùng cho đổi lần đầu, đặt lại từ email, đổi trong hồ sơ cá nhân).
 * `afterAuthUpdate`: việc phải làm thêm sau khi Supabase Auth nhận mật khẩu mới.
 */
export function NewPasswordForm({
  submitLabel,
  footnote,
  disableUntilFilled = false,
  afterAuthUpdate,
  onDone,
}: {
  submitLabel: string;
  /** Dòng chú nhỏ dưới nút (DN07). */
  footnote?: string;
  /** Nút mờ cho tới khi cả hai ô đã nhập (DN07, đổi mật khẩu lần đầu). */
  disableUntilFilled?: boolean;
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
    <form onSubmit={(e) => void submit(e)} noValidate className="flex flex-col gap-[18px]">
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
        size="lg"
        label="Mật khẩu mới"
        placeholder="Gõ thử để xem kiểm tra"
        name="new-password"
        autoComplete="new-password"
        required
        error={fieldError.password}
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      {policy && (
        <ul className="-my-1 flex flex-col gap-1.5 text-[13px]" aria-label="Điều kiện mật khẩu">
          {passwordRules(password, policy).map((rule) => (
            <li
              key={rule.label}
              className={cn(
                'flex items-center gap-2',
                rule.ok ? 'font-medium text-on-success-subtle' : 'text-fg-muted',
              )}
            >
              <span
                aria-hidden="true"
                className={cn(
                  'flex size-4 shrink-0 items-center justify-center rounded-full border-[1.5px]',
                  rule.ok
                    ? 'border-success-solid bg-success-solid text-on-solid'
                    : 'border-border-strong',
                )}
              >
                {rule.ok && <Icon name="check" size={16} />}
              </span>
              {rule.label}
              <span className="sr-only">{rule.ok ? ' (đạt)' : ' (chưa đạt)'}</span>
            </li>
          ))}
        </ul>
      )}
      <PasswordInput
        size="lg"
        label="Nhập lại mật khẩu mới"
        name="confirm-password"
        autoComplete="new-password"
        required
        error={fieldError.confirm}
        value={confirm}
        onChange={(e) => setConfirm(e.target.value)}
      />
      {error && <AuthAlert tone="danger">{error}</AuthAlert>}
      <Button
        type="submit"
        variant="primary"
        size="xl"
        fullWidth
        loading={busy}
        disabled={!policy || (disableUntilFilled && (password === '' || confirm === ''))}
      >
        {submitLabel}
      </Button>
      {footnote && <AuthNote>{footnote}</AuthNote>}
    </form>
  );
}
