import { render, screen } from '@testing-library/react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getSupabase } from '../lib/supabase';
import { HomePage } from './HomePage';

vi.mock('../lib/supabase', async (importOriginal) => {
  const original = await importOriginal<typeof import('../lib/supabase')>();
  return { ...original, getSupabase: vi.fn(() => null) };
});

const getSupabaseMock = vi.mocked(getSupabase);

function fakeClient(rpc: () => Promise<unknown>): SupabaseClient {
  return { rpc } as unknown as SupabaseClient;
}

function configureEnv() {
  vi.stubEnv('VITE_SUPABASE_URL', 'http://127.0.0.1:54321');
  vi.stubEnv('VITE_SUPABASE_PUBLISHABLE_KEY', 'sb_publishable_test');
}

describe('HomePage', () => {
  beforeEach(() => {
    getSupabaseMock.mockReset();
    getSupabaseMock.mockReturnValue(null);
  });

  it('hiện tên môi trường và "Chưa cấu hình" khi thiếu biến môi trường', () => {
    vi.stubEnv('VITE_APP_ENV', 'staging');
    vi.stubEnv('VITE_SUPABASE_URL', '');
    vi.stubEnv('VITE_SUPABASE_PUBLISHABLE_KEY', '');

    render(<HomePage />);

    expect(screen.getByTestId('env-label').textContent).toBe('Thử nghiệm');
    expect(screen.getByText('Chưa cấu hình')).toBeTruthy();
  });

  it('hiện "Không rõ" khi VITE_APP_ENV lạ', () => {
    vi.stubEnv('VITE_APP_ENV', 'abc');
    render(<HomePage />);
    expect(screen.getByTestId('env-label').textContent).toBe('Không rõ');
  });

  it('hiện "Đã kết nối" khi system_status trả dữ liệu', async () => {
    configureEnv();
    vi.stubEnv('VITE_APP_ENV', 'local');
    getSupabaseMock.mockReturnValue(
      fakeClient(() =>
        Promise.resolve({
          data: {
            app_name: 'HMT Platform',
            schema_version: '0001',
            db_time: '2026-10-09T00:00:00Z',
          },
          error: null,
        }),
      ),
    );

    render(<HomePage />);

    expect(await screen.findByText('Đã kết nối')).toBeTruthy();
    expect(screen.getByText('HMT Platform', { selector: 'dd' })).toBeTruthy();
    expect(screen.getByText('0001')).toBeTruthy();
  });

  it('hiện "Không kết nối được" kèm thông báo lỗi', async () => {
    configureEnv();
    getSupabaseMock.mockReturnValue(
      fakeClient(() => Promise.resolve({ data: null, error: { message: 'mất mạng' } })),
    );

    render(<HomePage />);

    expect(await screen.findByText('Không kết nối được')).toBeTruthy();
    expect(screen.getByText('mất mạng')).toBeTruthy();
  });
});
