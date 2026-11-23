import { useState, type FormEvent } from 'react';
import {
  checkPassword,
  type PasswordPolicy,
} from '../../../supabase/functions/_shared/login-rules.ts';
import { useAuth } from '../../lib/auth/authContext';
import { usePasswordPolicyState } from '../../lib/auth/usePasswordPolicy';
import { verifyCurrentPassword } from '../../lib/auth/verifyCurrentPassword';
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
  askCurrent = false,
  afterAuthUpdate,
  onDone,
}: {
  submitLabel: string;
  /** Dòng chú nhỏ dưới nút (DN07). */
  footnote?: string;
  /** Nút mờ cho tới khi cả hai ô đã nhập (DN07, đổi mật khẩu lần đầu). */
  disableUntilFilled?: boolean;
  /** Hỏi mật khẩu hiện tại và kiểm trước khi đổi (đổi trong hồ sơ cá nhân, S8). Đổi lần đầu và đặt lại từ email không hỏi. */
  askCurrent?: boolean;
  afterAuthUpdate?: () => Promise<string | null>;
  onDone: () => void;
}) {
  const { supabase, session, refresh } = useAuth();
  const {
    policy,
    failed: policyFailed,
    loading: policyLoading,
    retry: retryPolicy,
  } = usePasswordPolicyState();
  const [current, setCurrent] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [fieldError, setFieldError] = useState<{
    current: string | undefined;
    password: string | undefined;
    confirm: string | undefined;
  }>({
    current: undefined,
    password: undefined,
    confirm: undefined,
  });
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!supabase) return;
    // Luật mật khẩu chưa có (đang tải hoặc lỗi): báo bằng chữ, không được im lặng (Soát S16).
    if (!policy) {
      return setError(
        policyFailed
          ? 'Không tải được luật mật khẩu. Kiểm tra mạng rồi bấm «Tải lại luật mật khẩu».'
          : 'Đang tải luật mật khẩu, chờ một chút rồi bấm lại.',
      );
    }
    const problems = {
      current: askCurrent && current === '' ? 'Nhập mật khẩu hiện tại.' : undefined,
      password: checkPassword(password, policy) ?? undefined,
      confirm: password === confirm ? undefined : 'Hai lần nhập mật khẩu không khớp.',
    };
    setFieldError(problems);
    if (problems.current || problems.password || problems.confirm) return;
    setBusy(true);
    setError(null);
    // S8: kiểm mật khẩu hiện tại trước khi đổi; không kiểm được thì không đổi.
    if (askCurrent) {
      const email = session?.user.email ?? '';
      const verdict = await verifyCurrentPassword(email, current);
      if (verdict !== 'ok') {
        setBusy(false);
        if (verdict === 'wrong') {
          setFieldError({ ...problems, current: 'Mật khẩu hiện tại không đúng.' });
          return;
        }
        return setError('Chưa kiểm tra được mật khẩu hiện tại. Kiểm tra mạng rồi thử lại.');
      }
    }
    const { error: authError } = await supabase.auth.updateUser({ password });
    if (authError) {
      setBusy(false);
      return setError('Không đổi được mật khẩu. Mật khẩu mới phải khác mật khẩu cũ.');
    }
    const problem = afterAuthUpdate ? await afterAuthUpdate() : null;
    await refresh();
    setBusy(false);
    if (problem) return setError(problem);
    setCurrent('');
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
      {askCurrent && (
        <PasswordInput
          size="lg"
          label="Mật khẩu hiện tại"
          name="current-password"
          autoComplete="current-password"
          required
          error={fieldError.current}
          value={current}
          onChange={(e) => setCurrent(e.target.value)}
        />
      )}
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
      {policyFailed && !policy && (
        <AuthAlert tone="danger">
          Không tải được luật mật khẩu. Kiểm tra mạng rồi thử lại.
          <Button type="button" size="sm" onClick={retryPolicy}>
            Tải lại luật mật khẩu
          </Button>
        </AuthAlert>
      )}
      {policyLoading && !policy && !policyFailed && (
        <p className="text-[13px] text-fg-muted" role="status">
          Đang tải luật mật khẩu…
        </p>
      )}
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
