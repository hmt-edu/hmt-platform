// Hộp và cảnh báo trùng số điện thoại (TS-14), dùng chung cho tạo lead và tạo cơ hội trực tiếp.
import { FromLink } from '../../layout/FromLink';

// E67: hồ sơ ngoài phạm vi (visible = false) máy chủ KHÔNG trả id, mã, tên, cơ sở; người xem chỉ biết «đã có trong hệ thống».
export type Duplicate = {
  kind: 'LEAD' | 'PARENT';
  id: string | null;
  code: string | null;
  label: string | null;
  branch_code: string | null;
  visible: boolean;
};

/** Hai nhóm của hộp trùng SĐT (TS-14): lead đã có, phụ huynh đã có; hồ sơ ngoài phạm vi chỉ lộ mã và cơ sở. */
export function duplicateGroups(rows: Duplicate[]) {
  const line = (d: Duplicate) =>
    d.visible ? (
      d.kind === 'LEAD' ? (
        <FromLink to={`/crm/lead/${d.id}`} className="font-medium text-link hover:underline">
          {d.code} · {d.label}
        </FromLink>
      ) : (
        `${d.code} · ${d.label}`
      )
    ) : (
      'Hồ sơ ngoài phạm vi bạn xem (không hiện mã, tên, cơ sở)'
    );
  return [
    { title: 'Lead đã có', lines: rows.filter((d) => d.kind === 'LEAD').map(line) },
    { title: 'Phụ huynh đã có', lines: rows.filter((d) => d.kind === 'PARENT').map(line) },
  ].filter((g) => g.lines.length > 0);
}
