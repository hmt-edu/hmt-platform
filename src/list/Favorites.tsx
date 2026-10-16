// Bộ lọc yêu thích (CHUNG-19): dùng bảng app.saved_filter và hai hàm app.save_filter, app.remove_filter
// (đã có từ PR dữ liệu #17). Cả trạng thái ListState được lưu nguyên khối.
import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useAuth } from '../lib/auth/authContext';
import { rpc, useDb } from '../lib/db';
import { useAccess } from '../nav/AccessContext';
import { Button, IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Alert, StateView } from '../ui/Feedback';
import { Checkbox, TextField } from '../ui/Field';
import { Icon } from '../ui/icons';
import { useToast } from '../ui/toastContext';
import { SAVED_FILTERS_KEY, useSavedFilters, type SavedFilterRow } from './savedFilters';
import type { ListState } from './types';

/** Danh sách bộ lọc đã lưu: bấm để dùng, thùng rác để bỏ (người tạo, hoặc quản trị viên với bộ lọc dùng chung). */
export function FavoritesList({
  screenCode,
  onApply,
  onSaveCurrent,
}: {
  screenCode: string;
  onApply: (filters: Partial<ListState>) => void;
  onSaveCurrent: () => void;
}) {
  const supabase = useDb();
  const { claims } = useAuth();
  const access = useAccess();
  const queryClient = useQueryClient();
  const toast = useToast();
  const saved = useSavedFilters(screenCode);
  const rows = saved.data ?? [];

  const remove = async (row: SavedFilterRow) => {
    try {
      await rpc(supabase, 'remove_filter', { p_id: row.id });
      await queryClient.invalidateQueries({ queryKey: SAVED_FILTERS_KEY(screenCode) });
      toast({ title: `Đã bỏ bộ lọc “${row.name}”` });
    } catch (cause) {
      toast({
        tone: 'danger',
        title: cause instanceof Error ? cause.message : 'Chưa bỏ được bộ lọc.',
      });
    }
  };

  return (
    <div className="flex flex-col">
      <p className="px-4 pt-3 pb-1 font-display text-h4">Bộ lọc của tôi</p>
      {saved.isError && (
        <div className="px-4 pb-2">
          <Alert tone="danger">Không tải được bộ lọc đã lưu. Kiểm tra mạng rồi mở lại.</Alert>
        </div>
      )}
      {!saved.isError && rows.length === 0 && !saved.isPending && (
        <StateView kind="empty" title="Chưa có bộ lọc nào được lưu" headingLevel={2}>
          Chọn lọc rồi bấm “Lưu bộ lọc hiện tại”.
        </StateView>
      )}
      <ul className="flex flex-col px-2">
        {rows.map((row) => (
          <li key={row.id} className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => onApply(row.filters)}
              className="focus-ring tap flex min-h-9 min-w-0 flex-1 items-center gap-2 rounded-control px-2 text-left text-body hover:bg-hover"
            >
              <Icon name="star" size={16} className="shrink-0 text-fg-muted" />
              <span className="min-w-0 flex-1 truncate">{row.name}</span>
              {row.is_default && <span className="text-caption text-fg-muted">Mặc định</span>}
              {row.is_shared && <span className="text-caption text-fg-muted">Dùng chung</span>}
            </button>
            {(row.owner_id === claims?.userId || (row.is_shared && access.can('ADMIN', 'SUA'))) && (
              <IconButton
                icon="trash"
                label={`Bỏ bộ lọc ${row.name}`}
                onClick={() => void remove(row)}
              />
            )}
          </li>
        ))}
      </ul>
      <div className={cn('border-t border-border px-4 py-3', rows.length === 0 && 'mt-2')}>
        <Button icon="plus" onClick={onSaveCurrent}>
          Lưu bộ lọc hiện tại
        </Button>
      </div>
    </div>
  );
}

/** Lưu bộ lọc hiện tại: tóm tắt điều kiện, tên (bắt buộc), "Dùng cho mọi người" chỉ hiện với người có quyền. */
export function SaveFilterForm({
  screenCode,
  state,
  summary,
  onDone,
}: {
  screenCode: string;
  state: ListState;
  summary: string;
  onDone: () => void;
}) {
  const supabase = useDb();
  const access = useAccess();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [name, setName] = useState('');
  const [shared, setShared] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);
  // Luật theo cơ sở dữ liệu: chỉ quản trị viên lưu bộ lọc dùng chung (app.save_filter cũng chặn).
  const canShare = access.can('ADMIN', 'SUA');
  const missing = touched && name.trim() === '';

  const save = async () => {
    setTouched(true);
    if (name.trim() === '') return;
    setBusy(true);
    setError(null);
    try {
      await rpc(supabase, 'save_filter', {
        p_screen_code: screenCode,
        p_name: name,
        p_filters: state,
        p_is_shared: canShare && shared,
        p_is_default: false,
      });
      await queryClient.invalidateQueries({ queryKey: SAVED_FILTERS_KEY(screenCode) });
      toast({ title: `Đã lưu bộ lọc “${name.trim()}”` });
      onDone();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Chưa lưu được bộ lọc.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-3 p-4">
      <p className="font-display text-h4">Lưu bộ lọc hiện tại</p>
      <div className="rounded-control bg-surface-subtle px-3 py-2">
        <p className="text-caption text-fg-muted">Điều kiện đang áp dụng</p>
        <p className="text-body">{summary}</p>
      </div>
      <TextField
        label="Tên bộ lọc"
        required
        value={name}
        error={missing ? 'Hãy đặt tên cho bộ lọc.' : null}
        onChange={(e) => setName(e.target.value)}
      />
      {canShare && (
        <Checkbox
          label="Dùng cho mọi người"
          checked={shared}
          onChange={(e) => setShared(e.target.checked)}
        />
      )}
      {error && <Alert tone="danger">{error}</Alert>}
      <div className="flex justify-end gap-2">
        <Button onClick={onDone} disabled={busy}>
          Huỷ
        </Button>
        <Button variant="primary" loading={busy} onClick={() => void save()}>
          Lưu
        </Button>
      </div>
    </div>
  );
}
