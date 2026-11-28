import { Button } from '../../ui/Button';
import { Code } from '../../ui/Data';
import { Popover } from '../../ui/Overlays';

// Máy chủ trả các mã ghi danh nối bằng dấu phẩy: bảng chỉ hiện số đếm, mã nằm trong khung nổi.
export function EnrollmentCodes({ codes }: { codes: string }) {
  const list = codes.split(', ');
  return (
    <Popover label="Mã ghi danh" trigger={<Button size="sm">{list.length} ghi danh</Button>}>
      <ul className="flex flex-col gap-1">
        {list.map((code) => (
          <li key={code}>
            <Code>{code}</Code>
          </li>
        ))}
      </ul>
    </Popover>
  );
}
