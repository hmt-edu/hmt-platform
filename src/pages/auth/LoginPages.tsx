import { Link, useSearchParams } from 'react-router';
import { LoginForm } from './LoginForm';

const LINK = 'focus-ring rounded-tag text-link underline underline-offset-2';

function withNext(path: string, next: string | null): string {
  return next ? `${path}?next=${encodeURIComponent(next)}` : path;
}

/** CHUNG-01 · Đăng nhập nhân viên, giáo viên, trợ giảng: email + mật khẩu, có Turnstile. */
export function LoginPage() {
  const [params] = useSearchParams();
  return (
    <LoginForm
      title="Đăng nhập"
      subtitle="Dành cho nhân viên, giáo viên, trợ giảng"
      loginLabel="Email"
      loginInputMode="email"
      wrongText="Email hoặc mật khẩu không đúng. Kiểm tra lại rồi thử lần nữa."
      footer={
        <>
          <Link to="/quen-mat-khau" className={LINK}>
            Quên mật khẩu?
          </Link>
          <Link to={withNext('/dang-nhap/hoc-sinh', params.get('next'))} className={LINK}>
            Em là học sinh: đăng nhập bằng mã học sinh
          </Link>
        </>
      }
    />
  );
}

/** CHUNG-06 · Đăng nhập học sinh: mã HS + mật khẩu trung tâm cấp; quên mật khẩu thì nhờ CSKH. */
export function StudentLoginPage() {
  const [params] = useSearchParams();
  return (
    <LoginForm
      title="Đăng nhập học tập"
      subtitle="Dành cho học sinh Hòa Ma Toán"
      product="lms"
      loginLabel="Mã học sinh"
      submitLabel="Vào học"
      wrongText="Mã học sinh hoặc mật khẩu chưa đúng. Em kiểm tra lại nhé."
      loginHelp="Ví dụ: HS000123. Mã có trên thẻ học sinh hoặc do thầy cô gửi."
      footer={
        <>
          <p className="text-fg-muted">
            Quên mật khẩu? Em nhờ thầy cô hoặc bộ phận chăm sóc khách hàng ở cơ sở cấp lại.
          </p>
          <Link to={withNext('/dang-nhap', params.get('next'))} className={LINK}>
            Nhân viên, giáo viên đăng nhập bằng email
          </Link>
        </>
      }
    />
  );
}
