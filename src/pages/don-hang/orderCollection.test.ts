import { describe, expect, it } from 'vitest';
import { orderCollection } from './orderCollection';

describe('Đơn hàng: cột Đã thu, Còn phải thu, Thu tiền (BH06)', () => {
  it('đơn chưa Đã duyệt thì «—»', () => {
    expect(orderCollection('NHAP', 1000, 0)).toEqual({ receivable: null, label: null });
    expect(orderCollection('DA_TRINH', 1000, 0)).toEqual({ receivable: null, label: null });
    expect(orderCollection('HUY', 1000, 0)).toEqual({ receivable: null, label: null });
  });
  it('đơn Đã duyệt chưa thu', () => {
    expect(orderCollection('DA_DUYET', 1000, 0)).toEqual({ receivable: 1000, label: 'Chưa thu' });
  });
  it('thu một phần', () => {
    expect(orderCollection('DA_DUYET', 1000, 400)).toEqual({
      receivable: 600,
      label: 'Thu một phần',
    });
  });
  it('thu đủ, kể cả thu dư không âm', () => {
    expect(orderCollection('DA_DUYET', 1000, 1000)).toEqual({ receivable: 0, label: 'Đã thu đủ' });
    expect(orderCollection('DA_DUYET', 1000, 1200)).toEqual({ receivable: 0, label: 'Đã thu đủ' });
  });
});
