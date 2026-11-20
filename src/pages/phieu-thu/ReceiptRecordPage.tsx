// TC-02 Phiếu thu (bản ghi, khuôn K06): thông tin phiếu (số tiền, hình thức, ngày nhận, mã giao dịch, người và nơi nhận tiền, chia vào dòng đơn),
// thanh tình trạng chỉ đọc, nút theo việc làm được (get_receipt.actions): Lưu (Nháp), Trình quản lý, Duyệt (quản lý, kế toán), Từ chối, Huỷ.
// Giao diện KHÔNG tính tiền, không tự đoán quyền: mọi con số, mọi việc cho phép do hàm DB trả; luật, công tắc Bán hàng máy chủ kiểm lại.
// Điện thoại chỉ đọc (Đ248). Chia tiền về dòng đơn chốt khi Kế toán duyệt (R-TIEN-22, 23): trước đó chỉ chọn "dòng cấn trước".
import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../../lib/auth/authContext';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { formatDate, formatDateTime, formatMoney, formatNumber } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Table } from '../../ui/Data';
import { ReassignApproverDialog } from '../../features/approver-reassign/ReassignApproverDialog';
import { useReassignState } from '../../features/approver-reassign/useReassign';
import { ConfirmDialog, ReasonDialog } from '../../ui/Dialogs';
import { Spinner, StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { Combobox, DateInput, MoneyInput, type ComboOption } from '../../ui/Inputs';
import { Select, Tabs, type MenuItem } from '../../ui/Overlays';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import type { FieldFormat } from '../../features/chatter/entries';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { useOrder } from '../don-hang/useOrderData';
import { approverLine, submitBlockOf } from '../don-hang/orderRecord';
import { receiptEventEntries } from './receiptEventEntries';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  draftOf,
  editedSinceRejection,
  inputOf,
  lastRejection,
  reasonText,
  receiptSteps,
  rejectedByAccountant,
  type ReceiptDraft,
} from './receiptRecord';
import type { ReceiptRecord } from './receiptTypes';
import {
  approveReceiptAccounting,
  approveReceiptManager,
  cancelReceipt,
  rejectReceipt,
  saveReceipt,
  submitReceipt,
  useReceipt,
  useReceiptExpectedApprover,
  useReceiverOptions,
  useRefreshReceipt,
} from './useReceiptData';

const toDate = (key: string): Date | null => {
  const [y, m, d] = key.split('-').map(Number);
  return y && m && d ? new Date(y, m - 1, d) : null;
};
const toKey = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; // allow-number: hai chữ số

export function ReceiptRecordPage() {
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
  return <ReceiptView key={query.data.id} record={query.data} />;
}

const RECEIPT_CHANGE_FORMAT = { labels: {} } satisfies FieldFormat;

function ReceiptView({ record }: { record: ReceiptRecord }) {
  const openFrom = useNavigateFrom();
  const supabase = useDb();
  const toast = useToast();
  const access = useAccess();
  const { claims } = useAuth();
  const catalogs = useLeadCatalogs();
  const phone = useMedia(NARROW_TABLE);
  const refresh = useRefreshReceipt(record.id, record.order?.id);
  // R-V2-44: Admin thấy «Chuyển người duyệt» khi phiếu chờ quản lý (route QUAN_LY) và máy chủ báo người đã chốt không duyệt được.
  const reassign = useReassignState(
    'PHIEU_THU',
    record.id,
    Boolean(claims?.roles.includes('ADMIN')) &&
      record.status_code === 'DA_GUI' &&
      record.approval_route === 'QUAN_LY',
  );
  const [tab, setTab] = useState('info');
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<ReceiptDraft>(() => draftOf(record));
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<string[]>([]);
  const [dialog, setDialog] = useState<'reject' | 'cancel' | 'resubmit' | 'reassign' | null>(null);
  const [dialogError, setDialogError] = useState<string | null>(null);
  useCrumbTail(record.code);

  const can = (a: ReceiptRecord['actions'][number]) => record.actions.includes(a) && !phone;
  const hasAction =
    can('gui') ||
    can('duyet_quan_ly') ||
    can('duyet_ke_toan') ||
    can('tu_choi') ||
    (reassign.data?.can === true && !phone);
  const waitingCaption = hasAction
    ? null
    : record.status_code === 'DA_GUI'
      ? `Chờ ${record.approval_route === 'TRUONG_CS' ? 'Trưởng cơ sở' : 'quản lý'} duyệt.`
      : record.status_code === 'CHO_KE_TOAN'
        ? 'Chờ Kế toán duyệt.'
        : null;
  // Dòng chặn trình (canvas TC02_nhap_xem_ql_khoa, _ql_thieu_quyen, _chua_ql; GHI_CHU mục 9): người duyệt dự kiến theo đúng hàm mà lúc Trình dùng.
  const expected = useReceiptExpectedApprover(
    record.id,
    record.status_code === 'NHAP' && !record.is_opening_debt && record.actions.includes('gui'),
  );
  const approverFields = {
    status_code: 'NHAP' as const,
    expected_route: expected.data?.expected_route ?? null,
    expected_approver_can_approve: expected.data?.expected_approver_can_approve ?? null,
    expected_approver_name: expected.data?.expected_approver_name ?? null,
    expected_block: expected.data?.expected_block ?? null,
    created_by_name: expected.data?.created_by_name ?? record.created_by_name,
  };
  const submitBlocked = expected.data !== undefined && submitBlockOf(approverFields) !== null;
  const approverText =
    expected.data === undefined || Object.keys(expected.data).length === 0
      ? null
      : approverLine(approverFields, (claims?.userId ?? '') === record.created_by, 'phiếu thu');
  const canEdit = can('sua');
  const statusName = (code: string) => catalogs.name('RECEIPT_STATUS', code) ?? code;
  const steps: StageStep[] = receiptSteps(record.status_code, record.is_opening_debt === true).map(
    (code) => ({
      code,
      label: statusName(code),
    }),
  );
  const isDraft = record.status_code === 'NHAP';
  const order = useOrder(
    record.order && (isDraft || tab === 'lines') ? record.order.id : undefined,
  );

  async function run(key: string, action: () => Promise<void>, message: string) {
    if (busy) return;
    setBusy(key);
    setError(null);
    try {
      await action();
      await refresh();
      toast({ title: message });
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(null);
    }
  }

  const save = () =>
    run(
      'save',
      async () => {
        const result = await saveReceipt(supabase, record.id, inputOf(draft));
        setWarnings(result.warnings);
        setEditing(false);
      },
      'Đã lưu phiếu thu.',
    );

  // Q-58 (R-TIEN-06): phiếu vừa bị từ chối mà chưa sửa gì thì hỏi lại trước khi trình (không chặn); đã sửa hoặc chưa từng bị từ chối thì trình thẳng.
  const rejection = lastRejection(record);
  const edited = editedSinceRejection(record);
  const submitNow = () =>
    run(
      'gui',
      async () => {
        await submitReceipt(supabase, record.id);
      },
      'Đã trình quản lý duyệt.',
    );
  function requestSubmit() {
    if (rejection && !edited) setDialog('resubmit');
    else void submitNow();
  }

  const menu: MenuItem[] = can('huy')
    ? [
        {
          kind: 'action',
          label: 'Huỷ phiếu thu',
          onSelect: () => {
            setDialogError(null);
            setDialog('cancel');
          },
        },
      ]
    : [];

  // «Duyệt bởi» (canvas TC02_duyet): chỉ phiếu Đã duyệt; lấy người và ngày của sự kiện Kế toán duyệt gần nhất.
  const accountantEvent =
    record.status_code === 'DA_DUYET'
      ? [...record.events].reverse().find((e) => e.event_code === 'DUYET_KT')
      : undefined;
  const approvedBy = accountantEvent
    ? `${accountantEvent.by_name ?? 'Hệ thống'} · ${formatDate(accountantEvent.at)}`
    : null;

  const lineLabel = (l: { line_no: number; student_name: string | null; package_name: string }) =>
    `Dòng ${l.line_no} · ${l.student_name ?? 'Chưa có học sinh'} · ${l.package_name}`;
  const lineOptions = [
    { value: '', label: '(để trống) chia tỉ lệ' },
    ...(order.data?.lines ?? []).map((l) => ({ value: l.id, label: lineLabel(l) })),
  ];
  const targetLine = (order.data?.lines ?? []).find((l) => l.id === record.target_line_id);
  const branchOptions = access.teachingBranches.map((b) => ({
    value: b.id,
    label: `${b.code} ${b.name}`,
  }));
  const methodOptions = catalogs.options('PAYMENT_METHOD');

  const info = (
    <div className="flex flex-col gap-6">
      <section className="flex min-w-0 flex-col">
        <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
          Khoản tiền
        </h3>
        <dl className="flex flex-col">
          <DetailField
            label="Số tiền"
            required
            mode={editing ? 'edit' : 'view'}
            value={<span className="tabular font-semibold">{formatMoney(record.amount)}</span>}
            editor={
              <MoneyInput
                label="Số tiền"
                value={draft.amount}
                onChange={(v) => setDraft({ ...draft, amount: v })}
                help="Đơn vị: đồng"
              />
            }
          />
          <DetailField
            label="Hình thức"
            required
            mode={editing ? 'edit' : 'view'}
            value={record.payment_method ?? record.payment_method_code}
            editor={
              <Select
                label="Hình thức"
                value={draft.paymentMethod}
                onChange={(v) => setDraft({ ...draft, paymentMethod: v })}
                options={methodOptions}
                className="w-full"
              />
            }
          />
          <DetailField
            label="Ngày nhận"
            required
            mode={editing ? 'edit' : 'view'}
            value={formatDate(record.paid_on)}
            editor={
              <DateInput
                label="Ngày nhận"
                value={toDate(draft.paidOn)}
                onChange={(d) => d && setDraft({ ...draft, paidOn: toKey(d) })}
                max={new Date()}
              />
            }
          />
          <DetailField
            label="Mã giao dịch"
            mode={editing ? 'edit' : 'view'}
            value={record.txn_ref ?? '—'}
            editor={
              <TextField
                label="Mã giao dịch"
                value={draft.txnRef}
                onChange={(e) => setDraft({ ...draft, txnRef: e.target.value })}
              />
            }
          />
        </dl>
      </section>
      <section className="flex min-w-0 flex-col">
        <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
          Người và nơi nhận tiền
        </h3>
        <dl className="flex flex-col">
          <DetailField
            label="Người nhận tiền"
            required
            hint="mặc định người lập"
            mode={editing ? 'edit' : 'view'}
            value={record.receiver_name ?? '—'}
            editor={
              <ReceiverPicker
                draft={draft}
                onPick={(id, name) => setDraft({ ...draft, receiverId: id, receiverName: name })}
              />
            }
          />
          <DetailField
            label="Cơ sở thu tiền"
            required
            hint="khác cơ sở của đơn chỉ nhắc nhẹ"
            mode={editing ? 'edit' : 'view'}
            value={record.collect_branch_code}
            editor={
              <Select
                label="Cơ sở thu tiền"
                value={draft.collectBranchId}
                onChange={(v) => setDraft({ ...draft, collectBranchId: v })}
                options={branchOptions}
                className="w-full"
              />
            }
          />
          {/* Canvas TC02_duyet: «Duyệt bởi» = Kế toán duyệt phiếu, kèm ngày (sự kiện DUYET_KT gần nhất). */}
          {approvedBy && <DetailField label="Duyệt bởi" mode="view" value={approvedBy} />}
        </dl>
      </section>
      <section className="flex min-w-0 flex-col">
        <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
          Phân bổ vào đơn
        </h3>
        <dl className="flex flex-col">
          <DetailField
            label="Chia tiền vào dòng đơn"
            hint="khoá khi phiếu rời Nháp"
            mode={editing ? 'edit' : 'view'}
            value={targetLine ? lineLabel(targetLine) : '(để trống) chia tỉ lệ'}
            editor={
              <Select
                label="Chia tiền vào dòng đơn"
                value={draft.targetLineId}
                onChange={(v) => setDraft({ ...draft, targetLineId: v })}
                options={lineOptions}
                className="w-full"
              />
            }
          />
          <DetailField
            label="Ghi chú"
            mode={editing ? 'edit' : 'view'}
            value={record.note ?? '—'}
            editor={
              <TextField
                label="Ghi chú"
                value={draft.note}
                onChange={(e) => setDraft({ ...draft, note: e.target.value })}
              />
            }
          />
        </dl>
        <p className="mt-1 text-caption text-fg-muted">
          Tiền vào dòng đã chọn trước, tối đa bằng thành tiền dòng; phần thừa chia tỉ lệ cho các
          dòng khác (R-TIEN-23). Giờ tặng chỉ cấp khi đơn thu đủ (R-TIEN-24).
        </p>
      </section>
    </div>
  );

  const allocations = (
    <div className="flex flex-col gap-3">
      {record.money_in ? (
        <>
          <p className="text-body">
            Khoản tiền vào <b>{record.money_in.code}</b>: {formatMoney(record.money_in.amount)},
            chia về các dòng đơn:
          </p>
          <Table
            caption="Chia về các dòng đơn"
            rows={record.money_in.allocations}
            rowKey={(a) => String(a.line_no)}
            rowLabel={(a) => `Dòng ${a.line_no}`}
            empty={null}
            columns={[
              { key: 'line', header: 'Dòng', cell: (a) => `Dòng ${a.line_no}` },
              {
                key: 'student',
                header: 'Học sinh',
                cell: (a) =>
                  (order.data?.lines ?? []).find((l) => l.line_no === a.line_no)?.student_name ??
                  '—',
              },
              { key: 'pkg', header: 'Sản phẩm', cell: (a) => a.package_name },
              {
                key: 'total',
                header: 'Thành tiền (đ)',
                cell: (a) => {
                  const line = (order.data?.lines ?? []).find((l) => l.line_no === a.line_no);
                  return (
                    <span className="tabular">{line ? formatNumber(line.line_total) : '—'}</span>
                  );
                },
              },
              {
                key: 'amt',
                header: 'Tiền chia về dòng (đ)',
                cell: (a) => <span className="tabular">{formatNumber(a.amount)}</span>,
              },
            ]}
          />
        </>
      ) : (
        <p className="text-fg-muted">
          {record.status_code === 'HUY'
            ? 'Phiếu đã huỷ, không chia tiền.'
            : 'Tiền chỉ được chia về các dòng đơn khi Kế toán duyệt phiếu.'}
        </p>
      )}
    </div>
  );

  const payment = record.payment;
  return (
    <>
      <RecordDetail
        kind="Phiếu thu"
        title={record.code}
        mode={editing ? 'edit' : 'view'}
        dirty={editing}
        saving={busy === 'save'}
        readOnly={!canEdit}
        showEdit={canEdit}
        menuWhileEditing
        onEdit={() => {
          setDraft(draftOf(record));
          setEditing(true);
        }}
        onSave={() => void save()}
        onCancel={() => {
          setEditing(false);
          setDraft(draftOf(record));
        }}
        headerActions={
          <Button icon="printer" onClick={() => openFrom(`/crm/phieu-thu/${record.id}/in`)}>
            In biên nhận
          </Button>
        }
        stageShowCode={false}
        stage={{ steps, current: record.status_code, forwardOnly: true, onSelect: () => undefined }}
        stageNote={
          record.is_opening_debt
            ? 'Nháp → Chờ kế toán → Đã duyệt (không qua quản lý). Stage chỉ đọc.'
            : 'Stage chỉ đọc, đổi bằng nút bên dưới.'
        }
        menu={menu.length > 0 ? { label: 'Hành động', items: menu } : undefined}
        businessActions={
          <span className="flex flex-wrap items-center gap-2">
            {can('gui') && (
              <Button
                variant={editing ? 'secondary' : 'primary'}
                loading={busy === 'gui'}
                disabled={editing || submitBlocked}
                onClick={requestSubmit}
              >
                {rejection
                  ? 'Trình lại'
                  : record.is_opening_debt
                    ? 'Gửi kế toán duyệt'
                    : 'Trình quản lý'}
              </Button>
            )}
            {can('gui') && !editing && approverText && (
              <span className="text-caption text-fg-label">{approverText}</span>
            )}
            {can('gui') && editing && (
              <span className="text-caption text-fg-label">
                Lưu hoặc Huỷ rồi mới trình quản lý.
              </span>
            )}
            {can('duyet_quan_ly') && (
              <Button
                variant="primary"
                loading={busy === 'ql'}
                onClick={() =>
                  void run(
                    'ql',
                    () => approveReceiptManager(supabase, record.id),
                    'Đã duyệt, chuyển Kế toán.',
                  )
                }
              >
                Duyệt (chuyển Kế toán)
              </Button>
            )}
            {can('duyet_ke_toan') && (
              <Button
                variant="primary"
                loading={busy === 'kt'}
                onClick={() =>
                  void run(
                    'kt',
                    async () => {
                      await approveReceiptAccounting(supabase, record.id);
                    },
                    'Đã duyệt phiếu thu, tiền đã ghi nhận.',
                  )
                }
              >
                Duyệt phiếu thu
              </Button>
            )}
            {reassign.data?.can && !phone && (
              <Button
                onClick={() => {
                  setDialogError(null);
                  setDialog('reassign');
                }}
              >
                Chuyển người duyệt
              </Button>
            )}
            {can('tu_choi') && (
              <Button
                onClick={() => {
                  setDialogError(null);
                  setDialog('reject');
                }}
              >
                Từ chối
              </Button>
            )}
            {/* Không có việc nào cho người đang xem (đang chờ người khác duyệt): ghi rõ chờ ai thay vì để thanh nút trống (T2-04). */}
            {waitingCaption && <span className="text-caption text-fg-label">{waitingCaption}</span>}
          </span>
        }
        smart={[
          {
            key: 'don',
            label: 'Đơn hàng',
            icon: 'file',
            count: record.order ? 1 : 0,
            unavailable: 'Phiếu thu nợ đầu kỳ không có đơn',
            onOpen: () => {
              if (record.order) openFrom(`/crm/don-hang/${record.order.id}`);
            },
          },
          {
            key: 'phu-huynh',
            label: 'Phụ huynh',
            icon: 'user',
            count: record.parent ? 1 : 0,
            unavailable: 'Có khi làm màn Khách hàng',
            onOpen: () => undefined,
          },
          {
            key: 'tien-vao',
            label: 'Khoản tiền vào',
            icon: 'payment',
            count: record.money_in ? 1 : 0,
            unavailable: 'Có khi làm màn Khoản tiền vào',
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
            entityType="RECEIPT"
            entityId={record.id}
            createdText="Tạo phiếu thu."
            // Mọi thay đổi của phiếu đã có mục riêng từ sự kiện (Q-52): nhật ký thay đổi không hiện trường nào để khỏi lặp.
            format={RECEIPT_CHANGE_FORMAT}
            events={receiptEventEntries(record.events)}
            canWrite
          />
        }
      >
        <div className="flex flex-col gap-4">
          <Banner record={record} />
          {error && (
            <Notice tone="danger" title="Chưa thực hiện được">
              {error}
            </Notice>
          )}
          {warnings.map((w) => (
            <Notice key={w} tone="warning">
              {w}
            </Notice>
          ))}
          <section className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
            <dl className="flex min-w-0 flex-col">
              <DetailField label="Phiếu thu" mode="view" value={record.code} />
              <DetailField
                label={record.order ? 'Đơn hàng' : 'Loại phiếu'}
                mode="view"
                value={
                  record.order ? (
                    <Link
                      className="font-medium text-link hover:underline"
                      to={`/crm/don-hang/${record.order.id}`}
                    >
                      {record.order.code}
                    </Link>
                  ) : (
                    'Thu nợ đầu kỳ · không có đơn'
                  )
                }
              />
              <DetailField
                label="Phụ huynh"
                mode="view"
                value={
                  record.parent
                    ? `${record.parent.name} · ${record.parent.code} · ${formatPhone(record.parent.phone)}`
                    : '—'
                }
              />
            </dl>
            <dl className="flex min-w-0 flex-col">
              <DetailField
                label="Tình trạng"
                mode="view"
                value={record.status ?? statusName(record.status_code)}
              />
              {/* Canvas TC02_huy: phiếu Huỷ hiện «Lý do huỷ» thành một dòng của khối thông tin (ngoài dải thông báo). */}
              {record.status_code === 'HUY' && (
                <DetailField
                  label="Lý do huỷ"
                  mode="view"
                  value={
                    [record.cancel_reason, record.cancel_note].filter(Boolean).join(': ') || '—'
                  }
                />
              )}
              <DetailField
                label="Người lập"
                mode="view"
                value={`${record.created_by_name ?? '—'} · ${formatDateTime(record.created_at)}`}
              />
              {'paid' in payment ? (
                <DetailField
                  label="Đơn đã thu"
                  mode="view"
                  value={`${formatMoney(payment.paid)} / ${formatMoney(payment.total)} · còn ${formatMoney(payment.remaining)} · ${payment.deposit_reached ? 'đã đủ cọc' : 'chưa đủ cọc'}`}
                />
              ) : (
                <>
                  <DetailField
                    label="Em"
                    mode="view"
                    value={record.opening_student ? record.opening_student.name : '—'}
                  />
                  <DetailField
                    label="Nợ đầu kỳ còn lại của phụ huynh"
                    mode="view"
                    value={formatMoney(payment.opening_debt_remaining)}
                  />
                </>
              )}
            </dl>
          </section>
          <Tabs
            label="Phiếu thu"
            value={tab}
            onChange={setTab}
            items={[
              { value: 'info', label: 'Thông tin phiếu', content: info },
              { value: 'lines', label: 'Chia về các dòng đơn', content: allocations },
            ]}
          />
        </div>
      </RecordDetail>
      {reassign.data?.can && (
        <ReassignApproverDialog
          open={dialog === 'reassign'}
          onOpenChange={(o) => !o && setDialog(null)}
          kind="PHIEU_THU"
          id={record.id}
          subject={`phiếu thu ${record.code}`}
          state={reassign.data}
          onDone={async () => {
            await refresh();
            toast({ title: 'Đã chuyển người duyệt.' });
          }}
        />
      )}
      <ReasonDialog
        open={dialog === 'reject'}
        onOpenChange={(o) => !o && setDialog(null)}
        title="Từ chối phiếu thu"
        description="Phiếu về Nháp để người lập sửa; Trình lại thì đi lại từ bước quản lý."
        options={catalogs.optionsFor('REJECT_REASON', 'PHIEU_THU').map((o) => ({
          value: o.value,
          label: o.label,
          needsNote: catalogs.requiresNote('REJECT_REASON', o.value),
        }))}
        reasonLabel="Lý do từ chối"
        noteLabel="Ghi chú"
        notePlaceholder="Nêu rõ cần sửa gì"
        confirmLabel="Từ chối"
        confirmIcon="close"
        cancelLabel="Không"
        busy={busy === 'reject'}
        error={dialogError}
        onConfirm={(r) => {
          const name = catalogs.name('REJECT_REASON', r.option) ?? r.option;
          setBusy('reject');
          setDialogError(null);
          rejectReceipt(supabase, record.id, reasonText(name, r.note))
            .then(async () => {
              setDialog(null);
              await refresh();
              toast({ title: 'Đã từ chối, phiếu về Nháp.' });
            })
            .catch((e: unknown) => setDialogError(errorOf(e).message))
            .finally(() => setBusy(null));
        }}
      />
      <ConfirmDialog
        open={dialog === 'resubmit'}
        onOpenChange={(o) => !o && setDialog(null)}
        title={`Trình lại phiếu thu ${record.code}`}
        description="Phiếu thu chưa sửa từ lần bị từ chối. Vẫn trình?"
        note={
          (rejection
            ? `Lần từ chối: ${formatDate(rejection.event.at)}, ${rejection.event.by_name ?? 'Hệ thống'}${rejectedByAccountant(record) ? ' (Kế toán)' : ''}${rejection.event.note ? `, lý do ${rejection.event.note}` : ''}. `
            : '') +
          'Không chặn: bấm Vẫn trình thì phiếu thu đi lại như bình thường, lịch sử ghi “Gửi lại, chưa sửa từ lần bị từ chối”.' +
          (rejectedByAccountant(record) ? ' Trình lại sẽ đi từ bước quản lý duyệt.' : '')
        }
        confirmLabel="Vẫn trình"
        cancelLabel="Quay lại sửa"
        onConfirm={() => {
          setDialog(null);
          void submitNow();
        }}
      />
      <ReasonDialog
        open={dialog === 'cancel'}
        onOpenChange={(o) => !o && setDialog(null)}
        title="Huỷ phiếu thu"
        description="Phiếu chưa duyệt mới huỷ được. Phiếu huỷ không chia tiền, chỉ còn xem."
        options={catalogs.options('RECEIPT_CANCEL_REASON').map((o) => ({
          value: o.value,
          label: o.label,
          needsNote: catalogs.requiresNote('RECEIPT_CANCEL_REASON', o.value),
        }))}
        reasonLabel="Lý do huỷ"
        noteLabel="Ghi chú"
        notePlaceholder="Ghi chú thêm"
        confirmLabel="Huỷ phiếu thu"
        confirmIcon="close"
        cancelLabel="Không huỷ"
        busy={busy === 'cancel'}
        error={dialogError}
        onConfirm={(r) => {
          setBusy('cancel');
          setDialogError(null);
          cancelReceipt(supabase, record.id, r.option, r.note.trim() === '' ? null : r.note.trim())
            .then(async () => {
              setDialog(null);
              await refresh();
              toast({ title: 'Đã huỷ phiếu thu.' });
            })
            .catch((e: unknown) => setDialogError(errorOf(e).message))
            .finally(() => setBusy(null));
        }}
      />
    </>
  );
}

function ReceiverPicker({
  draft,
  onPick,
}: {
  draft: ReceiptDraft;
  onPick: (id: string, name: string) => void;
}) {
  const [query, setQuery] = useState('');
  const q = useDebounced(query).trim();
  const search = useReceiverOptions(q, true);
  const options = useMemo<ComboOption[]>(() => {
    const list: ComboOption[] = (search.data ?? []).map((r) => ({
      value: r.id,
      label: r.name,
      hint: r.same_branch ? `${r.branch_code} · cùng cơ sở` : r.branch_code,
    }));
    if (draft.receiverId !== '' && !list.some((o) => o.value === draft.receiverId)) {
      list.unshift({ value: draft.receiverId, label: draft.receiverName || draft.receiverId });
    }
    return list;
  }, [search.data, draft.receiverId, draft.receiverName]);
  return (
    <Combobox
      label="Người nhận tiền"
      required
      help="Mặc định người lập; cùng cơ sở xếp đầu"
      options={options}
      value={draft.receiverId === '' ? [] : [draft.receiverId]}
      onChange={(v) => {
        const id = v[0] ?? '';
        onPick(id, options.find((o) => o.value === id)?.label ?? '');
      }}
      placeholder="Chọn người nhận tiền"
      loading={search.isFetching}
      onSearch={setQuery}
    />
  );
}

function Banner({ record }: { record: ReceiptRecord }) {
  if (record.status_code === 'DA_GUI')
    return (
      <Notice>
        Đã trình, chờ {record.approval_route === 'TRUONG_CS' ? 'Trưởng cơ sở' : 'quản lý'} duyệt.
        Trong lúc chờ không sửa được; còn Huỷ được khi phiếu chưa duyệt.
      </Notice>
    );
  if (record.status_code === 'CHO_KE_TOAN')
    return (
      <Notice>
        {record.is_opening_debt
          ? 'Đã gửi, chờ Kế toán duyệt (phiếu nợ đầu kỳ không qua quản lý).'
          : 'Quản lý đã duyệt, chờ Kế toán duyệt.'}{' '}
        Trong lúc chờ không sửa được; còn Huỷ được khi phiếu chưa duyệt.
      </Notice>
    );
  if (record.status_code === 'DA_DUYET')
    return (
      <Notice>
        Phiếu đã duyệt và khoá. Tiền đã ghi nhận
        {record.money_in ? ` (${record.money_in.code})` : ''}.
      </Notice>
    );
  if (record.status_code === 'HUY')
    return (
      <Notice>
        Phiếu đã huỷ{record.cancel_reason ? `: ${record.cancel_reason}` : ''}
        {record.cancel_note ? ` · ${record.cancel_note}` : ''}. Chỉ còn xem.
      </Notice>
    );
  return null;
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
