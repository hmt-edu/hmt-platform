// DN09 · Hộp thoại hết phiên làm việc (P1 v4): biểu tượng đồng hồ tròn, tiêu đề, giải thích, nút "Đăng nhập lại" và chú nhỏ.
// Không có nút đóng (X): người dùng chỉ có một việc là đăng nhập lại.
import { Dialog } from 'radix-ui';
import type { ReactNode } from 'react';
import { Button } from '../../ui/Button';
import { AuthBigIcon, AuthNote } from './authParts';

export function SessionEndDialog({
  open,
  onClose,
  reason,
}: {
  open: boolean;
  onClose: () => void;
  /** Câu giải thích theo cổng: "Bạn không thao tác quá 60 phút nên…". */
  reason: ReactNode;
}) {
  return (
    <Dialog.Root open={open} onOpenChange={(next) => !next && onClose()}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-50 bg-neutral-900/60 backdrop-blur-[2px]" />
        <Dialog.Content
          aria-describedby="session-end-text"
          className="fixed top-1/2 left-1/2 z-50 flex w-[420px] max-w-[calc(100vw-32px)] -translate-x-1/2 -translate-y-1/2 flex-col gap-3.5 rounded-[12px] bg-surface p-7 shadow-3"
        >
          <AuthBigIcon tone="info" icon="clock" start />
          <Dialog.Title className="font-display text-[20px] leading-[1.3] font-bold">
            Phiên làm việc đã hết
          </Dialog.Title>
          <div id="session-end-text">
            <AuthNote>{reason}</AuthNote>
          </div>
          <Button variant="primary" size="xl" fullWidth onClick={onClose}>
            Đăng nhập lại
          </Button>
          <AuthNote>Đăng nhập lại xong sẽ quay về đúng trang đang mở.</AuthNote>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
