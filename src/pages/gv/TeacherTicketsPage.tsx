// GV-14 Ticket của lớp tôi (cổng giáo viên, chỉ đọc + nút Tạo ticket; R-CS-10): ticket trong các lớp mình được phân công và ticket mình tạo, mọi loại. Giáo viên không
// duyệt, không đổi trạng thái; cơ sở xử lý. Máy chủ quyết quyền, cờ AFTERSALE và phạm vi (app.teacher_class_tickets), phân trang ở máy chủ. Giáo viên trả lời trong ticket: sau 17/11.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button, ButtonLink } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { statusName, typeName, type TicketPage } from './ticketLogic';

const PAGE_SIZE = 20; // allow-number: số dòng một trang trên điện thoại (máy chủ giới hạn tối đa theo cài đặt)

export function TeacherTicketsPage() {
  const supabase = useDb();
  const [page, setPage] = useState(0);
  const query = useQuery({
    queryKey: ['gv-tickets', page],
    retry: false,
    queryFn: () =>
      rpc<TicketPage>(supabase, 'teacher_class_tickets', {
        p_limit: PAGE_SIZE,
        p_offset: page * PAGE_SIZE,
      }),
  });
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4 p-3">
      <p className="text-caption text-fg-muted">
        <Link className="text-link underline" to="/gv/lop">
          Lớp
        </Link>{' '}
        › Ticket
      </p>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-h2">Ticket của lớp tôi</h1>
        <ButtonLink to="/gv/ticket/tao" variant="primary">
          Tạo ticket
        </ButtonLink>
      </div>
      <p className="text-body text-fg-muted">
        Chỉ hiện ticket trong lớp của bạn. Cơ sở xử lý; giáo viên chỉ tạo và theo dõi (R-CS-10).
      </p>
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
        <StateView kind="empty" title="Chưa có ticket" headingLevel={2}>
          Chưa có ticket nào trong lớp của bạn.
        </StateView>
      ) : (
        <ul className="flex flex-col gap-2" aria-label="Ticket của lớp tôi">
          {query.data.rows.map((r) => (
            <li key={r.id} className="rounded-control border border-border bg-surface p-3">
              <p className="font-semibold">{r.code}</p>
              <p className="text-body">{r.title}</p>
              <p className="text-caption text-fg-muted">
                {typeName(r.ticket_type)}
                {r.category_name ? ` · ${r.category_name}` : ''}
                {r.class_code ? ` · ${r.class_code}` : ''}
                {r.student_name ? ` · ${r.student_name}` : ''}
              </p>
              <p className="py-1">
                <Tag tone="neutral">{statusName(r.status_code)}</Tag>
              </p>
            </li>
          ))}
        </ul>
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
