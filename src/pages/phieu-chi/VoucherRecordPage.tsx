// TC-11 Phiếu chi (bản ghi, khuôn K06): thông tin phiếu, bảng tính hoàn (số CHỤP lúc tạo yêu cầu, không sửa tay, R-TIEN-28), thanh tình trạng chỉ đọc.
// Nút «Ghi nhận đã chi» chỉ hiện khi máy chủ báo can_pay (Kế toán, phiếu Chờ chi). Giao diện KHÔNG tính tiền; điện thoại chỉ đọc (Đ248).
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { formatDateTime, formatMoney, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Table } from '../../ui/Data';
import { ConfirmDialog } from '../../ui/Dialogs';
import { Spinner, StateView } from '../../ui/Feedback';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { VOUCHER_STATUS_NAME } from './voucherConfig';
import type { VoucherRecord } from './voucherTypes';
import { payVoucher, useRefreshVoucher, useVoucher } from './useVoucherData';

export function VoucherRecordPage() {
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
  return <VoucherView key={query.data.voucher.id} record={query.data} />;
}

const STEPS: StageStep[] = [
  { code: 'CHO_CHI', label: VOUCHER_STATUS_NAME.CHO_CHI ?? 'Chờ chi' },
  { code: 'DA_CHI', label: VOUCHER_STATUS_NAME.DA_CHI ?? 'Đã chi' },
];

function VoucherView({ record }: { record: VoucherRecord }) {
  const access = useAccess();
  const openFrom = useNavigateFrom();
  const supabase = useDb();
  const toast = useToast();
  const phone = useMedia(NARROW_TABLE);
  const refresh = useRefreshVoucher(record.voucher.id);
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useCrumbTail(record.voucher.code);
  const v = record.voucher;
  const r = record.refund;
  const canPay = v.can_pay && !phone;

  const pay = () => {
    setBusy(true);
    setError(null);
    payVoucher(supabase, v.id, null)
      .then(async () => {
        setConfirming(false);
        await refresh();
        toast({ title: 'Đã ghi nhận chi tiền.' });
      })
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };

  // Bảng tính hoàn: các con số do máy chủ trả (chụp lúc tạo yêu cầu), giao diện chỉ hiện (R-TIEN-28).
  const rows =
    r.kind_code === 'TOAN_BO'
      ? [
          { key: 'paid', label: 'Phụ huynh đã đóng cho ghi danh', amount: r.paid_amount },
          {
            key: 'used',
            label: `Giờ đã học × giá gốc (${formatNumber(r.hours_used)} giờ × ${formatNumber(r.unit_price_base)} đ)`,
            amount: -(r.hours_used * r.unit_price_base),
          },
        ]
      : [
          {
            key: 'hours',
            label: `Giờ hoàn × giá sau chiết khấu (${formatNumber(r.hours_refund)} giờ × ${formatNumber(r.unit_price_net)} đ)`,
            amount: r.base_amount,
          },
        ];
  const calc = [
    ...rows,
    { key: 'base', label: 'Số tiền hoàn trước phí', amount: r.base_amount },
    { key: 'fee', label: `Phí xử lý (${formatNumber(r.fee_percent)}%)`, amount: -r.fee_amount },
    { key: 'refund', label: 'Số tiền hoàn', amount: r.refund_amount },
  ];

  return (
    <>
      <RecordDetail
        kind="Phiếu chi"
        title={v.code}
        mode="view"
        readOnly
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        headerActions={
          <Button icon="printer" onClick={() => openFrom(`/crm/phieu-chi/${v.id}/in`)}>
            In phiếu chi
          </Button>
        }
        stageShowCode={false}
        stage={{
          steps: STEPS,
          current: v.status_code,
          forwardOnly: true,
          onSelect: () => undefined,
        }}
        stageNote="Stage chỉ đọc, đổi bằng nút bên dưới."
        aside={
          <ol className="flex flex-col gap-2 text-body">
            <li>
              {formatDateTime(v.created_at)} · Phiếu chi sinh từ yêu cầu hoàn phí đã duyệt
              {v.created_by_name ? ` (${v.created_by_name})` : ''}.
            </li>
            {v.paid_at && (
              <li>
                {formatDateTime(v.paid_at)} · Đã ghi nhận chi tiền
                {v.paid_by_name ? ` (${v.paid_by_name})` : ''}.
              </li>
            )}
          </ol>
        }
        businessActions={
          canPay ? (
            <Button
              variant="primary"
              onClick={() => {
                setError(null);
                setConfirming(true);
              }}
            >
              Ghi nhận đã chi
            </Button>
          ) : undefined
        }
      >
        <div className="flex flex-col gap-4">
          {error && (
            <p role="alert" className="text-danger">
              {error}
            </p>
          )}
          <p className="text-caption text-fg-muted">
            Sinh từ yêu cầu hoàn phí đã duyệt, không tạo tay (R-TIEN-28). Số tiền hoàn tự tính theo
            bảng dưới, không sửa tay.
          </p>
          <section className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
            <dl className="flex min-w-0 flex-col">
              <DetailField label="Phiếu chi" mode="view" value={v.code} />
              <DetailField label="Ticket hoàn tiền" mode="view" value={r.ticket_ref ?? '—'} />
              <DetailField
                label="Phụ huynh"
                mode="view"
                value={`${v.parent_name} · ${v.parent_code}`}
              />
              <DetailField
                label="Ghi danh hoàn phí"
                mode="view"
                value={`${record.enrollment.code}${record.enrollment.student_name ? ` · ${record.enrollment.student_name}` : ''}`}
              />
            </dl>
            <dl className="flex min-w-0 flex-col">
              <DetailField
                label="Tình trạng"
                mode="view"
                value={VOUCHER_STATUS_NAME[v.status_code] ?? v.status_code}
              />
              <DetailField label="Người lập" mode="view" value={v.created_by_name ?? 'Hệ thống'} />
              <DetailField
                label="Cơ sở"
                mode="view"
                value={access.branchName(v.branch_code) ?? v.branch_code}
              />
              <DetailField label="Số tiền hoàn" mode="view" value={formatMoney(v.amount)} />
              {v.paid_at && (
                <DetailField
                  label="Đã chi"
                  mode="view"
                  value={`${formatDateTime(v.paid_at)}${v.paid_by_name ? ` · ${v.paid_by_name}` : ''}`}
                />
              )}
              {v.pay_note && <DetailField label="Ghi chú chi" mode="view" value={v.pay_note} />}
            </dl>
          </section>
          <Table
            caption="Bảng tính hoàn"
            rows={calc}
            rowKey={(x) => x.key}
            rowLabel={(x) => x.label}
            empty={null}
            columns={[
              { key: 'label', header: 'Khoản', cell: (x) => x.label },
              {
                key: 'amount',
                header: 'Số tiền (đ)',
                cell: (x) => <span className="tabular">{formatNumber(x.amount)}</span>,
              },
            ]}
          />
          <p className="text-caption text-fg-muted">
            Giờ tặng (nếu có) không hoàn tiền. Sau khi chi, ghi danh chuyển sang Hoàn phí.
          </p>
        </div>
      </RecordDetail>
      <ConfirmDialog
        open={confirming}
        onOpenChange={(o) => !busy && setConfirming(o)}
        title={`Ghi nhận đã chi ${v.code}`}
        description={`Xác nhận đã chi ${formatMoney(v.amount)} cho ${v.parent_name}. Không hoàn tác được.`}
        confirmLabel="Ghi nhận đã chi"
        cancelLabel="Quay lại"
        onConfirm={pay}
      />
    </>
  );
}
