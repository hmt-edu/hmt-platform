type PortalPlaceholderProps = {
  title: string;
};

export function PortalPlaceholder({ title }: PortalPlaceholderProps) {
  return (
    <section>
      <h1 className="text-2xl font-semibold">{title}</h1>
      <p className="mt-2 text-gray-600">Đang xây dựng.</p>
    </section>
  );
}
