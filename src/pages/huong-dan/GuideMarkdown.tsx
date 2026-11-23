// Dựng khối markdown của trang Hướng dẫn thành giao diện (A-23-30). Mọi chữ đưa ra dạng văn bản, không chèn HTML thô.
import { useState, type ReactNode } from 'react';
import { Link } from 'react-router';
import type { Block, Inline, ListItem } from './markdown';

/** Ảnh hoặc video nhúng từ public/huong-dan/. Chưa có file thì hiện ô chú thích «Ảnh sẽ bổ sung» thay vì ảnh vỡ. */
function Media({ kind, name }: { kind: 'image' | 'video'; name: string }) {
  const [missing, setMissing] = useState(false);
  if (missing) {
    return (
      <span className="my-1 block rounded-control border border-dashed border-border px-3 py-2 text-caption text-fg-muted">
        {kind === 'image' ? 'Ảnh' : 'Video'} «{name}» sẽ bổ sung.
      </span>
    );
  }
  if (kind === 'image') {
    return (
      <img
        src={`/huong-dan/anh/${name}.png`}
        alt={name.replace(/-/g, ' ')}
        loading="lazy"
        className="my-2 block max-w-full rounded-control border border-border"
        onError={() => setMissing(true)}
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
      onError={() => setMissing(true)}
    />
  );
}

function Inlines({ inline }: { inline: Inline[] }) {
  return (
    <>
      {inline.map((it, idx) => {
        const key = `${it.kind}-${idx}`;
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
            return <Media key={key} kind="image" name={it.name} />;
          case 'video':
            return <Media key={key} kind="video" name={it.name} />;
        }
      })}
    </>
  );
}

function Items({ items, ordered }: { items: ListItem[]; ordered: boolean }) {
  const Tag = ordered ? 'ol' : 'ul';
  return (
    <Tag className={`${ordered ? 'list-decimal' : 'list-disc'} space-y-1 pl-6`}>
      {items.map((it, idx) => (
        <li key={idx}>
          <Inlines inline={it.inline} />
          {it.children.length > 0 && (
            <div className="mt-1">
              <Items items={it.children} ordered={ordered} />
            </div>
          )}
        </li>
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
                <Inlines inline={b.inline} />
              </Tag>
            );
          }
          case 'paragraph':
            return (
              <p key={idx}>
                <Inlines inline={b.inline} />
              </p>
            );
          case 'list':
            return <Items key={idx} items={b.items} ordered={b.ordered} />;
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
                          <Inlines inline={h} />
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {b.rows.map((r, ri) => (
                      <tr key={ri} className="align-top">
                        {r.map((cell, c) => (
                          <td key={c} className="border-b border-surface-subtle px-2 py-1.5">
                            <Inlines inline={cell} />
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
                className="overflow-x-auto rounded-control bg-surface-subtle p-3 text-caption"
              >
                {b.text}
              </pre>
            );
          case 'quote':
            return (
              <blockquote key={idx} className="border-l-2 border-border pl-3 text-fg-muted">
                <Inlines inline={b.inline} />
              </blockquote>
            );
          case 'rule':
            return <hr key={idx} className="border-border" />;
        }
      })}
    </div>
  );
}
