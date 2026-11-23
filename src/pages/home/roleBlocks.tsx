// Các khối việc theo vai trò của Trang chủ CRM (CHUNG-14, K09): mỗi khối là một hàm đọc có sẵn của màn nguồn, lấy số tổng và vài dòng đầu
// (đọc theo quyền và phạm vi cơ sở của người xem), kèm «Xem tất cả» mở màn nguồn. Không tính nghiệp vụ ở giao diện.
import { useQuery } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { useDb } from '../../lib/db';
import { ALL_BRANCHES } from '../../nav/access';
import { useAccess } from '../../nav/AccessContext';
import { Button, ButtonLink } from '../../ui/Button';
import { Skeleton } from '../../ui/Data';
import { StateView } from '../../ui/Feedback';
import { ROLE_BLOCK_SPECS, type RoleBlockId, type Spec } from './roleBlockSpecs';

/** Một khối việc: tiêu đề + số tổng + vài dòng đầu + «Xem tất cả»; có trạng thái tải, rỗng, lỗi và Thử lại. */
export function RoleBlock({ id }: { id: RoleBlockId }) {
  const spec: Spec = ROLE_BLOCK_SPECS[id];
  const supabase = useDb();
  const access = useAccess();
  // Admin, Kế toán chọn cơ sở ở thanh trên thì số liệu theo cơ sở đó; người một cơ sở do RLS quyết.
  const branch =
    access.seesAllBranches && access.selectedBranch !== ALL_BRANCHES
      ? { branch_id: access.selectedBranch }
      : {};
  const query = useQuery({
    queryKey: ['home-role-block', id, branch],
    queryFn: () => spec.load(supabase, branch, access.seesAllBranches),
  });

  let body: ReactNode;
  if (query.isPending) {
    body = <Skeleton className="h-40 w-full" />;
  } else if (query.isError) {
    body = (
      <StateView
        kind="error"
        title="Không tải được khối này"
        headingLevel={2}
        actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
      >
        Kiểm tra kết nối rồi thử lại.
      </StateView>
    );
  } else if (query.data.lines.length === 0) {
    body = <p className="py-4 text-fg-muted">{spec.empty}</p>;
  } else {
    body = (
      <ul className="flex flex-col divide-y divide-border">
        {query.data.lines.map((line) => (
          <li key={line.key} className="flex flex-col py-2.5">
            <span
              className={
                line.tone === 'danger' ? 'truncate font-medium text-danger' : 'truncate font-medium'
              }
            >
              {line.title}
            </span>
            <span className="truncate text-caption text-fg-muted">{line.sub}</span>
          </li>
        ))}
      </ul>
    );
  }

  return (
    <section
      aria-labelledby={`home-${id}`}
      className="flex flex-col gap-3 rounded-card border border-border bg-surface p-4"
    >
      <div className="flex items-center justify-between gap-2">
        <h2 id={`home-${id}`} className="text-h4">
          {spec.title}
        </h2>
        {query.data && (
          <span className="tabular rounded-full bg-brand-50 px-2 text-caption font-semibold text-brand-800">
            {query.data.total}
          </span>
        )}
      </div>
      {body}
      <div className="flex flex-col items-start gap-2">
        <ButtonLink to={spec.to}>Xem tất cả</ButtonLink>
      </div>
    </section>
  );
}
