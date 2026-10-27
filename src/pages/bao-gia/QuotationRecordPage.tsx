// BH-02 Báo giá (bản ghi), phần CHỈ ĐỌC: khuôn K06 nối get_quotation. Xem báo giá ở mọi tình trạng (Nháp, Đã gửi, Từ chối, Huỷ):
// đầu bản ghi, bảng dòng gói, tổng tiền, Ghi chú và hoạt động. Phần sửa Nháp (lưới dòng chỉnh sửa, hộp chọn gói) chờ Design vẽ khuôn
// (QĐ-Đ227); nút Gửi, Từ chối (hộp BH-04) có ở đây; Huỷ báo giá chưa có nút trong canvas nên chưa dựng. Giao diện KHÔNG tính tiền: mọi con số do get_quotation trả.
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate, formatDateTime, formatMoney, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Table, Tag, type TagTone } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { ConfirmDialog, ReasonDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import type { MenuItem } from '../../ui/Overlays';
import type { StageStep } from '../../ui/Stage';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { useToast } from '../../ui/toastContext';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { QuoteLineGrid } from './QuoteLineGrid';
import {
  buildSaveLines,
  rowsFromRecord,
  rowsSignature,
  validateRows,
  type EditRow,
  type RowIssue,
} from './quoteEdit';
import { discountText, quantityText, statusSteps } from './quoteRecord';
import type { QuotationLine, QuotationRecord } from './quoteTypes';
import {
  cancelQuotation,
  rejectQuotation,
  saveQuotation,
  sendQuotation,
  useOpportunityStudents,
  useQuotation,
  useRefreshQuotation,
} from './useQuoteData';

const STATUS_TONE: Record<string, TagTone> = {
  NHAP: 'neutral',
  DA_GUI: 'info',
  DA_CHUYEN_DON: 'success',
  TU_CHOI: 'danger',
  HUY: 'neutral',
};

const ORDER_TONE: Record<string, TagTone> = {
  NHAP: 'neutral',
  DA_TRINH: 'info',
  DA_DUYET: 'success',
  HUY: 'neutral',
};

/** Tên cột (get_quotation → nhật ký) hiện cho người dùng trong lịch sử thay đổi. */
const QUOTE_FIELD_LABELS: Record<string, string> = {
  status_code: 'Tình trạng',
  total_amount: 'Tổng tiền',
  valid_until: 'Hạn hiệu lực',
  reject_reason_code: 'Lý do từ chối',
  reject_note: 'Ghi chú từ chối',
  cancel_note: 'Ghi chú huỷ',
};

export function QuotationRecordPage() {
  const { id } = useParams<{ id: string }>();
  const query = useQuotation(id);
  if (query.isPending) return <Spinner label="Đang tải báo giá…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem báo giá này'
            : missing
              ? 'Không tìm thấy báo giá'
              : 'Không tải được báo giá'
        }
        actions={
          <>
            <Link to="/crm/bao-gia" className="font-medium text-link hover:underline">
              Về danh sách Báo giá
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
  return <QuotationView key={query.data.id} record={query.data} />;
}

function QuotationView({ record }: { record: QuotationRecord }) {
  const navigate = useNavigate();
  const openFrom = useNavigateFrom();
  const access = useAccess();
  const catalogs = useLeadCatalogs();
  const capPercent = useIntSetting('discount_total_cap_percent');
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshQuotation(record.id);
  const [busy, setBusy] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [rejectBusy, setRejectBusy] = useState(false);
  const [rejectError, setRejectError] = useState<string | null>(null);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [cancelNote, setCancelNote] = useState('');
  // Sửa Nháp (K06c): lưới dòng sửa tại chỗ. Điện thoại giữ bản chỉ đọc, ẩn nút Sửa (Đ248) cho tới khi Design vẽ lưới điện thoại.
  const phone = useMedia(NARROW_TABLE);
  const [editing, setEditing] = useState(false);
  const [rows, setRows] = useState<EditRow[]>([]);
  const [baseline, setBaseline] = useState('');
  const [saving, setSaving] = useState(false);
  const [issues, setIssues] = useState<RowIssue[]>([]);
  const [saveError, setSaveError] = useState<string | null>(null);
  const students = useOpportunityStudents(record.opportunity_id, editing);
  useCrumbTail(record.code);

  // Nút theo tình trạng; quyền Sửa và công tắc Bán hàng kiểm ở đây, máy chủ kiểm lại (Đ173).
  const canChange = access.can('QUOTATION', 'SUA') && access.featureOn('BAN_HANG');
  const canSend = canChange && record.status_code === 'NHAP';
  const canReject =
    canChange && record.status_code === 'DA_GUI' && record.display_status_code !== 'DA_CHUYEN_DON';

  // Huỷ báo giá (Đ239): chỉ Nháp, Đã gửi, Từ chối; không có quyền Sửa hoặc tắt Bán hàng thì ẩn mục, các mục khác giữ.
  const canCancel = canChange && ['NHAP', 'DA_GUI', 'TU_CHOI'].includes(record.status_code);
  const menuItems: MenuItem[] = [
    { kind: 'action', label: 'In', onSelect: () => undefined, unavailable: 'Có khi làm BH-03' },
    ...(canCancel
      ? [
          {
            kind: 'action' as const,
            label: 'Huỷ báo giá',
            onSelect: () => {
              setCancelError(null);
              setCancelNote('');
              setCancelOpen(true);
            },
          },
        ]
      : []),
  ];

  const canEditDraft = canChange && record.status_code === 'NHAP' && !phone;
  const dirty = editing && rowsSignature(rows) !== baseline;

  function startEdit() {
    const initial = rowsFromRecord(record);
    setRows(initial);
    setBaseline(rowsSignature(initial));
    setIssues([]);
    setSaveError(null);
    setEditing(true);
  }

  function stopEdit() {
    setEditing(false);
    setIssues([]);
    setSaveError(null);
  }

  async function save() {
    if (saving) return;
    const found = validateRows(rows);
    setIssues(found);
    setSaveError(null);
    if (found.length > 0) return;
    setSaving(true);
    try {
      await saveQuotation(supabase, record.id, record.opportunity_id, buildSaveLines(rows));
      await refresh();
      stopEdit();
      toast({ title: 'Đã lưu báo giá.' });
    } catch (e) {
      setSaveError(errorOf(e).message);
    } finally {
      setSaving(false);
    }
  }

  async function send() {
    if (busy) return;
    setBusy(true);
    try {
      const result = await sendQuotation(supabase, record.id);
      await refresh();
      const warning = result.warnings[0];
      toast(
        warning
          ? { tone: 'warning', title: `Đã gửi báo giá. ${warning.message}` }
          : { title: 'Đã gửi báo giá.' },
      );
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setBusy(false);
    }
  }

  const statusName = (code: string) => catalogs.name('QUOTATION_STATUS', code) ?? code;
  const modeName = (code: string) => catalogs.name('STUDY_MODE', code) ?? code;
  const branchName =
    access.teachingBranches.find((b) => b.code === record.branch_code)?.name ?? undefined;
  const steps: StageStep[] = statusSteps(record).map((code) => ({
    code,
    label: statusName(code),
  }));
  const current = record.status_code === 'DA_GUI' ? record.display_status_code : record.status_code;

  const lines = (
    <div className="flex flex-col gap-2">
      <Table<QuotationLine>
        caption="Gói học"
        rows={record.lines}
        rowKey={(l) => l.id}
        rowLabel={(l) => `Dòng ${l.line_no}`}
        columns={[
          {
            key: 'student',
            header: 'Học sinh',
            cell: (l) =>
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
                </span>
              ) : (
                <span className="text-fg-muted">Chưa có học sinh</span>
              ),
          },
          { key: 'product', header: 'Sản phẩm', cell: (l) => l.package_name },
          {
            key: 'mode',
            header: 'Hình thức',
            cell: (l) => (l.line_kind === 'GIFT' ? '—' : modeName(l.delivery_mode_code)),
          },
          {
            key: 'quantity',
            header: 'Số lượng',
            cell: (l) => <span className="tabular">{quantityText(l)}</span>,
          },
          {
            key: 'price',
            header: 'Đơn giá',
            cell: (l) => <span className="tabular">{formatNumber(l.unit_price)}</span>,
          },
          {
            key: 'discount',
            header: 'Chiết khấu',
            cell: (l) => {
              const text = discountText(l);
              return text === '' ? '—' : text;
            },
          },
          {
            key: 'reduction',
            header: 'Giảm',
            cell: (l) => <span className="tabular">{formatNumber(l.discount_amount)}</span>,
          },
          {
            key: 'total',
            header: 'Thành tiền',
            cell: (l) => <span className="tabular">{formatNumber(l.line_total)}</span>,
          },
          // Đ242: mã và trạng thái đơn đang sống của dòng, cho mọi người có quyền Xem báo giá. Nút mở đơn chờ màn Đơn hàng (BH-05).
          {
            key: 'order',
            header: 'Đơn',
            cell: (l) =>
              l.order_code ? (
                <span className="flex flex-wrap items-center gap-1.5">
                  <span className="font-medium">{l.order_code}</span>
                  <Tag tone={ORDER_TONE[l.order_status_code ?? ''] ?? 'neutral'}>
                    {catalogs.name('ORDER_STATUS', l.order_status_code) ?? l.order_status_code}
                  </Tag>
                </span>
              ) : (
                '—'
              ),
          },
        ]}
        empty={<p className="px-4 py-6 text-center text-fg-muted">Chưa có gói học.</p>}
      />
      <div className="flex flex-wrap items-center justify-between gap-2 text-caption text-fg-muted">
        {capPercent !== null ? (
          <p>
            Chiết khấu (gồm giờ tặng) vượt {capPercent}% thì cần Trưởng cơ sở duyệt (R-TIEN-29); vẫn
            lưu được
          </p>
        ) : (
          <span />
        )}
        <p className="text-body text-fg">
          Tổng thành tiền <b className="tabular">{formatMoney(record.total_amount)}</b>
        </p>
      </div>
      <p className="text-caption text-fg-muted">
        Toán khối 7 trở lên: Đại số và Hình học là hai dòng riêng. Mỗi dòng một học sinh.
      </p>
    </div>
  );

  return (
    <>
      <RecordDetail
        kind="Báo giá"
        title={record.code}
        mode={editing ? 'edit' : 'view'}
        dirty={dirty}
        saving={saving}
        onEdit={startEdit}
        onSave={() => void save()}
        onCancel={stopEdit}
        readOnly={!canEditDraft}
        stageShowCode={false}
        stage={{ steps, current, forwardOnly: true, onSelect: () => undefined }}
        menu={{ label: 'Hành động', items: menuItems }}
        stageNote="Stage chỉ đọc, đổi bằng nút bên dưới."
        businessActions={
          <>
            {!editing && canSend && (
              <Button variant="primary" loading={busy} onClick={() => void send()}>
                Gửi
              </Button>
            )}
            {!editing && canReject && (
              <Button
                disabled={busy}
                onClick={() => {
                  setRejectError(null);
                  setRejectOpen(true);
                }}
              >
                Từ chối
              </Button>
            )}
          </>
        }
        smart={[
          {
            key: 'co-hoi',
            label: 'Cơ hội',
            icon: 'recruit',
            count: 1,
            onOpen: () => openFrom(`/crm/co-hoi/${record.opportunity_id}`),
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
            key: 'don-hang',
            label: 'Đơn hàng',
            icon: 'file',
            count: 0,
            unavailable: 'Có khi làm màn Đơn hàng',
            onOpen: () => undefined,
          },
        ]}
        aside={
          <RecordChatter
            entityType="QUOTATION"
            entityId={record.id}
            createdText="Tạo báo giá."
            format={{
              labels: QUOTE_FIELD_LABELS,
              value: (column, value) => {
                if (column === 'total_amount' && typeof value === 'number')
                  return formatMoney(value);
                if (column === 'status_code' && typeof value === 'string') return statusName(value);
                if (column === 'reject_reason_code' && typeof value === 'string')
                  return catalogs.name('REJECT_REASON', value) ?? value;
                if (column === 'valid_until' && typeof value === 'string') return formatDate(value);
                return null;
              },
            }}
            canWrite
          />
        }
      >
        <div className="flex flex-col gap-6">
          {record.status_code === 'DA_GUI' && (
            <p className="rounded-control bg-surface-subtle px-3 py-2 text-fg-muted">
              Đã gửi cho phụ huynh ngày {formatDate(record.sent_at)}. Quá hạn hiệu lực chỉ hiện nhãn
              “Đã quá hạn N ngày” cạnh ngày hạn; tình trạng vẫn là Đã gửi và vẫn chuyển thành đơn
              được.
            </p>
          )}
          {record.status_code === 'TU_CHOI' && (
            <p className="rounded-control bg-surface-subtle px-3 py-2">
              <b>Lý do từ chối</b>{' '}
              {[record.reject_reason, record.reject_note].filter(Boolean).join(': ') || '—'}
            </p>
          )}
          {record.status_code === 'HUY' && (
            <p className="rounded-control bg-surface-subtle px-3 py-2 text-fg-muted">
              Báo giá đã huỷ{record.cancel_note ? `: ${record.cancel_note}` : '.'}
            </p>
          )}
          <section className="flex min-w-0 flex-col">
            <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
              Thông tin báo giá
            </h3>
            <div className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
              <dl className="flex min-w-0 flex-col">
                <DetailField
                  label="Mã báo giá"
                  hint="cấp khi Lưu, không sửa"
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
                <DetailField
                  label="Cơ sở"
                  mode="view"
                  value={branchName ? `${record.branch_code} ${branchName}` : record.branch_code}
                />
              </dl>
              <dl className="flex min-w-0 flex-col">
                <DetailField
                  label="Tình trạng"
                  mode="view"
                  value={
                    <Tag tone={STATUS_TONE[record.display_status_code] ?? 'neutral'} dot>
                      {statusName(record.display_status_code)}
                    </Tag>
                  }
                />
                <DetailField label="Ngày lập" mode="view" value={formatDate(record.created_at)} />
                <DetailField
                  label="Hạn hiệu lực"
                  mode="view"
                  value={
                    record.valid_until ? (
                      <span className="flex flex-wrap items-center gap-2">
                        {formatDate(record.valid_until)}
                        {record.overdue_days !== null && record.overdue_days > 0 && (
                          <Tag tone="danger">{`Đã quá hạn ${record.overdue_days} ngày`}</Tag>
                        )}
                      </span>
                    ) : (
                      ''
                    )
                  }
                />
                <DetailField label="Người lập" mode="view" value={record.created_by_name ?? ''} />
                {record.sent_at && (
                  <DetailField
                    label="Đã gửi lúc"
                    mode="view"
                    value={`${formatDateTime(record.sent_at)}${record.sent_by_name ? ` · ${record.sent_by_name}` : ''}`}
                  />
                )}
              </dl>
            </div>
          </section>
          <section className="flex min-w-0 flex-col">
            <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
              Gói học
            </h3>
            {editing ? (
              <div className="flex flex-col gap-2">
                {(issues.length > 0 || saveError !== null) && (
                  <Alert tone="danger" title="Chưa lưu được.">
                    {saveError ?? (
                      <ul>
                        {issues.map((i) => (
                          <li key={i.rowKey}>{i.summary}</li>
                        ))}
                      </ul>
                    )}
                  </Alert>
                )}
                {students.isError && <Alert tone="danger">{errorOf(students.error).message}</Alert>}
                <QuoteLineGrid
                  rows={rows}
                  onChange={setRows}
                  students={students.data ?? []}
                  opportunityId={record.opportunity_id}
                  opportunityHref={`/crm/co-hoi/${record.opportunity_id}`}
                  issues={issues}
                  disabled={saving || students.isPending}
                />
              </div>
            ) : (
              lines
            )}
          </section>
          <p>
            <Button variant="text" onClick={() => void navigate('/crm/bao-gia')}>
              Về danh sách Báo giá
            </Button>
          </p>
        </div>
      </RecordDetail>
      <ReasonDialog
        open={rejectOpen}
        onOpenChange={setRejectOpen}
        title="Từ chối báo giá"
        description={record.code}
        options={catalogs.optionsFor('REJECT_REASON', 'BAO_GIA').map((o) => ({
          ...o,
          needsNote: catalogs.requiresNote('REJECT_REASON', o.value),
        }))}
        confirmLabel="Xác nhận"
        busy={rejectBusy}
        error={rejectError}
        onConfirm={(result) => {
          setRejectBusy(true);
          setRejectError(null);
          void rejectQuotation(
            supabase,
            record.id,
            result.option,
            result.note === '' ? null : result.note,
          )
            .then(refresh)
            .then(() => {
              setRejectOpen(false);
              toast({ title: 'Đã từ chối báo giá.' });
            })
            .catch((e: unknown) => setRejectError(errorOf(e).message))
            .finally(() => setRejectBusy(false));
        }}
      />
      <ConfirmDialog
        open={cancelOpen}
        onOpenChange={setCancelOpen}
        title="Huỷ báo giá"
        description={
          <div className="flex flex-col gap-3">
            <p>
              Báo giá {record.code} sẽ chuyển sang Huỷ và chỉ còn xem. Bản ghi không bị xoá và không
              huỷ lại được.
            </p>
            <TextAreaField
              label="Ghi chú"
              value={cancelNote}
              onChange={(e) => setCancelNote(e.target.value)}
            />
          </div>
        }
        confirmLabel="Xác nhận huỷ"
        confirmIcon="cancelled"
        cancelLabel="Đóng"
        tone="danger"
        busy={cancelBusy}
        error={cancelError}
        onConfirm={() => {
          setCancelBusy(true);
          setCancelError(null);
          void cancelQuotation(
            supabase,
            record.id,
            cancelNote.trim() === '' ? null : cancelNote.trim(),
          )
            .then(refresh)
            .then(() => {
              setCancelOpen(false);
              toast({ title: 'Đã huỷ báo giá.' });
            })
            // Có đơn đang xử lý: báo lỗi trong hộp, không đóng.
            .catch((e: unknown) => setCancelError(errorOf(e).message))
            .finally(() => setCancelBusy(false));
        }}
      />
    </>
  );
}
