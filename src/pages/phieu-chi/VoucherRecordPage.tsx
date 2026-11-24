// TC-11 Phiếu chi (bản ghi, khuôn K06): thông tin phiếu, bảng tính hoàn (số CHỤP lúc tạo yêu cầu, không sửa tay, R-TIEN-28), thanh tình trạng chỉ đọc.
// Nút «Ghi nhận đã chi» chỉ hiện khi máy chủ báo can_pay (Kế toán, phiếu Chờ chi). Giao diện KHÔNG tính tiền; điện thoại chỉ đọc (Đ248).
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { formatDate, formatDateTime, formatMoney, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { TextField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { vnDayBounds } from '../../lib/vnDay';
import { Table } from '../../ui/Data';
import { FormDialog, ReasonDialog } from '../../ui/Dialogs';
import { Spinner, StateView } from '../../ui/Feedback';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { VOUCHER_STATUS_NAME } from './voucherConfig';
import type { VoucherRecord } from './voucherTypes';
import { payVoucher, setVoucherPlan, useRefreshVoucher, useVoucher } from './useVoucherData';

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

const ACCOUNT_NOTE_MAX = 200; // allow-number: khớp giới hạn 200 ký tự ở máy chủ (migration 581)
const planToDate = (key: string): Date | null => {
  const [y, m, d] = key.split('-').map(Number);
  return y && m && d ? new Date(y, m - 1, d) : null;
};
const toDateKey = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; // allow-number: hai chữ số

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
  const catalogs = useLeadCatalogs();
  const [confirming, setConfirming] = useState(false);
  // Kế hoạch chi (TC-11): hình thức chi, tài khoản nhận (chữ tự do), ngày chi dự kiến; Kế toán ghi trước khi chi.
  const [planning, setPlanning] = useState(false);
  const [plan, setPlan] = useState({ methodCode: '', accountNote: '', plannedOn: '' });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useCrumbTail(record.voucher.code);
  const v = record.voucher;
  const r = record.refund;
  const canPay = v.can_pay && !phone;

  const pay = (methodCode: string, note: string) => {
    setBusy(true);
    setError(null);
    payVoucher(supabase, v.id, note.trim() === '' ? null : note.trim(), methodCode)
      .then(async () => {
        setConfirming(false);
        await refresh();
        toast({ title: 'Đã ghi nhận chi tiền.' });
      })
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };

  const openPlan = () => {
    setError(null);
    setPlan({
      methodCode: v.payment_method_code ?? '',
      accountNote: v.payout_account_note ?? '',
      plannedOn: v.planned_on ?? '',
    });
    setPlanning(true);
  };
  const savePlan = () => {
    setBusy(true);
    setError(null);
    setVoucherPlan(supabase, v.id, {
      methodCode: plan.methodCode === '' ? null : plan.methodCode,
      accountNote: plan.accountNote.trim() === '' ? null : plan.accountNote.trim(),
      plannedOn: plan.plannedOn === '' ? null : plan.plannedOn,
    })
      .then(async () => {
        setPlanning(false);
        await refresh();
        toast({ title: 'Đã lưu kế hoạch chi.' });
      })
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };
  // Ngày chi dự kiến chỉ CẢNH BÁO, không chặn (anh Trường chốt 20/11/2026): chưa tới ngày thì nhắc trong hộp xác nhận.
  const notYetPlanned = v.planned_on && v.planned_on > vnDayBounds().dateKey ? v.planned_on : null;

  // Bảng tính hoàn: các con số do máy chủ trả (chụp lúc tạo yêu cầu), giao diện chỉ hiện (R-TIEN-28).
  const n = formatNumber;
  const rows =
    r.kind_code === 'TOAN_BO'
      ? [
          { key: 'paid', label: 'Phụ huynh đã đóng cho ghi danh', how: '—', amount: r.paid_amount },
          {
            key: 'used',
            label: 'Giờ đã học × giá gốc',
            how: `${n(r.hours_used)} giờ × ${n(r.unit_price_base)} đ, giá gốc`,
            amount: -r.used_amount,
          },
          ...(r.prior_refund_amount > 0
            ? [
                {
                  key: 'prior',
                  label: 'Đã hoàn các lần trước',
                  how: 'Tiền gốc các phiếu hoàn đã duyệt hoặc đã chi',
                  amount: -r.prior_refund_amount,
                },
              ]
            : []),
        ]
      : [
          {
            key: 'hours',
            label: 'Giờ hoàn × giá sau chiết khấu',
            how: `${n(r.hours_refund)} giờ × ${n(r.unit_price_net)} đ`,
            amount: r.base_amount,
          },
        ];
  const calc = [
    ...rows,
    {
      key: 'base',
      // Canvas TC-11: hoàn toàn bộ gọi «Còn lại sau khi trừ giờ đã học»; hoàn một phần giữ «Số tiền hoàn trước phí».
      label:
        r.kind_code === 'TOAN_BO' ? 'Còn lại sau khi trừ giờ đã học' : 'Số tiền hoàn trước phí',
      how:
        r.kind_code === 'TOAN_BO'
          ? [
              n(r.paid_amount),
              n(r.used_amount),
              ...(r.prior_refund_amount > 0 ? [n(r.prior_refund_amount)] : []),
            ].join(' − ')
          : '—',
      amount: r.base_amount,
    },
    {
      key: 'fee',
      label: `Phí xử lý (${n(r.fee_percent)}%)`,
      how: `${n(r.fee_percent)}% của ${n(r.base_amount)}`,
      amount: -r.fee_amount,
    },
    {
      key: 'refund',
      label: 'Số tiền hoàn',
      how: `${n(r.base_amount)} − ${n(r.fee_amount)}`,
      amount: r.refund_amount,
    },
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
            <>
              <Button onClick={openPlan}>Kế hoạch chi</Button>
              <Button
                variant="primary"
                onClick={() => {
                  setError(null);
                  setConfirming(true);
                }}
              >
                Ghi nhận đã chi
              </Button>
            </>
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
            Sinh từ yêu cầu hoàn phí đã duyệt, không tạo tay. Số tiền hoàn tự tính theo bảng dưới,
            không sửa tay.
          </p>
          <section className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
            <dl className="flex min-w-0 flex-col">
              <DetailField label="Phiếu chi" mode="view" value={v.code} />
              <DetailField label="Ticket hoàn tiền" mode="view" value={r.ticket_ref ?? '—'} />
              <DetailField label="Phụ huynh" mode="view" value={v.parent_name} />
              <DetailField label="Mã phụ huynh" mode="view" value={v.parent_code} />
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
              {/* Canvas TC11: ba trường «Hình thức chi», «Tài khoản nhận» (chữ tự do), «Ngày chi dự kiến». */}
              <DetailField label="Hình thức chi" mode="view" value={v.payment_method ?? '—'} />
              <DetailField
                label="Tài khoản nhận"
                mode="view"
                value={v.payout_account_note ?? '—'}
              />
              <DetailField
                label="Ngày chi dự kiến"
                mode="view"
                value={v.planned_on ? formatDate(v.planned_on) : '—'}
              />
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
              { key: 'how', header: 'Cách tính', cell: (x) => x.how },
            ]}
          />
          <p className="text-caption text-fg-muted">
            Giờ tặng (nếu có) không hoàn tiền. Sau khi chi, ghi danh chuyển sang Hoàn phí.
          </p>
        </div>
      </RecordDetail>
      {/* Hình thức chi dùng chung danh mục hình thức thanh toán của Phiếu thu (anh Trường chốt 20/11/2026); hộp K08 chọn một mục kèm ghi chú. */}
      <ReasonDialog
        open={confirming}
        onOpenChange={(o) => !busy && setConfirming(o)}
        title={`Ghi nhận đã chi ${v.code}`}
        description={`Xác nhận đã chi ${formatMoney(v.amount)} cho ${v.parent_name}. Không hoàn tác được.${notYetPlanned ? ` Chưa tới ngày chi dự kiến (${formatDate(notYetPlanned)}); vẫn ghi nhận được.` : ''}`}
        options={catalogs.options('PAYMENT_METHOD').map((o) => ({ ...o, needsNote: false }))}
        reasonLabel="Hình thức chi"
        noteLabel="Ghi chú chi"
        notePlaceholder="Ghi chú thêm (không bắt buộc)"
        confirmLabel="Ghi nhận đã chi"
        cancelLabel="Quay lại"
        busy={busy}
        error={error}
        onConfirm={(result) => pay(result.option, result.note)}
      />
      <FormDialog
        open={planning}
        onOpenChange={(o) => !busy && setPlanning(o)}
        title={`Kế hoạch chi ${v.code}`}
        subtitle="Ghi trước khi chi; chưa chi tiền. Ngày chi dự kiến chỉ để nhắc, không chặn chi."
        confirmLabel="Lưu kế hoạch"
        canSubmit
        busy={busy}
        error={error}
        onSubmit={savePlan}
      >
        <div className="flex flex-col gap-3">
          <Select
            label="Hình thức chi"
            value={plan.methodCode}
            placeholder="Chưa chọn"
            onChange={(val) => setPlan({ ...plan, methodCode: val })}
            options={catalogs.options('PAYMENT_METHOD')}
            className="w-full"
          />
          <TextField
            label="Tài khoản nhận"
            value={plan.accountNote}
            onChange={(e) => setPlan({ ...plan, accountNote: e.target.value })}
            placeholder="Ví dụ: Techcombank …5544 (chữ tự do)"
            maxLength={ACCOUNT_NOTE_MAX}
          />
          <DateInput
            label="Ngày chi dự kiến"
            value={planToDate(plan.plannedOn)}
            onChange={(d) => setPlan({ ...plan, plannedOn: d ? toDateKey(d) : '' })}
          />
        </div>
      </FormDialog>
    </>
  );
}
