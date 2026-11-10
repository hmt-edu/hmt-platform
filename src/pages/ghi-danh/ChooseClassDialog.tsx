// BH-08 Chọn lớp và ngày vào lớp cho một dòng đơn Nháp (hộp thoại mở từ bảng dòng đơn lúc Sửa). Chỉ lớp đã duyệt, còn chỗ, đúng môn, khối, cơ sở của gói (R-GD-06, R-GD-08);
// ngày vào lớp là buổi sắp tới của lớp, lớp chưa có buổi thì ngày đúng thứ có lịch (R-GD-14). "Chưa chọn lớp": ghi danh ở Chờ xếp lớp, vận hành xếp sau.
// Bấm Chọn là lưu ngay vào dòng đơn (hàm set_order_line_class), không cần bấm Lưu đơn; huỷ Sửa đơn không hoàn tác lớp đã chọn.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Alert, Spinner } from '../../ui/Feedback';
import { Dialog } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { ClassPicker, type ClassPick } from './ClassPicker';
import type { MatchingClass } from './enrollTypes';
import { setOrderLineClass, useMatchingClasses } from './useEnrollmentData';

export type ChooseClassTarget = {
  orderId: string;
  lineNo: number;
  packageId: string;
  packageName: string;
  studentName: string | null;
  branchId: string;
  /** Lớp, ngày đang chọn của dòng (nếu có). */
  current: { classId: string; date: string } | null;
};

export function ChooseClassDialog({
  target,
  onClose,
  onSaved,
}: {
  target: ChooseClassTarget | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const classes = useMatchingClasses(target?.packageId ?? null, target?.branchId ?? null);
  return (
    <Dialog
      open={target !== null}
      onOpenChange={(open) => !open && onClose()}
      title="Chọn lớp và ngày vào lớp"
      description={
        target ? `${target.studentName ?? 'Chưa có học sinh'} · ${target.packageName}` : undefined
      }
      wide
    >
      {classes.isPending && <Spinner />}
      {classes.isError && <Alert tone="danger">{errorOf(classes.error).message}</Alert>}
      {target && classes.data && (
        // key: mỗi lần mở một dòng khác thì lựa chọn đặt lại theo lớp đang có của dòng.
        <ChooseBody
          key={`${target.orderId}:${target.lineNo}`}
          target={target}
          classes={classes.data}
          onClose={onClose}
          onSaved={onSaved}
        />
      )}
    </Dialog>
  );
}

function ChooseBody({
  target,
  classes,
  onClose,
  onSaved,
}: {
  target: ChooseClassTarget;
  classes: MatchingClass[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const supabase = useDb();
  const toast = useToast();
  const [pick, setPick] = useState<ClassPick>(
    target.current
      ? { classId: target.current.classId, date: target.current.date }
      : { classId: null, date: '' },
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const ready = pick.classId === null || pick.date !== '';

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await setOrderLineClass(
        supabase,
        target.orderId,
        target.lineNo,
        pick.classId,
        pick.classId ? pick.date : null,
      );
      toast({
        title: pick.classId
          ? 'Đã chọn lớp cho dòng đơn.'
          : 'Dòng đơn chưa chọn lớp: ghi danh sẽ chờ xếp lớp.',
      });
      onSaved();
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <ClassPicker
        classes={classes}
        value={pick}
        onChange={setPick}
        name="bh08-lop"
        allowLater
        laterLabel="Chưa chọn lớp (ghi danh ở Chờ xếp lớp, vận hành xếp sau)"
      />
      <p className="text-caption text-fg-muted">
        Bấm Chọn là lưu ngay vào dòng đơn, không cần bấm Lưu đơn.
      </p>
      {error && <Alert tone="danger">{error}</Alert>}
      <div className="flex justify-end gap-2">
        <Button onClick={onClose} disabled={busy}>
          Huỷ
        </Button>
        <Button
          variant="primary"
          loading={busy}
          disabled={!ready || busy}
          onClick={() => void submit()}
        >
          Chọn
        </Button>
      </div>
    </div>
  );
}
