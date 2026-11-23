// GD-04 Sổ giờ của ghi danh (danh sách, khuôn K03): mọi dòng cộng, trừ giờ, nguồn (buổi, phiếu thu, điều chỉnh, phiếu chuyển phí); chỉ thêm, không sửa (R-GD-04).
// Mở từ GD-02 (đường dẫn /crm/ghi-danh/:id/so-gio). Nút Điều chỉnh giờ (GD-05) nằm ở bản ghi ghi danh (GD-02).
import { Link, useParams } from 'react-router';
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListState, ViewMode } from '../../list/types';
import { HmtError, errorOf, useIntSetting } from '../../lib/db';
import { StateView } from '../../ui/Feedback';
import { buildLedgerConfig } from './enrollConfig';
import { EMPTY_ENROLL_STATE } from './enrollFilters';
import { useEnrollmentLedger, useEnrollmentRecord } from './useEnrollmentData';

export function EnrollmentLedgerPage() {
  const { id } = useParams();
  const record = useEnrollmentRecord(id);
  const config = useMemo(() => buildLedgerConfig(), []);
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_ENROLL_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [page, setPage] = useState(0);
  const ledger = useEnrollmentLedger(id, page * (pageSize ?? 0), pageSize);
  const rows = ledger.data?.rows ?? [];
  const total = ledger.data?.total ?? 0;

  if (record.isError || ledger.isError) {
    const err = errorOf(record.error ?? ledger.error);
    return (
      <StateView
        kind={
          err instanceof HmtError && err.code === 'HMT_KHONG_CO_QUYEN' ? 'forbidden' : 'not-found'
        }
        title={
          err.code === 'HMT_KHONG_CO_QUYEN'
            ? 'Bạn không có quyền xem dòng sổ giờ'
            : 'Không tìm thấy ghi danh'
        }
      >
        {err.message}
      </StateView>
    );
  }
  return (
    <div className="flex flex-col gap-2">
      <p className="px-4 pt-3 text-body text-fg-muted">
        <Link to="/crm/ghi-danh" className="text-link hover:underline">
          Ghi danh
        </Link>
        {' › '}
        {record.data && (
          <Link to={`/crm/ghi-danh/${id}`} className="text-link hover:underline">
            {record.data.enrollment.code}
          </Link>
        )}
        {' › Sổ giờ'}
      </p>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => `${r.entry_name} ${r.on_date}`}
        loading={ledger.isPending || ledger.isPlaceholderData}
        onRetry={() => void ledger.refetch()}
        pager={{
          from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
          to: page * (pageSize ?? 0) + rows.length,
          total,
          ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
          ...(page * (pageSize ?? 0) + rows.length < total
            ? { onNext: () => setPage(page + 1) }
            : {}),
        }}
        emptyMessage={{
          title: 'Chưa có dòng sổ giờ nào',
          hint: 'Sổ giờ chỉ thêm dòng, không sửa dòng cũ. Dòng đầu tiên sinh khi phiếu thu được duyệt.',
        }}
      />
    </div>
  );
}
