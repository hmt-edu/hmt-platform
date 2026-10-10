import { useEffect, useState, type FormEvent } from 'react';
import { Navigate, useNavigate } from 'react-router';
import {
  checkPassword,
  type PasswordPolicy,
} from '../../supabase/functions/_shared/login-rules.ts';
import { readBoolSetting, readIntSetting } from '../lib/auth/api';
import { useAuth } from '../lib/auth/authContext';

/** Đổi mật khẩu lần đầu (tài khoản do Admin, CSKH cấp mật khẩu tạm). */
export function ChangePasswordPage() {
  const { supabase, claims, refresh } = useAuth();
  const navigate = useNavigate();
  const [policy, setPolicy] = useState<PasswordPolicy | null>(null);
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!supabase) return;
    void Promise.all([
      readIntSetting(supabase, 'password_min_length'),
      readBoolSetting(supabase, 'password_require_letter_digit'),
    ]).then(([minLength, requireLetterDigit]) => {
      if (minLength !== null && requireLetterDigit !== null)
        setPolicy({ minLength, requireLetterDigit });
    });
  }, [supabase]);

  if (!claims) return <Navigate to="/dang-nhap" replace />;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!supabase || !policy) return;
    const problem = checkPassword(password, policy);
    if (problem) return setError(problem);
    if (password !== confirm) return setError('Hai lần nhập mật khẩu không khớp.');
    setBusy(true);
    setError(null);
    const { error: authError } = await supabase.auth.updateUser({ password });
    if (authError) {
      setBusy(false);
      return setError('Không đổi được mật khẩu. Mật khẩu mới phải khác mật khẩu cũ.');
    }
    const { error: dbError } = await supabase.schema('app').rpc('complete_first_password_change');
    await refresh();
    setBusy(false);
    if (dbError) return setError(dbError.message);
    void navigate('/dang-nhap', { replace: true });
  }

  return (
    <section className="mx-auto max-w-sm">
      <h1 className="text-2xl font-semibold">Đổi mật khẩu</h1>
      <p className="mt-2 text-sm text-gray-600">
        Đây là lần đầu bạn đăng nhập. Hãy đặt mật khẩu của riêng bạn
        {policy
          ? ` (ít nhất ${policy.minLength} ký tự${policy.requireLetterDigit ? ', có cả chữ và số' : ''})`
          : ''}
        .
      </p>
      <form onSubmit={(e) => void submit(e)} className="mt-6 flex flex-col gap-4">
        <label className="flex flex-col gap-1 text-sm">
          Mật khẩu mới
          <input
            name="new-password"
            type="password"
            autoComplete="new-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="rounded border border-gray-300 px-3 py-2 text-base"
            required
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Nhập lại mật khẩu mới
          <input
            name="confirm-password"
            type="password"
            autoComplete="new-password"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            className="rounded border border-gray-300 px-3 py-2 text-base"
            required
          />
        </label>
        {error && (
          <p role="alert" className="rounded bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </p>
        )}
        <button
          type="submit"
          disabled={busy || !policy}
          className="rounded bg-gray-900 px-4 py-2 font-medium text-white disabled:opacity-50"
        >
          {busy ? 'Đang lưu…' : 'Lưu mật khẩu mới'}
        </button>
      </form>
    </section>
  );
}
