// Thẻ lớp của Kanban LOP-01 (khuôn K04): mã, môn và khối, giáo viên, cơ sở, sĩ số, nhóm, vận hành.
import { Link } from 'react-router';
import { Code } from '../../ui/Data';
import { classPath } from './classConfig';
import { OPERATING_LABEL, type ClassRow } from './classTypes';

export function ClassCard({ row }: { row: ClassRow }) {
  return (
    <div className="flex flex-col gap-1">
      <Code>{row.code}</Code>
      <Link to={classPath(row.id)} className="font-medium text-link hover:underline">
        {row.subject_name ?? row.subject_code} {row.grade_code.replace(/^K0?/, '')}
        {row.level_name ? ` · ${row.level_name}` : ''}
      </Link>
      <span className="text-caption text-fg-muted">
        {[
          row.teacher_names,
          row.branch_code,
          row.max_students > 0 ? `${row.enrolled}/${row.max_students}` : `${row.enrolled} học sinh`,
          row.group_name && `nhóm ${row.group_name}`,
          row.operating_status && OPERATING_LABEL[row.operating_status],
        ]
          .filter(Boolean)
          .join(' · ')}
      </span>
    </div>
  );
}
