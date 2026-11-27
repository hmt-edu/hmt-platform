import type { RowActions } from './AppointmentParts';
import type { AppointmentRow } from './appointmentTypes';

/** Đóng khung chi tiết trước khi mở hộp thao tác. */
export function closingActions(actions: RowActions, close: () => void): RowActions {
  const wrap = (run: (row: AppointmentRow) => void) => (row: AppointmentRow) => {
    close();
    run(row);
  };
  return {
    ...actions,
    onComplete: wrap(actions.onComplete),
    onReschedule: wrap(actions.onReschedule),
    onCancel: wrap(actions.onCancel),
    onReopen: wrap(actions.onReopen),
  };
}
