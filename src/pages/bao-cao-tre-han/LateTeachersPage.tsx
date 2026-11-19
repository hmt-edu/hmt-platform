// BC-08 Giáo viên trễ hạn hằng tháng (khuôn báo cáo, canvas 1aab BC08_pc, BC08_khong_xuat_pc, BC08_trong_pc, BC08_tai_pc, BC08_quyen_pc): chọn tháng và cơ sở,
// ba thẻ tổng, bảng mỗi giáo viên hoặc trợ giảng CÓ buổi trễ một dòng. Chỉ ghi số liệu (R-GV-06): không tính vi phạm, không hiện mức xử lý.
// Số liệu một lần gọi app.report_teacher_late. CHƯA có «Xuất CSV» (khung có; làm khi Chat xác nhận).
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Pagination, Table, Tag, type Column } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { Select } from '../../ui/Overlays';
import {
  formatHours,
  mergePerPerson,
  monthOptions,
  type LateReport,
  type LateRow,
} from './lateLogic';

const ALL = '__all__';

function Tile({ label, value, note }: { label: string; value: string; note: string }) {
  return (
    <div className="flex flex-col gap-1 rounded-card border border-border bg-surface p-4">
      <span className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
        {label}
      </span>
      <span className="tabular font-display text-display">{value}</span>
      <span className="text-body text-fg-muted">{note}</span>
    </div>
  );
}

export function LateTeachersPage() {
  const supabase = useDb();
  const access = useAccess();
  const months = useMemo(() => monthOptions(), []);
  const [month, setMonth] = useState(months[0]?.value ?? '');
  const [branch, setBranch] = useState(ALL);
  const [page, setPage] = useState(1);
  const pageSize = useIntSetting('list_page_size_default');

  const query = useQuery({
    queryKey: ['report-teacher-late', month, branch, page, pageSize],
    enabled: month !== '' && pageSize !== null,
    placeholderData: keepPreviousData,
    retry: false,
    queryFn: () =>
      rpc<LateReport>(supabase, 'report_teacher_late', {
        p_month: month,
        p_branch_id: branch === ALL ? null : branch,
        p_limit: pageSize,
        p_offset: (page - 1) * (pageSize ?? 0),
      }),
  });
  const d = query.data;
  const rows = useMemo(() => (d ? mergePerPerson(d.rows) : []), [d]);

  const columns: Column<LateRow>[] = [
    { key: 'code', header: 'Mã', cell: (r) => r.code ?? '—' },
    {
      key: 'name',
      header: 'Giáo viên, trợ giảng',
      primary: true,
      cell: (r) => (
        <span>
          {r.name} {r.role === 'TRO_GIANG' ? <Tag tone="neutral">Trợ giảng</Tag> : null}
        </span>
      ),
    },
    {
      key: 'sessions',
      header: 'Số buổi trễ',
      numeric: true,
      cell: (r) => formatNumber(r.late_sessions),
    },
    {
      key: 'hours',
      header: 'Tổng giờ trễ (giờ)',
      numeric: true,
      cell: (r) => formatHours(r.late_hours),
    },
  ];

  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <h1 className="text-h1">Giáo viên trễ hạn hằng tháng</h1>
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
      </div>
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
              label="Người có buổi trễ"
              value={formatNumber(d.totals.people)}
              note="giáo viên, trợ giảng"
            />
            <Tile
              label="Số buổi trễ hạn"
              value={formatNumber(d.totals.late_sessions)}
              note="tổng các giáo viên"
            />
            <Tile label="Tổng giờ trễ" value={formatHours(d.totals.late_hours)} note="giờ" />
          </section>
          <Table
            caption="Giáo viên và trợ giảng có buổi trễ hạn trong tháng"
            columns={columns}
            rows={rows}
            rowKey={(r) => r.user_id}
            rowLabel={(r) => r.name}
            loading={query.isPlaceholderData}
            empty={
              <StateView kind="empty" title="Tháng này không có buổi trễ hạn">
                Không có giáo viên hay trợ giảng nào có buổi trễ hạn trong tháng. Chọn tháng khác
                bằng bộ lọc.
              </StateView>
            }
          />
          {pageSize !== null && d.total > pageSize && (
            <Pagination page={page} pageSize={pageSize} total={d.total} onPageChange={setPage} />
          )}
          <p className="text-body text-fg-muted">
            Tháng tính theo ngày buổi diễn ra. Chỉ hiện người có buổi trễ. Báo cáo chỉ ghi số liệu.
            Hệ thống không tự tính vi phạm và không hiện mức xử lý; mức xử lý do HMT quyết theo nội
            quy.
          </p>
        </>
      )}
    </div>
  );
}
