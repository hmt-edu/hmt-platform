import type { ReactNode } from 'react';
import logo from '../../design/hmt-platform/assets/hmt-logo-cropped.svg';
import { useProduct, type Product } from './useProduct';

/** Khuôn K11 (trang đơn): đăng nhập, xác thực, đặt mật khẩu, báo lỗi. Không có menu. */
export function AuthLayout({
  title,
  subtitle,
  product = 'crm',
  children,
}: {
  title: string;
  subtitle?: ReactNode | undefined;
  product?: Product | undefined;
  children: ReactNode;
}) {
  useProduct(product);
  return (
    <div className="grid min-h-dvh bg-canvas lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)]">
      <div className="auth-grid hidden lg:block" aria-hidden="true" />
      <main className="flex flex-col items-center justify-center px-4 py-10">
        <div className="flex w-full max-w-sm flex-col gap-6">
          <img src={logo} alt="Hòa Ma Toán" className="h-10 w-auto self-start" />
          <div>
            <h1 className="text-h1">{title}</h1>
            {subtitle && <p className="mt-1 text-fg-muted">{subtitle}</p>}
          </div>
          {children}
          <p className="text-center text-caption text-fg-muted">Hòa Ma Toán · 5 cơ sở tại Hà Nội</p>
        </div>
      </main>
    </div>
  );
}
