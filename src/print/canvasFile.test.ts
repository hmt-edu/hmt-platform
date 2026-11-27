import { afterEach, describe, expect, it, vi } from 'vitest';
import { canShareImages, shareOrDownloadCanvas, shareOrDownloadCanvases } from './canvasFile';

const canvas = {
  toBlob: (done: (b: Blob) => void) => done(new Blob(['x'], { type: 'image/png' })),
} as unknown as HTMLCanvasElement;

function setup(touch: boolean, share?: () => Promise<void>) {
  const clicked: string[] = [];
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (
    this: HTMLAnchorElement,
  ) {
    clicked.push(this.download);
  });
  URL.createObjectURL = vi.fn(() => 'blob:x');
  URL.revokeObjectURL = vi.fn();
  vi.stubGlobal('matchMedia', () => ({ matches: touch }));
  Object.assign(navigator, { canShare: share ? () => true : undefined, share });
  return clicked;
}

describe('Tải ảnh (PNG) của bản in', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it('máy tính: tải tệp .png, không mở bảng chia sẻ', async () => {
    const share = vi.fn(() => Promise.resolve());
    const clicked = setup(false, share);
    await expect(shareOrDownloadCanvas(canvas, 'BG1.png')).resolves.toBe('downloaded');
    expect(clicked).toEqual(['BG1.png']);
    expect(share).not.toHaveBeenCalled();
  });

  it('điện thoại có chia sẻ tệp: mở bảng chia sẻ, không tải', async () => {
    const clicked = setup(true, () => Promise.resolve());
    await expect(shareOrDownloadCanvas(canvas, 'BG1.png')).resolves.toBe('shared');
    expect(clicked).toEqual([]);
  });

  it('đóng bảng chia sẻ thì thôi; bị từ chối thì tải về', async () => {
    const aborted = setup(true, () => Promise.reject(new DOMException('', 'AbortError')));
    await expect(shareOrDownloadCanvas(canvas, 'BG1.png')).resolves.toBe('cancelled');
    expect(aborted).toEqual([]);
    vi.restoreAllMocks();
    const refused = setup(true, () => Promise.reject(new DOMException('', 'NotAllowedError')));
    await expect(shareOrDownloadCanvas(canvas, 'BG1.png')).resolves.toBe('downloaded');
    expect(refused).toEqual(['BG1.png']);
  });

  it('nhiều ảnh (xuất cả lớp): một lần chia sẻ gửi đủ các tệp', async () => {
    const share = vi.fn<(data: ShareData) => Promise<void>>().mockResolvedValue(undefined);
    setup(true, share as unknown as () => Promise<void>);
    expect(canShareImages()).toBe(true);
    await shareOrDownloadCanvases([
      { canvas, fileName: 'a.png' },
      { canvas, fileName: 'b.png' },
    ]);
    expect(share).toHaveBeenCalledTimes(1);
    expect(share.mock.calls[0]?.[0].files?.map((f) => f.name)).toEqual(['a.png', 'b.png']);
  });

  it('máy tính không có nút chia sẻ', () => {
    setup(false, () => Promise.resolve());
    expect(canShareImages()).toBe(false);
  });
});
