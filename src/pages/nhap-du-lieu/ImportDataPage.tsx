// QT-18 Nhập dữ liệu cũ (chỉ Admin): chọn loại nạp, tải file CSV, xem trước từng dòng, nạp thật, tải dòng lỗi.
// Bản tối giản dựng theo khuôn hộp nhiều bước K4b ⑤ (anh chốt 05/11: Design chưa vẽ, không chờ).
import { useState } from 'react';
import { Button } from '../../ui/Button';
import { ImportDataDialog } from './ImportDataDialog';
import { IMPORT_KINDS, type ImportKindConfig } from './importKinds';

export function ImportDataPage() {
  const [open, setOpen] = useState<ImportKindConfig | null>(null);
  return (
    <div className="mx-auto flex max-w-[860px] flex-col gap-4 p-4 md:p-6">
      <div>
        <h1 className="text-h1">Nhập dữ liệu</h1>
        <p className="mt-1 text-body text-fg-muted">
          Nạp dữ liệu từ hệ thống cũ theo từng loại. Mỗi lần: chọn loại, tải file CSV, xem trước
          từng dòng (hợp lệ, trùng, lỗi), rồi nạp. Dòng đã có thì bỏ qua, không ghi đè, không tự
          gộp.
        </p>
      </div>
      <ul className="flex flex-col gap-3" aria-label="Loại dữ liệu nạp">
        {IMPORT_KINDS.map((k) => (
          <li
            key={k.kind}
            className="flex flex-wrap items-center justify-between gap-3 rounded-control border border-border bg-surface p-4"
          >
            <div className="min-w-0 flex-1">
              <h2 className="text-h3 font-semibold">{k.title}</h2>
              <p className="text-body text-fg-muted">{k.description}</p>
            </div>
            <Button variant="primary" icon="upload" onClick={() => setOpen(k)}>
              Nhập {k.title.toLowerCase()}
            </Button>
          </li>
        ))}
      </ul>
      {open && (
        <ImportDataDialog config={open} open onOpenChange={(next) => !next && setOpen(null)} />
      )}
    </div>
  );
}
