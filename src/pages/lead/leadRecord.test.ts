import { describe, expect, it } from 'vitest';
import {
  BLANK_DRAFT,
  dateToIso,
  draftPayload,
  isoToDate,
  leadHistoryValue,
  toDraft,
  validateDraft,
  type LeadRecord,
} from './leadRecord';

const parentCode = (catalog: string, code: string | null | undefined, parent: string) =>
  catalog === 'SOURCE' && parent === 'SOURCE_TYPE' && code === 'FACEBOOK_ADS'
    ? 'MARKETING'
    : undefined;

const filled = {
  ...BLANK_DRAFT,
  parent_name: 'Chị Lê Thu Hằng',
  parent_phone: '0912 000 121',
  source_code: 'FACEBOOK_ADS',
  channel_code: 'FACEBOOK_ADS_LEAD_FORM',
  branch_id: 'b1',
  owner_id: 'u1',
};

describe('kiểm tra ô bắt buộc của biểu mẫu Lead (chặn sớm, luật thật ở hàm cơ sở dữ liệu)', () => {
  const opts = { creating: true, channelRequired: true };
  it('đủ thông tin thì không có lỗi', () => {
    expect(validateDraft(filled, opts)).toEqual({});
  });
  it('thiếu họ tên, SĐT sai, thiếu source: báo tại từng ô', () => {
    const errors = validateDraft(
      { ...filled, parent_name: '  ', parent_phone: '123', source_code: '' },
      opts,
    );
    expect(errors.parent_name).toBe('Nhập họ tên phụ huynh.');
    expect(errors.parent_phone).toBe('Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
    expect(errors.source_code).toBe('Chọn source.');
    expect(errors.channel_code).toBeUndefined();
  });
  it('SĐT nhận cách viết có dấu cách, chấm, gạch và đầu số +84', () => {
    for (const phone of [
      '0912 000 121',
      '0912.000.121',
      '0912-000-121',
      '+84912000121',
      '84912000121',
    ]) {
      expect(validateDraft({ ...filled, parent_phone: phone }, opts).parent_phone).toBeUndefined();
    }
    expect(
      validateDraft({ ...filled, parent_phone: '091200012' }, opts).parent_phone,
    ).toBeDefined();
  });
  it('nguồn có kênh con thì bắt chọn sub-source; nguồn không có kênh thì không bắt', () => {
    expect(validateDraft({ ...filled, channel_code: '' }, opts).channel_code).toBe(
      'Chọn sub-source.',
    );
    expect(
      validateDraft({ ...filled, channel_code: '' }, { ...opts, channelRequired: false })
        .channel_code,
    ).toBeUndefined();
  });
  it('năm sinh nếu có phải đủ bốn chữ số', () => {
    expect(validateDraft({ ...filled, student_birth_year: '12' }, opts).student_birth_year).toBe(
      'Năm sinh gồm 4 chữ số.',
    );
    expect(
      validateDraft({ ...filled, student_birth_year: '2012' }, opts).student_birth_year,
    ).toBeUndefined();
  });
  it('khi Tạo bắt buộc có cơ sở và người phụ trách; khi Sửa thì không xét hai ô này', () => {
    const blank = { ...filled, branch_id: '', owner_id: '' };
    expect(validateDraft(blank, opts).branch_id).toBe('Chọn cơ sở.');
    expect(validateDraft(blank, opts).owner_id).toBe('Chọn nhân sự phụ trách.');
    expect(validateDraft(blank, { ...opts, creating: false })).toEqual({});
  });
});

describe('dữ liệu gửi create_lead, update_lead', () => {
  it('bỏ khoảng trắng, ô trống thành null, SĐT chuẩn hoá, loại nguồn lấy từ nguồn', () => {
    const payload = draftPayload(
      { ...filled, need: '  ', student_birth_year: '2012', address: ' 12 Núi Trúc ' },
      { parentCode },
      { creating: true },
    );
    expect(payload).toMatchObject({
      parent_name: 'Chị Lê Thu Hằng',
      parent_phone: '0912000121',
      need: null,
      address: '12 Núi Trúc',
      student_birth_year: 2012,
      source_type_code: 'MARKETING',
      source_code: 'FACEBOOK_ADS',
      branch_id: 'b1',
      owner_id: 'u1',
    });
  });
  it('khi Sửa không gửi cơ sở và người phụ trách (đổi người phụ trách có hàm riêng, cơ sở không đổi)', () => {
    const payload = draftPayload(filled, { parentCode }, { creating: false });
    expect('branch_id' in payload).toBe(false);
    expect('owner_id' in payload).toBe(false);
  });
});

const record = {
  parent_name: 'A',
  student_birth_year: 2012,
  student_birth_date: '2012-03-15',
  ward_code: null,
  supporter_id: null,
  channel_code: null,
  campaign_id: null,
} as unknown as LeadRecord;

describe('bản nháp từ bản ghi và ngày', () => {
  it('ô rỗng của bản ghi thành chuỗi rỗng, số thành chuỗi', () => {
    const draft = toDraft(record);
    expect(draft.ward_code).toBe('');
    expect(draft.student_birth_year).toBe('2012');
    expect(draft.student_birth_date).toBe('2012-03-15');
  });
  it('ngày yyyy-mm-dd và Date địa phương đổi qua lại', () => {
    const d = isoToDate('2012-03-15');
    expect(d?.getFullYear()).toBe(2012);
    expect(dateToIso(d)).toBe('2012-03-15');
    expect(isoToDate('15/03/2012')).toBeNull();
    expect(dateToIso(null)).toBe('');
  });
});

describe('lịch sử thay đổi của lead hiện chữ dễ đọc', () => {
  const names = new Map([
    ['LEAD_STAGE|C4', 'Khách hàng tiềm năng'],
    ['LEAD_SUBSTAGE|C4C', 'Đủ điều kiện tạo cơ hội'],
    ['SOURCE|WEBSITE', 'Website'],
  ]);
  const value = leadHistoryValue(
    {
      name: (catalog, code) => names.get(`${catalog}|${code}`),
      campaignName: (id) => (id === 'c1' ? 'Ôn thi vào 10' : undefined),
    },
    { owner_id: 'u1', owner_name: 'Trần Thu Hà', supporter_id: null, supporter_name: null },
  );
  it('giai đoạn, nhóm con kèm mã; nguồn, chiến dịch ra tên', () => {
    expect(value('stage_code', 'C4')).toBe('C4 Khách hàng tiềm năng');
    expect(value('substage_code', 'C4C')).toBe('C4C Đủ điều kiện tạo cơ hội');
    expect(value('source_code', 'WEBSITE')).toBe('Website');
    expect(value('campaign_id', 'c1')).toBe('Ôn thi vào 10');
    expect(value('campaign_id', 'khac')).toBe('chiến dịch khác');
  });
  it('người phụ trách hiện tên nếu là người hiện tại, còn lại là "nhân sự khác"; mã lạ giữ mã', () => {
    expect(value('owner_id', 'u1')).toBe('Trần Thu Hà');
    expect(value('owner_id', 'u9')).toBe('nhân sự khác');
    expect(value('stage_code', 'C9')).toBe('C9');
  });
  it('trạng thái bản ghi và giá trị không phải chuỗi dùng cách mặc định', () => {
    expect(value('record_status', 'DA_GOP')).toBe('Đã gộp');
    expect(value('record_status', 'DA_HUY')).toBe('Đã huỷ');
    expect(value('need', 'abc')).toBeNull();
    expect(value('student_birth_year', 2012)).toBeNull();
  });
});
