#!/usr/bin/env node
// Bộ dò mã kỹ thuật lộ trong chữ cho người dùng (mẫu B4 «rà soát», F-23-15): mã luật (R-GV-08), mã quyết định (Q-31), mã màn (BUOI-14, TS-07),
// tên bảng/hàm DB (app.user_role) KHÔNG được nằm trong chuỗi chữ hiển thị ở src/**/*.ts, *.tsx. Người dùng không biết các mã này; nghiệp vụ cần ghi mã thì
// ghi ở comment hoặc tài liệu, không ở giao diện.
// Bỏ qua: comment, bài kiểm thử, trang thử dev, chuỗi là giá trị `screenCode`/`*_SCREEN_CODE` (khoá nội bộ của khuôn danh sách, không hiện ra),
// nhãn tiếng Anh giữ nguyên ở config/nhan-tieng-anh-giu-nguyen.json (một file duy nhất cho mọi script dò chữ giao diện).
// Lối thoát hiếm: comment cùng dòng `// allow-code: <lý do>`.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import ts from 'typescript';

export const SCREEN_PREFIXES = 'TS|BH|TC|CS|GD|LOP|BUOI|KH|QT|CH|BC|GV|HT|PH|CHUNG|CSN|DN';
/** Mẫu mã kỹ thuật: mã luật, mã quyết định, mã màn, tên bảng/hàm trong lược đồ app. */
export const PATTERNS = [
  { name: 'mã luật', re: /\bR-[A-Z][A-Z0-9]+(?:-[A-Z]+)?-\d+\b/ },
  { name: 'mã quyết định', re: /\bQ-\d+\b/ },
  { name: 'mã màn', re: new RegExp(`(?<![A-Z]-)\\b(?:${SCREEN_PREFIXES})-\\d{2}[A-Za-z]?\\b`) },
  { name: 'tên bảng, hàm DB', re: /\bapp\.[a-z_]{3,}\b/ },
];

const SKIP_PROP = new Set(['screenCode', 'code']);

/** @param {ts.Node} node */
function isInternalValue(node) {
  const parent = node.parent;
  if (!parent) return false;
  if (
    ts.isPropertyAssignment(parent) &&
    ts.isIdentifier(parent.name) &&
    SKIP_PROP.has(parent.name.text)
  )
    return true;
  if (
    ts.isVariableDeclaration(parent) &&
    ts.isIdentifier(parent.name) &&
    /SCREEN_CODE$/.test(parent.name.text)
  )
    return true;
  if (ts.isImportDeclaration(parent) || ts.isExportDeclaration(parent)) return true;
  return false;
}

/**
 * Tìm mã kỹ thuật trong chuỗi chữ của một file TSX.
 * @param {string} text nội dung file
 * @param {string[]} [keep] nhãn tiếng Anh giữ nguyên (cho qua)
 * @returns {{ line: number, kind: string, found: string }[]}
 */
export function findLeaks(text, keep = []) {
  const sf = ts.createSourceFile('x.tsx', text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  const lines = text.split('\n');
  /** @type {{ line: number, kind: string, found: string }[]} */
  const hits = [];
  /** @param {ts.Node} node @param {string} value */
  const check = (node, value) => {
    const line = sf.getLineAndCharacterOfPosition(node.getStart(sf)).line;
    if (/allow-code:/.test(lines[line] ?? '')) return;
    for (const p of PATTERNS) {
      const m = p.re.exec(value);
      if (m && !keep.includes(m[0])) hits.push({ line: line + 1, kind: p.name, found: m[0] });
    }
  };
  /** @param {ts.Node} node */
  const visit = (node) => {
    if (
      (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) &&
      !isInternalValue(node)
    )
      check(node, node.text);
    else if (ts.isTemplateHead(node) || ts.isTemplateMiddle(node) || ts.isTemplateTail(node))
      check(node, node.text);
    else if (ts.isJsxText(node)) check(node, node.text);
    ts.forEachChild(node, visit);
  };
  visit(sf);
  return hits;
}

function main() {
  const root = resolve(fileURLToPath(import.meta.url), '..', '..');
  const keep = JSON.parse(
    readFileSync(join(root, 'config/nhan-tieng-anh-giu-nguyen.json'), 'utf8'),
  ).nhan;
  /** @type {{ file: string, line: number, kind: string, found: string }[]} */
  const findings = [];
  /** @param {string} dir */
  const walk = (dir) => {
    for (const name of readdirSync(dir)) {
      const abs = join(dir, name);
      const rel = relative(root, abs).split(sep).join('/');
      if (statSync(abs).isDirectory()) {
        if (rel === 'src/pages/dev') continue;
        walk(abs);
      } else if (/\.tsx?$/.test(rel) && !/\.(test|spec)\./.test(rel) && !rel.endsWith('.d.ts')) {
        for (const h of findLeaks(readFileSync(abs, 'utf8'), keep))
          findings.push({ file: rel, ...h });
      }
    }
  };
  walk(join(root, 'src'));
  for (const f of findings)
    console.log(`${f.file}:${f.line}  ${f.kind} «${f.found}» nằm trong chữ hiển thị`);
  if (findings.length > 0) {
    console.log(
      `\ncheck:ma-ky-thuat: ${findings.length} chỗ. Bỏ mã khỏi chữ cho người dùng (ghi ở comment/tài liệu), hoặc // allow-code: <lý do>.`,
    );
    process.exit(1);
  }
  console.log('check:ma-ky-thuat: không thấy mã luật, mã màn, tên bảng DB trong chữ hiển thị.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
