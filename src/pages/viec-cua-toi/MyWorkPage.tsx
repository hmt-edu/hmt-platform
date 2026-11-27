// «Việc của tôi» (canvas 1bcc VC01, VC02, VC07*): việc còn phải làm của người đăng nhập, ba nhóm theo độ gấp, gom thẻ theo phụ huynh.
// Một lần gọi app.list_my_work, phân trang theo thẻ ở máy chủ. Việc gốc xong thì dòng tự mất; không có nút hoàn thành riêng.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { ALL_BRANCHES } from '../../nav/access';
import { useAccess } from '../../nav/AccessContext';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { Button, ButtonLink } from '../../ui/Button';
import { Pagination, Skeleton, Tag } from '../../ui/Data';
import { Avatar, StateView } from '../../ui/Feedback';
import { PageFrame, PageHeader } from '../../ui/PageHeader';
import { URGENCY_GROUPS, cardTag, cardTitle, dueText, itemLink } from './workLogic';
import type { WorkCard, WorkPage } from './workTypes';

function Card({ card, now }: { card: WorkCard; now: Date }) {
  const title = cardTitle(card);
  const tag = cardTag(card, now);
  return (
    <li className="rounded-card border border-border bg-surface">
      <div className="flex flex-wrap items-center gap-2 border-b border-border px-4 py-3">
        {card.parent_name ? <Avatar name={card.parent_name} large /> : null}
        <div className="min-w-0 flex-1">
          <h3 className="font-semibold">{title}</h3>
          <p className="tabular text-caption text-fg-muted">
            {card.phone && card.phone !== title ? (
              <>
                <a className="underline" href={`tel:${card.phone}`}>
                  {card.phone}
                </a>
                {' · '}
              </>
            ) : null}
            {card.items.length} việc
          </p>
        </div>
        <Tag tone={tag.tone} dot>
          {tag.label}
        </Tag>
      </div>
      <ul className="divide-y divide-border">
        {card.items.map((item) => {
          const link = itemLink(item);
          const due = dueText(item, now);
          return (
            <li
              key={`${item.signal}:${item.entity_id}`}
              className="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-3"
            >
              <div className="min-w-0 flex-1 basis-60">
                <p className="font-medium">{item.title}</p>
                <p className="text-caption text-fg-muted">
                  {item.why}
                  {due ? ` · ${due}` : ''}
                </p>
              </div>
              <ButtonLink to={link.to} size="sm">
                {link.label}
              </ButtonLink>
            </li>
          );
        })}
      </ul>
    </li>
  );
}

export function MyWorkPage() {
  const access = useAccess();
  const supabase = useDb();
  const pageSize = useIntSetting('list_page_size_default');
  const branchId =
    access.seesAllBranches && access.selectedBranch !== ALL_BRANCHES ? access.selectedBranch : null;
  const [paging, setPaging] = useState({ key: '', page: 1 });
  const pagingKey = branchId ?? '';
  const page = paging.key === pagingKey ? paging.page : 1;

  const query = useQuery({
    queryKey: ['my-work', branchId, page, pageSize],
    enabled: pageSize !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<WorkPage>(supabase, 'list_my_work', {
        p_filters: branchId ? { branch_id: branchId } : {},
        p_limit: pageSize,
        p_offset: (page - 1) * (pageSize ?? 0),
      }),
  });
  const data = query.data;
  const now = new Date(query.dataUpdatedAt);

  return (
    <PageFrame>
      <PageHeader
        title="Việc của tôi"
        description="Hệ thống tự gom từ dữ liệu. Việc gốc xong thì dòng tự mất, không cần bấm hoàn thành riêng."
      />
      {query.isError ? (
        <StateView
          kind="error"
          headingLevel={2}
          title="Chưa tải được danh sách việc."
          actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
        >
          {errorOf(query.error).message}
        </StateView>
      ) : (
        <>
          <dl className="grid grid-cols-3 gap-3">
            {URGENCY_GROUPS.map((g) => (
              <div
                key={g.urgency}
                className="rounded-card border border-border bg-surface px-4 py-3"
              >
                <dt className="text-caption font-semibold text-fg-muted">{g.label}</dt>
                <dd className="tabular font-display text-h2">
                  {data ? data.counts[g.count] : '–'}
                </dd>
              </div>
            ))}
          </dl>
          {!data ? (
            <div role="status" aria-label="Đang tải" className="flex flex-col gap-3">
              <Skeleton className="h-24" />
              <Skeleton className="h-24" />
            </div>
          ) : data.total_cards === 0 ? (
            <StateView kind="empty" headingLevel={2} title="Chưa có việc nào cần làm">
              Khi có lịch hẹn, phiếu Test, buổi học hay việc chờ duyệt cần xử lý, việc sẽ tự hiện ở
              đây.
            </StateView>
          ) : (
            <>
              {URGENCY_GROUPS.map((g) => {
                const cards = data.cards.filter((c) => c.urgency === g.urgency);
                // Nhóm còn việc nhưng nằm ở trang khác thì không hiện nhóm đó ở trang này.
                if (cards.length === 0 && data.counts[g.count] > 0) return null;
                return (
                  <section key={g.urgency} aria-label={g.label} className="flex flex-col gap-3">
                    <h2 className="flex items-center gap-2 text-h4">
                      {g.label}
                      <Tag tone={g.tone}>{data.counts[g.count]}</Tag>
                    </h2>
                    {cards.length === 0 ? (
                      <p className="text-fg-muted">{g.empty}</p>
                    ) : (
                      <ul className="flex flex-col gap-3">
                        {cards.map((card) => (
                          <Card key={card.group_key} card={card} now={now} />
                        ))}
                      </ul>
                    )}
                  </section>
                );
              })}
              {pageSize !== null && data.total_cards > pageSize ? (
                <Pagination
                  page={page}
                  pageSize={pageSize}
                  total={data.total_cards}
                  onPageChange={(next) => setPaging({ key: pagingKey, page: next })}
                />
              ) : null}
            </>
          )}
        </>
      )}
    </PageFrame>
  );
}
