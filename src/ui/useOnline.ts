import { useSyncExternalStore } from 'react';

// Báo trình duyệt đang có mạng hay không (sự kiện online/offline). Dùng để hiện dải «Mất kết nối» (T2-B, mất mạng không báo).
function subscribe(onChange: () => void): () => void {
  window.addEventListener('online', onChange);
  window.addEventListener('offline', onChange);
  return () => {
    window.removeEventListener('online', onChange);
    window.removeEventListener('offline', onChange);
  };
}

export function useOnline(): boolean {
  return useSyncExternalStore(
    subscribe,
    () => navigator.onLine,
    () => true,
  );
}
