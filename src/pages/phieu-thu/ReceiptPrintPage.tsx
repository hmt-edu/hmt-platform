// TC-07 Bản in biên nhận phiếu thu (khuôn K13, canvas TC07_in): nối get_receipt, in ở mọi tình trạng (nhãn BẢN NHÁP, CHỜ DUYỆT, ĐÃ HUỶ khi chưa duyệt).
// Quyền = quyền xem phiếu thu (hàm đọc). Số điện thoại chỉ che ở bản in. Nút "In" và "Tải PDF" cùng mở hộp in của trình duyệt. Giao diện KHÔNG tính tiền:
// số tiền và chữ "bằng chữ" chỉ đọc lại số máy chủ trả. Chưa có "Tài khoản nhận" và "Giờ cấp" (DB chưa lưu): xem ghi chú PR.
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { amountInWords } from '../../lib/amountInWords';
import { HmtError, errorOf } from '../../lib/db';
import { formatDate, formatMoney, formatNumber } from '../../lib/format';
import { PrintSheet } from '../../print/PrintSheet';
import { Button } from '../../ui/Button';
import { Spinner, StateView } from '../../ui/Feedback';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { useBranchInfo } from '../common/useBranchInfo';
import { maskPhone } from '../bao-gia/quotePrint';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { receiptStamp } from './receiptRecord';
import type { ReceiptRecord } from './receiptTypes';
import { useReceipt } from './useReceiptData';

export function ReceiptPrintPage() {
  const { id } = useParams<{ id: string }>();
  const query = useReceipt(id);
  if (query.isPending) return <Spinner label="Đang tải phiếu thu…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem phiếu thu này'
            : missing
              ? 'Không tìm thấy phiếu thu'
              : 'Không tải được phiếu thu'
        }
        actions={
          <>
            <Link to="/crm/phieu-thu" className="font-medium text-link hover:underline">
              Về danh sách Phiếu thu
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
  return <ReceiptPrint record={query.data} />;
}

function ReceiptPrint({ record }: { record: ReceiptRecord }) {
  const catalogs = useLeadCatalogs();
  const phone = useMedia(NARROW_TABLE);
  const branch = useBranchInfo(record.collect_branch_id);
  useCrumbTail(`${record.code} · Bản in`);
  const orgName = branch.data ? `Hoà Ma Toán · ${branch.data.name}` : 'Hoà Ma Toán';
  const allocations = record.money_in?.allocations ?? [];
  const approved = record.status_code === 'DA_DUYET';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3 print:hidden">
        <Link to={`/crm/phieu-thu/${record.id}`} className="font-medium text-link hover:underline">
          {`‹ Phiếu thu ${record.code}`}
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
          orgName={orgName}
          address={branch.data?.address ?? null}
          title="BIÊN NHẬN"
          subtitle="Xác nhận đã nhận tiền học phí"
          code={record.code}
          stamp={receiptStamp(record.status_code)}
          printedOn={formatDate(new Date())}
          words={amountInWords(record.amount)}
          note={
            approved
              ? `Phiếu đã được Kế toán duyệt${record.accountant_approved_at ? ` ngày ${formatDate(record.accountant_approved_at)}` : ''}${record.money_in ? ` · Khoản tiền vào ${record.money_in.code}` : ''}.`
              : 'Phiếu chưa được Kế toán duyệt, chưa có giá trị biên nhận.'
          }
          boxes={
            <>
              <div className="k13-box">
                <div className="k13-cap">NGƯỜI NỘP TIỀN</div>
                <div className="k13-name">{record.parent?.name ?? ''}</div>
                <div className="k13-row">
                  <span>Mã phụ huynh</span>
                  {record.parent?.code ?? ''}
                </div>
                <div className="k13-row">
                  <span>Đơn hàng</span>
                  {record.order.code}
                </div>
                <div className="k13-row">
                  <span>Điện thoại</span>
                  {record.parent ? maskPhone(record.parent.phone) : ''}
                </div>
              </div>
              <div className="k13-box">
                <div className="k13-cap">THÔNG TIN KHOẢN THU</div>
                <div className="k13-row">
                  <span>Ngày nhận</span>
                  <em>{formatDate(record.paid_on)}</em>
                </div>
                <div className="k13-row">
                  <span>Hình thức</span>
                  {catalogs.name('PAYMENT_METHOD', record.payment_method_code) ??
                    record.payment_method_code}
                </div>
                <div className="k13-row">
                  <span>Cơ sở thu</span>
                  {record.collect_branch_code}
                </div>
                {record.txn_ref && (
                  <div className="k13-row">
                    <span>Mã giao dịch</span>
                    {record.txn_ref}
                  </div>
                )}
              </div>
            </>
          }
          totals={
            <div className="k13-tr k13-pay">
              <span>Số tiền đã nhận</span>
              <b>{formatMoney(record.amount)}</b>
            </div>
          }
          signatures={
            <>
              <div>
                <b>Người nộp tiền</b>
                <i>(ký, ghi rõ họ tên)</i>
              </div>
              <div>
                <b>Người nhận tiền</b>
                <i>(ký, ghi rõ họ tên)</i>
                <u>{record.receiver_name ?? ''}</u>
              </div>
            </>
          }
        >
          {allocations.length > 0 && (
            <table className="k13-tb">
              <thead>
                <tr>
                  <th style={{ width: '8%' }}>#</th>
                  <th>Sản phẩm</th>
                  <th className="r" style={{ width: '24%' }}>
                    Tiền chia (đ)
                  </th>
                </tr>
              </thead>
              <tbody>
                {allocations.map((a) => (
                  <tr key={a.line_no}>
                    <td>{a.line_no}</td>
                    <td>{a.package_name}</td>
                    <td className="r">{formatNumber(a.amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </PrintSheet>
      </div>
    </div>
  );
}
