// GV-07X: vẽ phiếu nhận xét thành ảnh PNG (canvas) hoặc trang in A4 (PDF qua hộp thoại in của trình duyệt; Chat duyệt 19/11: không thêm thư viện).
// File tạo ngay trên trình duyệt, không lưu lên máy chủ. Mẫu có logo HMT và tên trung tâm, KHÔNG chữ ký. Nội dung do exportCard.ts dựng (không in điểm trung bình).
import { wrapText, type ExportCard } from './exportCard';

const CENTER_NAME = 'HMT Edu';
const WIDTH = 794; // allow-number: khổ A4 96 dpi (px)
const SCALE = 2; // allow-number: nhân đôi độ phân giải ảnh cho rõ chữ
const PAD = 48; // allow-number: lề phiếu (px)
const LINE = 24; // allow-number: cao một dòng chữ (px)
const FONT = '"Be Vietnam Pro", "Inter", system-ui, sans-serif';

function escapeHtml(t: string): string {
  return t
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Vẽ một phiếu lên canvas mới và trả về canvas (chiều cao theo nội dung). `logo` có thể null (chưa tải được). */
export function drawCard(card: ExportCard, logo: HTMLImageElement | null): HTMLCanvasElement {
  const measureCanvas = document.createElement('canvas');
  const m = measureCanvas.getContext('2d');
  if (!m) throw new Error('Trình duyệt không hỗ trợ vẽ ảnh.');
  m.font = `15px ${FONT}`;
  const inner = WIDTH - PAD * 2;
  const wrap = (t: string) => wrapText(t, inner, (s) => m.measureText(s).width);

  const blocks: {
    kind: 'title' | 'sub' | 'name' | 'section' | 'row' | 'text';
    a: string;
    b?: string;
  }[] = [
    { kind: 'title', a: card.title },
    { kind: 'sub', a: card.subtitle },
    { kind: 'name', a: card.studentName },
  ];
  for (const sec of card.sections) {
    if (sec.title) blocks.push({ kind: 'section', a: sec.title });
    for (const r of sec.rows)
      blocks.push(
        r.value === '' ? { kind: 'text', a: r.label } : { kind: 'row', a: r.label, b: r.value },
      );
  }
  if (card.message)
    blocks.push({ kind: 'section', a: 'Lời nhắn' }, { kind: 'text', a: card.message });
  if (card.improvement)
    blocks.push(
      { kind: 'section', a: 'Định hướng cải thiện' },
      { kind: 'text', a: card.improvement },
    );

  let height = PAD + 56; // allow-number: chừa chỗ logo và tên trung tâm
  for (const b of blocks) {
    if (b.kind === 'text') height += wrap(b.a).length * LINE;
    else height += b.kind === 'title' ? 34 : b.kind === 'section' ? 36 : LINE + 4; // allow-number: khoảng cách các khối
  }
  height += PAD;

  const canvas = document.createElement('canvas');
  canvas.width = WIDTH * SCALE;
  canvas.height = Math.max(height, 320) * SCALE; // allow-number: chiều cao tối thiểu
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Trình duyệt không hỗ trợ vẽ ảnh.');
  ctx.scale(SCALE, SCALE);
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, WIDTH, canvas.height / SCALE);
  let y = PAD;
  if (logo) ctx.drawImage(logo, PAD, y - 8, 96, 36); // allow-number: kích thước logo
  ctx.fillStyle = '#211C16';
  ctx.font = `600 16px ${FONT}`;
  ctx.textAlign = 'right';
  ctx.fillText(CENTER_NAME, WIDTH - PAD, y + 16); // allow-number: căn tên trung tâm
  ctx.textAlign = 'left';
  y += 56; // allow-number: dưới đầu phiếu
  for (const b of blocks) {
    if (b.kind === 'title') {
      ctx.font = `700 22px ${FONT}`;
      ctx.fillStyle = '#EF6925';
      ctx.fillText(b.a, PAD, y + 20);
      y += 34;
    } else if (b.kind === 'sub') {
      ctx.font = `14px ${FONT}`;
      ctx.fillStyle = '#6b6258';
      ctx.fillText(b.a, PAD, y + 14);
      y += LINE + 4;
    } else if (b.kind === 'name') {
      ctx.font = `700 18px ${FONT}`;
      ctx.fillStyle = '#211C16';
      ctx.fillText(b.a, PAD, y + 16);
      y += LINE + 4;
    } else if (b.kind === 'section') {
      ctx.font = `700 14px ${FONT}`;
      ctx.fillStyle = '#6b6258';
      ctx.fillText(b.a.toUpperCase(), PAD, y + 22);
      y += 36;
    } else if (b.kind === 'row') {
      ctx.font = `15px ${FONT}`;
      ctx.fillStyle = '#211C16';
      ctx.fillText(b.a, PAD, y + 16);
      ctx.textAlign = 'right';
      ctx.font = `700 15px ${FONT}`;
      ctx.fillText(b.b ?? '', WIDTH - PAD, y + 16);
      ctx.textAlign = 'left';
      y += LINE + 4;
    } else {
      ctx.font = `15px ${FONT}`;
      ctx.fillStyle = '#211C16';
      for (const line of wrap(b.a)) {
        ctx.fillText(line, PAD, y + 16);
        y += LINE;
      }
    }
  }
  return canvas;
}

/** Tải canvas về máy dạng PNG (không qua máy chủ). */
export function downloadCanvas(canvas: HTMLCanvasElement, fileName: string): Promise<void> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (!blob) {
        reject(new Error('Không tạo được ảnh.'));
        return;
      }
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = fileName;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      resolve();
    }, 'image/png');
  });
}

/** HTML in A4: mỗi phiếu một trang (ngắt trang), có logo và tên trung tâm. Giáo viên chọn «Lưu thành PDF» ở hộp thoại in. */
export function cardsToPrintHtml(cards: ExportCard[], logoUrl: string): string {
  const page = (c: ExportCard) => {
    const sections = c.sections
      .map(
        (s) =>
          `${s.title ? `<h3>${escapeHtml(s.title)}</h3>` : ''}<table>${s.rows
            .map((r) =>
              r.value === ''
                ? `<tr><td colspan="2">${escapeHtml(r.label)}</td></tr>`
                : `<tr><td>${escapeHtml(r.label)}</td><td class="v">${escapeHtml(r.value)}</td></tr>`,
            )
            .join('')}</table>`,
      )
      .join('');
    const msg = c.message
      ? `<h3>Lời nhắn</h3><p>${escapeHtml(c.message).replace(/\n/g, '<br>')}</p>`
      : '';
    const imp = c.improvement
      ? `<h3>Định hướng cải thiện</h3><p>${escapeHtml(c.improvement).replace(/\n/g, '<br>')}</p>`
      : '';
    return `<section class="p"><header><img src="${escapeHtml(logoUrl)}" alt=""><b>${escapeHtml(CENTER_NAME)}</b></header><h1>${escapeHtml(c.title)}</h1><p class="s">${escapeHtml(c.subtitle)}</p><h2>${escapeHtml(c.studentName)}</h2>${sections}${msg}${imp}</section>`;
  };
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>Nhận xét</title><style>
@page{size:A4;margin:16mm}body{font-family:${FONT};color:#211C16;margin:0}
.p{page-break-after:always}.p:last-child{page-break-after:auto}
header{display:flex;justify-content:space-between;align-items:center;margin-bottom:12px}header img{height:36px}
h1{font-size:22px;color:#EF6925;margin:8px 0 2px}.s{color:#6b6258;margin:0 0 10px}h2{font-size:18px;margin:6px 0}
h3{font-size:13px;color:#6b6258;text-transform:uppercase;margin:14px 0 4px}table{width:100%;border-collapse:collapse}td{padding:3px 0;font-size:15px}.v{text-align:right;font-weight:700}p{font-size:15px;line-height:1.5;margin:0}
</style></head><body>${cards.map(page).join('')}</body></html>`;
}

/** In qua khung ẩn (không mở cửa sổ mới nên không bị chặn bật lên): hộp thoại in của trình duyệt cho phép Lưu thành PDF. */
export function printHtml(html: string): Promise<void> {
  return new Promise((resolve) => {
    const frame = document.createElement('iframe');
    frame.setAttribute('aria-hidden', 'true');
    frame.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0';
    frame.onload = () => {
      const w = frame.contentWindow;
      if (w) {
        w.focus();
        w.print();
      }
      window.setTimeout(() => {
        frame.remove();
        resolve();
      }, 1000); // allow-number: chờ hộp thoại in nhận khung trước khi dọn (mili giây)
    };
    frame.srcdoc = html;
    document.body.appendChild(frame);
  });
}

/** Tải logo thành ảnh để vẽ lên canvas; lỗi tải thì trả null (phiếu vẫn xuất, không logo). */
export function loadImage(url: string): Promise<HTMLImageElement | null> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = url;
  });
}
