// HT-07 Kết quả học tập (cổng học sinh): chuyên cần, BTVN (nếu lớp có), điểm ba nhóm theo buổi, theo từng lớp. Chỉ đọc.
// Khung HT07_ds, HT07_khong_btvn, HT07_tai, HT07_loi (canvas 9189). Hai lớp trở lên: chip chọn lớp (đã chốt 23/11).
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useChildren } from './portalData';
import {
  formatScore,
  homeworkRate,
  shortDate,
  usePortalResults,
  type ResultClass,
} from './portalResults';

export function StudentResultsPage() {
  const children = useChildren();
  const student = children.data?.[0];
  const query = usePortalResults(student?.id);
  const [picked, setPicked] = useState<string | null>(null);

  const header = <h1 className="text-h2">Kết quả học tập</h1>;
  if (children.isPending || (student !== undefined && query.isPending))
    return (
      <div className="flex flex-col gap-3">
        {header}
        <Spinner label="Đang tải kết quả…" />
      </div>
    );
  if (children.isError || query.isError)
    return (
      <div className="flex flex-col gap-3">
        {header}
        <Alert tone="danger">{errorOf(children.error ?? query.error).message}</Alert>
        <div>
          <Button
            onClick={() => {
              void children.refetch();
              void query.refetch();
            }}
          >
            Thử lại
          </Button>
        </div>
      </div>
    );
  const classes = query.data?.classes ?? [];
  if (student === undefined || classes.length === 0)
    return (
      <div className="flex flex-col gap-3">
        {header}
        <StateView kind="empty" title="Chưa có kết quả" headingLevel={2}>
          Kết quả sẽ hiện sau khi giáo viên điểm danh và nhận xét các buổi học.
        </StateView>
      </div>
    );

  const current = classes.find((c) => c.class_id === picked) ?? classes[0];
  return (
    <div className="flex flex-col gap-4">
      {header}
      {classes.length > 1 && (
        <div className="flex flex-wrap gap-2" role="group" aria-label="Chọn lớp">
          {classes.map((c) => (
            <Button
              key={c.class_id}
              variant={c.class_id === current?.class_id ? 'primary' : 'secondary'}
              aria-pressed={c.class_id === current?.class_id}
              onClick={() => setPicked(c.class_id)}
            >
              {c.subject_name ?? c.class_code}
            </Button>
          ))}
        </div>
      )}
      {current && <ClassResult cls={current} />}
      <Link to="/hoc/ket-qua/nhan-xet" className="focus-ring text-body font-semibold text-accent">
        Xem nhận xét các buổi
      </Link>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-1 rounded-lg border border-border bg-surface p-3">
      <p className="text-caption text-fg-muted">{label}</p>
      <p className="tabular text-h3 font-semibold">{value}</p>
    </div>
  );
}

export function ClassResult({ cls }: { cls: ResultClass }) {
  const rate = homeworkRate(cls.homework);
  return (
    <section aria-label={cls.class_code} className="flex flex-col gap-3">
      <div className="grid grid-cols-2 gap-2">
        <Stat
          label="Chuyên cần"
          value={`${cls.attendance.present} / ${cls.attendance.total} buổi`}
        />
        {cls.homework.has && (
          <>
            <Stat label="Tỉ lệ làm BTVN" value={rate === null ? '–' : `${rate}%`} />
            <Stat label="Điểm BTVN trung bình" value={formatScore(cls.homework.avg_score)} />
          </>
        )}
      </div>
      {!cls.homework.has && (
        <p className="text-caption text-fg-muted">
          Lớp này giáo viên không giao bài về nhà nên không có phần BTVN.
        </p>
      )}
      <h2 className="text-caption font-semibold text-fg-label">
        ĐIỂM THEO BUỔI · THÁI ĐỘ, KIẾN THỨC, VẬN DỤNG
      </h2>
      <ul className="flex flex-col gap-2">
        {cls.sessions.map((s) => (
          <li
            key={s.session_id}
            className="flex items-center justify-between gap-3 rounded-lg border border-border bg-surface p-3"
          >
            <p>
              Buổi {s.session_no} · {shortDate(s.session_date)}
            </p>
            <p className="tabular font-semibold">
              <span className="sr-only">Thái độ </span>
              {formatScore(s.thai_do)}
              <span className="sr-only">, kiến thức </span>
              <span aria-hidden="true"> · </span>
              {formatScore(s.tiep_thu)}
              <span className="sr-only">, vận dụng </span>
              <span aria-hidden="true"> · </span>
              {formatScore(s.van_dung)}
            </p>
          </li>
        ))}
      </ul>
    </section>
  );
}
