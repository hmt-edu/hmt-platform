import { useCallback, useState, type FormEvent, type ReactNode } from 'react';
import { Navigate, useNavigate, useSearchParams } from 'react-router';
import { AuthLayout } from '../../layout/AuthLayout';
import type { Product } from '../../layout/useProduct';
import { loginWithPassword } from '../../lib/auth/api';
import { useAuth } from '../../lib/auth/authContext';
import { afterLoginPath } from '../../lib/auth/redirect';
import { sessionEndText } from '../../lib/auth/formatIdle';
import { takeSessionEnded, type SessionEnd } from '../../lib/auth/sessionEnd';
import { Button } from '../../ui/Button';
import { PasswordInput, TextField } from '../../ui/Field';
import { TurnstileSlot } from '../../ui/TurnstileSlot';
import { AuthAlert } from './authParts';
import { SessionEndDialog } from './SessionEndDialog';

/** Mã lỗi do Edge Function login trả khi đang tạm chặn (không nói tài khoản có tồn tại hay không). */
const TEMP_BLOCKED_CODE = 'HMT_DANG_NHAP_TAM_CHAN';
/** Mã lỗi khi sai tên đăng nhập hoặc mật khẩu: chữ hiện ra lấy từ thiết kế từng cổng. */
const WRONG_CODE = 'HMT_SAI_DANG_NHAP';

export type LoginFormProps = {
  title: string;
  subtitle: string;
  product?: Product | undefined;
  loginLabel: string;
  loginInputMode?: 'email' | 'text' | 'tel' | undefined;
  /** Chữ mờ trong ô tên đăng nhập. */
  loginPlaceholder?: string | undefined;
  /** Chữ nút gửi (học sinh: "Vào học"). */
  submitLabel?: string | undefined;
  /** Câu hiện khi sai tên đăng nhập hoặc mật khẩu (theo thiết kế từng cổng). */
  wrongText: string;
  /** Phần dưới nút Đăng nhập: quên mật khẩu, chuyển sang trang đăng nhập khác. */
  footer: ReactNode;
};

/** Biểu mẫu đăng nhập dùng chung cho CHUNG-01 (nhân viên, giáo viên) và CHUNG-06 (học sinh). */
export function LoginForm({
  title,
  subtitle,
  product,
  loginLabel,
  loginPlaceholder,
  loginInputMode,
  submitLabel = 'Đăng nhập',
  wrongText,
  footer,
}: LoginFormProps) {
  const { supabase, claims } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const next = params.get('next');
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [captcha, setCaptcha] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [missing, setMissing] = useState<{
    login: string | undefined;
    password: string | undefined;
  }>({
    login: undefined,
    password: undefined,
  });
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  // CHUNG-09: hộp thoại "Hết phiên làm việc" hiện một lần sau khi bị tự đăng xuất.
  const [sessionEnded, setSessionEnded] = useState<SessionEnd | null>(takeSessionEnded);
  const onToken = useCallback((token: string | null) => setCaptcha(token), []);

  if (claims) return <Navigate to={afterLoginPath(claims, next)} replace />;

  async function submit(event: FormEvent) {
    event.preventDefault();
    const problems = {
      login: login.trim() ? undefined : `Nhập ${loginLabel.toLowerCase()}.`,
      password: password ? undefined : 'Nhập mật khẩu.',
    };
    setMissing(problems);
    if (problems.login || problems.password) return;
    if (!supabase) return setError('Ứng dụng chưa cấu hình kết nối.');
    if (!captcha) return setError('Chờ bước xác minh chống máy tự động hoàn tất rồi bấm lại.');
    setBusy(true);
    setError(null);
    const result = await loginWithPassword(supabase, login, password, captcha);
    setBusy(false);
    if (!result) return; // Phiên đã có: phần đầu hàm tự chuyển trang.
    // Mã chống máy chỉ dùng được một lần: lấy mã mới cho lần thử sau.
    setAttempt((n) => n + 1);
    if (result.code === TEMP_BLOCKED_CODE) return void navigate('/khong-dang-nhap-duoc');
    setError(result.code === WRONG_CODE ? wrongText : result.message);
  }

  return (
    <AuthLayout title={title} subtitle={subtitle} product={product}>
      <form onSubmit={(e) => void submit(e)} noValidate className="flex flex-col gap-[18px]">
        {error && <AuthAlert tone="danger">{error}</AuthAlert>}
        <TextField
          size="lg"
          label={loginLabel}
          name="login"
          type={loginInputMode === 'email' ? 'email' : 'text'}
          inputMode={loginInputMode}
          autoComplete="username"
          autoCapitalize="none"
          spellCheck={false}
          placeholder={loginPlaceholder}
          required
          error={missing.login}
          invalid={Boolean(error)}
          value={login}
          onChange={(e) => setLogin(e.target.value)}
        />
        <PasswordInput
          size="lg"
          label="Mật khẩu"
          name="password"
          autoComplete="current-password"
          required
          error={missing.password}
          invalid={Boolean(error)}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <TurnstileSlot onToken={onToken} attempt={attempt} />
        <Button type="submit" variant="primary" size="xl" fullWidth loading={busy}>
          {busy ? 'Đang đăng nhập…' : submitLabel}
        </Button>
        {footer}
      </form>

      <SessionEndDialog
        open={sessionEnded !== null}
        onClose={() => setSessionEnded(null)}
        reason={sessionEnded ? sessionEndText(sessionEnded) : null}
      />
    </AuthLayout>
  );
}
