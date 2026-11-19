// CH-04: tình trạng theo ngày, kiểm biểu mẫu (câu theo khung CH04_loi), mã chính sách, tóm tắt lỗi.
import { describe, expect, it } from 'vitest';
import {
  appliesToLabel,
  discountAppliedLabel,
  branchesLabel,
  errorSummary,
  formErrors,
  policyCode,
  statusOf,
  todayVn,
  type FormValues,
} from './policyLogic';

const base: FormValues = {
  name: 'Đóng cả năm',
  kind: 'PERCENT',
  maxValue: '10',
  fixedValue: false,
  requiresApproval: false,
  validFrom: new Date(2026, 8, 1),
  validTo: new Date(2027, 7, 31),
  packageTypes: ['LC'],
  branchIds: [],
  appliesTo: ['BAO_GIA', 'DON', 'PHIEU_THU'],
};

describe('CH-04 tình trạng', () => {
  const p = { is_active: true, valid_from: '2026-09-01', valid_to: '2026-12-31' as string | null };
  it('đang áp dụng, chưa tới hạn, hết hạn, ngừng', () => {
    expect(statusOf(p, '2026-11-16')).toBe('ACTIVE');
    expect(statusOf(p, '2026-08-31')).toBe('UPCOMING');
    expect(statusOf(p, '2027-01-01')).toBe('EXPIRED');
    expect(statusOf({ ...p, is_active: false }, '2026-11-16')).toBe('STOPPED');
  });
  it('không có ngày kết thúc thì không bao giờ hết hạn', () => {
    expect(statusOf({ ...p, valid_to: null }, '2030-01-01')).toBe('ACTIVE');
  });
  it('ngày hôm nay theo giờ Việt Nam: 17:00 UTC đã là ngày hôm sau', () => {
    expect(todayVn(new Date('2026-11-15T17:00:00Z'))).toBe('2026-11-16');
    expect(todayVn(new Date('2026-11-15T16:59:00Z'))).toBe('2026-11-15');
  });
});

describe('CH-04 kiểm biểu mẫu', () => {
  it('biểu mẫu đủ thì không lỗi', () => {
    expect(formErrors(base)).toEqual({});
    expect(errorSummary(formErrors(base))).toBeNull();
  });
  it('khung CH04_loi: thiếu mức tối đa, hiệu lực đến sớm hơn hiệu lực từ, chưa chọn nhóm gói', () => {
    const errors = formErrors({
      ...base,
      maxValue: '',
      validTo: new Date(2026, 7, 1),
      packageTypes: [],
    });
    expect(errors.maxValue).toBe('Bắt buộc nhập mức tối đa');
    expect(errors.validTo).toBe('Hiệu lực đến phải sau hiệu lực từ');
    expect(errors.packageTypes).toBe('Chọn ít nhất một nhóm gói');
    expect(errorSummary(errors)).toBe(
      'Chưa lưu được: còn 3 chỗ cần sửa (mức tối đa, hiệu lực đến, nhóm gói).',
    );
  });
  it('phần trăm không quá 100; giờ tặng và số lượng quà không bị giới hạn 100', () => {
    expect(formErrors({ ...base, maxValue: '101' }).maxValue).toBe('Phần trăm không quá 100.');
    expect(formErrors({ ...base, kind: 'GIFT_HOURS', maxValue: '101' }).maxValue).toBeUndefined();
    expect(formErrors({ ...base, maxValue: '150' }, true).maxValue).toBeUndefined();
    expect(formErrors({ ...base, maxValue: '0' }).maxValue).toBe('Mức tối đa phải lớn hơn 0.');
  });
});

describe('CH-04 mã và cơ sở', () => {
  it('mã từ tên: hoa, không dấu, gạch dưới', () => {
    expect(policyCode('Đóng cả năm')).toBe('DONG_CA_NAM');
    expect(policyCode(' Anh chị em ruột! ')).toBe('ANH_CHI_EM_RUOT');
  });
  it('phạm vi cơ sở: rỗng là Tất cả cơ sở', () => {
    expect(branchesLabel([], () => 'x')).toBe('Tất cả cơ sở');
    expect(branchesLabel(['a', 'b'], (id) => id.toUpperCase())).toBe('A, B');
  });
});

describe('CH-04 cột Áp dụng cho, Giá trị', () => {
  const policy = {
    kind: 'PERCENT' as const,
    max_value: 10,
    fixed_value: false,
    applies_to: ['PHIEU_THU', 'BAO_GIA'],
  };
  it('Áp dụng cho theo thứ tự Báo giá, Đơn, Phiếu thu', () => {
    expect(appliesToLabel(policy)).toBe('Báo giá, Phiếu thu');
    expect(appliesToLabel({ applies_to: ['BAO_GIA', 'DON', 'PHIEU_THU'] })).toBe(
      'Báo giá, Đơn, Phiếu thu',
    );
  });
  it('Giá trị: áp đúng mức thì hiện mức, không thì Tuỳ chọn', () => {
    expect(discountAppliedLabel(policy as never)).toBe('Tuỳ chọn');
    expect(discountAppliedLabel({ ...policy, fixed_value: true } as never)).toBe('10%');
  });
});
