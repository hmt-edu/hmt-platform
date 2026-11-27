#!/usr/bin/env node
// Đếm chỗ mở trang CRM mà không mang đường dẫn của trang gốc: `navigate('/crm/…')` và `<Link to="/crm/…">` không có `state`.
// Chỉ BÁO số, không trượt CI (chưa dọn hết). Chỗ cố ý dựng đường dẫn từ menu: ghi `// duong-dan-menu: <lý do>` cùng dòng hoặc dòng trên.
// Giới hạn: địa chỉ dựng qua hàm (classPath, studentPath…) chưa nhận ra.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import ts from 'typescript';

/** @param {ts.Node | undefined} node */
function mentionsCrm(node) {
  return node !== undefined && /['"`]\/crm\//.test(node.getText());
}

/**
 * @param {string} source
 * @param {string} file
 * @returns {{ line: number, kind: 'navigate' | 'Link' }[]}
 */
export function scanSource(source, file = 'x.tsx') {
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  const lines = source.split('\n');
  /** @type {{ line: number, kind: 'navigate' | 'Link' }[]} */
  const found = [];
  /** @param {ts.Node} node @param {'navigate' | 'Link'} kind */
  const add = (node, kind) => {
    const line = tree.getLineAndCharacterOfPosition(node.getStart()).line;
    const around = `${lines[line - 1] ?? ''}\n${lines[line] ?? ''}`;
    if (!around.includes('duong-dan-menu:')) found.push({ line: line + 1, kind });
  };
  /** @param {ts.Node} node */
  const visit = (node) => {
    if (
      ts.isCallExpression(node) &&
      node.expression.getText() === 'navigate' &&
      mentionsCrm(node.arguments[0]) &&
      !node.arguments[1]?.getText().includes('state')
    )
      add(node, 'navigate');
    if (
      (ts.isJsxOpeningElement(node) || ts.isJsxSelfClosingElement(node)) &&
      node.tagName.getText() === 'Link'
    ) {
      const attrs = node.attributes.properties.filter(ts.isJsxAttribute);
      const to = attrs.find((a) => a.name.getText() === 'to');
      if (mentionsCrm(to?.initializer) && !attrs.some((a) => a.name.getText() === 'state'))
        add(node, 'Link');
    }
    ts.forEachChild(node, visit);
  };
  visit(tree);
  return found;
}

/** @param {string} dir @returns {string[]} */
function filesIn(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return filesIn(path);
    return /\.tsx?$/.test(name) && !/\.test\./.test(name) ? [path] : [];
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const found = ['src/pages', 'src/features']
    .flatMap(filesIn)
    .flatMap((file) =>
      scanSource(readFileSync(file, 'utf8'), file).map(
        (f) => `${relative('.', file)}:${f.line} ${f.kind}`,
      ),
    );
  if (process.argv.includes('--chi-tiet')) console.log(found.join('\n'));
  console.log(`check:duong-dan: ${found.length} chỗ mở trang CRM không mang đường dẫn trang gốc.`);
}
