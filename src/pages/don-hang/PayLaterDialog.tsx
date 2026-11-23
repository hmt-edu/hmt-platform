// BH-09 hộp «Bật cho học trước, đóng tiền sau» (canvas 9933 BH09_bat) và hộp tắt. Luật R-GD-12: quản lý cơ sở bật trên đơn đã duyệt chưa thu tiền; ghi danh tạo sớm;
// quỹ giờ được âm tối đa `max_sessions_ahead` buổi; vượt thì em bị loại khỏi danh sách các buổi sau. Máy chủ kiểm quyền, cờ, trạng thái đơn, đã thu tiền hay chưa.
import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { ConfirmDialog } from '../../ui/Dialogs';
import { useToast } from '../../ui/toastContext';
import { setOrderPayLater } from './usePayLater';

export function PayLaterDialog({
  open,
  onOpenChange,
  orderId,
  orderCode,
  enabled,
  onDone,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  orderId: string;
  orderCode: string;
  /** Đơn đang bật: hộp là hộp Tắt. */
  enabled: boolean;
  onDone: () => void;
}) {
  const supabase = useDb();
  const toast = useToast();
  const client = useQueryClient();
  const ahead = useIntSetting('max_sessions_ahead');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const turnOn = !enabled;
  return (
    <ConfirmDialog
      open={open}
      onOpenChange={(next) => {
        if (!busy) {
          if (!next) setError(null);
          onOpenChange(next);
        }
      }}
      title={turnOn ? 'Bật cho học trước, đóng tiền sau' : 'Tắt cho học trước'}
      summary={[
        { label: 'Đơn hàng', value: orderCode },
        ...(turnOn && ahead !== null
          ? [{ label: 'Hạn mức học trước', value: `${ahead} buổi` }]
          : []),
      ]}
      description={
        turnOn
          ? 'Ghi danh được tạo sớm cho các dòng của đơn, em học trước khi đóng tiền. Quỹ giờ được âm tối đa bằng hạn mức; vượt hạn mức thì em bị loại khỏi danh sách các buổi sau, kèm cảnh báo cho vận hành và sale. Khi thu tiền, các buổi đã học vẫn tính là đã học và trừ vào giờ được cấp.'
          : 'Các ghi danh của đơn không còn được học trước. Chỉ tắt được khi mọi ghi danh còn quỹ giờ không âm; nếu đã học trước thì thu tiền trước.'
      }
      confirmLabel={turnOn ? 'Bật' : 'Tắt'}
      tone={turnOn ? 'primary' : 'danger'}
      busy={busy}
      error={error}
      onConfirm={() => {
        setBusy(true);
        setError(null);
        void setOrderPayLater(supabase, orderId, turnOn, null)
          .then(async () => {
            await client.invalidateQueries({ queryKey: ['order-pay-later', orderId] });
            onOpenChange(false);
            onDone();
            toast({ title: turnOn ? 'Đã bật cho học trước.' : 'Đã tắt cho học trước.' });
          })
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    />
  );
}
