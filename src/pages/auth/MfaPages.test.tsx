import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router';
import { describe, expect, it, vi } from 'vitest';

const devices = vi.hoisted(() => ({ list: [] as { id: string }[] }));
const signOut = vi.hoisted(() => vi.fn(() => Promise.resolve()));

vi.mock('../../lib/auth/authContext', () => ({
  useAuth: () => ({
    supabase: {},
    claims: { userId: 'u1', aal: 'aal1', requireMfa: true },
    refresh: () => Promise.resolve(),
    signOut,
  }),
}));
vi.mock('../../lib/auth/mfa', () => ({
  listTotpDevices: () => Promise.resolve(devices.list),
  verifyTotpAnyDevice: () => Promise.resolve(),
}));
vi.mock('./TotpEnroll', () => ({ TotpEnroll: () => null }));

import { MfaSetupPage, MfaVerifyPage } from './MfaPages';

describe('Màn bật hai bước: chỉ nói Admin, không nhắc Kế toán (mig 647)', () => {
  it('lời dẫn không ghi Kế toán', () => {
    render(
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <MfaSetupPage />
        </MemoryRouter>
      </QueryClientProvider>,
    );
    expect(screen.getByText(/Tài khoản Admin phải bật trước/)).toBeTruthy();
    expect(screen.queryByText(/Kế toán/)).toBeNull();
  });

  it('màn nhập mã chỉ ghi «Bắt buộc với tài khoản Admin.»', async () => {
    devices.list = [{ id: 'd1' }];
    render(
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <MfaVerifyPage />
        </MemoryRouter>
      </QueryClientProvider>,
    );
    expect(await screen.findByText('Bắt buộc với tài khoản Admin.')).toBeTruthy();
  });
});

describe('Màn bật hai bước có đường thoát (A-24-04)', () => {
  it('bấm «Đăng nhập tài khoản khác»: đăng xuất và về /dang-nhap', async () => {
    devices.list = [];
    render(
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={['/thiet-lap-hai-buoc']}>
          <Routes>
            <Route path="/thiet-lap-hai-buoc" element={<MfaSetupPage />} />
            <Route path="/dang-nhap" element={<p>Trang đăng nhập</p>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    );
    fireEvent.click(await screen.findByRole('button', { name: 'Đăng nhập tài khoản khác' }));
    expect(await screen.findByText('Trang đăng nhập')).toBeTruthy();
    expect(signOut).toHaveBeenCalledTimes(1);
  });
});
