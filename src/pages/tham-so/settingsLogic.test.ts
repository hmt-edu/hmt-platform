// QT-09: nhóm tham số, kiểm khoảng nhập (luật do DB kiểm lại), hiển thị theo ngày của tham số lưu bằng phút.
import { describe, expect, it } from 'vitest';
import {
  buildGroups,
  formatSetting,
  formatSettingValue,
  formatHistoryValue,
  fromInputText,
  historyActor,
  historyScope,
  inputError,
  rangeLabel,
  toInputText,
  type SettingDef,
  type SettingHistoryRow,
} from './settingsLogic';

const def = (over: Partial<SettingDef>): SettingDef => ({
  key: 'quotation_validity_days',
  name: 'Hạn hiệu lực báo giá',
  description: 'Số ngày báo giá còn hiệu lực',
  value_type: 'INT',
  unit: 'ngày',
  min_value: 1,
  max_value: 90,
  value: '14',
  allow_branch_override: false,
  module: 'BAN_HANG',
  ...over,
});
const logout = def({
  key: 'teacher_idle_logout_minutes',
  name: 'Giáo viên tự đăng xuất',
  unit: 'phút',
  min_value: 5,
  max_value: 20160,
  value: '10080',
  module: 'ADMIN',
});

describe('QT-09 nhóm tham số', () => {
  const defs = [
    def({}),
    logout,
    def({ key: 'list_page_size', name: 'Số dòng mỗi trang', module: null }),
  ];
  it('nhóm theo module, tham số không module vào nhóm Chung, đúng thứ tự', () => {
    expect(buildGroups(defs, '').map((g) => g.label)).toEqual([
      'Bán hàng',
      'Đăng nhập, bảo mật',
      'Chung',
    ]);
  });
  it('tìm theo tên hoặc mã, bỏ nhóm không khớp', () => {
    const groups = buildGroups(defs, 'trang');
    expect(groups).toHaveLength(1);
    expect(groups[0]?.items[0]?.key).toBe('list_page_size');
  });
});

describe('QT-09 kiểm khoảng khi nhập', () => {
  it('trong khoảng thì hợp lệ', () => {
    expect(inputError(def({}), '14')).toBeNull();
    expect(inputError(def({}), '90')).toBeNull();
  });
  it('ngoài khoảng, không phải số, số lẻ ở tham số nguyên thì báo lỗi', () => {
    expect(inputError(def({}), '91')).toBe('Giá trị phải trong khoảng 1–90 ngày.');
    expect(inputError(def({}), '0')).not.toBeNull();
    expect(inputError(def({}), 'abc')).toBe('Nhập một số nguyên.');
    expect(inputError(def({}), '1.5')).toBe('Nhập một số nguyên.');
    expect(inputError(def({ value_type: 'NUMERIC' }), '1,5')).toBeNull();
  });
});

describe('QT-09 tham số lưu bằng phút, hiện theo ngày', () => {
  it('hiện 7 ngày, nhập 14 ngày lưu 20160 phút', () => {
    expect(toInputText(logout, '10080')).toBe('7');
    expect(formatSetting(logout, '10080')).toBe('7 ngày');
    // D50: cột Giá trị hiện tại không kèm đơn vị (đơn vị ở cột riêng).
    expect(formatSettingValue(logout, '10080')).toBe('7');
    expect(fromInputText(logout, '14')).toBe('20160');
    expect(rangeLabel(logout)).toBe('5 phút–14 ngày');
  });
  it('quá 14 ngày thì chặn', () => {
    expect(inputError(logout, '15')).not.toBeNull();
    expect(inputError(logout, '14')).toBeNull();
  });
  it('bật tắt hiện chữ Bật, Tắt', () => {
    expect(formatSetting(def({ value_type: 'BOOL', unit: null }), 'true')).toBe('Bật');
  });
});

describe('lịch sử thay đổi tham số (QT09_lich_su)', () => {
  const row = (over: Partial<SettingHistoryRow>): SettingHistoryRow => ({
    id: 1,
    at: '2026-11-05T03:12:00Z',
    setting_key: 'quotation_validity_days',
    branch_code: null,
    action: 'U',
    old_value: '21',
    new_value: '14',
    actor_name: 'Admin B',
    ...over,
  });
  it('giá trị cũ, mới kèm đơn vị; thiếu giá trị (lúc tạo ghi đè) hiện gạch', () => {
    expect(formatHistoryValue(def({}), '21')).toBe('21 ngày');
    expect(formatHistoryValue(def({}), null)).toBe('—');
    expect(formatHistoryValue(undefined, '5')).toBe('5');
  });
  it('phạm vi: Chung hoặc mã cơ sở; không có người sửa thì là Hệ thống', () => {
    expect(historyScope(row({}))).toBe('Chung');
    expect(historyScope(row({ branch_code: 'CS5' }))).toBe('CS5');
    expect(historyActor(null)).toBe('Hệ thống');
    expect(historyActor('Admin B')).toBe('Admin B');
  });
});
