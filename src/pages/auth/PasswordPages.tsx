import { Navigate, useNavigate } from 'react-router';
import { AuthLayout } from '../../layout/AuthLayout';
import { useAuth } from '../../lib/auth/authContext';
import { homePortal } from '../../lib/auth/claims';
import { afterLoginPath } from '../../lib/auth/redirect';
import { ButtonLink } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { NewPasswordForm } from './NewPasswordForm';

/**
 * CHUNG-04 · Quên mật khẩu (DN05, thiết kế P1 v4): giai đoạn 0 chỉ hướng dẫn liên hệ quản trị viên, không gửi
 * email. Tự đặt lại qua email làm sau (spec 03). Trang `ResetPasswordPage` giữ nguyên nhưng chưa có màn dẫn tới.
 */
export function ForgotPasswordPage() {
  return (
    <AuthLayout title="Quên mật khẩu">
      <p className="text-body text-fg-muted">
        Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm.
      </p>
      <ButtonLink to="/dang-nhap" variant="primary" fullWidth icon="back">
        Quay lại đăng nhập
      </ButtonLink>
    </AuthLayout>
  );
}

/** CHUNG-05 · Đặt mật khẩu mới từ email: HOÃN (thiết kế P1 v4); giữ trang, chưa có màn nào dẫn tới. */
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
            Đường dẫn đặt lại mật khẩu đã hết hạn hoặc đã dùng rồi. Hãy liên hệ quản trị viên.
          </Alert>
          <ButtonLink to="/quen-mat-khau" variant="primary" fullWidth>
            Xem hướng dẫn
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
    <AuthLayout title="Đổi mật khẩu lần đầu" product={homePortal(claims) === 'hoc' ? 'lms' : 'crm'}>
      <Alert tone="info" icon="forbidden">
        Mật khẩu hiện tại là mật khẩu tạm do trung tâm cấp. Đặt mật khẩu của riêng mình để tiếp tục.
      </Alert>
      <NewPasswordForm
        submitLabel="Đổi mật khẩu và tiếp tục"
        footnote="Áp dụng cho học sinh và nhân viên được cấp mật khẩu tạm. Chưa đổi thì chưa vào được trang nào khác."
        afterAuthUpdate={confirmChange}
        onDone={() => void navigate('/dang-nhap', { replace: true })}
      />
    </AuthLayout>
  );
}

/**
 * CHUNG-08 · Không thể đăng nhập (DN08, chốt 12/10): một câu chung cho tạm khoá và khoá hẳn. Không nói thời gian
 * khoá, không nói lý do, không nói tài khoản có tồn tại hay không (luật S03-18).
 */
export function CannotLoginPage() {
  return (
    <AuthLayout title="Không thể đăng nhập">
      <p className="text-body text-fg-muted">
        Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm.
      </p>
      <ButtonLink to="/dang-nhap" variant="primary" fullWidth icon="back">
        Quay lại đăng nhập
      </ButtonLink>
    </AuthLayout>
  );
}
