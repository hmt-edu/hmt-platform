import { useEffect, useRef } from 'react';

import { TEST_CAPTCHA_TOKEN, turnstileSiteKey } from '../lib/auth/turnstile';

// Cloudflare Turnstile (chống máy dò mật khẩu). Local/CI không có site key thì dùng mã thử của Cloudflare
// (khớp khoá bí mật thử trong supabase/config.toml), không tải script ngoài.

type TurnstileApi = {
  render: (el: HTMLElement, options: Record<string, unknown>) => string;
  remove: (id: string) => void;
};

declare global {
  interface Window {
    turnstile?: TurnstileApi;
  }
}

const SCRIPT_URL = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

export function Turnstile({ onToken }: { onToken: (token: string | null) => void }) {
  const box = useRef<HTMLDivElement>(null);
  const siteKey = turnstileSiteKey();

  useEffect(() => {
    if (!siteKey) {
      onToken(TEST_CAPTCHA_TOKEN);
      return;
    }
    let widgetId: string | null = null;
    const render = () => {
      if (!box.current || !window.turnstile) return;
      widgetId = window.turnstile.render(box.current, {
        sitekey: siteKey,
        language: 'vi',
        callback: (token: string) => onToken(token),
        'expired-callback': () => onToken(null),
        'error-callback': () => onToken(null),
      });
    };
    if (window.turnstile) {
      render();
    } else {
      const script = document.createElement('script');
      script.src = SCRIPT_URL;
      script.async = true;
      script.onload = render;
      document.head.appendChild(script);
    }
    return () => {
      if (widgetId && window.turnstile) window.turnstile.remove(widgetId);
    };
  }, [siteKey, onToken]);

  return siteKey ? <div ref={box} className="min-h-16" /> : null;
}
