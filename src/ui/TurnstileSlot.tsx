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
      // Môi trường thử: hộp mẫu như bản vẽ DN01 (bản thật dùng khung Cloudflare ở dưới).
      <p className="flex min-h-[58px] items-center gap-2.5 rounded-control border border-dashed border-border-strong bg-canvas px-3.5 text-[13px] text-fg-label">
        <span
          aria-hidden="true"
          className="flex size-[22px] shrink-0 items-center justify-center rounded-[5px] border-[1.5px] border-success-solid bg-surface text-success-solid"
        >
          <Icon name="checkMark" size={16} />
        </span>
        Turnstile · xác minh không phải robot
      </p>
    );
  }
  return <div ref={box} className="min-h-[65px]" />;
}
