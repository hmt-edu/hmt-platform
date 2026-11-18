// TC-12 Bản in phiếu chi (khuôn K13, cùng khuôn TC-07 biên nhận): nối get_payment_voucher. Chưa có khung canvas riêng cho mẫu phiếu chi,
// nên dùng đúng khuôn in của biên nhận, chỉ đổi trường và chữ (số điện thoại không in). Giao diện KHÔNG tính tiền: số tiền, "bằng chữ" đọc lại số máy chủ trả.
// Chưa có "Hình thức chi", "Tài khoản nhận" (DB chưa lưu): xem ghi chú PR.
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { amountInWords } from '../../lib/amountInWords';
import { HmtError, errorOf } from '../../lib/db';
import { formatDate, formatMoney, formatNumber } from '../../lib/format';
import { PrintSheet } from '../../print/PrintSheet';
import { Button } from '../../ui/Button';
import { Spinner, StateView } from '../../ui/Feedback';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import type { VoucherRecord } from './voucherTypes';
import { useVoucher } from './useVoucherData';

export function VoucherPrintPage() {
  const { id } = useParams<{ id: string }>();
  const query = useVoucher(id);
  if (query.isPending) return <Spinner label="Đang tải phiếu chi…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem phiếu chi này'
            : missing
              ? 'Không tìm thấy phiếu chi'
              : 'Không tải được phiếu chi'
        }
        actions={
          <>
            <Link to="/crm/phieu-chi" className="font-medium text-link hover:underline">
              Về danh sách Phiếu chi
            </Link>
            {!forbidden && !missing && (
              <Button onClick={() => void query.refetch()}>Thử lại</Button>
            )}
          </>
        }
      >
        {errorOf(error).message}
      </StateView>
    );
  }
  return <VoucherPrint record={query.data} />;
}

function VoucherPrint({ record }: { record: VoucherRecord }) {
  const phone = useMedia(NARROW_TABLE);
  const v = record.voucher;
  const r = record.refund;
  useCrumbTail(`${v.code} · Bản in`);
  const paid = v.status_code === 'DA_CHI';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3 print:hidden">
        <Link to={`/crm/phieu-chi/${v.id}`} className="font-medium text-link hover:underline">
          {`‹ Phiếu chi ${v.code}`}
        </Link>
        <span className="flex-1" />
        <span className="text-caption text-fg-muted">Chọn “Lưu thành PDF” để tải</span>
        <Button icon="file" onClick={() => window.print()}>
          Tải PDF
        </Button>
        {!phone && (
          <Button variant="primary" icon="printer" onClick={() => window.print()}>
            In
          </Button>
        )}
      </div>
      <div
        className="overflow-x-auto pb-4"
        tabIndex={0}
        role="region"
        aria-label="Bản xem trước bản in"
      >
        <PrintSheet
          orgName={`Hoà Ma Toán · ${v.branch_code}`}
          address={null}
          title="PHIẾU CHI"
          subtitle="Hoàn học phí cho phụ huynh"
          code={v.code}
          stamp={paid ? null : 'CHỜ CHI'}
          printedOn={formatDate(new Date())}
          words={amountInWords(v.amount)}
          note={
            paid
              ? `Đã chi ngày ${formatDate(v.paid_at)}${v.paid_by_name ? ` · ${v.paid_by_name}` : ''}.`
              : 'Phiếu chưa chi tiền, chưa có giá trị chứng từ chi.'
          }
          boxes={
            <>
              <div className="k13-box">
                <div className="k13-cap">NGƯỜI NHẬN TIỀN HOÀN</div>
                <div className="k13-name">{v.parent_name}</div>
                <div className="k13-row">
                  <span>Mã phụ huynh</span>
                  {v.parent_code}
                </div>
                <div className="k13-row">
                  <span>Ghi danh hoàn phí</span>
                  {record.enrollment.code}
                </div>
              </div>
              <div className="k13-box">
                <div className="k13-cap">THÔNG TIN KHOẢN CHI</div>
                <div className="k13-row">
                  <span>Ticket hoàn tiền</span>
                  {r.ticket_ref ?? '—'}
                </div>
                <div className="k13-row">
                  <span>Ngày lập</span>
                  <em>{formatDate(v.created_at)}</em>
                </div>
                <div className="k13-row">
                  <span>Cơ sở</span>
                  {v.branch_code}
                </div>
              </div>
            </>
          }
          totals={
            <div className="k13-tr k13-pay">
              <span>Số tiền hoàn</span>
              <b>{formatMoney(v.amount)}</b>
            </div>
          }
          signatures={
            <>
              <div>
                <b>Người nhận tiền</b>
                <i>(ký, ghi rõ họ tên)</i>
              </div>
              <div>
                <b>Kế toán chi tiền</b>
                <i>(ký, ghi rõ họ tên)</i>
                <u>{v.paid_by_name ?? ''}</u>
              </div>
            </>
          }
        >
          <table className="k13-tb">
            <thead>
              <tr>
                <th>Khoản</th>
                <th className="r" style={{ width: '28%' }}>
                  Số tiền (đ)
                </th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Số tiền hoàn trước phí</td>
                <td className="r">{formatNumber(r.base_amount)}</td>
              </tr>
              <tr>
                <td>{`Phí xử lý (${formatNumber(r.fee_percent)}%)`}</td>
                <td className="r">{formatNumber(-r.fee_amount)}</td>
              </tr>
              <tr>
                <td>Số tiền hoàn</td>
                <td className="r">{formatNumber(r.refund_amount)}</td>
              </tr>
            </tbody>
          </table>
        </PrintSheet>
      </div>
    </div>
  );
}
