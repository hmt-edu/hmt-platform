import { describe, expect, it, vi } from 'vitest';
import { FlowError, finishUpload, startUpload, viewFile, type FileDeps, type PendingRow, type UploadAuth } from './file-flow';

const SHA = 'a'.repeat(64);
const auth: UploadAuth = {
  branch_id: 'b', class_id: 'c', assignment_id: 'as', kind: 'BAI_NOP', submission_id: 's', student_id: 'st', is_color: false, delete_after: '2027-02-22',
  limits: { max_bytes: 1000, max_count: 2, max_total_bytes: 1500 },
};
const file = { mimeType: 'image/webp', size: 400, sha256: SHA, thumbSize: 50 };

function makeDeps(over: Partial<FileDeps> = {}) {
  const rows = new Map<string, PendingRow & { status: string }>();
  let n = 0;
  const deps: FileDeps = {
    drive: {
      startResumableUpload: vi.fn(async (p) => `https://upload/${p.name}`),
      getFileInfo: vi.fn(async (id: string) => ({ id, name: [...rows.keys()][0] ?? '', size: 400, mimeType: 'image/webp', trashed: false })),
      getStorageQuota: vi.fn(async () => ({ usage: 100, limit: 20 * 1024 ** 3 })),
      download: vi.fn(async () => new Response('x')),
    },
    rootFolderId: 'root',
    authorizeUpload: vi.fn(async () => auth),
    authorizeView: vi.fn(async () => ({ storage_key: 'K', thumb_storage_key: 'T', mime_type: 'image/webp', size_bytes: 1 })),
    insertPending: vi.fn(async (r) => {
      rows.set(r.id, { ...r, status: 'CHO_TAI' });
      return 'OK';
    }),
    supersedePending: vi.fn(async () => 0),
    getPending: vi.fn(async (id, owner) => {
      const r = rows.get(id);
      return r && r.owner_user_id === owner ? r : null;
    }),
    markReady: vi.fn(async () => undefined),
    minFreeGb: vi.fn(async () => 3),
    newId: () => `id-${++n}`,
    ...over,
  };
  return { deps, rows };
}
const run = async (p: Promise<unknown>) => p.then(() => null, (e: FlowError) => e.code);

describe('startUpload', () => {
  it('đủ điều kiện: ghi dòng CHO_TAI, tên Drive là uuid, trả địa chỉ tải cho tệp và ảnh thu nhỏ', async () => {
    const { deps, rows } = makeDeps();
    const r = await startUpload(deps, 'u1', { kind: 'BAI_NOP', assignmentId: 'as', studentId: 'st', files: [file] });
    expect(r.files[0]).toEqual({ id: 'id-1', uploadUrl: 'https://upload/id-1', thumbUploadUrl: 'https://upload/id-1-t' });
    expect(rows.get('id-1')?.status).toBe('CHO_TAI');
    expect(rows.get('id-1')?.delete_after).toBe('2027-02-22'); // chụp hạn giữ từ hàm DB
  });
  it('luật quyền: hàm DB chặn thì không mở phiên tải Drive', async () => {
    const { deps } = makeDeps({ authorizeUpload: vi.fn(async () => { throw new FlowError('HMT_KHONG_CO_QUYEN', 'x', 403); }) });
    expect(await run(startUpload(deps, 'u1', { kind: 'BAI_NOP', assignmentId: 'as', studentId: 'st', files: [file] }))).toBe('HMT_KHONG_CO_QUYEN');
    expect(deps.drive.startResumableUpload).not.toHaveBeenCalled();
  });
  it('luật giới hạn lô: quá số tệp, quá cỡ, quá tổng, sai loại', async () => {
    const { deps } = makeDeps();
    const go = (files: (typeof file)[]) => run(startUpload(deps, 'u1', { kind: 'BAI_NOP', assignmentId: 'as', studentId: 'st', files }));
    expect(await go([file, file, file])).toBe('HMT_TEP_QUA_NHIEU');
    expect(await go([{ ...file, size: 2000 }])).toBe('HMT_TEP_QUA_LON');
    expect(await go([{ ...file, size: 900, thumbSize: 100 }, { ...file, size: 900, thumbSize: 100 }])).toBe('HMT_TEP_TONG_QUA_LON');
    expect(await go([{ ...file, mimeType: 'application/zip' }])).toBe('HMT_TEP_LOAI_SAI');
    expect(await go([{ ...file, mimeType: 'image/heic' }])).toBe('HMT_TEP_LOAI_SAI'); // không gửi nguyên HEIC
  });
  it('luật chặn mềm dung lượng: còn trống dưới 3 GB thì chặn tải mới', async () => {
    const { deps } = makeDeps();
    deps.drive.getStorageQuota = vi.fn(async () => ({ usage: 12.5 * 1024 ** 3, limit: 15 * 1024 ** 3 }));
    expect(await run(startUpload(deps, 'u1', { kind: 'BAI_NOP', assignmentId: 'as', studentId: 'st', files: [file] }))).toBe('HMT_KHO_TEP_DAY');
  });
  it('luật chặn trùng: trùng ảnh đã nộp thì báo; trùng lần tải dở thì cho nộp lại', async () => {
    const dup = makeDeps({ insertPending: vi.fn(async () => 'TRUNG' as const) });
    expect(await run(startUpload(dup.deps, 'u1', { kind: 'BAI_NOP', assignmentId: 'as', studentId: 'st', files: [file] }))).toBe('HMT_TEP_TRUNG');
    let first = true;
    const retry = makeDeps({
      insertPending: vi.fn(async () => (first ? ((first = false), 'TRUNG' as const) : ('OK' as const))),
      supersedePending: vi.fn(async () => 1),
    });
    const r = await startUpload(retry.deps, 'u1', { kind: 'BAI_NOP', assignmentId: 'as', studentId: 'st', files: [file] });
    expect(r.files).toHaveLength(1);
  });
});

describe('finishUpload', () => {
  async function started() {
    const m = makeDeps();
    await startUpload(m.deps, 'u1', { kind: 'BAI_NOP', assignmentId: 'as', studentId: 'st', files: [file] });
    return m;
  }
  it('khớp tên và cỡ thì đổi sang DANG_DUNG với khoá Drive thật', async () => {
    const { deps } = await started();
    deps.drive.getFileInfo = vi.fn(async (id: string) => ({ id, name: id === 'D1' ? 'id-1' : 'id-1-t', size: 400, mimeType: 'image/webp', trashed: false }));
    await finishUpload(deps, 'u1', { id: 'id-1', driveId: 'D1', thumbDriveId: 'D2' });
    expect(deps.markReady).toHaveBeenCalledWith('id-1', 'D1', 'D2');
  });
  it('luật gắn tệp: sai tên hoặc sai cỡ thì từ chối (không gắn tệp Drive của người khác)', async () => {
    const { deps } = await started();
    deps.drive.getFileInfo = vi.fn(async (id: string) => ({ id, name: 'khac', size: 400, mimeType: 'image/webp', trashed: false }));
    expect(await run(finishUpload(deps, 'u1', { id: 'id-1', driveId: 'D1', thumbDriveId: 'D2' }))).toBe('HMT_TEP_KHONG_KHOP');
    deps.drive.getFileInfo = vi.fn(async (id: string) => ({ id, name: 'id-1', size: 5, mimeType: 'image/webp', trashed: false }));
    expect(await run(finishUpload(deps, 'u1', { id: 'id-1', driveId: 'D1', thumbDriveId: 'D2' }))).toBe('HMT_TEP_KHONG_KHOP');
    expect(deps.markReady).not.toHaveBeenCalled();
  });
  it('luật chủ lượt tải: người khác không hoàn tất được lượt của em; thiếu ảnh thu nhỏ thì từ chối', async () => {
    const { deps } = await started();
    expect(await run(finishUpload(deps, 'u2', { id: 'id-1', driveId: 'D1', thumbDriveId: null }))).toBe('HMT_TEP_KHONG_TIM_THAY');
    deps.drive.getFileInfo = vi.fn(async (id: string) => ({ id, name: 'id-1', size: 400, mimeType: 'image/webp', trashed: false }));
    expect(await run(finishUpload(deps, 'u1', { id: 'id-1', driveId: 'D1', thumbDriveId: null }))).toBe('HMT_TEP_KHONG_KHOP');
  });
});

describe('viewFile', () => {
  it('hàm DB cho phép thì tải từ Drive: ảnh thu nhỏ khi xin thumb, ảnh đầy khi không', async () => {
    const { deps } = makeDeps();
    expect((await viewFile(deps, { id: 'x', thumb: true })).mimeType).toBe('image/webp');
    expect(deps.drive.download).toHaveBeenLastCalledWith('T');
    await viewFile(deps, { id: 'x', thumb: false });
    expect(deps.drive.download).toHaveBeenLastCalledWith('K');
  });
  it('luật quyền xem: bị chặn thì không gọi Drive', async () => {
    const { deps } = makeDeps({ authorizeView: vi.fn(async () => { throw new FlowError('HMT_KHONG_CO_QUYEN', 'x', 403); }) });
    expect(await run(viewFile(deps, { id: 'x', thumb: false }))).toBe('HMT_KHONG_CO_QUYEN');
    expect(deps.drive.download).not.toHaveBeenCalled();
  });
});
