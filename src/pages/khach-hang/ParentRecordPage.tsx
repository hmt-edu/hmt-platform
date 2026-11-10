// KH-02 Phụ huynh (bản ghi, khuôn K06): thông tin, các con, đơn hàng, phiếu thu; nút liên kết có số đếm; ghi chú và hoạt động (Chatter).
// Không có Tạo tay (R-CRM-27). Sửa (KH-03), Gộp (KH-07), Tạo ticket (CS-04) chưa làm: hiện mờ kèm chú thích. Ticket và Tài chính: chưa có dữ liệu.
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { Button } from '../../ui/Button';
import { HmtError, errorOf } from '../../lib/db';
import { formatDate, formatMoney } from '../../lib/format';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { CustTabs } from './CustTabs';
import { studentPath } from './custConfig';
import { STUDENT_STATUS_LABEL, type ParentRecord } from './custTypes';
import { useParentRecord, useRefreshCustomers } from './useCustData';

const FORMAT = {
  labels: {
    full_name: 'Họ tên',
    phone: 'Số điện thoại',
    phone_2: 'Số điện thoại 2',
    address: 'Địa chỉ',
    relative_name: 'Người thân',
  },
};

export function ParentRecordPage() {
  const { id } = useParams();
  const query = useParentRecord(id);
  if (query.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (query.isError) {
    const code = query.error instanceof HmtError ? query.error.code : '';
    return (
      <StateView
        kind={
          code === 'HMT_KHONG_CO_QUYEN'
            ? 'forbidden'
            : code === 'HMT_KHONG_TIM_THAY'
              ? 'not-found'
              : 'error'
        }
        title={
          code === 'HMT_KHONG_CO_QUYEN'
            ? 'Bạn không có quyền xem phụ huynh này'
            : code === 'HMT_KHONG_TIM_THAY'
              ? 'Không tìm thấy phụ huynh'
              : 'Không tải được phụ huynh'
        }
        actions={
          <>
            <Link to="/crm/phu-huynh" className="font-medium text-link hover:underline">
              Về danh sách Phụ huynh
            </Link>
            {code === '' && <Button onClick={() => void query.refetch()}>Thử lại</Button>}
          </>
        }
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  return <ParentView key={query.data.id} record={query.data} />;
}

function ParentView({ record }: { record: ParentRecord }) {
  const refresh = useRefreshCustomers();
  const navigate = useNavigate();
  const [tab, setTab] = useState('overview');
  useCrumbTail(`${record.full_name} · ${record.code}`);
  const merged = record.record_status === 'DA_GOP';

  return (
    <RecordDetail
      kind="Phụ huynh"
      title={`${record.full_name} · ${record.code}`}
      mode="view"
      readOnly
      onEdit={() => undefined}
      onSave={() => undefined}
      onCancel={() => undefined}
      onRefresh={() => void refresh()}
      menu={{
        label: 'Hành động',
        items: [
          {
            kind: 'action',
            label: 'Sửa',
            onSelect: () => undefined,
            unavailable: 'Màn Sửa phụ huynh (KH-03) làm sau',
          },
          {
            kind: 'action',
            label: 'Gộp',
            onSelect: () => undefined,
            unavailable: 'Gộp hồ sơ trùng (KH-07) làm sau',
          },
          {
            kind: 'action',
            label: 'Tạo ticket',
            onSelect: () => undefined,
            unavailable: 'Ticket chăm sóc (CS-04) làm sau',
          },
        ],
      }}
      smart={[
        {
          key: 'con',
          label: 'Con',
          icon: 'training',
          count: record.counts.children,
          onOpen: () => setTab('children'),
        },
        {
          key: 'co-hoi',
          label: 'Cơ hội',
          icon: 'results',
          count: record.counts.opportunities,
          unavailable: 'Mở cơ hội từ menu Tuyển sinh',
          onOpen: () => undefined,
        },
        {
          key: 'phieu-test',
          label: 'Phiếu test',
          icon: 'results',
          count: record.counts.tests,
          unavailable: 'Mở phiếu test từ menu Tuyển sinh',
          onOpen: () => undefined,
        },
        {
          key: 'ghi-danh',
          label: 'Ghi danh',
          icon: 'training',
          count: record.counts.enrollments,
          unavailable: 'Màn Ghi danh sắp có',
          onOpen: () => undefined,
        },
        {
          key: 'phieu-thu',
          label: 'Phiếu thu',
          icon: 'results',
          count: record.counts.receipts,
          onOpen: () => setTab('receipts'),
        },
      ]}
      aside={
        <RecordChatter
          entityType="PARENT"
          entityId={record.id}
          format={FORMAT}
          createdText="Tạo phụ huynh."
          canWrite={!merged}
        />
      }
      asideLabel="Ghi chú và hoạt động"
    >
      {merged && (
        <p role="status" className="rounded-control bg-canvas p-3">
          Hồ sơ này đã gộp vào hồ sơ khác.{' '}
          {record.merged_into_id && (
            <Link
              className="font-medium text-link hover:underline"
              to={`/crm/phu-huynh/${record.merged_into_id}`}
            >
              Mở hồ sơ đích
            </Link>
          )}
        </p>
      )}
      <div className="flex flex-wrap items-center gap-2">
        <Tag tone={record.is_studying ? 'success' : 'neutral'}>
          {record.is_studying ? 'Có con đang học' : 'Chưa có con đang học'}
        </Tag>
      </div>
      <CustTabs
        active={tab}
        onChange={setTab}
        tabs={[
          { key: 'overview', label: 'Tổng quan' },
          { key: 'children', label: 'Các con' },
          { key: 'orders', label: 'Đơn hàng' },
          { key: 'receipts', label: 'Phiếu thu' },
          { key: 'tickets', label: 'Ticket', note: 'Chưa có dữ liệu (ticket làm sau)' },
          { key: 'finance', label: 'Tài chính', note: 'Chưa có dữ liệu (số dư, công nợ làm sau)' },
        ]}
      />
      {tab === 'overview' && (
        <DetailSection title="Thông tin phụ huynh">
          <DetailField mode="view" label="Họ tên" value={record.full_name} />
          <DetailField mode="view" label="Số điện thoại" value={record.phone} />
          <DetailField mode="view" label="Số điện thoại 2" value={record.phone_2 ?? ''} />
          <DetailField mode="view" label="Người thân" value={record.relative_name ?? ''} />
          <DetailField mode="view" label="Phường/Xã" value={record.ward_name ?? ''} />
          <DetailField mode="view" label="Tỉnh/Thành phố" value={record.province_name ?? ''} />
          <DetailField mode="view" label="Địa chỉ" value={record.address ?? ''} />
          <DetailField
            mode="view"
            label="Cơ sở tiếp nhận"
            hint="cố định, chỉ Admin sửa"
            value={record.branch_code}
          />
          <DetailField
            mode="view"
            label="Đang học tại"
            hint="tự tính từ ghi danh của các con"
            value={record.studying_at.join(', ')}
          />
          <DetailField mode="view" label="Ngày tạo" value={formatDate(record.created_at)} />
        </DetailSection>
      )}
      {tab === 'children' &&
        (record.children.length === 0 ? (
          <p className="py-2 text-fg-muted">Chưa có học sinh.</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {record.children.map((c) => (
              <li key={c.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
                <button
                  type="button"
                  className="text-left font-medium text-link hover:underline"
                  onClick={() => void navigate(studentPath(c.id))}
                >
                  {c.full_name}
                </button>
                <span className="text-caption text-fg-muted">
                  {c.code}
                  {c.grade ? ` · Lớp ${c.grade}` : ''} · {STUDENT_STATUS_LABEL[c.status]}
                </span>
              </li>
            ))}
          </ul>
        ))}
      {tab === 'orders' &&
        (record.orders.length === 0 ? (
          <p className="py-2 text-fg-muted">Chưa có đơn hàng.</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {record.orders.map((o) => (
              <li key={o.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
                <Link
                  to={`/crm/don-hang/${o.id}`}
                  className="font-medium text-link hover:underline"
                >
                  {o.code}
                </Link>
                <span className="text-caption text-fg-muted">
                  {formatDate(o.created_at)} · {formatMoney(o.total_amount)}
                </span>
              </li>
            ))}
          </ul>
        ))}
      {tab === 'receipts' &&
        (record.receipts.length === 0 ? (
          <p className="py-2 text-fg-muted">Chưa có phiếu thu.</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {record.receipts.map((r) => (
              <li key={r.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
                <Link
                  to={`/crm/phieu-thu/${r.id}`}
                  className="font-medium text-link hover:underline"
                >
                  {r.code}
                </Link>
                <span className="text-caption text-fg-muted">
                  {r.paid_on ? formatDate(r.paid_on) : '—'} · {formatMoney(r.amount)}
                </span>
              </li>
            ))}
          </ul>
        ))}
    </RecordDetail>
  );
}
