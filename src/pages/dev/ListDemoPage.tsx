// Trang mẫu của khuôn danh sách, Kanban, Calendar (PR 3). Cấu hình "Cơ hội" dưới đây chỉ là dữ liệu giả để thử
// khuôn; bộ lọc thật của từng màn sẽ có ở đặc tả từng phân hệ. Chỉ có ở bản không phải chạy thật.
import { useMemo, useState } from 'react';
import { Button } from '../../ui/Button';
import { Code, Tag } from '../../ui/Data';
import { useToast } from '../../ui/toastContext';
import { CalendarView, type CalendarMode } from '../../list/Calendar';
import { addDays, startOfDay, type CalendarEvent } from '../../list/calendarLogic';
import { forwardOnlyRule } from '../../list/kanbanLogic';
import { KanbanBoard } from '../../list/Kanban';
import { ListScreen } from '../../list/ListScreen';
import { applyFilters, emptyState } from '../../list/state';
import type { ListConfig, ListState, ViewMode } from '../../list/types';

type Opp = {
  id: string;
  code: string;
  name: string;
  parent: string;
  stage: string;
  source: string;
  owner: string;
  branch: string;
  created: Date;
  due: { label: string; tone: 'warning' | 'danger' | 'success'; at: Date } | null;
};

const STAGES = [
  { code: 'L1', label: 'L1 Khách hàng mới' },
  { code: 'L2', label: 'L2 Chưa liên hệ được' },
  { code: 'L4', label: 'L4 Khách hàng tiềm năng' },
  { code: 'L5', label: 'L5 Đồng ý tham gia test' },
  { code: 'L6', label: 'L6 Đã tham gia test' },
  { code: 'L7', label: 'L7 Tư vấn' },
  { code: 'L8', label: 'L8 Đăng ký học' },
];

const TODAY = new Date();
const HALF_HOUR_MS = 30 * 60_000; // allow-number: sự kiện mẫu dài 30 phút
const at = (days: number, hour: number) => {
  const d = addDays(startOfDay(TODAY), days);
  d.setHours(hour, 0, 0, 0);
  return d;
};
const dueOf = (days: number, hour: number): Opp['due'] => {
  const date = at(days, hour);
  const hh = `${String(hour).padStart(2, '0')}:00`;
  if (days < 0)
    return { label: `Quá hạn ${date.getDate()}/${date.getMonth() + 1}`, tone: 'danger', at: date };
  if (days === 0) return { label: `Hôm nay ${hh}`, tone: 'warning', at: date };
  return { label: `${date.getDate()}/${date.getMonth() + 1} ${hh}`, tone: 'success', at: date };
};

const DATA: Opp[] = [
  {
    id: '1',
    code: 'CO000133',
    name: 'Toán lớp 8 · Đặng Minh Châu',
    parent: 'Chị Đặng Thu Phương',
    stage: 'L1',
    source: 'Website',
    owner: 'Trần Thu Hà',
    branch: 'CS1',
    created: at(-1, 9),
    due: dueOf(0, 16),
  },
  {
    id: '2',
    code: 'CO000130',
    name: 'Toán lớp 7 · Vũ Gia Bảo',
    parent: 'Anh Vũ Đức Long',
    stage: 'L2',
    source: 'Hotline',
    owner: 'Trần Thu Hà',
    branch: 'CS1',
    created: at(-3, 10),
    due: dueOf(-3, 10),
  },
  {
    id: '3',
    code: 'CO000121',
    name: 'Toán lớp 9 · Lê Gia Huy',
    parent: 'Chị Lê Thu Hằng',
    stage: 'L4',
    source: 'Facebook Ads',
    owner: 'Trần Thu Hà',
    branch: 'CS1',
    created: at(-6, 14),
    due: dueOf(0, 14),
  },
  {
    id: '4',
    code: 'CO000127',
    name: 'Toán lớp 9 · Trần Bảo Long',
    parent: 'Chị Trần Thị Mai',
    stage: 'L4',
    source: 'Referral',
    owner: 'Trần Thu Hà',
    branch: 'CS1',
    created: at(-5, 8),
    due: dueOf(2, 9),
  },
  {
    id: '5',
    code: 'CO000124',
    name: 'Toán lớp 6 · Phạm Minh Khôi',
    parent: 'Anh Phạm Văn Tú',
    stage: 'L5',
    source: 'Website',
    owner: 'Nguyễn Hoàng Long',
    branch: 'CS5',
    created: at(-7, 15),
    due: dueOf(-1, 11),
  },
  {
    id: '6',
    code: 'CO000105',
    name: 'Toán lớp 9 · Đinh Quốc Bảo',
    parent: 'Anh Đinh Văn Sơn',
    stage: 'L6',
    source: 'Facebook Ads',
    owner: 'Nguyễn Hoàng Long',
    branch: 'CS5',
    created: at(-12, 9),
    due: dueOf(1, 17),
  },
  {
    id: '7',
    code: 'CO000109',
    name: 'Toán lớp 11 · Bùi Khánh Linh',
    parent: 'Anh Bùi Quang Vinh',
    stage: 'L7',
    source: 'Event',
    owner: 'Trần Thu Hà',
    branch: 'CS1',
    created: at(-10, 11),
    due: dueOf(0, 17),
  },
  {
    id: '8',
    code: 'CO000112',
    name: 'Toán lớp 10 · Lý Thanh Hương',
    parent: 'Chị Lý Ngọc Anh',
    stage: 'L7',
    source: 'Cold Call',
    owner: 'Trần Thu Hà',
    branch: 'CS1',
    created: at(-9, 16),
    due: null,
  },
];

const CONFIG: ListConfig<Opp> = {
  screenCode: 'DEV-01',
  title: 'Cơ hội',
  searchPlaceholder: 'Tìm tên, SĐT, mã (cả mã cũ)…',
  columns: [
    { key: 'code', label: 'Mã', locked: true, render: (r) => <Code>{r.code}</Code> },
    {
      key: 'name',
      label: 'Cơ hội',
      locked: true,
      primary: true,
      render: (r) => <span className="font-medium text-link">{r.name}</span>,
    },
    { key: 'parent', label: 'Phụ huynh · SĐT', render: (r) => r.parent },
    {
      key: 'stage',
      label: 'Stage · Sub-stage',
      render: (r) => <Tag>{STAGES.find((s) => s.code === r.stage)?.label ?? r.stage}</Tag>,
    },
    { key: 'source', label: 'Source · Sub-source', render: (r) => r.source },
    { key: 'owner', label: 'Sale phụ trách', render: (r) => r.owner },
    { key: 'branch', label: 'Cơ sở', render: (r) => r.branch },
    {
      key: 'due',
      label: 'Lịch hẹn kế tiếp',
      render: (r) =>
        r.due ? (
          <Tag tone={r.due.tone} dot>
            {r.due.label}
          </Tag>
        ) : (
          <Tag>Chưa có lịch</Tag>
        ),
    },
    {
      key: 'created',
      label: 'Ngày tạo',
      defaultVisible: false,
      numeric: true,
      render: (r) => r.created.toLocaleDateString('vi-VN'),
    },
  ],
  quickGroups: [
    {
      key: 'mine',
      label: 'Của tôi',
      options: [
        { value: 'sale', label: 'Tôi là sale', test: (r) => r.owner === 'Trần Thu Hà' },
        { value: 'support', label: 'Tôi hỗ trợ', test: () => false },
      ],
    },
    {
      key: 'appt',
      label: 'Lịch hẹn',
      options: [
        { value: 'today', label: 'Hôm nay', test: (r) => r.due?.tone === 'warning' },
        {
          value: 'late',
          label: 'Quá hạn chăm',
          hint: 'lịch hẹn kế tiếp đã quá hạn, chưa xong',
          test: (r) => r.due?.tone === 'danger',
        },
        { value: 'none', label: 'Chưa có lịch hẹn', test: (r) => r.due === null },
      ],
    },
  ],
  filterFields: [
    {
      key: 'source',
      label: 'Source',
      type: 'select',
      get: (r) => r.source,
      options: ['Website', 'Hotline', 'Facebook Ads', 'Referral', 'Event', 'Cold Call'].map(
        (v) => ({ value: v, label: v }),
      ),
    },
    {
      key: 'stage',
      label: 'Stage',
      type: 'multi',
      get: (r) => r.stage,
      options: STAGES.map((s) => ({ value: s.code, label: s.label })),
    },
    { key: 'name', label: 'Tên', type: 'text', get: (r) => r.name },
    {
      key: 'created',
      label: 'Ngày tạo',
      type: 'date',
      get: (r) => r.created.toISOString().slice(0, 10),
    },
  ],
  groupFields: [
    {
      key: 'stage',
      label: 'Stage',
      value: (r) => r.stage,
      valueLabel: (v) => STAGES.find((s) => s.code === v)?.label ?? v,
    },
    { key: 'source', label: 'Source', value: (r) => r.source },
    { key: 'owner', label: 'Sale phụ trách', value: (r) => r.owner },
    { key: 'branch', label: 'Cơ sở', value: (r) => r.branch },
  ],
  dateFields: [{ key: 'created', label: 'Ngày tạo', get: (r) => r.created }],
  views: ['list', 'kanban', 'calendar'],
};

const KINDS = [
  { key: 'call', label: 'Gọi điện', icon: 'phone2', tone: 'info' },
  { key: 'zalo', label: 'Zalo', icon: 'chat', tone: 'brand' },
  { key: 'meet', label: 'Gặp trực tiếp', icon: 'meet', tone: 'success' },
  { key: 'pay', label: 'Thu tiền', icon: 'payment', tone: 'warning' },
] as const;

export function ListDemoPage() {
  const toast = useToast();
  const [state, setState] = useState<ListState>(() => emptyState(CONFIG));
  const [view, setView] = useState<ViewMode>('list');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [mode, setMode] = useState<CalendarMode>('week');
  const [anchor, setAnchor] = useState(startOfDay(TODAY));
  const [resourceMode, setResourceMode] = useState<'all' | 'people' | 'rooms'>('all');
  const [stages, setStages] = useState<Record<string, string>>({});

  const rows = useMemo(
    () =>
      applyFilters(
        DATA.map((r) => ({ ...r, stage: stages[r.id] ?? r.stage })),
        state,
        CONFIG,
        (r) => `${r.code} ${r.name} ${r.parent} ${r.owner}`,
        TODAY,
      ),
    [state, stages],
  );

  const events: CalendarEvent[] = DATA.flatMap((r, i) =>
    r.due
      ? [
          {
            id: r.id,
            title: r.name.split(' · ')[1] ?? r.name,
            start: r.due.at,
            end: new Date(r.due.at.getTime() + HALF_HOUR_MS),
            kind: KINDS[i % KINDS.length]?.key ?? 'call',
            status: r.due.tone === 'danger' && i % 2 === 0 ? ('done' as const) : ('open' as const),
            resource: r.owner,
            subtitle: `${r.code} · ${r.branch}`,
          },
        ]
      : [],
  );

  return (
    <div className="flex flex-col gap-3">
      <p className="text-fg-muted">
        Trang mẫu khuôn danh sách, Kanban, Calendar. Dữ liệu giả, không lưu. Bộ lọc nhanh, trường
        lọc nâng cao, trường nhóm là cấu hình của màn “Cơ hội” giả này.
      </p>
      <ListScreen
        config={CONFIG}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => r.name}
        actions={[
          {
            label: 'Tạo',
            icon: 'plus',
            primary: true,
            onClick: () => toast({ title: 'Mở ngăn kéo tạo nhanh (PR 4)' }),
          },
          { label: 'Nhập', icon: 'upload', onClick: () => undefined },
          { label: 'Xuất', icon: 'download', onClick: () => undefined },
        ]}
        onRefresh={() => toast({ title: 'Đã làm mới' })}
        pager={{ from: rows.length === 0 ? 0 : 1, to: rows.length, total: rows.length }}
        selected={selected}
        onSelectedChange={setSelected}
        kanban={
          <KanbanBoard
            columns={STAGES.map((s) => ({
              code: s.code,
              label: s.label,
              cards: rows.filter((r) => r.stage === s.code),
            }))}
            cardKey={(c) => c.id}
            cardLabel={(c) => c.name}
            rule={forwardOnlyRule(
              STAGES.map((s) => s.code),
              ['L6', 'L8'],
            )}
            onMove={(card, _from, to) => {
              setStages((m) => ({ ...m, [card.id]: to }));
              toast({ title: `Đã chuyển ${card.code} sang ${to}` });
            }}
            onBlocked={(reason) => toast({ tone: 'warning', title: reason })}
            onAdd={() => toast({ title: 'Mở ngăn kéo tạo nhanh (PR 4)' })}
            note="Kéo thẻ chỉ thả được vào giai đoạn phía trước; L6, L8 do hệ thống tự chuyển."
            renderCard={(c) => (
              <div className="flex flex-col gap-1.5">
                <Code>{c.code}</Code>
                <p className="font-semibold">{c.name}</p>
                <p className="text-caption text-fg-muted">
                  {c.parent} · {c.branch}
                </p>
                <p className="text-caption text-fg-muted">{c.source}</p>
                {c.due && (
                  <span>
                    <Tag tone={c.due.tone} dot>
                      {c.due.label}
                    </Tag>
                  </span>
                )}
              </div>
            )}
          />
        }
        calendar={
          <CalendarView
            events={events}
            kinds={KINDS.map((k) => ({ ...k }))}
            mode={mode}
            onModeChange={setMode}
            anchor={anchor}
            onAnchorChange={setAnchor}
            today={TODAY}
            now={TODAY}
            startHour={8}
            endHour={20}
            resources={{
              people: ['Trần Thu Hà', 'Nguyễn Hoàng Long'],
              rooms: ['P101', 'P102'],
            }}
            resourceMode={resourceMode}
            onResourceModeChange={setResourceMode}
            renderDetail={(e, close) => (
              <div className="flex flex-col gap-2">
                <p className="font-semibold">{e.title}</p>
                <p className="text-fg-muted">{e.subtitle}</p>
                <div className="flex gap-2">
                  <Button
                    icon="checkMark"
                    onClick={() => {
                      toast({ title: 'Đã hoàn thành' });
                      close();
                    }}
                  >
                    Hoàn thành
                  </Button>
                  <Button icon="calendar" onClick={close}>
                    Dời
                  </Button>
                  <Button variant="danger" icon="close" onClick={close}>
                    Huỷ
                  </Button>
                </div>
              </div>
            )}
          />
        }
      />
    </div>
  );
}
