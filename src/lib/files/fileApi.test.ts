import type { SupabaseClient } from '@supabase/supabase-js';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const callFunction = vi.fn();
const rpc = vi.fn();
vi.mock('../db', () => {
  class HmtError extends Error {
    readonly code: string;
    constructor(code: string, message: string) {
      super(message);
      this.code = code;
    }
  }
  return {
    HmtError,
    callFunction: (...a: unknown[]): unknown => callFunction(...a),
    rpc: (...a: unknown[]): unknown => rpc(...a),
  };
});
vi.mock('../supabase', () => ({
  getSupabaseConfig: () => ({
    status: 'ok',
    config: { url: 'https://x.test', publishableKey: 'pk' },
  }),
}));

import { HmtError } from '../db';
import { blobToBase64, fetchFileBlob, submitAssignment, uploadFiles } from './fileApi';

const supabase = {
  auth: { getSession: () => Promise.resolve({ data: { session: { access_token: 'tok' } } }) },
} as unknown as SupabaseClient;
const args = {
  kind: 'BAI_NOP' as const,
  assignmentId: 'as',
  studentId: 'st',
  files: [{ blob: new Blob([new Uint8Array([1, 2, 3])]), thumb: null, mime: 'image/webp' }],
};

describe('fileApi', () => {
  beforeEach(() => {
    callFunction.mockReset();
    rpc.mockReset();
    vi.useRealTimers();
  });

  it('blobToBase64 đổi đúng byte', async () => {
    expect(await blobToBase64(new Blob([new Uint8Array([1, 2, 3])]))).toBe('AQID');
  });

  it('tải lên: gửi một lần cho cả lô, trả mã tệp theo thứ tự, báo giai đoạn', async () => {
    callFunction.mockResolvedValue({ files: [{ id: 'f1' }, { id: 'f2' }] });
    const stages: string[] = [];
    const ids = await uploadFiles(
      supabase,
      { ...args, files: [...args.files, ...args.files] },
      (s) => stages.push(s.phase),
    );
    expect(ids).toEqual(['f1', 'f2']);
    expect(callFunction).toHaveBeenCalledTimes(1);
    expect(callFunction.mock.calls[0]?.[1]).toBe('file-upload');
    expect(callFunction.mock.calls[0]?.[2]).toMatchObject({
      kind: 'BAI_NOP',
      assignmentId: 'as',
      studentId: 'st',
    });
    expect(stages).toEqual(['prepare', 'upload']);
  });

  it('luật thử lại: rớt mạng thì thử lại rồi thành công; lỗi nghiệp vụ không thử lại', async () => {
    vi.useFakeTimers();
    callFunction
      .mockRejectedValueOnce(new HmtError('HMT_MANG', 'mạng'))
      .mockResolvedValueOnce({ files: [{ id: 'f1' }] });
    const run = uploadFiles(supabase, args);
    await vi.advanceTimersByTimeAsync(2000);
    expect(await run).toEqual(['f1']);
    expect(callFunction).toHaveBeenCalledTimes(2);

    callFunction.mockReset();
    callFunction.mockRejectedValue(new HmtError('HMT_LMS_QUA_HAN', 'Đã quá hạn nộp bài này.'));
    await expect(uploadFiles(supabase, args)).rejects.toMatchObject({ code: 'HMT_LMS_QUA_HAN' });
    expect(callFunction).toHaveBeenCalledTimes(1);
  });

  it('luật thử lại: rớt mạng mãi thì bỏ cuộc sau số lần quy định và ném lỗi mạng', async () => {
    vi.useFakeTimers();
    callFunction.mockRejectedValue(new HmtError('HMT_MANG', 'mạng'));
    const run = uploadFiles(supabase, args);
    const assertion = expect(run).rejects.toMatchObject({ code: 'HMT_MANG' });
    await vi.advanceTimersByTimeAsync(10000);
    await assertion;
    expect(callFunction).toHaveBeenCalledTimes(3);
  });

  it('xem ảnh: GET kèm id và thumb, trả Blob; lỗi máy chủ giữ mã và câu tiếng Việt', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response('abc', { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);
    const blob = await fetchFileBlob(supabase, 'id1', { thumb: true });
    expect(await blob.text()).toBe('abc');
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      'https://x.test/functions/v1/file-view?id=id1&thumb=1',
    );
    expect(fetchMock.mock.calls[0]?.[1]).toMatchObject({ method: 'GET' });
    fetchMock.mockResolvedValue(
      new Response(
        JSON.stringify({
          error: { code: 'HMT_TEP_DA_DON', message: 'Ảnh đã được dọn theo quy định lưu trữ.' },
        }),
        { status: 410 },
      ),
    );
    await expect(fetchFileBlob(supabase, 'id2')).rejects.toMatchObject({ code: 'HMT_TEP_DA_DON' });
    vi.unstubAllGlobals();
  });

  it('chốt nộp bài: gọi hàm DB với danh sách tệp theo thứ tự trang', async () => {
    rpc.mockResolvedValue({ submission_id: 's', attempt: 1, is_late: false, submitted_at: 'x' });
    await submitAssignment(supabase, 'as', ['f2', 'f1']);
    expect(rpc).toHaveBeenCalledWith(supabase, 'lms_submit_assignment', {
      p_assignment_id: 'as',
      p_file_ids: ['f2', 'f1'],
    });
  });
});
