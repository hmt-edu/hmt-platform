// TT-02 Phiếu tái tục (bản ghi, khuôn K06, cùng cách dùng với bản ghi Cơ hội; anh Trường chốt 28/11): thanh giai đoạn bấm được («Không tái tục» cuối), Sub-stage,
// nút Tạo báo giá, Tạo đơn, Giao, rồi một trang: Tái tục của, Cần tái tục, Quản lý phiếu, Mốc thời gian. Số máy chủ chưa trả thì ghi «chưa có dữ liệu», không tự tính.
// Giao diện KHÔNG tính giờ, không tự đoán quyền: số liệu và việc làm được do get_upsale_ticket trả. Điện thoại chỉ đọc (Đ248).
import { useCrumbTail } from '../../layout/CrumbTail';
import { useState, type ReactNode } from 'react';
import { Link, useParams } from 'react-router';
import { RecordDetail, DetailField, DetailSection, type SmartItem } from '../../record/Detail';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { formatDate, formatDateTime, formatMoney, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Chatter } from '../../ui/Chatter';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Select } from '../../ui/Overlays';
import { Tag } from '../../ui/Data';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { weekdayLabel } from '../ghi-danh/enrollLogic';
import { codeAndName } from '../lead/leadFormat';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { AssignUpsaleDialog } from './AssignUpsaleDialog';
import { ChangeUpsaleStageDialog } from './ChangeUpsaleStageDialog';
import { CreateUpsaleOrderDialog } from './CreateUpsaleOrderDialog';
import { upsaleEventEntries } from './upsaleEventEntries';
import { lastAssignedAt, monthOf, orderStages } from './upsaleStages';
import type { UpsaleRecord } from './upsaleTypes';
import {
  changeUpsaleStage,
  useRefreshUpsaleRecord,
  useUpsaleOrders,
  useUpsaleQuotes,
  useUpsaleRecord,
} from './useUpsaleData';
import { useNavigateFrom } from '../../layout/crumbTrail';

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
  const phone = useMedia(NARROW_TABLE);
  const t = record.ticket;
  useCrumbTail(t.code);
  const refresh = useRefreshUpsaleRecord(t.id);
  const openFrom = useNavigateFrom();
  const [moveTo, setMoveTo] = useState<string | null>(null);
  const [dialog, setDialog] = useState<'assign' | 'order' | null>(null);
  const can = (a: UpsaleRecord['actions'][number]) => record.actions.includes(a) && !phone;
  const salesOn = access.featureOn('BAN_HANG');
  // Báo giá tạo ở mọi giai đoạn; đơn chỉ ở L8, không giới hạn số đơn (R-GD-13). Máy chủ trả việc làm được và kiểm lại.
  const canCreateQuote = can('tao_bao_gia') && salesOn;
  const canCreateOrder = can('tao_don') && salesOn;
  // Như bản ghi Cơ hội: người có quyền tạo đơn vẫn thấy nút, mờ kèm lý do khi phiếu chưa ở L8.
  const showOrderButton =
    canCreateOrder ||
    (salesOn && t.stage_code !== 'L8' && can('doi_giai_doan') && access.can('SALES_ORDER', 'TAO'));
  const canSeeQuotes = access.can('QUOTATION', 'XEM');
  const quotes = useUpsaleQuotes(t.id, canSeeQuotes);
  const orders = useUpsaleOrders(t.id);
  const quoteCount = quotes.data?.total ?? 0;
  const orderCount = orders.data?.length ?? 0;
  const forbiddenAll = !access.can('UPSALE', 'XEM');

  const stageName = (code: string) => codeAndName(code, catalogs.name('UPSALE_STAGE', code));
  const substageName = (code: string) => codeAndName(code, catalogs.name('UPSALE_SUBSTAGE', code));
  const steps: StageStep[] = orderStages(catalogs.options('UPSALE_STAGE')).map((o) => ({
    code: o.value,
    label: o.label,
  }));
  const substageOptions = catalogs
    .options('UPSALE_SUBSTAGE')
    .filter((o) => o.value.startsWith(t.stage_code))
    .map((o) => ({ value: o.value, label: substageName(o.value) }));

  async function changeSubstage(next: string) {
    try {
      await changeUpsaleStage(supabase, t.id, t.stage_code, null, null, next);
      await refresh();
      toast({ title: 'Đã đổi Sub-stage.' });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    }
  }

  /** Một bản ghi thì mở thẳng; nhiều thì mở danh sách đã lọc theo phiếu (K3, nút số đếm). */
  function openDocuments(path: string, ids: string[], count: number) {
    const only = count === 1 ? ids[0] : undefined;
    openFrom(only ? `${path}/${only}` : `${path}?phieu=${t.id}&ma=${encodeURIComponent(t.code)}`);
  }

  const smart: SmartItem[] = [
    {
      key: 'hoc-sinh',
      label: 'Học sinh',
      icon: 'user',
      count: record.student ? 1 : 0,
      onOpen: () => openFrom(`/crm/hoc-sinh/${t.student_id}`),
    },
    {
      key: 'phu-huynh',
      label: 'Phụ huynh',
      icon: 'user',
      count: record.parent ? 1 : 0,
      onOpen: () => openFrom(`/crm/phu-huynh/${record.parent?.id}`),
    },
    {
      key: 'lop',
      label: 'Lớp',
      icon: 'classes',
      count: 1,
      onOpen: () => openFrom(`/crm/lop/${t.class_id}`),
    },
    {
      key: 'ghi-danh',
      label: 'Ghi danh',
      icon: 'classes',
      count: record.enrollments.length,
      // Nhiều ghi danh: hồ sơ học sinh liệt kê đủ.
      onOpen: () => {
        const only = record.enrollments.length === 1 ? record.enrollments[0] : undefined;
        openFrom(only ? `/crm/ghi-danh/${only.id}` : `/crm/hoc-sinh/${t.student_id}`);
      },
    },
    {
      key: 'bao-gia',
      label: 'Báo giá',
      icon: 'payment',
      count: quoteCount,
      hidden: !canSeeQuotes,
      onOpen: () =>
        openDocuments(
          '/crm/bao-gia',
          (quotes.data?.rows ?? []).map((q) => q.id),
          quoteCount,
        ),
    },
    {
      key: 'don-hang',
      label: 'Đơn hàng',
      icon: 'file',
      count: orderCount,
      hidden: !access.can('SALES_ORDER', 'XEM'),
      onOpen: () =>
        openDocuments(
          '/crm/don-hang',
          (orders.data ?? []).map((o) => o.id),
          orderCount,
        ),
    },
  ];

  const hours = record.hours;
  const purchase = hours.last_purchase;
  const assignedAt = lastAssignedAt(record.events);
  const subjects = [
    ...new Set(
      record.enrollments.flatMap((e) =>
        e.subject_code ? [catalogs.name('SUBJECT', e.subject_code) ?? e.subject_code] : [],
      ),
    ),
  ].join(', ');
  const schedule = record.class.slots
    .map((s) => `${weekdayLabel(s.weekday)} ${s.start_time.slice(0, 5)}-${s.end_time.slice(0, 5)}`)
    .join('; ');
  const hoursText = (n: number) => `${formatNumber(n)} giờ`;
  const field = (label: string, value: ReactNode) => (
    <DetailField label={label} mode="view" value={value} />
  );

  return (
    <>
      <RecordDetail
        kind="Phiếu tái tục"
        title={t.code}
        mode="view"
        readOnly={!can('doi_giai_doan')}
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        onRefresh={() => refresh()}
        headerActions={
          can('giao') ? (
            <Button icon="user" onClick={() => setDialog('assign')}>
              Giao
            </Button>
          ) : undefined
        }
        stage={
          steps.length > 0
            ? {
                steps,
                current: t.stage_code,
                forwardOnly: false,
                onSelect: (step) => {
                  if (step.code !== t.stage_code) setMoveTo(step.code);
                },
              }
            : undefined
        }
        businessActions={
          canCreateQuote || showOrderButton ? (
            <>
              {canCreateQuote && (
                <Button
                  variant={canCreateOrder ? 'secondary' : 'primary'}
                  onClick={() => openFrom(`/crm/bao-gia/tao?phieu=${t.id}`)}
                >
                  Tạo báo giá
                </Button>
              )}
              {showOrderButton && (
                <Button
                  variant={canCreateOrder ? 'primary' : 'secondary'}
                  disabled={!canCreateOrder}
                  title={canCreateOrder ? undefined : 'Chỉ tạo đơn khi phiếu ở L8'}
                  onClick={() => setDialog('order')}
                >
                  Tạo đơn
                </Button>
              )}
            </>
          ) : undefined
        }
        subStage={
          substageOptions.length > 0 || t.substage_code ? (
            <>
              <span className="text-caption font-semibold text-fg-label">Sub-stage</span>
              <Select
                label="Sub-stage"
                value={t.substage_code ?? ''}
                onChange={(v) => void changeSubstage(v)}
                options={substageOptions}
                placeholder="Chưa có"
                // Giai đoạn con của L8 do hệ thống đặt theo đơn của phiếu.
                disabled={!can('doi_giai_doan') || t.stage_code === 'L8'}
              />
            </>
          ) : undefined
        }
        smart={smart}
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
        {forbiddenAll && <Alert tone="danger">Bạn không có quyền xem phiếu tái tục.</Alert>}
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Tái tục của">
            {field('Học sinh', record.student?.name ?? '')}
            {field('Mã học sinh', record.student?.code ?? '')}
            {field('Phụ huynh', record.parent?.name ?? '')}
            {field('Số điện thoại', record.parent ? formatPhone(record.parent.phone) : '')}
            {field('Email', record.parent?.email || <span className="text-fg-muted">Chưa có</span>)}
            {field('Lớp', record.class.code)}
            {field('Môn', subjects)}
            {field('Giáo viên', record.class.teacher_name ?? '')}
            {field('Cơ sở', t.branch_code)}
            {field('Lịch học', schedule)}
          </DetailSection>
          <DetailSection title="Cần tái tục">
            {field('Giờ còn', t.hours_left === null ? '' : hoursText(t.hours_left))}
            {field('Giờ tặng', hoursText(hours.gifted))}
            {field(
              'Buổi còn',
              hours.sessions_left === null ? '' : `${formatNumber(hours.sessions_left)} buổi`,
            )}
            {field(
              'Ngày hết giờ dự kiến',
              t.expected_end_date ? formatDate(t.expected_end_date) : '',
            )}
            {field('Campaign', monthOf(t.expected_end_date))}
            {field(
              `Vắng ${hours.window_days} ngày`,
              <>
                {hours.absences_window} buổi{' '}
                {t.risk_flag && (
                  <Tag tone="warning" dot>
                    Cờ rủi ro
                  </Tag>
                )}
              </>,
            )}
            {field('Mua gần nhất: ngày', purchase ? formatDate(purchase.at) : '')}
            {field('Mua gần nhất: gói', purchase?.package_name ?? '')}
            {field(
              'Mua gần nhất: đơn giá',
              purchase && purchase.unit_price !== null ? formatMoney(purchase.unit_price) : '',
            )}
          </DetailSection>
          <DetailSection title="Quản lý phiếu">
            {field('CSKH phụ trách', t.owner_name ?? 'chưa giao')}
            {field('Giai đoạn', stageName(t.stage_code))}
            {field('Sub-stage', t.substage_code ? substageName(t.substage_code) : '')}
          </DetailSection>
          <DetailSection title="Mốc thời gian">
            {field(
              'Ngày tạo',
              `${formatDateTime(t.created_at)}${t.created_by_name ? ` · ${t.created_by_name}` : ''}`,
            )}
            {field('Cập nhật lần cuối', NO_DATA)}
            {field('Ngày giao', assignedAt ? formatDateTime(assignedAt) : '')}
          </DetailSection>
        </div>
      </RecordDetail>
      {moveTo && (
        <ChangeUpsaleStageDialog
          open
          onOpenChange={(o) => !o && setMoveTo(null)}
          ticket={t}
          target={moveTo}
          onDone={async () => {
            await refresh();
            toast({ title: `Đã chuyển sang ${stageName(moveTo)}.` });
          }}
        />
      )}
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
