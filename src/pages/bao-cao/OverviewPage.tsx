// BC-01 Tổng quan Ban giám đốc (khuôn báo cáo của canvas BaoCao: bộ lọc ngày và cơ sở ở trên, thẻ số, chỉ xem). Số liệu một lần gọi
// app.report_overview (R-BC-02, 04, 05). Tỉ lệ tái tục (R-BC-03) chưa có ở máy chủ nên chưa hiện. Không có khung canvas riêng cho BC-01.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { datePresetRange } from '../../lib/dateRange';
import { formatMoney, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Spinner, StateView } from '../../ui/Feedback';
import { DateRange, type DateRangeValue } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { rangeParams, type Overview } from './overviewLogic';

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

export function OverviewPage() {
  const supabase = useDb();
  const access = useAccess();
  const [range, setRange] = useState<DateRangeValue>(() => {
    const preset = datePresetRange('month', new Date());
    return preset ? { ...preset, preset: 'month' } : null;
  });
  const [branch, setBranch] = useState(ALL);
  const params = rangeParams(range);

  const query = useQuery({
    queryKey: ['report-overview', params, branch],
    enabled: params !== null,
    retry: false,
    queryFn: () =>
      rpc<Overview>(supabase, 'report_overview', {
        ...params,
        p_branch_id: branch === ALL ? null : branch,
      }),
  });
  const d = query.data;

  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <h1 className="text-h1">Tổng quan Ban giám đốc</h1>
      <div className="flex flex-wrap items-end gap-3">
        <DateRange label="Thời gian" value={range} onChange={setRange} />
        {access.allBranches.length > 1 && (
          <Select
            label="Cơ sở"
            value={branch}
            onChange={setBranch}
            options={[
              { value: ALL, label: 'Tất cả cơ sở' },
              ...access.allBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
            ]}
          />
        )}
      </div>
      {params === null ? (
        <p className="text-body text-fg-muted">Chọn khoảng ngày để xem số liệu.</p>
      ) : query.isError ? (
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
          <section
            aria-label="Số liệu tổng quan"
            className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
          >
            <Tile
              label="Học sinh đang học"
              value={formatNumber(d.students_active)}
              note={`Đang bảo lưu: ${formatNumber(d.students_on_hold)} (không cộng vào)`}
            />
            <Tile
              label="Doanh thu ghi nhận"
              value={formatMoney(d.revenue_recognized)}
              note={`${formatNumber(d.revenue_hours)} giờ đã dạy trong khoảng`}
            />
            <Tile
              label="Tiền đã thu"
              value={formatMoney(d.cash_received)}
              note="Đã trừ khoản đảo"
            />
            <Tile
              label="Quỹ giờ còn quy ra tiền"
              value={formatMoney(d.hours_fund_value)}
              note={`${formatNumber(d.hours_fund_hours)} giờ còn lại`}
            />
          </section>
          {d.hours_without_price > 0 && (
            <p className="text-body text-fg-muted">
              Có {formatNumber(d.hours_without_price)} giờ đã dạy thuộc ghi danh nạp từ hệ thống cũ
              chưa có giá, nên chưa tính vào doanh thu.
            </p>
          )}
          <p className="text-caption text-fg-muted">
            Số học sinh đọc theo tình trạng ghi danh tại ngày xem. Tỉ lệ tái tục sẽ hiện khi có số
            liệu phiếu tái tục.
          </p>
        </>
      )}
    </div>
  );
}
