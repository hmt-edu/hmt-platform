// QT-12 Nhật ký đăng nhập và xuất file (khuôn K03, chỉ Admin): hai tab. Đăng nhập thành công/thất bại, tạm khoá; nút Mở khoá tạm ở dòng
// đang khoá. Xuất file: ai, phân hệ, số dòng, bộ lọc. Không có khung canvas riêng: dựng từ khuôn K03 và Tabs dùng chung.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListConfig, ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tabs } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { buildExportConfig, buildLoginConfig, EMPTY_LOG_STATE } from './loginLogConfig';
import { buildExportFilters, buildLoginFilters } from './loginLogLogic';
import type { Paged } from './loginLogTypes';
import { unlockTempLogin, useExportPage, useLoginPage, useModuleNames } from './useLoginLogData';

type QueryLike<T> = {
  data: Paged<T> | undefined;
  isPending: boolean;
  isPlaceholderData: boolean;
  isError: boolean;
  error: unknown;
  refetch: () => unknown;
};

function LogList<T>({
  config,
  query,
  state,
  setState,
  page,
  setPage,
  pageSize,
  rowKey,
  rowLabel,
  onRefresh,
}: {
  config: ListConfig<T>;
  query: QueryLike<T>;
  state: ListState;
  setState: (s: ListState) => void;
  page: number;
  setPage: (n: number) => void;
  pageSize: number | null;
  rowKey: (r: T) => string;
  rowLabel: (r: T) => string;
  onRefresh: () => void;
}) {
  const rows = query.data?.rows ?? [];
  const total = query.data?.total ?? 0;
  const size = pageSize ?? 0;
  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={rowKey}
      rowLabel={rowLabel}
      loading={query.isPending || query.isPlaceholderData}
      error={query.isError ? errorOf(query.error).message : null}
      onRetry={() => void query.refetch()}
      actions={[]}
      onRefresh={onRefresh}
      pager={{
        from: total === 0 ? 0 : page * size + 1,
        to: page * size + rows.length,
        total,
        ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
        ...(page * size + rows.length < total ? { onNext: () => setPage(page + 1) } : {}),
      }}
      sort={null}
      onSortChange={() => undefined}
      emptyMessage={{ title: 'Chưa có dòng nhật ký', hint: 'Đổi bộ lọc để xem tiếp.' }}
    />
  );
}

export function LoginLogPage() {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const pageSize = useIntSetting('list_page_size_default');
  const modules = useModuleNames();
  const canEdit = access.can('ADMIN', 'SUA');
  const [tab, setTab] = useState('login');
  const [loginState, setLoginState] = useState<ListState>(EMPTY_LOG_STATE);
  const [exportState, setExportState] = useState<ListState>(EMPTY_LOG_STATE);
  const [paging, setPaging] = useState({
    login: { key: '', page: 0 },
    export: { key: '', page: 0 },
  });
  const [unlocking, setUnlocking] = useState<string | null>(null);

  const debounced = useDebounced(loginState.search);
  const loginFilters = useMemo(
    () => buildLoginFilters({ ...loginState, search: debounced }),
    [loginState, debounced],
  );
  const exportFilters = useMemo(() => buildExportFilters(exportState), [exportState]);
  const loginKey = JSON.stringify(loginFilters);
  const exportKey = JSON.stringify(exportFilters);
  const loginPage = paging.login.key === loginKey ? paging.login.page : 0;
  const exportPage = paging.export.key === exportKey ? paging.export.page : 0;

  const logins = useLoginPage(loginFilters, loginPage * (pageSize ?? 0), pageSize);
  const exports = useExportPage(exportFilters, exportPage * (pageSize ?? 0), pageSize);

  async function unlock(userId: string, name: string) {
    if (unlocking) return;
    setUnlocking(userId);
    try {
      await unlockTempLogin(supabase, userId);
      toast({ title: `Đã mở khoá tạm cho ${name}.` });
      void logins.refetch();
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setUnlocking(null);
    }
  }

  const loginConfig = useMemo(
    () =>
      buildLoginConfig((r) =>
        canEdit && r.temp_locked && r.user_id ? (
          <Button
            loading={unlocking === r.user_id}
            onClick={() => void unlock(r.user_id as string, r.login_name)}
          >
            Mở khoá tạm
          </Button>
        ) : null,
      ),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- unlock đọc state qua đóng gói; chỉ dựng lại khi quyền hoặc dòng đang mở khoá đổi
    [canEdit, unlocking],
  );
  const exportConfig = useMemo(() => buildExportConfig(modules.data ?? []), [modules.data]);

  return (
    <div className="flex min-w-0 flex-col gap-3">
      <Tabs
        label="Nhật ký đăng nhập và xuất file"
        value={tab}
        onChange={setTab}
        items={[
          {
            value: 'login',
            label: 'Đăng nhập',
            content: (
              <LogList
                config={loginConfig}
                query={logins}
                state={loginState}
                setState={setLoginState}
                page={loginPage}
                setPage={(n) => setPaging((p) => ({ ...p, login: { key: loginKey, page: n } }))}
                pageSize={pageSize}
                rowKey={(r) => String(r.id)}
                rowLabel={(r) => r.login_name}
                onRefresh={() => void logins.refetch()}
              />
            ),
          },
          {
            value: 'export',
            label: 'Xuất file',
            content: (
              <LogList
                config={exportConfig}
                query={exports}
                state={exportState}
                setState={setExportState}
                page={exportPage}
                setPage={(n) => setPaging((p) => ({ ...p, export: { key: exportKey, page: n } }))}
                pageSize={pageSize}
                rowKey={(r) => String(r.id)}
                rowLabel={(r) => r.module_code}
                onRefresh={() => void exports.refetch()}
              />
            ),
          },
        ]}
      />
    </div>
  );
}
