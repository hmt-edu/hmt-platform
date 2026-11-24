import js from '@eslint/js';
import { defineConfig, globalIgnores } from 'eslint/config';
import reactHooks from 'eslint-plugin-react-hooks';
import { reactRefresh } from 'eslint-plugin-react-refresh';
import globals from 'globals';
import tseslint from 'typescript-eslint';

const browserDialogs = ['alert', 'confirm', 'prompt'].map((name) => ({
  name,
  message: 'Không dùng hộp thoại mặc định của trình duyệt; dùng hộp thoại của hệ thống thiết kế.',
}));

export default defineConfig(
  globalIgnores([
    'dist',
    'coverage',
    'playwright-report',
    'test-results',
    'supabase',
    'docs',
    'design',
    'node_modules',
  ]),
  {
    files: ['**/*.{ts,tsx,js,mjs}'],
    extends: [js.configs.recommended, tseslint.configs.recommendedTypeChecked],
    languageOptions: {
      ecmaVersion: 2023,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      'no-alert': 'error',
      'no-restricted-globals': ['error', ...browserDialogs],
    },
  },
  {
    files: ['src/**/*.{ts,tsx}'],
    extends: [reactHooks.configs.flat['recommended-latest'], reactRefresh.configs.vite()],
    languageOptions: { globals: globals.browser },
  },
  {
    // Kịch bản chạy tay chụp ảnh hướng dẫn (JS thuần, tham số Playwright không có kiểu): không dò kiểu.
    files: ['scripts/huong-dan/**/*.mjs', 'scripts/apps-script-kho-tep/*.mjs'],
    languageOptions: { globals: { ...globals.node, ...globals.browser } },
    rules: {
      '@typescript-eslint/ban-ts-comment': 'off',
      '@typescript-eslint/no-unsafe-call': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-argument': 'off',
      '@typescript-eslint/no-unsafe-return': 'off',
    },
  },
  {
    files: ['scripts/**/*.{ts,mjs}', '*.config.{ts,js}', 'e2e/**/*.ts'],
    languageOptions: { globals: globals.node },
  },
);
