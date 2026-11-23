import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useAuth } from '../../lib/auth/authContext';
import {
  MAX_TOTP_DEVICES,
  listTotpDevices,
  removeTotpDevice,
  type TotpDevice,
} from '../../lib/auth/mfa';
import { formatDateTime } from '../../lib/datetime';
import { Button } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { Dialog } from '../../ui/Overlays';
import { NewPasswordForm } from '../auth/NewPasswordForm';
import { TotpEnroll } from '../auth/TotpEnroll';

const CARD = 'rounded-card border border-border bg-surface p-card';

function TwoStepSection() {
  const { supabase, claims } = useAuth();
  const queryClient = useQueryClient();
  const queryKey = ['totp-devices', claims?.userId];
  const devices = useQuery({
    queryKey,
    enabled: Boolean(supabase),
    staleTime: 0,
    queryFn: () => {
      if (!supabase) throw new Error('Chưa cấu hình kết nối.');
      return listTotpDevices(supabase);
    },
  });
  const [adding, setAdding] = useState(false);
  const [removing, setRemoving] = useState<TotpDevice | null>(null);
  const [error, setError] = useState<string | null>(null);
  const list = devices.data ?? [];
  const reload = () => void queryClient.invalidateQueries({ queryKey });

  async function confirmRemove() {
    if (!supabase || !removing) return;
    try {
      await removeTotpDevice(supabase, removing.id);
      setError(null);
    } catch {
      setError('Không gỡ được thiết bị. Thử lại.');
    }
    setRemoving(null);
    reload();
  }

  return (
    <section className={CARD} aria-labelledby="hai-buoc">
      <h2 id="hai-buoc" className="text-h3">
        Xác thực hai bước
      </h2>
      <p className="mt-1 text-fg-muted">
        Vai trò của bạn bắt buộc xác thực hai bước. Đăng ký tối đa {MAX_TOTP_DEVICES} thiết bị (ví
        dụ điện thoại chính và một máy dự phòng) để mất một máy vẫn đăng nhập được. Không có mã dự
        phòng.
      </p>
      {error && (
        <Alert tone="danger" className="mt-3">
          {error}
        </Alert>
      )}
      {devices.isPending ? (
        <Spinner />
      ) : (
        <ul className="mt-3 flex flex-col divide-y divide-border">
          {list.map((device) => (
            <li key={device.id} className="flex min-h-row items-center justify-between gap-3 py-2">
              <span className="min-w-0">
                <span className="block truncate font-medium">{device.name}</span>
                <span className="block text-caption text-fg-muted">
                  Đăng ký lúc {formatDateTime(device.createdAt)}
                </span>
              </span>
              {/* Luật: vai trò bắt hai bước phải luôn còn ít nhất một thiết bị. */}
              <Button icon="trash" disabled={list.length <= 1} onClick={() => setRemoving(device)}>
                Gỡ
              </Button>
            </li>
          ))}
        </ul>
      )}
      {adding ? (
        <div className="mt-4 border-t border-border pt-4">
          <TotpEnroll
            deviceName={`Thiết bị ${list.length + 1}`}
            onDone={() => {
              setAdding(false);
              reload();
            }}
          />
          <Button variant="ghost" fullWidth className="mt-2" onClick={() => setAdding(false)}>
            Huỷ
          </Button>
        </div>
      ) : (
        <Button
          className="mt-3"
          icon="phone"
          disabled={list.length >= MAX_TOTP_DEVICES}
          onClick={() => setAdding(true)}
        >
          Thêm thiết bị
        </Button>
      )}
      {list.length >= MAX_TOTP_DEVICES && !adding && (
        <p className="mt-2 text-caption text-fg-muted">
          Đã đủ {MAX_TOTP_DEVICES} thiết bị. Gỡ một thiết bị để thêm máy khác.
        </p>
      )}

      <Dialog
        open={removing !== null}
        onOpenChange={(open) => !open && setRemoving(null)}
        title="Gỡ thiết bị xác thực?"
        description={`Sau khi gỡ, mã từ "${removing?.name ?? ''}" không dùng để đăng nhập được nữa.`}
        footer={
          <>
            <Button onClick={() => setRemoving(null)}>Không gỡ</Button>
            <Button variant="danger" onClick={() => void confirmRemove()}>
              Gỡ thiết bị
            </Button>
          </>
        }
      />
    </section>
  );
}

/** CHUNG-13 · Hồ sơ cá nhân: thông tin của mình, đổi mật khẩu, quản lý thiết bị hai bước. */
export function ProfilePage() {
  const { claims, session } = useAuth();
  const [changed, setChanged] = useState(false);
  if (!claims) return null;
  const email = session?.user.email ?? '';

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4">
      <h1 className="text-h1">Hồ sơ cá nhân</h1>

      <section className={CARD} aria-labelledby="thong-tin">
        <h2 id="thong-tin" className="text-h3">
          Thông tin
        </h2>
        <dl className="mt-3 grid grid-cols-[auto_1fr] gap-x-6 gap-y-2">
          <dt className="text-fg-muted">Họ tên</dt>
          <dd>{claims.name}</dd>
          <dt className="text-fg-muted">Tên đăng nhập</dt>
          <dd className="break-all">
            {email.includes('@hocsinh.') ? email.split('@')[0]?.toUpperCase() : email}
          </dd>
          <dt className="text-fg-muted">Cơ sở</dt>
          <dd>{claims.branchCode ?? 'Chưa gán'}</dd>
        </dl>
        <p className="mt-3 text-caption text-fg-muted">Thông tin sai thì nhờ quản trị viên sửa.</p>
      </section>

      <section className={CARD} aria-labelledby="doi-mat-khau">
        <h2 id="doi-mat-khau" className="text-h3">
          Đổi mật khẩu
        </h2>
        <div className="mt-3 max-w-sm">
          {changed && (
            <Alert tone="success" className="mb-3">
              Đã đổi mật khẩu.
            </Alert>
          )}
          <NewPasswordForm submitLabel="Đổi mật khẩu" askCurrent onDone={() => setChanged(true)} />
        </div>
      </section>

      {(claims.requireMfa || claims.mfaOptional) && <TwoStepSection />}
    </div>
  );
}
