import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';

const devices = vi.hoisted(() => ({ list: [] as { id: string }[] }));

vi.mock('../../lib/auth/authContext', () => ({
  useAuth: () => ({
    supabase: {},
    claims: { userId: 'u1', aal: 'aal1', requireMfa: true },
    refresh: () => Promise.resolve(),
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
