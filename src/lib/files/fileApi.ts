// Gọi kho tệp từ trình duyệt (F-24-05 PR-2): tải ảnh đã nén lên (Edge Function file-upload), xem ảnh (file-view, GET để trình duyệt giữ bộ nhớ đệm riêng),
// chốt lần nộp bài (hàm DB lms_submit_assignment). Quyền do máy chủ kiểm; ở đây chỉ gọi, báo tiến trình và thử lại khi lỗi mạng.
import type { SupabaseClient } from '@supabase/supabase-js';
import { callFunction, HmtError, rpc } from '../db';
import { getSupabaseConfig } from '../supabase';

export type UploadKind = 'BAI_NOP' | 'DINH_KEM_GV';

export interface FileToUpload {
  blob: Blob; // ảnh đã nén WebP hoặc PDF nguyên bản
  thumb: Blob | null; // ảnh thu nhỏ WebP (rỗng với PDF)
  mime: string;
}

export interface UploadArgs {
  kind: UploadKind;
  assignmentId: string;
  studentId: string | null; // BAI_NOP: chính học sinh; DINH_KEM_GV: rỗng
  files: FileToUpload[];
}

export interface SubmitResult {
  submission_id: string;
  attempt: number;
  is_late: boolean;
  submitted_at: string;
}

const BASE64_CHUNK = 0x8000; // allow-number: cỡ đoạn khi đổi byte sang chuỗi (tránh tràn ngăn xếp lời gọi)
const NETWORK_RETRIES = 2; // allow-number: thử lại khi rớt mạng (không tính lần đầu); chỉ mạng, không thử lại lỗi nghiệp vụ
const RETRY_DELAY_MS = 1500; // allow-number: chờ giữa các lần thử lại

/** Blob sang base64 (không có tiền tố data:). */
export async function blobToBase64(blob: Blob): Promise<string> {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  for (let i = 0; i < bytes.length; i += BASE64_CHUNK) {
    binary += String.fromCharCode(...bytes.subarray(i, i + BASE64_CHUNK));
  }
  return btoa(binary);
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/**
 * Tải lô tệp lên kho. Một lần gọi cho cả lô (máy chủ lưu song song). Rớt mạng (HMT_MANG) thì thử lại tối đa NETWORK_RETRIES lần;
 * lỗi nghiệp vụ (quyền, quá hạn, trùng, kho đầy...) ném ngay với câu tiếng Việt của máy chủ. Trả mã tệp theo đúng thứ tự gửi.
 * `onStage`: báo giai đoạn để giao diện hiện tiến trình («đang chuẩn bị», «đang tải lên», «thử lại lần n»).
 */
export async function uploadFiles(
  supabase: SupabaseClient,
  args: UploadArgs,
  onStage?: (stage: { phase: 'prepare' | 'upload' | 'retry'; attempt?: number }) => void,
): Promise<string[]> {
  onStage?.({ phase: 'prepare' });
  const files = await Promise.all(
    args.files.map(async (f) => ({
      mimeType: f.mime,
      dataBase64: await blobToBase64(f.blob),
      thumbBase64: f.thumb ? await blobToBase64(f.thumb) : null,
    })),
  );
  const body = {
    kind: args.kind,
    assignmentId: args.assignmentId,
    studentId: args.studentId,
    files,
  };
  for (let attempt = 0; ; attempt++) {
    onStage?.(attempt === 0 ? { phase: 'upload' } : { phase: 'retry', attempt });
    try {
      const result = await callFunction<{ files: { id: string }[] }>(supabase, 'file-upload', body);
      return result.files.map((f) => f.id);
    } catch (e) {
      if (!(e instanceof HmtError) || e.code !== 'HMT_MANG' || attempt >= NETWORK_RETRIES) throw e;
      await sleep(RETRY_DELAY_MS);
    }
  }
}

/** Xem ảnh: GET qua file-view (id và thumb trên địa chỉ) để trình duyệt tự giữ bộ nhớ đệm riêng; trả Blob, dùng URL.createObjectURL để hiện. */
export async function fetchFileBlob(
  supabase: SupabaseClient,
  id: string,
  options: { thumb?: boolean } = {},
): Promise<Blob> {
  const config = getSupabaseConfig();
  const { data } = await supabase.auth.getSession();
  if (config.status !== 'ok' || !data.session) {
    throw new HmtError('HMT_LOI', 'Có lỗi xảy ra, thử lại sau. Nếu vẫn lỗi, báo quản trị viên.');
  }
  const query = new URLSearchParams({ id });
  if (options.thumb) query.set('thumb', '1');
  let response: Response;
  try {
    response = await fetch(`${config.config.url}/functions/v1/file-view?${query.toString()}`, {
      method: 'GET',
      headers: {
        apikey: config.config.publishableKey,
        Authorization: `Bearer ${data.session.access_token}`,
      },
    });
  } catch {
    throw new HmtError('HMT_MANG', 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
  }
  if (!response.ok) {
    const payload = (await response.json().catch(() => ({}))) as {
      error?: { code?: string; message?: string };
    };
    throw new HmtError(
      payload.error?.code ?? 'HMT_LOI',
      payload.error?.message ?? 'Chưa mở được ảnh, thử lại sau.',
    );
  }
  return response.blob();
}

/** Chốt lần nộp: gắn các ảnh đã tải (đúng thứ tự trang) vào bài nộp. Luật quá hạn, nộp lại, đã chấm do hàm DB kiểm. */
export function submitAssignment(
  supabase: SupabaseClient,
  assignmentId: string,
  fileIds: string[],
): Promise<SubmitResult> {
  return rpc<SubmitResult>(supabase, 'lms_submit_assignment', {
    p_assignment_id: assignmentId,
    p_file_ids: fileIds,
  });
}
