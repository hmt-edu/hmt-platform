// GD-02 Ghi danh (bản ghi, khuôn K06, chỉ đọc; bố cục anh Trường chốt 28/11): một trang cuộn, không tab: ba khối thông tin (Học sinh và phụ huynh; Gói và đơn hàng;
// Lớp và thời gian), bốn ô số quỹ giờ, dòng xếp lớp, sổ giờ gần nhất. Ô trống hiện «—». Tình trạng đổi bằng nút nghiệp vụ, không bấm trên Stage. Nút Xếp lớp (khi
// Chờ xếp lớp), Điều chỉnh giờ (GD-05). Chưa làm: Tạo ticket (CS-04). Giao diện không tính giờ: số do hàm DB trả.
import { useParams } from 'react-router';
import { useState, type ReactNode } from 'react';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf } from '../../lib/db';
import { formatDate, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, RecordDetail } from '../../record/Detail';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { LineTable } from '../../ui/LineTable';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import type { StageStep } from '../../ui/Stage';
import { AdjustHoursDialog } from './AdjustHoursDialog';
import { AssignClassDialog } from './AssignClassDialog';
import { statusTone } from './enrollConfig';
import { enrollmentNotice } from './enrollLogic';
import { useEnrollmentLedger, useEnrollmentRecord, useSameClassPeers } from './useEnrollmentData';
import { FromLink } from '../../layout/FromLink';

const END_REASON: Record<string, string> = {
  CHUYEN_LOP: 'Đã chuyển lớp',
  DUNG: 'Dừng',
  KET_THUC: 'Kết thúc',
  NHAP_NHAM: 'Nhập nhầm',
  HOAN_PHI: 'Đã rời lớp',
};

// Bốn giai đoạn chính; bảo lưu, chuyển lớp, dừng, hoàn phí hiện bằng thẻ tình trạng (R-GD-05, R-GD-16).
const STEPS: StageStep[] = [
  { code: 'CHO_XEP_LOP', label: 'Chờ xếp lớp' },
  { code: 'DA_XEP_LOP', label: 'Đã xếp lớp' },
  { code: 'DANG_HOC', label: 'Đang học' },
  { code: 'HOAN_THANH', label: 'Hoàn thành' },
];

// Tên trường và giá trị trong lịch sử thay đổi (không hiện mã thô như CHO_XEP_LOP).
const CHATTER_FORMAT = {
  labels: { status_code: 'Tình trạng', start_date: 'Start Date', end_date: 'End Date' },
  value: (column: string, value: unknown): string | null =>
    column === 'status_code' ? (STEPS.find((x) => x.code === value)?.label ?? null) : null,
};

export function EnrollmentRecordPage() {
  const { id } = useParams();
  const query = useEnrollmentRecord(id);
  const peers = useSameClassPeers(id).data;
  const access = useAccess();
  const openFrom = useNavigateFrom();
  const [assigning, setAssigning] = useState(false);
  const [adjusting, setAdjusting] = useState(false);
  useCrumbTail(query.data ? query.data.enrollment.code : null);

  if (query.isPending) return <Spinner />;
  if (query.isError) {
    const err = errorOf(query.error);
    return (
      <StateView
        kind={err.code === 'HMT_KHONG_CO_QUYEN' ? 'forbidden' : 'not-found'}
        title={
          err.code === 'HMT_KHONG_CO_QUYEN'
            ? 'Bạn không có quyền xem ghi danh này'
            : 'Không tìm thấy ghi danh'
        }
      >
        {err.message}
      </StateView>
    );
  }
  const { enrollment: e, hours, classes } = query.data;
  const field = (label: string, value: ReactNode) => (
    <DetailField
      label={label}
      mode="view"
      value={value || <span className="text-fg-muted">—</span>}
    />
  );
  const inStages = STEPS.some((s) => s.code === e.status_code);
  const canAssign = e.status_code === 'CHO_XEP_LOP' && access.can('ENROLLMENT', 'SUA');
  // Điều chỉnh giờ (GD-05, R-GD-04): Ghi danh · Duyệt (Trưởng cơ sở, Admin) hoặc Kế toán · Duyệt (Kế toán).
  const canAdjust = access.can('ENROLLMENT', 'DUYET') || access.can('ACCOUNTING', 'DUYET');
  const notice = enrollmentNotice(e.status_code, hours, {
    holdStart: e.hold_start,
    holdEnd: e.hold_end,
    refundVoucher: e.refund_voucher_code,
  });
  return (
    <>
      <RecordDetail
        kind="Ghi danh"
        title={e.code}
        mode="view"
        readOnly
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        stageShowCode={false}
        stage={{
          steps: STEPS,
          current: inStages ? e.status_code : '',
          forwardOnly: true,
          onSelect: () => undefined,
        }}
        stageNote="Tình trạng chỉ đọc, đổi bằng nút bên dưới."
        aside={
          <RecordChatter
            entityType="ENROLLMENT"
            entityId={e.id}
            format={CHATTER_FORMAT}
            createdText="Tạo ghi danh."
            canWrite
          />
        }
        businessActions={
          <span className="flex flex-wrap items-center gap-2">
            {canAssign && (
              <Button variant="primary" onClick={() => setAssigning(true)}>
                Xếp lớp
              </Button>
            )}
            {canAdjust && <Button onClick={() => setAdjusting(true)}>Điều chỉnh giờ</Button>}
            {!inStages && <Tag tone={statusTone(e.status_code)}>{e.status_name}</Tag>}
          </span>
        }
        smart={[
          {
            key: 'hoc-sinh',
            label: 'Học sinh',
            icon: 'user',
            count: 1,
            onOpen: () => openFrom(`/crm/hoc-sinh/${e.student_id}`),
          },
          {
            key: 'don-hang',
            label: 'Đơn hàng',
            icon: 'file',
            count: e.order_id ? 1 : 0,
            ...(e.order_id
              ? { onOpen: () => openFrom(`/crm/don-hang/${e.order_id ?? ''}`) }
              : {
                  unavailable: 'Ghi danh nạp từ hệ thống cũ, không có đơn',
                  onOpen: () => undefined,
                }),
          },
        ]}
      >
        <div className="flex flex-col gap-5">
          <InfoBlock title="Học sinh và phụ huynh">
            {field('Học sinh', e.student_name)}
            {field('Mã học sinh', e.student_code)}
            {field('Phụ huynh', e.parent_name)}
            {field('Mã phụ huynh', e.parent_code)}
          </InfoBlock>
          <InfoBlock title="Gói và đơn hàng">
            {field('Gói', e.package_code)}
            {field('Hình thức học', e.delivery_mode_name)}
            {field(
              'Đơn hàng',
              e.order_id && e.order_code ? (
                <FromLink to={`/crm/don-hang/${e.order_id}`} className="text-link hover:underline">
                  {e.order_code}
                </FromLink>
              ) : null,
            )}
            {e.legacy_ref && field('Mã cũ', e.legacy_ref)}
          </InfoBlock>
          <div className="flex flex-col gap-1">
            <InfoBlock title="Lớp và thời gian">
              {field('Cơ sở', `${e.branch_code} ${e.branch_name}`)}
              {field('Tình trạng', e.status_name)}
              {field('Ngày ghi danh', formatDate(e.enrolled_on))}
              {field('Ngày bắt đầu', e.start_date ? formatDate(e.start_date) : null)}
            </InfoBlock>
            {/* Số dự báo gom một dòng nhỏ; chưa có lớp thì không có ngày kết thúc dự kiến (anh Trường 28/11). */}
            <p className="text-caption text-fg-muted">
              Dự báo (không chặn gì): ngày kết thúc dự kiến{' '}
              {classes.length === 0
                ? 'Chưa có lớp'
                : e.expected_end_date
                  ? formatDate(e.expected_end_date)
                  : '—'}{' '}
              · hạn gói {e.package_deadline ? formatDate(e.package_deadline) : '—'}
            </p>
          </div>

          {notice && (
            <Alert tone={notice.tone} title={notice.title}>
              {notice.text}
            </Alert>
          )}
          <section aria-label="Quỹ giờ" className="flex flex-col gap-2">
            <h3 className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
              Quỹ giờ
            </h3>
            <dl className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              <HourTile label="Giờ cấp" value={formatNumber(hours.granted)} />
              <HourTile label="Giờ tặng" value={formatNumber(hours.gifted)} />
              <HourTile label="Đã học" value={formatNumber(hours.used)} />
              <HourTile label="Còn lại" value={`${formatNumber(hours.remaining)} giờ`} />
            </dl>
          </section>

          <section className="flex flex-col gap-2" aria-labelledby="gd02-classes">
            <h3
              id="gd02-classes"
              className="text-caption font-semibold tracking-wide text-fg-muted uppercase"
            >
              Lớp đang học và lịch sử chuyển lớp (dòng xếp lớp)
            </h3>
            {classes.length === 0 ? (
              <p className="text-body text-fg-muted">
                Chưa có dòng xếp lớp. Bấm Xếp lớp để chọn lớp và ngày vào lớp.
              </p>
            ) : (
              <div className="overflow-x-auto rounded-control border border-border">
                <table aria-label="Dòng xếp lớp" className="w-full text-body">
                  <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
                    <tr>
                      <th className="px-3 py-2">Lớp</th>
                      <th className="px-3 py-2">Ngày vào</th>
                      <th className="px-3 py-2">Ngày rời</th>
                      <th className="px-3 py-2 text-right">Giờ đã học tại lớp</th>
                      <th className="px-3 py-2">Tình trạng</th>
                    </tr>
                  </thead>
                  <tbody>
                    {classes.map((c) => (
                      <tr key={`${c.class_id}-${c.start_date}`} className="border-t border-border">
                        <td className="px-3 py-2">{c.class_code}</td>
                        <td className="px-3 py-2">{formatDate(c.start_date)}</td>
                        <td className="px-3 py-2">{c.end_date ? formatDate(c.end_date) : '—'}</td>
                        <td className="px-3 py-2 text-right tabular">
                          {formatNumber(c.studied_hours)}
                        </td>
                        <td className="px-3 py-2">
                          {c.end_reason ? (END_REASON[c.end_reason] ?? c.end_reason) : 'Đang học'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            {peers && peers.peers.length > 0 && (
              <p className="text-body">
                Học sinh có {peers.peers.length + 1} ghi danh ở lớp này ({e.code} còn{' '}
                {formatNumber(hours.remaining)} giờ
                {peers.peers
                  .map((p) => `, ${p.code} còn ${formatNumber(p.remaining)} giờ`)
                  .join('')}
                ). Giờ còn của lớp = tổng các ghi danh:{' '}
                <b>{formatNumber(peers.total_remaining ?? 0)} giờ</b>.
              </p>
            )}
          </section>

          <section aria-label="Sổ giờ gần nhất" className="flex flex-col gap-2">
            <h3 className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
              Sổ giờ gần nhất
            </h3>
            <RecentLedger enrollmentId={e.id} />
            <div>
              <Button onClick={() => openFrom(`/crm/ghi-danh/${e.id}/so-gio`)}>
                Xem sổ đầy đủ
              </Button>
            </div>
          </section>
        </div>
      </RecordDetail>
      <AdjustHoursDialog
        enrollmentId={e.id}
        remaining={hours.remaining}
        open={adjusting}
        onClose={() => setAdjusting(false)}
      />
      <AssignClassDialog
        enrollmentId={assigning ? e.id : null}
        onClose={() => setAssigning(false)}
      />
    </>
  );
}

/** Một khối thông tin của bản ghi, hai cột trên màn rộng (dt, dd chỉ lồng một lớp div trong dl). */
function InfoBlock({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section aria-label={title} className="flex min-w-0 flex-col">
      <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
        {title}
      </h3>
      <dl className="grid grid-cols-1 gap-x-8 md:grid-cols-2">{children}</dl>
    </section>
  );
}

function HourTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-1 rounded-card border border-border bg-surface p-3">
      <dt className="text-caption font-semibold tracking-wide text-fg-muted uppercase">{label}</dt>
      <dd className="tabular font-display text-display">{value}</dd>
    </div>
  );
}

/** Bốn dòng gần nhất của sổ giờ (khung GD02); nút mở sổ đầy đủ nằm ngay dưới. */
const RECENT_LEDGER_ROWS = 4; // allow-number: số dòng sổ giờ xem nhanh ở bản ghi (canvas GD02)
function RecentLedger({ enrollmentId }: { enrollmentId: string }) {
  const ledger = useEnrollmentLedger(enrollmentId, 0, RECENT_LEDGER_ROWS);
  if (ledger.isPending) return <Spinner />;
  if (ledger.isError) return <p className="text-fg-muted">{errorOf(ledger.error).message}</p>;
  if (ledger.data.rows.length === 0) {
    return <p className="py-2 text-fg-muted">Chưa có dòng nào trong sổ giờ.</p>;
  }
  return (
    <LineTable
      caption="Sổ giờ gần đây"
      rows={ledger.data.rows}
      rowKey={(r) => r.id}
      columns={[
        { key: 'date', header: 'Ngày', cell: (r) => formatDate(r.on_date) },
        { key: 'type', header: 'Loại', cell: (r) => r.entry_name },
        {
          key: 'source',
          header: 'Nguồn',
          cell: (r) =>
            [
              r.class_code,
              r.session_no ? `Buổi ${r.session_no}` : null,
              r.session_date ? formatDate(r.session_date) : null,
              r.reason_name ? `Lý do: ${r.reason_name}` : null,
            ]
              .filter(Boolean)
              .join(' · ') || '—',
        },
        { key: 'hours', header: 'Giờ +/−', align: 'right', cell: (r) => formatNumber(r.hours) },
        {
          key: 'balance',
          header: 'Số dư (giờ)',
          align: 'right',
          cell: (r) => formatNumber(r.balance),
        },
      ]}
    />
  );
}
