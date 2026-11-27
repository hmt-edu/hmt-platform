// @vitest-environment jsdom
import { cleanup, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import { CalendarView } from './Calendar';

afterEach(cleanup);

describe('Lưới Lịch', () => {
  it('tuần không có lịch nào: vùng cuộn ngang vẫn tới được bằng bàn phím', () => {
    render(
      <CalendarView
        events={[]}
        kinds={[]}
        mode="week"
        modes={['week']}
        onModeChange={() => undefined}
        anchor={new Date(2026, 10, 28)}
        onAnchorChange={() => undefined}
        now={new Date(2026, 10, 28)}
        startHour={7}
        endHour={21}
        renderDetail={() => null}
      />,
    );
    expect(screen.getByRole('region', { name: 'Lưới lịch' }).getAttribute('tabindex')).toBe('0');
  });
});
