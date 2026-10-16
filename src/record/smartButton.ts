// Quy tắc smart button của K3 (anh Trường chốt 16/10): bấm nút liên kết có số đếm thì
// - nhiều bản ghi: mở danh sách K1 đã lọc theo bản ghi cha (chip "Cơ hội: CO000121", đường dẫn "Cơ hội / CO000121 / Lịch hẹn");
// - đúng 1 bản ghi: mở thẳng bản ghi đó;
// - 0 bản ghi: chưa chốt, là TUỲ CHỌN của khung; tạm mở danh sách rỗng có câu "Chưa có …".
export type SmartZeroBehavior = 'empty-list' | 'disabled';
export type SmartTarget = 'list' | 'record' | 'empty-list' | 'none';

export function smartTarget(count: number, zero: SmartZeroBehavior = 'empty-list'): SmartTarget {
  if (count > 1) return 'list';
  if (count === 1) return 'record';
  return zero === 'empty-list' ? 'empty-list' : 'none';
}
