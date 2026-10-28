// Số tiền bằng chữ cho bản in (K13). Chỉ đổi cách đọc của con số máy chủ đã tính; không tính tiền (R-TIEN-13).
const DIGITS: readonly string[] = [
  'không',
  'một',
  'hai',
  'ba',
  'bốn',
  'năm',
  'sáu',
  'bảy',
  'tám',
  'chín',
];
const UNITS = ['', 'nghìn', 'triệu', 'tỷ', 'nghìn tỷ', 'triệu tỷ'];

function digit(n: number): string {
  return DIGITS[n] ?? '';
}

/** Đọc một nhóm ba chữ số (0 đến 999). `full` = có nhóm lớn hơn đứng trước, nên đọc đủ "không trăm", "lẻ". */
function readGroup(n: number, full: boolean): string {
  const hundred = Math.floor(n / 100); // allow-number: cách đọc số tiếng Việt (trăm, nghìn), không phải số nghiệp vụ
  const ten = Math.floor((n % 100) / 10); // allow-number: cách đọc số tiếng Việt (trăm, nghìn), không phải số nghiệp vụ
  const unit = n % 10;
  const parts: string[] = [];
  if (hundred > 0 || full) parts.push(`${digit(hundred)} trăm`);
  if (ten > 1) {
    parts.push(`${digit(ten)} mươi`);
    if (unit === 1) parts.push('mốt');
    else if (unit === 4) parts.push('tư');
    else if (unit === 5) parts.push('lăm');
    else if (unit > 0) parts.push(digit(unit));
  } else if (ten === 1) {
    parts.push('mười');
    if (unit === 5) parts.push('lăm');
    else if (unit > 0) parts.push(digit(unit));
  } else if (unit > 0) {
    if (hundred > 0 || full) parts.push('lẻ');
    parts.push(digit(unit));
  }
  return parts.join(' ');
}

/** 13608000 → "Mười ba triệu sáu trăm lẻ tám nghìn đồng". Số âm, không nguyên hoặc quá lớn thì trả chuỗi rỗng. */
export function amountInWords(amount: number): string {
  if (!Number.isSafeInteger(amount) || amount < 0) return '';
  if (amount === 0) return 'Không đồng';
  const groups: number[] = [];
  for (let rest = amount; rest > 0; rest = Math.floor(rest / 1000)) groups.push(rest % 1000); // allow-number: cách đọc số tiếng Việt (trăm, nghìn), không phải số nghiệp vụ
  if (groups.length > UNITS.length) return '';
  const parts: string[] = [];
  for (let i = groups.length - 1; i >= 0; i--) {
    const value = groups[i] ?? 0;
    if (value === 0) continue;
    const text = readGroup(value, i < groups.length - 1);
    parts.push(UNITS[i] ? `${text} ${UNITS[i]}` : text);
  }
  const sentence = `${parts.join(' ')} đồng`;
  return sentence.charAt(0).toUpperCase() + sentence.slice(1);
}
