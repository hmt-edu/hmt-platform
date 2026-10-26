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
};

const ROLE_PREFIX = 'role:';
const EMPTY = 'trống';

function plain(value: unknown): string {
  if (value === null || value === undefined || value === '') return EMPTY;
  if (typeof value === 'boolean') return value ? 'Có' : 'Không';
  if (typeof value === 'string' || typeof value === 'number') return String(value);
  return JSON.stringify(value);
}

/** Đổi một dòng lịch sử thành các thay đổi đọc được; trường không có nhãn thì bỏ (trường kỹ thuật). */
export function describeChanges(row: HistoryRow, format: FieldFormat): ChatterChange[] {
  return Object.entries(row.changes ?? {}).flatMap(([column, pair]) => {
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
  createdText: string,
): ChatterEntry[] {
  const entries: ChatterEntry[] = [
    ...notes.map<ChatterEntry>((n) => ({
      kind: 'note',
      id: n.id,
      at: n.at,
      author: n.author_name,
      body: n.body,
      mentions: n.mention_names,
      ...(n.source_label ? { source: n.source_label } : {}),
    })),
    ...history.flatMap<ChatterEntry>((h) => {
      if (h.action === 'I') {
        return [
          { kind: 'system', id: String(h.id), at: h.at, author: h.actor_name, text: createdText },
        ];
      }
      const changes = describeChanges(h, format);
      return changes.length === 0
        ? []
        : [{ kind: 'change', id: String(h.id), at: h.at, author: h.actor_name, changes }];
    }),
  ];
  return entries.sort((a, b) => b.at.localeCompare(a.at));
}
