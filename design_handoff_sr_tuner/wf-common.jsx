/* global React */
// Shared primitives — rebuilt for the clean grey utility look.

const { useState } = React;

const Icon = ({ name, size = 14, stroke = 1.6 }) => {
  const p = { width: size, height: size, viewBox: "0 0 24 24", fill: "none",
              stroke: "currentColor", strokeWidth: stroke,
              strokeLinecap: "round", strokeLinejoin: "round",
              style: { flex: "none" } };
  switch (name) {
    case "folder":   return <svg {...p}><path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>;
    case "folder-plus": return <svg {...p}><path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M12 11v6M9 14h6"/></svg>;
    case "plus":     return <svg {...p}><path d="M12 5v14M5 12h14"/></svg>;
    case "play":     return <svg {...p}><path d="M7 5l12 7-12 7z"/></svg>;
    case "pause":    return <svg {...p}><path d="M7 5v14M17 5v14"/></svg>;
    case "stop":     return <svg {...p}><rect x="6" y="6" width="12" height="12" rx="1"/></svg>;
    case "image":    return <svg {...p}><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-6-6-10 10"/></svg>;
    case "video":    return <svg {...p}><rect x="3" y="5" width="14" height="14" rx="2"/><path d="M21 8l-4 4 4 4z"/></svg>;
    case "cpu":      return <svg {...p}><rect x="5" y="5" width="14" height="14" rx="2"/><rect x="9" y="9" width="6" height="6"/><path d="M9 1v3M15 1v3M9 20v3M15 20v3M1 9h3M1 15h3M20 9h3M20 15h3"/></svg>;
    case "chart":    return <svg {...p}><path d="M3 20h18M5 16l4-6 4 3 6-9"/></svg>;
    case "save":     return <svg {...p}><path d="M5 5a2 2 0 0 1 2-2h9l4 4v12a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2z"/><path d="M8 3v5h8V3M8 14h8v6H8z"/></svg>;
    case "gear":     return <svg {...p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>;
    case "check":    return <svg {...p}><path d="M5 13l4 4L19 7"/></svg>;
    case "warn":     return <svg {...p}><path d="M12 3l10 18H2z"/><path d="M12 10v5M12 18.5v.1"/></svg>;
    case "lock":     return <svg {...p}><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 1 1 8 0v3"/></svg>;
    case "download": return <svg {...p}><path d="M12 4v12m0 0l-4-4m4 4l4-4M4 20h16"/></svg>;
    case "trash":    return <svg {...p}><path d="M4 7h16M10 11v6M14 11v6M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13M9 7V4h6v3"/></svg>;
    case "star":     return <svg {...p}><path d="M12 3l3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1z"/></svg>;
    case "wand":     return <svg {...p}><path d="M15 4l5 5L9 20l-5-5z"/><path d="M14 5l5 5"/></svg>;
    case "grid":     return <svg {...p}><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></svg>;
    case "stack":    return <svg {...p}><path d="M12 3l9 5-9 5-9-5z"/><path d="M3 12l9 5 9-5M3 17l9 5 9-5"/></svg>;
    case "scan":     return <svg {...p}><path d="M4 8V5a1 1 0 0 1 1-1h3M20 8V5a1 1 0 0 0-1-1h-3M4 16v3a1 1 0 0 0 1 1h3M20 16v3a1 1 0 0 1-1 1h-3"/><path d="M4 12h16"/></svg>;
    case "search":   return <svg {...p}><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>;
    case "chevron-down": return <svg {...p}><path d="M6 9l6 6 6-6"/></svg>;
    case "chevron-right": return <svg {...p}><path d="M9 6l6 6-6 6"/></svg>;
    case "arrow-right": return <svg {...p}><path d="M5 12h14M13 6l6 6-6 6"/></svg>;
    case "arrow-left":  return <svg {...p}><path d="M19 12H5M11 6l-6 6 6 6"/></svg>;
    case "x":         return <svg {...p}><path d="M6 6l12 12M18 6L6 18"/></svg>;
    case "drop":      return <svg {...p}><path d="M12 3l6 7a6 6 0 1 1-12 0z"/></svg>;
    case "list":      return <svg {...p}><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg>;
    case "refresh":   return <svg {...p}><path d="M3 12a9 9 0 0 1 15.5-6.3L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-15.5 6.3L3 16"/><path d="M3 21v-5h5"/></svg>;
    case "info":      return <svg {...p}><circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7v.5"/></svg>;
    case "more":      return <svg {...p}><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg>;
    case "filter":    return <svg {...p}><path d="M4 5h16l-6 8v6l-4-2v-4z"/></svg>;
    case "spark":     return <svg {...p}><path d="M5 12c2 0 2-6 4-6s2 10 4 10 2-8 4-8 2 4 4 4"/></svg>;
    default:          return <svg {...p}><circle cx="12" cy="12" r="9"/></svg>;
  }
};

const Win = ({ title = "sr-tuner", children, height = 760 }) => (
  <div className="win" style={{ width: "100%", height }}>
    <div className="titlebar">
      <div className="traffic"><div className="light r"/><div className="light y"/><div className="light g"/></div>
      <div className="title">{title}</div>
      <div style={{ flex: 1 }} />
    </div>
    <div className="body">{children}</div>
  </div>
);

const Btn = ({ children, icon, primary, ghost, danger, sm, lg, disabled }) => (
  <button className={"btn" + (primary ? " primary" : "") + (ghost ? " ghost" : "") + (danger ? " danger" : "") + (sm ? " sm" : "") + (lg ? " lg" : "")} disabled={disabled} aria-disabled={disabled ? "true" : undefined}>
    {icon && <Icon name={icon} size={lg ? 15 : sm ? 11 : 13} />}
    {children}
  </button>
);

const IconBtn = ({ icon, sm }) => (
  <button className={"btn icon" + (sm ? " sm" : "")}><Icon name={icon} size={sm ? 11 : 13}/></button>
);

const Chip = ({ children, kind, icon }) => (
  <span className={"chip" + (kind ? " " + kind : "")}>
    {icon && <Icon name={icon} size={10}/>}
    {children}
  </span>
);

const Field = ({ label, value, hint, disabled, suffix, w, mono }) => (
  <div className="col" style={{ width: w, gap: 0 }}>
    {label && <div className="field-label">{label}</div>}
    <div className={"field" + (disabled ? " disabled" : "")}>
      <span className={"grow" + (mono ? " mono" : "")}>{value}</span>
      {suffix}
    </div>
    {hint && <div className="txt-xs" style={{ marginTop: 3 }}>{hint}</div>}
  </div>
);

const Section = ({ title, right, children, style }) => (
  <div className="col gap-8" style={style}>
    <div className="between">
      <div className="label">{title}</div>
      {right}
    </div>
    {children}
  </div>
);

const Banner = ({ kind = "info", icon, title, children, action }) => (
  <div className={"banner " + kind}>
    {icon && <Icon name={icon} size={14}/>}
    <div className="col">
      {title && <b>{title}</b>}
      <div>{children}</div>
    </div>
    {action}
  </div>
);

const ImgPh = ({ label, style }) => (
  <div className="img-ph" style={style}><span>{label}</span></div>
);

// faked grid chart
const Chart = ({ height = 100, points, color = "var(--accent)", fill = true, secondPoints, secondColor = "var(--accent-2)", label, yLabel }) => {
  const pts = points || [];
  const w = 320;
  const h = height;
  const all = secondPoints ? [...pts, ...secondPoints] : pts;
  const max = Math.max(...all) * 1.05;
  const min = Math.min(...all) * 0.95;
  const range = max - min || 1;
  const toPath = (arr) => {
    const dx = w / (arr.length - 1);
    return arr.map((v, i) => `${i === 0 ? "M" : "L"}${(i*dx).toFixed(1)},${(h - ((v - min) / range) * (h - 12) - 6).toFixed(1)}`).join(" ");
  };
  const path = toPath(pts);
  const fillPath = fill ? `${path} L${w},${h} L0,${h} Z` : null;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" style={{ width: "100%", height: h, display: "block" }}>
      <defs>
        <pattern id="g" width="32" height="20" patternUnits="userSpaceOnUse">
          <path d="M 32 0 L 0 0 0 20" fill="none" stroke="currentColor" strokeOpacity="0.08" strokeWidth="1"/>
        </pattern>
        <linearGradient id={"grad-" + color.replace(/[^a-z]/gi,"")} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.18"/>
          <stop offset="100%" stopColor={color} stopOpacity="0"/>
        </linearGradient>
      </defs>
      <rect width={w} height={h} fill="url(#g)" />
      {fillPath && <path d={fillPath} fill={`url(#grad-${color.replace(/[^a-z]/gi,"")})`}/>}
      {secondPoints && <path d={toPath(secondPoints)} stroke={secondColor} strokeWidth="1.4" fill="none" strokeDasharray="3 3"/>}
      <path d={path} stroke={color} strokeWidth="1.6" fill="none"/>
      {label && <text x={w-6} y={14} textAnchor="end" fontFamily="IBM Plex Mono" fontSize="10" fill="currentColor" opacity="0.5">{label}</text>}
      {yLabel && <text x={4} y={12} fontFamily="IBM Plex Mono" fontSize="10" fill="currentColor" opacity="0.5">{yLabel}</text>}
    </svg>
  );
};

const Spark = ({ points, color = "var(--accent)", height = 26 }) => {
  const w = 100, h = height;
  const max = Math.max(...points), min = Math.min(...points);
  const range = max - min || 1;
  const dx = w / (points.length - 1);
  const path = points.map((v, i) => `${i === 0 ? "M" : "L"}${(i*dx).toFixed(1)},${(h - ((v - min) / range) * (h - 4) - 2).toFixed(1)}`).join(" ");
  return (
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" style={{ width: "100%", height: h, display: "block" }}>
      <path d={path} stroke={color} strokeWidth="1.4" fill="none"/>
    </svg>
  );
};

Object.assign(window, { Icon, Win, Btn, IconBtn, Chip, Field, Section, Banner, ImgPh, Chart, Spark });
