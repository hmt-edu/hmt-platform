// QT-05 Ma trận quyền (canvas 9933: MaTranQuyen, MaTranQuyen_ct, MaTranQuyen_ls): vai trò bên trái, lưới phân hệ × hành động bên phải, mỗi ô là một phạm vi dữ liệu.
// Bấm Sửa, đổi ô (ô đã sửa có viền cam), Lưu thay đổi: tạo phiên bản mới, có hiệu lực ngay, có nhật ký (save_permission_matrix; DB kiểm phiên bản hiện hành,
// phân hệ Quản trị chỉ ADMIN). Chỉ Admin. Lịch sử: các phiên bản gần đây kèm ô đã đổi.
import { useMemo, useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { cn } from '../../ui/cn';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { INPUT_CLASS, TextField } from '../../ui/Field';
import { useToast } from '../../ui/toastContext';
import {
  baseMap,
  cellKey,
  changesOf,
  countForRole,
  describeChange,
  isLockedCell,
  NO_SCOPE,
  scopeAt,
  setCell,
  type Draft,
} from './matrixLogic';
import {
  saveMatrix,
  usePermActions,
  usePermModules,
  usePermScopes,
  usePermissionChanges,
  usePermissionRows,
  usePermissionVersions,
  useMatrixEditEnabled,
  useRefreshMatrix,
  useRoles,
} from './useMatrixData';

export function PermissionMatrixPage() {
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshMatrix();
  const roles = useRoles();
  const modules = usePermModules();
  const actions = usePermActions();
  const scopes = usePermScopes();
  const rows = usePermissionRows();
  const versions = usePermissionVersions();
  const editFlag = useMatrixEditEnabled();
  const changes = usePermissionChanges((versions.data ?? []).slice(0, 5).map((v) => v.version_no));
  const [picked, setPicked] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<Draft>(new Map());
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Sửa cần quyền Quản trị · Sửa VÀ cờ sửa ma trận đang bật (mặc định tắt; DB cũng chặn).
  const flagOn = editFlag.data === true;
  const canEdit = access.can('ADMIN', 'SUA') && flagOn;
  const base = useMemo(() => baseMap(rows.data ?? []), [rows.data]);
  const role = (roles.data ?? []).find((r) => r.code === picked) ?? roles.data?.[0] ?? null;
  const current = versions.data?.[0] ?? null;
  const failed = [roles, modules, actions, scopes, rows, versions].find((q) => q.isError);
  const ready =
    roles.data && modules.data && actions.data && scopes.data && rows.data && versions.data;
  const nameOf = (list: { code: string; name: string }[] | undefined, code: string | null) =>
    code === null || code === '' ? 'Không có' : (list?.find((i) => i.code === code)?.name ?? code);
  const total = draft.size;

  const cancel = () => {
    setDraft(new Map());
    setNote('');
    setError(null);
    setEditing(false);
  };
  const save = async () => {
    if (!current) return;
    setBusy(true);
    setError(null);
    try {
      const no = await saveMatrix(
        supabase,
        current.version_no,
        changesOf(draft),
        note.trim() || null,
      );
      await refresh();
      cancel();
      toast({ title: `Đã lưu phiên bản ${no}, có hiệu lực ngay.` });
    } catch (e) {
      // Phiên bản cũ (người khác vừa lưu): DB trả câu «Hãy tải lại rồi sửa tiếp», hiện nguyên câu.
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-h1">Ma trận quyền</h1>
        {current && (
          <p className="text-body text-fg-muted">
            Hiện hành: <b>phiên bản {current.version_no}</b> · lưu lúc{' '}
            {formatDateTime(current.saved_at)}
          </p>
        )}
      </div>
      {failed ? (
        <StateView
          kind="error"
          title="Không tải được ma trận quyền"
          actions={<Button onClick={() => void failed.refetch()}>Thử lại</Button>}
        >
          {errorOf(failed.error).message}
        </StateView>
      ) : !ready || !role ? (
        <Spinner label="Đang tải ma trận quyền…" />
      ) : (
        <>
          {editFlag.data === false && access.can('ADMIN', 'SUA') && (
            <Alert tone="warning">
              Sửa ma trận quyền đang tắt. Bật tham số «Cho phép sửa ma trận quyền» ở Cài đặt tham số
              (nhóm Đăng nhập, bảo mật) khi cần đổi quyền. Màn này đang chỉ xem.
            </Alert>
          )}
          <p className="text-body text-fg-muted">
            Phạm vi dữ liệu: {scopes.data.map((s) => `${s.name}`).join(' · ')}. Ô đã sửa có viền
            cam; ô mờ không sửa được (phân hệ Quản trị chỉ cấp cho Admin).
          </p>
          <div className="grid gap-4 lg:grid-cols-[240px_minmax(0,1fr)]">
            <nav
              aria-label="Vai trò"
              className="flex flex-col rounded-box border border-border bg-surface"
            >
              <p className="p-3 text-body text-fg-muted">
                <b className="text-h2 text-fg">{roles.data.length}</b> vai trò
              </p>
              <ul className="border-t border-border">
                {roles.data.map((r) => {
                  const n = countForRole(draft, r.code);
                  return (
                    <li key={r.code} className="border-b border-border last:border-b-0">
                      <button
                        type="button"
                        aria-current={r.code === role.code ? 'true' : undefined}
                        onClick={() => setPicked(r.code)}
                        className={cn(
                          'focus-ring flex w-full items-center justify-between gap-2 border-l-[3px] px-3 py-3 text-left hover:bg-hover',
                          r.code === role.code
                            ? 'border-l-brand-600 bg-brand-50'
                            : 'border-l-transparent',
                        )}
                      >
                        <span className="flex flex-col">
                          <span className="text-body font-semibold">{r.name}</span>
                          <span className="text-caption text-fg-muted">{r.code}</span>
                        </span>
                        {n > 0 && <Tag tone="warning">{n} ô sửa</Tag>}
                      </button>
                    </li>
                  );
                })}
              </ul>
            </nav>
            <section
              aria-label={`Quyền của vai trò ${role.name}`}
              className="min-w-0 rounded-box border border-border bg-surface"
            >
              <div className="flex flex-wrap items-center justify-between gap-2 border-b border-border px-4 py-3">
                <h2 className="text-h2">{role.name}</h2>
                {canEdit && !editing && (
                  <Button variant="primary" onClick={() => setEditing(true)}>
                    Sửa
                  </Button>
                )}
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-body">
                  <caption className="sr-only">Quyền của vai trò {role.name}</caption>
                  <thead>
                    <tr className="border-b border-border text-left">
                      <th scope="col" className="px-3 py-2">
                        Phân hệ
                      </th>
                      {actions.data.map((a) => (
                        <th key={a.code} scope="col" className="px-2 py-2">
                          {a.name}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {modules.data.map((m) => (
                      <tr key={m.code} className="border-b border-border last:border-b-0">
                        <th scope="row" className="px-3 py-2 text-left font-medium">
                          {m.name}
                        </th>
                        {actions.data.map((a) => {
                          const key = cellKey(role.code, m.code, a.code);
                          const value = scopeAt(base, draft, key);
                          const changed = draft.has(key);
                          const locked = isLockedCell(role.code, m.code);
                          return (
                            <td key={a.code} className="px-2 py-1">
                              {editing && !locked ? (
                                <select
                                  aria-label={`${role.name}, ${m.name}, ${a.name}`}
                                  value={value}
                                  onChange={(e) =>
                                    setDraft((d) => setCell(base, d, key, e.target.value))
                                  }
                                  className={cn(
                                    INPUT_CLASS,
                                    'h-8 min-w-28 text-caption',
                                    changed && 'border-2 border-brand-500',
                                  )}
                                >
                                  <option value={NO_SCOPE}>Không có</option>
                                  {scopes.data.map((s) => (
                                    <option key={s.code} value={s.code}>
                                      {s.name}
                                    </option>
                                  ))}
                                </select>
                              ) : (
                                <span
                                  className={cn(
                                    'text-caption',
                                    locked && 'text-fg-disabled',
                                    value === NO_SCOPE && 'text-fg-muted',
                                  )}
                                >
                                  {nameOf(scopes.data, value)}
                                </span>
                              )}
                            </td>
                          );
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {editing && (
                <div className="flex flex-col gap-3 border-t border-border p-4">
                  <p className="text-body">
                    Đã đổi <b>{countForRole(draft, role.code)}</b> ô của vai trò {role.name}
                    {total > countForRole(draft, role.code)
                      ? ` (tổng ${total} ô, mọi vai trò)`
                      : ''}
                    . Lưu tạo phiên bản mới, có hiệu lực ngay.
                  </p>
                  <TextField
                    label="Ghi chú phiên bản (tuỳ chọn)"
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                  />
                  {error && <Alert tone="danger">{error}</Alert>}
                  <div className="flex gap-2">
                    <Button onClick={cancel} disabled={busy}>
                      Huỷ
                    </Button>
                    <Button
                      variant="primary"
                      loading={busy}
                      disabled={total === 0}
                      onClick={() => void save()}
                    >
                      Lưu thay đổi
                    </Button>
                  </div>
                </div>
              )}
            </section>
          </div>
          <section
            aria-label="Lịch sử thay đổi quyền"
            className="rounded-box border border-border bg-surface p-4"
          >
            <h2 className="mb-2 text-h2">Lịch sử thay đổi gần đây</h2>
            <ul className="flex flex-col gap-3">
              {versions.data.slice(0, 5).map((v) => (
                <li key={v.version_no} className="text-body">
                  <p>
                    <b>Phiên bản {v.version_no}</b> · {formatDateTime(v.saved_at)} ·{' '}
                    {v.changed_count} ô{v.note ? ` · ${v.note}` : ''}
                  </p>
                  <ul className="ml-4 list-disc text-caption text-fg-muted">
                    {(changes.data ?? [])
                      .filter((c) => c.version_no === v.version_no)
                      .slice(0, 5)
                      .map((c, i) => (
                        <li key={i}>
                          {describeChange(c, {
                            role: (x) => nameOf(roles.data, x),
                            module: (x) => nameOf(modules.data, x),
                            action: (x) => nameOf(actions.data, x),
                            scope: (x) => nameOf(scopes.data, x),
                          })}
                        </li>
                      ))}
                  </ul>
                </li>
              ))}
            </ul>
          </section>
        </>
      )}
    </div>
  );
}
