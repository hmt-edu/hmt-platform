// PH-03 chi tiết đơn (cổng Phụ huynh): trạng thái, số giờ, thành tiền, đã thu, còn lại, phiếu thu. Chỉ xem.
import { useQuery } from '@tanstack/react-query';
import { useParams } from 'react-router';
import { rpc, useDb } from '../../lib/db';
import { formatMoney } from '../../lib/format';
import { ButtonLink } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { orderSubtitle, receiptTitle, type OrderDetail } from './feesLogic';

export function ParentOrderPage() {
  const { orderId } = useParams();
  const supabase = useDb();
  const query = useQuery({
    queryKey: ['ph-order', orderId],
    enabled: orderId !== undefined,
    queryFn: () => rpc<OrderDetail>(supabase, 'ph_order', { p_order_id: orderId }),
  });
  if (query.isPending) return <Spinner label="Đang tải đơn…" />;
  if (query.isError)
    return (
      <QueryErrorView error={query.error} subject="đơn hàng" onRetry={() => void query.refetch()} />
    );
  const o = query.data;
  const rows: [string, string][] = [
    ['Số giờ', o.hours === null ? '' : `${o.hours} giờ`],
    ['Thành tiền', formatMoney(o.total)],
    ['Đã thu', formatMoney(o.paid)],
    ['Còn lại', formatMoney(o.remaining)],
  ];
  return (
    <div className="flex flex-col gap-4">
      <div>
        <ButtonLink to="/ph/hoc-phi" variant="ghost">
          Quay lại
        </ButtonLink>
      </div>
      <header>
        <h1 className="text-h2">Đơn {o.code}</h1>
        <p className="text-fg-muted">{orderSubtitle({ name: o.name, hours: null })}</p>
      </header>
      <section className="rounded-control border border-border bg-surface p-3">
        <dl className="flex flex-col gap-1">
          <div className="flex justify-between gap-3">
            <dt className="text-fg-muted">Trạng thái</dt>
            <dd>
              <Tag tone={o.status === 'DA_THU_DU' ? 'success' : 'warning'}>
                {o.status === 'DA_THU_DU'
                  ? 'Đã thu đủ'
                  : o.status === 'DA_CHUYEN_PHI'
                    ? 'Đã chuyển phí'
                    : 'Còn thiếu'}
              </Tag>
            </dd>
          </div>
          {rows.map(([k, v]) => (
            <div key={k} className="flex justify-between gap-3">
              <dt className="text-fg-muted">{k}</dt>
              <dd>{v}</dd>
            </div>
          ))}
        </dl>
      </section>
      {o.receipts.length === 0 ? (
        <StateView kind="empty" title="Chưa có phiếu thu" headingLevel={2} />
      ) : (
        <section aria-label="Phiếu thu" className="flex flex-col gap-2">
          <h2 className="text-caption font-semibold uppercase text-fg-muted">Phiếu thu</h2>
          {o.receipts.map((r) => (
            <div
              key={r.code}
              className="flex justify-between gap-3 rounded-control border border-border bg-surface p-3"
            >
              <span>{receiptTitle(r)}</span>
              <span className="font-medium">{formatMoney(r.amount)}</span>
            </div>
          ))}
        </section>
      )}
      <p className="text-caption text-fg-muted">
        Quý phụ huynh đóng tiền tại cơ sở hoặc chuyển khoản theo hướng dẫn của nhân viên.
      </p>
    </div>
  );
}
