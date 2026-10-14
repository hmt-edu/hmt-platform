import { useEffect, useRef } from 'react';
import { TEST_CAPTCHA_TOKEN, turnstileSiteKey } from '../lib/auth/turnstile';
import { Icon } from './icons';

// Cloudflare Turnstile (chống máy dò mật khẩu). Local/CI không có site key thì dùng mã thử của Cloudflare
// (khớp khoá bí mật thử trong supabase/config.toml), không tải script ngoài.

type TurnstileApi = {
  render: (el: HTMLElement, options: Record<string, unknown>) => string;
  remove: (id: string) => void;
};

declare global {
  interface Window {
    turnstile?: TurnstileApi | undefined;
  }
}

const SCRIPT_URL = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

/**
 * Ô xác minh chống máy tự động. Mỗi mã chỉ dùng được một lần: sau mỗi lần gửi biểu mẫu, trang đổi
 * `attempt` để lấy mã mới.
 */
export function TurnstileSlot({
  onToken,
  attempt = 0,
}: {
  onToken: (token: string | null) => void;
  attempt?: number | undefined;
}) {
  const box = useRef<HTMLDivElement>(null);
  const siteKey = turnstileSiteKey();

  useEffect(() => {
    if (!siteKey) {
      onToken(TEST_CAPTCHA_TOKEN);
      return;
    }
    onToken(null);
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
  }, [siteKey, onToken, attempt]);

  if (!siteKey) {
    return (
      <p className="flex min-h-16 items-center gap-2 rounded-control border border-border-strong bg-surface-subtle px-3 text-body text-fg">
        <Icon name="check" className="text-success" />
        Đã xác minh (môi trường thử)
      </p>
    );
  }
  return <div ref={box} className="min-h-16" />;
}
