import { useCallback, useRef, useState } from 'react';

// K1: nút «Làm mới» phải cho thấy đang tải, kể cả khi dữ liệu về gần như ngay.
const MIN_BUSY_MS = 500; // allow-number: thời gian quay tối thiểu của nút, không phải số nghiệp vụ

/** Kết quả refetch của React Query không ném lỗi mà trả isError; gộp nhiều lời gọi thì là mảng. */
function hasError(result: unknown): boolean {
  if (Array.isArray(result)) return result.some(hasError);
  return typeof result === 'object' && result !== null && 'isError' in result && !!result.isError;
}

export type RefreshState = {
  busy: boolean;
  failed: boolean;
  updatedAt: Date | null;
  refresh: () => void;
};

export function useRefreshAction(onRefresh: (() => unknown) | undefined): RefreshState {
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null);
  const running = useRef(false);

  const run = useCallback(async () => {
    if (!onRefresh || running.current) return; // chặn bấm đúp
    running.current = true;
    setBusy(true);
    setFailed(false);
    const minimum = new Promise((resolve) => setTimeout(resolve, MIN_BUSY_MS));
    let ok: boolean;
    try {
      ok = !hasError(await onRefresh());
    } catch (error) {
      console.error('[HMT] Làm mới lỗi:', error);
      ok = false;
    }
    await minimum;
    if (ok) setUpdatedAt(new Date());
    setFailed(!ok);
    setBusy(false);
    running.current = false;
  }, [onRefresh]);

  return { busy, failed, updatedAt, refresh: () => void run() };
}
