import { describe, expect, it, vi } from 'vitest';
import { FlowError, uploadFiles, viewFile, type FileDeps, type PendingRow, type UploadAuth, type UploadInput } from './file-flow';

const auth: UploadAuth = {
  branch_id: 'b', class_id: 'c', assignment_id: 'as', kind: 'BAI_NOP', submission_id: 's', student_id: 'st', is_color: false, delete_after: '2027-01-23',
  limits: { max_bytes: 1000, max_count: 2, max_total_bytes: 1500 },
};
const enc = (n: number) => 'x'.repeat(n); // "base64" giả: bộ giải mã giả đổi chuỗi thành mảng byte cùng độ dài
const file = (n = 400, thumb: number | null = 50) => ({ mimeType: 'image/webp', dataBase64: enc(n), thumbBase64: thumb ? enc(thumb) : null });
const input = (files = [file()]): UploadInput => ({ kind: 'BAI_NOP', assignmentId: 'as', studentId: 'st', files });
const GB = 1024 ** 3;

function makeDeps(over: Partial<FileDeps> = {}) {
  const rows = new Map<string, PendingRow & { status: string }>();
  let n = 0;
  const deps: FileDeps = {
    store: {
      save: vi.fn(async (p) => `D-${p.name}`),
      read: vi.fn(async (id: string) => ({ mimeType: 'image/webp', bytes: new Uint8Array([1, 2, id.length]) })),
      getStorageQuota: vi.fn(async () => ({ usage: 100, limit: 20 * GB })),
    },
    authorizeUpload: vi.fn(async () => auth),
    authorizeView: vi.fn(async () => ({ storage_key: 'K', thumb_storage_key: 'T', mime_type: 'image/png', size_bytes: 1 })),
    insertPending: vi.fn(async (r) => {
      rows.set(r.id, { ...r, status: 'CHO_TAI' });
      return 'OK';
    }),
    supersedePending: vi.fn(async () => 0),
    abandon: vi.fn(async (id: string) => {
      const r = rows.get(id);
      if (r) r.status = 'DA_XOA';
    }),
    markReady: vi.fn(async (id: string) => {
      const r = rows.get(id);
      if (r) r.status = 'DANG_DUNG';
    }),
    minFreeGb: vi.fn(async () => 3),
    sha256: vi.fn(async (b: Uint8Array) => `sha${b.length}`),
    decodeBase64: (s: string) => new Uint8Array(s.length),
    newId: () => `id-${++n}`,
    monthFolder: () => '2026-11',
    ...over,
  };
  return { deps, rows };
}
const code = async (p: Promise<unknown>) => p.then(() => null, (e: FlowError) => e.code);

describe('uploadFiles', () => {
  it('đủ điều kiện: lưu ảnh và ảnh thu nhỏ vào thư mục lớp/tháng, tên là uuid, dòng sổ thành DANG_DUNG với khoá thật, mã băm tính ở máy chủ', async () => {
    const { deps, rows } = makeDeps();
    const r = await uploadFiles(deps, 'u1', input());
    expect(r.files).toEqual([{ id: 'id-1' }]);
    expect(deps.store.save).toHaveBeenCalledWith(expect.objectContaining({ path: ['c', '2026-11'], name: 'id-1.webp' }));
    expect(deps.store.save).toHaveBeenCalledWith(expect.objectContaining({ path: ['c', '2026-11'], name: 'id-1-t.webp' }));
    expect(deps.markReady).toHaveBeenCalledWith('id-1', 'D-id-1.webp', 'D-id-1-t.webp');
    expect(rows.get('id-1')).toMatchObject({ status: 'DANG_DUNG', sha256: 'sha400', delete_after: '2027-01-23' });
  });
  it('luật quyền: hàm DB chặn thì không lưu gì vào kho', async () => {
    const { deps } = makeDeps({ authorizeUpload: vi.fn(async () => { throw new FlowError('HMT_KHONG_CO_QUYEN', 'x', 403); }) });
    expect(await code(uploadFiles(deps, 'u1', input()))).toBe('HMT_KHONG_CO_QUYEN');
    expect(deps.store.save).not.toHaveBeenCalled();
  });
  it('luật giới hạn lô: quá số tệp, quá cỡ, quá tổng, sai loại (kể cả HEIC gửi nguyên)', async () => {
    const { deps } = makeDeps();
    expect(await code(uploadFiles(deps, 'u1', input([file(), file(), file()])))).toBe('HMT_TEP_QUA_NHIEU');
    expect(await code(uploadFiles(deps, 'u1', input([file(2000)])))).toBe('HMT_TEP_QUA_LON');
    expect(await code(uploadFiles(deps, 'u1', input([file(900, 100), file(900, 100)])))).toBe('HMT_TEP_TONG_QUA_LON');
    expect(await code(uploadFiles(deps, 'u1', input([{ ...file(), mimeType: 'application/zip' }])))).toBe('HMT_TEP_LOAI_SAI');
    expect(await code(uploadFiles(deps, 'u1', input([{ ...file(), mimeType: 'image/heic' }])))).toBe('HMT_TEP_LOAI_SAI');
    expect(await code(uploadFiles(deps, 'u1', input([file(0)])))).toBe('HMT_TEP_THIEU');
    expect(deps.store.save).not.toHaveBeenCalled();
  });
  it('luật chặn mềm: còn trống dưới 3 GB thì chặn tải mới; còn nhiều thì cho', async () => {
    const { deps } = makeDeps();
    deps.store.getStorageQuota = vi.fn(async () => ({ usage: 12.5 * GB, limit: 15 * GB }));
    expect(await code(uploadFiles(deps, 'u1', input()))).toBe('HMT_KHO_TEP_DAY');
    deps.store.getStorageQuota = vi.fn(async () => ({ usage: 5 * GB, limit: 15 * GB }));
    expect(await code(uploadFiles(deps, 'u1', input()))).toBe(null);
  });
  it('luật chặn trùng: trùng ảnh đã nộp thì báo; trùng lần tải dở thì cho nộp lại', async () => {
    const dup = makeDeps({ insertPending: vi.fn(async () => 'TRUNG' as const) });
    expect(await code(uploadFiles(dup.deps, 'u1', input()))).toBe('HMT_TEP_TRUNG');
    let first = true;
    const retry = makeDeps({ insertPending: vi.fn(async () => (first ? ((first = false), 'TRUNG' as const) : ('OK' as const))), supersedePending: vi.fn(async () => 1) });
    expect((await uploadFiles(retry.deps, 'u1', input())).files).toHaveLength(1);
  });
  it('lưu vào kho hỏng: dòng sổ trả về DA_XOA (không treo CHO_TAI), lỗi được ném tiếp', async () => {
    const { deps, rows } = makeDeps();
    deps.store.save = vi.fn(async () => { throw new FlowError('HMT_KHO_TEP_LOI', 'x', 502); });
    expect(await code(uploadFiles(deps, 'u1', input()))).toBe('HMT_KHO_TEP_LOI');
    expect(rows.get('id-1')?.status).toBe('DA_XOA');
    expect(deps.markReady).not.toHaveBeenCalled();
  });
});

describe('viewFile', () => {
  it('hàm DB cho phép thì đọc từ kho: ảnh thu nhỏ khi xin thumb, ảnh đầy khi không', async () => {
    const { deps } = makeDeps();
    expect((await viewFile(deps, { id: 'x', thumb: true })).mimeType).toBe('image/webp');
    expect(deps.store.read).toHaveBeenLastCalledWith('T');
    expect((await viewFile(deps, { id: 'x', thumb: false })).mimeType).toBe('image/png');
    expect(deps.store.read).toHaveBeenLastCalledWith('K');
  });
  it('luật quyền xem: bị chặn thì không đọc kho', async () => {
    const { deps } = makeDeps({ authorizeView: vi.fn(async () => { throw new FlowError('HMT_KHONG_CO_QUYEN', 'x', 403); }) });
    expect(await code(viewFile(deps, { id: 'x', thumb: false }))).toBe('HMT_KHONG_CO_QUYEN');
    expect(deps.store.read).not.toHaveBeenCalled();
  });
});
