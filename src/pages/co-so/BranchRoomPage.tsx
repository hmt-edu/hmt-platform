// QT-08 Cơ sở và phòng học (bản đồ màn hình: Cấu hình · K10, Admin, máy tính; canvas dc47 QT08_*).
// Cơ sở là danh mục khoá: chỉ sửa tên hiển thị và địa chỉ, không thêm, không ngừng ở giao diện. Phòng: thêm, sửa tên và sức chứa, Ngừng, Dùng lại.
// Ghi qua hàm DB (kiểm quyền Quản trị · Sửa và mọi luật); giao diện chỉ kiểm sớm để báo tại ô.
import { useMemo, useState } from 'react';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { useToast } from '../../ui/toastContext';
import {
  ADDRESS_MAX,
  EMPTY_ROOM_DRAFT,
  roomDraftOf,
  roomSummary,
  validateBranch,
  validateRoom,
  type Branch,
  type Room,
  type RoomDraft,
} from './branchLogic';
import {
  saveRoom,
  setRoomActive,
  updateBranchInfo,
  useBranchesAndRooms,
  useRefreshBranches,
} from './useBranchData';

export function BranchRoomPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refresh = useRefreshBranches();
  const data = useBranchesAndRooms();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [editBranch, setEditBranch] = useState(false);
  const [roomForm, setRoomForm] = useState<{ room: Room | null } | null>(null);
  const [stopping, setStopping] = useState<Room | null>(null);
  const [busy, setBusy] = useState(false);
  useCrumbTail('Cơ sở và phòng học');

  const branches = useMemo(() => data.data?.branches ?? [], [data.data]);
  const branch = branches.find((b) => b.id === selectedId) ?? branches[0] ?? null;
  const rooms = useMemo(
    () => (data.data?.rooms ?? []).filter((r) => r.branch_id === branch?.id),
    [data.data, branch?.id],
  );
  const canEdit = access.can('ADMIN', 'SUA');

  if (data.isPending) return <Spinner label="Đang tải cơ sở và phòng…" />;
  if (data.isError)
    return (
      <StateView
        kind="error"
        title="Chưa tải được cơ sở và phòng"
        actions={<Button onClick={() => void data.refetch()}>Thử lại</Button>}
      >
        {errorOf(data.error).message}
      </StateView>
    );

  const toggle = async (room: Room, active: boolean) => {
    setBusy(true);
    try {
      await setRoomActive(supabase, room.id, active);
      setStopping(null);
      await refresh();
      toast({ tone: 'success', title: active ? 'Đã dùng lại phòng.' : 'Đã ngừng phòng.' });
    } catch (cause) {
      toast({ tone: 'danger', title: errorOf(cause).message });
    } finally {
      setBusy(false);
    }
  };

  const columns: LineColumn<Room>[] = [
    { key: 'code', header: 'Mã phòng', width: 'w-28', cell: (r) => <b>{r.code}</b> },
    { key: 'name', header: 'Phòng', cell: (r) => r.name },
    { key: 'capacity', header: 'Sức chứa', width: 'w-28', cell: (r) => r.capacity ?? '—' },
    {
      key: 'status',
      header: 'Trạng thái',
      width: 'w-32',
      cell: (r) => (
        <Tag tone={r.is_active ? 'success' : 'neutral'}>{r.is_active ? 'Đang dùng' : 'Ngừng'}</Tag>
      ),
    },
    {
      key: 'actions',
      header: 'Thao tác',
      headerSrOnly: 'Thao tác',
      width: 'w-48',
      cell: (r) =>
        canEdit ? (
          <div className="flex gap-1">
            <Button variant="text" onClick={() => setRoomForm({ room: r })}>
              Sửa
            </Button>
            {r.is_active ? (
              <Button variant="text" onClick={() => setStopping(r)}>
                Ngừng
              </Button>
            ) : (
              <Button variant="text" loading={busy} onClick={() => void toggle(r, true)}>
                Dùng lại
              </Button>
            )}
          </div>
        ) : null,
    },
  ];

  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <h1 className="text-h1">Cơ sở và phòng học</h1>
      {!canEdit && (
        <Alert tone="info">Bạn chỉ xem được; chỉ Quản trị sửa được cơ sở và phòng học.</Alert>
      )}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[280px_minmax(0,1fr)]">
        <nav aria-label="Cơ sở" className="rounded-box border border-border bg-surface p-2">
          <p className="px-2 py-1 text-caption text-fg-muted">{branches.length} cơ sở</p>
          <ul className="flex flex-col gap-1">
            {branches.map((b) => {
              const own = (data.data?.rooms ?? []).filter((r) => r.branch_id === b.id);
              return (
                <li key={b.id}>
                  <button
                    type="button"
                    aria-current={b.id === branch?.id ? 'true' : undefined}
                    onClick={() => setSelectedId(b.id)}
                    className="focus-ring flex w-full flex-col rounded-control px-2 py-1.5 text-left hover:bg-surface-subtle aria-[current=true]:bg-surface-subtle"
                  >
                    <b>
                      {b.code} {b.name}
                    </b>
                    <span className="text-caption text-fg-muted">
                      {own.length === 0 ? 'Chưa có phòng học' : roomSummary(own)}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        </nav>
        {branch && (
          <section aria-label={`Cơ sở ${branch.code}`} className="flex min-w-0 flex-col gap-4">
            <div className="rounded-box border border-border bg-surface p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h2 className="text-h3">
                  {branch.code} {branch.name}
                </h2>
                {canEdit && <Button onClick={() => setEditBranch(true)}>Sửa cơ sở</Button>}
              </div>
              <dl className="mt-2 grid grid-cols-[120px_minmax(0,1fr)] gap-y-1">
                <dt className="font-semibold">Mã</dt>
                <dd>{branch.code}</dd>
                <dt className="font-semibold">Tên hiển thị</dt>
                <dd>{branch.name}</dd>
                <dt className="font-semibold">Địa chỉ</dt>
                <dd>{branch.address ?? '—'}</dd>
              </dl>
              <p className="mt-2 text-caption text-fg-muted">
                Cơ sở là danh mục khoá: chỉ sửa tên hiển thị và địa chỉ. Mở cơ sở mới làm bằng
                migration.
              </p>
            </div>
            <div className="rounded-box border border-border bg-surface">
              <div className="flex flex-wrap items-center justify-between gap-2 p-4">
                <div>
                  <h2 className="text-h3">Phòng học</h2>
                  <p className="text-caption text-fg-muted">
                    {roomSummary(rooms)}. Sức chứa tính theo chỗ ngồi.
                  </p>
                </div>
                {canEdit && (
                  <Button variant="primary" icon="plus" onClick={() => setRoomForm({ room: null })}>
                    Thêm phòng
                  </Button>
                )}
              </div>
              <LineTable
                caption={`Phòng học ${branch.code}`}
                columns={columns}
                rows={rooms}
                rowKey={(r) => r.id}
                rowLabel={(r) => r.name}
                empty={<p className="p-4 text-body text-fg-muted">Cơ sở này chưa có phòng học.</p>}
              />
            </div>
          </section>
        )}
      </div>
      {branch && editBranch && (
        <BranchForm
          branch={branch}
          onClose={() => setEditBranch(false)}
          onSaved={async () => {
            setEditBranch(false);
            await refresh();
            toast({ tone: 'success', title: 'Đã lưu cơ sở.' });
          }}
        />
      )}
      {branch && roomForm && (
        <RoomForm
          key={roomForm.room?.id ?? 'new'}
          branch={branch}
          room={roomForm.room}
          rooms={rooms}
          onClose={() => setRoomForm(null)}
          onSaved={async (message) => {
            setRoomForm(null);
            await refresh();
            toast({ tone: 'success', title: message });
          }}
        />
      )}
      <ConfirmDialog
        open={stopping !== null}
        onOpenChange={(o) => !o && setStopping(null)}
        title={`Ngừng ${stopping?.name ?? 'phòng'}?`}
        description="Phòng sẽ không hiện ở ô chọn phòng mới. Dữ liệu cũ vẫn giữ phòng này. Muốn dùng lại, bấm Dùng lại."
        confirmLabel="Ngừng phòng"
        busy={busy}
        onConfirm={() => stopping && void toggle(stopping, false)}
      />
    </div>
  );
}

function BranchForm({
  branch,
  onClose,
  onSaved,
}: {
  branch: Branch;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const supabase = useDb();
  const [name, setName] = useState(branch.name);
  const [address, setAddress] = useState(branch.address ?? '');
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const errors = validateBranch(name, address);
  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={`Sửa cơ sở ${branch.code}`}
      confirmLabel="Lưu"
      canSubmit={!show || Object.keys(errors).length === 0}
      busy={busy}
      error={error}
      onSubmit={() => {
        setShow(true);
        if (Object.keys(errors).length > 0) return;
        setBusy(true);
        setError(null);
        void updateBranchInfo(supabase, branch.id, name, address)
          .then(onSaved)
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <TextField label="Mã" value={branch.code} readOnly help="Mã không đổi được." />
        <TextField
          label="Tên hiển thị"
          required
          value={name}
          error={show ? errors.name : null}
          onChange={(e) => setName(e.target.value)}
        />
        <TextField
          label="Địa chỉ"
          value={address}
          error={show ? errors.address : null}
          help={`Một dòng, tối đa ${ADDRESS_MAX} ký tự (${address.trim().length}/${ADDRESS_MAX}).`}
          onChange={(e) => setAddress(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}

function RoomForm({
  branch,
  room,
  rooms,
  onClose,
  onSaved,
}: {
  branch: Branch;
  room: Room | null;
  rooms: Room[];
  onClose: () => void;
  onSaved: (message: string) => Promise<void>;
}) {
  const supabase = useDb();
  const [draft, setDraft] = useState<RoomDraft>(room ? roomDraftOf(room) : EMPTY_ROOM_DRAFT);
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const errors = validateRoom(draft, rooms, room?.id ?? null);
  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={
        room
          ? `Sửa phòng · ${branch.code} ${branch.name}`
          : `Thêm phòng · ${branch.code} ${branch.name}`
      }
      confirmLabel={room ? 'Lưu' : 'Thêm phòng'}
      canSubmit={!show || Object.keys(errors).length === 0}
      busy={busy}
      error={error}
      onSubmit={() => {
        setShow(true);
        if (Object.keys(errors).length > 0) return;
        setBusy(true);
        setError(null);
        void saveRoom(supabase, {
          ...(room ? { id: room.id } : { branch_id: branch.id, code: draft.code.trim() }),
          name: draft.name.trim(),
          capacity: Number(draft.capacity),
        })
          .then(() => onSaved(room ? 'Đã lưu phòng.' : 'Đã thêm phòng.'))
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <TextField
          label="Mã phòng"
          required
          value={draft.code}
          readOnly={room !== null}
          error={show ? errors.code : null}
          help={
            room
              ? 'Không đổi được sau khi tạo.'
              : 'Chữ viết hoa, số, dấu gạch dưới. Không trùng trong cơ sở. Không đổi được sau khi tạo.'
          }
          onChange={(e) => setDraft((d) => ({ ...d, code: e.target.value.toUpperCase() }))}
        />
        <TextField
          label="Tên phòng"
          required
          value={draft.name}
          error={show ? errors.name : null}
          onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))}
        />
        <TextField
          label="Sức chứa"
          required
          inputMode="numeric"
          value={draft.capacity}
          error={show ? errors.capacity : null}
          help="Số chỗ ngồi."
          onChange={(e) => setDraft((d) => ({ ...d, capacity: e.target.value }))}
        />
      </div>
    </FormDialog>
  );
}
