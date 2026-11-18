// Trạng thái «không có quyền» của các màn cổng Giáo viên (khung 9189: GV02_quyen, GV03_quyen, GV10_quyen, GV11_quyen, GV13_quyen...).
// Máy chủ từ chối (HMT_KHONG_CO_QUYEN: tài khoản chưa liên kết hồ sơ giáo viên hoặc lớp, buổi, học sinh không được phân công) thì hiện câu giải thích thay vì dòng lỗi đỏ chung.
import { StateView } from '../../ui/Feedback';

const TEXT = {
  today: {
    title: 'Tài khoản chưa liên kết hồ sơ giáo viên',
    body: 'Bạn chỉ thấy buổi dạy của mình. Hãy liên hệ quản trị viên để liên kết tài khoản với hồ sơ giáo viên.',
  },
  schedule: {
    title: 'Bạn không xem được lịch này',
    body: 'Giáo viên chỉ thấy lịch của mình. Hãy liên hệ quản trị viên nếu tài khoản chưa liên kết hồ sơ giáo viên.',
  },
  generic: {
    title: 'Bạn không xem được mục này',
    body: 'Giáo viên và trợ giảng chỉ thấy lớp, buổi, học sinh được phân công. Nếu đây là lớp của bạn, hãy liên hệ quản trị viên.',
  },
} as const;

export function GvForbidden({ kind = 'generic' }: { kind?: keyof typeof TEXT }) {
  const t = TEXT[kind];
  return (
    <StateView kind="forbidden" title={t.title} headingLevel={2}>
      {t.body}
    </StateView>
  );
}
