// Lưu một canvas thành tệp PNG ngay trên trình duyệt (không qua máy chủ), dùng chung cho phiếu nhận xét (GV-07X) và các bản in K13.

function toPngBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
      else reject(new Error('Không tạo được ảnh.'));
    }, 'image/png');
  });
}

function saveBlob(blob: Blob, fileName: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = fileName;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

/** Tải canvas về máy dạng PNG. */
export async function downloadCanvas(canvas: HTMLCanvasElement, fileName: string): Promise<void> {
  saveBlob(await toPngBlob(canvas), fileName);
}

/** Điện thoại (màn cảm ứng) chia sẻ được tệp ảnh (bảng chia sẻ có Zalo). */
export function canShareImages(files?: File[]): boolean {
  const touch = window.matchMedia?.('(pointer: coarse)').matches ?? false;
  const probe = files ?? [new File([''], 'anh.png', { type: 'image/png' })];
  return touch && (navigator.canShare?.({ files: probe }) ?? false);
}

/**
 * Điện thoại có chia sẻ tệp thì mở bảng chia sẻ một lần cho mọi ảnh (gửi thẳng Zalo), không thì tải từng tệp về.
 * Người dùng đóng bảng chia sẻ thì thôi; trình duyệt từ chối chia sẻ thì tải về.
 */
export async function shareOrDownloadCanvases(
  images: { canvas: HTMLCanvasElement; fileName: string }[],
): Promise<'shared' | 'downloaded' | 'cancelled'> {
  const files: File[] = [];
  for (const { canvas, fileName } of images) {
    files.push(new File([await toPngBlob(canvas)], fileName, { type: 'image/png' }));
  }
  if (canShareImages(files)) {
    try {
      await navigator.share({ files });
      return 'shared';
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') return 'cancelled';
    }
  }
  for (const file of files) saveBlob(file, file.name);
  return 'downloaded';
}

export function shareOrDownloadCanvas(canvas: HTMLCanvasElement, fileName: string) {
  return shareOrDownloadCanvases([{ canvas, fileName }]);
}
