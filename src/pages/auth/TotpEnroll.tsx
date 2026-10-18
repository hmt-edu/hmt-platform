import { useEffect, useState, type FormEvent } from 'react';
import { useAuth } from '../../lib/auth/authContext';
import { startTotpEnrollment, verifyTotp, type TotpEnrollment } from '../../lib/auth/mfa';
import { Button } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { OtpInput } from '../../ui/Field';

/** Đăng ký một thiết bị TOTP: quét QR (hoặc nhập khoá), rồi nhập mã 6 số để xác nhận. */
export function TotpEnroll({
  deviceName,
  onDone,
  onStep,
}: {
  deviceName: string;
  onDone: () => void;
  /** Có hàm này thì chia hai bước (DN04): 1 quét mã, 2 nhập mã; trang gọi dùng số bước để vẽ thanh bước. */
  onStep?: ((step: 1 | 2) => void) | undefined;
}) {
  const [step, setStep] = useState<1 | 2>(1);
  const split = onStep !== undefined;
  const go = (next: 1 | 2) => {
    setStep(next);
    onStep?.(next);
  };
  const { supabase, refresh } = useAuth();
  const [enrollment, setEnrollment] = useState<TotpEnrollment | null>(null);
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!supabase) return;
    let cancelled = false;
    startTotpEnrollment(supabase, deviceName)
      .then((result) => {
        if (!cancelled) setEnrollment(result);
      })
      .catch(() => {
        if (!cancelled) setError('Không tạo được mã cài đặt. Tải lại trang rồi thử lại.');
      });
    return () => {
      cancelled = true;
    };
  }, [supabase, deviceName]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!supabase || !enrollment) return;
    setBusy(true);
    setError(null);
    const ok = await verifyTotp(supabase, enrollment.factorId, code);
    if (!ok) {
      setBusy(false);
      return setError('Mã không đúng hoặc đã hết hạn. Nhập mã mới đang hiện trên ứng dụng.');
    }
    await refresh();
    setBusy(false);
    onDone();
  }

  if (!enrollment)
    return error ? <Alert tone="danger">{error}</Alert> : <Spinner label="Đang tạo mã cài đặt…" />;

  return (
    <form onSubmit={(e) => void submit(e)} noValidate className="flex flex-col gap-4">
      {(!split || step === 1) && (
        <>
          <ol className="flex list-decimal flex-col gap-2 pl-5 text-body text-fg">
            <li>
              Mở ứng dụng xác thực trên điện thoại (Mật khẩu của iPhone, Google Authenticator,
              Microsoft Authenticator…).
            </li>
            <li>Chọn thêm tài khoản rồi quét mã dưới đây.</li>
            <li>Nhập mã 6 số ứng dụng hiện ra.</li>
          </ol>
          <img
            src={enrollment.qrCode}
            alt="Mã QR để cài xác thực hai bước"
            className="mx-auto size-48 rounded-control bg-surface p-2"
          />
          <p className="text-caption text-fg-muted">
            Không quét được thì nhập khoá:{' '}
            <code className="font-mono break-all text-fg">{enrollment.secret}</code>
          </p>
        </>
      )}
      {(!split || step === 2) && (
        <>
          {error ? <Alert tone="danger">{error}</Alert> : null}
          <OtpInput label="Mã xác thực" value={code} onChange={setCode} invalid={Boolean(error)} />
        </>
      )}
      {split && step === 1 ? (
        <Button type="button" variant="primary" fullWidth onClick={() => go(2)}>
          Tiếp
        </Button>
      ) : (
        <div className="flex gap-3">
          {split && (
            <Button type="button" variant="secondary" onClick={() => go(1)}>
              Quay lại
            </Button>
          )}
          <Button type="submit" variant="primary" fullWidth loading={busy}>
            {split ? 'Hoàn tất' : 'Xác nhận'}
          </Button>
        </div>
      )}
    </form>
  );
}
