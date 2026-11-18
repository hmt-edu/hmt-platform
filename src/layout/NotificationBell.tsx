// Chuông thông báo (CHUNG-12, canvas Đ11): số chưa đọc, danh sách mới nhất, lọc Tất cả / Chưa đọc, bấm để đọc và mở bản ghi,
// "Đánh dấu tất cả đã đọc". Mỗi người chỉ thấy thông báo của mình (RLS notification_read_own). Số chưa đọc tự làm mới mỗi phút.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { errorOf, fetchRows, rpc, useDb, useIntSetting } from '../lib/db';
import { IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Popover } from '../ui/Overlays';
import { notificationPath, timeAgo, type NotificationRow } from './notificationLogic';

const REFRESH_MS = 60_000; // allow-number: chu kỳ làm mới số chưa đọc (một phút), không phải số nghiệp vụ

export function NotificationBell() {
  const supabase = useDb();
  const client = useQueryClient();
  const navigate = useNavigate();
  const limit = useIntSetting('list_page_size_default');
  const [open, setOpen] = useState(false);
  const [unreadOnly, setUnreadOnly] = useState(false);

  const unread = useQuery({
    queryKey: ['notification-unread'],
    refetchInterval: REFRESH_MS,
    queryFn: async () => {
      const { count, error } = await supabase
        .schema('app')
        .from('notification')
        .select('id', { count: 'exact', head: true })
        .is('read_at', null);
      if (error) throw error;
      return count ?? 0;
    },
  });

  const list = useQuery({
    queryKey: ['notification-list', unreadOnly, limit],
    enabled: open && limit !== null,
    queryFn: async () => {
      let q = supabase
        .schema('app')
        .from('notification')
        .select('id, kind, title, entity_type, entity_id, actor_id, read_at, created_at')
        .order('created_at', { ascending: false })
        .limit(limit ?? 0);
      if (unreadOnly) q = q.is('read_at', null);
      return (await fetchRows<NotificationRow>(q)).rows;
    },
  });

  const refresh = () => {
    void client.invalidateQueries({ queryKey: ['notification-unread'] });
    void client.invalidateQueries({ queryKey: ['notification-list'] });
  };

  async function openOne(n: NotificationRow) {
    try {
      if (!n.read_at) await rpc<number>(supabase, 'mark_notifications_read', { p_id: n.id });
    } finally {
      refresh();
    }
    const path = notificationPath(n);
    if (path) {
      setOpen(false);
      void navigate(path);
    }
  }

  async function readAll() {
    await rpc<number>(supabase, 'mark_notifications_read', { p_all: true });
    refresh();
  }

  const count = unread.data ?? 0;
  const now = new Date();
  return (
    <Popover
      open={open}
      onOpenChange={setOpen}
      align="end"
      className="w-96 p-0"
      trigger={
        <span className="relative inline-flex">
          <IconButton
            icon="bell"
            label={count > 0 ? `Thông báo (${count} chưa đọc)` : 'Thông báo'}
          />
          {count > 0 && (
            <span
              aria-hidden="true"
              className="tabular pointer-events-none absolute -top-0.5 -right-0.5 min-w-4 rounded-full bg-danger px-1 text-center text-caption text-neutral-0"
            >
              {count}
            </span>
          )}
        </span>
      }
    >
      <div className="flex items-center justify-between gap-2 border-b border-border p-3">
        <p className="text-h3 font-semibold">Thông báo</p>
        <button
          type="button"
          className="focus-ring text-body text-link hover:underline disabled:opacity-50"
          disabled={count === 0}
          onClick={() => void readAll()}
        >
          Đánh dấu tất cả đã đọc
        </button>
      </div>
      <div
        className="flex gap-1 border-b border-border p-2"
        role="group"
        aria-label="Lọc thông báo"
      >
        {[
          { v: false, label: 'Tất cả' },
          { v: true, label: `Chưa đọc (${count})` },
        ].map((o) => (
          <button
            key={String(o.v)}
            type="button"
            aria-pressed={unreadOnly === o.v}
            onClick={() => setUnreadOnly(o.v)}
            className={cn(
              'focus-ring rounded-control px-2.5 py-1 text-body',
              unreadOnly === o.v ? 'bg-surface-subtle font-semibold' : 'text-fg-muted',
            )}
          >
            {o.label}
          </button>
        ))}
      </div>
      <div className="max-h-[60vh] overflow-y-auto">
        {list.isError ? (
          <p className="p-3 text-body text-danger">{errorOf(list.error).message}</p>
        ) : list.isPending ? (
          <p className="p-3 text-body text-fg-muted">Đang tải…</p>
        ) : (list.data ?? []).length === 0 ? (
          <p className="p-3 text-body text-fg-muted">
            {unreadOnly ? 'Không còn thông báo chưa đọc.' : 'Chưa có thông báo.'}
          </p>
        ) : (
          <ul>
            {(list.data ?? []).map((n) => (
              <li key={n.id}>
                <button
                  type="button"
                  onClick={() => void openOne(n)}
                  className="focus-ring flex w-full gap-2 border-b border-border p-3 text-left hover:bg-surface-subtle"
                >
                  <span
                    aria-hidden="true"
                    className={cn(
                      'mt-1.5 size-2 shrink-0 rounded-full',
                      n.read_at ? 'bg-transparent' : 'bg-brand-500',
                    )}
                  />
                  <span className="min-w-0 flex-1">
                    <span className={cn('block text-body', !n.read_at && 'font-semibold')}>
                      {n.title}
                      {!n.read_at && <span className="sr-only"> (chưa đọc)</span>}
                    </span>
                    <span className="block text-caption text-fg-muted">
                      {timeAgo(n.created_at, now)}
                    </span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </Popover>
  );
}
