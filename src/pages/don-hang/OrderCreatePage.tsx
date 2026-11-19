// BH-05 Tạo đơn hàng (UI-O4, khung BH05_tao_trang_moi và BH05_tao_moi của canvas bổ sung, Đ259, R-CRM-19, R-TIEN-02, R-TIEN-14, R-CRM-16, R-TIEN-39).
// Bấm "Tạo đơn hàng" (ở cơ hội L8) hoặc "Chuyển thành đơn" (ở báo giá Đã gửi) chỉ mở form trắng: chưa có bản ghi, chưa cấp mã. Bấm Lưu mới tạo đơn Nháp
// (app.create_order_from_opportunity hoặc app.create_order_from_quotation) rồi mở bản ghi đơn; bấm Huỷ thì bỏ hết. Giao diện KHÔNG tính tiền (R-TIEN-13):
// đơn giá, chiết khấu, thành tiền do máy chủ. Lớp và ngày vào lớp chọn sau ở BH-08 (Đ214). Điện thoại giữ bản chỉ đọc (Đ248): không có màn này.
//  ?co-hoi=<id>  đơn không qua báo giá: thêm từng dòng như Tạo báo giá; cơ hội đã có đơn Nháp thì hộp BH-11 (Mở đơn cũ / Vẫn tạo).
//  ?bao-gia=<id> đơn từ báo giá: lấy hết các dòng chưa nằm trong đơn nào, bỏ bớt bằng ✕ (dòng bỏ ra vẫn còn trên báo giá).
import { useMemo, useState } from 'react';
import { flushSync } from 'react-dom';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { useAuth } from '../../lib/auth/authContext';
import { formatDate, formatMoney, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ConfirmDialog } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import type { StageStep } from '../../ui/Stage';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { useToast } from '../../ui/toastContext';
import {
  blankRow,
  buildSaveLines,
  rowsSignature,
  flexibleLimitIssues,
  validateRows,
} from '../bao-gia/quoteEdit';
import type { EditRow, RowIssue } from '../bao-gia/quoteEdit';
import { QuoteLineEditor } from '../bao-gia/QuoteLineEditor';
import type { QuotationLine } from '../bao-gia/quoteTypes';
import { useDiscountPolicies, useOpportunityStudents, useQuotation } from '../bao-gia/useQuoteData';
import { useOpportunity, useRefreshOppRecord } from '../co-hoi/useOppData';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  createOrderFromOpportunity,
  createOrderFromQuotation,
  getOpportunityDraftOrder,
  useRefreshOrders,
} from './useOrderData';

const STEP_CODES = ['NHAP', 'DA_TRINH', 'DA_DUYET'];

export function OrderCreatePage() {
  const [params] = useSearchParams();
  const opportunityId = params.get('co-hoi') ?? undefined;
  const quotationId = params.get('bao-gia') ?? undefined;
  const phone = useMedia(NARROW_TABLE);
  const access = useAccess();
  const back =
    quotationId !== undefined
      ? `/crm/bao-gia/${quotationId}`
      : opportunityId !== undefined
        ? `/crm/co-hoi/${opportunityId}`
        : '/crm/don-hang';
  const backLink = (
    <Link to={back} className="font-medium text-link hover:underline">
      Quay lại
    </Link>
  );
  if (opportunityId === undefined && quotationId === undefined)
    return (
      <StateView kind="not-found" title="Chưa chọn nguồn của đơn" actions={backLink}>
        Đơn hàng chỉ tạo từ cơ hội ở L8 (Tạo đơn hàng) hoặc từ báo giá Đã gửi (Chuyển thành đơn).
      </StateView>
    );
  if (phone)
    return (
      <StateView kind="forbidden" title="Tạo đơn hàng chỉ có trên máy tính" actions={backLink}>
        Trên điện thoại đơn hàng chỉ xem được.
      </StateView>
    );
  if (!access.can('SALES_ORDER', 'TAO') || !access.featureOn('BAN_HANG'))
    return (
      <StateView kind="forbidden" title="Bạn chưa tạo được đơn hàng ở cơ sở này" actions={backLink}>
        Cần quyền tạo đơn hàng và phân hệ Bán hàng đã bật ở cơ sở.
      </StateView>
    );
  return quotationId !== undefined ? (
    <FromQuotation quotationId={quotationId} backLink={backLink} />
  ) : (
    <FromOpportunity opportunityId={opportunityId ?? ''} backLink={backLink} />
  );
}

function useSteps() {
  const catalogs = useLeadCatalogs();
  return STEP_CODES.map<StageStep>((code) => ({
    code,
    label: catalogs.name('ORDER_STATUS', code) ?? code,
  }));
}

/** Khung chung hai nhánh: tiêu đề "Tạo đơn hàng", Lưu / Huỷ, thanh giai đoạn mờ, cột phải chưa có hoạt động. */
function Shell({
  mode,
  dirty,
  saving,
  saveDisabled,
  onSave,
  onCancel,
  children,
}: {
  mode: 'opportunity' | 'quotation';
  dirty: boolean;
  saving: boolean;
  saveDisabled: boolean;
  onSave: () => void;
  onCancel: () => void;
  children: React.ReactNode;
}) {
  const steps = useSteps();
  useCrumbTail('Tạo đơn hàng');
  return (
    <RecordDetail
      kind="Đơn hàng"
      title="Tạo đơn hàng"
      mode="create"
      dirty={dirty}
      saving={saving}
      saveDisabled={saveDisabled}
      onEdit={() => undefined}
      onSave={onSave}
      onCancel={onCancel}
      stageShowCode={false}
      stage={{ steps, current: '', forwardOnly: true, onSelect: () => undefined }}
      stageNote="Chưa lưu: đơn chưa có giai đoạn. Bấm Lưu để tạo ở giai đoạn Nháp."
      businessActions={
        <span className="flex flex-wrap items-center gap-2">
          <Button variant="primary" disabled>
            Trình duyệt
          </Button>
          <span className="text-caption text-fg-label">Lưu rồi mới trình duyệt.</span>
        </span>
      }
      smart={[
        { key: 'phu-huynh', label: 'Phụ huynh', icon: 'user', count: 0, onOpen: () => undefined },
        {
          key: mode === 'quotation' ? 'bao-gia' : 'co-hoi',
          label: mode === 'quotation' ? 'Báo giá' : 'Cơ hội',
          icon: 'file',
          count: 0,
          onOpen: () => undefined,
        },
      ]}
      aside={
        <p className="rounded-box border border-border bg-surface p-4 text-fg-muted">
          Lưu để bắt đầu ghi chú: bản ghi chỉ có khi bấm Lưu.
        </p>
      }
    >
      {children}
    </RecordDetail>
  );
}

function Header({
  parent,
  source,
  branch,
}: {
  parent: string;
  source: React.ReactNode;
  branch: string;
}) {
  const { claims } = useAuth();
  return (
    <section className="flex min-w-0 flex-col">
      <h3 className="mb-1 flex items-center gap-2 text-caption font-semibold tracking-wide text-fg-muted uppercase">
        Tạo đơn hàng <Tag tone="neutral">Chưa lưu</Tag>
      </h3>
      <div className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
        <dl className="flex min-w-0 flex-col">
          <DetailField label="Mã đơn" hint="cấp khi Lưu, không sửa" mode="view" value="" />
          <DetailField label="Phụ huynh" mode="view" value={parent} />
          <DetailField label="Nguồn" mode="view" value={source} />
          <DetailField label="Cơ sở vận hành" mode="view" value={branch} />
        </dl>
        <dl className="flex min-w-0 flex-col">
          <DetailField label="Ngày lập" mode="view" value={formatDate(new Date().toISOString())} />
          <DetailField label="Người lập" mode="view" value={claims?.name ?? ''} />
        </dl>
      </div>
    </section>
  );
}

function FromOpportunity({
  opportunityId,
  backLink,
}: {
  opportunityId: string;
  backLink: React.ReactNode;
}) {
  const query = useOpportunity(opportunityId);
  if (query.isPending) return <Spinner label="Đang tải cơ hội…" />;
  if (query.isError) {
    const forbidden = query.error instanceof HmtError && query.error.code === 'HMT_KHONG_CO_QUYEN';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : 'error'}
        title={forbidden ? 'Bạn không có quyền xem cơ hội này' : 'Không tải được cơ hội'}
        actions={backLink}
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  const opp = query.data;
  if (opp.record_status === 'DA_GOP')
    return (
      <StateView kind="forbidden" title="Cơ hội đã gộp vào bản khác" actions={backLink}>
        Không tạo đơn hàng cho cơ hội đã gộp.
      </StateView>
    );
  // R-CRM-16: chỉ cơ hội ở L8 (phụ huynh đã thanh toán) mới tạo được đơn; máy chủ kiểm lại khi Lưu.
  if (opp.stage_code !== 'L8')
    return (
      <StateView kind="forbidden" title="Cơ hội chưa ở L8" actions={backLink}>
        Cơ hội cần ở L8 (phụ huynh đã thanh toán) mới tạo được đơn hàng (R-CRM-16).
      </StateView>
    );
  return (
    <OpportunityForm
      opportunityId={opp.id}
      opportunityCode={opp.code}
      parent={`${opp.parent_name} · ${opp.parent_code} · ${formatPhone(opp.parent_phone)}`}
      branch={`${opp.branch_code} ${opp.branch_name}`}
    />
  );
}

function OpportunityForm({
  opportunityId,
  opportunityCode,
  parent,
  branch,
}: {
  opportunityId: string;
  opportunityCode: string;
  parent: string;
  branch: string;
}) {
  const navigate = useNavigate();
  const openFrom = useNavigateFrom();
  const supabase = useDb();
  const toast = useToast();
  const refreshOrders = useRefreshOrders();
  const refreshOpp = useRefreshOppRecord(opportunityId);
  const students = useOpportunityStudents(opportunityId, true);
  const discountPolicies = useDiscountPolicies(opportunityId, true);
  const [rows, setRows] = useState<EditRow[]>(() => [blankRow()]);
  const [issues, setIssues] = useState<RowIssue[]>([]);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [seeded, setSeeded] = useState(false);
  const [saved, setSaved] = useState(false);
  // BH-11 (R-TIEN-39): cơ hội đã có đơn Nháp thì hỏi Mở đơn cũ hay Vẫn tạo thêm.
  const [existing, setExisting] = useState<{
    message: string;
    id: string | null;
    code: string | null;
  } | null>(null);

  // R-TIEN-35: dòng đầu mặc định em đầu của cơ hội (đổi được), đặt một lần khi danh sách em về.
  const firstStudent = students.data?.[0]?.id;
  if (!seeded && firstStudent !== undefined) {
    setSeeded(true);
    setRows((cur) =>
      cur.map((r, i) => (i === 0 && r.studentId === '' ? { ...r, studentId: firstStudent } : r)),
    );
  }
  const initialSignature = useMemo(
    () => rowsSignature([{ ...blankRow(), studentId: firstStudent ?? '' }]),
    [firstStudent],
  );
  const dirty = rowsSignature(rows) !== initialSignature;

  async function save(confirmExisting: boolean) {
    if (saving) return;
    if (!confirmExisting) {
      const found = validateRows(rows);
      setIssues(found);
      setSaveError(null);
      if (found.length > 0) return;
    }
    setSaving(true);
    try {
      const created = await createOrderFromOpportunity(
        supabase,
        opportunityId,
        buildSaveLines(rows),
        confirmExisting,
      );
      await Promise.all([refreshOrders(), refreshOpp()]);
      toast({ title: `Đã tạo đơn hàng ${created.code}.` });
      flushSync(() => {
        setSaved(true);
        setExisting(null);
      });
      void navigate(`/crm/don-hang/${created.id}`, { replace: true });
    } catch (e) {
      const err = errorOf(e);
      if (err.code === 'HMT_CO_DON_NHAP') {
        const draft = await getOpportunityDraftOrder(supabase, opportunityId).catch(() => null);
        setExisting({ message: err.message, id: draft?.id ?? null, code: draft?.code ?? null });
      } else {
        setSaveError(err.message);
      }
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <Shell
        mode="opportunity"
        dirty={dirty && !saved}
        saving={saving}
        saveDisabled={flexibleLimitIssues(rows, discountPolicies.data ?? []).length > 0}
        onSave={() => void save(false)}
        // Huỷ: bỏ hết, chưa có bản ghi (R-CRM-19); về bản ghi cơ hội.
        onCancel={() => void navigate(`/crm/co-hoi/${opportunityId}`)}
      >
        <div className="flex flex-col gap-6">
          <Header
            parent={parent}
            branch={branch}
            source={
              <span>
                Không qua báo giá: tạo từ cơ hội{' '}
                <Link
                  to={`/crm/co-hoi/${opportunityId}`}
                  onClick={(e) => {
                    e.preventDefault();
                    openFrom(`/crm/co-hoi/${opportunityId}`);
                  }}
                  className="font-medium text-link hover:underline"
                >
                  {opportunityCode}
                </Link>
              </span>
            }
          />
          <section className="flex min-w-0 flex-col">
            <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
              Dòng đơn
            </h3>
            <QuoteLineEditor
              opportunityId={opportunityId}
              rows={rows}
              onRowsChange={setRows}
              issues={issues}
              onIssuesChange={setIssues}
              saveError={saveError}
              saving={saving}
              layout="tao"
              totalLabel="Tổng cộng đơn hàng"
            />
            <p className="text-caption text-fg-muted">
              Chưa thấy em? Thêm em ở cơ hội. Lớp và ngày vào lớp chọn sau khi tạo đơn.
            </p>
          </section>
          <p>
            <Button variant="text" onClick={() => void navigate(`/crm/co-hoi/${opportunityId}`)}>
              Về cơ hội
            </Button>
          </p>
        </div>
      </Shell>
      <ConfirmDialog
        open={existing !== null}
        onOpenChange={(o) => !o && setExisting(null)}
        title="Cơ hội đã có đơn Nháp"
        description={
          <span className="flex flex-col gap-2">
            <span>{existing?.message}</span>
            {existing?.id && (
              <Link
                to={`/crm/don-hang/${existing.id}`}
                className="font-medium text-link hover:underline"
              >
                Mở đơn cũ {existing.code}
              </Link>
            )}
          </span>
        }
        confirmLabel="Vẫn tạo đơn mới"
        cancelLabel="Đóng"
        busy={saving}
        onConfirm={() => void save(true)}
      />
    </>
  );
}

function FromQuotation({
  quotationId,
  backLink,
}: {
  quotationId: string;
  backLink: React.ReactNode;
}) {
  const query = useQuotation(quotationId);
  if (query.isPending) return <Spinner label="Đang tải báo giá…" />;
  if (query.isError) {
    const forbidden = query.error instanceof HmtError && query.error.code === 'HMT_KHONG_CO_QUYEN';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : 'error'}
        title={forbidden ? 'Bạn không có quyền xem báo giá này' : 'Không tải được báo giá'}
        actions={backLink}
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  const q = query.data;
  // R-TIEN-14: chỉ báo giá Đã gửi (chưa từ chối, chưa huỷ) mới chuyển thành đơn.
  if (q.status_code !== 'DA_GUI')
    return (
      <StateView kind="forbidden" title="Báo giá chưa chuyển thành đơn được" actions={backLink}>
        Chỉ báo giá ở tình trạng Đã gửi mới chuyển thành đơn (R-TIEN-14).
      </StateView>
    );
  const open = q.lines.filter((l) => l.order_id === null);
  if (open.length === 0)
    return (
      <StateView kind="forbidden" title="Mọi dòng đã nằm trong đơn" actions={backLink}>
        Báo giá này không còn dòng nào chưa lên đơn.
      </StateView>
    );
  return (
    <QuotationForm
      quotationId={q.id}
      quotationCode={q.code}
      parent={`${q.parent_name} · ${q.parent_code} · ${formatPhone(q.parent_phone)}`}
      branch={`${q.branch_code}`}
      lines={open}
    />
  );
}

function QuotationForm({
  quotationId,
  quotationCode,
  parent,
  branch,
  lines,
}: {
  quotationId: string;
  quotationCode: string;
  parent: string;
  branch: string;
  lines: QuotationLine[];
}) {
  const navigate = useNavigate();
  const supabase = useDb();
  const toast = useToast();
  const refreshOrders = useRefreshOrders();
  const catalogs = useLeadCatalogs();
  const [removed, setRemoved] = useState<ReadonlySet<number>>(new Set());
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const kept = lines.filter((l) => !removed.has(l.line_no));
  const students = new Set(kept.map((l) => l.prospect_student_id ?? l.student_name ?? l.line_no))
    .size;

  async function save() {
    if (saving || kept.length === 0) return;
    setSaving(true);
    setError(null);
    try {
      const created = await createOrderFromQuotation(
        supabase,
        quotationId,
        kept.map((l) => l.line_no),
      );
      await refreshOrders();
      toast({ title: `Đã tạo đơn hàng ${created.code}.` });
      flushSync(() => setSaved(true));
      void navigate(`/crm/don-hang/${created.id}`, { replace: true });
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <Shell
      mode="quotation"
      dirty={removed.size > 0 && !saved}
      saving={saving}
      saveDisabled={kept.length === 0}
      onSave={() => void save()}
      // Huỷ: bỏ hết, chưa có bản ghi; về báo giá.
      onCancel={() => void navigate(`/crm/bao-gia/${quotationId}`)}
    >
      <div className="flex flex-col gap-6">
        <Header
          parent={parent}
          branch={branch}
          source={
            <span>
              Báo giá{' '}
              <Link
                to={`/crm/bao-gia/${quotationId}`}
                className="font-medium text-link hover:underline"
              >
                {quotationCode}
              </Link>
            </span>
          }
        />
        <section className="flex min-w-0 flex-col gap-2">
          <h3 className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
            Dòng đơn
          </h3>
          {error !== null && (
            <Alert tone="danger" title="Chưa tạo được đơn.">
              {error}
            </Alert>
          )}
          <p className="text-body">
            Đơn tạo từ báo giá <b>{quotationCode}</b>: lấy hết {lines.length} dòng chưa nằm trong
            đơn nào. Bỏ dòng không đưa vào bằng ✕; dòng bỏ ra vẫn còn trên báo giá. Giá chép y báo
            giá.
          </p>
          <div className="overflow-x-auto rounded-control border border-border">
            <table aria-label="Dòng đơn" className="w-full text-body">
              <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
                <tr>
                  <th className="px-3 py-2">#</th>
                  <th className="px-3 py-2">Học sinh</th>
                  <th className="px-3 py-2">Sản phẩm</th>
                  <th className="px-3 py-2">Hình thức</th>
                  <th className="px-3 py-2 text-right">Số lượng</th>
                  <th className="px-3 py-2 text-right">Đơn giá</th>
                  <th className="px-3 py-2 text-right">Thành tiền</th>
                  <th className="px-3 py-2">
                    <span className="sr-only">Bỏ dòng</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {kept.map((l, i) => (
                  <tr key={l.line_no} className="border-t border-border">
                    <td className="px-3 py-2">{i + 1}</td>
                    <td className="px-3 py-2">{l.student_name ?? '—'}</td>
                    <td className="px-3 py-2">{l.package_name}</td>
                    <td className="px-3 py-2">
                      {catalogs.name('STUDY_MODE', l.delivery_mode_code) ?? l.delivery_mode_code}
                    </td>
                    <td className="tabular px-3 py-2 text-right">{formatNumber(l.quantity)}</td>
                    <td className="tabular px-3 py-2 text-right">{formatMoney(l.unit_price)}</td>
                    <td className="tabular px-3 py-2 text-right">{formatMoney(l.line_total)}</td>
                    <td className="px-3 py-2">
                      <Button
                        size="sm"
                        variant="text"
                        aria-label={`Bỏ dòng ${i + 1} khỏi đơn`}
                        disabled={saving}
                        onClick={() => setRemoved(new Set([...removed, l.line_no]))}
                      >
                        ✕
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="text-caption text-fg-muted">
            {students} em · {kept.length} dòng. Lớp và ngày vào lớp chọn sau khi tạo đơn. Tổng tiền
            do hệ thống tính khi Lưu.
          </p>
          {kept.length === 0 && (
            <Alert tone="warning">Đơn cần ít nhất một dòng: bỏ hết thì không lưu được.</Alert>
          )}
        </section>
      </div>
    </Shell>
  );
}
