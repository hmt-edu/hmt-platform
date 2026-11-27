// CH-01 Gói bán (cấu hình bán hàng, khuôn K10): danh sách gói (mã, tên, loại, môn, khối, trạng thái), Tạo gói, Sửa tên và mã cũ,
// Ngừng bán / Dùng lại. Không xoá gói. Gói không có số giờ (số giờ nhập khi lập dòng đơn). Lọc, tìm, phân trang ở máy chủ.

import { useState } from 'react';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Table, Tag, Pagination } from '../../ui/Data';
import { StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { ActivePackageDialog, CreatePackageDialog, EditPackageDialog } from './PackageDialogs';
import {
  usePackagePage,
  useRefreshPackages,
  type PackageFilters,
  type PackageRow,
} from './usePackageData';
import { PageFrame, PageHeader } from '../../ui/PageHeader';
import { FromLink } from '../../layout/FromLink';

const STATUS_OPTIONS = [
  { value: '', label: 'Mọi trạng thái' },
  { value: 'active', label: 'Đang bán' },
  { value: 'inactive', label: 'Ngừng' },
];

export function PackageListPage() {
  const access = useAccess();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const refresh = useRefreshPackages();
  const pageSize = useIntSetting('list_page_size_default');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<PackageFilters['status']>('');
  const [type, setType] = useState('');
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<PackageRow | null>(null);
  const [toggling, setToggling] = useState<PackageRow | null>(null);
  const q = useDebounced(search);
  const filters: PackageFilters = { q, status, type };
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const list = usePackagePage(filters, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const canCreate = access.can('CONFIG_SALES', 'TAO');
  const canEdit = access.can('CONFIG_SALES', 'SUA');
  const done = (message: string) => {
    void refresh();
    toast({ title: message });
  };
  const typeOptions = catalogs.options('PACKAGE_TYPE');
  const grade = (r: PackageRow) => {
    if (!r.grade_from_code) return '—';
    const from = catalogs.name('GRADE', r.grade_from_code) ?? r.grade_from_code;
    return r.grade_to_code
      ? `${from} đến ${catalogs.name('GRADE', r.grade_to_code) ?? r.grade_to_code}`
      : from;
  };

  return (
    <PageFrame>
      <PageHeader
        title="Gói bán"
        description={
          <>
            {list.isSuccess ? `${total} gói bán. ` : ''}Mã gói theo Loại-Môn-Khối, không chứa hình
            thức. Giá nằm ở Bảng giá.
          </>
        }
        actions={
          canCreate && (
            <Button variant="primary" icon="plus" onClick={() => setCreating(true)}>
              Tạo gói
            </Button>
          )
        }
      />
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-[240px] flex-1">
          <TextField
            label="Tìm gói"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Tìm mã, tên, mã cũ…"
          />
        </div>
        <Select
          label="Loại gói"
          value={type}
          onChange={setType}
          options={[{ value: '', label: 'Mọi loại gói' }, ...typeOptions]}
        />
        <Select
          label="Trạng thái"
          value={status}
          onChange={(v) => setStatus(v as PackageFilters['status'])}
          options={STATUS_OPTIONS}
        />
      </div>
      {list.isError ? (
        <StateView
          kind="error"
          title="Không tải được danh sách gói"
          actions={<Button onClick={() => void list.refetch()}>Thử lại</Button>}
        >
          {errorOf(list.error).message}
        </StateView>
      ) : (
        <Table<PackageRow>
          caption="Gói bán"
          loading={list.isPending}
          rows={rows}
          rowKey={(r) => r.id}
          rowLabel={(r) => r.code}
          rowMuted={(r) => !r.is_active}
          empty={
            <StateView kind="empty" title="Chưa có gói nào" headingLevel={2}>
              Đổi bộ lọc hoặc tạo gói mới.
            </StateView>
          }
          columns={[
            {
              key: 'code',
              header: 'Mã gói',
              primary: true,
              cell: (r) => (
                <FromLink
                  className="font-medium text-action-link underline"
                  to={`/crm/cau-hinh/goi-ban/${r.id}`}
                >
                  {r.code}
                </FromLink>
              ),
            },
            { key: 'name', header: 'Tên gói', cell: (r) => r.name },
            {
              key: 'type',
              header: 'Loại gói',
              cell: (r) =>
                catalogs.name('PACKAGE_TYPE', r.package_type_code) ?? r.package_type_code,
            },
            {
              key: 'subject',
              header: 'Môn',
              cell: (r) =>
                r.subject_code ? (catalogs.name('SUBJECT', r.subject_code) ?? r.subject_code) : '—',
            },
            { key: 'grade', header: 'Khối', cell: grade },
            {
              key: 'status',
              header: 'Trạng thái',
              cell: (r) =>
                r.is_active ? <Tag tone="success">Đang bán</Tag> : <Tag tone="neutral">Ngừng</Tag>,
            },
            {
              key: 'actions',
              header: '',
              cell: (r) =>
                canEdit ? (
                  <span className="flex gap-2">
                    <Button onClick={() => setEditing(r)}>Sửa</Button>
                    <Button onClick={() => setToggling(r)}>
                      {r.is_active ? 'Ngừng' : 'Dùng lại'}
                    </Button>
                  </span>
                ) : null,
            },
          ]}
        />
      )}
      {pageSize !== null && total > pageSize && (
        <Pagination
          page={page + 1}
          pageSize={pageSize}
          total={total}
          onPageChange={(next) => setPaging({ key: pagingKey, page: next - 1 })}
        />
      )}
      <p className="text-caption text-fg-muted">
        Không xoá gói: chỉ Ngừng. Số giờ nhập khi lập dòng đơn, gói không có cột số giờ.
      </p>
      <CreatePackageDialog
        open={creating}
        onOpenChange={setCreating}
        types={typeOptions}
        subjects={catalogs.options('SUBJECT')}
        grades={catalogs.options('GRADE')}
        onDone={done}
      />
      <EditPackageDialog row={editing} onOpenChange={(o) => !o && setEditing(null)} onDone={done} />
      <ActivePackageDialog
        row={toggling}
        onOpenChange={(o) => !o && setToggling(null)}
        onDone={done}
      />
    </PageFrame>
  );
}
