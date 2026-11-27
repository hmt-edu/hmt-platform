// TT-02 Phiếu tái tục (bản ghi, khuôn K06; canvas 9933 TT02_*): thanh giai đoạn chỉ đọc (đổi bằng nút «Chuyển giai đoạn»), thông tin phụ huynh, học sinh, lớp,
// giờ còn, ngày hết giờ dự kiến, hai ô tự do (Mục tiêu/nhu cầu tiếp theo, Lộ trình tiếp theo), tab Giờ học, Báo giá và đơn (làm ở PR sau), Tình hình học tập (mờ, chưa dùng).
// Giao diện KHÔNG tính giờ, không tự đoán quyền: số liệu và việc làm được do get_upsale_ticket trả. Điện thoại chỉ đọc (Đ248).
import { useCrumbTail } from '../../layout/CrumbTail';
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { RecordDetail, DetailField } from '../../record/Detail';
import { HmtError, errorOf, useDb, useIntSetting } from '../../lib/db';
import {
  formatDate,
  formatDateTime,
  formatMoney,
  formatMonth,
  formatNumber,
} from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Chatter } from '../../ui/Chatter';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextAreaField } from '../../ui/Field';
import { Tabs } from '../../ui/Overlays';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { formatPhone } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { AssignUpsaleDialog } from './AssignUpsaleDialog';
import { ChangeUpsaleStageDialog } from './ChangeUpsaleStageDialog';
import { CreateUpsaleOrderDialog } from './CreateUpsaleOrderDialog';
import { upsaleEventEntries } from './upsaleEventEntries';
import { upsaleStageNote } from './upsaleNotes';
import type { UpsaleOrderRow, UpsaleRecord } from './upsaleTypes';
import {
  saveUpsaleNotes,
  useRefreshUpsaleRecord,
  useUpsaleOrders,
  useUpsaleRecord,
} from './useUpsaleData';
import { FromLink } from '../../layout/FromLink';

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
  const [tab, setTab] = useState('overview');
  const [dialog, setDialog] = useState<'stage' | 'assign' | 'order' | null>(null);
  const [goal, setGoal] = useState(t.next_goal ?? '');
  const [roadmap, setRoadmap] = useState(t.next_roadmap ?? '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const orders = useUpsaleOrders(t.id);
  const can = (a: UpsaleRecord['actions'][number]) => record.actions.includes(a) && !phone;
  // Tạo đơn: phiếu ở L6, cần cả quyền Đơn hàng · Tạo và Phiếu tái tục · Sửa (máy chủ kiểm lại từng bước).
  const canCreateOrder =
    t.stage_code === 'L6' &&
    can('doi_giai_doan') &&
    access.can('SALES_ORDER', 'TAO') &&
    access.featureOn('BAN_HANG');
  const dirty = goal !== (t.next_goal ?? '') || roadmap !== (t.next_roadmap ?? '');
  const forbiddenAll = !access.can('UPSALE', 'XEM');

  const steps: StageStep[] = catalogs.options('UPSALE_STAGE').map((o) => ({
    code: o.value,
    label: o.label,
    fullLabel: `${o.value} ${o.label}`,
    ...(o.value === 'L7' || o.value === 'L8'
      ? { lockedReason: 'Hệ thống tự chuyển khi có báo giá, đơn.' }
      : {}),
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

  const stageNote = upsaleStageNote(
    t,
    t.lost_reason_code
      ? (catalogs.name('RENEWAL_LOST_REASON', t.lost_reason_code) ?? t.lost_reason_code)
      : null,
    { hours: hoursThreshold, days: daysThreshold },
  );

  const overview = (
    <div className="flex flex-col gap-6">
      {stageNote && <Alert tone={stageNote.tone}>{stageNote.text}</Alert>}
      {t.risk_flag && (
        <Alert tone="warning">
          Học sinh vắng từ{' '}
          {record.hours.window_days > 0 ? `${record.hours.absences_window} buổi` : ''} trong{' '}
          {record.hours.window_days} ngày gần nhất ở lớp này (cờ rủi ro).
        </Alert>
      )}
      <section className="grid grid-cols-1 gap-x-8 lg:grid-cols-2">
        <dl className="flex min-w-0 flex-col">
          <DetailField label="Phiếu tái tục" mode="view" value={t.code} />
          <DetailField label="Học sinh" mode="view" value={record.student?.name ?? ''} />
          <DetailField label="Mã học sinh" mode="view" value={record.student?.code ?? ''} />
          <DetailField label="Lớp" mode="view" value={record.class.code} />
          <DetailField
            label="Giáo viên lớp hiện tại"
            mode="view"
            value={record.class.teacher_name ?? ''}
          />
          <DetailField
            label={`Ghi danh liên quan (${record.enrollments.length})`}
            mode="view"
            value={
              record.enrollments.length === 0
                ? ''
                : record.enrollments
                    .map((e) => `${e.code} · còn ${formatNumber(e.hours_left)} giờ`)
                    .join('; ')
            }
          />
        </dl>
        <dl className="flex min-w-0 flex-col">
          <DetailField label="Phụ huynh" mode="view" value={record.parent?.name ?? ''} />
          <DetailField
            label="Số điện thoại"
            mode="view"
            value={record.parent ? formatPhone(record.parent.phone) : ''}
          />
          <DetailField label="Email" mode="view" value={record.parent?.email ?? ''} />
          <DetailField
            label="Giờ còn"
            mode="view"
            value={t.hours_left === null ? '' : `${formatNumber(t.hours_left)} giờ`}
          />
          <DetailField
            label="Ngày hết giờ dự kiến"
            mode="view"
            value={t.expected_end_date ? formatDate(t.expected_end_date) : ''}
          />
        </dl>
      </section>
      <section className="flex flex-col gap-3">
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
      </section>
    </div>
  );

  const hours = (
    <dl className="flex flex-col">
      <DetailField
        label="Đã mua (gồm giờ tặng)"
        mode="view"
        value={`${formatNumber(record.hours.bought)} giờ`}
      />
      <DetailField
        label="Đã mua gần nhất"
        mode="view"
        value={
          record.hours.last_purchase
            ? `${formatNumber(record.hours.last_purchase.hours)} giờ · ${formatMonth(record.hours.last_purchase.at)}`
            : ''
        }
      />
      <DetailField label="Đã học" mode="view" value={`${formatNumber(record.hours.used)} giờ`} />
      <DetailField
        label={`Vắng ${record.hours.window_days} ngày`}
        mode="view"
        value={`${record.hours.absences_window} buổi`}
      />
      <DetailField label="Campaign" mode="view" value={t.campaign_label ?? ''} />
    </dl>
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
        stageNote="Stage chỉ đọc, đổi bằng nút bên dưới."
        subStage={
          t.substage_code ? (
            <span className="text-caption text-fg-label">
              Sub-stage: {t.substage_code} {catalogs.name('UPSALE_SUBSTAGE', t.substage_code) ?? ''}
            </span>
          ) : undefined
        }
        businessActions={
          <span className="flex flex-wrap items-center gap-2">
            {can('doi_giai_doan') && (
              <Button variant="primary" onClick={() => setDialog('stage')}>
                Chuyển giai đoạn
              </Button>
            )}
            {canCreateOrder && (
              <Button variant="primary" onClick={() => setDialog('order')}>
                Tạo đơn
              </Button>
            )}
            {can('giao') && <Button onClick={() => setDialog('assign')}>Giao</Button>}
          </span>
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
            count: 0,
            unavailable: 'Làm ở PR sau (tạo báo giá từ phiếu)',
            onOpen: () => undefined,
          },
          {
            key: 'don-hang',
            label: 'Đơn hàng',
            icon: 'payment',
            count: orders.data?.length ?? 0,
            unavailable: 'Phiếu chưa có đơn',
            onOpen: () => setTab('quotes'),
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
          {t.stage_code === 'L6' && (
            <Alert tone="info">
              Phụ huynh đã đồng ý tái tục. Tạo báo giá hoặc tạo đơn từ phiếu này; gửi báo giá thì
              phiếu sang L7 Dự thu.
            </Alert>
          )}
          {t.stage_code === 'L5' && (
            <Alert tone="info">
              Không tái tục:{' '}
              {catalogs.name('RENEWAL_LOST_REASON', t.lost_reason_code) ??
                t.lost_reason_code ??
                '—'}
              {t.lost_note ? `. ${t.lost_note}` : ''} ·{' '}
              {t.closed_at ? formatDateTime(t.closed_at) : ''}
            </Alert>
          )}
          <Tabs
            label="Phiếu tái tục"
            value={tab}
            onChange={setTab}
            items={[
              { value: 'overview', label: 'Tổng quan', content: overview },
              { value: 'hours', label: 'Giờ học', content: hours },
              {
                value: 'quotes',
                label: 'Báo giá và đơn',
                content: <OrdersTab orders={orders.data ?? []} />,
              },
              {
                value: 'learning',
                label: 'Tình hình học tập',
                content: <p className="text-fg-muted">Tab này bật ở giai đoạn Giáo viên.</p>,
              },
            ]}
          />
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

/** Tab «Báo giá và đơn»: đơn sinh ra từ phiếu (báo giá từ phiếu làm ở PR sau). */
function OrdersTab({ orders }: { orders: UpsaleOrderRow[] }) {
  if (orders.length === 0)
    return (
      <p className="text-fg-muted">Chưa có báo giá hay đơn tái tục. Tạo từ các nút phía trên.</p>
    );
  return (
    <ul className="flex flex-col gap-2">
      {orders.map((o) => (
        <li key={o.id} className="flex flex-wrap items-center gap-2">
          <FromLink className="font-medium text-link hover:underline" to={`/crm/don-hang/${o.id}`}>
            {o.code}
          </FromLink>
          <span className="text-fg-muted">
            {ORDER_STATUS[o.status_code] ?? o.status_code} · {formatMoney(o.total_amount)} ·{' '}
            {formatDate(o.created_at)}
          </span>
        </li>
      ))}
    </ul>
  );
}
