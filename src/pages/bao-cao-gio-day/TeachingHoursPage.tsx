// BC-09 Giờ dạy giáo viên (khuôn báo cáo, canvas 1aab BC09_pc, BC09_trong_pc, BC09_tai_pc, BC09_quyen_pc, BC09_bm_pc): chọn tháng và cơ sở, thẻ tổng,
// bảng mỗi giáo viên hoặc trợ giảng một dòng, tách Học chính, Củng cố, Học bù, Học bổ trợ. Số liệu một lần gọi app.report_teaching_hours (R-GV-14).
// «Chốt tháng» (migration 619): cả hệ thống một lần, khoá, không Mở lại; tháng đã chốt đọc số từ ảnh chụp lúc chốt (app.teaching_hours_view). Trưởng cơ sở
// (một cơ sở) không có nút Chốt. CHƯA CÓ «Xuất CSV» (khung có; thẻ riêng).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { formatDateTime, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Pagination, Table, Tag, type Column } from '../../ui/Data';
import { ConfirmDialog } from '../../ui/Dialogs';
import { useToast } from '../../ui/toastContext';
import { Spinner, StateView } from '../../ui/Feedback';
import { Select } from '../../ui/Overlays';
import {
  TYPE_COLUMNS,
  formatHours,
  mergePerPerson,
  monthOptions,
  type HoursReport,
  monthEnded,
  type HoursRow,
} from './teachingHoursLogic';

const ALL = '__all__';

function Tile({ label, value, note }: { label: string; value: string; note?: string | undefined }) {
  return (
    <div className="flex flex-col gap-1 rounded-card border border-border bg-surface p-4">
      <span className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
        {label}
      </span>
      <span className="tabular font-display text-display">{value}</span>
      {note && <span className="text-body text-fg-muted">{note}</span>}
    </div>
  );
}

export function TeachingHoursPage() {
  const supabase = useDb();
  const access = useAccess();
  const months = useMemo(() => monthOptions(), []);
  const [month, setMonth] = useState(months[0]?.value ?? '');
  const [branch, setBranch] = useState(ALL);
  const [page, setPage] = useState(1);
  const pageSize = useIntSetting('list_page_size_default');

  const query = useQuery({
    queryKey: ['report-teaching-hours', month, branch, page, pageSize],
    enabled: month !== '' && pageSize !== null,
    placeholderData: keepPreviousData,
    retry: false,
    queryFn: () =>
      rpc<HoursReport>(supabase, 'teaching_hours_view', {
        p_month: month,
        p_branch_id: branch === ALL ? null : branch,
        p_limit: pageSize,
        p_offset: (page - 1) * (pageSize ?? 0),
      }),
  });
  const d = query.data;
  const toast = useToast();
  const client = useQueryClient();
  const [confirming, setConfirming] = useState(false);
  const [closing, setClosing] = useState(false);
  const [closeError, setCloseError] = useState<string | null>(null);
  // Nút Chốt chỉ cho người xem được nhiều cơ sở và có quyền Xuất báo cáo (Kế toán, Admin); DB kiểm lại. Tháng đã chốt hoặc chưa kết thúc thì không có nút.
  const canClose =
    access.can('REPORT', 'XUAT') &&
    access.allBranches.length > 1 &&
    d !== undefined &&
    d.closed === null &&
    monthEnded(month);
  const monthLabel = months.find((m) => m.value === month)?.label.replace('Tháng ', '') ?? '';

  async function closeMonth() {
    setClosing(true);
    setCloseError(null);
    try {
      await rpc(supabase, 'close_teaching_hours_month', { p_month: month });
      setConfirming(false);
      await client.invalidateQueries({ queryKey: ['report-teaching-hours'] });
      toast({ title: `Đã chốt giờ dạy tháng ${monthLabel}.` });
    } catch (e) {
      setCloseError(errorOf(e).message);
    } finally {
      setClosing(false);
    }
  }
  // Xem «Tất cả cơ sở»: người dạy nhiều cơ sở gộp một dòng (trong phạm vi trang đang xem).
  const rows = useMemo(() => (d ? mergePerPerson(d.rows) : []), [d]);

  const columns: Column<HoursRow>[] = [
    { key: 'code', header: 'Mã', cell: (r) => r.code ?? '—' },
    {
      key: 'name',
      header: 'Họ tên',
      primary: true,
      cell: (r) => (
        <span>
          {r.name} {r.role === 'TRO_GIANG' ? <Tag tone="neutral">Trợ giảng</Tag> : null}
        </span>
      ),
    },
    ...TYPE_COLUMNS.map((t) => ({
      key: t.key,
      header: t.label,
      numeric: true,
      cell: (r: HoursRow) => formatHours(r.by_type[t.key]),
    })),
    {
      key: 'hours',
      header: 'Tổng giờ',
      numeric: true,
      cell: (r) => <strong>{formatHours(r.hours)}</strong>,
    },
  ];

  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-h1">Giờ dạy giáo viên</h1>
        {canClose && (
          <Button
            variant="primary"
            onClick={() => {
              setCloseError(null);
              setConfirming(true);
            }}
          >
            Chốt tháng
          </Button>
        )}
      </div>
      <div className="flex flex-wrap items-end gap-3">
        <Select
          label="Tháng"
          value={month}
          onChange={(v) => {
            setMonth(v);
            setPage(1);
          }}
          options={months}
        />
        {access.allBranches.length > 1 && (
          <Select
            label="Cơ sở"
            value={branch}
            onChange={(v) => {
              setBranch(v);
              setPage(1);
            }}
            options={[
              { value: ALL, label: 'Tất cả cơ sở' },
              ...access.allBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
            ]}
          />
        )}
        {d && (
          <Tag tone={d.closed ? 'success' : 'neutral'}>{d.closed ? 'Đã chốt' : 'Chưa chốt'}</Tag>
        )}
      </div>
      {d?.closed && (
        <p className="text-body text-fg-muted">
          Đã chốt bởi {d.closed.closed_by_name} lúc {formatDateTime(d.closed.closed_at)}
        </p>
      )}
      {query.isError ? (
        <StateView
          kind="error"
          title="Không tải được báo cáo"
          actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
        >
          {errorOf(query.error).message}
        </StateView>
      ) : !d ? (
        <Spinner label="Đang tải báo cáo…" />
      ) : (
        <>
          <section aria-label="Số liệu tổng" className="grid gap-3 sm:grid-cols-3">
            <Tile
              label="Tổng giờ dạy"
              value={formatHours(d.totals.hours)}
              note="giờ, mọi loại buổi"
            />
            <Tile label="Giáo viên" value={formatNumber(d.totals.teachers)} note="có giờ dạy" />
            <Tile label="Trợ giảng" value={formatNumber(d.totals.assistants)} note="có giờ dạy" />
          </section>
          <Table
            caption="Giờ dạy theo giáo viên và loại buổi"
            columns={columns}
            rows={rows}
            rowKey={(r) => r.user_id}
            rowLabel={(r) => r.name}
            loading={query.isPlaceholderData}
            empty={
              <StateView kind="empty" title="Tháng này chưa có buổi dạy">
                Tháng không có buổi nào đã hoàn tất thì không có giờ để tính. Chọn tháng khác bằng
                bộ lọc Tháng.
              </StateView>
            }
          />
          {pageSize !== null && d.total > pageSize && (
            <Pagination page={page} pageSize={pageSize} total={d.total} onPageChange={setPage} />
          )}
          <p className="text-body text-fg-muted">
            Tổng theo loại buổi:{' '}
            {TYPE_COLUMNS.map((t) => `${t.label} ${formatHours(d.totals.by_type[t.key])}`).join(
              ' · ',
            )}
            . Giờ dạy tính cho người dạy thật, chỉ buổi đã Hoàn thành, mọi loại buổi thực dạy (gồm
            học bổ trợ), theo thời lượng buổi. Buổi huỷ, kể cả huỷ có tính phí, không tính. Tháng
            tính theo ngày buổi diễn ra.{' '}
            {d.closed
              ? 'Tháng đã chốt: số liệu giữ nguyên như lúc chốt.'
              : 'Tháng chưa chốt: số liệu còn đổi nếu buổi được sửa.'}
          </p>
        </>
      )}
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={`Chốt giờ dạy tháng ${monthLabel}?`}
        summary={[
          { label: 'Tháng', value: monthLabel },
          { label: 'Phạm vi', value: 'Tất cả cơ sở' },
          {
            label: 'Người có giờ dạy',
            value: d ? formatNumber(d.totals.teachers + d.totals.assistants) : '',
          },
          { label: 'Tổng giờ dạy', value: d ? `${formatHours(d.totals.hours)} giờ` : '' },
        ]}
        note="Chốt xong, tháng giữ nguyên và không sửa được. Sửa buổi sau đó thì chênh lệch đưa vào tháng sau."
        confirmLabel="Chốt tháng"
        busy={closing}
        error={closeError}
        onConfirm={() => void closeMonth()}
      />
    </div>
  );
}
