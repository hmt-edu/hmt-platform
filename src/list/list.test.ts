import { describe, expect, it } from 'vitest';
import {
  layoutDay,
  monthGrid,
  sameDay,
  vnToday,
  weekDays,
  type CalendarEvent,
} from './calendarLogic';
import { forwardOnlyRule, freeMoveRule } from './kanbanLogic';
import {
  applyFilters,
  buildGroupTree,
  chipsOf,
  clearFilters,
  datePresetRange,
  defaultColumnKeys,
  emptyState,
  removeChip,
  summarize,
  visibleColumnKeys,
} from './state';
import type { ListConfig } from './types';

type Row = {
  id: string;
  name: string;
  stage: string;
  source: string;
  owner: string;
  late: boolean;
};
const ROWS: Row[] = [
  { id: '1', name: 'Toán 8', stage: 'L1', source: 'Website', owner: 'Hà', late: false },
  { id: '2', name: 'Toán 7', stage: 'L2', source: 'Hotline', owner: 'Hà', late: true },
  { id: '3', name: 'Lý 10', stage: 'L4', source: 'Website', owner: 'Long', late: true },
  { id: '4', name: 'Toán 9', stage: 'L4', source: 'Referral', owner: 'Hà', late: false },
];

const CONFIG: ListConfig<Row> = {
  screenCode: 'T-01',
  title: 'Mẫu',
  searchPlaceholder: 'Tìm',
  columns: [
    { key: 'code', label: 'Mã', locked: true, render: () => null },
    { key: 'name', label: 'Tên', locked: true, render: () => null },
    { key: 'stage', label: 'Stage', render: () => null },
    { key: 'source', label: 'Source', render: () => null },
    { key: 'created', label: 'Ngày tạo', defaultVisible: false, render: () => null },
  ],
  quickGroups: [
    {
      key: 'mine',
      label: 'Của tôi',
      options: [
        { value: 'ha', label: 'Tôi là Hà', test: (r) => r.owner === 'Hà' },
        { value: 'long', label: 'Tôi là Long', test: (r) => r.owner === 'Long' },
      ],
    },
    {
      key: 'time',
      label: 'Lịch hẹn',
      options: [{ value: 'late', label: 'Quá hạn', test: (r) => r.late }],
    },
  ],
  filterFields: [
    {
      key: 'source',
      label: 'Source',
      type: 'select',
      get: (r) => r.source,
      options: [{ value: 'Website', label: 'Website' }],
    },
    {
      key: 'stage',
      label: 'Stage',
      type: 'multi',
      get: (r) => r.stage,
      options: [
        { value: 'L4', label: 'L4 Tiềm năng' },
        { value: 'L1', label: 'L1 Mới' },
      ],
    },
    { key: 'name', label: 'Tên', type: 'text', get: (r) => r.name },
  ],
  groupFields: [
    { key: 'stage', label: 'Stage', value: (r) => r.stage },
    { key: 'source', label: 'Source', value: (r) => r.source },
  ],
  dateFields: [],
  views: ['list'],
};

describe('lọc nhanh (R-CRM-07)', () => {
  it('cùng nhóm là HOẶC, khác nhóm là VÀ', () => {
    const s = { ...emptyState(CONFIG), quick: { mine: ['ha', 'long'] } };
    expect(applyFilters(ROWS, s, CONFIG, (r) => r.name).map((r) => r.id)).toEqual([
      '1',
      '2',
      '3',
      '4',
    ]);
    const both = { ...s, quick: { mine: ['ha'], time: ['late'] } };
    expect(applyFilters(ROWS, both, CONFIG, (r) => r.name).map((r) => r.id)).toEqual(['2']);
  });

  it('điều kiện nâng cao nối bằng VÀ; trường nhiều giá trị dùng "là một trong"', () => {
    const s = {
      ...emptyState(CONFIG),
      conditions: [
        { id: 'a', field: 'source', op: 'eq' as const, value: 'Website' },
        { id: 'b', field: 'stage', op: 'in' as const, value: ['L4', 'L1'] },
      ],
    };
    expect(applyFilters(ROWS, s, CONFIG, (r) => r.name).map((r) => r.id)).toEqual(['1', '3']);
  });

  it('điều kiện còn trống thì bỏ qua; tìm theo từ khoá', () => {
    const s = {
      ...emptyState(CONFIG),
      search: 'toán',
      conditions: [{ id: 'a', field: 'name', op: 'contains' as const, value: '  ' }],
    };
    expect(applyFilters(ROWS, s, CONFIG, (r) => r.name).map((r) => r.id)).toEqual(['1', '2', '4']);
  });
});

describe('chip, tóm tắt, xoá', () => {
  const s = {
    ...emptyState(CONFIG),
    search: 'Toán',
    quick: { mine: ['ha', 'long'] },
    group: ['stage', 'source'],
    conditions: [{ id: 'a', field: 'stage', op: 'in' as const, value: ['L4'] }],
  };

  it('chip có nhãn đọc được', () => {
    expect(chipsOf(s, CONFIG).map((c) => c.label)).toEqual([
      'Của tôi: Tôi là Hà hoặc Tôi là Long',
      'Tìm: Toán',
      'Stage là một trong L4 Tiềm năng',
      'Group By: Stage › Source',
    ]);
  });

  it('tóm tắt nối bằng dấu chấm giữa', () => {
    expect(summarize(emptyState(CONFIG), CONFIG)).toBe('Chưa có điều kiện nào.');
    expect(summarize(s, CONFIG)).toContain('Group By: Stage › Source');
  });

  it('bỏ từng chip và xoá tất cả (giữ cột)', () => {
    expect(removeChip(s, 'quick:mine').quick).toEqual({});
    expect(removeChip(s, 'group').group).toEqual([]);
    expect(removeChip(s, 'cond:a').conditions).toEqual([]);
    const cleared = clearFilters({ ...s, columns: ['code', 'name'] });
    expect(chipsOf(cleared, CONFIG)).toEqual([]);
    expect(cleared.columns).toEqual(['code', 'name']);
  });
});

describe('cột hiển thị', () => {
  it('mặc định bỏ cột ẩn; cột khoá luôn hiện và đứng đầu', () => {
    expect(defaultColumnKeys(CONFIG)).toEqual(['code', 'name', 'stage', 'source']);
    const s = { ...emptyState(CONFIG), columns: ['source', 'created'] };
    expect(visibleColumnKeys(CONFIG, s)).toEqual(['code', 'name', 'source', 'created']);
  });
});

describe('Group By', () => {
  it('nhóm hai cấp, giữ thứ tự xuất hiện, có số đếm', () => {
    const tree = buildGroupTree(ROWS, ['stage', 'source'], CONFIG.groupFields);
    expect(tree.map((g) => [g.label, g.count])).toEqual([
      ['L1', 1],
      ['L2', 1],
      ['L4', 2],
    ]);
    expect(tree[2]?.children.map((g) => [g.label, g.count])).toEqual([
      ['Website', 1],
      ['Referral', 1],
    ]);
    expect(tree[2]?.rows).toEqual([]);
  });

  it('nhóm một cấp thì dòng nằm ở nhóm', () => {
    const tree = buildGroupTree(ROWS, ['stage'], CONFIG.groupFields);
    expect(tree[2]?.rows.map((r) => r.id)).toEqual(['3', '4']);
  });
});

describe('khoảng ngày', () => {
  it('tuần bắt đầu từ thứ Hai, tháng trước đúng đầu và cuối', () => {
    const sunday = new Date('2026-10-11T08:00:00Z'); // 15:00 chủ nhật 11/10 giờ Việt Nam
    const week = datePresetRange('week', sunday);
    expect(week?.from.getDate()).toBe(5);
    expect(week?.to.getDate()).toBe(11);
    const last = datePresetRange('last-month', sunday);
    expect([last?.from.getMonth(), last?.from.getDate(), last?.to.getDate()]).toEqual([8, 1, 30]);
    expect(datePresetRange('', sunday)).toBeNull();
  });

  // Lỗi lịch hẹn Q-168: 17:22 UTC chủ nhật 08/11 đã là 00:22 thứ Hai 09/11 giờ Việt Nam. Tuần phải là 09–15/11,
  // không phải 02–08/11 theo ngày UTC, nếu không lịch vừa tạo cho "Hôm nay" biến mất khỏi danh sách.
  it('"Hôm nay" và "Tuần này" theo ngày Việt Nam, không theo múi giờ máy', () => {
    const lateSundayUtc = new Date('2026-11-08T17:22:00Z');
    const week = datePresetRange('week', lateSundayUtc);
    expect([week?.from.getMonth(), week?.from.getDate(), week?.to.getDate()]).toEqual([10, 9, 15]);
    const today = datePresetRange('today', lateSundayUtc);
    expect([today?.from.getMonth(), today?.from.getDate()]).toEqual([10, 9]);
  });
});

describe('Kanban: luật kéo thả', () => {
  const rule = forwardOnlyRule(['L1', 'L2', 'L4', 'L5', 'L6'], ['L6']);
  it('chỉ đi tới, không lùi; cột hệ thống không thả tay vào', () => {
    expect(rule('L1', 'L4')).toEqual({ ok: true });
    expect(rule('L4', 'L2')).toMatchObject({ ok: false });
    expect(rule('L4', 'L4')).toMatchObject({ ok: false });
    expect(rule('L4', 'L6')).toMatchObject({ ok: false });
  });
});

describe('Kanban: "chỉ đi tới" là tuỳ chọn', () => {
  it('luật tự do cho kéo lùi; cột hệ thống vẫn chặn; cùng cột thì không', () => {
    const rule = freeMoveRule(['L6']);
    expect(rule('L4', 'L2')).toEqual({ ok: true });
    expect(rule('L1', 'L5')).toEqual({ ok: true });
    expect(rule('L4', 'L6')).toMatchObject({ ok: false });
    expect(rule('L4', 'L4')).toMatchObject({ ok: false });
  });
});

describe('Calendar', () => {
  it('tuần và lưới tháng bắt đầu từ thứ Hai', () => {
    const days = weekDays(new Date(2026, 9, 14)); // thứ Tư
    expect(days).toHaveLength(7);
    expect(days[0]?.getDay()).toBe(1);
    expect(sameDay(days[0] as Date, new Date(2026, 9, 12))).toBe(true);
    const grid = monthGrid(new Date(2026, 9, 14));
    expect(grid).toHaveLength(42);
    expect(grid[0]?.getDay()).toBe(1);
  });

  it('vị trí sự kiện theo giờ; trùng giờ thì chia cột', () => {
    const day = new Date(2026, 9, 14);
    const at = (h: number, m = 0) => new Date(2026, 9, 14, h, m);
    const events: CalendarEvent[] = [
      { id: 'a', title: 'A', start: at(9), end: at(10), kind: 'x' },
      { id: 'b', title: 'B', start: at(9, 30), end: at(10, 30), kind: 'x' },
      { id: 'c', title: 'C', start: at(13), end: at(14), kind: 'x' },
    ];
    const placed = layoutDay(events, day, 8, 20, 48);
    const a = placed.find((p) => p.id === 'a');
    const b = placed.find((p) => p.id === 'b');
    const c = placed.find((p) => p.id === 'c');
    expect(a?.top).toBe(48);
    expect(a?.height).toBe(48);
    expect([a?.lanes, b?.lanes, a?.lane, b?.lane]).toEqual([2, 2, 0, 1]);
    expect([c?.lanes, c?.lane]).toEqual([1, 0]);
  });
});

describe('Ngày hôm nay theo giờ Việt Nam, không theo múi giờ máy (R-HT-07, Q-172)', () => {
  it('lúc 01:00 sáng 10/11 giờ Việt Nam (18:00 UTC 09/11) "hôm nay" là 10/11', () => {
    const t = vnToday(new Date('2026-11-09T18:00:00Z'));
    expect([t.getFullYear(), t.getMonth(), t.getDate()]).toEqual([2026, 10, 10]);
  });
  it('lúc 23:30 giờ Việt Nam (16:30 UTC) vẫn là ngày đó, chưa sang ngày sau', () => {
    const t = vnToday(new Date('2026-11-10T16:30:00Z'));
    expect([t.getFullYear(), t.getMonth(), t.getDate()]).toEqual([2026, 10, 10]);
  });
});
