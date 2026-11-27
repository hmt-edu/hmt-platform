// Nút «Tải ảnh (PNG)» cạnh «Tải PDF» của mọi bản in K13: chụp tờ giấy đang hiện thành ảnh để gửi Zalo.
// Phần vẽ ảnh nạp khi bấm (không tăng dung lượng lúc mở bản in).
import { useState } from 'react';
import { Button } from '../ui/Button';
import { useToast } from '../ui/toastContext';

export function PrintImageButton({ code }: { code: string }) {
  const toast = useToast();
  const [busy, setBusy] = useState(false);

  async function exportImage() {
    const sheet = document.querySelector<HTMLElement>('.k13-paper');
    if (!sheet) return;
    setBusy(true);
    try {
      const [{ captureSheet }, { shareOrDownloadCanvas }] = await Promise.all([
        import('./captureSheet'),
        import('./canvasFile'),
      ]);
      await shareOrDownloadCanvas(await captureSheet(sheet), `${code}.png`);
    } catch {
      toast({ tone: 'danger', title: 'Chưa tạo được ảnh. Thử lại, hoặc dùng «Tải PDF».' });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Button icon="file" loading={busy} onClick={() => void exportImage()}>
      Tải ảnh (PNG)
    </Button>
  );
}
