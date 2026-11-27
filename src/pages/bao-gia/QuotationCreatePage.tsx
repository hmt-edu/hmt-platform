// BH-02 Tạo báo giá từ cơ hội (khung BH02_tao, R-CRM-19, R-TIEN-02): bấm "Tạo báo giá" trên bản ghi cơ hội chỉ mở form trắng; chưa có bản ghi, chưa cấp
// mã. Bấm Lưu mới tạo báo giá Nháp và cấp mã (app.save_quotation); bấm Huỷ thì bỏ hết, về cơ hội. Danh sách báo giá không có nút Tạo.
// Hai nguồn, cùng một form (R-GD-13): ?co-hoi= (cơ hội) hoặc ?phieu= (phiếu tái tục, mọi giai đoạn). Điện thoại cũng lập được (B-27-09, anh cho phép 27/11).
import { useMemo, useState } from 'react';
import { flushSync } from 'react-dom';
import { Link, useNavigate, useSearchParams, useLocation } from 'react-router';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf, useDb, useIntSetting } from '../../lib/db';
import { useAuth } from '../../lib/auth/authContext';
import { formatDate } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { useOpportunity } from '../co-hoi/useOppData';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  blankRow,
  buildSaveLines,
  rowsSignature,
  flexibleLimitIssues,
  validateRows,
  type EditRow,
  type RowIssue,
} from './quoteEdit';
import { QuoteLineEditor } from './QuoteLineEditor';
import {
  saveQuotation,
  useDiscountPolicies,
  useOpportunityStudents,
  useRefreshQuotations,
  type OppStudent,
} from './useQuoteData';
import { useUpsaleRecord } from '../tai-tuc/useUpsaleData';
import { branchLabel } from '../don-hang/orderBranch';
import { FromLink } from '../../layout/FromLink';

/** Nơi sinh ra báo giá: cơ hội hoặc phiếu tái tục. */
type Source = {
  /** Mã nội bộ gửi lên máy chủ (cơ hội hoặc phiếu). */
  id: string;
  code: string;
  href: string;
  label: 'Cơ hội' | 'Phiếu tái tục';
  /** Chỉ có ở phiếu tái tục: em của phiếu. */
  ticketStudent?: OppStudent;
};

export function QuotationCreatePage() {
  const [params] = useSearchParams();
  const ticketId = params.get('phieu');
  return ticketId === null ? <FromOpportunity /> : <FromTicket ticketId={ticketId} />;
}

function FromTicket({ ticketId }: { ticketId: string }) {
  const access = useAccess();
  const query = useUpsaleRecord(ticketId);
  const href = `/crm/tai-tuc/${ticketId}`;
  const backLink = (
    <Link to={href} className="font-medium text-link hover:underline">
      Về phiếu tái tục
    </Link>
  );
  if (query.isPending) return <Spinner label="Đang tải phiếu tái tục…" />;
  if (query.isError) {
    const forbidden = query.error instanceof HmtError && query.error.code === 'HMT_KHONG_CO_QUYEN';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : 'error'}
        title={forbidden ? 'Bạn không có quyền xem phiếu tái tục này' : 'Không tải được phiếu'}
        actions={backLink}
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  const { ticket, parent, student, actions } = query.data;
  if (
    !actions.includes('tao_bao_gia') ||
    !access.featureOn('BAN_HANG') ||
    parent === null ||
    student === null
  )
    return (
      <StateView kind="forbidden" title="Bạn chưa lập được báo giá ở cơ sở này" actions={backLink}>
        Cần quyền lập báo giá, quyền sửa phiếu tái tục và phân hệ Bán hàng đã bật ở cơ sở của phiếu.
      </StateView>
    );
  return (
    <CreateForm
      source={{
        id: ticket.id,
        code: ticket.code,
        href,
        label: 'Phiếu tái tục',
        ticketStudent: {
          id: student.id,
          position: 1,
          full_name: student.name,
          birth_year: student.birth_year,
        },
      }}
      branchId={ticket.branch_id}
      parent={`${parent.name} · ${parent.code} · ${formatPhone(parent.phone)}`}
      branch={branchLabel(ticket.branch_code, access.teachingBranches)}
    />
  );
}

function FromOpportunity() {
  const [params] = useSearchParams();
  const opportunityId = params.get('co-hoi') ?? undefined;
  const access = useAccess();
  const query = useOpportunity(opportunityId);
  const back = opportunityId === undefined ? '/crm/co-hoi' : `/crm/co-hoi/${opportunityId}`;
  const backLink = (
    <Link to={back} className="font-medium text-link hover:underline">
      Về cơ hội
    </Link>
  );

  if (opportunityId === undefined)
    return (
      <StateView kind="not-found" title="Chưa chọn cơ hội" actions={backLink}>
        Báo giá chỉ tạo từ bản ghi cơ hội: mở cơ hội rồi bấm Tạo báo giá.
      </StateView>
    );
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
  if (!access.can('QUOTATION', 'TAO') || !access.featureOn('BAN_HANG'))
    return (
      <StateView kind="forbidden" title="Bạn chưa lập được báo giá ở cơ sở này" actions={backLink}>
        Cần quyền lập báo giá và phân hệ Bán hàng đã bật ở cơ sở của cơ hội.
      </StateView>
    );
  if (opp.record_status === 'DA_GOP')
    return (
      <StateView kind="forbidden" title="Cơ hội đã gộp vào bản khác" actions={backLink}>
        Không tạo báo giá cho cơ hội đã gộp.
      </StateView>
    );
  return (
    <CreateForm
      source={{ id: opp.id, code: opp.code, href: `/crm/co-hoi/${opp.id}`, label: 'Cơ hội' }}
      branchId={opp.branch_id}
      parent={`${opp.parent_name} · ${opp.parent_code} · ${formatPhone(opp.parent_phone)}`}
      branch={`${opp.branch_code} ${opp.branch_name}`}
    />
  );
}

function CreateForm({
  source,
  branchId,
  parent,
  branch,
}: {
  source: Source;
  branchId: string;
  parent: string;
  branch: string;
}) {
  const navigate = useNavigate();
  const location = useLocation();
  const openFrom = useNavigateFrom();
  const supabase = useDb();
  const toast = useToast();
  const { claims } = useAuth();
  const catalogs = useLeadCatalogs();
  const validityDays = useIntSetting('quotation_validity_days', branchId); // theo cơ sở của cơ hội, cùng nguồn với hàm Gửi; // hạn hiệu lực báo giá (R-TIEN-05), khung BH02: «N ngày kể từ ngày Gửi»
  const refreshList = useRefreshQuotations();
  const opportunityId = source.id;
  const backLabel = source.label === 'Cơ hội' ? 'Về cơ hội' : 'Về phiếu tái tục';
  const students = useOpportunityStudents(opportunityId, source.ticketStudent === undefined);
  const discountPolicies = useDiscountPolicies(opportunityId, true);
  useCrumbTail('Tạo báo giá');
  const [rows, setRows] = useState<EditRow[]>(() => [blankRow()]);
  const [issues, setIssues] = useState<RowIssue[]>([]);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [seeded, setSeeded] = useState(false);
  const [saved, setSaved] = useState(false);

  // R-TIEN-35: dòng đầu mặc định em đầu của cơ hội (đổi được), đặt một lần khi danh sách em về.
  const firstStudent = source.ticketStudent?.id ?? students.data?.[0]?.id;
  if (!seeded && firstStudent !== undefined) {
    setSeeded(true);
    setRows((cur) =>
      cur.map((r, i) => (i === 0 && r.studentId === '' ? { ...r, studentId: firstStudent } : r)),
    );
  }

  // Chưa đổi gì ngoài dòng trắng mặc định (kể cả em đầu đặt sẵn) thì Huỷ không hỏi.
  const initialSignature = useMemo(
    () => rowsSignature([{ ...blankRow(), studentId: firstStudent ?? '' }]),
    [firstStudent],
  );
  const dirty = rowsSignature(rows) !== initialSignature;
  const stageNames = ['NHAP', 'DA_GUI', 'DA_CHUYEN_DON'];
  const steps: StageStep[] = stageNames.map((code) => ({
    code,
    label: catalogs.name('QUOTATION_STATUS', code) ?? code,
  }));

  async function save() {
    if (saving) return;
    const found = validateRows(rows);
    setIssues(found);
    setSaveError(null);
    if (found.length > 0) return;
    setSaving(true);
    try {
      const created = await saveQuotation(supabase, null, opportunityId, buildSaveLines(rows));
      await refreshList();
      toast({ title: `Đã tạo báo giá ${created.code}.` });
      // Đã lưu: tắt cảnh báo rời trang (không còn thay đổi chưa lưu) rồi mở bản ghi vừa tạo.
      flushSync(() => setSaved(true));
      void navigate(`/crm/bao-gia/${created.id}`, {
        replace: true,
        state: location.state as unknown,
      });
    } catch (e) {
      setSaveError(errorOf(e).message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <RecordDetail
      kind="Báo giá"
      title="Tạo báo giá"
      mode="create"
      dirty={dirty && !saved}
      saving={saving}
      saveDisabled={flexibleLimitIssues(rows, discountPolicies.data ?? []).length > 0}
      onEdit={() => undefined}
      onSave={() => void save()}
      // Huỷ: bỏ hết, chưa có bản ghi (R-CRM-19); về bản ghi cơ hội.
      onCancel={() => openFrom(source.href)}
      stageShowCode={false}
      stage={{ steps, current: '', forwardOnly: true, onSelect: () => undefined }}
      stageNote="Chưa lưu: báo giá chưa có giai đoạn. Bấm Lưu để tạo ở giai đoạn Nháp."
      businessActions={
        <span className="flex flex-wrap items-center gap-2">
          <Button variant="primary" disabled>
            Gửi
          </Button>
          <span className="text-caption text-fg-label">Lưu rồi mới gửi.</span>
        </span>
      }
      smart={[
        {
          key: 'nguon',
          label: source.label,
          icon: 'recruit',
          count: 0,
          onOpen: () => undefined,
        },
        { key: 'phu-huynh', label: 'Phụ huynh', icon: 'user', count: 0, onOpen: () => undefined },
        { key: 'don-hang', label: 'Đơn hàng', icon: 'file', count: 0, onOpen: () => undefined },
      ]}
      aside={
        <p className="rounded-box border border-border bg-surface p-4 text-fg-muted">
          Lưu để bắt đầu ghi chú: bản ghi chỉ có khi bấm Lưu.
        </p>
      }
    >
      <div className="flex flex-col gap-6">
        <section className="flex min-w-0 flex-col">
          <h3 className="mb-1 flex items-center gap-2 text-caption font-semibold tracking-wide text-fg-muted uppercase">
            Tạo báo giá <Tag tone="neutral">Chưa lưu</Tag>
          </h3>
          <div className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
            <dl className="flex min-w-0 flex-col">
              <DetailField label="Mã báo giá" hint="cấp khi Lưu, không sửa" mode="view" value="" />
              <DetailField label="Phụ huynh" mode="view" value={parent} />
              <DetailField
                label={source.label}
                mode="view"
                value={
                  <FromLink to={source.href} className="font-medium text-link hover:underline">
                    {source.code}
                  </FromLink>
                }
              />
              <DetailField label="Cơ sở" mode="view" value={branch} />
            </dl>
            <dl className="flex min-w-0 flex-col">
              <DetailField
                label="Ngày lập"
                mode="view"
                value={formatDate(new Date().toISOString())}
              />
              <DetailField
                label="Hạn hiệu lực"
                mode="view"
                value={
                  validityDays === null ? 'tính từ ngày Gửi' : `${validityDays} ngày kể từ ngày Gửi`
                }
              />
              <DetailField label="Người lập" mode="view" value={claims?.name ?? ''} />
            </dl>
          </div>
        </section>
        <section className="flex min-w-0 flex-col">
          <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
            Gói học
          </h3>
          <QuoteLineEditor
            opportunityId={opportunityId}
            ticketStudent={source.ticketStudent}
            rows={rows}
            onRowsChange={setRows}
            issues={issues}
            onIssuesChange={setIssues}
            saveError={saveError}
            saving={saving}
            layout="tao"
          />
        </section>
        <p>
          <Button variant="text" onClick={() => openFrom(source.href)}>
            {backLabel}
          </Button>
        </p>
      </div>
    </RecordDetail>
  );
}
