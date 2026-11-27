import { QueryClientContext, type QueryClient } from '@tanstack/react-query';
import { useCallback, useContext, useRef, useState } from 'react';

// K1: nút «Làm mới» phải cho thấy đang tải, kể cả khi dữ liệu về gần như ngay.
const MIN_BUSY_MS = 500; // allow-number: thời gian quay tối thiểu của nút, không phải số nghiệp vụ

/** Kết quả refetch của React Query không ném lỗi mà trả isError; gộp nhiều lời gọi thì là mảng. */
function hasError(result: unknown): boolean {
  if (Array.isArray(result)) return result.some(hasError);
  return typeof result === 'object' && result !== null && 'isError' in result && !!result.isError;
}

const POLL_MS = 100; // allow-number: nhịp hỏi lại xem truy vấn đã tải xong chưa

const pause = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * `invalidateQueries` nuốt lỗi (B-27-14) nên không tin kết quả trả về: chờ các truy vấn đang hiện tải xong rồi đọc trạng thái.
 * Lỗi mới kể từ lúc bấm, hoặc bị treo vì mất mạng, đều là làm mới không được.
 */
async function queriesFailed(client: QueryClient, since: number): Promise<boolean> {
  while (client.isFetching({ type: 'active' }) > 0) await pause(POLL_MS);
  return client
    .getQueryCache()
    .findAll({ type: 'active' })
    .some((q) => q.state.fetchStatus === 'paused' || q.state.errorUpdatedAt >= since);
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
  const client = useContext(QueryClientContext);

  const run = useCallback(async () => {
    if (!onRefresh || running.current) return; // chặn bấm đúp
    running.current = true;
    setBusy(true);
    setFailed(false);
    const since = Date.now();
    const minimum = pause(MIN_BUSY_MS);
    let ok: boolean;
    try {
      ok = !hasError(await onRefresh());
    } catch (error) {
      console.error('[HMT] Làm mới lỗi:', error);
      ok = false;
    }
    await minimum;
    if (ok && client) ok = !(await queriesFailed(client, since));
    if (ok) setUpdatedAt(new Date());
    setFailed(!ok);
    setBusy(false);
    running.current = false;
  }, [onRefresh, client]);

  return { busy, failed, updatedAt, refresh: () => void run() };
}
