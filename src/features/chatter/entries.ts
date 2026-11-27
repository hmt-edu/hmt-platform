// Đổi ghi chú và lịch sử từ cơ sở dữ liệu thành các dòng của Chatter (hàm thuần, có kiểm thử).
import type { ChatterChange, ChatterEntry } from '../../ui/Chatter';

export type NoteRow = {
  id: string;
  at: string;
  author_name: string;
  body: string;
  mention_names: string[];
  /** Ghi chú của lead gốc hiện ở cơ hội: "Lead LD000012"; ghi chú của chính bản ghi thì null. */
  source_label?: string | null;
  /** Tên kênh và kết quả khi ghi chú là một lần liên hệ (migration 694). */
  contact_channel?: string | null;
  contact_result?: string | null;
};
export type HistoryRow = {
  id: number;
  at: string;
  actor_name: string;
  action: string;
  changes: Record<string, [unknown, unknown]> | null;
};
export type CandidateRow = {
  id: string;
  display_name: string;
  role_names: string | null;
  branch_code: string;
};

export type FieldFormat = {
  /** Tên trường hiện cho người dùng, theo tên cột trong cơ sở dữ liệu. */
  labels: Record<string, string>;
  /** Đổi giá trị thô thành chữ (vd id cơ sở thành tên cơ sở). Không có thì dùng cách mặc định. */
  value?: (column: string, value: unknown) => string | null;
  /** Cột đã có dòng sự kiện nghiệp vụ riêng (vd Tình trạng của lớp): đổi cột này cùng lúc với một sự kiện thì không hiện thêm dòng đổi trường, tránh một thao tác hai dòng. */
  coveredByEvents?: string[];
};

/** Hai dòng cách nhau không quá chừng này (mili giây) coi là cùng một thao tác. */
const SAME_ACTION_MS = 5000; // allow-number: dung sai giờ giữa sự kiện và nhật ký của một thao tác, không phải số nghiệp vụ

function sameAction(a: string, b: string): boolean {
  return Math.abs(new Date(a).getTime() - new Date(b).getTime()) <= SAME_ACTION_MS;
}

const ROLE_PREFIX = 'role:';
const EMPTY = 'trống';

function plain(value: unknown): string {
  if (value === null || value === undefined || value === '') return EMPTY;
  if (typeof value === 'boolean') return value ? 'Có' : 'Không';
  if (typeof value === 'string' || typeof value === 'number') return String(value);
  return JSON.stringify(value);
}

/** Đổi một dòng lịch sử thành các thay đổi đọc được; trường không có nhãn thì bỏ (trường kỹ thuật). */
export function describeChanges(
  row: HistoryRow,
  format: FieldFormat,
  skip: ReadonlySet<string> = new Set(),
): ChatterChange[] {
  return Object.entries(row.changes ?? {}).flatMap(([column, pair]) => {
    if (skip.has(column)) return [];
    const [from, to] = pair;
    if (column.startsWith(ROLE_PREFIX)) {
      return [
        { label: `Vai trò ${column.slice(ROLE_PREFIX.length)}`, from: plain(from), to: plain(to) },
      ];
    }
    const label = format.labels[column];
    if (!label) return [];
    return [
      {
        label,
        from: format.value?.(column, from) ?? plain(from),
        to: format.value?.(column, to) ?? plain(to),
      },
    ];
  });
}

export function buildEntries(
  notes: NoteRow[],
  history: HistoryRow[],
  format: FieldFormat,
  createdText: string | null,
  extra: ChatterEntry[] = [],
): ChatterEntry[] {
  // Sự kiện nghiệp vụ chưa có tên người làm (author rỗng): lấy người ghi nhật ký thay đổi cùng thao tác; không có thì mới ghi «Hệ thống».
  const events = extra.map((e): ChatterEntry => {
    if (e.kind !== 'system' || e.author !== '') return e;
    const row = history.find((h) => sameAction(h.at, e.at));
    return { ...e, author: row ? row.actor_name : 'Hệ thống' };
  });
  const entries: ChatterEntry[] = [
    ...notes.map<ChatterEntry>((n) => ({
      kind: 'note',
      id: n.id,
      at: n.at,
      author: n.author_name,
      body: n.body,
      mentions: n.mention_names,
      ...(n.source_label ? { source: n.source_label } : {}),
      ...(n.contact_channel ? { contact: `${n.contact_channel} · ${n.contact_result ?? ''}` } : {}),
    })),
    ...history.flatMap<ChatterEntry>((h) => {
      if (h.action === 'I') {
        // Màn có sự kiện riêng (Đơn hàng, Phiếu thu) đã có mục "Tạo" từ sự kiện: bỏ dòng "Tạo …" của nhật ký thay đổi để không lặp.
        if (createdText === null) return [];
        return [
          { kind: 'system', id: String(h.id), at: h.at, author: h.actor_name, text: createdText },
        ];
      }
      const covered = events.some((e) => e.kind === 'system' && sameAction(e.at, h.at));
      const changes = describeChanges(h, format, new Set(covered ? format.coveredByEvents : []));
      return changes.length === 0
        ? []
        : [{ kind: 'change', id: String(h.id), at: h.at, author: h.actor_name, changes }];
    }),
    ...events,
  ];
  return entries.sort((a, b) => b.at.localeCompare(a.at));
}
