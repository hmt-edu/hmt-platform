// BH-12 Bản in đơn hàng (khuôn K13, A4 dọc, như bản in báo giá BH-03): nối get_order, in ở mọi tình trạng, nhãn theo tình trạng thật.
// Quyền = quyền xem đơn. Nút "In" và "Tải PDF" cùng mở hộp in của trình duyệt. Giao diện KHÔNG tính tiền (R-TIEN-13).
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { FromLink } from '../../layout/FromLink';
import { amountInWords } from '../../lib/amountInWords';
import { HmtError, errorOf } from '../../lib/db';
import { formatDate, formatMoney, formatNumber } from '../../lib/format';
import { PrintImageButton } from '../../print/PrintImageButton';
import { PrintSheet } from '../../print/PrintSheet';
import { Button } from '../../ui/Button';
import { Spinner, StateView } from '../../ui/Feedback';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { useBranchInfo } from '../common/useBranchInfo';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { hoursText, maskPhone } from '../bao-gia/quotePrint';
import { discountText, giftValueText, quantityText } from '../bao-gia/quoteRecord';
import { orderStamp } from './orderPrint';
import type { OrderRecord } from './orderTypes';
import { useOrder } from './useOrderData';

export function OrderPrintPage() {
  const { id } = useParams<{ id: string }>();
  const query = useOrder(id);
  if (query.isPending) return <Spinner label="Đang tải đơn hàng…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem đơn hàng này'
            : missing
              ? 'Không tìm thấy đơn hàng'
              : 'Không tải được đơn hàng'
        }
        actions={
          <>
            {/* duong-dan-menu: không tải được bản ghi, về danh sách chung */}
            <Link to="/crm/don-hang" className="font-medium text-link hover:underline">
              Về danh sách Đơn hàng
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
  return <OrderPrint record={query.data} />;
}

function OrderPrint({ record }: { record: OrderRecord }) {
  const catalogs = useLeadCatalogs();
  const branch = useBranchInfo(record.branch_id);
  const phone = useMedia(NARROW_TABLE);
  useCrumbTail(`${record.code} · Bản in`);

  // Đơn của nhiều em: mỗi dòng ghi tên em; dòng quà tặng giá 0 (R-TIEN-30).
  const modeName = (code: string) => catalogs.name('STUDY_MODE', code) ?? code;
  const hasGift = record.lines.some((l) => l.line_kind === 'GIFT');
  const orgName = branch.data ? `Hoà Ma Toán · ${branch.data.name}` : 'Hoà Ma Toán';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3 print:hidden">
        <FromLink
          to={`/crm/don-hang/${record.id}`}
          className="font-medium text-link hover:underline"
        >
          {`‹ Đơn hàng ${record.code}`}
        </FromLink>
        <span className="flex-1" />
        <span className="text-caption text-fg-muted">Chọn “Lưu thành PDF” để tải</span>
        <Button icon="file" onClick={() => window.print()}>
          Tải PDF
        </Button>
        <PrintImageButton code={record.code} />
        {/* Điện thoại không có máy in: ẩn nút In, giữ Tải PDF (khuôn K13). */}
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
          title="ĐƠN HÀNG"
          subtitle="Dành cho phụ huynh và học sinh"
          code={record.code}
          legacyRef={record.legacy_ref}
          stamp={orderStamp(record.status_code)}
          printedOn={formatDate(new Date())}
          words={amountInWords(record.total_amount)}
          note={hasGift ? 'Quà tặng không có giá, không tính vào tổng.' : undefined}
          boxes={
            <>
              <div className="k13-box">
                <div className="k13-cap">KÍNH GỬI PHỤ HUYNH</div>
                <div className="k13-name">{record.parent_name}</div>
                <div className="k13-row">
                  <span>Mã phụ huynh</span>
                  {record.parent_code}
                </div>
                <div className="k13-row">
                  <span>Điện thoại</span>
                  {maskPhone(record.parent_phone)}
                </div>
              </div>
              <div className="k13-box">
                <div className="k13-cap">THÔNG TIN HỌC PHÍ</div>
                <div className="k13-row">
                  <span>Ngày lập</span>
                  <em>{formatDate(record.created_at)}</em>
                </div>
                <div className="k13-row">
                  <span>Người lập</span>
                  {record.created_by_name ?? ''}
                </div>
              </div>
            </>
          }
          totals={
            <>
              <div className="k13-tr">
                <span>Tổng niêm yết</span>
                <b>{formatNumber(record.gross_total)}</b>
              </div>
              <div className="k13-tr">
                <span>Tổng ưu đãi</span>
                <b>
                  {record.discount_total > 0 ? `− ${formatNumber(record.discount_total)}` : '0'}
                </b>
              </div>
              <div className="k13-tr k13-pay">
                <span>Thành tiền</span>
                <b>{formatMoney(record.total_amount)}</b>
              </div>
            </>
          }
          signatures={
            <>
              <div>
                <b>Phụ huynh xác nhận</b>
                <i>(ký, ghi rõ họ tên)</i>
              </div>
              <div>
                <b>Người lập</b>
                <i>(ký, ghi rõ họ tên)</i>
                <u>{record.created_by_name ?? ''}</u>
              </div>
            </>
          }
        >
          <table className="k13-tb">
            <thead>
              <tr>
                <th style={{ width: '4%' }}>#</th>
                <th style={{ width: '14%' }}>Học sinh</th>
                <th style={{ width: '21%' }}>Gói</th>
                <th style={{ width: '9%' }}>Hình thức</th>
                <th className="r" style={{ width: '8%' }}>
                  Giờ mua
                </th>
                <th className="r" style={{ width: '7%' }}>
                  Giờ tặng
                </th>
                <th className="r" style={{ width: '10%' }}>
                  Đơn giá
                </th>
                <th style={{ width: '14%' }}>Ưu đãi · chính sách</th>
                <th className="r" style={{ width: '13%' }}>
                  Thành tiền
                </th>
              </tr>
            </thead>
            <tbody>
              {record.lines.map((l) => {
                const gift = l.line_kind === 'GIFT';
                const discount = discountText(l);
                return (
                  <tr key={l.id} className={gift ? 'k13-gift' : undefined}>
                    <td>{l.line_no}</td>
                    <td>{l.student_name ?? ''}</td>
                    <td>
                      {gift && <span className="k13-gt">Quà tặng</span>}
                      {l.package_name}
                    </td>
                    <td>{gift ? '—' : modeName(l.delivery_mode_code)}</td>
                    <td className="r">{gift ? quantityText(l) : hoursText(l.quantity)}</td>
                    <td className="r">{gift ? '—' : hoursText(l.gifted_quantity)}</td>
                    <td className="r">
                      {formatNumber(l.unit_price)}
                      {giftValueText(l) !== '' && (
                        <span className="k13-sm">{giftValueText(l)}</span>
                      )}
                    </td>
                    <td>
                      {discount === '' ? '—' : discount}
                      {l.discount_amount > 0 && (
                        <span className="k13-sm">{`− ${formatNumber(l.discount_amount)}`}</span>
                      )}
                    </td>
                    <td className="r">
                      <b>{formatNumber(l.line_total)}</b>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </PrintSheet>
      </div>
    </div>
  );
}
