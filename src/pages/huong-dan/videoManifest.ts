// Danh sách video hướng dẫn (A-23-41b). Video KHÔNG nằm trong repo: file public/huong-dan/video-manifest.json ghi mã bài → nơi lưu.
// Đổi nơi lưu (Drive, R2, máy chủ khác) chỉ sửa file manifest, không sửa code.
// Dạng: { "videos": { "ma-bai": { "drive": "<ID file Drive>" } | { "url": "https://…/x.mp4" } | { "url": "/huong-dan/video/x.mp4" } } }

export type VideoSource =
  | { kind: 'drive'; src: string } // khung xem trước của Google Drive (iframe)
  | { kind: 'file'; src: string }; // tệp mp4 trực tiếp (thẻ video)

export type VideoManifest = Record<string, VideoSource>;

const DRIVE_ID = /^[A-Za-z0-9_-]{10,}$/;

/** Chỉ nhận đường dẫn cùng máy chủ («/…») hoặc https; chặn «//», javascript:, data:. */
export function safeVideoUrl(url: unknown): string | null {
  if (typeof url !== 'string') return null;
  if (url.startsWith('/') && !url.startsWith('//')) return url;
  if (url.startsWith('https://')) return url;
  return null;
}

/** Đọc manifest từ JSON không tin cậy; dòng hỏng bị bỏ qua (bài đó hiện «Video đang cập nhật»). */
export function parseVideoManifest(raw: unknown): VideoManifest {
  const out: VideoManifest = {};
  if (typeof raw !== 'object' || raw === null) return out;
  const videos = (raw as { videos?: unknown }).videos;
  if (typeof videos !== 'object' || videos === null) return out;
  for (const [name, entry] of Object.entries(videos)) {
    if (typeof entry !== 'object' || entry === null) continue;
    const e = entry as { drive?: unknown; url?: unknown };
    if (typeof e.drive === 'string' && DRIVE_ID.test(e.drive)) {
      out[name] = { kind: 'drive', src: `https://drive.google.com/file/d/${e.drive}/preview` };
      continue;
    }
    const url = safeVideoUrl(e.url);
    if (url) out[name] = { kind: 'file', src: url };
  }
  return out;
}

export const VIDEO_MANIFEST_PATH = '/huong-dan/video-manifest.json';

export async function loadVideoManifest(): Promise<VideoManifest> {
  try {
    const res = await fetch(VIDEO_MANIFEST_PATH, { cache: 'no-cache' });
    if (!res.ok) return {};
    return parseVideoManifest(await res.json());
  } catch {
    // Mất mạng hoặc máy chủ trả trang HTML thay cho JSON: coi như chưa có video nào.
    return {};
  }
}
