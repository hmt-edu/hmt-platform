import { afterEach, describe, expect, it, vi } from 'vitest';
import { hasNewVersion, isChunkLoadError, reloadOnStaleChunk } from './chunkReload';

const stale = new TypeError('Failed to fetch dynamically imported module: /assets/MfaPages-abc.js');

describe('B-27-05 tệp màn cũ sau khi cập nhật bản mới', () => {
  afterEach(() => window.sessionStorage.clear());

  it('nhận ra câu lỗi của các trình duyệt', () => {
    expect(isChunkLoadError(stale)).toBe(true);
    expect(isChunkLoadError(new TypeError('Importing a module script failed.'))).toBe(true);
    expect(
      isChunkLoadError(new TypeError("'text/html' is not a valid JavaScript MIME type.")),
    ).toBe(true);
    expect(isChunkLoadError(new TypeError('x is undefined'))).toBe(false);
  });

  const yes = () => Promise.resolve(true);

  it('tự tải lại một lần, lỗi tiếp ngay sau đó thì không lặp', async () => {
    const reload = vi.fn();
    const deps = { reload, isNewVersion: yes };
    expect(await reloadOnStaleChunk(stale, { ...deps, now: 1_000_000 })).toBe(true);
    expect(await reloadOnStaleChunk(stale, { ...deps, now: 1_001_000 })).toBe(false);
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('lỗi khác, hoặc máy chủ chưa có bản mới (đang chuyển trang), thì không tải lại', async () => {
    const reload = vi.fn();
    expect(await reloadOnStaleChunk(new Error('khác'), { reload, isNewVersion: yes })).toBe(false);
    expect(
      await reloadOnStaleChunk(stale, { reload, isNewVersion: () => Promise.resolve(false) }),
    ).toBe(false);
    expect(reload).not.toHaveBeenCalled();
  });

  it('so tệp gốc của index.html để biết có bản mới', async () => {
    const page = (src: string) => () =>
      Promise.resolve(new Response(`<script type="module" crossorigin src="${src}"></script>`));
    expect(await hasNewVersion('/assets/index-a.js', page('/assets/index-b.js'))).toBe(true);
    expect(await hasNewVersion('/assets/index-a.js', page('/assets/index-a.js'))).toBe(false);
    expect(
      await hasNewVersion('/assets/index-a.js', () => Promise.reject(new Error('mất mạng'))),
    ).toBe(false);
  });
});
