import type { ReactNode } from 'react';
import logo from '../../design/hmt-p0-p2/assets/Logo-HMT-cropped.svg';
import { useBranchNames } from '../lib/auth/branches';
import { cn } from '../ui/cn';
import { BrandArt, BrandBars, BrandSlogan } from './BrandArt';
import { useProduct, type Product } from './useProduct';

/**
 * Cột giới thiệu bên trái (chỉ máy tính, canvas 9933 v149): tiêu đề chữ hoa, đoạn giới thiệu căn đều, nhãn CÁC CƠ SỞ với các viên cơ sở
 * (đọc từ hàm công khai login_branch_names, theo thứ tự danh mục, không viết cứng), hình năm cột, slogan chạy từng từ ở đáy.
 */
function BrandPanel() {
  const branches = useBranchNames();
  return (
    <aside
      aria-label="Giới thiệu hệ thống"
      className="relative hidden flex-col overflow-hidden bg-action bg-[linear-gradient(180deg,transparent_45%,rgb(101_41_16/0.28))] px-16 pt-[150px] pb-12 text-neutral-0 lg:flex"
    >
      <BrandArt />
      <BrandBars />
      <div className="relative flex w-max max-w-full flex-col gap-5">
        <p className="font-display text-[30px] leading-[1.3] font-bold tracking-[0.02em] whitespace-nowrap uppercase">
          Hệ thống quản lý trung tâm
        </p>
        <p className="w-0 min-w-full text-justify text-[16px] leading-[1.65] text-pretty">
          Tuyển sinh, bán hàng, lớp học, buổi học và chăm sóc khách hàng ở một nơi. Giáo viên điểm
          danh, chấm bài ngay trên điện thoại.
        </p>
        {branches.data && branches.data.length > 0 && (
          <div className="mt-3 w-0 min-w-full border-t border-neutral-0/45 pt-[22px]">
            <p className="mb-3.5 text-[12px] font-semibold tracking-[0.14em] opacity-90">
              CÁC CƠ SỞ
            </p>
            <ul className="flex flex-wrap gap-2.5">
              {branches.data.map((b) => (
                <li
                  key={b.code}
                  className="inline-flex items-center gap-2.5 rounded-full border border-neutral-0/30 bg-neutral-0/[0.14] py-[5px] pr-4 pl-[5px] text-[14px] font-semibold"
                >
                  <b className="inline-flex h-[26px] min-w-[42px] items-center justify-center rounded-full bg-neutral-0 text-[12px] font-bold text-[#AB420F]">
                    {b.code}
                  </b>
                  {b.name}
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
      <BrandSlogan />
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
  wide = false,
  icon,
  children,
}: {
  title: string;
  subtitle?: ReactNode | undefined;
  product?: Product | undefined;
  /** Dòng nhỏ trên tiêu đề, ví dụ "BƯỚC 1/2 · QUÉT MÃ". Có thì tiêu đề căn trái. */
  eyebrow?: string | undefined;
  /** Thanh bước: bước hiện tại trên tổng số. */
  progress?: { step: number; total: number } | undefined;
  /** Biểu mẫu rộng 560px (chọn cổng, DN10) thay vì 400px. */
  wide?: boolean | undefined;
  /** Biểu tượng tròn lớn giữa logo và tiêu đề (DN08). */
  icon?: ReactNode | undefined;
  children: ReactNode;
}) {
  useProduct(product);
  const start = eyebrow !== undefined;
  return (
    <div className="grid min-h-dvh bg-surface lg:grid-cols-[46fr_54fr]">
      <BrandPanel />
      <main className="flex justify-center px-6 pt-9 pb-7 lg:px-10 lg:pt-[150px] lg:pb-10">
        <div
          className={cn(
            'flex w-full flex-col gap-[18px]',
            wide ? 'max-w-[560px]' : 'max-w-[400px]',
          )}
        >
          <img
            src={logo}
            alt="Hòa Ma Toán · 18+ năm kinh nghiệm luyện thi"
            className="mx-auto mb-1.5 h-auto w-[150px] lg:w-[176px]"
          />
          {icon}
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
          {eyebrow && (
            <p className="text-caption font-bold tracking-wider text-on-selected uppercase">
              {eyebrow}
            </p>
          )}
          <div className={start ? 'flex flex-col gap-2' : 'flex flex-col gap-2.5 text-center'}>
            <h1 className="font-display text-[22px] leading-tight font-bold tracking-tight lg:text-[26px]">
              {title}
            </h1>
            {subtitle && <p className="text-[14px] leading-[1.6] text-fg-muted">{subtitle}</p>}
          </div>
          {children}
        </div>
      </main>
    </div>
  );
}
