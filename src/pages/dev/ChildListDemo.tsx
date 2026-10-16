// Danh sách con mở từ smart button của K3 (trang mẫu, dữ liệu giả): các bản ghi con của cơ hội cha.
// Lịch hẹn có 2 bản ghi; loại chưa có bản ghi nào thì hiện danh sách rỗng "Chưa có …".
import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { Code, Tag } from '../../ui/Data';
import { ListScreen } from '../../list/ListScreen';
import { emptyState } from '../../list/state';
import type { ListConfig, ListState, ViewMode } from '../../list/types';

type Appointment = {
  id: string;
  code: string;
  kind: string;
  at: string;
  status: { label: string; tone: 'warning' | 'danger' | 'success' };
  owner: string;
  note: string;
};

// Dữ liệu giả của cơ hội CO000121 (khớp số "2 Lịch hẹn" trên nút).
const APPOINTMENTS: Appointment[] = [
  {
    id: 'lh1',
    code: 'LH000301',
    kind: 'Gọi điện',
    at: '16/10/2026 16:00',
    status: { label: 'Hôm nay', tone: 'warning' },
    owner: 'Trần Thu Hà',
    note: 'Gọi lại chị Hằng báo lịch test',
  },
  {
    id: 'lh2',
    code: 'LH000288',
    kind: 'Zalo',
    at: '13/10/2026 09:30',
    status: { label: 'Quá hạn', tone: 'danger' },
    owner: 'Trần Thu Hà',
    note: 'Gửi bảng học phí và lịch khai giảng',
  },
];

const CHILD_LABEL: Record<string, string> = {
  'lich-hen': 'Lịch hẹn',
  'bao-gia': 'Báo giá',
  'don-hang': 'Đơn hàng',
  'kiem-tra': 'Kiểm tra đầu vào',
};

const CONFIG: ListConfig<Appointment> = {
  screenCode: 'DEV-02',
  title: 'Lịch hẹn',
  searchPlaceholder: 'Tìm mã, nội dung…',
  columns: [
    { key: 'code', label: 'Mã', locked: true, render: (r) => <Code>{r.code}</Code> },
    {
      key: 'note',
      label: 'Nội dung',
      locked: true,
      primary: true,
      render: (r) => <span className="font-medium text-link">{r.note}</span>,
    },
    { key: 'kind', label: 'Loại', render: (r) => r.kind },
    { key: 'at', label: 'Ngày giờ', render: (r) => r.at },
    {
      key: 'status',
      label: 'Trạng thái',
      render: (r) => (
        <Tag tone={r.status.tone} dot>
          {r.status.label}
        </Tag>
      ),
    },
    { key: 'owner', label: 'Người phụ trách', render: (r) => r.owner },
  ],
  quickGroups: [],
  filterFields: [],
  groupFields: [
    { key: 'kind', label: 'Loại', value: (r) => r.kind },
    { key: 'owner', label: 'Người phụ trách', value: (r) => r.owner },
  ],
  dateFields: [],
  views: ['list'],
};

export function ChildListDemo({ parentCode, childKey }: { parentCode: string; childKey: string }) {
  const navigate = useNavigate();
  const [, setParams] = useSearchParams();
  const [state, setState] = useState<ListState>(() => emptyState(CONFIG));
  const [view, setView] = useState<ViewMode>('list');
  const childLabel = CHILD_LABEL[childKey] ?? 'Bản ghi';
  const rows = childKey === 'lich-hen' ? APPOINTMENTS : [];
  return (
    <div className="flex flex-col gap-3">
      <p className="text-fg-muted">
        Trang mẫu danh sách con mở từ nút liên kết. Dữ liệu giả, không lưu.
      </p>
      <ListScreen
        config={{ ...CONFIG, title: childLabel }}
        parent={{
          entityLabel: 'Cơ hội',
          code: parentCode,
          childLabel,
          onOpenParent: () => void navigate(`/dev/chi-tiet?ma=${parentCode}`),
          onClear: () => setParams({}),
        }}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => r.code}
        pager={{ from: rows.length === 0 ? 0 : 1, to: rows.length, total: rows.length }}
      />
    </div>
  );
}
