import { describe, expect, it } from 'vitest';
import { sha256Hex, targetSize, toGrayscaleContrast, validateBatch } from './imageProcess';

const limits = { maxBytes: 100, maxCount: 2, maxTotalBytes: 150 };
const ok = { name: 'a.jpg', size: 80, type: 'image/jpeg' };

describe('targetSize', () => {
  it('thu nhỏ theo cạnh dài, giữ tỉ lệ', () => {
    expect(targetSize(4000, 2000, 1000)).toEqual({ width: 1000, height: 500 });
    expect(targetSize(1500, 3000, 1000)).toEqual({ width: 500, height: 1000 });
  });
  it('không phóng to ảnh nhỏ', () => {
    expect(targetSize(800, 600, 1000)).toEqual({ width: 800, height: 600 });
  });
  it('ảnh lỗi kích thước 0 trả 0', () => {
    expect(targetSize(0, 100, 1000)).toEqual({ width: 0, height: 0 });
  });
});

describe('toGrayscaleContrast', () => {
  it('đổi sang thang xám: ba kênh bằng nhau, giữ kênh alpha', () => {
    const d = toGrayscaleContrast(new Uint8ClampedArray([200, 100, 50, 255]), 1);
    expect(d[0]).toBe(d[1]);
    expect(d[1]).toBe(d[2]);
    expect(d[3]).toBe(255);
  });
  it('tăng tương phản: điểm sáng sáng hơn, điểm tối tối hơn, mức giữa không đổi', () => {
    const d = toGrayscaleContrast(
      new Uint8ClampedArray([200, 200, 200, 255, 50, 50, 50, 255, 128, 128, 128, 255]),
      1.5,
    );
    expect(d[0]).toBeGreaterThan(200);
    expect(d[4]).toBeLessThan(50);
    expect(d[8]).toBe(128);
  });
  it('không tràn ngoài 0-255', () => {
    const d = toGrayscaleContrast(new Uint8ClampedArray([255, 255, 255, 255, 0, 0, 0, 255]), 3);
    expect(d[0]).toBe(255);
    expect(d[4]).toBe(0);
  });
});

describe('sha256Hex', () => {
  it('đúng giá trị chuẩn của chuỗi rỗng và dài 64 ký tự', async () => {
    expect(await sha256Hex(new ArrayBuffer(0))).toBe(
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
  });
  it('cùng nội dung cùng mã băm, khác nội dung khác mã băm', async () => {
    const a = await sha256Hex(new Uint8Array([1, 2, 3]).buffer);
    expect(await sha256Hex(new Uint8Array([1, 2, 3]).buffer)).toBe(a);
    expect(await sha256Hex(new Uint8Array([1, 2, 4]).buffer)).not.toBe(a);
  });
});

describe('validateBatch', () => {
  it('lô hợp lệ không có lỗi', () => {
    expect(validateBatch([ok], limits)).toEqual([]);
  });
  it('chặn quá số tệp mỗi lần', () => {
    expect(validateBatch([ok, ok, ok], limits).map((e) => e.code)).toContain('QUA_NHIEU_TEP');
  });
  it('chặn tệp quá lớn, nêu tên tệp', () => {
    const e = validateBatch([{ ...ok, name: 'to.jpg', size: 101 }], limits);
    expect(e[0]).toMatchObject({ code: 'TEP_QUA_LON', name: 'to.jpg' });
  });
  it('chặn tổng quá lớn', () => {
    expect(validateBatch([ok, ok], limits).map((e) => e.code)).toContain('TONG_QUA_LON');
  });
  it('chặn loại tệp ngoài danh sách (zip, svg), nhận HEIC và PDF', () => {
    expect(validateBatch([{ ...ok, type: 'application/zip' }], limits)[0]?.code).toBe(
      'SAI_LOAI_TEP',
    );
    expect(validateBatch([{ ...ok, type: 'image/svg+xml' }], limits)[0]?.code).toBe('SAI_LOAI_TEP');
    expect(validateBatch([{ ...ok, type: 'image/heic' }], limits)).toEqual([]);
    expect(validateBatch([{ ...ok, type: 'application/pdf' }], limits)).toEqual([]);
  });
});
