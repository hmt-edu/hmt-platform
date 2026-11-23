import { useEffect } from 'react';
import { useSearchParams } from 'react-router';
import { AuthAlert, AuthLink, AuthNote } from './authParts';
import { LoginForm } from './LoginForm';
import { prefetchAfterLogin } from './prefetchAfterLogin';

function withNext(path: string, next: string | null): string {
  return next ? `${path}?next=${encodeURIComponent(next)}` : path;
}

/** DN01 · Đăng nhập nhân viên, giáo viên, trợ giảng: email + mật khẩu, có Turnstile. */
export function LoginPage() {
  const [params] = useSearchParams();
  useEffect(() => prefetchAfterLogin(), []);
  return (
    <LoginForm
      title="Đăng nhập"
      subtitle="Dành cho nhân viên, giáo viên và trợ giảng."
      loginLabel="Email"
      loginInputMode="email"
      loginPlaceholder="ten@hoamatoan.vn"
      wrongText="Email hoặc mật khẩu không đúng. Kiểm tra lại rồi thử lần nữa."
      footer={
        <>
          <p className="text-center text-[14px]">
            <AuthLink to="/quen-mat-khau">Quên mật khẩu?</AuthLink>
          </p>
          <AuthNote center>
            Học sinh?{' '}
            <AuthLink to={withNext('/dang-nhap/hoc-sinh', params.get('next'))}>
              Đăng nhập bằng mã học sinh
            </AuthLink>
          </AuthNote>
        </>
      }
    />
  );
}

/** DN02 · Đăng nhập học sinh: mã HS + mật khẩu trung tâm cấp; quên mật khẩu thì nhờ CSKH. */
export function StudentLoginPage() {
  const [params] = useSearchParams();
  return (
    <LoginForm
      title="Chào em"
      subtitle="Đăng nhập để xem bài tập, lịch học và kết quả."
      product="lms"
      loginLabel="Mã học sinh"
      loginPlaceholder="HS000212"
      submitLabel="Vào học"
      wrongText="Mã học sinh hoặc mật khẩu chưa đúng. Em kiểm tra lại nhé."
      footer={
        <>
          <AuthAlert tone="info">
            Quên mật khẩu? Em nhờ thầy cô hoặc bộ phận chăm sóc khách hàng ở cơ sở cấp lại.
          </AuthAlert>
          <AuthNote center>
            Nhân viên, giáo viên:{' '}
            <AuthLink to={withNext('/dang-nhap', params.get('next'))}>đăng nhập ở đây</AuthLink>
          </AuthNote>
          <AuthNote center>
            Phụ huynh?{' '}
            <AuthLink to={withNext('/dang-nhap/phu-huynh', params.get('next'))}>
              Đăng nhập bằng mã phụ huynh
            </AuthLink>
          </AuthNote>
        </>
      }
    />
  );
}

/**
 * CHUNG-23 · Đăng nhập phụ huynh (khuôn DN03, điện thoại): mã PH + mật khẩu trung tâm cấp (QT-17).
 * Dùng luồng đăng nhập chung (Edge Function login: chống dò, khoá tạm); không đổi luật khoá.
 */
export function ParentLoginPage() {
  const [params] = useSearchParams();
  return (
    <LoginForm
      title="Chào quý phụ huynh"
      subtitle="Đăng nhập để xem kết quả, học phí và lịch học của con."
      product="lms"
      loginLabel="Số điện thoại"
      loginInputMode="tel"
      wrongText="Số điện thoại hoặc mật khẩu chưa đúng. Quý phụ huynh kiểm tra lại."
      footer={
        <>
          <AuthAlert tone="info">Quên mật khẩu? Liên hệ CSKH ở cơ sở để đặt lại.</AuthAlert>
          <AuthNote center>
            Nhân viên, giáo viên:{' '}
            <AuthLink to={withNext('/dang-nhap', params.get('next'))}>đăng nhập ở đây</AuthLink>
          </AuthNote>
        </>
      }
    />
  );
}
