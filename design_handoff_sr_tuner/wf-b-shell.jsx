/* global React, Icon, Win, Btn, IconBtn, Chip, Field, Section, Banner, ImgPh, Chart, Spark */
// Direction B — shell chrome + Overview + Dataset tab (with empty + video-import flow)

const Shell = ({ tab, project = "rooftop-x4", subtitle = "datasets · 2  ·  models · 1  ·  runs · 3", children, badge }) => {
  const tabs = [
    { id: "overview",    label: "Overview",    icon: "grid" },
    { id: "dataset",     label: "Dataset",     icon: "image" },
    { id: "model",       label: "Model",       icon: "stack" },
    { id: "training",    label: "Training",    icon: "gear" },
    { id: "live",        label: "Live",        icon: "chart" },
    { id: "checkpoints", label: "Checkpoints", icon: "save" },
    { id: "inference",   label: "Inference",   icon: "wand" },
  ];
  return (
    <Win title={`sr-tuner — ${project}.srtproj`}>
      <div className="col" style={{ flex: 1, minWidth: 0 }}>
        {/* project header */}
        <div className="row gap-12" style={{ padding: "10px 14px", borderBottom: "1px solid var(--line)" }}>
          <div className="row gap-8">
            <div style={{ width: 22, height: 22, borderRadius: 4, background: "var(--accent)", display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", fontFamily: "IBM Plex Mono", fontSize: 10, fontWeight: 600 }}>
              SR
            </div>
            <div className="col" style={{ gap: 0 }}>
              <div className="row gap-6"><span style={{ fontWeight: 600 }}>{project}</span><Icon name="chevron-down" size={11}/></div>
              <div className="txt-xs muted">{subtitle}</div>
            </div>
          </div>
          <div style={{ flex: 1 }} />
          <div className="row gap-8">
            <Chip icon="cpu">CUDA · RTX 4070</Chip>
            <div className="row gap-4 txt-xs muted"><div className="dot ok"/>backend ready</div>
            <IconBtn icon="gear" sm/>
          </div>
        </div>

        {/* tab bar */}
        <div className="row" style={{ padding: "0 8px", borderBottom: "1px solid var(--line)", background: "var(--surface-2)" }}>
          {tabs.map(t => (
            <div key={t.id} className={"tab" + (t.id === tab ? " active" : "") + (t.locked ? " locked" : "")}>
              <Icon name={t.icon} size={12}/>{t.label}
            </div>
          ))}
          <div style={{ flex: 1 }}/>
          {badge}
        </div>

        {/* tab content */}
        <div className="grow" style={{ minHeight: 0, overflow: "hidden", background: "var(--bg)" }}>
          {children}
        </div>

        {/* status bar */}
        <div className="row gap-12" style={{ padding: "4px 12px", borderTop: "1px solid var(--line)", background: "var(--surface-2)", fontSize: 11, color: "var(--muted)" }}>
          <span>v0.4.2</span>
          <span className="vdiv" style={{ height: 11 }}/>
          <span>~/Projects/rooftop-x4</span>
          <span className="vdiv" style={{ height: 11 }}/>
          <span>git: <span className="mono">main</span></span>
          <div style={{ flex: 1 }}/>
          <span>disk 41.2 GB free</span>
          <span className="vdiv" style={{ height: 11 }}/>
          <span>idle</span>
        </div>
      </div>
    </Win>
  );
};

// =========================================================
// OVERVIEW (project home)
// =========================================================
const OverviewTab = () => (
  <Shell tab="overview">
    <div className="col gap-16 p-20" style={{ height: "100%" }}>
      <div className="between">
        <div className="h2">rooftop‑x4</div>
        <div className="row gap-8">
          <Btn icon="folder" sm>Open folder</Btn>
          <Btn icon="play" primary sm>Resume training</Btn>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10 }}>
        <div className="metric"><div className="key">Dataset pairs</div><div className="val">12,480</div><div className="sub">+ 320 val</div></div>
        <div className="metric"><div className="key">Active model</div><div className="val" style={{ fontSize: 14 }}>Real‑ESRGAN x4</div><div className="sub">RRDB · 23 blocks</div></div>
        <div className="metric"><div className="key">Best PSNR</div><div className="val">28.94</div><div className="sub">ckpt @ ep 42</div></div>
        <div className="metric"><div className="key">Runs</div><div className="val">3</div><div className="sub">2 done · 1 paused</div></div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1fr", gap: 12, flex: 1, minHeight: 0 }}>
        <div className="sk p-12 col gap-8">
          <div className="between"><div className="label">Recent activity</div><Btn ghost sm>Open Live →</Btn></div>
          {[
            { t: "2m ago",  k: "Run",   v: "run-003 epoch 42 / 100 · psnr 28.94", icon: "play", kind: "tint" },
            { t: "1h ago",  k: "Ckpt",  v: "saved ckpt-ep42.pt (best val)", icon: "save", kind: "ok" },
            { t: "3h ago",  k: "Data",  v: "imported 1,840 frames from drone-flight-04.mp4", icon: "video" },
            { t: "yest.",   k: "Model", v: "swapped to Real‑ESRGAN x4 template", icon: "stack" },
            { t: "yest.",   k: "Run",   v: "run-002 stopped early — loss plateaued", icon: "warn", kind: "warn" },
          ].map((r, i) => (
            <div key={i} className="row gap-12" style={{ padding: "4px 0" }}>
              <span className="txt-xs muted mono" style={{ width: 54 }}>{r.t}</span>
              <Chip kind={r.kind} icon={r.icon}>{r.k}</Chip>
              <span className="txt-sm grow">{r.v}</span>
            </div>
          ))}
        </div>

        <div className="col gap-12">
          <div className="sk p-12 col gap-6">
            <div className="label">Next step</div>
            <div className="txt-sm">
              run‑003 is paused at <span className="mono">epoch 42</span>. Loss has been flat for ~6 epochs.
            </div>
            <div className="row gap-6">
              <Btn primary sm icon="play">Resume</Btn>
              <Btn sm icon="wand">Try inference</Btn>
              <Btn sm icon="gear">Tune LR</Btn>
            </div>
          </div>

          <div className="sk p-12 col gap-6">
            <div className="label">Loss · last 24h</div>
            <div style={{ color: "var(--accent)" }}>
              <Chart height={90} points={[2.10, 1.78, 1.42, 1.20, 1.05, 0.97, 0.93, 0.91, 0.90, 0.89, 0.89, 0.88, 0.88]} />
            </div>
            <div className="row between txt-xs muted"><span className="mono">2.10</span><span>plateau warning</span><span className="mono">0.88</span></div>
          </div>
        </div>
      </div>
    </div>
  </Shell>
);

// =========================================================
// DATASET (populated)
// =========================================================
const DatasetTab = () => {
  const sources = [
    { name: "drone-flight-04.mp4",      type: "video", pairs: 1840, status: "ok" },
    { name: "rooftop-batch-jan/",       type: "folder", pairs: 4120, status: "ok" },
    { name: "rooftop-batch-feb/",       type: "folder", pairs: 5860, status: "ok" },
    { name: "tourist-iphone.mov",       type: "video", pairs: 660,  status: "warn", note: "low motion · 12 dupes pruned" },
    { name: "old-archive-2019/",        type: "folder", pairs: 0,    status: "err",  note: "files unreadable" },
  ];

  return (
    <Shell tab="dataset">
      <div className="col" style={{ height: "100%" }}>
        {/* dataset header */}
        <div className="between p-12" style={{ borderBottom: "1px solid var(--line)" }}>
          <div className="row gap-12">
            <div className="col" style={{ gap: 0 }}>
              <div className="row gap-6"><span style={{ fontWeight: 600 }}>rooftop‑pairs‑v3</span><Chip kind="ok" icon="check">ready to train</Chip></div>
              <div className="txt-xs muted">12,480 train pairs · 320 val · 96×96 LR / 384×384 HR · degradation: realistic</div>
            </div>
          </div>
          <div className="row gap-6">
            <Btn sm icon="plus">Add source…</Btn>
            <Btn sm icon="scan">Re‑scan</Btn>
            <Btn sm icon="download">Export .zip</Btn>
          </div>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1.1fr", flex: 1, minHeight: 0 }}>
          {/* sources */}
          <div className="col gap-8 p-12" style={{ borderRight: "1px solid var(--line)", overflow: "hidden" }}>
            <div className="between">
              <div className="label">Sources</div>
              <div className="txt-xs muted">{sources.length} items</div>
            </div>
            <div className="col gap-4">
              {sources.map((s, i) => (
                <div key={i} className={"sk p-8 row gap-8" + (s.status === "err" ? " " : "")} style={{ alignItems: "flex-start", borderLeft: s.status === "ok" ? "3px solid var(--accent-2)" : s.status === "warn" ? "3px solid var(--warn)" : "3px solid var(--danger)" }}>
                  <Icon name={s.type === "video" ? "video" : "folder"} size={13}/>
                  <div className="col grow" style={{ gap: 1, minWidth: 0 }}>
                    <div className="row between gap-8">
                      <span className="txt-sm" style={{ fontWeight: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{s.name}</span>
                      <span className="mono txt-xs">{s.pairs.toLocaleString()} pairs</span>
                    </div>
                    {s.note && <div className="txt-xs muted">{s.note}</div>}
                  </div>
                  <IconBtn icon="more" sm/>
                </div>
              ))}
            </div>

            <div className="hdiv" style={{ margin: "4px 0" }}/>

            <Section title="Degradation pipeline" right={<Btn ghost sm icon="refresh">Re‑synthesize</Btn>}>
              <div className="col gap-4">
                {[
                  ["Blur",  "iso + aniso gaussian", "0.2 – 3.0 σ"],
                  ["Noise", "gaussian + poisson",   "σ 1 – 25"],
                  ["JPEG",  "compress + recompress", "Q 30 – 95"],
                  ["Down",  "bicubic / area / nearest", "× 4"],
                ].map(([k, what, range], i) => (
                  <div key={i} className="row gap-8 txt-sm" style={{ padding: "4px 8px", borderRadius: 3, background: "var(--surface-2)" }}>
                    <span className="mono txt-xs" style={{ width: 44, color: "var(--muted)" }}>{k}</span>
                    <span className="grow">{what}</span>
                    <span className="mono txt-xs muted">{range}</span>
                  </div>
                ))}
              </div>
            </Section>
          </div>

          {/* preview */}
          <div className="col gap-12 p-12" style={{ overflow: "hidden" }}>
            <div className="between">
              <div className="label">Preview · pair #4,213</div>
              <div className="row gap-4">
                <IconBtn icon="arrow-left" sm/>
                <span className="mono txt-xs">4213 / 12480</span>
                <IconBtn icon="arrow-right" sm/>
                <Btn ghost sm icon="refresh">shuffle</Btn>
              </div>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
              <div className="col gap-2">
                <div className="txt-xs muted mono">LR · 96×96 (degraded)</div>
                <ImgPh label="LR" style={{ aspectRatio: "1 / 1" }}/>
              </div>
              <div className="col gap-2">
                <div className="txt-xs muted mono">HR · 384×384 (target)</div>
                <ImgPh label="HR" style={{ aspectRatio: "1 / 1" }}/>
              </div>
            </div>

            <Section title="Histogram" right={<span className="txt-xs muted">L · A · B</span>}>
              <div className="sk p-8" style={{ color: "var(--accent)" }}>
                <Chart height={56} points={[3,8,14,22,30,38,44,42,36,28,22,16,10,6,3,2]} />
              </div>
            </Section>

            <Section title="Health checks">
              <div className="col gap-4">
                {[
                  ["Pairs aligned (no shift)", "ok",   "12,480 / 12,480"],
                  ["Brightness distribution",   "ok",   "balanced (kurt 2.8)"],
                  ["Near‑duplicate frames",     "warn", "84 found · auto‑pruned"],
                  ["Source resolution ≥ HR",    "ok",   "min 1080p"],
                  ["EXIF orientation",          "ok",   "normalized"],
                ].map(([k, st, v], i) => (
                  <div key={i} className="row gap-8 txt-sm" style={{ padding: "3px 8px" }}>
                    <Icon name={st === "ok" ? "check" : "warn"} size={11}/>
                    <span className="grow">{k}</span>
                    <span className="txt-xs muted">{v}</span>
                  </div>
                ))}
              </div>
            </Section>
          </div>
        </div>
      </div>
    </Shell>
  );
};

// =========================================================
// DATASET — EMPTY (no sources yet)
// =========================================================
const DatasetEmptyTab = () => (
  <Shell tab="dataset" project="new-project" subtitle="datasets · 0  ·  models · 0  ·  runs · 0">
    <div className="col gap-16 p-20" style={{ height: "100%" }}>
      <div className="col gap-2">
        <div className="h2">No dataset yet</div>
        <div className="txt-sm muted">Pick how you want to feed sr‑tuner image pairs. You can mix sources later.</div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12 }}>
        {[
          { icon: "video",  title: "Extract from video", body: "Sample frames from any .mp4, .mov, .mkv. Auto‑prune blur and dupes.", cta: "Pick video…", primary: true },
          { icon: "image",  title: "Folder of images",   body: "Point at a folder of high‑res shots. We'll synthesize the LR side.", cta: "Pick folder…" },
          { icon: "stack",  title: "Pre‑made pairs",     body: "Already have LR/HR pairs? Map two folders and we'll align them.", cta: "Map pairs…" },
        ].map((c, i) => (
          <div key={i} className="sk p-16 col gap-8" style={{ minHeight: 160 }}>
            <div className="row gap-8"><Icon name={c.icon} size={16}/><span style={{ fontWeight: 600 }}>{c.title}</span></div>
            <div className="txt-sm muted grow">{c.body}</div>
            <div><Btn primary={c.primary} sm icon="arrow-right">{c.cta}</Btn></div>
          </div>
        ))}
      </div>

      <div className="sk dashed p-20 col gap-6" style={{ alignItems: "center", textAlign: "center" }}>
        <Icon name="drop" size={18}/>
        <div style={{ fontWeight: 500 }}>… or drop video / folder anywhere on this window</div>
        <div className="txt-xs muted">supports .mp4 .mov .mkv .webm · folders of .png .jpg .tif</div>
      </div>

      <div style={{ flex: 1 }}/>

      <Banner kind="info" icon="info" title="What's a good dataset for SR?">
        500+ sharp high‑res frames, varied content (close‑ups, textures, edges), and consistent capture conditions.
        Beginners: start with one 60‑second 4K video — that's plenty.
      </Banner>
    </div>
  </Shell>
);

// =========================================================
// DATASET — CREATE FROM VIDEO (modal flow)
// =========================================================
const DatasetFromVideo = () => (
  <Shell tab="dataset">
    <div style={{ height: "100%", position: "relative" }}>
      {/* dimmed bg hint */}
      <div className="p-20" style={{ opacity: 0.35, pointerEvents: "none" }}>
        <div className="h2">rooftop‑pairs‑v3</div>
        <div className="sk p-12" style={{ marginTop: 8, height: 80 }}/>
      </div>

      {/* modal */}
      <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", background: "rgba(15,18,24,0.35)" }}>
        <div className="sk elev" style={{ width: 660, background: "var(--surface)" }}>
          <div className="between p-12" style={{ borderBottom: "1px solid var(--line)" }}>
            <div className="row gap-8"><Icon name="video" size={14}/><b>Extract frames from video</b></div>
            <IconBtn icon="x" sm/>
          </div>

          <div className="col gap-16 p-16">

            {/* step tracker */}
            <div className="row gap-4">
              {["Source", "Sampling", "Filters", "Review"].map((s, i) => (
                <React.Fragment key={i}>
                  <div className="row gap-6">
                    <div style={{
                      width: 18, height: 18, borderRadius: 999,
                      border: "1px solid " + (i <= 1 ? "var(--accent)" : "var(--line)"),
                      background: i < 1 ? "var(--accent)" : i === 1 ? "var(--tint)" : "var(--surface)",
                      color: i < 1 ? "#fff" : i === 1 ? "var(--accent)" : "var(--muted)",
                      display: "flex", alignItems: "center", justifyContent: "center",
                      fontSize: 10, fontFamily: "IBM Plex Mono", fontWeight: 600
                    }}>
                      {i < 1 ? <Icon name="check" size={10}/> : i + 1}
                    </div>
                    <span className="txt-sm" style={{ fontWeight: i === 1 ? 600 : 400, color: i === 1 ? "var(--ink)" : "var(--muted)" }}>{s}</span>
                  </div>
                  {i < 3 && <div style={{ flex: 1, height: 1, background: "var(--line)" }}/>}
                </React.Fragment>
              ))}
            </div>

            <div className="hdiv"/>

            {/* current step content — Sampling */}
            <div className="col gap-12">
              <div className="row gap-12 txt-sm">
                <Icon name="video" size={13}/>
                <span style={{ fontWeight: 500 }}>drone-flight-04.mp4</span>
                <span className="mono txt-xs muted">4K · 60 fps · 1m 22s · 4,920 frames</span>
              </div>

              <div className="col gap-6">
                <div className="field-label">Sampling strategy</div>
                <div className="row gap-6">
                  {[
                    ["Every N frames", true],
                    ["Scene change", false],
                    ["Time interval", false],
                  ].map(([l, on], i) => (
                    <div key={i} className={"sk p-8 grow center txt-sm"} style={{ borderColor: on ? "var(--accent)" : "var(--line)", background: on ? "var(--tint)" : "var(--surface)", color: on ? "var(--accent)" : "var(--ink-2)", fontWeight: on ? 500 : 400, cursor: "pointer" }}>{l}</div>
                  ))}
                </div>
              </div>

              <div className="row gap-12">
                <Field label="N (every Nth frame)" value="6" w={150} mono/>
                <Field label="Estimated yield" value="≈ 820 frames" w={180} mono disabled/>
                <div className="grow"/>
                <Field label="Output size" value="384 × 384 (HR)" w={170} mono/>
              </div>

              <Banner kind="info" icon="info">
                We'll skip frames that are <b>too similar</b> to ones we already kept (perceptual hash, threshold 4).
              </Banner>
            </div>
          </div>

          <div className="row p-12 between" style={{ borderTop: "1px solid var(--line)", background: "var(--surface-2)" }}>
            <Btn ghost sm>← Back</Btn>
            <div className="row gap-6">
              <span className="txt-xs muted">2 of 4</span>
              <Btn sm>Cancel</Btn>
              <Btn primary sm icon="arrow-right">Continue</Btn>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Shell>
);

window.Shell = Shell;
window.OverviewTab = OverviewTab;
window.DatasetTab = DatasetTab;
window.DatasetEmptyTab = DatasetEmptyTab;
window.DatasetFromVideo = DatasetFromVideo;
