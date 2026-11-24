// D-23-26: bảng «Số tiền dự kiến» trên phiếu Dừng học, Hoàn học phí để Trưởng cơ sở và Kế toán thấy số tiền sẽ hoàn hoặc sẽ đổi thành số dư trước khi duyệt.
// Số do DB tính (app.preview_stop_task_money), giao diện không tính tiền. Tính lại lúc thực hiện nên đây là số tham khảo.
import { formatMoney } from '../../lib/format';
import { DetailSection } from '../../record/Detail';
import { Alert, Spinner } from '../../ui/Feedback';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { useStopMoneyPreview } from './useTaskCreate';

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <tr>
      <td>{label}</td>
      <td className={`text-right ${strong ? 'font-semibold' : ''}`}>{value}</td>
    </tr>
  );
}

export function StopMoneyPreviewSection({
  taskId,
  taskType,
}: {
  taskId: string;
  taskType: 'DUNG_HOC' | 'HOAN_PHI';
}) {
  const q = useStopMoneyPreview(taskId, true);
  if (q.isLoading) return <Spinner />;
  if (q.isError)
    return (
      <QueryErrorView error={q.error} subject="số tiền dự kiến" onRetry={() => void q.refetch()} />
    );
  const d = q.data;
  if (!d) return null;
  const refunding = taskType === 'HOAN_PHI' || d.money_mode === 'HOAN_TIEN';
  return (
    <DetailSection title="Số tiền dự kiến">
      <table className="w-full text-body">
        <tbody>
          {d.paid_amount !== null && <Row label="Đã đóng" value={formatMoney(d.paid_amount)} />}
          {refunding ? (
            d.refund_amount !== null ? (
              <>
                {d.refund_kind === 'MOT_PHAN' ? (
                  <Row
                    label={`Giờ hoàn × giá sau chiết khấu (${d.hours_refund ?? 0} giờ)`}
                    value={formatMoney(d.base_amount ?? 0)}
                  />
                ) : (
                  <>
                    {d.used_amount != null && (
                      <Row label="Giờ đã học trừ" value={`− ${formatMoney(d.used_amount)}`} />
                    )}
                    {(d.prior_refund_amount ?? 0) > 0 && (
                      <Row
                        label="Đã hoàn các lần trước"
                        value={`− ${formatMoney(d.prior_refund_amount ?? 0)}`}
                      />
                    )}
                    {d.base_amount != null && (
                      <Row label="Còn lại trước phí" value={formatMoney(d.base_amount)} />
                    )}
                  </>
                )}
                <Row
                  label={`Phí xử lý (${d.fee_percent ?? 0}%)`}
                  value={formatMoney(d.fee_amount ?? 0)}
                />
                <Row
                  label="Số tiền hoàn cho phụ huynh"
                  value={formatMoney(d.refund_amount)}
                  strong
                />
              </>
            ) : null
          ) : (
            <>
              <Row label="Giờ còn lại" value={`${d.hours_left ?? 0} giờ`} />
              <Row label="Giờ tặng bị huỷ" value={`${d.hours_cancelled ?? 0} giờ`} />
              <Row label="Giá sau chiết khấu" value={formatMoney(d.unit_price_net ?? 0)} />
              <Row
                label="Số dư giữ lại cho phụ huynh"
                value={formatMoney(d.balance_amount ?? 0)}
                strong
              />
            </>
          )}
        </tbody>
      </table>
      {refunding && d.refund_amount === null && (
        <Alert tone="warning">
          Chưa tính được số hoàn: {d.refund_error}. Kiểm tra lại ghi danh trước khi duyệt.
        </Alert>
      )}
      {taskType === 'DUNG_HOC' && !refunding && d.refund_amount !== null && (
        <p className="text-caption text-fg-muted">
          Nếu chuyển sang Hoàn tiền: hoàn {formatMoney(d.refund_amount)} sau phí xử lý.
        </p>
      )}
      <p className="text-caption text-fg-muted">
        Số tính theo dữ liệu hôm nay; khi thực hiện hệ thống tính lại và dùng số lúc đó.
      </p>
    </DetailSection>
  );
}
