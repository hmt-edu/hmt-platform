// Dựng khối markdown của trang Hướng dẫn thành giao diện (A-23-30). Mọi chữ đưa ra dạng văn bản, không chèn HTML thô.
import { useState, type ReactNode } from 'react';
import { Link } from 'react-router';
import type { Block, Inline, ListItem } from './markdown';

/** Ảnh hoặc video nhúng từ public/huong-dan/. Chưa có file thì ẨN (không hiện chữ kỹ thuật cho người dùng) và báo lên để ẩn cả dòng «Ảnh:». */
function Media({
  kind,
  name,
  onMissing,
}: {
  kind: 'image' | 'video';
  name: string;
  onMissing: () => void;
}) {
  const [missing, setMissing] = useState(false);
  if (missing) return null;
  const fail = () => {
    setMissing(true);
    onMissing();
  };
  if (kind === 'image') {
    return (
      <img
        src={`/huong-dan/anh/${name}.png`}
        alt={name.replace(/-/g, ' ')}
        loading="lazy"
        className="my-2 block max-w-full rounded-control border border-border"
        onError={fail}
      />
    );
  }
  return (
    <video
      src={`/huong-dan/video/${name}.mp4`}
      controls
      preload="none"
      aria-label={name.replace(/-/g, ' ')}
      className="my-2 block max-w-full rounded-control border border-border"
      onError={fail}
    />
  );
}

const isMedia = (it: Inline) => it.kind === 'image' || it.kind === 'video';
/** Chữ nối giữa các ảnh («, ») và nhãn «Ảnh:»: ẩn cùng ảnh khi không có ảnh nào. */
const isAlbumGlue = (it: Inline) =>
  (it.kind === 'bold' && /^(Ảnh|Video):?$/.test(it.text.trim())) ||
  (it.kind === 'text' && /^[\s,.;:]*$/.test(it.text));

function Inlines({
  inline,
  allGone,
  onMissing,
}: {
  inline: Inline[];
  allGone: boolean;
  onMissing: () => void;
}) {
  return (
    <>
      {inline.map((it, idx) => {
        const key = `${it.kind}-${idx}`;
        if (allGone && isAlbumGlue(it)) return null;
        switch (it.kind) {
          case 'text':
            return <span key={key}>{it.text}</span>;
          case 'bold':
            return (
              <strong key={key} className="font-semibold">
                {it.text}
              </strong>
            );
          case 'code':
            return (
              <code key={key} className="rounded-control bg-surface-subtle px-1 text-caption">
                {it.text}
              </code>
            );
          case 'link':
            return it.href.startsWith('/') ? (
              <Link key={key} to={it.href} className="text-accent underline focus-ring">
                {it.text}
              </Link>
            ) : (
              <a
                key={key}
                href={it.href}
                target="_blank"
                rel="noreferrer noopener"
                className="text-accent underline focus-ring"
              >
                {it.text}
              </a>
            );
          case 'image':
            return <Media key={key} kind="image" name={it.name} onMissing={onMissing} />;
          case 'video':
            return <Media key={key} kind="video" name={it.name} onMissing={onMissing} />;
        }
      })}
    </>
  );
}

/** Một dòng chữ có thể kèm ảnh; đếm ảnh chưa có để ẩn nhãn «Ảnh:» khi không còn ảnh nào. */
function RichInline({ inline }: { inline: Inline[] }) {
  const [gone, setGone] = useState(0);
  const total = inline.filter(isMedia).length;
  return (
    <Inlines
      inline={inline}
      allGone={total > 0 && gone >= total}
      onMissing={() => setGone((n) => n + 1)}
    />
  );
}

/** Dòng danh sách chỉ gồm nhãn «Ảnh:» và ảnh: ẩn cả dòng khi không có ảnh nào. */
function ListLine({ item, ordered }: { item: ListItem; ordered: boolean }) {
  const [gone, setGone] = useState(0);
  const total = item.inline.filter(isMedia).length;
  const allGone = total > 0 && gone >= total;
  const onlyAlbum =
    total > 0 &&
    item.children.length === 0 &&
    item.inline.every((x) => isMedia(x) || isAlbumGlue(x));
  if (allGone && onlyAlbum) return null;
  return (
    <li>
      <Inlines inline={item.inline} allGone={allGone} onMissing={() => setGone((n) => n + 1)} />
      {item.children.length > 0 && (
        <div className="mt-1">
          <Items items={item.children} ordered={ordered} />
        </div>
      )}
    </li>
  );
}

function Items({
  items,
  ordered,
  start,
}: {
  items: ListItem[];
  ordered: boolean;
  start?: number | undefined;
}) {
  const Tag = ordered ? 'ol' : 'ul';
  return (
    <Tag
      className={`${ordered ? 'list-decimal' : 'list-disc'} space-y-1 pl-6`}
      {...(ordered && start !== undefined && start > 1 ? { start } : {})}
    >
      {items.map((it, idx) => (
        <ListLine key={idx} item={it} ordered={ordered} />
      ))}
    </Tag>
  );
}

const HEADING_TAG = { 1: 'h1', 2: 'h2', 3: 'h3', 4: 'h4' } as const;
const HEADING_CLASS = {
  1: 'text-h1',
  2: 'text-h3',
  3: 'text-h4',
  4: 'text-body font-semibold',
} as const;

export function GuideMarkdown({ blocks }: { blocks: Block[] }): ReactNode {
  return (
    <div className="space-y-3 text-body">
      {blocks.map((b, idx) => {
        switch (b.kind) {
          case 'heading': {
            const Tag = HEADING_TAG[b.level];
            return (
              <Tag key={idx} id={b.id} className={`${HEADING_CLASS[b.level]} scroll-mt-20 pt-2`}>
                <RichInline inline={b.inline} />
              </Tag>
            );
          }
          case 'paragraph':
            return (
              <p key={idx}>
                <RichInline inline={b.inline} />
              </p>
            );
          case 'list':
            return <Items key={idx} items={b.items} ordered={b.ordered} start={b.start} />;
          case 'table':
            return (
              <div key={idx} className="overflow-x-auto">
                <table className="w-full border-collapse text-left text-body">
                  <thead>
                    <tr>
                      {b.header.map((h, c) => (
                        <th
                          key={c}
                          scope="col"
                          className="border-b border-border px-2 py-1.5 font-semibold"
                        >
                          <RichInline inline={h} />
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {b.rows.map((r, ri) => (
                      <tr key={ri} className="align-top">
                        {r.map((cell, c) => (
                          <td key={c} className="border-b border-surface-subtle px-2 py-1.5">
                            <RichInline inline={cell} />
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            );
          case 'code':
            return (
              <pre
                key={idx}
                // Khối cuộn ngang được: phải focus được bằng bàn phím (axe: scrollable-region-focusable).
                tabIndex={0}
                role="region"
                aria-label="Sơ đồ hoặc khối chữ cố định"
                className="overflow-x-auto rounded-control bg-surface-subtle p-3 text-caption"
              >
                {b.text}
              </pre>
            );
          case 'quote':
            return (
              <blockquote key={idx} className="border-l-2 border-border pl-3 text-fg-muted">
                <RichInline inline={b.inline} />
              </blockquote>
            );
          case 'rule':
            return <hr key={idx} className="border-border" />;
        }
      })}
    </div>
  );
}
