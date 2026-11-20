// GD-03 Xếp lớp cho ghi danh (hộp thoại, mở từ GD-06 Hàng chờ xếp lớp và GD-02 Ghi danh): hai cách: "Theo nhóm lớp" (ghi danh Đại vào lớp Đại, ghi danh Hình
// vào lớp Hình của cùng học sinh, một giao dịch) hoặc "Một lớp lẻ". Chỉ lớp đã duyệt, còn chỗ, đúng gói; lớp trùng buổi hiện mờ kèm lý do (R-GD-14, R-GD-15).
// Mọi luật kiểm cuối cùng ở máy chủ (app.assign_enrollment_class); trùng giờ thật vẫn báo lỗi có mã ở đó.
import { useMemo, useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { Dialog, Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { ClassPicker, type ClassPick } from './ClassPicker';
import { defaultStart, upcomingLabel } from './enrollLogic';
import type { AssignOptions } from './enrollTypes';
import { assignEnrollments, useAssignOptions, useRefreshEnrollments } from './useEnrollmentData';

type Mode = 'group' | 'single';

export function AssignClassDialog({
  enrollmentId,
  onClose,
}: {
  /** Mở khi có mã ghi danh; đóng khi null. */
  enrollmentId: string | null;
  onClose: () => void;
}) {
  const options = useAssignOptions(enrollmentId);
  return (
    <Dialog
      open={enrollmentId !== null}
      onOpenChange={(open) => !open && onClose()}
      title="Xếp lớp cho ghi danh"
      wide
      description={
        options.data
          ? `${options.data.enrollment.student_name} · ${options.data.siblings.length} ghi danh chờ xếp lớp`
          : undefined
      }
    >
      {options.isPending && <Spinner />}
      {options.isError && <Alert tone="danger">{errorOf(options.error).message}</Alert>}
      {options.data && (
        <AssignBody key={options.data.enrollment.id} data={options.data} onClose={onClose} />
      )}
    </Dialog>
  );
}

function AssignBody({ data, onClose }: { data: AssignOptions; onClose: () => void }) {
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshEnrollments();
  const hasGroups = data.groups.length > 0;
  const [mode, setMode] = useState<Mode>(hasGroups ? 'group' : 'single');
  const [groupId, setGroupId] = useState<string | null>(data.groups[0]?.group_id ?? null);
  // Ngày vào lớp của từng ghi danh trong nhóm (mặc định buổi sắp tới đầu tiên của lớp được gợi ý).
  const [groupDates, setGroupDates] = useState<Record<string, string>>({});
  const [pick, setPick] = useState<ClassPick>({ classId: null, date: '' });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const group = data.groups.find((g) => g.group_id === groupId) ?? null;
  const entries = useMemo(() => {
    if (mode === 'group') {
      return (group?.pairs ?? []).map((p) => ({
        enrollment_id: p.enrollment_id,
        class_id: p.class.id,
        start_date: groupDates[p.enrollment_id] ?? defaultStart(p.class),
      }));
    }
    return pick.classId && pick.date
      ? [{ enrollment_id: data.enrollment.id, class_id: pick.classId, start_date: pick.date }]
      : [];
  }, [mode, group, groupDates, pick, data.enrollment.id]);
  const ready = entries.length > 0 && entries.every((e) => e.start_date !== '');

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const n = await assignEnrollments(supabase, entries);
      await refresh();
      toast({ tone: 'success', title: n === 1 ? 'Đã xếp lớp.' : `Đã xếp lớp cho ${n} ghi danh.` });
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <div role="radiogroup" aria-label="Cách xếp lớp" className="flex flex-wrap gap-2">
        {hasGroups && (
          <ModeButton on={mode === 'group'} onClick={() => setMode('group')}>
            Theo nhóm lớp
          </ModeButton>
        )}
        <ModeButton on={mode === 'single'} onClick={() => setMode('single')}>
          Một lớp lẻ
        </ModeButton>
      </div>

      {mode === 'group' && group && (
        <div className="flex flex-col gap-2">
          <p className="text-caption font-semibold text-fg-label">
            NHÓM LỚP PHÙ HỢP ({data.groups.length})
          </p>
          <ul className="flex flex-col gap-1" aria-label="Nhóm lớp phù hợp">
            {data.groups.map((g) => (
              <li key={g.group_id}>
                <label className="flex cursor-pointer items-start gap-2 rounded-control border border-border p-2">
                  <input
                    type="radio"
                    name="nhom-lop"
                    checked={groupId === g.group_id}
                    onChange={() => setGroupId(g.group_id)}
                    className="mt-1"
                  />
                  <span className="min-w-0 flex-1">
                    <span className="block font-medium">{g.group_name ?? 'Nhóm lớp'}</span>
                    <span className="block text-caption text-fg-muted">
                      {g.pairs.map((p) => `${p.class.subject_name} ${p.class.code}`).join(' · ')}
                    </span>
                  </span>
                </label>
              </li>
            ))}
          </ul>
          <p className="text-caption font-semibold text-fg-label">XẾP VÀO</p>
          <div className="overflow-x-auto rounded-control border border-border">
            <table aria-label="Xếp vào" className="w-full text-body">
              <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
                <tr>
                  <th className="px-3 py-2">Ghi danh</th>
                  <th className="px-3 py-2">Môn</th>
                  <th className="px-3 py-2">Lớp</th>
                  <th className="px-3 py-2">Ngày vào lớp</th>
                </tr>
              </thead>
              <tbody>
                {group.pairs.map((p) => (
                  <tr key={p.enrollment_id} className="border-t border-border">
                    <td className="px-3 py-2">{p.enrollment_code}</td>
                    <td className="px-3 py-2">{p.class.subject_name}</td>
                    <td className="px-3 py-2">{p.class.code}</td>
                    <td className="px-3 py-2">
                      {p.class.has_sessions ? (
                        <Select
                          label={`Ngày vào lớp ${p.enrollment_code}`}
                          value={groupDates[p.enrollment_id] ?? defaultStart(p.class)}
                          onChange={(v) => setGroupDates((d) => ({ ...d, [p.enrollment_id]: v }))}
                          options={p.class.upcoming.map((u) => ({
                            value: u.date,
                            label: upcomingLabel(u.date, u.session_no),
                          }))}
                        />
                      ) : (
                        <span className="text-fg-muted">
                          Lớp chưa có buổi: xếp một lớp lẻ để chọn ngày
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="text-caption text-fg-muted">
            Hai lớp của nhóm cùng thứ, giờ, phòng nhưng luân phiên: không có buổi nào trùng, xếp
            được cả hai (R-GD-15).
          </p>
          <p className="text-caption text-fg-muted">
            Chọn nhóm thì ghi danh Đại vào lớp Đại, ghi danh Hình vào lớp Hình. Học sinh chỉ có một
            ghi danh thì chỉ xếp lớp tương ứng.
          </p>
        </div>
      )}

      {mode === 'single' && (
        <div className="flex flex-col gap-2">
          <p className="text-caption text-fg-muted">
            Chọn từng ghi danh một lớp: dùng khi học sinh không học theo nhóm.
          </p>
          <ClassPicker
            classes={data.classes}
            value={pick}
            onChange={setPick}
            name="lop-le"
            enrollMode={data.enrollment.delivery_mode_code}
          />
        </div>
      )}

      {error && <Alert tone="danger">{error}</Alert>}
      <div className="flex justify-end gap-2">
        <Button onClick={onClose} disabled={busy}>
          Đóng
        </Button>
        <Button
          variant="primary"
          loading={busy}
          disabled={!ready || busy}
          onClick={() => void submit()}
        >
          Xếp lớp
        </Button>
      </div>
    </div>
  );
}

function ModeButton({
  on,
  onClick,
  children,
}: {
  on: boolean;
  onClick: () => void;
  children: string;
}) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={on}
      onClick={onClick}
      className={`focus-ring min-h-11 rounded-control border px-3 text-body ${on ? 'border-border-strong bg-selected font-semibold text-on-selected' : 'border-border bg-surface hover:bg-hover'}`}
    >
      {children}
    </button>
  );
}
