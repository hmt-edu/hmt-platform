// Xử lý ảnh bài nộp ở trình duyệt trước khi tải lên R2 (thiết kế docs/ke-hoach/luu-tru-tep-r2.md mục 5, F-23-46 b).
// Phần thuần (không cần canvas) để kiểm thử: tính cỡ đích, thang xám + tăng tương phản, mã băm SHA-256, kiểm lô tệp theo giới hạn.
// Phần dùng canvas (nén WebP, ảnh thu nhỏ) nằm ở imageCompress.ts.

/** Cấu hình nén: anh duyệt 24/11 (WebP thang xám ~60-65, cạnh dài ~1280, thu nhỏ ~400). Mức thật chốt sau khi thử trên ảnh vở GIẢ. */
export const FILE_COMPRESS_PROFILE = {
  maxEdge: 1280, // allow-number: cạnh dài ảnh đầy (thiết kế R2 mục 5)
  thumbEdge: 400, // allow-number: cạnh dài ảnh thu nhỏ (thiết kế R2 mục 5)
  quality: 0.62, // allow-number: chất lượng WebP 60-65 (thiết kế R2 mục 5)
  thumbQuality: 0.5, // allow-number: chất lượng WebP ảnh thu nhỏ
  contrast: 1.35, // allow-number: hệ số tăng tương phản cho chữ viết tay
} as const;

export const ACCEPTED_MIME = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'application/pdf',
] as const;

/** Cỡ đích: giữ tỉ lệ, cạnh dài không quá maxEdge, không phóng to. */
export function targetSize(
  width: number,
  height: number,
  maxEdge: number,
): { width: number; height: number } {
  if (width <= 0 || height <= 0) return { width: 0, height: 0 };
  const longest = Math.max(width, height);
  if (longest <= maxEdge) return { width, height };
  const scale = maxEdge / longest;
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  };
}

/** Đổi điểm ảnh RGBA sang thang xám và tăng tương phản quanh mức giữa (128). Sửa trực tiếp mảng, trả lại chính nó. */
export function toGrayscaleContrast(data: Uint8ClampedArray, contrast: number): Uint8ClampedArray {
  for (let i = 0; i + 3 < data.length; i += 4) {
    const gray = 0.299 * (data[i] ?? 0) + 0.587 * (data[i + 1] ?? 0) + 0.114 * (data[i + 2] ?? 0); // allow-number: hệ số độ sáng ITU-R BT.601
    const v = (gray - 128) * contrast + 128; // allow-number: mức giữa thang 0-255
    data[i] = data[i + 1] = data[i + 2] = v; // Uint8ClampedArray tự cắt về 0-255
  }
  return data;
}

/** SHA-256 dạng 64 ký tự thập lục phân thường, để chặn nộp trùng (khớp ràng buộc sha256 của bảng stored_file). */
export async function sha256Hex(bytes: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

export interface UploadLimits {
  maxBytes: number; // mỗi tệp
  maxCount: number; // số tệp mỗi lần
  maxTotalBytes: number; // tổng mỗi lần
}

export type BatchError =
  | { code: 'QUA_NHIEU_TEP'; message: string }
  | { code: 'TEP_QUA_LON'; message: string; name: string }
  | { code: 'TONG_QUA_LON'; message: string }
  | { code: 'SAI_LOAI_TEP'; message: string; name: string };

/** Kiểm lô tệp theo giới hạn (đọc từ tham số cài đặt, không viết cứng). Trả danh sách lỗi tiếng Việt; rỗng là hợp lệ. Máy chủ kiểm lại lần nữa. */
export function validateBatch(
  files: ReadonlyArray<{ name: string; size: number; type: string }>,
  limits: UploadLimits,
): BatchError[] {
  const errors: BatchError[] = [];
  if (files.length > limits.maxCount) {
    errors.push({ code: 'QUA_NHIEU_TEP', message: `Mỗi lần nộp tối đa ${limits.maxCount} tệp.` });
  }
  for (const f of files) {
    if (!(ACCEPTED_MIME as readonly string[]).includes(f.type)) {
      errors.push({
        code: 'SAI_LOAI_TEP',
        name: f.name,
        message: `Tệp «${f.name}» không đúng loại (nhận JPG, PNG, HEIC, PDF).`,
      });
    } else if (f.size > limits.maxBytes) {
      errors.push({ code: 'TEP_QUA_LON', name: f.name, message: `Tệp «${f.name}» quá lớn.` });
    }
  }
  const total = files.reduce((sum, f) => sum + f.size, 0);
  if (total > limits.maxTotalBytes) {
    errors.push({ code: 'TONG_QUA_LON', message: 'Tổng dung lượng các tệp quá lớn.' });
  }
  return errors;
}
