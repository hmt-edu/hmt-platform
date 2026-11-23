// Đặc tả các khối việc theo vai trò của Trang chủ CRM (CHUNG-14): mỗi khối là một hàm đọc có sẵn của màn nguồn (đọc theo quyền và phạm vi cơ sở), lấy số tổng và vài dòng đầu.
import type { useDb } from '../../lib/db';
import { rpc } from '../../lib/db';
import { formatDate, formatMoney } from '../../lib/format';
import { sessionLabel } from '../nhan-xet-cho-gui/parentMessageTypes';
import { KIND_LABELS } from '../viec-cho-duyet/approvalsLogic';
import type { ApprovalPage } from '../viec-cho-duyet/approvalsTypes';
import type { PendingPage } from '../buoi/sessionTypes';
import type { ReceivablePage } from '../thu-tien/treasuryTypes';

/** Số dòng xem nhanh trên Trang chủ (bản vẽ K09b: bốn đến năm dòng); số tổng vẫn đủ. */
const PREVIEW_ROWS = 5; // allow-number: số dòng xem nhanh trên giao diện, không phải ngưỡng nghiệp vụ

export type Line = { key: string; title: string; sub: string; tone?: 'danger' };
export type Loaded = { total: number; lines: Line[] };

export type Spec = {
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
