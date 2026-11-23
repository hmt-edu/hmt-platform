// CH-02 Gói bán (bản ghi, khuôn K06; bản đồ màn hình: Thông tin gói, các giá theo hiệu lực; Sửa, Thêm giá mới; sang CH-03 Bảng giá). Không có khung canvas riêng (CH01_* là danh sách):
// dựng từ khuôn bản ghi chỉ đọc + hộp Sửa, Thêm giá của CH-01. Giá chỉ thêm, không sửa (giá cũ giữ nguyên cho đơn đã lập: R-TIEN-10, chụp lại giá lúc tạo).
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, useDb } from '../../lib/db';
import { formatDate, formatMoney } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { Field, TextField } from '../../ui/Field';
import { Spinner, StateView } from '../../ui/Feedback';
import { DateInput } from '../../ui/Inputs';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { toIso } from '../ngay-nghi/holidayLogic';
import {
  MODE_CODES,
  MODE_LABEL,
  currentPrices,
  parsePriceInput,
  priceStateLabel,
  priceText,
  type PriceRow,
} from './packageRecordLogic';
import { ActivePackageDialog, EditPackageDialog } from './PackageDialogs';
import { addPackagePrice, usePackageRecord, useRefreshPackageRecord } from './usePackageRecord';
import type { PackageRow } from './usePackageData';

export function PackageRecordPage() {
  const { id } = useParams();
  const query = usePackageRecord(id);
  const access = useAccess();
  const toast = useToast();
  const refresh = useRefreshPackageRecord();
  const catalogs = useLeadCatalogs();
  const [editing, setEditing] = useState<PackageRow | null>(null);
  const [toggling, setToggling] = useState<PackageRow | null>(null);
  const [addingPrice, setAddingPrice] = useState(false);
  useCrumbTail(query.data?.pkg ? query.data.pkg.code : null);

  if (query.isPending) return <Spinner label="Đang tải gói bán…" />;
  // Lỗi tải (mạng, máy chủ) khác với «không tìm thấy»: có nút Thử lại.
  if (query.isError) {
    return (
      <StateView
        kind="error"
        title="Không tải được gói bán"
        actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  if (!query.data.pkg) {
    return (
      <StateView kind="not-found" title="Không tìm thấy gói bán">
        Gói không tồn tại hoặc bạn không có quyền xem.
      </StateView>
    );
  }
  const { pkg, prices } = query.data;
  const today = toIso(new Date());
  const current = currentPrices(prices, today);
  const canEdit = access.can('CONFIG_SALES', 'SUA');
  const canAddPrice = access.can('CONFIG_SALES', 'TAO');
  const done = (message: string) => {
    void refresh();
    toast({ title: message });
  };
  const grade = (code: string | null) => (code ? (catalogs.name('GRADE', code) ?? code) : '—');

  const columns: LineColumn<PriceRow>[] = [
    {
      key: 'from',
      header: 'Hiệu lực từ',
      width: 'w-36',
      cell: (r) => <b>{formatDate(r.effective_from)}</b>,
    },
    {
      key: 'mode',
      header: 'Hình thức',
      width: 'w-32',
      cell: (r) => MODE_LABEL[r.delivery_mode_code] ?? r.delivery_mode_code,
    },
    { key: 'price', header: 'Giá', cell: (r) => priceText(r.unit_price, formatMoney) },
    { key: 'state', header: 'Tình trạng', width: 'w-48', cell: (r) => priceStateLabel(r, today) },
  ];

  return (
    <>
      <RecordDetail
        kind="Gói bán"
        title={pkg.code}
        mode="view"
        readOnly
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        aside={
          <p className="p-3 text-body text-fg-muted">
            Ghi chú và hoạt động của gói làm sau. Mọi sửa cấu hình đã ghi nhật ký thao tác.
          </p>
        }
        businessActions={
          <span className="flex flex-wrap items-center gap-2">
            {canEdit && <Button onClick={() => setEditing(pkg)}>Sửa</Button>}
            {canAddPrice && (
              <Button variant="primary" onClick={() => setAddingPrice(true)}>
                Thêm giá mới
              </Button>
            )}
            {canEdit && (
              <Button onClick={() => setToggling(pkg)}>
                {pkg.is_active ? 'Ngừng' : 'Dùng lại'}
              </Button>
            )}
            <Link className="text-body text-action-link underline" to="/crm/cau-hinh/bang-gia">
              Xem bảng giá
            </Link>
            <Tag tone={pkg.is_active ? 'success' : 'neutral'}>
              {pkg.is_active ? 'Đang bán' : 'Ngừng'}
            </Tag>
          </span>
        }
      >
        <div className="grid gap-6 md:grid-cols-2">
          <DetailSection title="Thông tin gói">
            <DetailField label="Mã gói" mode="view" value={pkg.code} />
            <DetailField label="Tên gói" mode="view" value={pkg.name} />
            <DetailField
              label="Loại gói"
              mode="view"
              value={catalogs.name('PACKAGE_TYPE', pkg.package_type_code) ?? pkg.package_type_code}
            />
            <DetailField
              label="Môn"
              mode="view"
              value={
                pkg.subject_code
                  ? (catalogs.name('SUBJECT', pkg.subject_code) ?? pkg.subject_code)
                  : '—'
              }
            />
            <DetailField
              label="Khối"
              mode="view"
              value={
                pkg.grade_from_code &&
                pkg.grade_to_code &&
                pkg.grade_to_code !== pkg.grade_from_code
                  ? `${grade(pkg.grade_from_code)} – ${grade(pkg.grade_to_code)}`
                  : grade(pkg.grade_from_code)
              }
            />
            <DetailField label="Mã cũ (Sheet)" mode="view" value={pkg.legacy_ref ?? '—'} />
          </DetailSection>
          <DetailSection title="Giá đang hiệu lực">
            {MODE_CODES.map((mode) => (
              <DetailField
                key={mode}
                label={MODE_LABEL[mode] ?? mode}
                mode="view"
                value={
                  current[mode]
                    ? `${priceText(current[mode].unit_price, formatMoney)} (từ ${formatDate(current[mode].effective_from)})`
                    : 'Chưa có giá'
                }
              />
            ))}
          </DetailSection>
        </div>
        <section
          aria-label="Giá theo hiệu lực"
          className="mt-6 rounded-box border border-border bg-surface"
        >
          <LineTable
            caption="Giá theo hiệu lực của gói"
            columns={columns}
            rows={prices}
            rowKey={(r) => r.id}
            rowLabel={(r) =>
              `${MODE_LABEL[r.delivery_mode_code] ?? r.delivery_mode_code} ${r.effective_from}`
            }
            empty={
              <p className="p-4 text-body text-fg-muted">
                Gói chưa có giá nào. Bấm «Thêm giá mới».
              </p>
            }
          />
        </section>
        <p className="mt-2 text-caption text-fg-muted">
          Giá chỉ thêm, không sửa: đơn đã lập giữ giá lúc tạo. Giá để trống = ngừng bán hình thức đó
          từ ngày hiệu lực.
        </p>
      </RecordDetail>
      <EditPackageDialog row={editing} onOpenChange={(o) => !o && setEditing(null)} onDone={done} />
      <ActivePackageDialog
        row={toggling}
        onOpenChange={(o) => !o && setToggling(null)}
        onDone={done}
      />
      {addingPrice && (
        <AddPriceForm
          packageId={pkg.id}
          onClose={() => setAddingPrice(false)}
          onDone={(message) => {
            setAddingPrice(false);
            done(message);
          }}
        />
      )}
    </>
  );
}

function AddPriceForm({
  packageId,
  onClose,
  onDone,
}: {
  packageId: string;
  onClose: () => void;
  onDone: (message: string) => void;
}) {
  const supabase = useDb();
  const [mode, setMode] = useState('OFF');
  const [priceText_, setPriceText] = useState('');
  const [from, setFrom] = useState<Date | null>(() => new Date());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const price = parsePriceInput(priceText_);
  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title="Thêm giá mới"
      confirmLabel="Thêm"
      canSubmit={from !== null && price !== undefined}
      busy={busy}
      error={error}
      onSubmit={() => {
        if (!from || price === undefined) return;
        setBusy(true);
        setError(null);
        void addPackagePrice(supabase, { packageId, mode, price, effectiveFrom: toIso(from) })
          .then(() => onDone('Đã thêm giá mới.'))
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <Field label="Hình thức">
          {(field) => (
            <Select
              id={field.id}
              label="Hình thức"
              value={mode}
              onChange={setMode}
              options={MODE_CODES.map((m) => ({ value: m, label: MODE_LABEL[m] ?? m }))}
            />
          )}
        </Field>
        <TextField
          label="Giá (đồng)"
          inputMode="numeric"
          value={priceText_}
          onChange={(e) => setPriceText(e.target.value)}
          help="Để trống nếu ngừng bán hình thức này từ ngày hiệu lực."
          error={price === undefined ? 'Nhập số lớn hơn 0.' : undefined}
        />
        <DateInput label="Hiệu lực từ" required value={from} onChange={setFrom} />
      </div>
    </FormDialog>
  );
}
