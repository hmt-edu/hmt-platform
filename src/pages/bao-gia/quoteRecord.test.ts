import { describe, expect, it } from 'vitest';
import { discountText, quantityText, statusSteps } from './quoteRecord';
import type { QuotationLine } from './quoteTypes';

const line = (over: Partial<QuotationLine>): QuotationLine => ({
  id: 'l',
  line_no: 1,
  line_kind: 'ENROL',
  prospect_student_id: null,
  package_id: 'p',
  package_code: 'LC-TOAN-K09',
  package_name: 'Toán 9',
  package_type_code: 'LC',
  delivery_mode_code: 'OFF',
  unit_code: 'GIO',
  quantity: 24,
  gifted_quantity: 0,
  unit_price: 220000,
  gross_amount: 5280000,
  discount_percent: 0,
  gift_percent: 0,
  discount_amount: 0,
  line_total: 5280000,
  over_cap: false,
  needs_acknowledgement: false,
  student_name: null,
  student_birth_year: null,
  student_code: null,
  student_complete: true,
  gift_policy_name: null,
  order_id: null,
  order_code: null,
  order_status_code: null,
  discounts: [],
  ...over,
});

describe('bản ghi Báo giá (BH-02)', () => {
  it('các bước tình trạng: luồng thường, Từ chối, Huỷ', () => {
    expect(statusSteps({ status_code: 'NHAP' })).toEqual(['NHAP', 'DA_GUI', 'DA_CHUYEN_DON']);
    expect(statusSteps({ status_code: 'DA_GUI' })).toEqual(['NHAP', 'DA_GUI', 'DA_CHUYEN_DON']);
    expect(statusSteps({ status_code: 'TU_CHOI' })).toEqual(['NHAP', 'DA_GUI', 'TU_CHOI']);
    expect(statusSteps({ status_code: 'HUY' })).toEqual(['NHAP', 'HUY']);
  });
  it('chữ chiết khấu', () => {
    expect(discountText(line({}))).toBe('');
    expect(discountText(line({ discount_percent: 10 }))).toBe('10%');
    expect(discountText(line({ discount_percent: 3.33 }))).toBe('3,33%');
    expect(discountText(line({ discount_percent: 5, gifted_quantity: 4 }))).toBe('5% + tặng 4 giờ');
    expect(discountText(line({ line_kind: 'GIFT', gift_policy_name: 'Tặng tài liệu' }))).toBe(
      'Tặng tài liệu',
    );
  });
  it('số lượng kèm đơn vị theo loại gói', () => {
    expect(quantityText({ quantity: 24, unit_code: 'GIO' })).toBe('24 giờ');
    expect(quantityText({ quantity: 0.5, unit_code: 'GIO' })).toBe('0,5 giờ');
    expect(quantityText({ quantity: 3, unit_code: 'THANG' })).toBe('3 tháng');
    expect(quantityText({ quantity: 1, unit_code: 'BO' })).toBe('1 bộ');
  });
});
