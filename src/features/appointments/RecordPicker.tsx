// Ô "Gắn với" của hộp Tạo lịch hẹn khi tạo từ màn Lịch hẹn (TS-13): tìm lead và cơ hội theo tên, SĐT, mã (cả mã cũ) ở máy chủ.
// Lịch hẹn không có hồ sơ mồ côi (R-CRM-04). Phiếu kiểm tra có lịch nhắc tự sinh nên không chọn ở đây.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { rpc, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Combobox, type ComboOption } from '../../ui/Inputs';
import { formatPhone, leadTitle } from '../../pages/lead/leadFormat';
import type { LeadPage, LeadRow } from '../../pages/lead/leadTypes';
import { oppTitle } from '../../pages/co-hoi/oppConfig';
import type { OpportunityPage, OpportunityRow } from '../../pages/co-hoi/oppTypes';
import type { AppointmentTarget } from './AppointmentDialog';

export type PickedRecord = AppointmentTarget & { kind: 'LEAD' | 'OPPORTUNITY'; recordId: string };

type Found = { lead: LeadRow[]; opportunity: OpportunityRow[] };

const KEY = { LEAD: 'LEAD:', OPPORTUNITY: 'OPP:' } as const;
const LABEL = { LEAD: 'Lead', OPPORTUNITY: 'Cơ hội' } as const;

export function RecordPicker({
  value,
  onChange,
  error,
}: {
  value: PickedRecord | null;
  onChange: (record: PickedRecord | null) => void;
  error?: string | null | undefined;
}) {
  const supabase = useDb();
  const access = useAccess();
  const limit = useIntSetting('list_page_size_default');
  const [query, setQuery] = useState('');
  const debounced = useDebounced(query);
  const q = debounced.trim();
  const canLead = access.can('LEAD', 'XEM');
  const canOpp = access.can('OPPORTUNITY', 'XEM');
  const search = useQuery({
    queryKey: ['record-picker', q, limit, canLead, canOpp],
    enabled: limit !== null,
    queryFn: async (): Promise<Found> => {
      const filters = q === '' ? {} : { q };
      const [lead, opportunity] = await Promise.all([
        canLead
          ? rpc<LeadPage>(supabase, 'list_leads', {
              p_filters: filters,
              p_sort: 'created_desc',
              p_limit: limit,
              p_offset: 0,
            })
          : Promise.resolve({ total: 0, rows: [] as LeadRow[] }),
        canOpp
          ? rpc<OpportunityPage>(supabase, 'list_opportunities', {
              p_filters: filters,
              p_sort: 'created_desc',
              p_limit: limit,
              p_offset: 0,
            })
          : Promise.resolve({ total: 0, rows: [] as OpportunityRow[] }),
      ]);
      return { lead: lead.rows, opportunity: opportunity.rows };
    },
  });

  const branchOf = (code: string) => access.teachingBranches.find((b) => b.code === code);
  const picks = new Map<string, PickedRecord>();
  const options: ComboOption[] = [];
  const add = (
    kind: PickedRecord['kind'],
    id: string,
    code: string,
    title: string,
    phone: string,
    branchCode: string,
  ) => {
    const branch = branchOf(branchCode);
    if (!branch) return;
    const key = `${KEY[kind]}${id}`;
    const label = `${LABEL[kind]} ${code} · ${title}`;
    picks.set(key, { kind, recordId: id, label: `${code} · ${title}`, branchId: branch.id });
    options.push({
      value: key,
      label,
      hint: `${formatPhone(phone)} · ${branchCode}`,
      keywords: code,
    });
  };
  for (const r of search.data?.lead ?? [])
    add('LEAD', r.id, r.code, leadTitle(r), r.parent_phone, r.branch_code);
  for (const r of search.data?.opportunity ?? [])
    add('OPPORTUNITY', r.id, r.code, oppTitle(r), r.parent_phone, r.branch_code);
  // Hồ sơ đã chọn luôn có mặt trong danh sách (kể cả khi ô tìm đổi và kết quả không còn có nó).
  const selectedKey = value ? `${KEY[value.kind]}${value.recordId}` : null;
  if (value && selectedKey && !options.some((o) => o.value === selectedKey)) {
    options.unshift({ value: selectedKey, label: `${LABEL[value.kind]} ${value.label}` });
  }

  return (
    <Combobox
      label="Gắn với"
      required
      help="Bắt buộc: lịch hẹn phải gắn với 1 lead hoặc cơ hội. Gõ tên, số điện thoại hoặc mã để tìm."
      placeholder="Tìm lead hoặc cơ hội…"
      options={options}
      value={selectedKey ? [selectedKey] : []}
      loading={search.isFetching}
      onSearch={setQuery}
      error={error}
      onChange={([key]) => {
        const picked = key ? picks.get(key) : undefined;
        if (picked) onChange(picked);
      }}
    />
  );
}
