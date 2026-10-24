// QT-01 Người dùng (danh sách, khuôn K03): tài khoản nhân viên, giáo viên, trợ giảng. Chỉ Admin đã xác thực hai bước. Lọc, tìm, sắp
// xếp, phân trang ở máy chủ. Xuất (chỉ Admin, Đ45) tải CSV. Khoá, Mở khoá ngay ở dòng. Tạo người dùng (QT-03) cần hộp mật khẩu tạm
// K4g, K4e4 (chờ #69): chưa có nút Tạo.
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { Button } from '../../ui/Button';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { useToast } from '../../ui/toastContext';
import { downloadText, toCsv } from '../lead/csv';
import { ActionConfirmDialog, LockDialog } from './UserDialogs';
import { EMPTY_USER_STATE, buildUserConfig, userPath } from './userConfig';
import { buildUserFilters, userSortParam } from './userFilters';
import type { UserRow } from './userTypes';
import { exportUsers, lockUser, unlockUser, useRefreshUsers, useUserPage } from './useUserData';

const EXPORT_COLUMNS = [
  { key: 'staff_code', label: 'Mã NV/GV/TG' },
  { key: 'display_name', label: 'Tên' },
  { key: 'login_name', label: 'Email đăng nhập' },
  { key: 'roles', label: 'Vai trò' },
  { key: 'branch', label: 'Cơ sở' },
  { key: 'status', label: 'Trạng thái' },
];

export function UserListPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const navigate = useNavigate();
  const refreshData = useRefreshUsers();
  const pageSize = useIntSetting('list_page_size_default');

  const [state, setState] = useState<ListState>(EMPTY_USER_STATE);
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [exporting, setExporting] = useState(false);
  const [locking, setLocking] = useState<UserRow | null>(null);
  const [unlocking, setUnlocking] = useState<UserRow | null>(null);

  const canEdit = access.can('ADMIN', 'SUA');
  const canExport = access.can('ADMIN', 'XUAT');

  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildUserFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const sortValue = userSortParam(sort?.key ?? null, sort?.direction ?? null);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useUserPage(filters, sortValue, page * (pageSize ?? 0), pageSize, true);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const errorText = list.isError ? errorOf(list.error).message : null;

  const config = useMemo(
    () =>
      buildUserConfig(
        access.allRoles,
        access.allBranches.map((b) => ({ id: b.id, label: `${b.code} ${b.name}` })),
        (row) =>
          canEdit ? (
            row.is_locked ? (
              <Button onClick={() => setUnlocking(row)}>Mở khoá</Button>
            ) : (
              <Button onClick={() => setLocking(row)}>Khoá</Button>
            )
          ) : null,
      ),
    [access, canEdit],
  );

  async function exportFile() {
    if (exporting) return;
    setExporting(true);
    try {
      const result = await exportUsers(supabase, filters);
      downloadText(`nguoi-dung-${vnDayBounds().dateKey}.csv`, toCsv(result.rows, EXPORT_COLUMNS));
      toast(
        result.truncated
          ? {
              tone: 'warning',
              title: `Đã xuất ${result.exported} trên ${result.total} dòng (quá giới hạn mỗi lần xuất). Thêm bộ lọc để xuất phần còn lại.`,
            }
          : { title: `Đã xuất ${result.exported} dòng.` },
      );
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setExporting(false);
    }
  }

  const done = (message: string) => {
    void refreshData();
    toast({ title: message });
  };

  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view="list"
        onViewChange={() => undefined}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => r.display_name}
        loading={list.isPending || list.isPlaceholderData}
        error={errorText}
        onRetry={() => void list.refetch()}
        actions={
          canExport
            ? [
                {
                  label: 'Xuất',
                  icon: 'download' as const,
                  onClick: () => void exportFile(),
                  loading: exporting,
                },
              ]
            : []
        }
        onRefresh={() => void refreshData()}
        pager={{
          from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
          to: page * (pageSize ?? 0) + rows.length,
          total,
          ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
          ...(page * (pageSize ?? 0) + rows.length < total
            ? { onNext: () => setPage(page + 1) }
            : {}),
        }}
        sort={sort}
        onSortChange={(next) => setSort(next?.key === 'last_login' ? next : null)}
        onRowClick={(r) => void navigate(userPath(r.id))}
        emptyMessage={{
          title: 'Chưa có người dùng',
          hint: 'Không có tài khoản nào trong bộ lọc này. Đổi bộ lọc để xem tiếp.',
        }}
      />
      <LockDialog
        open={locking !== null}
        onOpenChange={(open) => !open && setLocking(null)}
        name={locking?.display_name ?? ''}
        onLock={(reason) => lockUser(supabase, locking?.id ?? '', reason)}
        onDone={() => done(`Đã khoá ${locking?.display_name ?? 'tài khoản'}.`)}
      />
      <ActionConfirmDialog
        open={unlocking !== null}
        onOpenChange={(open) => !open && setUnlocking(null)}
        name={unlocking?.display_name ?? ''}
        title="Mở khoá tài khoản"
        description="Người này đăng nhập lại được bằng mật khẩu hiện có."
        confirmLabel="Mở khoá"
        onConfirm={() => unlockUser(supabase, unlocking?.id ?? '')}
        onDone={() => done(`Đã mở khoá ${unlocking?.display_name ?? 'tài khoản'}.`)}
      />
    </>
  );
}
