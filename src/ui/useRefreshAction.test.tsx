import { act, renderHook } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useRefreshAction } from './useRefreshAction';

describe('K1 nút «Làm mới» có trạng thái đang tải', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('quay tối thiểu nửa giây dù dữ liệu về ngay, bấm đúp chỉ tải một lần, xong ghi giờ cập nhật', async () => {
    const onRefresh = vi.fn(() => Promise.resolve());
    const { result } = renderHook(() => useRefreshAction(onRefresh));
    act(() => {
      result.current.refresh();
      result.current.refresh();
    });
    await act(() => vi.advanceTimersByTimeAsync(499));
    expect(result.current.busy).toBe(true);
    await act(() => vi.advanceTimersByTimeAsync(1));
    expect(result.current.busy).toBe(false);
    expect(result.current.updatedAt).not.toBeNull();
    expect(onRefresh).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['ném lỗi', () => Promise.reject(new Error('mất mạng'))],
    ['trả isError', () => Promise.resolve([{ isError: false }, { isError: true }])],
  ])('tải lỗi (%s): ngừng quay, báo lỗi, không ghi giờ, bấm lại được', async (_, fail) => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const onRefresh = vi.fn(fail);
    const { result } = renderHook(() => useRefreshAction(onRefresh));
    act(() => result.current.refresh());
    await act(() => vi.advanceTimersByTimeAsync(500));
    expect(result.current).toMatchObject({ busy: false, failed: true, updatedAt: null });
    act(() => result.current.refresh());
    expect(onRefresh).toHaveBeenCalledTimes(2);
    await act(() => vi.advanceTimersByTimeAsync(500));
  });
});
