// Gọi dữ liệu CH-08 Chiến dịch marketing: danh sách phân trang ở máy chủ (list_campaigns), tạo (create_campaign), Ngừng/Dùng lại (set_campaign_active).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { CampaignFilters, CampaignPage } from './campaignLogic';

export function useCampaigns(filters: CampaignFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['campaigns', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<CampaignPage>(supabase, 'list_campaigns', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useRefreshCampaigns() {
  const queryClient = useQueryClient();
  return useCallback(
    () =>
      Promise.all(
        ['campaigns', 'lead-campaigns'].map((key) =>
          queryClient.invalidateQueries({ queryKey: [key] }),
        ),
      ),
    [queryClient],
  );
}

export function createCampaign(
  supabase: SupabaseClient,
  input: { name: string; startsOn: string | null; endsOn: string | null },
): Promise<{ id: string }> {
  return rpc<{ id: string }>(supabase, 'create_campaign', {
    p_name: input.name,
    p_starts_on: input.startsOn,
    p_ends_on: input.endsOn,
  });
}

export function setCampaignActive(
  supabase: SupabaseClient,
  id: string,
  active: boolean,
): Promise<void> {
  return rpc<void>(supabase, 'set_campaign_active', { p_id: id, p_active: active });
}
