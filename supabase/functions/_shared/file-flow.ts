// Luồng lưu tệp lên kho (Google Drive) cho Edge Function file-upload-start, file-upload-done, file-view (F-23-49).
// Thiết kế docs/ke-hoach/luu-tru-tep-drive.md mục 2, 3. Phần lõi thuần (nhận các việc gọi ngoài qua `deps`) để kiểm thử bằng Drive giả, không cần Deno.
// Luật: quyền do hàm DB kiểm (file_authorize_upload / file_authorize_view) bằng token người gọi; giới hạn đọc từ tham số cài đặt (không viết số);
// chặn mềm khi dung lượng còn trống của tài khoản kho tệp dưới file_storage_min_free_gb; chặn nộp trùng bằng chỉ mục (bài, học sinh, mã băm).
// Tên tệp trên Drive là uuid của dòng stored_file (không tên học sinh); lúc `done` kiểm tên + cỡ để gắn đúng tệp Drive với đúng dòng sổ.

export class FlowError extends Error {
  constructor(
    public code: string,
    message: string,
    public status = 400, // allow-number: mã HTTP mặc định cho lỗi nghiệp vụ
  ) {
    super(message);
  }
}

export const ACCEPTED_UPLOAD_MIME = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'] as const;

export interface UploadAuth {
  branch_id: string;
  class_id: string;
  assignment_id: string;
  kind: 'BAI_NOP' | 'DINH_KEM_GV';
  submission_id: string | null;
  student_id: string | null;
  is_color: boolean;
  delete_after: string;
  limits: { max_bytes: number; max_count: number; max_total_bytes: number };
}
export interface ViewAuth {
  storage_key: string;
  thumb_storage_key: string | null;
  mime_type: string;
  size_bytes: number;
}
export interface PendingRow {
  id: string;
  storage_key: string;
  thumb_storage_key: string | null;
  sha256: string;
  kind: string;
  branch_id: string;
  class_id: string;
  assignment_id: string;
  submission_id: string | null;
  student_id: string | null;
  owner_user_id: string | null;
  mime_type: string;
  size_bytes: number;
  is_color: boolean;
  delete_after: string;
}
export interface DriveLike {
  startResumableUpload(p: { name: string; mimeType: string; size: number; parentId: string; origin?: string }): Promise<string>;
  getFileInfo(id: string): Promise<{ id: string; name: string; size: number; mimeType: string; trashed: boolean }>;
  getStorageQuota(): Promise<{ usage: number; limit: number }>;
  download(id: string): Promise<Response>;
}
export interface FileDeps {
  drive: DriveLike;
  rootFolderId: string;
  /** Hàm DB bằng token người gọi; ném FlowError với mã HMT_* khi bị chặn. */
  authorizeUpload(kind: string, assignmentId: string, studentId: string | null): Promise<UploadAuth>;
  authorizeView(fileId: string): Promise<ViewAuth>;
  /** Ghi bằng khoá dịch vụ. insertPending trả 'TRUNG' khi vướng chỉ mục chặn trùng. */
  insertPending(row: PendingRow): Promise<'OK' | 'TRUNG'>;
  /** Đổi dòng CHO_TAI cũ của cùng (bài, học sinh, mã băm) thành DA_XOA; trả số dòng đổi (cho phép nộp lại sau lần tải dở). */
  supersedePending(assignmentId: string, studentId: string | null, sha256: string): Promise<number>;
  getPending(id: string, ownerUserId: string): Promise<(PendingRow & { status: string }) | null>;
  markReady(id: string, storageKey: string, thumbKey: string | null): Promise<void>;
  /** Dung lượng còn trống tối thiểu, tính bằng GB (file_storage_min_free_gb). */
  minFreeGb(): Promise<number>;
  newId(): string;
}

export interface StartFile {
  mimeType: string;
  size: number;
  sha256: string;
  thumbSize: number | null; // có ảnh thu nhỏ (WebP) thì kèm cỡ
}
export interface StartInput {
  kind: string;
  assignmentId: string;
  studentId: string | null;
  files: StartFile[];
  origin?: string;
}
export interface StartResult {
  files: { id: string; uploadUrl: string; thumbUploadUrl: string | null }[];
}

const SHA_RE = /^[0-9a-f]{64}$/;
const BYTES_PER_GB = 1024 ** 3; // allow-number: đổi GB sang byte

/** Bắt đầu tải lên: kiểm quyền + giới hạn + dung lượng, ghi dòng CHO_TAI, mở phiên tải Drive cho từng tệp. */
export async function startUpload(deps: FileDeps, ownerUserId: string, input: StartInput): Promise<StartResult> {
  if (input.files.length === 0) throw new FlowError('HMT_TEP_THIEU', 'Chưa chọn tệp nào.');
  const auth = await deps.authorizeUpload(input.kind, input.assignmentId, input.studentId);
  const { limits } = auth;
  // Luật giới hạn lô: số tệp, cỡ mỗi tệp, tổng (tham số cài đặt; máy chủ kiểm lại dù giao diện đã kiểm).
  if (input.files.length > limits.max_count) throw new FlowError('HMT_TEP_QUA_NHIEU', `Mỗi lần nộp tối đa ${limits.max_count} tệp.`);
  let total = 0;
  for (const f of input.files) {
    if (!(ACCEPTED_UPLOAD_MIME as readonly string[]).includes(f.mimeType)) throw new FlowError('HMT_TEP_LOAI_SAI', 'Tệp không đúng loại (nhận JPG, PNG, WebP, PDF).');
    if (!SHA_RE.test(f.sha256)) throw new FlowError('HMT_TEP_THIEU', 'Thiếu mã kiểm tệp.');
    if (!Number.isInteger(f.size) || f.size <= 0) throw new FlowError('HMT_TEP_THIEU', 'Tệp rỗng.');
    if (f.size > limits.max_bytes) throw new FlowError('HMT_TEP_QUA_LON', 'Có tệp quá lớn.');
    total += f.size + (f.thumbSize ?? 0);
  }
  if (total > limits.max_total_bytes) throw new FlowError('HMT_TEP_TONG_QUA_LON', 'Tổng dung lượng các tệp quá lớn.');

  // Luật chặn mềm dung lượng: chạm ngưỡng thì chặn tải mới (không tự phát sinh tiền, thiết kế mục 6).
  const [quota, minFreeGb] = await Promise.all([deps.drive.getStorageQuota(), deps.minFreeGb()]);
  // Hạn mức 0 là tài khoản không giới hạn (không chặn). Còn trống = hạn mức trừ đã dùng (gồm cả sao lưu đêm và thư) trừ lô sắp tải.
  if (quota.limit > 0 && quota.limit - quota.usage - total < minFreeGb * BYTES_PER_GB) {
    throw new FlowError('HMT_KHO_TEP_DAY', 'Kho lưu trữ đang gần đầy, chưa nhận thêm ảnh. Báo quản trị viên.', 503); // allow-number: mã HTTP
  }

  const result: StartResult = { files: [] };
  for (const f of input.files) {
    const id = deps.newId();
    const row: PendingRow = {
      id,
      storage_key: `pending:${id}`,
      thumb_storage_key: f.thumbSize ? `pending:${id}:t` : null,
      sha256: f.sha256,
      kind: auth.kind,
      branch_id: auth.branch_id,
      class_id: auth.class_id,
      assignment_id: auth.assignment_id,
      submission_id: auth.submission_id,
      student_id: auth.student_id,
      owner_user_id: ownerUserId,
      mime_type: f.mimeType,
      size_bytes: f.size,
      is_color: auth.is_color,
      delete_after: auth.delete_after,
    };
    let state = await deps.insertPending(row);
    if (state === 'TRUNG') {
      // Lần tải dở trước (CHO_TAI) thì cho nộp lại; trùng với ảnh đã nộp thật thì báo.
      const freed = await deps.supersedePending(auth.assignment_id, auth.student_id, f.sha256);
      state = freed > 0 ? await deps.insertPending(row) : 'TRUNG';
    }
    if (state === 'TRUNG') throw new FlowError('HMT_TEP_TRUNG', 'Ảnh này đã nộp rồi.', 409); // allow-number: mã HTTP xung đột
    const uploadUrl = await deps.drive.startResumableUpload({ name: id, mimeType: f.mimeType, size: f.size, parentId: deps.rootFolderId, origin: input.origin });
    const thumbUploadUrl = f.thumbSize
      ? await deps.drive.startResumableUpload({ name: `${id}-t`, mimeType: 'image/webp', size: f.thumbSize, parentId: deps.rootFolderId, origin: input.origin })
      : null;
    result.files.push({ id, uploadUrl, thumbUploadUrl });
  }
  return result;
}

/** Xong tải lên: kiểm tệp Drive đúng tên (uuid dòng sổ), đúng cỡ, rồi đổi dòng sang DANG_DUNG với khoá thật. Chỉ chủ dòng gọi được. */
export async function finishUpload(
  deps: FileDeps,
  ownerUserId: string,
  input: { id: string; driveId: string; thumbDriveId: string | null },
): Promise<{ id: string }> {
  const row = await deps.getPending(input.id, ownerUserId);
  if (!row || row.status !== 'CHO_TAI') throw new FlowError('HMT_TEP_KHONG_TIM_THAY', 'Không tìm thấy lượt tải lên này.', 404); // allow-number: mã HTTP
  const info = await deps.drive.getFileInfo(input.driveId);
  // Luật gắn tệp: tên tệp Drive phải là uuid của dòng sổ và cỡ phải khớp: không gắn tệp Drive của người khác.
  if (info.trashed || info.name !== row.id || info.size !== row.size_bytes) {
    throw new FlowError('HMT_TEP_KHONG_KHOP', 'Tệp tải lên chưa đầy đủ, hãy nộp lại.');
  }
  let thumbKey: string | null = null;
  if (row.thumb_storage_key) {
    if (!input.thumbDriveId) throw new FlowError('HMT_TEP_KHONG_KHOP', 'Tệp tải lên chưa đầy đủ, hãy nộp lại.');
    const t = await deps.drive.getFileInfo(input.thumbDriveId);
    if (t.trashed || t.name !== `${row.id}-t`) throw new FlowError('HMT_TEP_KHONG_KHOP', 'Tệp tải lên chưa đầy đủ, hãy nộp lại.');
    thumbKey = t.id;
  }
  await deps.markReady(row.id, info.id, thumbKey);
  return { id: row.id };
}

/** Xem tệp: hàm DB kiểm quyền (nhân viên theo bài giao, học sinh chủ ảnh, phụ huynh của em), Edge Function làm trung gian tải từ Drive. */
export async function viewFile(deps: FileDeps, input: { id: string; thumb: boolean }): Promise<{ stream: Response; mimeType: string }> {
  const v = await deps.authorizeView(input.id);
  const key = input.thumb && v.thumb_storage_key ? v.thumb_storage_key : v.storage_key;
  const stream = await deps.drive.download(key);
  return { stream, mimeType: input.thumb && v.thumb_storage_key ? 'image/webp' : v.mime_type };
}
