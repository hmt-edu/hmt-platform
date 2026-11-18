import { afterEach, describe, expect, it, vi } from 'vitest';
import { prefetchAfterLogin } from './prefetchAfterLogin';

describe('prefetchAfterLogin (tải sẵn sau đăng nhập lúc rảnh)', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it('chế độ tiết kiệm dữ liệu: không đặt lịch tải gì', () => {
    vi.stubGlobal('navigator', { connection: { saveData: true } });
    const idle = vi.fn();
    vi.stubGlobal('requestIdleCallback', idle);
    window.requestIdleCallback = idle;
    prefetchAfterLogin()();
    expect(idle).not.toHaveBeenCalled();
  });

  it('bình thường: đặt lịch lúc rảnh và huỷ được khi rời trang', () => {
    vi.stubGlobal('navigator', {});
    const idle = vi.fn(() => 7);
    const cancel = vi.fn();
    window.requestIdleCallback = idle;
    window.cancelIdleCallback = cancel;
    const stop = prefetchAfterLogin();
    expect(idle).toHaveBeenCalledTimes(1);
    stop();
    expect(cancel).toHaveBeenCalledWith(7);
  });
});
