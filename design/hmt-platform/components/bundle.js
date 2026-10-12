/* @ds-bundle: {"format": 4, "namespace": "HMT", "components": [{"name": "Button"}, {"name": "Field"}, {"name": "DateInput"}, {"name": "Table"}, {"name": "Pagination"}, {"name": "Badge"}, {"name": "Avatar"}, {"name": "Tooltip"}, {"name": "Chip"}, {"name": "Sidebar"}, {"name": "TopNav"}, {"name": "Tabs"}, {"name": "Breadcrumb"}, {"name": "BottomNav"}, {"name": "Toast"}, {"name": "Alert"}, {"name": "StateView"}, {"name": "Loading"}, {"name": "Dialog"}, {"name": "ConfirmDialog"}, {"name": "Drawer"}, {"name": "Popover"}, {"name": "SegmentedControl"}, {"name": "AttendanceSheet"}, {"name": "StudentListItem"}, {"name": "ClassCard"}, {"name": "ProgressBar"}, {"name": "StatusBar"}, {"name": "SmartButton"}, {"name": "Chatter"}, {"name": "FilterBar"}, {"name": "BulkActionBar"}, {"name": "Kanban"}, {"name": "Calendar"}, {"name": "Combobox"}, {"name": "DateRange"}, {"name": "MoneyInput"}, {"name": "HoursDisplay"}, {"name": "RatingScale"}, {"name": "HomeworkStatus"}, {"name": "RadarChart"}, {"name": "FileUpload"}, {"name": "TaskStepper"}, {"name": "SlaBadge"}, {"name": "ApprovalChain"}, {"name": "BlockingDialog"}, {"name": "VersionedConfig"}, {"name": "PrintLayout"}, {"name": "AppShell"}, {"name": "PageHeader"}, {"name": "StatTile"}, {"name": "LineChart"}, {"name": "TeacherShell"}, {"name": "QuickGrid"}, {"name": "StudentShell"}, {"name": "PhotoPages"}, {"name": "SubmissionViewer"}, {"name": "AuthLayout"}, {"name": "TurnstileSlot"}, {"name": "OtpInput"}, {"name": "PasswordInput"}, {"name": "ScoreInput"}]} */
"use strict";
(function () {
    const { useState, useEffect, useRef, useCallback, useMemo, useContext, createContext, useId, cloneElement, Fragment } = React;
    const cx = (...a) => a.filter(Boolean).join(" ");
    /* ---------------- Icons (placeholder set — icon library is OPEN) ---------------- */
    const P = {
        check: React.createElement("path", { d: "M5 12.5l4.5 4.5L19 7" }),
        x: React.createElement("path", { d: "M6 6l12 12M18 6L6 18" }),
        alert: React.createElement("g", null,
            React.createElement("path", { d: "M12 3.5l9.5 16.5h-19z" }),
            React.createElement("path", { d: "M12 10v4.5M12 17.5v.5" })),
        info: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "12", r: "9" }),
            React.createElement("path", { d: "M12 11v6M12 7.5v.5" })),
        xcircle: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "12", r: "9" }),
            React.createElement("path", { d: "M9 9l6 6M15 9l-6 6" })),
        checkcircle: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "12", r: "9" }),
            React.createElement("path", { d: "M8 12.5l3 3 5-6" })),
        chevronLeft: React.createElement("path", { d: "M15 5l-7 7 7 7" }),
        chevronRight: React.createElement("path", { d: "M9 5l7 7-7 7" }),
        chevronDown: React.createElement("path", { d: "M5 9l7 7 7-7" }),
        chevronsUpDown: React.createElement("path", { d: "M8 9l4-4 4 4M8 15l4 4 4-4" }),
        arrowUp: React.createElement("path", { d: "M12 19V5M6 11l6-6 6 6" }),
        arrowDown: React.createElement("path", { d: "M12 5v14M6 13l6 6 6-6" }),
        calendar: React.createElement("g", null,
            React.createElement("rect", { x: "3.5", y: "5", width: "17", height: "15", rx: "2" }),
            React.createElement("path", { d: "M3.5 10h17M8 3v4M16 3v4" })),
        search: React.createElement("g", null,
            React.createElement("circle", { cx: "11", cy: "11", r: "6.5" }),
            React.createElement("path", { d: "M16 16l4.5 4.5" })),
        home: React.createElement("path", { d: "M4 11l8-7 8 7v9h-5v-6H9v6H4z" }),
        users: React.createElement("g", null,
            React.createElement("circle", { cx: "9", cy: "8", r: "3.5" }),
            React.createElement("path", { d: "M2.5 20c.5-3.5 3-5.5 6.5-5.5s6 2 6.5 5.5" }),
            React.createElement("path", { d: "M16 4.8a3.5 3.5 0 010 6.4M18 14.8c2 .7 3.2 2.5 3.5 5.2" })),
        book: React.createElement("path", { d: "M4 5.5C4 4.7 4.7 4 5.5 4H11v16H5.5c-.8 0-1.5-.7-1.5-1.5zM20 5.5c0-.8-.7-1.5-1.5-1.5H13v16h5.5c.8 0 1.5-.7 1.5-1.5z" }),
        clipboard: React.createElement("g", null,
            React.createElement("rect", { x: "5", y: "4.5", width: "14", height: "16", rx: "2" }),
            React.createElement("path", { d: "M9 4.5V3h6v1.5M8.5 13l2.5 2.5 4.5-5" })),
        wallet: React.createElement("g", null,
            React.createElement("rect", { x: "3", y: "6", width: "18", height: "13", rx: "2" }),
            React.createElement("path", { d: "M3 10h18M16 14.5h2" })),
        settings: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "12", r: "3" }),
            React.createElement("path", { d: "M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1" })),
        menu: React.createElement("path", { d: "M4 7h16M4 12h16M4 17h16" }),
        bell: React.createElement("path", { d: "M6 16V11a6 6 0 0112 0v5l1.5 2h-15zM10 20.5h4" }),
        more: React.createElement("g", null,
            React.createElement("circle", { cx: "5.5", cy: "12", r: "1" }),
            React.createElement("circle", { cx: "12", cy: "12", r: "1" }),
            React.createElement("circle", { cx: "18.5", cy: "12", r: "1" })),
        file: React.createElement("g", null,
            React.createElement("path", { d: "M6 3h8l4 4v14H6z" }),
            React.createElement("path", { d: "M14 3v4h4M9 12h6M9 16h6" })),
        star: React.createElement("path", { d: "M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.9L12 17l-5.2 2.7 1-5.9-4.3-4.1 5.9-.8z" }),
        plus: React.createElement("path", { d: "M12 5v14M5 12h14" }),
        clock: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "12", r: "9" }),
            React.createElement("path", { d: "M12 7v5l3 2" })),
        mapPin: React.createElement("g", null,
            React.createElement("path", { d: "M12 21s-7-6.2-7-11.5a7 7 0 0114 0C19 14.8 12 21 12 21z" }),
            React.createElement("circle", { cx: "12", cy: "9.5", r: "2.5" })),
        inbox: React.createElement("g", null,
            React.createElement("path", { d: "M3 13l2.5-8h13L21 13v6H3z" }),
            React.createElement("path", { d: "M3 13h5l1.5 2.5h5L16 13h5" })),
        wifiOff: React.createElement("g", null,
            React.createElement("path", { d: "M3 3l18 18M8.5 16.5a5 5 0 017 0M5 12.5a10 10 0 015.5-2.6M19 12.5a10 10 0 00-3-1.9M2 9a15 15 0 015-2.6M22 9a15 15 0 00-9.5-3.9" }),
            React.createElement("path", { d: "M12 20h.01" })),
        refresh: React.createElement("path", { d: "M20 11a8 8 0 00-14.5-4.5M4 4v3.5h3.5M4 13a8 8 0 0014.5 4.5M20 20v-3.5h-3.5" }),
        trash: React.createElement("path", { d: "M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3" }),
        edit: React.createElement("path", { d: "M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4" }),
        logout: React.createElement("path", { d: "M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10" }),
        sidebar: React.createElement("g", null,
            React.createElement("rect", { x: "3.5", y: "4.5", width: "17", height: "15", rx: "2" }),
            React.createElement("path", { d: "M9 4.5v15" })),
        lock: React.createElement("g", null,
            React.createElement("rect", { x: "5", y: "11", width: "14", height: "9", rx: "2" }),
            React.createElement("path", { d: "M8 11V8a4 4 0 018 0v3" })),
        filter: React.createElement("path", { d: "M4 6h16M7 12h10M10 18h4" }),
        columns: React.createElement("g", null,
            React.createElement("rect", { x: "3.5", y: "4.5", width: "17", height: "15", rx: "2" }),
            React.createElement("path", { d: "M9.5 4.5v15M14.5 4.5v15" })),
        layers: React.createElement("path", { d: "M12 3l9 5-9 5-9-5zM3 13l9 5 9-5" }),
        bookmark: React.createElement("path", { d: "M6 3h12v18l-6-4-6 4z" }),
        list: React.createElement("path", { d: "M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01" }),
        kanban: React.createElement("g", null,
            React.createElement("rect", { x: "3.5", y: "4", width: "17", height: "16", rx: "2" }),
            React.createElement("path", { d: "M8 8v6M12 8v9M16 8v4" })),
        download: React.createElement("path", { d: "M12 4v11M7 10l5 5 5-5M5 20h14" }),
        upload: React.createElement("path", { d: "M12 20V9M7 14l5-5 5 5M5 4h14" }),
        camera: React.createElement("g", null,
            React.createElement("path", { d: "M4 8h3l2-3h6l2 3h3v11H4z" }),
            React.createElement("circle", { cx: "12", cy: "13", r: "3.5" })),
        image: React.createElement("g", null,
            React.createElement("rect", { x: "3.5", y: "4.5", width: "17", height: "15", rx: "2" }),
            React.createElement("circle", { cx: "9", cy: "10", r: "1.5" }),
            React.createElement("path", { d: "M20.5 16l-5-5-9 9" })),
        paperclip: React.createElement("path", { d: "M20 11l-8.5 8.5a5 5 0 01-7-7L13 4a3.5 3.5 0 015 5l-8.5 8.5a2 2 0 01-3-3L14 7" }),
        at: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "12", r: "4" }),
            React.createElement("path", { d: "M16 8v5a3 3 0 006 0v-1a10 10 0 10-4 8" })),
        send: React.createElement("path", { d: "M4 12l16-8-6 16-2-7z" }),
        history: React.createElement("path", { d: "M3 12a9 9 0 103-6.7M3 4v4h4M12 7v5l3 2" }),
        message: React.createElement("path", { d: "M4 5h16v11H8l-4 4z" }),
        receipt: React.createElement("path", { d: "M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6" }),
        userCheck: React.createElement("g", null,
            React.createElement("circle", { cx: "9", cy: "8", r: "3.5" }),
            React.createElement("path", { d: "M2.5 20c.5-3.5 3-5.5 6.5-5.5s6 2 6.5 5.5M16 11l2 2 4-4" })),
        graduation: React.createElement("path", { d: "M2 9l10-5 10 5-10 5zM6 11v5c3 2 9 2 12 0v-5" }),
        timer: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "13", r: "8" }),
            React.createElement("path", { d: "M12 9v4M10 2h4" })),
        hourglass: React.createElement("path", { d: "M6 3h12M6 21h12M7 3c0 6 10 6 10 9s-10 3-10 9M17 3c0 6-10 6-10 9" }),
        gift: React.createElement("g", null,
            React.createElement("rect", { x: "3.5", y: "8", width: "17", height: "4" }),
            React.createElement("path", { d: "M5 12v8h14v-8M12 8v12M12 8c-2-4-6-3-5 0M12 8c2-4 6-3 5 0" })),
        phone: React.createElement("path", { d: "M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2z" }),
        printer: React.createElement("g", null,
            React.createElement("path", { d: "M7 9V3h10v6M7 17H4v-7h16v7h-3" }),
            React.createElement("rect", { x: "7", y: "14", width: "10", height: "7" })),
        gitCompare: React.createElement("g", null,
            React.createElement("circle", { cx: "6", cy: "6", r: "2.5" }),
            React.createElement("circle", { cx: "18", cy: "18", r: "2.5" }),
            React.createElement("path", { d: "M6 8.5V15a3 3 0 003 3h5M18 15.5V9a3 3 0 00-3-3h-5" })),
        ban: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "12", r: "9" }),
            React.createElement("path", { d: "M5.6 5.6l12.8 12.8" })),
        arrowRight: React.createElement("path", { d: "M5 12h14M13 6l6 6-6 6" }),
        grip: React.createElement("path", { d: "M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01" }),
        fileCheck: React.createElement("g", null,
            React.createElement("path", { d: "M6 3h8l4 4v14H6z" }),
            React.createElement("path", { d: "M9 14l2 2 4-4" })),
        userX: React.createElement("g", null,
            React.createElement("circle", { cx: "9", cy: "8", r: "3.5" }),
            React.createElement("path", { d: "M2.5 20c.5-3.5 3-5.5 6.5-5.5s6 2 6.5 5.5M17 9l4 4M21 9l-4 4" })),
        moreV: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "5.5", r: "1" }),
            React.createElement("circle", { cx: "12", cy: "12", r: "1" }),
            React.createElement("circle", { cx: "12", cy: "18.5", r: "1" })),
        rotateCw: React.createElement("path", { d: "M20 12a8 8 0 11-2.3-5.7M20 4v4h-4" }),
        zoomIn: React.createElement("g", null,
            React.createElement("circle", { cx: "11", cy: "11", r: "7" }),
            React.createElement("path", { d: "M20 20l-4-4M8 11h6M11 8v6" })),
        zoomOut: React.createElement("g", null,
            React.createElement("circle", { cx: "11", cy: "11", r: "7" }),
            React.createElement("path", { d: "M20 20l-4-4M8 11h6" })),
        eye: React.createElement("g", null,
            React.createElement("path", { d: "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" }),
            React.createElement("circle", { cx: "12", cy: "12", r: "3" })),
        award: React.createElement("g", null,
            React.createElement("circle", { cx: "12", cy: "9", r: "6" }),
            React.createElement("path", { d: "M8.5 14L7 22l5-3 5 3-1.5-8" })),
        flame: React.createElement("path", { d: "M12 3c1 4 6 6 6 11a6 6 0 01-12 0c0-3 2-4 2-6 1 1 2 2 2 4 1-3 1-6 2-9z" }),
    };
    /* Lucide (O-12): names map to Lucide icons; the page loads lucide UMD from CDN.
       When window.lucide is unavailable the placeholder set above is drawn instead. */
    const LUCIDE = {
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
    function lucideNode(name) {
        const L = window.lucide;
        if (!L || !L.icons)
            return null;
        for (const n of LUCIDE[name] || []) {
            const node = L.icons[n];
            if (node)
                return node[0] === "svg" ? node[2] : node;
        }
        return null;
    }
    function renderNode(children) { return children.map(([tag, attrs, kids], i) => React.createElement(tag, { key: i, ...attrs }, kids ? renderNode(kids) : null)); }
    function Icon({ name, label, className, size }) {
        const ln = lucideNode(name);
        const p = ln ? renderNode(ln) : (P[name] || P.info);
        return (React.createElement("svg", { viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.5, strokeLinecap: "round", strokeLinejoin: "round", width: size, height: size, className: cx("hmt-icon", className), "aria-hidden": label ? undefined : true, role: label ? "img" : undefined, "aria-label": label, focusable: "false" }, p));
    }
    const TONE_ICON = { success: "checkcircle", warning: "alert", danger: "xcircle", info: "info" };
    /* ---------------- Button (one component, configured by variant) ---------------- */
    function Button({ variant = "primary", size, solid, loading, loadingLabel, disabled, iconStart, iconEnd, iconOnly, label, fullWidth, neutral, children, onClick, type = "button", className, ...rest }) {
        const inactive = disabled || loading;
        const v = variant === "destructive" && solid ? "destructive-solid" : variant;
        const text = iconOnly ? null : (loading && loadingLabel ? loadingLabel : children);
        const btn = (React.createElement("button", { type: type, ...rest, className: cx("hmt-btn hmt-focus", `hmt-btn--${v}`, size === "sm" && "hmt-btn--sm", fullWidth && "hmt-btn--full", iconOnly && "hmt-btn--icon", neutral && "hmt-btn--neutral", className), "aria-disabled": disabled ? true : undefined, "aria-busy": loading ? true : undefined, "aria-label": iconOnly ? label : rest["aria-label"], onClick: (e) => { if (inactive) {
                e.preventDefault();
                return;
            } onClick && onClick(e); } },
            loading ? React.createElement("span", { className: "hmt-spinner", "aria-hidden": "true" }) : iconStart && React.createElement(Icon, { name: iconStart }),
            iconOnly && !loading ? React.createElement(Icon, { name: iconOnly }) : null,
            text,
            iconEnd && !loading ? React.createElement(Icon, { name: iconEnd }) : null));
        return iconOnly ? React.createElement(Tooltip, { content: label }, btn) : btn;
    }
    /* ---------------- Field + inputs (one wrapper, many controls) ---------------- */
    const FieldCtx = createContext(null);
    function Field({ label, helper, error, required, optional, counter, children, className, hideLabel }) {
        const id = useId();
        const ctx = { id: `${id}-c`, describedBy: [helper && `${id}-h`, error && `${id}-e`].filter(Boolean).join(" ") || undefined, invalid: !!error, required };
        return (React.createElement("div", { className: cx("hmt-field", className) },
            React.createElement("label", { className: cx("hmt-label", hideLabel && "hmt-sr"), htmlFor: ctx.id },
                label,
                required ? React.createElement("span", { className: "hmt-req", "aria-hidden": "true" }, "*") : null,
                optional ? React.createElement("span", { className: "hmt-label-opt" }, "(kh\u00F4ng b\u1EAFt bu\u1ED9c)") : null),
            React.createElement(FieldCtx.Provider, { value: ctx }, children),
            error ? React.createElement("p", { className: "hmt-err", id: `${id}-e` },
                React.createElement(Icon, { name: "xcircle" }),
                " ",
                React.createElement("span", null, error)) : null,
            helper && !error ? React.createElement("p", { className: "hmt-help", id: `${id}-h` }, helper) : null,
            helper && error ? React.createElement("p", { className: "hmt-sr", id: `${id}-h` }, helper) : null,
            counter));
    }
    function useField(props) {
        const ctx = useContext(FieldCtx) || {};
        return {
            id: props.id || ctx.id,
            "aria-describedby": props["aria-describedby"] || ctx.describedBy,
            "aria-invalid": props.invalid || ctx.invalid ? true : undefined,
            "aria-required": ctx.required ? true : undefined,
        };
    }
    function TextInput({ leadingIcon, trailing, invalid, disabled, className, ...rest }) {
        const f = useField({ invalid, ...rest });
        return (React.createElement("div", { className: cx("hmt-control", className), "data-invalid": f["aria-invalid"] ? "true" : undefined, "data-disabled": disabled ? "true" : undefined },
            leadingIcon ? React.createElement("span", { className: "hmt-adorn" },
                React.createElement(Icon, { name: leadingIcon })) : null,
            React.createElement("input", { ...rest, ...f, disabled: disabled }),
            trailing));
    }
    function Select({ options = [], placeholder, invalid, disabled, className, ...rest }) {
        const f = useField({ invalid, ...rest });
        return (React.createElement("div", { className: cx("hmt-control hmt-control--select", className), "data-invalid": f["aria-invalid"] ? "true" : undefined, "data-disabled": disabled ? "true" : undefined },
            React.createElement("select", { ...rest, ...f, disabled: disabled },
                placeholder ? React.createElement("option", { value: "", disabled: true }, placeholder) : null,
                options.map((o) => React.createElement("option", { key: o.value, value: o.value }, o.label))),
            React.createElement(Icon, { name: "chevronDown" })));
    }
    function Textarea({ maxLength, value, invalid, disabled, className, ...rest }) {
        const f = useField({ invalid, ...rest });
        const n = (value || "").length;
        return (React.createElement(Fragment, null,
            React.createElement("div", { className: cx("hmt-control hmt-control--area", className), "data-invalid": f["aria-invalid"] ? "true" : undefined, "data-disabled": disabled ? "true" : undefined },
                React.createElement("textarea", { ...rest, ...f, value: value, disabled: disabled })),
            maxLength ? React.createElement("p", { className: "hmt-count", "data-over": n > maxLength ? "true" : undefined, "aria-live": "polite" },
                n,
                "/",
                maxLength) : null));
    }
    /* Date: dd/mm/yyyy text + calendar popover (desktop); native date on mobile */
    const pad = (n) => String(n).padStart(2, "0");
    const fmt = (d) => `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()}`;
    function parseVN(s) {
        const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(s || "");
        if (!m)
            return null;
        const d = new Date(+m[3], +m[2] - 1, +m[1]);
        return d.getDate() === +m[1] && d.getMonth() === +m[2] - 1 ? d : null;
    }
    const DOW = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
    const MONTHS = ["Tháng 1", "Tháng 2", "Tháng 3", "Tháng 4", "Tháng 5", "Tháng 6", "Tháng 7", "Tháng 8", "Tháng 9", "Tháng 10", "Tháng 11", "Tháng 12"];
    function MonthGrid({ value, onSelect, today = new Date(), rangeFrom, rangeTo, autoFocus = true }) {
        const [cursor, setCursor] = useState(value || rangeFrom || today);
        const gridRef = useRef(null);
        const y = cursor.getFullYear(), mo = cursor.getMonth();
        const first = new Date(y, mo, 1);
        const offset = (first.getDay() + 6) % 7;
        const days = Array.from({ length: 42 }, (_, i) => new Date(y, mo, 1 - offset + i));
        const same = (a, b) => a && b && a.toDateString() === b.toDateString();
        const first_ = useRef(true);
        useEffect(() => { if (first_.current && !autoFocus) {
            first_.current = false;
            return;
        } first_.current = false; const el = gridRef.current && gridRef.current.querySelector('[tabindex="0"]'); el && el.focus(); }, [cursor]);
        const inRange = (d) => rangeFrom && rangeTo && d >= rangeFrom && d <= rangeTo;
        const move = (n) => { const d = new Date(cursor); d.setDate(d.getDate() + n); setCursor(d); };
        const onKey = (e) => {
            const k = e.key;
            if (k === "ArrowLeft")
                move(-1);
            else if (k === "ArrowRight")
                move(1);
            else if (k === "ArrowUp")
                move(-7);
            else if (k === "ArrowDown")
                move(7);
            else if (k === "PageUp")
                setCursor(new Date(y, mo - 1, Math.min(cursor.getDate(), 28)));
            else if (k === "PageDown")
                setCursor(new Date(y, mo + 1, Math.min(cursor.getDate(), 28)));
            else if (k === "Home")
                move(-((cursor.getDay() + 6) % 7));
            else if (k === "End")
                move(6 - ((cursor.getDay() + 6) % 7));
            else if (k === "Enter" || k === " ")
                onSelect(cursor);
            else
                return;
            e.preventDefault();
        };
        return (React.createElement("div", { className: "hmt-cal" },
            React.createElement("div", { className: "hmt-cal-head" },
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "chevronLeft", label: "Th\u00E1ng tr\u01B0\u1EDBc", onClick: () => setCursor(new Date(y, mo - 1, 1)) }),
                React.createElement("span", { "aria-live": "polite" },
                    MONTHS[mo],
                    " ",
                    y),
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "chevronRight", label: "Th\u00E1ng sau", onClick: () => setCursor(new Date(y, mo + 1, 1)) })),
            React.createElement("div", { className: "hmt-cal-grid", role: "grid", "aria-label": `${MONTHS[mo]} ${y}`, ref: gridRef, onKeyDown: onKey },
                DOW.map((d) => React.createElement("div", { key: d, className: "hmt-cal-dow", role: "columnheader" }, d)),
                days.map((d) => (React.createElement("button", { key: d.toISOString(), type: "button", role: "gridcell", className: "hmt-cal-day", tabIndex: same(d, cursor) ? 0 : -1, "aria-selected": same(d, value) || same(d, rangeFrom) || same(d, rangeTo) ? true : undefined, "data-inrange": inRange(d) ? "true" : undefined, "data-today": same(d, today) ? "true" : undefined, "data-out": d.getMonth() !== mo ? "true" : undefined, "aria-label": `${d.getDate()} ${MONTHS[d.getMonth()].toLowerCase()} ${d.getFullYear()}`, onClick: () => onSelect(d) }, d.getDate()))))));
    }
    function DateInput({ value = "", onChange, invalid, disabled, native, min, max, ...rest }) {
        const [open, setOpen] = useState(false);
        const ctrlRef = useRef(null);
        const f = useField({ invalid, ...rest });
        if (native) {
            const iso = (() => { const d = parseVN(value); return d ? `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` : ""; })();
            return (React.createElement("div", { className: "hmt-control", "data-invalid": f["aria-invalid"] ? "true" : undefined },
                React.createElement("input", { type: "date", ...f, value: iso, disabled: disabled, onChange: (e) => { const [yy, mm, dd] = e.target.value.split("-"); onChange && onChange(e.target.value ? `${dd}/${mm}/${yy}` : ""); } })));
        }
        const mask = (s) => { const d = s.replace(/\D/g, "").slice(0, 8); return [d.slice(0, 2), d.slice(2, 4), d.slice(4)].filter(Boolean).join("/"); };
        return (React.createElement(Fragment, null,
            React.createElement("div", { ref: ctrlRef, className: "hmt-control", "data-invalid": f["aria-invalid"] ? "true" : undefined, "data-disabled": disabled ? "true" : undefined },
                React.createElement("input", { ...rest, ...f, inputMode: "numeric", placeholder: "dd/mm/yyyy", autoComplete: "off", value: value, disabled: disabled, onChange: (e) => onChange && onChange(mask(e.target.value)) }),
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "calendar", label: "Ch\u1ECDn ng\u00E0y t\u1EEB l\u1ECBch", "aria-haspopup": "dialog", "aria-expanded": open, disabled: disabled, onClick: () => setOpen(!open) })),
            React.createElement(PopoverPanel, { open: open, onClose: () => setOpen(false), anchorRoot: ctrlRef, label: "Ch\u1ECDn ng\u00E0y", initialFocus: '[role="gridcell"][tabindex="0"]' },
                React.createElement(MonthGrid, { value: parseVN(value), onSelect: (d) => { onChange && onChange(fmt(d)); setOpen(false); } }))));
    }
    /* ---------------- Focus management shared by Dialog, Drawer, Popover ---------------- */
    const FOCUSABLE = 'a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])';
    function useOverlay(open, onClose, panelRef, { trap = true, initialFocus } = {}) {
        useEffect(() => {
            if (!open)
                return;
            const prev = document.activeElement;
            const panel = panelRef.current;
            const first = (initialFocus && panel && panel.querySelector(initialFocus)) || (panel && panel.querySelector(FOCUSABLE)) || panel;
            first && first.focus && first.focus();
            const onKey = (e) => {
                if (e.key === "Escape") {
                    e.stopPropagation();
                    onClose();
                }
                if (trap && e.key === "Tab" && panel) {
                    const els = Array.from(panel.querySelectorAll(FOCUSABLE));
                    if (!els.length)
                        return;
                    const a = els[0], b = els[els.length - 1];
                    if (e.shiftKey && document.activeElement === a) {
                        e.preventDefault();
                        b.focus();
                    }
                    else if (!e.shiftKey && document.activeElement === b) {
                        e.preventDefault();
                        a.focus();
                    }
                }
            };
            document.addEventListener("keydown", onKey, true);
            const ov = trap ? document.body.style.overflow : null;
            if (trap)
                document.body.style.overflow = "hidden";
            return () => { document.removeEventListener("keydown", onKey, true); if (trap)
                document.body.style.overflow = ov || ""; prev && prev.focus && prev.focus(); };
        }, [open]);
    }
    function Dialog({ open, onClose, title, description, tone, size, children, footer, role = "dialog", initialFocus, dismissible = true }) {
        const ref = useRef(null);
        const id = useId();
        useOverlay(open, () => dismissible && onClose(), ref, { initialFocus: initialFocus || ".hmt-ov-body input, .hmt-ov-body select, .hmt-ov-body textarea, .hmt-ov-body button, .hmt-ov-foot button" });
        if (!open)
            return null;
        return ReactDOM.createPortal(React.createElement("div", { className: "hmt-root" },
            React.createElement("div", { className: "hmt-scrim", onClick: () => dismissible && onClose() }),
            React.createElement("div", { ref: ref, className: cx("hmt-dialog", size === "lg" && "hmt-dialog--lg"), role: role, "aria-modal": "true", "aria-labelledby": `${id}-t`, "aria-describedby": description ? `${id}-d` : undefined, tabIndex: -1 },
                React.createElement("div", { className: "hmt-ov-head" },
                    tone ? React.createElement("span", { className: `hmt-ov-icon hmt-ov-icon--${tone}` },
                        React.createElement(Icon, { name: TONE_ICON[tone] })) : null,
                    React.createElement("div", { style: { flex: 1 } },
                        React.createElement("h2", { className: "hmt-ov-title", id: `${id}-t` }, title),
                        description ? React.createElement("p", { className: "hmt-ov-desc", id: `${id}-d` }, description) : null),
                    dismissible ? React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "x", label: "\u0110\u00F3ng", onClick: onClose }) : null),
                children ? React.createElement("div", { className: "hmt-ov-body" }, children) : null,
                footer ? React.createElement("div", { className: "hmt-ov-foot" }, footer) : null)), document.body);
    }
    /* ConfirmDialog = Dialog configured; not a separate overlay */
    /* ConfirmDialog = Dialog configured. reasonLabel → bắt buộc lý do (huỷ, từ chối, điều chỉnh, đảo khoản…) */
    function ConfirmDialog({ open, onClose, onConfirm, title, description, confirmLabel, cancelLabel = "Huỷ", tone = "danger", loading, children, reasonLabel, reasonOptions, reasonHelper }) {
        const [reason, setReason] = useState("");
        const [note, setNote] = useState("");
        const [tried, setTried] = useState(false);
        useEffect(() => { if (open) {
            setReason("");
            setNote("");
            setTried(false);
        } }, [open]);
        const needNote = !reasonOptions || reason === "other";
        const missing = reasonLabel ? (reasonOptions ? !reason || (reason === "other" && !note.trim()) : !note.trim()) : false;
        const go = () => { setTried(true); if (missing) {
            const el = document.querySelector("[data-reason]");
            el && el.focus();
            return;
        } onConfirm({ reason, note: note.trim() }); };
        return (React.createElement(Dialog, { open: open, onClose: onClose, title: title, description: description, tone: tone, role: "alertdialog", initialFocus: reasonLabel ? "[data-reason]" : "[data-cancel]", dismissible: !loading, footer: React.createElement(Fragment, null,
                React.createElement(Button, { variant: "secondary", onClick: onClose, "data-cancel": "", disabled: loading }, cancelLabel),
                React.createElement(Button, { variant: tone === "danger" ? "destructive" : "primary", solid: tone === "danger", loading: loading, loadingLabel: "\u0110ang x\u1EED l\u00FD\u2026", onClick: go }, confirmLabel)) },
            children,
            reasonLabel ? React.createElement("div", { style: { display: "grid", gap: 12, marginTop: children ? 12 : 0 } },
                reasonOptions ? React.createElement(Field, { label: reasonLabel, required: true, error: tried && !reason ? "Chọn lý do" : undefined },
                    React.createElement(Select, { "data-reason": "", value: reason, onChange: (e) => setReason(e.target.value), placeholder: "Ch\u1ECDn l\u00FD do", options: [...reasonOptions, { value: "other", label: "Khác…" }] })) : null,
                needNote ? React.createElement(Field, { label: reasonOptions ? "Ghi rõ lý do" : reasonLabel, required: true, helper: reasonHelper, error: tried && !note.trim() ? "Nhập lý do" : undefined },
                    React.createElement(Textarea, { "data-reason": reasonOptions ? undefined : "", value: note, onChange: (e) => setNote(e.target.value), maxLength: 500 })) : null) : null));
    }
    function Drawer({ open, onClose, title, description, placement = "right", children, footer }) {
        const ref = useRef(null);
        const id = useId();
        useOverlay(open, onClose, ref, { initialFocus: ".hmt-ov-body input, .hmt-ov-body select, .hmt-ov-body textarea, .hmt-ov-body button, .hmt-ov-foot button" });
        if (!open)
            return null;
        return ReactDOM.createPortal(React.createElement("div", { className: "hmt-root" },
            React.createElement("div", { className: "hmt-scrim", onClick: onClose }),
            React.createElement("div", { ref: ref, className: cx("hmt-drawer", `hmt-drawer--${placement}`), role: "dialog", "aria-modal": "true", "aria-labelledby": `${id}-t`, tabIndex: -1 },
                React.createElement("div", { className: "hmt-ov-head" },
                    React.createElement("div", { style: { flex: 1 } },
                        React.createElement("h2", { className: "hmt-ov-title", id: `${id}-t` }, title),
                        description ? React.createElement("p", { className: "hmt-ov-desc" }, description) : null),
                    React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "x", label: "\u0110\u00F3ng", onClick: onClose })),
                React.createElement("div", { className: "hmt-ov-body" }, children),
                footer ? React.createElement("div", { className: "hmt-ov-foot" }, footer) : null)), document.body);
    }
    function PopoverPanel({ open, onClose, anchorRoot, anchorSelector, label, children, placement = "bottom-start", role = "dialog", initialFocus }) {
        const ref = useRef(null);
        const [pos, setPos] = useState({ top: -9999, left: -9999 });
        useOverlay(open, onClose, ref, { trap: false, initialFocus });
        useEffect(() => {
            if (!open)
                return;
            const anchor = (anchorRoot && anchorRoot.current) || document.querySelector(anchorSelector);
            const place = () => {
                if (!anchor || !ref.current)
                    return;
                const r = anchor.getBoundingClientRect();
                const p = ref.current.getBoundingClientRect();
                let top = r.bottom + 6, left = placement.endsWith("end") ? r.right - p.width : r.left;
                if (top + p.height > window.innerHeight - 8)
                    top = Math.max(8, r.top - p.height - 6);
                left = Math.min(Math.max(8, left), window.innerWidth - p.width - 8);
                setPos({ top, left });
            };
            place();
            const t = setTimeout(place, 0);
            const out = (e) => { if (ref.current && !ref.current.contains(e.target) && !(anchor && anchor.contains(e.target)))
                onClose(); };
            document.addEventListener("mousedown", out);
            window.addEventListener("resize", place);
            window.addEventListener("scroll", place, true);
            return () => { clearTimeout(t); document.removeEventListener("mousedown", out); window.removeEventListener("resize", place); window.removeEventListener("scroll", place, true); };
        }, [open]);
        if (!open)
            return null;
        return ReactDOM.createPortal(React.createElement("div", { className: "hmt-root" },
            React.createElement("div", { ref: ref, className: "hmt-pop", role: role, "aria-label": label, style: { top: pos.top, left: pos.left } }, children)), document.body);
    }
    function Popover({ trigger, label, children, placement }) {
        const [open, setOpen] = useState(false);
        const id = useId();
        const anchorRef = useRef(null);
        const t = cloneElement(trigger, { "aria-haspopup": "dialog", "aria-expanded": open, "aria-controls": open ? id : undefined, onClick: () => setOpen(!open) });
        return (React.createElement(Fragment, null,
            React.createElement("span", { style: { display: "inline-flex" }, ref: anchorRef }, t),
            React.createElement(PopoverPanel, { open: open, onClose: () => setOpen(false), anchorRoot: anchorRef, label: label, placement: placement },
                React.createElement("div", { id: id, className: "hmt-pop-body" }, typeof children === "function" ? children(() => setOpen(false)) : children))));
    }
    /* ---------------- Tooltip ---------------- */
    function Tooltip({ content, children, delay = 400 }) {
        const [show, setShow] = useState(false);
        const [pos, setPos] = useState({ top: 0, left: 0 });
        const id = useId();
        const wrap = useRef(null);
        const timer = useRef(0);
        const open = (immediate) => {
            clearTimeout(timer.current);
            timer.current = setTimeout(() => {
                const el = wrap.current && wrap.current.firstElementChild;
                if (!el)
                    return;
                const r = el.getBoundingClientRect();
                setPos({ top: r.top - 8, left: r.left + r.width / 2 });
                setShow(true);
            }, immediate ? 0 : delay);
        };
        const close = () => { clearTimeout(timer.current); setShow(false); };
        useEffect(() => { if (!show)
            return; const k = (e) => e.key === "Escape" && close(); document.addEventListener("keydown", k); return () => document.removeEventListener("keydown", k); }, [show]);
        const dup = children.props && children.props["aria-label"] === content;
        const child = dup ? children : cloneElement(children, { "aria-describedby": show ? id : undefined });
        return (React.createElement("span", { ref: wrap, style: { display: "inline-flex" }, onMouseEnter: () => open(), onMouseLeave: close, onFocus: (e) => e.target.matches(":focus-visible") && open(true), onBlur: close },
            child,
            show ? ReactDOM.createPortal(React.createElement("div", { className: "hmt-root" },
                React.createElement("div", { role: "tooltip", id: id, className: "hmt-tip", style: { top: pos.top, left: pos.left, transform: "translate(-50%,-100%)" } }, content)), document.body) : null));
    }
    /* ---------------- Data display ---------------- */
    function Badge({ tone = "neutral", solid, icon, children }) {
        const ic = icon === false ? null : icon || TONE_ICON[tone];
        return React.createElement("span", { className: cx("hmt-badge", `hmt-badge--${tone}`, solid && "hmt-badge--solid") },
            ic ? React.createElement(Icon, { name: ic }) : null,
            children);
    }
    function CountBadge({ count, label }) {
        if (!count)
            return null;
        return React.createElement("span", { className: "hmt-badge hmt-badge--count", "aria-label": label || `${count} mục mới` }, count > 99 ? "99+" : count);
    }
    function initials(name) { const p = (name || "").trim().split(/\s+/); return ((p.length > 1 ? p[p.length - 2][0] : "") + (p[p.length - 1] || "")[0]).toUpperCase(); }
    function Avatar({ name, src, size = "md", decorative }) {
        const [err, setErr] = useState(false);
        return (React.createElement("span", { className: cx("hmt-avatar", `hmt-avatar--${size}`), role: decorative ? undefined : "img", "aria-label": decorative ? undefined : name, "aria-hidden": decorative ? true : undefined }, src && !err ? React.createElement("img", { src: src, alt: "", onError: () => setErr(true) }) : React.createElement("span", { "aria-hidden": "true" }, initials(name))));
    }
    function Chip({ selected, onToggle, children, count }) {
        return React.createElement("button", { type: "button", className: "hmt-chip hmt-focus", "aria-pressed": !!selected, onClick: onToggle },
            selected ? React.createElement(Icon, { name: "check" }) : null,
            children,
            count != null ? React.createElement("span", { className: "hmt-tabular", style: { opacity: .8 } },
                "\u00B7 ",
                count) : null);
    }
    function useNarrow(ref, bp = 640) {
        const [narrow, setNarrow] = useState(false);
        useEffect(() => {
            if (!ref.current || typeof ResizeObserver === "undefined")
                return;
            const ro = new ResizeObserver(([e]) => setNarrow(e.contentRect.width < bp));
            ro.observe(ref.current);
            return () => ro.disconnect();
        }, []);
        return narrow;
    }
    function Table({ columns, rows, rowKey = "id", caption, selectable, selected = [], onSelectedChange, sort, onSortChange, loading, empty, bulkActions, rowLabel = (r) => r.name, cardsBelow = 640, maxHeight }) {
        const wrap = useRef(null);
        const narrow = useNarrow(wrap, cardsBelow);
        const allIds = rows.map((r) => r[rowKey]);
        const all = allIds.length > 0 && allIds.every((id) => selected.includes(id));
        const some = !all && allIds.some((id) => selected.includes(id));
        const headRef = useRef(null);
        useEffect(() => { if (headRef.current)
            headRef.current.indeterminate = some; }, [some]);
        const toggle = (id) => onSelectedChange(selected.includes(id) ? selected.filter((x) => x !== id) : [...selected, id]);
        const sortIcon = (c) => !sort || sort.key !== c.key ? "chevronsUpDown" : sort.dir === "asc" ? "arrowUp" : "arrowDown";
        const ariaSort = (c) => !c.sortable ? undefined : !sort || sort.key !== c.key ? "none" : sort.dir === "asc" ? "ascending" : "descending";
        const body = loading
            ? Array.from({ length: 4 }, (_, i) => React.createElement("tr", { key: `s${i}` },
                selectable ? React.createElement("td", null,
                    React.createElement(Skeleton, { width: 18, height: 18 })) : null,
                columns.map((c) => React.createElement("td", { key: c.key, className: c.numeric ? "hmt-num" : undefined },
                    React.createElement(Skeleton, { width: c.numeric ? 80 : 120 })))))
            : rows.map((r) => {
                const id = r[rowKey];
                const sel = selected.includes(id);
                return (React.createElement("tr", { key: id, "aria-selected": selectable ? sel : undefined },
                    selectable ? React.createElement("td", { style: { width: 44 } },
                        React.createElement("input", { type: "checkbox", className: "hmt-check", checked: sel, onChange: () => toggle(id), "aria-label": `Chọn ${rowLabel(r)}` })) : null,
                    columns.map((c) => React.createElement("td", { key: c.key, className: c.numeric ? "hmt-num" : undefined }, c.render ? c.render(r) : r[c.key]))));
            });
        return (React.createElement("div", { ref: wrap }, narrow && !loading ? (rows.length ? React.createElement("ul", { className: "hmt-table-cards", "aria-label": caption, style: { listStyle: "none", margin: 0, padding: 0 } }, rows.map((r) => (React.createElement("li", { key: r[rowKey], className: "hmt-rowcard" }, columns.map((c, i) => i === 0
            ? React.createElement("div", { key: c.key, style: { fontWeight: 600 } }, c.render ? c.render(r) : r[c.key])
            : React.createElement("div", { key: c.key, className: "hmt-rowcard-line" },
                React.createElement("span", { className: "hmt-rowcard-k" }, c.header),
                React.createElement("span", { className: c.numeric ? "hmt-tabular" : undefined }, c.render ? c.render(r) : r[c.key]))))))) : empty) : (React.createElement("div", { className: "hmt-table-wrap", style: maxHeight ? { maxHeight } : undefined },
            selectable && selected.length ? React.createElement(BulkActionBar, { count: selected.length, onClear: () => onSelectedChange([]) }, bulkActions) : null,
            React.createElement("table", { className: "hmt-table", "aria-busy": loading ? true : undefined },
                caption ? React.createElement("caption", { className: "hmt-sr" }, caption) : null,
                React.createElement("thead", null,
                    React.createElement("tr", null,
                        selectable ? React.createElement("th", { style: { width: 44 } },
                            React.createElement("input", { ref: headRef, type: "checkbox", className: "hmt-check", checked: all, onChange: () => onSelectedChange(all ? [] : allIds), "aria-label": "Ch\u1ECDn t\u1EA5t c\u1EA3 tr\u00EAn trang" })) : null,
                        columns.map((c) => (React.createElement("th", { key: c.key, scope: "col", className: c.numeric ? "hmt-num" : undefined, "aria-sort": ariaSort(c), style: c.width ? { width: c.width } : undefined }, c.sortable ? React.createElement("button", { type: "button", className: "hmt-th-sort", "data-active": sort && sort.key === c.key ? "true" : undefined, onClick: () => onSortChange({ key: c.key, dir: sort && sort.key === c.key && sort.dir === "asc" ? "desc" : "asc" }) },
                            c.header,
                            React.createElement(Icon, { name: sortIcon(c) })) : c.header))))),
                React.createElement("tbody", null, !loading && !rows.length ? React.createElement("tr", null,
                    React.createElement("td", { colSpan: columns.length + (selectable ? 1 : 0), style: { height: "auto" } }, empty)) : body))))));
    }
    function Pagination({ page, pageCount, onPageChange, total, pageSize, compact }) {
        const pages = useMemo(() => {
            const s = new Set([1, pageCount, page - 1, page, page + 1].filter((p) => p >= 1 && p <= pageCount));
            const arr = Array.from(s).sort((a, b) => a - b);
            const out = [];
            arr.forEach((p, i) => { if (i && p - arr[i - 1] > 1)
                out.push("…" + p); out.push(p); });
            return out;
        }, [page, pageCount]);
        const from = (page - 1) * pageSize + 1, to = Math.min(total, page * pageSize);
        return (React.createElement("nav", { className: "hmt-pager", "aria-label": "Ph\u00E2n trang" },
            total != null ? React.createElement("span", { className: "hmt-pager-info hmt-tabular" },
                from,
                "\u2013",
                to,
                " / ",
                total.toLocaleString("vi-VN")) : null,
            React.createElement(Button, { variant: "secondary", size: "sm", iconOnly: "chevronLeft", label: "Trang tr\u01B0\u1EDBc", disabled: page <= 1, onClick: () => onPageChange(page - 1) }),
            compact ? React.createElement("span", { className: "hmt-tabular", "aria-live": "polite", style: { padding: "0 8px" } },
                "Trang ",
                page,
                "/",
                pageCount)
                : pages.map((p) => typeof p === "string" ? React.createElement("span", { key: p, "aria-hidden": "true", style: { padding: "0 4px", color: "var(--hmt-fg-muted)" } }, "\u2026")
                    : React.createElement(Button, { key: p, variant: "secondary", size: "sm", "aria-current": p === page ? "page" : undefined, "aria-label": `Trang ${p}`, onClick: () => onPageChange(p) },
                        React.createElement("span", { className: "hmt-tabular" }, p))),
            React.createElement(Button, { variant: "secondary", size: "sm", iconOnly: "chevronRight", label: "Trang sau", disabled: page >= pageCount, onClick: () => onPageChange(page + 1) })));
    }
    /* ---------------- Navigation ---------------- */
    function Sidebar({ title = "Hòa Ma Toán", subtitle, sections, activeId, onNavigate, collapsed, onCollapsedChange, footer }) {
        return (React.createElement("nav", { className: "hmt-sidebar", "data-collapsed": collapsed ? "true" : undefined, "aria-label": "\u0110i\u1EC1u h\u01B0\u1EDBng ch\u00EDnh" },
            React.createElement("div", { className: "hmt-sidebar-head" },
                React.createElement("span", { className: "hmt-wordmark" },
                    title,
                    subtitle ? React.createElement("small", null, subtitle) : null)),
            React.createElement("ul", { className: "hmt-nav" }, sections.map((s) => (React.createElement(Fragment, { key: s.label || "main" },
                s.label ? React.createElement("li", { className: "hmt-nav-sec", "aria-hidden": collapsed ? true : undefined }, s.label) : null,
                s.items.map((it) => {
                    const link = (React.createElement("a", { href: it.href || "#", "aria-current": it.id === activeId ? "page" : undefined, "aria-label": collapsed ? it.label : undefined, onClick: (e) => { e.preventDefault(); onNavigate && onNavigate(it.id); } },
                        React.createElement(Icon, { name: it.icon }),
                        React.createElement("span", { className: "hmt-nav-label" }, it.label),
                        React.createElement(CountBadge, { count: it.badge })));
                    return React.createElement("li", { key: it.id }, collapsed ? React.createElement(Tooltip, { content: it.label }, link) : link);
                }))))),
            React.createElement("div", { className: "hmt-sidebar-foot" },
                footer,
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconStart: "sidebar", "aria-expanded": !collapsed, onClick: () => onCollapsedChange(!collapsed), iconOnly: collapsed ? "sidebar" : undefined, label: collapsed ? "Mở rộng menu" : undefined }, collapsed ? null : "Thu gọn"))));
    }
    function TopNav({ title, leading, actions, children }) {
        return (React.createElement("header", { className: "hmt-topnav" },
            leading,
            React.createElement("h1", { className: "hmt-topnav-title" }, title),
            children,
            React.createElement("div", { className: "hmt-topnav-actions" }, actions)));
    }
    function Tabs({ items, value, onChange, label, children }) {
        const id = useId();
        const refs = useRef({});
        const idx = items.findIndex((t) => t.value === value);
        const go = (i) => { const t = items[(i + items.length) % items.length]; onChange(t.value); setTimeout(() => refs.current[t.value] && refs.current[t.value].focus(), 0); };
        return (React.createElement("div", null,
            React.createElement("div", { className: "hmt-tabs", role: "tablist", "aria-label": label, onKeyDown: (e) => { const k = e.key; if (k === "ArrowRight")
                    go(idx + 1);
                else if (k === "ArrowLeft")
                    go(idx - 1);
                else if (k === "Home")
                    go(0);
                else if (k === "End")
                    go(items.length - 1);
                else
                    return; e.preventDefault(); } }, items.map((t) => (React.createElement("button", { key: t.value, ref: (el) => (refs.current[t.value] = el), type: "button", role: "tab", className: "hmt-tab", id: `${id}-${t.value}`, "aria-selected": t.value === value, "aria-controls": `${id}-p`, tabIndex: t.value === value ? 0 : -1, onClick: () => onChange(t.value) },
                t.label,
                t.count != null ? React.createElement(Badge, { tone: "neutral", icon: false },
                    React.createElement("span", { className: "hmt-tabular" }, t.count)) : null)))),
            React.createElement("div", { role: "tabpanel", id: `${id}-p`, "aria-labelledby": `${id}-${value}`, tabIndex: 0, className: "hmt-tabpanel" }, children)));
    }
    function Breadcrumb({ items, compact }) {
        if (compact && items.length > 1) {
            const parent = items[items.length - 2];
            return React.createElement("nav", { className: "hmt-crumbs", "aria-label": "V\u1ECB tr\u00ED" },
                React.createElement("ol", null,
                    React.createElement("li", null,
                        React.createElement("a", { href: parent.href || "#", onClick: (e) => { e.preventDefault(); parent.onClick && parent.onClick(); } },
                            React.createElement(Icon, { name: "chevronLeft" }),
                            " ",
                            parent.label))));
        }
        return (React.createElement("nav", { className: "hmt-crumbs", "aria-label": "V\u1ECB tr\u00ED" },
            React.createElement("ol", null, items.map((it, i) => (React.createElement("li", { key: i, style: { display: "inline-flex", alignItems: "center", gap: 4 } }, i < items.length - 1 ? React.createElement(Fragment, null,
                React.createElement("a", { href: it.href || "#", onClick: (e) => { e.preventDefault(); it.onClick && it.onClick(); } }, it.label),
                React.createElement(Icon, { name: "chevronRight" }))
                : React.createElement("span", { "aria-current": "page" }, it.label)))))));
    }
    function BottomNav({ items, activeId, onNavigate }) {
        return (React.createElement("nav", { className: "hmt-bottomnav", "aria-label": "\u0110i\u1EC1u h\u01B0\u1EDBng ch\u00EDnh" }, items.map((it) => (React.createElement("a", { key: it.id, href: "#", className: "hmt-focus", "aria-current": it.id === activeId ? "page" : undefined, onClick: (e) => { e.preventDefault(); onNavigate(it.id); } },
            React.createElement("span", { className: "hmt-bn-pill" },
                React.createElement(Icon, { name: it.icon })),
            it.label,
            React.createElement(CountBadge, { count: it.badge, label: it.badge ? `${it.badge} mục cần xử lý` : undefined }))))));
    }
    /* ---------------- Feedback ---------------- */
    function Alert({ tone = "info", title, children, actions, onDismiss, live }) {
        return (React.createElement("div", { className: cx("hmt-alert", `hmt-alert--${tone}`), role: live ? (tone === "danger" ? "alert" : "status") : undefined },
            React.createElement(Icon, { name: TONE_ICON[tone] }),
            React.createElement("div", { style: { flex: 1 } },
                title ? React.createElement("p", { className: "hmt-alert-title" }, title) : null,
                children ? React.createElement("div", { className: "hmt-alert-body" }, children) : null,
                actions ? React.createElement("div", { className: "hmt-alert-actions" }, actions) : null),
            onDismiss ? React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "x", label: "\u0110\u00F3ng th\u00F4ng b\u00E1o", onClick: onDismiss }) : null));
    }
    const ToastCtx = createContext(null);
    function ToastProvider({ children, placement = "bottom-right" }) {
        const [list, setList] = useState([]);
        const dismiss = useCallback((id) => setList((l) => l.filter((t) => t.id !== id)), []);
        const push = useCallback((t) => { const id = Math.random().toString(36).slice(2); setList((l) => [...l.slice(-2), { tone: "success", ...t, id }]); return id; }, []);
        return (React.createElement(ToastCtx.Provider, { value: { push, dismiss } },
            children,
            React.createElement("div", { className: cx("hmt-toasts", placement === "bottom" && "hmt-toasts--bottom"), role: "region", "aria-label": "Th\u00F4ng b\u00E1o" },
                React.createElement("div", { "aria-live": "polite", style: { display: "contents" } }, list.filter((t) => t.tone !== "danger").map((t) => React.createElement(ToastItem, { key: t.id, t: t, onDone: () => dismiss(t.id) }))),
                React.createElement("div", { "aria-live": "assertive", style: { display: "contents" } }, list.filter((t) => t.tone === "danger").map((t) => React.createElement(ToastItem, { key: t.id, t: t, onDone: () => dismiss(t.id) }))))));
    }
    function ToastItem({ t, onDone }) {
        const [paused, setPaused] = useState(false);
        const dur = t.duration || (t.action ? 8000 : 5000);
        useEffect(() => { if (paused || t.tone === "danger")
            return; const h = setTimeout(onDone, dur); return () => clearTimeout(h); }, [paused]);
        return (React.createElement("div", { className: "hmt-toast hmt-root", onMouseEnter: () => setPaused(true), onMouseLeave: () => setPaused(false), onFocus: () => setPaused(true), onBlur: () => setPaused(false) },
            React.createElement("span", { className: `hmt-toast-ico--${t.tone}` },
                React.createElement(Icon, { name: TONE_ICON[t.tone] })),
            React.createElement("span", { className: "hmt-toast-msg" }, t.message),
            t.action ? React.createElement("button", { type: "button", className: "hmt-toast-act hmt-focus", onClick: () => { t.action.onClick(); onDone(); } }, t.action.label) : null,
            React.createElement("button", { type: "button", className: "hmt-toast-x hmt-focus", "aria-label": "\u0110\u00F3ng", onClick: onDone },
                React.createElement(Icon, { name: "x" }))));
    }
    function useToast() { return useContext(ToastCtx) || { push: () => { }, dismiss: () => { } }; }
    const STATE = {
        empty: { icon: "inbox" }, "no-results": { icon: "search" }, error: { icon: "xcircle" }, offline: { icon: "wifiOff" }, "no-access": { icon: "alert" },
    };
    function StateView({ kind = "empty", title, description, actions, compact }) {
        return (React.createElement("div", { className: cx("hmt-state", `hmt-state--${kind}`), role: kind === "error" ? "alert" : undefined, style: compact ? { padding: 16 } : undefined },
            React.createElement("span", { className: "hmt-state-ico" },
                React.createElement(Icon, { name: STATE[kind].icon })),
            React.createElement("p", { className: "hmt-state-title" }, title),
            description ? React.createElement("p", { className: "hmt-state-desc" }, description) : null,
            actions ? React.createElement("div", { className: "hmt-state-actions" }, actions) : null));
    }
    function Skeleton({ width = "100%", height = 14, radius, style }) {
        return React.createElement("span", { className: "hmt-skel", "aria-hidden": "true", style: { width, height, borderRadius: radius, ...style } });
    }
    function Spinner({ label = "Đang tải…" }) {
        return React.createElement("span", { role: "status", style: { display: "inline-flex", alignItems: "center", gap: 8, color: "var(--hmt-fg-muted)" } },
            React.createElement("span", { className: "hmt-spinner", "aria-hidden": "true" }),
            React.createElement("span", null, label));
    }
    /* ---------------- Domain: class, student, attendance, progress ---------------- */
    /* colored: lựa chọn đã chọn tô theo option.tone + option.emphasis ('subtle' | 'solid') — R-DD-01 màu điểm danh */
    function SegmentedControl({ name, options, value, onChange, label, colored, layout = "stack", disabled }) {
        return (React.createElement("fieldset", { className: cx("hmt-seg", layout === "row" && "hmt-seg--row"), "data-colored": colored ? "true" : undefined, disabled: disabled },
            React.createElement("legend", { className: "hmt-sr" }, label),
            options.map((o) => (React.createElement("label", { key: o.value, className: "hmt-seg-opt", "data-tone": o.tone, "data-emphasis": o.emphasis || "subtle" },
                React.createElement("input", { type: "radio", name: name, value: o.value, checked: value === o.value, onChange: () => onChange(o.value) }),
                o.icon ? React.createElement(Icon, { name: o.icon }) : null,
                React.createElement("span", null, o.short || o.label))))));
    }
    function PersonLine({ name, meta, avatar, size = "md" }) {
        return (React.createElement("div", { className: "hmt-person" },
            React.createElement(Avatar, { name: name, src: avatar, size: size, decorative: true }),
            React.createElement("div", { className: "hmt-person-text" },
                React.createElement("p", { className: "hmt-person-name" }, name),
                meta ? React.createElement("p", { className: "hmt-person-meta" }, meta) : null)));
    }
    function StudentListItem({ name, meta, avatar, trailing, onClick }) {
        const inner = React.createElement(Fragment, null,
            React.createElement(PersonLine, { name: name, meta: meta, avatar: avatar }),
            trailing ? React.createElement("div", { style: { marginLeft: "auto", display: "flex", gap: 8, alignItems: "center" } }, trailing) : null);
        return onClick ? React.createElement("button", { type: "button", className: "hmt-listitem hmt-focus", style: { all: "unset", boxSizing: "border-box", display: "flex", width: "100%", cursor: "pointer" }, onClick: onClick },
            React.createElement("div", { className: "hmt-listitem", style: { width: "100%" } }, inner))
            : React.createElement("div", { className: "hmt-listitem" }, inner);
    }
    function ClassCard({ name, campus, schedule, teacher, enrolled, capacity, status, href, footer }) {
        const full = capacity && enrolled >= capacity;
        const Tag = href ? "a" : "div";
        return (React.createElement(Tag, { className: "hmt-classcard", href: href, onClick: href ? (e) => e.preventDefault() : undefined },
            React.createElement("div", { className: "hmt-classcard-top" },
                React.createElement("p", { className: "hmt-classcard-name" }, name),
                status),
            React.createElement("dl", { className: "hmt-classcard-meta" },
                campus ? React.createElement(Fragment, null,
                    React.createElement("dt", null,
                        React.createElement(Icon, { name: "mapPin" }),
                        "C\u01A1 s\u1EDF"),
                    React.createElement("dd", null, campus)) : null,
                schedule ? React.createElement(Fragment, null,
                    React.createElement("dt", null,
                        React.createElement(Icon, { name: "clock" }),
                        "L\u1ECBch"),
                    React.createElement("dd", null, schedule)) : null,
                teacher ? React.createElement(Fragment, null,
                    React.createElement("dt", null,
                        React.createElement(Icon, { name: "users" }),
                        "Gi\u00E1o vi\u00EAn"),
                    React.createElement("dd", null, teacher)) : null,
                capacity ? React.createElement(Fragment, null,
                    React.createElement("dt", null,
                        React.createElement(Icon, { name: "clipboard" }),
                        "S\u0129 s\u1ED1"),
                    React.createElement("dd", { className: "hmt-tabular" },
                        enrolled,
                        "/",
                        capacity,
                        full ? React.createElement(Fragment, null,
                            " \u00B7 ",
                            React.createElement(Badge, { tone: "warning" }, "\u0110\u00E3 \u0111\u1EE7")) : null)) : null),
            footer));
    }
    function ProgressBar({ value, max = 100, label, valueText, variant = "default", size }) {
        const pct = Math.max(0, Math.min(100, (value / max) * 100));
        const id = useId();
        return (React.createElement("div", { className: cx("hmt-progress", variant === "lms" && "hmt-progress--lms", size === "lg" && "hmt-progress--lg") },
            label ? React.createElement("div", { className: "hmt-progress-top" },
                React.createElement("span", { id: id }, label),
                React.createElement("span", { className: "hmt-tabular", style: { fontWeight: 600 } }, valueText || `${Math.round(pct)}%`)) : null,
            React.createElement("div", { className: "hmt-progress-track", role: "progressbar", "aria-labelledby": label ? id : undefined, "aria-valuenow": value, "aria-valuemin": 0, "aria-valuemax": max, "aria-valuetext": valueText },
                React.createElement("div", { className: "hmt-progress-fill", style: { width: `${pct}%` } }))));
    }
    /* ======================= Điểm danh (R-DD-01/02/03) ======================= */
    const ATT_STATUSES = [
        { value: "present", label: "Có mặt", short: "Có mặt", icon: "check", tone: "success", emphasis: "subtle" },
        { value: "late", label: "Đi muộn", short: "Đi muộn", icon: "clock", tone: "warning", emphasis: "subtle" },
        { value: "excused", label: "Vắng có phép", short: "Vắng có phép", icon: "fileCheck", tone: "danger", emphasis: "solid" },
        { value: "absent", label: "Vắng không phép", short: "Vắng không phép", icon: "userX", tone: "danger", emphasis: "solid" },
    ];
    const CONTACT_REASONS = ["Không nghe máy", "Đã nhắc vào lớp", "Đã vào lớp", "Xin nghỉ học", "Khác"]; // danh mục 17, cấu hình được (QT-07)
    function SaveState({ state }) {
        if (!state)
            return null;
        const M = { saving: ["timer", "Đang lưu…", "var(--hmt-fg-muted)"], saved: ["check", "Đã lưu", "var(--hmt-success)"], error: ["alert", "Chưa lưu được", "var(--hmt-danger)"] };
        const [ic, t, c] = M[state];
        return React.createElement("span", { className: "hmt-savestate", role: "status", style: { color: c } },
            React.createElement(Icon, { name: ic }),
            " ",
            t);
    }
    function attLabel(v) { const s = ATT_STATUSES.find((x) => x.value === v); return s ? s.label : "Chưa điểm danh"; }
    function AttBadge({ value }) {
        const s = ATT_STATUSES.find((x) => x.value === value);
        if (!s)
            return React.createElement("span", { className: "hmt-badge hmt-badge--neutral hmt-att-empty" }, "\u2014 Ch\u01B0a \u0111i\u1EC3m danh");
        return React.createElement("span", { className: cx("hmt-badge", `hmt-badge--${s.tone}`, s.emphasis === "solid" && "hmt-badge--solid") },
            React.createElement(Icon, { name: s.icon }),
            s.label);
    }
    /* mode: "teacher" (chính thức) · "ops" (vận hành ghi kèm lý do liên hệ) · "compare" (xem hai cột, chỉ đọc) */
    function AttendanceSheet({ className: klass, session, students, mode = "teacher", initial = {}, opsMarks = {}, onChange, onRequestNext, failNext = false }) {
        const toast = useToast();
        const [marks, setMarks] = useState(() => { const v = {}; students.forEach((s) => (v[s.id] = initial[s.id] || null)); return v; });
        const [reasons, setReasons] = useState(() => { const v = {}; students.forEach((s) => (v[s.id] = (opsMarks[s.id] && opsMarks[s.id].reason) || "")); return v; });
        const [save, setSave] = useState(null);
        const [blocked, setBlocked] = useState(false);
        const listRef = useRef(null);
        const tick = useRef(0);
        const unmarked = students.filter((s) => !marks[s.id]);
        const counts = ATT_STATUSES.map((st) => ({ ...st, n: students.filter((s) => marks[s.id] === st.value).length }));
        const persist = (next) => {
            const t = ++tick.current;
            setSave("saving");
            setTimeout(() => { if (t !== tick.current)
                return; const fail = failNext && Object.values(next).filter(Boolean).length === 3; setSave(fail ? "error" : "saved"); }, 600);
            onChange && onChange(next);
        };
        const set = (id, v) => setMarks((m) => { const n = { ...m, [id]: v }; persist(n); return n; });
        const markRest = () => {
            const prev = marks;
            const n = { ...marks };
            unmarked.forEach((s) => (n[s.id] = "present"));
            setMarks(n);
            persist(n);
            toast.push({ tone: "info", message: `Đã đánh dấu ${unmarked.length} em còn lại là Có mặt`, action: { label: "Hoàn tác", onClick: () => { setMarks(prev); persist(prev); } } });
        };
        const focusStudent = (id) => { const el = listRef.current && listRef.current.querySelector(`[data-sid="${id}"]`); if (el) {
            el.scrollIntoView({ block: "center", behavior: "smooth" });
            const r = el.querySelector("input,select");
            r && r.focus({ preventScroll: true });
        } };
        const next = () => { if (unmarked.length) {
            setBlocked(true);
            return;
        } onRequestNext && onRequestNext(marks); };
        if (mode === "compare") {
            return (React.createElement("section", { className: cx("hmt-att hmt-att--compare", klass), "aria-label": `Điểm danh ${session.className}` },
                React.createElement("div", { className: "hmt-table-wrap" },
                    React.createElement("table", { className: "hmt-table" },
                        React.createElement("caption", { className: "hmt-sr" }, "\u0110i\u1EC3m danh v\u1EADn h\u00E0nh v\u00E0 gi\u00E1o vi\u00EAn"),
                        React.createElement("thead", null,
                            React.createElement("tr", null,
                                React.createElement("th", { scope: "col" }, "H\u1ECDc sinh"),
                                React.createElement("th", { scope: "col" },
                                    "V\u1EADn h\u00E0nh ",
                                    React.createElement("span", { className: "hmt-th-note" }, "(ch\u1EC9 \u0111\u1ECDc)")),
                                React.createElement("th", { scope: "col" }, "L\u00FD do li\u00EAn h\u1EC7"),
                                React.createElement("th", { scope: "col" },
                                    "Gi\u00E1o vi\u00EAn ",
                                    React.createElement("span", { className: "hmt-th-note" }, "(ch\u00EDnh th\u1EE9c)")))),
                        React.createElement("tbody", null, students.map((s) => {
                            const o = opsMarks[s.id] || {};
                            const diff = o.status && initial[s.id] && o.status !== initial[s.id];
                            return (React.createElement("tr", { key: s.id },
                                React.createElement("td", null,
                                    React.createElement(PersonLine, { name: s.name, meta: s.code, size: "sm" })),
                                React.createElement("td", null, o.status ? React.createElement(AttBadge, { value: o.status }) : React.createElement("span", { className: "hmt-help" }, "\u2014")),
                                React.createElement("td", null, o.reason || React.createElement("span", { className: "hmt-help" }, "\u2014")),
                                React.createElement("td", null,
                                    React.createElement("span", { style: { display: "inline-flex", gap: 8, alignItems: "center" } },
                                        React.createElement(AttBadge, { value: initial[s.id] }),
                                        diff ? React.createElement("span", { className: "hmt-diff" }, "Kh\u00E1c v\u1EADn h\u00E0nh") : null))));
                        }))))));
        }
        return (React.createElement("section", { className: cx("hmt-att", klass), "aria-label": `Điểm danh ${session.className}` },
            React.createElement("div", { className: "hmt-att-head" },
                React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8, justifyContent: "space-between" } },
                    React.createElement("h3", null, session.className),
                    React.createElement(SaveState, { state: save })),
                React.createElement("span", { className: "hmt-person-meta" },
                    session.label,
                    " \u00B7 ",
                    session.time,
                    " \u00B7 ",
                    session.campus,
                    " \u00B7 ",
                    students.length,
                    " em"),
                mode === "ops" ? React.createElement("span", { className: "hmt-help" }, "V\u1EADn h\u00E0nh ghi ri\u00EAng k\u00E8m l\u00FD do li\u00EAn h\u1EC7. \u00D4 c\u1EE7a gi\u00E1o vi\u00EAn m\u1EDBi l\u00E0 tr\u1EA1ng th\u00E1i ch\u00EDnh th\u1EE9c.") : null,
                unmarked.length > 0 ? React.createElement("div", null,
                    React.createElement(Button, { variant: "secondary", size: "sm", iconStart: "check", onClick: markRest },
                        "C\u00F2n l\u1EA1i: C\u00F3 m\u1EB7t (",
                        unmarked.length,
                        ")")) : null),
            React.createElement("div", { className: "hmt-att-colhead", "aria-hidden": "true" },
                React.createElement("span", null, "H\u1ECDc sinh"),
                React.createElement("span", null, "Ghi ch\u00FA"),
                React.createElement("span", null, "\u0110i\u1EC3m danh"),
                mode === "ops" ? React.createElement("span", null, "L\u00FD do li\u00EAn h\u1EC7") : null),
            React.createElement("ul", { className: "hmt-att-list", ref: listRef, "data-mode": mode }, students.map((s) => (React.createElement("li", { key: s.id, className: "hmt-att-item", "data-sid": s.id, "data-unmarked": !marks[s.id] ? "true" : undefined },
                React.createElement(PersonLine, { name: s.name, meta: s.meta, avatar: s.avatar }),
                !marks[s.id] || s.note ? React.createElement("div", { className: "hmt-att-info" },
                    !marks[s.id] ? React.createElement("span", { className: "hmt-att-flag" },
                        React.createElement(Icon, { name: "alert" }),
                        " Ch\u01B0a \u0111i\u1EC3m danh") : null,
                    s.note ? React.createElement("span", { className: "hmt-att-note" },
                        "Ghi ch\u00FA: ",
                        s.note) : null) : React.createElement("div", { className: "hmt-att-info" }),
                React.createElement(SegmentedControl, { name: `att-${mode}-${s.id}`, label: `Điểm danh ${s.name}`, options: ATT_STATUSES, value: marks[s.id], onChange: (v) => set(s.id, v), colored: true, layout: "row" }),
                mode === "ops" ? (React.createElement(Field, { label: "L\u00FD do li\u00EAn h\u1EC7", optional: true },
                    React.createElement(Select, { value: reasons[s.id], onChange: (e) => { setReasons({ ...reasons, [s.id]: e.target.value }); persist(marks); }, placeholder: "Ch\u1ECDn l\u00FD do li\u00EAn h\u1EC7", options: CONTACT_REASONS.map((r) => ({ value: r, label: r })) }))) : null)))),
            React.createElement("div", { className: "hmt-att-foot" },
                React.createElement("div", { className: "hmt-att-sum", "aria-live": "polite" },
                    counts.map((c) => React.createElement("span", { key: c.value },
                        React.createElement("b", null, c.n),
                        " ",
                        c.label.toLowerCase())),
                    unmarked.length ? React.createElement("span", { style: { color: "var(--hmt-warning)" } },
                        React.createElement("b", null, unmarked.length),
                        " ch\u01B0a \u0111i\u1EC3m danh") : null),
                save === "error" ? React.createElement(Alert, { tone: "danger", title: "Ch\u01B0a l\u01B0u \u0111\u01B0\u1EE3c \u0111i\u1EC3m danh", actions: React.createElement(Button, { variant: "tertiary", size: "sm", onClick: () => persist(marks) }, "Th\u1EED l\u1EA1i") }, "D\u1EEF li\u1EC7u v\u1EABn n\u1EB1m tr\u00EAn m\u00E1y n\u00E0y. Ki\u1EC3m tra k\u1EBFt n\u1ED1i r\u1ED3i th\u1EED l\u1EA1i.") : null,
                onRequestNext ? React.createElement(Button, { fullWidth: true, iconEnd: "arrowRight", onClick: next }, "Ti\u1EBFp: N\u1ED9i dung bu\u1ED5i") : null),
            React.createElement(BlockingDialog, { open: blocked, onClose: () => setBlocked(false), title: "Ch\u01B0a th\u1EC3 sang b\u01B0\u1EDBc ti\u1EBFp", description: "M\u1ED7i em c\u00F3 t\u00EAn trong danh s\u00E1ch c\u1EA7n m\u1ED9t tr\u1EA1ng th\u00E1i \u0111i\u1EC3m danh.", reasons: unmarked.map((s) => ({ text: `${s.name} chưa điểm danh`, actionLabel: "Đến em này", onAction: () => { setBlocked(false); setTimeout(() => focusStudent(s.id), 50); } })) })));
    }
    /* ======================= BlockingDialog ======================= */
    /* kind "block": lỗi chặn — chỉ đóng, mỗi lý do có nút đến chỗ sửa · kind "warn": cảnh báo — vẫn làm tiếp được */
    function BlockingDialog({ open, onClose, kind = "block", title, description, reasons = [], continueLabel = "Vẫn tiếp tục", onContinue }) {
        return (React.createElement(Dialog, { open: open, onClose: onClose, title: title, description: description, tone: kind === "block" ? "danger" : "warning", role: "alertdialog", footer: kind === "block"
                ? React.createElement(Button, { variant: "secondary", onClick: onClose, "data-cancel": "" }, "\u0110\u00F3ng")
                : React.createElement(Fragment, null,
                    React.createElement(Button, { variant: "secondary", onClick: onClose, "data-cancel": "" }, "Quay l\u1EA1i"),
                    React.createElement(Button, { onClick: () => { onContinue && onContinue(); onClose(); } }, continueLabel)) },
            React.createElement("p", { className: "hmt-block-kind" }, kind === "block" ? React.createElement(Fragment, null,
                React.createElement(Icon, { name: "ban" }),
                " L\u1ED7i ch\u1EB7n \u2014 c\u1EA7n s\u1EEDa tr\u01B0\u1EDBc khi ti\u1EBFp t\u1EE5c") : React.createElement(Fragment, null,
                React.createElement(Icon, { name: "alert" }),
                " C\u1EA3nh b\u00E1o \u2014 v\u1EABn c\u00F3 th\u1EC3 ti\u1EBFp t\u1EE5c")),
            React.createElement("ul", { className: "hmt-block-list" }, reasons.map((r, i) => (React.createElement("li", { key: i },
                React.createElement("span", { className: "hmt-block-ico" },
                    React.createElement(Icon, { name: kind === "block" ? "xcircle" : "alert" })),
                React.createElement("span", { style: { flex: 1 } },
                    r.text,
                    r.detail ? React.createElement("span", { className: "hmt-person-meta", style: { display: "block" } }, r.detail) : null),
                r.actionLabel ? React.createElement(Button, { variant: "tertiary", size: "sm", iconEnd: "arrowRight", onClick: r.onAction }, r.actionLabel) : null))))));
    }
    /* ======================= StatusBar ======================= */
    function StatusBar({ steps, current, terminal, substatus, forwardOnly, locked, actions, onStepClick, label = "Trạng thái" }) {
        const wrap = useRef(null);
        const narrow = useNarrow(wrap, 640);
        const [open, setOpen] = useState(false);
        const idx = steps.findIndex((s) => s.id === current);
        const cur = steps[idx];
        const canClick = (i) => onStepClick && !terminal && !locked && (forwardOnly ? i > idx : i !== idx);
        const stepList = (vertical) => (React.createElement("ol", { className: cx("hmt-sb-steps", vertical && "hmt-sb-steps--v"), "aria-label": label }, steps.map((s, i) => {
            const st = terminal ? (i <= idx ? "done" : "todo") : i < idx ? "done" : i === idx ? "current" : "todo";
            const abbr = !vertical && steps.length > 5 && st !== "current" && s.short;
            const inner = React.createElement(Fragment, null,
                React.createElement("span", { className: "hmt-sb-dot", "aria-hidden": "true" }, st === "done" ? React.createElement(Icon, { name: "check" }) : i + 1),
                React.createElement("span", { className: "hmt-sb-label", title: abbr ? s.label : undefined }, abbr ? React.createElement(Fragment, null,
                    React.createElement("span", { "aria-hidden": "true" }, s.short),
                    React.createElement("span", { className: "hmt-sr" }, s.label)) : s.label));
            return (React.createElement("li", { key: s.id, className: "hmt-sb-step", "data-state": st, "aria-current": st === "current" ? "step" : undefined },
                canClick(i) ? React.createElement("button", { type: "button", className: "hmt-sb-btn hmt-focus", onClick: () => { setOpen(false); onStepClick(s.id); } }, inner) : React.createElement("span", { className: "hmt-sb-btn", "aria-disabled": !canClick(i) && st !== "current" ? true : undefined }, inner),
                React.createElement("span", { className: "hmt-sr" }, st === "done" ? " (đã qua)" : st === "current" ? " (hiện tại)" : "")));
        })));
        return (React.createElement("div", { className: "hmt-sb", ref: wrap },
            actions ? React.createElement("div", { className: "hmt-sb-actions" }, actions) : null,
            narrow ? (React.createElement("div", { className: "hmt-sb-compact" },
                React.createElement("span", { className: "hmt-sb-cur" },
                    React.createElement("span", { className: "hmt-person-meta" },
                        "B\u01B0\u1EDBc ",
                        idx + 1,
                        "/",
                        steps.length),
                    React.createElement("b", null, cur && cur.label),
                    substatus ? React.createElement("span", { className: "hmt-person-meta" }, substatus) : null),
                React.createElement(Button, { variant: "secondary", size: "sm", onClick: () => setOpen(true) }, "C\u00E1c b\u01B0\u1EDBc"),
                React.createElement(Drawer, { open: open, onClose: () => setOpen(false), placement: "bottom", title: "C\u00E1c b\u01B0\u1EDBc" },
                    stepList(true),
                    forwardOnly ? React.createElement("p", { className: "hmt-help" }, "Ch\u1EC9 \u0111i t\u1EDBi, kh\u00F4ng l\u00F9i b\u01B0\u1EDBc.") : null))) : (React.createElement("div", { className: "hmt-sb-main" },
                stepList(),
                substatus ? React.createElement("span", { className: "hmt-sb-sub" },
                    React.createElement(Icon, { name: "layers" }),
                    " ",
                    substatus) : null)),
            React.createElement("div", { className: "hmt-sb-flags" },
                terminal ? React.createElement(Badge, { tone: terminal.tone || "danger", solid: true, icon: terminal.icon || "ban" }, terminal.label) : null,
                locked ? React.createElement("span", { className: "hmt-sb-lock" },
                    React.createElement(Icon, { name: "lock" }),
                    " \u0110\u00E3 kho\u00E1") : null,
                forwardOnly && !narrow ? React.createElement("span", { className: "hmt-help" }, "Ch\u1EC9 \u0111i t\u1EDBi") : null)));
    }
    /* ======================= SmartButton ======================= */
    function SmartButton({ icon, label, count, onClick }) {
        return (React.createElement("button", { type: "button", className: "hmt-smart hmt-focus", onClick: onClick, "aria-label": `${label}: ${count}` },
            React.createElement(Icon, { name: icon }),
            React.createElement("span", { className: "hmt-smart-text" },
                React.createElement("span", { className: "hmt-smart-count hmt-tabular" }, count),
                React.createElement("span", { className: "hmt-smart-label" }, label))));
    }
    function SmartButtonGroup({ items, max = 4 }) {
        const shown = items.slice(0, items.length > max ? max - 1 : max);
        const rest = items.slice(shown.length);
        return (React.createElement("div", { className: "hmt-smarts", role: "group", "aria-label": "Li\u00EAn k\u1EBFt c\u1EE7a b\u1EA3n ghi" },
            shown.map((it) => React.createElement(SmartButton, { key: it.label, ...it })),
            rest.length ? React.createElement(Popover, { label: "Li\u00EAn k\u1EBFt kh\u00E1c", placement: "bottom-end", trigger: React.createElement("button", { type: "button", className: "hmt-smart hmt-focus" },
                    React.createElement(Icon, { name: "more" }),
                    React.createElement("span", { className: "hmt-smart-text" },
                        React.createElement("span", { className: "hmt-smart-count hmt-tabular" }, rest.length),
                        React.createElement("span", { className: "hmt-smart-label" }, "Th\u00EAm"))) }, (close) => React.createElement("ul", { className: "hmt-menu", style: { margin: -12 } }, rest.map((it) => React.createElement("li", { key: it.label },
                React.createElement("button", { onClick: () => { close(); it.onClick && it.onClick(); } },
                    React.createElement(Icon, { name: it.icon }),
                    it.label,
                    React.createElement("span", { className: "hmt-tabular", style: { marginLeft: "auto", fontWeight: 600 } }, it.count)))))) : null));
    }
    /* ======================= Chatter ======================= */
    function fmtTime(d) { return d; }
    function Chatter({ entries: initialEntries, people = [], me = "Bạn", onPost }) {
        const [entries, setEntries] = useState(initialEntries);
        const [filter, setFilter] = useState("all");
        const [text, setText] = useState("");
        const [files, setFiles] = useState([]);
        const [mention, setMention] = useState(null);
        const [mi, setMi] = useState(0);
        const taRef = useRef(null);
        const list = entries.filter((e) => filter === "all" || (filter === "notes" ? e.type === "note" : e.type !== "note"));
        const onType = (e) => {
            const v = e.target.value;
            setText(v);
            const m = /@([\p{L}\s]{0,20})$/u.exec(v.slice(0, e.target.selectionStart));
            setMention(m ? m[1].toLowerCase() : null);
            setMi(0);
        };
        const matches = mention == null ? [] : people.filter((p) => p.name.toLowerCase().includes(mention.trim())).slice(0, 5);
        const pick = (p) => { const v = text.replace(/@[\p{L}\s]{0,20}$/u, `@${p.name} `); setText(v); setMention(null); taRef.current.focus(); };
        const post = () => {
            if (!text.trim() && !files.length)
                return;
            const e = { id: Date.now(), type: "note", author: me, at: "Vừa xong", text: text.trim(), files };
            setEntries([e, ...entries]);
            setText("");
            setFiles([]);
            onPost && onPost(e);
        };
        const renderText = (t) => t.split(/(@[\p{L}]+(?:\s[\p{L}]+){0,3})/u).map((part, i) => part.startsWith("@") && people.some((p) => part.startsWith("@" + p.name)) ? React.createElement("span", { key: i, className: "hmt-mention" }, part) : part);
        return (React.createElement("section", { className: "hmt-chatter", "aria-label": "Ghi ch\u00FA trao \u0111\u1ED5i v\u00E0 l\u1ECBch s\u1EED thay \u0111\u1ED5i" },
            React.createElement("div", { className: "hmt-chatter-compose" },
                React.createElement("label", { className: "hmt-sr", htmlFor: "chatter-ta" }, "Ghi ch\u00FA trao \u0111\u1ED5i"),
                React.createElement("div", { className: "hmt-control hmt-control--area", style: { position: "relative" } },
                    React.createElement("textarea", { id: "chatter-ta", ref: taRef, value: text, onChange: onType, placeholder: "Ghi ch\u00FA\u2026 g\u00F5 @ \u0111\u1EC3 nh\u1EAFc \u0111\u1ED3ng nghi\u1EC7p", rows: 2, "aria-autocomplete": "list", "aria-expanded": matches.length > 0, "aria-controls": "chatter-mention", onKeyDown: (e) => {
                            if (matches.length) {
                                if (e.key === "ArrowDown") {
                                    setMi((mi + 1) % matches.length);
                                    e.preventDefault();
                                }
                                else if (e.key === "ArrowUp") {
                                    setMi((mi - 1 + matches.length) % matches.length);
                                    e.preventDefault();
                                }
                                else if (e.key === "Enter") {
                                    pick(matches[mi]);
                                    e.preventDefault();
                                }
                                else if (e.key === "Escape") {
                                    setMention(null);
                                    e.stopPropagation();
                                }
                            }
                            else if (e.key === "Enter" && (e.ctrlKey || e.metaKey))
                                post();
                        } }),
                    matches.length ? React.createElement("ul", { id: "chatter-mention", role: "listbox", className: "hmt-pop hmt-mention-list", style: { position: "absolute", top: "100%", left: 0 } }, matches.map((p, i) => React.createElement("li", { key: p.name, role: "option", "aria-selected": i === mi, onMouseDown: (e) => { e.preventDefault(); pick(p); } },
                        React.createElement(Avatar, { name: p.name, size: "sm", decorative: true }),
                        " ",
                        p.name,
                        React.createElement("span", { className: "hmt-person-meta" }, p.role)))) : null),
                files.length ? React.createElement("div", { className: "hmt-demo-row" }, files.map((f) => React.createElement("span", { key: f, className: "hmt-badge hmt-badge--neutral" },
                    React.createElement(Icon, { name: "paperclip" }),
                    f))) : null,
                React.createElement("div", { className: "hmt-chatter-bar" },
                    React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "at", label: "Nh\u1EAFc t\u00EAn", onClick: () => { setText(text + "@"); setMention(""); taRef.current.focus(); } }),
                    React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "paperclip", label: "\u0110\u00EDnh k\u00E8m", onClick: () => setFiles([...files, `anh-chup-${files.length + 1}.jpg`]) }),
                    React.createElement("span", { style: { flex: 1 } }),
                    React.createElement(Button, { size: "sm", iconStart: "send", onClick: post }, "G\u1EEDi ghi ch\u00FA"))),
            React.createElement(SegmentedControl, { name: "chatter-f", layout: "row", label: "L\u1ECDc d\u00F2ng th\u1EDDi gian", value: filter, onChange: setFilter, options: [{ value: "all", label: "Tất cả" }, { value: "notes", label: "Ghi chú", icon: "message" }, { value: "history", label: "Lịch sử", icon: "history" }] }),
            React.createElement("ol", { className: "hmt-timeline" },
                list.map((e) => (React.createElement("li", { key: e.id, className: "hmt-tl-item", "data-type": e.type },
                    React.createElement("span", { className: "hmt-tl-ico", "aria-hidden": "true" },
                        React.createElement(Icon, { name: e.type === "note" ? "message" : e.type === "system" ? "settings" : "history" })),
                    React.createElement("div", { className: "hmt-tl-body" },
                        React.createElement("p", { className: "hmt-tl-head" },
                            React.createElement("b", null, e.author),
                            " ",
                            React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } },
                                "\u00B7 ",
                                fmtTime(e.at))),
                        e.type === "note" ? React.createElement("p", { className: "hmt-tl-text" }, renderText(e.text)) : null,
                        e.changes ? React.createElement("ul", { className: "hmt-tl-changes" }, e.changes.map((c, i) => React.createElement("li", { key: i },
                            React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } },
                                c.field,
                                ":"),
                            " ",
                            React.createElement("s", { className: "hmt-tl-from" }, c.from || "trống"),
                            " ",
                            React.createElement(Icon, { name: "arrowRight" }),
                            " ",
                            React.createElement("b", null, c.to)))) : null,
                        e.text && e.type !== "note" ? React.createElement("p", { className: "hmt-tl-text" }, e.text) : null,
                        e.files && e.files.length ? React.createElement("div", { className: "hmt-demo-row" }, e.files.map((f) => React.createElement("span", { key: f, className: "hmt-badge hmt-badge--neutral" },
                            React.createElement(Icon, { name: "paperclip" }),
                            f))) : null)))),
                !list.length ? React.createElement("li", null,
                    React.createElement(StateView, { compact: true, kind: "empty", title: filter === "notes" ? "Chưa có ghi chú" : "Chưa có thay đổi" })) : null)));
    }
    /* ======================= BulkActionBar ======================= */
    function BulkActionBar({ count, children, onClear, label = "dòng" }) {
        return (React.createElement("div", { className: "hmt-bulk", role: "region", "aria-label": "Thao t\u00E1c h\u00E0ng lo\u1EA1t" },
            React.createElement("span", { "aria-live": "polite", className: "hmt-bulk-count" },
                React.createElement(Icon, { name: "check" }),
                " \u0110\u00E3 ch\u1ECDn ",
                React.createElement("b", { className: "hmt-tabular" }, count),
                " ",
                label),
            React.createElement("div", { className: "hmt-bulk-actions" }, children),
            React.createElement(Button, { variant: "tertiary", size: "sm", onClick: onClear }, "B\u1ECF ch\u1ECDn")));
    }
    /* ======================= FilterBar (R-CRM-07) ======================= */
    function FilterBar({ search, onSearch, searchPlaceholder = "Tìm theo tên, SĐT, mã mới, mã cũ", groups = [], value = {}, onChange, advancedCount = 0, onAdvanced, groupByOptions = [], groupBy, onGroupBy, favorites = [], onSaveFavorite, onApplyFavorite, columns = [], onColumnsChange, views = ["list"], view = "list", onViewChange, resultCount }) {
        const toggle = (g, id) => { const cur = value[g] || []; onChange({ ...value, [g]: cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id] }); };
        const active = groups.filter((g) => (value[g.id] || []).length);
        const [saveOpen, setSaveOpen] = useState(false);
        const [favName, setFavName] = useState("");
        const [favDefault, setFavDefault] = useState(false);
        const [favShared, setFavShared] = useState("me");
        const VIEW = { list: ["list", "Danh sách"], kanban: ["kanban", "Kanban"], calendar: ["calendar", "Lịch"] };
        return (React.createElement("div", { className: "hmt-fb" },
            React.createElement("div", { className: "hmt-fb-row" },
                React.createElement("div", { className: "hmt-fb-search" },
                    React.createElement(TextInput, { type: "search", leadingIcon: "search", "aria-label": "T\u00ECm ki\u1EBFm", value: search, onChange: (e) => onSearch(e.target.value), placeholder: searchPlaceholder })),
                React.createElement(Button, { variant: "secondary", iconStart: "filter", onClick: onAdvanced },
                    "L\u1ECDc n\u00E2ng cao",
                    advancedCount ? React.createElement("span", { className: "hmt-badge hmt-badge--count", "aria-label": `${advancedCount} điều kiện` }, advancedCount) : null),
                groupByOptions.length ? React.createElement(Popover, { label: "Nh\u00F3m theo", trigger: React.createElement(Button, { variant: "secondary", iconStart: "layers" }, groupBy ? `Nhóm: ${groupByOptions.find((o) => o.value === groupBy).label}` : "Nhóm theo") }, (close) => React.createElement("ul", { className: "hmt-menu", style: { margin: -12 } }, [{ value: "", label: "Không nhóm" }, ...groupByOptions].map((o) => React.createElement("li", { key: o.value },
                    React.createElement("button", { onClick: () => { onGroupBy(o.value); close(); } },
                        groupBy === o.value || (!groupBy && !o.value) ? React.createElement(Icon, { name: "check" }) : React.createElement("span", { style: { width: "1.15em" } }),
                        o.label))))) : null,
                React.createElement(Popover, { label: "B\u1ED9 l\u1ECDc y\u00EAu th\u00EDch", trigger: React.createElement(Button, { variant: "secondary", iconStart: "bookmark" }, "Y\u00EAu th\u00EDch") }, (close) => React.createElement("div", { style: { display: "grid", gap: 4, minWidth: 240, margin: -4 } },
                    React.createElement("ul", { className: "hmt-menu" }, favorites.map((f) => React.createElement("li", { key: f.name },
                        React.createElement("button", { onClick: () => { onApplyFavorite && onApplyFavorite(f); close(); } },
                            React.createElement(Icon, { name: "bookmark" }),
                            f.name,
                            f.isDefault ? React.createElement("span", { className: "hmt-badge hmt-badge--neutral", style: { marginLeft: "auto" } }, "M\u1EB7c \u0111\u1ECBnh") : null,
                            f.shared ? React.createElement("span", { className: "hmt-person-meta", style: { marginLeft: f.isDefault ? 4 : "auto" } }, "D\u00F9ng chung") : null)))),
                    React.createElement(Button, { variant: "tertiary", size: "sm", iconStart: "plus", onClick: () => { close(); setSaveOpen(true); } }, "L\u01B0u b\u1ED9 l\u1ECDc hi\u1EC7n t\u1EA1i\u2026"))),
                React.createElement("span", { style: { flex: 1 } }),
                columns.length ? React.createElement(Popover, { label: "Ch\u1ECDn c\u1ED9t", placement: "bottom-end", trigger: React.createElement(Button, { variant: "secondary", iconOnly: "columns", label: "Ch\u1ECDn c\u1ED9t" }) },
                    React.createElement("fieldset", { style: { border: 0, margin: 0, padding: 0, display: "grid", gap: 8 } },
                        React.createElement("legend", { className: "hmt-label", style: { marginBottom: 6 } }, "C\u1ED9t hi\u1EC3n th\u1ECB"),
                        columns.map((c) => React.createElement("label", { key: c.key, style: { display: "flex", gap: 8, alignItems: "center" } },
                            React.createElement("input", { type: "checkbox", className: "hmt-check", checked: c.visible, disabled: c.locked, onChange: () => onColumnsChange(columns.map((x) => x.key === c.key ? { ...x, visible: !x.visible } : x)) }),
                            c.label,
                            c.locked ? React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } }, "(lu\u00F4n hi\u1EC7n)") : null)))) : null,
                views.length > 1 ? React.createElement("div", { className: "hmt-fb-views", role: "radiogroup", "aria-label": "Ki\u1EC3u xem" }, views.map((v) => React.createElement("button", { key: v, type: "button", role: "radio", "aria-checked": view === v, className: "hmt-fb-view hmt-focus", onClick: () => onViewChange(v), title: VIEW[v][1] },
                    React.createElement(Icon, { name: VIEW[v][0] }),
                    React.createElement("span", { className: "hmt-sr" }, VIEW[v][1])))) : null),
            React.createElement("div", { className: "hmt-fb-row hmt-fb-chips" }, groups.map((g, gi) => (React.createElement("div", { key: g.id, className: "hmt-fb-group", role: "group", "aria-label": g.label },
                React.createElement("span", { className: "hmt-fb-glabel" }, g.label),
                g.options.map((o) => React.createElement(Chip, { key: o.id, selected: (value[g.id] || []).includes(o.id), onToggle: () => toggle(g.id, o.id), count: o.count }, o.label)),
                gi < groups.length - 1 ? React.createElement("span", { className: "hmt-fb-sep", "aria-hidden": "true" }) : null)))),
            React.createElement("div", { className: "hmt-fb-summary", "aria-live": "polite" },
                React.createElement("span", { className: "hmt-tabular" },
                    React.createElement("b", null, resultCount != null ? resultCount.toLocaleString("vi-VN") : "—"),
                    " k\u1EBFt qu\u1EA3"),
                active.length ? React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } },
                    "\u00B7 \u0110ang l\u1ECDc: ",
                    active.map((g) => "(" + (value[g.id] || []).map((id) => g.options.find((o) => o.id === id).label).join(" hoặc ") + ")").join(" và ")) : null,
                active.length ? React.createElement(Button, { variant: "tertiary", size: "sm", onClick: () => onChange({}) }, "Xo\u00E1 l\u1ECDc nhanh") : null),
            React.createElement(Dialog, { open: saveOpen, onClose: () => setSaveOpen(false), title: "L\u01B0u b\u1ED9 l\u1ECDc y\u00EAu th\u00EDch", footer: React.createElement(Fragment, null,
                    React.createElement(Button, { variant: "secondary", onClick: () => setSaveOpen(false) }, "Hu\u1EF7"),
                    React.createElement(Button, { onClick: () => { if (!favName.trim())
                            return; onSaveFavorite && onSaveFavorite({ name: favName.trim(), isDefault: favDefault, shared: favShared === "all" }); setSaveOpen(false); setFavName(""); } }, "L\u01B0u b\u1ED9 l\u1ECDc")) },
                React.createElement("div", { style: { display: "grid", gap: 12 } },
                    React.createElement(Field, { label: "T\u00EAn b\u1ED9 l\u1ECDc", required: true },
                        React.createElement(TextInput, { value: favName, onChange: (e) => setFavName(e.target.value), placeholder: "V\u00ED d\u1EE5: L\u1ECBch h\u1EB9n qu\u00E1 h\u1EA1n c\u1EE7a t\u00F4i" })),
                    React.createElement("label", { style: { display: "flex", gap: 8, alignItems: "center" } },
                        React.createElement("input", { type: "checkbox", className: "hmt-check", checked: favDefault, onChange: () => setFavDefault(!favDefault) }),
                        "\u0110\u1EB7t l\u00E0m m\u1EB7c \u0111\u1ECBnh khi m\u1EDF danh s\u00E1ch"),
                    React.createElement(SegmentedControl, { name: "fav-share", layout: "row", label: "Ph\u1EA1m vi", value: favShared, onChange: setFavShared, options: [{ value: "me", label: "Chỉ mình tôi" }, { value: "all", label: "Dùng chung cơ sở" }] })))));
    }
    /* ======================= Kanban ======================= */
    function Kanban({ columns, onMove, canMove, renderCard, label = "Bảng kanban" }) {
        const [drag, setDrag] = useState(null);
        const [over, setOver] = useState(null);
        const [block, setBlock] = useState(null);
        const tryMove = (cardId, from, to) => {
            if (from === to)
                return;
            const r = canMove ? canMove(cardId, from, to) : { ok: true };
            if (!r.ok) {
                setBlock(r);
                return;
            }
            onMove(cardId, from, to);
        };
        return (React.createElement("div", { className: "hmt-kb", "aria-label": label },
            columns.map((col) => (React.createElement("section", { key: col.id, className: "hmt-kb-col", "data-over": over === col.id ? "true" : undefined, "aria-label": `${col.label}: ${col.cards.length} thẻ`, onDragOver: (e) => { e.preventDefault(); setOver(col.id); }, onDragLeave: () => setOver(null), onDrop: (e) => { e.preventDefault(); setOver(null); if (drag)
                    tryMove(drag.id, drag.from, col.id); setDrag(null); } },
                React.createElement("header", { className: "hmt-kb-head" },
                    React.createElement("span", { className: "hmt-kb-title" }, col.label),
                    React.createElement("span", { className: "hmt-badge hmt-badge--neutral hmt-tabular" }, col.cards.length)),
                React.createElement("ul", { className: "hmt-kb-list" },
                    col.cards.map((c) => (React.createElement("li", { key: c.id, className: "hmt-kb-card", draggable: true, onDragStart: () => setDrag({ id: c.id, from: col.id }), onDragEnd: () => setDrag(null) },
                        renderCard ? renderCard(c) : React.createElement(KanbanCard, { card: c }),
                        React.createElement("div", { className: "hmt-kb-move" },
                            React.createElement(Popover, { label: `Chuyển ${c.code}`, placement: "bottom-end", trigger: React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "moreV", label: `Chuyển ${c.code} sang giai đoạn khác` }) }, (close) => React.createElement("ul", { className: "hmt-menu", style: { margin: -12 } },
                                React.createElement("li", { className: "hmt-person-meta", style: { padding: "6px 10px" } }, "Chuy\u1EC3n sang"),
                                columns.filter((x) => x.id !== col.id).map((x) => React.createElement("li", { key: x.id },
                                    React.createElement("button", { onClick: () => { close(); tryMove(c.id, col.id, x.id); } }, x.label))))))))),
                    !col.cards.length ? React.createElement("li", { className: "hmt-kb-empty" }, "Kh\u00F4ng c\u00F3 th\u1EBB") : null)))),
            React.createElement(BlockingDialog, { open: !!block, onClose: () => setBlock(null), title: "Kh\u00F4ng chuy\u1EC3n \u0111\u01B0\u1EE3c giai \u0111o\u1EA1n", reasons: block ? [{ text: block.reason, detail: block.detail }] : [] })));
    }
    function KanbanCard({ card }) {
        return (React.createElement("div", { className: "hmt-kb-cardin" },
            card.onOpen ? React.createElement("a", { href: "#", className: "hmt-link hmt-tabular hmt-kb-code", title: card.openLabel || `Mở ${card.code}`, onClick: (e) => { e.preventDefault(); e.stopPropagation(); card.onOpen(); }, onMouseDown: (e) => e.stopPropagation(), draggable: false }, card.code) : React.createElement("span", { className: "hmt-person-meta hmt-tabular", style: { display: "block" } }, card.code),
            React.createElement("p", { className: "hmt-kb-name" }, card.title),
            card.lines ? card.lines.map((l, i) => React.createElement("p", { key: i, className: "hmt-kb-line" }, l)) : null,
            React.createElement("div", { className: "hmt-kb-foot" },
                card.owner ? React.createElement("span", { style: { display: "inline-flex", gap: 6, alignItems: "center" } },
                    React.createElement(Avatar, { name: card.owner, size: "sm", decorative: true }),
                    React.createElement("span", { className: "hmt-kb-line" }, card.owner)) : null,
                card.due ? React.createElement("span", { style: { marginLeft: "auto" } }, card.due) : null)));
    }
    /* ======================= Calendar (lịch buổi) ======================= */
    const SESSION_TYPES = { chinh: { label: "Chính", cat: 1 }, cungco: { label: "Củng cố", cat: 2 }, hocbu: { label: "Học bù", cat: 3 }, botro: { label: "Học bổ trợ", cat: 4 } };
    const WD = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
    function hm(t) { const [h, m] = t.split(":").map(Number); return h + m / 60; }
    function EventChip({ ev, compact, onOpen, types = SESSION_TYPES }) {
        const t = types[ev.type] || { label: ev.type, cat: 4 };
        /* conflict: true | "room" = trùng phòng; "teacher" = trùng giáo viên; "both" = cả hai (cảnh báo, không chặn) */
        const cf = ev.conflict === true || ev.conflict === "room" ? "Trùng phòng" : ev.conflict === "teacher" ? "Trùng giáo viên" : ev.conflict ? "Trùng phòng, giáo viên" : "";
        return (React.createElement("button", { type: "button", className: "hmt-ev hmt-focus", "data-cat": t.cat, "data-cancelled": ev.cancelled ? "true" : undefined, onClick: () => onOpen && onOpen(ev), "aria-label": `${ev.title}, ${t.label}, ${ev.start}–${ev.end}, ${ev.room}${ev.cancelled ? ", đã huỷ" : ""}${cf ? `, ${cf.toLowerCase()}` : ""}` },
            React.createElement("span", { className: "hmt-ev-type" },
                t.label,
                ev.cancelled ? " · Huỷ" : ""),
            React.createElement("span", { className: "hmt-ev-title" }, ev.title),
            !compact ? React.createElement("span", { className: "hmt-ev-meta" },
                ev.start,
                "\u2013",
                ev.end,
                " \u00B7 ",
                ev.room,
                " \u00B7 ",
                ev.teacher) : null,
            cf ? React.createElement("span", { className: "hmt-ev-conflict" },
                React.createElement(Icon, { name: "alert" }),
                " ",
                cf) : null));
    }
    function Calendar({ events, view = "week", onViewChange, by = "room", onByChange, resources = [], weekStart, day, onOpen, startHour = 7, endHour = 22, types = SESSION_TYPES, legendLabel = "Chú thích loại buổi", cancelledLabel = "Buổi huỷ" }) {
        const H = 44;
        const hours = Array.from({ length: endHour - startHour }, (_, i) => startHour + i);
        const pos = (ev) => ({ top: (hm(ev.start) - startHour) * H, height: Math.max(22, (hm(ev.end) - hm(ev.start)) * H - 2) });
        const cols = view === "day" ? resources : WD;
        const colEvents = (c, i) => view === "day" ? events.filter((e) => e.date === day && (by === "room" ? e.room : e.teacher) === c) : events.filter((e) => e.dow === i);
        const layout = (evs) => { const out = evs.map((e) => ({ e, s: hm(e.start), t: hm(e.end) })); return out.map((x) => { const ov = out.filter((y) => y.s < x.t && x.s < y.t); const k = ov.indexOf(x); return { ...x, n: ov.length, k }; }); };
        const gridRef = useRef(null);
        useEffect(() => { if (gridRef.current)
            gridRef.current.scrollTop = (16 - startHour) * H; }, [view]);
        const head = (React.createElement("div", { className: "hmt-cal2-bar" },
            React.createElement(SegmentedControl, { name: "calv", layout: "row", label: "Ki\u1EC3u xem l\u1ECBch", value: view, onChange: onViewChange, options: [{ value: "day", label: "Ngày" }, { value: "week", label: "Tuần" }, { value: "month", label: "Tháng" }] }),
            view === "day" ? React.createElement(SegmentedControl, { name: "calb", layout: "row", label: "Xem theo", value: by, onChange: onByChange, options: [{ value: "room", label: "Theo phòng" }, { value: "person", label: "Theo giáo viên" }] }) : null,
            React.createElement("span", { style: { flex: 1 } }),
            React.createElement("ul", { className: "hmt-cal2-legend", "aria-label": legendLabel },
                Object.keys(types).map((k) => React.createElement("li", { key: k, "data-cat": types[k].cat },
                    React.createElement("span", { className: "hmt-cal2-sw", "aria-hidden": "true" }),
                    types[k].label)),
                React.createElement("li", null,
                    React.createElement("s", null, cancelledLabel)))));
        if (view === "month") {
            const days = Array.from({ length: 35 }, (_, i) => i - 2);
            return (React.createElement("div", { className: "hmt-cal2" },
                head,
                React.createElement("div", { className: "hmt-cal2-month", role: "grid", "aria-label": "Th\u00E1ng 10/2026" },
                    WD.map((d) => React.createElement("div", { key: d, className: "hmt-cal2-mh", role: "columnheader" }, d)),
                    days.map((n, i) => {
                        const evs = events.filter((e) => e.mday === n);
                        return (React.createElement("div", { key: i, className: "hmt-cal2-mcell", role: "gridcell", "data-out": n < 1 || n > 31 ? "true" : undefined },
                            React.createElement("span", { className: "hmt-cal2-mnum hmt-tabular" }, n < 1 ? 30 + n : n > 31 ? n - 31 : n),
                            evs.slice(0, 2).map((e) => React.createElement(EventChip, { key: e.id, ev: e, compact: true, onOpen: onOpen, types: types })),
                            evs.length > 2 ? React.createElement("button", { type: "button", className: "hmt-cal2-more hmt-focus" },
                                "+",
                                evs.length - 2,
                                " bu\u1ED5i") : null));
                    }))));
        }
        return (React.createElement("div", { className: "hmt-cal2" },
            head,
            React.createElement("div", { ref: gridRef, className: "hmt-cal2-grid", style: { gridTemplateColumns: `56px repeat(${cols.length}, minmax(170px,1fr))` } },
                React.createElement("div", { className: "hmt-cal2-corner" }),
                cols.map((c, i) => React.createElement("div", { key: c, className: "hmt-cal2-ch" }, view === "week" ? `${c} ${weekStart + i}/10` : c)),
                React.createElement("div", { className: "hmt-cal2-times" }, hours.map((h) => React.createElement("div", { key: h, style: { height: H }, className: "hmt-tabular" },
                    String(h).padStart(2, "0"),
                    ":00"))),
                cols.map((c, i) => (React.createElement("div", { key: c, className: "hmt-cal2-col", style: { height: hours.length * H } },
                    hours.map((h) => React.createElement("div", { key: h, className: "hmt-cal2-slot", style: { height: H } })),
                    layout(colEvents(c, i)).map((x) => React.createElement("div", { key: x.e.id, className: "hmt-cal2-pos", style: { ...pos(x.e), left: `calc(${(x.k / x.n) * 100}% + 3px)`, width: `calc(${100 / x.n}% - 6px)`, right: "auto" } },
                        React.createElement(EventChip, { ev: x.e, compact: x.n > 1, onOpen: onOpen, types: types })))))))));
    }
    /* ======================= Combobox ======================= */
    function norm(s) { return (s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").replace(/Đ/g, "D").toLowerCase(); }
    function Combobox({ options, value, onChange, multiple, placeholder = "Gõ tên, mã hoặc mã cũ", invalid, disabled, loading, emptyText = "Không tìm thấy kết quả", ...rest }) {
        const f = useField({ invalid, ...rest });
        const [q, setQ] = useState("");
        const [open, setOpen] = useState(false);
        const [act, setAct] = useState(0);
        const listId = useId();
        const wrap = useRef(null);
        const inp = useRef(null);
        const sel = multiple ? (value || []) : value ? [value] : [];
        const results = options.filter((o) => !q || [o.label, o.code, o.legacyCode].some((x) => norm(x).includes(norm(q)))).slice(0, 8);
        const choose = (o) => {
            if (o.disabled)
                return;
            if (multiple) {
                onChange(sel.includes(o.value) ? sel.filter((v) => v !== o.value) : [...sel, o.value]);
                setQ("");
            }
            else {
                onChange(o.value);
                setQ("");
                setOpen(false);
            }
        };
        useEffect(() => { if (!open)
            return; const h = (e) => { if (wrap.current && !wrap.current.contains(e.target))
            setOpen(false); }; document.addEventListener("mousedown", h); return () => document.removeEventListener("mousedown", h); }, [open]);
        const single = !multiple && sel.length ? options.find((o) => o.value === sel[0]) : null;
        return (React.createElement("div", { className: "hmt-cbx", ref: wrap },
            React.createElement("div", { className: cx("hmt-control", multiple && "hmt-cbx-multi"), "data-invalid": f["aria-invalid"] ? "true" : undefined, "data-disabled": disabled ? "true" : undefined, onClick: () => inp.current.focus() },
                React.createElement("span", { className: "hmt-adorn" },
                    React.createElement(Icon, { name: "search" })),
                multiple ? sel.map((v) => { const o = options.find((x) => x.value === v); return React.createElement("span", { key: v, className: "hmt-cbx-tag" },
                    o ? o.label : v,
                    React.createElement("button", { type: "button", "aria-label": `Bỏ ${o ? o.label : v}`, onClick: (e) => { e.stopPropagation(); onChange(sel.filter((x) => x !== v)); } },
                        React.createElement(Icon, { name: "x" }))); }) : null,
                React.createElement("input", { ref: inp, ...f, role: "combobox", "aria-expanded": open, "aria-controls": listId, "aria-autocomplete": "list", "aria-activedescendant": open && results[act] ? `${listId}-${act}` : undefined, value: open || !single ? q : `${single.label} · ${single.code}`, placeholder: sel.length && multiple ? "" : placeholder, disabled: disabled, onFocus: () => setOpen(true), onBlur: () => setTimeout(() => { if (wrap.current && !wrap.current.contains(document.activeElement))
                        setOpen(false); }, 120), onChange: (e) => { setQ(e.target.value); setOpen(true); setAct(0); }, onKeyDown: (e) => {
                        const step = (d) => { for (let k = act + d; k >= 0 && k < results.length; k += d)
                            if (!results[k].disabled)
                                return k; return act; };
                        if (e.key === "ArrowDown") {
                            setOpen(true);
                            setAct(step(1));
                            e.preventDefault();
                        }
                        else if (e.key === "ArrowUp") {
                            setAct(step(-1));
                            e.preventDefault();
                        }
                        else if (e.key === "Tab")
                            setOpen(false);
                        else if (e.key === "Enter" && open && results[act]) {
                            choose(results[act]);
                            e.preventDefault();
                        }
                        else if (e.key === "Escape") {
                            setOpen(false);
                            e.stopPropagation();
                        }
                        else if (e.key === "Backspace" && !q && multiple && sel.length)
                            onChange(sel.slice(0, -1));
                    } }),
                !multiple && single && !disabled ? React.createElement("button", { type: "button", className: "hmt-cbx-clear", "aria-label": "Xo\u00E1 l\u1EF1a ch\u1ECDn", onClick: (e) => { e.stopPropagation(); onChange(null); } },
                    React.createElement(Icon, { name: "x" })) : null),
            open ? (React.createElement("ul", { id: listId, role: "listbox", "aria-multiselectable": multiple || undefined, className: "hmt-pop hmt-cbx-list" }, loading ? React.createElement("li", { className: "hmt-cbx-none" },
                React.createElement("span", { className: "hmt-spinner" }),
                " \u0110ang t\u00ECm\u2026")
                : !results.length ? React.createElement("li", { className: "hmt-cbx-none", role: "option", "aria-disabled": "true" },
                    React.createElement(Icon, { name: "search" }),
                    " ",
                    emptyText,
                    q ? ` cho “${q}”` : "")
                    : results.map((o, i) => {
                        const on = sel.includes(o.value);
                        return (React.createElement("li", { key: o.value, id: `${listId}-${i}`, role: "option", "aria-selected": on, "aria-disabled": o.disabled || undefined, className: "hmt-cbx-opt", "data-active": i === act ? "true" : undefined, onMouseDown: (e) => { e.preventDefault(); choose(o); }, onMouseEnter: () => setAct(i) },
                            multiple ? React.createElement("span", { className: "hmt-cbx-box", "aria-hidden": "true" }, on ? React.createElement(Icon, { name: "check" }) : null) : null,
                            React.createElement("span", { style: { flex: 1, minWidth: 0 } },
                                React.createElement("span", { className: "hmt-cbx-main" },
                                    o.label,
                                    " ",
                                    React.createElement("span", { className: "hmt-tabular hmt-cbx-code" }, o.code)),
                                o.legacyCode ? React.createElement("span", { className: "hmt-cbx-sub" },
                                    "M\u00E3 c\u0169: ",
                                    o.legacyCode) : null,
                                o.meta ? React.createElement("span", { className: "hmt-cbx-sub" }, o.meta) : null),
                            o.disabled ? React.createElement("span", { className: "hmt-badge hmt-badge--neutral" }, o.disabledReason || "Không chọn được") : !multiple && on ? React.createElement(Icon, { name: "check" }) : null));
                    }))) : null));
    }
    /* ======================= DateRange ======================= */
    function DateRange({ value, onChange, today = new Date(2026, 9, 11) }) {
        const [open, setOpen] = useState(false);
        const [pick, setPick] = useState(null);
        const ref = useRef(null);
        const d0 = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const monday = (d) => { const x = d0(d); x.setDate(x.getDate() - ((x.getDay() + 6) % 7)); return x; };
        const P_ = [
            { id: "today", label: "Hôm nay", r: () => [d0(today), d0(today)] },
            { id: "week", label: "Tuần này", r: () => { const a = monday(today); const b = new Date(a); b.setDate(a.getDate() + 6); return [a, b]; } },
            { id: "month", label: "Tháng này", r: () => [new Date(today.getFullYear(), today.getMonth(), 1), new Date(today.getFullYear(), today.getMonth() + 1, 0)] },
            { id: "last", label: "Tháng trước", r: () => [new Date(today.getFullYear(), today.getMonth() - 1, 1), new Date(today.getFullYear(), today.getMonth(), 0)] },
        ];
        const text = value && value.from ? `${fmt(value.from)} – ${fmt(value.to || value.from)}` : "Chọn khoảng ngày";
        const preset = value && P_.find((p) => { const [a, b] = p.r(); return value.from && value.to && a.getTime() === value.from.getTime() && b.getTime() === value.to.getTime(); });
        return (React.createElement(Fragment, null,
            React.createElement("span", { ref: ref, style: { display: "inline-flex" } },
                React.createElement(Button, { variant: "secondary", iconStart: "calendar", iconEnd: "chevronDown", "aria-haspopup": "dialog", "aria-expanded": open, onClick: () => setOpen(!open) }, preset ? React.createElement("span", null,
                    preset.label,
                    " ",
                    React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } },
                        "(",
                        text,
                        ")")) : text)),
            React.createElement(PopoverPanel, { open: open, onClose: () => setOpen(false), anchorRoot: ref, label: "Ch\u1ECDn kho\u1EA3ng ng\u00E0y" },
                React.createElement("div", { className: "hmt-dr" },
                    React.createElement("ul", { className: "hmt-menu hmt-dr-presets" }, P_.map((p) => React.createElement("li", { key: p.id },
                        React.createElement("button", { onClick: () => { const [a, b] = p.r(); onChange({ from: a, to: b }); setOpen(false); } },
                            preset && preset.id === p.id ? React.createElement(Icon, { name: "check" }) : React.createElement("span", { style: { width: "1.15em" } }),
                            p.label)))),
                    React.createElement("div", null,
                        React.createElement("p", { className: "hmt-help", style: { padding: "8px 8px 0" } }, pick ? `Từ ${fmt(pick)} — chọn ngày kết thúc` : "Tuỳ chọn: bấm ngày bắt đầu rồi ngày kết thúc"),
                        React.createElement(MonthGrid, { autoFocus: false, value: null, rangeFrom: pick || (value && value.from), rangeTo: pick ? null : value && value.to, today: today, onSelect: (d) => { if (!pick)
                                setPick(d);
                            else {
                                const [a, b] = d < pick ? [d, pick] : [pick, d];
                                onChange({ from: a, to: b });
                                setPick(null);
                                setOpen(false);
                            } } }))))));
    }
    /* ======================= MoneyInput ======================= */
    const vnd = (n) => (n == null || isNaN(n) ? "" : Math.round(n).toLocaleString("vi-VN"));
    function MoneyInput({ value, onChange, readOnly, invalid, disabled, systemNote = "Hệ thống tính", ...rest }) {
        const f = useField({ invalid, ...rest });
        if (readOnly)
            return (React.createElement("div", { className: "hmt-control hmt-money hmt-money--ro", "data-ro": "true" },
                React.createElement("span", { className: "hmt-adorn" },
                    React.createElement(Icon, { name: "lock" })),
                React.createElement("output", { ...f, className: "hmt-money-val hmt-tabular" }, vnd(value)),
                React.createElement("span", { className: "hmt-money-unit" }, "\u0111"),
                React.createElement("span", { className: "hmt-money-note" }, systemNote)));
        return (React.createElement("div", { className: "hmt-control hmt-money", "data-invalid": f["aria-invalid"] ? "true" : undefined, "data-disabled": disabled ? "true" : undefined },
            React.createElement("input", { ...rest, ...f, inputMode: "numeric", className: "hmt-money-val hmt-tabular", value: vnd(value), disabled: disabled, onChange: (e) => { const n = parseInt(e.target.value.replace(/\D/g, "") || "0", 10); onChange && onChange(n); } }),
            React.createElement("span", { className: "hmt-money-unit" }, "\u0111")));
    }
    /* ======================= HoursDisplay (R-GD-07) ======================= */
    const hrs = (n) => `${String(Math.round(n * 10) / 10).replace(".", ",")} giờ`;
    function HoursDisplay({ granted, used, bonus = 0, bonusLocked, expectedEnd, packageEnd, packageExpired, threshold = 10, compact }) {
        const left = granted + (bonusLocked ? 0 : bonus) - used;
        const total = granted + bonus;
        const low = left <= threshold;
        const pct = (n) => `${Math.max(0, (n / total) * 100)}%`;
        return (React.createElement("div", { className: "hmt-hours", "data-low": low ? "true" : undefined },
            React.createElement("div", { className: "hmt-hours-top" },
                React.createElement("span", null,
                    React.createElement("b", { className: "hmt-tabular hmt-hours-left" }, hrs(left)),
                    " c\u00F2n l\u1EA1i"),
                low ? React.createElement(Badge, { tone: "warning" },
                    "S\u1EAFp h\u1EBFt gi\u1EDD (\u2264 ",
                    threshold,
                    " gi\u1EDD)") : null),
            React.createElement("div", { className: "hmt-hours-bar", role: "img", "aria-label": `Đã dùng ${hrs(used)}, còn lại ${hrs(left)}, giờ tặng ${hrs(bonus)}${bonusLocked ? " chưa cấp" : ""}` },
                React.createElement("span", { className: "hmt-hours-used", style: { width: pct(used) } }),
                React.createElement("span", { className: "hmt-hours-rest", style: { width: pct(granted - used) } }),
                React.createElement("span", { className: "hmt-hours-bonus", "data-locked": bonusLocked ? "true" : undefined, style: { width: pct(bonus) } })),
            React.createElement("ul", { className: "hmt-hours-legend" },
                React.createElement("li", null,
                    React.createElement("span", { className: "hmt-hours-sw hmt-hours-used" }),
                    "\u0110\u00E3 d\u00F9ng ",
                    React.createElement("b", { className: "hmt-tabular" }, hrs(used))),
                React.createElement("li", null,
                    React.createElement("span", { className: "hmt-hours-sw hmt-hours-rest" }),
                    "C\u00F2n l\u1EA1i (\u0111\u00E3 c\u1EA5p) ",
                    React.createElement("b", { className: "hmt-tabular" }, hrs(Math.max(0, granted - used)))),
                React.createElement("li", null,
                    React.createElement("span", { className: "hmt-hours-sw hmt-hours-bonus", "data-locked": bonusLocked ? "true" : undefined }),
                    "Gi\u1EDD t\u1EB7ng ",
                    React.createElement("b", { className: "hmt-tabular" }, hrs(bonus)),
                    bonusLocked ? React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } }, " \u00B7 c\u1EA5p khi thu \u0111\u1EE7 ti\u1EC1n") : null)),
            !compact ? React.createElement("dl", { className: "hmt-hours-dl" },
                React.createElement("dt", null, "\u0110\u00E3 c\u1EA5p"),
                React.createElement("dd", { className: "hmt-tabular" }, hrs(granted)),
                React.createElement("dt", null, "H\u1EBFt gi\u1EDD d\u1EF1 ki\u1EBFn"),
                React.createElement("dd", { className: "hmt-tabular" }, expectedEnd),
                packageEnd ? React.createElement(Fragment, null,
                    React.createElement("dt", null, "H\u1EA1n g\u00F3i (d\u1EF1 b\u00E1o)"),
                    React.createElement("dd", { className: "hmt-tabular" }, packageEnd)) : null) : null,
            packageExpired ? React.createElement("p", { className: "hmt-hours-info" },
                React.createElement(Icon, { name: "info" }),
                " G\u00F3i \u0111\u00E3 qu\u00E1 h\u1EA1n 6 th\u00E1ng nh\u01B0ng c\u00F2n gi\u1EDD \u2014 em v\u1EABn h\u1ECDc b\u00ECnh th\u01B0\u1EDDng. H\u1EA1n g\u00F3i ch\u1EC9 \u0111\u1EC3 d\u1EF1 b\u00E1o.") : null));
    }
    /* ======================= RatingScale (R-GV-01/02/04) ======================= */
    function RatingScale({ name, label, value, onChange, descriptions = {}, required }) {
        const id = useId();
        return (React.createElement("fieldset", { className: "hmt-rate", "data-empty": value == null ? "true" : undefined },
            React.createElement("legend", { className: "hmt-rate-label" },
                label,
                required ? React.createElement("span", { className: "hmt-req", "aria-hidden": "true" }, " *") : null),
            React.createElement("div", { className: "hmt-rate-row" },
                [1, 2, 3, 4, 5].map((n) => (React.createElement("label", { key: n, className: "hmt-rate-opt" },
                    React.createElement("input", { type: "radio", name: name, value: n, checked: value === n, onChange: () => onChange(n), "aria-describedby": `${id}-d` }),
                    React.createElement("span", { className: "hmt-tabular" }, n)))),
                value != null ? React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "x", label: `Bỏ chấm ${label}`, onClick: () => onChange(null) }) : null),
            React.createElement("p", { id: `${id}-d`, className: "hmt-rate-desc", "aria-live": "polite" }, value == null ? React.createElement("span", { className: "hmt-rate-unset" },
                React.createElement(Icon, { name: "info" }),
                " Ch\u01B0a ch\u1EA5m \u2014 kh\u00E1c \u0111i\u1EC3m 0") : descriptions[value] ? React.createElement(Fragment, null,
                React.createElement("b", null,
                    "M\u1EE9c ",
                    value,
                    ":"),
                " ",
                descriptions[value]) : React.createElement("b", null,
                "M\u1EE9c ",
                value))));
    }
    /* ======================= HomeworkStatus (R-GV-11) ======================= */
    const HW = {
        graded: { label: "Đã chấm", tone: "success", icon: "check", score: true },
        partial: { label: "Làm chưa xong", tone: "warning", icon: "hourglass", score: true },
        none: { label: "Không làm", tone: "danger", icon: "x", score: false },
        late: { label: "Nộp sau", tone: "info", icon: "clock", score: false },
        na: { label: "Không áp dụng", tone: "neutral", icon: "ban", score: false },
    };
    /* ======================= ScoreInput — điểm số gõ tay (BTVN 1–5 theo R-GV-11; kiểm tra đầu vào 0–10 truyền min/max) ======================= */
    const fmtScore = (n) => (n == null ? "" : String(n).replace(".", ","));
    function checkScore(text, min, max, decimals) {
        const t = String(text || "").trim().replace(",", ".");
        if (!t)
            return { value: null, error: null };
        if (!/^\d+([.]\d+)?$/.test(t))
            return { value: null, error: `Chỉ nhập số, ví dụ ${Math.round(max * 0.8)}` };
        const dec = (t.split(".")[1] || "").length;
        if (dec > decimals)
            return { value: null, error: decimals ? `Tối đa ${decimals} chữ số sau dấu phẩy` : `Nhập số nguyên, ví dụ ${Math.round(max * 0.8)}` };
        const n = Number(t);
        if (n < min || n > max)
            return { value: null, error: `Điểm phải từ ${min} đến ${max}` };
        return { value: n, error: null };
    }
    function ScoreInput({ value, onChange, onErrorChange, min = 1, max = 5, decimals = 1, invalid, disabled, id, ...rest }) {
        const [text, setText] = useState(fmtScore(value));
        const focused = useRef(false);
        useEffect(() => { if (!focused.current)
            setText(fmtScore(value)); }, [value]);
        const f = useField({ invalid, id });
        const commit = (t) => { const r = checkScore(t, min, max, decimals); onErrorChange && onErrorChange(r.error); if (!r.error) {
            onChange && onChange(r.value);
            setText(fmtScore(r.value));
        } };
        return (React.createElement("div", { className: "hmt-control hmt-score", "data-invalid": f["aria-invalid"] ? "true" : undefined, "data-disabled": disabled ? "true" : undefined },
            React.createElement("input", { ...f, type: "text", inputMode: decimals ? "decimal" : "numeric", autoComplete: "off", maxLength: 4, value: text, disabled: disabled, placeholder: "\u2014", onFocus: () => (focused.current = true), onChange: (e) => { setText(e.target.value); if (invalid) {
                    const r = checkScore(e.target.value, min, max, decimals);
                    if (!r.error)
                        onErrorChange && onErrorChange(null);
                } }, onBlur: (e) => { focused.current = false; commit(e.target.value); }, onKeyDown: (e) => { if (e.key === "Enter")
                    commit(e.target.value); }, ...rest }),
            React.createElement("span", { className: "hmt-score-max", "aria-hidden": "true" },
                "/ ",
                max)));
    }
    /* ======================= HomeworkStatus (R-GV-11; điểm 1–5 gõ tay, một chữ số thập phân — A-47) ======================= */
    function HomeworkStatus({ value, onChange, readOnly, name = "hw", min = 1, max = 5, decimals = 1, showMissing, hideLabels }) {
        var _a;
        const v = value || {};
        const meta = HW[v.status];
        const [err, setErr] = useState(null);
        if (readOnly)
            return meta ? React.createElement("span", { className: "hmt-hw-view" },
                React.createElement(Badge, { tone: meta.tone, icon: meta.icon }, meta.label),
                meta.score && v.score != null ? React.createElement("span", { className: "hmt-tabular hmt-hw-score" },
                    React.createElement("b", null, fmtScore(v.score)),
                    "/",
                    max) : null) : React.createElement("span", { className: "hmt-badge hmt-badge--neutral hmt-att-empty" }, "\u2014 Ch\u01B0a c\u1EADp nh\u1EADt");
        const missing = meta && meta.score && v.score == null;
        const scoreErr = err || (showMissing && missing ? `Nhập điểm từ ${min} đến ${max}` : null);
        return (React.createElement("div", { className: "hmt-hw" },
            React.createElement("div", { className: "hmt-hw-grid" },
                React.createElement(Field, { label: "Tr\u1EA1ng th\u00E1i", required: true, hideLabel: hideLabels, className: "hmt-hw-status" },
                    React.createElement(Select, { value: v.status || "", placeholder: "Ch\u1ECDn tr\u1EA1ng th\u00E1i", onChange: (e) => { var _a; setErr(null); onChange({ status: e.target.value, score: HW[e.target.value].score ? ((_a = v.score) !== null && _a !== void 0 ? _a : null) : null }); }, options: Object.keys(HW).map((k) => ({ value: k, label: HW[k].label })) })),
                meta && meta.score ? (React.createElement("div", { className: "hmt-hw-scorefield" },
                    React.createElement(Field, { label: `Điểm (${min}–${max})`, required: true, hideLabel: hideLabels, error: scoreErr || undefined },
                        React.createElement(ScoreInput, { name: `${name}-score`, value: (_a = v.score) !== null && _a !== void 0 ? _a : null, min: min, max: max, decimals: decimals, invalid: !!scoreErr, onChange: (n) => onChange({ ...v, score: n }), onErrorChange: setErr })))) : null),
            v.status === "late" ? React.createElement("p", { className: "hmt-help" }, "C\u1EADp nh\u1EADt \u0111i\u1EC3m \u1EDF bu\u1ED5i sau, kh\u00F4ng c\u1EA7n m\u1EDF l\u1EA1i bu\u1ED5i n\u00E0y.") : null));
    }
    /* ======================= Cổng Giáo viên (đợt 5.5) =======================
       TeacherShell (GV-01): cùng 5 mục cho hai bố cục. Điện thoại: tiêu đề trên + thanh dưới. Laptop: menu trái thu gọn + vùng nội dung rộng.
       Chữ 16 (data-product="teacher"); laptop thêm data-device="desktop" để control 40px, dòng 48px. */
    const GV_NAV = [{ id: "today", label: "Hôm nay", icon: "home" }, { id: "cal", label: "Lịch dạy", icon: "calendar" }, { id: "cls", label: "Lớp", icon: "book" }, { id: "todo", label: "Việc cần làm", icon: "clipboard" }, { id: "me", label: "Tài khoản", icon: "users" }];
    function TeacherShell({ device = "phone", activeId = "today", onNavigate, title, onBack, actions, user, badges = {}, saveState, children, height = 740, contentMaxWidth, flush }) {
        const items = GV_NAV.map((x) => ({ ...x, badge: badges[x.id] }));
        const nav = (id) => onNavigate && onNavigate(id);
        const top = React.createElement(TopNav, { leading: onBack ? React.createElement(Button, { variant: "tertiary", neutral: true, iconOnly: "chevronLeft", label: "Quay l\u1EA1i", onClick: onBack }) : undefined, title: title, actions: React.createElement(Fragment, null,
                saveState ? React.createElement(SaveState, { state: saveState }) : null,
                actions,
                React.createElement(Button, { variant: "tertiary", neutral: true, iconOnly: "bell", label: "Th\u00F4ng b\u00E1o" })) });
        if (device === "laptop")
            return (React.createElement("div", { className: "hmt-gvshell", "data-product": "teacher", "data-device": "desktop", style: { height } },
                React.createElement(Sidebar, { subtitle: "C\u1ED5ng Gi\u00E1o vi\u00EAn", collapsed: true, onCollapsedChange: () => { }, activeId: activeId, onNavigate: nav, sections: [{ items }], footer: user ? React.createElement("span", { className: "hmt-gvshell-user", title: user },
                        React.createElement(Avatar, { name: user, size: "sm" })) : null }),
                React.createElement("div", { className: "hmt-gvshell-main" },
                    top,
                    React.createElement("div", { className: "hmt-gvshell-body", style: { maxWidth: contentMaxWidth, padding: flush ? 0 : undefined } }, children))));
        return (React.createElement("div", { className: "hmt-phone hmt-gvshell-phone", "data-product": "teacher", style: { height } },
            top,
            React.createElement("div", { className: "hmt-gvshell-pbody", style: { padding: flush ? 0 : undefined } }, children),
            React.createElement(BottomNav, { items: items, activeId: activeId, onNavigate: nav })));
    }
    /* ======================= Cổng Học tập + Phụ huynh (đợt 5.6) =======================
       StudentShell (HT-09): data-product="lms" (chữ 16, control 44). young = học sinh nhỏ (lớp 2–5): chữ 18, control 52, nhãn thanh dưới 14.
       portal "hs": Trang chủ, Bài tập, Lịch, Kết quả, Tài khoản · portal "ph": Trang chủ, Kết quả, Lịch, Học phí, Đề nghị (Q-10, chỉ điện thoại); Tài khoản ở menu ảnh đại diện trên đầu trang.
       Laptop (chỉ học sinh): menu trái mở rộng + nội dung MỘT CỘT giữa trang (tối đa 720px). */
    const HT_NAV = [{ id: "home", label: "Trang chủ", icon: "home" }, { id: "hw", label: "Bài tập", icon: "book" }, { id: "cal", label: "Lịch", icon: "calendar" }, { id: "res", label: "Kết quả", icon: "layers" }, { id: "me", label: "Tài khoản", icon: "users" }];
    const PH_NAV = [{ id: "home", label: "Trang chủ", icon: "home" }, { id: "res", label: "Kết quả", icon: "layers" }, { id: "cal", label: "Lịch", icon: "calendar" }, { id: "fee", label: "Học phí", icon: "wallet" }, { id: "req", label: "Đề nghị", icon: "message" }];
    function StudentShell({ portal = "hs", device = "phone", young, activeId = "home", onNavigate, title, onBack, actions, user, badges = {}, children, height = 740, flush, bottom }) {
        const items = (portal === "ph" ? PH_NAV : HT_NAV).map((x) => ({ ...x, badge: badges[x.id] }));
        const nav = (id) => onNavigate && onNavigate(id);
        const top = React.createElement(TopNav, { leading: onBack ? React.createElement(Button, { variant: "tertiary", neutral: true, iconOnly: "chevronLeft", label: "Quay l\u1EA1i", onClick: onBack }) : undefined, title: title, actions: React.createElement(Fragment, null,
                actions,
                React.createElement(Button, { variant: "tertiary", neutral: true, iconOnly: "bell", label: "Th\u00F4ng b\u00E1o" }),
                portal === "ph" ? React.createElement(Popover, { label: "T\u00E0i kho\u1EA3n", placement: "bottom-end", trigger: React.createElement("button", { type: "button", className: "hmt-lshell-av hmt-focus", "aria-label": `Tài khoản: ${user || ""}` },
                        React.createElement(Avatar, { name: user || "?", size: "sm", decorative: true })) }, (close) => React.createElement("ul", { className: "hmt-menu", style: { margin: -12 } },
                    React.createElement("li", { className: "hmt-person-meta", style: { padding: "8px 12px" } }, user),
                    [["users", "Tài khoản"], ["lock", "Đổi mật khẩu"], ["logout", "Đăng xuất"]].map(([ic, l]) => React.createElement("li", { key: l },
                        React.createElement("button", { onClick: () => close() },
                            React.createElement(Icon, { name: ic }),
                            l))))) : null) });
        if (device === "laptop" && portal !== "ph")
            return (React.createElement("div", { className: "hmt-lshell", "data-product": "lms", "data-young": young ? "true" : undefined, style: { height } },
                React.createElement(Sidebar, { subtitle: "H\u1ECDc t\u1EADp", activeId: activeId, onNavigate: nav, sections: [{ items }], onCollapsedChange: () => { }, footer: user ? React.createElement("span", { className: "hmt-lshell-user" },
                        React.createElement(Avatar, { name: user, size: "sm" }),
                        React.createElement("span", null, user)) : null }),
                React.createElement("div", { className: "hmt-lshell-main" },
                    top,
                    React.createElement("div", { className: "hmt-lshell-scroll" },
                        React.createElement("div", { className: "hmt-lshell-col", style: { padding: flush ? 0 : undefined } }, children)),
                    bottom ? React.createElement("div", { className: "hmt-lshell-foot" }, bottom) : null)));
        return (React.createElement("div", { className: "hmt-phone hmt-lshell-phone", "data-product": "lms", "data-young": young ? "true" : undefined, style: { height } },
            top,
            React.createElement("div", { className: "hmt-lshell-pbody", style: { padding: flush ? 0 : undefined } }, children),
            bottom,
            React.createElement(BottomNav, { items: items, activeId: activeId, onNavigate: nav })));
    }
    /* PhotoPages (HT-04): các trang của một bài nộp, theo đúng thứ tự giáo viên sẽ xem.
       page { id, kind: "img"|"pdf", src?, name, size?, pages? (số trang PDF), status: "done"|"uploading"|"error", progress?, error? }
       Sửa: đưa trang lên trước / ra sau (nút, không chỉ kéo), gỡ, thử lại; bấm ảnh để xem to (onView). review = chỉ xem, không có nút sửa. */
    function PhotoPages({ pages, onChange, onView, onRetry, review, onAdd, addLabel = "Thêm trang", columns }) {
        const move = (i, d) => { const a = [...pages]; const j = i + d; if (j < 0 || j >= a.length)
            return; [a[i], a[j]] = [a[j], a[i]]; onChange && onChange(a); };
        const kb = (n) => n > 1e6 ? `${(n / 1e6).toFixed(1).replace(".", ",")} MB` : `${Math.round(n / 1e3)} KB`;
        let pageNo = 0;
        return (React.createElement("ol", { className: "hmt-pp", "data-review": review ? "true" : undefined, style: columns ? { gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` } : undefined, "aria-label": "C\u00E1c trang b\u00E0i l\u00E0m" },
            pages.map((p, i) => {
                const from = pageNo + 1;
                pageNo += p.kind === "pdf" ? (p.pages || 1) : 1;
                const lbl = p.kind === "pdf" && (p.pages || 1) > 1 ? `Trang ${from}–${pageNo}` : `Trang ${from}`;
                return (React.createElement("li", { key: p.id, className: "hmt-pp-item", "data-status": p.status },
                    React.createElement("button", { type: "button", className: "hmt-pp-thumb hmt-focus", onClick: () => onView && onView(p.id), "aria-label": `Xem ${lbl}: ${p.name}` },
                        p.kind === "pdf" ? React.createElement("span", { className: "hmt-pp-pdf" },
                            React.createElement(Icon, { name: "file", size: 28 }),
                            React.createElement("b", null, "PDF"),
                            React.createElement("span", null,
                                p.pages || 1,
                                " trang")) : React.createElement("img", { src: p.src, alt: "" }),
                        p.status === "uploading" ? React.createElement("span", { className: "hmt-pp-over" },
                            React.createElement("span", { className: "hmt-progress-track", role: "progressbar", "aria-valuenow": p.progress || 0, "aria-valuemin": 0, "aria-valuemax": 100, "aria-label": `Đang tải ${p.name}` },
                                React.createElement("span", { className: "hmt-progress-fill", style: { width: `${p.progress || 0}%`, display: "block" } })),
                            React.createElement("span", null,
                                "\u0110ang t\u1EA3i ",
                                p.progress || 0,
                                "%")) : null,
                        p.status === "error" ? React.createElement("span", { className: "hmt-pp-over hmt-pp-over--err" },
                            React.createElement(Icon, { name: "xcircle" }),
                            " ",
                            p.error || "Chưa tải được") : null),
                    React.createElement("span", { className: "hmt-pp-cap" },
                        React.createElement("b", { className: "hmt-tabular" }, lbl),
                        React.createElement("span", { className: "hmt-pp-meta" },
                            p.name,
                            p.size ? ` · ${kb(p.size)}` : "")),
                    review ? null : React.createElement("span", { className: "hmt-pp-tools" },
                        p.status === "error" ? React.createElement(Button, { variant: "tertiary", size: "sm", iconStart: "refresh", onClick: () => onRetry && onRetry(p.id) }, "Th\u1EED l\u1EA1i") : React.createElement(Fragment, null,
                            React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "chevronLeft", label: `Đưa ${lbl} lên trước`, disabled: i === 0, onClick: () => move(i, -1) }),
                            React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "chevronRight", label: `Đưa ${lbl} ra sau`, disabled: i === pages.length - 1, onClick: () => move(i, 1) })),
                        React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "trash", label: `Gỡ ${lbl}`, onClick: () => onChange && onChange(pages.filter((x) => x.id !== p.id)) }))));
            }),
            onAdd && !review ? React.createElement("li", { className: "hmt-pp-item" },
                React.createElement("button", { type: "button", className: "hmt-pp-add hmt-focus", onClick: onAdd },
                    React.createElement(Icon, { name: "plus", size: 24 }),
                    React.createElement("span", null, addLabel))) : null));
    }
    /* SubmissionViewer (GV-18, HT-05): xem ảnh / PDF học sinh nộp. Chuyển trang (← →), phóng to (+ −), xoay 90°, vừa khung; dãy trang nhỏ bên dưới.
       pages [{ id, src, label }] — PDF đã tách trang. Phím: ← → đổi trang, + − phóng, R xoay. */
    function SubmissionViewer({ pages, page = 0, onPage, height = 420, compact }) {
        const [z, setZ] = useState(1);
        const [r, setR] = useState(0);
        const cur = pages[page] || pages[0];
        const go = (i) => { if (i < 0 || i >= pages.length)
            return; onPage && onPage(i); setZ(1); setR(0); };
        const key = (e) => { const k = e.key; if (k === "ArrowRight")
            go(page + 1);
        else if (k === "ArrowLeft")
            go(page - 1);
        else if (k === "+" || k === "=")
            setZ(Math.min(3, z + 0.25));
        else if (k === "-")
            setZ(Math.max(0.5, z - 0.25));
        else if (k === "r" || k === "R")
            setR((r + 90) % 360);
        else
            return; e.preventDefault(); };
        return (React.createElement("div", { className: "hmt-sv", "data-compact": compact ? "true" : undefined },
            React.createElement("div", { className: "hmt-sv-bar" },
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "chevronLeft", label: "Trang tr\u01B0\u1EDBc", disabled: page === 0, onClick: () => go(page - 1) }),
                React.createElement("span", { className: "hmt-tabular hmt-sv-pg", "aria-live": "polite" },
                    "Trang ",
                    page + 1,
                    "/",
                    pages.length),
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "chevronRight", label: "Trang sau", disabled: page === pages.length - 1, onClick: () => go(page + 1) }),
                React.createElement("span", { className: "hmt-sv-sp" }),
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "zoomOut", label: "Thu nh\u1ECF", disabled: z <= 0.5, onClick: () => setZ(Math.max(0.5, z - 0.25)) }),
                React.createElement("span", { className: "hmt-tabular hmt-sv-z" },
                    Math.round(z * 100),
                    "%"),
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "zoomIn", label: "Ph\u00F3ng to", disabled: z >= 3, onClick: () => setZ(Math.min(3, z + 0.25)) }),
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "rotateCw", label: "Xoay 90 \u0111\u1ED9", onClick: () => setR((r + 90) % 360) }),
                compact ? null : React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", onClick: () => { setZ(1); setR(0); } }, "V\u1EEBa khung")),
            React.createElement("div", { className: "hmt-sv-stage hmt-focus", tabIndex: 0, role: "group", "aria-label": `Bài làm, ${cur.label || `trang ${page + 1}`}. Phím mũi tên đổi trang, + − phóng, R xoay`, onKeyDown: key, style: { height } },
                React.createElement("img", { src: cur.src, alt: cur.label || `Trang ${page + 1}`, style: { transform: `scale(${z}) rotate(${r}deg)` } })),
            pages.length > 1 ? React.createElement("div", { className: "hmt-sv-strip", role: "tablist", "aria-label": "Ch\u1ECDn trang" }, pages.map((p, i) => React.createElement("button", { key: p.id, type: "button", role: "tab", "aria-selected": i === page, className: "hmt-sv-th hmt-focus", onClick: () => go(i), "aria-label": `Trang ${i + 1}` },
                React.createElement("img", { src: p.src, alt: "" }),
                React.createElement("span", { className: "hmt-tabular" }, i + 1)))) : null));
    }
    /* QuickGrid (khuôn K14 · Bảng chấm nhanh trên laptop)
       Hàng = học sinh, cột = trạng thái / tiêu chí. Cột kiểu:
         radio  { field, value, hotkey }       — mỗi cột là một trạng thái của cùng một trường (điểm danh: phím 1–4)
         select { options[{value,label,hotkey,tone,icon}] } — một cột chọn bằng phím số (BTVN: 1–5)
         score  { min, max, decimals, disabled(vals) => lý do } — gõ số, Enter/Tab ghi
         text   — mở ngăn bên (onOpenRow) để viết dài; read { render(vals) } — chỉ đọc, hệ thống tính
       Ô trống (nét đứt, không chữ) khác hẳn điểm. Cột tên + hàng tiêu đề cố định khi cuộn. Lưu tự động (Đang lưu / Đã lưu / Chưa lưu được). */
    function QuickGrid({ rows, columns, values: vIn, onChange, onOpenRow, caption, maxHeight = 520, rowDisabled, rowNote, failOnSave, help = true, onSaveState }) {
        const [vals, setVals] = useState(() => JSON.parse(JSON.stringify(vIn || {})));
        const [act, setAct] = useState({ r: 0, c: 0 });
        const [edit, setEdit] = useState(null);
        const [err, setErr] = useState({});
        const [save, setSave] = useState(null);
        const tick = useRef(0);
        const refs = useRef({});
        const wrap = useRef(null);
        const focusIn = useRef(false);
        const groups = columns.some((c) => c.group);
        const field = (col) => col.field || col.key;
        const persist = (next) => {
            const t = ++tick.current;
            setSave("saving");
            onSaveState && onSaveState("saving");
            setTimeout(() => { if (t !== tick.current)
                return; const st = failOnSave && failOnSave(next) ? "error" : "saved"; setSave(st); onSaveState && onSaveState(st); }, 650);
            onChange && onChange(next);
        };
        const setVal = (rid, f, v) => { const next = { ...vals, [rid]: { ...(vals[rid] || {}), [f]: v } }; setVals(next); persist(next); };
        const dis = (r) => rowDisabled ? rowDisabled(rows[r], vals[rows[r].id] || {}) : null;
        const colDis = (r, c) => { const col = columns[c]; if (col.kind === "radio")
            return null; const d = dis(r); if (d)
            return d; return col.disabled ? col.disabled(vals[rows[r].id] || {}) : null; };
        const go = (r, c) => { const R = Math.max(0, Math.min(rows.length - 1, r)), C = Math.max(0, Math.min(columns.length - 1, c)); setAct({ r: R, c: C }); setEdit(null); };
        useEffect(() => { if (!focusIn.current)
            return; const el = refs.current[`${act.r}:${act.c}`]; if (el && !edit)
            el.focus(); }, [act, edit]);
        const commit = (r, c, text, move) => {
            const col = columns[c];
            const rid = rows[r].id;
            const t = String(text).trim().replace(",", ".");
            let v = null;
            let e = null;
            if (t) {
                if (!/^\d+([.]\d+)?$/.test(t))
                    e = "Chỉ nhập số";
                else {
                    const n = Number(t);
                    const dec = (t.split(".")[1] || "").length;
                    if (dec > (col.decimals || 0))
                        e = col.decimals ? `Tối đa ${col.decimals} chữ số sau dấu phẩy` : "Nhập số nguyên";
                    else if (n < col.min || n > col.max)
                        e = `Thang ${col.min}–${col.max}${n === 0 ? " · ô trống là chưa chấm, không có điểm 0" : ""}`;
                    else
                        v = n;
                }
            }
            const k = `${rid}:${col.key}`;
            if (e) {
                setErr({ ...err, [k]: e });
                return false;
            }
            const ne = { ...err };
            delete ne[k];
            setErr(ne);
            setVal(rid, field(col), v);
            setEdit(null);
            if (move === "down")
                go(r + 1, c);
            else if (move === "right")
                go(c === columns.length - 1 ? r + 1 : r, c === columns.length - 1 ? 0 : c + 1);
            else if (move === "left")
                go(r, c - 1);
            return true;
        };
        const hot = (r, key) => {
            const rid = rows[r].id;
            const col = columns[act.c];
            if (col.kind === "select") {
                const o = col.options.find((x) => x.hotkey === key);
                if (o && !colDis(r, act.c)) {
                    setVal(rid, field(col), o.value);
                    return true;
                }
            }
            const rc = columns.find((x) => x.kind === "radio" && x.hotkey === key);
            if (rc && (col.kind === "radio" || !col.kind || col.kind === "read" || col.kind === "text")) {
                setVal(rid, rc.field, rc.value);
                return true;
            }
            return false;
        };
        const onKey = (e, r, c) => {
            if (edit)
                return;
            const col = columns[c];
            const k = e.key;
            if (k === "ArrowDown") {
                e.preventDefault();
                go(r + 1, c);
            }
            else if (k === "ArrowUp") {
                e.preventDefault();
                go(r - 1, c);
            }
            else if (k === "ArrowRight") {
                e.preventDefault();
                go(r, c + 1);
            }
            else if (k === "ArrowLeft") {
                e.preventDefault();
                go(r, c - 1);
            }
            else if (k === "Tab") {
                const atEnd = !e.shiftKey && r === rows.length - 1 && c === columns.length - 1;
                const atStart = e.shiftKey && r === 0 && c === 0;
                if (atEnd || atStart)
                    return;
                e.preventDefault();
                if (e.shiftKey)
                    go(c === 0 ? r - 1 : r, c === 0 ? columns.length - 1 : c - 1);
                else
                    go(c === columns.length - 1 ? r + 1 : r, c === columns.length - 1 ? 0 : c + 1);
            }
            else if (k === "Enter" || k === "F2") {
                e.preventDefault();
                if (col.kind === "text")
                    onOpenRow && onOpenRow(rows[r]);
                else if (col.kind === "score" && !colDis(r, c))
                    setEdit({ r, c, text: vals[rows[r].id] && vals[rows[r].id][field(col)] != null ? String(vals[rows[r].id][field(col)]).replace(".", ",") : "" });
                else
                    go(r + 1, c);
            }
            else if (k === "Backspace" || k === "Delete") {
                e.preventDefault();
                if (col.kind === "radio" || col.kind === "select" || col.kind === "score") {
                    if (!colDis(r, c))
                        setVal(rows[r].id, field(col), null);
                }
            }
            else if (k === " " && col.kind === "radio") {
                e.preventDefault();
                setVal(rows[r].id, col.field, col.value);
            }
            else if (/^[0-9]$/.test(k)) {
                if (col.kind === "score") {
                    e.preventDefault();
                    if (!colDis(r, c))
                        setEdit({ r, c, text: k });
                }
                else if (hot(r, k))
                    e.preventDefault();
            }
        };
        const cell = (r, c) => {
            const col = columns[c];
            const row = rows[r];
            const v = (vals[row.id] || {})[field(col)];
            const d = colDis(r, c);
            const active = act.r === r && act.c === c;
            const k = `${row.id}:${col.key}`;
            const er = err[k];
            const common = { ref: (el) => (refs.current[`${r}:${c}`] = el), tabIndex: active ? 0 : -1, onFocus: () => { focusIn.current = true; if (!active)
                    setAct({ r, c }); }, onKeyDown: (e) => onKey(e, r, c), "data-active": active ? "true" : undefined };
            if (col.kind === "radio") {
                const on = v === col.value;
                return React.createElement("td", { key: col.key, className: "hmt-qg-c hmt-qg-radio", "data-tone": on ? col.tone : undefined, role: "gridcell", "aria-label": `${row.name}: ${col.label}${on ? " (đang chọn)" : ""}`, ...common, onClick: () => setVal(row.id, col.field, on ? null : col.value) },
                    React.createElement("span", { className: "hmt-qg-dot", "data-on": on ? "true" : undefined }, on ? React.createElement(Icon, { name: col.icon || "check" }) : null));
            }
            if (col.kind === "select") {
                const o = col.options.find((x) => x.value === v);
                return React.createElement("td", { key: col.key, className: "hmt-qg-c", role: "gridcell", "aria-label": `${row.name}: ${col.label} ${o ? o.label : "chưa chọn"}`, "aria-disabled": d ? true : undefined, ...common }, d ? React.createElement("span", { className: "hmt-qg-na" }, d) : o ? React.createElement(Badge, { tone: o.tone, icon: o.icon }, o.label) : React.createElement("span", { className: "hmt-qg-empty", "aria-hidden": "true" }));
            }
            if (col.kind === "score") {
                const editing = edit && edit.r === r && edit.c === c;
                return React.createElement("td", { key: col.key, className: "hmt-qg-c hmt-qg-num", role: "gridcell", "data-err": er ? "true" : undefined, "aria-disabled": d ? true : undefined, "aria-label": `${row.name}: ${col.label} ${v != null ? String(v).replace(".", ",") : "chưa chấm"}${er ? ". Lỗi: " + er : ""}`, ...common, onDoubleClick: () => !d && setEdit({ r, c, text: v != null ? String(v).replace(".", ",") : "" }) },
                    editing ? React.createElement("input", { className: "hmt-qg-input", autoFocus: true, inputMode: col.decimals ? "decimal" : "numeric", value: edit.text, "aria-label": `${col.label} của ${row.name}, thang ${col.min}–${col.max}`, onChange: (e) => setEdit({ ...edit, text: e.target.value }), onKeyDown: (e) => { if (e.key === "Enter") {
                            e.preventDefault();
                            commit(r, c, e.target.value, "down");
                        }
                        else if (e.key === "Tab") {
                            e.preventDefault();
                            commit(r, c, e.target.value, e.shiftKey ? "left" : "right");
                        }
                        else if (e.key === "Escape") {
                            e.preventDefault();
                            setEdit(null);
                            const ne = { ...err };
                            delete ne[k];
                            setErr(ne);
                        } }, onBlur: (e) => { if (edit)
                            commit(r, c, e.target.value, null); } })
                        : d ? React.createElement("span", { className: "hmt-qg-na" }, d) : v != null ? React.createElement("b", { className: "hmt-tabular" }, String(v).replace(".", ",")) : React.createElement("span", { className: "hmt-qg-empty", "aria-hidden": "true" }),
                    er ? React.createElement("span", { className: "hmt-qg-err", role: "alert" }, er) : null);
            }
            if (col.kind === "text")
                return React.createElement("td", { key: col.key, className: "hmt-qg-c hmt-qg-text", role: "gridcell", "aria-disabled": d ? true : undefined, ...common, onClick: () => !d && onOpenRow && onOpenRow(row) }, d ? React.createElement("span", { className: "hmt-qg-na" }, d) : v ? React.createElement("span", { className: "hmt-qg-snip" }, v) : React.createElement("span", { className: "hmt-qg-todo" },
                    React.createElement(Icon, { name: "edit" }),
                    " Vi\u1EBFt"));
            return React.createElement("td", { key: col.key, className: "hmt-qg-c hmt-qg-num", role: "gridcell", ...common }, col.render ? col.render(vals[row.id] || {}, row) : v);
        };
        const grpSpans = [];
        columns.forEach((c) => { const g = c.group || ""; const last = grpSpans[grpSpans.length - 1]; if (last && last.g === g)
            last.n++;
        else
            grpSpans.push({ g, n: 1 }); });
        return (React.createElement("div", { className: "hmt-qg" },
            React.createElement("div", { className: "hmt-qg-bar" },
                React.createElement("span", { className: "hmt-help" }, caption),
                React.createElement("span", { style: { marginLeft: "auto" } },
                    React.createElement(SaveState, { state: save || "saved" }))),
            React.createElement("div", { className: "hmt-qg-wrap", ref: wrap, style: { maxHeight } },
                React.createElement("table", { className: "hmt-qg-table", role: "grid", "aria-label": caption },
                    React.createElement("thead", null,
                        groups ? React.createElement("tr", { className: "hmt-qg-grp" },
                            React.createElement("th", { className: "hmt-qg-name", rowSpan: 2, scope: "col" }, "H\u1ECDc sinh"),
                            grpSpans.map((g, i) => React.createElement("th", { key: i, colSpan: g.n, scope: "colgroup" }, g.g))) : null,
                        React.createElement("tr", null,
                            groups ? null : React.createElement("th", { className: "hmt-qg-name", scope: "col" }, "H\u1ECDc sinh"),
                            columns.map((c) => React.createElement("th", { key: c.key, scope: "col", className: c.kind === "score" || c.kind === "radio" || c.kind === "read" ? "hmt-qg-num" : undefined, title: c.help },
                                c.label,
                                c.hotkey ? React.createElement("kbd", { className: "hmt-qg-kbd" }, c.hotkey) : null,
                                c.sub ? React.createElement("span", { className: "hmt-qg-sub" }, c.sub) : null)))),
                    React.createElement("tbody", null, rows.map((row, r) => {
                        const d = dis(r);
                        return (React.createElement("tr", { key: row.id, "data-active": act.r === r ? "true" : undefined, "data-disabled": d ? "true" : undefined },
                            React.createElement("th", { scope: "row", className: "hmt-qg-name" },
                                React.createElement("button", { type: "button", className: "hmt-qg-namebtn hmt-focus", onClick: () => onOpenRow && onOpenRow(row), "aria-label": `Mở chi tiết ${row.name}` },
                                    React.createElement("span", { className: "hmt-qg-idx hmt-tabular" }, r + 1),
                                    React.createElement("span", { style: { display: "grid", minWidth: 0 } },
                                        React.createElement("b", null, row.name),
                                        row.note || (rowNote && rowNote(row, vals[row.id] || {})) ? React.createElement("span", { className: "hmt-qg-rownote" }, row.note || rowNote(row, vals[row.id] || {})) : null))),
                            d && !columns.some((x) => x.kind === "radio") ? React.createElement("td", { className: "hmt-qg-c hmt-qg-off", colSpan: columns.length, role: "gridcell", "aria-disabled": "true", tabIndex: act.r === r ? 0 : -1, ref: (el) => { for (let c = 0; c < columns.length; c++)
                                    refs.current[`${r}:${c}`] = el; }, onFocus: () => { focusIn.current = true; }, onKeyDown: (e) => onKey(e, r, act.c) },
                                React.createElement("span", { className: "hmt-qg-na" },
                                    d,
                                    " \u00B7 kh\u00F4ng ch\u1EA5m")) : columns.map((_, c) => cell(r, c))));
                    })))),
            help ? React.createElement("p", { className: "hmt-qg-help" },
                React.createElement("kbd", null, "Tab"),
                "/",
                React.createElement("kbd", null, "\u2190\u2191\u2193\u2192"),
                " di chuy\u1EC3n \u00B7 ",
                columns.some((c) => c.kind === "radio") ? React.createElement(Fragment, null,
                    React.createElement("kbd", null, "1"),
                    "\u2013",
                    React.createElement("kbd", null, columns.filter((c) => c.kind === "radio").length),
                    " ch\u1ECDn tr\u1EA1ng th\u00E1i \u00B7 ") : null,
                columns.some((c) => c.kind === "select") ? React.createElement(Fragment, null,
                    React.createElement("kbd", null, "1"),
                    "\u2013",
                    React.createElement("kbd", null, Math.max(...columns.filter((c) => c.kind === "select").map((c) => c.options.length))),
                    " ch\u1ECDn tr\u1EA1ng th\u00E1i (\u1EDF c\u1ED9t tr\u1EA1ng th\u00E1i) \u00B7 ") : null,
                columns.some((c) => c.kind === "score") ? React.createElement(Fragment, null,
                    "g\u00F5 s\u1ED1 r\u1ED3i ",
                    React.createElement("kbd", null, "Enter"),
                    " (xu\u1ED1ng em sau) ho\u1EB7c ",
                    React.createElement("kbd", null, "Tab"),
                    " \u00B7 ") : null,
                React.createElement("kbd", null, "Delete"),
                " b\u1ECF tr\u1ED1ng \u00B7 b\u1EA5m t\u00EAn em m\u1EDF ng\u0103n b\u00EAn \u00B7 ",
                React.createElement("span", { className: "hmt-qg-empty hmt-qg-empty--inline", "aria-hidden": "true" }),
                " = ch\u01B0a ch\u1EA5m (kh\u00E1c \u0111i\u1EC3m)") : null));
    }
    /* ======================= RadarChart ======================= */
    function RadarChart({ axes, series, max = 5, size = 280, title }) {
        const [table, setTable] = useState(false);
        const c = size / 2, R = size / 2 - 40, n = axes.length, PAD = 70;
        const pt = (i, v) => { const a = -Math.PI / 2 + (i * 2 * Math.PI) / n; return [c + Math.cos(a) * R * (v / max), c + Math.sin(a) * R * (v / max)]; };
        const [hover, setHover] = useState(null);
        return (React.createElement("figure", { className: "hmt-radar" },
            React.createElement("figcaption", { className: "hmt-radar-cap" },
                React.createElement("span", null, title),
                React.createElement(Button, { variant: "tertiary", size: "sm", onClick: () => setTable(!table), "aria-pressed": table }, table ? "Xem biểu đồ" : "Xem bảng số")),
            React.createElement("ul", { className: "hmt-radar-legend" }, series.map((s) => React.createElement("li", { key: s.name, "data-kind": s.kind },
                React.createElement("span", { className: "hmt-radar-sw" }),
                s.name))),
            table ? (React.createElement("table", { className: "hmt-table hmt-radar-table" },
                React.createElement("caption", { className: "hmt-sr" }, title),
                React.createElement("thead", null,
                    React.createElement("tr", null,
                        React.createElement("th", { scope: "col" }, "Ti\u00EAu ch\u00ED"),
                        series.map((s) => React.createElement("th", { key: s.name, scope: "col", className: "hmt-num" }, s.name)))),
                React.createElement("tbody", null, axes.map((a, i) => React.createElement("tr", { key: a },
                    React.createElement("td", null, a),
                    series.map((s) => React.createElement("td", { key: s.name, className: "hmt-num" }, String(s.values[i]).replace(".", ",")))))))) : (React.createElement("svg", { viewBox: `${-PAD} 0 ${size + 2 * PAD} ${size}`, width: "100%", style: { maxWidth: size + 2 * PAD }, role: "img", "aria-label": `${title}. ${series.map((s) => s.name + ": " + axes.map((a, i) => `${a} ${s.values[i]}`).join(", ")).join(". ")}` },
                [1, 2, 3, 4, 5].map((k) => React.createElement("polygon", { key: k, className: "hmt-radar-grid", points: axes.map((_, i) => pt(i, k).join(",")).join(" ") })),
                axes.map((a, i) => { const [x, y] = pt(i, max); const [lx, ly] = pt(i, max + 0.9); return React.createElement("g", { key: a },
                    React.createElement("line", { className: "hmt-radar-axis", x1: c, y1: c, x2: x, y2: y }),
                    React.createElement("text", { className: "hmt-radar-lbl", x: lx, y: ly, textAnchor: Math.abs(lx - c) < 8 ? "middle" : lx > c ? "start" : "end", dominantBaseline: "middle" }, a)); }),
                series.map((s) => React.createElement("polygon", { key: s.name, className: "hmt-radar-area", "data-kind": s.kind, points: s.values.map((v, i) => pt(i, v).join(",")).join(" ") })),
                series.filter((s) => s.kind !== "ref").map((s) => s.values.map((v, i) => { const [x, y] = pt(i, v); return React.createElement("g", { key: s.name + i },
                    React.createElement("circle", { className: "hmt-radar-dot", cx: x, cy: y, r: 4 }),
                    React.createElement("circle", { cx: x, cy: y, r: 12, fill: "transparent", onMouseEnter: () => setHover({ x, y, t: `${axes[i]}: ${String(v).replace(".", ",")}` }), onMouseLeave: () => setHover(null) })); })),
                hover ? React.createElement("g", { pointerEvents: "none" },
                    React.createElement("rect", { className: "hmt-radar-tip", x: hover.x + 8, y: hover.y - 26, width: hover.t.length * 6.6 + 12, height: 22, rx: 4 }),
                    React.createElement("text", { className: "hmt-radar-tipt", x: hover.x + 14, y: hover.y - 11 }, hover.t)) : null))));
    }
    /* ======================= FileUpload ======================= */
    function FileUpload({ accept = "image/*,application/pdf", maxMB = 10, multiple = true, label = "Đính kèm", helper, mobile }) {
        const [files, setFiles] = useState([]);
        const [over, setOver] = useState(false);
        const inp = useRef(null);
        const cam = useRef(null);
        const add = (list) => {
            const arr = Array.from(list || []).map((f) => {
                const bad = f.size > maxMB * 1024 * 1024 ? `Quá ${maxMB} MB` : !/^image\/|application\/pdf/.test(f.type) ? "Chỉ nhận ảnh hoặc PDF" : null;
                return { id: Math.random().toString(36).slice(2), name: f.name, size: f.size, type: f.type, url: f.type.startsWith("image/") ? URL.createObjectURL(f) : null, progress: bad ? 0 : 0, error: bad };
            });
            setFiles((x) => [...x, ...arr]);
            arr.filter((a) => !a.error).forEach((a) => { let p = 0; const t = setInterval(() => { p += 20; setFiles((x) => x.map((y) => y.id === a.id ? { ...y, progress: Math.min(100, p) } : y)); if (p >= 100)
                clearInterval(t); }, 250); });
        };
        const addDemo = (kind) => {
            const demo = { ok: { name: "bai-lam-trang-1.jpg", size: 820000, type: "image/jpeg" }, pdf: { name: "de-kiem-tra.pdf", size: 1200000, type: "application/pdf" }, big: { name: "video-buoi-hoc.mp4", size: 52000000, type: "video/mp4" } }[kind];
            const f = new File([new Uint8Array(1)], demo.name, { type: demo.type });
            Object.defineProperty(f, "size", { value: demo.size });
            add([f]);
        };
        const kb = (n) => n > 1e6 ? `${(n / 1e6).toFixed(1).replace(".", ",")} MB` : `${Math.round(n / 1e3)} KB`;
        return (React.createElement("div", { className: "hmt-up" },
            React.createElement("span", { className: "hmt-label" }, label),
            mobile ? (React.createElement("div", { className: "hmt-up-mobile" },
                React.createElement(Button, { variant: "secondary", iconStart: "camera", fullWidth: true, onClick: () => cam.current.click() }, "Ch\u1EE5p \u1EA3nh"),
                React.createElement(Button, { variant: "secondary", iconStart: "image", fullWidth: true, onClick: () => inp.current.click() }, "Ch\u1ECDn \u1EA3nh, PDF"))) : (React.createElement("div", { className: "hmt-up-drop", "data-over": over ? "true" : undefined, onDragOver: (e) => { e.preventDefault(); setOver(true); }, onDragLeave: () => setOver(false), onDrop: (e) => { e.preventDefault(); setOver(false); add(e.dataTransfer.files); } },
                React.createElement(Icon, { name: "upload", size: 24 }),
                React.createElement("span", null,
                    "K\u00E9o th\u1EA3 \u1EA3nh ho\u1EB7c PDF v\u00E0o \u0111\u00E2y, ho\u1EB7c ",
                    React.createElement("button", { type: "button", className: "hmt-up-link hmt-focus", onClick: () => inp.current.click() }, "ch\u1ECDn t\u1EC7p")),
                React.createElement("span", { className: "hmt-help" }, helper || `Ảnh, PDF · tối đa ${maxMB} MB mỗi tệp`))),
            React.createElement("input", { ref: inp, type: "file", accept: accept, multiple: multiple, className: "hmt-sr", tabIndex: -1, onChange: (e) => { add(e.target.files); e.target.value = ""; } }),
            React.createElement("input", { ref: cam, type: "file", accept: "image/*", capture: "environment", className: "hmt-sr", tabIndex: -1, onChange: (e) => { add(e.target.files); e.target.value = ""; } }),
            React.createElement("div", { className: "hmt-demo-row", style: { gap: 6 } },
                React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } }, "Th\u1EED nhanh:"),
                React.createElement(Button, { variant: "tertiary", size: "sm", onClick: () => addDemo("ok") }, "+ \u1EA3nh"),
                React.createElement(Button, { variant: "tertiary", size: "sm", onClick: () => addDemo("pdf") }, "+ PDF"),
                React.createElement(Button, { variant: "tertiary", size: "sm", onClick: () => addDemo("big") }, "+ t\u1EC7p l\u1ED7i")),
            files.length ? React.createElement("ul", { className: "hmt-up-list" }, files.map((f) => (React.createElement("li", { key: f.id, className: "hmt-up-item", "data-error": f.error ? "true" : undefined },
                React.createElement("span", { className: "hmt-up-thumb" }, f.url ? React.createElement("img", { src: f.url, alt: "" }) : React.createElement(Icon, { name: f.type === "application/pdf" ? "file" : "paperclip" })),
                React.createElement("span", { className: "hmt-up-meta" },
                    React.createElement("span", { className: "hmt-up-name" }, f.name),
                    f.error ? React.createElement("span", { className: "hmt-err" },
                        React.createElement(Icon, { name: "xcircle" }),
                        " ",
                        f.error)
                        : f.progress < 100 ? React.createElement("span", { className: "hmt-up-prog" },
                            React.createElement("span", { className: "hmt-progress-track", style: { flex: 1 }, role: "progressbar", "aria-valuenow": f.progress, "aria-valuemin": 0, "aria-valuemax": 100, "aria-label": `Đang tải ${f.name}` },
                                React.createElement("span", { className: "hmt-progress-fill", style: { width: `${f.progress}%`, display: "block" } })),
                            React.createElement("span", { className: "hmt-tabular hmt-person-meta", style: { display: "inline" } },
                                f.progress,
                                "%"))
                            : React.createElement("span", { className: "hmt-person-meta" },
                                kb(f.size),
                                " \u00B7 \u0110\u00E3 t\u1EA3i l\u00EAn")),
                React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconOnly: "x", label: `Gỡ ${f.name}`, onClick: () => setFiles(files.filter((x) => x.id !== f.id)) }))))) : null));
    }
    /* ======================= TaskStepper (K12) ======================= */
    function TaskStepper({ title, steps, current, onStepChange, deadline, children, nav, footer }) {
        const idx = steps.findIndex((s) => s.id === current);
        const done = steps.filter((s) => s.status === "done").length;
        return (React.createElement("section", { className: "hmt-ts", "aria-label": title },
            React.createElement("div", { className: "hmt-ts-in" },
                React.createElement("header", { className: "hmt-ts-head" },
                    React.createElement("div", { className: "hmt-ts-top" },
                        React.createElement("span", { className: "hmt-ts-title" }, title),
                        deadline),
                    React.createElement("div", { className: "hmt-ts-prog", role: "progressbar", "aria-valuenow": done, "aria-valuemin": 0, "aria-valuemax": steps.length, "aria-valuetext": `Xong ${done}/${steps.length} bước` }, steps.map((s) => React.createElement("span", { key: s.id, className: "hmt-ts-seg", "data-state": s.id === current ? "current" : s.status }))),
                    React.createElement("ol", { className: "hmt-ts-steps" }, steps.map((s, i) => (React.createElement("li", { key: s.id },
                        React.createElement("button", { type: "button", className: "hmt-ts-step hmt-focus", "aria-current": s.id === current ? "step" : undefined, "data-state": s.id === current ? "current" : s.status, onClick: () => onStepChange && onStepChange(s.id) },
                            React.createElement("span", { className: "hmt-ts-n" }, s.status === "done" ? React.createElement(Icon, { name: "check" }) : i + 1),
                            React.createElement("span", { className: "hmt-ts-l" }, s.short || s.label),
                            React.createElement("span", { className: "hmt-ts-lf" }, s.label)))))),
                    React.createElement("p", { className: "hmt-ts-cur" },
                        "B\u01B0\u1EDBc ",
                        idx + 1,
                        "/",
                        steps.length,
                        " \u00B7 ",
                        React.createElement("b", null, steps[idx].label))),
                React.createElement("div", { className: "hmt-ts-body" }, children),
                React.createElement("footer", { className: "hmt-ts-foot" },
                    nav ? React.createElement("div", { className: "hmt-ts-nav" },
                        React.createElement(Button, { variant: "secondary", iconStart: "chevronLeft", disabled: !nav.hasPrev, onClick: nav.onPrev }, "Em tr\u01B0\u1EDBc"),
                        React.createElement("span", { className: "hmt-tabular hmt-ts-pos" },
                            nav.index,
                            "/",
                            nav.total),
                        React.createElement(Button, { variant: "secondary", iconEnd: "chevronRight", disabled: !nav.hasNext, onClick: nav.onNext }, "Em sau")) : null,
                    footer))));
    }
    /* ======================= SlaBadge (R-CS-08, R-GV-05) ======================= */
    function SlaBadge({ kind, hours, threshold = 4 }) {
        const h = hrs(hours);
        if (kind === "remaining")
            return React.createElement(Badge, { tone: hours <= threshold ? "warning" : "info", icon: "timer" },
                "C\u00F2n ",
                h);
        if (kind === "overdue")
            return React.createElement(Badge, { tone: "danger", solid: true, icon: "alert" },
                "Qu\u00E1 h\u1EA1n ",
                h);
        if (kind === "ontime")
            return React.createElement(Badge, { tone: "success", icon: "check" }, "\u0110\u00FAng h\u1EA1n");
        return React.createElement(Badge, { tone: "danger", icon: "clock" },
            "Tr\u1EC5 h\u1EA1n ",
            h);
    }
    /* ======================= ApprovalChain ======================= */
    function ApprovalChain({ levels, layout = "vertical" }) {
        const M = { approved: ["success", "check", "Đã duyệt"], rejected: ["danger", "x", "Từ chối"], pending: ["warning", "hourglass", "Chờ duyệt"], waiting: ["neutral", "clock", "Chưa tới lượt"] };
        return (React.createElement("ol", { className: cx("hmt-ac", layout === "horizontal" && "hmt-ac--h"), "aria-label": "Chu\u1ED7i duy\u1EC7t" }, levels.map((l, i) => {
            const [tone, ic, txt] = M[l.status];
            return (React.createElement("li", { key: i, className: "hmt-ac-item", "data-status": l.status },
                React.createElement("span", { className: "hmt-ac-dot", "data-tone": tone, "aria-hidden": "true" },
                    React.createElement(Icon, { name: ic })),
                React.createElement("div", { className: "hmt-ac-body" },
                    React.createElement("p", { className: "hmt-ac-role" },
                        React.createElement("b", null,
                            "C\u1EA5p ",
                            i + 1,
                            " \u00B7 ",
                            l.role)),
                    React.createElement("p", { className: "hmt-ac-line" },
                        React.createElement(Badge, { tone: tone, icon: false }, txt),
                        l.approver ? React.createElement("span", null,
                            " ",
                            l.approver) : null,
                        l.at ? React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } },
                            " \u00B7 ",
                            l.at) : null),
                    l.reason ? React.createElement("p", { className: "hmt-ac-reason" },
                        React.createElement("b", null, "L\u00FD do t\u1EEB ch\u1ED1i:"),
                        " ",
                        l.reason) : null)));
        })));
    }
    /* ======================= VersionedConfig ======================= */
    function VersionedConfig({ title, versions, rows, format = (v) => v }) {
        const active = versions.find((v) => v.status === "active");
        const upcoming = versions.find((v) => v.status === "scheduled");
        const [a, setA] = useState(active ? active.id : versions[0].id);
        const [b, setB] = useState(upcoming ? upcoming.id : versions[1] && versions[1].id);
        const [cmp, setCmp] = useState(false);
        const V = (id) => versions.find((v) => v.id === id);
        const ST = { active: ["success", "Đang dùng"], scheduled: ["info", "Sắp hiệu lực"], past: ["neutral", "Đã hết hiệu lực"] };
        return (React.createElement("section", { className: "hmt-vc", "aria-label": title },
            React.createElement("div", { className: "hmt-vc-cards" }, [active, upcoming].filter(Boolean).map((v) => (React.createElement("div", { key: v.id, className: "hmt-panel hmt-vc-card" },
                React.createElement(Badge, { tone: ST[v.status][0], icon: false }, ST[v.status][1]),
                React.createElement("p", { className: "hmt-vc-name" }, v.label),
                React.createElement("p", { className: "hmt-person-meta" },
                    "Hi\u1EC7u l\u1EF1c t\u1EEB ",
                    v.effectiveFrom,
                    v.effectiveTo ? ` đến ${v.effectiveTo}` : "",
                    " \u00B7 ",
                    v.author))))),
            React.createElement("div", { className: "hmt-demo-row", style: { alignItems: "flex-end" } },
                React.createElement(Field, { label: "So s\u00E1nh" },
                    React.createElement(Select, { value: a, onChange: (e) => setA(e.target.value), options: versions.map((v) => ({ value: v.id, label: v.label })) })),
                React.createElement(Field, { label: "v\u1EDBi" },
                    React.createElement(Select, { value: b, onChange: (e) => setB(e.target.value), options: versions.map((v) => ({ value: v.id, label: v.label })) })),
                React.createElement(Button, { variant: "secondary", iconStart: "gitCompare", onClick: () => setCmp(true) }, "So s\u00E1nh")),
            cmp ? (React.createElement("div", { className: "hmt-table-wrap" },
                React.createElement("table", { className: "hmt-table" },
                    React.createElement("caption", { className: "hmt-sr" },
                        "So s\u00E1nh ",
                        V(a).label,
                        " v\u00E0 ",
                        V(b).label),
                    React.createElement("thead", null,
                        React.createElement("tr", null,
                            React.createElement("th", { scope: "col" }, "M\u1EE5c"),
                            React.createElement("th", { scope: "col", className: "hmt-num" }, V(a).label),
                            React.createElement("th", { scope: "col", className: "hmt-num" }, V(b).label),
                            React.createElement("th", { scope: "col" }, "Kh\u00E1c bi\u1EC7t"))),
                    React.createElement("tbody", null, rows.map((r) => {
                        const x = r.values[a], y = r.values[b];
                        const ch = x !== y;
                        return (React.createElement("tr", { key: r.key, "data-changed": ch ? "true" : undefined },
                            React.createElement("td", null, r.label),
                            React.createElement("td", { className: "hmt-num" }, x == null ? "—" : format(x, r)),
                            React.createElement("td", { className: "hmt-num" }, y == null ? "—" : format(y, r)),
                            React.createElement("td", null, ch ? React.createElement("span", { className: "hmt-diff" }, x == null ? "Thêm mới" : y == null ? "Bỏ" : "Đã đổi") : React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } }, "Gi\u1EEF nguy\u00EAn"))));
                    }))))) : null,
            React.createElement("details", { className: "hmt-vc-hist" },
                React.createElement("summary", null,
                    "L\u1ECBch s\u1EED phi\u00EAn b\u1EA3n (",
                    versions.length,
                    ")"),
                React.createElement("ol", null, versions.map((v) => React.createElement("li", { key: v.id },
                    React.createElement(Badge, { tone: ST[v.status][0], icon: false }, ST[v.status][1]),
                    " ",
                    React.createElement("b", null, v.label),
                    " ",
                    React.createElement("span", { className: "hmt-person-meta", style: { display: "inline" } },
                        "\u00B7 t\u1EEB ",
                        v.effectiveFrom,
                        " \u00B7 ",
                        v.author,
                        " \u00B7 ",
                        v.note)))))));
    }
    /* ======================= PrintLayout (K13) ======================= */
    function PrintLayout({ size = "A4", logoSrc, campus, docTitle, code, date, status, party = [], columns, lines, totals = [], amountInWords, notes, signatures = [] }) {
        return (React.createElement("article", { className: "hmt-print", "data-size": size, "aria-label": `${docTitle} ${code}` },
            React.createElement("header", { className: "hmt-print-head" },
                logoSrc ? React.createElement("img", { className: "hmt-print-logo", src: logoSrc, alt: "H\u00F2a Ma To\u00E1n" }) : null,
                React.createElement("div", { className: "hmt-print-org" },
                    React.createElement("b", null,
                        "H\u00F2a Ma To\u00E1n \u00B7 ",
                        campus.code,
                        " ",
                        campus.name),
                    React.createElement("span", null, campus.address),
                    React.createElement("span", null,
                        "Hotline ",
                        campus.phone)),
                React.createElement("div", { className: "hmt-print-doc" },
                    React.createElement("h1", null, docTitle),
                    React.createElement("span", { className: "hmt-tabular" },
                        "S\u1ED1: ",
                        code),
                    React.createElement("span", null,
                        "Ng\u00E0y: ",
                        date),
                    status ? React.createElement("span", { className: "hmt-print-status" }, status) : null)),
            React.createElement("dl", { className: "hmt-print-party" }, party.map((p) => React.createElement(Fragment, { key: p.k },
                React.createElement("dt", null, p.k),
                React.createElement("dd", null, p.v)))),
            React.createElement("table", { className: "hmt-print-table" },
                React.createElement("thead", null,
                    React.createElement("tr", null,
                        React.createElement("th", null, "STT"),
                        columns.map((c) => React.createElement("th", { key: c.key, className: c.numeric ? "hmt-num" : undefined }, c.header)))),
                React.createElement("tbody", null, lines.map((l, i) => React.createElement("tr", { key: i },
                    React.createElement("td", null, i + 1),
                    columns.map((c) => React.createElement("td", { key: c.key, className: c.numeric ? "hmt-num" : undefined }, l[c.key]))))),
                React.createElement("tfoot", null, totals.map((t) => React.createElement("tr", { key: t.k, "data-strong": t.strong ? "true" : undefined },
                    React.createElement("td", { colSpan: columns.length, className: "hmt-num" }, t.k),
                    React.createElement("td", { className: "hmt-num" }, t.v))))),
            amountInWords ? React.createElement("p", { className: "hmt-print-words" },
                React.createElement("i", null,
                    "B\u1EB1ng ch\u1EEF: ",
                    amountInWords)) : null,
            notes ? React.createElement("p", { className: "hmt-print-notes" }, notes) : null,
            React.createElement("div", { className: "hmt-print-signs" }, signatures.map((s) => React.createElement("div", { key: s.role },
                React.createElement("b", null, s.role),
                React.createElement("span", null, "(K\u00FD, ghi r\u00F5 h\u1ECD t\u00EAn)"),
                React.createElement("span", { className: "hmt-print-signname" }, s.name || ""))))));
    }
    /* =====================================================================
       ĐỢT 5.2 · KHUÔN DÙNG LẠI (K01 khung CRM, K11 trang đơn, K09 thẻ số)
       ===================================================================== */
    /* Menu CRM 9 nhóm (đợt 5.1, P-15). Quyền thấy lấy từ cột Vai trò của bản đồ màn hình (P-19).
       Hàng: [nhóm, nhóm con, nhãn, mã màn, vai trò dùng, vai trò chỉ xem]. App thật dựng từ ma trận quyền QT-05. */
    const CRM_MENU_ROWS = [["Tổng quan", null, "Trang chủ", "CHUNG-14", "ADBMSACSKT", ""], ["Tổng quan", null, "Việc chờ tôi duyệt", "CHUNG-15", "ADBMKT", ""], ["Tuyển sinh", null, "Lead", "TS-01", "BMSACS", ""], ["Tuyển sinh", null, "Cơ hội", "TS-07", "BMSACS", ""], ["Tuyển sinh", null, "Lịch hẹn", "TS-11", "BMSACS", ""], ["Tuyển sinh", null, "Phiếu kiểm tra", "TS-16", "BMSACS", ""], ["Khách hàng", null, "Phụ huynh", "KH-01", "BMSACSKT", ""], ["Khách hàng", null, "Học sinh", "KH-04", "BMSACSKT", ""], ["Bán hàng và thu chi", null, "Báo giá", "BH-01", "BMSACS", ""], ["Bán hàng và thu chi", null, "Đơn hàng", "BH-06", "BMSACSKT", ""], ["Bán hàng và thu chi", null, "Phiếu thu", "TC-01", "BMSACSKT", ""], ["Bán hàng và thu chi", null, "Chờ kế toán duyệt", "TC-04", "KT", ""], ["Bán hàng và thu chi", null, "Khoản tiền vào", "TC-08", "ADBMKT", ""], ["Bán hàng và thu chi", null, "Công nợ", "TC-13", "BMSACSKT", ""], ["Bán hàng và thu chi", null, "Phiếu chi", "TC-10", "ADBMKT", ""], ["Bán hàng và thu chi", null, "Số dư khách hàng", "TC-14", "BMKT", ""], ["Bán hàng và thu chi", null, "Đối soát thu tiền", "TC-15", "KT", ""], ["Đào tạo", "Ghi danh", "Ghi danh", "GD-01", "BMSACSKT", ""], ["Đào tạo", "Ghi danh", "Chờ xếp lớp", "GD-06", "BMCS", ""], ["Đào tạo", "Ghi danh", "Sắp hết giờ", "GD-07", "BMSACS", ""], ["Đào tạo", "Lớp", "Lớp", "LOP-01", "BMSACS", ""], ["Đào tạo", "Lớp", "Lịch tuần cơ sở", "LOP-08", "BMCS", ""], ["Đào tạo", "Buổi học", "Buổi học", "BUOI-01", "BMCS", ""], ["Đào tạo", "Buổi học", "Điểm danh vận hành", "BUOI-11", "CS", ""], ["Đào tạo", "Buổi học", "Yêu cầu buổi", "BUOI-10", "BMCS", ""], ["Đào tạo", "Buổi học", "Buổi chưa Done", "BUOI-12", "BMCS", ""], ["Chăm sóc khách hàng", null, "Ticket", "CS-01", "ADBMSACSKT", ""], ["Chăm sóc khách hàng", null, "Nhận xét chờ gửi", "CS-16", "CS", ""], ["Chăm sóc khách hàng", null, "Phiếu tái tục", "TT-01", "BMSACS", ""], ["Báo cáo", null, "Tổng quan Ban giám đốc", "BC-01", "ADBM", ""], ["Báo cáo", null, "Giáo viên trễ hạn", "BC-08", "ADBM", ""], ["Báo cáo", null, "Giờ dạy giáo viên", "BC-09", "ADBMKT", ""], ["Báo cáo", null, "Báo cáo trên Looker", "LOOKER", "ADBMSACSKT", ""], ["Cấu hình", null, "Gói bán", "CH-01", "AD", ""], ["Cấu hình", null, "Bảng giá", "CH-03", "AD", ""], ["Cấu hình", null, "Chính sách chiết khấu", "CH-04", "AD", ""], ["Cấu hình", null, "Điều khoản thanh toán", "CH-09", "AD", ""], ["Cấu hình", null, "Chiến dịch marketing", "CH-08", "ADSA", ""], ["Cấu hình", null, "Khung chương trình", "CH-05", "AD", "BM"], ["Cấu hình", null, "Rubric nhận xét", "CH-07", "AD", ""], ["Cấu hình", null, "Ngày nghỉ lễ", "QT-14", "ADBM", ""], ["Cấu hình", null, "Người duyệt ticket", "QT-15", "AD", ""], ["Quản trị", null, "Người dùng", "QT-01", "AD", ""], ["Quản trị", null, "Vai trò", "QT-04", "AD", ""], ["Quản trị", null, "Ma trận quyền", "QT-05", "AD", ""], ["Quản trị", null, "Danh mục", "QT-06", "AD", ""], ["Quản trị", null, "Cơ sở và phòng học", "QT-08", "AD", ""], ["Quản trị", null, "Tham số nghiệp vụ", "QT-09", "AD", ""], ["Quản trị", null, "Công tắc tính năng", "QT-10", "AD", ""], ["Quản trị", null, "Giáo viên, trợ giảng", "QT-16", "ADBM", ""], ["Quản trị", null, "Tài khoản học sinh", "QT-13", "ADCS", ""], ["Quản trị", null, "Tài khoản phụ huynh", "QT-17", "ADCS", ""], ["Quản trị", null, "Nhật ký thao tác", "QT-11", "AD", ""], ["Quản trị", null, "Nhật ký đăng nhập, xuất file", "QT-12", "AD", ""]];
    const CRM_GROUP_ICON = { "Tổng quan": "home", "Tuyển sinh": "users", "Khách hàng": "userCheck", "Bán hàng và thu chi": "wallet", "Đào tạo": "graduation", "Chăm sóc khách hàng": "message", "Báo cáo": "layers", "Cấu hình": "settings", "Quản trị": "lock" };
    const ROLE_LABEL = { AD: "Admin", BM: "Trưởng cơ sở", SA: "Tuyển sinh", CS: "CSKH, vận hành lớp", KT: "Kế toán", GV: "Giáo viên", TG: "Trợ giảng" };
    const CAMPUSES = [
        { code: "CS1", name: "Nguyễn Chí Thanh", hasRooms: true }, { code: "CS2", name: "Đỗ Quang", hasRooms: true },
        { code: "CS3", name: "Hội sở", hasRooms: false }, { code: "CS4", name: "Hà Đông", hasRooms: true }, { code: "CS5", name: "Mỹ Đình", hasRooms: true },
    ];
    function menuFor(role) {
        const groups = [];
        CRM_MENU_ROWS.forEach(([g, sub, label, code, full, view]) => {
            const access = role === "AD" || full.includes(role) ? "full" : view.includes(role) ? "view" : null; // A-22: Admin làm được mọi màn CRM ở mọi cơ sở
            if (!access)
                return;
            let G = groups.find((x) => x.label === g);
            if (!G) {
                G = { id: g, label: g, icon: CRM_GROUP_ICON[g], subs: [] };
                groups.push(G);
            }
            let S = G.subs.find((x) => x.label === sub);
            if (!S) {
                S = { label: sub, items: [] };
                G.subs.push(S);
            }
            S.items.push({ id: code, label, access, external: code === "LOOKER" });
        });
        return groups;
    }
    function CrmNav({ groups, activeId, onNavigate, collapsed }) {
        const activeGroup = (groups.find((g) => g.subs.some((s) => s.items.some((i) => i.id === activeId))) || {}).id;
        const [open, setOpen] = useState(() => ({ [activeGroup]: true }));
        useEffect(() => { if (activeGroup)
            setOpen((o) => ({ ...o, [activeGroup]: true })); }, [activeGroup]);
        return (React.createElement("ul", { className: "hmt-cnav" }, groups.map((g) => {
            const isOpen = !!open[g.id];
            const hasActive = g.id === activeGroup;
            const head = (React.createElement("button", { type: "button", className: "hmt-cnav-g hmt-focus", "aria-expanded": collapsed ? undefined : isOpen, "data-active": hasActive ? "true" : undefined, "aria-label": collapsed ? g.label : undefined, onClick: () => collapsed ? onNavigate && onNavigate(g.subs[0].items[0].id) : setOpen({ ...open, [g.id]: !isOpen }) },
                React.createElement(Icon, { name: g.icon }),
                React.createElement("span", { className: "hmt-cnav-gl" }, g.label),
                !collapsed ? React.createElement(Icon, { name: "chevronDown", className: "hmt-cnav-chev" }) : null));
            return (React.createElement("li", { key: g.id },
                collapsed ? React.createElement(Tooltip, { content: g.label }, head) : head,
                !collapsed && isOpen ? (React.createElement("ul", { className: "hmt-cnav-items" }, g.subs.map((s) => (React.createElement(Fragment, { key: s.label || "_" },
                    s.label ? React.createElement("li", { className: "hmt-cnav-sub", "aria-hidden": "true" }, s.label) : null,
                    s.items.map((it) => (React.createElement("li", { key: it.id },
                        React.createElement("a", { href: "#", className: "hmt-cnav-i", "aria-current": it.id === activeId ? "page" : undefined, onClick: (e) => { e.preventDefault(); onNavigate && onNavigate(it.id); } },
                            React.createElement("span", null, it.label),
                            it.access === "view" ? React.createElement("span", { className: "hmt-cnav-tag" }, "Xem") : null,
                            it.external ? React.createElement(Icon, { name: "arrowRight", className: "hmt-cnav-ext", label: "m\u1EDF tab m\u1EDBi" }) : null,
                            it.badge ? React.createElement(CountBadge, { count: it.badge }) : null))))))))) : null));
        })));
    }
    /* K01 · Khung CRM (CHUNG-10). Cố định: menu trái, thanh trên. Thay đổi: vùng nội dung (children). */
    function AppShell({ role = "BM", user, campus, onCampusChange, activeId, onNavigate, notifications = 0, onSearch, onNotifications, multiPortal, onAccount, loading, mobile, children, badges = {}, defaultCollapsed = false }) {
        const [collapsed, setCollapsed] = useState(defaultCollapsed);
        const [drawer, setDrawer] = useState(false);
        const groups = useMemo(() => menuFor(role).map((g) => ({ ...g, subs: g.subs.map((s) => ({ ...s, items: s.items.map((i) => ({ ...i, badge: badges[i.id] })) })) })), [role, JSON.stringify(badges)]);
        const picker = role === "AD" || role === "KT";
        const nav = loading ? React.createElement("div", { className: "hmt-cnav-skel", "aria-hidden": "true" }, [70, 55, 80, 60, 75, 50, 65].map((w, i) => React.createElement(Skeleton, { key: i, width: `${w}%`, height: 14 })))
            : React.createElement(CrmNav, { groups: groups, activeId: activeId, onNavigate: (id) => { setDrawer(false); onNavigate && onNavigate(id); }, collapsed: collapsed && !mobile });
        const acct = (React.createElement(Popover, { label: "T\u00E0i kho\u1EA3n", placement: "bottom-end", trigger: React.createElement("button", { type: "button", className: "hmt-shell-acct hmt-focus" },
                React.createElement(Avatar, { name: user.name, size: "sm", decorative: true }),
                React.createElement("span", { className: "hmt-shell-acct-t" },
                    React.createElement("b", null, user.name),
                    React.createElement("small", null,
                        ROLE_LABEL[role],
                        " \u00B7 ",
                        user.campus)),
                React.createElement(Icon, { name: "chevronDown" })) }, (close) => React.createElement("ul", { className: "hmt-menu", style: { margin: -12 } },
            React.createElement("li", null,
                React.createElement("button", { onClick: () => { close(); onAccount && onAccount("profile"); } },
                    React.createElement(Icon, { name: "userCheck" }),
                    "H\u1ED3 s\u01A1 c\u00E1 nh\u00E2n")),
            multiPortal ? React.createElement("li", null,
                React.createElement("button", { onClick: () => { close(); onAccount && onAccount("portal"); } },
                    React.createElement(Icon, { name: "gitCompare" }),
                    "\u0110\u1ED5i sang c\u1ED5ng Gi\u00E1o vi\u00EAn")) : null,
            React.createElement("li", null,
                React.createElement("button", { onClick: () => { close(); onAccount && onAccount("logout"); } },
                    React.createElement(Icon, { name: "logout" }),
                    "\u0110\u0103ng xu\u1EA5t")))));
        return (React.createElement("div", { className: "hmt-shell", "data-mobile": mobile ? "true" : undefined },
            !mobile ? (React.createElement("nav", { className: "hmt-shell-side", "data-collapsed": collapsed ? "true" : undefined, "aria-label": "Menu ch\u00EDnh" },
                React.createElement("div", { className: "hmt-sidebar-head" },
                    React.createElement("span", { className: "hmt-wordmark" },
                        collapsed ? "HMT" : "Hòa Ma Toán",
                        !collapsed ? React.createElement("small", null, "CRM") : null)),
                React.createElement("div", { className: "hmt-shell-navwrap" }, nav),
                React.createElement("div", { className: "hmt-sidebar-foot" },
                    React.createElement(Button, { variant: "tertiary", neutral: true, size: "sm", iconStart: "sidebar", "aria-expanded": !collapsed, onClick: () => setCollapsed(!collapsed), iconOnly: collapsed ? "sidebar" : undefined, label: collapsed ? "Mở rộng menu" : undefined }, collapsed ? null : "Thu gọn")))) : null,
            React.createElement("div", { className: "hmt-shell-main" },
                React.createElement("header", { className: "hmt-shell-top" },
                    mobile ? React.createElement(Button, { variant: "tertiary", neutral: true, iconOnly: "menu", label: "M\u1EDF menu", onClick: () => setDrawer(true) }) : null,
                    mobile ? React.createElement("span", { className: "hmt-wordmark", style: { flex: 1 } }, "HMT \u00B7 CRM") : (React.createElement("button", { type: "button", className: "hmt-shell-search hmt-focus", onClick: onSearch },
                        React.createElement(Icon, { name: "search" }),
                        React.createElement("span", null, "T\u00ECm h\u1ECDc sinh, ph\u1EE5 huynh, lead, \u0111\u01A1n, phi\u1EBFu thu, l\u1EDBp\u2026"))),
                    mobile ? React.createElement(Button, { variant: "tertiary", neutral: true, iconOnly: "search", label: "T\u00ECm ki\u1EBFm", onClick: onSearch }) : null,
                    picker && !mobile ? (React.createElement("label", { className: "hmt-shell-campus" },
                        React.createElement("span", { className: "hmt-sr" }, "C\u01A1 s\u1EDF \u0111ang xem"),
                        React.createElement(Icon, { name: "mapPin" }),
                        React.createElement("select", { value: campus, onChange: (e) => onCampusChange && onCampusChange(e.target.value) },
                            React.createElement("option", { value: "ALL" }, "T\u1EA5t c\u1EA3 c\u01A1 s\u1EDF"),
                            CAMPUSES.filter((c) => c.hasRooms).map((c) => React.createElement("option", { key: c.code, value: c.code },
                                c.code,
                                " \u00B7 ",
                                c.name))))) : null,
                    React.createElement("span", { className: "hmt-shell-bell" },
                        React.createElement(Button, { variant: "tertiary", neutral: true, iconOnly: "bell", label: `Thông báo${notifications ? `, ${notifications} chưa đọc` : ""}`, onClick: onNotifications }),
                        React.createElement(CountBadge, { count: notifications, label: `${notifications} thông báo chưa đọc` })),
                    !mobile ? acct : null),
                React.createElement("main", { className: "hmt-shell-content", "aria-busy": loading || undefined }, children)),
            mobile ? (React.createElement(Drawer, { open: drawer, onClose: () => setDrawer(false), placement: "left", title: "H\u00F2a Ma To\u00E1n \u00B7 CRM", description: `${user.name} · ${ROLE_LABEL[role]} · ${user.campus}` },
                picker ? React.createElement(Field, { label: "C\u01A1 s\u1EDF \u0111ang xem" },
                    React.createElement(Select, { value: campus, onChange: (e) => onCampusChange && onCampusChange(e.target.value), options: [{ value: "ALL", label: "Tất cả cơ sở" }, ...CAMPUSES.filter((c) => c.hasRooms).map((c) => ({ value: c.code, label: `${c.code} · ${c.name}` }))] })) : null,
                nav,
                React.createElement("ul", { className: "hmt-menu", style: { borderTop: "1px solid var(--hmt-border)", marginTop: 8, paddingTop: 8 } },
                    React.createElement("li", null,
                        React.createElement("button", { onClick: () => onAccount && onAccount("profile") },
                            React.createElement(Icon, { name: "userCheck" }),
                            "H\u1ED3 s\u01A1 c\u00E1 nh\u00E2n")),
                    React.createElement("li", null,
                        React.createElement("button", { onClick: () => onAccount && onAccount("logout") },
                            React.createElement(Icon, { name: "logout" }),
                            "\u0110\u0103ng xu\u1EA5t"))))) : null));
    }
    /* Tiêu đề trang trong vùng nội dung */
    function PageHeader({ title, code, breadcrumb, meta, actions, children }) {
        return (React.createElement("div", { className: "hmt-ph" },
            breadcrumb ? React.createElement(Breadcrumb, { items: breadcrumb }) : null,
            React.createElement("div", { className: "hmt-ph-row" },
                React.createElement("div", { className: "hmt-ph-t" },
                    React.createElement("h1", null, title),
                    code ? React.createElement("span", { className: "hmt-ph-code" }, code) : null,
                    meta ? React.createElement("div", { className: "hmt-ph-meta" }, meta) : null),
                actions ? React.createElement("div", { className: "hmt-ph-actions" }, actions) : null),
            children));
    }
    /* K09 · Thẻ số (việc cần làm). Bấm mở danh sách lọc sẵn. */
    function StatTile({ label, value, hint, hintTone, icon, onOpen, linkLabel = "Mở danh sách", target, loading }) {
        if (loading)
            return React.createElement("div", { className: "hmt-stat", "aria-hidden": "true" },
                React.createElement(Skeleton, { width: "50%" }),
                React.createElement(Skeleton, { width: 56, height: 28 }),
                React.createElement(Skeleton, { width: "70%", height: 10 }));
        return (React.createElement("button", { type: "button", className: "hmt-stat hmt-focus", onClick: onOpen, "aria-label": `${label}: ${value}. ${hint || ""} ${linkLabel}` },
            React.createElement("span", { className: "hmt-stat-l" },
                icon ? React.createElement(Icon, { name: icon }) : null,
                label),
            React.createElement("span", { className: "hmt-stat-v hmt-tabular" }, value),
            hint ? React.createElement("span", { className: "hmt-stat-h", "data-tone": hintTone },
                hintTone ? React.createElement(Icon, { name: TONE_ICON[hintTone] || "info" }) : null,
                hint) : React.createElement("span", { className: "hmt-stat-h" }, "\u00A0"),
            React.createElement("span", { className: "hmt-stat-a" },
                linkLabel,
                target ? React.createElement("span", { className: "hmt-ph-code" }, target) : null,
                React.createElement(Icon, { name: "arrowRight" }))));
    }
    /* LineChart (đợt 5.7): biểu đồ đường 1–4 chuỗi, MỘT trục y. Chú giải luôn có khi ≥ 2 chuỗi, nhãn cuối đường,
       rê chuột / phím mũi tên hiện đường dọc + hộp số. Chuỗi 2 trở đi nét đứt để không dựa vào màu. Có bảng ẩn cho trình đọc màn hình. */
    function LineChart({ labels, series, format = (n) => String(n), axisFormat, height = 240, label, yMax: yMaxIn, tooltipTitle }) {
        const wrap = useRef(null);
        const [w, setW] = useState(720);
        const [hi, setHi] = useState(null);
        const tid = useId();
        useEffect(() => {
            const el = wrap.current;
            if (!el)
                return;
            const upd = () => setW(Math.max(280, el.clientWidth));
            upd();
            if (typeof ResizeObserver !== "undefined") {
                const ro = new ResizeObserver(upd);
                ro.observe(el);
                return () => ro.disconnect();
            }
        }, []);
        const COLORS = ["var(--hmt-cat-1)", "var(--hmt-cat-3)", "var(--hmt-cat-2)", "var(--hmt-cat-4)"];
        const S = series.map((x, i) => ({ ...x, color: x.color || COLORS[i % 4], dashed: x.dashed !== undefined ? x.dashed : i > 0 }));
        const n = labels.length;
        const all = S.flatMap((x) => x.values.filter((v) => v !== null && v !== undefined));
        const raw = yMaxIn || Math.max(1, ...all);
        const rough = raw / 5;
        const mag = Math.pow(10, Math.floor(Math.log10(rough)));
        const step0 = [1, 2, 2.5, 5, 10].map((k) => k * mag).find((st) => st >= rough) || mag * 10;
        const nT = Math.ceil(raw / step0);
        const yMax = step0 * nT;
        const ticks = Array.from({ length: nT + 1 }, (_, i) => i * step0);
        const endLab = S.length <= 4;
        const padL = 56, padR = endLab ? 120 : 16, padT = 12, padB = 28;
        const iw = w - padL - padR, ih = height - padT - padB;
        const X = (i) => padL + (n === 1 ? iw / 2 : (i * iw) / (n - 1));
        const Y = (v) => padT + ih - (v / yMax) * ih;
        const every = Math.ceil(n / Math.max(2, Math.floor(iw / 64)));
        const af = axisFormat || format;
        const pick = (clientX) => { const r = wrap.current.querySelector("svg").getBoundingClientRect(); const x = clientX - r.left; const i = Math.round(((x - padL) / iw) * (n - 1)); setHi(Math.max(0, Math.min(n - 1, i))); };
        const onKey = (e) => { if (e.key === "ArrowRight") {
            e.preventDefault();
            setHi(hi === null ? 0 : Math.min(n - 1, hi + 1));
        } if (e.key === "ArrowLeft") {
            e.preventDefault();
            setHi(hi === null ? n - 1 : Math.max(0, hi - 1));
        } if (e.key === "Escape")
            setHi(null); };
        // nhãn cuối đường: tránh chồng (cách tối thiểu 16px)
        const ends = S.map((x, i) => { let k = x.values.length - 1; while (k > 0 && (x.values[k] === null || x.values[k] === undefined))
            k--; return { i, k, y: Y(x.values[k]) }; }).sort((a, b) => a.y - b.y);
        for (let j = 1; j < ends.length; j++)
            if (ends[j].y - ends[j - 1].y < 16)
                ends[j].y = ends[j - 1].y + 16;
        const tipLeft = hi === null ? 0 : Math.min(Math.max(X(hi) + 12, 0), w - 200);
        return (React.createElement("figure", { className: "hmt-lc", "aria-label": label, style: { margin: 0 } },
            S.length > 1 ? React.createElement("div", { className: "hmt-lc-legend", "aria-hidden": "true" }, S.map((x) => React.createElement("span", { key: x.name },
                React.createElement("svg", { width: "24", height: "10" },
                    React.createElement("line", { x1: "1", y1: "5", x2: "23", y2: "5", stroke: x.color, strokeWidth: "2", strokeDasharray: x.dashed ? "5 3" : undefined, strokeLinecap: "round" })),
                x.name))) : null,
            React.createElement("div", { ref: wrap, className: "hmt-lc-plot", style: { position: "relative" } },
                React.createElement("svg", { width: w, height: height, role: "img", "aria-label": `${label}. Dùng phím mũi tên để xem từng mốc.`, tabIndex: 0, className: "hmt-focus", onKeyDown: onKey, onMouseMove: (e) => pick(e.clientX), onMouseLeave: () => setHi(null), onBlur: () => setHi(null), "aria-describedby": hi !== null ? tid : undefined },
                    ticks.map((t) => React.createElement("g", { key: t },
                        React.createElement("line", { x1: padL, x2: padL + iw, y1: Y(t), y2: Y(t), className: "hmt-lc-grid" }),
                        React.createElement("text", { x: padL - 8, y: Y(t), dy: "0.32em", textAnchor: "end", className: "hmt-lc-tick" }, af(t)))),
                    labels.map((l, i) => i % every === 0 || i === n - 1 ? React.createElement("text", { key: i, x: X(i), y: height - 8, textAnchor: "middle", className: "hmt-lc-tick" }, l) : null),
                    hi !== null ? React.createElement("line", { x1: X(hi), x2: X(hi), y1: padT, y2: padT + ih, className: "hmt-lc-cross" }) : null,
                    S.map((x) => {
                        const pts = x.values.map((v, i) => v === null || v === undefined ? null : `${X(i)},${Y(v)}`).filter(Boolean).join(" ");
                        return React.createElement("g", { key: x.name },
                            React.createElement("polyline", { points: pts, fill: "none", stroke: x.color, strokeWidth: "2", strokeLinejoin: "round", strokeLinecap: "round", strokeDasharray: x.dashed ? "6 4" : undefined }),
                            hi !== null && x.values[hi] !== null && x.values[hi] !== undefined ? React.createElement("circle", { cx: X(hi), cy: Y(x.values[hi]), r: "5", fill: x.color, stroke: "var(--hmt-surface)", strokeWidth: "2" }) : null);
                    }),
                    endLab ? ends.map((e) => { const x = S[e.i]; return React.createElement("text", { key: x.name, x: X(e.k) + 8, y: e.y, dy: "0.32em", className: "hmt-lc-end" }, x.short || x.name); }) : null),
                hi !== null ? React.createElement("div", { id: tid, role: "status", className: "hmt-lc-tip", style: { left: tipLeft, top: 8 } },
                    React.createElement("b", null, tooltipTitle ? tooltipTitle(hi) : labels[hi]),
                    S.map((x) => React.createElement("span", { key: x.name, className: "hmt-lc-tip-row" },
                        React.createElement("svg", { width: "16", height: "8", "aria-hidden": "true" },
                            React.createElement("line", { x1: "1", y1: "4", x2: "15", y2: "4", stroke: x.color, strokeWidth: "2", strokeDasharray: x.dashed ? "4 2" : undefined })),
                        x.name,
                        React.createElement("b", { className: "hmt-tabular" }, x.values[hi] === null || x.values[hi] === undefined ? "—" : format(x.values[hi]))))) : null),
            React.createElement("table", { className: "hmt-sr" },
                React.createElement("caption", null, label),
                React.createElement("thead", null,
                    React.createElement("tr", null,
                        React.createElement("th", null, "M\u1ED1c"),
                        S.map((x) => React.createElement("th", { key: x.name }, x.name)))),
                React.createElement("tbody", null, labels.map((l, i) => React.createElement("tr", { key: i },
                    React.createElement("td", null, l),
                    S.map((x) => React.createElement("td", { key: x.name }, x.values[i] === null || x.values[i] === undefined ? "—" : format(x.values[i])))))))));
    }
    /* K11 · Trang đơn: đăng nhập, lỗi, khoá. Không có menu. */
    function AuthLayout({ product = "crm", logoSrc, logoWhiteSrc, title, subtitle, children, footer, mobile, aside }) {
        return (React.createElement("div", { className: "hmt-auth", "data-product": product, "data-mobile": mobile ? "true" : undefined },
            !mobile ? (React.createElement("aside", { className: "hmt-auth-brand", "aria-hidden": "true" },
                logoWhiteSrc ? React.createElement("img", { src: logoWhiteSrc, alt: "", className: "hmt-auth-logo-w" }) : null,
                React.createElement("div", { className: "hmt-auth-pattern" }),
                aside)) : null,
            React.createElement("main", { className: "hmt-auth-main" },
                React.createElement("div", { className: "hmt-auth-card" },
                    logoSrc && mobile ? React.createElement("img", { src: logoSrc, alt: "H\u00F2a Ma To\u00E1n", className: "hmt-auth-logo" }) : null,
                    logoSrc && !mobile ? React.createElement("img", { src: logoSrc, alt: "H\u00F2a Ma To\u00E1n", className: "hmt-auth-logo hmt-auth-logo--sm" }) : null,
                    React.createElement("h1", { className: "hmt-auth-title" }, title),
                    subtitle ? React.createElement("p", { className: "hmt-auth-sub" }, subtitle) : null,
                    children),
                footer ? React.createElement("div", { className: "hmt-auth-foot" }, footer) : null)));
    }
    /* Chỗ đặt ô Turnstile của Cloudflare (giao diện thật do Cloudflare vẽ; DS chỉ giữ chỗ 300 × 65 và các trạng thái quanh nó). */
    function TurnstileSlot({ state = "verifying", onRetry }) {
        const M = { verifying: ["timer", "Đang xác minh bạn không phải robot…"], success: ["checkcircle", "Đã xác minh"], error: ["xcircle", "Chưa xác minh được."], expired: ["alert", "Phiên xác minh đã hết hạn."] };
        const [ic, t] = M[state];
        return (React.createElement("div", { className: "hmt-turnstile", "data-state": state, role: "group", "aria-label": "X\u00E1c minh kh\u00F4ng ph\u1EA3i robot (Turnstile)" },
            React.createElement(Icon, { name: ic }),
            React.createElement("span", { "aria-live": "polite" }, t),
            state === "error" || state === "expired" ? React.createElement(Button, { variant: "tertiary", size: "sm", onClick: onRetry }, "Th\u1EED l\u1EA1i") : null,
            React.createElement("small", null, "Turnstile")));
    }
    /* Ô nhập mã 6 số (xác thực hai bước) */
    function OtpInput({ length = 6, value = "", onChange, invalid, label = "Mã xác thực 6 số", autoFocus }) {
        const refs = useRef([]);
        useEffect(() => { if (autoFocus && refs.current[0])
            refs.current[0].focus(); }, []);
        const set = (i, ch) => { const v = (value.padEnd(length, " ").slice(0, i) + ch + value.padEnd(length, " ").slice(i + 1)).replace(/\s+$/, ""); onChange(v); };
        return (React.createElement("div", { className: "hmt-otp", role: "group", "aria-label": label, "data-invalid": invalid ? "true" : undefined }, Array.from({ length }, (_, i) => (React.createElement("input", { key: i, ref: (el) => (refs.current[i] = el), inputMode: "numeric", autoComplete: i === 0 ? "one-time-code" : "off", maxLength: 1, "aria-label": `Số thứ ${i + 1}`, "aria-invalid": invalid || undefined, value: (value[i] || "").trim(), onChange: (e) => { const d = e.target.value.replace(/\D/g, "").slice(-1); if (!d)
                return; set(i, d); if (i < length - 1)
                refs.current[i + 1].focus(); }, onKeyDown: (e) => { var _a; if (e.key === "Backspace") {
                e.preventDefault();
                set(i, " ");
                if (!((_a = value[i]) === null || _a === void 0 ? void 0 : _a.trim()) && i > 0)
                    refs.current[i - 1].focus();
            } if (e.key === "ArrowLeft" && i > 0)
                refs.current[i - 1].focus(); if (e.key === "ArrowRight" && i < length - 1)
                refs.current[i + 1].focus(); }, onPaste: (e) => { const d = (e.clipboardData.getData("text") || "").replace(/\D/g, "").slice(0, length); if (d) {
                e.preventDefault();
                onChange(d);
                refs.current[Math.min(d.length, length - 1)].focus();
            } } })))));
    }
    /* Mật khẩu có nút hiện/ẩn; PasswordRules liệt kê luật tối thiểu (S03-04: ≥ 8 ký tự, có chữ và số) */
    function PasswordInput({ value, onChange, invalid, autoComplete = "current-password", ...rest }) {
        const [show, setShow] = useState(false);
        return React.createElement(TextInput, { type: show ? "text" : "password", value: value, onChange: onChange, invalid: invalid, autoComplete: autoComplete, ...rest, trailing: React.createElement("button", { type: "button", className: "hmt-pw-toggle hmt-focus", "aria-pressed": show, onClick: () => setShow(!show) },
                show ? "Ẩn" : "Hiện",
                React.createElement("span", { className: "hmt-sr" }, " m\u1EADt kh\u1EA9u")) });
    }
    const PW_RULES = [["Ít nhất 8 ký tự", (v) => v.length >= 8], ["Có chữ cái", (v) => /[A-Za-zÀ-ỹ]/.test(v)], ["Có chữ số", (v) => /\d/.test(v)]];
    function PasswordRules({ value = "" }) {
        return React.createElement("ul", { className: "hmt-pwr", "aria-label": "Y\u00EAu c\u1EA7u m\u1EADt kh\u1EA9u" }, PW_RULES.map(([t, f]) => { const ok = f(value); return React.createElement("li", { key: t, "data-ok": ok ? "true" : undefined },
            React.createElement(Icon, { name: ok ? "check" : "x" }),
            t,
            React.createElement("span", { className: "hmt-sr" }, ok ? ": đạt" : ": chưa đạt")); }));
    }
    const passwordOk = (v) => PW_RULES.every(([, f]) => f(v));
    window.HMT = {
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
