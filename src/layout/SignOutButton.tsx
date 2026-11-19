import { useNavigate } from 'react-router';
import { useAuth } from '../lib/auth/authContext';
import { Button } from '../ui/Button';

/**
 * Nút «Đăng xuất» dùng ở các trang chặn (không có quyền, đổi mật khẩu lần đầu, chọn cổng, lỗi tải quyền): người dùng luôn có lối thoát
 * để đăng nhập tài khoản khác. Dùng chung đường đăng xuất của menu tài khoản (signOut rồi về /dang-nhap).
 */
export function SignOutButton({
  variant = 'secondary',
  size,
  fullWidth,
}: {
  variant?: 'secondary' | 'primary';
  size?: 'xl';
  fullWidth?: boolean;
}) {
  const { signOut } = useAuth();
  const navigate = useNavigate();
  return (
    <Button
      variant={variant}
      {...(size ? { size } : {})}
      {...(fullWidth ? { fullWidth } : {})}
      onClick={() => void signOut().then(() => navigate('/dang-nhap'))}
    >
      Đăng xuất
    </Button>
  );
}
