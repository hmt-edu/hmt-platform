// Đổi người đăng nhập trong cùng thẻ thì xoá bộ nhớ đệm dữ liệu (T2-08/T2-12); cùng người làm mới phiên thì giữ.
import { act, render } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { queryClient } from '../query';

type Listener = (event: string, session: unknown) => void;
const hooks = vi.hoisted(() => ({ listener: null as null | ((e: string, s: unknown) => void) }));

vi.mock('../supabase', () => {
  // Một đối tượng cố định: getSupabase trả mới mỗi lần sẽ làm useEffect chạy lại mãi.
  const client = {
    auth: {
      getSession: () =>
        Promise.resolve({ data: { session: { user: { id: 'u1' }, access_token: 'x.e30.y' } } }),
      onAuthStateChange: (cb: Listener) => {
        hooks.listener = cb;
        return { data: { subscription: { unsubscribe: () => undefined } } };
      },
    },
  };
  return { getSupabase: () => client };
});

import { AuthProvider } from './AuthProvider';

const sessionOf = (id: string) => ({ user: { id }, access_token: 'x.e30.y' });

describe('AuthProvider: bộ nhớ đệm khi đổi người', () => {
  beforeEach(() => {
    queryClient.clear();
    hooks.listener = null;
  });

  async function mount() {
    render(<AuthProvider>{null}</AuthProvider>);
    await act(async () => {
      await Promise.resolve();
    });
    queryClient.setQueryData(['du-lieu'], 'của người trước');
  }

  it('đổi sang người khác: xoá bộ nhớ đệm', async () => {
    await mount();
    act(() => hooks.listener?.('SIGNED_IN', sessionOf('u2')));
    expect(queryClient.getQueryData(['du-lieu'])).toBeUndefined();
  });

  it('đăng xuất: xoá bộ nhớ đệm', async () => {
    await mount();
    act(() => hooks.listener?.('SIGNED_OUT', null));
    expect(queryClient.getQueryData(['du-lieu'])).toBeUndefined();
  });

  it('cùng người làm mới phiên: giữ bộ nhớ đệm', async () => {
    await mount();
    act(() => hooks.listener?.('TOKEN_REFRESHED', sessionOf('u1')));
    expect(queryClient.getQueryData(['du-lieu'])).toBe('của người trước');
  });
});
