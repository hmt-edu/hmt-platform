import { Link } from 'react-router';

export function NotFoundPage() {
  return (
    <section>
      <h1 className="text-2xl font-semibold">Không tìm thấy trang</h1>
      <p className="mt-2 text-gray-600">Địa chỉ này không tồn tại hoặc đã được chuyển đi.</p>
      <Link to="/" className="mt-4 inline-block text-gray-900 underline">
        Về trang chủ
      </Link>
    </section>
  );
}
