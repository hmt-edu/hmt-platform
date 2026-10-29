import { QueryObserver } from '@tanstack/react-query';
import { describe, expect, it } from 'vitest';
import { HmtQueryClient } from './query';

// Tái hiện lỗi "danh sách cũ sau khi ghi": lượt tải đầu của một khoá (chưa có dữ liệu) bắt đầu TRƯỚC khi ghi xong, rồi gặp làm mới.
describe('làm mới sau khi ghi (HmtQueryClient)', () => {
  function setup(client: { fetches: number }) {
    let db = 'cũ';
    const queryFn = async () => {
      client.fetches += 1;
      const seen = db; // đọc ngay lúc bắt đầu, như một lời gọi đọc trước khi ghi xong
      await new Promise((r) => setTimeout(r, 30));
      return seen;
    };
    return { write: () => (db = 'mới'), queryFn };
  }

  it('khoá đang tải lần đầu khi ghi xong: sau làm mới màn thấy dữ liệu mới', async () => {
    const client = new HmtQueryClient();
    const counter = { fetches: 0 };
    const { write, queryFn } = setup(counter);
    const observer = new QueryObserver(client, { queryKey: ['danh-sach'], queryFn });
    const unsubscribe = observer.subscribe(() => undefined);
    await new Promise((r) => setTimeout(r, 5)); // lượt tải đầu đã bắt đầu, chưa xong
    write(); // thao tác ghi xong
    await client.invalidateQueries({ queryKey: ['danh-sach'] });
    expect(client.getQueryData(['danh-sach'])).toBe('mới');
    expect(counter.fetches).toBe(2);
    unsubscribe();
  });

  it('QueryClient mặc định giữ kết quả cũ (chứng minh lỗi gốc)', async () => {
    const { QueryClient } = await import('@tanstack/react-query');
    const client = new QueryClient();
    const counter = { fetches: 0 };
    const { write, queryFn } = setup(counter);
    const observer = new QueryObserver(client, { queryKey: ['danh-sach'], queryFn });
    const unsubscribe = observer.subscribe(() => undefined);
    await new Promise((r) => setTimeout(r, 5));
    write();
    await client.invalidateQueries({ queryKey: ['danh-sach'] });
    expect(client.getQueryData(['danh-sach'])).toBe('cũ');
    unsubscribe();
  });

  it('khoá đã có dữ liệu: sau ghi, làm mới tải lại đúng một lần và có dữ liệu mới', async () => {
    const client = new HmtQueryClient();
    const counter = { fetches: 0 };
    const { write, queryFn } = setup(counter);
    await client.fetchQuery({ queryKey: ['a'], queryFn });
    // staleTime vô hạn: người quan sát gắn vào không tự tải lại, nên mọi lượt tải thêm đều do làm mới.
    const observer = new QueryObserver(client, { queryKey: ['a'], queryFn, staleTime: Infinity });
    const unsubscribe = observer.subscribe(() => undefined);
    expect(counter.fetches).toBe(1);
    write();
    await client.invalidateQueries({ queryKey: ['a'] });
    expect(client.getQueryData(['a'])).toBe('mới');
    expect(counter.fetches).toBe(2);
    unsubscribe();
  });
});
