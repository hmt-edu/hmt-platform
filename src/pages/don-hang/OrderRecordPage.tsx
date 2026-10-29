// BH-05 Đơn hàng (bản ghi), phần XEM (UI-O2a): khuôn K06 nối get_order. Xem đơn ở mọi tình trạng: đầu bản ghi, thanh tình trạng, các nút
// theo khung, tab Dòng đơn (lưới K06c chỉ đọc), Thanh toán (lịch đóng tiền), Ghi danh (làm ở phân hệ sau), Ghi chú và hoạt động.
// UI-O2b: nút Trình duyệt (Nháp) và mục Huỷ đơn (R-TIEN-38, hộp K08 có lý do từ danh mục); Duyệt, Từ chối (UI-O2c) và sửa Nháp (UI-O3) có ở
// các PR sau. Giao diện KHÔNG tính tiền (R-TIEN-13): mọi con số do get_order trả. Đọc không bị chặn khi tắt Bán hàng (Đ181); Trình, Huỷ cần
// Bán hàng đang bật (Đ173), máy chủ kiểm lại. Điện thoại chỉ đọc (Đ248): ẩn Trình, Huỷ.
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { useAuth } from '../../lib/auth/authContext';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { formatDate, formatDateTime, formatMoney, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Table, Tag, type TagTone } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { ReasonDialog } from '../../ui/Dialogs';
import { Tabs, type MenuItem } from '../../ui/Overlays';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { discountText, quantityText } from '../bao-gia/quoteRecord';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  approverWarning,
  canCancelOrder,
  canSubmitOrder,
  errorLineNumbers,
  expectedApproverText,
  lastRejection,
  orderSteps,
} from './orderRecord';
import type { OrderEvent, OrderInstallment, OrderLine, OrderRecord } from './orderTypes';
import { cancelOrder, submitOrder, useOrder, useRefreshOrder } from './useOrderData';

const STATUS_TONE: Record<string, TagTone> = {
  NHAP: 'neutral',
  DA_TRINH: 'info',
  DA_DUYET: 'success',
  HUY: 'neutral',
};

/** Tên cột (get_order → nhật ký) hiện cho người dùng trong lịch sử thay đổi. */
const ORDER_FIELD_LABELS: Record<string, string> = {
  status_code: 'Tình trạng',
  total_amount: 'Tổng tiền',
  payment_term_id: 'Điều khoản thanh toán',
  cancel_reason_code: 'Lý do huỷ',
  cancel_note: 'Ghi chú huỷ',
};

const EVENT_TEXT: Record<OrderEvent['event_code'], string> = {
  TAO: 'Tạo đơn',
  TRINH: 'Trình duyệt',
  DUYET: 'Duyệt',
  TU_CHOI: 'Từ chối',
  HUY: 'Huỷ đơn',
};

export function OrderRecordPage() {
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
  return <OrderView key={query.data.id} record={query.data} />;
}

function OrderView({ record }: { record: OrderRecord }) {
  const openFrom = useNavigateFrom();
  const [tab, setTab] = useState('lines');
  const access = useAccess();
  const catalogs = useLeadCatalogs();
  const supabase = useDb();
  const { claims } = useAuth();
  const toast = useToast();
  const refresh = useRefreshOrder(record.id);
  const phone = useMedia(NARROW_TABLE);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<{ message: string; retry: boolean } | null>(null);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  useCrumbTail(record.code);

  const statusName = (code: string) => catalogs.name('ORDER_STATUS', code) ?? code;
  const modeName = (code: string) => catalogs.name('STUDY_MODE', code) ?? code;
  const branchName =
    access.teachingBranches.find((b) => b.code === record.branch_code)?.name ?? undefined;
  const rejection = lastRejection(record);
  const approverText = expectedApproverText(record);
  const warning = approverWarning(record);
  const steps: StageStep[] = orderSteps(record).map((code) => ({ code, label: statusName(code) }));

  // Quyền đọc từ ma trận quyền (không viết cứng vai trò); công tắc Bán hàng kiểm ở đây, máy chủ kiểm lại (Đ173).
  const featureOn = access.featureOn('BAN_HANG');
  const canSubmit = canSubmitOrder(record, {
    edit: access.can('SALES_ORDER', 'SUA'),
    featureOn,
    phone,
  });
  const canCancel = canCancelOrder(record, {
    userId: claims?.userId ?? '',
    canCancel: access.can('SALES_ORDER', 'HUY'),
    featureOn,
    // Người duyệt thay khi vắng (Admin): máy chủ chốt, ở đây chỉ đoán theo quyền Quản trị để hiện mục.
    approvesInstead: access.can('ADMIN', 'XEM'),
    phone,
  });
  const menuItems: MenuItem[] = canCancel
    ? [
        {
          kind: 'action',
          label: 'Huỷ đơn',
          onSelect: () => {
            setCancelError(null);
            setCancelOpen(true);
          },
        },
      ]
    : [];
  const errorLines = submitError ? errorLineNumbers(submitError.message) : [];

  async function submit() {
    if (submitting) return;
    setSubmitting(true);
    setSubmitError(null);
    try {
      await submitOrder(supabase, record.id);
      await refresh();
      toast({ title: 'Đã trình đơn.' });
    } catch (e) {
      const error = errorOf(e);
      // Lỗi nghiệp vụ (HMT_*) hiện thẳng câu tiếng Việt, kèm dòng bị lỗi; lỗi mạng hoặc lỗi chung thì có nút Thử lại.
      setSubmitError({ message: error.message, retry: error.code === 'HMT_LOI' });
      setTab('lines');
    } finally {
      setSubmitting(false);
    }
  }

  const lineColumns = [
    {
      key: 'student',
      header: 'Học sinh',
      cell: (l: OrderLine) =>
        l.student_name ? (
          <span className="flex flex-col">
            <span>
              {l.student_name}
              {l.student_birth_year ? ` · ${l.student_birth_year}` : ''}
            </span>
            {!l.student_complete && (
              <span className="text-caption text-on-warning-subtle">
                {l.student_birth_year ? 'thiếu họ tên' : 'thiếu năm sinh'}
              </span>
            )}
            {errorLines.includes(l.line_no) && (
              <span className="text-caption text-on-danger-subtle">
                {`Dòng ${l.line_no}: cần sửa, xem thông báo phía trên`}
              </span>
            )}
          </span>
        ) : (
          <span className="text-fg-muted">Chưa có học sinh</span>
        ),
    },
    { key: 'product', header: 'Sản phẩm', cell: (l: OrderLine) => l.package_name },
    {
      key: 'mode',
      header: 'Hình thức',
      cell: (l: OrderLine) => (l.line_kind === 'GIFT' ? '—' : modeName(l.delivery_mode_code)),
    },
    {
      key: 'quantity',
      header: 'Số lượng',
      cell: (l: OrderLine) => <span className="tabular">{quantityText(l)}</span>,
    },
    {
      key: 'price',
      header: 'Đơn giá',
      cell: (l: OrderLine) => <span className="tabular">{formatNumber(l.unit_price)}</span>,
    },
    {
      key: 'discount',
      header: 'Chiết khấu',
      cell: (l: OrderLine) => {
        const text = discountText(l);
        return text === '' ? '—' : text;
      },
    },
    {
      key: 'reduction',
      header: 'Giảm',
      cell: (l: OrderLine) => <span className="tabular">{formatNumber(l.discount_amount)}</span>,
    },
    {
      key: 'total',
      header: 'Thành tiền',
      cell: (l: OrderLine) => <span className="tabular">{formatNumber(l.line_total)}</span>,
    },
  ];

  const lines = (
    <div className="flex flex-col gap-3">
      <Table<OrderLine>
        caption="Dòng đơn"
        rows={record.lines}
        rowKey={(l) => l.id}
        rowLabel={(l) => `Dòng ${l.line_no}`}
        columns={lineColumns}
        empty={<p className="px-4 py-6 text-center text-fg-muted">Đơn chưa có dòng nào.</p>}
      />
      <dl className="ml-auto flex w-full max-w-sm flex-col gap-1 text-body">
        <TotalRow label="Tổng niêm yết" value={formatMoney(record.gross_total)} />
        <TotalRow
          label="Tổng chiết khấu"
          value={record.discount_total > 0 ? `− ${formatMoney(record.discount_total)}` : '0 đ'}
        />
        <TotalRow label="Thành tiền" value={formatMoney(record.total_amount)} strong />
        {/* Đ269: chưa có phiếu thu nên Đã thu, Còn phải thu hiện "—", không hiện 0. */}
        <TotalRow label="Đã thu" value="—" muted />
        <TotalRow label="Còn phải thu" value="—" muted />
      </dl>
    </div>
  );

  const payments = (
    <div className="flex flex-col gap-4">
      <section className="flex flex-col gap-1.5">
        <h3 className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
          Lịch đóng tiền từng đợt
        </h3>
        {record.installments.length === 0 ? (
          <p className="text-fg-muted">
            Đơn chưa có lịch đóng tiền: không chọn điều khoản thì thanh toán một lần (R-TIEN-07).
          </p>
        ) : (
          <Table<OrderInstallment>
            caption="Lịch đóng tiền"
            rows={record.installments}
            rowKey={(i) => String(i.seq)}
            rowLabel={(i) => `Đợt ${i.seq}`}
            columns={[
              {
                key: 'seq',
                header: 'Đợt',
                cell: (i) => `Đợt ${i.seq}/${record.installments.length}`,
              },
              {
                key: 'due',
                header: 'Hạn đóng',
                cell: (i) =>
                  i.due_date ? formatDate(i.due_date) : `${i.due_days} ngày sau khi duyệt`,
              },
              {
                key: 'amount',
                header: 'Số tiền (đ)',
                cell: (i) => <span className="tabular">{formatNumber(i.amount)}</span>,
              },
              {
                key: 'paid',
                header: 'Đã đóng (đ)',
                cell: () => <span className="text-fg-muted">—</span>,
              },
            ]}
            empty={null}
          />
        )}
        <p className="text-caption text-fg-muted">
          Lịch tự tính từ Điều khoản thanh toán của đơn, chỉ đọc. Dùng để theo dõi công nợ và nhắc
          hạn, không chặn học (R-TIEN-07).
        </p>
      </section>
      <section className="flex flex-col gap-1">
        <h3 className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
          Phiếu thu
        </h3>
        <p className="text-fg-muted">Chưa có phiếu thu. Phiếu thu làm ở phân hệ sau.</p>
      </section>
    </div>
  );

  const history = (
    <section className="flex flex-col gap-1.5">
      <h3 className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
        Lịch sử xử lý
      </h3>
      <ul className="flex flex-col gap-1 text-body">
        {[...record.events]
          .sort((a, b) => a.seq - b.seq)
          .map((e) => (
            <li key={e.seq} className="flex flex-wrap gap-x-2">
              <b>{EVENT_TEXT[e.event_code]}</b>
              <span className="text-fg-muted">
                {`${formatDateTime(e.created_at)} · ${e.actor_name ?? 'Hệ thống'}${e.on_behalf ? ' (thay người duyệt)' : ''}`}
              </span>
              {eventReason(e, catalogs.name) && <span>{eventReason(e, catalogs.name)}</span>}
            </li>
          ))}
      </ul>
    </section>
  );

  return (
    <>
      <RecordDetail
        kind="Đơn hàng"
        title={record.code}
        mode="view"
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        readOnly
        stageShowCode={false}
        stage={{
          steps,
          current: record.status_code,
          forwardOnly: true,
          onSelect: () => undefined,
        }}
        stageNote="Stage chỉ đọc, đổi bằng nút bên dưới."
        menu={menuItems.length > 0 ? { label: 'Hành động', items: menuItems } : undefined}
        businessActions={
          <>
            {record.status_code === 'NHAP' && (
              <span className="flex flex-wrap items-center gap-2">
                {canSubmit && (
                  <Button variant="primary" loading={submitting} onClick={() => void submit()}>
                    Trình duyệt
                  </Button>
                )}
                {approverText && <span className="text-caption text-fg-label">{approverText}</span>}
              </span>
            )}
            {record.status_code === 'DA_DUYET' && (
              <Button variant="primary" disabled title="Phiếu thu làm ở phân hệ sau">
                Tạo phiếu thu
              </Button>
            )}
          </>
        }
        smart={[
          {
            key: 'co-hoi',
            label: 'Cơ hội',
            icon: 'recruit',
            count: record.opportunity_id ? 1 : 0,
            ...(record.opportunity_id
              ? { onOpen: () => openFrom(`/crm/co-hoi/${record.opportunity_id ?? ''}`) }
              : { unavailable: 'Đơn này không sinh từ cơ hội', onOpen: () => undefined }),
          },
          {
            key: 'phu-huynh',
            label: 'Phụ huynh',
            icon: 'user',
            count: 1,
            unavailable: 'Có khi làm màn Khách hàng',
            onOpen: () => undefined,
          },
          {
            key: 'bao-gia',
            label: 'Báo giá',
            icon: 'file',
            count: record.quotation_id ? 1 : 0,
            ...(record.quotation_id
              ? { onOpen: () => openFrom(`/crm/bao-gia/${record.quotation_id ?? ''}`) }
              : { unavailable: 'Đơn này không sinh từ báo giá', onOpen: () => undefined }),
          },
          {
            key: 'phieu-thu',
            label: 'Phiếu thu',
            icon: 'payment',
            count: 0,
            unavailable: 'Làm ở phân hệ sau',
            onOpen: () => undefined,
          },
          {
            key: 'ghi-danh',
            label: 'Ghi danh',
            icon: 'classes',
            count: 0,
            unavailable: 'Làm ở phân hệ sau',
            onOpen: () => undefined,
          },
        ]}
        aside={
          <RecordChatter
            entityType="SALES_ORDER"
            entityId={record.id}
            createdText="Tạo đơn hàng."
            format={{
              labels: ORDER_FIELD_LABELS,
              value: (column, value) => {
                if (column === 'total_amount' && typeof value === 'number')
                  return formatMoney(value);
                if (column === 'status_code' && typeof value === 'string') return statusName(value);
                if (column === 'cancel_reason_code' && typeof value === 'string')
                  return catalogs.name('ORDER_CANCEL_REASON', value) ?? value;
                return null;
              },
            }}
            canWrite
          />
        }
      >
        <div className="flex flex-col gap-6">
          {record.status_code === 'DA_TRINH' && (
            <Notice>
              Đơn đã trình, chờ {record.approver_name ?? 'người duyệt'} duyệt. Trong lúc chờ không
              sửa được dòng.
            </Notice>
          )}
          {rejection && (
            <Notice tone="danger" title="Đơn bị từ chối">
              {`${rejection.actor_name ?? ''}, ${formatDate(rejection.created_at)}: “${eventReason(rejection, catalogs.name)}”. Sửa rồi bấm Trình lại.`}
            </Notice>
          )}
          {record.status_code === 'HUY' && (
            <Notice>
              Đơn đã huỷ
              {record.cancel_reason ? `: ${record.cancel_reason}` : ''}
              {record.cancel_note ? ` · ${record.cancel_note}` : ''}. Chỉ còn xem.
            </Notice>
          )}
          {record.status_code === 'DA_DUYET' && (
            <Notice>
              Đơn đã duyệt và khoá: sửa sau này đi qua xếp lớp, chuyển lớp trên ghi danh.
            </Notice>
          )}
          {submitError && (
            <Notice tone="danger" title="Chưa trình được">
              {submitError.message}
              {submitError.retry && (
                <Button className="ml-2" loading={submitting} onClick={() => void submit()}>
                  Thử lại
                </Button>
              )}
            </Notice>
          )}
          {warning && (
            <Notice tone="warning" title="Cần xử lý trước khi trình">
              {warning}
            </Notice>
          )}
          {record.status_code === 'NHAP' && record.has_incomplete_students && (
            <Notice tone="warning" title="Có em chưa đủ thông tin">
              Mỗi em cần họ tên và năm sinh trước khi trình (R-TIEN-35). Bổ sung ở cơ hội rồi quay
              lại.
            </Notice>
          )}
          <section className="flex min-w-0 flex-col">
            <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
              Thông tin chung
            </h3>
            <div className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
              <dl className="flex min-w-0 flex-col">
                <DetailField
                  label="Mã đơn"
                  hint="cấp khi tạo, không sửa"
                  mode="view"
                  value={
                    <>
                      {record.code}
                      {record.legacy_ref && (
                        <span className="ml-2 text-caption text-fg-muted">
                          mã cũ {record.legacy_ref}
                        </span>
                      )}
                    </>
                  }
                />
                <DetailField
                  label="Phụ huynh"
                  mode="view"
                  value={`${record.parent_name} · ${record.parent_code} · ${formatPhone(record.parent_phone)}`}
                />
                {record.opportunity_id && (
                  <DetailField
                    label="Cơ hội"
                    mode="view"
                    value={
                      <Link
                        to={`/crm/co-hoi/${record.opportunity_id}`}
                        className="font-medium text-link hover:underline"
                      >
                        {record.opportunity_code}
                      </Link>
                    }
                  />
                )}
                {record.quotation_id && (
                  <DetailField
                    label="Báo giá"
                    mode="view"
                    value={
                      <Link
                        to={`/crm/bao-gia/${record.quotation_id}`}
                        className="font-medium text-link hover:underline"
                      >
                        {record.quotation_code}
                      </Link>
                    }
                  />
                )}
              </dl>
              <dl className="flex min-w-0 flex-col">
                <DetailField
                  label="Tình trạng"
                  mode="view"
                  value={
                    <Tag tone={STATUS_TONE[record.status_code] ?? 'neutral'} dot>
                      {record.status_code === 'DA_DUYET'
                        ? `${statusName('DA_DUYET')} · khoá`
                        : rejection
                          ? `${statusName('NHAP')} · bị từ chối`
                          : statusName(record.status_code)}
                    </Tag>
                  }
                />
                <DetailField label="Ngày lập" mode="view" value={formatDate(record.created_at)} />
                <DetailField label="Người lập" mode="view" value={record.created_by_name ?? ''} />
                <DetailField
                  label="Người duyệt"
                  mode="view"
                  value={
                    record.approved_at
                      ? `${record.approved_by_name ?? ''} · ${formatDate(record.approved_at)}${record.approved_on_behalf ? ' (duyệt thay)' : ''}`
                      : (record.approver_name ?? '')
                  }
                />
                <DetailField
                  label="Cơ sở vận hành"
                  mode="view"
                  value={branchName ? `${record.branch_code} ${branchName}` : record.branch_code}
                />
                <DetailField
                  label="Điều khoản thanh toán"
                  hint="danh mục cấu hình; lịch đợt ở tab Thanh toán"
                  mode="view"
                  value={record.payment_term_name ?? 'Thanh toán một lần'}
                />
              </dl>
            </div>
          </section>
          <Tabs
            label="Nội dung đơn"
            value={tab}
            onChange={setTab}
            items={[
              { value: 'lines', label: 'Dòng đơn', count: record.lines.length, content: lines },
              { value: 'payments', label: 'Thanh toán', content: payments },
              {
                value: 'enrol',
                label: 'Ghi danh',
                content: (
                  <p className="text-fg-muted">
                    Làm ở phân hệ sau. Ghi danh sinh khi tiền đã vào đủ cọc tối thiểu (mỗi dòng đơn
                    một ghi danh).
                  </p>
                ),
              },
            ]}
          />
          {history}
        </div>
      </RecordDetail>
      <ReasonDialog
        open={cancelOpen}
        onOpenChange={setCancelOpen}
        title="Huỷ đơn hàng"
        description={`Đơn ${record.code} sẽ chuyển sang Huỷ và chỉ còn xem; các dòng trả về báo giá. Chỉ huỷ được khi đơn chưa có phiếu thu.`}
        options={catalogs.options('ORDER_CANCEL_REASON').map((o) => ({
          ...o,
          needsNote: catalogs.requiresNote('ORDER_CANCEL_REASON', o.value),
        }))}
        confirmLabel="Xác nhận huỷ"
        cancelLabel="Đóng"
        busy={cancelBusy}
        error={cancelError}
        onConfirm={(result) => {
          setCancelBusy(true);
          setCancelError(null);
          void cancelOrder(
            supabase,
            record.id,
            result.option,
            result.note === '' ? null : result.note,
          )
            .then(refresh)
            .then(() => {
              setCancelOpen(false);
              toast({ title: 'Đã huỷ đơn.' });
            })
            // Bị chặn (chưa phải người được huỷ, đã có phiếu thu, tắt Bán hàng): hiện câu máy chủ trong hộp, không đóng.
            .catch((e: unknown) => setCancelError(errorOf(e).message))
            .finally(() => setCancelBusy(false));
        }}
      />
    </>
  );
}

function TotalRow({
  label,
  value,
  strong = false,
  muted = false,
}: {
  label: string;
  value: string;
  strong?: boolean;
  muted?: boolean;
}) {
  return (
    <div className="flex items-baseline justify-between gap-4">
      <dt className={muted ? 'text-fg-muted' : 'text-fg-label'}>{label}</dt>
      <dd className={`tabular ${strong ? 'font-semibold' : ''} ${muted ? 'text-fg-muted' : ''}`}>
        {value}
      </dd>
    </div>
  );
}

function Notice({
  tone = 'neutral',
  title,
  children,
}: {
  tone?: 'neutral' | 'danger' | 'warning';
  title?: string;
  children: React.ReactNode;
}) {
  const color =
    tone === 'danger'
      ? 'bg-danger-subtle text-on-danger-subtle'
      : tone === 'warning'
        ? 'bg-warning-subtle text-on-warning-subtle'
        : 'bg-surface-subtle text-fg';
  return (
    <p role="status" className={`rounded-control px-3 py-2 ${color}`}>
      {title && <b className="mr-1">{title}.</b>}
      {children}
    </p>
  );
}

/** Lý do của một sự kiện: tên lý do trong danh mục kèm ghi chú. */
function eventReason(
  e: OrderEvent,
  name: (catalog: string, code: string | null | undefined) => string | undefined,
): string {
  const catalog = e.event_code === 'HUY' ? 'ORDER_CANCEL_REASON' : 'REJECT_REASON';
  const reason = e.reason_code ? (name(catalog, e.reason_code) ?? e.reason_code) : '';
  return [reason, e.note].filter(Boolean).join(': ');
}
