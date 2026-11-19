// GD-02 Ghi danh (bản ghi, khuôn K06, chỉ đọc): thông tin ghi danh, quỹ giờ (cấp, tặng, đã học, còn lại), dòng xếp lớp và lịch sử chuyển lớp, nút Xếp lớp (khi Chờ xếp lớp)
// và Sổ giờ. Tình trạng đổi bằng nút nghiệp vụ, không bấm trên Stage. Điều chỉnh giờ (GD-05, Ghi danh · Duyệt). Chưa làm ở cụm này: Tạo ticket (CS-04, sau 17/11), "Tạo phiếu thu tái tục thủ
// công" (TT-03 đã bỏ). Ngày hết giờ dự kiến, hạn gói (chỉ dự báo) chưa tính: hiện "—". Giao diện không tính giờ: số do hàm DB trả.
import { Link, useParams } from 'react-router';
import { useState } from 'react';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf } from '../../lib/db';
import { formatDate, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { Button } from '../../ui/Button';
import { CustTabs } from '../khach-hang/CustTabs';
import { Tag } from '../../ui/Data';
import { LineTable } from '../../ui/LineTable';
import { Spinner, StateView } from '../../ui/Feedback';
import type { StageStep } from '../../ui/Stage';
import { AdjustHoursDialog } from './AdjustHoursDialog';
import { AssignClassDialog } from './AssignClassDialog';
import { statusTone } from './enrollConfig';
import { useEnrollmentLedger, useEnrollmentRecord, useSameClassPeers } from './useEnrollmentData';

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
  const [tab, setTab] = useState('fund');
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
  const { enrollment: e, hours, classes, tickets } = query.data;
  const view = 'view' as const;
  const inStages = STEPS.some((s) => s.code === e.status_code);
  const canAssign = e.status_code === 'CHO_XEP_LOP' && access.can('ENROLLMENT', 'SUA');
  // Điều chỉnh giờ: chỉ Ghi danh · Duyệt (Trưởng cơ sở, Admin), GD-05, R-GD-04.
  const canAdjust = access.can('ENROLLMENT', 'DUYET');
  return (
    <>
      <RecordDetail
        kind="Ghi danh"
        title={e.code}
        mode={view}
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
            <Button onClick={() => openFrom(`/crm/ghi-danh/${e.id}/so-gio`)}>Sổ giờ</Button>
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
          {
            key: 'ticket',
            label: 'Ticket',
            icon: 'service',
            count: tickets,
            unavailable: 'Ticket làm sau 17/11',
            onOpen: () => undefined,
          },
        ]}
      >
        <div className="grid gap-6 md:grid-cols-2">
          <DetailSection title="Thông tin ghi danh">
            <DetailField
              label="Ghi danh"
              mode={view}
              value={e.legacy_ref ? `${e.code} · mã cũ ${e.legacy_ref}` : e.code}
            />
            <DetailField
              label="Học sinh"
              mode={view}
              value={`${e.student_name} · ${e.student_code}`}
            />
            <DetailField
              label="Phụ huynh"
              mode={view}
              value={`${e.parent_name} · ${e.parent_code}`}
            />
            <DetailField label="Gói" mode={view} value={e.package_code ?? ''} />
            <DetailField label="Hình thức học" mode={view} value={e.delivery_mode_name ?? ''} />
            <DetailField
              label="Đơn hàng"
              mode={view}
              value={
                e.order_id && e.order_code ? (
                  <Link to={`/crm/don-hang/${e.order_id}`} className="text-link hover:underline">
                    {e.order_code}
                  </Link>
                ) : (
                  ''
                )
              }
            />
            <DetailField label="Tình trạng" mode={view} value={e.status_name} />
            <DetailField label="Cơ sở" mode={view} value={`${e.branch_code} ${e.branch_name}`} />
            <DetailField label="Ngày ghi danh" mode={view} value={formatDate(e.enrolled_on)} />
            <DetailField
              label="Start Date"
              mode={view}
              value={e.start_date ? formatDate(e.start_date) : ''}
            />
            <DetailField
              label="End Date (dự kiến, chỉ dự báo)"
              mode={view}
              value={e.expected_end_date ? formatDate(e.expected_end_date) : ''}
            />
            <DetailField
              label="Hạn gói (chỉ dự báo)"
              mode={view}
              value={e.package_deadline ? formatDate(e.package_deadline) : ''}
            />
          </DetailSection>
        </div>

        <div className="mt-6">
          <CustTabs
            active={tab}
            onChange={setTab}
            tabs={[
              { key: 'fund', label: 'Quỹ giờ và lớp' },
              { key: 'ledger', label: 'Sổ giờ' },
              {
                key: 'tickets',
                label: 'Ticket liên quan',
                note: 'Chưa có dữ liệu (ticket làm sau)',
              },
            ]}
          />
        </div>
        {tab === 'ledger' && (
          <section className="mt-6 flex flex-col gap-2">
            <p className="text-body text-fg-muted">
              Sổ giờ chỉ thêm dòng, không sửa dòng cũ. Mọi cộng, trừ giờ của ghi danh nằm ở sổ giờ.
            </p>
            <RecentLedger enrollmentId={e.id} />
            <div>
              <Button onClick={() => openFrom(`/crm/ghi-danh/${e.id}/so-gio`)}>
                Mở sổ giờ đầy đủ
              </Button>
            </div>
          </section>
        )}
        {tab === 'fund' && (
          <>
            <div className="mt-6 grid gap-6 md:grid-cols-2">
              <DetailSection title="Quỹ giờ">
                <DetailField label="Giờ cấp" mode={view} value={formatNumber(hours.granted)} />
                <DetailField label="Giờ tặng" mode={view} value={formatNumber(hours.gifted)} />
                <DetailField label="Đã học" mode={view} value={formatNumber(hours.used)} />
                <DetailField
                  label="Còn lại"
                  mode={view}
                  value={<b>{formatNumber(hours.remaining)} giờ</b>}
                />
              </DetailSection>
            </div>

            <section className="mt-6 flex flex-col gap-2" aria-labelledby="gd02-classes">
              <h3
                id="gd02-classes"
                className="text-caption font-semibold tracking-wide text-fg-muted uppercase"
              >
                Lớp đang học và lịch sử chuyển lớp (dòng xếp lớp)
              </h3>
              {classes.length === 0 ? (
                <p className="text-body text-fg-muted">
                  Chưa có lớp. Ghi danh Chờ xếp lớp: bấm Xếp lớp để xếp.
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
                        <tr
                          key={`${c.class_id}-${c.start_date}`}
                          className="border-t border-border"
                        >
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
                  Em có {peers.peers.length + 1} ghi danh ở lớp này ({e.code} còn{' '}
                  {formatNumber(hours.remaining)} giờ
                  {peers.peers
                    .map((p) => `, ${p.code} còn ${formatNumber(p.remaining)} giờ`)
                    .join('')}
                  ). Giờ còn của lớp = tổng các ghi danh:{' '}
                  <b>{formatNumber(peers.total_remaining ?? 0)} giờ</b>.
                </p>
              )}
              <p className="text-caption text-fg-muted">
                Ngày hết giờ dự kiến cộng lịch của lớp đang học, chỉ để dự báo, không chặn gì.
              </p>
            </section>
          </>
        )}
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

/** Bốn dòng gần nhất của sổ giờ (khung GD02) ở tab Sổ giờ; nút mở sổ đầy đủ nằm ngay dưới. */
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
