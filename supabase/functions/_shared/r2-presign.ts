// Ký địa chỉ có hạn (presigned URL) theo AWS Signature V4 cho Cloudflare R2 (giao thức S3), F-23-46 c.
// Hàm thuần dùng WebCrypto, không phụ thuộc thư viện; thời điểm truyền vào để kiểm thử tái hiện được.
// Chỉ ký tiêu đề `host`, nội dung `UNSIGNED-PAYLOAD`: trình duyệt PUT/GET thẳng lên R2. Khoá R2 chỉ ở secret của Edge Function.
// Thiết kế: docs/ke-hoach/luu-tru-tep-r2.md mục 1 và 2.

export interface PresignInput {
  method: 'GET' | 'PUT' | 'HEAD' | 'DELETE';
  host: string; // ví dụ <account>.r2.cloudflarestorage.com
  path: string; // bắt đầu bằng /, ví dụ /bucket/khoa/tep
  accessKeyId: string;
  secretAccessKey: string;
  region: string; // R2 dùng 'auto'
  expiresSeconds: number;
  now: Date;
  service?: string; // mặc định 's3'
}

const encoder = new TextEncoder();

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, '0')).join(''); // allow-number: cơ số thập lục phân, hai chữ số mỗi byte
}

async function hmac(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const k = await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return crypto.subtle.sign('HMAC', k, encoder.encode(data));
}

async function sha256Hex(data: string): Promise<string> {
  return hex(await crypto.subtle.digest('SHA-256', encoder.encode(data)));
}

/** Mã hoá theo SigV4: giữ A-Z a-z 0-9 - _ . ~, còn lại %XX viết hoa. */
export function uriEncode(value: string): string {
  return encodeURIComponent(value).replace(/[!'()*]/g, (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase()); // allow-number: cơ số 16 khi viết mã %XX
}

/** Mã hoá từng đoạn của đường dẫn, giữ dấu / giữa các đoạn. */
export function encodePath(path: string): string {
  return path.split('/').map(uriEncode).join('/');
}

function amzDate(now: Date): string {
  return now.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

/** Trả địa chỉ đầy đủ (https) đã ký, dùng được ngay bởi trình duyệt cho đến khi hết expiresSeconds. */
export async function presignUrl(input: PresignInput): Promise<string> {
  const service = input.service ?? 's3';
  const stamp = amzDate(input.now);
  const day = stamp.slice(0, 8); // allow-number: độ dài ngày YYYYMMDD
  const scope = `${day}/${input.region}/${service}/aws4_request`;
  const params: Array<[string, string]> = [
    ['X-Amz-Algorithm', 'AWS4-HMAC-SHA256'],
    ['X-Amz-Credential', `${input.accessKeyId}/${scope}`],
    ['X-Amz-Date', stamp],
    ['X-Amz-Expires', String(input.expiresSeconds)],
    ['X-Amz-SignedHeaders', 'host'],
  ];
  const canonicalQuery = params
    .map(([k, v]) => [uriEncode(k), uriEncode(v)] as const)
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0))
    .map(([k, v]) => `${k}=${v}`)
    .join('&');
  const canonicalPath = encodePath(input.path);
  const canonicalRequest = [input.method, canonicalPath, canonicalQuery, `host:${input.host}\n`, 'host', 'UNSIGNED-PAYLOAD'].join('\n');
  const stringToSign = ['AWS4-HMAC-SHA256', stamp, scope, await sha256Hex(canonicalRequest)].join('\n');
  const kDate = await hmac(encoder.encode('AWS4' + input.secretAccessKey), day);
  const kRegion = await hmac(kDate, input.region);
  const kService = await hmac(kRegion, service);
  const kSigning = await hmac(kService, 'aws4_request');
  const signature = hex(await hmac(kSigning, stringToSign));
  return `https://${input.host}${canonicalPath}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}
