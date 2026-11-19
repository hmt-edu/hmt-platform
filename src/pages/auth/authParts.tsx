// Các phần dùng chung của nhóm trang đăng nhập (khuôn K11, thiết kế P1 v4 `design/hmt-p0-p2` DN01 đến DN10):
// khối thông báo cỡ lớn, dòng chú, liên kết, biểu tượng tròn lớn. Ô nhập, nút dùng cỡ `lg` / `xl` của thành phần chung.
import type { ReactNode } from 'react';
import { Link, useNavigate, type LinkProps } from 'react-router';
import { useAuth } from '../../lib/auth/authContext';
import { cn } from '../../ui/cn';
import { Icon, type IconName } from '../../ui/icons';

export type AuthAlertTone = 'danger' | 'info' | 'plain';

const ALERT_TONE: Record<AuthAlertTone, { box: string; icon: IconName }> = {
  danger: { box: 'bg-danger-subtle text-on-danger-subtle', icon: 'alert' },
  info: { box: 'bg-info-subtle text-on-info-subtle', icon: 'info' },
  // DN07: dòng nhắc có biểu tượng, không nền.
  plain: { box: 'text-fg', icon: 'forbidden' },
};

/** Thông báo của trang đăng nhập: chữ 13px, bo lớn, lề 11/14. Lỗi đọc ngay (role=alert). */
export function AuthAlert({
  tone,
  icon,
  children,
}: {
  tone: AuthAlertTone;
  icon?: IconName | undefined;
  children: ReactNode;
}) {
  const style = ALERT_TONE[tone];
  return (
    <div
      role={tone === 'danger' ? 'alert' : 'status'}
      className={cn(
        'flex items-start gap-2.5 rounded-box px-3.5 py-[11px] text-left text-[13px] leading-[1.5]',
        style.box,
      )}
    >
      <Icon name={icon ?? style.icon} size={16} className="mt-px shrink-0" />
      <span>{children}</span>
    </div>
  );
}

/** Dòng chú nhỏ 13px; `center` canh giữa. */
export function AuthNote({ center = false, children }: { center?: boolean; children: ReactNode }) {
  return (
    <p className={cn('text-[13px] leading-[1.55] text-fg-muted', center && 'text-center')}>
      {children}
    </p>
  );
}

const LINK_CLASS = 'focus-ring rounded-tag font-medium text-link hover:underline';

/** Liên kết của trang đăng nhập: màu cam, không gạch chân (gạch khi rê chuột, tiêu điểm có viền). */
export function AuthLink(props: LinkProps) {
  return <Link {...props} className={cn(LINK_CLASS, props.className)} />;
}

/** Nút liên kết dạng chữ (không điều hướng) cùng kiểu với AuthLink. */
export function AuthLinkButton({
  onClick,
  children,
}: {
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button type="button" onClick={onClick} className={LINK_CLASS}>
      {children}
    </button>
  );
}

/** Biểu tượng tròn lớn 64px trên đầu trang một câu (DN08 khoá, DN09 hết phiên). */
export function AuthBigIcon({
  tone,
  icon,
  start = false,
}: {
  tone: 'danger' | 'info';
  icon: IconName;
  /** Canh trái (hộp thoại) thay vì giữa trang. */
  start?: boolean;
}) {
  return (
    <div
      aria-hidden="true"
      className={cn(
        'flex size-16 items-center justify-center rounded-full',
        !start && 'mx-auto',
        tone === 'danger' ? 'bg-danger-subtle text-danger-solid' : 'bg-info-subtle text-info-solid',
      )}
    >
      <Icon name={icon} size={24} />
    </div>
  );
}

/** Liên kết «Đăng xuất» ở các trang đăng nhập dở dang (DN03 hai bước, đổi mật khẩu lần đầu, chọn cổng): đăng xuất rồi về trang đăng nhập. */
export function SignOutLink({ label = 'Đăng nhập tài khoản khác' }: { label?: string }) {
  const { signOut } = useAuth();
  const navigate = useNavigate();
  return (
    <p className="text-center text-[14px]">
      <AuthLinkButton onClick={() => void signOut().then(() => navigate('/dang-nhap'))}>
        {label}
      </AuthLinkButton>
    </p>
  );
}
