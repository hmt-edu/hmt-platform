// KH-05 Học sinh (hồ sơ 360°, khuôn K06): thông tin, ghi danh và lớp, điểm danh, điểm kiểm tra, phiếu kiểm tra đầu vào; nút liên kết có số đếm;
// ghi chú và hoạt động (Chatter). Không có Tạo tay (R-CRM-27). Sửa (KH-06), Gộp, Tạo ticket, tài khoản học tập: chưa làm, hiện mờ kèm chú thích.
// Giáo viên được phân công xem hồ sơ trong lớp mình nhưng không thấy SĐT phụ huynh (R-GV-13): máy chủ trả null.
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { Button } from '../../ui/Button';
import { HmtError, errorOf } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { CustTabs } from './CustTabs';
import { ATTENDANCE_LABEL, STUDENT_STATUS_LABEL, type StudentRecord } from './custTypes';
import { useRefreshCustomers, useStudentRecord } from './useCustData';

const FORMAT = {
  labels: {
    full_name: 'Họ tên',
    birth_date: 'Ngày sinh',
    birth_year: 'Năm sinh',
    school: 'Trường học',
    goal: 'Mục tiêu',
    grade: 'Khối',
  },
};

export function StudentRecordPage() {
  const { id } = useParams();
  const query = useStudentRecord(id);
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
            ? 'Bạn không có quyền xem học sinh này'
            : code === 'HMT_KHONG_TIM_THAY'
              ? 'Không tìm thấy học sinh'
              : 'Không tải được học sinh'
        }
        actions={
          <>
            <Link to="/crm/hoc-sinh" className="font-medium text-link hover:underline">
              Về danh sách Học sinh
            </Link>
            {code === '' && <Button onClick={() => void query.refetch()}>Thử lại</Button>}
          </>
        }
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  return <StudentView key={query.data.id} record={query.data} />;
}

function StudentView({ record }: { record: StudentRecord }) {
  const refresh = useRefreshCustomers();
  const [tab, setTab] = useState('overview');
  useCrumbTail(`${record.full_name} · ${record.code}`);
  const merged = record.record_status === 'DA_GOP';
  const summary = Object.entries(record.attendance_summary);

  return (
    <RecordDetail
      kind="Học sinh"
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
            unavailable: 'Màn Sửa học sinh (KH-06) làm sau',
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
          {
            kind: 'action',
            label: 'Cấp tài khoản',
            onSelect: () => undefined,
            unavailable: 'Tài khoản học tập làm ở giai đoạn 4',
          },
        ],
      }}
      smart={[
        {
          key: 'ghi-danh',
          label: 'Ghi danh',
          icon: 'training',
          count: record.counts.enrollments,
          onOpen: () => setTab('study'),
        },
        {
          key: 'lop',
          label: 'Lớp',
          icon: 'training',
          count: record.counts.classes,
          onOpen: () => setTab('study'),
        },
        {
          key: 'phieu-test',
          label: 'Phiếu test',
          icon: 'results',
          count: record.counts.tests,
          onOpen: () => setTab('exam'),
        },
      ]}
      aside={
        <RecordChatter
          entityType="STUDENT"
          entityId={record.id}
          format={FORMAT}
          createdText="Tạo học sinh."
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
              to={`/crm/hoc-sinh/${record.merged_into_id}`}
            >
              Mở hồ sơ đích
            </Link>
          )}
        </p>
      )}
      <div className="flex flex-wrap items-center gap-2">
        <Tag tone={record.status === 'DANG_HOC' ? 'success' : 'neutral'}>
          {STUDENT_STATUS_LABEL[record.status]}
        </Tag>
      </div>
      <CustTabs
        active={tab}
        onChange={setTab}
        tabs={[
          { key: 'overview', label: 'Tổng quan' },
          { key: 'study', label: 'Học tập' },
          { key: 'attendance', label: 'Điểm danh' },
          { key: 'exam', label: 'Điểm kiểm tra' },
          { key: 'care', label: 'Chăm sóc', note: 'Chưa có dữ liệu (chăm sóc làm sau)' },
          {
            key: 'tickets',
            label: 'Đề nghị & khiếu nại',
            note: 'Chưa có dữ liệu (ticket làm sau)',
          },
        ]}
      />
      {tab === 'overview' && (
        <DetailSection title="Thông tin học sinh">
          <DetailField
            mode="view"
            label="Mã cũ (Sheet)"
            hint="chỉ xem, Admin sửa được"
            value={record.legacy_ref ?? ''}
          />
          <DetailField mode="view" label="Họ tên" value={record.full_name} />
          <DetailField
            mode="view"
            label="Ngày sinh"
            value={record.birth_date ? formatDate(record.birth_date) : ''}
          />
          <DetailField mode="view" label="Năm sinh" value={record.birth_year ?? ''} />
          <DetailField mode="view" label="Khối" value={record.grade ? `Lớp ${record.grade}` : ''} />
          <DetailField mode="view" label="Trường học" value={record.school ?? ''} />
          <DetailField mode="view" label="Mục tiêu" value={record.goal ?? ''} />
          <DetailField
            mode="view"
            label="Phụ huynh"
            value={
              record.parent ? (
                <Link
                  className="font-medium text-link hover:underline"
                  to={`/crm/phu-huynh/${record.parent.id}`}
                >
                  {record.parent.full_name}
                </Link>
              ) : (
                ''
              )
            }
          />
          <DetailField mode="view" label="SĐT phụ huynh" value={record.parent?.phone ?? ''} />
          <DetailField
            mode="view"
            label="Tình trạng"
            hint="hệ thống tự đổi theo ghi danh"
            value={STUDENT_STATUS_LABEL[record.status]}
          />
          <DetailField
            mode="view"
            label="Cơ sở tiếp nhận"
            hint="chỉ Admin sửa"
            value={record.branch_code}
          />
          <DetailField
            mode="view"
            label="Đang học tại"
            hint="tự tính từ các lớp"
            value={record.studying_at.join(', ')}
          />
          <DetailField
            mode="view"
            label="Cập nhật lần cuối"
            value={formatDateTime(record.updated_at)}
          />
        </DetailSection>
      )}
      {tab === 'study' &&
        (record.enrollments.length === 0 ? (
          <p className="py-2 text-fg-muted">Chưa có ghi danh.</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {record.enrollments.map((e) => (
              <li key={e.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
                <span>
                  <span className="font-medium">{e.code}</span>{' '}
                  <span className="text-fg-muted">{e.subject_name ?? e.subject_code}</span>
                </span>
                <span className="text-caption text-fg-muted">
                  {e.status_name ?? e.status_code}
                  {e.class_id && e.class_code ? (
                    <>
                      {' · '}
                      <Link className="text-link hover:underline" to={`/crm/lop/${e.class_id}`}>
                        {e.class_code}
                      </Link>
                    </>
                  ) : (
                    ' · chưa xếp lớp'
                  )}
                  {` · còn ${e.hours_left} giờ`}
                </span>
              </li>
            ))}
          </ul>
        ))}
      {tab === 'attendance' && (
        <div className="flex flex-col gap-2">
          <p className="text-fg-muted">
            {summary.length === 0
              ? 'Chưa có điểm danh.'
              : summary.map(([k, n]) => `${ATTENDANCE_LABEL[k] ?? k}: ${n}`).join(' · ')}
          </p>
          <ul className="flex flex-col divide-y divide-border">
            {record.attendance.map((a, i) => (
              <li key={i} className="flex flex-wrap justify-between gap-2 py-1.5">
                <span>
                  {formatDate(a.session_date)} {a.start_time.slice(0, 5)} · {a.class_code}
                </span>
                <span className="text-caption text-fg-muted">
                  {ATTENDANCE_LABEL[a.status ?? 'CHUA'] ?? a.status}
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}
      {tab === 'exam' && (
        <div className="flex flex-col gap-3">
          <DetailSection title="Điểm kiểm tra trong lớp">
            {record.exam_scores.length === 0 ? (
              <p className="py-2 text-fg-muted">Chưa có điểm kiểm tra.</p>
            ) : (
              <ul className="flex flex-col divide-y divide-border">
                {record.exam_scores.map((x, i) => (
                  <li key={i} className="flex flex-wrap justify-between gap-2 py-1.5">
                    <span>
                      {formatDate(x.session_date)} · {x.class_code}
                    </span>
                    <span className="tabular font-medium">
                      {x.total_score ?? '—'}
                      {x.max_score ? ` / ${x.max_score}` : ''}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </DetailSection>
          <DetailSection title="Phiếu kiểm tra đầu vào">
            {record.tests.length === 0 ? (
              <p className="py-2 text-fg-muted">Chưa có phiếu kiểm tra.</p>
            ) : (
              <ul className="flex flex-col divide-y divide-border">
                {record.tests.map((t) => (
                  <li key={t.id} className="flex flex-wrap justify-between gap-2 py-1.5">
                    <Link
                      to={`/crm/phieu-kiem-tra/${t.id}`}
                      className="font-medium text-link hover:underline"
                    >
                      {t.code}
                    </Link>
                    <span className="text-caption text-fg-muted">
                      {t.scheduled_at ? formatDate(t.scheduled_at) : '—'}
                      {t.score !== null ? ` · điểm ${t.score}` : ''}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </DetailSection>
        </div>
      )}
    </RecordDetail>
  );
}
