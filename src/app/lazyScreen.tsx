import { lazy, Suspense, type ComponentType } from 'react';
import { Spinner } from '../ui/Feedback';
import { reloadOnStaleChunk } from './chunkReload';

/**
 * Tách gói tải theo cổng và theo màn (CLAUDE.md, Hiệu năng): mã của màn chỉ tải khi mở màn đó.
 * Trong lúc tải hiện trạng thái "Đang tải…", không để trang trống.
 * Dùng: `lazyScreen(() => import('../layout/CrmShell'), 'CrmShell')`.
 */
export function lazyScreen<M extends Record<K, ComponentType<never>>, K extends string>(
  load: () => Promise<M>,
  name: K,
): M[K] {
  const Screen = lazy(() =>
    load().then(
      (m) => ({ default: m[name] as unknown as ComponentType<Record<string, unknown>> }),
      (error: unknown) => {
        // Tệp màn của bản cũ không còn (B-27-05): tải lại trang, giữ vòng quay cho tới khi trang mới lên.
        if (reloadOnStaleChunk(error)) return new Promise<never>(() => {});
        throw error;
      },
    ),
  );
  function LazyScreen(props: Record<string, unknown>) {
    return (
      <Suspense
        fallback={
          <div className="flex min-h-40 items-center justify-center p-4">
            <Spinner />
          </div>
        }
      >
        <Screen {...props} />
      </Suspense>
    );
  }
  return LazyScreen as unknown as M[K];
}
