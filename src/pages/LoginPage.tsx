import { useCallback, useState, type FormEvent } from 'react';
import { Navigate, useNavigate, useSearchParams } from 'react-router';
import { Turnstile } from '../components/Turnstile';
import { loginWithPassword } from '../lib/auth/api';
import { useAuth } from '../lib/auth/authContext';
import { homePortal, pendingStep } from '../lib/auth/claims';

/** Trang đăng nhập tối giản (bước 4 thay bằng giao diện theo hệ thống thiết kế). */
export function LoginPage() {
  const { supabase, claims } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [captcha, setCaptcha] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const onToken = useCallback((token: string | null) => setCaptcha(token), []);

  if (claims) {
    const step = pendingStep(claims);
    if (step === 'change-password') return <Navigate to="/doi-mat-khau" replace />;
    if (step === 'mfa') return <Navigate to="/xac-thuc-hai-buoc" replace />;
    const next = params.get('next');
    const home = homePortal(claims);
    return <Navigate to={next ?? (home ? `/${home}` : '/')} replace />;
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!supabase) return setError('Ứng dụng chưa cấu hình kết nối.');
    if (!captcha) return setError('Chờ bước xác minh chống máy tự động hoàn tất.');
    setBusy(true);
    setError(null);
    const result = await loginWithPassword(supabase, login, password, captcha);
    setBusy(false);
    if (result) {
      setError(result.message);
      setPassword('');
      return;
    }
    void navigate(params.get('next') ?? '/dang-nhap', { replace: true });
  }

  return (
    <section className="mx-auto max-w-sm">
      <h1 className="text-2xl font-semibold">Đăng nhập</h1>
      <form onSubmit={(e) => void submit(e)} className="mt-6 flex flex-col gap-4">
        <label className="flex flex-col gap-1 text-sm">
          Email hoặc mã học sinh
          <input
            name="login"
            autoComplete="username"
            value={login}
            onChange={(e) => setLogin(e.target.value)}
            className="rounded border border-gray-300 px-3 py-2 text-base"
            required
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Mật khẩu
          <input
            name="password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="rounded border border-gray-300 px-3 py-2 text-base"
            required
          />
        </label>
        <Turnstile onToken={onToken} />
        {error && (
          <p role="alert" className="rounded bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </p>
        )}
        <button
          type="submit"
          disabled={busy}
          className="rounded bg-gray-900 px-4 py-2 font-medium text-white disabled:opacity-50"
        >
          {busy ? 'Đang đăng nhập…' : 'Đăng nhập'}
        </button>
        <p className="text-sm text-gray-600">
          Quên mật khẩu: nhân viên liên hệ quản trị viên; học sinh nhờ CSKH đặt lại.
        </p>
      </form>
    </section>
  );
}
