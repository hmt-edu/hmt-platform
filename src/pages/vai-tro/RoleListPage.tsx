// QT-04 Vai trò (bản đồ màn hình: Danh sách · K10, Admin, máy tính): các vai trò hệ thống và phạm vi mặc định, cổng vào, hai bước, số người đang dùng, số ô quyền; nút «Mở ma trận» sang QT-05.
// Chỉ đọc: không thêm, sửa, ngừng vai trò (vai trò là danh mục hệ thống, sửa quyền ở QT-05). Không có khung canvas riêng (BAN-DO-VIEC: «Thiếu khung canvas»): dựng từ khuôn K10 và các thành phần dùng chung.
import { useMemo, useState } from 'react';

import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { filterRoles, IDLE_GROUP_LABEL, portalsLabel, type RoleSummary } from './roleLogic';
import { useRoleSummaries, useScopeNames } from './useRoleData';
import { PageFrame, PageHeader } from '../../ui/PageHeader';
import { FromLink } from '../../layout/FromLink';

export function RoleListPage() {
  const roles = useRoleSummaries();
  const scopes = useScopeNames();
  const [search, setSearch] = useState('');
  const rows = useMemo(() => filterRoles(roles.data ?? [], search), [roles.data, search]);
  const scopeName = (code: string) => scopes.data?.find((s) => s.code === code)?.name ?? code;

  const columns: LineColumn<RoleSummary>[] = [
    {
      key: 'name',
      header: 'Vai trò',
      cell: (r) => (
        <div className="flex flex-col">
          <span className="font-semibold">{r.name}</span>
          <span className="text-caption text-fg-muted">{r.code}</span>
        </div>
      ),
    },
    {
      key: 'scope',
      header: 'Phạm vi mặc định',
      width: 'w-44',
      cell: (r) => scopeName(r.default_scope),
    },
    { key: 'portals', header: 'Cổng vào', width: 'min-w-32', cell: (r) => portalsLabel(r) },
    {
      key: 'mfa',
      header: 'Hai bước',
      width: 'w-28',
      cell: (r) => (
        <Tag tone={r.require_mfa ? 'warning' : 'neutral'}>
          {r.require_mfa ? 'Bắt buộc' : 'Không'}
        </Tag>
      ),
    },
    {
      key: 'idle',
      header: 'Nhóm tự đăng xuất',
      width: 'w-44',
      cell: (r) => IDLE_GROUP_LABEL[r.idle_group] ?? r.idle_group,
    },
    { key: 'users', header: 'Số người', align: 'right', width: 'w-24', cell: (r) => r.users },
    { key: 'cells', header: 'Ô quyền', align: 'right', width: 'w-24', cell: (r) => r.cells },
    {
      key: 'actions',
      header: 'Thao tác',
      headerSrOnly: 'Thao tác',
      width: 'w-36',
      cell: (r) => (
        <FromLink
          to={`/crm/quan-tri/ma-tran-quyen?vai-tro=${encodeURIComponent(r.code)}`}
          className="text-link hover:underline"
          aria-label={`Mở ma trận quyền của ${r.name}`}
        >
          Mở ma trận
        </FromLink>
      ),
    },
  ];

  return (
    <PageFrame>
      <PageHeader
        title="Vai trò"
        description="Các vai trò hệ thống và phạm vi dữ liệu mặc định. Vai trò là danh mục hệ thống nên không thêm hay xoá ở đây; muốn đổi quyền của một vai trò, mở ma trận quyền."
      />
      <section
        aria-label="Danh sách vai trò"
        className="min-w-0 rounded-box border border-border bg-surface"
      >
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border p-3">
          <p className="text-body text-fg-muted">
            <b className="text-h2 text-fg">{roles.data?.length ?? 0}</b> vai trò
          </p>
          <TextField
            label="Tìm vai trò"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Tìm theo tên hoặc mã"
          />
        </div>
        {roles.isError ? (
          <div className="p-4">
            <StateView
              kind="error"
              title="Không tải được danh sách vai trò"
              actions={<Button onClick={() => void roles.refetch()}>Thử lại</Button>}
            >
              {errorOf(roles.error).message}
            </StateView>
          </div>
        ) : !roles.data ? (
          <div className="p-4">
            <Spinner label="Đang tải vai trò…" />
          </div>
        ) : (
          <LineTable
            wrap
            caption="Các vai trò"
            columns={columns}
            rows={rows}
            rowKey={(r) => r.code}
            rowLabel={(r) => r.name}
            empty={<p className="p-4 text-body text-fg-muted">Không có vai trò nào khớp.</p>}
          />
        )}
      </section>
    </PageFrame>
  );
}
