import { formatDateTime } from '../lib/datetime';
import { currentRawEnv, getAppEnvLabel } from '../lib/env';
import { useSystemStatus, type SystemStatus } from '../lib/systemStatus';

function StatusBody({ status }: { status: SystemStatus }) {
  switch (status.state) {
    case 'not-configured':
      return (
        <>
          <p className="font-medium text-gray-900">Chưa cấu hình</p>
          <p className="mt-1 text-sm text-gray-600">{status.detail}</p>
        </>
      );
    case 'loading':
      return <p className="text-gray-600">Đang kiểm tra…</p>;
    case 'connected':
      return (
        <>
          <p className="font-medium text-gray-900">Đã kết nối</p>
          <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
            <dt className="text-gray-500">Ứng dụng</dt>
            <dd>{status.info.appName}</dd>
            <dt className="text-gray-500">Phiên bản schema</dt>
            <dd>{status.info.schemaVersion}</dd>
            <dt className="text-gray-500">Giờ máy chủ</dt>
            <dd>{formatDateTime(status.info.dbTime)}</dd>
          </dl>
        </>
      );
    case 'error':
      return (
        <>
          <p className="font-medium text-gray-900">Không kết nối được</p>
          <p className="mt-1 text-sm break-words text-gray-600">{status.message}</p>
        </>
      );
  }
}

export function HomePage() {
  const envLabel = getAppEnvLabel(currentRawEnv().VITE_APP_ENV);
  const status = useSystemStatus();

  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-semibold">HMT Platform</h1>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <h2 className="text-sm text-gray-500">Môi trường</h2>
          <p className="mt-1 text-lg font-medium" data-testid="env-label">
            {envLabel}
          </p>
        </div>
        <div
          className="rounded-lg border border-gray-200 bg-white p-4"
          data-testid="db-status"
          aria-live="polite"
        >
          <h2 className="text-sm text-gray-500">Cơ sở dữ liệu</h2>
          <div className="mt-1">
            <StatusBody status={status} />
          </div>
        </div>
      </div>
    </section>
  );
}
