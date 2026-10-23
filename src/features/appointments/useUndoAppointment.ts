// Nút "Hoàn tác" trên thông báo sau khi Hoàn thành hoặc Huỷ một lịch hẹn: mở lại lịch về Chưa làm (R-CRM-04, ghi lịch sử như Mở lại).
// Bấm Hoàn tác ngay sau thao tác là cố ý, nên không hỏi xác nhận lần nữa (khác nút Mở lại ở màn Lịch hẹn, có hộp xác nhận).
import { useCallback } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { useToast } from '../../ui/toastContext';
import { reopenAppointment } from './appointmentApi';

export function useUndoAppointment(refresh: () => Promise<void>) {
  const supabase = useDb();
  const toast = useToast();
  return useCallback(
    (id: string) => ({
      label: 'Hoàn tác',
      onClick: () => {
        void reopenAppointment(supabase, id)
          .then(refresh)
          .then(() => toast({ title: 'Đã hoàn tác, lịch hẹn về Chưa làm.' }))
          .catch((e: unknown) => toast({ tone: 'danger', title: errorOf(e).message }));
      },
    }),
    [supabase, toast, refresh],
  );
}
