import { useQuery } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { Navigate, useNavigate } from 'react-router';
import { AuthLayout } from '../../layout/AuthLayout';
import { useAuth } from '../../lib/auth/authContext';
import { listTotpDevices, verifyTotpAnyDevice } from '../../lib/auth/mfa';
import { afterLoginPath } from '../../lib/auth/redirect';
import { Button } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { OtpInput } from '../../ui/Field';
import { TotpEnroll } from './TotpEnroll';

function useTotpDevices() {
  const { supabase, claims } = useAuth();
  return useQuery({
    queryKey: ['totp-devices', claims?.userId],
    enabled: Boolean(supabase && claims),
    staleTime: 0,
    queryFn: () => {
      if (!supabase) throw new Error('Chưa cấu hình kết nối.');
      return listTotpDevices(supabase);
    },
  });
}

function SignOutLink() {
  const { signOut } = useAuth();
  const navigate = useNavigate();
  return (
    <Button
      variant="ghost"
      fullWidth
      onClick={() => void signOut().then(() => navigate('/dang-nhap'))}
    >
      Đăng nhập bằng tài khoản khác
    </Button>
  );
}

/** CHUNG-02 · Xác thực hai bước: nhập mã 6 số sau khi đăng nhập (Admin, Kế toán). Không có mã dự phòng. */
export function MfaVerifyPage() {
  const { supabase, claims, refresh } = useAuth();
  const devices = useTotpDevices();
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (!claims) return <Navigate to="/dang-nhap" replace />;
  if (claims.aal === 'aal2' || !claims.requireMfa)
    return <Navigate to={afterLoginPath(claims, null)} replace />;
  if (devices.data && devices.data.length === 0)
    return <Navigate to="/thiet-lap-hai-buoc" replace />;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!supabase || !devices.data) return;
    setBusy(true);
    setError(null);
    const ok = await verifyTotpAnyDevice(supabase, devices.data, code);
    if (!ok) {
      setBusy(false);
      setCode('');
      return setError('Mã không đúng hoặc đã hết hạn. Nhập mã mới đang hiện trên ứng dụng.');
    }
    await refresh();
    setBusy(false);
  }

  return (
    <AuthLayout
      title="Xác thực hai bước"
      subtitle="Nhập mã 6 số đang hiện trên ứng dụng xác thực của bạn."
    >
      {devices.isPending ? (
        <Spinner />
      ) : devices.isError ? (
        <Alert tone="danger">Không tải được thông tin xác thực. Tải lại trang rồi thử lại.</Alert>
      ) : (
        <form onSubmit={(e) => void submit(e)} noValidate className="flex flex-col gap-4">
          <OtpInput label="Mã xác thực" value={code} onChange={setCode} error={error} autoFocus />
          <Button type="submit" variant="primary" fullWidth loading={busy}>
            Xác nhận
          </Button>
          <p className="text-caption text-fg-muted">
            Mất điện thoại? Liên hệ quản trị viên để đặt lại xác thực hai bước.
          </p>
        </form>
      )}
      <SignOutLink />
    </AuthLayout>
  );
}

/** CHUNG-03 · Thiết lập xác thực hai bước lần đầu: quét QR, nhập mã xác nhận. */
export function MfaSetupPage() {
  const { claims } = useAuth();
  const navigate = useNavigate();
  const devices = useTotpDevices();

  if (!claims) return <Navigate to="/dang-nhap" replace />;
  if (!claims.requireMfa || claims.aal === 'aal2')
    return <Navigate to={afterLoginPath(claims, null)} replace />;
  if (devices.data && devices.data.length > 0) return <Navigate to="/xac-thuc-hai-buoc" replace />;

  return (
    <AuthLayout
      title="Thiết lập xác thực hai bước"
      subtitle="Vai trò của bạn bắt buộc xác thực hai bước. Làm một lần, mất khoảng 2 phút."
    >
      {devices.isPending ? (
        <Spinner />
      ) : (
        <TotpEnroll
          deviceName="Thiết bị 1"
          onDone={() => void navigate('/dang-nhap', { replace: true })}
        />
      )}
      <SignOutLink />
    </AuthLayout>
  );
}
