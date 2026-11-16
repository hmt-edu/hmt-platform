// GD-07 Sắp hết giờ (danh sách dự báo chỉ đọc, khuôn K03 giản lược). ĐỀ XUẤT docs/spec/de-xuat-luat-a.md: mỗi dòng một (học sinh, lớp); giờ còn, hết giờ dự kiến,
// hạn gói (dự báo, R-GD-07: không chặn gì), tình trạng gợi ý. Không sinh phiếu tái tục (R-V2-25), không có nút tạo tay (R-TIEN-02). Phân hệ SAP_HET_GIO tắt mặc định.
// Máy chủ quyết quyền, cờ và tính toán (app.list_expiring_enrollments); phân trang 50 dòng ở máy chủ. Điện thoại: thẻ từng dòng.
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { dateText, hoursText, statusName, statusTone, type ExpiringRow } from './expiringLogic';
import { useExpiringPage } from './useExpiringData';

const PAGE_SIZE = 50; // allow-number: mặc định phân trang danh sách (quy ước hiệu năng, tối đa 100)
const FILTERS: { key: string; label: string; status: string[] | null }[] = [
  { key: 'tat-ca', label: 'Tất cả', status: null },
  { key: 'sap', label: 'Sắp hết giờ', status: ['SAP_HET_GIO'] },
  { key: 'het', label: 'Hết giờ', status: ['HET_GIO'] },
  { key: 'qua-han', label: 'Quá hạn gói, còn giờ', status: ['QUA_HAN_CON_GIO'] },
];

export function ExpiringListPage() {
  const narrow = useMedia(NARROW_TABLE);
  const [filter, setFilter] = useState('tat-ca');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const status = FILTERS.find((f) => f.key === filter)?.status ?? null;
  const query = useExpiringPage(status, search.trim(), page * PAGE_SIZE, PAGE_SIZE);

  const classLink = (r: ExpiringRow) => (
    <Link className="text-link underline" to={`/crm/lop/${r.class_id}`}>
      {r.class_code}
    </Link>
  );

  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-4">
      <h1 className="text-h2">Sắp hết giờ</h1>
      <p className="text-body text-fg-muted">
        Dự báo theo từng học sinh và lớp, để tư vấn tái tục sớm. Hạn gói chỉ để tham khảo, không
        chặn học (R-GD-07).
      </p>
      <div role="group" aria-label="Tình trạng" className="flex flex-wrap gap-2">
        {FILTERS.map((f) => (
          <Button
            key={f.key}
            variant={filter === f.key ? 'primary' : 'secondary'}
            aria-pressed={filter === f.key}
            onClick={() => {
              setFilter(f.key);
              setPage(0);
            }}
          >
            {f.label}
          </Button>
        ))}
      </div>
      <TextField
        label="Tìm tên học sinh hoặc mã lớp"
        value={search}
        onChange={(e) => {
          setSearch(e.target.value);
          setPage(0);
        }}
      />
      {query.isPending ? (
        <Spinner />
      ) : query.isError ? (
        errorOf(query.error).code === 'HMT_TINH_NANG_TAT' ? (
          <StateView kind="forbidden" title="Phân hệ chưa bật" headingLevel={2}>
            {errorOf(query.error).message}
          </StateView>
        ) : (
          <Alert tone="danger">{errorOf(query.error).message}</Alert>
        )
      ) : query.data.rows.length === 0 ? (
        <StateView kind="empty" title="Chưa có học sinh sắp hết giờ" headingLevel={2}>
          Không có học sinh nào khớp bộ lọc này.
        </StateView>
      ) : narrow ? (
        <ul className="flex flex-col gap-2">
          {query.data.rows.map((r) => (
            <li
              key={`${r.student_id}:${r.class_id}`}
              className="rounded-control border border-border bg-surface p-3"
            >
              <p className="font-semibold">{r.student_name}</p>
              <p className="text-body">{classLink(r)}</p>
              <p className="text-caption text-fg-muted">
                Còn {hoursText(r.hours_left)} giờ · Hết giờ dự kiến {dateText(r.projected_end)} ·
                Hạn gói {dateText(r.validity_date)}
              </p>
              <p className="py-1">
                <Tag tone={statusTone(r.status_code)}>{statusName(r.status_code)}</Tag>
              </p>
            </li>
          ))}
        </ul>
      ) : (
        <div className="overflow-x-auto rounded-control border border-border">
          <table aria-label="Sắp hết giờ" className="w-full text-body">
            <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
              <tr>
                <th className="px-3 py-2">Học sinh</th>
                <th className="px-3 py-2">Lớp</th>
                <th className="px-3 py-2">Ghi danh</th>
                <th className="px-3 py-2">Giờ còn</th>
                <th className="px-3 py-2">Hết giờ dự kiến</th>
                <th className="px-3 py-2">Hạn gói (dự báo)</th>
                <th className="px-3 py-2">Tình trạng</th>
              </tr>
            </thead>
            <tbody>
              {query.data.rows.map((r) => (
                <tr key={`${r.student_id}:${r.class_id}`} className="border-t border-border">
                  <td className="px-3 py-2">{r.student_name}</td>
                  <td className="px-3 py-2">{classLink(r)}</td>
                  <td className="px-3 py-2">{r.enrollment_codes.join(', ')}</td>
                  <td className="px-3 py-2">{hoursText(r.hours_left)}</td>
                  <td className="px-3 py-2">{dateText(r.projected_end)}</td>
                  <td className="px-3 py-2">{dateText(r.validity_date)}</td>
                  <td className="px-3 py-2">
                    <Tag tone={statusTone(r.status_code)}>{statusName(r.status_code)}</Tag>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {query.data && query.data.total > PAGE_SIZE && (
        <div className="flex items-center gap-2">
          <Button disabled={page === 0} onClick={() => setPage(page - 1)}>
            Trang trước
          </Button>
          <span className="text-caption text-fg-muted">
            {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, query.data.total)} /{' '}
            {query.data.total}
          </span>
          <Button
            disabled={(page + 1) * PAGE_SIZE >= query.data.total}
            onClick={() => setPage(page + 1)}
          >
            Trang sau
          </Button>
        </div>
      )}
    </div>
  );
}
