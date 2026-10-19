import type { TagTone } from '../../ui/Data';
import type { AppointmentStatus } from './appointmentTypes';

export const STATUS_TONE: Record<AppointmentStatus, TagTone> = {
  CHUA_LAM: 'neutral',
  HOAN_THANH: 'success',
  HUY: 'neutral',
};
