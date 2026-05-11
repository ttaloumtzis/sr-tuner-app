/* global React, Win, Btn, IconBtn, Chip, Icon, Section, Banner, ImgPh */
// Start screen — project picker.

const WFStart = () => {
  const recents = [
    { name: "drone-footage-x4", model: "Real-ESRGAN x4", last: "2 hours ago",  size: "12,480 pairs", status: "training" },
    { name: "vintage-restore",  model: "SwinIR x2",       last: "yesterday",   size: "3,210 pairs",  status: "ready" },
    { name: "macro-microscope", model: "HAT-L x4",        last: "3 days ago",  size: "—",            status: "empty" },
    { name: "wildlife-cam-v2",  model: "BSRGAN x4",       last: "last week",   size: "8,640 pairs",  status: "ready" },
    { name: "test-anime-x4",    model: "Real-ESRGAN x4",  last: "Apr 12",      size: "1,200 pairs",  status: "archived" },
  ];

  return (
    <Win title="sr-tuner — welcome" height={720}>
      <div style={{ flex: 1, display: "grid", gridTemplateColumns: "1fr 1.2fr", minHeight: 0 }}>

        {/* left — actions */}
        <div className="col gap-24 p-24" style={{ borderRight: "1px solid var(--line)", justifyContent: "space-between" }}>
          <div className="col gap-20">
            <div className="col gap-4">
              <div className="row gap-6">
                <div style={{ width: 18, height: 18, border: "1px solid var(--ink)", borderRadius: 3, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: "IBM Plex Mono", fontSize: 10, fontWeight: 600 }}>SR</div>
                <span className="txt-sm soft">sr-tuner</span>
                <span className="chip" style={{ marginLeft: 4 }}>v0.4.2</span>
              </div>
              <div className="h1" style={{ marginTop: 12 }}>Train a super‑resolution<br/>model on your own data.</div>
              <div className="txt-sm muted" style={{ marginTop: 6, maxWidth: 380 }}>
                Pull frames from a video, tune a template, and watch it learn — no Python required.
              </div>
            </div>

            <div className="col gap-8" style={{ marginTop: 8 }}>
              <Btn primary lg icon="folder-plus">New project</Btn>
              <Btn lg icon="folder">Open project folder…</Btn>
              <Btn ghost icon="download">Import from .srtproj archive</Btn>
            </div>
          </div>

          <div className="col gap-6">
            <div className="label">Learn</div>
            <div className="row gap-6 wrap">
              <Chip icon="info">First model in 10 min</Chip>
              <Chip icon="video">Datasets from video</Chip>
              <Chip icon="cpu">Template reference</Chip>
            </div>
          </div>
        </div>

        {/* right — recents */}
        <div className="col gap-12 p-20" style={{ background: "var(--surface-2)" }}>
          <div className="between">
            <div className="label">Recent projects</div>
            <div className="row gap-6">
              <div className="field" style={{ width: 180, padding: "3px 8px" }}>
                <Icon name="search" size={11}/>
                <span className="grow txt-sm faint">Search projects…</span>
              </div>
              <IconBtn icon="filter" sm/>
            </div>
          </div>

          <div className="col gap-6">
            {recents.map((p, i) => (
              <div key={i} className="sk p-12 between" style={{ gap: 12, cursor: "pointer" }}>
                <div className="col gap-2" style={{ minWidth: 0, flex: 1 }}>
                  <div className="row gap-8">
                    <Icon name="folder" size={13}/>
                    <span style={{ fontWeight: 500, fontSize: 13 }}>{p.name}</span>
                    {p.status === "training" && <Chip kind="tint" icon="play">training</Chip>}
                    {p.status === "ready"    && <Chip kind="ok" icon="check">ready</Chip>}
                    {p.status === "empty"    && <Chip>no dataset</Chip>}
                    {p.status === "archived" && <Chip>archived</Chip>}
                  </div>
                  <div className="row gap-12 txt-xs muted">
                    <span>{p.model}</span>
                    <span>·</span>
                    <span className="mono">{p.size}</span>
                    <span>·</span>
                    <span>opened {p.last}</span>
                  </div>
                </div>
                <Icon name="chevron-right" size={14}/>
              </div>
            ))}
          </div>

          <div className="txt-xs muted" style={{ marginTop: 6, textAlign: "center" }}>
            Projects are folders. Move them anywhere — sr‑tuner finds the manifest.
          </div>
        </div>
      </div>
    </Win>
  );
};

window.WFStart = WFStart;
