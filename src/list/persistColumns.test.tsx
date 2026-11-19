import { act, render } from '@testing-library/react';
import { beforeEach, describe, expect, it } from 'vitest';
import { useEffect, useState } from 'react';
import { AuthContext, type AuthState } from '../lib/auth/authContext';
import { columnsStorageKey, readSavedColumns, usePersistedColumns } from './persistColumns';
import type { ListState } from './types';

const SCREEN = 'DON_HANG';
const EMPTY = { columns: [] } as unknown as ListState;
// Hộp ghi lại trạng thái và hàm đổi của màn thử (cập nhật trong effect, không gán biến ngoài lúc vẽ).
const box: { state: ListState; set: (next: ListState) => void } = {
  state: EMPTY,
  set: () => undefined,
};

function Probe() {
  const [state, setState] = useState<ListState>(EMPTY);
  useEffect(() => {
    box.state = state;
    box.set = setState;
  }, [state]);
  usePersistedColumns(SCREEN, state, setState);
  return null;
}

const auth = (id: string) => ({ session: { user: { id } } }) as unknown as AuthState;

function mount(userId: string) {
  return render(
    <AuthContext.Provider value={auth(userId)}>
      <Probe />
    </AuthContext.Provider>,
  );
}

describe('K03: cột chọn ở nút «Cột» giữ sau khi tải lại', () => {
  beforeEach(() => window.localStorage.clear());

  it('chọn cột rồi mở lại màn: cột đã chọn được áp lại', async () => {
    const first = mount('u1');
    act(() => box.set({ ...box.state, columns: ['code', 'parent'] }));
    expect(readSavedColumns('u1', SCREEN)).toEqual(['code', 'parent']);
    first.unmount();
    mount('u1');
    await act(async () => Promise.resolve());
    expect(box.state.columns).toEqual(['code', 'parent']);
    expect(readSavedColumns('u1', SCREEN)).toEqual(['code', 'parent']);
  });

  it('người khác trên cùng trình duyệt không thấy cột của người trước', async () => {
    window.localStorage.setItem(columnsStorageKey('u1', SCREEN), JSON.stringify(['code']));
    mount('u2');
    await act(async () => Promise.resolve());
    expect(box.state.columns).toEqual([]);
  });

  it('Đặt lại (cột rỗng) xoá bản đã lưu', async () => {
    window.localStorage.setItem(columnsStorageKey('u1', SCREEN), JSON.stringify(['code']));
    mount('u1');
    await act(async () => Promise.resolve());
    act(() => box.set({ ...box.state, columns: [] }));
    expect(readSavedColumns('u1', SCREEN)).toBeNull();
  });

  it('dữ liệu lưu hỏng thì bỏ qua, không lỗi', async () => {
    window.localStorage.setItem(columnsStorageKey('u1', SCREEN), '{không phải mảng');
    mount('u1');
    await act(async () => Promise.resolve());
    expect(box.state.columns).toEqual([]);
  });
});
