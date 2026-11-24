import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';
import { huongDanMaLoi } from './scripts/vite-huong-dan-ma-loi.ts';
import { huongDanMucLuc } from './scripts/vite-huong-dan-muc-luc.ts';

export default defineConfig({
  plugins: [react(), tailwindcss(), huongDanMucLuc(), huongDanMaLoi()],
  // Bản kê các gói để scripts/bundle-size.mjs đo dung lượng tải theo từng cổng, màn.
  build: { manifest: true },
  test: {
    environment: 'jsdom',
    include: [
      'src/**/*.test.{ts,tsx}',
      'scripts/**/*.test.ts',
      'supabase/functions/_shared/**/*.test.ts',
    ],
    setupFiles: ['./src/test/setup.ts'],
    restoreMocks: true,
    unstubEnvs: true,
  },
});
