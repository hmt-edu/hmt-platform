// Khuôn K1, K2 khi dữ liệu do máy chủ tính: tổng và thanh màu từ máy chủ, nhóm tải dòng khi mở, dòng "Đã gộp" mờ.
import { fireEvent, render, screen, within } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { Table, type TableGroup } from '../ui/Data';
import { KanbanBoard } from './Kanban';

type Card = { id: string; name: string };
const SEGMENTS = [
  { key: 'ok', label: 'Sắp tới', tone: 'success' as const },
  { key: 'none', label: 'Chưa có lịch', tone: 'neutral' as const },
];

function board(
  counts: Record<string, Record<string, number>>,
  extra: Partial<Parameters<typeof KanbanBoard<Card>>[0]> = {},
) {
  return (
    <KanbanBoard<Card>
      columns={[
        { code: 'C1', label: 'C1 Data mới', cards: [{ id: '1', name: 'A' }], total: 7 },
        { code: 'C2', label: 'C2 Chưa liên hệ', cards: [{ id: '2', name: 'B' }] },
      ]}
      cardKey={(c) => c.id}
      cardLabel={(c) => c.name}
      renderCard={(c) => c.name}
      onMove={() => undefined}
      onBlocked={() => undefined}
      bar={{ segments: SEGMENTS, of: () => 'none', counts: (code) => counts[code] }}
      {...extra}
    />
  );
}

describe('Kanban với số liệu từ máy chủ', () => {
  it('đầu cột hiện tổng của máy chủ (không phải số thẻ đã tải); cột không có tổng lấy số thẻ', () => {
    render(board({}));
    const c1 = screen.getByRole('region', { name: 'C1 Data mới: 7 thẻ' });
    expect(within(c1).getByText('7')).toBeTruthy();
    expect(screen.getByRole('region', { name: 'C2 Chưa liên hệ: 1 thẻ' })).toBeTruthy();
  });

  it('thanh màu dùng số đếm của máy chủ trên cả cột', () => {
    render(board({ C1: { ok: 5, none: 2 } }));
    expect(screen.getByRole('button', { name: 'Sắp tới: 5 thẻ' })).toBeTruthy();
  });

  it('cột chỉ có khúc xám (chưa có lịch hẹn nào) thì không vẽ thanh (P0 v5, số 12)', () => {
    render(board({ C1: { ok: 0, none: 7 }, C2: { ok: 1, none: 0 } }));
    expect(screen.queryByRole('group', { name: 'Tỷ lệ thẻ của C1 Data mới' })).toBeNull();
    expect(screen.getByRole('group', { name: 'Tỷ lệ thẻ của C2 Chưa liên hệ' })).toBeTruthy();
  });

  it('lọc theo khúc do màn quản lý: bấm khúc gọi onBarSelect, khúc đang chọn có aria-pressed', () => {
    const onBarSelect = vi.fn();
    render(board({ C1: { ok: 5, none: 2 } }, { barActive: ['ok'], onBarSelect }));
    const segment = screen.getByRole('button', { name: /^Sắp tới: 5 thẻ/ });
    expect(segment.getAttribute('aria-pressed')).toBe('true');
    fireEvent.click(segment);
    expect(onBarSelect).toHaveBeenCalledWith('ok');
  });

  it('cột còn thẻ chưa tải có nút "Xem thêm" nêu số còn lại; "+" chỉ ở cột được phép', () => {
    const onLoadMore = vi.fn();
    render(board({}, { onLoadMore, onAdd: () => undefined, showAdd: (code) => code === 'C1' }));
    fireEvent.click(screen.getByRole('button', { name: 'Xem thêm (còn 6)' }));
    expect(onLoadMore).toHaveBeenCalledWith('C1');
    expect(screen.getByRole('button', { name: 'Thêm vào C1 Data mới' })).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Thêm vào C2 Chưa liên hệ' })).toBeNull();
  });
});

type Row = { id: string; name: string; merged?: boolean };
const COLUMNS = [{ key: 'name', header: 'Tên', cell: (r: Row) => r.name }];

function table(groups: TableGroup<Row>[], extra: Partial<Parameters<typeof Table<Row>>[0]> = {}) {
  return (
    <Table<Row>
      caption="Lead"
      columns={COLUMNS}
      rows={[]}
      rowKey={(r) => r.id}
      rowLabel={(r) => r.name}
      empty={<p>Trống</p>}
      groups={groups}
      groupsDefaultOpen={false}
      {...extra}
    />
  );
}

describe('Bảng với nhóm tải dòng khi mở (Group By ở máy chủ)', () => {
  const leaf = (patch: Partial<TableGroup<Row>> = {}): TableGroup<Row> => ({
    key: 'g1',
    label: 'C1 Data mới',
    count: 3,
    children: [],
    rows: [],
    ...patch,
  });

  it('mặc định các nhóm đóng; mở nhóm thì báo để tải dòng, đóng lại cũng báo', () => {
    const onGroupToggle = vi.fn();
    render(table([leaf({ rows: [{ id: '1', name: 'Chị Hằng' }] })], { onGroupToggle }));
    expect(screen.queryByText('Chị Hằng')).toBeNull();
    const toggle = screen.getByRole('button', { name: /C1 Data mới/ });
    fireEvent.click(toggle);
    expect(onGroupToggle).toHaveBeenLastCalledWith('g1', true);
    expect(screen.getByText('Chị Hằng')).toBeTruthy();
    fireEvent.click(toggle);
    expect(onGroupToggle).toHaveBeenLastCalledWith('g1', false);
  });

  it('nhóm có số đếm nhưng chưa có dòng không bị coi là rỗng; đang tải thì hiện khung chờ', () => {
    render(table([leaf({ loading: true })]));
    expect(screen.queryByText('Trống')).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: /C1 Data mới/ }));
    expect(
      document.querySelector('[aria-hidden="true"].animate-pulse, .animate-pulse'),
    ).not.toBeNull();
  });

  it('cuối nhóm còn dòng chưa tải có nút "Xem thêm (còn n)"', () => {
    const onMore = vi.fn();
    render(
      table([
        leaf({
          rows: [{ id: '1', name: 'Chị Hằng' }],
          more: { remaining: 2, loading: false, onMore },
        }),
      ]),
    );
    fireEvent.click(screen.getByRole('button', { name: /C1 Data mới/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Xem thêm (còn 2)' }));
    expect(onMore).toHaveBeenCalled();
  });

  it('không có nhóm nào thì hiện trạng thái rỗng', () => {
    render(table([]));
    expect(screen.getByText('Trống')).toBeTruthy();
  });

  it('dòng "Đã gộp" mờ (rowMuted)', () => {
    render(
      table([], {
        groups: undefined,
        rows: [
          { id: '1', name: 'Còn dùng' },
          { id: '2', name: 'Bản đã gộp', merged: true },
        ],
        rowMuted: (r) => r.merged === true,
      }),
    );
    expect(screen.getByText('Bản đã gộp').closest('tr')?.className).toContain('opacity-55');
    expect(screen.getByText('Còn dùng').closest('tr')?.className).not.toContain('opacity-55');
  });
});
