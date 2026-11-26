import { describe, expect, it } from 'vitest';
import { parseCsv } from '../lead/importCsv';
import {
  buildRows,
  errorRowsCsv,
  explainLine,
  normalizeHeader,
  passwordsCsv,
  type ImportResult,
} from './importFile';
import { IMPORT_KINDS, kindConfig } from './importKinds';

const parent = kindConfig('PHU_HUYNH');

describe('màn Nhập: đọc file CSV theo loại', () => {
  it('tên cột chuẩn hoá chữ thường, bỏ khoảng trắng hai đầu', () => {
    expect(normalizeHeader('  Ma_Cu ')).toBe('ma_cu');
  });

  it('ghép theo tên cột, số dòng trong file làm số dòng báo lỗi', () => {
    const table = parseCsv(
      'ma_cu,ho_ten,sdt,co_so\nPH1,An,0912000111,CS5\nPH2,Bình,0912000222,CS1\n',
    );
    const built = buildRows(table, parent);
    expect(built.missing).toEqual([]);
    expect(built.rows).toEqual([
      { row: 2, ma_cu: 'PH1', ho_ten: 'An', sdt: '0912000111', co_so: 'CS5' },
      { row: 3, ma_cu: 'PH2', ho_ten: 'Bình', sdt: '0912000222', co_so: 'CS1' },
    ]);
  });

  it('thiếu cột bắt buộc thì báo tên cột; cột lạ bị bỏ qua và liệt kê', () => {
    const table = parseCsv('ma_cu,ho_ten,sdt,nguon_tab\nPH1,An,0912000111,x\n');
    const built = buildRows(table, parent);
    expect(built.missing).toEqual(['co_so']);
    expect(built.ignored).toEqual(['nguon_tab']);
    expect(built.rows[0]).not.toHaveProperty('nguon_tab');
  });

  it('SĐT giữ nguyên chữ (không mất số 0 đầu); dấu nháy do file dòng lỗi thêm trước +84 được bỏ', () => {
    const table = parseCsv(
      "ma_cu,ho_ten,sdt,co_so\nPH1,An,0912000111,CS5\nPH2,Bình,'+84912000222,CS5\n",
    );
    const built = buildRows(table, parent);
    expect(built.rows.map((r) => r.sdt)).toEqual(['0912000111', '+84912000222']);
  });

  it('file dòng lỗi: giữ cột gốc, thêm ket_qua và ly_do, chỉ dòng Lỗi và Trùng', () => {
    const table = parseCsv(
      'ma_cu,ho_ten,sdt,co_so\nPH1,An,0912000111,CS5\nPH2,Bình,091,CS5\nPH3,Cúc,0912000333,CS5\n',
    );
    const result: ImportResult = {
      mode: 'NHAP',
      kind: 'PHU_HUYNH',
      total: 3,
      imported: 1,
      duplicates: 1,
      errors: 1,
      rows: [
        {
          row: 2,
          label: 'Dòng 2 (A.)',
          initial: 'A',
          status: 'HOP_LE',
          code: 'PH000001',
          message: null,
        },
        {
          row: 3,
          label: 'Dòng 3 (B.)',
          initial: 'B',
          status: 'LOI',
          code: null,
          message: 'Số điện thoại không đúng',
        },
        {
          row: 4,
          label: 'Dòng 4 (C.)',
          initial: 'C',
          status: 'TRUNG',
          code: 'PH000009',
          message: 'Đã có',
        },
      ],
    };
    const lines = errorRowsCsv(table, parent, result).replace('﻿', '').trim().split('\r\n');
    expect(lines[0]).toBe('dong,ma_cu,ho_ten,sdt,co_so,ket_qua,ly_do');
    expect(lines).toHaveLength(3);
    expect(lines[1]).toBe('3,PH2,Bình,091,CS5,Lỗi,Số điện thoại không đúng');
    expect(lines[2]).toBe('4,PH3,Cúc,0912000333,CS5,Trùng,Đã có');
  });

  it('file mật khẩu tạm có hai cột, một dòng mỗi tài khoản', () => {
    const csv = passwordsCsv([{ username: 'annv', password: 'Abc123xyz' }]).replace('﻿', '');
    expect(csv.trim().split('\r\n')).toEqual(['ten_dang_nhap,mat_khau_tam', 'annv,Abc123xyz']);
  });

  it('Cơ hội: cột nam_sinh tuỳ chọn, thiếu cột bắt buộc thì báo, cột lạ (nguon_tab) bỏ qua', () => {
    const co = kindConfig('CO_HOI');
    const full = parseCsv(
      'ma_cu,ngay_tao,ho_ten_ph,sdt_ph,nguon_goc,nguon,co_so,nguoi_phu_trach,giai_doan,nam_sinh,nguon_tab\n0900000001,2026-09-15,Zeta,0900000001,Marketing,Hotline,CS5,sale.cs5,L5,2013,T9\n',
    );
    const built = buildRows(full, co);
    expect(built.missing).toEqual([]);
    expect(built.ignored).toEqual(['nguon_tab']);
    expect(built.rows[0]).toMatchObject({
      row: 2,
      giai_doan: 'L5',
      nam_sinh: '2013',
      ngay_tao: '2026-09-15',
    });
    const noYear = parseCsv(
      'ma_cu,ngay_tao,ho_ten_ph,sdt_ph,nguon_goc,nguon,co_so,nguoi_phu_trach,giai_doan\n1,2026-09-15,Z,0900000001,Marketing,Hotline,CS5,x,L5\n',
    );
    expect(buildRows(noYear, co).missing).toEqual([]);
    const lacking = parseCsv('ma_cu,ngay_tao,ho_ten_ph,sdt_ph\n1,2026-09-15,Z,0900000001\n');
    expect(buildRows(lacking, co).missing).toEqual([
      'nguon_goc',
      'nguon',
      'co_so',
      'nguoi_phu_trach',
      'giai_doan',
    ]);
  });

  it('thứ tự loại nạp: Người dùng, Cơ hội, Phụ huynh, Học sinh, Lớp, Ghi danh, Phiếu Test, Số dư', () => {
    expect(IMPORT_KINDS.map((k) => k.kind)).toEqual([
      'NGUOI_DUNG',
      'CO_HOI',
      'PHU_HUYNH',
      'HOC_SINH',
      'LOP',
      'GHI_DANH',
      'PHIEU_TEST',
      'SO_DU',
    ]);
  });
});

describe('QT-18: câu Giải thích có tên cột lỗi (khung QT18_ket_qua)', () => {
  it('có cột mà câu chưa nhắc thì thêm «Cột <tên>: » ở đầu', () => {
    expect(explainLine({ message: 'Số điện thoại cần đủ 10 số.', column: 'sdt' })).toBe(
      'Cột sdt: Số điện thoại cần đủ 10 số.',
    );
  });
  it('câu đã nêu tên cột thì giữ nguyên, không lặp', () => {
    expect(explainLine({ message: 'Cột diem phải từ 0 đến 10.', column: 'diem' })).toBe(
      'Cột diem phải từ 0 đến 10.',
    );
  });
  it('không biết cột (null hoặc trống) thì giữ nguyên câu; không có câu thì trống', () => {
    expect(explainLine({ message: 'Dòng không đúng định dạng.', column: null })).toBe(
      'Dòng không đúng định dạng.',
    );
    expect(explainLine({ message: null, column: 'sdt' })).toBe('');
  });
});
