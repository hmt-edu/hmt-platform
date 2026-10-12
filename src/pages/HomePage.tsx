import { formatDateTime } from '../lib/datetime';
import { currentRawEnv, getAppEnvLabel } from '../lib/env';
import { useSystemStatus, type SystemStatus } from '../lib/systemStatus';

function StatusBody({ status }: { status: SystemStatus }) {
  switch (status.state) {
    case 'not-configured':
      return (
        <>
          <p className="font-medium text-fg">Chưa cấu hình</p>
          <p className="mt-1 text-body text-fg-muted">{status.detail}</p>
        </>
      );
    case 'loading':
      return <p className="text-fg-muted">Đang kiểm tra…</p>;
    case 'connected':
      return (
        <>
          <p className="font-medium text-fg">Đã kết nối</p>
          <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-body">
            <dt className="text-fg-muted">Ứng dụng</dt>
            <dd>{status.info.appName}</dd>
            <dt className="text-fg-muted">Phiên bản schema</dt>
            <dd>{status.info.schemaVersion}</dd>
            <dt className="text-fg-muted">Giờ máy chủ</dt>
            <dd>{formatDateTime(status.info.dbTime)}</dd>
          </dl>
        </>
      );
    case 'error':
      return (
        <>
          <p className="font-medium text-fg">Không kết nối được</p>
          <p className="mt-1 text-body break-words text-fg-muted">{status.message}</p>
        </>
      );
  }
}

export function HomePage() {
  const envLabel = getAppEnvLabel(currentRawEnv().VITE_APP_ENV);
  const status = useSystemStatus();

  return (
    <section className="mx-auto max-w-3xl space-y-4 p-4">
      <h1 className="text-h1">HMT Platform</h1>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-card border border-border bg-surface p-card">
          <h2 className="text-body text-fg-muted">Môi trường</h2>
          <p className="mt-1 text-h3" data-testid="env-label">
            {envLabel}
          </p>
        </div>
        <div
          className="rounded-card border border-border bg-surface p-card"
          data-testid="db-status"
          aria-live="polite"
        >
          <h2 className="text-body text-fg-muted">Cơ sở dữ liệu</h2>
          <div className="mt-1">
            <StatusBody status={status} />
          </div>
        </div>
      </div>
    </section>
  );
}
