// @vitest-environment jsdom
import { act, renderHook } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { useOnline } from './useOnline';

describe('useOnline (dải «Mất kết nối»)', () => {
  afterEach(() => vi.restoreAllMocks());

  it('đổi theo sự kiện offline rồi online của trình duyệt', () => {
    let on = true;
    vi.spyOn(navigator, 'onLine', 'get').mockImplementation(() => on);
    const { result } = renderHook(() => useOnline());
    expect(result.current).toBe(true);
    act(() => {
      on = false;
      window.dispatchEvent(new Event('offline'));
    });
    expect(result.current).toBe(false);
    act(() => {
      on = true;
      window.dispatchEvent(new Event('online'));
    });
    expect(result.current).toBe(true);
  });
});
