import { useNavigate } from 'react-router';
import { useAuth } from '../lib/auth/authContext';
import { PORTALS, portalAccess, type Portal } from '../lib/auth/claims';
import { Avatar } from '../ui/Feedback';
import { DropdownMenu, type MenuItem } from '../ui/Overlays';
import { accountLabel } from './accountLabel';
import { PORTAL_NAMES } from './portalNames';

/** Góc tài khoản: tên, vai trò và cơ sở mỗi thứ một dòng (T13); mở ra Hồ sơ cá nhân, Đổi cổng, Đăng xuất. */
export function AccountMenu({
  portal,
  roleLines,
  compact,
}: {
  portal: Portal;
  roleLines: string[];
  compact?: boolean | undefined;
}) {
  const { claims, signOut } = useAuth();
  const navigate = useNavigate();
  if (!claims) return null;

  const others = PORTALS.filter((p) => p !== portal && portalAccess(claims, p) !== 'none');
  const items: MenuItem[] = [
    { kind: 'link', label: 'Hồ sơ cá nhân', to: `/${portal}/tai-khoan`, icon: 'user' },
    ...(portal === 'crm'
      ? [
          {
            kind: 'link',
            label: 'Hướng dẫn sử dụng',
            to: '/crm/huong-dan',
            icon: 'info',
          } satisfies MenuItem,
        ]
      : []),
    ...others.map<MenuItem>((p) => ({
      kind: 'link',
      label: `Sang cổng ${PORTAL_NAMES[p]}`,
      to: `/${p}`,
      icon: 'switchPortal',
    })),
    {
      kind: 'action',
      label: 'Đăng xuất',
      icon: 'logout',
      onSelect: () => void signOut().then(() => navigate('/dang-nhap')),
    },
  ];

  return (
    <DropdownMenu
      items={items}
      trigger={
        <button
          type="button"
          className="focus-ring touch-target flex items-center gap-2 rounded-control px-1 text-left hover:bg-hover"
        >
          <Avatar name={claims.name} large />
          {/* Tên đọc của nút lấy từ chữ ẩn này (không dùng aria-label), nên luật axe label-content-name-mismatch (WCAG 2.5.3) không còn so nhãn với chữ hiển thị; chữ hiển thị để aria-hidden tránh đọc hai lần. */}
          <span className="sr-only">{accountLabel(claims.name, roleLines, compact === true)}</span>
          {!compact && (
            <span aria-hidden="true" className="hidden min-w-0 sm:block">
              <span
                className="block truncate text-body font-semibold text-fg"
                data-testid="ten-nguoi-dung"
              >
                {claims.name}
              </span>
              {roleLines.map((line) => (
                <span key={line} className="block truncate text-caption text-fg-muted">
                  {line}
                </span>
              ))}
            </span>
          )}
        </button>
      }
    />
  );
}
