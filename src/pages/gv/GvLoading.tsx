// Trạng thái «đang tải» của màn giáo viên theo khung canvas (GV02_tai, GV04_tai, GV06_tai): có sẵn tiêu đề màn, bên dưới là khung xương.
export function GvLoading({ title, lines = 3 }: { title: string; lines?: number }) {
  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-3 p-4">
      <h1 className="text-h3">{title}</h1>
      <div role="status" aria-label="Đang tải" className="flex flex-col gap-2">
        {Array.from({ length: lines }, (_, i) => (
          <div key={i} className="h-16 animate-pulse rounded-control bg-surface-subtle" />
        ))}
      </div>
    </div>
  );
}
