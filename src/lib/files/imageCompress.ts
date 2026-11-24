// Nén ảnh bài nộp bằng canvas trong trình duyệt (F-23-46 b). Phần thuần ở imageProcess.ts.
// Ảnh học sinh: thang xám + tăng tương phản + WebP. Ảnh giáo viên đính kèm: giữ màu (keepColor). PDF giữ nguyên. Không AVIF (iPhone cũ).
import {
  decodeFailureMessage,
  FILE_COMPRESS_PROFILE,
  sha256Hex,
  targetSize,
  toGrayscaleContrast,
} from './imageProcess';

const WEBP = 'image/webp';

/** Loại tệp THẬT của ảnh đã nén: Safari cũ không nén được WebP và trả PNG, không được ghi nhãn WebP cho ảnh PNG (máy chủ phát nosniff). */
export function mimeOfBlob(blob: Blob): string {
  return blob.type === 'image/png' || blob.type === 'image/jpeg' ? blob.type : WEBP;
}

export interface ProcessedImage {
  blob: Blob;
  thumb: Blob | null;
  sha256: string;
  mime: string;
  width: number;
  height: number;
}

function drawScaled(
  bitmap: ImageBitmap,
  edge: number,
  grayscale: boolean,
): { canvas: HTMLCanvasElement; w: number; h: number } {
  const { width, height } = targetSize(bitmap.width, bitmap.height, edge);
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Trình duyệt chưa hỗ trợ xử lý ảnh.');
  ctx.drawImage(bitmap, 0, 0, width, height);
  if (grayscale) {
    const img = ctx.getImageData(0, 0, width, height);
    toGrayscaleContrast(img.data, FILE_COMPRESS_PROFILE.contrast);
    ctx.putImageData(img, 0, 0);
  }
  return { canvas, w: width, h: height };
}

function toBlob(canvas: HTMLCanvasElement, quality: number): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (b) => (b ? resolve(b) : reject(new Error('Không nén được ảnh.'))),
      'image/webp',
      quality,
    );
  });
}

/** Nén một ảnh: trả ảnh đầy, ảnh thu nhỏ và mã băm của ảnh đã nén. PDF không đi qua hàm này. */
export async function compressImage(
  file: File,
  opts: { keepColor: boolean },
): Promise<ProcessedImage> {
  // Đọc được mới nén; không đọc được (HEIC trên trình duyệt chưa hỗ trợ) thì báo ngay, KHÔNG gửi nguyên tệp (F-23-50).
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    throw new Error(decodeFailureMessage(file.name, file.type));
  }
  try {
    const full = drawScaled(bitmap, FILE_COMPRESS_PROFILE.maxEdge, !opts.keepColor);
    const blob = await toBlob(full.canvas, FILE_COMPRESS_PROFILE.quality);
    const small = drawScaled(bitmap, FILE_COMPRESS_PROFILE.thumbEdge, !opts.keepColor);
    const thumbBlob = await toBlob(small.canvas, FILE_COMPRESS_PROFILE.thumbQuality);
    return {
      blob,
      thumb: thumbBlob.type === WEBP ? thumbBlob : null, // Safari cũ không có WebP, canvas trả PNG: bỏ ảnh thu nhỏ, máy chủ ghi và phát nó là WebP
      sha256: await sha256Hex(await blob.arrayBuffer()),
      mime: mimeOfBlob(blob),
      width: full.w,
      height: full.h,
    };
  } finally {
    bitmap.close();
  }
}
