import { useEffect, useState, type FormEvent } from 'react';
import { Navigate, useNavigate } from 'react-router';
import { useAuth } from '../lib/auth/authContext';

type Enrollment = { factorId: string; qrCode: string; secret: string };

/** Xác thực hai bước (TOTP) cho Admin, Kế toán: cài ứng dụng lần đầu, các lần sau nhập mã. */
export function MfaPage() {
  const { supabase, claims, refresh } = useAuth();
  const navigate = useNavigate();
  const [factorId, setFactorId] = useState<string | null>(null);
  const [enrollment, setEnrollment] = useState<Enrollment | null>(null);
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!supabase || !claims) return;
    void supabase.auth.mfa.listFactors().then(async ({ data }) => {
      const verified = data?.totp.find((f) => f.status === 'verified');
      if (verified) return setFactorId(verified.id);
      // Chưa có ứng dụng xác thực: tạo mới (bỏ các lần cài dở trước đó).
      for (const f of data?.all ?? []) {
        if (f.status === 'unverified') await supabase.auth.mfa.unenroll({ factorId: f.id });
      }
      const { data: enrolled, error: enrollError } = await supabase.auth.mfa.enroll({
        factorType: 'totp',
        friendlyName: 'HMT',
      });
      if (enrollError || !enrolled) return setError('Không tạo được mã cài đặt. Tải lại trang.');
      setFactorId(enrolled.id);
      setEnrollment({
        factorId: enrolled.id,
        qrCode: enrolled.totp.qr_code,
        secret: enrolled.totp.secret,
      });
    });
  }, [supabase, claims]);

  if (!claims) return <Navigate to="/dang-nhap" replace />;
  if (claims.aal === 'aal2') return <Navigate to="/dang-nhap" replace />;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!supabase || !factorId) return;
    setBusy(true);
    setError(null);
    const { error: verifyError } = await supabase.auth.mfa.challengeAndVerify({
      factorId,
      code: code.trim(),
    });
    if (verifyError) {
      setBusy(false);
      return setError('Mã không đúng hoặc đã hết hạn. Nhập mã mới đang hiện trên ứng dụng.');
    }
    await refresh();
    setBusy(false);
    void navigate('/dang-nhap', { replace: true });
  }

  return (
    <section className="mx-auto max-w-sm">
      <h1 className="text-2xl font-semibold">Xác thực hai bước</h1>
      {enrollment ? (
        <div className="mt-4 text-sm text-gray-700">
          <p>
            Vai trò của bạn bắt buộc xác thực hai bước. Mở ứng dụng xác thực (Google Authenticator,
            Microsoft Authenticator…), chọn thêm tài khoản và quét mã dưới đây:
          </p>
          <img
            src={enrollment.qrCode}
            alt="Mã QR cài xác thực hai bước"
            className="mx-auto my-4 h-48 w-48"
          />
          <p>
            Không quét được thì nhập khoá: <code className="break-all">{enrollment.secret}</code>
          </p>
        </div>
      ) : (
        <p className="mt-4 text-sm text-gray-700">
          Nhập mã 6 số đang hiện trên ứng dụng xác thực của bạn.
        </p>
      )}
      <form onSubmit={(e) => void submit(e)} className="mt-6 flex flex-col gap-4">
        <label className="flex flex-col gap-1 text-sm">
          Mã xác thực
          <input
            name="totp"
            inputMode="numeric"
            autoComplete="one-time-code"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className="rounded border border-gray-300 px-3 py-2 text-base tracking-widest"
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
          disabled={busy || !factorId}
          className="rounded bg-gray-900 px-4 py-2 font-medium text-white disabled:opacity-50"
        >
          {busy ? 'Đang kiểm…' : 'Xác nhận'}
        </button>
      </form>
    </section>
  );
}
