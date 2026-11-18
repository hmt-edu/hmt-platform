import { describe, expect, it } from 'vitest';
import { selectedSummary } from '../../features/assign/assignText';
import { vnDayStartOf } from '../../lib/vnDay';
import { EMPTY_LEAD_STATE } from './leadConfig';
import { csvCell, toCsv } from './csv';
import { appointmentTag, formatPhone, leadTitle } from './leadFormat';
import { buildLeadFilters, groupFilter, nextSort, sortParam } from './leadFilters';
import { buildLeadGroupTree } from './leadGroups';
import type { GroupCounts } from './leadTypes';
import type { ListState } from '../../list/types';

const state = (patch: Partial<ListState>): ListState => ({ ...EMPTY_LEAD_STATE, ...patch });

describe('bộ lọc gửi máy chủ (R-CRM-07: cùng nhóm HOẶC, khác nhóm VÀ)', () => {
  it('không chọn gì thì không có bộ lọc', () => {
    expect(buildLeadFilters(EMPTY_LEAD_STATE)).toEqual({});
  });

  it('tìm kiếm cắt khoảng trắng; ô trống thì bỏ', () => {
    expect(buildLeadFilters(state({ search: '  Hằng ' }))).toEqual({ q: 'Hằng' });
    expect(buildLeadFilters(state({ search: '   ' }))).toEqual({});
  });

  it('lọc nhanh Lịch hẹn: nhiều lựa chọn cùng nhóm thành một danh sách (máy chủ nối bằng HOẶC)', () => {
    expect(
      buildLeadFilters(state({ quick: { appt: ['overdue', 'upcoming', 'none', 'today'] } })),
    ).toEqual({
      appointment: ['OVERDUE', 'UPCOMING', 'NONE', 'TODAY'],
    });
  });

  it('lọc nhanh Của tôi và Trạng thái bản ghi: Đã gộp', () => {
    expect(buildLeadFilters(state({ quick: { mine: ['owner'], status: ['merged'] } }))).toEqual({
      mine_roles: ['OWNER'],
      include_merged: true,
    });
  });

  it('khoá lọc lạ bị bỏ, không gửi lên máy chủ', () => {
    expect(buildLeadFilters(state({ quick: { appt: ['lạ'], khac: ['x'] } }))).toEqual({});
  });

  it('lọc nâng cao: nhiều điều kiện cùng trường gộp thành một danh sách, trường chọn một thì lấy giá trị', () => {
    const filters = buildLeadFilters(
      state({
        conditions: [
          { id: 'a', field: 'stage', op: 'in', value: ['C1', 'C2'] },
          { id: 'b', field: 'stage', op: 'in', value: ['C2', 'C3'] },
          { id: 'c', field: 'campaign', op: 'eq', value: 'id-chien-dich' },
          { id: 'd', field: 'channel', op: 'in', value: [] },
        ],
      }),
    );
    expect(filters).toEqual({ stage: ['C1', 'C2', 'C3'], campaign_id: 'id-chien-dich' });
  });

  it('Chiến dịch với phép "khác" không được gửi (máy chủ không hiểu)', () => {
    expect(
      buildLeadFilters(
        state({ conditions: [{ id: 'a', field: 'campaign', op: 'ne', value: 'x' }] }),
      ),
    ).toEqual({});
  });

  it('Ngày tạo: từ ngày, đến ngày tính theo giờ Việt Nam, "đến" tính hết ngày', () => {
    const filters = buildLeadFilters(
      state({
        conditions: [
          { id: 'a', field: 'created', op: 'from', value: '2026-10-18' },
          { id: 'b', field: 'created', op: 'to', value: '2026-10-18' },
        ],
      }),
    );
    expect(filters).toEqual({
      created_from: '2026-10-17T17:00:00.000Z',
      created_to: '2026-10-18T17:00:00.000Z',
    });
  });

  it('mốc nhanh Hôm nay của ô Ngày tạo thành khoảng created_from đến created_to (00:00 giờ Việt Nam, R-HT-07)', () => {
    // 18/10/2026 10:00 giờ Việt Nam = 03:00 UTC; kết quả không phụ thuộc múi giờ của máy chạy kiểm thử.
    const filters = buildLeadFilters(
      state({ dateField: 'created', datePreset: 'today' }),
      new Date('2026-10-18T03:00:00Z'),
    );
    expect(filters.created_from).toBe('2026-10-17T17:00:00.000Z');
    expect(filters.created_to).toBe('2026-10-18T17:00:00.000Z');
  });
});

describe('nhóm và sắp xếp', () => {
  it('bộ lọc của nhóm lá: giai đoạn, nguồn, người phụ trách; nhóm "Chưa có" không lọc', () => {
    expect(groupFilter('stage', 'C2')).toEqual({ stage: ['C2'] });
    expect(groupFilter('source', 'WEBSITE')).toEqual({ source: ['WEBSITE'] });
    expect(groupFilter('owner', 'u1')).toEqual({ owner_id: 'u1' });
    expect(groupFilter('stage', '')).toEqual({});
  });

  it('sắp xếp: chỉ các kiểu máy chủ hỗ trợ; chiều không hỗ trợ thì bỏ sắp xếp, không hiện mũi tên sai', () => {
    expect(sortParam(null)).toBeUndefined();
    expect(sortParam({ key: 'created', direction: 'asc' })).toBe('created_asc');
    expect(sortParam({ key: 'created', direction: 'desc' })).toBe('created_desc');
    expect(sortParam({ key: 'next', direction: 'asc' })).toBe('next_appointment_asc');
    expect(sortParam({ key: 'next', direction: 'desc' })).toBeUndefined();
    expect(sortParam({ key: 'parent', direction: 'asc' })).toBe('name_asc');
    expect(nextSort({ key: 'next', direction: 'desc' })).toBeNull();
    expect(nextSort({ key: 'next', direction: 'asc' })).toEqual({ key: 'next', direction: 'asc' });
  });
});

describe('cây nhóm Group By ở máy chủ', () => {
  const counts: GroupCounts = {
    total: 5,
    groups: [
      { k1: 'C1', l1: 'Data mới', k2: 'FACEBOOK_ADS', l2: 'Facebook Ads', count: 3 },
      { k1: 'C1', l1: 'Data mới', k2: 'WEBSITE', l2: 'Website', count: 1 },
      { k1: 'C2', l1: 'Chưa liên hệ được', k2: 'WEBSITE', l2: 'Website', count: 1 },
    ],
  };

  it('một cấp: mỗi nhóm là nhóm lá, nhãn giai đoạn kèm mã, số đếm của máy chủ', () => {
    const one: GroupCounts = {
      total: 4,
      groups: [{ k1: 'C1', l1: 'Data mới', k2: null, l2: null, count: 4 }],
    };
    const { tree, specs } = buildLeadGroupTree(one, ['stage'], {}, () => undefined);
    expect(tree).toHaveLength(1);
    expect(tree[0]).toMatchObject({
      key: 'g:stage=C1',
      label: 'C1 Data mới',
      count: 4,
      children: [],
      rows: [],
    });
    expect(specs.get('g:stage=C1')?.filters).toEqual({ stage: ['C1'] });
  });

  it('hai cấp: nhóm cha cộng số đếm, nhóm lá có bộ lọc gộp của cả hai cấp', () => {
    const { tree, specs } = buildLeadGroupTree(counts, ['stage', 'source'], {}, () => undefined);
    expect(tree.map((g) => [g.label, g.count, g.children.length])).toEqual([
      ['C1 Data mới', 4, 2],
      ['C2 Chưa liên hệ được', 1, 1],
    ]);
    expect(specs.get('g:stage=C1/source=WEBSITE')?.filters).toEqual({
      stage: ['C1'],
      source: ['WEBSITE'],
    });
    expect(specs.size).toBe(3);
  });

  it('nhóm lá còn dòng chưa tải thì có "Xem thêm" với số còn lại; tải đủ thì không', () => {
    const calls: string[] = [];
    const loaded = {
      'g:stage=C1': { rows: [], total: 4, loading: true },
    };
    const one: GroupCounts = {
      total: 4,
      groups: [{ k1: 'C1', l1: 'Data mới', k2: null, l2: null, count: 4 }],
    };
    expect(buildLeadGroupTree(one, ['stage'], loaded, () => undefined).tree[0]?.loading).toBe(true);
    const row = { id: 'x' } as never;
    const partial = { 'g:stage=C1': { rows: [row, row], total: 4, loading: false } };
    const group = buildLeadGroupTree(one, ['stage'], partial, (key) => calls.push(key)).tree[0];
    expect(group?.more?.remaining).toBe(2);
    group?.more?.onMore();
    expect(calls).toEqual(['g:stage=C1']);
    const full = { 'g:stage=C1': { rows: [row, row, row, row], total: 4, loading: false } };
    expect(buildLeadGroupTree(one, ['stage'], full, () => undefined).tree[0]?.more).toBeUndefined();
  });
});

describe('thẻ Lịch hẹn kế tiếp (giờ Việt Nam)', () => {
  // 10:00 sáng 18/10/2026 giờ Việt Nam.
  const now = new Date('2026-10-18T03:00:00Z');
  it('không có lịch', () => {
    expect(appointmentTag(null, now)).toEqual({ label: 'Chưa có lịch', tone: 'neutral' });
  });
  it('quá hạn: trước đầu ngày hôm nay, kể cả 23:59 hôm qua', () => {
    expect(appointmentTag('2026-10-17T16:59:00Z', now)).toEqual({
      label: 'Quá hạn 17/10',
      tone: 'danger',
    });
  });
  it('hôm nay: từ 00:00, kể cả giờ đã qua trong ngày', () => {
    expect(appointmentTag('2026-10-17T17:00:00Z', now)).toEqual({
      label: 'Hôm nay 00:00',
      tone: 'warning',
    });
    expect(appointmentTag('2026-10-18T07:00:00Z', now)).toEqual({
      label: 'Hôm nay 14:00',
      tone: 'warning',
    });
  });
  it('sắp tới: từ 00:00 ngày mai, hiện ngày và giờ', () => {
    expect(appointmentTag('2026-10-18T17:00:00Z', now)).toEqual({
      label: '19/10 00:00',
      tone: 'success',
    });
    expect(appointmentTag('2026-10-19T02:00:00Z', now)).toEqual({
      label: '19/10 09:00',
      tone: 'success',
    });
  });
});

describe('hiển thị', () => {
  it('SĐT 10 số chia nhóm; chuỗi khác giữ nguyên', () => {
    expect(formatPhone('0912000121')).toBe('0912 000 121');
    expect(formatPhone('123')).toBe('123');
  });
  it('tiêu đề thẻ: phụ huynh kèm học sinh nếu có', () => {
    expect(leadTitle({ parent_name: 'Chị Hằng', student_name: 'Huy' })).toBe('Chị Hằng · Huy');
    expect(leadTitle({ parent_name: 'Chị Hằng', student_name: null })).toBe('Chị Hằng');
  });
  it('dòng "n lead đã chọn" liệt kê tối đa năm mã', () => {
    expect(selectedSummary('lead', ['A', 'B'])).toBe('2 lead đã chọn: A, B');
    expect(selectedSummary('lead', ['1', '2', '3', '4', '5', '6', '7'])).toBe(
      '7 lead đã chọn: 1, 2, 3, 4, 5 và 2 lead khác',
    );
  });
  it('ngày dạng yyyy-mm-dd thành 00:00 giờ Việt Nam; chuỗi sai thì null', () => {
    expect(vnDayStartOf('2026-10-18')?.toISOString()).toBe('2026-10-17T17:00:00.000Z');
    expect(vnDayStartOf('18/10/2026')).toBeNull();
  });
});

describe('xuất CSV', () => {
  it('ô có dấu phẩy, nháy kép, xuống dòng được bọc và nhân đôi nháy', () => {
    expect(csvCell('Chị A, B')).toBe('"Chị A, B"');
    expect(csvCell('Nói "xin chào"')).toBe('"Nói ""xin chào"""');
    expect(csvCell('hai\ndòng')).toBe('"hai\ndòng"');
    expect(csvCell(null)).toBe('');
    expect(csvCell(2012)).toBe('2012');
  });
  it('ô bắt đầu bằng = + - @ được thêm dấu nháy để Excel không hiểu thành công thức', () => {
    expect(csvCell('=SUM(A1)')).toBe("'=SUM(A1)");
    expect(csvCell('+84912000121')).toBe("'+84912000121");
    expect(csvCell('@abc')).toBe("'@abc");
    expect(csvCell('-1')).toBe("'-1");
  });
  it('có BOM UTF-8 để Excel đọc đúng tiếng Việt, dòng tiêu đề và dòng dữ liệu', () => {
    const csv = toCsv(
      [{ code: 'LD1', name: 'Chị Hằng' }],
      [
        { key: 'code', label: 'Mã' },
        { key: 'name', label: 'Phụ huynh' },
      ],
    );
    expect(csv).toBe('﻿Mã,Phụ huynh\r\nLD1,Chị Hằng\r\n');
  });
});
