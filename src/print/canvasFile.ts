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

/**
 * Điện thoại (màn cảm ứng) có chia sẻ tệp thì mở bảng chia sẻ (gửi thẳng Zalo), không thì tải về.
 * Người dùng đóng bảng chia sẻ thì thôi; trình duyệt từ chối chia sẻ thì tải về.
 */
export async function shareOrDownloadCanvas(
  canvas: HTMLCanvasElement,
  fileName: string,
): Promise<'shared' | 'downloaded' | 'cancelled'> {
  const blob = await toPngBlob(canvas);
  const file = new File([blob], fileName, { type: 'image/png' });
  const touch = window.matchMedia?.('(pointer: coarse)').matches ?? false;
  if (touch && navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file] });
      return 'shared';
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') return 'cancelled';
    }
  }
  saveBlob(blob, fileName);
  return 'downloaded';
}
