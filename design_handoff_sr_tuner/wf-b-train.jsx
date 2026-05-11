/* global React, Icon, Win, Btn, IconBtn, Chip, Field, Section, Banner, ImgPh, Chart, Spark, Shell */
// Model tab + Training setup tab + Live tab + their empty/blocked states.

// =========================================================
// MODEL TAB
// =========================================================
const ModelTab = () => {
  const templates = [
    { id: "esrgan", name: "Real‑ESRGAN x4",    arch: "RRDB · 23 blocks",     size: "16.7 M params", best: "photos · drone · realistic", speed: "medium", on: true },
    { id: "swinir", name: "SwinIR x2",          arch: "Swin Transformer",     size: "11.8 M params", best: "documents · text · line art", speed: "slow" },
    { id: "hatl",   name: "HAT‑L x4",           arch: "Hybrid Attention",     size: "20.8 M params", best: "highest quality, big GPU", speed: "slow" },
    { id: "bsrgan", name: "BSRGAN x4",          arch: "RRDB · degradation",   size: "16.7 M params", best: "old photos · scans", speed: "medium" },
    { id: "edsr",   name: "EDSR (light) x2",    arch: "Residual blocks · 16", size: "1.5 M params",  best: "fast iteration · low VRAM", speed: "fast" },
  ];

  return (
    <Shell tab="model">
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1.1fr", height: "100%" }}>
        {/* templates list */}
        <div className="col" style={{ borderRight: "1px solid var(--line)", overflow: "hidden" }}>
          <div className="between p-12" style={{ borderBottom: "1px solid var(--line)" }}>
            <div className="col" style={{ gap: 0 }}>
              <div className="label">Model templates</div>
              <div className="txt-xs muted">Pick one to start from — you can swap later</div>
            </div>
            <div className="row gap-6">
              <Btn ghost sm icon="filter">Filter</Btn>
              <Btn ghost sm icon="download">Import…</Btn>
            </div>
          </div>

          <div className="col gap-6 p-12" style={{ overflow: "auto" }}>
            {templates.map(t => (
              <div key={t.id} className="sk p-12 col gap-6" style={{ borderColor: t.on ? "var(--accent)" : "var(--line)", borderWidth: t.on ? 2 : 1, background: t.on ? "var(--tint)" : "var(--surface)" }}>
                <div className="between">
                  <div className="row gap-8"><Icon name="stack" size={13}/><span style={{ fontWeight: 600 }}>{t.name}</span></div>
                  {t.on
                    ? <Chip kind="tint" icon="check">selected</Chip>
                    : <Btn sm>Use</Btn>}
                </div>
                <div className="txt-xs muted">{t.arch} · {t.size}</div>
                <div className="row gap-6 wrap">
                  <Chip>{t.best}</Chip>
                  <Chip kind={t.speed === "fast" ? "ok" : t.speed === "slow" ? "warn" : ""}>{t.speed} on RTX 4070</Chip>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* details + architecture */}
        <div className="col p-12 gap-12" style={{ overflow: "hidden" }}>
          <div className="between">
            <div className="col" style={{ gap: 0 }}>
              <div className="h2" style={{ fontSize: 18 }}>Real‑ESRGAN x4</div>
              <div className="txt-xs muted">based on Wang et al. · realistic image SR with degradation pretraining</div>
            </div>
            <div className="row gap-6">
              <Btn sm icon="refresh">Reset to defaults</Btn>
              <Btn primary sm icon="check">Save as model</Btn>
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6 }}>
            {[
              ["Scale factor", "× 4"],
              ["Params", "16.7 M"],
              ["VRAM (train)", "~8.2 GB"],
              ["Input crop", "96 px"],
            ].map(([k, v], i) => (
              <div key={i} className="metric"><div className="key">{k}</div><div className="val" style={{ fontSize: 14 }}>{v}</div></div>
            ))}
          </div>

          <Section title="Architecture (RRDB · 23 blocks)">
            <div className="sk p-12 row gap-4 wrap" style={{ alignItems: "stretch" }}>
              <div className="col center" style={{ width: 56, padding: 6, border: "1px solid var(--line)", borderRadius: 3, background: "var(--surface-2)" }}>
                <div className="mono txt-xs muted">in</div>
                <div className="txt-sm">conv</div>
                <div className="mono txt-xs muted">3→64</div>
              </div>
              <div className="center" style={{ color: "var(--muted)" }}><Icon name="chevron-right" size={12}/></div>
              {[1,2,3,4,5,6].map(i => (
                <div key={i} className="col center" style={{ width: 52, padding: 6, border: "1px solid var(--line)", borderRadius: 3 }}>
                  <div className="mono txt-xs muted">RRDB</div>
                  <div className="txt-sm">#{i}</div>
                </div>
              ))}
              <div className="center txt-xs muted" style={{ padding: 6 }}>… 17 more …</div>
              <div className="center" style={{ color: "var(--muted)" }}><Icon name="chevron-right" size={12}/></div>
              <div className="col center" style={{ width: 64, padding: 6, border: "1px solid var(--line)", borderRadius: 3, background: "var(--surface-2)" }}>
                <div className="mono txt-xs muted">upsample</div>
                <div className="txt-sm">×4</div>
              </div>
              <div className="center" style={{ color: "var(--muted)" }}><Icon name="chevron-right" size={12}/></div>
              <div className="col center" style={{ width: 56, padding: 6, border: "1px solid var(--line)", borderRadius: 3, background: "var(--tint)" }}>
                <div className="mono txt-xs" style={{ color: "var(--accent)" }}>out</div>
                <div className="txt-sm">conv</div>
                <div className="mono txt-xs muted">64→3</div>
              </div>
            </div>
          </Section>

          <Section title="Hyperparameters · advanced">
            <div className="sk p-12" style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 10 }}>
              <Field label="num RRDB blocks" value="23" mono/>
              <Field label="growth channels" value="32" mono/>
              <Field label="features"  value="64" mono/>
              <Field label="upsampler"  value="pixel‑shuffle ×2 → ×2" mono/>
              <Field label="activation" value="LeakyReLU 0.2" mono/>
              <Field label="init"       value="kaiming · gain 0.1" mono/>
            </div>
            <div className="row gap-6">
              <Chip icon="info">Defaults match the published paper for x4 SR.</Chip>
            </div>
          </Section>

          <div style={{ flex: 1 }}/>
          <Banner kind="info" icon="info">
            Swapping templates is non‑destructive — your dataset and runs are untouched.
          </Banner>
        </div>
      </div>
    </Shell>
  );
};

// =========================================================
// TRAINING SETUP TAB
// =========================================================
const TrainingTab = () => (
  <Shell tab="training">
    <div className="col" style={{ height: "100%" }}>
      <div className="between p-12" style={{ borderBottom: "1px solid var(--line)" }}>
        <div className="col" style={{ gap: 0 }}>
          <div className="row gap-6"><span style={{ fontWeight: 600 }}>run‑003</span><Chip kind="warn" icon="pause">paused @ ep 42</Chip></div>
          <div className="txt-xs muted">Real‑ESRGAN x4 · rooftop‑pairs‑v3 · started 4 days ago</div>
        </div>
        <div className="row gap-6">
          <Btn sm icon="folder">All runs</Btn>
          <Btn sm icon="refresh">Clone settings</Btn>
          <Btn primary sm icon="play">Resume training</Btn>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", flex: 1, minHeight: 0, gap: 0 }}>
        {/* col 1 — basics */}
        <div className="col gap-14 p-14" style={{ borderRight: "1px solid var(--line)" }}>
          <Section title="Basics">
            <Field label="Run name"   value="run‑003"/>
            <Field label="Dataset"    value="rooftop‑pairs‑v3 (12,480 / 320)" disabled/>
            <Field label="Model"      value="Real‑ESRGAN x4" disabled/>
            <Field label="Mode"       value="fine‑tune from ckpt‑ep42.pt" suffix={<Icon name="chevron-down" size={12}/>}/>
          </Section>

          <Section title="Schedule">
            <Field label="Max epochs"  value="100" mono/>
            <Field label="Batch size"  value="16" mono hint="~7.4 GB VRAM at 96px crop"/>
            <Field label="Crop size"   value="96 px (LR) → 384 px (HR)" mono/>
            <Field label="Workers"     value="6" mono/>
          </Section>
        </div>

        {/* col 2 — optimizer & loss */}
        <div className="col gap-14 p-14" style={{ borderRight: "1px solid var(--line)" }}>
          <Section title="Optimizer">
            <Field label="Type"            value="Adam" suffix={<Icon name="chevron-down" size={12}/>}/>
            <Field label="Learning rate"   value="2e‑4 → 1e‑5 (cosine)" mono/>
            <Field label="Betas"           value="(0.9, 0.999)" mono/>
            <Field label="Weight decay"    value="0" mono/>
          </Section>

          <Section title="Loss">
            <div className="col gap-4">
              {[
                ["L1 (pixel)",     "1.00", true],
                ["VGG perceptual", "0.10", true],
                ["GAN (relativistic)", "0.005", true],
                ["FFT", "0.00", false],
              ].map(([k, w, on], i) => (
                <div key={i} className="row gap-8 txt-sm" style={{ padding: "5px 8px", border: "1px solid " + (on ? "var(--line)" : "var(--line-2)"), borderRadius: 3, background: on ? "var(--surface)" : "transparent", opacity: on ? 1 : 0.55 }}>
                  <div className="dot" style={{ background: on ? "var(--accent)" : "var(--faint)" }}/>
                  <span className="grow">{k}</span>
                  <span className="mono txt-xs">weight {w}</span>
                </div>
              ))}
            </div>
          </Section>
        </div>

        {/* col 3 — validation + advanced */}
        <div className="col gap-14 p-14">
          <Section title="Validation">
            <Field label="Every"           value="2 epochs" mono/>
            <Field label="Metrics"         value="PSNR · SSIM · LPIPS" mono/>
            <Field label="Sample previews" value="8 fixed pairs" mono/>
          </Section>

          <Section title="Checkpoints">
            <Field label="Save every" value="5 epochs" mono/>
            <Field label="Keep best"  value="by val PSNR · top 3" mono/>
            <Field label="EMA"        value="enabled · decay 0.999" mono/>
          </Section>

          <Section title="Estimate">
            <div className="sk p-12 col gap-4">
              <div className="row between"><span className="txt-sm muted">Time to epoch 100</span><span className="mono">≈ 14h 20m</span></div>
              <div className="row between"><span className="txt-sm muted">Iters / epoch</span><span className="mono">780</span></div>
              <div className="row between"><span className="txt-sm muted">VRAM peak</span><span className="mono">7.4 / 12 GB</span></div>
              <div className="row between"><span className="txt-sm muted">Disk per ckpt</span><span className="mono">67 MB</span></div>
            </div>
          </Section>
        </div>
      </div>
    </div>
  </Shell>
);

// =========================================================
// LIVE TAB (training in progress)
// =========================================================
const LiveTab = () => {
  const lossA = [2.10, 1.78, 1.52, 1.34, 1.21, 1.10, 1.03, 0.98, 0.95, 0.93, 0.91, 0.90, 0.89, 0.88, 0.88, 0.87, 0.87, 0.86, 0.86, 0.86];
  const psnr  = [22.1, 23.4, 24.5, 25.3, 25.8, 26.3, 26.7, 27.1, 27.4, 27.7, 27.9, 28.1, 28.3, 28.4, 28.5, 28.7, 28.8, 28.8, 28.9, 28.94];
  return (
    <Shell tab="live" badge={<div className="row gap-6" style={{ paddingRight: 10, color: "var(--accent)" }}><div className="dot live"/><span className="txt-xs" style={{ fontWeight: 600 }}>LIVE</span></div>}>
      <div className="col" style={{ height: "100%" }}>
        {/* top status strip */}
        <div className="row gap-12 p-12" style={{ borderBottom: "1px solid var(--line)" }}>
          <div className="row gap-6"><Chip kind="tint" icon="play">run‑003</Chip><span className="txt-sm muted">epoch 42 of 100 · iter 32,840 / 78,000</span></div>
          <div style={{ flex: 1 }}/>
          <div className="row gap-6">
            <Btn sm icon="save">Snapshot now</Btn>
            <Btn sm icon="pause">Pause</Btn>
            <Btn sm danger icon="stop">Stop</Btn>
          </div>
        </div>

        {/* progress bars — REAL meaning */}
        <div className="p-12 col gap-10" style={{ borderBottom: "1px solid var(--line)" }}>
          <div className="col gap-4">
            <div className="row between txt-xs">
              <span className="muted">Epoch progress · iter 640 / 780</span>
              <span className="mono">82.1 % · this epoch finishes in 2m 14s</span>
            </div>
            <div className="bar"><div className="fill striped" style={{ width: "82%" }}/></div>
          </div>
          <div className="col gap-4">
            <div className="row between txt-xs">
              <span className="muted">Run progress · epoch 42 / 100</span>
              <span className="mono">42.0 % · ETA Tue 04:18 (≈ 9h 12m)</span>
            </div>
            <div className="bar"><div className="fill" style={{ width: "42%" }}/></div>
          </div>
        </div>

        {/* charts row */}
        <div className="row gap-0" style={{ flex: 1, minHeight: 0 }}>
          <div className="col gap-12 p-14 grow" style={{ borderRight: "1px solid var(--line)" }}>
            <Section title="Loss · train vs val" right={<div className="row gap-6 txt-xs muted"><span><span style={{ display: "inline-block", width: 10, height: 2, background: "var(--accent)", marginRight: 4 }}/>train</span><span><span style={{ display: "inline-block", width: 10, height: 2, background: "var(--accent-2)", borderTop: "1px dashed", marginRight: 4 }}/>val</span></div>}>
              <div className="sk p-8" style={{ color: "var(--accent)" }}>
                <Chart height={150} points={lossA} secondPoints={lossA.map(v => v * 1.07)} secondColor="var(--accent-2)" yLabel="loss" label="0.86 (val 0.92)"/>
              </div>
            </Section>

            <Section title="PSNR · validation">
              <div className="sk p-8" style={{ color: "var(--accent-2)" }}>
                <Chart height={120} points={psnr} color="var(--accent-2)" yLabel="dB" label="28.94 dB"/>
              </div>
            </Section>

            <div style={{ display: "grid", gridTemplateColumns: "repeat(5, 1fr)", gap: 6 }}>
              <div className="metric"><div className="key">step / s</div><div className="val">3.42</div></div>
              <div className="metric"><div className="key">LR</div><div className="val">1.4e‑4</div></div>
              <div className="metric"><div className="key">GPU</div><div className="val">92%</div><div className="sub">73 °C · 7.4 GB</div></div>
              <div className="metric"><div className="key">Best PSNR</div><div className="val">28.94</div><div className="sub">ep 42 (now)</div></div>
              <div className="metric"><div className="key">Best LPIPS</div><div className="val">0.092</div><div className="sub">ep 38</div></div>
            </div>
          </div>

          {/* validation previews */}
          <div className="col gap-8 p-14" style={{ width: 340 }}>
            <div className="between">
              <div className="label">Validation samples · ep 42</div>
              <div className="row gap-4"><IconBtn icon="arrow-left" sm/><span className="mono txt-xs">3 / 8</span><IconBtn icon="arrow-right" sm/></div>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6 }}>
              <ImgPh label="LR (input)" style={{ aspectRatio: "1 / 1" }}/>
              <ImgPh label="SR (model)" style={{ aspectRatio: "1 / 1" }}/>
              <ImgPh label="HR (target)" style={{ aspectRatio: "1 / 1" }}/>
              <ImgPh label="diff ×4" style={{ aspectRatio: "1 / 1" }}/>
            </div>

            <div className="col gap-2">
              <div className="row between"><span className="txt-xs muted">PSNR</span><span className="mono txt-xs">29.42 dB</span></div>
              <div className="row between"><span className="txt-xs muted">SSIM</span><span className="mono txt-xs">0.871</span></div>
              <div className="row between"><span className="txt-xs muted">LPIPS</span><span className="mono txt-xs">0.094</span></div>
            </div>

            <div className="hdiv"/>

            <div className="col gap-4">
              <div className="label">Recent events</div>
              {[
                ["12:42", "ckpt-ep42.pt", "saved · new best PSNR", "ok"],
                ["12:18", "val", "ran on 8 samples", ""],
                ["11:55", "LR", "cosine → 1.4e-4", ""],
              ].map(([t, k, v, kind], i) => (
                <div key={i} className="row gap-6 txt-xs" style={{ padding: "3px 0" }}>
                  <span className="mono muted" style={{ width: 40 }}>{t}</span>
                  <Chip kind={kind} sm>{k}</Chip>
                  <span className="muted">{v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </Shell>
  );
};

// =========================================================
// LIVE TAB — EMPTY (no run started)
// =========================================================
const LiveEmptyTab = () => (
  <Shell tab="live">
    <div className="center" style={{ height: "100%", padding: 40 }}>
      <div className="empty" style={{ maxWidth: 460 }}>
        <div className="icon-wrap"><Icon name="chart" size={16}/></div>
        <div style={{ fontWeight: 600, fontSize: 15, marginTop: 4 }}>No active training run</div>
        <div className="txt-sm muted">Live shows charts, validation previews, and GPU stats while a model is training.</div>
        <div className="row gap-8" style={{ marginTop: 10 }}>
          <Btn primary sm icon="play">Start a run from Training →</Btn>
          <Btn sm icon="refresh">Resume run‑003</Btn>
        </div>
      </div>
    </div>
  </Shell>
);

// =========================================================
// LIVE TAB — ERROR (CUDA OOM)
// =========================================================
const LiveErrorTab = () => (
  <Shell tab="live" badge={<div className="row gap-6" style={{ paddingRight: 10, color: "var(--danger)" }}><div className="dot err"/><span className="txt-xs" style={{ fontWeight: 600 }}>ERROR</span></div>}>
    <div className="col gap-14 p-14" style={{ height: "100%" }}>
      <Banner kind="err" icon="warn" title="Training stopped — CUDA out of memory at epoch 12, iter 480">
        <span className="mono txt-xs">torch.cuda.OutOfMemoryError</span> — Tried to allocate 1.42 GiB. GPU 0 has 11.99 GiB total · 11.71 GiB already allocated.
      </Banner>

      <div className="sk p-12 col gap-6">
        <div className="label">Suggested fixes</div>
        {[
          ["Lower batch size",     "16 → 12 (≈ 5.6 GB peak)",      "Apply"],
          ["Lower crop size",      "96 → 80 px",                    "Apply"],
          ["Enable mixed precision (AMP)", "halves activation memory", "Apply"],
          ["Gradient checkpointing", "slower but fits in 6 GB",     "Apply"],
        ].map(([k, v, cta], i) => (
          <div key={i} className="row gap-8 between" style={{ padding: "6px 8px", borderRadius: 3, background: "var(--surface-2)" }}>
            <div className="col" style={{ gap: 0 }}>
              <span style={{ fontWeight: 500, fontSize: 13 }}>{k}</span>
              <span className="txt-xs muted">{v}</span>
            </div>
            <Btn sm>{cta}</Btn>
          </div>
        ))}
      </div>

      <div className="sk p-12 col gap-4">
        <div className="between">
          <div className="label">Log tail · /runs/run‑004/train.log</div>
          <Btn ghost sm icon="folder">Open log</Btn>
        </div>
        <div className="mono txt-xs" style={{ background: "var(--surface-2)", border: "1px solid var(--line)", borderRadius: 3, padding: 10, lineHeight: 1.6 }}>
          <div className="muted">[12:18:42] ep 12 / 100 · it 477 / 780 · loss 0.94</div>
          <div className="muted">[12:18:43] ep 12 / 100 · it 478 / 780 · loss 0.93</div>
          <div className="muted">[12:18:43] ep 12 / 100 · it 479 / 780 · loss 0.92</div>
          <div style={{ color: "var(--danger)" }}>[12:18:44] ! torch.cuda.OutOfMemoryError: CUDA out of memory.</div>
          <div style={{ color: "var(--danger)" }}>            Tried to allocate 1.42 GiB. GPU 0 has 11.99 GiB total capacity.</div>
          <div className="muted">[12:18:44] writing crash snapshot → ckpt-ep12-iter479.pt</div>
        </div>
      </div>

      <div className="row gap-6">
        <Btn primary icon="refresh">Apply all suggested · retry</Btn>
        <Btn icon="gear">Open training settings</Btn>
        <Btn ghost icon="info">Read GPU memory guide</Btn>
      </div>
    </div>
  </Shell>
);

window.ModelTab = ModelTab;
window.TrainingTab = TrainingTab;
window.LiveTab = LiveTab;
window.LiveEmptyTab = LiveEmptyTab;
window.LiveErrorTab = LiveErrorTab;
