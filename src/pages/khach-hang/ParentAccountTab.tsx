// Tab «Tài khoản» của hồ sơ phụ huynh (canvas a8d7: KH02_tai_khoan): dùng lại thao tác của màn Tài khoản phụ huynh (QT-17).
// Chỉ quản trị viên xem và thao tác; máy chủ kiểm quyền. Mật khẩu tạm hiện đúng một lần, không xem lại được.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { useToast } from '../../ui/toastContext';
import { ActionConfirmDialog, TempPasswordDialog } from '../nguoi-dung/UserDialogs';
import { resetUserPassword, unlockUser } from '../nguoi-dung/useUserData';
import type { ParentAccountPage } from '../tai-khoan-phu-huynh/parentAccountTypes';
import { issueParentAccount, lockParentAccount } from '../tai-khoan-phu-huynh/useParentAccountData';
import { formatPhone } from '../lead/leadFormat';
import type { ParentRecord } from './custTypes';

type Action = 'issue' | 'reset' | 'lock' | 'unlock';

const STATE_TEXT = { CHUA_CAP: 'Chưa có tài khoản', HOAT_DONG: 'Đang dùng', BI_KHOA: 'Đã khoá' };

export function ParentAccountTab({ record }: { record: ParentRecord }) {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const client = useQueryClient();
  const canView = access.can('ADMIN', 'XEM');
  const query = useQuery({
    queryKey: ['parent-record', record.id, 'account'],
    enabled: canView,
    queryFn: async () => {
      const page = await rpc<ParentAccountPage>(supabase, 'list_parent_accounts', {
        p_filters: { q: record.code },
      });
      return page.rows.find((r) => r.parent_id === record.id) ?? null;
    },
  });
  const [action, setAction] = useState<Action | null>(null);
  const [password, setPassword] = useState<string | null>(null);
  const row = query.data ?? null;
  const name = `${record.code} ${record.full_name}`;
  const close = (open: boolean) => {
    if (!open) setAction(null);
  };
  const done = (message: string) => {
    void client.invalidateQueries({ queryKey: ['parent-record', record.id, 'account'] });
    void client.invalidateQueries({ queryKey: ['parent-account-list'] });
    toast({ title: message });
  };
  const canAct = access.can('ADMIN', 'SUA') && record.record_status !== 'DA_GOP' && row !== null;

  return (
    <DetailSection title="Tài khoản phụ huynh">
      {!canView ? (
        <DetailField mode="view" label="Trạng thái" value="Chỉ quản trị viên xem được" />
      ) : query.isError ? (
        <p role="alert">{errorOf(query.error).message}</p>
      ) : (
        <>
          <DetailField
            mode="view"
            label="Tên đăng nhập"
            hint="số điện thoại của phụ huynh"
            value={row && row.state !== 'CHUA_CAP' ? formatPhone(record.phone) : ''}
          />
          <DetailField mode="view" label="Trạng thái" value={row ? STATE_TEXT[row.state] : ''} />
          <DetailField
            mode="view"
            label="Mật khẩu"
            value={row && row.state !== 'CHUA_CAP' ? 'Không hiển thị' : ''}
          />
          <DetailField
            mode="view"
            label="Đăng nhập gần nhất"
            value={row?.last_login_at ? formatDateTime(row.last_login_at) : ''}
          />
        </>
      )}
      {canAct && (
        <div className="flex flex-wrap gap-2">
          {row.state === 'CHUA_CAP' ? (
            <Button onClick={() => setAction('issue')}>Cấp tài khoản</Button>
          ) : (
            <>
              <Button onClick={() => setAction('reset')}>Đặt lại mật khẩu</Button>
              {row.state === 'BI_KHOA' ? (
                <Button onClick={() => setAction('unlock')}>Mở khoá tài khoản</Button>
              ) : (
                <Button onClick={() => setAction('lock')}>Khoá tài khoản</Button>
              )}
            </>
          )}
        </div>
      )}
      <ActionConfirmDialog
        open={action === 'issue'}
        onOpenChange={close}
        name={name}
        title="Cấp tài khoản phụ huynh"
        description="Hệ thống sinh mật khẩu tạm, hiện đúng một lần; phụ huynh đổi mật khẩu ở lần đăng nhập đầu."
        confirmLabel="Cấp tài khoản"
        onConfirm={async () => setPassword(await issueParentAccount(supabase, record.code))}
        onDone={() => done(`Đã cấp tài khoản cho ${record.full_name}.`)}
      />
      <ActionConfirmDialog
        open={action === 'reset'}
        onOpenChange={close}
        name={name}
        title="Đặt lại mật khẩu"
        description="Hệ thống sinh mật khẩu tạm mới, hiện đúng một lần; mật khẩu cũ hết hiệu lực."
        confirmLabel="Đặt lại mật khẩu"
        onConfirm={async () => setPassword(await resetUserPassword(supabase, row?.user_id ?? ''))}
        onDone={() => done(`Đã đặt lại mật khẩu cho ${record.full_name}.`)}
      />
      <ActionConfirmDialog
        open={action === 'lock'}
        onOpenChange={close}
        name={record.full_name}
        title="Khoá tài khoản"
        description="Phụ huynh không đăng nhập được và bị đăng xuất khỏi mọi thiết bị."
        confirmLabel="Khoá tài khoản"
        onConfirm={() => lockParentAccount(supabase, row?.user_id ?? '')}
        onDone={() => done(`Đã khoá tài khoản của ${record.full_name}.`)}
      />
      <ActionConfirmDialog
        open={action === 'unlock'}
        onOpenChange={close}
        name={record.full_name}
        title="Mở khoá tài khoản"
        description="Phụ huynh đăng nhập lại được bằng mật khẩu hiện có."
        confirmLabel="Mở khoá"
        onConfirm={() => unlockUser(supabase, row?.user_id ?? '')}
        onDone={() => done(`Đã mở khoá tài khoản của ${record.full_name}.`)}
      />
      <TempPasswordDialog
        password={password}
        name={record.full_name}
        onClose={() => setPassword(null)}
      />
    </DetailSection>
  );
}
