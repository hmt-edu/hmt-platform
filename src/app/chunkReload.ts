// B-27-05: mã mỗi màn tải riêng theo tên tệp có mã băm. Sau mỗi lần đưa bản mới lên, tệp cũ không còn và Cloudflare Pages trả
// trang HTML (200) thay cho tệp JS, nên tab mở từ trước sẽ lỗi khi mở màn chưa tải. Tải lại trang là lấy được bản mới.

const KEY = 'hmt-chunk-reload-at';
const MIN_GAP_MS = 60_000; // allow-number: khoảng cách tối thiểu giữa hai lần tự tải lại, chống lặp vô tận (không phải số nghiệp vụ)

// Câu lỗi tải mô-đun của Chrome, Firefox, Safari và của Vite khi tải trước CSS.
const CHUNK_ERROR =
  /dynamically imported module|importing a module script failed|valid JavaScript MIME type|unable to preload/i;

export function isChunkLoadError(error: unknown): boolean {
  return error instanceof Error && CHUNK_ERROR.test(error.message);
}

/** Tự tải lại trang một lần khi lỗi do tệp cũ; trả false nếu không phải lỗi đó hoặc vừa tải lại xong (để hiện khung lỗi). */
export function reloadOnStaleChunk(
  error: unknown,
  reload: () => void = () => window.location.reload(),
  now: number = Date.now(),
): boolean {
  if (!isChunkLoadError(error)) return false;
  try {
    const last = Number(window.sessionStorage.getItem(KEY) ?? 0);
    if (now - last < MIN_GAP_MS) return false;
    window.sessionStorage.setItem(KEY, String(now));
  } catch {
    return false; // Không ghi được dấu thì không tự tải lại, tránh lặp.
  }
  reload();
  return true;
}
