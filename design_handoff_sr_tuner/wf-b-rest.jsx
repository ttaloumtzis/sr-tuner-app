/* global React, Icon, Win, Btn, IconBtn, Chip, Field, Section, Banner, ImgPh, Chart, Spark, Shell */
// Checkpoints + Inference tabs + their empty/blocked states.

// =========================================================
// CHECKPOINTS TAB
// =========================================================
const CheckpointsTab = () => {
  const cks = [
    { name: "ckpt-ep42.pt",  ep: 42, psnr: 28.94, ssim: 0.871, lpips: 0.092, size: "67 MB", date: "12:42",       best: true,  star: true },
    { name: "ckpt-ep40.pt",  ep: 40, psnr: 28.82, ssim: 0.868, lpips: 0.094, size: "67 MB", date: "11:20" },
    { name: "ckpt-ep38.pt",  ep: 38, psnr: 28.71, ssim: 0.864, lpips: 0.091, size: "67 MB", date: "09:48",       bestLpips: true },
    { name: "ckpt-ep35.pt",  ep: 35, psnr: 28.42, ssim: 0.857, lpips: 0.099, size: "67 MB", date: "07:02" },
    { name: "ckpt-ep30.pt",  ep: 30, psnr: 27.91, ssim: 0.844, lpips: 0.108, size: "67 MB", date: "yesterday" },
    { name: "ckpt-ep25.pt",  ep: 25, psnr: 27.18, ssim: 0.823, lpips: 0.124, size: "67 MB", date: "yesterday" },
    { name: "ckpt-ep20.pt",  ep: 20, psnr: 26.42, ssim: 0.801, lpips: 0.141, size: "67 MB", date: "2 days ago" },
    { name: "ckpt-ep10.pt",  ep: 10, psnr: 24.05, ssim: 0.742, lpips: 0.198, size: "67 MB", date: "3 days ago", manual: true },
  ];
  const psnrSeries = cks.map(c => c.psnr).reverse();

  return (
    <Shell tab="checkpoints">
      <div className="col" style={{ height: "100%" }}>
        <div className="between p-12" style={{ borderBottom: "1px solid var(--line)" }}>
          <div className="row gap-12">
            <div className="col" style={{ gap: 0 }}>
              <div className="row gap-6"><span style={{ fontWeight: 600 }}>8 checkpoints</span><Chip kind="ok" icon="star">best ckpt-ep42.pt</Chip></div>
              <div className="txt-xs muted">run-003 · auto-pruned to top 3 + manual saves · 536 MB on disk</div>
            </div>
          </div>
          <div className="row gap-6">
            <Btn sm icon="folder">Show in folder</Btn>
            <Btn sm icon="download">Export best…</Btn>
            <Btn sm icon="play" primary>Continue from best</Btn>
          </div>
        </div>

        {/* PSNR over time strip */}
        <div className="p-12 col gap-4" style={{ borderBottom: "1px solid var(--line)" }}>
          <div className="row between txt-xs">
            <span className="muted">PSNR across saved checkpoints</span>
            <span className="mono">24.05 → 28.94 dB · +4.89</span>
          </div>
          <div className="sk p-6" style={{ color: "var(--accent)" }}>
            <Chart height={60} points={psnrSeries} fill={true}/>
          </div>
        </div>

        {/* table */}
        <div className="col" style={{ flex: 1, overflow: "auto" }}>
          <div className="row gap-0" style={{ padding: "6px 12px", borderBottom: "1px solid var(--line)", background: "var(--surface-2)", fontSize: 10, fontWeight: 600, color: "var(--muted)", letterSpacing: "0.08em", textTransform: "uppercase" }}>
            <div style={{ width: 24 }}/>
            <div style={{ width: 200 }}>name</div>
            <div style={{ width: 60 }}>epoch</div>
            <div style={{ width: 90 }}>psnr</div>
            <div style={{ width: 80 }}>ssim</div>
            <div style={{ width: 80 }}>lpips</div>
            <div className="grow">tags</div>
            <div style={{ width: 100 }}>saved</div>
            <div style={{ width: 70, textAlign: "right" }}>size</div>
            <div style={{ width: 100 }}/>
          </div>
          {cks.map((c, i) => (
            <div key={i} className="row gap-0" style={{ padding: "8px 12px", borderBottom: "1px solid var(--line-2)", background: c.best ? "var(--tint)" : "transparent", fontSize: 12, alignItems: "center" }}>
              <div style={{ width: 24, color: c.star ? "var(--warn)" : "var(--faint)" }}><Icon name="star" size={12}/></div>
              <div style={{ width: 200, fontWeight: c.best ? 600 : 500, fontFamily: "IBM Plex Mono", fontSize: 11.5 }}>{c.name}</div>
              <div style={{ width: 60 }} className="mono">{c.ep}</div>
              <div style={{ width: 90, color: c.best ? "var(--accent)" : "var(--ink)", fontWeight: c.best ? 600 : 400 }} className="mono">{c.psnr.toFixed(2)} dB</div>
              <div style={{ width: 80 }} className="mono">{c.ssim.toFixed(3)}</div>
              <div style={{ width: 80, color: c.bestLpips ? "var(--accent-2)" : "var(--ink)", fontWeight: c.bestLpips ? 600 : 400 }} className="mono">{c.lpips.toFixed(3)}</div>
              <div className="grow row gap-4">
                {c.best && <Chip kind="tint">best psnr</Chip>}
                {c.bestLpips && <Chip kind="ok">best perceptual</Chip>}
                {c.manual && <Chip>manual</Chip>}
              </div>
              <div style={{ width: 100, color: "var(--muted)" }}>{c.date}</div>
              <div style={{ width: 70, textAlign: "right" }} className="mono">{c.size}</div>
              <div style={{ width: 100 }} className="row gap-4">
                <IconBtn icon="wand" sm/>
                <IconBtn icon="play" sm/>
                <IconBtn icon="more" sm/>
              </div>
            </div>
          ))}
        </div>

        {/* footer compare */}
        <div className="between p-12" style={{ borderTop: "1px solid var(--line)", background: "var(--surface-2)" }}>
          <div className="txt-xs muted">Select 2 checkpoints to compare side‑by‑side ·  <span className="kbd">⌘</span><span className="kbd">click</span></div>
          <div className="row gap-6">
            <Btn ghost sm icon="trash">Prune older</Btn>
            <Btn sm icon="refresh">Compare side‑by‑side</Btn>
          </div>
        </div>
      </div>
    </Shell>
  );
};

// =========================================================
// CHECKPOINTS — EMPTY
// =========================================================
const CheckpointsEmptyTab = () => (
  <Shell tab="checkpoints">
    <div className="center" style={{ height: "100%", padding: 40 }}>
      <div className="empty" style={{ maxWidth: 460 }}>
        <div className="icon-wrap"><Icon name="save" size={16}/></div>
        <div style={{ fontWeight: 600, fontSize: 15, marginTop: 4 }}>No checkpoints yet</div>
        <div className="txt-sm muted">Checkpoints are model snapshots saved during training. The best ones become your model.</div>
        <div className="row gap-8" style={{ marginTop: 10 }}>
          <Btn primary sm icon="play">Start training →</Btn>
          <Btn sm icon="download">Import .pt file</Btn>
        </div>
      </div>
    </div>
  </Shell>
);

// =========================================================
// INFERENCE TAB — WORKING (before/after slider)
// =========================================================
const InferenceTab = () => (
  <Shell tab="inference">
    <div className="col" style={{ height: "100%" }}>
      <div className="between p-12" style={{ borderBottom: "1px solid var(--line)" }}>
        <div className="row gap-12">
          <Field label="Model" value="ckpt‑ep42.pt · best" suffix={<Icon name="chevron-down" size={12}/>} w={260}/>
          <Field label="Scale" value="× 4" mono w={80}/>
          <Field label="Tile"  value="auto · 384" mono w={140} hint="splits large images"/>
        </div>
        <div className="row gap-6">
          <Btn sm icon="folder">Batch folder…</Btn>
          <Btn sm icon="download">Save result</Btn>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", flex: 1, minHeight: 0 }}>
        {/* compare viewer */}
        <div className="col gap-10 p-14" style={{ borderRight: "1px solid var(--line)", overflow: "hidden" }}>
          <div className="row gap-6 between">
            <div className="row gap-6">
              <Chip kind="tint">before · 480 × 320</Chip>
              <Icon name="arrow-right" size={12}/>
              <Chip kind="ok">after · 1920 × 1280</Chip>
            </div>
            <div className="row gap-4">
              <Btn ghost sm icon="grid">2‑up</Btn>
              <Btn sm icon="more">Slider</Btn>
            </div>
          </div>

          {/* the slider viewer */}
          <div style={{ position: "relative", flex: 1, minHeight: 0, borderRadius: 4, overflow: "hidden", border: "1px solid var(--line)" }}>
            {/* LR side */}
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", background: "var(--surface-2)" }}>
              <div className="img-ph" style={{ width: "100%", height: "100%", border: "none", background: "transparent" }}>
                <span>LR · 480 × 320 (input)</span>
              </div>
            </div>
            {/* SR side — clipped */}
            <div style={{ position: "absolute", inset: 0, clipPath: "inset(0 0 0 52%)", background: "var(--surface)" }}>
              <div className="img-ph" style={{ width: "100%", height: "100%", border: "none", background: "transparent" }}>
                <span>SR · 1920 × 1280 (× 4 upscale)</span>
              </div>
            </div>
            {/* handle */}
            <div style={{ position: "absolute", top: 0, bottom: 0, left: "52%", width: 2, background: "var(--accent)", boxShadow: "0 0 0 1px rgba(255,255,255,0.4)" }}>
              <div style={{ position: "absolute", top: "50%", left: "50%", transform: "translate(-50%,-50%)", width: 28, height: 28, borderRadius: "50%", background: "var(--accent)", color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 1px 4px rgba(0,0,0,0.25)" }}>
                <Icon name="arrow-right" size={11}/>
              </div>
            </div>
            <div style={{ position: "absolute", top: 8, left: 8 }}><Chip kind="tint">BEFORE</Chip></div>
            <div style={{ position: "absolute", top: 8, right: 8 }}><Chip kind="ok">AFTER</Chip></div>
          </div>

          {/* film strip */}
          <div className="col gap-4">
            <div className="between"><div className="label">Recent</div><span className="txt-xs muted mono">3 / 12</span></div>
            <div className="row gap-6">
              {[0,1,2,3,4,5].map(i => (
                <div key={i} className={"img-ph" + (i === 2 ? "" : "")} style={{ width: 74, height: 50, borderColor: i === 2 ? "var(--accent)" : "var(--line)" }}><span>{i === 2 ? "now" : i + 1}</span></div>
              ))}
              <div className="img-ph dashed" style={{ width: 74, height: 50, border: "1px dashed var(--line)" }}><span>+ add</span></div>
            </div>
          </div>
        </div>

        {/* inspector */}
        <div className="col gap-12 p-14" style={{ overflow: "auto" }}>
          <Section title="Output">
            <Field label="Resolution" value="1920 × 1280" mono/>
            <Field label="Format"     value="PNG · 16 bit" suffix={<Icon name="chevron-down" size={12}/>}/>
            <Field label="Filename"   value="drone-shot-07_x4.png" mono/>
          </Section>

          <Section title="Estimated quality">
            <div className="sk p-10 col gap-4">
              <div className="row between"><span className="txt-xs muted">vs. bicubic</span><span className="mono" style={{ color: "var(--accent-2)" }}>+ 5.2 dB PSNR</span></div>
              <div className="row between"><span className="txt-xs muted">Sharpness gain</span><span className="mono">+ 38 %</span></div>
              <div className="row between"><span className="txt-xs muted">Inference time</span><span className="mono">2.4 s · GPU</span></div>
            </div>
          </Section>

          <Section title="Tuning">
            <div className="col gap-2">
              <div className="row between txt-xs"><span className="muted">Denoise strength</span><span className="mono">0.6</span></div>
              <div className="bar"><div className="fill" style={{ width: "60%" }}/></div>
            </div>
            <div className="col gap-2">
              <div className="row between txt-xs"><span className="muted">Detail boost</span><span className="mono">0.35</span></div>
              <div className="bar"><div className="fill" style={{ width: "35%" }}/></div>
            </div>
            <div className="col gap-2">
              <div className="row between txt-xs"><span className="muted">Color preserve</span><span className="mono">on</span></div>
              <div className="bar"><div className="fill" style={{ width: "100%" }}/></div>
            </div>
          </Section>

          <Section title="Batch">
            <div className="sk dashed p-10 center col gap-2 txt-xs muted">
              <Icon name="drop" size={14}/>
              <span>Drop a folder to process all</span>
            </div>
          </Section>
        </div>
      </div>
    </div>
  </Shell>
);

// =========================================================
// INFERENCE — BLOCKED (no usable checkpoint)
// =========================================================
const InferenceBlockedTab = () => (
  <Shell tab="inference">
    <div className="col gap-16 p-20" style={{ height: "100%" }}>
      <Banner kind="warn" icon="lock" title="Inference is locked until you have a trained checkpoint">
        Models need at least one saved checkpoint before they can upscale an image.
      </Banner>

      <div className="col gap-10">
        <div className="label">What you need</div>
        {[
          ["A dataset",   "rooftop‑pairs‑v3 · 12,480 pairs",  "done"],
          ["A model",     "Real‑ESRGAN x4 template",          "done"],
          ["A training run that reached at least 5 epochs", "no run yet", "todo"],
          ["A saved checkpoint",                              "0 / 1",    "todo"],
        ].map(([k, v, st], i) => (
          <div key={i} className="row gap-8" style={{ padding: "8px 12px", borderRadius: 4, border: "1px solid " + (st === "done" ? "var(--line)" : "var(--line)"), background: st === "done" ? "var(--tint-ok)" : "var(--surface-2)" }}>
            <Icon name={st === "done" ? "check" : "lock"} size={13} stroke={2}/>
            <span style={{ flex: 1, fontWeight: 500 }}>{k}</span>
            <span className="txt-xs muted">{v}</span>
            {st === "todo" && <Btn sm icon="arrow-right">Go</Btn>}
          </div>
        ))}
      </div>

      <div style={{ flex: 1 }}/>

      <div className="sk p-16 col gap-6">
        <div className="row gap-8"><Icon name="info" size={14}/><b>Why this gate?</b></div>
        <div className="txt-sm muted">An untrained model would just produce noise. We keep this tab inert until something useful exists — so you can't accidentally ship a broken result.</div>
      </div>
    </div>
  </Shell>
);

window.CheckpointsTab = CheckpointsTab;
window.CheckpointsEmptyTab = CheckpointsEmptyTab;
window.InferenceTab = InferenceTab;
window.InferenceBlockedTab = InferenceBlockedTab;
