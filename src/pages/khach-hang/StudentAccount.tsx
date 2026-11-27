// Khối «Tài khoản app học sinh» trên hồ sơ (canvas a8d7: KH05_tk_*, R-CRM-32): dùng lại thao tác của màn Tài khoản học sinh (QT-13).
// Nút ở đầu hồ sơ khớp nút trong khối. Chỉ quản trị viên xem và thao tác; máy chủ kiểm quyền. Mật khẩu tạm hiện đúng một lần.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { useToast } from '../../ui/toastContext';
import { ActionConfirmDialog, TempPasswordDialog } from '../nguoi-dung/UserDialogs';
import { lockUser, resetUserPassword, unlockUser } from '../nguoi-dung/useUserData';
import type {
  StudentAccountPage,
  StudentAccountState,
} from '../tai-khoan-hoc-sinh/studentAccountTypes';
import { issueStudentAccount } from '../tai-khoan-hoc-sinh/useStudentAccountData';
import type { StudentRecord } from './custTypes';

type Action = 'issue' | 'reset' | 'lock' | 'unlock';

const STATE_TEXT: Record<StudentAccountState, string> = {
  CHUA_CAP: 'Chưa có tài khoản',
  HOAT_DONG: 'Đang hoạt động',
  BI_KHOA: 'Đã khoá',
};
/** Nút theo ba trạng thái (anh Trường chốt 27/11). */
const STATE_ACTIONS: Record<StudentAccountState, [Action, string][]> = {
  CHUA_CAP: [['issue', 'Cấp tài khoản']],
  HOAT_DONG: [
    ['reset', 'Đặt lại mật khẩu'],
    ['lock', 'Khoá tài khoản'],
  ],
  BI_KHOA: [['unlock', 'Mở khoá tài khoản']],
};
// Hộp Khoá của khung không có ô lý do: gửi lý do mặc định vì hàm khoá bắt buộc lý do.
const LOCK_REASON = 'Khoá tài khoản app học sinh';

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

  const canManage = access.can('ADMIN', 'SUA');
  const issued = row !== null && row.state !== 'CHUA_CAP';
  const buttons =
    canManage && row !== null && record.record_status !== 'DA_GOP' ? STATE_ACTIONS[row.state] : [];
  const actions = buttons.map(([key, label]) => (
    <Button key={key} onClick={() => setAction(key)}>
      {label}
    </Button>
  ));
  const passwordText = !row
    ? ''
    : !issued
      ? 'Chưa có mật khẩu'
      : row.state === 'HOAT_DONG' && canManage
        ? 'Không hiển thị · bấm “Đặt lại mật khẩu” để tạo mới'
        : 'Không hiển thị';

  const section = (
    <DetailSection title="Tài khoản app học sinh">
      {actions.length > 0 && <div className="flex flex-wrap gap-2">{actions}</div>}
      {!canManage && (
        <p className="text-body text-fg-muted">
          Bạn không có quyền quản lý tài khoản app học sinh, nên không có nút thao tác.
        </p>
      )}
      {canView &&
        (query.isError ? (
          <p role="alert">{errorOf(query.error).message}</p>
        ) : (
          <>
            <DetailField
              mode="view"
              label="Tên đăng nhập"
              hint="mã học sinh"
              value={!row ? '' : issued ? row.student_code : 'Chưa cấp'}
            />
            <DetailField mode="view" label="Trạng thái" value={row ? STATE_TEXT[row.state] : ''} />
            <DetailField mode="view" label="Mật khẩu" value={passwordText} />
            <DetailField
              mode="view"
              label="Đăng nhập gần nhất"
              value={row?.last_login_at ? formatDateTime(row.last_login_at) : '—'}
            />
          </>
        ))}
    </DetailSection>
  );

  const dialogs = (
    <>
      <ActionConfirmDialog
        open={action === 'issue'}
        onOpenChange={close}
        name={name}
        title="Cấp tài khoản app"
        description={`Cấp tài khoản app cho học sinh ${record.full_name} (${record.code})? Hệ thống tạo mật khẩu tạm và CHỈ HIỆN MỘT LẦN ngay sau khi anh/chị xác nhận.`}
        confirmLabel="Cấp tài khoản"
        onConfirm={async () => setPassword(await issueStudentAccount(supabase, record.code))}
        onDone={() => done(`Đã cấp tài khoản cho ${record.full_name}.`)}
      />
      <ActionConfirmDialog
        open={action === 'reset'}
        onOpenChange={close}
        name={name}
        title="Đặt lại mật khẩu"
        description={`Đặt lại mật khẩu cho học sinh ${record.full_name}? Mật khẩu cũ sẽ không dùng được nữa. Hệ thống tạo mật khẩu tạm và CHỈ HIỆN MỘT LẦN ngay sau khi anh/chị xác nhận.`}
        confirmLabel="Đặt lại mật khẩu"
        onConfirm={async () => setPassword(await resetUserPassword(supabase, row?.user_id ?? ''))}
        onDone={() => done(`Đã đặt lại mật khẩu cho ${record.full_name}.`)}
      />
      <ActionConfirmDialog
        open={action === 'lock'}
        onOpenChange={close}
        name={name}
        title="Khoá tài khoản"
        description={`Khoá tài khoản app của học sinh ${record.full_name}? Học sinh sẽ không đăng nhập được vào app.`}
        confirmLabel="Khoá tài khoản"
        onConfirm={() => lockUser(supabase, row?.user_id ?? '', LOCK_REASON)}
        onDone={() => done(`Đã khoá tài khoản của ${record.full_name}.`)}
      />
      <ActionConfirmDialog
        open={action === 'unlock'}
        onOpenChange={close}
        name={name}
        title="Mở khoá tài khoản"
        description={`Mở khoá tài khoản app của học sinh ${record.full_name}? Học sinh sẽ đăng nhập lại được bằng mật khẩu hiện có. Thao tác được ghi nhật ký.`}
        confirmLabel="Mở khoá tài khoản"
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
  return { actions: actions.length > 0 ? <>{actions}</> : undefined, section, dialogs };
}
