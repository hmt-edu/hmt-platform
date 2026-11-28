// TT-02 Phiếu tái tục (bản ghi, khuôn K06; bố cục anh Trường chốt 27/11): thanh giai đoạn chỉ đọc («Không tái tục» cuối), nút, câu theo giai đoạn, rồi một trang
// liền: Liên hệ, Giờ học, Ghi danh, Báo giá và đơn, Tình hình học tập, Kết quả tái tục. Số máy chủ chưa trả thì ghi «chưa có dữ liệu», không tự tính.
// Giao diện KHÔNG tính giờ, không tự đoán quyền: số liệu và việc làm được do get_upsale_ticket trả. Điện thoại chỉ đọc (Đ248).
import { useCrumbTail } from '../../layout/CrumbTail';
import { useRef, useState, type ReactNode, type Ref } from 'react';
import { Link, useParams } from 'react-router';
import { RecordDetail, DetailField } from '../../record/Detail';
import { HmtError, errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate, formatDateTime, formatMoney, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Chatter } from '../../ui/Chatter';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextAreaField } from '../../ui/Field';
import { LineTable } from '../../ui/LineTable';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { AssignUpsaleDialog } from './AssignUpsaleDialog';
import { ChangeUpsaleStageDialog } from './ChangeUpsaleStageDialog';
import { CreateUpsaleOrderDialog } from './CreateUpsaleOrderDialog';
import { upsaleEventEntries } from './upsaleEventEntries';
import { orderStages, upsaleStageNote } from './upsaleNotes';
import type { UpsaleOrderRow, UpsaleRecord } from './upsaleTypes';
import {
  saveUpsaleNotes,
  useRefreshUpsaleRecord,
  useUpsaleOrders,
  useUpsaleQuotes,
  useUpsaleRecord,
} from './useUpsaleData';
import { FromLink } from '../../layout/FromLink';
import { useNavigateFrom } from '../../layout/crumbTrail';
import type { QuotationRow } from '../bao-gia/quoteTypes';

/** Ô máy chủ chưa trả số liệu: nói rõ, để không hiểu nhầm là «chưa có» thật. */
const NO_DATA = <span className="text-fg-muted">chưa có dữ liệu</span>;

export function UpsaleRecordPage() {
  const { id } = useParams<{ id: string }>();
  const query = useUpsaleRecord(id);
  if (query.isPending) return <Spinner label="Đang tải phiếu tái tục…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem phiếu tái tục này'
            : missing
              ? 'Không tìm thấy phiếu tái tục'
              : 'Không tải được phiếu tái tục'
        }
        actions={
          <>
            {/* duong-dan-menu: không tải được bản ghi, về danh sách chung */}
            <Link to="/crm/tai-tuc" className="font-medium text-link hover:underline">
              Về danh sách Tái tục
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
  return <UpsaleView key={query.data.ticket.id} record={query.data} />;
}

function UpsaleView({ record }: { record: UpsaleRecord }) {
  const supabase = useDb();
  const toast = useToast();
  const access = useAccess();
  const catalogs = useLeadCatalogs();
  const hoursThreshold = useIntSetting('upsale_hours_left_threshold');
  const daysThreshold = useIntSetting('upsale_days_left_threshold');
  const phone = useMedia(NARROW_TABLE);
  const t = record.ticket;
  useCrumbTail(t.code);
  const refresh = useRefreshUpsaleRecord(t.id);
  const ordersRef = useRef<HTMLElement>(null);
  const [dialog, setDialog] = useState<'stage' | 'assign' | 'order' | null>(null);
  const [goal, setGoal] = useState(t.next_goal ?? '');
  const [roadmap, setRoadmap] = useState(t.next_roadmap ?? '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const orders = useUpsaleOrders(t.id);
  const can = (a: UpsaleRecord['actions'][number]) => record.actions.includes(a) && !phone;
  // Báo giá tạo ở mọi giai đoạn; đơn chỉ ở L8, không giới hạn số đơn (R-GD-13). Máy chủ trả việc làm được và kiểm lại.
  const canCreateQuote = can('tao_bao_gia') && access.featureOn('BAN_HANG');
  const canCreateOrder = can('tao_don') && access.featureOn('BAN_HANG');
  const openFrom = useNavigateFrom();
  const canSeeQuotes = access.can('QUOTATION', 'XEM');
  const quotes = useUpsaleQuotes(t.id, canSeeQuotes);
  const quoteCount = quotes.data?.total ?? 0;
  const orderCount = orders.data?.length ?? 0;
  const dirty = goal !== (t.next_goal ?? '') || roadmap !== (t.next_roadmap ?? '');
  const forbiddenAll = !access.can('UPSALE', 'XEM');

  const steps: StageStep[] = orderStages(catalogs.options('UPSALE_STAGE')).map((o) => ({
    code: o.value,
    label: o.label,
    fullLabel: `${o.value} ${o.label}`,
  }));

  async function save() {
    setSaving(true);
    setError(null);
    try {
      await saveUpsaleNotes(supabase, t.id, goal, roadmap);
      await refresh();
      toast({ title: 'Đã lưu ghi chú phiếu.' });
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setSaving(false);
    }
  }

  // Ở L5 giai đoạn con chính là lý do; phiếu cũ thiếu giai đoạn con thì lấy lý do danh mục đã lưu.
  const lostReason =
    t.stage_code !== 'L5'
      ? ''
      : t.substage_code
        ? (catalogs.name('UPSALE_SUBSTAGE', t.substage_code) ?? t.substage_code)
        : t.lost_reason_code
          ? (catalogs.name('RENEWAL_LOST_REASON', t.lost_reason_code) ?? t.lost_reason_code)
          : '';
  const stageNote = upsaleStageNote(
    t,
    lostReason || null,
    { hours: hoursThreshold, days: daysThreshold },
    {
      sentQuotes: (quotes.data?.rows ?? []).filter((q) => q.status_code === 'DA_GUI').length,
    },
    can('giao'),
  );
  const toDocuments = () => ordersRef.current?.scrollIntoView({ block: 'start' });
  // Điện thoại và người không có quyền: không dựng thanh nút rỗng, không nhắc nút không có.
  const hasActions = can('doi_giai_doan') || canCreateQuote || canCreateOrder || can('giao');

  const purchase = record.hours.last_purchase;
  const absences = `${record.hours.absences_window} buổi`;
  const lastContact = record.contact.last;
  // Ngày giờ · kênh · kết quả của lần liên hệ gần nhất (một thông tin: lần liên hệ).
  const lastContactText = lastContact
    ? [
        formatDateTime(lastContact.at),
        catalogs.name('CONTACT_CHANNEL', lastContact.channel_code) ?? lastContact.channel_code,
        catalogs.name('CONTACT_RESULT', lastContact.result_code) ?? lastContact.result_code,
      ].join(' · ')
    : '';
  const field = (label: string, value: ReactNode) => (
    <DetailField label={label} mode="view" value={value} />
  );

  return (
    <>
      <RecordDetail
        kind="Phiếu tái tục"
        title={t.code}
        mode="view"
        readOnly
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        stageShowCode={false}
        stage={{ steps, current: t.stage_code, forwardOnly: true, onSelect: () => undefined }}
        stageNote={
          can('doi_giai_doan') ? 'Stage chỉ đọc, đổi bằng nút bên dưới.' : 'Stage chỉ đọc.'
        }
        subStage={
          t.substage_code ? (
            <span className="text-caption text-fg-label">
              Sub-stage: {catalogs.name('UPSALE_SUBSTAGE', t.substage_code) ?? t.substage_code}
            </span>
          ) : undefined
        }
        businessActions={
          hasActions ? (
            <span className="flex flex-wrap items-center gap-2">
              {can('doi_giai_doan') && (
                <Button variant="primary" onClick={() => setDialog('stage')}>
                  Chuyển giai đoạn
                </Button>
              )}
              {canCreateQuote && (
                <Button
                  variant="primary"
                  onClick={() => openFrom(`/crm/bao-gia/tao?phieu=${t.id}`)}
                >
                  Tạo báo giá
                </Button>
              )}
              {canCreateOrder && (
                <Button variant="primary" onClick={() => setDialog('order')}>
                  Tạo đơn
                </Button>
              )}
              {can('giao') && <Button onClick={() => setDialog('assign')}>Giao</Button>}
            </span>
          ) : undefined
        }
        smart={[
          {
            key: 'hoc-sinh',
            label: 'Học sinh',
            icon: 'user',
            count: record.student ? 1 : 0,
            unavailable: 'Có khi làm màn Khách hàng',
            onOpen: () => undefined,
          },
          {
            key: 'bao-gia',
            label: 'Báo giá',
            icon: 'file',
            count: quoteCount,
            // Có `unavailable` là nút mờ, nên chỉ đặt khi chưa mở được gì.
            ...(quoteCount > 0
              ? { onOpen: toDocuments }
              : {
                  unavailable: canSeeQuotes
                    ? 'Phiếu chưa có báo giá'
                    : 'Bạn không có quyền xem báo giá',
                  onOpen: () => undefined,
                }),
          },
          {
            key: 'don-hang',
            label: 'Đơn hàng',
            icon: 'payment',
            count: orderCount,
            ...(orderCount > 0
              ? { onOpen: toDocuments }
              : { unavailable: 'Phiếu chưa có đơn', onOpen: () => undefined }),
          },
          {
            key: 'ghi-danh',
            label: 'Ghi danh',
            icon: 'classes',
            count: record.enrollments.length,
            unavailable: 'Có khi làm bản ghi Ghi danh từ phiếu',
            onOpen: () => undefined,
          },
        ]}
        aside={
          <Chatter
            entries={upsaleEventEntries(record.events)}
            status="ready"
            canWrite={false}
            onSend={() => Promise.resolve()}
            searchPeople={() => Promise.resolve([])}
          />
        }
      >
        <div className="flex flex-col gap-4">
          {forbiddenAll && <Alert tone="danger">Bạn không có quyền xem phiếu tái tục.</Alert>}
          {error && (
            <Alert tone="danger" title="Chưa thực hiện được">
              {error}
            </Alert>
          )}
          {stageNote && <Alert tone={stageNote.tone}>{stageNote.text}</Alert>}
          {t.risk_flag && record.hours.absences_window > 0 && (
            <Alert tone="warning">
              Học sinh vắng {absences} trong {record.hours.window_days} ngày gần nhất ở lớp này (cờ
              rủi ro).
            </Alert>
          )}

          <Block title="Liên hệ">
            <div className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
              <dl className="flex min-w-0 flex-col">
                {field('Phụ huynh', record.parent?.name ?? '')}
                {field('Số điện thoại', record.parent ? formatPhone(record.parent.phone) : '')}
                {field(
                  'Email',
                  record.parent?.email || <span className="text-fg-muted">Chưa có</span>,
                )}
                {field('Học sinh', record.student?.name ?? '')}
                {field('Mã học sinh', record.student?.code ?? '')}
              </dl>
              <dl className="flex min-w-0 flex-col">
                {field('Người phụ trách', t.owner_name ?? 'chưa giao')}
                {field('Lần liên hệ gần nhất', lastContactText)}
                {field(
                  'Ngày hẹn gọi lại',
                  record.contact.next_appointment_at
                    ? formatDateTime(record.contact.next_appointment_at)
                    : '',
                )}
              </dl>
            </div>
          </Block>

          <Block title="Giờ học">
            <div className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
              <dl className="flex min-w-0 flex-col">
                {field('Đã mua (gồm giờ tặng)', `${formatNumber(record.hours.bought)} giờ`)}
                {field('Giờ tặng', `${formatNumber(record.hours.gifted)} giờ`)}
                {field('Đã học', `${formatNumber(record.hours.used)} giờ`)}
                {field('Giờ còn', t.hours_left === null ? '' : `${formatNumber(t.hours_left)} giờ`)}
                {field(
                  'Ngày hết giờ dự kiến',
                  t.expected_end_date ? formatDate(t.expected_end_date) : '',
                )}
                {field(`Vắng ${record.hours.window_days} ngày`, absences)}
              </dl>
              <dl className="flex min-w-0 flex-col">
                {field('Mua gần nhất: ngày', purchase ? formatDate(purchase.at) : '')}
                {field('Mua gần nhất: gói', purchase?.package_name ?? '')}
                {field(
                  'Mua gần nhất: số giờ',
                  purchase ? `${formatNumber(purchase.hours)} giờ` : '',
                )}
                {field('Tháng hết giờ', t.campaign_label ?? '')}
              </dl>
            </div>
          </Block>

          <Block title={`Ghi danh (${record.enrollments.length})`}>
            <LineTable
              caption="Ghi danh của phiếu"
              scrollFocusable
              rows={record.enrollments}
              rowKey={(e) => e.id}
              empty={<p className="p-3 text-fg-muted">Chưa có ghi danh đang học ở lớp này.</p>}
              columns={[
                { key: 'code', header: 'Ghi danh', cell: (e) => e.code },
                { key: 'class', header: 'Lớp', cell: () => record.class.code },
                { key: 'subject', header: 'Môn', cell: () => NO_DATA },
                {
                  key: 'teacher',
                  header: 'Giáo viên',
                  cell: () => record.class.teacher_name ?? '',
                },
                {
                  key: 'left',
                  header: 'Giờ còn',
                  align: 'right',
                  cell: (e) => formatNumber(e.hours_left),
                },
                { key: 'end', header: 'Ngày hết', cell: () => NO_DATA },
              ]}
            />
          </Block>

          <Block title="Báo giá và đơn" ref={ordersRef}>
            <DocumentsTable
              quotes={quotes.data?.rows ?? []}
              orders={orders.data ?? []}
              quoteStatus={(code) => catalogs.name('QUOTATION_STATUS', code) ?? code}
            />
          </Block>

          <Block title="Tình hình học tập">
            <dl className="flex flex-col">
              {field(
                'Chuyên cần',
                `Vắng ${absences} trong ${record.hours.window_days} ngày gần nhất`,
              )}
              {field('Nhận xét gần nhất', NO_DATA)}
            </dl>
          </Block>

          <Block title="Kết quả tái tục">
            <TextAreaField
              label="Mục tiêu / nhu cầu tiếp theo"
              value={goal}
              onChange={(e) => setGoal(e.target.value)}
              rows={3}
              disabled={!can('sua_ghi_chu')}
            />
            <TextAreaField
              label="Lộ trình tiếp theo"
              value={roadmap}
              onChange={(e) => setRoadmap(e.target.value)}
              rows={3}
              disabled={!can('sua_ghi_chu')}
            />
            {can('sua_ghi_chu') && (
              <span>
                <Button
                  variant="primary"
                  loading={saving}
                  disabled={!dirty}
                  onClick={() => void save()}
                >
                  Lưu
                </Button>
              </span>
            )}
            {t.stage_code === 'L5' && (
              <dl className="flex flex-col">
                {field('Lý do không tái tục', [lostReason, t.lost_note].filter(Boolean).join('. '))}
                {field('Ngày đóng phiếu', t.closed_at ? formatDateTime(t.closed_at) : '')}
              </dl>
            )}
          </Block>
        </div>
      </RecordDetail>
      <ChangeUpsaleStageDialog
        open={dialog === 'stage'}
        onOpenChange={(o) => !o && setDialog(null)}
        ticket={t}
        onDone={async () => {
          await refresh();
          toast({ title: 'Đã chuyển giai đoạn.' });
        }}
      />
      <CreateUpsaleOrderDialog
        open={dialog === 'order'}
        onOpenChange={(o) => !o && setDialog(null)}
        ticket={t}
        onDone={async () => {
          await refresh();
        }}
      />
      <AssignUpsaleDialog
        row={dialog === 'assign' ? t : null}
        onOpenChange={(o) => !o && setDialog(null)}
        onAssigned={(name) => {
          void refresh();
          toast({ title: `Đã giao cho ${name}.` });
        }}
      />
    </>
  );
}

const ORDER_STATUS: Record<string, string> = {
  NHAP: 'Nháp',
  DA_TRINH: 'Đã trình',
  DA_DUYET: 'Đã duyệt',
  HUY: 'Huỷ',
};

/** Một khối của trang phiếu: tiêu đề và nội dung. */
function Block({
  title,
  children,
  ref,
}: {
  title: string;
  children: ReactNode;
  ref?: Ref<HTMLElement>;
}) {
  return (
    <section ref={ref} aria-label={title} className="flex min-w-0 flex-col gap-2">
      <h3 className="text-body-lg font-semibold">{title}</h3>
      {children}
    </section>
  );
}

type DocumentRow = {
  id: string;
  code: string;
  to: string;
  type: 'Báo giá' | 'Đơn hàng';
  status: string;
  total_amount: number;
  created_at: string;
};

/** Báo giá và đơn sinh ra từ phiếu (máy chủ chưa trả số đã thu). */
function DocumentsTable({
  quotes,
  orders,
  quoteStatus,
}: {
  quotes: QuotationRow[];
  orders: UpsaleOrderRow[];
  quoteStatus: (code: string) => string;
}) {
  const rows: DocumentRow[] = [
    ...quotes.map((q) => ({
      id: q.id,
      code: q.code,
      to: `/crm/bao-gia/${q.id}`,
      type: 'Báo giá' as const,
      status: quoteStatus(q.display_status_code),
      total_amount: q.total_amount,
      created_at: q.created_at,
    })),
    ...orders.map((o) => ({
      id: o.id,
      code: o.code,
      to: `/crm/don-hang/${o.id}`,
      type: 'Đơn hàng' as const,
      status: ORDER_STATUS[o.status_code] ?? o.status_code,
      total_amount: o.total_amount,
      created_at: o.created_at,
    })),
  ];
  return (
    <LineTable
      caption="Báo giá và đơn của phiếu"
      rows={rows}
      rowKey={(r) => r.id}
      empty={<p className="p-3 text-fg-muted">Chưa có báo giá hay đơn tái tục nào.</p>}
      columns={[
        {
          key: 'code',
          header: 'Số',
          cell: (r) => (
            <FromLink className="font-medium text-link hover:underline" to={r.to}>
              {r.code}
            </FromLink>
          ),
        },
        { key: 'type', header: 'Loại', cell: (r) => r.type },
        { key: 'status', header: 'Trạng thái', cell: (r) => r.status },
        {
          key: 'amount',
          header: 'Số tiền',
          align: 'right',
          cell: (r) => formatMoney(r.total_amount),
        },
        { key: 'date', header: 'Ngày', cell: (r) => formatDate(r.created_at) },
        { key: 'paid', header: 'Đã thu', align: 'right', cell: () => NO_DATA },
      ]}
    />
  );
}
