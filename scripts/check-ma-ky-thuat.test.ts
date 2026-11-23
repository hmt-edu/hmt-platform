import { describe, expect, it } from 'vitest';
import { findLeaks } from './check-ma-ky-thuat.mjs';

type Hit = { line: number; kind: string; found: string };
const leaks = (code: string, keep: string[] = []) => findLeaks(code, keep) as Hit[];

describe('check-ma-ky-thuat (mã kỹ thuật lộ trong chữ cho người dùng)', () => {
  it('bắt mã luật trong chuỗi và trong chữ JSX', () => {
    expect(leaks(`const a = 'Giá không sửa (R-TIEN-14).';`)[0]?.found).toBe('R-TIEN-14');
    expect(leaks(`const x = <p>Chỉ xem (R-GV-08).</p>;`)[0]?.found).toBe('R-GV-08');
    expect(leaks(`const a = 'theo luật (R-V2-20)';`)[0]?.found).toBe('R-V2-20');
  });
  it('bắt mã quyết định, mã màn, tên bảng DB', () => {
    expect(leaks(`const a = 'xem Q-31';`)[0]?.kind).toBe('mã quyết định');
    expect(leaks(`const a = 'sửa ở BUOI-14';`)[0]?.found).toBe('BUOI-14');
    expect(leaks(`const a = 'bảng app.user_role';`)[0]?.found).toBe('app.user_role');
  });
  it('không bắt comment, screenCode, code của menu, chữ thường', () => {
    expect(leaks(`// (R-GV-08) ghi chú\nconst a = 1;`)).toEqual([]);
    expect(leaks(`const c = { screenCode: 'QT-17' };`)).toEqual([]);
    expect(leaks(`const m = { code: 'QT-17', label: 'Tài khoản' };`)).toEqual([]);
    expect(leaks(`const a = 'Chỉ cho giáo viên được phân công.';`)).toEqual([]);
  });
  it('lối thoát allow-code và danh sách nhãn cho qua', () => {
    expect(leaks(`const a = 'Q-31'; // allow-code: tên nhà cung cấp`)).toEqual([]);
    expect(leaks(`const a = 'Q-31';`, ['Q-31'])).toEqual([]);
  });
});
