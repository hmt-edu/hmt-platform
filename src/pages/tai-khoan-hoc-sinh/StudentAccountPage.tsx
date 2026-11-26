// QT-13 Tài khoản học sinh (danh sách, khuôn K03): mọi học sinh kèm tình trạng tài khoản đăng nhập app học tập (Chưa cấp, Đang dùng,
// Đã khoá). Chỉ Admin đã xác thực hai bước (R-CRM-32). Cấp tài khoản theo mã HS (một em ở dòng, nhiều em: chọn dòng rồi «Cấp tài khoản»),
// Đặt lại mật khẩu, Khoá, Mở khoá. Mật khẩu tạm hiện MỘT lần (một em: hộp K4g; nhiều em: tải file một lần), không lưu ở đâu, không bao
// giờ mang mật khẩu hệ thống cũ sang. Lọc, tìm, phân trang ở máy chủ.
import { useMemo, useState } from 'react';
import { Button } from '../../ui/Button';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { BulkActionBar } from '../../ui/Data';
import { useToast } from '../../ui/toastContext';
import { downloadText, toCsv } from '../lead/csv';
import { ActionConfirmDialog, LockDialog, TempPasswordDialog } from '../nguoi-dung/UserDialogs';
import { lockUser, resetUserPassword, unlockUser } from '../nguoi-dung/useUserData';
import { EMPTY_STUDENT_ACCOUNT_STATE, buildStudentAccountConfig } from './studentAccountConfig';
import { buildStudentAccountFilters, issuable } from './studentAccountFilters';
import type { StudentAccountRow } from './studentAccountTypes';
import {
  issueStudentAccount,
  issueStudentAccounts,
  useRefreshStudentAccounts,
  useStudentAccountPage,
} from './useStudentAccountData';

const EXPORT_COLUMNS = [
  { key: 'student_code', label: 'Mã HS (tên đăng nhập)' },
  { key: 'full_name', label: 'Học sinh' },
  { key: 'password', label: 'Mật khẩu tạm' },
  { key: 'error', label: 'Lỗi' },
];

export function StudentAccountPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshStudentAccounts();
  const pageSize = useIntSetting('list_page_size_default');

  const [state, setState] = useState<ListState>(EMPTY_STUDENT_ACCOUNT_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [issuing, setIssuing] = useState<StudentAccountRow | null>(null);
  const [issuingMany, setIssuingMany] = useState<StudentAccountRow[] | null>(null);
  const [resetting, setResetting] = useState<StudentAccountRow | null>(null);
  const [locking, setLocking] = useState<StudentAccountRow | null>(null);
  const [unlocking, setUnlocking] = useState<StudentAccountRow | null>(null);
  const [temp, setTemp] = useState<{ password: string; name: string } | null>(null);

  const canEdit = access.can('ADMIN', 'SUA');

  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildStudentAccountFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useStudentAccountPage(filters, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const errorText = list.isError ? errorOf(list.error).message : null;
  const chosen = issuable(rows, selected);

  const config = useMemo(
    () =>
      buildStudentAccountConfig(
        access.allBranches.map((b) => ({ id: b.id, label: `${b.code} ${b.name}` })),
        (row) => {
          if (!canEdit) return null;
          if (row.state === 'CHUA_CAP')
            return <Button onClick={() => setIssuing(row)}>Cấp tài khoản</Button>;
          return (
            <span className="flex flex-wrap gap-1.5">
              <Button onClick={() => setResetting(row)}>Đặt lại mật khẩu</Button>
              {row.state === 'BI_KHOA' ? (
                <Button onClick={() => setUnlocking(row)}>Mở khoá</Button>
              ) : (
                <Button onClick={() => setLocking(row)}>Khoá</Button>
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

  async function issueMany(targets: StudentAccountRow[]) {
    setBusyKey('many');
    try {
      const results = await issueStudentAccounts(supabase, targets);
      const ok = results.filter((r) => r.password !== null);
      const failed = results.length - ok.length;
      downloadText(
        `tai-khoan-hoc-sinh-${vnDayBounds().dateKey}.csv`,
        toCsv(results, EXPORT_COLUMNS),
      );
      setSelected(new Set());
      void refreshData();
      toast(
        failed > 0
          ? {
              tone: 'warning',
              title: `Đã cấp ${ok.length}/${results.length} học sinh; ${failed} học sinh lỗi (xem cột Lỗi trong file vừa tải). File chứa mật khẩu tạm, chỉ có một lần này.`,
            }
          : {
              title: `Đã cấp ${ok.length} tài khoản. File vừa tải chứa mật khẩu tạm, chỉ có một lần này.`,
            },
      );
    } finally {
      setBusyKey(null);
    }
  }

  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view="list"
        onViewChange={() => undefined}
        rows={rows}
        rowKey={(r) => r.student_id}
        rowLabel={(r) => `${r.student_code} ${r.full_name}`}
        loading={list.isPending || list.isPlaceholderData}
        error={errorText}
        onRetry={() => void list.refetch()}
        actions={[]}
        onRefresh={() => void refreshData()}
        selected={canEdit ? selected : undefined}
        onSelectedChange={canEdit ? setSelected : undefined}
        bulk={
          canEdit ? (
            <BulkActionBar count={selected.size} onClear={() => setSelected(new Set())}>
              <Button
                variant="primary"
                disabled={chosen.length === 0 || busyKey !== null}
                onClick={() => setIssuingMany(chosen)}
              >
                {`Cấp tài khoản (${chosen.length})`}
              </Button>
            </BulkActionBar>
          ) : undefined
        }
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
          title: 'Chưa có học sinh',
          hint: 'Không có học sinh nào trong bộ lọc này. Hồ sơ học sinh tự sinh khi có phiếu Test hoặc đơn được duyệt.',
        }}
      />
      <ActionConfirmDialog
        open={issuing !== null}
        onOpenChange={(open) => !open && setIssuing(null)}
        name={issuing ? `${issuing.student_code} ${issuing.full_name}` : ''}
        title="Cấp tài khoản học sinh"
        description="Tên đăng nhập là mã HS. Hệ thống sinh mật khẩu tạm, hiện một lần; học sinh đổi mật khẩu ở lần đăng nhập đầu."
        confirmLabel="Cấp tài khoản"
        onConfirm={async () => {
          const password = await issueStudentAccount(supabase, issuing?.student_code ?? '');
          setTemp({ password, name: issuing?.full_name ?? '' });
        }}
        onDone={() => done(`Đã cấp tài khoản cho ${issuing?.full_name ?? 'học sinh'}.`)}
      />
      <ActionConfirmDialog
        open={issuingMany !== null}
        onOpenChange={(open) => !open && setIssuingMany(null)}
        name={`${issuingMany?.length ?? 0} học sinh chưa có tài khoản`}
        title="Cấp tài khoản hàng loạt"
        description="Mỗi học sinh một tài khoản, tên đăng nhập là mã HS. Mật khẩu tạm của cả đợt nằm trong một file tải về, chỉ có một lần; hệ thống không lưu."
        confirmLabel="Cấp và tải file"
        onConfirm={() => issueMany(issuingMany ?? [])}
        onDone={() => undefined}
      />
      <ActionConfirmDialog
        open={resetting !== null}
        onOpenChange={(open) => !open && setResetting(null)}
        name={resetting ? `${resetting.student_code} ${resetting.full_name}` : ''}
        title="Đặt lại mật khẩu"
        description="Hệ thống sinh mật khẩu tạm mới, hiện một lần; mật khẩu cũ hết hiệu lực và học sinh bị đăng xuất khỏi mọi thiết bị."
        confirmLabel="Đặt lại mật khẩu"
        onConfirm={async () => {
          const password = await resetUserPassword(supabase, resetting?.user_id ?? '');
          setTemp({ password, name: resetting?.full_name ?? '' });
        }}
        onDone={() => done(`Đã đặt lại mật khẩu cho ${resetting?.full_name ?? 'học sinh'}.`)}
      />
      <LockDialog
        open={locking !== null}
        onOpenChange={(open) => !open && setLocking(null)}
        name={locking?.full_name ?? ''}
        onLock={(reason) => lockUser(supabase, locking?.user_id ?? '', reason)}
        onDone={() => done(`Đã khoá tài khoản của ${locking?.full_name ?? 'học sinh'}.`)}
      />
      <ActionConfirmDialog
        open={unlocking !== null}
        onOpenChange={(open) => !open && setUnlocking(null)}
        name={unlocking?.full_name ?? ''}
        title="Mở khoá tài khoản"
        description="Học sinh đăng nhập lại được bằng mật khẩu hiện có."
        confirmLabel="Mở khoá"
        onConfirm={() => unlockUser(supabase, unlocking?.user_id ?? '')}
        onDone={() => done(`Đã mở khoá tài khoản của ${unlocking?.full_name ?? 'học sinh'}.`)}
      />
      <TempPasswordDialog
        password={temp?.password ?? null}
        name={temp?.name ?? ''}
        onClose={() => setTemp(null)}
      />
    </>
  );
}
