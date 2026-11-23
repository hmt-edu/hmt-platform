// Các khối việc theo vai trò của Trang chủ CRM (CHUNG-14, K09): mỗi khối là một hàm đọc có sẵn của màn nguồn, lấy số tổng và vài dòng đầu
// (đọc theo quyền và phạm vi cơ sở của người xem), kèm «Xem tất cả» mở màn nguồn. Không tính nghiệp vụ ở giao diện.
import { useQuery } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { rpc, useDb } from '../../lib/db';
import { formatDate, formatMoney } from '../../lib/format';
import { ALL_BRANCHES } from '../../nav/access';
import { useAccess } from '../../nav/AccessContext';
import { sessionLabel } from '../nhan-xet-cho-gui/parentMessageTypes';
import { KIND_LABELS } from '../viec-cho-duyet/approvalsLogic';
import type { ApprovalPage } from '../viec-cho-duyet/approvalsTypes';
import type { PendingPage } from '../buoi/sessionTypes';
import type { ReceivablePage } from '../thu-tien/treasuryTypes';
import { ButtonLink } from '../../ui/Button';
import { Skeleton } from '../../ui/Data';
import { Button } from '../../ui/Button';
import { StateView } from '../../ui/Feedback';

/** Số dòng xem nhanh trên Trang chủ (bản vẽ K09b: bốn đến năm dòng); số tổng vẫn đủ. */
const PREVIEW_ROWS = 5; // allow-number: số dòng xem nhanh trên giao diện, không phải ngưỡng nghiệp vụ

type Line = { key: string; title: string; sub: string; tone?: 'danger' };
type Loaded = { total: number; lines: Line[] };

type Spec = {
  title: string;
  to: string;
  empty: string;
  load: (
    supabase: ReturnType<typeof useDb>,
    branch: Record<string, string>,
    showBranch: boolean,
  ) => Promise<Loaded>;
};

const join = (parts: (string | null | undefined | false)[]) => parts.filter(Boolean).join(' · ');

export const ROLE_BLOCK_SPECS = {
  approvals: {
    title: 'Việc chờ tôi duyệt',
    to: '/crm/viec-cho-duyet',
    empty: 'Không có việc nào chờ bạn duyệt.',
    load: async (supabase, branch, showBranch) => {
      const page = await rpc<ApprovalPage>(supabase, 'list_my_approvals', {
        p_filters: branch,
        p_limit: PREVIEW_ROWS,
        p_offset: 0,
      });
      return {
        total: page.total,
        lines: page.rows.map((r) => ({
          key: `${r.kind}-${r.ref_id}`,
          title: r.subject_name ?? r.detail ?? r.code,
          sub: join([KIND_LABELS[r.kind], r.code, showBranch && r.branch_code]),
        })),
      };
    },
  },
  reviews: {
    title: 'Nhận xét chờ gửi phụ huynh',
    to: '/crm/nhan-xet-cho-gui',
    empty: 'Không có nhận xét nào chờ gửi.',
    load: async (supabase, branch) => {
      const page = await rpc<{
        total: number;
        rows: {
          id: string;
          student_name: string;
          class_code: string;
          session_no: number | null;
          session_date: string;
        }[];
      }>(supabase, 'list_parent_messages', {
        p_filters: { status: 'CHO_GUI', ...branch },
        p_limit: PREVIEW_ROWS,
        p_offset: 0,
      });
      return {
        total: page.total,
        lines: page.rows.map((r) => ({
          key: r.id,
          title: r.student_name,
          sub: join([r.class_code, sessionLabel(r.session_no, r.session_date)]),
        })),
      };
    },
  },
  sessions: {
    title: 'Buổi chưa hoàn tất',
    to: '/crm/buoi-chua-done',
    empty: 'Không có buổi nào đang chờ hoàn tất.',
    load: async (supabase, branch) => {
      const page = await rpc<PendingPage>(supabase, 'session_pending_list', {
        p_filters: branch,
        p_limit: PREVIEW_ROWS,
        p_offset: 0,
      });
      return {
        total: page.total,
        lines: page.rows.map((r) => ({
          key: r.id,
          title: join([r.subject_name, r.class_code]),
          sub: join([
            r.session_no ? `Buổi ${String(r.session_no)}` : null,
            formatDate(r.session_date),
            r.teacher_name,
          ]),
          ...(r.minutes_left < 0 ? { tone: 'danger' as const } : {}),
        })),
      };
    },
  },
  debt: {
    title: 'Công nợ quá hạn',
    to: '/crm/cong-no',
    empty: 'Không có khoản nào quá hạn.',
    load: async (supabase, branch, showBranch) => {
      const page = await rpc<ReceivablePage>(supabase, 'list_receivables', {
        p_filters: { status: ['QUA_HAN'], ...branch },
        p_limit: PREVIEW_ROWS,
        p_offset: 0,
      });
      return {
        total: page.total,
        lines: page.rows.map((r) => ({
          key: `${r.order_id}-${String(r.seq)}`,
          title: r.parent_name,
          sub: join([
            r.order_code,
            `Đợt ${String(r.seq)}/${String(r.seq_count)}`,
            formatMoney(r.owed),
            showBranch && r.branch_code,
          ]),
          tone: 'danger' as const,
        })),
      };
    },
  },
} satisfies Record<string, Spec>;

export type RoleBlockId = keyof typeof ROLE_BLOCK_SPECS;

/** Một khối việc: tiêu đề + số tổng + vài dòng đầu + «Xem tất cả»; có trạng thái tải, rỗng, lỗi và Thử lại. */
export function RoleBlock({ id }: { id: RoleBlockId }) {
  const spec: Spec = ROLE_BLOCK_SPECS[id];
  const supabase = useDb();
  const access = useAccess();
  // Admin, Kế toán chọn cơ sở ở thanh trên thì số liệu theo cơ sở đó; người một cơ sở do RLS quyết.
  const branch =
    access.seesAllBranches && access.selectedBranch !== ALL_BRANCHES
      ? { branch_id: access.selectedBranch }
      : {};
  const query = useQuery({
    queryKey: ['home-role-block', id, branch],
    queryFn: () => spec.load(supabase, branch, access.seesAllBranches),
  });

  let body: ReactNode;
  if (query.isPending) {
    body = <Skeleton className="h-40 w-full" />;
  } else if (query.isError) {
    body = (
      <StateView
        kind="error"
        title="Không tải được khối này"
        headingLevel={3}
        actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
      >
        Kiểm tra kết nối rồi thử lại.
      </StateView>
    );
  } else if (query.data.lines.length === 0) {
    body = <p className="py-4 text-fg-muted">{spec.empty}</p>;
  } else {
    body = (
      <ul className="flex flex-col divide-y divide-border">
        {query.data.lines.map((line) => (
          <li key={line.key} className="flex flex-col py-2.5">
            <span
              className={
                line.tone === 'danger' ? 'truncate font-medium text-danger' : 'truncate font-medium'
              }
            >
              {line.title}
            </span>
            <span className="truncate text-caption text-fg-muted">{line.sub}</span>
          </li>
        ))}
      </ul>
    );
  }

  return (
    <section
      aria-labelledby={`home-${id}`}
      className="flex flex-col gap-3 rounded-card border border-border bg-surface p-4"
    >
      <div className="flex items-center justify-between gap-2">
        <h2 id={`home-${id}`} className="text-h4">
          {spec.title}
        </h2>
        {query.data && (
          <span className="tabular rounded-full bg-brand-50 px-2 text-caption font-semibold text-brand-800">
            {query.data.total}
          </span>
        )}
      </div>
      {body}
      <div className="flex flex-col items-start gap-2">
        <ButtonLink to={spec.to}>Xem tất cả</ButtonLink>
      </div>
    </section>
  );
}
