// QT-10 Công tắc tính năng theo cơ sở (bản đồ màn hình: Cấu hình · K10, chỉ Admin, máy tính). Bảng phân hệ × cơ sở; mỗi ô Bật hoặc Tắt, đổi qua hộp xác nhận.
// Không có khung canvas riêng cho QT-10 (BAN-DO-VIEC: «Thiếu khung canvas»): dựng từ khuôn K10 và bảng của QT-09, chữ lấy từ bản đồ màn hình.
// Luật: R-HT-02, R-V2-10 (đủ năm cơ sở kể cả CS3), R-LMS-05; không có dòng công tắc là Tắt. Kiểm quyền ở hàm DB set_feature (Admin).
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { ConfirmDialog } from '../../ui/Dialogs';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { useToast } from '../../ui/toastContext';
import { enabledCount, isEnabled, shortName, type FeatureModule } from './featureLogic';
import {
  setFeature,
  useFeatureFlags,
  useFeatureModules,
  useRefreshFeatures,
} from './useFeatureData';
import { PageFrame, PageHeader } from '../../ui/PageHeader';

type Change = { module: FeatureModule; branchId: string; next: boolean };

export function FeatureFlagsPage() {
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshFeatures();
  const modules = useFeatureModules();
  const flags = useFeatureFlags();
  const [change, setChange] = useState<Change | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const canEdit = access.can('ADMIN', 'SUA');
  const branches = access.teachingBranches;
  const branchCode = (id: string) => branches.find((b) => b.id === id)?.code ?? id;
  const list = flags.data ?? [];

  const columns: LineColumn<FeatureModule>[] = [
    {
      key: 'module',
      header: 'Phân hệ',
      cell: (m) => (
        <div className="flex flex-col">
          <span className="font-semibold">{shortName(m.name)}</span>
          <span className="text-caption text-fg-muted">{m.name}</span>
        </div>
      ),
    },
    ...branches.map<LineColumn<FeatureModule>>((b) => ({
      key: b.id,
      header: b.code,
      align: 'center',
      width: 'w-28',
      cell: (m) => {
        const on = isEnabled(list, m.code, b.id);
        return canEdit ? (
          <Button
            variant="text"
            aria-label={`${shortName(m.name)} ở ${b.code}: ${on ? 'đang bật' : 'đang tắt'}. ${on ? 'Tắt' : 'Bật'}`}
            onClick={() => {
              setError(null);
              setChange({ module: m, branchId: b.id, next: !on });
            }}
          >
            <Tag tone={on ? 'success' : 'neutral'}>{on ? 'Bật' : 'Tắt'}</Tag>
          </Button>
        ) : (
          <Tag tone={on ? 'success' : 'neutral'}>{on ? 'Bật' : 'Tắt'}</Tag>
        );
      },
    })),
    {
      key: 'count',
      header: 'Đang bật',
      align: 'right',
      width: 'w-24',
      cell: (m) => `${enabledCount(list, m.code)}/${branches.length}`,
    },
  ];

  return (
    <PageFrame>
      <PageHeader
        title="Công tắc tính năng"
        description="Bật từng phân hệ cho từng cơ sở (chạy CS5 trước). Chưa có công tắc nghĩa là Tắt. Hàm nghiệp vụ trong DB cũng kiểm công tắc này."
      />
      <section
        aria-label="Công tắc theo phân hệ và cơ sở"
        className="min-w-0 rounded-box border border-border bg-surface"
      >
        {modules.isError || flags.isError ? (
          <div className="p-4">
            <StateView
              kind="error"
              title="Không tải được công tắc"
              actions={
                <Button
                  onClick={() => {
                    void modules.refetch();
                    void flags.refetch();
                  }}
                >
                  Thử lại
                </Button>
              }
            >
              {errorOf(modules.error ?? flags.error).message}
            </StateView>
          </div>
        ) : modules.data && flags.data ? (
          <LineTable
            wrap
            caption="Công tắc tính năng theo phân hệ và cơ sở"
            columns={columns}
            rows={modules.data}
            rowKey={(m) => m.code}
            rowLabel={(m) => shortName(m.name)}
          />
        ) : (
          <div className="p-4">
            <Spinner label="Đang tải công tắc…" />
          </div>
        )}
      </section>
      <ConfirmDialog
        open={change !== null}
        onOpenChange={(open) => {
          if (!open && !busy) setChange(null);
        }}
        title={change?.next ? 'Bật phân hệ cho cơ sở' : 'Tắt phân hệ ở cơ sở'}
        summary={
          change
            ? [
                { label: 'Phân hệ', value: shortName(change.module.name) },
                { label: 'Cơ sở', value: branchCode(change.branchId) },
                { label: 'Trạng thái mới', value: change.next ? 'Bật' : 'Tắt' },
              ]
            : undefined
        }
        note={
          change?.next === false
            ? 'Tắt: người dùng của cơ sở không dùng được phân hệ này nữa, kể cả việc đang làm dở.'
            : 'Bật: người dùng của cơ sở dùng được phân hệ này theo quyền của vai trò.'
        }
        tone={change?.next === false ? 'danger' : 'primary'}
        confirmLabel={change?.next ? 'Bật' : 'Tắt'}
        busy={busy}
        error={error}
        onConfirm={() => {
          if (!change) return;
          setBusy(true);
          setError(null);
          void setFeature(supabase, change.module.code, change.branchId, change.next)
            .then(refresh)
            .then(() => {
              setChange(null);
              toast({ title: change.next ? 'Đã bật phân hệ.' : 'Đã tắt phân hệ.' });
            })
            .catch((e: unknown) => setError(errorOf(e).message))
            .finally(() => setBusy(false));
        }}
      />
    </PageFrame>
  );
}
