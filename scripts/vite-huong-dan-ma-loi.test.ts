import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { buildErrorCodes } from './vite-huong-dan-ma-loi.ts';

describe('Tra mã lỗi tự sinh từ migration (A-23-42 phần 3)', () => {
  it('lấy mã + câu mới nhất, bỏ trùng, gắn bài có nhắc mã', () => {
    const root = mkdtempSync(join(tmpdir(), 'ml-'));
    const mig = join(root, 'mig');
    const doc = join(root, 'doc');
    mkdirSync(mig);
    mkdirSync(doc);
    writeFileSync(
      join(mig, '001.sql'),
      "perform app.raise_error('HMT_A', 'Câu cũ.');\n-- HMT_CHI_TRONG_CHU_THICH\n",
    );
    writeFileSync(
      join(mig, '002.sql'),
      "perform app.raise_error('HMT_A', 'Câu mới.');\nperform app.raise_error('HMT_A', 'Câu cũ.');\nperform app.raise_error('HMT_B', 'Bạn không có ''quyền''.');",
    );
    writeFileSync(
      join(doc, 'x.md'),
      '---\ntitle: Bài X\ngroup: vai\n---\n\n| HMT_B | nghĩa |\nHMT_KHONG_CO_TRONG_DB\n',
    );
    const out = buildErrorCodes(mig, doc);
    expect(out.map((e) => e.code)).toEqual(['HMT_A', 'HMT_B', 'HMT_CHI_TRONG_CHU_THICH']);
    expect(out[0]?.messages).toEqual(['Câu mới.', 'Câu cũ.']);
    expect(out[1]?.messages).toEqual(["Bạn không có 'quyền'."]);
    expect(out[1]?.guides).toEqual([{ slug: 'x', title: 'Bài X' }]);
    expect(out[0]?.guides).toEqual([]);
  });
});
