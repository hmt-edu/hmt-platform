// QT-03 Tạo người dùng (ngăn kéo bên phải, canvas ca9b QT03_tao, QT03_tao_trung) và hộp Sửa email (QT03_sua_email, QT03_sua_email_trung).
// Tên đăng nhập gợi ý từ tên, sửa được, không đổi sau khi tạo; email quy ước `<tên đăng nhập>@<tên miền trong Cài đặt>`. Trùng báo ngay ở ô
// (hàm DB check_account_fields). Tạo xong, mật khẩu tạm hiện một lần ở hộp K4g. Luật và quyền do hàm DB, Edge Function kiểm.
import { useEffect, useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { Button } from '../../ui/Button';
import { FormDialog } from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { Checkbox, Field, TextField } from '../../ui/Field';
import { Drawer, Select } from '../../ui/Overlays';
import {
  checkAccountFields,
  createUser,
  setUserEmail,
  useAccountFormDefaults,
} from './useUserData';
import {
  STAFF_KINDS,
  conventionalEmail,
  emailFormatError,
  rolesError,
  suggestUsername,
  usernameFormatError,
} from './userLogic';

const DUPLICATE_USERNAME = 'Tên đăng nhập này đã có người dùng.';
const DUPLICATE_EMAIL = 'Email này đã dùng cho tài khoản khác.';

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  roles: { code: string; name: string }[];
  branches: { code: string; label: string }[];
  defaultBranch: string;
  /** Tạo xong: mật khẩu tạm (hiện một lần) và tên người vừa tạo. */
  onCreated: (password: string, name: string) => void;
};

export function CreateUserDrawer(props: Props) {
  return props.open ? <CreateUserForm {...props} /> : null;
}

function CreateUserForm({ open, onOpenChange, roles, branches, defaultBranch, onCreated }: Props) {
  const supabase = useDb();
  const defaults = useAccountFormDefaults(open);
  const domain = defaults.data?.email_domain ?? '';
  const [displayName, setDisplayName] = useState('');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  // Còn để ô tự điền chừng nào người dùng chưa gõ tay vào ô đó.
  const [usernameEdited, setUsernameEdited] = useState(false);
  const [emailEdited, setEmailEdited] = useState(false);
  const [branchCode, setBranchCode] = useState(defaultBranch);
  const [staffKind, setStaffKind] = useState('NV');
  const [picked, setPicked] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [taken, setTaken] = useState<{ username: boolean; email: boolean }>({
    username: false,
    email: false,
  });

  const effectiveUsername = usernameEdited ? username : suggestUsername(displayName);
  const effectiveEmail = emailEdited ? email : conventionalEmail(effectiveUsername, domain);
  const usernameFormat = effectiveUsername === '' ? null : usernameFormatError(effectiveUsername);
  const emailFormat = effectiveEmail === '' ? null : emailFormatError(effectiveEmail);
  const debouncedUsername = useDebounced(effectiveUsername);
  const debouncedEmail = useDebounced(effectiveEmail);

  // Báo trùng ngay ở ô: hỏi DB sau khi ngừng gõ (không ghi gì).
  useEffect(() => {
    const u = usernameFormatError(debouncedUsername) === null ? debouncedUsername : '';
    const e = emailFormatError(debouncedEmail) === null ? debouncedEmail : '';
    if (u === '' && e === '') return;
    let cancelled = false;
    checkAccountFields(supabase, u, e)
      .then((result) => {
        if (!cancelled) {
          setTaken({
            username: u !== '' && result.username === 'HMT_TEN_DANG_NHAP_TRUNG',
            email: e !== '' && result.email === 'HMT_EMAIL_TRUNG',
          });
        }
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [supabase, debouncedUsername, debouncedEmail]);

  const usernameShown =
    taken.username && debouncedUsername === effectiveUsername ? DUPLICATE_USERNAME : usernameFormat;
  const emailShown =
    taken.email && debouncedEmail === effectiveEmail ? DUPLICATE_EMAIL : emailFormat;
  const rolesProblem = rolesError(picked);
  const canSubmit =
    displayName.trim() !== '' &&
    effectiveUsername !== '' &&
    effectiveEmail !== '' &&
    usernameShown === null &&
    emailShown === null &&
    branchCode !== '' &&
    rolesProblem === null;

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const password = await createUser(supabase, {
        displayName: displayName.trim(),
        username: effectiveUsername,
        email: effectiveEmail,
        branchCode,
        staffKind,
        roles: picked,
      });
      onOpenChange(false);
      onCreated(password, displayName.trim());
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Drawer
      open={open}
      onOpenChange={(next) => !busy && onOpenChange(next)}
      title="Tạo người dùng"
      side="right"
      footer={
        <>
          <Button onClick={() => onOpenChange(false)} disabled={busy}>
            Huỷ
          </Button>
          <Button
            variant="primary"
            loading={busy}
            disabled={!canSubmit}
            onClick={() => void submit()}
          >
            Tạo tài khoản
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3 px-4 py-4">
        <p className="text-caption text-fg-muted">Tài khoản nhân viên, giáo viên, trợ giảng.</p>
        {error && (
          <Alert tone="danger" title="Chưa tạo được.">
            {error}
          </Alert>
        )}
        <TextField
          label="Tên hiển thị"
          required
          value={displayName}
          onChange={(e) => setDisplayName(e.target.value)}
        />
        <TextField
          label="Tên đăng nhập"
          required
          value={effectiveUsername}
          onChange={(e) => {
            setUsernameEdited(true);
            setUsername(e.target.value.toLowerCase());
          }}
          error={usernameShown}
          help="Hệ thống gợi ý theo tên, sửa được. Không đổi được sau khi tạo."
        />
        <TextField
          label="Email"
          required
          type="email"
          value={effectiveEmail}
          onChange={(e) => {
            setEmailEdited(true);
            setEmail(e.target.value.toLowerCase());
          }}
          error={emailShown}
          help={domain === '' ? undefined : `Email quy ước: <tên đăng nhập>@${domain}.`}
        />
        <div className="grid grid-cols-2 gap-3">
          <Field label="Cơ sở" required help="Chọn một cơ sở.">
            {(field) => (
              <Select
                id={field.id}
                label="Cơ sở"
                value={branchCode}
                onChange={setBranchCode}
                options={branches.map((b) => ({ value: b.code, label: b.label }))}
                className="w-full"
              />
            )}
          </Field>
          <Field label="Loại nhân sự" required>
            {(field) => (
              <Select
                id={field.id}
                label="Loại nhân sự"
                value={staffKind}
                onChange={setStaffKind}
                options={STAFF_KINDS}
                className="w-full"
              />
            )}
          </Field>
        </div>
        <fieldset className="flex flex-col gap-1">
          <legend className="mb-1 text-caption font-semibold text-fg-label">
            Vai trò (chọn một hoặc nhiều)
          </legend>
          {roles.map((r) => (
            <Checkbox
              key={r.code}
              label={r.name}
              checked={picked.includes(r.code)}
              onChange={(e) =>
                setPicked((prev) =>
                  e.target.checked ? [...prev, r.code] : prev.filter((c) => c !== r.code),
                )
              }
            />
          ))}
        </fieldset>
        <TextField
          label="Mã nhân sự"
          readOnly
          value="Tự cấp khi tạo"
          help="Cấp theo chuẩn mã, không sửa được."
        />
        <p className="text-caption text-fg-muted">
          Tạo xong, mật khẩu tạm hiện đúng một lần. Người dùng đổi mật khẩu ở lần đăng nhập đầu.
        </p>
      </div>
    </Drawer>
  );
}

type EmailProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  userId: string;
  /** Tên đăng nhập của người được sửa, hiện ở tiêu đề; chưa có thì dùng tên hiển thị. */
  label: string;
  currentEmail: string;
  onDone: () => void;
};

/** Sửa email của người khác (Admin): email mới đúng dạng, không trùng; tên đăng nhập giữ nguyên; người đó bị đăng xuất mọi phiên. */
export function EmailDialog(props: EmailProps) {
  return props.open ? <EmailForm {...props} /> : null;
}

function EmailForm({ open, onOpenChange, userId, label, currentEmail, onDone }: EmailProps) {
  const supabase = useDb();
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const value = email.trim().toLowerCase();
  const debounced = useDebounced(value);
  const [takenEmail, setTakenEmail] = useState<string | null>(null);
  const format = value === '' ? null : emailFormatError(value);
  const same = value === currentEmail;

  // Báo trùng ngay ở ô (không ghi gì).
  useEffect(() => {
    if (debounced === '' || emailFormatError(debounced) !== null) return;
    let cancelled = false;
    checkAccountFields(supabase, '', debounced)
      .then((result) => {
        if (!cancelled) setTakenEmail(result.email === 'HMT_EMAIL_TRUNG' ? debounced : null);
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [supabase, debounced]);

  const shown = same
    ? 'Email mới trùng email hiện tại.'
    : takenEmail !== null && takenEmail === value
      ? DUPLICATE_EMAIL
      : format;

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await setUserEmail(supabase, userId, value);
      onOpenChange(false);
      onDone();
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={`Sửa email của ${label}`}
      confirmLabel="Lưu email"
      canSubmit={value !== '' && shown === null}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <TextField label="Email hiện tại" readOnly value={currentEmail} />
        <TextField
          label="Email mới"
          required
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          error={shown}
        />
        <p className="text-caption text-fg-muted">
          Tên đăng nhập giữ nguyên. Người này bị đăng xuất khỏi mọi thiết bị và đăng nhập lại bằng
          email mới. Việc đổi email ghi nhật ký (email cũ, email mới).
        </p>
      </div>
    </FormDialog>
  );
}
