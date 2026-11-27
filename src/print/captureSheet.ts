// Vẽ tờ bản in (DOM của khuôn K13) lên canvas để xuất PNG, không thêm thư viện (Chat duyệt 19/11 ở GV-07X).
// Đọc đúng vị trí trình duyệt đã dàn: nền, viền, ảnh và từng chữ; nhờ vậy bản ảnh khớp bản trên màn.

const SCALE = 2; // allow-number: nhân đôi độ phân giải ảnh cho rõ chữ

type Box = { x: number; y: number; w: number; h: number };

const visible = (color: string) => color !== 'transparent' && !/,\s*0\)$/.test(color);

function drawBox(ctx: CanvasRenderingContext2D, style: CSSStyleDeclaration, b: Box) {
  const radius = parseFloat(style.borderTopLeftRadius) || 0;
  const path = (box: Box) => {
    ctx.beginPath();
    if (radius && ctx.roundRect) ctx.roundRect(box.x, box.y, box.w, box.h, radius);
    else ctx.rect(box.x, box.y, box.w, box.h);
  };
  if (visible(style.backgroundColor)) {
    ctx.fillStyle = style.backgroundColor;
    path(b);
    ctx.fill();
  }
  // Khung bo góc viền đều bốn cạnh (nhãn đóng khung) thì vẽ một nét theo góc bo.
  const edge = (side: string) =>
    ['width', 'style', 'color'].map((k) => style.getPropertyValue(`border-${side}-${k}`)).join();
  const top = parseFloat(style.getPropertyValue('border-top-width')) || 0;
  if (radius && top && ['right', 'bottom', 'left'].every((side) => edge(side) === edge('top'))) {
    ctx.strokeStyle = style.getPropertyValue('border-top-color');
    ctx.lineWidth = top;
    path({ x: b.x + top / 2, y: b.y + top / 2, w: b.w - top, h: b.h - top });
    ctx.stroke();
    return;
  }
  const sides = [
    ['Top', b.x, b.y, b.x + b.w, b.y, 0, 1],
    ['Right', b.x + b.w, b.y, b.x + b.w, b.y + b.h, -1, 0],
    ['Bottom', b.x, b.y + b.h, b.x + b.w, b.y + b.h, 0, -1],
    ['Left', b.x, b.y, b.x, b.y + b.h, 1, 0],
  ] as const;
  for (const [side, x1, y1, x2, y2, inX, inY] of sides) {
    const width = parseFloat(style.getPropertyValue(`border-${side.toLowerCase()}-width`)) || 0;
    const kind = style.getPropertyValue(`border-${side.toLowerCase()}-style`);
    const color = style.getPropertyValue(`border-${side.toLowerCase()}-color`);
    if (!width || kind === 'none' || !visible(color)) continue;
    ctx.save();
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    if (kind === 'dotted' || kind === 'dashed') ctx.setLineDash([width, width * 2]);
    ctx.beginPath();
    ctx.moveTo(x1 + (inX * width) / 2, y1 + (inY * width) / 2);
    ctx.lineTo(x2 + (inX * width) / 2, y2 + (inY * width) / 2);
    ctx.stroke();
    ctx.restore();
  }
}

function drawText(
  ctx: CanvasRenderingContext2D,
  node: Text,
  style: CSSStyleDeclaration,
  toBox: (r: DOMRect) => Box,
) {
  ctx.font = `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
  ctx.fillStyle = style.color;
  ctx.textBaseline = 'middle';
  if ('letterSpacing' in ctx) {
    ctx.letterSpacing = style.letterSpacing === 'normal' ? '0px' : style.letterSpacing;
  }
  const upper = style.textTransform === 'uppercase';
  // Số thẳng cột (tabular-nums) canvas không vẽ được: vẽ từng ký tự, canh giữa ô của nó.
  const tabular = style.fontVariantNumeric.includes('tabular-nums');
  ctx.textAlign = tabular ? 'center' : 'left';
  const range = document.createRange();
  const paint = (from: number, to: number) => {
    range.setStart(node, from);
    range.setEnd(node, to);
    const rects = range.getClientRects();
    // Chữ bị ngắt giữa chừng qua hai dòng: vẽ từng ký tự theo đúng chỗ.
    if (rects.length > 1 && to - from > 1) {
      for (let i = from; i < to; i += 1) paint(i, i + 1);
      return;
    }
    const rect = rects[0];
    if (!rect) return;
    const box = toBox(rect);
    const text = node.data.slice(from, to);
    const x = tabular ? box.x + box.w / 2 : box.x;
    ctx.fillText(upper ? text.toLocaleUpperCase('vi') : text, x, box.y + box.h / 2, box.w + 1);
  };
  // Chỗ khác vẽ theo từng từ (dấu cách không ngắt dòng giữ trong từ).
  for (const match of node.data.matchAll(tabular ? /[^ \t\n\r]/g : /[^ \t\n\r]+/g)) {
    paint(match.index, match.index + match[0].length);
  }
}

/** Trả canvas nền trắng, đúng kích thước tờ giấy nhân đôi. Chờ phông và ảnh (logo) tải xong trước khi vẽ. */
export async function captureSheet(root: HTMLElement): Promise<HTMLCanvasElement> {
  await document.fonts?.ready;
  await Promise.all([...root.querySelectorAll('img')].map((img) => img.decode().catch(() => {})));

  const canvas = document.createElement('canvas');
  canvas.width = root.offsetWidth * SCALE;
  canvas.height = root.offsetHeight * SCALE;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Trình duyệt không hỗ trợ vẽ ảnh.');
  ctx.scale(SCALE, SCALE);
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, root.offsetWidth, root.offsetHeight);

  const origin = root.getBoundingClientRect();
  const zoom = origin.width / root.offsetWidth || 1;
  const toBox = (r: DOMRect): Box => ({
    x: (r.left - origin.left) / zoom,
    y: (r.top - origin.top) / zoom,
    w: r.width / zoom,
    h: r.height / zoom,
  });

  const walk = (el: Element) => {
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') return;
    const box = toBox(el.getBoundingClientRect());
    drawBox(ctx, style, box);
    if (el instanceof HTMLImageElement) {
      if (el.naturalWidth > 0) ctx.drawImage(el, box.x, box.y, box.w, box.h);
      return;
    }
    for (const child of el.childNodes) {
      if (child instanceof Element) walk(child);
      else if (child instanceof Text) drawText(ctx, child, style, toBox);
    }
  };
  walk(root);
  return canvas;
}
