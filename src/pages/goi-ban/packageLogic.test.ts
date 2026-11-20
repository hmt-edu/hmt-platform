import { describe, expect, it } from 'vitest';
import { buildPackageCode, gradeRangeError, isHourType, packageDialogText } from './packageLogic';

const base = { type: 'LC', subject: 'TOAN', gradeFrom: 'K09', gradeTo: '', suffix: '' };

describe('packageLogic', () => {
  it('mã gói giờ học: Loại-Môn-Khối, một khối hoặc dải khối', () => {
    expect(buildPackageCode(base)).toBe('LC-TOAN-K09');
    expect(buildPackageCode({ ...base, gradeTo: 'K09' })).toBe('LC-TOAN-K09');
    expect(buildPackageCode({ ...base, type: 'VIP', gradeFrom: 'K03', gradeTo: 'K07' })).toBe(
      'VIP-TOAN-K03K07',
    );
  });
  it('chưa đủ ô thì chưa có mã', () => {
    expect(buildPackageCode({ ...base, subject: '' })).toBe('');
    expect(buildPackageCode({ ...base, type: '' })).toBe('');
  });
  it('dịch vụ, tài liệu: Loại-TÊN viết hoa, bỏ ký tự lạ', () => {
    expect(buildPackageCode({ ...base, type: 'DV', suffix: ' csgk ' })).toBe('DV-CSGK');
    expect(buildPackageCode({ ...base, type: 'TL', suffix: 'Ma Toán!' })).toBe('TL-MATON');
    expect(buildPackageCode({ ...base, type: 'TL', suffix: '' })).toBe('');
    expect(isHourType('DV')).toBe(false);
  });
  it('khối đến nhỏ hơn khối từ bị báo', () => {
    const order = ['K06', 'K07', 'K08'];
    expect(gradeRangeError(order, 'K08', 'K06')).not.toBeNull();
    expect(gradeRangeError(order, 'K06', 'K08')).toBeNull();
    expect(gradeRangeError(order, 'K06', '')).toBeNull();
  });
});

describe('chữ hộp thoại Gói bán (So canvas CH-01, dc47)', () => {
  it('Sửa gói: tiêu đề có mã; ba dòng gợi ý đúng khung CH01_sua_ten', () => {
    expect(packageDialogText.editTitle('LC-TOAN-K09')).toBe('Sửa gói LC-TOAN-K09');
    expect(packageDialogText.codeHelp).toBe('Mã không đổi được.');
    expect(packageDialogText.legacyHelp).toBe(
      'Mã cũ trên Sheet, dùng để tìm kiếm. Sửa được; mã gói vẫn khoá.',
    );
    expect(packageDialogText.nameHelp).toBe('Đổi tên không đổi mã.');
  });
  it('Ngừng bán: tiêu đề hỏi kèm mã; câu nói đơn đã tạo giữ gói và cách bán lại (CH01_ngung)', () => {
    expect(packageDialogText.stopTitle('LC-TOAN-K06')).toBe('Ngừng bán gói LC-TOAN-K06?');
    expect(packageDialogText.stopBody('LC-TOAN-K06')).toBe(
      'Gói LC-TOAN-K06 sẽ không hiện ở ô chọn khi tạo báo giá, đơn mới. Đơn đã tạo vẫn giữ gói này. Muốn bán lại, bấm Dùng lại.',
    );
  });
});
