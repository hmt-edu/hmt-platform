// PH-04 Đề nghị và khiếu nại (cổng Phụ huynh, điện thoại 390): danh sách, gửi mới, theo dõi 4 bước, xác nhận phương án, chấm hài lòng.
// Khung PH04_ds, PH04_gui, PH04_chi_tiet, PH04_phuong_an, PH04_hai_long, PH04_tai, PH04_trong, PH04_loi, PH04_loi_gui (canvas 9189).
// «Không đồng ý phương án» (PH04_khong_dong_y): hộp thoại trên màn phương án, gọi app.ph_reject_proposal (mig 643).
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { Alert, StateView } from '../../ui/Feedback';
import { Field, INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { useToast } from '../../ui/toastContext';
import { cn } from '../../ui/cn';
import { useChildren } from '../hoc/portalData';
import { ChildChips } from './ChildChips';
import {
  buildSteps,
  sentSubtitle,
  statusText,
  statusTone,
  typeText,
  type RequestCategory,
  type RequestDetail,
  type RequestRow,
} from './requestsLogic';

const PAGE_SIZE = 20; // allow-number: số đề nghị mỗi lần tải thêm (≤ list_page_size_max)
const SCORES = [1, 2, 3, 4, 5]; // allow-number: thang hài lòng 1 đến 5 (AS-04)

function Loading() {
  return (
    <div role="status" aria-label="Đang tải" className="flex flex-col gap-2">
      {[0, 1, 2].map((i) => (
        <div key={i} className="h-16 animate-pulse rounded-control bg-surface-subtle" />
      ))}
    </div>
  );
}

function LoadError({ onRetry }: { onRetry: () => void }) {
  return (
    <StateView
      kind="error"
      title="Không tải được dữ liệu"
      headingLevel={2}
      actions={<Button onClick={onRetry}>Thử lại</Button>}
    >
      Kiểm tra kết nối mạng rồi thử lại. Dữ liệu của quý phụ huynh không bị mất.
    </StateView>
  );
}

/** Danh sách «Đề nghị của tôi» (PH04_ds). */
export function ParentRequestsPage() {
  const supabase = useDb();
  const children = useChildren();
  const [limit, setLimit] = useState(PAGE_SIZE);
  const query = useQuery({
    queryKey: ['ph-tickets', limit],
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<{ total: number; rows: RequestRow[] }>(supabase, 'ph_list_tickets', {
        p_student_id: null,
        p_limit: limit,
        p_offset: 0,
      }),
    refetchOnWindowFocus: true,
  });
  const rows = query.data?.rows ?? [];
  const total = query.data?.total ?? rows.length;
  const canSend = (children.data?.length ?? 0) > 0;
  return (
    <div className="flex flex-col gap-3">
      <h1 className="text-h2">Đề nghị của tôi</h1>
      {query.isPending ? (
        <Loading />
      ) : query.isError ? (
        <LoadError onRetry={() => void query.refetch()} />
      ) : rows.length === 0 ? (
        <StateView kind="empty" title="Chưa có đề nghị nào" headingLevel={2}>
          Khi quý phụ huynh gửi đề nghị hoặc khiếu nại, tình trạng xử lý sẽ hiện ở đây.
        </StateView>
      ) : (
        <ul className="flex flex-col gap-2">
          {rows.map((r) => (
            <li key={r.id}>
              <Link
                to={`/ph/de-nghi/${r.id}`}
                className="focus-ring flex min-h-14 items-center gap-3 rounded-control border border-border bg-surface p-3"
              >
                <span className="min-w-0 flex-1">
                  <span className="block font-medium">{r.title}</span>
                  <span className="block text-fg-muted">{sentSubtitle(r)}</span>
                </span>
                <Tag tone={statusTone(r.status)}>{statusText(r.status)}</Tag>
              </Link>
            </li>
          ))}
        </ul>
      )}
      {rows.length < total && (
        <div>
          <Button
            variant="secondary"
            loading={query.isFetching}
            onClick={() => setLimit(limit + PAGE_SIZE)}
          >
            Xem thêm
          </Button>
        </div>
      )}
      {canSend && (
        <Link
          to="/ph/de-nghi/moi"
          className="focus-ring inline-flex min-h-11 items-center justify-center rounded-control bg-accent px-4 font-medium text-on-accent"
        >
          Gửi đề nghị hoặc khiếu nại mới
        </Link>
      )}
    </div>
  );
}

/** Gửi mới (PH04_gui, PH04_loi_gui). */
export function ParentRequestNewPage() {
  const supabase = useDb();
  const navigate = useNavigate();
  const toast = useToast();
  const client = useQueryClient();
  const children = useChildren();
  const list = children.data ?? [];
  const [picked, setPicked] = useState<string | null>(null);
  const [type, setType] = useState<'DN' | 'KN'>('DN');
  const [category, setCategory] = useState('');
  const [content, setContent] = useState('');
  const child = list.find((c) => c.id === picked) ?? list[0];
  const categories = useQuery({
    queryKey: ['ph-request-categories', type],
    queryFn: () => rpc<RequestCategory[]>(supabase, 'ph_request_categories', { p_type: type }),
  });
  const send = useMutation({
    mutationFn: () =>
      rpc<{ id: string; code: string }>(supabase, 'ph_create_request', {
        p_student_id: child?.id,
        p_type: type,
        p_category_code: category,
        p_content: content,
      }),
    onSuccess: (res) => {
      void client.invalidateQueries({ queryKey: ['ph-tickets'] });
      toast({ title: 'Đã gửi' });
      void navigate(`/ph/de-nghi/${res.id}`, { replace: true });
    },
  });
  const ready = child !== undefined && category !== '' && content.trim() !== '';
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={(e) => {
        e.preventDefault();
        if (ready) send.mutate();
      }}
    >
      <div className="flex flex-col gap-1">
        <h1 className="text-h2">Gửi đề nghị hoặc khiếu nại</h1>
        <Link to="/ph/de-nghi" className="focus-ring text-caption text-accent">
          Quay lại
        </Link>
      </div>
      <ChildChips items={list} value={child?.id ?? ''} onChange={setPicked} />
      <div role="group" aria-label="Loại" className="flex gap-2">
        {(['DN', 'KN'] as const).map((t) => (
          <button
            key={t}
            type="button"
            aria-pressed={type === t}
            onClick={() => {
              setType(t);
              setCategory('');
            }}
            className={cn(
              'focus-ring min-h-11 flex-1 rounded-control border px-4',
              type === t
                ? 'border-transparent bg-selected font-medium text-on-selected'
                : 'border-border bg-surface',
            )}
          >
            {typeText(t)}
          </button>
        ))}
      </div>
      <Field label="Nhóm" required>
        {(field) => (
          <select
            {...field}
            className={INPUT_CLASS}
            value={category}
            onChange={(e) => setCategory(e.target.value)}
          >
            <option value="">Chọn nhóm</option>
            {(categories.data ?? []).map((c) => (
              <option key={c.code} value={c.code}>
                {c.group_name} · {c.name}
              </option>
            ))}
          </select>
        )}
      </Field>
      <TextAreaField
        label="Nội dung"
        required
        rows={5}
        value={content}
        onChange={(e) => setContent(e.target.value)}
      />
      {send.isError && <Alert tone="danger">{errorOf(send.error).message}</Alert>}
      <Button type="submit" loading={send.isPending} disabled={!ready}>
        Gửi
      </Button>
    </form>
  );
}

/** Theo dõi 4 bước, phương án, chấm hài lòng (PH04_chi_tiet, PH04_phuong_an, PH04_hai_long). */
export function ParentRequestDetailPage() {
  const supabase = useDb();
  const client = useQueryClient();
  const toast = useToast();
  const { ticketId } = useParams();
  const [score, setScore] = useState<number | null>(null);
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState('');
  const key = ['ph-ticket', ticketId];
  const query = useQuery({
    queryKey: key,
    enabled: ticketId !== undefined,
    queryFn: () => rpc<RequestDetail>(supabase, 'ph_get_ticket', { p_ticket_id: ticketId }),
    refetchOnWindowFocus: true,
  });
  const done = (title: string) => {
    void client.invalidateQueries({ queryKey: key });
    void client.invalidateQueries({ queryKey: ['ph-tickets'] });
    toast({ title });
  };
  const confirm = useMutation({
    mutationFn: () => rpc<null>(supabase, 'ph_confirm_option', { p_ticket_id: ticketId }),
    onSuccess: () => done('Đã gửi xác nhận'),
  });
  const reject = useMutation({
    mutationFn: () =>
      rpc<{ id: string; code: string; reopened: boolean }>(supabase, 'ph_reject_proposal', {
        p_ticket_id: ticketId,
        p_reason: reason,
      }),
    onSuccess: () => {
      setRejecting(false);
      setReason('');
      done('Đã gửi, nhân viên chăm sóc sẽ liên hệ lại');
    },
  });
  const rate = useMutation({
    mutationFn: () =>
      rpc<null>(supabase, 'ph_rate_ticket', { p_ticket_id: ticketId, p_score: score }),
    onSuccess: () => done('Cảm ơn quý phụ huynh đã đánh giá'),
  });
  const header = (
    <div className="flex flex-col gap-1">
      <h1 className="text-h2">{query.data?.title ?? 'Đề nghị'}</h1>
      <Link to="/ph/de-nghi" className="focus-ring text-caption text-accent">
        Quay lại danh sách
      </Link>
    </div>
  );
  if (query.isPending)
    return (
      <div className="flex flex-col gap-3">
        {header}
        <Loading />
      </div>
    );
  if (query.isError)
    return (
      <div className="flex flex-col gap-3">
        {header}
        <LoadError onRetry={() => void query.refetch()} />
      </div>
    );
  const d = query.data;
  const steps = buildSteps(d.step);
  const waiting = d.status === 'CHO_XAC_NHAN';
  const canRate = (waiting || d.status === 'DA_XONG') && d.satisfaction === null;
  return (
    <div className="flex flex-col gap-4">
      {header}
      <section className="rounded-control border border-border bg-surface p-3">
        <dl className="flex flex-col gap-1">
          <div className="flex justify-between gap-3">
            <dt className="text-fg-muted">{sentSubtitle(d)}</dt>
            <dd>
              <Tag tone={statusTone(d.status)}>{statusText(d.status)}</Tag>
            </dd>
          </div>
          {d.student_name !== null && (
            <div className="flex justify-between gap-3">
              <dt className="text-fg-muted">Cho con</dt>
              <dd className="font-medium">{d.student_name}</dd>
            </div>
          )}
        </dl>
      </section>
      <section aria-label="Các bước" className="flex flex-col gap-2">
        <h2 className="text-caption font-semibold uppercase text-fg-muted">Các bước</h2>
        <ol className="flex flex-col gap-2">
          {steps.map((s) => (
            <li
              key={s.no}
              className="flex items-center justify-between gap-3 rounded-control border border-border bg-surface p-3"
            >
              <span className="font-medium">
                {s.no}. {s.label}
              </span>
              <span className="text-fg-muted">
                {s.state === 'done' ? 'Xong' : s.state === 'current' ? 'Đang làm' : 'Chưa'}
              </span>
            </li>
          ))}
        </ol>
      </section>
      {d.proposal !== null && d.proposal !== '' && (
        <section aria-label="Phương án" className="flex flex-col gap-2">
          <h2 className="text-caption font-semibold uppercase text-fg-muted">Phương án đề xuất</h2>
          <p className="whitespace-pre-line rounded-control border border-border bg-surface p-3">
            {d.proposal}
          </p>
          {waiting && (
            <>
              <p className="text-caption text-fg-muted">
                Quý phụ huynh xác nhận thì cơ sở mới thực hiện.
              </p>
              {confirm.isError && <Alert tone="danger">{errorOf(confirm.error).message}</Alert>}
              <Button loading={confirm.isPending} onClick={() => confirm.mutate()}>
                Đồng ý phương án
              </Button>
              <Button variant="secondary" onClick={() => setRejecting(true)}>
                Không đồng ý
              </Button>
            </>
          )}
        </section>
      )}
      {canRate && (
        <section aria-label="Đánh giá xử lý" className="flex flex-col gap-2">
          <h2 className="text-caption font-semibold uppercase text-fg-muted">Đánh giá xử lý</h2>
          <p>Quý phụ huynh hài lòng thế nào?</p>
          <div role="group" aria-label="Mức hài lòng" className="flex gap-2">
            {SCORES.map((n) => (
              <button
                key={n}
                type="button"
                aria-pressed={score === n}
                onClick={() => setScore(n)}
                className={cn(
                  'focus-ring min-h-11 flex-1 rounded-control border',
                  score === n
                    ? 'border-transparent bg-selected font-medium text-on-selected'
                    : 'border-border bg-surface',
                )}
              >
                {n}
              </button>
            ))}
          </div>
          <p className="text-caption text-fg-muted">1 là chưa hài lòng, 5 là rất hài lòng.</p>
          {rate.isError && <Alert tone="danger">{errorOf(rate.error).message}</Alert>}
          <Button loading={rate.isPending} disabled={score === null} onClick={() => rate.mutate()}>
            Gửi đánh giá
          </Button>
        </section>
      )}
      {d.satisfaction !== null && (
        <p className="text-fg-muted">Quý phụ huynh đã đánh giá {d.satisfaction}/5.</p>
      )}
      <FormDialog
        open={rejecting}
        onOpenChange={setRejecting}
        title="Không đồng ý phương án"
        confirmLabel="Gửi"
        canSubmit={reason.trim() !== ''}
        busy={reject.isPending}
        error={reject.isError ? errorOf(reject.error).message : null}
        onSubmit={() => reject.mutate()}
      >
        <TextAreaField
          label="Lý do không đồng ý"
          required
          rows={4}
          help="Bắt buộc. Nhân viên chăm sóc sẽ đọc và liên hệ lại."
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />
      </FormDialog>
    </div>
  );
}
