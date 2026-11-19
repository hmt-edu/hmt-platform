// CH-08 Chiến dịch marketing (bản đồ màn hình: Danh sách · K10, máy tính). Chiến dịch gắn nguồn lead, thời gian chạy; MỌI vai trò vào được cổng CRM đều xem và Tạo (anh Trường chốt 19/11,
// R-CRM-11); Ngừng và Dùng lại: Admin hoặc người tạo (nút chỉ hiện khi được; DB kiểm lại). Không có khung canvas riêng: dựng từ khuôn K10 như QT-14, chữ theo bản đồ màn hình.
import { useMemo, useState } from 'react';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate, formatNumber } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { Button } from '../../ui/Button';
import { Pagination, Tag } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { TextField } from '../../ui/Field';
import { Spinner, StateView } from '../../ui/Feedback';
import { DateInput } from '../../ui/Inputs';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import {
  STATUS_OPTIONS,
  campaignFilters,
  periodText,
  toIsoDate,
  type CampaignRow,
} from './campaignLogic';
import {
  createCampaign,
  setCampaignActive,
  useCampaigns,
  useRefreshCampaigns,
} from './useCampaignData';

export function CampaignPage() {
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshCampaigns();
  const pageSize = useIntSetting('list_page_size_default');
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [creating, setCreating] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const debounced = useDebounced(q);
  const filters = useMemo(() => campaignFilters(debounced, status), [debounced, status]);
  const list = useCampaigns(filters, (page - 1) * (pageSize ?? 0), pageSize);

  const toggle = async (c: CampaignRow) => {
    setBusyId(c.id);
    try {
      await setCampaignActive(supabase, c.id, !c.is_active);
      await refresh();
      toast({ title: c.is_active ? 'Đã ngừng chiến dịch.' : 'Đã dùng lại chiến dịch.' });
    } catch (e) {
      toast({ title: errorOf(e).message, tone: 'danger' });
    } finally {
      setBusyId(null);
    }
  };

  const columns: LineColumn<CampaignRow>[] = [
    { key: 'name', header: 'Chiến dịch', cell: (c) => <b>{c.name}</b> },
    {
      key: 'period',
      header: 'Thời gian chạy',
      width: 'w-64',
      cell: (c) => periodText(c.starts_on, c.ends_on, formatDate),
    },
    {
      key: 'leads',
      header: 'Lead gắn',
      width: 'w-28',
      cell: (c) => formatNumber(c.lead_count),
    },
    { key: 'creator', header: 'Người tạo', width: 'w-44', cell: (c) => c.created_by_name ?? '—' },
    {
      key: 'status',
      header: 'Tình trạng',
      width: 'w-32',
      cell: (c) => (
        <Tag tone={c.is_active ? 'success' : 'neutral'}>{c.is_active ? 'Đang dùng' : 'Ngừng'}</Tag>
      ),
    },
    {
      key: 'actions',
      header: 'Thao tác',
      headerSrOnly: 'Thao tác',
      width: 'w-32',
      cell: (c) =>
        c.can_toggle ? (
          <Button variant="text" loading={busyId === c.id} onClick={() => void toggle(c)}>
            {c.is_active ? 'Ngừng' : 'Dùng lại'}
          </Button>
        ) : null,
    },
  ];

  const total = list.data?.total ?? 0;
  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-h1">Chiến dịch marketing</h1>
        <Button variant="primary" icon="plus" onClick={() => setCreating(true)}>
          Tạo chiến dịch
        </Button>
      </div>
      <p className="text-body text-fg-muted">
        Chiến dịch gắn vào lead để biết lead đến từ đợt quảng bá nào. Ai vào được cổng CRM cũng tạo
        được. Chiến dịch ngừng không còn chọn được cho lead mới; lead cũ giữ nguyên.
      </p>
      <div className="flex flex-wrap items-end gap-3">
        <TextField
          label="Tìm chiến dịch"
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setPage(1);
          }}
        />
        <Select
          label="Tình trạng"
          value={status}
          onChange={(v) => {
            setStatus(v);
            setPage(1);
          }}
          options={STATUS_OPTIONS}
        />
      </div>
      <section
        aria-label="Danh sách chiến dịch"
        className="min-w-0 rounded-box border border-border bg-surface"
      >
        {list.isError ? (
          <div className="p-4">
            <StateView
              kind="error"
              title="Không tải được chiến dịch"
              actions={<Button onClick={() => void list.refetch()}>Thử lại</Button>}
            >
              {errorOf(list.error).message}
            </StateView>
          </div>
        ) : list.data ? (
          <LineTable
            caption="Chiến dịch marketing"
            columns={columns}
            rows={list.data.rows}
            rowKey={(c) => c.id}
            rowLabel={(c) => c.name}
            empty={
              <p className="p-4 text-body text-fg-muted">
                {Object.keys(filters).length > 0
                  ? 'Không có chiến dịch nào khớp bộ lọc.'
                  : 'Chưa có chiến dịch nào. Bấm «Tạo chiến dịch» để thêm.'}
              </p>
            }
          />
        ) : (
          <div className="p-4">
            <Spinner label="Đang tải chiến dịch…" />
          </div>
        )}
      </section>
      {pageSize !== null && total > pageSize && (
        <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
      )}
      {creating && (
        <CreateForm
          onClose={() => setCreating(false)}
          onCreated={async () => {
            setCreating(false);
            setPage(1);
            await refresh();
            toast({ title: 'Đã tạo chiến dịch.' });
          }}
        />
      )}
    </div>
  );
}

function CreateForm({
  onClose,
  onCreated,
}: {
  onClose: () => void;
  onCreated: () => Promise<void>;
}) {
  const supabase = useDb();
  const [name, setName] = useState('');
  const [from, setFrom] = useState<Date | null>(null);
  const [to, setTo] = useState<Date | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title="Tạo chiến dịch"
      confirmLabel="Tạo"
      canSubmit={name.trim() !== ''}
      busy={busy}
      error={error}
      onSubmit={() => {
        setBusy(true);
        setError(null);
        void createCampaign(supabase, {
          name,
          startsOn: from ? toIsoDate(from) : null,
          endsOn: to ? toIsoDate(to) : null,
        })
          .then(() => onCreated())
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <TextField
          label="Tên chiến dịch"
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <DateInput label="Ngày bắt đầu" value={from} onChange={setFrom} />
        <DateInput label="Ngày kết thúc" value={to} onChange={setTo} />
      </div>
    </FormDialog>
  );
}
