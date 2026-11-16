// QT-08 Cơ sở và phòng học: kiểu dữ liệu và luật kiểm biểu mẫu (luật chặn thật ở hàm DB: migration 225; canvas dc47 QT08_*).
export type Branch = {
  id: string;
  code: string;
  name: string;
  address: string | null;
  is_active: boolean;
};
export type Room = {
  id: string;
  branch_id: string;
  code: string;
  name: string;
  capacity: number | null;
  is_active: boolean;
};

/** Địa chỉ một dòng, tối đa 200 ký tự (canvas QT08_sua_co_so). */
export const ADDRESS_MAX = 200; // allow-number: giới hạn độ dài địa chỉ theo canvas, DB kiểm lại
export const ROOM_CODE_PATTERN = /^[A-Z0-9][A-Z0-9_]*$/;

export type RoomDraft = { code: string; name: string; capacity: string };
export const EMPTY_ROOM_DRAFT: RoomDraft = { code: '', name: '', capacity: '' };
export const roomDraftOf = (r: Room): RoomDraft => ({
  code: r.code,
  name: r.name,
  capacity: r.capacity === null ? '' : String(r.capacity),
});

/** Chuẩn hoá để so tên trùng: bỏ dấu, chữ thường, gộp khoảng trắng (DB so lại bằng fold_text). */
export const foldName = (s: string) =>
  s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();

export type RoomErrors = Partial<Record<'code' | 'name' | 'capacity', string>>;

export function validateRoom(
  draft: RoomDraft,
  rooms: Room[],
  editingId: string | null,
): RoomErrors {
  const errors: RoomErrors = {};
  if (editingId === null) {
    if (!ROOM_CODE_PATTERN.test(draft.code.trim()))
      errors.code = 'Mã phòng chỉ gồm chữ viết hoa, số và dấu gạch dưới (ví dụ P101).';
    else if (rooms.some((r) => r.code === draft.code.trim()))
      errors.code = `Mã ${draft.code.trim()} đã có trong cơ sở.`;
  }
  if (draft.name.trim() === '') errors.name = 'Nhập tên phòng.';
  else if (rooms.some((r) => r.id !== editingId && foldName(r.name) === foldName(draft.name)))
    errors.name = 'Tên phòng này đã có trong cơ sở.';
  const cap = Number(draft.capacity);
  if (draft.capacity.trim() === '' || !Number.isInteger(cap) || cap <= 0)
    errors.capacity = 'Nhập sức chứa, là số lớn hơn 0.';
  return errors;
}

export function validateBranch(
  name: string,
  address: string,
): Partial<Record<'name' | 'address', string>> {
  const errors: Partial<Record<'name' | 'address', string>> = {};
  if (name.trim() === '') errors.name = 'Nhập tên hiển thị.';
  if (address.trim().length > ADDRESS_MAX) errors.address = `Địa chỉ tối đa ${ADDRESS_MAX} ký tự.`;
  return errors;
}

export const roomSummary = (rooms: Room[]) =>
  `${rooms.length} phòng (${rooms.filter((r) => r.is_active).length} đang dùng)`;
