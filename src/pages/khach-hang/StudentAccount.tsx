// Tài khoản app học sinh trên hồ sơ (khung KH05_day_du): dùng lại thao tác của màn Tài khoản học sinh (QT-13).
// Chỉ quản trị viên xem và thao tác; máy chủ kiểm quyền.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection } from '../../record/Detail';
import type { MenuItem } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { ActionConfirmDialog, LockDialog, TempPasswordDialog } from '../nguoi-dung/UserDialogs';
import { lockUser, resetUserPassword, unlockUser } from '../nguoi-dung/useUserData';
import { STATE_LABEL } from '../tai-khoan-hoc-sinh/studentAccountConfig';
import type { StudentAccountPage } from '../tai-khoan-hoc-sinh/studentAccountTypes';
import { issueStudentAccount } from '../tai-khoan-hoc-sinh/useStudentAccountData';
import type { StudentRecord } from './custTypes';

type Action = 'issue' | 'reset' | 'lock' | 'unlock';

export function useStudentAccount(record: StudentRecord) {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const client = useQueryClient();
  const canView = access.can('ADMIN', 'XEM');
  const query = useQuery({
    queryKey: ['student-record', record.id, 'account'],
    enabled: canView,
    queryFn: async () => {
      const page = await rpc<StudentAccountPage>(supabase, 'list_student_accounts', {
        p_filters: { q: record.code },
      });
      return page.rows.find((r) => r.student_id === record.id) ?? null;
    },
  });
  const row = query.data ?? null;
  const [action, setAction] = useState<Action | null>(null);
  const [password, setPassword] = useState<string | null>(null);
  const name = `${record.code} ${record.full_name}`;
  const close = (open: boolean) => {
    if (!open) setAction(null);
  };
  const done = (message: string) => {
    void client.invalidateQueries({ queryKey: ['student-record', record.id, 'account'] });
    void client.invalidateQueries({ queryKey: ['student-account-list'] });
    toast({ title: message });
  };

  const blocked =
    record.record_status === 'DA_GOP'
      ? 'Hồ sơ đã gộp chỉ xem được'
      : !access.can('ADMIN', 'SUA')
        ? 'Chỉ quản trị viên được quản lý tài khoản học sinh'
        : query.isError
          ? errorOf(query.error).message
          : query.isPending
            ? 'Đang tải tài khoản'
            : row === null
              ? 'Không tìm thấy tài khoản của học sinh này'
              : null;
  const item = (label: string, next: Action, reason: string | null): MenuItem => ({
    kind: 'action',
    label,
    onSelect: () => setAction(next),
    ...((blocked ?? reason) ? { unavailable: blocked ?? reason ?? '' } : {}),
  });
  const none = row?.state === 'CHUA_CAP' ? 'Học sinh chưa có tài khoản' : null;
  const menuItems: MenuItem[] = [
    item(
      'Cấp tài khoản',
      'issue',
      row && row.state !== 'CHUA_CAP' ? 'Học sinh đã có tài khoản' : null,
    ),
    item('Đặt lại mật khẩu', 'reset', none),
    row?.state === 'BI_KHOA'
      ? item('Mở khoá tài khoản', 'unlock', null)
      : item('Khoá tài khoản', 'lock', none),
  ];

  const section = (
    <DetailSection title="Tài khoản app học sinh">
      {!canView ? (
        <DetailField mode="view" label="Trạng thái" value="Chỉ quản trị viên xem được" />
      ) : (
        <>
          <DetailField
            mode="view"
            label="Tên đăng nhập"
            value={row && row.state !== 'CHUA_CAP' ? row.student_code : ''}
          />
          <DetailField mode="view" label="Trạng thái" value={row ? STATE_LABEL[row.state] : ''} />
          <DetailField
            mode="view"
            label="Đăng nhập gần nhất"
            value={row?.last_login_at ? formatDateTime(row.last_login_at) : ''}
          />
        </>
      )}
    </DetailSection>
  );

  const dialogs = (
    <>
      <ActionConfirmDialog
        open={action === 'issue'}
        onOpenChange={close}
        name={name}
        title="Cấp tài khoản học sinh"
        description="Tên đăng nhập là mã học sinh. Hệ thống sinh mật khẩu tạm, hiện một lần; học sinh đổi mật khẩu ở lần đăng nhập đầu."
        confirmLabel="Cấp tài khoản"
        onConfirm={async () => setPassword(await issueStudentAccount(supabase, record.code))}
        onDone={() => done(`Đã cấp tài khoản cho ${record.full_name}.`)}
      />
      <ActionConfirmDialog
        open={action === 'reset'}
        onOpenChange={close}
        name={name}
        title="Đặt lại mật khẩu"
        description="Hệ thống sinh mật khẩu tạm mới, hiện một lần; mật khẩu cũ hết hiệu lực và học sinh bị đăng xuất khỏi mọi thiết bị."
        confirmLabel="Đặt lại mật khẩu"
        onConfirm={async () => setPassword(await resetUserPassword(supabase, row?.user_id ?? ''))}
        onDone={() => done(`Đã đặt lại mật khẩu cho ${record.full_name}.`)}
      />
      <LockDialog
        open={action === 'lock'}
        onOpenChange={close}
        name={record.full_name}
        onLock={(reason) => lockUser(supabase, row?.user_id ?? '', reason)}
        onDone={() => done(`Đã khoá tài khoản của ${record.full_name}.`)}
      />
      <ActionConfirmDialog
        open={action === 'unlock'}
        onOpenChange={close}
        name={record.full_name}
        title="Mở khoá tài khoản"
        description="Học sinh đăng nhập lại được bằng mật khẩu hiện có."
        confirmLabel="Mở khoá"
        onConfirm={() => unlockUser(supabase, row?.user_id ?? '')}
        onDone={() => done(`Đã mở khoá tài khoản của ${record.full_name}.`)}
      />
      <TempPasswordDialog
        password={password}
        name={record.full_name}
        onClose={() => setPassword(null)}
      />
    </>
  );
  return { menuItems, section, dialogs };
}
