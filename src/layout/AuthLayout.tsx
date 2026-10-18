import type { ReactNode } from 'react';
import logo from '../../design/hmt-p0-p2/assets/Logo-HMT-cropped.svg';
import { useBranchNames } from '../lib/auth/branches';
import { cn } from '../ui/cn';
import { BrandArt, BrandRobot } from './BrandArt';
import { useProduct, type Product } from './useProduct';

/** Cột giới thiệu bên trái (chỉ máy tính): tên hệ thống, lời giới thiệu, các cơ sở dạy học, chỗ nhờ hỗ trợ. */
function BrandPanel() {
  const branches = useBranchNames();
  return (
    <aside
      aria-label="Giới thiệu hệ thống"
      className="relative hidden flex-col gap-5 overflow-hidden bg-[linear-gradient(180deg,transparent_45%,rgb(101_41_16/0.28)),var(--action-primary-bg)] px-16 pt-[150px] pb-12 text-neutral-0 lg:flex"
    >
      <BrandArt />
      <BrandRobot />
      <p className="relative max-w-[520px] font-display text-[38px] leading-[1.22] font-bold tracking-tight">
        Hệ thống quản lý trung tâm
      </p>
      <p className="relative max-w-[440px] text-[16px] leading-[1.65]">
        Tuyển sinh, bán hàng, lớp học, buổi học và chăm sóc khách hàng ở một nơi. Giáo viên điểm
        danh, chấm bài ngay trên điện thoại.
      </p>
      {branches.data && branches.data.length > 0 && (
        <ul className="relative mt-3 flex max-w-[440px] flex-col gap-2.5 border-t border-neutral-0/45 pt-[22px]">
          {branches.data.map((b) => (
            <li key={b.code} className="flex items-center gap-2.5 text-body font-semibold">
              <span className="size-2 shrink-0 rounded-full bg-neutral-0" aria-hidden="true" />
              {b.code} {b.name}
            </li>
          ))}
        </ul>
      )}
      <p className="relative mt-5 max-w-[440px] text-caption">
        Cần hỗ trợ đăng nhập: liên hệ quản trị viên của trung tâm.
      </p>
    </aside>
  );
}

/**
 * Khuôn K11 (trang đơn) theo thiết kế P1 v4: máy tính chia hai cột (giới thiệu | biểu mẫu), điện thoại chỉ có
 * biểu mẫu. `eyebrow` và `progress` dùng cho các bước thiết lập (căn trái, có thanh bước).
 */
export function AuthLayout({
  title,
  subtitle,
  product = 'crm',
  eyebrow,
  progress,
  children,
}: {
  title: string;
  subtitle?: ReactNode | undefined;
  product?: Product | undefined;
  /** Dòng nhỏ trên tiêu đề, ví dụ "BƯỚC 1/2 · QUÉT MÃ". Có thì tiêu đề căn trái. */
  eyebrow?: string | undefined;
  /** Thanh bước: bước hiện tại trên tổng số. */
  progress?: { step: number; total: number } | undefined;
  children: ReactNode;
}) {
  useProduct(product);
  const start = eyebrow !== undefined;
  return (
    <div className="grid min-h-dvh bg-surface lg:grid-cols-[46fr_54fr]">
      <BrandPanel />
      <main className="flex justify-center px-6 pt-9 pb-7 lg:px-10 lg:pt-[150px] lg:pb-10">
        <div className="flex w-full max-w-[400px] flex-col gap-[18px]">
          <img
            src={logo}
            alt="Hòa Ma Toán · 18+ năm kinh nghiệm luyện thi"
            className="mx-auto mb-1.5 h-auto w-[150px] lg:w-[176px]"
          />
          {progress && (
            <div
              className="flex gap-2"
              role="img"
              aria-label={`Bước ${progress.step} trên ${progress.total}`}
            >
              {Array.from({ length: progress.total }, (_, i) => (
                <span
                  key={i}
                  className={cn(
                    'h-1 flex-1 rounded-full',
                    i < progress.step ? 'bg-action' : 'bg-border',
                  )}
                />
              ))}
            </div>
          )}
          <div className={start ? 'flex flex-col gap-2' : 'flex flex-col gap-2 text-center'}>
            {eyebrow && (
              <p className="text-caption font-bold tracking-wider text-on-selected uppercase">
                {eyebrow}
              </p>
            )}
            <h1 className="font-display text-[22px] leading-tight font-bold tracking-tight lg:text-[26px]">
              {title}
            </h1>
            {subtitle && <p className="text-body text-fg-muted">{subtitle}</p>}
          </div>
          {children}
        </div>
      </main>
    </div>
  );
}
