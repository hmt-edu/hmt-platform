// Luật tệp của LMS (R-LMS-04), tách khỏi Lms.tsx để Lms.tsx chỉ xuất thành phần.

/** Dung lượng tệp tối đa khi giao bài và khi nộp bài (R-LMS-04: 10 MB mỗi tệp). */
export const LMS_MAX_FILE_BYTES = 10 * 1024 * 1024; // allow-number: R-LMS-04, trần tệp 10 MB (luật cố định)

/** «1,5 MB», «820 KB»: dung lượng đọc được, dấu phẩy thập phân kiểu Việt. */
export function formatFileSize(bytes: number): string {
  const kb = 1024; // allow-number: đổi đơn vị
  if (bytes < kb * kb) return `${Math.max(1, Math.round(bytes / kb))} KB`;
  return `${(bytes / (kb * kb)).toFixed(1).replace('.', ',')} MB`;
}

/** Lý do tệp không dùng được (R-LMS-04), hoặc null nếu hợp lệ: chỉ ảnh hoặc PDF, tối đa 10 MB. */
export function fileProblem(file: { type: string; size: number }): string | null {
  const okType = file.type === 'application/pdf' || file.type.startsWith('image/');
  if (!okType) return 'Chỉ nhận ảnh hoặc PDF.';
  if (file.size > LMS_MAX_FILE_BYTES) return 'Tệp quá 10 MB.';
  return null;
}
