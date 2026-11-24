// Luật CORS (thuần TypeScript, không phụ thuộc Deno để Vitest kiểm được).

/** Nguồn chạy local (npm run dev / preview). */
export const LOCAL_ORIGINS = ['http://localhost:5173', 'http://127.0.0.1:5173', 'http://localhost:4173', 'http://127.0.0.1:4173'];

/** Bản xem trước của từng PR trên Cloudflare Pages thử nghiệm. */
const STAGING_PREVIEW = /^https:\/\/[a-z0-9-]+\.hmt-staging\.pages\.dev$/;

export interface CorsConfig {
  /** Nguồn được phép thêm (biến HMT_ALLOWED_ORIGINS). */
  allowedOrigins: string[];
  /** Chỉ bật trên thử nghiệm (biến HMT_ALLOW_STAGING_PREVIEWS=true). */
  allowStagingPreviews: boolean;
  /** Nhận nguồn localhost (biến HMT_ALLOW_LOCAL_ORIGINS=true): chỉ local và thử nghiệm; bản chạy thật KHÔNG đặt (bảo mật A-23-36). */
  allowLocalOrigins?: boolean;
}

export function isOriginAllowed(origin: string, config: CorsConfig): boolean {
  if (config.allowedOrigins.includes(origin)) return true;
  // Luật: nguồn localhost chỉ nhận khi bật cờ riêng (local, thử nghiệm); chạy thật không đặt cờ nên không nhận.
  if (config.allowLocalOrigins === true && LOCAL_ORIGINS.includes(origin)) return true;
  // Luật: trang xem trước của thử nghiệm chỉ được gọi Edge Function thử nghiệm, không gọi bản chạy thật.
  return config.allowStagingPreviews && STAGING_PREVIEW.test(origin);
}
