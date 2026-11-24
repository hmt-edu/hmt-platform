// Luồng lưu tệp lên kho (Google Drive qua Apps Script) cho Edge Function file-upload và file-view (F-23-49, F-23-55).
// Thiết kế docs/ke-hoach/kho-tep-apps-script.md mục 2. Phần lõi thuần (nhận các việc gọi ngoài qua `deps`) để kiểm thử bằng Drive giả, không cần Deno.
// Luật: quyền do hàm DB kiểm (file_authorize_upload / file_authorize_view) bằng token người gọi; giới hạn đọc từ tham số cài đặt (không viết số);
// chặn mềm khi dung lượng còn trống của tài khoản kho tệp dưới file_storage_min_free_gb; chặn nộp trùng bằng chỉ mục (bài, học sinh, mã băm).
// Tên tệp trên Drive là uuid của dòng stored_file (không tên học sinh); mã băm tính lại ở máy chủ (không tin giá trị trình duyệt gửi).

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
export interface StoreLike {
  save(p: { path: string[]; name: string; mimeType: string; bytes: Uint8Array }): Promise<string>;
  read(id: string): Promise<{ mimeType: string; bytes: Uint8Array }>;
  getStorageQuota(): Promise<{ usage: number; limit: number }>;
}
export interface FileDeps {
  store: StoreLike;
  /** Hàm DB bằng token người gọi; ném FlowError với mã HMT_* khi bị chặn. */
  authorizeUpload(kind: string, assignmentId: string, studentId: string | null): Promise<UploadAuth>;
  authorizeView(fileId: string): Promise<ViewAuth>;
  /** Ghi bằng khoá dịch vụ. insertPending trả 'TRUNG' khi vướng chỉ mục chặn trùng. */
  insertPending(row: PendingRow): Promise<'OK' | 'TRUNG'>;
  /** Đổi dòng CHO_TAI cũ của cùng (bài, học sinh, mã băm) thành DA_XOA; trả số dòng đổi (cho phép nộp lại sau lần tải dở). */
  supersedePending(assignmentId: string, studentId: string | null, sha256: string): Promise<number>;
  /** Đổi dòng vừa tạo (CHO_TAI) sang DA_XOA khi lưu vào kho thất bại. */
  abandon(id: string): Promise<void>;
  markReady(id: string, storageKey: string, thumbKey: string | null): Promise<void>;
  /** Dung lượng còn trống tối thiểu, tính bằng GB (file_storage_min_free_gb). */
  minFreeGb(): Promise<number>;
  sha256(bytes: Uint8Array): Promise<string>;
  decodeBase64(b64: string): Uint8Array;
  newId(): string;
  /** Năm-tháng hiện tại giờ Việt Nam, dạng YYYY-MM (tên thư mục con). */
  monthFolder(): string;
}

export interface UploadFile {
  mimeType: string;
  dataBase64: string;
  thumbBase64: string | null; // ảnh thu nhỏ WebP (rỗng với PDF)
}
export interface UploadInput {
  kind: string;
  assignmentId: string;
  studentId: string | null;
  files: UploadFile[];
}
export interface UploadResult {
  files: { id: string }[];
}

const BYTES_PER_GB = 1024 ** 3; // allow-number: đổi GB sang byte
const EXT: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'application/pdf': 'pdf' };

/** Tải lên: kiểm quyền + giới hạn + dung lượng, ghi dòng CHO_TAI, lưu vào kho (ảnh đầy và ảnh thu nhỏ), đổi dòng sang DANG_DUNG. Một lần gọi cho cả lô. */
export async function uploadFiles(deps: FileDeps, ownerUserId: string, input: UploadInput): Promise<UploadResult> {
  if (input.files.length === 0) throw new FlowError('HMT_TEP_THIEU', 'Chưa chọn tệp nào.');
  const auth = await deps.authorizeUpload(input.kind, input.assignmentId, input.studentId);
  const { limits } = auth;
  // Luật giới hạn lô: số tệp, cỡ mỗi tệp, tổng (tham số cài đặt; máy chủ kiểm lại dù giao diện đã kiểm). Cỡ tính trên byte đã giải mã.
  if (input.files.length > limits.max_count) throw new FlowError('HMT_TEP_QUA_NHIEU', `Mỗi lần nộp tối đa ${limits.max_count} tệp.`);
  const decoded: { f: UploadFile; bytes: Uint8Array; thumb: Uint8Array | null; sha: string }[] = [];
  let total = 0;
  for (const f of input.files) {
    if (!(ACCEPTED_UPLOAD_MIME as readonly string[]).includes(f.mimeType)) throw new FlowError('HMT_TEP_LOAI_SAI', 'Tệp không đúng loại (nhận JPG, PNG, WebP, PDF).');
    let bytes: Uint8Array;
    let thumb: Uint8Array | null = null;
    try {
      bytes = deps.decodeBase64(f.dataBase64);
      thumb = f.thumbBase64 ? deps.decodeBase64(f.thumbBase64) : null;
    } catch {
      throw new FlowError('HMT_TEP_THIEU', 'Tệp gửi lên không đọc được, hãy chọn lại.');
    }
    if (bytes.length === 0) throw new FlowError('HMT_TEP_THIEU', 'Tệp rỗng.');
    if (bytes.length > limits.max_bytes) throw new FlowError('HMT_TEP_QUA_LON', 'Có tệp quá lớn.');
    total += bytes.length + (thumb?.length ?? 0);
    decoded.push({ f, bytes, thumb, sha: await deps.sha256(bytes) });
  }
  if (total > limits.max_total_bytes) throw new FlowError('HMT_TEP_TONG_QUA_LON', 'Tổng dung lượng các tệp quá lớn.');

  // Luật chặn mềm dung lượng: còn trống dưới mức tối thiểu thì chặn tải mới (không tự phát sinh tiền, thiết kế mục 6).
  const [quota, minFreeGb] = await Promise.all([deps.store.getStorageQuota(), deps.minFreeGb()]);
  // Hạn mức 0 là tài khoản không giới hạn (không chặn). Còn trống = hạn mức trừ đã dùng (gồm cả sao lưu đêm và thư) trừ lô sắp tải.
  if (quota.limit > 0 && quota.limit - quota.usage - total < minFreeGb * BYTES_PER_GB) {
    throw new FlowError('HMT_KHO_TEP_DAY', 'Kho lưu trữ đang gần đầy, chưa nhận thêm ảnh. Báo quản trị viên.', 503); // allow-number: mã HTTP
  }

  const result: UploadResult = { files: [] };
  // Bước 1 (tuần tự): ghi dòng CHO_TAI cho từng tệp, vì chặn nộp trùng dựa vào chỉ mục duy nhất nên phải theo thứ tự.
  const pending: { id: string; d: (typeof decoded)[number] }[] = [];
  const abandonAll = async (): Promise<void> => {
    await Promise.all(pending.map((p) => deps.abandon(p.id)));
  };
  for (const d of decoded) {
    const id = deps.newId();
    const row: PendingRow = {
      id,
      storage_key: `pending:${id}`,
      thumb_storage_key: d.thumb ? `pending:${id}:t` : null,
      sha256: d.sha,
      kind: auth.kind,
      branch_id: auth.branch_id,
      class_id: auth.class_id,
      assignment_id: auth.assignment_id,
      submission_id: auth.submission_id,
      student_id: auth.student_id,
      owner_user_id: ownerUserId,
      mime_type: d.f.mimeType,
      size_bytes: d.bytes.length,
      is_color: auth.is_color,
      delete_after: auth.delete_after,
    };
    let state = await deps.insertPending(row);
    if (state === 'TRUNG') {
      // Lần tải dở trước (CHO_TAI) thì cho nộp lại; trùng với ảnh đã nộp thật thì báo.
      const freed = await deps.supersedePending(auth.assignment_id, auth.student_id, d.sha);
      state = freed > 0 ? await deps.insertPending(row) : 'TRUNG';
    }
    if (state === 'TRUNG') {
      await abandonAll(); // trả các dòng đã ghi trong lô này về DA_XOA để nộp lại được
      throw new FlowError('HMT_TEP_TRUNG', 'Ảnh này đã nộp rồi.', 409); // allow-number: mã HTTP xung đột
    }
    pending.push({ id, d });
  }
  // Bước 2 (song song): mỗi lần gọi kho mất vài giây (đo 25/11: ~5 giây/lần, không phụ thuộc cỡ ảnh), nên ảnh đầy và ảnh thu nhỏ của mọi tệp lưu cùng lúc
  // thay vì lần lượt (trước đó ~3 lần gọi nối tiếp mỗi ảnh). Tệp nào lưu hỏng thì dòng của nó về DA_XOA; các tệp đã lưu xong giữ nguyên.
  const folder = [auth.class_id, deps.monthFolder()]; // thư mục con: lớp / năm-tháng (uuid và số, không tên học sinh)
  const settled = await Promise.allSettled(
    pending.map(async ({ id, d }) => {
      try {
        const [storageKey, thumbKey] = await Promise.all([
          deps.store.save({ path: folder, name: `${id}.${EXT[d.f.mimeType]}`, mimeType: d.f.mimeType, bytes: d.bytes }),
          d.thumb ? deps.store.save({ path: folder, name: `${id}-t.webp`, mimeType: 'image/webp', bytes: d.thumb }) : Promise.resolve(null),
        ]);
        await deps.markReady(id, storageKey, thumbKey);
      } catch (e) {
        await deps.abandon(id); // lưu hỏng: trả dòng về DA_XOA để nộp lại được, không để dòng CHO_TAI treo
        throw e;
      }
    }),
  );
  const failed = settled.find((r): r is PromiseRejectedResult => r.status === 'rejected');
  if (failed) throw failed.reason;
  for (const p of pending) result.files.push({ id: p.id });
  return result;
}

/** Xem tệp: hàm DB kiểm quyền (nhân viên theo bài giao, học sinh chủ ảnh, phụ huynh của em), Edge Function làm trung gian đọc từ kho. */
export async function viewFile(deps: FileDeps, input: { id: string; thumb: boolean }): Promise<{ bytes: Uint8Array; mimeType: string }> {
  const v = await deps.authorizeView(input.id);
  const useThumb = input.thumb && v.thumb_storage_key !== null;
  const r = await deps.store.read(useThumb ? (v.thumb_storage_key as string) : v.storage_key);
  return { bytes: r.bytes, mimeType: useThumb ? 'image/webp' : v.mime_type };
}
