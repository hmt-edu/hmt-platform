import { Link, type LinkProps } from 'react-router';
import { useFromState } from './crumbTrail';

/** Liên kết mở một trang từ trang đang xem: đường dẫn trên thanh trên nối tiếp trang này (H1). */
export function FromLink(props: Omit<LinkProps, 'state'>) {
  const state = useFromState();
  return <Link {...props} state={state} />;
}
