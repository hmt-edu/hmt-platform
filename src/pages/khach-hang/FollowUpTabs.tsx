// Tab «Lịch hẹn», «Tái tục» của hồ sơ phụ huynh, học sinh (canvas a8d7: KH02_lich_hen, KH02_tai_tuc, KH05_lich_hen, KH05_tai_tuc).
// Danh sách phân trang ở máy chủ (app.list_record_appointments, app.list_record_upsale); phạm vi xem do máy chủ quyết.
import { Link } from 'react-router';
import type { CustomerOwner } from '../../features/appointments/appointmentApi';
import { formatDate, formatDateTime, formatNumber } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Tag, type Column } from '../../ui/Data';
import {
  RECORD_KIND_LABEL,
  recordKind,
  recordPath,
  STATUS_LABEL,
  type AppointmentRow,
} from '../lich-hen/appointmentTypes';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { upsaleStageTone } from '../tai-tuc/upsaleConfig';
import { PagedTable } from './PagedTable';
import { FromLink } from '../../layout/FromLink';

const NONE = '—';

type ApptRow = AppointmentRow & { student_name: string | null };

export function AppointmentTab({ owner }: { owner: CustomerOwner }) {
  const catalogs = useLeadCatalogs();
  const allowed = useAccess().can('APPOINTMENT', 'XEM');
  const columns: Column<ApptRow>[] = [
    {
      key: 'time',
      header: 'Thời gian',
      primary: true,
      cell: (r) => formatDateTime(r.scheduled_at),
    },
    {
      key: 'activity',
      header: 'Loại',
      cell: (r) => catalogs.name('ACTIVITY_TYPE', r.activity_code) ?? r.activity_code,
    },
    {
      key: 'record',
      header: 'Gắn với',
      cell: (r) => {
        const path = recordPath(r);
        const text = `${RECORD_KIND_LABEL[recordKind(r)]} · ${r.record_code ?? NONE}`;
        return path ? (
          <Link className="text-link hover:underline" to={path}>
            {text}
          </Link>
        ) : (
          text
        );
      },
    },
    ...(owner.key === 'parent_id'
      ? [
          {
            key: 'student',
            header: 'Học sinh',
            cell: (r: ApptRow) => r.student_name ?? NONE,
          },
        ]
      : []),
    { key: 'owner', header: 'Phụ trách', cell: (r) => r.owner_name ?? NONE },
    { key: 'status', header: 'Tình trạng', cell: (r) => <Tag>{STATUS_LABEL[r.status]}</Tag> },
  ];
  return (
    <PagedTable<ApptRow>
      caption="Lịch hẹn"
      fn="list_record_appointments"
      filters={{ [owner.key]: owner.id }}
      sort="time_desc"
      columns={columns}
      rowKey={(r) => r.id}
      allowed={allowed}
      empty="Chưa có lịch hẹn."
      denied="Bạn không có quyền xem lịch hẹn."
    />
  );
}

type UpsaleRow = {
  id: string;
  code: string;
  student_name: string;
  subject_name: string | null;
  class_code: string;
  hours_left: number | null;
  expected_end_date: string | null;
  stage_code: string;
  stage_name: string | null;
  owner_name: string | null;
  risk: boolean;
  absences: number;
};

const riskText = (r: UpsaleRow) =>
  !r.risk ? NONE : r.absences > 0 ? `Vắng ${r.absences} buổi` : 'Có rủi ro';

export function UpsaleTab({ owner }: { owner: CustomerOwner }) {
  const allowed = useAccess().can('UPSALE', 'XEM');
  const columns: Column<UpsaleRow>[] = [
    ...(owner.key === 'parent_id'
      ? [{ key: 'student', header: 'Học sinh', cell: (r: UpsaleRow) => r.student_name }]
      : []),
    {
      key: 'class',
      header: 'Môn, lớp',
      primary: true,
      cell: (r) => (
        <FromLink className="text-link hover:underline" to={`/crm/tai-tuc/${r.id}`}>
          {r.subject_name ?? NONE} ({r.class_code})
        </FromLink>
      ),
    },
    {
      key: 'hours',
      header: 'Giờ còn lại',
      numeric: true,
      cell: (r) => (r.hours_left === null ? NONE : formatNumber(r.hours_left)),
    },
    {
      key: 'end',
      header: 'Hết giờ dự kiến',
      cell: (r) => (r.expected_end_date ? formatDate(r.expected_end_date) : NONE),
    },
    {
      key: 'stage',
      header: 'Bước',
      cell: (r) => (
        <Tag tone={upsaleStageTone(r.stage_code)} dot>
          {r.stage_code} {r.stage_name ?? ''}
        </Tag>
      ),
    },
    { key: 'owner', header: 'Phụ trách', cell: (r) => r.owner_name ?? NONE },
    { key: 'risk', header: 'Rủi ro', cell: riskText },
  ];
  return (
    <PagedTable<UpsaleRow>
      caption="Phiếu tái tục"
      fn="list_record_upsale"
      filters={{ [owner.key]: owner.id }}
      sort="open_first"
      columns={columns}
      rowKey={(r) => r.id}
      allowed={allowed}
      empty="Chưa có phiếu tái tục."
      denied="Bạn không có quyền xem phiếu tái tục."
    />
  );
}
