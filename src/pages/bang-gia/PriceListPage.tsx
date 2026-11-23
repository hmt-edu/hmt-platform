// CH-03 Bảng giá (theo gói, anh chốt 06/11): giá hiệu lực của từng gói (offline, online) tại một ngày chọn, nhóm hiển thị theo Loại gói,
// Môn, Khối. Chip "Chưa có giá" (hổ phách: chưa có dòng giá, chờ cập nhật) và "Không bán" (xám: dòng giá để trống, hoặc dịch vụ, tài liệu
// không có online). "Thêm bảng giá mới" thêm nhiều giá một lần. Giá đã tạo không sửa, muốn đổi thì thêm giá ngày hiệu lực mới (R-TIEN-14).
// Khác khung CH03: khung vẽ "bản bảng giá" và dòng theo nhóm; màn này theo gói (DB lưu giá từng gói).
import { useMemo, useState } from 'react';
import { errorOf, useIntSetting } from '../../lib/db';
import { formatMoney } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Pagination, Table, Tag, type TableGroup } from '../../ui/Data';
import { StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { AddPricesDialog } from './AddPricesDialog';
import { priceUnit, toDateKey, type PriceCell } from './priceLogic';
import { usePricePage, useRefreshPrices, type PriceFilters, type PriceRow } from './usePriceData';

export function PriceCellView({ cell, type }: { cell: PriceCell; type: string }) {
  if (cell.state === 'CO_GIA') {
    return (
      <span className="tabular">
        {formatMoney(cell.price)}/{priceUnit(type)}
      </span>
    );
  }
  if (cell.state === 'CHUA_CO_GIA') {
    return (
      <span className="flex flex-col gap-0.5">
        <Tag tone="warning">Chưa có giá</Tag>
        <span className="text-caption text-fg-muted">Chờ cập nhật, không phải ngừng bán</span>
      </span>
    );
  }
  return (
    <span className="flex flex-col gap-0.5">
      <Tag tone="neutral">Không bán</Tag>
      <span className="text-caption text-fg-muted">Gói không bán hình thức này</span>
    </span>
  );
}

export function PriceListPage() {
  const access = useAccess();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const refresh = useRefreshPrices();
  const pageSize = useIntSetting('list_page_size_default');
  const [on, setOn] = useState<Date>(() => new Date());
  const [search, setSearch] = useState('');
  const [type, setType] = useState('');
  const [subject, setSubject] = useState('');
  const [grade, setGrade] = useState('');
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [adding, setAdding] = useState(false);
  const q = useDebounced(search);
  const filters: PriceFilters = { q, type, subject, grade };
  const onKey = toDateKey(on);
  const pagingKey = `${onKey}|${JSON.stringify(filters)}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const list = usePricePage(onKey, filters, page * (pageSize ?? 0), pageSize);
  const rows = useMemo(() => list.data?.rows ?? [], [list.data]);
  const total = list.data?.total ?? 0;
  const canAdd = access.can('CONFIG_SALES', 'TAO');

  // Nhóm chỉ để hiển thị (Loại gói, Môn, Khối); máy chủ đã xếp đúng thứ tự nên chỉ gộp các dòng liền nhau.
  const groups = useMemo(() => {
    const out: TableGroup<PriceRow>[] = [];
    for (const r of rows) {
      const tKey = `t:${r.package_type_code}`;
      let t = out.find((g) => g.key === tKey);
      if (!t) {
        t = {
          key: tKey,
          label: catalogs.name('PACKAGE_TYPE', r.package_type_code) ?? r.package_type_code,
          count: 0,
          children: [],
          rows: [],
        };
        out.push(t);
      }
      t.count += 1;
      const sKey = `${tKey}|s:${r.subject_code ?? ''}`;
      let s = t.children.find((g) => g.key === sKey);
      if (!s) {
        s = {
          key: sKey,
          label: r.subject_code
            ? (catalogs.name('SUBJECT', r.subject_code) ?? r.subject_code)
            : 'Không gắn môn',
          count: 0,
          children: [],
          rows: [],
        };
        t.children.push(s);
      }
      s.count += 1;
      const gKey = `${sKey}|g:${r.grade_from_code ?? ''}|${r.grade_to_code ?? ''}`;
      let g = s.children.find((x) => x.key === gKey);
      if (!g) {
        const from = r.grade_from_code
          ? (catalogs.name('GRADE', r.grade_from_code) ?? r.grade_from_code)
          : 'Không gắn khối';
        const to = r.grade_to_code
          ? ` đến ${catalogs.name('GRADE', r.grade_to_code) ?? r.grade_to_code}`
          : '';
        g = { key: gKey, label: `${from}${to}`, count: 0, children: [], rows: [] };
        s.children.push(g);
      }
      g.count += 1;
      g.rows.push(r);
    }
    return out;
  }, [rows, catalogs]);

  return (
    <div className="mx-auto flex max-w-[1100px] flex-col gap-4 p-4 md:p-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-h1">Bảng giá</h1>
          <p className="mt-1 text-body text-fg-muted">
            Giá của từng gói theo hình thức học, tại ngày chọn. Giá đã tạo không sửa được: muốn đổi,
            thêm giá với ngày hiệu lực mới. Đơn đã tạo giữ giá lúc tạo.
          </p>
        </div>
        {canAdd && (
          <Button variant="primary" icon="plus" onClick={() => setAdding(true)}>
            Thêm bảng giá mới
          </Button>
        )}
      </div>
      <div className="flex flex-wrap items-end gap-3">
        <DateInput
          label="Giá hiệu lực tại ngày"
          value={on}
          onChange={(d) => d && setOn(d)}
          compact
        />
        <div className="min-w-[200px] flex-1">
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
          options={[{ value: '', label: 'Mọi loại gói' }, ...catalogs.options('PACKAGE_TYPE')]}
        />
        <Select
          label="Môn"
          value={subject}
          onChange={setSubject}
          options={[{ value: '', label: 'Mọi môn' }, ...catalogs.options('SUBJECT')]}
        />
        <Select
          label="Khối"
          value={grade}
          onChange={setGrade}
          options={[{ value: '', label: 'Mọi khối' }, ...catalogs.options('GRADE')]}
        />
      </div>
      {list.isError ? (
        <StateView
          kind="error"
          title="Không tải được bảng giá"
          actions={<Button onClick={() => void list.refetch()}>Thử lại</Button>}
        >
          {errorOf(list.error).message}
        </StateView>
      ) : (
        <Table<PriceRow>
          caption="Bảng giá"
          loading={list.isPending}
          rows={rows}
          groups={groups}
          rowKey={(r) => r.id}
          rowLabel={(r) => r.code}
          rowMuted={(r) => !r.is_active}
          empty={
            <StateView kind="empty" title="Chưa có gói nào" headingLevel={2}>
              Đổi bộ lọc, hoặc tạo gói ở màn Gói bán.
            </StateView>
          }
          columns={[
            {
              key: 'code',
              header: 'Mã gói',
              primary: true,
              cell: (r) => (
                <span className="font-medium">
                  {r.code}
                  {r.is_active ? '' : ' (ngừng)'}
                </span>
              ),
            },
            { key: 'name', header: 'Tên gói', cell: (r) => r.name },
            {
              key: 'off',
              header: 'Giá offline',
              cell: (r) => <PriceCellView cell={r.offline} type={r.package_type_code} />,
            },
            {
              key: 'onl',
              header: 'Giá online',
              cell: (r) => <PriceCellView cell={r.online} type={r.package_type_code} />,
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
        Giá trống nghĩa là gói không bán hình thức đó. Chip &quot;Chưa có giá&quot;: chờ cập nhật,
        không phải ngừng bán. Chip &quot;Không bán&quot;: gói không bán hình thức đó, ví dụ dịch vụ,
        tài liệu không có giá online.
      </p>
      <AddPricesDialog
        open={adding}
        onOpenChange={setAdding}
        onDone={(message) => {
          void refresh();
          toast({ title: message });
        }}
      />
    </div>
  );
}
