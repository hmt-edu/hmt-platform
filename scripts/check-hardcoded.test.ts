// @vitest-environment node
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  checkSource,
  classifyFile,
  findNumbersInSqlBodies,
  findNumbersInTs,
  globToRegExp,
} from './check-hardcoded.mjs';

type CheckConfig = Parameters<typeof checkSource>[2];

const config = JSON.parse(
  readFileSync(new URL('../hardcode-check.config.json', import.meta.url), 'utf8'),
) as CheckConfig;

const DOMAIN_FILE = 'src/domain/hours.ts';
const MIGRATION_FILE = 'supabase/migrations/20990101000000_fixture.sql';
const UI_FILE = 'src/pages/Fixture.tsx';

function values(relPath: string, source: string): number[] {
  return checkSource(relPath, source, config).map((finding) => finding.value);
}

describe('globToRegExp / classifyFile', () => {
  it('khớp glob có ** và {a,b}', () => {
    expect(globToRegExp('src/**/*.{ts,tsx}').test('src/a/b/c.tsx')).toBe(true);
    expect(globToRegExp('src/**/*.{ts,tsx}').test('src/c.ts')).toBe(true);
    expect(globToRegExp('src/**/*.{ts,tsx}').test('src/c.js')).toBe(false);
  });

  it('xếp file đúng vùng', () => {
    expect(classifyFile(DOMAIN_FILE, config)).toEqual({ zone: 'strict', language: 'ts' });
    expect(classifyFile('supabase/functions/x/index.ts', config)).toEqual({
      zone: 'strict',
      language: 'ts',
    });
    expect(classifyFile(MIGRATION_FILE, config)).toEqual({ zone: 'strict', language: 'sql' });
    expect(classifyFile(UI_FILE, config)).toEqual({ zone: 'ui', language: 'ts' });
    expect(classifyFile('src/pages/Fixture.test.tsx', config)).toBeNull();
    expect(classifyFile('src/vite-env.d.ts', config)).toBeNull();
    expect(classifyFile('src/domain/hours.test.ts', config)).toBeNull();
    expect(classifyFile('vite.config.ts', config)).toBeNull();
  });
});

describe('vùng strict: TypeScript', () => {
  it('bắt số 2', () => {
    const findings = checkSource(DOMAIN_FILE, 'export const maxEarly = 2;\n', config);
    expect(findings).toHaveLength(1);
    expect(findings[0]).toMatchObject({ value: 2, line: 1, col: 25, zone: 'strict' });
  });

  it('cho 0, 1, -1', () => {
    expect(values(DOMAIN_FILE, 'const a = 0; const b = 1; const c = -1; const d = x - 1;')).toEqual(
      [],
    );
  });

  it('bắt -2 và số thập phân', () => {
    expect(values(DOMAIN_FILE, 'const a = -2; const b = 1.5;')).toEqual([-2, 1.5]);
  });

  it('bỏ qua số trong chuỗi, template, comment', () => {
    const source = [
      "const a = 'giá 200';",
      'const b = `mã ${prefix}-2`;',
      '// 300 buổi',
      '/* 400 */',
    ].join('\n');
    expect(values(DOMAIN_FILE, source)).toEqual([]);
  });

  it('vẫn bắt số trong biểu thức của template', () => {
    expect(values(DOMAIN_FILE, 'const s = `${hours * 2}`;')).toEqual([2]);
  });
});

describe('vùng strict: thân hàm SQL', () => {
  const sql = (body: string) => `create function f() returns int language sql as $$\n${body}\n$$;`;

  it('bắt số 2 trong thân hàm', () => {
    const findings = checkSource(MIGRATION_FILE, sql('  select 2;'), config);
    expect(findings).toHaveLength(1);
    expect(findings[0]).toMatchObject({ value: 2, line: 2, col: 10, zone: 'strict' });
  });

  it('bắt số trong thân hàm có thẻ $tag$', () => {
    const source = 'do $body$ begin perform pg_sleep(5); end $body$;';
    expect(values(MIGRATION_FILE, source)).toEqual([5]);
  });

  it('cho 0, 1, -1 và tham số $1', () => {
    expect(values(MIGRATION_FILE, sql('select 0, 1, -1, $2, col1 where id = $1;'))).toEqual([]);
  });

  it('bỏ qua kiểu numeric(6,2), varchar(50)', () => {
    expect(
      values(MIGRATION_FILE, sql('select x::numeric(6,2), y::varchar(50), z::numeric(6, 2);')),
    ).toEqual([]);
  });

  it('bỏ qua số trong chuỗi và comment trong thân hàm', () => {
    expect(
      values(MIGRATION_FILE, sql("select 'gói 6 tháng'; -- 30 phút\n /* 8 giờ */ select E'\\'7';")),
    ).toEqual([]);
  });

  it('không kiểm SQL ngoài thân hàm', () => {
    const source = [
      'create table t (id smallint check (id = 7), amount numeric(12,2) default 500);',
      "insert into app.settings (key, value) values ('max_early_sessions', 2);",
      sql('select 1;'),
    ].join('\n');
    expect(values(MIGRATION_FILE, source)).toEqual([]);
  });

  it('tìm được số trong nhiều thân hàm', () => {
    const source = `${sql('select 3;')}\n${sql('select 4;')}`;
    expect(findNumbersInSqlBodies(source).map((hit) => hit.value)).toEqual([3, 4]);
  });
});

describe('vùng ui', () => {
  it('bỏ qua 50, bắt 150', () => {
    expect(values(UI_FILE, 'const a = 50;\nconst b = 150;')).toEqual([150]);
  });

  it('bỏ qua chuỗi className, style và giá trị chuỗi của thuộc tính JSX', () => {
    const source = [
      'export const A = () => (',
      '  <div className="w-[300px] p-400" style={{ width: "500px" }} data-x={`600`}>',
      '    Năm 2026',
      '  </div>',
      ');',
    ].join('\n');
    expect(values(UI_FILE, source)).toEqual([]);
  });

  it('bắt số trong biểu thức JSX từ ngưỡng', () => {
    expect(values(UI_FILE, 'export const A = () => <div tabIndex={-150} />;')).toEqual([-150]);
  });

  it('findNumbersInTs đọc được TSX', () => {
    expect(findNumbersInTs('const a = <b>{2}</b>;', 'x.tsx').map((hit) => hit.value)).toEqual([2]);
  });
});

describe('lối thoát allow-number', () => {
  it('comment có lý do thì bỏ qua', () => {
    expect(
      values(DOMAIN_FILE, 'const pct = 2; // allow-number: hệ số nhân đôi theo luật lõi'),
    ).toEqual([]);
    expect(values(UI_FILE, 'const w = 150; // allow-number: chiều rộng biểu đồ')).toEqual([]);
    expect(
      values(
        MIGRATION_FILE,
        'create function f() returns int language sql as $$\nselect 2; -- allow-number: luật lõi\n$$;',
      ),
    ).toEqual([]);
  });

  it('comment không có lý do thì vẫn báo', () => {
    expect(values(DOMAIN_FILE, 'const pct = 2; // allow-number:')).toEqual([2]);
    expect(values(DOMAIN_FILE, 'const pct = 2; // allow-number:   ')).toEqual([2]);
    expect(
      values(
        MIGRATION_FILE,
        'create function f() returns int language sql as $$\nselect 2; -- allow-number:\n$$;',
      ),
    ).toEqual([2]);
  });

  it('chỉ áp dụng cho đúng dòng có comment', () => {
    expect(values(DOMAIN_FILE, '// allow-number: dòng trên\nconst a = 2;')).toEqual([2]);
  });
});
