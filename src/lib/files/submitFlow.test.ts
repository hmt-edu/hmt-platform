import type { SupabaseClient } from '@supabase/supabase-js';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const uploadFiles = vi.fn();
const submitAssignment = vi.fn();
vi.mock('./fileApi', () => ({
  uploadFiles: (...a: unknown[]): unknown => uploadFiles(...a),
  submitAssignment: (...a: unknown[]): unknown => submitAssignment(...a),
}));

import { inBatches, submitPages, type SubmitPage } from './submitFlow';

const supabase = {} as SupabaseClient;
const file = () => ({ blob: new Blob(['x']), thumb: null, mime: 'image/webp' });
const pages = (n: number): SubmitPage[] =>
  Array.from({ length: n }, () => ({ fileId: null, prepare: () => Promise.resolve(file()) }));
const run = (p: SubmitPage[], maxPerBatch: number) =>
  submitPages(supabase, { assignmentId: 'a', studentId: 's', pages: p, maxPerBatch });

beforeEach(() => {
  uploadFiles.mockReset();
  submitAssignment.mockReset();
  uploadFiles.mockImplementation((_s: unknown, args: { files: unknown[] }) =>
    Promise.resolve(args.files.map(() => `f${uploadFiles.mock.calls.length}-${Math.random()}`)),
  );
  submitAssignment.mockResolvedValue({ attempt: 1 });
});

describe('inBatches', () => {
  it('chia đợt giữ thứ tự, đợt cuối có thể ít hơn', () => {
    expect(inBatches([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]]);
    expect(inBatches([], 3)).toEqual([]);
  });
});

describe('submitPages', () => {
  it('luật số trang: 15 trang với 10 tệp mỗi lần tải thành 2 đợt rồi chốt MỘT lần đủ 15 mã đúng thứ tự', async () => {
    const p = pages(15);
    await run(p, 10);
    expect(uploadFiles).toHaveBeenCalledTimes(2);
    expect((uploadFiles.mock.calls[0]?.[1] as { files: unknown[] }).files).toHaveLength(10);
    expect((uploadFiles.mock.calls[1]?.[1] as { files: unknown[] }).files).toHaveLength(5);
    expect(submitAssignment).toHaveBeenCalledTimes(1);
    expect(submitAssignment.mock.calls[0]?.[2]).toEqual(p.map((x) => x.fileId));
  });
  it('luật thử lại: tải xong mà chốt hỏng thì «Thử lại» chỉ chốt lại, KHÔNG tải lại ảnh', async () => {
    const p = pages(3);
    submitAssignment.mockRejectedValueOnce(new Error('mất mạng'));
    await expect(run(p, 10)).rejects.toThrow('mất mạng');
    expect(uploadFiles).toHaveBeenCalledTimes(1);
    await run(p, 10);
    expect(uploadFiles).toHaveBeenCalledTimes(1);
    expect(submitAssignment).toHaveBeenCalledTimes(2);
  });
  it('luật thử lại giữa chừng: đợt 2 hỏng thì đợt 1 giữ mã, thử lại chỉ tải đợt 2', async () => {
    const p = pages(4);
    uploadFiles.mockImplementationOnce((_s: unknown, a: { files: unknown[] }) =>
      Promise.resolve(a.files.map((_, i) => `ok${i}`)),
    );
    uploadFiles.mockRejectedValueOnce(new Error('đứt'));
    await expect(run(p, 2)).rejects.toThrow('đứt');
    expect(p.map((x) => x.fileId)).toEqual(['ok0', 'ok1', null, null]);
    await run(p, 2);
    expect(uploadFiles).toHaveBeenCalledTimes(3);
    expect((uploadFiles.mock.calls[2]?.[1] as { files: unknown[] }).files).toHaveLength(2);
  });
});
