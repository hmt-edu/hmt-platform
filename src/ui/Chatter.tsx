// Cột phải của bản ghi (K3): "Ghi chú & hoạt động". Ô viết ghi chú (gõ @ nhắc đồng nghiệp), hoạt động sắp tới
// (nơi dùng truyền vào), dòng thời gian chia theo ngày với bộ lọc Tất cả / Ghi chú / Hệ thống.
// Thành phần chỉ lo hiển thị và gõ; dữ liệu do nơi dùng truyền vào (xem src/features/chatter).
import { useId, useRef, useState, type KeyboardEvent, type ReactNode } from 'react';
import { formatDmy } from '../lib/dateText';
import { formatTime } from '../lib/format';
import { Button, IconButton } from './Button';
import { cn } from './cn';
import { Alert, Avatar, Spinner, StateView } from './Feedback';
import { TEXTAREA_CLASS } from './Field';
import { Icon } from './icons';

export type ChatterChange = { label: string; from: string; to: string };
export type ChatterEntry =
  | {
      kind: 'note';
      id: string;
      at: string;
      author: string;
      body: string;
      mentions: string[];
      /** Ghi chú đến từ bản ghi khác (lead gốc của cơ hội): "Lead LD000012". */
      source?: string | undefined;
    }
  | { kind: 'change'; id: string; at: string; author: string; changes: ChatterChange[] }
  | { kind: 'system'; id: string; at: string; author: string; text: string };

export type Person = { id: string; name: string; hint?: string | undefined };
export type ChatterFilter = 'all' | 'notes' | 'system';

const FILTERS: { value: ChatterFilter; label: string }[] = [
  { value: 'all', label: 'Tất cả' },
  { value: 'notes', label: 'Ghi chú' },
  { value: 'system', label: 'Hệ thống' },
];

/** Tô đậm các tên được nhắc (@Tên) trong nội dung ghi chú. */
function renderBody(body: string, mentions: string[]): ReactNode {
  if (mentions.length === 0) return body;
  const tokens = mentions.map((name) => `@${name}`).sort((a, b) => b.length - a.length);
  const parts: ReactNode[] = [];
  let rest = body;
  let key = 0;
  while (rest.length > 0) {
    let found: { index: number; token: string } | null = null;
    for (const token of tokens) {
      const index = rest.indexOf(token);
      if (index >= 0 && (found === null || index < found.index)) found = { index, token };
    }
    if (!found) break;
    parts.push(rest.slice(0, found.index));
    parts.push(
      <strong key={key++} className="font-semibold text-link">
        {found.token}
      </strong>,
    );
    rest = rest.slice(found.index + found.token.length);
  }
  parts.push(rest);
  return parts;
}

function Composer({
  onSend,
  searchPeople,
}: {
  onSend: (body: string, mentionIds: string[]) => Promise<void>;
  searchPeople: (query: string) => Promise<Person[]>;
}) {
  const listId = useId();
  const textRef = useRef<HTMLTextAreaElement>(null);
  const [body, setBody] = useState('');
  const [picked, setPicked] = useState<Person[]>([]);
  const [people, setPeople] = useState<Person[] | null>(null);
  const [active, setActive] = useState(0);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const requestRef = useRef(0);

  /** Chữ đang gõ sau dấu @ gần con trỏ nhất (null nếu không đang nhắc tên). */
  const mentionQuery = (text: string, caret: number): string | null => {
    const match = /(^|\s)@([^\s@]*(?: [^\s@]+){0,3})$/.exec(text.slice(0, caret));
    return match ? (match[2] ?? '') : null;
  };

  const refreshPeople = (text: string, caret: number) => {
    const query = mentionQuery(text, caret);
    if (query === null) {
      setPeople(null);
      return;
    }
    const request = ++requestRef.current;
    void searchPeople(query).then(
      (found) => {
        if (request !== requestRef.current) return;
        setPeople(found);
        setActive(0);
      },
      () => request === requestRef.current && setPeople([]),
    );
  };

  const choose = (person: Person) => {
    const area = textRef.current;
    const caret = area?.selectionStart ?? body.length;
    const before = body.slice(0, caret).replace(/@[^@]*$/, `@${person.name} `);
    setBody(before + body.slice(caret));
    setPicked((current) =>
      current.some((p) => p.id === person.id) ? current : [...current, person],
    );
    setPeople(null);
    requestAnimationFrame(() => {
      area?.focus();
      area?.setSelectionRange(before.length, before.length);
    });
  };

  const send = async () => {
    const text = body.trim();
    if (text === '' || sending) return;
    setSending(true);
    setError(null);
    try {
      // Chỉ báo cho người mà tên còn nằm trong nội dung lúc gửi.
      await onSend(
        text,
        picked.filter((p) => text.includes(`@${p.name}`)).map((p) => p.id),
      );
      setBody('');
      setPicked([]);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Chưa gửi được ghi chú. Thử lại.');
    } finally {
      setSending(false);
    }
  };

  const onKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (people && people.length > 0) {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        const step = event.key === 'ArrowDown' ? 1 : -1;
        setActive((i) => (i + step + people.length) % people.length);
        return;
      }
      if (event.key === 'Enter' || event.key === 'Tab') {
        const person = people[active];
        if (person) {
          event.preventDefault();
          choose(person);
          return;
        }
      }
    }
    if (event.key === 'Escape' && people) {
      event.preventDefault();
      setPeople(null);
      return;
    }
    if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      void send();
    }
  };

  return (
    <div className="flex flex-col gap-2">
      <div className="relative">
        <textarea
          ref={textRef}
          rows={3}
          value={body}
          onChange={(e) => {
            setBody(e.target.value);
            refreshPeople(e.target.value, e.target.selectionStart);
          }}
          onKeyDown={onKeyDown}
          onBlur={() => setPeople(null)}
          aria-label="Ghi chú"
          role="combobox"
          aria-expanded={people !== null}
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={people?.[active] ? `${listId}-${active}` : undefined}
          placeholder="Viết ghi chú… gõ @ để nhắc đồng nghiệp"
          className={TEXTAREA_CLASS}
        />
        {people !== null && (
          <ul
            id={listId}
            role="listbox"
            aria-label="Đồng nghiệp"
            className="absolute inset-x-0 top-full z-20 mt-1 max-h-60 overflow-y-auto rounded-box border border-border bg-surface p-1.5 shadow-2"
          >
            {people.length === 0 && (
              <li className="px-2 py-2 text-fg-muted">Không tìm thấy đồng nghiệp nào.</li>
            )}
            {people.map((person, index) => (
              <li
                key={person.id}
                id={`${listId}-${index}`}
                role="option"
                aria-selected={index === active}
                // Giữ focus ở ô gõ: chọn bằng chuột không làm mất con trỏ.
                onMouseDown={(event) => {
                  event.preventDefault();
                  choose(person);
                }}
                className={cn(
                  'flex min-h-8 cursor-pointer flex-col justify-center rounded-tag px-2 py-1 max-md:min-h-target',
                  index === active && 'bg-hover',
                )}
              >
                <span>{person.name}</span>
                {person.hint && <span className="text-caption text-fg-muted">{person.hint}</span>}
              </li>
            ))}
          </ul>
        )}
      </div>
      {error && <Alert tone="danger">{error}</Alert>}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-1">
          <IconButton
            icon="at"
            label="Nhắc đồng nghiệp"
            onClick={() => {
              const next = body === '' || body.endsWith(' ') ? `${body}@` : `${body} @`;
              setBody(next);
              textRef.current?.focus();
              refreshPeople(next, next.length);
            }}
          />
          {/* Đính kèm (CHUNG-21): chưa có nơi lưu tệp nên nút tắt, nói rõ lý do. */}
          <IconButton icon="attach" label="Đính kèm tệp (có từ giai đoạn 4)" disabled />
        </div>
        <Button
          icon="send"
          loading={sending}
          disabled={body.trim() === ''}
          onClick={() => void send()}
        >
          Gửi ghi chú
        </Button>
      </div>
    </div>
  );
}

function Entry({ entry }: { entry: ChatterEntry }) {
  const system = entry.kind !== 'note';
  return (
    <li className="flex gap-2.5 px-4 py-2">
      {system ? (
        <span className="flex size-[30px] shrink-0 items-center justify-center rounded-full bg-surface-subtle text-fg-label">
          <Icon name={entry.kind === 'change' ? 'history' : 'system'} size={16} />
        </span>
      ) : (
        <Avatar name={entry.author} large />
      )}
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <p className="text-caption text-fg-muted">
          <b className="font-semibold text-fg">
            {system && entry.kind === 'system' ? 'Hệ thống' : entry.author}
          </b>
          {' · '}
          <span className="tabular">{formatTime(entry.at)}</span>
          {entry.kind === 'note' && ' · Ghi chú'}
          {entry.kind === 'note' && entry.source && (
            <>
              {' · '}
              <span className="rounded-full bg-neutral-100 px-1.5 py-0.5 text-caption font-semibold text-fg-muted">
                Từ {entry.source}
              </span>
            </>
          )}
        </p>
        {entry.kind === 'note' && (
          <p className="rounded-control border border-brand-200 bg-brand-50 px-2.5 py-1.5 break-words whitespace-pre-wrap">
            {renderBody(entry.body, entry.mentions)}
          </p>
        )}
        {entry.kind === 'system' && <p>{entry.text}</p>}
        {entry.kind === 'change' && (
          <ul className="flex flex-col gap-0.5">
            {entry.changes.map((change) => (
              <li key={change.label} className="flex flex-wrap items-center gap-x-1.5 text-caption">
                <span className="text-fg-muted">{change.label}:</span>
                <del className="text-fg-muted">{change.from}</del>
                <Icon name="arrowRight" size={16} className="text-fg-muted" />
                <span className="sr-only">đổi thành</span>
                <strong className="font-semibold">{change.to}</strong>
              </li>
            ))}
          </ul>
        )}
      </div>
    </li>
  );
}

/** Nhãn ngày của dòng thời gian: "Hôm nay · 13/10/2026" hoặc "12/10/2026". */
function dayLabel(iso: string, today: Date): string {
  const date = new Date(iso);
  const same =
    date.getFullYear() === today.getFullYear() &&
    date.getMonth() === today.getMonth() &&
    date.getDate() === today.getDate();
  return same ? `Hôm nay · ${formatDmy(date)}` : formatDmy(date);
}

export function Chatter({
  entries,
  status,
  onRetry,
  onSend,
  searchPeople,
  canWrite = true,
  disabled = false,
  actions,
  upcoming,
  headerRight,
  today = new Date(),
}: {
  entries: ChatterEntry[];
  status: 'ready' | 'loading' | 'error' | 'forbidden';
  onRetry?: (() => void) | undefined;
  onSend: (body: string, mentionIds: string[]) => Promise<void>;
  searchPeople: (query: string) => Promise<Person[]>;
  canWrite?: boolean | undefined;
  /** Bản ghi chưa lưu (đang Tạo): cả cột mờ, chưa dùng được cho tới khi lưu. */
  disabled?: boolean | undefined;
  /** Hàng nút nghiệp vụ trên ô ghi chú (Lên lịch hẹn, Tạo lịch Test). */
  actions?: ReactNode | undefined;
  /** Khối "Hoạt động sắp tới" do màn truyền vào. */
  upcoming?: ReactNode | undefined;
  /** Góc phải của tiêu đề (nút Theo dõi). */
  headerRight?: ReactNode | undefined;
  today?: Date | undefined;
}) {
  const [filter, setFilter] = useState<ChatterFilter>('all');
  const shown = entries.filter(
    (e) => filter === 'all' || (filter === 'notes' ? e.kind === 'note' : e.kind !== 'note'),
  );
  // Gom theo ngày, giữ thứ tự mới nhất trước.
  const days: { label: string; items: ChatterEntry[] }[] = [];
  for (const entry of shown) {
    const label = dayLabel(entry.at, today);
    const last = days[days.length - 1];
    if (last && last.label === label) last.items.push(entry);
    else days.push({ label, items: [entry] });
  }

  if (status === 'forbidden') {
    return (
      <div className="rounded-box border border-border bg-surface">
        <StateView kind="forbidden" title="Bạn không có quyền xem trao đổi" headingLevel={2}>
          Ghi chú và hoạt động của bản ghi này chỉ dành cho người có quyền xem bản ghi.
        </StateView>
      </div>
    );
  }

  return (
    <section
      aria-label="Ghi chú & hoạt động"
      aria-disabled={disabled || undefined}
      inert={disabled}
      className={cn(
        'flex flex-col rounded-box border border-border bg-surface',
        disabled && 'opacity-50',
      )}
    >
      <header className="flex items-center gap-2 px-4 pt-3 pb-2.5">
        <h2 className="mr-auto font-display text-h4">Ghi chú &amp; hoạt động</h2>
        {headerRight}
      </header>
      <div className="flex flex-col gap-2.5 px-4 pb-3">
        {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
        {canWrite && <Composer onSend={onSend} searchPeople={searchPeople} />}
      </div>
      {upcoming}
      <div className="border-t border-border px-4 pt-2.5 pb-2">
        <p className="mb-1.5 text-caption font-semibold text-fg-muted">DÒNG THỜI GIAN</p>
        <div role="group" aria-label="Lọc dòng thời gian" className="flex flex-wrap gap-1.5">
          {FILTERS.map((item) => (
            <button
              key={item.value}
              type="button"
              aria-pressed={filter === item.value}
              onClick={() => setFilter(item.value)}
              className={cn(
                'focus-ring tap h-control-sm rounded-full border px-3 text-caption',
                filter === item.value
                  ? 'border-border-selected bg-selected font-semibold text-brand-800'
                  : 'border-border-strong bg-surface hover:bg-hover',
              )}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>
      <div className="border-t border-border pb-2">
        {status === 'loading' && <Spinner label="Đang tải trao đổi…" />}
        {status === 'error' && (
          <StateView
            kind="error"
            title="Không tải được trao đổi"
            headingLevel={2}
            actions={onRetry && <Button onClick={onRetry}>Thử lại</Button>}
          >
            Kiểm tra mạng rồi bấm Thử lại.
          </StateView>
        )}
        {status === 'ready' && shown.length === 0 && (
          <StateView kind="empty" title="Chưa có ghi chú" headingLevel={2}>
            Ghi chú của bản ghi này sẽ hiện ở đây. Gõ @ để nhắc đồng nghiệp.
          </StateView>
        )}
        {status === 'ready' &&
          days.map((day) => (
            <div key={day.label}>
              <p className="flex items-center gap-2 px-4 pt-2.5 pb-1 text-caption font-semibold text-fg-muted before:h-px before:flex-1 before:bg-border after:h-px after:flex-1 after:bg-border">
                {day.label}
              </p>
              <ul>
                {day.items.map((entry) => (
                  <Entry key={`${entry.kind}-${entry.id}`} entry={entry} />
                ))}
              </ul>
            </div>
          ))}
      </div>
    </section>
  );
}
