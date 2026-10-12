import { useNavigate } from 'react-router';
import { useAuth } from '../lib/auth/authContext';
import { PORTALS, portalAccess, type Portal } from '../lib/auth/claims';
import { Avatar } from '../ui/Feedback';
import { Icon } from '../ui/icons';
import { DropdownMenu, type MenuItem } from '../ui/Overlays';
import { PORTAL_NAMES } from './portalNames';

/** Góc tài khoản: tên, vai trò · cơ sở; mở ra Hồ sơ cá nhân, Đổi cổng, Đăng xuất. */
export function AccountMenu({
  portal,
  roleLine,
  compact,
}: {
  portal: Portal;
  roleLine: string;
  compact?: boolean | undefined;
}) {
  const { claims, signOut } = useAuth();
  const navigate = useNavigate();
  if (!claims) return null;

  const others = PORTALS.filter((p) => p !== portal && portalAccess(claims, p) !== 'none');
  const items: MenuItem[] = [
    { kind: 'link', label: 'Hồ sơ cá nhân', to: `/${portal}/tai-khoan`, icon: 'user' },
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
          aria-label={`Tài khoản: ${claims.name}`}
          className="focus-ring touch-target flex items-center gap-2 rounded-md px-1 text-left hover:bg-hover-overlay"
        >
          <Avatar name={claims.name} />
          {!compact && (
            <span className="hidden min-w-0 sm:block">
              <span className="block truncate text-label text-fg" data-testid="ten-nguoi-dung">
                {claims.name}
              </span>
              <span className="block truncate text-caption text-fg-muted">{roleLine}</span>
            </span>
          )}
          <Icon name="chevronDown" size={16} className="text-fg-muted" />
        </button>
      }
    />
  );
}
