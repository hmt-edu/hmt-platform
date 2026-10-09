#!/usr/bin/env node
// Bộ dò số nghiệp vụ viết cứng.
// - Vùng "strict" (code nghiệp vụ + thân hàm SQL trong migration): chỉ cho các số trong `allowed`.
// - Vùng "ui" (giao diện): chỉ bắt số có |giá trị| >= `minAbsValue`.
// - Bỏ qua số trong chuỗi, comment, kiểu SQL như numeric(6,2).
// - Lối thoát: comment cùng dòng `// allow-number: <lý do>` hoặc `-- allow-number: <lý do>`.

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import ts from 'typescript';

/**
 * @typedef {{ value: number, raw: string, line: number, col: number }} NumberHit
 * @typedef {{ description?: string, include: string[], sqlFunctionBodies?: string[], exclude?: string[], allowed?: number[], minAbsValue?: number }} ZoneConfig
 * @typedef {{ ignoreDirs?: string[], zones: { strict: ZoneConfig, ui: ZoneConfig } }} CheckConfig
 * @typedef {'strict' | 'ui'} ZoneName
 * @typedef {{ zone: ZoneName, language: 'ts' | 'sql' }} Classification
 * @typedef {NumberHit & { file: string, zone: ZoneName }} Finding
 */

export const HINT = 'Đưa vào bảng Cài đặt (app.get_setting) hoặc thêm // allow-number: <lý do>';

// ---------------------------------------------------------------------------
// Glob
// ---------------------------------------------------------------------------

/**
 * Chuyển glob (hỗ trợ **, *, ?, {a,b}) thành RegExp, đường dẫn dùng "/".
 * @param {string} glob
 * @returns {RegExp}
 */
export function globToRegExp(glob) {
  let out = '';
  let i = 0;
  let braceDepth = 0;
  while (i < glob.length) {
    const ch = glob.charAt(i);
    if (ch === '*') {
      if (glob.charAt(i + 1) === '*') {
        const slashAfter = glob.charAt(i + 2) === '/';
        out += slashAfter ? '(?:.*/)?' : '.*';
        i += slashAfter ? 3 : 2;
        continue;
      }
      out += '[^/]*';
    } else if (ch === '?') {
      out += '[^/]';
    } else if (ch === '{') {
      braceDepth += 1;
      out += '(?:';
    } else if (ch === '}' && braceDepth > 0) {
      braceDepth -= 1;
      out += ')';
    } else if (ch === ',' && braceDepth > 0) {
      out += '|';
    } else {
      out += ch.replace(/[.+^$()|[\]\\]/g, '\\$&');
    }
    i += 1;
  }
  return new RegExp(`^${out}$`);
}

/**
 * @param {string} path
 * @param {string[] | undefined} globs
 * @returns {boolean}
 */
function matchesAny(path, globs) {
  return (globs ?? []).some((glob) => globToRegExp(glob).test(path));
}

/**
 * Xếp file vào vùng kiểm tra; null nếu không kiểm.
 * @param {string} relPath đường dẫn tương đối, dùng "/"
 * @param {CheckConfig} config
 * @returns {Classification | null}
 */
export function classifyFile(relPath, config) {
  const { strict, ui } = config.zones;
  if (!matchesAny(relPath, strict.exclude)) {
    if (matchesAny(relPath, strict.sqlFunctionBodies)) return { zone: 'strict', language: 'sql' };
    if (matchesAny(relPath, strict.include)) return { zone: 'strict', language: 'ts' };
  }
  if (matchesAny(relPath, ui.include) && !matchesAny(relPath, ui.exclude)) {
    return { zone: 'ui', language: 'ts' };
  }
  return null;
}

// ---------------------------------------------------------------------------
// Dò số trong TypeScript (dùng trình phân tích của TypeScript)
// ---------------------------------------------------------------------------

/**
 * @param {string} raw
 * @returns {number}
 */
function parseNumeric(raw) {
  const text = raw.replace(/_/g, '').replace(/n$/, '');
  return Number(text);
}

/**
 * Tìm mọi số literal trong code TS/TSX (bỏ qua chuỗi, template, comment, JSX text).
 * @param {string} source
 * @param {string} [fileName]
 * @returns {NumberHit[]}
 */
export function findNumbersInTs(source, fileName = 'file.tsx') {
  const kind = fileName.endsWith('.tsx') ? ts.ScriptKind.TSX : ts.ScriptKind.TS;
  const sourceFile = ts.createSourceFile(fileName, source, ts.ScriptTarget.Latest, true, kind);
  /** @type {NumberHit[]} */
  const hits = [];

  /** @param {ts.Node} node */
  const visit = (node) => {
    if (ts.isNumericLiteral(node) || ts.isBigIntLiteral(node)) {
      const parent = node.parent;
      const negative =
        ts.isPrefixUnaryExpression(parent) && parent.operator === ts.SyntaxKind.MinusToken;
      const anchor = negative ? parent : node;
      const start = anchor.getStart(sourceFile);
      const { line, character } = sourceFile.getLineAndCharacterOfPosition(start);
      const raw = negative ? `-${node.text}` : node.getText(sourceFile);
      const value = parseNumeric(node.getText(sourceFile));
      hits.push({ value: negative ? -value : value, raw, line: line + 1, col: character + 1 });
      return;
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return hits;
}

// ---------------------------------------------------------------------------
// Dò số trong thân hàm SQL ($$ ... $$ hoặc $tag$ ... $tag$)
// ---------------------------------------------------------------------------

const SQL_TYPE_MODIFIER_BEFORE =
  /\b(?:numeric|decimal|varchar|char|character|varying|bit|varbit|time|timetz|timestamp|timestamptz|interval|float)\s*\(\s*(?:\d+\s*,\s*)?$/i;
const DOLLAR_TAG = /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/;
const SQL_NUMBER = /^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/;
const IDENT_CHAR = /[A-Za-z0-9_$]/;

/**
 * Bỏ qua comment/chuỗi SQL tại vị trí i; trả về vị trí kết thúc, hoặc -1 nếu không phải.
 * @param {string} text
 * @param {number} i
 * @returns {number}
 */
function skipSqlNonCode(text, i) {
  const ch = text.charAt(i);
  const next = text.charAt(i + 1);
  if (ch === '-' && next === '-') {
    const end = text.indexOf('\n', i);
    return end === -1 ? text.length : end;
  }
  if (ch === '/' && next === '*') {
    let depth = 1;
    let j = i + 2;
    while (j < text.length && depth > 0) {
      if (text.startsWith('/*', j)) {
        depth += 1;
        j += 2;
      } else if (text.startsWith('*/', j)) {
        depth -= 1;
        j += 2;
      } else {
        j += 1;
      }
    }
    return j;
  }
  if (ch === "'" || ch === '"') {
    const escapeBackslash = ch === "'" && /[eE]/.test(text.charAt(i - 1));
    let j = i + 1;
    while (j < text.length) {
      const c = text.charAt(j);
      if (escapeBackslash && c === '\\') {
        j += 2;
        continue;
      }
      if (c === ch) {
        if (text.charAt(j + 1) === ch) {
          j += 2;
          continue;
        }
        return j + 1;
      }
      j += 1;
    }
    return text.length;
  }
  return -1;
}

/**
 * Tìm các khoảng dollar-quoted ở mức ngoài cùng.
 * @param {string} text
 * @param {number} from
 * @param {number} to
 * @returns {{ start: number, end: number }[]} khoảng nội dung (không gồm thẻ $tag$)
 */
function findDollarBodies(text, from, to) {
  /** @type {{ start: number, end: number }[]} */
  const bodies = [];
  let i = from;
  while (i < to) {
    const skipped = skipSqlNonCode(text, i);
    if (skipped !== -1) {
      i = skipped;
      continue;
    }
    if (text.charAt(i) === '$' && !IDENT_CHAR.test(text.charAt(i - 1))) {
      const match = DOLLAR_TAG.exec(text.slice(i, i + 64));
      if (match) {
        const tag = match[0];
        const bodyStart = i + tag.length;
        const close = text.indexOf(tag, bodyStart);
        const bodyEnd = close === -1 || close > to ? to : close;
        bodies.push({ start: bodyStart, end: bodyEnd });
        i = bodyEnd + tag.length;
        continue;
      }
    }
    i += 1;
  }
  return bodies;
}

/**
 * @param {string} text
 * @param {number} offset
 * @returns {{ line: number, col: number }}
 */
function lineColAt(text, offset) {
  let line = 1;
  let lastNewline = -1;
  for (let k = 0; k < offset; k += 1) {
    if (text.charCodeAt(k) === 10) {
      line += 1;
      lastNewline = k;
    }
  }
  return { line, col: offset - lastNewline };
}

/**
 * Dò số trong một thân hàm; chuỗi lồng (kể cả dollar-quoted lồng) bị bỏ qua.
 * @param {string} text
 * @param {number} start
 * @param {number} end
 * @param {NumberHit[]} hits
 */
function scanSqlCode(text, start, end, hits) {
  let i = start;
  while (i < end) {
    const skipped = skipSqlNonCode(text, i);
    if (skipped !== -1) {
      i = skipped;
      continue;
    }
    const ch = text.charAt(i);
    if (ch === '$') {
      const match = DOLLAR_TAG.exec(text.slice(i, i + 64));
      if (match && !IDENT_CHAR.test(text.charAt(i - 1))) {
        const close = text.indexOf(match[0], i + match[0].length);
        i = close === -1 || close > end ? end : close + match[0].length;
        continue;
      }
      // $1, $2: tham số vị trí, không phải số nghiệp vụ.
      i += 1;
      while (i < end && /[0-9]/.test(text.charAt(i))) i += 1;
      continue;
    }
    if (IDENT_CHAR.test(ch) && !/[0-9]/.test(ch)) {
      while (i < end && IDENT_CHAR.test(text.charAt(i))) i += 1;
      continue;
    }
    const numberMatch = /[0-9.]/.test(ch) ? SQL_NUMBER.exec(text.slice(i, end)) : null;
    if (numberMatch && !IDENT_CHAR.test(text.charAt(i - 1))) {
      const raw = numberMatch[0];
      const before = text.slice(Math.max(start, i - 64), i);
      if (!SQL_TYPE_MODIFIER_BEFORE.test(before)) {
        const minus = /(^|[^A-Za-z0-9_)\]\s])\s*-\s*$/.exec(before) ?? /^\s*-\s*$/.exec(before);
        const value = Number(raw);
        const anchor = minus ? i - (before.length - before.lastIndexOf('-')) : i;
        const { line, col } = lineColAt(text, anchor);
        hits.push({
          value: minus ? -value : value,
          raw: minus ? `-${raw}` : raw,
          line,
          col,
        });
      }
      i += raw.length;
      continue;
    }
    i += 1;
  }
}

/**
 * Tìm số trong các thân hàm/khối dollar-quoted của file SQL. SQL ngoài thân hàm không kiểm.
 * @param {string} source
 * @returns {NumberHit[]}
 */
export function findNumbersInSqlBodies(source) {
  /** @type {NumberHit[]} */
  const hits = [];
  for (const body of findDollarBodies(source, 0, source.length)) {
    scanSqlCode(source, body.start, body.end, hits);
  }
  return hits;
}

// ---------------------------------------------------------------------------
// Luật vùng + lối thoát allow-number
// ---------------------------------------------------------------------------

const ALLOW_TS = /\/\/\s*allow-number:\s*\S/;
const ALLOW_SQL = /--\s*allow-number:\s*\S/;

/**
 * @param {string} source
 * @param {'ts' | 'sql'} language
 * @returns {Set<number>} các dòng (đếm từ 1) có lối thoát hợp lệ
 */
function allowedLines(source, language) {
  const pattern = language === 'sql' ? ALLOW_SQL : ALLOW_TS;
  /** @type {Set<number>} */
  const lines = new Set();
  source.split('\n').forEach((text, index) => {
    if (pattern.test(text)) lines.add(index + 1);
  });
  return lines;
}

/**
 * @param {number} value
 * @param {ZoneName} zone
 * @param {CheckConfig} config
 * @returns {boolean}
 */
function isViolation(value, zone, config) {
  if (zone === 'strict') {
    const allowed = config.zones.strict.allowed ?? [];
    return !allowed.some((n) => Object.is(n, value) || n === value);
  }
  const threshold = config.zones.ui.minAbsValue ?? Number.POSITIVE_INFINITY;
  return Math.abs(value) >= threshold;
}

/**
 * Kiểm một file (hàm thuần, không đọc đĩa).
 * @param {string} relPath
 * @param {string} source
 * @param {CheckConfig} config
 * @returns {Finding[]}
 */
export function checkSource(relPath, source, config) {
  const classification = classifyFile(relPath, config);
  if (!classification) return [];
  const { zone, language } = classification;
  const hits =
    language === 'sql' ? findNumbersInSqlBodies(source) : findNumbersInTs(source, relPath);
  const escapes = allowedLines(source, language);
  return hits
    .filter((hit) => !escapes.has(hit.line) && isViolation(hit.value, zone, config))
    .map((hit) => ({ ...hit, file: relPath, zone }));
}

// ---------------------------------------------------------------------------
// Duyệt thư mục + CLI
// ---------------------------------------------------------------------------

/**
 * @param {string} rootDir
 * @param {CheckConfig} config
 * @returns {string[]} đường dẫn tương đối, dùng "/"
 */
export function listFiles(rootDir, config) {
  const ignore = new Set(config.ignoreDirs ?? []);
  /** @type {string[]} */
  const files = [];
  /** @param {string} dir */
  const walk = (dir) => {
    for (const name of readdirSync(dir)) {
      const abs = join(dir, name);
      const rel = relative(rootDir, abs).split(sep).join('/');
      if (ignore.has(rel) || ignore.has(name)) continue;
      if (statSync(abs).isDirectory()) walk(abs);
      else files.push(rel);
    }
  };
  walk(rootDir);
  return files.sort();
}

/**
 * @param {string} rootDir
 * @param {CheckConfig} config
 * @returns {Finding[]}
 */
export function checkProject(rootDir, config) {
  return listFiles(rootDir, config).flatMap((rel) =>
    classifyFile(rel, config)
      ? checkSource(rel, readFileSync(join(rootDir, rel), 'utf8'), config)
      : [],
  );
}

/**
 * @param {Finding} finding
 * @returns {string}
 */
export function formatFinding(finding) {
  return `${finding.file}:${finding.line}:${finding.col}  ${finding.raw}  [${finding.zone}]\n  → ${HINT}`;
}

function main() {
  const rootDir = resolve(fileURLToPath(new URL('..', import.meta.url)));
  /** @type {unknown} */
  const parsed = JSON.parse(readFileSync(join(rootDir, 'hardcode-check.config.json'), 'utf8'));
  const config = /** @type {CheckConfig} */ (parsed);
  const findings = checkProject(rootDir, config);
  if (findings.length === 0) {
    console.log('check:hardcode: không thấy số nghiệp vụ viết cứng.');
    return;
  }
  for (const finding of findings) console.error(formatFinding(finding));
  console.error(`\ncheck:hardcode: ${findings.length} chỗ cần xử lý.`);
  process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main();
}
