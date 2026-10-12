import { QueryClient } from '@tanstack/react-query';

const STALE_MS = 60_000; // allow-number: dữ liệu khung (quyền, cơ sở) coi là mới trong một phút

export const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: STALE_MS, retry: 1, refetchOnWindowFocus: true } },
});
