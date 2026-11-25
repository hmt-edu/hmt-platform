import type { ReactNode } from 'react';

/**
 * Khung trang dùng chung cho màn Cấu hình (CH-*) và Quản trị (QT-*) (F-24-16, G1).
 * Lề trang do CrmShell lo (20 px); màn KHÔNG tự thêm mx-auto, max-w, p-4/p-6.
 * Dải tiêu đề: tiêu đề 20 px (text-h2) bên trái, nút chính và «Lịch sử thay đổi» CÙNG HÀNG bên phải,
 * mô tả cách tiêu đề một khoảng cố định (mt-1).
 */
export const PAGE_FRAME_CLASS = 'flex min-w-0 flex-col gap-4';

export function PageFrame({ children }: { children: ReactNode }) {
  return (
    <div data-page-frame className={PAGE_FRAME_CLASS}>
      {children}
    </div>
  );
}

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <header
      data-page-header
      className="flex min-h-14 flex-wrap items-center justify-between gap-x-3 gap-y-2"
    >
      <div className="min-w-0 flex-1 basis-72">
        <h1 className="font-display text-h2">{title}</h1>
        {description ? <p className="mt-1 text-body text-fg-muted">{description}</p> : null}
      </div>
      {actions ? <div className="flex shrink-0 flex-wrap items-center gap-2">{actions}</div> : null}
    </header>
  );
}
