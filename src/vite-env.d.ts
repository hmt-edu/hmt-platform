/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL?: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY?: string;
  readonly VITE_APP_ENV?: string;
  readonly VITE_TURNSTILE_SITE_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

// Mục lục Hướng dẫn tự sinh từ phần đầu các bài (scripts/vite-huong-dan-muc-luc.ts).
declare module 'virtual:huong-dan-muc-luc' {
  const index: import('./pages/huong-dan/frontmatter').GuideMeta[];
  export default index;
}
