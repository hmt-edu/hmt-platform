import { describe, expect, it } from 'vitest';
import { buildEntries, describeChanges, type FieldFormat } from './entries';

const format: FieldFormat = {
  labels: { display_name: 'Họ tên', branch_id: 'Cơ sở', is_locked: 'Khoá tài khoản' },
  value: (column, value) => (column === 'branch_id' ? (value === 'b1' ? 'Cơ sở 1' : null) : null),
};

describe('lịch sử thay đổi của bản ghi', () => {
  it('đổi tên cột thành nhãn, giá trị đúng/sai thành Có/Không, trống thành "trống"', () => {
    const changes = describeChanges(
      {
        id: 1,
        at: '2026-10-12T02:00:00Z',
        actor_name: 'A',
        action: 'U',
        changes: { is_locked: [false, true], display_name: [null, 'Trần Thu Hà'] },
      },
      format,
    );
    expect(changes).toContainEqual({ label: 'Khoá tài khoản', from: 'Không', to: 'Có' });
    expect(changes).toContainEqual({ label: 'Họ tên', from: 'trống', to: 'Trần Thu Hà' });
  });

  it('id cơ sở đổi thành tên; cột không có nhãn (kỹ thuật) thì bỏ; vai trò ghi tên vai trò', () => {
    const changes = describeChanges(
      {
        id: 2,
        at: '2026-10-12T02:00:00Z',
        actor_name: 'A',
        action: 'U',
        changes: { branch_id: ['b0', 'b1'], some_internal: [1, 2], 'role:Kế toán': [false, true] },
      },
      format,
    );
    expect(changes).toEqual([
      { label: 'Cơ sở', from: 'b0', to: 'Cơ sở 1' },
      { label: 'Vai trò Kế toán', from: 'Không', to: 'Có' },
    ]);
  });

  it('gộp ghi chú và lịch sử, mới nhất trước; dòng tạo thành câu hệ thống; dòng rỗng thì bỏ', () => {
    const entries = buildEntries(
      [
        {
          id: 'n1',
          at: '2026-10-12T03:00:00Z',
          author_name: 'B',
          body: 'Ghi chú',
          mention_names: [],
        },
      ],
      [
        { id: 1, at: '2026-10-10T01:00:00Z', actor_name: 'Hệ thống', action: 'I', changes: null },
        {
          id: 2,
          at: '2026-10-12T04:00:00Z',
          actor_name: 'A',
          action: 'U',
          changes: { is_locked: [false, true] },
        },
        {
          id: 3,
          at: '2026-10-12T05:00:00Z',
          actor_name: 'A',
          action: 'U',
          changes: { some_internal: [1, 2] },
        },
      ],
      format,
      'Tạo tài khoản.',
    );
    expect(entries.map((e) => e.kind)).toEqual(['change', 'note', 'system']);
    expect(entries[2]).toMatchObject({ kind: 'system', text: 'Tạo tài khoản.' });
  });
});

describe('ghi chú của lead gốc hiện ở cơ hội (lỗi 26/10)', () => {
  it('ghi chú có nhãn nguồn mang theo nhãn; ghi chú của chính bản ghi không có', () => {
    const entries = buildEntries(
      [
        {
          id: 'n1',
          at: '2026-10-26T01:00:00Z',
          author_name: 'A',
          body: 'Gọi lần 1',
          mention_names: [],
          source_label: 'Lead LD000012',
        },
        {
          id: 'n2',
          at: '2026-10-26T02:00:00Z',
          author_name: 'B',
          body: 'Tư vấn',
          mention_names: [],
          source_label: null,
        },
      ],
      [],
      { labels: {} },
      'Tạo cơ hội.',
    );
    const own = entries.find((e) => e.id === 'n2');
    const fromLead = entries.find((e) => e.id === 'n1');
    expect(own && 'source' in own).toBe(false);
    expect(fromLead && fromLead.kind === 'note' ? fromLead.source : null).toBe('Lead LD000012');
  });

  it('có sự kiện riêng: bỏ dòng "Tạo" của nhật ký thay đổi, trộn sự kiện theo giờ (Q-48)', () => {
    const history = [
      { id: 1, at: '2026-11-07T01:00:00Z', actor_name: 'A', action: 'I', changes: null },
    ];
    const event = {
      kind: 'event' as const,
      id: 'e1',
      at: '2026-11-07T01:00:01Z',
      author: 'A',
      title: 'Tạo đơn hàng',
      lines: [],
    };
    const entries = buildEntries([], history, { labels: {} }, null, [event]);
    expect(entries).toEqual([event]);
    const withCreated = buildEntries([], history, { labels: {} }, 'Tạo đơn hàng.', [event]);
    expect(withCreated.map((e) => e.kind)).toEqual(['event', 'system']);
  });

  it('B10: sự kiện không tên lấy người làm từ nhật ký cùng thao tác; cột đã có sự kiện không hiện thêm dòng đổi trường', () => {
    const fmt = {
      labels: { status_code: 'Tình trạng', max_students: 'Sĩ số' },
      coveredByEvents: ['status_code'],
    };
    const history = [
      {
        id: 5,
        at: '2026-11-23T03:00:01Z',
        actor_name: 'CSKH CS5',
        action: 'U',
        changes: { status_code: ['NHAP', 'DA_TRINH'], max_students: [10, 12] },
      },
    ] as never;
    const entries = buildEntries([], history, fmt, null, [
      { kind: 'system', id: 'ev', at: '2026-11-23T03:00:00Z', author: '', text: 'Trình' },
    ]);
    expect(entries.find((e) => e.kind === 'system')).toMatchObject({ author: 'CSKH CS5' });
    const change = entries.find((e) => e.kind === 'change');
    expect(change).toMatchObject({ changes: [{ label: 'Sĩ số' }] });
    const only = buildEntries(
      [],
      [{ ...(history as object[])[0], changes: { status_code: ['NHAP', 'DA_TRINH'] } }] as never,
      fmt,
      null,
      [{ kind: 'system', id: 'ev', at: '2026-11-23T03:00:00Z', author: '', text: 'Trình' }],
    );
    expect(only.map((e) => e.kind)).toEqual(['system']);
  });
});
