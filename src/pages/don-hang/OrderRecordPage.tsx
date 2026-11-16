// BH-05 Đơn hàng (bản ghi), phần XEM (UI-O2a): khuôn K06 nối get_order. Xem đơn ở mọi tình trạng: đầu bản ghi, thanh tình trạng, các nút
// theo khung, tab Dòng đơn (lưới K06c chỉ đọc), Thanh toán (lịch đóng tiền), Ghi danh (làm ở phân hệ sau), Ghi chú và hoạt động.
// UI-O2b: nút Trình duyệt (Nháp) và mục Huỷ đơn (R-TIEN-38, hộp K08 có lý do từ danh mục); Duyệt, Từ chối (UI-O2c) và sửa Nháp (UI-O3) có ở
// các PR sau. Giao diện KHÔNG tính tiền (R-TIEN-13): mọi con số do get_order trả. Đọc không bị chặn khi tắt Bán hàng (Đ181); Trình, Huỷ cần
// Bán hàng đang bật (Đ173), máy chủ kiểm lại. Điện thoại chỉ đọc (Đ248): ẩn Trình, Huỷ.
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import type { FieldFormat } from '../../features/chatter/entries';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { useAuth } from '../../lib/auth/authContext';
import { HmtError, errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate, formatMoney, formatNumber } from '../../lib/format';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Table, Tag, type TagTone } from '../../ui/Data';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { ConfirmDialog, ReasonDialog } from '../../ui/Dialogs';
import { Select, Tabs, type MenuItem } from '../../ui/Overlays';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { quantityText } from '../bao-gia/quoteRecord';
import { percentText } from '../bao-gia/quotePreview';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  approverLine,
  waitingApproverName,
  submitBlockOf,
  canCancelOrder,
  canSubmitOrder,
  editedSinceRejection,
  errorLineNumbers,
  lastRejection,
  orderSteps,
} from './orderRecord';
import type { OrderInstallment, OrderLine, OrderRecord } from './orderTypes';
import {
  cancelOrder,
  editOrder,
  submitOrder,
  useOrder,
  useOrderEditOptions,
  useRefreshOrder,
} from './useOrderData';
import { OrderEditLines } from './OrderEditLines';
import { PayLaterDialog } from './PayLaterDialog';
import { useOrderPayLater } from './usePayLater';
import { QuotePackageDialog } from '../bao-gia/QuotePackageDialog';
import { useOpportunityStudents } from '../bao-gia/useQuoteData';
import { orderEventEntries, reasonLine } from './orderEventEntries';
import {
  type AddedLine,
  type LineDraft,
  type OrderDraft,
  addedError,
  flexibleLimitError,
  allRemoved,
  buildEdits,
  draftOf,
  hasChanges,
  lineError,
} from './orderEdit';
import { ApproveOrderDialog, RejectOrderDialog } from './OrderApproveDialogs';
import {
  capPercentText,
  orderCapText,
  overCapLines,
  roundOne,
  totalPercentText,
} from './orderApprove';
import { CreateReceiptDialog } from '../phieu-thu/CreateReceiptDialog';
import { ChooseClassDialog, type ChooseClassTarget } from '../ghi-danh/ChooseClassDialog';
import { useOrderLineClasses } from '../ghi-danh/useEnrollmentData';
import { useOrderPayment, useReceiptPage } from '../phieu-thu/useReceiptData';

const ORDER_CHANGE_FORMAT = { labels: {} } satisfies FieldFormat;

const STATUS_TONE: Record<string, TagTone> = {
  NHAP: 'neutral',
  DA_TRINH: 'info',
  DA_DUYET: 'success',
  HUY: 'neutral',
};

/** Tên cột (get_order → nhật ký) hiện cho người dùng trong lịch sử thay đổi. */
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
  // BH-08: mã lớp và ngày vào lớp của từng dòng; hộp Chọn lớp mở từ bảng Sửa.
  const lineClassQuery = useOrderLineClasses(record.id);
  const lineClasses = Object.fromEntries((lineClassQuery.data ?? []).map((c) => [c.line_no, c]));
  const [classTarget, setClassTarget] = useState<ChooseClassTarget | null>(null);
  const phone = useMedia(NARROW_TABLE);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<{ message: string; retry: boolean } | null>(null);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [receiptOpen, setReceiptOpen] = useState(false);
  const [payLaterOpen, setPayLaterOpen] = useState(false);
  const [approveOpen, setApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [editing, setEditing] = useState(false);
  const [pickOpen, setPickOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);
  const [draft, setDraft] = useState<OrderDraft | null>(null);
  const [confirmUnedited, setConfirmUnedited] = useState(false);
  const editOptions = useOrderEditOptions(editing);
  const cap = useIntSetting('discount_total_cap_percent');
  const paymentQuery = useOrderPayment(record.status_code === 'DA_DUYET' ? record.id : undefined);
  const receiptsQuery = useReceiptPage({ order_id: record.id }, 'created_desc', 0, 1);
  const receiptCount = receiptsQuery.data?.total ?? 0;
  const onlyReceiptId = receiptCount === 1 ? (receiptsQuery.data?.rows[0]?.id ?? null) : null;
  const canCreateReceipt = access.can('RECEIPT', 'TAO') && access.featureOn('BAN_HANG') && !phone;
  // BH-09 (R-GD-12): quản lý cơ sở (Đơn hàng · Duyệt) bật hoặc tắt «cho học trước» trên đơn đã duyệt; bật chỉ khi chưa thu tiền. Máy chủ kiểm lại, cờ tham số tắt mặc định.
  const payLaterQuery = useOrderPayLater(record.status_code === 'DA_DUYET' ? record.id : undefined);
  const payLaterOn = payLaterQuery.data === true;
  const canPayLater =
    record.status_code === 'DA_DUYET' &&
    access.can('SALES_ORDER', 'DUYET') &&
    access.featureOn('BAN_HANG') &&
    !phone &&
    (payLaterOn || (paymentQuery.data !== undefined && paymentQuery.data.paid === 0));
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  useCrumbTail(record.code);

  const statusName = (code: string) => catalogs.name('ORDER_STATUS', code) ?? code;
  const modeName = (code: string) => catalogs.name('STUDY_MODE', code) ?? code;
  const branchName =
    access.teachingBranches.find((b) => b.code === record.branch_code)?.name ?? undefined;
  const rejection = lastRejection(record);
  // Q-77: MỘT dòng cạnh nút Trình thay cho hai khối cũ; bị chặn thì nút mờ.
  const approverText = approverLine(record, (claims?.userId ?? '') === record.created_by);
  const submitBlocked = submitBlockOf(record) !== null;
  // Dòng thời gian bên phải (Q-48, Q-51): sự kiện của đơn, mỗi lần lưu một mục.
  const eventEntries = orderEventEntries(record.events, catalogs.name);
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

  // Đơn Nháp sửa được khi người xem có quyền Sửa (can_submit cùng điều kiện quyền, trạng thái, công tắc), máy tính; điện thoại chỉ đọc (Đ248).
  const canEdit = record.status_code === 'NHAP' && record.can_submit && !phone;
  // Em của cơ hội để chọn cho dòng mới thêm khi sửa (Q-67); đơn không sinh từ cơ hội thì không thêm dòng được.
  const students = useOpportunityStudents(
    record.opportunity_id ?? '',
    editing && record.opportunity_id !== null,
  );
  const fixedPolicyIds = new Set(
    (editOptions.data?.policies ?? []).filter((p) => p.fixed_value).map((p) => p.id),
  );
  const initialTermId =
    (editOptions.data?.terms ?? []).find((t) => t.name === record.payment_term_name)?.id ?? '';
  const todayKey = vnDayBounds().dateKey; // Ngày hôm nay theo giờ Việt Nam (R-HT-07), không theo UTC hay múi giờ máy
  const edited = editedSinceRejection(record);

  function startEdit() {
    setEditError(null);
    setDraft(draftOf(record, initialTermId, fixedPolicyIds));
    setEditing(true);
    setTab('lines');
  }
  const patchLine = (lineNo: number, patch: Partial<LineDraft>) =>
    setDraft((prev) =>
      prev
        ? { ...prev, lines: { ...prev.lines, [lineNo]: { ...prev.lines[lineNo]!, ...patch } } }
        : prev,
    );
  const patchAdded = (key: string, patch: Partial<AddedLine>) =>
    setDraft((prev) =>
      prev
        ? { ...prev, added: prev.added.map((a) => (a.key === key ? { ...a, ...patch } : a)) }
        : prev,
    );
  const removeAdded = (key: string) =>
    setDraft((prev) => (prev ? { ...prev, added: prev.added.filter((a) => a.key !== key) } : prev));
  function addPackage(pkg: {
    id: string;
    code: string;
    name: string;
    package_type_code: string;
    prices: Record<string, number>;
  }) {
    const modes = Object.keys(pkg.prices);
    const only = students.data?.length === 1 ? (students.data[0]?.id ?? '') : '';
    setDraft((prev) =>
      prev
        ? {
            ...prev,
            added: [
              ...prev.added,
              {
                key: `new-${Date.now()}-${prev.added.length}`,
                studentId: only,
                packageId: pkg.id,
                packageCode: pkg.code,
                packageName: pkg.name,
                packageTypeCode: pkg.package_type_code,
                discounts: [],
                mode: modes[0] ?? '',
                modes,
                quantity: null,
              },
            ],
          }
        : prev,
    );
    setPickOpen(false);
  }
  // Vượt hạn mức Ưu đãi linh hoạt: nút Lưu mờ (Q-151), chữ đỏ ở chip của dòng.
  const limitBlocked =
    draft !== null &&
    (Object.values(draft.lines).some(
      (l) =>
        !l.removed && flexibleLimitError(l.discounts, editOptions.data?.policies ?? []) !== null,
    ) ||
      draft.added.some(
        (a) => flexibleLimitError(a.discounts, editOptions.data?.policies ?? []) !== null,
      ));
  const draftInvalid =
    draft !== null &&
    (Object.values(draft.lines).some((l) => lineError(l) !== null) ||
      draft.added.some((a) => addedError(a) !== null) ||
      limitBlocked ||
      allRemoved(draft));
  const dirty = draft !== null && hasChanges(record.lines, draft, initialTermId, fixedPolicyIds);

  async function saveEdit() {
    if (!draft || saving || draftInvalid) return;
    setSaving(true);
    setEditError(null);
    try {
      const edits = buildEdits(record.lines, draft, fixedPolicyIds);
      const termChanged = draft.termId !== initialTermId && draft.termId !== '';
      if (edits.length === 0 && !termChanged) {
        setEditing(false);
        return;
      }
      await editOrder(supabase, record.id, edits, termChanged ? draft.termId : null);
      await refresh();
      setEditing(false);
      setDraft(null);
      toast({ title: 'Đã lưu đơn.' });
    } catch (e) {
      // Lỗi nghiệp vụ (HMT_*) hiện thẳng câu tiếng Việt của máy chủ, giữ nguyên bản đang sửa.
      setEditError(errorOf(e).message);
    } finally {
      setSaving(false);
    }
  }

  // Q-29: đơn vừa bị từ chối mà chưa sửa gì thì hỏi lại trước khi trình; đã sửa hoặc chưa từng bị từ chối thì trình thẳng.
  function requestSubmit() {
    if (rejection && !edited) setConfirmUnedited(true);
    else void submit();
  }

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

  const lineColumns: LineColumn<OrderLine>[] = [
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
    {
      key: 'product',
      header: 'Sản phẩm',
      truncate: 'max-w-64',
      title: (l: OrderLine) => l.package_name,
      cell: (l: OrderLine) => l.package_name,
    },
    {
      key: 'mode',
      header: 'Hình thức',
      cell: (l: OrderLine) => (l.line_kind === 'GIFT' ? '—' : modeName(l.delivery_mode_code)),
    },
    // Mã lớp, Ngày vào lớp (BH-08): do hộp Chọn lớp ghi vào dòng đơn Nháp; chưa chọn thì "—" (ghi danh sẽ Chờ xếp lớp).
    {
      key: 'class',
      header: 'Mã lớp',
      cell: (l: OrderLine) =>
        lineClasses[l.line_no]?.class_code ?? <span className="text-fg-muted">—</span>,
    },
    {
      key: 'start',
      header: 'Ngày vào lớp',
      cell: (l: OrderLine) =>
        lineClasses[l.line_no] ? (
          formatDate(lineClasses[l.line_no]?.enrol_start_date)
        ) : (
          <span className="text-fg-muted">—</span>
        ),
    },
    {
      key: 'quantity',
      align: 'right',
      header: 'Số lượng',
      cell: (l: OrderLine) => <span className="tabular">{quantityText(l)}</span>,
    },
    {
      key: 'price',
      align: 'right',
      header: 'Đơn giá',
      cell: (l: OrderLine) => <span className="tabular">{formatNumber(l.unit_price)}</span>,
    },
    {
      key: 'discount-type',
      header: 'Chiết khấu',
      // Chip một hàng (canvas BH05 xem): tên chính sách kèm mức đã áp; quà tặng ghi tên chính sách quà.
      cell: (l: OrderLine) => {
        const chips =
          l.line_kind === 'GIFT'
            ? [l.gift_policy_name ?? 'Quà tặng']
            : l.discounts.map((d) =>
                d.kind === 'GIFT_HOURS'
                  ? // Khung BH05_nhap_xem: chip giờ tặng ghi số giờ và % quy ra (máy chủ trả gift_percent): "Tên (2 giờ) 8,3%".
                    `${d.policy_name} (${percentText(d.applied_value)} giờ) ${percentText(roundOne(l.gift_percent))}%`
                  : `${d.policy_name} ${percentText(d.applied_value)}%`,
              );
        return chips.length === 0 ? (
          '—'
        ) : (
          <span className="flex items-center gap-1.5 whitespace-nowrap">
            {chips.map((c) => (
              <span key={c} className="rounded-tag bg-surface-subtle px-2 py-0.5 text-caption">
                {c}
              </span>
            ))}
          </span>
        );
      },
    },
    {
      key: 'discount',
      align: 'right',
      header: 'Tổng %',
      cell: (l: OrderLine) => {
        const text = totalPercentText(l);
        return text === '' ? '—' : text;
      },
    },
    {
      key: 'reduction',
      align: 'right',
      header: 'Giảm',
      cell: (l: OrderLine) => <span className="tabular">{formatNumber(l.discount_amount)}</span>,
    },
    {
      key: 'total',
      align: 'right',
      header: 'Thành tiền',
      cell: (l: OrderLine) => <span className="tabular">{formatNumber(l.line_total)}</span>,
    },
  ];

  const modeOptions = catalogs.options('STUDY_MODE');
  // Khung BH05_chip_vuot_tran, BH05_nhap_xem (Q-163): câu trần luôn hiện dưới bảng dòng ở cả Xem và Sửa; hộp vàng chỉ khi bản ĐÃ LƯU vượt trần
  // (Tổng % chỉ cập nhật khi Lưu, Q-157). N đọc từ tham số discount_total_cap_percent.
  const capNote = record.lines.some((l) => l.over_cap) ? (
    <Alert tone="warning">{orderCapText(cap)}</Alert>
  ) : (
    <p className="text-caption text-fg-muted">{orderCapText(cap)}</p>
  );
  const lines = (
    <div className="flex flex-col gap-3">
      {editing && draft && (
        <>
          {editError && (
            <Notice tone="danger" title="Chưa lưu được">
              {editError}
            </Notice>
          )}
          {record.quotation_code && (
            <Notice tone="warning">
              Đơn chuyển từ báo giá {record.quotation_code}: sửa số giờ, hình thức, chiết khấu, bỏ
              dòng, thêm dòng được. Lưu thì nhật ký ghi “Đơn đã sửa so với báo giá” kèm giá trị cũ,
              mới. Giá niêm yết giữ theo ngày của báo giá.
            </Notice>
          )}
          <OrderEditLines
            lines={record.lines}
            draft={draft}
            onChange={patchLine}
            policies={editOptions.data?.policies ?? []}
            modes={modeOptions}
            branchId={record.branch_id}
            today={todayKey}
            stale={dirty}
            students={students.data ?? []}
            onAdd={() => setPickOpen(true)}
            onChangeAdded={patchAdded}
            onRemoveAdded={removeAdded}
            lineClasses={lineClasses}
            onPickClass={(l) =>
              setClassTarget({
                orderId: record.id,
                lineNo: l.line_no,
                packageId: l.package_id,
                packageName: l.package_name,
                studentName: l.student_name ?? null,
                branchId: record.branch_id,
                current: lineClasses[l.line_no]
                  ? {
                      classId: lineClasses[l.line_no]?.class_id ?? '',
                      date: lineClasses[l.line_no]?.enrol_start_date ?? '',
                    }
                  : null,
              })
            }
          />
          {capNote}
        </>
      )}
      {!(editing && draft) && (
        <LineTable<OrderLine>
          caption="Dòng đơn"
          scrollFocusable
          rows={record.lines}
          rowKey={(l) => l.id}
          columns={lineColumns}
          empty={<p className="px-4 py-6 text-center text-fg-muted">Đơn chưa có dòng nào.</p>}
        />
      )}
      {!(editing && draft) && capNote}
      <dl
        className={`ml-auto flex w-full max-w-sm flex-col gap-1 text-body ${editing && dirty ? 'opacity-50' : ''}`}
      >
        <TotalRow label="Tổng niêm yết" value={formatMoney(record.gross_total)} />
        <TotalRow
          label="Tổng chiết khấu"
          value={record.discount_total > 0 ? `− ${formatMoney(record.discount_total)}` : '0 đ'}
        />
        <TotalRow label="Thành tiền" value={formatMoney(record.total_amount)} strong />
        {/* Đ269: chưa có phiếu thu nên Đã thu, Còn phải thu hiện "—", không hiện 0. */}
        <TotalRow
          label="Đã thu"
          value={receiptCount > 0 && paymentQuery.data ? formatMoney(paymentQuery.data.paid) : '—'}
          muted={receiptCount === 0}
        />
        <TotalRow
          label="Còn phải thu"
          value={
            receiptCount > 0 && paymentQuery.data ? formatMoney(paymentQuery.data.remaining) : '—'
          }
          muted={receiptCount === 0}
        />
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
        <p className="text-fg-muted">
          {receiptCount === 0
            ? 'Chưa có phiếu thu.'
            : `Có ${receiptCount} phiếu thu. Bấm nút Phiếu thu ở đầu trang để xem.`}
        </p>
      </section>
    </div>
  );

  return (
    <>
      <RecordDetail
        kind="Đơn hàng"
        title={record.code}
        mode={editing ? 'edit' : 'view'}
        dirty={editing && dirty}
        saving={saving}
        saveDisabled={limitBlocked}
        onEdit={startEdit}
        onSave={() => void saveEdit()}
        onCancel={() => {
          setEditing(false);
          setDraft(null);
          setEditError(null);
        }}
        readOnly
        showEdit={canEdit}
        editLabel="Sửa đơn"
        menuWhileEditing
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
                {/* Q-49 (canvas BH05_nhap_xem, BH05_nhap_sua): Sửa đơn, Lưu, Huỷ, Hành động ở thanh tiêu đề; hàng này chỉ có nút chuyển giai đoạn.
                    Đang sửa: nút khoá, ghi "Lưu hoặc Huỷ rồi mới trình duyệt". Đơn đã bị từ chối: nút đổi chữ thành "Trình lại". */}
                {canSubmit && (
                  <Button
                    variant={editing ? 'secondary' : 'primary'}
                    loading={submitting}
                    disabled={editing}
                    // Q-77: bị chặn thì nút mờ (aria-disabled) nhưng vẫn bấm được để máy chủ nêu lý do bằng câu tiếng Việt; dòng bên cạnh đã nói trước.
                    aria-disabled={submitBlocked || undefined}
                    className={submitBlocked ? 'opacity-55' : undefined}
                    onClick={requestSubmit}
                  >
                    {rejection ? 'Trình lại' : 'Trình duyệt'}
                  </Button>
                )}
                {editing && canSubmit && (
                  <span className="text-caption text-fg-label">
                    Lưu hoặc Huỷ rồi mới trình duyệt.
                  </span>
                )}
                {!editing && rejection && canSubmit && (
                  <span className="text-caption text-fg-label">
                    Nhánh khác: Từ chối · bị từ chối thì về Nháp, sửa rồi trình lại
                  </span>
                )}
                {approverText && <span className="text-caption text-fg-label">{approverText}</span>}
              </span>
            )}
            {record.status_code === 'DA_TRINH' && (record.can_approve || record.can_reject) && (
              <span className="flex flex-wrap items-center gap-2">
                {record.can_approve && (
                  <Button variant="primary" onClick={() => setApproveOpen(true)}>
                    Duyệt
                  </Button>
                )}
                {record.can_reject && <Button onClick={() => setRejectOpen(true)}>Từ chối</Button>}
              </span>
            )}
            {record.status_code === 'DA_DUYET' && canCreateReceipt && (
              <Button variant="primary" onClick={() => setReceiptOpen(true)}>
                Tạo phiếu thu
              </Button>
            )}
            {canPayLater && (
              <Button onClick={() => setPayLaterOpen(true)}>
                {payLaterOn ? 'Tắt cho học trước' : 'Cho học trước'}
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
            count: receiptCount,
            onOpen: () =>
              openFrom(onlyReceiptId ? `/crm/phieu-thu/${onlyReceiptId}` : '/crm/phieu-thu'),
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
            // Mọi thay đổi quan trọng của đơn (tình trạng, tổng tiền, điều khoản, lý do huỷ) đã có mục riêng từ sự kiện (Q-51): nhật ký thay đổi
            // không hiện trường nào nữa để khỏi lặp.
            format={ORDER_CHANGE_FORMAT}
            events={eventEntries}
            canWrite
          />
        }
      >
        <div className="flex flex-col gap-6">
          {record.status_code === 'DA_TRINH' && overCapLines(record.lines).length > 0 && (
            <Notice tone="warning" title={`Chiết khấu vượt trần ${capPercentText(cap)}`}>
              {overCapLines(record.lines)
                .map((l) => `Dòng ${l.line_no}: ${l.total_percent_text}%`)
                .join('; ')}
              . Chỉ cảnh báo, không chặn: người duyệt xem xét rồi Duyệt hoặc Từ chối.
            </Notice>
          )}
          {record.status_code === 'DA_TRINH' && (
            <Notice>
              Đơn đã trình, chờ {waitingApproverName(record) ?? 'người duyệt'} duyệt. Trong lúc chờ
              không sửa được dòng.
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
                      : (waitingApproverName(record) ?? '')
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
                  mode={editing ? 'edit' : 'view'}
                  value={record.payment_term_name ?? 'Thanh toán một lần'}
                  editor={
                    <Select
                      label="Kiểu thanh toán"
                      value={draft?.termId ?? ''}
                      placeholder="Chọn điều khoản"
                      onChange={(v) => setDraft((prev) => (prev ? { ...prev, termId: v } : prev))}
                      options={(editOptions.data?.terms ?? []).map((t) => ({
                        value: t.id,
                        label: t.name,
                      }))}
                      className="w-full"
                    />
                  }
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
        </div>
      </RecordDetail>
      <ChooseClassDialog
        target={classTarget}
        onClose={() => setClassTarget(null)}
        onSaved={() => {
          void lineClassQuery.refetch();
          void refresh();
        }}
      />
      <ConfirmDialog
        open={confirmUnedited}
        onOpenChange={setConfirmUnedited}
        title={`Trình lại đơn ${record.code}`}
        description="Đơn chưa sửa từ lần bị từ chối. Vẫn trình?"
        note={
          (rejection
            ? `Lần từ chối: ${formatDate(rejection.created_at)}, ${rejection.actor_name ?? 'Hệ thống'}, “${reasonLine(rejection, catalogs.name)}”. `
            : '') +
          'Không chặn: bấm Vẫn trình thì đơn đi lại như bình thường, lịch sử ghi “Trình lại, chưa sửa từ lần bị từ chối”.'
        }
        confirmLabel="Vẫn trình"
        cancelLabel="Quay lại sửa"
        onConfirm={() => {
          setConfirmUnedited(false);
          void submit();
        }}
      />
      {record.opportunity_id && (
        <QuotePackageDialog
          open={pickOpen}
          onOpenChange={setPickOpen}
          opportunityId={record.opportunity_id}
          onPick={addPackage}
        />
      )}
      <ApproveOrderDialog
        record={record}
        open={approveOpen}
        onOpenChange={setApproveOpen}
        onReject={() => {
          setApproveOpen(false);
          setRejectOpen(true);
        }}
        onDone={(message) => {
          void refresh();
          toast({ title: message });
        }}
      />
      <RejectOrderDialog
        record={record}
        open={rejectOpen}
        onOpenChange={setRejectOpen}
        onDone={(message) => {
          void refresh();
          toast({ title: message });
        }}
      />
      <PayLaterDialog
        open={payLaterOpen}
        onOpenChange={setPayLaterOpen}
        orderId={record.id}
        orderCode={record.code}
        enabled={payLaterOn}
        onDone={() => void refresh()}
      />
      <CreateReceiptDialog
        open={receiptOpen}
        onOpenChange={setReceiptOpen}
        orderId={record.id}
        orderCode={record.code}
        receivable={paymentQuery.data?.receivable ?? null}
      />
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
