// BUOI-15 Điểm danh trong ngày (danh sách theo dõi chỉ đọc, khuôn K03 giản lược). ĐỀ XUẤT docs/spec/de-xuat-luat-a.md: mỗi dòng một buổi của ngày (mặc định hôm nay), kèm số em theo
// trạng thái điểm danh phía vận hành và phía giáo viên (ô giáo viên là chính thức, R-DD-02), tình trạng ghi, và "PH báo nghỉ n" (lý do liên hệ XIN_NGHI_HOC). Sửa điểm danh ở màn buổi,
// không ở đây. Máy chủ quyết quyền, cờ và tính toán (app.session_day_attendance); phân trang 50 dòng ở máy chủ; phân hệ DIEM_DANH_TRONG_NGAY tắt mặc định.
import { useState } from 'react';

import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { countsText, noticeText, stateName, stateTone, type DayRow } from './dayLogic';
import { useDayPage } from './useDayData';
import { FromLink } from '../../layout/FromLink';

const PAGE_SIZE = 50; // allow-number: mặc định phân trang danh sách (quy ước hiệu năng, tối đa 100)
const FILTERS: { key: string; label: string; state: string[] | null; notice: boolean | null }[] = [
  { key: 'tat-ca', label: 'Tất cả', state: null, notice: null },
  { key: 'chua', label: 'Chưa ghi', state: ['CHUA_GHI'], notice: null },
  { key: 'do', label: 'Ghi dở', state: ['GHI_DO'], notice: null },
  { key: 'du', label: 'Ghi đủ', state: ['GHI_DU'], notice: null },
  { key: 'nghi', label: 'Có báo nghỉ', state: null, notice: true },
];

export function DayAttendancePage() {
  const narrow = useMedia(NARROW_TABLE);
  const [date, setDate] = useState('');
  const [filter, setFilter] = useState('tat-ca');
  const [page, setPage] = useState(0);
  const f = FILTERS.find((x) => x.key === filter) ?? FILTERS[0];
  const catalogs = useLeadCatalogs();
  const query = useDayPage(
    { date, state: f?.state ?? null, hasNotice: f?.notice ?? null },
    page * PAGE_SIZE,
    PAGE_SIZE,
  );

  const sessionLink = (r: DayRow) => (
    <FromLink className="text-link underline" to={`/crm/buoi-hoc/${r.session_id}`}>
      {r.class_code} · {r.session_no ? `Buổi ${r.session_no}` : 'Buổi'}
    </FromLink>
  );

  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-4">
      <h1 className="text-h2">Điểm danh trong ngày</h1>
      <p className="text-body text-fg-muted">
        Theo dõi điểm danh các buổi trong ngày. Ô giáo viên là trạng thái chính thức; sửa ở màn
        buổi.
      </p>
      <TextField
        label="Ngày (để trống là hôm nay)"
        type="date"
        value={date}
        onChange={(e) => {
          setDate(e.target.value);
          setPage(0);
        }}
      />
      <div role="group" aria-label="Tình trạng ghi" className="flex flex-wrap gap-2">
        {FILTERS.map((x) => (
          <Button
            key={x.key}
            variant={filter === x.key ? 'primary' : 'secondary'}
            aria-pressed={filter === x.key}
            onClick={() => {
              setFilter(x.key);
              setPage(0);
            }}
          >
            {x.label}
          </Button>
        ))}
      </div>
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
        <StateView kind="empty" title="Không có buổi nào" headingLevel={2}>
          Không có buổi nào khớp ngày và bộ lọc này.
        </StateView>
      ) : narrow ? (
        <ul className="flex flex-col gap-2">
          {query.data.rows.map((r) => (
            <li key={r.session_id} className="rounded-control border border-border bg-surface p-3">
              <p className="font-semibold">{sessionLink(r)}</p>
              <p className="text-caption text-fg-muted">
                {r.start_time}–{r.end_time} · {r.room_name ?? 'Chưa có phòng'} ·{' '}
                {r.teacher_name ?? 'Chưa có giáo viên'}
              </p>
              <p className="text-caption">Vận hành: {countsText(r.ops)}</p>
              <p className="text-caption">Giáo viên: {countsText(r.teacher)}</p>
              <p className="py-1">
                <Tag tone={stateTone(r.state)}>{stateName(r.state)}</Tag>{' '}
                <span className="text-caption">{noticeText(r.notice)}</span>
              </p>
            </li>
          ))}
        </ul>
      ) : (
        <div className="overflow-x-auto rounded-control border border-border">
          <table aria-label="Điểm danh trong ngày" className="w-full text-body">
            <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
              <tr>
                <th className="px-3 py-2">Giờ</th>
                <th className="px-3 py-2">Lớp</th>
                <th className="px-3 py-2">Cơ sở</th>
                <th className="px-3 py-2">Giáo viên</th>
                <th className="px-3 py-2">Tình trạng buổi</th>
                <th className="px-3 py-2">Điểm danh</th>
                <th className="px-3 py-2">VH điểm danh</th>
                <th className="px-3 py-2">GV điểm danh</th>
                <th className="px-3 py-2">Lưu ý</th>
                <th className="px-3 py-2">CSKH</th>
                <th className="px-3 py-2">Xử lý</th>
              </tr>
            </thead>
            <tbody>
              {query.data.rows.map((r) => (
                <tr key={r.session_id} className="border-t border-border">
                  <td className="px-3 py-2">
                    {r.start_time}–{r.end_time}
                  </td>
                  <td className="px-3 py-2">
                    <span className="flex flex-col">
                      <span className="font-medium">{r.class_code}</span>
                      <span className="text-caption text-fg-muted">
                        {r.session_no ? `Buổi ${r.session_no}` : 'Buổi'}
                        {r.room_name ? ` · ${r.room_name}` : ''}
                      </span>
                    </span>
                  </td>
                  <td className="px-3 py-2">{r.branch_code}</td>
                  <td className="px-3 py-2">{r.teacher_name ?? '—'}</td>
                  <td className="px-3 py-2">
                    {catalogs.name('SESSION_STATUS', r.status_code) ?? r.status_code}
                  </td>
                  <td className="px-3 py-2">
                    <Tag tone={stateTone(r.state)}>{stateName(r.state)}</Tag>
                  </td>
                  <td className="px-3 py-2">{countsText(r.ops)}</td>
                  <td className="px-3 py-2">{countsText(r.teacher)}</td>
                  <td className="px-3 py-2">{noticeText(r.notice)}</td>
                  <td className="px-3 py-2">{r.cskh_name ?? '—'}</td>
                  <td className="px-3 py-2">
                    <FromLink className="text-link underline" to={`/crm/buoi-hoc/${r.session_id}`}>
                      Xem
                    </FromLink>
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
