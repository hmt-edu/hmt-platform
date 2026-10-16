// Luật kéo thả của Kanban (K2): chỉ đi tới, không lùi; cột "hệ thống tự chuyển" không thả vào được.
// Luật thật của từng loại bản ghi nằm ở hàm cơ sở dữ liệu; đây chỉ là chặn sớm ở giao diện cho gọn.
export type MoveCheck = { ok: true } | { ok: false; reason: string };

export type MoveRule = (from: string, to: string) => MoveCheck;

/**
 * Luật "chỉ đi tới" theo thứ tự cột. `systemOnly`: các cột do hệ thống tự chuyển (vd L6, L8) không thả tay vào.
 * Cấu hình theo từng loại bản ghi; khung không biết cột nào là cột hệ thống.
 */
export function forwardOnlyRule(order: string[], systemOnly: string[] = []): MoveRule {
  return (from, to) => {
    const a = order.indexOf(from);
    const b = order.indexOf(to);
    if (a < 0 || b < 0) return { ok: false, reason: 'Không có giai đoạn này.' };
    if (a === b) return { ok: false, reason: 'Thẻ đang ở giai đoạn này.' };
    if (systemOnly.includes(to)) {
      return { ok: false, reason: 'Giai đoạn này do hệ thống tự chuyển, không kéo tay vào được.' };
    }
    if (b < a) return { ok: false, reason: 'Chỉ đi tới, không lùi giai đoạn.' };
    return { ok: true };
  };
}
