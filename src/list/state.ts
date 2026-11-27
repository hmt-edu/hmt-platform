// Logic thuần của khuôn danh sách: trạng thái bộ lọc, chip, tóm tắt, lọc trong trình duyệt, nhóm, khoảng ngày.
// Không phụ thuộc giao diện nên có kiểm thử; màn dữ liệu lớn dùng `ListState` để dựng truy vấn ở máy chủ.
import { customRangeDays, datePresetInstants, datePresetRange } from '../lib/dateRange';
import { formatDmy } from '../lib/dateText';
import {
  OPERATORS_BY_TYPE,
  type Condition,
  type FieldType,
  type FilterField,
  type GroupField,
  type ListConfig,
  type ListState,
} from './types';

export const MAX_GROUP_LEVELS = 2; // allow-number: Group By tối đa hai cấp theo thiết kế (K1_nhom)

export { datePresetInstants, datePresetRange };

export const DATE_PRESETS = [
  { key: '', label: 'Tất cả thời gian' },
  { key: 'today', label: 'Hôm nay' },
  { key: 'week', label: 'Tuần này' },
  { key: 'last-week', label: 'Tuần trước' },
  { key: 'month', label: 'Tháng này' },
  { key: 'last-month', label: 'Tháng trước' },
] as const;

/** Chữ của mốc đang chọn; khoảng tự chọn hiện "dd/mm/yyyy – dd/mm/yyyy". */
export function datePresetLabel(preset: string): string {
  const custom = customRangeDays(preset);
  if (custom) return `${formatDmy(custom.from)} – ${formatDmy(custom.to)}`;
  return DATE_PRESETS.find((p) => p.key === preset)?.label ?? preset;
}

export function emptyState<Row>(config: ListConfig<Row>): ListState {
  return {
    search: '',
    quick: {},
    conditions: [],
    group: [],
    columns: [],
    dateField: config.dateFields[0]?.key ?? '',
    datePreset: '',
  };
}

/** Bảng K03 mặc định hiện tối đa bấy nhiêu cột (mẫu B12, 23/11/2026); còn lại để người dùng bật ở nút «Cột». */
export const DEFAULT_MAX_COLUMNS = 8; // allow-number: giới hạn hiển thị mặc định theo mẫu rà soát B12, không phải số nghiệp vụ

/**
 * Cột hiện mặc định theo cấu hình, giữ đúng thứ tự khai báo: cột khoá luôn có; các cột còn lại lấy theo thứ tự cho tới khi đủ
 * DEFAULT_MAX_COLUMNS (cột khoá tính vào số này). Cột nào cấu hình đặt `defaultVisible: false` thì không vào mặc định.
 */
export function defaultColumnKeys<Row>(config: ListConfig<Row>): string[] {
  const locked = config.columns.filter((c) => c.locked).length;
  let room = Math.max(DEFAULT_MAX_COLUMNS - locked, 0);
  return config.columns
    .filter((c) => {
      if (c.locked) return true;
      if (c.defaultVisible === false || room <= 0) return false;
      room -= 1;
      return true;
    })
    .map((c) => c.key);
}

/** Cột đang hiện, theo thứ tự người dùng chọn; cột khoá luôn hiện và luôn đứng đầu. */
export function visibleColumnKeys<Row>(config: ListConfig<Row>, state: ListState): string[] {
  const chosen = state.columns.length > 0 ? state.columns : defaultColumnKeys(config);
  const known = new Set(config.columns.map((c) => c.key));
  const locked = config.columns.filter((c) => c.locked).map((c) => c.key);
  const rest = chosen.filter((k) => known.has(k) && !locked.includes(k));
  return [...locked, ...rest];
}

export type Chip = {
  id: string;
  kind: 'quick' | 'search' | 'condition' | 'group' | 'date';
  label: string;
};

function optionLabel<Row>(config: ListConfig<Row>, groupKey: string, value: string): string {
  const group = config.quickGroups.find((g) => g.key === groupKey);
  return group?.options.find((o) => o.value === value)?.label ?? value;
}

function fieldOf<Row>(config: ListConfig<Row>, key: string): FilterField<Row> | undefined {
  return config.filterFields.find((f) => f.key === key);
}

function operatorLabel(fieldType: FieldType | undefined, cond: Condition): string {
  const ops = OPERATORS_BY_TYPE[fieldType ?? 'text'];
  return ops.find((o) => o.op === cond.op)?.label ?? cond.op;
}

function valueLabel(
  options: { value: string; label: string }[] | undefined,
  value: string | string[],
): string {
  const one = (v: string) => options?.find((o) => o.value === v)?.label ?? v;
  return Array.isArray(value) ? value.map(one).join(', ') : one(value);
}

function isFilled(cond: Condition): boolean {
  return Array.isArray(cond.value) ? cond.value.length > 0 : cond.value.trim() !== '';
}

/** Các chip hiện dưới thanh công cụ: lọc nhanh, tìm, điều kiện nâng cao, nhóm, thời gian. */
export function chipsOf<Row>(state: ListState, config: ListConfig<Row>): Chip[] {
  const chips: Chip[] = [];
  for (const group of config.quickGroups) {
    const picked = state.quick[group.key] ?? [];
    if (picked.length === 0) continue;
    chips.push({
      id: `quick:${group.key}`,
      kind: 'quick',
      label: `${group.label}: ${picked.map((v) => optionLabel(config, group.key, v)).join(' hoặc ')}`,
    });
  }
  if (state.search.trim() !== '') {
    chips.push({ id: 'search', kind: 'search', label: `Tìm: ${state.search.trim()}` });
  }
  for (const cond of state.conditions.filter(isFilled)) {
    const field = fieldOf(config, cond.field);
    chips.push({
      id: `cond:${cond.id}`,
      kind: 'condition',
      label: `${field?.label ?? cond.field} ${operatorLabel(field?.type, cond)} ${valueLabel(field?.options, cond.value)}`,
    });
  }
  if (state.group.length > 0) {
    const names = state.group.map((k) => config.groupFields.find((g) => g.key === k)?.label ?? k);
    chips.push({ id: 'group', kind: 'group', label: `Group By: ${names.join(' › ')}` });
  }
  if (state.datePreset !== '') {
    const field = config.dateFields.find((f) => f.key === state.dateField);
    chips.push({
      id: 'date',
      kind: 'date',
      label: `${field?.label ?? 'Thời gian'}: ${datePresetLabel(state.datePreset)}`,
    });
  }
  return chips;
}

export function removeChip(state: ListState, chipId: string): ListState {
  if (chipId === 'search') return { ...state, search: '' };
  if (chipId === 'group') return { ...state, group: [] };
  if (chipId === 'date') return { ...state, datePreset: '' };
  if (chipId.startsWith('quick:')) {
    const key = chipId.slice('quick:'.length);
    const rest = Object.fromEntries(Object.entries(state.quick).filter(([k]) => k !== key));
    return { ...state, quick: rest };
  }
  if (chipId.startsWith('cond:')) {
    const id = chipId.slice('cond:'.length);
    return { ...state, conditions: state.conditions.filter((c) => c.id !== id) };
  }
  return state;
}

/** Xoá mọi lọc và nhóm; giữ cột và trường ngày đang chọn. */
export function clearFilters(state: ListState): ListState {
  return { ...state, search: '', quick: {}, conditions: [], group: [], datePreset: '' };
}

export function activeCount<Row>(state: ListState, config: ListConfig<Row>): number {
  return chipsOf(state, config).length;
}

/** Câu tóm tắt cho hộp "Lưu bộ lọc hiện tại": "Của tôi: Tôi là sale · Tìm: Toán · Group By: Stage". */
export function summarize<Row>(state: ListState, config: ListConfig<Row>): string {
  const chips = chipsOf(state, config);
  return chips.length === 0 ? 'Chưa có điều kiện nào.' : chips.map((c) => c.label).join(' · ');
}

function conditionMatches<Row>(row: Row, cond: Condition, field: FilterField<Row>): boolean {
  const raw = field.get ? field.get(row) : '';
  const value = Array.isArray(cond.value) ? cond.value : cond.value.trim();
  switch (cond.op) {
    case 'contains':
      return raw.toLowerCase().includes(String(value).toLowerCase());
    case 'eq':
      return raw === value;
    case 'ne':
      return raw !== value;
    case 'in':
      return Array.isArray(value) && value.includes(raw);
    case 'from':
      return raw !== '' && raw >= String(value);
    case 'to':
      return raw !== '' && raw <= String(value);
  }
}

/**
 * Lọc trong trình duyệt (cho danh sách nhỏ và kiểm thử): cùng nhóm là HOẶC, khác nhóm là VÀ,
 * điều kiện nâng cao nối bằng VÀ; tìm theo từ khoá trên các trường văn bản.
 */
export function applyFilters<Row>(
  rows: Row[],
  state: ListState,
  config: ListConfig<Row>,
  searchText: (row: Row) => string,
  today: Date = new Date(),
): Row[] {
  const range = datePresetInstants(state.datePreset, today);
  const dateGet = config.dateFields.find((f) => f.key === state.dateField)?.get;
  const needle = state.search.trim().toLowerCase();
  return rows.filter((row) => {
    for (const group of config.quickGroups) {
      const picked = state.quick[group.key] ?? [];
      if (picked.length === 0) continue;
      const tests = group.options.filter((o) => picked.includes(o.value));
      if (!tests.some((o) => (o.test ? o.test(row) : true))) return false;
    }
    for (const cond of state.conditions.filter(isFilled)) {
      const field = fieldOf(config, cond.field);
      if (field && !conditionMatches(row, cond, field)) return false;
    }
    if (needle !== '' && !searchText(row).toLowerCase().includes(needle)) return false;
    if (range && dateGet) {
      const at = dateGet(row);
      if (!at || at < range.from || at > range.to) return false;
    }
    return true;
  });
}

export type GroupNode<Row> = {
  key: string;
  label: string;
  count: number;
  children: GroupNode<Row>[];
  rows: Row[];
};

/** Nhóm dòng theo tối đa hai cấp, giữ thứ tự xuất hiện lần đầu của từng giá trị. */
export function buildGroupTree<Row>(
  rows: Row[],
  keys: string[],
  fields: GroupField<Row>[],
  depth = 0,
  parentKey = '',
): GroupNode<Row>[] {
  const field = fields.find((f) => f.key === keys[depth]);
  if (!field) return [];
  const order: string[] = [];
  const bucket = new Map<string, Row[]>();
  for (const row of rows) {
    const value = field.value(row);
    if (!bucket.has(value)) {
      bucket.set(value, []);
      order.push(value);
    }
    bucket.get(value)?.push(row);
  }
  return order.map((value) => {
    const members = bucket.get(value) ?? [];
    const key = `${parentKey}/${field.key}=${value}`;
    const hasMore = depth + 1 < keys.length && depth + 1 < MAX_GROUP_LEVELS;
    return {
      key,
      label: value === '' ? 'Chưa có' : (field.valueLabel?.(value) ?? value),
      count: members.length,
      children: hasMore ? buildGroupTree(members, keys, fields, depth + 1, key) : [],
      rows: hasMore ? [] : members,
    };
  });
}

let counter = 0;
/** Mã điều kiện mới (chỉ cần duy nhất trong một màn). */
export function newConditionId(): string {
  counter += 1;
  return `c${Date.now().toString(36)}${counter}`;
}

/** Điều kiện trống mới cho một trường: phép so sánh đầu tiên của kiểu trường. */
export function blankCondition<Row>(field: FilterField<Row>): Condition {
  const op =
    OPERATORS_BY_TYPE[field.type].find((o) => !field.ops || field.ops.includes(o.op))?.op ?? 'eq';
  return { id: newConditionId(), field: field.key, op, value: field.type === 'multi' ? [] : '' };
}
