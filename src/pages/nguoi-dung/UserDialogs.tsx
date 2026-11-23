// Hộp thoại thao tác của màn Người dùng (QT-02): Sửa vai trò, Đổi cơ sở, Quản lý trực tiếp, Khoá, Mở khoá, Thu hồi phiên, Đặt lại hai
// bước. Dựng bằng khuôn K4 có sẵn (FormDialog, ReasonDialog, ConfirmDialog); luật và quyền do hàm DB, Edge Function kiểm, hộp chỉ hiện
// lỗi của chúng. Đặt lại mật khẩu dùng hộp mật khẩu tạm K4g (TempPasswordDialog, 05/11); Tạo người dùng cần thêm form QT-03 (chờ khung): chưa có ở đây.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { Button } from '../../ui/Button';
import { ConfirmDialog, FormDialog, ReasonDialog } from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { Dialog } from '../../ui/Overlays';
import { Checkbox, Field } from '../../ui/Field';
import { Combobox, type ComboOption } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { lockReasonText, rolesError, sameRoles } from './userLogic';
import type { UserPage } from './userTypes';

/** Chạy một thao tác ghi: khoá nút khi đang chạy, thành công thì đóng, lỗi thì hiện câu lỗi của hàm trong hộp. */
function useAction(onOpenChange: (open: boolean) => void, onDone: () => void) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const run = async (action: () => Promise<void>) => {
    setBusy(true);
    setError(null);
    try {
      await action();
      onOpenChange(false);
      onDone();
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  };
  return { busy, error, run };
}

type Common = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Tên người đang thao tác (hiện dưới tiêu đề). */
  name: string;
  onDone: () => void;
};

/** Sửa vai trò: chọn nhiều, ít nhất một. Mỗi lần mở là một biểu mẫu mới. */
export function RolesDialog(
  props: Common & {
    roles: { code: string; name: string }[];
    current: string[];
    onSave: (roles: string[]) => Promise<void>;
  },
) {
  return props.open ? <RolesForm {...props} /> : null;
}

function RolesForm({
  open,
  onOpenChange,
  name,
  onDone,
  roles,
  current,
  onSave,
}: Common & {
  roles: { code: string; name: string }[];
  current: string[];
  onSave: (roles: string[]) => Promise<void>;
}) {
  const [selected, setSelected] = useState<string[]>(current);
  const action = useAction(onOpenChange, onDone);
  const problem = rolesError(selected);
  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Sửa vai trò"
      subtitle={name}
      confirmLabel="Lưu"
      canSubmit={problem === null && !sameRoles(selected, current)}
      busy={action.busy}
      error={action.error ?? problem}
      onSubmit={() => void action.run(() => onSave(selected))}
    >
      <fieldset className="flex flex-col gap-1">
        <legend className="mb-1 text-caption font-semibold text-fg-label">Vai trò *</legend>
        <p className="text-caption text-fg-muted">Được chọn nhiều vai trò.</p>

        {roles.map((r) => (
          <Checkbox
            key={r.code}
            label={r.name}
            checked={selected.includes(r.code)}
            onChange={(e) =>
              setSelected((prev) =>
                e.target.checked ? [...prev, r.code] : prev.filter((c) => c !== r.code),
              )
            }
          />
        ))}
      </fieldset>
    </FormDialog>
  );
}

/** Đổi cơ sở (một cơ sở). Đổi cơ sở thì người đó bị đăng xuất mọi phiên (hàm DB). */
export function BranchDialog(
  props: Common & {
    branches: { code: string; label: string }[];
    current: string;
    onSave: (branchCode: string) => Promise<void>;
  },
) {
  return props.open ? <BranchForm {...props} /> : null;
}

function BranchForm({
  open,
  onOpenChange,
  name,
  onDone,
  branches,
  current,
  onSave,
}: Common & {
  branches: { code: string; label: string }[];
  current: string;
  onSave: (branchCode: string) => Promise<void>;
}) {
  const [code, setCode] = useState(current);
  const action = useAction(onOpenChange, onDone);
  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Đổi cơ sở"
      subtitle={name}
      confirmLabel="Lưu"
      canSubmit={code !== '' && code !== current}
      busy={action.busy}
      error={action.error}
      onSubmit={() => void action.run(() => onSave(code))}
    >
      <Field label="Cơ sở" required>
        {(field) => (
          <Select
            id={field.id}
            label="Cơ sở"
            value={code}
            onChange={setCode}
            options={branches.map((b) => ({ value: b.code, label: b.label }))}
            className="w-full"
          />
        )}
      </Field>
      <p className="mt-2 text-caption text-fg-muted">
        Đổi cơ sở thì người này bị đăng xuất khỏi mọi thiết bị và đăng nhập lại.
      </p>
    </FormDialog>
  );
}

/** Quản lý trực tiếp (R-HT-06): tìm một nhân viên đang hoạt động ở máy chủ; để trống là bỏ quản lý. */
export function ManagerDialog(
  props: Common & {
    userId: string;
    current: { id: string; name: string | null } | null;
    onSave: (managerId: string | null) => Promise<void>;
  },
) {
  return props.open ? <ManagerForm {...props} /> : null;
}

function ManagerForm({
  open,
  onOpenChange,
  name,
  onDone,
  userId,
  current,
  onSave,
}: Common & {
  userId: string;
  current: { id: string; name: string | null } | null;
  onSave: (managerId: string | null) => Promise<void>;
}) {
  const supabase = useDb();
  const [query, setQuery] = useState('');
  const q = useDebounced(query).trim();
  const [managerId, setManagerId] = useState<string | null>(current?.id ?? null);
  const [picked, setPicked] = useState<ComboOption | null>(
    current ? { value: current.id, label: current.name ?? current.id } : null,
  );
  const action = useAction(onOpenChange, onDone);
  const search = useQuery({
    queryKey: ['user-manager-search', q],
    staleTime: 0,
    gcTime: 0,
    queryFn: () =>
      rpc<UserPage>(supabase, 'list_users', {
        p_filters: { status: 'ACTIVE', ...(q === '' ? {} : { q }) },
        p_sort: 'name_asc',
        p_limit: 8,
        p_offset: 0,
      }),
  });
  const options: ComboOption[] = (search.data?.rows ?? [])
    .filter((r) => r.id !== userId)
    .map((r) => ({
      value: r.id,
      label: r.display_name,
      hint: [r.staff_code, r.branch_code].filter(Boolean).join(' · '),
      keywords: `${r.login_name} ${r.staff_code ?? ''}`,
    }));
  if (picked && !options.some((o) => o.value === picked.value)) options.unshift(picked);
  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Quản lý trực tiếp"
      subtitle={name}
      confirmLabel="Lưu"
      canSubmit={managerId !== (current?.id ?? null)}
      busy={action.busy}
      error={action.error}
      onSubmit={() => void action.run(() => onSave(managerId))}
    >
      <Combobox
        label="Quản lý trực tiếp"
        options={options}
        value={managerId ? [managerId] : []}
        onChange={(v) => {
          const id = v[0] ?? null;
          setManagerId(id);
          setPicked(options.find((o) => o.value === id) ?? null);
        }}
        placeholder="Chưa có quản lý"
        loading={search.isFetching}
        onSearch={setQuery}
        help="Quản lý là người duyệt đơn hàng của nhân viên này. Gõ tên, email hoặc mã để tìm."
      />
      {managerId !== null && (
        <button
          type="button"
          className="focus-ring mt-2 rounded-tag px-1.5 text-caption font-semibold text-link hover:bg-hover"
          onClick={() => {
            setManagerId(null);
            setPicked(null);
          }}
        >
          Bỏ quản lý
        </button>
      )}
    </FormDialog>
  );
}

/** Khoá tài khoản: lý do chọn từ danh mục "Lý do khoá tài khoản", "Khác" bắt ghi chú (R-HT-04). */
export function LockDialog({
  open,
  onOpenChange,
  name,
  onDone,
  onLock,
}: Common & { onLock: (reason: string) => Promise<void> }) {
  const catalogs = useLeadCatalogs();
  const action = useAction(onOpenChange, onDone);
  const options = catalogs.options('ACCOUNT_LOCK_REASON').map((o) => ({
    value: o.value,
    label: o.label,
    needsNote: catalogs.requiresNote('ACCOUNT_LOCK_REASON', o.value),
  }));
  return (
    <ReasonDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Khoá tài khoản"
      description={`${name}: không đăng nhập được nữa và bị đăng xuất khỏi mọi thiết bị. Mở khoá lại được.`}
      options={options}
      confirmLabel="Khoá"
      confirmIcon="forbidden"
      cancelLabel="Không khoá"
      busy={action.busy}
      error={action.error}
      onConfirm={({ option, note }) => {
        const label = options.find((o) => o.value === option)?.label ?? option;
        void action.run(() => onLock(lockReasonText(label, note)));
      }}
    />
  );
}

/** Hộp xác nhận một thao tác không cần lý do: Mở khoá, Thu hồi phiên, Đặt lại hai bước. */
export function ActionConfirmDialog({
  open,
  onOpenChange,
  name,
  onDone,
  title,
  description,
  note,
  confirmLabel,
  danger = false,
  onConfirm,
}: Common & {
  title: string;
  description: string;
  note?: string;
  confirmLabel: string;
  danger?: boolean;
  onConfirm: () => Promise<void>;
}) {
  const action = useAction(onOpenChange, onDone);
  return (
    <ConfirmDialog
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      summary={[{ label: 'Người dùng', value: name }]}
      description={description}
      {...(note ? { note } : {})}
      confirmLabel={confirmLabel}
      tone={danger ? 'danger' : 'primary'}
      busy={action.busy}
      error={action.error}
      onConfirm={() => void action.run(onConfirm)}
    />
  );
}

/**
 * Hộp mật khẩu tạm (khuôn K4g, hiện MỘT lần): sau khi đặt lại mật khẩu (hoặc tạo người dùng). Mật khẩu chỉ nằm trong bộ nhớ của hộp này,
 * không lưu ở đâu; đóng hộp là mất. Chưa chép thì nút Xong báo lại một lần trước khi đóng.
 */
export function TempPasswordDialog({
  password,
  name,
  onClose,
}: {
  /** Có mật khẩu thì hộp mở; null thì đóng. */
  password: string | null;
  name: string;
  onClose: () => void;
}) {
  const [copied, setCopied] = useState(false);
  const [warned, setWarned] = useState(false);
  const [copyFailed, setCopyFailed] = useState(false);
  const close = () => {
    setCopied(false);
    setWarned(false);
    setCopyFailed(false);
    onClose();
  };
  async function copy() {
    if (password === null) return;
    try {
      await navigator.clipboard.writeText(password);
      setCopied(true);
      setCopyFailed(false);
    } catch {
      setCopyFailed(true);
    }
  }
  return (
    <Dialog
      open={password !== null}
      dismissible={false}
      title="Mật khẩu tạm"
      description={`Của ${name}. Chỉ hiện một lần, không lưu ở đâu.`}
      footer={
        <>
          <Button onClick={() => void copy()}>{copied ? 'Đã chép' : 'Chép mật khẩu'}</Button>
          <Button
            variant="primary"
            onClick={() => {
              if (!copied && !warned) {
                setWarned(true);
                return;
              }
              close();
            }}
          >
            Xong
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <p
          aria-label="Mật khẩu tạm"
          className="select-all rounded-control border border-border bg-surface-subtle px-3 py-3 text-center font-mono text-h3 tracking-wider"
        >
          {password}
        </p>
        <p className="text-body text-fg-muted">
          Giao mật khẩu này cho người dùng. Họ phải đổi mật khẩu ở lần đăng nhập đầu. Mật khẩu cũ đã
          hết hiệu lực.
        </p>
        {copyFailed && (
          <Alert tone="warning">Không chép được vào bộ nhớ tạm. Bôi đen và chép tay.</Alert>
        )}
        {warned && !copied && (
          <Alert tone="warning">
            Chưa chép mật khẩu. Đóng hộp này là không xem lại được; bấm Xong lần nữa nếu đã ghi lại.
          </Alert>
        )}
      </div>
    </Dialog>
  );
}
