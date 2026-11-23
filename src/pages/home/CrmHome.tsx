import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useAuth } from '../../lib/auth/authContext';
import { formatVnDayLong, formatVnTime } from '../../lib/vnDay';
import { ALL_BRANCHES } from '../../nav/access';
import { useAccess } from '../../nav/AccessContext';
import type { PermissionRow } from '../../nav/accessData';
import { Button, ButtonLink } from '../../ui/Button';
import { Skeleton } from '../../ui/Data';
import { Alert, StateView } from '../../ui/Feedback';
import { cn } from '../../ui/cn';
import { Icon } from '../../ui/icons';
import { HOME_BLOCKS, visibleHomeBlocks } from './homeBlocks';
import { RoleBlock } from './roleBlocks';
import { useAppointmentsToday } from './useAppointmentsToday';

/** Vai trò làm việc ở cổng CRM để Admin xem thử bố cục (đọc từ bảng vai trò, không viết cứng tên vai trò). */
function usePreviewRoles() {
  const access = useAccess();
  return access.crmRoles;
}

/** Quyền của một vai trò (chỉ để vẽ thử bố cục; Admin đọc được bảng quyền). */
function usePreviewPermissions(roleCode: string | null) {
  const { supabase } = useAuth();
  return useQuery({
    queryKey: ['home-preview-permissions', roleCode],
    enabled: Boolean(supabase && roleCode),
    queryFn: async (): Promise<PermissionRow[]> => {
      if (!supabase || !roleCode) return [];
      const { data, error } = await supabase
        .schema('app')
        .from('permission')
        .select('role_code, module_code, action_code, scope_code')
        .eq('is_active', true)
        .eq('role_code', roleCode);
      if (error) throw new Error(error.message);
      return data ?? [];
    },
  });
}

function StatTile({ label, value, tone }: { label: string; value: number; tone?: 'danger' }) {
  return (
    <div className="flex flex-col gap-1 rounded-card border border-border bg-surface p-4">
      <span className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
        {label}
      </span>
      <span
        className={cn(
          'tabular font-display text-display',
          tone === 'danger' && value > 0 && 'text-danger',
        )}
      >
        {value}
      </span>
    </div>
  );
}

/** Khối "Lịch hẹn" của Trang chủ: thẻ số HÔM NAY và QUÁ HẠN, danh sách lịch hẹn Chưa làm hôm nay (TS-12). */
function AppointmentsBlock() {
  const access = useAccess();
  // Admin, Kế toán chọn cơ sở ở thanh trên thì số liệu theo cơ sở đó; người một cơ sở do RLS quyết.
  const branchId =
    access.seesAllBranches && access.selectedBranch !== ALL_BRANCHES ? access.selectedBranch : null;
  const query = useAppointmentsToday(branchId);

  if (query.isPending)
    return (
      <div className="flex flex-col gap-3" aria-busy="true">
        <Skeleton className="h-24 w-full" />
        <Skeleton className="h-56 w-full" />
      </div>
    );
  if (query.isError)
    return (
      <div className="rounded-card border border-border bg-surface">
        <StateView
          kind="error"
          title="Không tải được lịch hẹn"
          headingLevel={2}
          actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
        >
          Kiểm tra kết nối rồi thử lại.
        </StateView>
      </div>
    );

  const { todayTotal, rows, overdue } = query.data;
  return (
    <section aria-labelledby="home-appointments" className="flex flex-col gap-3">
      <div className="grid grid-cols-2 gap-3">
        <StatTile label="Hôm nay" value={todayTotal} />
        <StatTile label="Quá hạn" value={overdue} tone="danger" />
      </div>
      <div className="flex flex-col gap-3 rounded-card border border-border bg-surface p-4">
        <div className="flex items-center justify-between gap-2">
          <h2 id="home-appointments" className="text-h4">
            Lịch hẹn hôm nay
          </h2>
          <span className="tabular rounded-full bg-brand-50 px-2 text-caption font-semibold text-brand-800">
            {todayTotal}
          </span>
        </div>
        {rows.length === 0 ? (
          <p className="py-4 text-fg-muted">Hôm nay không còn lịch hẹn nào cần làm.</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {rows.map((row) => (
              <li key={row.id} className="flex gap-3 py-2.5">
                <span className="tabular w-12 shrink-0 font-semibold">
                  {formatVnTime(row.scheduled_at)}
                </span>
                <span className="flex min-w-0 flex-col">
                  <span className="truncate font-medium">{row.title}</span>
                  <span className="truncate text-caption text-fg-muted">
                    {[
                      row.record_label,
                      row.record_code,
                      access.seesAllBranches ? row.branch_code : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                </span>
              </li>
            ))}
          </ul>
        )}
        <div className="flex flex-col items-start gap-2">
          <ButtonLink to="/crm/lich-hen">Mở danh sách</ButtonLink>
          <p className="text-caption text-fg-muted">
            <Icon name="arrowRight" size={16} className="mr-1 inline align-text-bottom" />
            Danh sách lịch hẹn, lọc “của tôi, hôm nay”
          </p>
        </div>
      </div>
    </section>
  );
}

const BLOCK_VIEW = {
  appointments: AppointmentsBlock,
  approvals: () => <RoleBlock id="approvals" />,
  sessions: () => <RoleBlock id="sessions" />,
  debt: () => <RoleBlock id="debt" />,
} as const;

/**
 * CHUNG-14 · Trang chủ CRM: "Việc của tôi hôm nay" (K09b, TS-12). Chỉ nhắc việc; KPI để báo cáo.
 * Khối hiện theo ma trận quyền và công tắc tính năng. Admin có thể xem thử bố cục của vai trò khác:
 * chỉ đổi khối nào hiện, số liệu vẫn theo quyền thật của người xem.
 */
export function CrmHome() {
  const access = useAccess();
  const roles = usePreviewRoles();
  const [previewRole, setPreviewRole] = useState<string | null>(null);
  const preview = usePreviewPermissions(previewRole);
  const canPreview = access.can('ADMIN', 'XEM');

  const previewing = canPreview && previewRole !== null;
  const granted = new Set((preview.data ?? []).map((p) => `${p.module_code}|${p.action_code}`));
  const can = previewing
    ? (module: string, action: string) =>
        module === '*'
          ? [...granted].some((g) => g.endsWith(`|${action}`))
          : granted.has(`${module}|${action}`)
    : (module: string, action: string) =>
        module === '*' ? access.canAnyModule(action) : access.can(module, action);
  const blocks =
    previewing && preview.isPending ? [] : visibleHomeBlocks(HOME_BLOCKS, can, access.featureOn);
  const previewName = roles.find((r) => r.code === previewRole)?.name ?? '';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="flex flex-col gap-1">
          <h1 className="text-h1">Việc của tôi hôm nay</h1>
          <p className="text-fg-muted">
            {formatVnDayLong()} · Mỗi khối chỉ hiện việc thuộc quyền của bạn
          </p>
        </div>
        {canPreview && (
          <div
            className="flex flex-wrap items-center gap-2"
            role="group"
            aria-label="Xem thử vai trò"
          >
            <span className="text-caption text-fg-muted">Xem thử vai trò</span>
            <Button
              size="sm"
              variant={previewRole === null ? 'primary' : 'secondary'}
              aria-pressed={previewRole === null}
              onClick={() => setPreviewRole(null)}
            >
              Của tôi
            </Button>
            {roles.map((r) => (
              <Button
                key={r.code}
                size="sm"
                variant={previewRole === r.code ? 'primary' : 'secondary'}
                aria-pressed={previewRole === r.code}
                onClick={() => setPreviewRole(r.code)}
              >
                {r.name}
              </Button>
            ))}
          </div>
        )}
      </div>
      {previewing && (
        <Alert tone="info">
          Đang xem thử bố cục của vai trò {previewName}. Chỉ đổi khối nào hiện; số liệu vẫn theo
          quyền thật của bạn.
        </Alert>
      )}
      {previewing && preview.isError ? (
        <Alert tone="danger">Không tải được quyền của vai trò này. Thử lại sau.</Alert>
      ) : blocks.length === 0 && !(previewing && preview.isPending) ? (
        <div className="rounded-card border border-border bg-surface">
          <StateView kind="empty" title="Chưa có mục nhắc việc nào cho bạn." headingLevel={2} />
        </div>
      ) : (
        <div className="grid gap-4 lg:grid-cols-3">
          {blocks.map((b) => {
            const View = BLOCK_VIEW[b.id];
            return <View key={b.id} />;
          })}
        </div>
      )}
    </div>
  );
}
