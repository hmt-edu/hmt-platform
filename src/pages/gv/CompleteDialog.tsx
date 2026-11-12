import { useQuery } from '@tanstack/react-query';
import { errorOf, rpc, useDb } from '../../lib/db';
import { Button, ButtonLink } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { Dialog } from '../../ui/Overlays';
import type { AttendanceSheet } from './attendanceLogic';
import type { SessionOverview } from './sessionContent';
import { buildMissing, stampOf, unmarkedNames } from './sessionCompletion';

/**
 * GV-09 · Hoàn tất buổi: hộp thoại (máy tính) / tấm trượt dưới (điện thoại, do Dialog tự đổi). Liệt kê em còn thiếu theo từng việc,
 * mỗi việc có nút Đi tới; đủ hết thì hiện Đúng hạn / Trễ hạn. KHÔNG đổi tình trạng buổi (R-GV-08: Done do hệ thống).
 */
export function CompleteDialog({
  overview,
  open,
  onOpenChange,
}: {
  overview: SessionOverview;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const supabase = useDb();
  const needSheet = open && overview.attendance_marked < overview.attendance_total;
  const sheet = useQuery({
    queryKey: ['gv-attendance', overview.session_id],
    enabled: needSheet,
    queryFn: () =>
      rpc<AttendanceSheet>(supabase, 'teacher_attendance_sheet', {
        p_session_id: overview.session_id,
      }),
    retry: false,
  });
  const names = sheet.data ? unmarkedNames(sheet.data.students) : null;
  const missing = buildMissing(overview, names);
  const complete = missing.length === 0;
  const stamp = complete ? stampOf(overview, new Date()) : null;

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Hoàn tất buổi"
      description={
        complete
          ? 'Thầy cô đã làm đủ các việc của buổi.'
          : 'Còn việc chưa xong. Làm xong từng mục rồi quay lại đây.'
      }
      footer={
        <>
          <Button variant="secondary" onClick={() => onOpenChange(false)}>
            Đóng
          </Button>
          {complete ? (
            <ButtonLink to="/gv" variant="primary">
              Hoàn tất
            </ButtonLink>
          ) : (
            <Button variant="primary" disabled>
              Hoàn tất
            </Button>
          )}
        </>
      }
    >
      {complete ? (
        <div className="flex flex-col gap-2" data-testid="gv09-complete">
          {stamp ? (
            <p
              className="text-h4"
              data-testid="gv09-stamp"
              data-kind={stamp.kind === 'ON_TIME' ? 'on-time' : 'late'}
            >
              {stamp.text}
            </p>
          ) : (
            <p className="text-body">Buổi đã Done.</p>
          )}
          <p className="text-caption text-fg-muted">
            Hệ thống tự chuyển buổi sang Done. Màn này không đổi tình trạng buổi.
          </p>
        </div>
      ) : (
        <ul className="flex flex-col gap-3" aria-label="Việc còn thiếu" data-testid="gv09-missing">
          {missing.map((item) => (
            <li key={item.key} className="flex flex-col gap-1 rounded-lg border border-border p-3">
              <div className="flex items-center gap-2">
                <div className="min-w-0 flex-1">
                  <p className="text-body font-medium">{item.title}</p>
                  <p className="text-caption text-fg-muted">{item.summary}</p>
                </div>
                {item.path && (
                  <ButtonLink to={item.path} size="sm">
                    Đi tới
                  </ButtonLink>
                )}
              </div>
              {item.key === 'attendance' && needSheet && sheet.isPending && <Spinner />}
              {item.key === 'attendance' && sheet.isError && (
                <Alert tone="warning" title="Chưa tải được tên em">
                  {errorOf(sheet.error).message}
                </Alert>
              )}
              {item.names.length > 0 && (
                <ul className="list-disc pl-5 text-body">
                  {item.names.map((name) => (
                    <li key={name}>{name}</li>
                  ))}
                  {item.more > 0 && <li>và {item.more} em nữa</li>}
                </ul>
              )}
            </li>
          ))}
        </ul>
      )}
    </Dialog>
  );
}
