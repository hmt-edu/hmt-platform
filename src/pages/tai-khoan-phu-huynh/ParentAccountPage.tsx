// QT-17 Tài khoản phụ huynh (danh sách, khuôn K03; canvas QT17_* chưa lưu trong repo: làm theo ghi chú Design 23/11 và khuôn QT-13/QT-02).
// Phụ huynh đăng nhập bằng MÃ PH + mật khẩu trung tâm cấp (CHUNG-23). Chưa cấp: Cấp tài khoản. Đang dùng: Đặt lại mật khẩu, Khoá.
// Đã khoá: Đặt lại mật khẩu + Mở khoá (anh Trường chốt 24/11 23:52: Quản trị mở lại được phụ huynh bị khoá; Đặt lại mật khẩu KHÔNG gỡ khoá). Khoá không bắt lý do. Mật khẩu tạm hiện MỘT lần ở hộp K4g, không lưu,
// không gửi email. Chỉ Admin đã xác thực hai bước (như QT-13). Lọc, tìm, phân trang ở máy chủ.
import { useMemo, useState } from 'react';
import { Button } from '../../ui/Button';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { useToast } from '../../ui/toastContext';
import { ActionConfirmDialog, TempPasswordDialog } from '../nguoi-dung/UserDialogs';
import { resetUserPassword, unlockUser } from '../nguoi-dung/useUserData';
import { EMPTY_PARENT_ACCOUNT_STATE, buildParentAccountConfig } from './parentAccountConfig';
import { buildParentAccountFilters } from './parentAccountFilters';
import type { ParentAccountRow } from './parentAccountTypes';
import {
  issueParentAccount,
  lockParentAccount,
  useParentAccountPage,
  useRefreshParentAccounts,
} from './useParentAccountData';

export function ParentAccountPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshParentAccounts();
  const pageSize = useIntSetting('list_page_size_default');

  const [state, setState] = useState<ListState>(EMPTY_PARENT_ACCOUNT_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [issuing, setIssuing] = useState<ParentAccountRow | null>(null);
  const [resetting, setResetting] = useState<ParentAccountRow | null>(null);
  const [locking, setLocking] = useState<ParentAccountRow | null>(null);
  const [unlocking, setUnlocking] = useState<ParentAccountRow | null>(null);
  const [temp, setTemp] = useState<{ password: string; name: string } | null>(null);

  const canEdit = access.can('ADMIN', 'SUA');

  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildParentAccountFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useParentAccountPage(filters, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const errorText = list.isError ? errorOf(list.error).message : null;

  const config = useMemo(
    () =>
      buildParentAccountConfig(
        access.allBranches.map((b) => ({ id: b.id, label: `${b.code} ${b.name}` })),
        (row) => {
          if (!canEdit) return null;
          if (row.state === 'CHUA_CAP')
            return <Button onClick={() => setIssuing(row)}>Cấp tài khoản</Button>;
          return (
            <span className="flex flex-wrap gap-1.5">
              <Button onClick={() => setResetting(row)}>Đặt lại mật khẩu</Button>
              {row.state === 'HOAT_DONG' && <Button onClick={() => setLocking(row)}>Khoá</Button>}
              {row.state === 'BI_KHOA' && (
                <Button onClick={() => setUnlocking(row)}>Mở khoá</Button>
              )}
            </span>
          );
        },
      ),
    [access, canEdit],
  );

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
        rowKey={(r) => r.parent_id}
        rowLabel={(r) => `${r.parent_code} ${r.full_name}`}
        loading={list.isPending || list.isPlaceholderData}
        error={errorText}
        onRetry={() => void list.refetch()}
        actions={[]}
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
        sort={null}
        onSortChange={() => undefined}
        emptyMessage={{
          title: 'Chưa có phụ huynh',
          hint: 'Không có phụ huynh nào trong bộ lọc này. Hồ sơ phụ huynh tự sinh khi có phiếu kiểm tra đầu vào hoặc đơn được duyệt.',
        }}
      />
      <ActionConfirmDialog
        open={issuing !== null}
        onOpenChange={(open) => !open && setIssuing(null)}
        name={issuing ? `${issuing.parent_code} ${issuing.full_name}` : ''}
        title="Cấp tài khoản phụ huynh"
        description="Tên đăng nhập là mã PH. Hệ thống sinh mật khẩu tạm, hiện một lần; không gửi email. Anh chị chuyển mật khẩu cho phụ huynh."
        confirmLabel="Cấp tài khoản"
        onConfirm={async () => {
          const password = await issueParentAccount(supabase, issuing?.parent_code ?? '');
          setTemp({ password, name: issuing?.full_name ?? '' });
        }}
        onDone={() => done(`Đã cấp tài khoản cho ${issuing?.full_name ?? 'phụ huynh'}.`)}
      />
      <ActionConfirmDialog
        open={resetting !== null}
        onOpenChange={(open) => !open && setResetting(null)}
        name={resetting ? `${resetting.parent_code} ${resetting.full_name}` : ''}
        title="Đặt lại mật khẩu"
        description="Hệ thống sinh mật khẩu tạm mới, hiện một lần; mật khẩu cũ hết hiệu lực và phụ huynh bị đăng xuất khỏi mọi thiết bị."
        confirmLabel="Đặt lại mật khẩu"
        onConfirm={async () => {
          const password = await resetUserPassword(supabase, resetting?.user_id ?? '');
          setTemp({ password, name: resetting?.full_name ?? '' });
        }}
        onDone={() => done(`Đã đặt lại mật khẩu cho ${resetting?.full_name ?? 'phụ huynh'}.`)}
      />
      <ActionConfirmDialog
        open={locking !== null}
        onOpenChange={(open) => !open && setLocking(null)}
        name={locking ? `${locking.parent_code} ${locking.full_name}` : ''}
        title="Khoá tài khoản"
        description="Phụ huynh không đăng nhập được nữa và bị đăng xuất khỏi mọi thiết bị. Muốn vào lại thì Mở khoá."
        confirmLabel="Khoá"
        onConfirm={() => lockParentAccount(supabase, locking?.user_id ?? '')}
        onDone={() => done(`Đã khoá tài khoản của ${locking?.full_name ?? 'phụ huynh'}.`)}
      />
      <ActionConfirmDialog
        open={unlocking !== null}
        onOpenChange={(open) => !open && setUnlocking(null)}
        name={unlocking ? `${unlocking.parent_code} ${unlocking.full_name}` : ''}
        title="Mở khoá tài khoản"
        description="Phụ huynh đăng nhập lại được bằng mật khẩu hiện có. Quên mật khẩu thì Đặt lại mật khẩu."
        confirmLabel="Mở khoá"
        onConfirm={() => unlockUser(supabase, unlocking?.user_id ?? '')}
        onDone={() => done(`Đã mở khoá tài khoản của ${unlocking?.full_name ?? 'phụ huynh'}.`)}
      />
      <TempPasswordDialog
        password={temp?.password ?? null}
        name={temp?.name ?? ''}
        onClose={() => setTemp(null)}
      />
    </>
  );
}
