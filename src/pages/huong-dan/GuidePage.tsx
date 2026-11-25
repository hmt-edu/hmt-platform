// Hướng dẫn sử dụng (A-23-30): menu trái theo mục, nội dung đọc từ docs/huong-dan/*.md nhúng lúc build, tìm kiếm trong tài liệu.
// Mọi người đã đăng nhập cổng CRM đều xem được; không gọi máy chủ dữ liệu.
import { useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { Link, Navigate, useLocation, useParams } from 'react-router';
import { ButtonLink } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { Icon } from '../../ui/icons';
import { cn } from '../../ui/cn';
import { GuideMarkdown } from './GuideMarkdown';
import {
  defaultSectionFor,
  sectionsFor,
  type GuidePortal,
  GUIDE_GROUPS,
  buildRoleTree,
  childLabel,
  type GuideRoleNode,
  GUIDE_SLUG_ALIASES,
  findSection,
  loadSource,
  roleButtons,
  neighbours,
  searchGuide,
  sectionLabel,
  type GuideSection,
} from './guideIndex';
import { outline, parseMarkdown, plainText, type Block } from './markdown';

const GUIDE_STALE_MS = 3_600_000; // allow-number: giữ tài liệu nhúng trong bộ nhớ một giờ (trình bày), không phải số nghiệp vụ

function useSectionBlocks(section: GuideSection | undefined) {
  const query = useQuery({
    queryKey: ['huong-dan', section?.file],
    enabled: Boolean(section),
    staleTime: GUIDE_STALE_MS,
    queryFn: () => (section ? loadSource(section) : Promise.resolve('')),
  });
  const blocks = useMemo<Block[]>(
    () => (query.data ? parseMarkdown(query.data) : []),
    [query.data],
  );
  return { query, blocks };
}

/** Mỗi dòng chữ kèm tiêu đề gần nhất, để kết quả tìm kiếm trỏ đúng chỗ. */
function searchLines(blocks: Block[]) {
  const lines: { heading: string; headingId: string; text: string }[] = [];
  let heading = '';
  let headingId = '';
  for (const b of blocks) {
    if (b.kind === 'heading') {
      heading = b.text;
      headingId = b.id;
      continue;
    }
    for (const text of plainText([b]).split('\n')) {
      if (text.trim()) lines.push({ heading, headingId, text });
    }
  }
  return lines;
}

function SearchResults({ term, portal }: { term: string; portal: GuidePortal }) {
  const sources = useQuery({
    queryKey: ['huong-dan', 'tat-ca', portal],
    staleTime: GUIDE_STALE_MS,
    queryFn: async () =>
      Promise.all(
        sectionsFor(portal).map(async (section) => ({
          section,
          lines: searchLines(parseMarkdown(await loadSource(section))),
        })),
      ),
  });
  if (sources.isPending) return <Spinner label="Đang tìm…" />;
  if (sources.isError) {
    return (
      <Alert tone="danger">
        Không tải được tài liệu để tìm.{' '}
        <button
          type="button"
          className="underline focus-ring"
          onClick={() => void sources.refetch()}
        >
          Thử lại
        </button>
      </Alert>
    );
  }
  const hits = searchGuide(sources.data, term);
  if (hits.length === 0) {
    return <p className="text-fg-muted">Không thấy mục nào có «{term}». Thử từ khác ngắn hơn.</p>;
  }
  return (
    <ul className="space-y-2" aria-label="Kết quả tìm trong hướng dẫn">
      {hits.map((h, idx) => (
        <li key={idx} className="rounded-card border border-border bg-surface p-3">
          <Link
            to={`/${portal}/huong-dan/${h.section.slug}${h.headingId ? `#${h.headingId}` : ''}`}
            className="font-semibold text-accent underline focus-ring"
          >
            {h.section.title}
            {h.heading ? ` · ${h.heading}` : ''}
          </Link>
          <p className="text-caption text-fg-muted">{h.snippet}</p>
        </li>
      ))}
    </ul>
  );
}

/** Khối «Bạn là ai?» ở đầu hướng dẫn: mỗi vai một nút tới bài của vai đó. */
function WhoAreYou({ portal }: { portal: GuidePortal }) {
  const roles = roleButtons(sectionsFor(portal));
  return (
    <section
      aria-labelledby="ban-la-ai"
      className="mb-4 rounded-card border border-border bg-surface-subtle p-card"
    >
      <h2 id="ban-la-ai" className="text-h3">
        Bạn là ai? Bấm vào vai của bạn
      </h2>
      <ul className="mt-2 flex flex-wrap gap-2">
        {roles.map((r) => (
          <li key={r.label}>
            <ButtonLink to={`/${portal}/huong-dan/${r.section.slug}`} variant="secondary">
              {r.label}
            </ButtonLink>
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Cuối bài: bài trước và bài sau theo đúng thứ tự menu. */
function PrevNext({ slug, portal }: { slug: string; portal: GuidePortal }) {
  const { prev, next } = neighbours(slug, portal);
  if (!prev && !next) return null;
  return (
    <nav
      aria-label="Bài trước và bài sau"
      className="mt-6 flex flex-wrap justify-between gap-2 border-t border-border pt-3"
    >
      {prev ? (
        <Link to={`/${portal}/huong-dan/${prev.slug}`} className="text-accent underline focus-ring">
          ‹ Bài trước: {sectionLabel(prev)}
        </Link>
      ) : (
        <span />
      )}
      {next && (
        <Link to={`/${portal}/huong-dan/${next.slug}`} className="text-accent underline focus-ring">
          Bài sau: {sectionLabel(next)} ›
        </Link>
      )}
    </nav>
  );
}

/** Một vai trên menu: bấm để mở/đóng, mở sẵn khi đang đọc bài của nó. Cùng kiểu nút với menu trái của cổng CRM. */
function ParentMenu({
  node,
  portal,
  currentSlug,
  searching,
  onPick,
}: {
  node: GuideRoleNode;
  portal: GuidePortal;
  currentSlug: string;
  searching: boolean;
  onPick: () => void;
}) {
  const hasActive = !searching && node.children.some((c) => c.slug === currentSlug);
  const [open, setOpen] = useState(hasActive);
  const expanded = open || hasActive;
  const panelId = `huong-dan-vai-${node.key}`;
  return (
    <li>
      <button
        type="button"
        aria-expanded={expanded}
        aria-controls={panelId}
        onClick={() => setOpen(!expanded)}
        className={cn(
          'touch-target focus-ring flex w-full items-center gap-2 rounded-control px-2 py-1.5 text-left text-body font-medium hover:bg-hover',
          expanded && 'bg-hover',
        )}
      >
        <span className="min-w-0 flex-1">{node.title}</span>
        <span className="text-caption text-fg-muted">{node.children.length}</span>
        <Icon name={expanded ? 'chevronDown' : 'chevronRight'} size={16} className="shrink-0" />
      </button>
      {expanded && (
        <ul id={panelId} className="mt-1 space-y-1 border-l border-border pl-2 ml-2">
          {node.children.map((x) => (
            <li key={x.slug}>
              <Link
                to={`/${portal}/huong-dan/${x.slug}`}
                onClick={onPick}
                aria-current={!searching && x.slug === currentSlug ? 'page' : undefined}
                className="touch-target focus-ring flex items-center rounded-control px-2 py-1.5 text-body hover:bg-hover aria-[current=page]:bg-hover aria-[current=page]:font-semibold"
              >
                {childLabel(x)}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </li>
  );
}

export function GuidePage() {
  const { slug } = useParams();
  const location = useLocation();
  const portal: GuidePortal = location.pathname.startsWith('/gv/') ? 'gv' : 'crm';
  const first = defaultSectionFor(portal);
  const [term, setTerm] = useState('');
  const [tocOpen, setTocOpen] = useState(false);
  const found = findSection(slug);
  const section = found && sectionsFor(portal).includes(found) ? found : undefined;
  const { query, blocks } = useSectionBlocks(section);
  const searching = term.trim().length >= 2;

  // Mở đúng chỗ khi vào bằng #mã-neo (từ kết quả tìm hoặc mục lục).
  useEffect(() => {
    if (!location.hash || blocks.length === 0) return;
    document
      .getElementById(decodeURIComponent(location.hash.slice(1)))
      ?.scrollIntoView({ block: 'start' });
  }, [location.hash, blocks]);

  if (slug !== undefined && GUIDE_SLUG_ALIASES[slug] !== undefined)
    return <Navigate to={`/${portal}/huong-dan/${GUIDE_SLUG_ALIASES[slug]}`} replace />;
  if (slug === undefined) return <Navigate to={`/${portal}/huong-dan/${first.slug}`} replace />;
  if (!section) {
    return (
      <StateView
        kind="not-found"
        title="Không có mục hướng dẫn này"
        actions={
          <Link to={`/${portal}/huong-dan/${first.slug}`} className="underline focus-ring">
            Về mục đầu
          </Link>
        }
      />
    );
  }

  const toc = outline(blocks);
  const tree = buildRoleTree(sectionsFor(portal));
  const pick = () => {
    setTerm('');
    setTocOpen(false);
  };
  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-4 lg:flex-row">
      <nav
        aria-label="Mục hướng dẫn"
        className="shrink-0 lg:sticky lg:top-[calc(var(--spacing-topbar)+1rem)] lg:max-h-[calc(100dvh-var(--spacing-topbar)-2rem)] lg:w-64 lg:self-start lg:overflow-y-auto"
      >
        <h1 className="mb-2 text-h1">Hướng dẫn sử dụng</h1>
        <div className="mb-3">
          <TextField
            label="Tìm trong hướng dẫn"
            type="search"
            value={term}
            onChange={(e) => setTerm(e.target.value)}
            placeholder="Ví dụ: xếp lớp, phiếu thu"
          />
        </div>
        <button
          type="button"
          aria-expanded={tocOpen}
          aria-controls="huong-dan-muc-luc"
          onClick={() => setTocOpen(!tocOpen)}
          className="touch-target focus-ring mb-2 flex w-full items-center gap-2 rounded-control border border-border bg-surface px-3 py-2 text-left text-body font-medium lg:hidden"
        >
          <span className="shrink-0">Mục lục</span>
          <span className="min-w-0 flex-1 truncate text-fg-muted">
            {searching ? 'Đang tìm' : sectionLabel(section)}
          </span>
          <Icon name={tocOpen ? 'chevronDown' : 'chevronRight'} size={16} className="shrink-0" />
        </button>
        <div id="huong-dan-muc-luc" className={cn('space-y-3 lg:block', !tocOpen && 'hidden')}>
          {GUIDE_GROUPS.map((g) => (
            <div key={g.key}>
              <p className="px-2 pb-1 text-caption font-semibold uppercase text-fg-muted">
                {g.title}
              </p>
              <ul className="space-y-1">
                {g.key === 'vai'
                  ? tree.map((n) => (
                      <ParentMenu
                        key={n.key}
                        node={n}
                        portal={portal}
                        currentSlug={section.slug}
                        searching={searching}
                        onPick={pick}
                      />
                    ))
                  : sectionsFor(portal)
                      .filter((x) => x.group === g.key)
                      .map((x) => (
                        <li key={x.slug}>
                          <Link
                            to={`/${portal}/huong-dan/${x.slug}`}
                            onClick={pick}
                            aria-current={
                              !searching && x.slug === section.slug ? 'page' : undefined
                            }
                            className="touch-target focus-ring flex items-center rounded-control px-2 py-1.5 text-body hover:bg-hover aria-[current=page]:bg-hover aria-[current=page]:font-semibold"
                          >
                            {sectionLabel(x)}
                          </Link>
                        </li>
                      ))}
              </ul>
            </div>
          ))}
        </div>
      </nav>

      <main
        className="min-w-0 flex-1 rounded-card border border-border bg-surface p-card"
        aria-live="polite"
      >
        {searching ? (
          <SearchResults term={term.trim()} portal={portal} />
        ) : query.isPending ? (
          <Spinner label="Đang tải hướng dẫn…" />
        ) : query.isError ? (
          <Alert tone="danger">
            Không tải được hướng dẫn.{' '}
            <button
              type="button"
              className="underline focus-ring"
              onClick={() => void query.refetch()}
            >
              Thử lại
            </button>
          </Alert>
        ) : (
          <div className="flex flex-col gap-4 xl:flex-row">
            <article className="min-w-0 flex-1">
              {section.slug === first.slug && <WhoAreYou portal={portal} />}
              <GuideMarkdown blocks={blocks} />
              <PrevNext slug={section.slug} portal={portal} />
            </article>
            {toc.length > 0 && (
              <aside
                aria-label="Trong mục này"
                className="shrink-0 text-caption xl:sticky xl:top-[calc(var(--spacing-topbar)+1rem)] xl:max-h-[calc(100dvh-var(--spacing-topbar)-2rem)] xl:w-56 xl:self-start xl:overflow-y-auto"
              >
                <p className="mb-1 font-semibold text-fg-muted">Trong mục này</p>
                <ul className="space-y-1">
                  {toc
                    .filter((t) => t.level === 2)
                    .map((t) => (
                      <li key={t.id}>
                        <Link
                          to={`/${portal}/huong-dan/${section.slug}#${t.id}`}
                          className="focus-ring hover:underline"
                        >
                          {t.text}
                        </Link>
                      </li>
                    ))}
                </ul>
              </aside>
            )}
          </div>
        )}
      </main>
    </div>
  );
}
