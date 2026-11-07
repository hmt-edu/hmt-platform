// Khối "Gói học" đang sửa của BH-02 (khuôn K06c): băng lỗi lưu, lưới dòng, băng lỗi mạng khi xem thử giá, Tổng cộng báo giá. Dùng chung cho
// sửa Nháp (bản ghi báo giá) và Tạo báo giá từ cơ hội. Giao diện không tính gì: mọi số do máy chủ trả (xem thử giá, lưu).
import { errorOf, useIntSetting } from '../../lib/db';
import { formatMoney } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Alert } from '../../ui/Feedback';
import { pruneIssues, type EditRow, type RowIssue } from './quoteEdit';
import { QuoteLineGrid } from './QuoteLineGrid';
import { useDiscountPolicies, useGiftPolicies, useOpportunityStudents } from './useQuoteData';
import { useQuotePreview } from './useQuotePreview';

export function QuoteLineEditor({
  opportunityId,
  rows,
  onRowsChange,
  issues,
  onIssuesChange,
  saveError,
  saving,
  layout,
}: {
  opportunityId: string;
  rows: EditRow[];
  onRowsChange: (rows: EditRow[]) => void;
  issues: RowIssue[];
  onIssuesChange: (issues: RowIssue[]) => void;
  saveError: string | null;
  saving: boolean;
  /** Q-74: 'tao' = Tạo báo giá (11 cột), 'sua' = Sửa báo giá (13 cột). */
  layout: 'tao' | 'sua';
}) {
  const capPercent = useIntSetting('discount_total_cap_percent');
  const students = useOpportunityStudents(opportunityId, true);
  const policies = useDiscountPolicies(opportunityId, true);
  const giftPolicies = useGiftPolicies(opportunityId, true);
  const preview = useQuotePreview(opportunityId, rows, true);
  return (
    <div className="flex flex-col gap-2">
      {(issues.length > 0 || saveError !== null) && (
        <Alert tone="danger" title="Chưa lưu được.">
          {saveError ?? (
            <ul>
              {issues.map((i) => (
                <li key={i.rowKey}>{i.summary}</li>
              ))}
            </ul>
          )}
        </Alert>
      )}
      {policies.isError && <Alert tone="danger">{errorOf(policies.error).message}</Alert>}
      {students.isError && <Alert tone="danger">{errorOf(students.error).message}</Alert>}
      <QuoteLineGrid
        rows={rows}
        onChange={(next) => {
          onRowsChange(next);
          onIssuesChange(pruneIssues(issues, next));
        }}
        students={students.data ?? []}
        opportunityId={opportunityId}
        opportunityHref={`/crm/co-hoi/${opportunityId}`}
        issues={issues}
        disabled={saving || students.isPending}
        policies={policies.data ?? []}
        giftPolicies={giftPolicies.data ?? []}
        calcs={preview.calcs}
        cap={capPercent}
        layout={layout}
      />
      {preview.networkError !== null && (
        <Alert tone="danger" title="Không tính được giá.">
          <span className="flex flex-wrap items-center gap-2">
            {preview.networkError}
            <Button size="sm" onClick={preview.retry}>
              Thử lại
            </Button>
          </span>
        </Alert>
      )}
      <p className="flex flex-wrap items-baseline justify-end gap-2 text-body">
        <span>Tổng cộng báo giá</span>
        <span className="text-caption text-fg-muted">(hệ thống tính)</span>
        <b className="tabular" aria-busy={preview.computing ? true : undefined}>
          {preview.computing || preview.total === null ? '—' : formatMoney(preview.total)}
        </b>
      </p>
    </div>
  );
}
