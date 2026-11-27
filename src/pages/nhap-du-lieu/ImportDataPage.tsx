// QT-18 Nhập dữ liệu cũ (chỉ Admin): chọn loại nạp, tải file CSV, xem trước từng dòng, nạp thật, tải dòng lỗi.
// Dựng theo khung QT18_chon_loai (canvas dc47, Q-209): bảng đủ 8 loại theo thứ tự nạp; loại chưa có hàm nạp là "Sắp có", nút Nhập khoá.
import { useState } from 'react';
import { Button } from '../../ui/Button';
import { downloadText } from '../lead/csv';
import { ImportDataDialog } from './ImportDataDialog';
import { IMPORT_KIND_ROWS, kindConfig, sampleCsvText, type ImportKindConfig } from './importKinds';
import { PageFrame, PageHeader } from '../../ui/PageHeader';

export function ImportDataPage() {
  const [open, setOpen] = useState<ImportKindConfig | null>(null);
  return (
    <PageFrame>
      <PageHeader
        title="Nhập dữ liệu"
        description={
          <>
            Nạp dữ liệu từ hệ thống cũ theo từng loại, đúng thứ tự gợi ý: loại nào cần dữ liệu có
            trước thì nạp sau. Mỗi lần: chọn loại, tải file CSV, xem trước từng dòng (hợp lệ, trùng,
            lỗi), rồi nạp. Dòng đã có thì bỏ qua, không ghi đè, không tự gộp. Loại ghi{' '}
            <strong>Sắp có</strong> chưa nạp được.
          </>
        }
      />
      <div className="overflow-x-auto rounded-control border border-border bg-surface">
        <table className="w-full text-left text-body" aria-label="Loại dữ liệu nạp">
          <thead className="bg-canvas text-caption text-fg-muted">
            <tr>
              <th className="px-3 py-2 font-semibold">Thứ tự</th>
              <th className="px-3 py-2 font-semibold">Loại nạp</th>
              <th className="px-3 py-2 font-semibold">Mô tả</th>
              <th className="px-3 py-2 font-semibold">Cần có trước</th>
              <th className="px-3 py-2 font-semibold">Trạng thái</th>
              <th className="px-3 py-2 font-semibold">
                <span className="sr-only">Thao tác</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {IMPORT_KIND_ROWS.map((row, index) => {
              const config = row.kind ? kindConfig(row.kind) : null;
              return (
                <tr key={row.title} className="border-t border-border align-top">
                  <td className="px-3 py-3 text-fg-muted">{index + 1}</td>
                  <td className="px-3 py-3 font-semibold whitespace-nowrap">{row.title}</td>
                  <td className="px-3 py-3 text-fg-muted">{row.description}</td>
                  <td className="px-3 py-3 text-fg-muted">{row.needs}</td>
                  <td className="px-3 py-3 whitespace-nowrap">
                    {config ? 'Sẵn sàng' : <span className="text-fg-muted">Sắp có</span>}
                  </td>
                  <td className="px-3 py-3">
                    <div className="flex flex-col items-end gap-2 whitespace-nowrap xl:flex-row xl:justify-end">
                      {config && (
                        <Button
                          variant="secondary"
                          icon="download"
                          aria-label={`Tải file mẫu ${row.title.toLowerCase()}`}
                          onClick={() =>
                            downloadText(
                              `mau-${config.kind.toLowerCase()}.csv`,
                              sampleCsvText(config),
                            )
                          }
                        >
                          Tải file mẫu
                        </Button>
                      )}
                      <Button
                        variant="primary"
                        icon="upload"
                        disabled={!config}
                        onClick={() => config && setOpen(config)}
                      >
                        Nhập {row.title.toLowerCase()}
                      </Button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      {open && (
        <ImportDataDialog config={open} open onOpenChange={(next) => !next && setOpen(null)} />
      )}
    </PageFrame>
  );
}
