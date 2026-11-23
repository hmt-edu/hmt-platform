// Đặc tả các khối việc theo vai trò của Trang chủ CRM (CHUNG-14): mỗi khối là một hàm đọc có sẵn của màn nguồn (đọc theo quyền và phạm vi cơ sở), lấy số tổng và vài dòng đầu.
import type { useDb } from '../../lib/db';
import { rpc } from '../../lib/db';
import { formatDate, formatMoney } from '../../lib/format';
import { KIND_LABELS } from '../viec-cho-duyet/approvalsLogic';
import type { ApprovalPage } from '../viec-cho-duyet/approvalsTypes';
import type { PendingPage } from '../buoi/sessionTypes';
import type { ClassPage } from '../lop/classTypes';
import type { TicketPage } from '../ticket/ticketTypes';
import { stateName, type DayPage } from '../diem-danh-ngay/dayLogic';
import { vnDayBounds } from '../../lib/vnDay';
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
  classesPending: {
    title: 'Lớp chờ duyệt',
    to: '/crm/lop',
    empty: 'Không có lớp nào chờ duyệt.',
    load: async (supabase, branch, showBranch) => {
      // Lớp đã trình (DA_TRINH) và đã xác nhận (DA_XAC_NHAN, chờ Duyệt cuối) chờ người có quyền duyệt; hàm đọc có sẵn của màn Lớp học.
      const page = await rpc<ClassPage>(supabase, 'list_classes', {
        p_filters: { status: ['DA_TRINH', 'DA_XAC_NHAN'], ...branch },
        p_sort: 'code_asc',
        p_limit: PREVIEW_ROWS,
        p_offset: 0,
      });
      return {
        total: page.total,
        lines: page.rows.map((r) => ({
          key: r.id,
          title: join([r.code, r.subject_name]),
          sub: join([r.class_type_name, r.level_name, showBranch && r.branch_code]),
        })),
      };
    },
  },
  tickets: {
    title: 'Ticket quá hạn',
    to: '/crm/ticket',
    empty: 'Không có ticket nào quá hạn.',
    load: async (supabase, branch, showBranch) => {
      // Hạn do hàm DB tính (sla_state), giao diện không tự tính.
      const page = await rpc<TicketPage>(supabase, 'list_tickets', {
        p_filters: { sla_state: 'QUA_HAN', ...branch },
        p_limit: PREVIEW_ROWS,
        p_offset: 0,
      });
      return {
        total: page.total,
        lines: page.rows.map((r) => ({
          key: r.id,
          title: r.title,
          sub: join([r.code, r.assignee_name ?? 'Chưa giao', showBranch && r.branch_code]),
          tone: 'danger' as const,
        })),
      };
    },
  },
  sessionsToday: {
    title: 'Buổi hôm nay',
    to: '/crm/diem-danh-trong-ngay',
    empty: 'Hôm nay không có buổi nào.',
    load: async (supabase, branch, showBranch) => {
      // Hàm điểm danh trong ngày (BUOI-15) lọc theo ngày Việt Nam và theo cơ sở đang chọn như các khối khác.
      const page = await rpc<DayPage>(supabase, 'session_day_attendance', {
        p_filters: { date: vnDayBounds().dateKey, ...branch },
        p_limit: PREVIEW_ROWS,
        p_offset: 0,
      });
      return {
        total: page.total,
        lines: page.rows.map((r) => ({
          key: r.session_id,
          title: join([r.class_code, `${r.start_time.slice(0, 5)}–${r.end_time.slice(0, 5)}`]),
          sub: join([r.teacher_name, stateName(r.state), showBranch && r.branch_code]),
          ...(r.state === 'CHUA_GHI' ? { tone: 'danger' as const } : {}),
        })),
      };
    },
  },
} satisfies Record<string, Spec>;

export type RoleBlockId = keyof typeof ROLE_BLOCK_SPECS;
