import { fireEvent, render, screen } from '@testing-library/react';
import { Link, MemoryRouter } from 'react-router';
import { beforeEach, describe, expect, it } from 'vitest';
import { CRM_MENU } from '../nav/crmMenu';
import { CrmMenuGroup } from './CrmMenuGroup';

const quanTri = CRM_MENU.find((g) => g.id === 'quan-tri');
if (!quanTri) throw new Error('Không thấy nhóm Quản trị');

const open = (path: string) =>
  render(
    <MemoryRouter initialEntries={[path]}>
      <Link to="/crm/quan-tri/co-so">sang-co-so</Link>
      <ul>
        <CrmMenuGroup group={quanTri} />
      </ul>
    </MemoryRouter>,
  );
const button = (name: RegExp) => screen.getByRole('button', { name });
const link = (name: string) => screen.queryByRole('link', { name });

describe('menu CRM đóng/mở', () => {
  beforeEach(() => localStorage.clear());

  it('chỉ nhóm con chứa màn đang xem được mở; nhóm một mục hiện thẳng', () => {
    open('/crm/quan-tri/nguoi-dung');
    expect(button(/^Tài khoản/).getAttribute('aria-expanded')).toBe('true');
    expect(button(/^Hệ thống/).getAttribute('aria-expanded')).toBe('false');
    expect(link('Danh mục')).toBeNull();
    expect(link('Nhật ký')).not.toBeNull();
    expect(screen.queryByRole('button', { name: /^Nhật ký/ })).toBeNull();
  });

  it('nhóm đang chứa màn hiện tại đóng được; sang màn khác thì tự mở lại', () => {
    open('/crm/quan-tri/nguoi-dung');
    fireEvent.click(button(/^Quản trị/));
    expect(button(/^Quản trị/).getAttribute('aria-expanded')).toBe('false');
    expect(button(/^Quản trị/).getAttribute('aria-current')).toBe('true');
    expect(link('Người dùng')).toBeNull();

    fireEvent.click(screen.getByRole('link', { name: 'sang-co-so' }));
    expect(button(/^Quản trị/).getAttribute('aria-expanded')).toBe('true');
    expect(button(/^Hệ thống/).getAttribute('aria-expanded')).toBe('true');
    expect(button(/^Tài khoản/).getAttribute('aria-expanded')).toBe('false');
  });

  it('nhóm con mở tay thì lần sau vẫn mở', () => {
    const first = open('/crm/quan-tri/nguoi-dung');
    fireEvent.click(button(/^Quyền/));
    first.unmount();
    open('/crm/quan-tri/nguoi-dung');
    expect(button(/^Quyền/).getAttribute('aria-expanded')).toBe('true');
  });
});
