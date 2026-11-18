// Luật axe `label-content-name-mismatch` (axe-core 4.14): nút có aria-label thì nhãn phải CHỨA chữ đang hiện trên nút.
// Bài quét tĩnh các tệp đã từng vi phạm, để lỗi không quay lại (kiểm thật bằng axe ở Playwright).
import { describe, expect, it } from 'vitest';
import detailSrc from './Detail.tsx?raw';
import reviewSrc from '../pages/gv/ReviewGradingPage.tsx?raw';
import quoteGridSrc from '../pages/bao-gia/QuoteLineGrid.tsx?raw';
import calendarSrc from '../list/Calendar.tsx?raw';
import scheduleSrc from '../pages/gv/TeacherSchedulePage.tsx?raw';

const files: Record<string, string> = {
  'src/record/Detail.tsx': detailSrc,
  'src/pages/gv/ReviewGradingPage.tsx': reviewSrc,
  'src/pages/bao-gia/QuoteLineGrid.tsx': quoteGridSrc,
  'src/list/Calendar.tsx': calendarSrc,
  'src/pages/gv/TeacherSchedulePage.tsx': scheduleSrc,
};
const read = (p: string) => files[p] ?? '';

describe('nhãn nút khớp chữ hiển thị (axe label-content-name-mismatch)', () => {
  it('nút liên kết của bản ghi (Detail.tsx) không đặt aria-label «Nhãn: số» riêng', () => {
    expect(read('src/record/Detail.tsx')).not.toMatch(
      /aria-label=\{`\$\{item\.label\}: \$\{item\.count\}`\}/,
    );
  });
  it('nút Bật/Tắt tiêu chí (chấm nhận xét) có nhãn bắt đầu bằng chữ đang hiện', () => {
    const s = read('src/pages/gv/ReviewGradingPage.tsx');
    expect(s).toContain("'Đang áp dụng' : 'Không áp dụng cả buổi'}: ${on ?");
  });
  it('nút chọn gói của lưới dòng (QuoteLineGrid) có nhãn chứa chữ gói đang hiện', () => {
    const s = read('src/pages/bao-gia/QuoteLineGrid.tsx');
    expect(s).toContain('(Gói dòng ${String(index + 1)})');
  });
  it('thẻ lịch và dải ngày GV-03 không còn aria-label riêng lệch chữ hiển thị', () => {
    expect(read('src/list/Calendar.tsx')).not.toMatch(
      /aria-label=\{`\$\{kindLabel\}: \$\{event\.title\}/,
    );
    expect(read('src/pages/gv/TeacherSchedulePage.tsx')).not.toMatch(
      /aria-pressed=\{d === selected\}\s*aria-label=/,
    );
  });
});
