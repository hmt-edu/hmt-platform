import { useCallback, useState, type FormEvent } from 'react';
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router';
import { AuthLayout } from '../../layout/AuthLayout';
import { useAuth } from '../../lib/auth/authContext';
import { homePortal } from '../../lib/auth/claims';
import { afterLoginPath } from '../../lib/auth/redirect';
import { Button, ButtonLink } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { TurnstileSlot } from '../../ui/TurnstileSlot';
import { NewPasswordForm } from './NewPasswordForm';

const LINK = 'focus-ring rounded-sm text-link underline underline-offset-2';

/** CHUNG-04 · Quên mật khẩu: nhân viên tự đặt lại qua email. Học sinh nhờ CSKH. */
export function ForgotPasswordPage() {
  const { supabase } = useAuth();
  const [email, setEmail] = useState('');
  const [captcha, setCaptcha] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [missing, setMissing] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const onToken = useCallback((token: string | null) => setCaptcha(token), []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!email.trim()) return setMissing('Nhập email đăng nhập của bạn.');
    setMissing(null);
    if (!supabase || !captcha) return;
    setBusy(true);
    // Kết quả không được lộ email có tài khoản hay không: gửi được hay không đều hiện cùng một câu.
    await supabase.auth.resetPasswordForEmail(email.trim().toLowerCase(), {
      redirectTo: `${window.location.origin}/dat-mat-khau`,
      captchaToken: captcha,
    });
    setBusy(false);
    setAttempt((n) => n + 1);
    setSent(true);
  }

  return (
    <AuthLayout title="Quên mật khẩu" subtitle="Dành cho nhân viên, giáo viên, trợ giảng">
      {sent ? (
        <>
          <Alert tone="info" title="Đã ghi nhận yêu cầu">
            Nếu email này có tài khoản, hệ thống sẽ gửi thư kèm đường dẫn đặt lại mật khẩu. Không
            nhận được thư sau ít phút thì liên hệ quản trị viên để được đặt lại mật khẩu.
          </Alert>
          <ButtonLink to="/dang-nhap" variant="primary" fullWidth>
            Về trang đăng nhập
          </ButtonLink>
        </>
      ) : (
        <form onSubmit={(e) => void submit(e)} noValidate className="flex flex-col gap-4">
          <TextField
            label="Email"
            name="email"
            type="email"
            inputMode="email"
            autoComplete="username"
            required
            error={missing}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <TurnstileSlot onToken={onToken} attempt={attempt} />
          <Button type="submit" variant="primary" fullWidth loading={busy} disabled={!captcha}>
            Gửi email đặt lại mật khẩu
          </Button>
          <p className="text-body text-fg-muted">
            Học sinh quên mật khẩu thì nhờ thầy cô chăm sóc lớp đặt lại.
          </p>
          <Link to="/dang-nhap" className={LINK}>
            Về trang đăng nhập
          </Link>
        </form>
      )}
    </AuthLayout>
  );
}

/** CHUNG-05 · Đặt mật khẩu mới từ đường dẫn trong email. */
export function ResetPasswordPage() {
  const { session, claims } = useAuth();
  const navigate = useNavigate();
  if (session === undefined)
    return (
      <AuthLayout title="Đặt mật khẩu mới">
        <Spinner />
      </AuthLayout>
    );
  return (
    <AuthLayout
      title="Đặt mật khẩu mới"
      subtitle={claims ? 'Đặt mật khẩu của riêng bạn để đăng nhập.' : undefined}
    >
      {claims ? (
        <NewPasswordForm
          submitLabel="Lưu mật khẩu mới"
          onDone={() => void navigate('/dang-nhap', { replace: true })}
        />
      ) : (
        <>
          <Alert tone="warning" title="Đường dẫn không còn dùng được">
            Đường dẫn đặt lại mật khẩu đã hết hạn hoặc đã dùng rồi. Hãy gửi lại yêu cầu.
          </Alert>
          <ButtonLink to="/quen-mat-khau" variant="primary" fullWidth>
            Gửi lại yêu cầu
          </ButtonLink>
        </>
      )}
    </AuthLayout>
  );
}

/** CHUNG-07 · Đổi mật khẩu bắt buộc lần đầu (người được cấp mật khẩu tạm phải đổi ngay). */
export function ChangePasswordPage() {
  const { supabase, claims } = useAuth();
  const navigate = useNavigate();
  if (!claims) return <Navigate to="/dang-nhap" replace />;
  if (!claims.mustChangePassword) return <Navigate to={afterLoginPath(claims, null)} replace />;

  // Luật: chỉ hết "phải đổi mật khẩu" khi cơ sở dữ liệu xác nhận mật khẩu đã khác mật khẩu tạm.
  const confirmChange = async () => {
    if (!supabase) return 'Ứng dụng chưa cấu hình kết nối.';
    const { error } = await supabase.schema('app').rpc('complete_first_password_change');
    return error ? error.message : null;
  };

  return (
    <AuthLayout
      title="Đổi mật khẩu"
      subtitle="Đây là lần đầu bạn đăng nhập bằng mật khẩu được cấp. Hãy đặt mật khẩu của riêng bạn."
      product={homePortal(claims) === 'hoc' ? 'lms' : 'crm'}
    >
      <NewPasswordForm
        submitLabel="Lưu mật khẩu mới"
        afterAuthUpdate={confirmChange}
        onDone={() => void navigate('/dang-nhap', { replace: true })}
      />
    </AuthLayout>
  );
}

/**
 * CHUNG-08 · Không đăng nhập được (chốt 12/10): thông báo chung kèm hướng dẫn liên hệ quản trị.
 * Không nói tài khoản bị khoá hay không tồn tại (đăng nhập không lộ trạng thái tài khoản).
 */
export function CannotLoginPage() {
  const [params] = useSearchParams();
  const tempBlocked = params.get('ly-do') === 'tam-chan';
  return (
    <AuthLayout title="Không đăng nhập được">
      {tempBlocked && <Alert tone="warning">Đăng nhập tạm thời bị chặn, thử lại sau.</Alert>}
      <div className="flex flex-col gap-2 text-body text-fg">
        <p>Nếu bạn chắc đã nhập đúng mà vẫn không vào được:</p>
        <ul className="flex list-disc flex-col gap-1 pl-5">
          <li>Nhân viên, giáo viên: liên hệ quản trị viên hoặc Trưởng cơ sở của bạn.</li>
          <li>Học sinh: nhờ thầy cô chăm sóc lớp kiểm tra tài khoản.</li>
        </ul>
      </div>
      <ButtonLink to="/dang-nhap" variant="primary" fullWidth icon="back">
        Quay lại đăng nhập
      </ButtonLink>
    </AuthLayout>
  );
}
