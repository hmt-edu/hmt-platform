// Ô tìm kiếm toàn hệ thống (CHUNG-11, canvas K1): gõ tên, số điện thoại, mã mới hoặc mã cũ; kết quả nhóm theo loại; Enter hoặc bấm để mở.
// Gọi app.search_records (chạy bằng quyền người gọi nên chỉ ra bản ghi được xem). Điện thoại: thu thành biểu tượng, bấm mới mở ô.
import { useQuery } from '@tanstack/react-query';
import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { errorOf, rpc, useDb, useIntSetting } from '../lib/db';
import { useDebounced } from '../lib/useDebounced';
import { IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Icon } from '../ui/icons';
import { groupHits, hitPath, type SearchHit } from './searchLogic';

export function GlobalSearch() {
  const supabase = useDb();
  const navigate = useNavigate();
  const minLength = useIntSetting('search_min_length');
  const listId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const boxRef = useRef<HTMLDivElement>(null);
  const [text, setText] = useState('');
  const [open, setOpen] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [active, setActive] = useState(0);
  const debounced = useDebounced(text.trim());
  const enabled = minLength !== null && debounced.length >= minLength;

  const result = useQuery({
    queryKey: ['global-search', debounced],
    enabled,
    staleTime: 30_000, // allow-number: giữ kết quả 30 giây để gõ lại cùng chữ không gọi lại máy chủ
    queryFn: () => rpc<SearchHit[]>(supabase, 'search_records', { p_query: debounced }),
  });
  const groups = useMemo(() => groupHits(result.data ?? []), [result.data]);
  const flat = useMemo(() => groups.flatMap((g) => g.hits), [groups]);

  useEffect(() => {
    const onDown = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, []);

  function go(hit: SearchHit | undefined) {
    const path = hit ? hitPath(hit) : null;
    if (!path) return;
    setOpen(false);
    setText('');
    setExpanded(false);
    void navigate(path);
  }

  function onKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Escape') {
      setOpen(false);
      setExpanded(false);
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((i) => Math.min(i + 1, flat.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((i) => Math.max(i - 1, 0));
    } else if (e.key === 'Enter') {
      go(flat[active]);
    }
  }

  const showPanel = open && enabled;
  let index = -1;
  return (
    <div ref={boxRef} className="relative">
      {!expanded && (
        <IconButton
          icon="search"
          label="Tìm kiếm"
          className="md:hidden"
          onClick={() => {
            setExpanded(true);
            setOpen(true);
            setTimeout(() => inputRef.current?.focus(), 0);
          }}
        />
      )}
      <div
        className={cn(
          'items-center gap-2 rounded-control border border-border bg-surface px-2.5 focus-within:border-brand-500',
          expanded
            ? 'fixed inset-x-3 top-2 z-30 flex h-control'
            : 'hidden h-control w-64 md:flex lg:w-80',
        )}
      >
        <Icon name="search" size={16} className="shrink-0 text-fg-muted" />
        <input
          ref={inputRef}
          type="search"
          role="combobox"
          aria-label="Tìm kiếm toàn hệ thống"
          aria-expanded={showPanel}
          aria-controls={listId}
          value={text}
          placeholder="Tìm tên, số điện thoại, mã…"
          className="min-w-0 flex-1 bg-transparent text-body outline-none"
          onChange={(e) => {
            setText(e.target.value);
            setOpen(true);
            setActive(0);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={onKeyDown}
        />
      </div>
      {showPanel && (
        <div
          id={listId}
          role="listbox"
          aria-label="Kết quả tìm kiếm"
          className={cn(
            'z-30 max-h-[70vh] overflow-y-auto rounded-box border border-border bg-surface p-1 shadow-lg',
            expanded
              ? 'fixed inset-x-3 top-14'
              : 'absolute top-full right-0 mt-1 w-[28rem] max-w-[90vw]',
          )}
        >
          {result.isError ? (
            <p className="p-3 text-body text-danger">{errorOf(result.error).message}</p>
          ) : result.isPending ? (
            <p className="p-3 text-body text-fg-muted">Đang tìm…</p>
          ) : groups.length === 0 ? (
            <div className="p-3">
              <p className="text-body font-semibold">Không tìm thấy</p>
              <p className="text-body text-fg-muted">
                Không có kết quả cho “{debounced}”. Thử mã, số điện thoại hoặc tên khác.
              </p>
            </div>
          ) : (
            groups.map((g) => (
              <div key={g.type} role="group" aria-label={g.label}>
                <p className="px-2 pt-2 pb-1 text-caption font-semibold text-fg-muted">
                  {g.label} · {g.hits.length}
                </p>
                {g.hits.map((h) => {
                  index += 1;
                  const mine = index;
                  return (
                    <button
                      key={`${h.entity_type}-${h.entity_id}`}
                      type="button"
                      role="option"
                      aria-selected={mine === active}
                      onMouseEnter={() => setActive(mine)}
                      onClick={() => go(h)}
                      className={cn(
                        'flex w-full items-baseline gap-2 rounded-control px-2 py-1.5 text-left text-body',
                        mine === active && 'bg-surface-subtle',
                      )}
                    >
                      <span className="tabular shrink-0 text-fg-muted">{h.code ?? ''}</span>
                      <span className="min-w-0 flex-1 truncate font-medium">{h.title}</span>
                      {h.subtitle && (
                        <span className="max-w-40 shrink-0 truncate text-fg-muted">
                          {h.subtitle}
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}
