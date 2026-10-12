/* HMT components — interactive prototype (React 18, classic script → window.HMT).
   Colors come only from --hmt-* tokens via bundle.css. Not production code:
   production builds the same API with React + Tailwind v4 (HMT_COMPONENT_SPEC.md). */
declare const React: any;
declare const ReactDOM: any;

(function () {
  const { useState, useEffect, useRef, useCallback, useMemo, useContext, createContext, useId, cloneElement, Fragment } = React;
  const cx = (...a: any[]) => a.filter(Boolean).join(" ");

  /* ---------------- Icons (placeholder set — icon library is OPEN) ---------------- */
  const P: Record<string, any> = {
    check: <path d="M5 12.5l4.5 4.5L19 7" />,
    x: <path d="M6 6l12 12M18 6L6 18" />,
    alert: <g><path d="M12 3.5l9.5 16.5h-19z" /><path d="M12 10v4.5M12 17.5v.5" /></g>,
    info: <g><circle cx="12" cy="12" r="9" /><path d="M12 11v6M12 7.5v.5" /></g>,
    xcircle: <g><circle cx="12" cy="12" r="9" /><path d="M9 9l6 6M15 9l-6 6" /></g>,
    checkcircle: <g><circle cx="12" cy="12" r="9" /><path d="M8 12.5l3 3 5-6" /></g>,
    chevronLeft: <path d="M15 5l-7 7 7 7" />,
    chevronRight: <path d="M9 5l7 7-7 7" />,
    chevronDown: <path d="M5 9l7 7 7-7" />,
    chevronsUpDown: <path d="M8 9l4-4 4 4M8 15l4 4 4-4" />,
    arrowUp: <path d="M12 19V5M6 11l6-6 6 6" />,
    arrowDown: <path d="M12 5v14M6 13l6 6 6-6" />,
    calendar: <g><rect x="3.5" y="5" width="17" height="15" rx="2" /><path d="M3.5 10h17M8 3v4M16 3v4" /></g>,
    search: <g><circle cx="11" cy="11" r="6.5" /><path d="M16 16l4.5 4.5" /></g>,
    home: <path d="M4 11l8-7 8 7v9h-5v-6H9v6H4z" />,
    users: <g><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20c.5-3.5 3-5.5 6.5-5.5s6 2 6.5 5.5" /><path d="M16 4.8a3.5 3.5 0 010 6.4M18 14.8c2 .7 3.2 2.5 3.5 5.2" /></g>,
    book: <path d="M4 5.5C4 4.7 4.7 4 5.5 4H11v16H5.5c-.8 0-1.5-.7-1.5-1.5zM20 5.5c0-.8-.7-1.5-1.5-1.5H13v16h5.5c.8 0 1.5-.7 1.5-1.5z" />,
    clipboard: <g><rect x="5" y="4.5" width="14" height="16" rx="2" /><path d="M9 4.5V3h6v1.5M8.5 13l2.5 2.5 4.5-5" /></g>,
    wallet: <g><rect x="3" y="6" width="18" height="13" rx="2" /><path d="M3 10h18M16 14.5h2" /></g>,
    settings: <g><circle cx="12" cy="12" r="3" /><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1" /></g>,
    menu: <path d="M4 7h16M4 12h16M4 17h16" />,
    bell: <path d="M6 16V11a6 6 0 0112 0v5l1.5 2h-15zM10 20.5h4" />,
    more: <g><circle cx="5.5" cy="12" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="18.5" cy="12" r="1" /></g>,
    file: <g><path d="M6 3h8l4 4v14H6z" /><path d="M14 3v4h4M9 12h6M9 16h6" /></g>,
    star: <path d="M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.9L12 17l-5.2 2.7 1-5.9-4.3-4.1 5.9-.8z" />,
    plus: <path d="M12 5v14M5 12h14" />,
    clock: <g><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></g>,
    mapPin: <g><path d="M12 21s-7-6.2-7-11.5a7 7 0 0114 0C19 14.8 12 21 12 21z" /><circle cx="12" cy="9.5" r="2.5" /></g>,
    inbox: <g><path d="M3 13l2.5-8h13L21 13v6H3z" /><path d="M3 13h5l1.5 2.5h5L16 13h5" /></g>,
    wifiOff: <g><path d="M3 3l18 18M8.5 16.5a5 5 0 017 0M5 12.5a10 10 0 015.5-2.6M19 12.5a10 10 0 00-3-1.9M2 9a15 15 0 015-2.6M22 9a15 15 0 00-9.5-3.9" /><path d="M12 20h.01" /></g>,
    refresh: <path d="M20 11a8 8 0 00-14.5-4.5M4 4v3.5h3.5M4 13a8 8 0 0014.5 4.5M20 20v-3.5h-3.5" />,
    trash: <path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3" />,
    edit: <path d="M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4" />,
    logout: <path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10" />,
    sidebar: <g><rect x="3.5" y="4.5" width="17" height="15" rx="2" /><path d="M9 4.5v15" /></g>,
    lock: <g><rect x="5" y="11" width="14" height="9" rx="2" /><path d="M8 11V8a4 4 0 018 0v3" /></g>,
    filter: <path d="M4 6h16M7 12h10M10 18h4" />,
    columns: <g><rect x="3.5" y="4.5" width="17" height="15" rx="2" /><path d="M9.5 4.5v15M14.5 4.5v15" /></g>,
    layers: <path d="M12 3l9 5-9 5-9-5zM3 13l9 5 9-5" />,
    bookmark: <path d="M6 3h12v18l-6-4-6 4z" />,
    list: <path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01" />,
    kanban: <g><rect x="3.5" y="4" width="17" height="16" rx="2" /><path d="M8 8v6M12 8v9M16 8v4" /></g>,
    download: <path d="M12 4v11M7 10l5 5 5-5M5 20h14" />,
    upload: <path d="M12 20V9M7 14l5-5 5 5M5 4h14" />,
    camera: <g><path d="M4 8h3l2-3h6l2 3h3v11H4z" /><circle cx="12" cy="13" r="3.5" /></g>,
    image: <g><rect x="3.5" y="4.5" width="17" height="15" rx="2" /><circle cx="9" cy="10" r="1.5" /><path d="M20.5 16l-5-5-9 9" /></g>,
    paperclip: <path d="M20 11l-8.5 8.5a5 5 0 01-7-7L13 4a3.5 3.5 0 015 5l-8.5 8.5a2 2 0 01-3-3L14 7" />,
    at: <g><circle cx="12" cy="12" r="4" /><path d="M16 8v5a3 3 0 006 0v-1a10 10 0 10-4 8" /></g>,
    send: <path d="M4 12l16-8-6 16-2-7z" />,
    history: <path d="M3 12a9 9 0 103-6.7M3 4v4h4M12 7v5l3 2" />,
    message: <path d="M4 5h16v11H8l-4 4z" />,
    receipt: <path d="M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6" />,
    userCheck: <g><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20c.5-3.5 3-5.5 6.5-5.5s6 2 6.5 5.5M16 11l2 2 4-4" /></g>,
    graduation: <path d="M2 9l10-5 10 5-10 5zM6 11v5c3 2 9 2 12 0v-5" />,
    timer: <g><circle cx="12" cy="13" r="8" /><path d="M12 9v4M10 2h4" /></g>,
    hourglass: <path d="M6 3h12M6 21h12M7 3c0 6 10 6 10 9s-10 3-10 9M17 3c0 6-10 6-10 9" />,
    gift: <g><rect x="3.5" y="8" width="17" height="4" /><path d="M5 12v8h14v-8M12 8v12M12 8c-2-4-6-3-5 0M12 8c2-4 6-3 5 0" /></g>,
    phone: <path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2z" />,
    printer: <g><path d="M7 9V3h10v6M7 17H4v-7h16v7h-3" /><rect x="7" y="14" width="10" height="7" /></g>,
    gitCompare: <g><circle cx="6" cy="6" r="2.5" /><circle cx="18" cy="18" r="2.5" /><path d="M6 8.5V15a3 3 0 003 3h5M18 15.5V9a3 3 0 00-3-3h-5" /></g>,
    ban: <g><circle cx="12" cy="12" r="9" /><path d="M5.6 5.6l12.8 12.8" /></g>,
    arrowRight: <path d="M5 12h14M13 6l6 6-6 6" />,
    grip: <path d="M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01" />,
    fileCheck: <g><path d="M6 3h8l4 4v14H6z" /><path d="M9 14l2 2 4-4" /></g>,
    userX: <g><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20c.5-3.5 3-5.5 6.5-5.5s6 2 6.5 5.5M17 9l4 4M21 9l-4 4" /></g>,
    moreV: <g><circle cx="12" cy="5.5" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="12" cy="18.5" r="1" /></g>,
    rotateCw: <path d="M20 12a8 8 0 11-2.3-5.7M20 4v4h-4" />,
    zoomIn: <g><circle cx="11" cy="11" r="7" /><path d="M20 20l-4-4M8 11h6M11 8v6" /></g>,
    zoomOut: <g><circle cx="11" cy="11" r="7" /><path d="M20 20l-4-4M8 11h6" /></g>,
    eye: <g><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" /><circle cx="12" cy="12" r="3" /></g>,
    award: <g><circle cx="12" cy="9" r="6" /><path d="M8.5 14L7 22l5-3 5 3-1.5-8" /></g>,
    flame: <path d="M12 3c1 4 6 6 6 11a6 6 0 01-12 0c0-3 2-4 2-6 1 1 2 2 2 4 1-3 1-6 2-9z" />,
  };
  /* Lucide (O-12): names map to Lucide icons; the page loads lucide UMD from CDN.
     When window.lucide is unavailable the placeholder set above is drawn instead. */
  const LUCIDE: Record<string, string[]> = {
    check: ["Check"], x: ["X"], alert: ["TriangleAlert", "AlertTriangle"], info: ["Info"], xcircle: ["CircleX", "XCircle"], checkcircle: ["CircleCheck", "CheckCircle"],
    chevronLeft: ["ChevronLeft"], chevronRight: ["ChevronRight"], chevronDown: ["ChevronDown"], chevronsUpDown: ["ChevronsUpDown"], arrowUp: ["ArrowUp"], arrowDown: ["ArrowDown"],
    calendar: ["Calendar"], search: ["Search"], home: ["House", "Home"], users: ["Users"], book: ["BookOpen"], clipboard: ["ClipboardCheck"], wallet: ["Wallet"], settings: ["Settings"],
    menu: ["Menu"], bell: ["Bell"], more: ["Ellipsis", "MoreHorizontal"], file: ["FileText"], star: ["Star"], plus: ["Plus"], clock: ["Clock"], mapPin: ["MapPin"], inbox: ["Inbox"],
    wifiOff: ["WifiOff"], refresh: ["RefreshCw"], trash: ["Trash2"], edit: ["Pencil"], logout: ["LogOut"], sidebar: ["PanelLeft", "Sidebar"],
    lock: ["Lock"], filter: ["ListFilter", "Filter"], columns: ["Columns3", "Columns"], layers: ["Layers"], bookmark: ["Bookmark"], list: ["List"], kanban: ["SquareKanban", "Kanban"],
    download: ["Download"], upload: ["Upload"], camera: ["Camera"], image: ["Image"], paperclip: ["Paperclip"], at: ["AtSign"], send: ["SendHorizontal", "Send"], history: ["History"],
    message: ["MessageSquare"], receipt: ["Receipt"], userCheck: ["UserCheck"], graduation: ["GraduationCap"], timer: ["Timer"], hourglass: ["Hourglass"], gift: ["Gift"], phone: ["Phone"],
    printer: ["Printer"], gitCompare: ["GitCompare"], ban: ["Ban"], arrowRight: ["ArrowRight"], grip: ["GripVertical"], fileCheck: ["FileCheck"], userX: ["UserX"], moreV: ["EllipsisVertical", "MoreVertical"],
    rotateCw: ["RotateCw"], zoomIn: ["ZoomIn"], zoomOut: ["ZoomOut"], eye: ["Eye"], award: ["Award"], flame: ["Flame"],
  };
  function lucideNode(name: string) {
    const L: any = (window as any).lucide; if (!L || !L.icons) return null;
    for (const n of LUCIDE[name] || []) { const node = L.icons[n]; if (node) return node[0] === "svg" ? node[2] : node; }
    return null;
  }
  function renderNode(children: any[]): any { return children.map(([tag, attrs, kids]: any, i: number) => React.createElement(tag, { key: i, ...attrs }, kids ? renderNode(kids) : null)); }
  function Icon({ name, label, className, size }: any) {
    const ln = lucideNode(name);
    const p = ln ? renderNode(ln) : (P[name] || P.info);
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round" width={size} height={size}
        className={cx("hmt-icon", className)} aria-hidden={label ? undefined : true} role={label ? "img" : undefined} aria-label={label} focusable="false">{p}</svg>
    );
  }
  const TONE_ICON: Record<string, string> = { success: "checkcircle", warning: "alert", danger: "xcircle", info: "info" };

  /* ---------------- Button (one component, configured by variant) ---------------- */
  function Button({ variant = "primary", size, solid, loading, loadingLabel, disabled, iconStart, iconEnd, iconOnly, label, fullWidth, neutral, children, onClick, type = "button", className, ...rest }: any) {
    const inactive = disabled || loading;
    const v = variant === "destructive" && solid ? "destructive-solid" : variant;
    const text = iconOnly ? null : (loading && loadingLabel ? loadingLabel : children);
    const btn = (
      <button type={type} {...rest}
        className={cx("hmt-btn hmt-focus", `hmt-btn--${v}`, size === "sm" && "hmt-btn--sm", fullWidth && "hmt-btn--full", iconOnly && "hmt-btn--icon", neutral && "hmt-btn--neutral", className)}
        aria-disabled={disabled ? true : undefined} aria-busy={loading ? true : undefined}
        aria-label={iconOnly ? label : rest["aria-label"]}
        onClick={(e: any) => { if (inactive) { e.preventDefault(); return; } onClick && onClick(e); }}>
        {loading ? <span className="hmt-spinner" aria-hidden="true" /> : iconStart && <Icon name={iconStart} />}
        {iconOnly && !loading ? <Icon name={iconOnly} /> : null}
        {text}
        {iconEnd && !loading ? <Icon name={iconEnd} /> : null}
      </button>
    );
    return iconOnly ? <Tooltip content={label}>{btn}</Tooltip> : btn;
  }

  /* ---------------- Field + inputs (one wrapper, many controls) ---------------- */
  const FieldCtx = createContext(null);
  function Field({ label, helper, error, required, optional, counter, children, className, hideLabel }: any) {
    const id = useId();
    const ctx = { id: `${id}-c`, describedBy: [helper && `${id}-h`, error && `${id}-e`].filter(Boolean).join(" ") || undefined, invalid: !!error, required };
    return (
      <div className={cx("hmt-field", className)}>
        <label className={cx("hmt-label", hideLabel && "hmt-sr")} htmlFor={ctx.id}>
          {label}{required ? <span className="hmt-req" aria-hidden="true">*</span> : null}{optional ? <span className="hmt-label-opt">(không bắt buộc)</span> : null}
        </label>
        <FieldCtx.Provider value={ctx}>{children}</FieldCtx.Provider>
        {error ? <p className="hmt-err" id={`${id}-e`}><Icon name="xcircle" /> <span>{error}</span></p> : null}
        {helper && !error ? <p className="hmt-help" id={`${id}-h`}>{helper}</p> : null}
        {helper && error ? <p className="hmt-sr" id={`${id}-h`}>{helper}</p> : null}
        {counter}
      </div>
    );
  }
  function useField(props: any) {
    const ctx: any = useContext(FieldCtx) || {};
    return {
      id: props.id || ctx.id,
      "aria-describedby": props["aria-describedby"] || ctx.describedBy,
      "aria-invalid": props.invalid || ctx.invalid ? true : undefined,
      "aria-required": ctx.required ? true : undefined,
    };
  }
  function TextInput({ leadingIcon, trailing, invalid, disabled, className, ...rest }: any) {
    const f = useField({ invalid, ...rest });
    return (
      <div className={cx("hmt-control", className)} data-invalid={f["aria-invalid"] ? "true" : undefined} data-disabled={disabled ? "true" : undefined}>
        {leadingIcon ? <span className="hmt-adorn"><Icon name={leadingIcon} /></span> : null}
        <input {...rest} {...f} disabled={disabled} />
        {trailing}
      </div>
    );
  }
  function Select({ options = [], placeholder, invalid, disabled, className, ...rest }: any) {
    const f = useField({ invalid, ...rest });
    return (
      <div className={cx("hmt-control hmt-control--select", className)} data-invalid={f["aria-invalid"] ? "true" : undefined} data-disabled={disabled ? "true" : undefined}>
        <select {...rest} {...f} disabled={disabled}>
          {placeholder ? <option value="" disabled>{placeholder}</option> : null}
          {options.map((o: any) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <Icon name="chevronDown" />
      </div>
    );
  }
  function Textarea({ maxLength, value, invalid, disabled, className, ...rest }: any) {
    const f = useField({ invalid, ...rest });
    const n = (value || "").length;
    return (
      <Fragment>
        <div className={cx("hmt-control hmt-control--area", className)} data-invalid={f["aria-invalid"] ? "true" : undefined} data-disabled={disabled ? "true" : undefined}>
          <textarea {...rest} {...f} value={value} disabled={disabled} />
        </div>
        {maxLength ? <p className="hmt-count" data-over={n > maxLength ? "true" : undefined} aria-live="polite">{n}/{maxLength}</p> : null}
      </Fragment>
    );
  }

  /* Date: dd/mm/yyyy text + calendar popover (desktop); native date on mobile */
  const pad = (n: number) => String(n).padStart(2, "0");
  const fmt = (d: Date) => `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()}`;
  function parseVN(s: string) {
    const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(s || "");
    if (!m) return null;
    const d = new Date(+m[3], +m[2] - 1, +m[1]);
    return d.getDate() === +m[1] && d.getMonth() === +m[2] - 1 ? d : null;
  }
  const DOW = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
  const MONTHS = ["Tháng 1", "Tháng 2", "Tháng 3", "Tháng 4", "Tháng 5", "Tháng 6", "Tháng 7", "Tháng 8", "Tháng 9", "Tháng 10", "Tháng 11", "Tháng 12"];
  function MonthGrid({ value, onSelect, today = new Date(), rangeFrom, rangeTo, autoFocus = true }: any) {
    const [cursor, setCursor] = useState(value || rangeFrom || today);
    const gridRef = useRef(null);
    const y = cursor.getFullYear(), mo = cursor.getMonth();
    const first = new Date(y, mo, 1); const offset = (first.getDay() + 6) % 7;
    const days = Array.from({ length: 42 }, (_, i) => new Date(y, mo, 1 - offset + i));
    const same = (a: Date, b: Date) => a && b && a.toDateString() === b.toDateString();
    const first_ = useRef(true);
    useEffect(() => { if (first_.current && !autoFocus) { first_.current = false; return; } first_.current = false; const el: any = gridRef.current && (gridRef.current as any).querySelector('[tabindex="0"]'); el && el.focus(); }, [cursor]);
    const inRange = (d: Date) => rangeFrom && rangeTo && d >= rangeFrom && d <= rangeTo;
    const move = (n: number) => { const d = new Date(cursor); d.setDate(d.getDate() + n); setCursor(d); };
    const onKey = (e: any) => {
      const k = e.key;
      if (k === "ArrowLeft") move(-1); else if (k === "ArrowRight") move(1); else if (k === "ArrowUp") move(-7); else if (k === "ArrowDown") move(7);
      else if (k === "PageUp") setCursor(new Date(y, mo - 1, Math.min(cursor.getDate(), 28)));
      else if (k === "PageDown") setCursor(new Date(y, mo + 1, Math.min(cursor.getDate(), 28)));
      else if (k === "Home") move(-((cursor.getDay() + 6) % 7)); else if (k === "End") move(6 - ((cursor.getDay() + 6) % 7));
      else if (k === "Enter" || k === " ") onSelect(cursor); else return;
      e.preventDefault();
    };
    return (
      <div className="hmt-cal">
        <div className="hmt-cal-head">
          <Button variant="tertiary" neutral size="sm" iconOnly="chevronLeft" label="Tháng trước" onClick={() => setCursor(new Date(y, mo - 1, 1))} />
          <span aria-live="polite">{MONTHS[mo]} {y}</span>
          <Button variant="tertiary" neutral size="sm" iconOnly="chevronRight" label="Tháng sau" onClick={() => setCursor(new Date(y, mo + 1, 1))} />
        </div>
        <div className="hmt-cal-grid" role="grid" aria-label={`${MONTHS[mo]} ${y}`} ref={gridRef} onKeyDown={onKey}>
          {DOW.map((d) => <div key={d} className="hmt-cal-dow" role="columnheader">{d}</div>)}
          {days.map((d) => (
            <button key={d.toISOString()} type="button" role="gridcell" className="hmt-cal-day"
              tabIndex={same(d, cursor) ? 0 : -1} aria-selected={same(d, value) || same(d, rangeFrom) || same(d, rangeTo) ? true : undefined}
              data-inrange={inRange(d) ? "true" : undefined}
              data-today={same(d, today) ? "true" : undefined} data-out={d.getMonth() !== mo ? "true" : undefined}
              aria-label={`${d.getDate()} ${MONTHS[d.getMonth()].toLowerCase()} ${d.getFullYear()}`}
              onClick={() => onSelect(d)}>{d.getDate()}</button>
          ))}
        </div>
      </div>
    );
  }
  function DateInput({ value = "", onChange, invalid, disabled, native, min, max, ...rest }: any) {
    const [open, setOpen] = useState(false);
    const ctrlRef = useRef(null);
    const f = useField({ invalid, ...rest });
    if (native) {
      const iso = (() => { const d = parseVN(value); return d ? `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` : ""; })();
      return (
        <div className="hmt-control" data-invalid={f["aria-invalid"] ? "true" : undefined}>
          <input type="date" {...f} value={iso} disabled={disabled}
            onChange={(e: any) => { const [yy, mm, dd] = e.target.value.split("-"); onChange && onChange(e.target.value ? `${dd}/${mm}/${yy}` : ""); }} />
        </div>
      );
    }
    const mask = (s: string) => { const d = s.replace(/\D/g, "").slice(0, 8); return [d.slice(0, 2), d.slice(2, 4), d.slice(4)].filter(Boolean).join("/"); };
    return (
      <Fragment>
        <div ref={ctrlRef} className="hmt-control" data-invalid={f["aria-invalid"] ? "true" : undefined} data-disabled={disabled ? "true" : undefined}>
          <input {...rest} {...f} inputMode="numeric" placeholder="dd/mm/yyyy" autoComplete="off" value={value} disabled={disabled}
            onChange={(e: any) => onChange && onChange(mask(e.target.value))} />
          <Button variant="tertiary" neutral size="sm" iconOnly="calendar" label="Chọn ngày từ lịch"
            aria-haspopup="dialog" aria-expanded={open} disabled={disabled} onClick={() => setOpen(!open)} />
        </div>
        <PopoverPanel open={open} onClose={() => setOpen(false)} anchorRoot={ctrlRef} label="Chọn ngày" initialFocus='[role="gridcell"][tabindex="0"]'>
          <MonthGrid value={parseVN(value)} onSelect={(d: Date) => { onChange && onChange(fmt(d)); setOpen(false); }} />
        </PopoverPanel>
      </Fragment>
    );
  }

  /* ---------------- Focus management shared by Dialog, Drawer, Popover ---------------- */
  const FOCUSABLE = 'a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])';
  function useOverlay(open: boolean, onClose: () => void, panelRef: any, { trap = true, initialFocus }: any = {}) {
    useEffect(() => {
      if (!open) return;
      const prev: any = document.activeElement;
      const panel: any = panelRef.current;
      const first = (initialFocus && panel && panel.querySelector(initialFocus)) || (panel && panel.querySelector(FOCUSABLE)) || panel;
      first && first.focus && first.focus();
      const onKey = (e: any) => {
        if (e.key === "Escape") { e.stopPropagation(); onClose(); }
        if (trap && e.key === "Tab" && panel) {
          const els: any[] = Array.from(panel.querySelectorAll(FOCUSABLE));
          if (!els.length) return;
          const a = els[0], b = els[els.length - 1];
          if (e.shiftKey && document.activeElement === a) { e.preventDefault(); b.focus(); }
          else if (!e.shiftKey && document.activeElement === b) { e.preventDefault(); a.focus(); }
        }
      };
      document.addEventListener("keydown", onKey, true);
      const ov = trap ? document.body.style.overflow : null;
      if (trap) document.body.style.overflow = "hidden";
      return () => { document.removeEventListener("keydown", onKey, true); if (trap) document.body.style.overflow = ov || ""; prev && prev.focus && prev.focus(); };
    }, [open]);
  }
  function Dialog({ open, onClose, title, description, tone, size, children, footer, role = "dialog", initialFocus, dismissible = true }: any) {
    const ref = useRef(null); const id = useId();
    useOverlay(open, () => dismissible && onClose(), ref, { initialFocus: initialFocus || ".hmt-ov-body input, .hmt-ov-body select, .hmt-ov-body textarea, .hmt-ov-body button, .hmt-ov-foot button" });
    if (!open) return null;
    return ReactDOM.createPortal(
      <div className="hmt-root">
        <div className="hmt-scrim" onClick={() => dismissible && onClose()} />
        <div ref={ref} className={cx("hmt-dialog", size === "lg" && "hmt-dialog--lg")} role={role} aria-modal="true" aria-labelledby={`${id}-t`} aria-describedby={description ? `${id}-d` : undefined} tabIndex={-1}>
          <div className="hmt-ov-head">
            {tone ? <span className={`hmt-ov-icon hmt-ov-icon--${tone}`}><Icon name={TONE_ICON[tone]} /></span> : null}
            <div style={{ flex: 1 }}>
              <h2 className="hmt-ov-title" id={`${id}-t`}>{title}</h2>
              {description ? <p className="hmt-ov-desc" id={`${id}-d`}>{description}</p> : null}
            </div>
            {dismissible ? <Button variant="tertiary" neutral size="sm" iconOnly="x" label="Đóng" onClick={onClose} /> : null}
          </div>
          {children ? <div className="hmt-ov-body">{children}</div> : null}
          {footer ? <div className="hmt-ov-foot">{footer}</div> : null}
        </div>
      </div>, document.body);
  }
  /* ConfirmDialog = Dialog configured; not a separate overlay */
  /* ConfirmDialog = Dialog configured. reasonLabel → bắt buộc lý do (huỷ, từ chối, điều chỉnh, đảo khoản…) */
  function ConfirmDialog({ open, onClose, onConfirm, title, description, confirmLabel, cancelLabel = "Huỷ", tone = "danger", loading, children, reasonLabel, reasonOptions, reasonHelper }: any) {
    const [reason, setReason] = useState(""); const [note, setNote] = useState(""); const [tried, setTried] = useState(false);
    useEffect(() => { if (open) { setReason(""); setNote(""); setTried(false); } }, [open]);
    const needNote = !reasonOptions || reason === "other";
    const missing = reasonLabel ? (reasonOptions ? !reason || (reason === "other" && !note.trim()) : !note.trim()) : false;
    const go = () => { setTried(true); if (missing) { const el: any = document.querySelector("[data-reason]"); el && el.focus(); return; } onConfirm({ reason, note: note.trim() }); };
    return (
      <Dialog open={open} onClose={onClose} title={title} description={description} tone={tone} role="alertdialog" initialFocus={reasonLabel ? "[data-reason]" : "[data-cancel]"} dismissible={!loading}
        footer={<Fragment>
          <Button variant="secondary" onClick={onClose} data-cancel="" disabled={loading}>{cancelLabel}</Button>
          <Button variant={tone === "danger" ? "destructive" : "primary"} solid={tone === "danger"} loading={loading} loadingLabel="Đang xử lý…" onClick={go}>{confirmLabel}</Button>
        </Fragment>}>
        {children}
        {reasonLabel ? <div style={{ display: "grid", gap: 12, marginTop: children ? 12 : 0 }}>
          {reasonOptions ? <Field label={reasonLabel} required error={tried && !reason ? "Chọn lý do" : undefined}>
            <Select data-reason="" value={reason} onChange={(e: any) => setReason(e.target.value)} placeholder="Chọn lý do" options={[...reasonOptions, { value: "other", label: "Khác…" }]} />
          </Field> : null}
          {needNote ? <Field label={reasonOptions ? "Ghi rõ lý do" : reasonLabel} required helper={reasonHelper} error={tried && !note.trim() ? "Nhập lý do" : undefined}>
            <Textarea data-reason={reasonOptions ? undefined : ""} value={note} onChange={(e: any) => setNote(e.target.value)} maxLength={500} />
          </Field> : null}
        </div> : null}
      </Dialog>
    );
  }
  function Drawer({ open, onClose, title, description, placement = "right", children, footer }: any) {
    const ref = useRef(null); const id = useId();
    useOverlay(open, onClose, ref, { initialFocus: ".hmt-ov-body input, .hmt-ov-body select, .hmt-ov-body textarea, .hmt-ov-body button, .hmt-ov-foot button" });
    if (!open) return null;
    return ReactDOM.createPortal(
      <div className="hmt-root">
        <div className="hmt-scrim" onClick={onClose} />
        <div ref={ref} className={cx("hmt-drawer", `hmt-drawer--${placement}`)} role="dialog" aria-modal="true" aria-labelledby={`${id}-t`} tabIndex={-1}>
          <div className="hmt-ov-head">
            <div style={{ flex: 1 }}>
              <h2 className="hmt-ov-title" id={`${id}-t`}>{title}</h2>
              {description ? <p className="hmt-ov-desc">{description}</p> : null}
            </div>
            <Button variant="tertiary" neutral size="sm" iconOnly="x" label="Đóng" onClick={onClose} />
          </div>
          <div className="hmt-ov-body">{children}</div>
          {footer ? <div className="hmt-ov-foot">{footer}</div> : null}
        </div>
      </div>, document.body);
  }
  function PopoverPanel({ open, onClose, anchorRoot, anchorSelector, label, children, placement = "bottom-start", role = "dialog", initialFocus }: any) {
    const ref = useRef(null); const [pos, setPos] = useState({ top: -9999, left: -9999 });
    useOverlay(open, onClose, ref, { trap: false, initialFocus });
    useEffect(() => {
      if (!open) return;
      const anchor: any = (anchorRoot && anchorRoot.current) || document.querySelector(anchorSelector);
      const place = () => {
        if (!anchor || !ref.current) return;
        const r = anchor.getBoundingClientRect(); const p: any = (ref.current as any).getBoundingClientRect();
        let top = r.bottom + 6, left = placement.endsWith("end") ? r.right - p.width : r.left;
        if (top + p.height > window.innerHeight - 8) top = Math.max(8, r.top - p.height - 6);
        left = Math.min(Math.max(8, left), window.innerWidth - p.width - 8);
        setPos({ top, left });
      };
      place(); const t = setTimeout(place, 0);
      const out = (e: any) => { if (ref.current && !(ref.current as any).contains(e.target) && !(anchor && anchor.contains(e.target))) onClose(); };
      document.addEventListener("mousedown", out); window.addEventListener("resize", place); window.addEventListener("scroll", place, true);
      return () => { clearTimeout(t); document.removeEventListener("mousedown", out); window.removeEventListener("resize", place); window.removeEventListener("scroll", place, true); };
    }, [open]);
    if (!open) return null;
    return ReactDOM.createPortal(<div className="hmt-root"><div ref={ref} className="hmt-pop" role={role} aria-label={label} style={{ top: pos.top, left: pos.left }}>{children}</div></div>, document.body);
  }
  function Popover({ trigger, label, children, placement }: any) {
    const [open, setOpen] = useState(false); const id = useId(); const anchorRef = useRef(null);
    const t = cloneElement(trigger, { "aria-haspopup": "dialog", "aria-expanded": open, "aria-controls": open ? id : undefined, onClick: () => setOpen(!open) });
    return (
      <Fragment>
        <span style={{ display: "inline-flex" }} ref={anchorRef}>{t}</span>
        <PopoverPanel open={open} onClose={() => setOpen(false)} anchorRoot={anchorRef} label={label} placement={placement}>
          <div id={id} className="hmt-pop-body">{typeof children === "function" ? children(() => setOpen(false)) : children}</div>
        </PopoverPanel>
      </Fragment>
    );
  }

  /* ---------------- Tooltip ---------------- */
  function Tooltip({ content, children, delay = 400 }: any) {
    const [show, setShow] = useState(false); const [pos, setPos] = useState({ top: 0, left: 0 });
    const id = useId(); const wrap = useRef(null); const timer = useRef(0);
    const open = (immediate?: boolean) => {
      clearTimeout(timer.current);
      timer.current = setTimeout(() => {
        const el: any = wrap.current && (wrap.current as any).firstElementChild; if (!el) return;
        const r = el.getBoundingClientRect(); setPos({ top: r.top - 8, left: r.left + r.width / 2 }); setShow(true);
      }, immediate ? 0 : delay) as any;
    };
    const close = () => { clearTimeout(timer.current); setShow(false); };
    useEffect(() => { if (!show) return; const k = (e: any) => e.key === "Escape" && close(); document.addEventListener("keydown", k); return () => document.removeEventListener("keydown", k); }, [show]);
    const dup = children.props && children.props["aria-label"] === content;
    const child = dup ? children : cloneElement(children, { "aria-describedby": show ? id : undefined });
    return (
      <span ref={wrap} style={{ display: "inline-flex" }} onMouseEnter={() => open()} onMouseLeave={close} onFocus={(e: any) => e.target.matches(":focus-visible") && open(true)} onBlur={close}>
        {child}
        {show ? ReactDOM.createPortal(<div className="hmt-root"><div role="tooltip" id={id} className="hmt-tip" style={{ top: pos.top, left: pos.left, transform: "translate(-50%,-100%)" }}>{content}</div></div>, document.body) : null}
      </span>
    );
  }

  /* ---------------- Data display ---------------- */
  function Badge({ tone = "neutral", solid, icon, children }: any) {
    const ic = icon === false ? null : icon || TONE_ICON[tone];
    return <span className={cx("hmt-badge", `hmt-badge--${tone}`, solid && "hmt-badge--solid")}>{ic ? <Icon name={ic} /> : null}{children}</span>;
  }
  function CountBadge({ count, label }: any) {
    if (!count) return null;
    return <span className="hmt-badge hmt-badge--count" aria-label={label || `${count} mục mới`}>{count > 99 ? "99+" : count}</span>;
  }
  function initials(name: string) { const p = (name || "").trim().split(/\s+/); return ((p.length > 1 ? p[p.length - 2][0] : "") + (p[p.length - 1] || "")[0]).toUpperCase(); }
  function Avatar({ name, src, size = "md", decorative }: any) {
    const [err, setErr] = useState(false);
    return (
      <span className={cx("hmt-avatar", `hmt-avatar--${size}`)} role={decorative ? undefined : "img"} aria-label={decorative ? undefined : name} aria-hidden={decorative ? true : undefined}>
        {src && !err ? <img src={src} alt="" onError={() => setErr(true)} /> : <span aria-hidden="true">{initials(name)}</span>}
      </span>
    );
  }
  function Chip({ selected, onToggle, children, count }: any) {
    return <button type="button" className="hmt-chip hmt-focus" aria-pressed={!!selected} onClick={onToggle}>{selected ? <Icon name="check" /> : null}{children}{count != null ? <span className="hmt-tabular" style={{ opacity: .8 }}>· {count}</span> : null}</button>;
  }

  function useNarrow(ref: any, bp = 640) {
    const [narrow, setNarrow] = useState(false);
    useEffect(() => {
      if (!ref.current || typeof ResizeObserver === "undefined") return;
      const ro = new ResizeObserver(([e]: any) => setNarrow(e.contentRect.width < bp)); ro.observe(ref.current); return () => ro.disconnect();
    }, []);
    return narrow;
  }
  function Table({ columns, rows, rowKey = "id", caption, selectable, selected = [], onSelectedChange, sort, onSortChange, loading, empty, bulkActions, rowLabel = (r: any) => r.name, cardsBelow = 640, maxHeight }: any) {
    const wrap = useRef(null); const narrow = useNarrow(wrap, cardsBelow);
    const allIds = rows.map((r: any) => r[rowKey]);
    const all = allIds.length > 0 && allIds.every((id: any) => selected.includes(id));
    const some = !all && allIds.some((id: any) => selected.includes(id));
    const headRef = useRef(null);
    useEffect(() => { if (headRef.current) (headRef.current as any).indeterminate = some; }, [some]);
    const toggle = (id: any) => onSelectedChange(selected.includes(id) ? selected.filter((x: any) => x !== id) : [...selected, id]);
    const sortIcon = (c: any) => !sort || sort.key !== c.key ? "chevronsUpDown" : sort.dir === "asc" ? "arrowUp" : "arrowDown";
    const ariaSort = (c: any) => !c.sortable ? undefined : !sort || sort.key !== c.key ? "none" : sort.dir === "asc" ? "ascending" : "descending";
    const body = loading
      ? Array.from({ length: 4 }, (_, i) => <tr key={`s${i}`}>{selectable ? <td><Skeleton width={18} height={18} /></td> : null}{columns.map((c: any) => <td key={c.key} className={c.numeric ? "hmt-num" : undefined}><Skeleton width={c.numeric ? 80 : 120} /></td>)}</tr>)
      : rows.map((r: any) => {
        const id = r[rowKey]; const sel = selected.includes(id);
        return (
          <tr key={id} aria-selected={selectable ? sel : undefined}>
            {selectable ? <td style={{ width: 44 }}><input type="checkbox" className="hmt-check" checked={sel} onChange={() => toggle(id)} aria-label={`Chọn ${rowLabel(r)}`} /></td> : null}
            {columns.map((c: any) => <td key={c.key} className={c.numeric ? "hmt-num" : undefined}>{c.render ? c.render(r) : r[c.key]}</td>)}
          </tr>
        );
      });
    return (
      <div ref={wrap}>
        {narrow && !loading ? (
          rows.length ? <ul className="hmt-table-cards" aria-label={caption} style={{ listStyle: "none", margin: 0, padding: 0 }}>
            {rows.map((r: any) => (
              <li key={r[rowKey]} className="hmt-rowcard">
                {columns.map((c: any, i: number) => i === 0
                  ? <div key={c.key} style={{ fontWeight: 600 }}>{c.render ? c.render(r) : r[c.key]}</div>
                  : <div key={c.key} className="hmt-rowcard-line"><span className="hmt-rowcard-k">{c.header}</span><span className={c.numeric ? "hmt-tabular" : undefined}>{c.render ? c.render(r) : r[c.key]}</span></div>)}
              </li>))}
          </ul> : empty
        ) : (
          <div className="hmt-table-wrap" style={maxHeight ? { maxHeight } : undefined}>
            {selectable && selected.length ? <BulkActionBar count={selected.length} onClear={() => onSelectedChange([])}>{bulkActions}</BulkActionBar> : null}
            <table className="hmt-table" aria-busy={loading ? true : undefined}>
              {caption ? <caption className="hmt-sr">{caption}</caption> : null}
              <thead><tr>
                {selectable ? <th style={{ width: 44 }}><input ref={headRef} type="checkbox" className="hmt-check" checked={all} onChange={() => onSelectedChange(all ? [] : allIds)} aria-label="Chọn tất cả trên trang" /></th> : null}
                {columns.map((c: any) => (
                  <th key={c.key} scope="col" className={c.numeric ? "hmt-num" : undefined} aria-sort={ariaSort(c)} style={c.width ? { width: c.width } : undefined}>
                    {c.sortable ? <button type="button" className="hmt-th-sort" data-active={sort && sort.key === c.key ? "true" : undefined}
                      onClick={() => onSortChange({ key: c.key, dir: sort && sort.key === c.key && sort.dir === "asc" ? "desc" : "asc" })}>{c.header}<Icon name={sortIcon(c)} /></button> : c.header}
                  </th>))}
              </tr></thead>
              <tbody>{!loading && !rows.length ? <tr><td colSpan={columns.length + (selectable ? 1 : 0)} style={{ height: "auto" }}>{empty}</td></tr> : body}</tbody>
            </table>
          </div>
        )}
      </div>
    );
  }
  function Pagination({ page, pageCount, onPageChange, total, pageSize, compact }: any) {
    const pages = useMemo(() => {
      const s = new Set([1, pageCount, page - 1, page, page + 1].filter((p) => p >= 1 && p <= pageCount));
      const arr = Array.from(s).sort((a: any, b: any) => a - b); const out: any[] = [];
      arr.forEach((p: any, i) => { if (i && p - arr[i - 1] > 1) out.push("…" + p); out.push(p); }); return out;
    }, [page, pageCount]);
    const from = (page - 1) * pageSize + 1, to = Math.min(total, page * pageSize);
    return (
      <nav className="hmt-pager" aria-label="Phân trang">
        {total != null ? <span className="hmt-pager-info hmt-tabular">{from}–{to} / {total.toLocaleString("vi-VN")}</span> : null}
        <Button variant="secondary" size="sm" iconOnly="chevronLeft" label="Trang trước" disabled={page <= 1} onClick={() => onPageChange(page - 1)} />
        {compact ? <span className="hmt-tabular" aria-live="polite" style={{ padding: "0 8px" }}>Trang {page}/{pageCount}</span>
          : pages.map((p) => typeof p === "string" ? <span key={p} aria-hidden="true" style={{ padding: "0 4px", color: "var(--hmt-fg-muted)" }}>…</span>
            : <Button key={p} variant="secondary" size="sm" aria-current={p === page ? "page" : undefined} aria-label={`Trang ${p}`} onClick={() => onPageChange(p)}><span className="hmt-tabular">{p}</span></Button>)}
        <Button variant="secondary" size="sm" iconOnly="chevronRight" label="Trang sau" disabled={page >= pageCount} onClick={() => onPageChange(page + 1)} />
      </nav>
    );
  }

  /* ---------------- Navigation ---------------- */
  function Sidebar({ title = "Hòa Ma Toán", subtitle, sections, activeId, onNavigate, collapsed, onCollapsedChange, footer }: any) {
    return (
      <nav className="hmt-sidebar" data-collapsed={collapsed ? "true" : undefined} aria-label="Điều hướng chính">
        <div className="hmt-sidebar-head">
          <span className="hmt-wordmark">{title}{subtitle ? <small>{subtitle}</small> : null}</span>
        </div>
        <ul className="hmt-nav">
          {sections.map((s: any) => (
            <Fragment key={s.label || "main"}>
              {s.label ? <li className="hmt-nav-sec" aria-hidden={collapsed ? true : undefined}>{s.label}</li> : null}
              {s.items.map((it: any) => {
                const link = (
                  <a href={it.href || "#"} aria-current={it.id === activeId ? "page" : undefined} aria-label={collapsed ? it.label : undefined}
                    onClick={(e: any) => { e.preventDefault(); onNavigate && onNavigate(it.id); }}>
                    <Icon name={it.icon} /><span className="hmt-nav-label">{it.label}</span><CountBadge count={it.badge} />
                  </a>);
                return <li key={it.id}>{collapsed ? <Tooltip content={it.label}>{link}</Tooltip> : link}</li>;
              })}
            </Fragment>
          ))}
        </ul>
        <div className="hmt-sidebar-foot">
          {footer}
          <Button variant="tertiary" neutral size="sm" iconStart="sidebar" aria-expanded={!collapsed} onClick={() => onCollapsedChange(!collapsed)} iconOnly={collapsed ? "sidebar" : undefined} label={collapsed ? "Mở rộng menu" : undefined}>{collapsed ? null : "Thu gọn"}</Button>
        </div>
      </nav>
    );
  }
  function TopNav({ title, leading, actions, children }: any) {
    return (
      <header className="hmt-topnav">
        {leading}
        <h1 className="hmt-topnav-title">{title}</h1>
        {children}
        <div className="hmt-topnav-actions">{actions}</div>
      </header>
    );
  }
  function Tabs({ items, value, onChange, label, children }: any) {
    const id = useId(); const refs = useRef({});
    const idx = items.findIndex((t: any) => t.value === value);
    const go = (i: number) => { const t = items[(i + items.length) % items.length]; onChange(t.value); setTimeout(() => (refs.current as any)[t.value] && (refs.current as any)[t.value].focus(), 0); };
    return (
      <div>
        <div className="hmt-tabs" role="tablist" aria-label={label}
          onKeyDown={(e: any) => { const k = e.key; if (k === "ArrowRight") go(idx + 1); else if (k === "ArrowLeft") go(idx - 1); else if (k === "Home") go(0); else if (k === "End") go(items.length - 1); else return; e.preventDefault(); }}>
          {items.map((t: any) => (
            <button key={t.value} ref={(el: any) => ((refs.current as any)[t.value] = el)} type="button" role="tab" className="hmt-tab" id={`${id}-${t.value}`}
              aria-selected={t.value === value} aria-controls={`${id}-p`} tabIndex={t.value === value ? 0 : -1} onClick={() => onChange(t.value)}>
              {t.label}{t.count != null ? <Badge tone="neutral" icon={false}><span className="hmt-tabular">{t.count}</span></Badge> : null}
            </button>))}
        </div>
        <div role="tabpanel" id={`${id}-p`} aria-labelledby={`${id}-${value}`} tabIndex={0} className="hmt-tabpanel">{children}</div>
      </div>
    );
  }
  function Breadcrumb({ items, compact }: any) {
    if (compact && items.length > 1) {
      const parent = items[items.length - 2];
      return <nav className="hmt-crumbs" aria-label="Vị trí"><ol><li><a href={parent.href || "#"} onClick={(e: any) => { e.preventDefault(); parent.onClick && parent.onClick(); }}><Icon name="chevronLeft" /> {parent.label}</a></li></ol></nav>;
    }
    return (
      <nav className="hmt-crumbs" aria-label="Vị trí">
        <ol>{items.map((it: any, i: number) => (
          <li key={i} style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
            {i < items.length - 1 ? <Fragment><a href={it.href || "#"} onClick={(e: any) => { e.preventDefault(); it.onClick && it.onClick(); }}>{it.label}</a><Icon name="chevronRight" /></Fragment>
              : <span aria-current="page">{it.label}</span>}
          </li>))}</ol>
      </nav>
    );
  }
  function BottomNav({ items, activeId, onNavigate }: any) {
    return (
      <nav className="hmt-bottomnav" aria-label="Điều hướng chính">
        {items.map((it: any) => (
          <a key={it.id} href="#" className="hmt-focus" aria-current={it.id === activeId ? "page" : undefined} onClick={(e: any) => { e.preventDefault(); onNavigate(it.id); }}>
            <span className="hmt-bn-pill"><Icon name={it.icon} /></span>{it.label}<CountBadge count={it.badge} label={it.badge ? `${it.badge} mục cần xử lý` : undefined} />
          </a>))}
      </nav>
    );
  }

  /* ---------------- Feedback ---------------- */
  function Alert({ tone = "info", title, children, actions, onDismiss, live }: any) {
    return (
      <div className={cx("hmt-alert", `hmt-alert--${tone}`)} role={live ? (tone === "danger" ? "alert" : "status") : undefined}>
        <Icon name={TONE_ICON[tone]} />
        <div style={{ flex: 1 }}>
          {title ? <p className="hmt-alert-title">{title}</p> : null}
          {children ? <div className="hmt-alert-body">{children}</div> : null}
          {actions ? <div className="hmt-alert-actions">{actions}</div> : null}
        </div>
        {onDismiss ? <Button variant="tertiary" neutral size="sm" iconOnly="x" label="Đóng thông báo" onClick={onDismiss} /> : null}
      </div>
    );
  }
  const ToastCtx = createContext(null);
  function ToastProvider({ children, placement = "bottom-right" }: any) {
    const [list, setList] = useState([]);
    const dismiss = useCallback((id: any) => setList((l: any) => l.filter((t: any) => t.id !== id)), []);
    const push = useCallback((t: any) => { const id = Math.random().toString(36).slice(2); setList((l: any) => [...l.slice(-2), { tone: "success", ...t, id }]); return id; }, []);
    return (
      <ToastCtx.Provider value={{ push, dismiss }}>
        {children}
        <div className={cx("hmt-toasts", placement === "bottom" && "hmt-toasts--bottom")} role="region" aria-label="Thông báo">
          <div aria-live="polite" style={{ display: "contents" }}>{list.filter((t: any) => t.tone !== "danger").map((t: any) => <ToastItem key={t.id} t={t} onDone={() => dismiss(t.id)} />)}</div>
          <div aria-live="assertive" style={{ display: "contents" }}>{list.filter((t: any) => t.tone === "danger").map((t: any) => <ToastItem key={t.id} t={t} onDone={() => dismiss(t.id)} />)}</div>
        </div>
      </ToastCtx.Provider>
    );
  }
  function ToastItem({ t, onDone }: any) {
    const [paused, setPaused] = useState(false);
    const dur = t.duration || (t.action ? 8000 : 5000);
    useEffect(() => { if (paused || t.tone === "danger") return; const h = setTimeout(onDone, dur); return () => clearTimeout(h); }, [paused]);
    return (
      <div className="hmt-toast hmt-root" onMouseEnter={() => setPaused(true)} onMouseLeave={() => setPaused(false)} onFocus={() => setPaused(true)} onBlur={() => setPaused(false)}>
        <span className={`hmt-toast-ico--${t.tone}`}><Icon name={TONE_ICON[t.tone]} /></span>
        <span className="hmt-toast-msg">{t.message}</span>
        {t.action ? <button type="button" className="hmt-toast-act hmt-focus" onClick={() => { t.action.onClick(); onDone(); }}>{t.action.label}</button> : null}
        <button type="button" className="hmt-toast-x hmt-focus" aria-label="Đóng" onClick={onDone}><Icon name="x" /></button>
      </div>
    );
  }
  function useToast() { return useContext(ToastCtx) || { push: () => {}, dismiss: () => {} }; }

  const STATE: Record<string, any> = {
    empty: { icon: "inbox" }, "no-results": { icon: "search" }, error: { icon: "xcircle" }, offline: { icon: "wifiOff" }, "no-access": { icon: "alert" },
  };
  function StateView({ kind = "empty", title, description, actions, compact }: any) {
    return (
      <div className={cx("hmt-state", `hmt-state--${kind}`)} role={kind === "error" ? "alert" : undefined} style={compact ? { padding: 16 } : undefined}>
        <span className="hmt-state-ico"><Icon name={STATE[kind].icon} /></span>
        <p className="hmt-state-title">{title}</p>
        {description ? <p className="hmt-state-desc">{description}</p> : null}
        {actions ? <div className="hmt-state-actions">{actions}</div> : null}
      </div>
    );
  }
  function Skeleton({ width = "100%", height = 14, radius, style }: any) {
    return <span className="hmt-skel" aria-hidden="true" style={{ width, height, borderRadius: radius, ...style }} />;
  }
  function Spinner({ label = "Đang tải…" }: any) {
    return <span role="status" style={{ display: "inline-flex", alignItems: "center", gap: 8, color: "var(--hmt-fg-muted)" }}><span className="hmt-spinner" aria-hidden="true" /><span>{label}</span></span>;
  }

  /* ---------------- Domain: class, student, attendance, progress ---------------- */
  /* colored: lựa chọn đã chọn tô theo option.tone + option.emphasis ('subtle' | 'solid') — R-DD-01 màu điểm danh */
  function SegmentedControl({ name, options, value, onChange, label, colored, layout = "stack", disabled }: any) {
    return (
      <fieldset className={cx("hmt-seg", layout === "row" && "hmt-seg--row")} data-colored={colored ? "true" : undefined} disabled={disabled}>
        <legend className="hmt-sr">{label}</legend>
        {options.map((o: any) => (
          <label key={o.value} className="hmt-seg-opt" data-tone={o.tone} data-emphasis={o.emphasis || "subtle"}>
            <input type="radio" name={name} value={o.value} checked={value === o.value} onChange={() => onChange(o.value)} />
            {o.icon ? <Icon name={o.icon} /> : null}<span>{o.short || o.label}</span>
          </label>))}
      </fieldset>
    );
  }
  function PersonLine({ name, meta, avatar, size = "md" }: any) {
    return (
      <div className="hmt-person">
        <Avatar name={name} src={avatar} size={size} decorative />
        <div className="hmt-person-text"><p className="hmt-person-name">{name}</p>{meta ? <p className="hmt-person-meta">{meta}</p> : null}</div>
      </div>
    );
  }
  function StudentListItem({ name, meta, avatar, trailing, onClick }: any) {
    const inner = <Fragment><PersonLine name={name} meta={meta} avatar={avatar} />{trailing ? <div style={{ marginLeft: "auto", display: "flex", gap: 8, alignItems: "center" }}>{trailing}</div> : null}</Fragment>;
    return onClick ? <button type="button" className="hmt-listitem hmt-focus" style={{ all: "unset", boxSizing: "border-box", display: "flex", width: "100%", cursor: "pointer" } as any} onClick={onClick}><div className="hmt-listitem" style={{ width: "100%" }}>{inner}</div></button>
      : <div className="hmt-listitem">{inner}</div>;
  }
  function ClassCard({ name, campus, schedule, teacher, enrolled, capacity, status, href, footer }: any) {
    const full = capacity && enrolled >= capacity;
    const Tag: any = href ? "a" : "div";
    return (
      <Tag className="hmt-classcard" href={href} onClick={href ? (e: any) => e.preventDefault() : undefined}>
        <div className="hmt-classcard-top"><p className="hmt-classcard-name">{name}</p>{status}</div>
        <dl className="hmt-classcard-meta">
          {campus ? <Fragment><dt><Icon name="mapPin" />Cơ sở</dt><dd>{campus}</dd></Fragment> : null}
          {schedule ? <Fragment><dt><Icon name="clock" />Lịch</dt><dd>{schedule}</dd></Fragment> : null}
          {teacher ? <Fragment><dt><Icon name="users" />Giáo viên</dt><dd>{teacher}</dd></Fragment> : null}
          {capacity ? <Fragment><dt><Icon name="clipboard" />Sĩ số</dt><dd className="hmt-tabular">{enrolled}/{capacity}{full ? <Fragment> · <Badge tone="warning">Đã đủ</Badge></Fragment> : null}</dd></Fragment> : null}
        </dl>
        {footer}
      </Tag>
    );
  }
  function ProgressBar({ value, max = 100, label, valueText, variant = "default", size }: any) {
    const pct = Math.max(0, Math.min(100, (value / max) * 100));
    const id = useId();
    return (
      <div className={cx("hmt-progress", variant === "lms" && "hmt-progress--lms", size === "lg" && "hmt-progress--lg")}>
        {label ? <div className="hmt-progress-top"><span id={id}>{label}</span><span className="hmt-tabular" style={{ fontWeight: 600 }}>{valueText || `${Math.round(pct)}%`}</span></div> : null}
        <div className="hmt-progress-track" role="progressbar" aria-labelledby={label ? id : undefined} aria-valuenow={value} aria-valuemin={0} aria-valuemax={max} aria-valuetext={valueText}>
          <div className="hmt-progress-fill" style={{ width: `${pct}%` }} />
        </div>
      </div>
    );
  }

  /* ======================= Điểm danh (R-DD-01/02/03) ======================= */
  const ATT_STATUSES = [
    { value: "present", label: "Có mặt", short: "Có mặt", icon: "check", tone: "success", emphasis: "subtle" },
    { value: "late", label: "Đi muộn", short: "Đi muộn", icon: "clock", tone: "warning", emphasis: "subtle" },
    { value: "excused", label: "Vắng có phép", short: "Vắng có phép", icon: "fileCheck", tone: "danger", emphasis: "solid" },
    { value: "absent", label: "Vắng không phép", short: "Vắng không phép", icon: "userX", tone: "danger", emphasis: "solid" },
  ];
  const CONTACT_REASONS = ["Không nghe máy", "Đã nhắc vào lớp", "Đã vào lớp", "Xin nghỉ học", "Khác"]; // danh mục 17, cấu hình được (QT-07)
  function SaveState({ state }: any) {
    if (!state) return null;
    const M: any = { saving: ["timer", "Đang lưu…", "var(--hmt-fg-muted)"], saved: ["check", "Đã lưu", "var(--hmt-success)"], error: ["alert", "Chưa lưu được", "var(--hmt-danger)"] };
    const [ic, t, c] = M[state];
    return <span className="hmt-savestate" role="status" style={{ color: c }}><Icon name={ic} /> {t}</span>;
  }
  function attLabel(v: string) { const s = ATT_STATUSES.find((x) => x.value === v); return s ? s.label : "Chưa điểm danh"; }
  function AttBadge({ value }: any) {
    const s: any = ATT_STATUSES.find((x) => x.value === value);
    if (!s) return <span className="hmt-badge hmt-badge--neutral hmt-att-empty">— Chưa điểm danh</span>;
    return <span className={cx("hmt-badge", `hmt-badge--${s.tone}`, s.emphasis === "solid" && "hmt-badge--solid")}><Icon name={s.icon} />{s.label}</span>;
  }
  /* mode: "teacher" (chính thức) · "ops" (vận hành ghi kèm lý do liên hệ) · "compare" (xem hai cột, chỉ đọc) */
  function AttendanceSheet({ className: klass, session, students, mode = "teacher", initial = {}, opsMarks = {}, onChange, onRequestNext, failNext = false }: any) {
    const toast = useToast();
    const [marks, setMarks] = useState(() => { const v: any = {}; students.forEach((s: any) => (v[s.id] = initial[s.id] || null)); return v; });
    const [reasons, setReasons] = useState(() => { const v: any = {}; students.forEach((s: any) => (v[s.id] = (opsMarks[s.id] && opsMarks[s.id].reason) || "")); return v; });
    const [save, setSave] = useState(null);
    const [blocked, setBlocked] = useState(false);
    const listRef = useRef(null); const tick = useRef(0);
    const unmarked = students.filter((s: any) => !marks[s.id]);
    const counts = ATT_STATUSES.map((st) => ({ ...st, n: students.filter((s: any) => marks[s.id] === st.value).length }));
    const persist = (next: any) => {
      const t = ++tick.current; setSave("saving");
      setTimeout(() => { if (t !== tick.current) return; const fail = failNext && Object.values(next).filter(Boolean).length === 3; setSave(fail ? "error" : "saved"); }, 600);
      onChange && onChange(next);
    };
    const set = (id: any, v: any) => setMarks((m: any) => { const n = { ...m, [id]: v }; persist(n); return n; });
    const markRest = () => { const prev = marks; const n = { ...marks }; unmarked.forEach((s: any) => (n[s.id] = "present")); setMarks(n); persist(n);
      toast.push({ tone: "info", message: `Đã đánh dấu ${unmarked.length} em còn lại là Có mặt`, action: { label: "Hoàn tác", onClick: () => { setMarks(prev); persist(prev); } } }); };
    const focusStudent = (id: any) => { const el: any = listRef.current && (listRef.current as any).querySelector(`[data-sid="${id}"]`); if (el) { el.scrollIntoView({ block: "center", behavior: "smooth" }); const r = el.querySelector("input,select"); r && r.focus({ preventScroll: true }); } };
    const next = () => { if (unmarked.length) { setBlocked(true); return; } onRequestNext && onRequestNext(marks); };
    if (mode === "compare") {
      return (
        <section className={cx("hmt-att hmt-att--compare", klass)} aria-label={`Điểm danh ${session.className}`}>
          <div className="hmt-table-wrap">
            <table className="hmt-table">
              <caption className="hmt-sr">Điểm danh vận hành và giáo viên</caption>
              <thead><tr><th scope="col">Học sinh</th><th scope="col">Vận hành <span className="hmt-th-note">(chỉ đọc)</span></th><th scope="col">Lý do liên hệ</th><th scope="col">Giáo viên <span className="hmt-th-note">(chính thức)</span></th></tr></thead>
              <tbody>{students.map((s: any) => {
                const o = opsMarks[s.id] || {}; const diff = o.status && initial[s.id] && o.status !== initial[s.id];
                return (<tr key={s.id}>
                  <td><PersonLine name={s.name} meta={s.code} size="sm" /></td>
                  <td>{o.status ? <AttBadge value={o.status} /> : <span className="hmt-help">—</span>}</td>
                  <td>{o.reason || <span className="hmt-help">—</span>}</td>
                  <td><span style={{ display: "inline-flex", gap: 8, alignItems: "center" }}><AttBadge value={initial[s.id]} />{diff ? <span className="hmt-diff">Khác vận hành</span> : null}</span></td>
                </tr>);
              })}</tbody>
            </table>
          </div>
        </section>
      );
    }
    return (
      <section className={cx("hmt-att", klass)} aria-label={`Điểm danh ${session.className}`}>
        <div className="hmt-att-head">
          <div style={{ display: "flex", alignItems: "center", gap: 8, justifyContent: "space-between" }}>
            <h3>{session.className}</h3><SaveState state={save} />
          </div>
          <span className="hmt-person-meta">{session.label} · {session.time} · {session.campus} · {students.length} em</span>
          {mode === "ops" ? <span className="hmt-help">Vận hành ghi riêng kèm lý do liên hệ. Ô của giáo viên mới là trạng thái chính thức.</span> : null}
          {unmarked.length > 0 ? <div><Button variant="secondary" size="sm" iconStart="check" onClick={markRest}>Còn lại: Có mặt ({unmarked.length})</Button></div> : null}
        </div>
        <div className="hmt-att-colhead" aria-hidden="true"><span>Học sinh</span><span>Ghi chú</span><span>Điểm danh</span>{mode === "ops" ? <span>Lý do liên hệ</span> : null}</div>
        <ul className="hmt-att-list" ref={listRef} data-mode={mode}>
          {students.map((s: any) => (
            <li key={s.id} className="hmt-att-item" data-sid={s.id} data-unmarked={!marks[s.id] ? "true" : undefined}>
              <PersonLine name={s.name} meta={s.meta} avatar={s.avatar} />
              {!marks[s.id] || s.note ? <div className="hmt-att-info">
                {!marks[s.id] ? <span className="hmt-att-flag"><Icon name="alert" /> Chưa điểm danh</span> : null}
                {s.note ? <span className="hmt-att-note">Ghi chú: {s.note}</span> : null}
              </div> : <div className="hmt-att-info" />}
              <SegmentedControl name={`att-${mode}-${s.id}`} label={`Điểm danh ${s.name}`} options={ATT_STATUSES} value={marks[s.id]} onChange={(v: any) => set(s.id, v)} colored layout="row" />
              {mode === "ops" ? (
                <Field label="Lý do liên hệ" optional>
                  <Select value={reasons[s.id]} onChange={(e: any) => { setReasons({ ...reasons, [s.id]: e.target.value }); persist(marks); }} placeholder="Chọn lý do liên hệ" options={CONTACT_REASONS.map((r) => ({ value: r, label: r }))} />
                </Field>) : null}
            </li>))}
        </ul>
        <div className="hmt-att-foot">
          <div className="hmt-att-sum" aria-live="polite">
            {counts.map((c: any) => <span key={c.value}><b>{c.n}</b> {c.label.toLowerCase()}</span>)}
            {unmarked.length ? <span style={{ color: "var(--hmt-warning)" }}><b>{unmarked.length}</b> chưa điểm danh</span> : null}
          </div>
          {save === "error" ? <Alert tone="danger" title="Chưa lưu được điểm danh" actions={<Button variant="tertiary" size="sm" onClick={() => persist(marks)}>Thử lại</Button>}>Dữ liệu vẫn nằm trên máy này. Kiểm tra kết nối rồi thử lại.</Alert> : null}
          {onRequestNext ? <Button fullWidth iconEnd="arrowRight" onClick={next}>Tiếp: Nội dung buổi</Button> : null}
        </div>
        <BlockingDialog open={blocked} onClose={() => setBlocked(false)} title="Chưa thể sang bước tiếp"
          description="Mỗi em có tên trong danh sách cần một trạng thái điểm danh."
          reasons={unmarked.map((s: any) => ({ text: `${s.name} chưa điểm danh`, actionLabel: "Đến em này", onAction: () => { setBlocked(false); setTimeout(() => focusStudent(s.id), 50); } }))} />
      </section>
    );
  }

  /* ======================= BlockingDialog ======================= */
  /* kind "block": lỗi chặn — chỉ đóng, mỗi lý do có nút đến chỗ sửa · kind "warn": cảnh báo — vẫn làm tiếp được */
  function BlockingDialog({ open, onClose, kind = "block", title, description, reasons = [], continueLabel = "Vẫn tiếp tục", onContinue }: any) {
    return (
      <Dialog open={open} onClose={onClose} title={title} description={description} tone={kind === "block" ? "danger" : "warning"} role="alertdialog"
        footer={kind === "block"
          ? <Button variant="secondary" onClick={onClose} data-cancel="">Đóng</Button>
          : <Fragment><Button variant="secondary" onClick={onClose} data-cancel="">Quay lại</Button><Button onClick={() => { onContinue && onContinue(); onClose(); }}>{continueLabel}</Button></Fragment>}>
        <p className="hmt-block-kind">{kind === "block" ? <Fragment><Icon name="ban" /> Lỗi chặn — cần sửa trước khi tiếp tục</Fragment> : <Fragment><Icon name="alert" /> Cảnh báo — vẫn có thể tiếp tục</Fragment>}</p>
        <ul className="hmt-block-list">
          {reasons.map((r: any, i: number) => (
            <li key={i}><span className="hmt-block-ico"><Icon name={kind === "block" ? "xcircle" : "alert"} /></span>
              <span style={{ flex: 1 }}>{r.text}{r.detail ? <span className="hmt-person-meta" style={{ display: "block" }}>{r.detail}</span> : null}</span>
              {r.actionLabel ? <Button variant="tertiary" size="sm" iconEnd="arrowRight" onClick={r.onAction}>{r.actionLabel}</Button> : null}</li>))}
        </ul>
      </Dialog>
    );
  }

  /* ======================= StatusBar ======================= */
  function StatusBar({ steps, current, terminal, substatus, forwardOnly, locked, actions, onStepClick, label = "Trạng thái" }: any) {
    const wrap = useRef(null); const narrow = useNarrow(wrap, 640); const [open, setOpen] = useState(false);
    const idx = steps.findIndex((s: any) => s.id === current);
    const cur = steps[idx];
    const canClick = (i: number) => onStepClick && !terminal && !locked && (forwardOnly ? i > idx : i !== idx);
    const stepList = (vertical?: boolean) => (
      <ol className={cx("hmt-sb-steps", vertical && "hmt-sb-steps--v")} aria-label={label}>
        {steps.map((s: any, i: number) => {
          const st = terminal ? (i <= idx ? "done" : "todo") : i < idx ? "done" : i === idx ? "current" : "todo";
          const abbr = !vertical && steps.length > 5 && st !== "current" && s.short;
          const inner = <Fragment><span className="hmt-sb-dot" aria-hidden="true">{st === "done" ? <Icon name="check" /> : i + 1}</span><span className="hmt-sb-label" title={abbr ? s.label : undefined}>{abbr ? <Fragment><span aria-hidden="true">{s.short}</span><span className="hmt-sr">{s.label}</span></Fragment> : s.label}</span></Fragment>;
          return (
            <li key={s.id} className="hmt-sb-step" data-state={st} aria-current={st === "current" ? "step" : undefined}>
              {canClick(i) ? <button type="button" className="hmt-sb-btn hmt-focus" onClick={() => { setOpen(false); onStepClick(s.id); }}>{inner}</button> : <span className="hmt-sb-btn" aria-disabled={!canClick(i) && st !== "current" ? true : undefined}>{inner}</span>}
              <span className="hmt-sr">{st === "done" ? " (đã qua)" : st === "current" ? " (hiện tại)" : ""}</span>
            </li>);
        })}
      </ol>
    );
    return (
      <div className="hmt-sb" ref={wrap}>
        {actions ? <div className="hmt-sb-actions">{actions}</div> : null}
        {narrow ? (
          <div className="hmt-sb-compact">
            <span className="hmt-sb-cur"><span className="hmt-person-meta">Bước {idx + 1}/{steps.length}</span><b>{cur && cur.label}</b>{substatus ? <span className="hmt-person-meta">{substatus}</span> : null}</span>
            <Button variant="secondary" size="sm" onClick={() => setOpen(true)}>Các bước</Button>
            <Drawer open={open} onClose={() => setOpen(false)} placement="bottom" title="Các bước">{stepList(true)}{forwardOnly ? <p className="hmt-help">Chỉ đi tới, không lùi bước.</p> : null}</Drawer>
          </div>
        ) : (
          <div className="hmt-sb-main">
            {stepList()}
            {substatus ? <span className="hmt-sb-sub"><Icon name="layers" /> {substatus}</span> : null}
          </div>
        )}
        <div className="hmt-sb-flags">
          {terminal ? <Badge tone={terminal.tone || "danger"} solid icon={terminal.icon || "ban"}>{terminal.label}</Badge> : null}
          {locked ? <span className="hmt-sb-lock"><Icon name="lock" /> Đã khoá</span> : null}
          {forwardOnly && !narrow ? <span className="hmt-help">Chỉ đi tới</span> : null}
        </div>
      </div>
    );
  }

  /* ======================= SmartButton ======================= */
  function SmartButton({ icon, label, count, onClick }: any) {
    return (
      <button type="button" className="hmt-smart hmt-focus" onClick={onClick} aria-label={`${label}: ${count}`}>
        <Icon name={icon} /><span className="hmt-smart-text"><span className="hmt-smart-count hmt-tabular">{count}</span><span className="hmt-smart-label">{label}</span></span>
      </button>
    );
  }
  function SmartButtonGroup({ items, max = 4 }: any) {
    const shown = items.slice(0, items.length > max ? max - 1 : max); const rest = items.slice(shown.length);
    return (
      <div className="hmt-smarts" role="group" aria-label="Liên kết của bản ghi">
        {shown.map((it: any) => <SmartButton key={it.label} {...it} />)}
        {rest.length ? <Popover label="Liên kết khác" placement="bottom-end" trigger={<button type="button" className="hmt-smart hmt-focus"><Icon name="more" /><span className="hmt-smart-text"><span className="hmt-smart-count hmt-tabular">{rest.length}</span><span className="hmt-smart-label">Thêm</span></span></button>}>
          {(close: any) => <ul className="hmt-menu" style={{ margin: -12 }}>{rest.map((it: any) => <li key={it.label}><button onClick={() => { close(); it.onClick && it.onClick(); }}><Icon name={it.icon} />{it.label}<span className="hmt-tabular" style={{ marginLeft: "auto", fontWeight: 600 }}>{it.count}</span></button></li>)}</ul>}
        </Popover> : null}
      </div>
    );
  }

  /* ======================= Chatter ======================= */
  function fmtTime(d: string) { return d; }
  function Chatter({ entries: initialEntries, people = [], me = "Bạn", onPost }: any) {
    const [entries, setEntries] = useState(initialEntries);
    const [filter, setFilter] = useState("all");
    const [text, setText] = useState(""); const [files, setFiles] = useState([]);
    const [mention, setMention] = useState(null); const [mi, setMi] = useState(0);
    const taRef = useRef(null);
    const list = entries.filter((e: any) => filter === "all" || (filter === "notes" ? e.type === "note" : e.type !== "note"));
    const onType = (e: any) => {
      const v = e.target.value; setText(v);
      const m = /@([\p{L}\s]{0,20})$/u.exec(v.slice(0, e.target.selectionStart));
      setMention(m ? m[1].toLowerCase() : null); setMi(0);
    };
    const matches = mention == null ? [] : people.filter((p: any) => p.name.toLowerCase().includes(mention.trim())).slice(0, 5);
    const pick = (p: any) => { const v = text.replace(/@[\p{L}\s]{0,20}$/u, `@${p.name} `); setText(v); setMention(null); (taRef.current as any).focus(); };
    const post = () => {
      if (!text.trim() && !files.length) return;
      const e = { id: Date.now(), type: "note", author: me, at: "Vừa xong", text: text.trim(), files };
      setEntries([e, ...entries]); setText(""); setFiles([]); onPost && onPost(e);
    };
    const renderText = (t: string) => t.split(/(@[\p{L}]+(?:\s[\p{L}]+){0,3})/u).map((part, i) => part.startsWith("@") && people.some((p: any) => part.startsWith("@" + p.name)) ? <span key={i} className="hmt-mention">{part}</span> : part);
    return (
      <section className="hmt-chatter" aria-label="Ghi chú trao đổi và lịch sử thay đổi">
        <div className="hmt-chatter-compose">
          <label className="hmt-sr" htmlFor="chatter-ta">Ghi chú trao đổi</label>
          <div className="hmt-control hmt-control--area" style={{ position: "relative" }}>
            <textarea id="chatter-ta" ref={taRef} value={text} onChange={onType} placeholder="Ghi chú… gõ @ để nhắc đồng nghiệp" rows={2}
              aria-autocomplete="list" aria-expanded={matches.length > 0} aria-controls="chatter-mention"
              onKeyDown={(e: any) => {
                if (matches.length) { if (e.key === "ArrowDown") { setMi((mi + 1) % matches.length); e.preventDefault(); } else if (e.key === "ArrowUp") { setMi((mi - 1 + matches.length) % matches.length); e.preventDefault(); } else if (e.key === "Enter") { pick(matches[mi]); e.preventDefault(); } else if (e.key === "Escape") { setMention(null); e.stopPropagation(); } }
                else if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) post();
              }} />
            {matches.length ? <ul id="chatter-mention" role="listbox" className="hmt-pop hmt-mention-list" style={{ position: "absolute", top: "100%", left: 0 }}>
              {matches.map((p: any, i: number) => <li key={p.name} role="option" aria-selected={i === mi} onMouseDown={(e: any) => { e.preventDefault(); pick(p); }}><Avatar name={p.name} size="sm" decorative /> {p.name}<span className="hmt-person-meta">{p.role}</span></li>)}
            </ul> : null}
          </div>
          {files.length ? <div className="hmt-demo-row">{files.map((f: any) => <span key={f} className="hmt-badge hmt-badge--neutral"><Icon name="paperclip" />{f}</span>)}</div> : null}
          <div className="hmt-chatter-bar">
            <Button variant="tertiary" neutral size="sm" iconOnly="at" label="Nhắc tên" onClick={() => { setText(text + "@"); setMention(""); (taRef.current as any).focus(); }} />
            <Button variant="tertiary" neutral size="sm" iconOnly="paperclip" label="Đính kèm" onClick={() => setFiles([...files, `anh-chup-${files.length + 1}.jpg`])} />
            <span style={{ flex: 1 }} />
            <Button size="sm" iconStart="send" onClick={post}>Gửi ghi chú</Button>
          </div>
        </div>
        <SegmentedControl name="chatter-f" layout="row" label="Lọc dòng thời gian" value={filter} onChange={setFilter}
          options={[{ value: "all", label: "Tất cả" }, { value: "notes", label: "Ghi chú", icon: "message" }, { value: "history", label: "Lịch sử", icon: "history" }]} />
        <ol className="hmt-timeline">
          {list.map((e: any) => (
            <li key={e.id} className="hmt-tl-item" data-type={e.type}>
              <span className="hmt-tl-ico" aria-hidden="true"><Icon name={e.type === "note" ? "message" : e.type === "system" ? "settings" : "history"} /></span>
              <div className="hmt-tl-body">
                <p className="hmt-tl-head"><b>{e.author}</b> <span className="hmt-person-meta" style={{ display: "inline" }}>· {fmtTime(e.at)}</span></p>
                {e.type === "note" ? <p className="hmt-tl-text">{renderText(e.text)}</p> : null}
                {e.changes ? <ul className="hmt-tl-changes">{e.changes.map((c: any, i: number) => <li key={i}><span className="hmt-person-meta" style={{ display: "inline" }}>{c.field}:</span> <s className="hmt-tl-from">{c.from || "trống"}</s> <Icon name="arrowRight" /> <b>{c.to}</b></li>)}</ul> : null}
                {e.text && e.type !== "note" ? <p className="hmt-tl-text">{e.text}</p> : null}
                {e.files && e.files.length ? <div className="hmt-demo-row">{e.files.map((f: any) => <span key={f} className="hmt-badge hmt-badge--neutral"><Icon name="paperclip" />{f}</span>)}</div> : null}
              </div>
            </li>))}
          {!list.length ? <li><StateView compact kind="empty" title={filter === "notes" ? "Chưa có ghi chú" : "Chưa có thay đổi"} /></li> : null}
        </ol>
      </section>
    );
  }

  /* ======================= BulkActionBar ======================= */
  function BulkActionBar({ count, children, onClear, label = "dòng" }: any) {
    return (
      <div className="hmt-bulk" role="region" aria-label="Thao tác hàng loạt">
        <span aria-live="polite" className="hmt-bulk-count"><Icon name="check" /> Đã chọn <b className="hmt-tabular">{count}</b> {label}</span>
        <div className="hmt-bulk-actions">{children}</div>
        <Button variant="tertiary" size="sm" onClick={onClear}>Bỏ chọn</Button>
      </div>
    );
  }

  /* ======================= FilterBar (R-CRM-07) ======================= */
  function FilterBar({ search, onSearch, searchPlaceholder = "Tìm theo tên, SĐT, mã mới, mã cũ", groups = [], value = {}, onChange, advancedCount = 0, onAdvanced,
    groupByOptions = [], groupBy, onGroupBy, favorites = [], onSaveFavorite, onApplyFavorite, columns = [], onColumnsChange, views = ["list"], view = "list", onViewChange, resultCount }: any) {
    const toggle = (g: string, id: string) => { const cur = value[g] || []; onChange({ ...value, [g]: cur.includes(id) ? cur.filter((x: string) => x !== id) : [...cur, id] }); };
    const active = groups.filter((g: any) => (value[g.id] || []).length);
    const [saveOpen, setSaveOpen] = useState(false); const [favName, setFavName] = useState(""); const [favDefault, setFavDefault] = useState(false); const [favShared, setFavShared] = useState("me");
    const VIEW: any = { list: ["list", "Danh sách"], kanban: ["kanban", "Kanban"], calendar: ["calendar", "Lịch"] };
    return (
      <div className="hmt-fb">
        <div className="hmt-fb-row">
          <div className="hmt-fb-search"><TextInput type="search" leadingIcon="search" aria-label="Tìm kiếm" value={search} onChange={(e: any) => onSearch(e.target.value)} placeholder={searchPlaceholder} /></div>
          <Button variant="secondary" iconStart="filter" onClick={onAdvanced}>Lọc nâng cao{advancedCount ? <span className="hmt-badge hmt-badge--count" aria-label={`${advancedCount} điều kiện`}>{advancedCount}</span> : null}</Button>
          {groupByOptions.length ? <Popover label="Nhóm theo" trigger={<Button variant="secondary" iconStart="layers">{groupBy ? `Nhóm: ${groupByOptions.find((o: any) => o.value === groupBy).label}` : "Nhóm theo"}</Button>}>
            {(close: any) => <ul className="hmt-menu" style={{ margin: -12 }}>{[{ value: "", label: "Không nhóm" }, ...groupByOptions].map((o: any) => <li key={o.value}><button onClick={() => { onGroupBy(o.value); close(); }}>{groupBy === o.value || (!groupBy && !o.value) ? <Icon name="check" /> : <span style={{ width: "1.15em" }} />}{o.label}</button></li>)}</ul>}
          </Popover> : null}
          <Popover label="Bộ lọc yêu thích" trigger={<Button variant="secondary" iconStart="bookmark">Yêu thích</Button>}>
            {(close: any) => <div style={{ display: "grid", gap: 4, minWidth: 240, margin: -4 }}>
              <ul className="hmt-menu">{favorites.map((f: any) => <li key={f.name}><button onClick={() => { onApplyFavorite && onApplyFavorite(f); close(); }}><Icon name="bookmark" />{f.name}{f.isDefault ? <span className="hmt-badge hmt-badge--neutral" style={{ marginLeft: "auto" }}>Mặc định</span> : null}{f.shared ? <span className="hmt-person-meta" style={{ marginLeft: f.isDefault ? 4 : "auto" }}>Dùng chung</span> : null}</button></li>)}</ul>
              <Button variant="tertiary" size="sm" iconStart="plus" onClick={() => { close(); setSaveOpen(true); }}>Lưu bộ lọc hiện tại…</Button>
            </div>}
          </Popover>
          <span style={{ flex: 1 }} />
          {columns.length ? <Popover label="Chọn cột" placement="bottom-end" trigger={<Button variant="secondary" iconOnly="columns" label="Chọn cột" />}>
            <fieldset style={{ border: 0, margin: 0, padding: 0, display: "grid", gap: 8 }}><legend className="hmt-label" style={{ marginBottom: 6 }}>Cột hiển thị</legend>
              {columns.map((c: any) => <label key={c.key} style={{ display: "flex", gap: 8, alignItems: "center" }}><input type="checkbox" className="hmt-check" checked={c.visible} disabled={c.locked} onChange={() => onColumnsChange(columns.map((x: any) => x.key === c.key ? { ...x, visible: !x.visible } : x))} />{c.label}{c.locked ? <span className="hmt-person-meta" style={{ display: "inline" }}>(luôn hiện)</span> : null}</label>)}
            </fieldset>
          </Popover> : null}
          {views.length > 1 ? <div className="hmt-fb-views" role="radiogroup" aria-label="Kiểu xem">{views.map((v: string) => <button key={v} type="button" role="radio" aria-checked={view === v} className="hmt-fb-view hmt-focus" onClick={() => onViewChange(v)} title={VIEW[v][1]}><Icon name={VIEW[v][0]} /><span className="hmt-sr">{VIEW[v][1]}</span></button>)}</div> : null}
        </div>
        <div className="hmt-fb-row hmt-fb-chips">
          {groups.map((g: any, gi: number) => (
            <div key={g.id} className="hmt-fb-group" role="group" aria-label={g.label}>
              <span className="hmt-fb-glabel">{g.label}</span>
              {g.options.map((o: any) => <Chip key={o.id} selected={(value[g.id] || []).includes(o.id)} onToggle={() => toggle(g.id, o.id)} count={o.count}>{o.label}</Chip>)}
              {gi < groups.length - 1 ? <span className="hmt-fb-sep" aria-hidden="true" /> : null}
            </div>))}
        </div>
        <div className="hmt-fb-summary" aria-live="polite">
          <span className="hmt-tabular"><b>{resultCount != null ? resultCount.toLocaleString("vi-VN") : "—"}</b> kết quả</span>
          {active.length ? <span className="hmt-person-meta" style={{ display: "inline" }}>· Đang lọc: {active.map((g: any) => "(" + (value[g.id] || []).map((id: string) => g.options.find((o: any) => o.id === id).label).join(" hoặc ") + ")").join(" và ")}</span> : null}
          {active.length ? <Button variant="tertiary" size="sm" onClick={() => onChange({})}>Xoá lọc nhanh</Button> : null}
        </div>
        <Dialog open={saveOpen} onClose={() => setSaveOpen(false)} title="Lưu bộ lọc yêu thích"
          footer={<Fragment><Button variant="secondary" onClick={() => setSaveOpen(false)}>Huỷ</Button><Button onClick={() => { if (!favName.trim()) return; onSaveFavorite && onSaveFavorite({ name: favName.trim(), isDefault: favDefault, shared: favShared === "all" }); setSaveOpen(false); setFavName(""); }}>Lưu bộ lọc</Button></Fragment>}>
          <div style={{ display: "grid", gap: 12 }}>
            <Field label="Tên bộ lọc" required><TextInput value={favName} onChange={(e: any) => setFavName(e.target.value)} placeholder="Ví dụ: Lịch hẹn quá hạn của tôi" /></Field>
            <label style={{ display: "flex", gap: 8, alignItems: "center" }}><input type="checkbox" className="hmt-check" checked={favDefault} onChange={() => setFavDefault(!favDefault)} />Đặt làm mặc định khi mở danh sách</label>
            <SegmentedControl name="fav-share" layout="row" label="Phạm vi" value={favShared} onChange={setFavShared} options={[{ value: "me", label: "Chỉ mình tôi" }, { value: "all", label: "Dùng chung cơ sở" }]} />
          </div>
        </Dialog>
      </div>
    );
  }

  /* ======================= Kanban ======================= */
  function Kanban({ columns, onMove, canMove, renderCard, label = "Bảng kanban" }: any) {
    const [drag, setDrag] = useState(null); const [over, setOver] = useState(null); const [block, setBlock] = useState(null);
    const tryMove = (cardId: any, from: string, to: string) => {
      if (from === to) return;
      const r = canMove ? canMove(cardId, from, to) : { ok: true };
      if (!r.ok) { setBlock(r); return; }
      onMove(cardId, from, to);
    };
    return (
      <div className="hmt-kb" aria-label={label}>
        {columns.map((col: any) => (
          <section key={col.id} className="hmt-kb-col" data-over={over === col.id ? "true" : undefined} aria-label={`${col.label}: ${col.cards.length} thẻ`}
            onDragOver={(e: any) => { e.preventDefault(); setOver(col.id); }} onDragLeave={() => setOver(null)}
            onDrop={(e: any) => { e.preventDefault(); setOver(null); if (drag) tryMove((drag as any).id, (drag as any).from, col.id); setDrag(null); }}>
            <header className="hmt-kb-head"><span className="hmt-kb-title">{col.label}</span><span className="hmt-badge hmt-badge--neutral hmt-tabular">{col.cards.length}</span></header>
            <ul className="hmt-kb-list">
              {col.cards.map((c: any) => (
                <li key={c.id} className="hmt-kb-card" draggable onDragStart={() => setDrag({ id: c.id, from: col.id })} onDragEnd={() => setDrag(null)}>
                  {renderCard ? renderCard(c) : <KanbanCard card={c} />}
                  <div className="hmt-kb-move">
                    <Popover label={`Chuyển ${c.code}`} placement="bottom-end" trigger={<Button variant="tertiary" neutral size="sm" iconOnly="moreV" label={`Chuyển ${c.code} sang giai đoạn khác`} />}>
                      {(close: any) => <ul className="hmt-menu" style={{ margin: -12 }}><li className="hmt-person-meta" style={{ padding: "6px 10px" }}>Chuyển sang</li>{columns.filter((x: any) => x.id !== col.id).map((x: any) => <li key={x.id}><button onClick={() => { close(); tryMove(c.id, col.id, x.id); }}>{x.label}</button></li>)}</ul>}
                    </Popover>
                  </div>
                </li>))}
              {!col.cards.length ? <li className="hmt-kb-empty">Không có thẻ</li> : null}
            </ul>
          </section>))}
        <BlockingDialog open={!!block} onClose={() => setBlock(null)} title="Không chuyển được giai đoạn" reasons={block ? [{ text: (block as any).reason, detail: (block as any).detail }] : []} />
      </div>
    );
  }
  function KanbanCard({ card }: any) {
    return (
      <div className="hmt-kb-cardin">
        {card.onOpen ? <a href="#" className="hmt-link hmt-tabular hmt-kb-code" title={card.openLabel || `Mở ${card.code}`} onClick={(e: any) => { e.preventDefault(); e.stopPropagation(); card.onOpen(); }} onMouseDown={(e: any) => e.stopPropagation()} draggable={false}>{card.code}</a> : <span className="hmt-person-meta hmt-tabular" style={{ display: "block" }}>{card.code}</span>}
        <p className="hmt-kb-name">{card.title}</p>
        {card.lines ? card.lines.map((l: string, i: number) => <p key={i} className="hmt-kb-line">{l}</p>) : null}
        <div className="hmt-kb-foot">{card.owner ? <span style={{ display: "inline-flex", gap: 6, alignItems: "center" }}><Avatar name={card.owner} size="sm" decorative /><span className="hmt-kb-line">{card.owner}</span></span> : null}{card.due ? <span style={{ marginLeft: "auto" }}>{card.due}</span> : null}</div>
      </div>
    );
  }

  /* ======================= Calendar (lịch buổi) ======================= */
  const SESSION_TYPES: any = { chinh: { label: "Chính", cat: 1 }, cungco: { label: "Củng cố", cat: 2 }, hocbu: { label: "Học bù", cat: 3 }, botro: { label: "Học bổ trợ", cat: 4 } };
  const WD = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
  function hm(t: string) { const [h, m] = t.split(":").map(Number); return h + m / 60; }
  function EventChip({ ev, compact, onOpen, types = SESSION_TYPES }: any) {
    const t = types[ev.type] || { label: ev.type, cat: 4 };
    /* conflict: true | "room" = trùng phòng; "teacher" = trùng giáo viên; "both" = cả hai (cảnh báo, không chặn) */
    const cf = ev.conflict === true || ev.conflict === "room" ? "Trùng phòng" : ev.conflict === "teacher" ? "Trùng giáo viên" : ev.conflict ? "Trùng phòng, giáo viên" : "";
    return (
      <button type="button" className="hmt-ev hmt-focus" data-cat={t.cat} data-cancelled={ev.cancelled ? "true" : undefined} onClick={() => onOpen && onOpen(ev)}
        aria-label={`${ev.title}, ${t.label}, ${ev.start}–${ev.end}, ${ev.room}${ev.cancelled ? ", đã huỷ" : ""}${cf ? `, ${cf.toLowerCase()}` : ""}`}>
        <span className="hmt-ev-type">{t.label}{ev.cancelled ? " · Huỷ" : ""}</span>
        <span className="hmt-ev-title">{ev.title}</span>
        {!compact ? <span className="hmt-ev-meta">{ev.start}–{ev.end} · {ev.room} · {ev.teacher}</span> : null}
        {cf ? <span className="hmt-ev-conflict"><Icon name="alert" /> {cf}</span> : null}
      </button>
    );
  }
  function Calendar({ events, view = "week", onViewChange, by = "room", onByChange, resources = [], weekStart, day, onOpen, startHour = 7, endHour = 22, types = SESSION_TYPES, legendLabel = "Chú thích loại buổi", cancelledLabel = "Buổi huỷ" }: any) {
    const H = 44; const hours = Array.from({ length: endHour - startHour }, (_, i) => startHour + i);
    const pos = (ev: any) => ({ top: (hm(ev.start) - startHour) * H, height: Math.max(22, (hm(ev.end) - hm(ev.start)) * H - 2) });
    const cols = view === "day" ? resources : WD;
    const colEvents = (c: string, i: number) => view === "day" ? events.filter((e: any) => e.date === day && (by === "room" ? e.room : e.teacher) === c) : events.filter((e: any) => e.dow === i);
    const layout = (evs: any[]) => { const out = evs.map((e: any) => ({ e, s: hm(e.start), t: hm(e.end) })); return out.map((x: any) => { const ov = out.filter((y: any) => y.s < x.t && x.s < y.t); const k = ov.indexOf(x); return { ...x, n: ov.length, k }; }); };
    const gridRef = useRef(null);
    useEffect(() => { if (gridRef.current) (gridRef.current as any).scrollTop = (16 - startHour) * H; }, [view]);
    const head = (
      <div className="hmt-cal2-bar">
        <SegmentedControl name="calv" layout="row" label="Kiểu xem lịch" value={view} onChange={onViewChange} options={[{ value: "day", label: "Ngày" }, { value: "week", label: "Tuần" }, { value: "month", label: "Tháng" }]} />
        {view === "day" ? <SegmentedControl name="calb" layout="row" label="Xem theo" value={by} onChange={onByChange} options={[{ value: "room", label: "Theo phòng" }, { value: "person", label: "Theo giáo viên" }]} /> : null}
        <span style={{ flex: 1 }} />
        <ul className="hmt-cal2-legend" aria-label={legendLabel}>{Object.keys(types).map((k) => <li key={k} data-cat={types[k].cat}><span className="hmt-cal2-sw" aria-hidden="true" />{types[k].label}</li>)}<li><s>{cancelledLabel}</s></li></ul>
      </div>
    );
    if (view === "month") {
      const days = Array.from({ length: 35 }, (_, i) => i - 2);
      return (
        <div className="hmt-cal2">{head}
          <div className="hmt-cal2-month" role="grid" aria-label="Tháng 10/2026">
            {WD.map((d) => <div key={d} className="hmt-cal2-mh" role="columnheader">{d}</div>)}
            {days.map((n, i) => { const evs = events.filter((e: any) => e.mday === n); return (
              <div key={i} className="hmt-cal2-mcell" role="gridcell" data-out={n < 1 || n > 31 ? "true" : undefined}>
                <span className="hmt-cal2-mnum hmt-tabular">{n < 1 ? 30 + n : n > 31 ? n - 31 : n}</span>
                {evs.slice(0, 2).map((e: any) => <EventChip key={e.id} ev={e} compact onOpen={onOpen} types={types} />)}
                {evs.length > 2 ? <button type="button" className="hmt-cal2-more hmt-focus">+{evs.length - 2} buổi</button> : null}
              </div>); })}
          </div>
        </div>
      );
    }
    return (
      <div className="hmt-cal2">{head}
        <div ref={gridRef} className="hmt-cal2-grid" style={{ gridTemplateColumns: `56px repeat(${cols.length}, minmax(170px,1fr))` }}>
          <div className="hmt-cal2-corner" />
          {cols.map((c: string, i: number) => <div key={c} className="hmt-cal2-ch">{view === "week" ? `${c} ${weekStart + i}/10` : c}</div>)}
          <div className="hmt-cal2-times">{hours.map((h) => <div key={h} style={{ height: H }} className="hmt-tabular">{String(h).padStart(2, "0")}:00</div>)}</div>
          {cols.map((c: string, i: number) => (
            <div key={c} className="hmt-cal2-col" style={{ height: hours.length * H }}>
              {hours.map((h) => <div key={h} className="hmt-cal2-slot" style={{ height: H }} />)}
              {layout(colEvents(c, i)).map((x: any) => <div key={x.e.id} className="hmt-cal2-pos" style={{ ...pos(x.e), left: `calc(${(x.k / x.n) * 100}% + 3px)`, width: `calc(${100 / x.n}% - 6px)`, right: "auto" }}><EventChip ev={x.e} compact={x.n > 1} onOpen={onOpen} types={types} /></div>)}
            </div>))}
        </div>
      </div>
    );
  }

  /* ======================= Combobox ======================= */
  function norm(s: string) { return (s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").replace(/Đ/g, "D").toLowerCase(); }
  function Combobox({ options, value, onChange, multiple, placeholder = "Gõ tên, mã hoặc mã cũ", invalid, disabled, loading, emptyText = "Không tìm thấy kết quả", ...rest }: any) {
    const f = useField({ invalid, ...rest });
    const [q, setQ] = useState(""); const [open, setOpen] = useState(false); const [act, setAct] = useState(0);
    const listId = useId(); const wrap = useRef(null); const inp = useRef(null);
    const sel: any[] = multiple ? (value || []) : value ? [value] : [];
    const results = options.filter((o: any) => !q || [o.label, o.code, o.legacyCode].some((x) => norm(x).includes(norm(q)))).slice(0, 8);
    const choose = (o: any) => {
      if (o.disabled) return;
      if (multiple) { onChange(sel.includes(o.value) ? sel.filter((v) => v !== o.value) : [...sel, o.value]); setQ(""); }
      else { onChange(o.value); setQ(""); setOpen(false); }
    };
    useEffect(() => { if (!open) return; const h = (e: any) => { if (wrap.current && !(wrap.current as any).contains(e.target)) setOpen(false); }; document.addEventListener("mousedown", h); return () => document.removeEventListener("mousedown", h); }, [open]);
    const single = !multiple && sel.length ? options.find((o: any) => o.value === sel[0]) : null;
    return (
      <div className="hmt-cbx" ref={wrap}>
        <div className={cx("hmt-control", multiple && "hmt-cbx-multi")} data-invalid={f["aria-invalid"] ? "true" : undefined} data-disabled={disabled ? "true" : undefined} onClick={() => (inp.current as any).focus()}>
          <span className="hmt-adorn"><Icon name="search" /></span>
          {multiple ? sel.map((v) => { const o = options.find((x: any) => x.value === v); return <span key={v} className="hmt-cbx-tag">{o ? o.label : v}<button type="button" aria-label={`Bỏ ${o ? o.label : v}`} onClick={(e: any) => { e.stopPropagation(); onChange(sel.filter((x) => x !== v)); }}><Icon name="x" /></button></span>; }) : null}
          <input ref={inp} {...f} role="combobox" aria-expanded={open} aria-controls={listId} aria-autocomplete="list" aria-activedescendant={open && results[act] ? `${listId}-${act}` : undefined}
            value={open || !single ? q : `${single.label} · ${single.code}`} placeholder={sel.length && multiple ? "" : placeholder} disabled={disabled}
            onFocus={() => setOpen(true)} onBlur={() => setTimeout(() => { if (wrap.current && !(wrap.current as any).contains(document.activeElement)) setOpen(false); }, 120)} onChange={(e: any) => { setQ(e.target.value); setOpen(true); setAct(0); }}
            onKeyDown={(e: any) => {
              const step = (d: number) => { for (let k = act + d; k >= 0 && k < results.length; k += d) if (!results[k].disabled) return k; return act; };
              if (e.key === "ArrowDown") { setOpen(true); setAct(step(1)); e.preventDefault(); }
              else if (e.key === "ArrowUp") { setAct(step(-1)); e.preventDefault(); }
              else if (e.key === "Tab") setOpen(false);
              else if (e.key === "Enter" && open && results[act]) { choose(results[act]); e.preventDefault(); }
              else if (e.key === "Escape") { setOpen(false); e.stopPropagation(); }
              else if (e.key === "Backspace" && !q && multiple && sel.length) onChange(sel.slice(0, -1));
            }} />
          {!multiple && single && !disabled ? <button type="button" className="hmt-cbx-clear" aria-label="Xoá lựa chọn" onClick={(e: any) => { e.stopPropagation(); onChange(null); }}><Icon name="x" /></button> : null}
        </div>
        {open ? (
          <ul id={listId} role="listbox" aria-multiselectable={multiple || undefined} className="hmt-pop hmt-cbx-list">
            {loading ? <li className="hmt-cbx-none"><span className="hmt-spinner" /> Đang tìm…</li>
              : !results.length ? <li className="hmt-cbx-none" role="option" aria-disabled="true"><Icon name="search" /> {emptyText}{q ? ` cho “${q}”` : ""}</li>
              : results.map((o: any, i: number) => {
                const on = sel.includes(o.value);
                return (
                  <li key={o.value} id={`${listId}-${i}`} role="option" aria-selected={on} aria-disabled={o.disabled || undefined} className="hmt-cbx-opt" data-active={i === act ? "true" : undefined}
                    onMouseDown={(e: any) => { e.preventDefault(); choose(o); }} onMouseEnter={() => setAct(i)}>
                    {multiple ? <span className="hmt-cbx-box" aria-hidden="true">{on ? <Icon name="check" /> : null}</span> : null}
                    <span style={{ flex: 1, minWidth: 0 }}>
                      <span className="hmt-cbx-main">{o.label} <span className="hmt-tabular hmt-cbx-code">{o.code}</span></span>
                      {o.legacyCode ? <span className="hmt-cbx-sub">Mã cũ: {o.legacyCode}</span> : null}
                      {o.meta ? <span className="hmt-cbx-sub">{o.meta}</span> : null}
                    </span>
                    {o.disabled ? <span className="hmt-badge hmt-badge--neutral">{o.disabledReason || "Không chọn được"}</span> : !multiple && on ? <Icon name="check" /> : null}
                  </li>);
              })}
          </ul>) : null}
      </div>
    );
  }

  /* ======================= DateRange ======================= */
  function DateRange({ value, onChange, today = new Date(2026, 9, 11) }: any) {
    const [open, setOpen] = useState(false); const [pick, setPick] = useState(null); const ref = useRef(null);
    const d0 = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
    const monday = (d: Date) => { const x = d0(d); x.setDate(x.getDate() - ((x.getDay() + 6) % 7)); return x; };
    const P_: any[] = [
      { id: "today", label: "Hôm nay", r: () => [d0(today), d0(today)] },
      { id: "week", label: "Tuần này", r: () => { const a = monday(today); const b = new Date(a); b.setDate(a.getDate() + 6); return [a, b]; } },
      { id: "month", label: "Tháng này", r: () => [new Date(today.getFullYear(), today.getMonth(), 1), new Date(today.getFullYear(), today.getMonth() + 1, 0)] },
      { id: "last", label: "Tháng trước", r: () => [new Date(today.getFullYear(), today.getMonth() - 1, 1), new Date(today.getFullYear(), today.getMonth(), 0)] },
    ];
    const text = value && value.from ? `${fmt(value.from)} – ${fmt(value.to || value.from)}` : "Chọn khoảng ngày";
    const preset = value && P_.find((p) => { const [a, b] = p.r(); return value.from && value.to && a.getTime() === value.from.getTime() && b.getTime() === value.to.getTime(); });
    return (
      <Fragment>
        <span ref={ref} style={{ display: "inline-flex" }}><Button variant="secondary" iconStart="calendar" iconEnd="chevronDown" aria-haspopup="dialog" aria-expanded={open} onClick={() => setOpen(!open)}>
          {preset ? <span>{preset.label} <span className="hmt-person-meta" style={{ display: "inline" }}>({text})</span></span> : text}</Button></span>
        <PopoverPanel open={open} onClose={() => setOpen(false)} anchorRoot={ref} label="Chọn khoảng ngày">
          <div className="hmt-dr">
            <ul className="hmt-menu hmt-dr-presets">{P_.map((p) => <li key={p.id}><button onClick={() => { const [a, b] = p.r(); onChange({ from: a, to: b }); setOpen(false); }}>{preset && preset.id === p.id ? <Icon name="check" /> : <span style={{ width: "1.15em" }} />}{p.label}</button></li>)}</ul>
            <div>
              <p className="hmt-help" style={{ padding: "8px 8px 0" }}>{pick ? `Từ ${fmt(pick)} — chọn ngày kết thúc` : "Tuỳ chọn: bấm ngày bắt đầu rồi ngày kết thúc"}</p>
              <MonthGrid autoFocus={false} value={null} rangeFrom={pick || (value && value.from)} rangeTo={pick ? null : value && value.to} today={today}
                onSelect={(d: Date) => { if (!pick) setPick(d); else { const [a, b] = d < pick ? [d, pick] : [pick, d]; onChange({ from: a, to: b }); setPick(null); setOpen(false); } }} />
            </div>
          </div>
        </PopoverPanel>
      </Fragment>
    );
  }

  /* ======================= MoneyInput ======================= */
  const vnd = (n: number) => (n == null || isNaN(n) ? "" : Math.round(n).toLocaleString("vi-VN"));
  function MoneyInput({ value, onChange, readOnly, invalid, disabled, systemNote = "Hệ thống tính", ...rest }: any) {
    const f = useField({ invalid, ...rest });
    if (readOnly) return (
      <div className="hmt-control hmt-money hmt-money--ro" data-ro="true">
        <span className="hmt-adorn"><Icon name="lock" /></span>
        <output {...f} className="hmt-money-val hmt-tabular">{vnd(value)}</output><span className="hmt-money-unit">đ</span>
        <span className="hmt-money-note">{systemNote}</span>
      </div>);
    return (
      <div className="hmt-control hmt-money" data-invalid={f["aria-invalid"] ? "true" : undefined} data-disabled={disabled ? "true" : undefined}>
        <input {...rest} {...f} inputMode="numeric" className="hmt-money-val hmt-tabular" value={vnd(value)} disabled={disabled}
          onChange={(e: any) => { const n = parseInt(e.target.value.replace(/\D/g, "") || "0", 10); onChange && onChange(n); }} />
        <span className="hmt-money-unit">đ</span>
      </div>);
  }

  /* ======================= HoursDisplay (R-GD-07) ======================= */
  const hrs = (n: number) => `${String(Math.round(n * 10) / 10).replace(".", ",")} giờ`;
  function HoursDisplay({ granted, used, bonus = 0, bonusLocked, expectedEnd, packageEnd, packageExpired, threshold = 10, compact }: any) {
    const left = granted + (bonusLocked ? 0 : bonus) - used; const total = granted + bonus;
    const low = left <= threshold;
    const pct = (n: number) => `${Math.max(0, (n / total) * 100)}%`;
    return (
      <div className="hmt-hours" data-low={low ? "true" : undefined}>
        <div className="hmt-hours-top">
          <span><b className="hmt-tabular hmt-hours-left">{hrs(left)}</b> còn lại</span>
          {low ? <Badge tone="warning">Sắp hết giờ (≤ {threshold} giờ)</Badge> : null}
        </div>
        <div className="hmt-hours-bar" role="img" aria-label={`Đã dùng ${hrs(used)}, còn lại ${hrs(left)}, giờ tặng ${hrs(bonus)}${bonusLocked ? " chưa cấp" : ""}`}>
          <span className="hmt-hours-used" style={{ width: pct(used) }} />
          <span className="hmt-hours-rest" style={{ width: pct(granted - used) }} />
          <span className="hmt-hours-bonus" data-locked={bonusLocked ? "true" : undefined} style={{ width: pct(bonus) }} />
        </div>
        <ul className="hmt-hours-legend">
          <li><span className="hmt-hours-sw hmt-hours-used" />Đã dùng <b className="hmt-tabular">{hrs(used)}</b></li>
          <li><span className="hmt-hours-sw hmt-hours-rest" />Còn lại (đã cấp) <b className="hmt-tabular">{hrs(Math.max(0, granted - used))}</b></li>
          <li><span className="hmt-hours-sw hmt-hours-bonus" data-locked={bonusLocked ? "true" : undefined} />Giờ tặng <b className="hmt-tabular">{hrs(bonus)}</b>{bonusLocked ? <span className="hmt-person-meta" style={{ display: "inline" }}> · cấp khi thu đủ tiền</span> : null}</li>
        </ul>
        {!compact ? <dl className="hmt-hours-dl">
          <dt>Đã cấp</dt><dd className="hmt-tabular">{hrs(granted)}</dd>
          <dt>Hết giờ dự kiến</dt><dd className="hmt-tabular">{expectedEnd}</dd>
          {packageEnd ? <Fragment><dt>Hạn gói (dự báo)</dt><dd className="hmt-tabular">{packageEnd}</dd></Fragment> : null}
        </dl> : null}
        {packageExpired ? <p className="hmt-hours-info"><Icon name="info" /> Gói đã quá hạn 6 tháng nhưng còn giờ — em vẫn học bình thường. Hạn gói chỉ để dự báo.</p> : null}
      </div>
    );
  }

  /* ======================= RatingScale (R-GV-01/02/04) ======================= */
  function RatingScale({ name, label, value, onChange, descriptions = {}, required }: any) {
    const id = useId();
    return (
      <fieldset className="hmt-rate" data-empty={value == null ? "true" : undefined}>
        <legend className="hmt-rate-label">{label}{required ? <span className="hmt-req" aria-hidden="true"> *</span> : null}</legend>
        <div className="hmt-rate-row">
          {[1, 2, 3, 4, 5].map((n) => (
            <label key={n} className="hmt-rate-opt">
              <input type="radio" name={name} value={n} checked={value === n} onChange={() => onChange(n)} aria-describedby={`${id}-d`} />
              <span className="hmt-tabular">{n}</span>
            </label>))}
          {value != null ? <Button variant="tertiary" neutral size="sm" iconOnly="x" label={`Bỏ chấm ${label}`} onClick={() => onChange(null)} /> : null}
        </div>
        <p id={`${id}-d`} className="hmt-rate-desc" aria-live="polite">{value == null ? <span className="hmt-rate-unset"><Icon name="info" /> Chưa chấm — khác điểm 0</span> : descriptions[value] ? <Fragment><b>Mức {value}:</b> {descriptions[value]}</Fragment> : <b>Mức {value}</b>}</p>
      </fieldset>
    );
  }

  /* ======================= HomeworkStatus (R-GV-11) ======================= */
  const HW: any = {
    graded: { label: "Đã chấm", tone: "success", icon: "check", score: true },
    partial: { label: "Làm chưa xong", tone: "warning", icon: "hourglass", score: true },
    none: { label: "Không làm", tone: "danger", icon: "x", score: false },
    late: { label: "Nộp sau", tone: "info", icon: "clock", score: false },
    na: { label: "Không áp dụng", tone: "neutral", icon: "ban", score: false },
  };
  /* ======================= ScoreInput — điểm số gõ tay (BTVN 1–5 theo R-GV-11; kiểm tra đầu vào 0–10 truyền min/max) ======================= */
  const fmtScore = (n: any) => (n == null ? "" : String(n).replace(".", ","));
  function checkScore(text: string, min: number, max: number, decimals: number) {
    const t = String(text || "").trim().replace(",", ".");
    if (!t) return { value: null, error: null };
    if (!/^\d+([.]\d+)?$/.test(t)) return { value: null, error: `Chỉ nhập số, ví dụ ${Math.round(max * 0.8)}` };
    const dec = (t.split(".")[1] || "").length;
    if (dec > decimals) return { value: null, error: decimals ? `Tối đa ${decimals} chữ số sau dấu phẩy` : `Nhập số nguyên, ví dụ ${Math.round(max * 0.8)}` };
    const n = Number(t);
    if (n < min || n > max) return { value: null, error: `Điểm phải từ ${min} đến ${max}` };
    return { value: n, error: null };
  }
  function ScoreInput({ value, onChange, onErrorChange, min = 1, max = 5, decimals = 1, invalid, disabled, id, ...rest }: any) {
    const [text, setText] = useState(fmtScore(value));
    const focused = useRef(false);
    useEffect(() => { if (!focused.current) setText(fmtScore(value)); }, [value]);
    const f = useField({ invalid, id });
    const commit = (t: string) => { const r = checkScore(t, min, max, decimals); onErrorChange && onErrorChange(r.error); if (!r.error) { onChange && onChange(r.value); setText(fmtScore(r.value)); } };
    return (
      <div className="hmt-control hmt-score" data-invalid={f["aria-invalid"] ? "true" : undefined} data-disabled={disabled ? "true" : undefined}>
        <input {...f} type="text" inputMode={decimals ? "decimal" : "numeric"} autoComplete="off" maxLength={4} value={text} disabled={disabled} placeholder="—"
          onFocus={() => (focused.current = true)}
          onChange={(e: any) => { setText(e.target.value); if (invalid) { const r = checkScore(e.target.value, min, max, decimals); if (!r.error) onErrorChange && onErrorChange(null); } }}
          onBlur={(e: any) => { focused.current = false; commit(e.target.value); }}
          onKeyDown={(e: any) => { if (e.key === "Enter") commit(e.target.value); }} {...rest} />
        <span className="hmt-score-max" aria-hidden="true">/ {max}</span>
      </div>
    );
  }

  /* ======================= HomeworkStatus (R-GV-11; điểm 1–5 gõ tay, một chữ số thập phân — A-47) ======================= */
  function HomeworkStatus({ value, onChange, readOnly, name = "hw", min = 1, max = 5, decimals = 1, showMissing, hideLabels }: any) {
    const v = value || {}; const meta = HW[v.status];
    const [err, setErr] = useState(null);
    if (readOnly) return meta ? <span className="hmt-hw-view"><Badge tone={meta.tone} icon={meta.icon}>{meta.label}</Badge>{meta.score && v.score != null ? <span className="hmt-tabular hmt-hw-score"><b>{fmtScore(v.score)}</b>/{max}</span> : null}</span> : <span className="hmt-badge hmt-badge--neutral hmt-att-empty">— Chưa cập nhật</span>;
    const missing = meta && meta.score && v.score == null;
    const scoreErr = err || (showMissing && missing ? `Nhập điểm từ ${min} đến ${max}` : null);
    return (
      <div className="hmt-hw">
        <div className="hmt-hw-grid">
          <Field label="Trạng thái" required hideLabel={hideLabels} className="hmt-hw-status">
            <Select value={v.status || ""} placeholder="Chọn trạng thái" onChange={(e: any) => { setErr(null); onChange({ status: e.target.value, score: HW[e.target.value].score ? (v.score ?? null) : null }); }}
              options={Object.keys(HW).map((k) => ({ value: k, label: HW[k].label }))} />
          </Field>
          {meta && meta.score ? (
            <div className="hmt-hw-scorefield">
              <Field label={`Điểm (${min}–${max})`} required hideLabel={hideLabels} error={scoreErr || undefined}>
                <ScoreInput name={`${name}-score`} value={v.score ?? null} min={min} max={max} decimals={decimals} invalid={!!scoreErr}
                  onChange={(n: any) => onChange({ ...v, score: n })} onErrorChange={setErr} />
              </Field>
            </div>) : null}
        </div>
        {v.status === "late" ? <p className="hmt-help">Cập nhật điểm ở buổi sau, không cần mở lại buổi này.</p> : null}
      </div>
    );
  }

  /* ======================= Cổng Giáo viên (đợt 5.5) =======================
     TeacherShell (GV-01): cùng 5 mục cho hai bố cục. Điện thoại: tiêu đề trên + thanh dưới. Laptop: menu trái thu gọn + vùng nội dung rộng.
     Chữ 16 (data-product="teacher"); laptop thêm data-device="desktop" để control 40px, dòng 48px. */
  const GV_NAV = [{ id: "today", label: "Hôm nay", icon: "home" }, { id: "cal", label: "Lịch dạy", icon: "calendar" }, { id: "cls", label: "Lớp", icon: "book" }, { id: "todo", label: "Việc cần làm", icon: "clipboard" }, { id: "me", label: "Tài khoản", icon: "users" }];
  function TeacherShell({ device = "phone", activeId = "today", onNavigate, title, onBack, actions, user, badges = {}, saveState, children, height = 740, contentMaxWidth, flush }: any) {
    const items = GV_NAV.map((x) => ({ ...x, badge: badges[x.id] }));
    const nav = (id: any) => onNavigate && onNavigate(id);
    const top = <TopNav leading={onBack ? <Button variant="tertiary" neutral iconOnly="chevronLeft" label="Quay lại" onClick={onBack} /> : undefined} title={title}
      actions={<Fragment>{saveState ? <SaveState state={saveState} /> : null}{actions}<Button variant="tertiary" neutral iconOnly="bell" label="Thông báo" /></Fragment>} />;
    if (device === "laptop") return (
      <div className="hmt-gvshell" data-product="teacher" data-device="desktop" style={{ height }}>
        <Sidebar subtitle="Cổng Giáo viên" collapsed onCollapsedChange={() => {}} activeId={activeId} onNavigate={nav} sections={[{ items }]} footer={user ? <span className="hmt-gvshell-user" title={user}><Avatar name={user} size="sm" /></span> : null} />
        <div className="hmt-gvshell-main">{top}<div className="hmt-gvshell-body" style={{ maxWidth: contentMaxWidth, padding: flush ? 0 : undefined }}>{children}</div></div>
      </div>);
    return (
      <div className="hmt-phone hmt-gvshell-phone" data-product="teacher" style={{ height }}>
        {top}<div className="hmt-gvshell-pbody" style={{ padding: flush ? 0 : undefined }}>{children}</div>
        <BottomNav items={items} activeId={activeId} onNavigate={nav} />
      </div>);
  }


  /* ======================= Cổng Học tập + Phụ huynh (đợt 5.6) =======================
     StudentShell (HT-09): data-product="lms" (chữ 16, control 44). young = học sinh nhỏ (lớp 2–5): chữ 18, control 52, nhãn thanh dưới 14.
     portal "hs": Trang chủ, Bài tập, Lịch, Kết quả, Tài khoản · portal "ph": Trang chủ, Kết quả, Lịch, Học phí, Đề nghị (Q-10, chỉ điện thoại); Tài khoản ở menu ảnh đại diện trên đầu trang.
     Laptop (chỉ học sinh): menu trái mở rộng + nội dung MỘT CỘT giữa trang (tối đa 720px). */
  const HT_NAV = [{ id: "home", label: "Trang chủ", icon: "home" }, { id: "hw", label: "Bài tập", icon: "book" }, { id: "cal", label: "Lịch", icon: "calendar" }, { id: "res", label: "Kết quả", icon: "layers" }, { id: "me", label: "Tài khoản", icon: "users" }];
  const PH_NAV = [{ id: "home", label: "Trang chủ", icon: "home" }, { id: "res", label: "Kết quả", icon: "layers" }, { id: "cal", label: "Lịch", icon: "calendar" }, { id: "fee", label: "Học phí", icon: "wallet" }, { id: "req", label: "Đề nghị", icon: "message" }];
  function StudentShell({ portal = "hs", device = "phone", young, activeId = "home", onNavigate, title, onBack, actions, user, badges = {}, children, height = 740, flush, bottom }: any) {
    const items = (portal === "ph" ? PH_NAV : HT_NAV).map((x) => ({ ...x, badge: badges[x.id] }));
    const nav = (id: any) => onNavigate && onNavigate(id);
    const top = <TopNav leading={onBack ? <Button variant="tertiary" neutral iconOnly="chevronLeft" label="Quay lại" onClick={onBack} /> : undefined} title={title}
      actions={<Fragment>{actions}<Button variant="tertiary" neutral iconOnly="bell" label="Thông báo" />{portal === "ph" ? <Popover label="Tài khoản" placement="bottom-end" trigger={<button type="button" className="hmt-lshell-av hmt-focus" aria-label={`Tài khoản: ${user || ""}`}><Avatar name={user || "?"} size="sm" decorative /></button>}>
        {(close: any) => <ul className="hmt-menu" style={{ margin: -12 }}><li className="hmt-person-meta" style={{ padding: "8px 12px" }}>{user}</li>{[["users", "Tài khoản"], ["lock", "Đổi mật khẩu"], ["logout", "Đăng xuất"]].map(([ic, l]) => <li key={l}><button onClick={() => close()}><Icon name={ic} />{l}</button></li>)}</ul>}
      </Popover> : null}</Fragment>} />;
    if (device === "laptop" && portal !== "ph") return (
      <div className="hmt-lshell" data-product="lms" data-young={young ? "true" : undefined} style={{ height }}>
        <Sidebar subtitle="Học tập" activeId={activeId} onNavigate={nav} sections={[{ items }]} onCollapsedChange={() => {}} footer={user ? <span className="hmt-lshell-user"><Avatar name={user} size="sm" /><span>{user}</span></span> : null} />
        <div className="hmt-lshell-main">{top}<div className="hmt-lshell-scroll"><div className="hmt-lshell-col" style={{ padding: flush ? 0 : undefined }}>{children}</div></div>{bottom ? <div className="hmt-lshell-foot">{bottom}</div> : null}</div>
      </div>);
    return (
      <div className="hmt-phone hmt-lshell-phone" data-product="lms" data-young={young ? "true" : undefined} style={{ height }}>
        {top}<div className="hmt-lshell-pbody" style={{ padding: flush ? 0 : undefined }}>{children}</div>{bottom}
        <BottomNav items={items} activeId={activeId} onNavigate={nav} />
      </div>);
  }

  /* PhotoPages (HT-04): các trang của một bài nộp, theo đúng thứ tự giáo viên sẽ xem.
     page { id, kind: "img"|"pdf", src?, name, size?, pages? (số trang PDF), status: "done"|"uploading"|"error", progress?, error? }
     Sửa: đưa trang lên trước / ra sau (nút, không chỉ kéo), gỡ, thử lại; bấm ảnh để xem to (onView). review = chỉ xem, không có nút sửa. */
  function PhotoPages({ pages, onChange, onView, onRetry, review, onAdd, addLabel = "Thêm trang", columns }: any) {
    const move = (i: number, d: number) => { const a = [...pages]; const j = i + d; if (j < 0 || j >= a.length) return; [a[i], a[j]] = [a[j], a[i]]; onChange && onChange(a); };
    const kb = (n: number) => n > 1e6 ? `${(n / 1e6).toFixed(1).replace(".", ",")} MB` : `${Math.round(n / 1e3)} KB`;
    let pageNo = 0;
    return (
      <ol className="hmt-pp" data-review={review ? "true" : undefined} style={columns ? { gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` } : undefined} aria-label="Các trang bài làm">
        {pages.map((p: any, i: number) => {
          const from = pageNo + 1; pageNo += p.kind === "pdf" ? (p.pages || 1) : 1;
          const lbl = p.kind === "pdf" && (p.pages || 1) > 1 ? `Trang ${from}–${pageNo}` : `Trang ${from}`;
          return (
            <li key={p.id} className="hmt-pp-item" data-status={p.status}>
              <button type="button" className="hmt-pp-thumb hmt-focus" onClick={() => onView && onView(p.id)} aria-label={`Xem ${lbl}: ${p.name}`}>
                {p.kind === "pdf" ? <span className="hmt-pp-pdf"><Icon name="file" size={28} /><b>PDF</b><span>{p.pages || 1} trang</span></span> : <img src={p.src} alt="" />}
                {p.status === "uploading" ? <span className="hmt-pp-over"><span className="hmt-progress-track" role="progressbar" aria-valuenow={p.progress || 0} aria-valuemin={0} aria-valuemax={100} aria-label={`Đang tải ${p.name}`}><span className="hmt-progress-fill" style={{ width: `${p.progress || 0}%`, display: "block" }} /></span><span>Đang tải {p.progress || 0}%</span></span> : null}
                {p.status === "error" ? <span className="hmt-pp-over hmt-pp-over--err"><Icon name="xcircle" /> {p.error || "Chưa tải được"}</span> : null}
              </button>
              <span className="hmt-pp-cap"><b className="hmt-tabular">{lbl}</b><span className="hmt-pp-meta">{p.name}{p.size ? ` · ${kb(p.size)}` : ""}</span></span>
              {review ? null : <span className="hmt-pp-tools">
                {p.status === "error" ? <Button variant="tertiary" size="sm" iconStart="refresh" onClick={() => onRetry && onRetry(p.id)}>Thử lại</Button> : <Fragment>
                  <Button variant="tertiary" neutral size="sm" iconOnly="chevronLeft" label={`Đưa ${lbl} lên trước`} disabled={i === 0} onClick={() => move(i, -1)} />
                  <Button variant="tertiary" neutral size="sm" iconOnly="chevronRight" label={`Đưa ${lbl} ra sau`} disabled={i === pages.length - 1} onClick={() => move(i, 1)} /></Fragment>}
                <Button variant="tertiary" neutral size="sm" iconOnly="trash" label={`Gỡ ${lbl}`} onClick={() => onChange && onChange(pages.filter((x: any) => x.id !== p.id))} />
              </span>}
            </li>);
        })}
        {onAdd && !review ? <li className="hmt-pp-item"><button type="button" className="hmt-pp-add hmt-focus" onClick={onAdd}><Icon name="plus" size={24} /><span>{addLabel}</span></button></li> : null}
      </ol>
    );
  }

  /* SubmissionViewer (GV-18, HT-05): xem ảnh / PDF học sinh nộp. Chuyển trang (← →), phóng to (+ −), xoay 90°, vừa khung; dãy trang nhỏ bên dưới.
     pages [{ id, src, label }] — PDF đã tách trang. Phím: ← → đổi trang, + − phóng, R xoay. */
  function SubmissionViewer({ pages, page = 0, onPage, height = 420, compact }: any) {
    const [z, setZ] = useState(1); const [r, setR] = useState(0);
    const cur = pages[page] || pages[0];
    const go = (i: number) => { if (i < 0 || i >= pages.length) return; onPage && onPage(i); setZ(1); setR(0); };
    const key = (e: any) => { const k = e.key; if (k === "ArrowRight") go(page + 1); else if (k === "ArrowLeft") go(page - 1); else if (k === "+" || k === "=") setZ(Math.min(3, z + 0.25)); else if (k === "-") setZ(Math.max(0.5, z - 0.25)); else if (k === "r" || k === "R") setR((r + 90) % 360); else return; e.preventDefault(); };
    return (
      <div className="hmt-sv" data-compact={compact ? "true" : undefined}>
        <div className="hmt-sv-bar">
          <Button variant="tertiary" neutral size="sm" iconOnly="chevronLeft" label="Trang trước" disabled={page === 0} onClick={() => go(page - 1)} />
          <span className="hmt-tabular hmt-sv-pg" aria-live="polite">Trang {page + 1}/{pages.length}</span>
          <Button variant="tertiary" neutral size="sm" iconOnly="chevronRight" label="Trang sau" disabled={page === pages.length - 1} onClick={() => go(page + 1)} />
          <span className="hmt-sv-sp" />
          <Button variant="tertiary" neutral size="sm" iconOnly="zoomOut" label="Thu nhỏ" disabled={z <= 0.5} onClick={() => setZ(Math.max(0.5, z - 0.25))} />
          <span className="hmt-tabular hmt-sv-z">{Math.round(z * 100)}%</span>
          <Button variant="tertiary" neutral size="sm" iconOnly="zoomIn" label="Phóng to" disabled={z >= 3} onClick={() => setZ(Math.min(3, z + 0.25))} />
          <Button variant="tertiary" neutral size="sm" iconOnly="rotateCw" label="Xoay 90 độ" onClick={() => setR((r + 90) % 360)} />
          {compact ? null : <Button variant="tertiary" neutral size="sm" onClick={() => { setZ(1); setR(0); }}>Vừa khung</Button>}
        </div>
        <div className="hmt-sv-stage hmt-focus" tabIndex={0} role="group" aria-label={`Bài làm, ${cur.label || `trang ${page + 1}`}. Phím mũi tên đổi trang, + − phóng, R xoay`} onKeyDown={key} style={{ height }}>
          <img src={cur.src} alt={cur.label || `Trang ${page + 1}`} style={{ transform: `scale(${z}) rotate(${r}deg)` }} />
        </div>
        {pages.length > 1 ? <div className="hmt-sv-strip" role="tablist" aria-label="Chọn trang">{pages.map((p: any, i: number) => <button key={p.id} type="button" role="tab" aria-selected={i === page} className="hmt-sv-th hmt-focus" onClick={() => go(i)} aria-label={`Trang ${i + 1}`}><img src={p.src} alt="" /><span className="hmt-tabular">{i + 1}</span></button>)}</div> : null}
      </div>
    );
  }

  /* QuickGrid (khuôn K14 · Bảng chấm nhanh trên laptop)
     Hàng = học sinh, cột = trạng thái / tiêu chí. Cột kiểu:
       radio  { field, value, hotkey }       — mỗi cột là một trạng thái của cùng một trường (điểm danh: phím 1–4)
       select { options[{value,label,hotkey,tone,icon}] } — một cột chọn bằng phím số (BTVN: 1–5)
       score  { min, max, decimals, disabled(vals) => lý do } — gõ số, Enter/Tab ghi
       text   — mở ngăn bên (onOpenRow) để viết dài; read { render(vals) } — chỉ đọc, hệ thống tính
     Ô trống (nét đứt, không chữ) khác hẳn điểm. Cột tên + hàng tiêu đề cố định khi cuộn. Lưu tự động (Đang lưu / Đã lưu / Chưa lưu được). */
  function QuickGrid({ rows, columns, values: vIn, onChange, onOpenRow, caption, maxHeight = 520, rowDisabled, rowNote, failOnSave, help = true, onSaveState }: any) {
    const [vals, setVals] = useState(() => JSON.parse(JSON.stringify(vIn || {})));
    const [act, setAct] = useState({ r: 0, c: 0 }); const [edit, setEdit] = useState(null as any); const [err, setErr] = useState({} as any);
    const [save, setSave] = useState(null as any); const tick = useRef(0); const refs = useRef({} as any); const wrap = useRef(null as any); const focusIn = useRef(false);
    const groups = columns.some((c: any) => c.group);
    const field = (col: any) => col.field || col.key;
    const persist = (next: any) => { const t = ++tick.current; setSave("saving"); onSaveState && onSaveState("saving");
      setTimeout(() => { if (t !== tick.current) return; const st = failOnSave && failOnSave(next) ? "error" : "saved"; setSave(st); onSaveState && onSaveState(st); }, 650); onChange && onChange(next); };
    const setVal = (rid: any, f: string, v: any) => { const next = { ...vals, [rid]: { ...(vals[rid] || {}), [f]: v } }; setVals(next); persist(next); };
    const dis = (r: number) => rowDisabled ? rowDisabled(rows[r], vals[rows[r].id] || {}) : null;
    const colDis = (r: number, c: number) => { const col = columns[c]; if (col.kind === "radio") return null; const d = dis(r); if (d) return d; return col.disabled ? col.disabled(vals[rows[r].id] || {}) : null; };
    const go = (r: number, c: number) => { const R = Math.max(0, Math.min(rows.length - 1, r)), C = Math.max(0, Math.min(columns.length - 1, c)); setAct({ r: R, c: C }); setEdit(null); };
    useEffect(() => { if (!focusIn.current) return; const el = refs.current[`${act.r}:${act.c}`]; if (el && !edit) el.focus(); }, [act, edit]);
    const commit = (r: number, c: number, text: string, move: "down" | "right" | "left" | null) => {
      const col = columns[c]; const rid = rows[r].id; const t = String(text).trim().replace(",", ".");
      let v: any = null; let e: any = null;
      if (t) { if (!/^\d+([.]\d+)?$/.test(t)) e = "Chỉ nhập số"; else { const n = Number(t); const dec = (t.split(".")[1] || "").length;
        if (dec > (col.decimals || 0)) e = col.decimals ? `Tối đa ${col.decimals} chữ số sau dấu phẩy` : "Nhập số nguyên"; else if (n < col.min || n > col.max) e = `Thang ${col.min}–${col.max}${n === 0 ? " · ô trống là chưa chấm, không có điểm 0" : ""}`; else v = n; } }
      const k = `${rid}:${col.key}`;
      if (e) { setErr({ ...err, [k]: e }); return false; }
      const ne = { ...err }; delete ne[k]; setErr(ne); setVal(rid, field(col), v); setEdit(null);
      if (move === "down") go(r + 1, c); else if (move === "right") go(c === columns.length - 1 ? r + 1 : r, c === columns.length - 1 ? 0 : c + 1); else if (move === "left") go(r, c - 1);
      return true;
    };
    const hot = (r: number, key: string) => {
      const rid = rows[r].id; const col = columns[act.c];
      if (col.kind === "select") { const o = col.options.find((x: any) => x.hotkey === key); if (o && !colDis(r, act.c)) { setVal(rid, field(col), o.value); return true; } }
      const rc = columns.find((x: any) => x.kind === "radio" && x.hotkey === key);
      if (rc && (col.kind === "radio" || !col.kind || col.kind === "read" || col.kind === "text")) { setVal(rid, rc.field, rc.value); return true; }
      return false;
    };
    const onKey = (e: any, r: number, c: number) => {
      if (edit) return; const col = columns[c]; const k = e.key;
      if (k === "ArrowDown") { e.preventDefault(); go(r + 1, c); } else if (k === "ArrowUp") { e.preventDefault(); go(r - 1, c); }
      else if (k === "ArrowRight") { e.preventDefault(); go(r, c + 1); } else if (k === "ArrowLeft") { e.preventDefault(); go(r, c - 1); }
      else if (k === "Tab") { const atEnd = !e.shiftKey && r === rows.length - 1 && c === columns.length - 1; const atStart = e.shiftKey && r === 0 && c === 0; if (atEnd || atStart) return; e.preventDefault(); if (e.shiftKey) go(c === 0 ? r - 1 : r, c === 0 ? columns.length - 1 : c - 1); else go(c === columns.length - 1 ? r + 1 : r, c === columns.length - 1 ? 0 : c + 1); }
      else if (k === "Enter" || k === "F2") { e.preventDefault(); if (col.kind === "text") onOpenRow && onOpenRow(rows[r]); else if (col.kind === "score" && !colDis(r, c)) setEdit({ r, c, text: vals[rows[r].id] && vals[rows[r].id][field(col)] != null ? String(vals[rows[r].id][field(col)]).replace(".", ",") : "" }); else go(r + 1, c); }
      else if (k === "Backspace" || k === "Delete") { e.preventDefault(); if (col.kind === "radio" || col.kind === "select" || col.kind === "score") { if (!colDis(r, c)) setVal(rows[r].id, field(col), null); } }
      else if (k === " " && col.kind === "radio") { e.preventDefault(); setVal(rows[r].id, col.field, col.value); }
      else if (/^[0-9]$/.test(k)) { if (col.kind === "score") { e.preventDefault(); if (!colDis(r, c)) setEdit({ r, c, text: k }); } else if (hot(r, k)) e.preventDefault(); }
    };
    const cell = (r: number, c: number) => {
      const col = columns[c]; const row = rows[r]; const v = (vals[row.id] || {})[field(col)]; const d = colDis(r, c); const active = act.r === r && act.c === c;
      const k = `${row.id}:${col.key}`; const er = err[k];
      const common = { ref: (el: any) => (refs.current[`${r}:${c}`] = el), tabIndex: active ? 0 : -1, onFocus: () => { focusIn.current = true; if (!active) setAct({ r, c }); }, onKeyDown: (e: any) => onKey(e, r, c), "data-active": active ? "true" : undefined };
      if (col.kind === "radio") { const on = v === col.value;
        return <td key={col.key} className="hmt-qg-c hmt-qg-radio" data-tone={on ? col.tone : undefined} role="gridcell" aria-label={`${row.name}: ${col.label}${on ? " (đang chọn)" : ""}`} {...common} onClick={() => setVal(row.id, col.field, on ? null : col.value)}>
          <span className="hmt-qg-dot" data-on={on ? "true" : undefined}>{on ? <Icon name={col.icon || "check"} /> : null}</span></td>; }
      if (col.kind === "select") { const o = col.options.find((x: any) => x.value === v);
        return <td key={col.key} className="hmt-qg-c" role="gridcell" aria-label={`${row.name}: ${col.label} ${o ? o.label : "chưa chọn"}`} aria-disabled={d ? true : undefined} {...common}>
          {d ? <span className="hmt-qg-na">{d}</span> : o ? <Badge tone={o.tone} icon={o.icon}>{o.label}</Badge> : <span className="hmt-qg-empty" aria-hidden="true" />}</td>; }
      if (col.kind === "score") {
        const editing = edit && edit.r === r && edit.c === c;
        return <td key={col.key} className="hmt-qg-c hmt-qg-num" role="gridcell" data-err={er ? "true" : undefined} aria-disabled={d ? true : undefined} aria-label={`${row.name}: ${col.label} ${v != null ? String(v).replace(".", ",") : "chưa chấm"}${er ? ". Lỗi: " + er : ""}`} {...common}
          onDoubleClick={() => !d && setEdit({ r, c, text: v != null ? String(v).replace(".", ",") : "" })}>
          {editing ? <input className="hmt-qg-input" autoFocus inputMode={col.decimals ? "decimal" : "numeric"} value={edit.text} aria-label={`${col.label} của ${row.name}, thang ${col.min}–${col.max}`}
              onChange={(e: any) => setEdit({ ...edit, text: e.target.value })}
              onKeyDown={(e: any) => { if (e.key === "Enter") { e.preventDefault(); commit(r, c, e.target.value, "down"); } else if (e.key === "Tab") { e.preventDefault(); commit(r, c, e.target.value, e.shiftKey ? "left" : "right"); } else if (e.key === "Escape") { e.preventDefault(); setEdit(null); const ne = { ...err }; delete ne[k]; setErr(ne); } }}
              onBlur={(e: any) => { if (edit) commit(r, c, e.target.value, null); }} />
            : d ? <span className="hmt-qg-na">{d}</span> : v != null ? <b className="hmt-tabular">{String(v).replace(".", ",")}</b> : <span className="hmt-qg-empty" aria-hidden="true" />}
          {er ? <span className="hmt-qg-err" role="alert">{er}</span> : null}</td>; }
      if (col.kind === "text") return <td key={col.key} className="hmt-qg-c hmt-qg-text" role="gridcell" aria-disabled={d ? true : undefined} {...common} onClick={() => !d && onOpenRow && onOpenRow(row)}>
        {d ? <span className="hmt-qg-na">{d}</span> : v ? <span className="hmt-qg-snip">{v}</span> : <span className="hmt-qg-todo"><Icon name="edit" /> Viết</span>}</td>;
      return <td key={col.key} className="hmt-qg-c hmt-qg-num" role="gridcell" {...common}>{col.render ? col.render(vals[row.id] || {}, row) : v}</td>;
    };
    const grpSpans: any[] = []; columns.forEach((c: any) => { const g = c.group || ""; const last = grpSpans[grpSpans.length - 1]; if (last && last.g === g) last.n++; else grpSpans.push({ g, n: 1 }); });
    return (
      <div className="hmt-qg">
        <div className="hmt-qg-bar"><span className="hmt-help">{caption}</span><span style={{ marginLeft: "auto" }}><SaveState state={save || "saved"} /></span></div>
        <div className="hmt-qg-wrap" ref={wrap} style={{ maxHeight }}>
          <table className="hmt-qg-table" role="grid" aria-label={caption}>
            <thead>
              {groups ? <tr className="hmt-qg-grp"><th className="hmt-qg-name" rowSpan={2} scope="col">Học sinh</th>{grpSpans.map((g, i) => <th key={i} colSpan={g.n} scope="colgroup">{g.g}</th>)}</tr> : null}
              <tr>{groups ? null : <th className="hmt-qg-name" scope="col">Học sinh</th>}{columns.map((c: any) => <th key={c.key} scope="col" className={c.kind === "score" || c.kind === "radio" || c.kind === "read" ? "hmt-qg-num" : undefined} title={c.help}>{c.label}{c.hotkey ? <kbd className="hmt-qg-kbd">{c.hotkey}</kbd> : null}{c.sub ? <span className="hmt-qg-sub">{c.sub}</span> : null}</th>)}</tr>
            </thead>
            <tbody>{rows.map((row: any, r: number) => { const d = dis(r); return (
              <tr key={row.id} data-active={act.r === r ? "true" : undefined} data-disabled={d ? "true" : undefined}>
                <th scope="row" className="hmt-qg-name"><button type="button" className="hmt-qg-namebtn hmt-focus" onClick={() => onOpenRow && onOpenRow(row)} aria-label={`Mở chi tiết ${row.name}`}><span className="hmt-qg-idx hmt-tabular">{r + 1}</span><span style={{ display: "grid", minWidth: 0 }}><b>{row.name}</b>{row.note || (rowNote && rowNote(row, vals[row.id] || {})) ? <span className="hmt-qg-rownote">{row.note || rowNote(row, vals[row.id] || {})}</span> : null}</span></button></th>
                {d && !columns.some((x: any) => x.kind === "radio") ? <td className="hmt-qg-c hmt-qg-off" colSpan={columns.length} role="gridcell" aria-disabled="true" tabIndex={act.r === r ? 0 : -1} ref={(el: any) => { for (let c = 0; c < columns.length; c++) refs.current[`${r}:${c}`] = el; }} onFocus={() => { focusIn.current = true; }} onKeyDown={(e: any) => onKey(e, r, act.c)}><span className="hmt-qg-na">{d} · không chấm</span></td> : columns.map((_: any, c: number) => cell(r, c))}
              </tr>); })}</tbody>
          </table>
        </div>
        {help ? <p className="hmt-qg-help"><kbd>Tab</kbd>/<kbd>←↑↓→</kbd> di chuyển · {columns.some((c: any) => c.kind === "radio") ? <Fragment><kbd>1</kbd>–<kbd>{columns.filter((c: any) => c.kind === "radio").length}</kbd> chọn trạng thái · </Fragment> : null}{columns.some((c: any) => c.kind === "select") ? <Fragment><kbd>1</kbd>–<kbd>{Math.max(...columns.filter((c: any) => c.kind === "select").map((c: any) => c.options.length))}</kbd> chọn trạng thái (ở cột trạng thái) · </Fragment> : null}{columns.some((c: any) => c.kind === "score") ? <Fragment>gõ số rồi <kbd>Enter</kbd> (xuống em sau) hoặc <kbd>Tab</kbd> · </Fragment> : null}<kbd>Delete</kbd> bỏ trống · bấm tên em mở ngăn bên · <span className="hmt-qg-empty hmt-qg-empty--inline" aria-hidden="true" /> = chưa chấm (khác điểm)</p> : null}
      </div>
    );
  }

  /* ======================= RadarChart ======================= */
  function RadarChart({ axes, series, max = 5, size = 280, title }: any) {
    const [table, setTable] = useState(false);
    const c = size / 2, R = size / 2 - 40, n = axes.length, PAD = 70;
    const pt = (i: number, v: number) => { const a = -Math.PI / 2 + (i * 2 * Math.PI) / n; return [c + Math.cos(a) * R * (v / max), c + Math.sin(a) * R * (v / max)]; };
    const [hover, setHover] = useState(null);
    return (
      <figure className="hmt-radar">
        <figcaption className="hmt-radar-cap"><span>{title}</span>
          <Button variant="tertiary" size="sm" onClick={() => setTable(!table)} aria-pressed={table}>{table ? "Xem biểu đồ" : "Xem bảng số"}</Button></figcaption>
        <ul className="hmt-radar-legend">{series.map((s: any) => <li key={s.name} data-kind={s.kind}><span className="hmt-radar-sw" />{s.name}</li>)}</ul>
        {table ? (
          <table className="hmt-table hmt-radar-table"><caption className="hmt-sr">{title}</caption>
            <thead><tr><th scope="col">Tiêu chí</th>{series.map((s: any) => <th key={s.name} scope="col" className="hmt-num">{s.name}</th>)}</tr></thead>
            <tbody>{axes.map((a: string, i: number) => <tr key={a}><td>{a}</td>{series.map((s: any) => <td key={s.name} className="hmt-num">{String(s.values[i]).replace(".", ",")}</td>)}</tr>)}</tbody></table>
        ) : (
          <svg viewBox={`${-PAD} 0 ${size + 2 * PAD} ${size}`} width="100%" style={{ maxWidth: size + 2 * PAD }} role="img" aria-label={`${title}. ${series.map((s: any) => s.name + ": " + axes.map((a: string, i: number) => `${a} ${s.values[i]}`).join(", ")).join(". ")}`}>
            {[1, 2, 3, 4, 5].map((k) => <polygon key={k} className="hmt-radar-grid" points={axes.map((_: any, i: number) => pt(i, k).join(",")).join(" ")} />)}
            {axes.map((a: string, i: number) => { const [x, y] = pt(i, max); const [lx, ly] = pt(i, max + 0.9); return <g key={a}><line className="hmt-radar-axis" x1={c} y1={c} x2={x} y2={y} /><text className="hmt-radar-lbl" x={lx} y={ly} textAnchor={Math.abs(lx - c) < 8 ? "middle" : lx > c ? "start" : "end"} dominantBaseline="middle">{a}</text></g>; })}
            {series.map((s: any) => <polygon key={s.name} className="hmt-radar-area" data-kind={s.kind} points={s.values.map((v: number, i: number) => pt(i, v).join(",")).join(" ")} />)}
            {series.filter((s: any) => s.kind !== "ref").map((s: any) => s.values.map((v: number, i: number) => { const [x, y] = pt(i, v); return <g key={s.name + i}><circle className="hmt-radar-dot" cx={x} cy={y} r={4} /><circle cx={x} cy={y} r={12} fill="transparent" onMouseEnter={() => setHover({ x, y, t: `${axes[i]}: ${String(v).replace(".", ",")}` })} onMouseLeave={() => setHover(null)} /></g>; }))}
            {hover ? <g pointerEvents="none"><rect className="hmt-radar-tip" x={(hover as any).x + 8} y={(hover as any).y - 26} width={(hover as any).t.length * 6.6 + 12} height={22} rx={4} /><text className="hmt-radar-tipt" x={(hover as any).x + 14} y={(hover as any).y - 11}>{(hover as any).t}</text></g> : null}
          </svg>
        )}
      </figure>
    );
  }

  /* ======================= FileUpload ======================= */
  function FileUpload({ accept = "image/*,application/pdf", maxMB = 10, multiple = true, label = "Đính kèm", helper, mobile }: any) {
    const [files, setFiles] = useState([]); const [over, setOver] = useState(false); const inp = useRef(null); const cam = useRef(null);
    const add = (list: any) => {
      const arr = Array.from(list || []).map((f: any) => {
        const bad = f.size > maxMB * 1024 * 1024 ? `Quá ${maxMB} MB` : !/^image\/|application\/pdf/.test(f.type) ? "Chỉ nhận ảnh hoặc PDF" : null;
        return { id: Math.random().toString(36).slice(2), name: f.name, size: f.size, type: f.type, url: f.type.startsWith("image/") ? URL.createObjectURL(f) : null, progress: bad ? 0 : 0, error: bad };
      });
      setFiles((x: any) => [...x, ...arr]);
      arr.filter((a: any) => !a.error).forEach((a: any) => { let p = 0; const t = setInterval(() => { p += 20; setFiles((x: any) => x.map((y: any) => y.id === a.id ? { ...y, progress: Math.min(100, p) } : y)); if (p >= 100) clearInterval(t); }, 250); });
    };
    const addDemo = (kind: string) => {
      const demo: any = { ok: { name: "bai-lam-trang-1.jpg", size: 820000, type: "image/jpeg" }, pdf: { name: "de-kiem-tra.pdf", size: 1200000, type: "application/pdf" }, big: { name: "video-buoi-hoc.mp4", size: 52000000, type: "video/mp4" } }[kind];
      const f = new File([new Uint8Array(1)], demo.name, { type: demo.type }); Object.defineProperty(f, "size", { value: demo.size }); add([f]);
    };
    const kb = (n: number) => n > 1e6 ? `${(n / 1e6).toFixed(1).replace(".", ",")} MB` : `${Math.round(n / 1e3)} KB`;
    return (
      <div className="hmt-up">
        <span className="hmt-label">{label}</span>
        {mobile ? (
          <div className="hmt-up-mobile">
            <Button variant="secondary" iconStart="camera" fullWidth onClick={() => (cam.current as any).click()}>Chụp ảnh</Button>
            <Button variant="secondary" iconStart="image" fullWidth onClick={() => (inp.current as any).click()}>Chọn ảnh, PDF</Button>
          </div>
        ) : (
          <div className="hmt-up-drop" data-over={over ? "true" : undefined} onDragOver={(e: any) => { e.preventDefault(); setOver(true); }} onDragLeave={() => setOver(false)} onDrop={(e: any) => { e.preventDefault(); setOver(false); add(e.dataTransfer.files); }}>
            <Icon name="upload" size={24} />
            <span>Kéo thả ảnh hoặc PDF vào đây, hoặc <button type="button" className="hmt-up-link hmt-focus" onClick={() => (inp.current as any).click()}>chọn tệp</button></span>
            <span className="hmt-help">{helper || `Ảnh, PDF · tối đa ${maxMB} MB mỗi tệp`}</span>
          </div>
        )}
        <input ref={inp} type="file" accept={accept} multiple={multiple} className="hmt-sr" tabIndex={-1} onChange={(e: any) => { add(e.target.files); e.target.value = ""; }} />
        <input ref={cam} type="file" accept="image/*" capture="environment" className="hmt-sr" tabIndex={-1} onChange={(e: any) => { add(e.target.files); e.target.value = ""; }} />
        <div className="hmt-demo-row" style={{ gap: 6 }}><span className="hmt-person-meta" style={{ display: "inline" }}>Thử nhanh:</span><Button variant="tertiary" size="sm" onClick={() => addDemo("ok")}>+ ảnh</Button><Button variant="tertiary" size="sm" onClick={() => addDemo("pdf")}>+ PDF</Button><Button variant="tertiary" size="sm" onClick={() => addDemo("big")}>+ tệp lỗi</Button></div>
        {files.length ? <ul className="hmt-up-list">{files.map((f: any) => (
          <li key={f.id} className="hmt-up-item" data-error={f.error ? "true" : undefined}>
            <span className="hmt-up-thumb">{f.url ? <img src={f.url} alt="" /> : <Icon name={f.type === "application/pdf" ? "file" : "paperclip"} />}</span>
            <span className="hmt-up-meta"><span className="hmt-up-name">{f.name}</span>
              {f.error ? <span className="hmt-err"><Icon name="xcircle" /> {f.error}</span>
                : f.progress < 100 ? <span className="hmt-up-prog"><span className="hmt-progress-track" style={{ flex: 1 }} role="progressbar" aria-valuenow={f.progress} aria-valuemin={0} aria-valuemax={100} aria-label={`Đang tải ${f.name}`}><span className="hmt-progress-fill" style={{ width: `${f.progress}%`, display: "block" }} /></span><span className="hmt-tabular hmt-person-meta" style={{ display: "inline" }}>{f.progress}%</span></span>
                : <span className="hmt-person-meta">{kb(f.size)} · Đã tải lên</span>}</span>
            <Button variant="tertiary" neutral size="sm" iconOnly="x" label={`Gỡ ${f.name}`} onClick={() => setFiles(files.filter((x: any) => x.id !== f.id))} />
          </li>))}</ul> : null}
      </div>
    );
  }

  /* ======================= TaskStepper (K12) ======================= */
  function TaskStepper({ title, steps, current, onStepChange, deadline, children, nav, footer }: any) {
    const idx = steps.findIndex((s: any) => s.id === current); const done = steps.filter((s: any) => s.status === "done").length;
    return (
      <section className="hmt-ts" aria-label={title}><div className="hmt-ts-in">
        <header className="hmt-ts-head">
          <div className="hmt-ts-top"><span className="hmt-ts-title">{title}</span>{deadline}</div>
          <div className="hmt-ts-prog" role="progressbar" aria-valuenow={done} aria-valuemin={0} aria-valuemax={steps.length} aria-valuetext={`Xong ${done}/${steps.length} bước`}>
            {steps.map((s: any) => <span key={s.id} className="hmt-ts-seg" data-state={s.id === current ? "current" : s.status} />)}
          </div>
          <ol className="hmt-ts-steps">{steps.map((s: any, i: number) => (
            <li key={s.id}><button type="button" className="hmt-ts-step hmt-focus" aria-current={s.id === current ? "step" : undefined} data-state={s.id === current ? "current" : s.status} onClick={() => onStepChange && onStepChange(s.id)}>
              <span className="hmt-ts-n">{s.status === "done" ? <Icon name="check" /> : i + 1}</span><span className="hmt-ts-l">{s.short || s.label}</span><span className="hmt-ts-lf">{s.label}</span></button></li>))}</ol>
          <p className="hmt-ts-cur">Bước {idx + 1}/{steps.length} · <b>{steps[idx].label}</b></p>
        </header>
        <div className="hmt-ts-body">{children}</div>
        <footer className="hmt-ts-foot">
          {nav ? <div className="hmt-ts-nav">
            <Button variant="secondary" iconStart="chevronLeft" disabled={!nav.hasPrev} onClick={nav.onPrev}>Em trước</Button>
            <span className="hmt-tabular hmt-ts-pos">{nav.index}/{nav.total}</span>
            <Button variant="secondary" iconEnd="chevronRight" disabled={!nav.hasNext} onClick={nav.onNext}>Em sau</Button>
          </div> : null}
          {footer}
        </footer>
      </div></section>
    );
  }

  /* ======================= SlaBadge (R-CS-08, R-GV-05) ======================= */
  function SlaBadge({ kind, hours, threshold = 4 }: any) {
    const h = hrs(hours);
    if (kind === "remaining") return <Badge tone={hours <= threshold ? "warning" : "info"} icon="timer">Còn {h}</Badge>;
    if (kind === "overdue") return <Badge tone="danger" solid icon="alert">Quá hạn {h}</Badge>;
    if (kind === "ontime") return <Badge tone="success" icon="check">Đúng hạn</Badge>;
    return <Badge tone="danger" icon="clock">Trễ hạn {h}</Badge>;
  }

  /* ======================= ApprovalChain ======================= */
  function ApprovalChain({ levels, layout = "vertical" }: any) {
    const M: any = { approved: ["success", "check", "Đã duyệt"], rejected: ["danger", "x", "Từ chối"], pending: ["warning", "hourglass", "Chờ duyệt"], waiting: ["neutral", "clock", "Chưa tới lượt"] };
    return (
      <ol className={cx("hmt-ac", layout === "horizontal" && "hmt-ac--h")} aria-label="Chuỗi duyệt">
        {levels.map((l: any, i: number) => { const [tone, ic, txt] = M[l.status]; return (
          <li key={i} className="hmt-ac-item" data-status={l.status}>
            <span className="hmt-ac-dot" data-tone={tone} aria-hidden="true"><Icon name={ic} /></span>
            <div className="hmt-ac-body">
              <p className="hmt-ac-role"><b>Cấp {i + 1} · {l.role}</b></p>
              <p className="hmt-ac-line"><Badge tone={tone} icon={false}>{txt}</Badge>{l.approver ? <span> {l.approver}</span> : null}{l.at ? <span className="hmt-person-meta" style={{ display: "inline" }}> · {l.at}</span> : null}</p>
              {l.reason ? <p className="hmt-ac-reason"><b>Lý do từ chối:</b> {l.reason}</p> : null}
            </div>
          </li>); })}
      </ol>
    );
  }

  /* ======================= VersionedConfig ======================= */
  function VersionedConfig({ title, versions, rows, format = (v: any) => v }: any) {
    const active = versions.find((v: any) => v.status === "active"); const upcoming = versions.find((v: any) => v.status === "scheduled");
    const [a, setA] = useState(active ? active.id : versions[0].id); const [b, setB] = useState(upcoming ? upcoming.id : versions[1] && versions[1].id);
    const [cmp, setCmp] = useState(false);
    const V = (id: string) => versions.find((v: any) => v.id === id);
    const ST: any = { active: ["success", "Đang dùng"], scheduled: ["info", "Sắp hiệu lực"], past: ["neutral", "Đã hết hiệu lực"] };
    return (
      <section className="hmt-vc" aria-label={title}>
        <div className="hmt-vc-cards">
          {[active, upcoming].filter(Boolean).map((v: any) => (
            <div key={v.id} className="hmt-panel hmt-vc-card">
              <Badge tone={ST[v.status][0]} icon={false}>{ST[v.status][1]}</Badge>
              <p className="hmt-vc-name">{v.label}</p>
              <p className="hmt-person-meta">Hiệu lực từ {v.effectiveFrom}{v.effectiveTo ? ` đến ${v.effectiveTo}` : ""} · {v.author}</p>
            </div>))}
        </div>
        <div className="hmt-demo-row" style={{ alignItems: "flex-end" }}>
          <Field label="So sánh"><Select value={a} onChange={(e: any) => setA(e.target.value)} options={versions.map((v: any) => ({ value: v.id, label: v.label }))} /></Field>
          <Field label="với"><Select value={b} onChange={(e: any) => setB(e.target.value)} options={versions.map((v: any) => ({ value: v.id, label: v.label }))} /></Field>
          <Button variant="secondary" iconStart="gitCompare" onClick={() => setCmp(true)}>So sánh</Button>
        </div>
        {cmp ? (
          <div className="hmt-table-wrap"><table className="hmt-table"><caption className="hmt-sr">So sánh {V(a).label} và {V(b).label}</caption>
            <thead><tr><th scope="col">Mục</th><th scope="col" className="hmt-num">{V(a).label}</th><th scope="col" className="hmt-num">{V(b).label}</th><th scope="col">Khác biệt</th></tr></thead>
            <tbody>{rows.map((r: any) => { const x = r.values[a], y = r.values[b]; const ch = x !== y; return (
              <tr key={r.key} data-changed={ch ? "true" : undefined}><td>{r.label}</td><td className="hmt-num">{x == null ? "—" : format(x, r)}</td><td className="hmt-num">{y == null ? "—" : format(y, r)}</td>
                <td>{ch ? <span className="hmt-diff">{x == null ? "Thêm mới" : y == null ? "Bỏ" : "Đã đổi"}</span> : <span className="hmt-person-meta" style={{ display: "inline" }}>Giữ nguyên</span>}</td></tr>); })}</tbody></table></div>
        ) : null}
        <details className="hmt-vc-hist"><summary>Lịch sử phiên bản ({versions.length})</summary>
          <ol>{versions.map((v: any) => <li key={v.id}><Badge tone={ST[v.status][0]} icon={false}>{ST[v.status][1]}</Badge> <b>{v.label}</b> <span className="hmt-person-meta" style={{ display: "inline" }}>· từ {v.effectiveFrom} · {v.author} · {v.note}</span></li>)}</ol>
        </details>
      </section>
    );
  }

  /* ======================= PrintLayout (K13) ======================= */
  function PrintLayout({ size = "A4", logoSrc, campus, docTitle, code, date, status, party = [], columns, lines, totals = [], amountInWords, notes, signatures = [] }: any) {
    return (
      <article className="hmt-print" data-size={size} aria-label={`${docTitle} ${code}`}>
        <header className="hmt-print-head">
          {logoSrc ? <img className="hmt-print-logo" src={logoSrc} alt="Hòa Ma Toán" /> : null}
          <div className="hmt-print-org"><b>Hòa Ma Toán · {campus.code} {campus.name}</b><span>{campus.address}</span><span>Hotline {campus.phone}</span></div>
          <div className="hmt-print-doc"><h1>{docTitle}</h1><span className="hmt-tabular">Số: {code}</span><span>Ngày: {date}</span>{status ? <span className="hmt-print-status">{status}</span> : null}</div>
        </header>
        <dl className="hmt-print-party">{party.map((p: any) => <Fragment key={p.k}><dt>{p.k}</dt><dd>{p.v}</dd></Fragment>)}</dl>
        <table className="hmt-print-table">
          <thead><tr><th>STT</th>{columns.map((c: any) => <th key={c.key} className={c.numeric ? "hmt-num" : undefined}>{c.header}</th>)}</tr></thead>
          <tbody>{lines.map((l: any, i: number) => <tr key={i}><td>{i + 1}</td>{columns.map((c: any) => <td key={c.key} className={c.numeric ? "hmt-num" : undefined}>{l[c.key]}</td>)}</tr>)}</tbody>
          <tfoot>{totals.map((t: any) => <tr key={t.k} data-strong={t.strong ? "true" : undefined}><td colSpan={columns.length} className="hmt-num">{t.k}</td><td className="hmt-num">{t.v}</td></tr>)}</tfoot>
        </table>
        {amountInWords ? <p className="hmt-print-words"><i>Bằng chữ: {amountInWords}</i></p> : null}
        {notes ? <p className="hmt-print-notes">{notes}</p> : null}
        <div className="hmt-print-signs">{signatures.map((s: any) => <div key={s.role}><b>{s.role}</b><span>(Ký, ghi rõ họ tên)</span><span className="hmt-print-signname">{s.name || ""}</span></div>)}</div>
      </article>
    );
  }


  /* =====================================================================
     ĐỢT 5.2 · KHUÔN DÙNG LẠI (K01 khung CRM, K11 trang đơn, K09 thẻ số)
     ===================================================================== */
  /* Menu CRM 9 nhóm (đợt 5.1, P-15). Quyền thấy lấy từ cột Vai trò của bản đồ màn hình (P-19).
     Hàng: [nhóm, nhóm con, nhãn, mã màn, vai trò dùng, vai trò chỉ xem]. App thật dựng từ ma trận quyền QT-05. */
  const CRM_MENU_ROWS: any[] = [["Tổng quan", null, "Trang chủ", "CHUNG-14", "ADBMSACSKT", ""], ["Tổng quan", null, "Việc chờ tôi duyệt", "CHUNG-15", "ADBMKT", ""], ["Tuyển sinh", null, "Lead", "TS-01", "BMSACS", ""], ["Tuyển sinh", null, "Cơ hội", "TS-07", "BMSACS", ""], ["Tuyển sinh", null, "Lịch hẹn", "TS-11", "BMSACS", ""], ["Tuyển sinh", null, "Phiếu kiểm tra", "TS-16", "BMSACS", ""], ["Khách hàng", null, "Phụ huynh", "KH-01", "BMSACSKT", ""], ["Khách hàng", null, "Học sinh", "KH-04", "BMSACSKT", ""], ["Bán hàng và thu chi", null, "Báo giá", "BH-01", "BMSACS", ""], ["Bán hàng và thu chi", null, "Đơn hàng", "BH-06", "BMSACSKT", ""], ["Bán hàng và thu chi", null, "Phiếu thu", "TC-01", "BMSACSKT", ""], ["Bán hàng và thu chi", null, "Chờ kế toán duyệt", "TC-04", "KT", ""], ["Bán hàng và thu chi", null, "Khoản tiền vào", "TC-08", "ADBMKT", ""], ["Bán hàng và thu chi", null, "Công nợ", "TC-13", "BMSACSKT", ""], ["Bán hàng và thu chi", null, "Phiếu chi", "TC-10", "ADBMKT", ""], ["Bán hàng và thu chi", null, "Số dư khách hàng", "TC-14", "BMKT", ""], ["Bán hàng và thu chi", null, "Đối soát thu tiền", "TC-15", "KT", ""], ["Đào tạo", "Ghi danh", "Ghi danh", "GD-01", "BMSACSKT", ""], ["Đào tạo", "Ghi danh", "Chờ xếp lớp", "GD-06", "BMCS", ""], ["Đào tạo", "Ghi danh", "Sắp hết giờ", "GD-07", "BMSACS", ""], ["Đào tạo", "Lớp", "Lớp", "LOP-01", "BMSACS", ""], ["Đào tạo", "Lớp", "Lịch tuần cơ sở", "LOP-08", "BMCS", ""], ["Đào tạo", "Buổi học", "Buổi học", "BUOI-01", "BMCS", ""], ["Đào tạo", "Buổi học", "Điểm danh vận hành", "BUOI-11", "CS", ""], ["Đào tạo", "Buổi học", "Yêu cầu buổi", "BUOI-10", "BMCS", ""], ["Đào tạo", "Buổi học", "Buổi chưa Done", "BUOI-12", "BMCS", ""], ["Chăm sóc khách hàng", null, "Ticket", "CS-01", "ADBMSACSKT", ""], ["Chăm sóc khách hàng", null, "Nhận xét chờ gửi", "CS-16", "CS", ""], ["Chăm sóc khách hàng", null, "Phiếu tái tục", "TT-01", "BMSACS", ""], ["Báo cáo", null, "Tổng quan Ban giám đốc", "BC-01", "ADBM", ""], ["Báo cáo", null, "Giáo viên trễ hạn", "BC-08", "ADBM", ""], ["Báo cáo", null, "Giờ dạy giáo viên", "BC-09", "ADBMKT", ""], ["Báo cáo", null, "Báo cáo trên Looker", "LOOKER", "ADBMSACSKT", ""], ["Cấu hình", null, "Gói bán", "CH-01", "AD", ""], ["Cấu hình", null, "Bảng giá", "CH-03", "AD", ""], ["Cấu hình", null, "Chính sách chiết khấu", "CH-04", "AD", ""], ["Cấu hình", null, "Điều khoản thanh toán", "CH-09", "AD", ""], ["Cấu hình", null, "Chiến dịch marketing", "CH-08", "ADSA", ""], ["Cấu hình", null, "Khung chương trình", "CH-05", "AD", "BM"], ["Cấu hình", null, "Rubric nhận xét", "CH-07", "AD", ""], ["Cấu hình", null, "Ngày nghỉ lễ", "QT-14", "ADBM", ""], ["Cấu hình", null, "Người duyệt ticket", "QT-15", "AD", ""], ["Quản trị", null, "Người dùng", "QT-01", "AD", ""], ["Quản trị", null, "Vai trò", "QT-04", "AD", ""], ["Quản trị", null, "Ma trận quyền", "QT-05", "AD", ""], ["Quản trị", null, "Danh mục", "QT-06", "AD", ""], ["Quản trị", null, "Cơ sở và phòng học", "QT-08", "AD", ""], ["Quản trị", null, "Tham số nghiệp vụ", "QT-09", "AD", ""], ["Quản trị", null, "Công tắc tính năng", "QT-10", "AD", ""], ["Quản trị", null, "Giáo viên, trợ giảng", "QT-16", "ADBM", ""], ["Quản trị", null, "Tài khoản học sinh", "QT-13", "ADCS", ""], ["Quản trị", null, "Tài khoản phụ huynh", "QT-17", "ADCS", ""], ["Quản trị", null, "Nhật ký thao tác", "QT-11", "AD", ""], ["Quản trị", null, "Nhật ký đăng nhập, xuất file", "QT-12", "AD", ""]]
;
  const CRM_GROUP_ICON: any = { "Tổng quan": "home", "Tuyển sinh": "users", "Khách hàng": "userCheck", "Bán hàng và thu chi": "wallet", "Đào tạo": "graduation", "Chăm sóc khách hàng": "message", "Báo cáo": "layers", "Cấu hình": "settings", "Quản trị": "lock" };
  const ROLE_LABEL: any = { AD: "Admin", BM: "Trưởng cơ sở", SA: "Tuyển sinh", CS: "CSKH, vận hành lớp", KT: "Kế toán", GV: "Giáo viên", TG: "Trợ giảng" };
  const CAMPUSES = [
    { code: "CS1", name: "Nguyễn Chí Thanh", hasRooms: true }, { code: "CS2", name: "Đỗ Quang", hasRooms: true },
    { code: "CS3", name: "Hội sở", hasRooms: false }, { code: "CS4", name: "Hà Đông", hasRooms: true }, { code: "CS5", name: "Mỹ Đình", hasRooms: true },
  ];
  function menuFor(role: string) {
    const groups: any[] = [];
    CRM_MENU_ROWS.forEach(([g, sub, label, code, full, view]: any) => {
      const access = role === "AD" || full.includes(role) ? "full" : view.includes(role) ? "view" : null; // A-22: Admin làm được mọi màn CRM ở mọi cơ sở
      if (!access) return;
      let G = groups.find((x) => x.label === g); if (!G) { G = { id: g, label: g, icon: CRM_GROUP_ICON[g], subs: [] }; groups.push(G); }
      let S = G.subs.find((x: any) => x.label === sub); if (!S) { S = { label: sub, items: [] }; G.subs.push(S); }
      S.items.push({ id: code, label, access, external: code === "LOOKER" });
    });
    return groups;
  }

  function CrmNav({ groups, activeId, onNavigate, collapsed }: any) {
    const activeGroup = (groups.find((g: any) => g.subs.some((s: any) => s.items.some((i: any) => i.id === activeId))) || {}).id;
    const [open, setOpen] = useState(() => ({ [activeGroup]: true } as any));
    useEffect(() => { if (activeGroup) setOpen((o: any) => ({ ...o, [activeGroup]: true })); }, [activeGroup]);
    return (
      <ul className="hmt-cnav">
        {groups.map((g: any) => {
          const isOpen = !!open[g.id]; const hasActive = g.id === activeGroup;
          const head = (
            <button type="button" className="hmt-cnav-g hmt-focus" aria-expanded={collapsed ? undefined : isOpen} data-active={hasActive ? "true" : undefined}
              aria-label={collapsed ? g.label : undefined} onClick={() => collapsed ? onNavigate && onNavigate(g.subs[0].items[0].id) : setOpen({ ...open, [g.id]: !isOpen })}>
              <Icon name={g.icon} /><span className="hmt-cnav-gl">{g.label}</span>{!collapsed ? <Icon name="chevronDown" className="hmt-cnav-chev" /> : null}
            </button>);
          return (
            <li key={g.id}>
              {collapsed ? <Tooltip content={g.label}>{head}</Tooltip> : head}
              {!collapsed && isOpen ? (
                <ul className="hmt-cnav-items">
                  {g.subs.map((s: any) => (
                    <Fragment key={s.label || "_"}>
                      {s.label ? <li className="hmt-cnav-sub" aria-hidden="true">{s.label}</li> : null}
                      {s.items.map((it: any) => (
                        <li key={it.id}><a href="#" className="hmt-cnav-i" aria-current={it.id === activeId ? "page" : undefined}
                          onClick={(e: any) => { e.preventDefault(); onNavigate && onNavigate(it.id); }}>
                          <span>{it.label}</span>{it.access === "view" ? <span className="hmt-cnav-tag">Xem</span> : null}{it.external ? <Icon name="arrowRight" className="hmt-cnav-ext" label="mở tab mới" /> : null}{it.badge ? <CountBadge count={it.badge} /> : null}
                        </a></li>))}
                    </Fragment>))}
                </ul>) : null}
            </li>);
        })}
      </ul>
    );
  }

  /* K01 · Khung CRM (CHUNG-10). Cố định: menu trái, thanh trên. Thay đổi: vùng nội dung (children). */
  function AppShell({ role = "BM", user, campus, onCampusChange, activeId, onNavigate, notifications = 0, onSearch, onNotifications, multiPortal, onAccount, loading, mobile, children, badges = {}, defaultCollapsed = false }: any) {
    const [collapsed, setCollapsed] = useState(defaultCollapsed); const [drawer, setDrawer] = useState(false);
    const groups = useMemo(() => menuFor(role).map((g: any) => ({ ...g, subs: g.subs.map((s: any) => ({ ...s, items: s.items.map((i: any) => ({ ...i, badge: badges[i.id] })) })) })), [role, JSON.stringify(badges)]);
    const picker = role === "AD" || role === "KT";
    const nav = loading ? <div className="hmt-cnav-skel" aria-hidden="true">{[70, 55, 80, 60, 75, 50, 65].map((w, i) => <Skeleton key={i} width={`${w}%`} height={14} />)}</div>
      : <CrmNav groups={groups} activeId={activeId} onNavigate={(id: any) => { setDrawer(false); onNavigate && onNavigate(id); }} collapsed={collapsed && !mobile} />;
    const acct = (
      <Popover label="Tài khoản" placement="bottom-end" trigger={<button type="button" className="hmt-shell-acct hmt-focus"><Avatar name={user.name} size="sm" decorative /><span className="hmt-shell-acct-t"><b>{user.name}</b><small>{ROLE_LABEL[role]} · {user.campus}</small></span><Icon name="chevronDown" /></button>}>
        {(close: any) => <ul className="hmt-menu" style={{ margin: -12 }}>
          <li><button onClick={() => { close(); onAccount && onAccount("profile"); }}><Icon name="userCheck" />Hồ sơ cá nhân</button></li>
          {multiPortal ? <li><button onClick={() => { close(); onAccount && onAccount("portal"); }}><Icon name="gitCompare" />Đổi sang cổng Giáo viên</button></li> : null}
          <li><button onClick={() => { close(); onAccount && onAccount("logout"); }}><Icon name="logout" />Đăng xuất</button></li>
        </ul>}
      </Popover>);
    return (
      <div className="hmt-shell" data-mobile={mobile ? "true" : undefined}>
        {!mobile ? (
          <nav className="hmt-shell-side" data-collapsed={collapsed ? "true" : undefined} aria-label="Menu chính">
            <div className="hmt-sidebar-head"><span className="hmt-wordmark">{collapsed ? "HMT" : "Hòa Ma Toán"}{!collapsed ? <small>CRM</small> : null}</span></div>
            <div className="hmt-shell-navwrap">{nav}</div>
            <div className="hmt-sidebar-foot"><Button variant="tertiary" neutral size="sm" iconStart="sidebar" aria-expanded={!collapsed} onClick={() => setCollapsed(!collapsed)} iconOnly={collapsed ? "sidebar" : undefined} label={collapsed ? "Mở rộng menu" : undefined}>{collapsed ? null : "Thu gọn"}</Button></div>
          </nav>) : null}
        <div className="hmt-shell-main">
          <header className="hmt-shell-top">
            {mobile ? <Button variant="tertiary" neutral iconOnly="menu" label="Mở menu" onClick={() => setDrawer(true)} /> : null}
            {mobile ? <span className="hmt-wordmark" style={{ flex: 1 }}>HMT · CRM</span> : (
              <button type="button" className="hmt-shell-search hmt-focus" onClick={onSearch}><Icon name="search" /><span>Tìm học sinh, phụ huynh, lead, đơn, phiếu thu, lớp…</span></button>)}
            {mobile ? <Button variant="tertiary" neutral iconOnly="search" label="Tìm kiếm" onClick={onSearch} /> : null}
            {picker && !mobile ? (
              <label className="hmt-shell-campus"><span className="hmt-sr">Cơ sở đang xem</span><Icon name="mapPin" />
                <select value={campus} onChange={(e: any) => onCampusChange && onCampusChange(e.target.value)}>
                  <option value="ALL">Tất cả cơ sở</option>{CAMPUSES.filter((c) => c.hasRooms).map((c) => <option key={c.code} value={c.code}>{c.code} · {c.name}</option>)}
                </select></label>) : null}
            <span className="hmt-shell-bell"><Button variant="tertiary" neutral iconOnly="bell" label={`Thông báo${notifications ? `, ${notifications} chưa đọc` : ""}`} onClick={onNotifications} /><CountBadge count={notifications} label={`${notifications} thông báo chưa đọc`} /></span>
            {!mobile ? acct : null}
          </header>
          <main className="hmt-shell-content" aria-busy={loading || undefined}>{children}</main>
        </div>
        {mobile ? (
          <Drawer open={drawer} onClose={() => setDrawer(false)} placement="left" title="Hòa Ma Toán · CRM" description={`${user.name} · ${ROLE_LABEL[role]} · ${user.campus}`}>
            {picker ? <Field label="Cơ sở đang xem"><Select value={campus} onChange={(e: any) => onCampusChange && onCampusChange(e.target.value)} options={[{ value: "ALL", label: "Tất cả cơ sở" }, ...CAMPUSES.filter((c) => c.hasRooms).map((c) => ({ value: c.code, label: `${c.code} · ${c.name}` }))]} /></Field> : null}
            {nav}
            <ul className="hmt-menu" style={{ borderTop: "1px solid var(--hmt-border)", marginTop: 8, paddingTop: 8 }}>
              <li><button onClick={() => onAccount && onAccount("profile")}><Icon name="userCheck" />Hồ sơ cá nhân</button></li>
              <li><button onClick={() => onAccount && onAccount("logout")}><Icon name="logout" />Đăng xuất</button></li>
            </ul>
          </Drawer>) : null}
      </div>
    );
  }

  /* Tiêu đề trang trong vùng nội dung */
  function PageHeader({ title, code, breadcrumb, meta, actions, children }: any) {
    return (
      <div className="hmt-ph">
        {breadcrumb ? <Breadcrumb items={breadcrumb} /> : null}
        <div className="hmt-ph-row">
          <div className="hmt-ph-t"><h1>{title}</h1>{code ? <span className="hmt-ph-code">{code}</span> : null}{meta ? <div className="hmt-ph-meta">{meta}</div> : null}</div>
          {actions ? <div className="hmt-ph-actions">{actions}</div> : null}
        </div>
        {children}
      </div>
    );
  }

  /* K09 · Thẻ số (việc cần làm). Bấm mở danh sách lọc sẵn. */
  function StatTile({ label, value, hint, hintTone, icon, onOpen, linkLabel = "Mở danh sách", target, loading }: any) {
    if (loading) return <div className="hmt-stat" aria-hidden="true"><Skeleton width="50%" /><Skeleton width={56} height={28} /><Skeleton width="70%" height={10} /></div>;
    return (
      <button type="button" className="hmt-stat hmt-focus" onClick={onOpen} aria-label={`${label}: ${value}. ${hint || ""} ${linkLabel}`}>
        <span className="hmt-stat-l">{icon ? <Icon name={icon} /> : null}{label}</span>
        <span className="hmt-stat-v hmt-tabular">{value}</span>
        {hint ? <span className="hmt-stat-h" data-tone={hintTone}>{hintTone ? <Icon name={TONE_ICON[hintTone] || "info"} /> : null}{hint}</span> : <span className="hmt-stat-h">&nbsp;</span>}
        <span className="hmt-stat-a">{linkLabel}{target ? <span className="hmt-ph-code">{target}</span> : null}<Icon name="arrowRight" /></span>
      </button>
    );
  }

  /* LineChart (đợt 5.7): biểu đồ đường 1–4 chuỗi, MỘT trục y. Chú giải luôn có khi ≥ 2 chuỗi, nhãn cuối đường,
     rê chuột / phím mũi tên hiện đường dọc + hộp số. Chuỗi 2 trở đi nét đứt để không dựa vào màu. Có bảng ẩn cho trình đọc màn hình. */
  function LineChart({ labels, series, format = (n: number) => String(n), axisFormat, height = 240, label, yMax: yMaxIn, tooltipTitle }: any) {
    const wrap = useRef(null as any); const [w, setW] = useState(720); const [hi, setHi] = useState(null as any); const tid = useId();
    useEffect(() => { const el = wrap.current; if (!el) return; const upd = () => setW(Math.max(280, el.clientWidth)); upd();
      if (typeof ResizeObserver !== "undefined") { const ro = new ResizeObserver(upd); ro.observe(el); return () => ro.disconnect(); } }, []);
    const COLORS = ["var(--hmt-cat-1)", "var(--hmt-cat-3)", "var(--hmt-cat-2)", "var(--hmt-cat-4)"];
    const S = series.map((x: any, i: number) => ({ ...x, color: x.color || COLORS[i % 4], dashed: x.dashed !== undefined ? x.dashed : i > 0 }));
    const n = labels.length; const all = S.flatMap((x: any) => x.values.filter((v: any) => v !== null && v !== undefined));
    const raw = yMaxIn || Math.max(1, ...all); const rough = raw / 5; const mag = Math.pow(10, Math.floor(Math.log10(rough))); const step0 = [1, 2, 2.5, 5, 10].map((k) => k * mag).find((st) => st >= rough) || mag * 10;
    const nT = Math.ceil(raw / step0); const yMax = step0 * nT; const ticks = Array.from({ length: nT + 1 }, (_, i) => i * step0);
    const endLab = S.length <= 4; const padL = 56, padR = endLab ? 120 : 16, padT = 12, padB = 28; const iw = w - padL - padR, ih = height - padT - padB;
    const X = (i: number) => padL + (n === 1 ? iw / 2 : (i * iw) / (n - 1)); const Y = (v: number) => padT + ih - (v / yMax) * ih;
    const every = Math.ceil(n / Math.max(2, Math.floor(iw / 64)));
    const af = axisFormat || format;
    const pick = (clientX: number) => { const r = wrap.current.querySelector("svg").getBoundingClientRect(); const x = clientX - r.left; const i = Math.round(((x - padL) / iw) * (n - 1)); setHi(Math.max(0, Math.min(n - 1, i))); };
    const onKey = (e: any) => { if (e.key === "ArrowRight") { e.preventDefault(); setHi(hi === null ? 0 : Math.min(n - 1, hi + 1)); } if (e.key === "ArrowLeft") { e.preventDefault(); setHi(hi === null ? n - 1 : Math.max(0, hi - 1)); } if (e.key === "Escape") setHi(null); };
    // nhãn cuối đường: tránh chồng (cách tối thiểu 16px)
    const ends = S.map((x: any, i: number) => { let k = x.values.length - 1; while (k > 0 && (x.values[k] === null || x.values[k] === undefined)) k--; return { i, k, y: Y(x.values[k]) }; }).sort((a: any, b: any) => a.y - b.y);
    for (let j = 1; j < ends.length; j++) if (ends[j].y - ends[j - 1].y < 16) ends[j].y = ends[j - 1].y + 16;
    const tipLeft = hi === null ? 0 : Math.min(Math.max(X(hi) + 12, 0), w - 200);
    return (
      <figure className="hmt-lc" aria-label={label} style={{ margin: 0 }}>
        {S.length > 1 ? <div className="hmt-lc-legend" aria-hidden="true">{S.map((x: any) => <span key={x.name}><svg width="24" height="10"><line x1="1" y1="5" x2="23" y2="5" stroke={x.color} strokeWidth="2" strokeDasharray={x.dashed ? "5 3" : undefined} strokeLinecap="round" /></svg>{x.name}</span>)}</div> : null}
        <div ref={wrap} className="hmt-lc-plot" style={{ position: "relative" }}>
          <svg width={w} height={height} role="img" aria-label={`${label}. Dùng phím mũi tên để xem từng mốc.`} tabIndex={0} className="hmt-focus" onKeyDown={onKey}
            onMouseMove={(e: any) => pick(e.clientX)} onMouseLeave={() => setHi(null)} onBlur={() => setHi(null)} aria-describedby={hi !== null ? tid : undefined}>
            {ticks.map((t) => <g key={t}><line x1={padL} x2={padL + iw} y1={Y(t)} y2={Y(t)} className="hmt-lc-grid" /><text x={padL - 8} y={Y(t)} dy="0.32em" textAnchor="end" className="hmt-lc-tick">{af(t)}</text></g>)}
            {labels.map((l: string, i: number) => i % every === 0 || i === n - 1 ? <text key={i} x={X(i)} y={height - 8} textAnchor="middle" className="hmt-lc-tick">{l}</text> : null)}
            {hi !== null ? <line x1={X(hi)} x2={X(hi)} y1={padT} y2={padT + ih} className="hmt-lc-cross" /> : null}
            {S.map((x: any) => { const pts = x.values.map((v: any, i: number) => v === null || v === undefined ? null : `${X(i)},${Y(v)}`).filter(Boolean).join(" ");
              return <g key={x.name}><polyline points={pts} fill="none" stroke={x.color} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" strokeDasharray={x.dashed ? "6 4" : undefined} />
                {hi !== null && x.values[hi] !== null && x.values[hi] !== undefined ? <circle cx={X(hi)} cy={Y(x.values[hi])} r="5" fill={x.color} stroke="var(--hmt-surface)" strokeWidth="2" /> : null}</g>; })}
            {endLab ? ends.map((e: any) => { const x = S[e.i]; return <text key={x.name} x={X(e.k) + 8} y={e.y} dy="0.32em" className="hmt-lc-end">{x.short || x.name}</text>; }) : null}
          </svg>
          {hi !== null ? <div id={tid} role="status" className="hmt-lc-tip" style={{ left: tipLeft, top: 8 }}><b>{tooltipTitle ? tooltipTitle(hi) : labels[hi]}</b>
            {S.map((x: any) => <span key={x.name} className="hmt-lc-tip-row"><svg width="16" height="8" aria-hidden="true"><line x1="1" y1="4" x2="15" y2="4" stroke={x.color} strokeWidth="2" strokeDasharray={x.dashed ? "4 2" : undefined} /></svg>{x.name}<b className="hmt-tabular">{x.values[hi] === null || x.values[hi] === undefined ? "—" : format(x.values[hi])}</b></span>)}</div> : null}
        </div>
        <table className="hmt-sr"><caption>{label}</caption><thead><tr><th>Mốc</th>{S.map((x: any) => <th key={x.name}>{x.name}</th>)}</tr></thead><tbody>{labels.map((l: string, i: number) => <tr key={i}><td>{l}</td>{S.map((x: any) => <td key={x.name}>{x.values[i] === null || x.values[i] === undefined ? "—" : format(x.values[i])}</td>)}</tr>)}</tbody></table>
      </figure>
    );
  }

  /* K11 · Trang đơn: đăng nhập, lỗi, khoá. Không có menu. */
  function AuthLayout({ product = "crm", logoSrc, logoWhiteSrc, title, subtitle, children, footer, mobile, aside }: any) {
    return (
      <div className="hmt-auth" data-product={product} data-mobile={mobile ? "true" : undefined}>
        {!mobile ? (
          <aside className="hmt-auth-brand" aria-hidden="true">
            {logoWhiteSrc ? <img src={logoWhiteSrc} alt="" className="hmt-auth-logo-w" /> : null}
            <div className="hmt-auth-pattern" />
            {aside}
          </aside>) : null}
        <main className="hmt-auth-main">
          <div className="hmt-auth-card">
            {logoSrc && mobile ? <img src={logoSrc} alt="Hòa Ma Toán" className="hmt-auth-logo" /> : null}
            {logoSrc && !mobile ? <img src={logoSrc} alt="Hòa Ma Toán" className="hmt-auth-logo hmt-auth-logo--sm" /> : null}
            <h1 className="hmt-auth-title">{title}</h1>
            {subtitle ? <p className="hmt-auth-sub">{subtitle}</p> : null}
            {children}
          </div>
          {footer ? <div className="hmt-auth-foot">{footer}</div> : null}
        </main>
      </div>
    );
  }

  /* Chỗ đặt ô Turnstile của Cloudflare (giao diện thật do Cloudflare vẽ; DS chỉ giữ chỗ 300 × 65 và các trạng thái quanh nó). */
  function TurnstileSlot({ state = "verifying", onRetry }: any) {
    const M: any = { verifying: ["timer", "Đang xác minh bạn không phải robot…"], success: ["checkcircle", "Đã xác minh"], error: ["xcircle", "Chưa xác minh được."], expired: ["alert", "Phiên xác minh đã hết hạn."] };
    const [ic, t] = M[state];
    return (
      <div className="hmt-turnstile" data-state={state} role="group" aria-label="Xác minh không phải robot (Turnstile)">
        <Icon name={ic} /><span aria-live="polite">{t}</span>
        {state === "error" || state === "expired" ? <Button variant="tertiary" size="sm" onClick={onRetry}>Thử lại</Button> : null}
        <small>Turnstile</small>
      </div>
    );
  }

  /* Ô nhập mã 6 số (xác thực hai bước) */
  function OtpInput({ length = 6, value = "", onChange, invalid, label = "Mã xác thực 6 số", autoFocus }: any) {
    const refs = useRef([] as any[]);
    useEffect(() => { if (autoFocus && refs.current[0]) refs.current[0].focus(); }, []);
    const set = (i: number, ch: string) => { const v = (value.padEnd(length, " ").slice(0, i) + ch + value.padEnd(length, " ").slice(i + 1)).replace(/\s+$/, ""); onChange(v); };
    return (
      <div className="hmt-otp" role="group" aria-label={label} data-invalid={invalid ? "true" : undefined}>
        {Array.from({ length }, (_, i) => (
          <input key={i} ref={(el) => (refs.current[i] = el)} inputMode="numeric" autoComplete={i === 0 ? "one-time-code" : "off"} maxLength={1} aria-label={`Số thứ ${i + 1}`} aria-invalid={invalid || undefined}
            value={(value[i] || "").trim()}
            onChange={(e: any) => { const d = e.target.value.replace(/\D/g, "").slice(-1); if (!d) return; set(i, d); if (i < length - 1) refs.current[i + 1].focus(); }}
            onKeyDown={(e: any) => { if (e.key === "Backspace") { e.preventDefault(); set(i, " "); if (!value[i]?.trim() && i > 0) refs.current[i - 1].focus(); } if (e.key === "ArrowLeft" && i > 0) refs.current[i - 1].focus(); if (e.key === "ArrowRight" && i < length - 1) refs.current[i + 1].focus(); }}
            onPaste={(e: any) => { const d = (e.clipboardData.getData("text") || "").replace(/\D/g, "").slice(0, length); if (d) { e.preventDefault(); onChange(d); refs.current[Math.min(d.length, length - 1)].focus(); } }} />))}
      </div>
    );
  }

  /* Mật khẩu có nút hiện/ẩn; PasswordRules liệt kê luật tối thiểu (S03-04: ≥ 8 ký tự, có chữ và số) */
  function PasswordInput({ value, onChange, invalid, autoComplete = "current-password", ...rest }: any) {
    const [show, setShow] = useState(false);
    return <TextInput type={show ? "text" : "password"} value={value} onChange={onChange} invalid={invalid} autoComplete={autoComplete} {...rest}
      trailing={<button type="button" className="hmt-pw-toggle hmt-focus" aria-pressed={show} onClick={() => setShow(!show)}>{show ? "Ẩn" : "Hiện"}<span className="hmt-sr"> mật khẩu</span></button>} />;
  }
  const PW_RULES = [["Ít nhất 8 ký tự", (v: string) => v.length >= 8], ["Có chữ cái", (v: string) => /[A-Za-zÀ-ỹ]/.test(v)], ["Có chữ số", (v: string) => /\d/.test(v)]];
  function PasswordRules({ value = "" }: any) {
    return <ul className="hmt-pwr" aria-label="Yêu cầu mật khẩu">{PW_RULES.map(([t, f]: any) => { const ok = f(value); return <li key={t} data-ok={ok ? "true" : undefined}><Icon name={ok ? "check" : "x"} />{t}<span className="hmt-sr">{ok ? ": đạt" : ": chưa đạt"}</span></li>; })}</ul>;
  }
  const passwordOk = (v: string) => PW_RULES.every(([, f]: any) => f(v));

  (window as any).HMT = {
    Icon, Button, Field, TextInput, Select, Textarea, DateInput, MonthGrid,
    Table, Pagination, Badge, CountBadge, Avatar, Chip, Tooltip,
    Sidebar, TopNav, Tabs, Breadcrumb, BottomNav,
    ToastProvider, useToast, Alert, StateView, Skeleton, Spinner,
    Dialog, ConfirmDialog, Drawer, Popover, BlockingDialog,
    SegmentedControl, StudentListItem, PersonLine, ClassCard, ProgressBar, AttendanceSheet, AttBadge, ATT_STATUSES, CONTACT_REASONS, SaveState,
    StatusBar, SmartButton, SmartButtonGroup, Chatter, FilterBar, BulkActionBar, Kanban, KanbanCard, Calendar, SESSION_TYPES,
    Combobox, DateRange, MoneyInput, HoursDisplay, RatingScale, HomeworkStatus, ScoreInput, HW_STATUSES: HW, RadarChart, FileUpload, TaskStepper, SlaBadge, ApprovalChain, VersionedConfig, PrintLayout,
    AppShell, CrmNav, menuFor, CRM_MENU_ROWS, ROLE_LABEL, CAMPUSES, PageHeader, StatTile, LineChart, TeacherShell, GV_NAV, QuickGrid, StudentShell, HT_NAV, PH_NAV, PhotoPages, SubmissionViewer, AuthLayout, TurnstileSlot, OtpInput, PasswordInput, PasswordRules, passwordOk,
  };
})();
