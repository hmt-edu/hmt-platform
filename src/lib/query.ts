import { QueryClient } from '@tanstack/react-query';

const STALE_MS = 60_000; // allow-number: dữ liệu khung (quyền, cơ sở) coi là mới trong một phút

/**
 * Sửa lỗi "danh sách cũ sau khi ghi" (28/10): TanStack Query KHÔNG huỷ lượt tải đang chạy của một khoá chưa có dữ liệu khi gọi
 * `invalidateQueries`, mà nối vào đúng lượt tải đó. Nếu lượt tải ấy bắt đầu TRƯỚC khi thao tác ghi xong (ví dụ danh sách vừa đổi ô tìm kiếm,
 * khoá mới đang tải lần đầu), kết quả cũ được giữ làm mới và màn hiện trạng thái trước khi ghi. Huỷ các lượt đang tải của đúng các khoá cần làm
 * mới trước khi làm mới thì lượt tải kế tiếp luôn bắt đầu SAU lúc ghi xong.
 */
export class HmtQueryClient extends QueryClient {
  override async invalidateQueries(
    ...args: Parameters<QueryClient['invalidateQueries']>
  ): ReturnType<QueryClient['invalidateQueries']> {
    await this.cancelQueries(args[0]);
    return super.invalidateQueries(...args);
  }
}

export const queryClient = new HmtQueryClient({
  defaultOptions: { queries: { staleTime: STALE_MS, retry: 1, refetchOnWindowFocus: true } },
});
