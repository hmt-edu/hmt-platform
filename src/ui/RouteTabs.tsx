// Tab chuyển giữa các màn cùng một mục menu: dáng .hmt-tab của Tabs, nhưng mỗi tab là một đường dẫn riêng.
import { NavLink } from 'react-router';
import { cn } from './cn';

export function RouteTabs({
  label,
  items,
}: {
  label: string;
  items: { to: string; label: string }[];
}) {
  return (
    <nav
      aria-label={label}
      className="mb-3 flex gap-0.5 overflow-x-auto overflow-y-hidden border-b border-border"
    >
      {items.map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          end
          className={({ isActive }) =>
            cn(
              'focus-ring tap -mb-px inline-flex h-control items-center border-b-2 px-3 text-body whitespace-nowrap',
              isActive
                ? 'border-brand-500 font-semibold text-brand-800'
                : 'border-transparent font-medium text-fg-label',
            )
          }
        >
          {item.label}
        </NavLink>
      ))}
    </nav>
  );
}
