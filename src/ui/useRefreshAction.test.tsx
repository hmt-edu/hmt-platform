import { QueryClientProvider, useQuery } from '@tanstack/react-query';
import { act, renderHook } from '@testing-library/react';
import { createElement, type ReactNode } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { HmtQueryClient } from '../lib/query';
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

  // B-27-14: dùng invalidateQueries thật (nuốt lỗi), không giả.
  it.each([
    ['máy chủ lỗi', true],
    ['máy chủ trả được', false],
  ])('làm mới bằng invalidateQueries, %s: báo đúng kết quả', async (_, broken) => {
    const client = new HmtQueryClient({ defaultOptions: { queries: { retry: false } } });
    let fail = false;
    const wrapper = ({ children }: { children: ReactNode }) =>
      createElement(QueryClientProvider, { client }, children);
    const { result } = renderHook(
      () => {
        useQuery({
          queryKey: ['ds'],
          queryFn: () => (fail ? Promise.reject(new Error('lỗi')) : Promise.resolve(1)),
        });
        return useRefreshAction(() => client.invalidateQueries({ queryKey: ['ds'] }));
      },
      { wrapper },
    );
    await act(() => vi.advanceTimersByTimeAsync(10));
    fail = broken;
    act(() => result.current.refresh());
    await act(() => vi.advanceTimersByTimeAsync(700));
    expect(result.current.busy).toBe(false);
    expect(result.current.failed).toBe(broken);
    expect(result.current.updatedAt === null).toBe(broken);
  });
});
