import { useQuery } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { Navigate, useNavigate } from 'react-router';
import { AuthLayout } from '../../layout/AuthLayout';
import { useAuth } from '../../lib/auth/authContext';
import { listTotpDevices, verifyTotpAnyDevice } from '../../lib/auth/mfa';
import { afterLoginPath } from '../../lib/auth/redirect';
import { Button } from '../../ui/Button';
import { Spinner } from '../../ui/Feedback';
import { OtpInput } from '../../ui/Field';
import { AuthAlert, AuthNote, SignOutLink } from './authParts';
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

/** DN03 · Xác thực hai bước: nhập mã 6 số sau khi đăng nhập (Admin). Không có mã dự phòng. */
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
      return setError('Mã không đúng. Kiểm tra lại mã đang hiện trong ứng dụng rồi nhập lại.');
    }
    await refresh();
    setBusy(false);
  }

  return (
    <AuthLayout
      title="Xác thực hai bước"
      subtitle="Mở ứng dụng xác thực trên điện thoại, nhập mã 6 số đang hiện cho tài khoản HMT."
    >
      {devices.isPending ? (
        <Spinner />
      ) : devices.isError ? (
        <AuthAlert tone="danger">
          Không tải được thông tin xác thực. Tải lại trang rồi thử lại.
        </AuthAlert>
      ) : (
        <form onSubmit={(e) => void submit(e)} noValidate className="flex flex-col gap-[18px]">
          {error ? <AuthAlert tone="danger">{error}</AuthAlert> : null}
          <OtpInput
            label="Mã xác thực"
            value={code}
            onChange={setCode}
            invalid={Boolean(error)}
            autoFocus
          />
          <Button type="submit" variant="primary" size="xl" fullWidth loading={busy}>
            Xác nhận
          </Button>
          <AuthNote center>
            Mất điện thoại? Liên hệ quản trị viên để đặt lại xác thực hai bước
          </AuthNote>
          <AuthNote center>Bắt buộc với tài khoản Admin.</AuthNote>
        </form>
      )}
      <SignOutLink />
    </AuthLayout>
  );
}

/** DN04 · Thiết lập xác thực hai bước lần đầu: quét QR (bước 1), nhập mã xác nhận (bước 2). */
export function MfaSetupPage() {
  const [step, setStep] = useState<1 | 2>(1);
  const { claims } = useAuth();
  const navigate = useNavigate();
  const devices = useTotpDevices();

  if (!claims) return <Navigate to="/dang-nhap" replace />;
  if (!claims.requireMfa || claims.aal === 'aal2')
    return <Navigate to={afterLoginPath(claims, null)} replace />;
  if (devices.data && devices.data.length > 0) return <Navigate to="/xac-thuc-hai-buoc" replace />;

  return (
    <AuthLayout
      title={step === 1 ? 'Bật xác thực hai bước' : 'Nhập mã từ ứng dụng'}
      subtitle={
        step === 1
          ? 'Tài khoản Admin phải bật trước khi dùng hệ thống. Cài ứng dụng xác thực (Google Authenticator, Microsoft Authenticator…) rồi quét mã dưới đây.'
          : 'Nhập mã 6 số ứng dụng đang hiện để xác nhận đã cài đúng.'
      }
      eyebrow={step === 1 ? 'BƯỚC 1/2 · QUÉT MÃ' : 'BƯỚC 2/2 · NHẬP MÃ'}
      progress={{ step, total: 2 }}
    >
      {devices.isPending ? (
        <Spinner />
      ) : (
        <TotpEnroll
          deviceName="Thiết bị 1"
          onStep={setStep}
          onDone={() => void navigate('/dang-nhap', { replace: true })}
        />
      )}
      {/* Đường thoát cả hai bước (anh gặp 25/11: bị kẹt, không về đăng nhập được). */}
      <SignOutLink />
    </AuthLayout>
  );
}
