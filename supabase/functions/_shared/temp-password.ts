// Mật khẩu tạm ngẫu nhiên khi nạp người dùng (thuần TypeScript, không phụ thuộc Deno để Vitest kiểm được).
// Bỏ các ký tự dễ nhầm (0, O, 1, l, I). Luôn có ít nhất một chữ và một số (đúng chính sách mật khẩu). Nguồn ngẫu nhiên truyền vào
// (trong Edge Function là crypto.getRandomValues) để bài kiểm tái hiện được.
const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const DIGITS = '23456789';
const ALL = LETTERS + DIGITS;

/** Số giá trị của một byte (0 đến 255), không phải số nghiệp vụ. */
const BYTE_RANGE = 256; // allow-number: miền giá trị của một byte
/** Độ dài tối thiểu để có đủ một chữ và một số. */
const MIN_LENGTH = 4; // allow-number: tối thiểu một chữ, một số và đủ để xáo trộn

export type RandomBytes = (buffer: Uint8Array) => Uint8Array;

/** Chọn đều một chỉ số trong [0, n) từ byte ngẫu nhiên (loại bỏ lệch bằng cách bỏ giá trị vượt bội số của n). */
function pickIndex(n: number, random: RandomBytes): number {
  const limit = BYTE_RANGE - (BYTE_RANGE % n);
  const buffer = new Uint8Array(1);
  for (;;) {
    random(buffer);
    if (buffer[0] < limit) return buffer[0] % n;
  }
}

/** Sinh mật khẩu tạm dài `length` ký tự (tối thiểu 4 để có đủ chữ và số). */
export function generateTempPassword(length: number, random: RandomBytes): string {
  const size = Math.max(Math.floor(length), MIN_LENGTH);
  const chars: string[] = [LETTERS[pickIndex(LETTERS.length, random)], DIGITS[pickIndex(DIGITS.length, random)]];
  while (chars.length < size) chars.push(ALL[pickIndex(ALL.length, random)]);
  // Xáo trộn Fisher-Yates để chữ, số bắt buộc không luôn đứng đầu.
  for (let i = chars.length - 1; i > 0; i--) {
    const j = pickIndex(i + 1, random);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}
