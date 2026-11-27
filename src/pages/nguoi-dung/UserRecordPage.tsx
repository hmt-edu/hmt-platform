// QT-02 Người dùng (bản ghi, khuôn K06): thông tin tài khoản, vai trò, cơ sở, quản lý trực tiếp, trạng thái, thiết bị hai bước, lịch sử
// đăng nhập. Chỉ Admin đã xác thực hai bước. Thao tác trong menu Hành động: Sửa vai trò, Đổi cơ sở, Quản lý trực tiếp, Khoá, Mở khoá,
// Thu hồi phiên, Đặt lại hai bước (hai việc cuối không dùng cho chính mình, Đ50). Đặt lại mật khẩu cần hộp mật khẩu tạm K4g, K4e4
// (chờ #69): chưa có mục này. Sửa email (không dùng cho chính mình): hộp QT03_sua_email.
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { Button } from '../../ui/Button';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { useAuth } from '../../lib/auth/authContext';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import type { MenuItem } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import {
  ActionConfirmDialog,
  BranchDialog,
  LockDialog,
  ManagerDialog,
  RolesDialog,
  TempPasswordDialog,
} from './UserDialogs';
import { EmailDialog } from './UserCreate';
import { roleNames, staffKind } from './userLogic';
import { LOGIN_RESULT_LABEL, type UserRecord } from './userTypes';
import {
  lockUser,
  resetUserMfa,
  resetUserPassword,
  revokeUserSessions,
  setUserBranch,
  setUserManager,
  setUserRoles,
  unlockUser,
  useRefreshUsers,
  useUserRecord,
} from './useUserData';

type Dialog =
  | 'roles'
  | 'branch'
  | 'manager'
  | 'email'
  | 'lock'
  | 'unlock'
  | 'revoke'
  | 'mfa'
  | 'password'
  | null;

export function UserRecordPage() {
  const { id } = useParams<{ id: string }>();
  const query = useUserRecord(id);
  if (query.isPending) return <Spinner label="Đang tải người dùng…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem người dùng này'
            : missing
              ? 'Không tìm thấy người dùng'
              : 'Không tải được người dùng'
        }
        actions={
          <>
            {/* duong-dan-menu: không tải được bản ghi, về danh sách chung */}
            <Link to="/crm/quan-tri/nguoi-dung" className="font-medium text-link hover:underline">
              Về danh sách Người dùng
            </Link>
            {!forbidden && !missing && (
              <Button onClick={() => void query.refetch()}>Thử lại</Button>
            )}
          </>
        }
      >
        {errorOf(error).message}
      </StateView>
    );
  }
  return <UserView key={query.data.id} record={query.data} />;
}

function UserView({ record }: { record: UserRecord }) {
  const supabase = useDb();
  const toast = useToast();
  const access = useAccess();
  const { claims } = useAuth();
  const refresh = useRefreshUsers();
  const [dialog, setDialog] = useState<Dialog>(null);
  const [tempPassword, setTempPassword] = useState<string | null>(null);
  useCrumbTail(record.display_name);

  const canEdit = access.can('ADMIN', 'SUA');
  const self = claims?.userId === record.id;
  const close = (open: boolean) => {
    if (!open) setDialog(null);
  };
  const done = (message: string) => () => {
    void refresh();
    toast({ title: message });
  };
  const common = { name: record.display_name };

  const menu: MenuItem[] = canEdit
    ? [
        { kind: 'action', label: 'Sửa vai trò', onSelect: () => setDialog('roles') },
        { kind: 'action', label: 'Đổi cơ sở', onSelect: () => setDialog('branch') },
        { kind: 'action', label: 'Quản lý trực tiếp', onSelect: () => setDialog('manager') },
        record.is_locked
          ? { kind: 'action', label: 'Mở khoá', onSelect: () => setDialog('unlock') }
          : { kind: 'action', label: 'Khoá', onSelect: () => setDialog('lock') },
        ...(self
          ? []
          : [
              {
                kind: 'action' as const,
                label: 'Sửa email',
                onSelect: () => setDialog('email'),
              },
              {
                kind: 'action' as const,
                label: 'Thu hồi phiên',
                onSelect: () => setDialog('revoke'),
              },
              {
                kind: 'action' as const,
                label: 'Đặt lại mật khẩu',
                onSelect: () => setDialog('password'),
              },
              {
                kind: 'action' as const,
                label: 'Đặt lại hai bước',
                onSelect: () => setDialog('mfa'),
              },
            ]),
      ]
    : [];

  return (
    <>
      <RecordDetail
        kind="Người dùng"
        title={record.display_name}
        mode="view"
        readOnly
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        onRefresh={() => refresh()}
        menu={menu.length > 0 ? { label: 'Hành động', items: menu } : undefined}
        asideLabel="Lịch sử đăng nhập"
        aside={<LoginHistory record={record} />}
      >
        <div className="grid gap-x-8 gap-y-4 md:grid-cols-2">
          <DetailSection title="Tài khoản">
            <DetailField mode="view" label="Mã NV/GV/TG" value={record.staff_code ?? ''} />
            <DetailField mode="view" label="Loại" value={staffKind(record.staff_code)} />
            <DetailField mode="view" label="Tên đăng nhập" value={record.username ?? ''} />
            <DetailField mode="view" label="Email đăng nhập" value={record.login_name} />
            <DetailField
              mode="view"
              label="Trạng thái"
              value={
                record.is_locked ? (
                  <span className="inline-flex flex-wrap items-center gap-2">
                    <Tag tone="danger">Đã khoá</Tag>
                    {record.lock_reason && <span>{record.lock_reason}</span>}
                  </span>
                ) : (
                  <Tag tone="success">Đang hoạt động</Tag>
                )
              }
            />
            <DetailField
              mode="view"
              label="Đăng nhập gần nhất"
              value={record.last_login_at ? formatDateTime(record.last_login_at) : ''}
            />
            <DetailField mode="view" label="Ngày tạo" value={formatDateTime(record.created_at)} />
          </DetailSection>
          <DetailSection title="Phân quyền">
            <DetailField
              mode="view"
              label="Cơ sở"
              value={`${record.branch.code} ${record.branch.name}`}
            />
            <DetailField mode="view" label="Vai trò" value={roleNames(record.roles)} />
            <DetailField
              mode="view"
              label="Quản lý trực tiếp"
              value={record.manager ? (record.manager.name ?? '') : ''}
            />
            <DetailField
              mode="view"
              label="Xác thực hai bước"
              value={
                record.mfa_required
                  ? `Bắt buộc, ${record.mfa_devices} thiết bị`
                  : `Tuỳ chọn, ${record.mfa_devices} thiết bị`
              }
            />
            {record.mfa_reset_at && (
              <DetailField
                mode="view"
                label="Đặt lại hai bước"
                value={`${formatDateTime(record.mfa_reset_at)}${record.mfa_reset_by ? ` bởi ${record.mfa_reset_by}` : ''}`}
              />
            )}
            <DetailField
              mode="view"
              label="Mật khẩu"
              value={record.must_change_password ? 'Phải đổi ở lần đăng nhập sau' : 'Bình thường'}
            />
          </DetailSection>
        </div>
      </RecordDetail>

      <RolesDialog
        {...common}
        open={dialog === 'roles'}
        onOpenChange={close}
        roles={access.allRoles}
        current={record.roles.map((r) => r.code)}
        onSave={(roles) => setUserRoles(supabase, record.id, roles)}
        onDone={done('Đã lưu vai trò.')}
      />
      <BranchDialog
        {...common}
        open={dialog === 'branch'}
        onOpenChange={close}
        branches={access.allBranches.map((b) => ({ code: b.code, label: `${b.code} ${b.name}` }))}
        current={record.branch.code}
        onSave={(code) => setUserBranch(supabase, record.id, code)}
        onDone={done('Đã đổi cơ sở.')}
      />
      <ManagerDialog
        {...common}
        open={dialog === 'manager'}
        onOpenChange={close}
        userId={record.id}
        current={record.manager}
        onSave={(managerId) => setUserManager(supabase, record.id, managerId)}
        onDone={done('Đã lưu quản lý trực tiếp.')}
      />
      <LockDialog
        {...common}
        open={dialog === 'lock'}
        onOpenChange={close}
        onLock={(reason) => lockUser(supabase, record.id, reason)}
        onDone={done('Đã khoá tài khoản.')}
      />
      <ActionConfirmDialog
        {...common}
        open={dialog === 'unlock'}
        onOpenChange={close}
        title="Mở khoá tài khoản"
        description="Người này đăng nhập lại được bằng mật khẩu hiện có."
        confirmLabel="Mở khoá"
        onConfirm={() => unlockUser(supabase, record.id)}
        onDone={done('Đã mở khoá tài khoản.')}
      />
      <ActionConfirmDialog
        {...common}
        open={dialog === 'revoke'}
        onOpenChange={close}
        title="Thu hồi phiên"
        description="Người này bị đăng xuất khỏi mọi thiết bị và phải đăng nhập lại."
        confirmLabel="Thu hồi phiên"
        danger
        onConfirm={() => revokeUserSessions(supabase, record.id)}
        onDone={done('Đã thu hồi phiên.')}
      />
      <ActionConfirmDialog
        {...common}
        open={dialog === 'password'}
        onOpenChange={close}
        title={`Đặt lại mật khẩu của ${record.username ?? record.display_name}?`}
        description={`Mật khẩu cũ hết hiệu lực ngay. Mọi phiên đăng nhập của ${record.username ?? record.display_name} bị thu hồi, người này bị đăng xuất khỏi mọi thiết bị.`}
        note="Hệ thống tạo một mật khẩu tạm mới và hiện đúng một lần ở hộp kế tiếp. Người dùng phải đổi mật khẩu ở lần đăng nhập kế tiếp. Chỉ Admin được đặt lại mật khẩu. Thao tác ghi nhật ký (không ghi mật khẩu)."
        confirmLabel="Đặt lại mật khẩu"
        danger
        onConfirm={async () => {
          setTempPassword(await resetUserPassword(supabase, record.id));
        }}
        onDone={() => void refresh()}
      />
      <EmailDialog
        open={dialog === 'email'}
        onOpenChange={close}
        userId={record.id}
        label={record.username ?? record.display_name}
        currentEmail={record.login_name}
        onDone={done('Đã lưu email mới.')}
      />
      <TempPasswordDialog
        password={tempPassword}
        name={record.display_name}
        onClose={() => setTempPassword(null)}
      />
      <ActionConfirmDialog
        {...common}
        open={dialog === 'mfa'}
        onOpenChange={close}
        title="Đặt lại hai bước"
        description="Xoá mọi thiết bị xác thực hai bước của người này và đăng xuất khỏi mọi thiết bị."
        note={
          record.mfa_required
            ? 'Vai trò của người này bắt buộc hai bước: họ phải thiết lập lại thiết bị ở lần đăng nhập sau, chưa xong thì không vào được hệ thống.'
            : 'Vai trò của người này không bắt buộc hai bước: họ đăng nhập bình thường, thiết lập lại thiết bị khi cần.'
        }
        confirmLabel="Đặt lại hai bước"
        danger
        onConfirm={async () => {
          await resetUserMfa(supabase, record.id);
        }}
        onDone={done('Đã đặt lại hai bước.')}
      />
    </>
  );
}

function LoginHistory({ record }: { record: UserRecord }) {
  return (
    <section className="rounded-box border border-border bg-surface p-4">
      <h2 className="mb-2 font-display text-h3">Lịch sử đăng nhập</h2>
      {record.recent_logins.length === 0 ? (
        <p className="text-body text-fg-muted">Chưa có lần đăng nhập nào.</p>
      ) : (
        <ul className="flex flex-col divide-y divide-border">
          {record.recent_logins.map((e, i) => (
            <li key={`${e.at}-${i}`} className="flex flex-col gap-0.5 py-2">
              <span className="flex items-center gap-2">
                <span className="tabular">{formatDateTime(e.at)}</span>
                <Tag tone={e.result === 'THANH_CONG' ? 'success' : 'warning'}>
                  {LOGIN_RESULT_LABEL[e.result] ?? e.result}
                </Tag>
              </span>
              {(e.ip || e.user_agent) && (
                <span className="truncate text-caption text-fg-muted">
                  {[e.ip, e.user_agent].filter(Boolean).join(' · ')}
                </span>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
