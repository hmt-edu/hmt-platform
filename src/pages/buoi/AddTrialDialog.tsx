// BUOI-06 Thêm học sinh học thử vào buổi (hộp thoại K08): chọn CƠ HỘI (tìm theo tên, SĐT, mã ở máy chủ) rồi chọn em của cơ hội; máy chủ quyết luật
// (app.add_trial_student): cơ hội từ L5, buổi Đã chốt, tối đa trial_sessions_max_per_opportunity buổi mỗi cơ hội (R-GD-17), học thử miễn phí, không trừ giờ (R-GD-11).
// Cờ HOC_THU tắt mặc định (nút ẩn khi tắt). Ghi nhận khác khung: chưa cảnh báo khác khối (cơ hội không có cột khối).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { FormDialog } from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { Combobox } from '../../ui/Inputs';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { oppTitle } from '../co-hoi/oppConfig';
import type { OpportunityPage } from '../co-hoi/oppTypes';
import { useOpportunityStudents } from '../bao-gia/useQuoteData';
import { useAddTrialStudent } from './useSessionData';

export function AddTrialDialog({
  sessionId,
  open,
  onClose,
}: {
  sessionId: string;
  open: boolean;
  onClose: () => void;
}) {
  // Khoá theo lần mở để dựng lại trạng thái nhập, không dùng effect.
  return open ? <Body sessionId={sessionId} onClose={onClose} /> : null;
}

function Body({ sessionId, onClose }: { sessionId: string; onClose: () => void }) {
  const supabase = useDb();
  const toast = useToast();
  const add = useAddTrialStudent(sessionId);
  const limit = useIntSetting('list_page_size_default');
  const [query, setQuery] = useState('');
  const debounced = useDebounced(query);
  const q = debounced.trim();
  const [oppId, setOppId] = useState('');
  const [studentRow, setStudentRow] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<string[]>([]);
  const search = useQuery({
    queryKey: ['trial-opp-search', q, limit],
    enabled: limit !== null,
    queryFn: () =>
      rpc<OpportunityPage>(supabase, 'list_opportunities', {
        p_filters: q === '' ? {} : { q },
        p_sort: 'created_desc',
        p_limit: limit,
        p_offset: 0,
      }),
  });
  const students = useOpportunityStudents(oppId, oppId !== '');
  const rows = search.data?.rows ?? [];
  const options = rows.map((r) => ({
    value: r.id,
    label: `${r.code} · ${oppTitle(r)}`,
    hint: `${r.stage_code} · ${r.branch_code}`,
    keywords: r.code,
  }));

  async function submit() {
    setError(null);
    try {
      const res = await add.mutateAsync(studentRow);
      toast({
        tone: res.warnings.length > 0 ? 'warning' : 'success',
        title:
          res.warnings.length > 0
            ? `Đã thêm học thử, kèm cảnh báo: ${res.warnings.join(' ')}`
            : 'Đã thêm học sinh học thử vào buổi',
      });
      setWarnings(res.warnings);
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Thêm học thử"
      confirmLabel="Thêm vào buổi"
      cancelLabel="Đóng"
      canSubmit={oppId !== '' && studentRow !== ''}
      busy={add.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Học thử miễn phí, không trừ giờ, không tính vào sĩ số lớp (R-GD-11, R-GD-17). Chỉ cơ hội
          từ L5 trở lên; mỗi cơ hội có hạn mức số buổi học thử.
        </p>
        <Combobox
          label="Cơ hội"
          required
          help="Gõ tên, số điện thoại hoặc mã để tìm."
          placeholder="Tìm cơ hội…"
          options={options}
          value={oppId ? [oppId] : []}
          loading={search.isFetching}
          onSearch={setQuery}
          onChange={([key]) => {
            setOppId(key ?? '');
            setStudentRow('');
          }}
        />
        {oppId !== '' && (
          <OptionalSelect
            label="Học sinh của cơ hội"
            value={studentRow}
            onChange={setStudentRow}
            options={(students.data ?? []).map((s) => ({
              value: s.id,
              label: s.full_name ?? `Em ${s.position}`,
            }))}
            placeholder={students.isPending ? 'Đang tải…' : 'Chọn học sinh'}
          />
        )}
        {warnings.length > 0 && <Alert tone="warning">{warnings.join(' ')}</Alert>}
      </div>
    </FormDialog>
  );
}
