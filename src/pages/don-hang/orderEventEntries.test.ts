import { describe, expect, it } from 'vitest';
import { editedNoteText, noteLines, orderEventEntries, reasonLine } from './orderEventEntries';
import type { OrderEvent } from './orderTypes';

const ev = (
  seq: number,
  code: OrderEvent['event_code'],
  extra: Partial<OrderEvent> = {},
): OrderEvent => ({
  seq,
  event_code: code,
  from_status: null,
  to_status: null,
  reason_code: null,
  note: null,
  on_behalf: false,
  created_at: `2026-11-07T0${seq}:00:00Z`,
  actor_name: 'Giả sales1',
  total_amount: null,
  ...extra,
});
const name = (catalog: string, code: string | null | undefined) =>
  catalog === 'REJECT_REASON' && code === 'THIEU_THONG_TIN' ? 'Thiếu thông tin' : undefined;

describe('mục dòng thời gian của đơn (Q-48, Q-51)', () => {
  it('Tạo và Duyệt hiện tổng tiền; Trình không có tổng', () => {
    const entries = orderEventEntries(
      [
        ev(1, 'TAO', { total_amount: 12_000_000 }),
        ev(2, 'TRINH'),
        ev(3, 'DUYET', { total_amount: 12_000_000 }),
      ],
      name,
    );
    expect(entries.map((e) => (e.kind === 'event' ? e.title : ''))).toEqual([
      'Tạo đơn hàng',
      'Trình duyệt',
      'Duyệt đơn',
    ]);
    expect(entries[0]).toMatchObject({ total: 'Tổng tiền: 12.000.000 đ' });
    expect(entries[2]).toMatchObject({ total: 'Tổng tiền: 12.000.000 đ' });
    expect(entries[1]).not.toHaveProperty('total');
  });

  it('Sửa đơn thẳng: tiêu đề "Sửa đơn", mỗi thay đổi một dòng, tổng tiền cũ → mới từ sự kiện liền trước', () => {
    const entries = orderEventEntries(
      [
        ev(1, 'TAO', { total_amount: 10_000_000 }),
        ev(2, 'SUA', {
          total_amount: 10_500_000,
          note: 'Sửa đơn\ndòng 1 (LC-TOAN-K09): số giờ 48 → 50\nđiều khoản thanh toán A → B',
        }),
      ],
      name,
    );
    expect(entries[1]).toMatchObject({
      title: 'Sửa đơn',
      lines: ['dòng 1 (LC-TOAN-K09): số giờ 48 → 50', 'điều khoản thanh toán A → B'],
      total: 'Tổng tiền: 10.000.000 đ → 10.500.000 đ',
    });
  });

  it('Sửa chỉ điều khoản (tổng không đổi): không có dòng tổng tiền; sự kiện cũ thiếu số: không có dòng tổng', () => {
    const same = orderEventEntries(
      [
        ev(1, 'TAO', { total_amount: 5_000_000 }),
        ev(2, 'SUA', { total_amount: 5_000_000, note: 'Sửa đơn\nđiều khoản thanh toán A → B' }),
      ],
      name,
    );
    expect(same[1]).not.toHaveProperty('total', expect.anything());
    const legacy = orderEventEntries(
      [ev(1, 'TAO'), ev(2, 'SUA', { note: 'Sửa đơn: dòng 1 số giờ 6 → 8' })],
      name,
    );
    expect(legacy[1]).toMatchObject({ title: 'Sửa đơn', lines: ['dòng 1 số giờ 6 → 8'] });
    expect(legacy[1]).not.toHaveProperty('total', expect.anything());
    // Liền trước là sự kiện cũ (chưa có số), sự kiện Sửa có số: chỉ hiện số mới.
    const after = orderEventEntries(
      [
        ev(1, 'TAO'),
        ev(2, 'SUA', { total_amount: 7_000_000, note: 'Sửa đơn\ndòng 1: số giờ 6 → 8' }),
      ],
      name,
    );
    expect(after[1]).toMatchObject({ total: 'Tổng tiền: 7.000.000 đ' });
  });

  it('Đơn từ báo giá: tiêu đề "Sửa đơn (đã sửa so với báo giá BG-xxx)", không chip hay mục riêng', () => {
    const entries = orderEventEntries(
      [
        ev(1, 'SUA', {
          note: 'Đơn đã sửa so với báo giá BG-1\ndòng 1 (LC-TOAN-K09): đơn giá 220.000 → 120.000',
        }),
      ],
      name,
    );
    expect(entries).toHaveLength(1);
    expect(entries[0]).toMatchObject({
      title: 'Sửa đơn (đã sửa so với báo giá BG-1)',
      lines: ['dòng 1 (LC-TOAN-K09): đơn giá 220.000 → 120.000'],
    });
  });

  it('Trình lại chưa sửa: dòng cảnh báo vàng; Từ chối nêu lý do theo danh mục; Duyệt thay người duyệt', () => {
    const entries = orderEventEntries(
      [
        ev(1, 'TRINH', { note: 'Trình lại, chưa sửa từ lần bị từ chối' }),
        ev(2, 'TU_CHOI', { reason_code: 'THIEU_THONG_TIN', note: 'Bổ sung năm sinh' }),
        ev(3, 'DUYET', { on_behalf: true, note: 'Admin duyệt thay' }),
      ],
      name,
    );
    expect(entries[0]).toMatchObject({ warning: 'Trình lại, chưa sửa từ lần bị từ chối' });
    expect(entries[1]).toMatchObject({
      title: 'Từ chối',
      lines: ['Thiếu thông tin: Bổ sung năm sinh'],
    });
    expect(entries[2]).toMatchObject({
      title: 'Duyệt đơn (thay người duyệt)',
      lines: ['Admin duyệt thay'],
    });
  });

  it('noteLines, reasonLine, editedNoteText', () => {
    expect(noteLines(null)).toEqual([]);
    expect(noteLines('a\n\n b ')).toEqual(['a', 'b']);
    expect(
      reasonLine({ event_code: 'HUY', reason_code: 'X', note: null }, () => 'Phụ huynh đổi ý'),
    ).toBe('Phụ huynh đổi ý');
    expect(editedNoteText('Đơn đã sửa so với báo giá BG-1\ndòng 1: số giờ 6 → 8\ndòng 2: bỏ')).toBe(
      'BG-1: dòng 1: số giờ 6 → 8; dòng 2: bỏ',
    );
    expect(editedNoteText('Đơn đã sửa so với báo giá BG-1: dòng 1 số giờ 6 → 8')).toBe(
      'BG-1: dòng 1 số giờ 6 → 8',
    );
  });
});
