import { useState } from 'react';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ConfirmDialog } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { errorOf } from '../../lib/db';
import { formatDateTime } from '../../lib/datetime';
import {
  demoCreateErrorText,
  useCreateDemoSet,
  useDeleteDemoSet,
  useDemoAvailable,
  useDemoSets,
} from './useDemoData';
import type { DemoSet } from './useDemoData';

/** Dữ liệu mẫu của tôi: tạo bộ dữ liệu giả cho cơ sở đang chọn, xem và xoá bộ. Chỉ có ở môi trường thử nghiệm. */
export function DemoDataPage() {
  const toast = useToast();
  const available = useDemoAvailable();
  const sets = useDemoSets();
  const create = useCreateDemoSet();
  const remove = useDeleteDemoSet();
  const [target, setTarget] = useState<DemoSet | null>(null);
  const [error, setError] = useState<string | null>(null);

  if (available.isPending) return <Spinner />;
  if (!available.data) {
    return (
      <div className="mx-auto w-full max-w-3xl p-4">
        <StateView kind="empty" title="Dữ liệu mẫu đang tắt">
          Chức năng này chỉ dùng ở môi trường thử nghiệm.
        </StateView>
      </div>
    );
  }
  const rows = (sets.data ?? []).filter((s) => s.status_code === 'DANG_DUNG');

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
      <header className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="text-h3">Dữ liệu mẫu của tôi</h1>
          <p className="text-caption text-fg-muted">
            Bộ dữ liệu giả gắn cơ sở đang chọn, ghi rõ «[MẪU]». Không gửi tin thật cho ai. Phiếu
            «Cập nhật hồ sơ» mẫu do chính bạn tạo sẽ chờ người khác cùng cơ sở duyệt.
          </p>
        </div>
        <Button
          variant="primary"
          loading={create.isPending}
          onClick={() => {
            setError(null);
            create.mutate(undefined, {
              onSuccess: () => toast({ tone: 'success', title: 'Đã tạo bộ dữ liệu mẫu' }),
              onError: (e) => {
                const err = errorOf(e);
                setError(demoCreateErrorText(err.code, err.message));
              },
            });
          }}
        >
          Tạo bộ dữ liệu mẫu
        </Button>
      </header>
      {error && <Alert tone="danger">{error}</Alert>}
      {sets.isPending ? (
        <Spinner />
      ) : sets.isError ? (
        <Alert tone="danger">
          Không tải được danh sách.{' '}
          <Button size="sm" onClick={() => void sets.refetch()}>
            Thử lại
          </Button>
        </Alert>
      ) : rows.length === 0 ? (
        <StateView kind="empty" title="Chưa có bộ dữ liệu mẫu">
          Bấm «Tạo bộ dữ liệu mẫu» để có dữ liệu thử.
        </StateView>
      ) : (
        <ul className="flex flex-col gap-2">
          {rows.map((s) => (
            <li
              key={s.id}
              className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border p-3"
            >
              <div>
                <p className="text-body font-medium">
                  {s.branch_name} <Tag tone="info">Đang dùng</Tag>
                </p>
                <p className="text-caption text-fg-muted">
                  {formatDateTime(s.created_at)}
                  {s.creator_name ? ` · ${s.creator_name}` : ''}
                </p>
              </div>
              <Button size="sm" onClick={() => setTarget(s)}>
                Xoá bộ
              </Button>
            </li>
          ))}
        </ul>
      )}
      <ConfirmDialog
        open={target !== null}
        onOpenChange={(open) => !open && setTarget(null)}
        title="Xoá bộ dữ liệu mẫu?"
        description="Cả bộ sẽ bị ẩn đi. Không khôi phục được."
        confirmLabel="Xoá bộ"
        tone="danger"
        busy={remove.isPending}
        onConfirm={() => {
          if (!target) return;
          remove.mutate(target.id, {
            onSuccess: () => {
              setTarget(null);
              toast({ tone: 'success', title: 'Đã xoá bộ dữ liệu mẫu' });
            },
            onError: (e) => {
              setTarget(null);
              setError(errorOf(e).message);
            },
          });
        }}
      />
    </div>
  );
}
