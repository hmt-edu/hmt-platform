import { afterEach, describe, expect, it, vi } from 'vitest';
import { isChunkLoadError, reloadOnStaleChunk } from './chunkReload';

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

  it('tự tải lại một lần, lỗi tiếp ngay sau đó thì không lặp', () => {
    const reload = vi.fn();
    expect(reloadOnStaleChunk(stale, reload, 1_000_000)).toBe(true);
    expect(reloadOnStaleChunk(stale, reload, 1_001_000)).toBe(false);
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('lỗi khác thì không tải lại', () => {
    const reload = vi.fn();
    expect(reloadOnStaleChunk(new Error('khác'), reload)).toBe(false);
    expect(reload).not.toHaveBeenCalled();
  });
});
