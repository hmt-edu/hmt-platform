// Lịch "Theo người", chế độ Ngày (Đ34, Đ38): những người có lịch hẹn trong ngày đang xem, xếp theo tên (tiếng Việt), mỗi người một
// cột. Chỉ gồm người có trong các lịch hẹn mà người xem được xem theo ma trận quyền (không thu hẹp quyền xem).
import type { AppointmentRow } from './appointmentTypes';

export function peopleWithAppointments(rows: Pick<AppointmentRow, 'owner_name'>[]): string[] {
  return [...new Set(rows.flatMap((r) => (r.owner_name ? [r.owner_name] : [])))].sort((a, b) =>
    a.localeCompare(b, 'vi'),
  );
}
