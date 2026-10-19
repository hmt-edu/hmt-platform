// Ô "Gắn với" của hộp Tạo lịch hẹn khi tạo từ màn Lịch hẹn (TS-13): tìm lead theo tên, SĐT, mã (cả mã cũ) ở máy chủ.
// Bản này chỉ chọn lead; cơ hội thêm khi có màn Cơ hội (TS-08). Lịch hẹn không có hồ sơ mồ côi (R-CRM-04).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { rpc, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Combobox, type ComboOption } from '../../ui/Inputs';
import { formatPhone, leadTitle } from '../../pages/lead/leadFormat';
import type { LeadPage, LeadRow } from '../../pages/lead/leadTypes';
import type { AppointmentTarget } from './AppointmentDialog';

export type PickedLead = AppointmentTarget & { leadId: string };

const toOption = (r: LeadRow): ComboOption => ({
  value: r.id,
  label: `${r.code} · ${leadTitle(r)}`,
  hint: `${formatPhone(r.parent_phone)} · ${r.branch_code}`,
  keywords: r.code,
});

export function LeadPicker({
  value,
  onChange,
  error,
}: {
  value: PickedLead | null;
  onChange: (lead: PickedLead | null) => void;
  error?: string | null | undefined;
}) {
  const supabase = useDb();
  const access = useAccess();
  const limit = useIntSetting('list_page_size_default');
  const [query, setQuery] = useState('');
  const debounced = useDebounced(query);
  const search = useQuery({
    queryKey: ['lead-picker', debounced.trim(), limit],
    enabled: limit !== null,
    queryFn: () =>
      rpc<LeadPage>(supabase, 'list_leads', {
        p_filters: debounced.trim() === '' ? {} : { q: debounced.trim() },
        p_sort: 'created_desc',
        p_limit: limit,
        p_offset: 0,
      }),
  });
  const found = search.data?.rows ?? [];
  // Lead đã chọn luôn có mặt trong danh sách (kể cả khi ô tìm đổi và kết quả không còn có nó).
  const options: ComboOption[] = [
    ...(value && !found.some((r) => r.id === value.leadId)
      ? [{ value: value.leadId, label: value.label }]
      : []),
    ...found.map(toOption),
  ];
  const byId = new Map(found.map((r) => [r.id, r]));

  return (
    <Combobox
      label="Gắn với"
      required
      help="Bắt buộc: lịch hẹn phải gắn với 1 lead. Gõ tên, số điện thoại hoặc mã để tìm."
      placeholder="Tìm lead…"
      options={options}
      value={value ? [value.leadId] : []}
      loading={search.isFetching}
      onSearch={setQuery}
      error={error}
      onChange={([id]) => {
        const row = id ? byId.get(id) : undefined;
        // Danh sách lead chỉ trả mã cơ sở; đổi sang id để ô "Người phụ trách" lấy đúng nhân sự của cơ sở đó.
        const branch = access.teachingBranches.find((b) => b.code === row?.branch_code);
        if (!row || !branch) return;
        onChange({
          leadId: row.id,
          label: `${row.code} · ${leadTitle(row)}`,
          branchId: branch.id,
        });
      }}
    />
  );
}
