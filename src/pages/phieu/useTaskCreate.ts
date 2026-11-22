// Dữ liệu biểu mẫu tạo phiếu từ chi tiết ticket: trường hồ sơ sửa được (cấu hình) và gọi app.create_ticket_task.
import type { SupabaseClient } from '@supabase/supabase-js';
import { useQuery } from '@tanstack/react-query';
import { errorOf, rpc, useDb } from '../../lib/db';
import type { DestBranch, TaskOptions } from './businessTaskForm';
import type { TaskFieldDef } from './taskForm';

/** Trường hồ sơ sửa được bằng phiếu Cập nhật hồ sơ (cấu hình app.ticket_task_field), cho biểu mẫu tạo phiếu. */
export function useTaskFields(enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-fields'],
    enabled,
    staleTime: Infinity,
    queryFn: async () => {
      const { data, error } = await supabase
        .schema('app')
        .from('ticket_task_field')
        .select('entity, field_code, label')
        .eq('is_active', true)
        .order('entity')
        .order('label')
        .returns<TaskFieldDef[]>();
      if (error) throw errorOf(error);
      return data;
    },
  });
}

/** Tạo phiếu ở bước Nháp (app.create_ticket_task); trả id và mã phiếu. */
export function createTicketTask(
  supabase: SupabaseClient,
  args: { ticketId: string; type: string; reason: string; payload: unknown },
) {
  return rpc<{ id: string; code: string }>(supabase, 'create_ticket_task', {
    p_ticket_id: args.ticketId,
    p_type: args.type,
    p_reason: args.reason,
    p_payload: args.payload,
  });
}

/** Tuỳ chọn cho biểu mẫu Bảo lưu, Chuyển lớp (app.get_task_form_options): ghi danh của học sinh, lý do, lớp mới. */
export function useTaskOptions(ticketId: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-options', ticketId],
    enabled,
    queryFn: () => rpc<TaskOptions>(supabase, 'get_task_form_options', { p_ticket_id: ticketId }),
  });
}

/** Cơ sở dạy học đang hoạt động để chọn cơ sở mới khi Chuyển cơ sở (bảng nhỏ, vài cơ sở; không lấy phòng ban/hội sở). */
export function useDestBranches(enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-dest-branches'],
    enabled,
    staleTime: Infinity,
    queryFn: async () => {
      const { data, error } = await supabase
        .schema('app')
        .from('branch')
        .select('id, code, name')
        .eq('is_active', true)
        .eq('is_office', false)
        .order('sort_order')
        .order('code')
        .returns<DestBranch[]>();
      if (error) throw errorOf(error);
      return data;
    },
  });
}
