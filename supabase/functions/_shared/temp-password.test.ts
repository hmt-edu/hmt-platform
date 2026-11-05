import { describe, expect, it } from 'vitest';
import { generateTempPassword, type RandomBytes } from './temp-password.ts';

// Nguồn ngẫu nhiên giả, tái hiện được (xoay vòng một dãy byte).
function sequence(bytes: number[]): RandomBytes {
  let i = 0;
  return (buffer) => {
    for (let k = 0; k < buffer.length; k++) buffer[k] = bytes[i++ % bytes.length];
    return buffer;
  };
}

describe('mật khẩu tạm khi nạp người dùng', () => {
  it('đúng độ dài yêu cầu, có ít nhất một chữ và một số', () => {
    const random = sequence([7, 91, 203, 14, 55, 120, 3, 77, 250, 18, 199, 64]);
    for (let n = 0; n < 50; n++) {
      const password = generateTempPassword(14, random);
      expect(password).toHaveLength(14);
      expect(password).toMatch(/[A-Za-z]/);
      expect(password).toMatch(/[0-9]/);
    }
  });
  it('không dùng ký tự dễ nhầm 0, O, 1, l, I', () => {
    const random = sequence(Array.from({ length: 256 }, (_, i) => i));
    for (let n = 0; n < 200; n++) {
      expect(generateTempPassword(20, random)).not.toMatch(/[0O1lI]/);
    }
  });
  it('độ dài nhỏ hơn 4 được nâng lên 4 để vẫn đủ chữ và số', () => {
    expect(generateTempPassword(2, sequence([5, 9, 33]))).toHaveLength(4);
  });
  it('hai lần sinh với dãy byte khác nhau ra mật khẩu khác nhau', () => {
    const a = generateTempPassword(14, sequence([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]));
    const b = generateTempPassword(14, sequence([200, 150, 100, 50, 25, 12, 6, 3, 99, 77, 55, 33, 11]));
    expect(a).not.toBe(b);
  });
  it('byte vượt bội số được bỏ để không lệch (byte 255 bị bỏ khi chọn trong 8 chữ số)', () => {
    // 256 % 8 = 0 nên không bỏ; kiểm với 54 ký tự: 256 % 54 = 40, giới hạn 216: byte 250 bị bỏ, lấy byte kế.
    const password = generateTempPassword(4, sequence([250, 3, 250, 2, 250, 1, 250, 0, 250, 4, 250, 5]));
    expect(password).toHaveLength(4);
  });
});
