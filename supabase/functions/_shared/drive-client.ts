// Lớp gọi Google Drive cho Edge Function (F-23-49; thiết kế docs/ke-hoach/luu-tru-tep-drive.md).
// OAuth refresh token của tài khoản vận hành + scope drive.file. Mọi lời gọi mạng đi qua `fetch` truyền vào để thay bằng giả lập khi kiểm thử.
// Khoá (client id, client secret, refresh token) chỉ đến từ secret của Edge Function, không bao giờ vào log hay phản hồi.
// Có hai nơi lỗi: DriveError (kèm mã HMT_*) để Edge Function trả câu tiếng Việt cho giao diện.

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export interface DriveConfig {
  clientId: string;
  clientSecret: string;
  refreshToken: string;
}

export class DriveError extends Error {
  constructor(
    public code: string,
    message: string,
    public status?: number,
  ) {
    super(message);
  }
}

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const API = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3/files';
const FOLDER_MIME = 'application/vnd.google-apps.folder';
const RETRY_ATTEMPTS = 3; // allow-number: thử lại tối đa 3 lần (thiết kế Drive mục 5)
const RETRY_BASE_MS = 500; // allow-number: chờ tăng dần từ 0,5 giây
const TOKEN_MARGIN_MS = 60_000; // allow-number: đổi token sớm 1 phút trước khi hết hạn
const HTTP_TOO_MANY = 429; // allow-number: mã HTTP
const HTTP_SERVER_ERROR = 500; // allow-number: mã HTTP
const HTTP_FORBIDDEN = 403; // allow-number: mã HTTP

/** Lỗi nào đáng thử lại: 429, 5xx, hoặc 403 do quá hạn mức tốc độ (không phải hết dung lượng). */
export function isRetryable(status: number, reason: string | undefined): boolean {
  if (status === HTTP_TOO_MANY || status >= HTTP_SERVER_ERROR) return true;
  return status === HTTP_FORBIDDEN && (reason === 'rateLimitExceeded' || reason === 'userRateLimitExceeded');
}

export function createDriveClient(config: DriveConfig, fetchFn: FetchLike = fetch, sleep: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms)), now: () => number = Date.now) {
  let token: { value: string; expiresAt: number } | null = null;

  async function accessToken(): Promise<string> {
    if (token && token.expiresAt - TOKEN_MARGIN_MS > now()) return token.value;
    const res = await fetchFn(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        client_id: config.clientId,
        client_secret: config.clientSecret,
        refresh_token: config.refreshToken,
      }),
    });
    const body = (await res.json().catch(() => ({}))) as { access_token?: string; expires_in?: number; error?: string };
    if (!res.ok || !body.access_token) {
      // invalid_grant: token bị thu hồi hoặc hết hạn (thiết kế mục 1): báo Admin cấp lại.
      const revoked = body.error === 'invalid_grant';
      throw new DriveError(revoked ? 'HMT_DRIVE_HET_QUYEN' : 'HMT_DRIVE_LOI', revoked ? 'Kho tệp cần được cấp quyền lại (báo quản trị viên).' : 'Chưa kết nối được kho tệp, thử lại sau.', res.status);
    }
    token = { value: body.access_token, expiresAt: now() + (body.expires_in ?? 0) * 1000 }; // allow-number: giây sang mili giây
    return token.value;
  }

  /** Gọi Drive có thử lại: tối đa RETRY_ATTEMPTS lần, chờ tăng dần. Trả Response đã ok; lỗi khác ném DriveError. */
  async function call(url: string, init: RequestInit = {}): Promise<Response> {
    for (let attempt = 1; ; attempt++) {
      const res = await fetchFn(url, { ...init, headers: { ...(init.headers as Record<string, string>), Authorization: `Bearer ${await accessToken()}` } });
      if (res.ok) return res;
      const err = (await res.clone().json().catch(() => ({}))) as { error?: { errors?: Array<{ reason?: string }> } };
      const reason = err.error?.errors?.[0]?.reason;
      if (reason === 'storageQuotaExceeded') throw new DriveError('HMT_DRIVE_DAY', 'Kho tệp đã đầy, báo quản trị viên.', res.status);
      if (attempt < RETRY_ATTEMPTS && isRetryable(res.status, reason)) {
        await sleep(RETRY_BASE_MS * 2 ** (attempt - 1)); // allow-number: nhân đôi thời gian chờ mỗi lần
        continue;
      }
      throw new DriveError('HMT_DRIVE_LOI', 'Tải lên chưa được, thử lại sau.', res.status);
    }
  }

  return {
    /** Tạo phiên tải tiếp được; trả địa chỉ phiên để trình duyệt PUT thẳng (cách A). origin truyền để Drive cho phép CORS. */
    async startResumableUpload(p: { name: string; mimeType: string; size: number; parentId: string; origin?: string }): Promise<string> {
      const res = await call(`${UPLOAD}?uploadType=resumable&fields=id`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': p.mimeType,
          'X-Upload-Content-Length': String(p.size),
          ...(p.origin ? { Origin: p.origin } : {}),
        },
        body: JSON.stringify({ name: p.name, parents: [p.parentId] }),
      });
      const location = res.headers.get('location');
      if (!location) throw new DriveError('HMT_DRIVE_LOI', 'Tải lên chưa được, thử lại sau.');
      return location;
    },
    /** Metadata tệp để xác nhận đúng cỡ sau khi tải (file-upload-done). */
    async getFileInfo(id: string): Promise<{ id: string; size: number; mimeType: string; trashed: boolean }> {
      const res = await call(`${API}/files/${encodeURIComponent(id)}?fields=id,size,mimeType,trashed`);
      const b = (await res.json()) as { id: string; size?: string; mimeType: string; trashed?: boolean };
      return { id: b.id, size: Number(b.size ?? 0), mimeType: b.mimeType, trashed: Boolean(b.trashed) };
    },
    /** Tải nội dung tệp (file-view làm trung gian); trả Response để chuyển tiếp dòng dữ liệu, không giữ cả tệp trong bộ nhớ. */
    async download(id: string): Promise<Response> {
      return call(`${API}/files/${encodeURIComponent(id)}?alt=media`);
    },
    /** Xoá VĨNH VIỄN (thùng rác Drive vẫn tính dung lượng). Tệp đã không còn thì coi như xong. */
    async deletePermanently(id: string): Promise<void> {
      try {
        await call(`${API}/files/${encodeURIComponent(id)}`, { method: 'DELETE' });
      } catch (e) {
        if (e instanceof DriveError && e.status === 404) return; // allow-number: mã HTTP không tìm thấy
        throw e;
      }
    },
    /** Dung lượng đang dùng và hạn mức của tài khoản (byte), cho chặn mềm 80%. */
    async getStorageQuota(): Promise<{ usage: number; limit: number }> {
      const res = await call(`${API}/about?fields=storageQuota`);
      const b = (await res.json()) as { storageQuota: { usage: string; limit?: string } };
      return { usage: Number(b.storageQuota.usage), limit: Number(b.storageQuota.limit ?? 0) };
    },
    /** Tạo thư mục con (id trả về để Edge Function nhớ). */
    async createFolder(name: string, parentId: string): Promise<string> {
      const res = await call(`${API}/files?fields=id`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ name, mimeType: FOLDER_MIME, parents: [parentId] }),
      });
      return ((await res.json()) as { id: string }).id;
    },
  };
}

export type DriveClient = ReturnType<typeof createDriveClient>;
