/**
 * p-reels-split-2d — per-reel custom Canvas 2D illustrations
 *
 * Export named functions matching the `props.draw` string in beats.json.
 * Signature: (ctx: CanvasRenderingContext2D, tLocal: number, props: object) => void
 *
 * tLocal = seconds since the beat started (use for subtle animation).
 * Origin (0,0) is placed at the beat's zone centroid BEFORE this function is called
 * (the caller does ctx.translate(cx, cy)), so draw centered around (0, 0).
 *
 * FONT RULE: Use `'Proxima Nova', sans-serif` (NOT -apple-system / SF Pro).
 * node-canvas only has the font registered via --font; system UI stacks fall back
 * to a fixed-size bitmap font that ignores the px size you set.
 * Minimum 34px for any illustration text. Primary labels: 40-56px.
 *
 * SHADOW HELPER: use the shadow() wrapper below — never ctx.shadowBlur on drawImage.
 */

const FONT = "'Proxima Nova', sans-serif";

// ── Drawing helpers ───────────────────────────────────────────────────────────
function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function shadow(ctx, fn, { blur = 18, offsetY = 8, alpha = 0.16 } = {}) {
  ctx.save();
  ctx.shadowColor   = `rgba(31,24,21,${alpha})`;
  ctx.shadowBlur    = blur;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = offsetY;
  fn(ctx);
  ctx.restore();
}

const breathe = (t, freq = 1.2, amp = 0.012) => 1 + Math.sin(t * freq) * amp;

// ── Illustrations ─────────────────────────────────────────────────────────────

/**
 * Agent grid — 3×2 grid of rounded agent cards, arrows between them.
 * Good for: "147 agents", "parallel agents", "agent swarm" beats.
 */
export function drawAgentGrid(ctx, t, props) {
  const cols = 3, rows = 2;
  const cw = 88, ch = 60, gx = 24, gy = 20;
  const totalW = cols * cw + (cols - 1) * gx;
  const totalH = rows * ch + (rows - 1) * gy;
  const ox = -totalW / 2, oy = -totalH / 2;

  const labels = props.labels ?? ["Agent 1","Agent 2","Agent 3","Agent 4","Agent 5","Agent 6"];
  const accent = props.accent ?? "#3B82F6";
  const scale  = breathe(t) * (props.scale ?? 1);

  ctx.save();
  ctx.scale(scale, scale);

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const idx = r * cols + c;
      const x = ox + c * (cw + gx);
      const y = oy + r * (ch + gy);

      shadow(ctx, (sCtx) => {
        sCtx.beginPath();
        roundRect(sCtx, x, y, cw, ch, 10);
        sCtx.fillStyle = "rgba(30,58,138,0.85)";
        sCtx.fill();
      });

      ctx.beginPath();
      roundRect(ctx, x, y, cw, ch, 10);
      ctx.fillStyle = "rgba(37,99,235,0.7)";
      ctx.fill();
      ctx.strokeStyle = "rgba(147,197,253,0.3)";
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // Label (min 34px)
      ctx.font = `600 34px ${FONT}`;
      ctx.fillStyle = "#FFFFFF";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      const label = labels[idx] ?? `A${idx+1}`;
      // Truncate to fit
      const maxW = cw - 12;
      let txt = label;
      while (ctx.measureText(txt).width > maxW && txt.length > 1) txt = txt.slice(0,-1) + "…";
      ctx.fillText(txt, x + cw / 2, y + ch / 2);
    }
  }

  ctx.restore();
}

/**
 * Parallel lanes — 3 vertical lanes with arrows and a result box.
 * Good for: "parallel", "simultaneously", "fan-out" beats.
 */
export function drawParallelLanes(ctx, t, props) {
  const lanes = props.lanes ?? ["Task A","Task B","Task C"];
  const n = lanes.length;
  const laneW = 120, laneH = 70, gx = 28;
  const totalW = n * laneW + (n - 1) * gx;
  const ox = -totalW / 2;
  const laneY = -90;
  const arrowY = laneY + laneH + 10;
  const resultY = arrowY + 40;

  ctx.save();
  ctx.scale(breathe(t, 0.8) * (props.scale ?? 1), breathe(t, 0.8) * (props.scale ?? 1));

  const colors = ["rgba(37,99,235,0.7)","rgba(124,58,237,0.7)","rgba(5,150,105,0.7)"];

  for (let i = 0; i < n; i++) {
    const x = ox + i * (laneW + gx);
    shadow(ctx, (sCtx) => {
      sCtx.beginPath();
      roundRect(sCtx, x, laneY, laneW, laneH, 10);
      sCtx.fillStyle = colors[i % colors.length];
      sCtx.fill();
    });
    ctx.beginPath();
    roundRect(ctx, x, laneY, laneW, laneH, 10);
    ctx.fillStyle = colors[i % colors.length];
    ctx.fill();

    ctx.font = `600 38px ${FONT}`;
    ctx.fillStyle = "#FFFFFF";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(lanes[i], x + laneW / 2, laneY + laneH / 2);

    // Arrow down
    const ax = x + laneW / 2;
    ctx.beginPath();
    ctx.moveTo(ax, arrowY);
    ctx.lineTo(ax, arrowY + 24);
    ctx.lineTo(ax - 8, arrowY + 14);
    ctx.moveTo(ax, arrowY + 24);
    ctx.lineTo(ax + 8, arrowY + 14);
    ctx.strokeStyle = "rgba(255,255,255,0.5)";
    ctx.lineWidth = 2.5;
    ctx.stroke();
  }

  // Result box
  const rw = 200, rh = 52;
  const rx = -rw / 2;
  shadow(ctx, (sCtx) => {
    sCtx.beginPath();
    roundRect(sCtx, rx, resultY, rw, rh, 10);
    sCtx.fillStyle = "rgba(5,150,105,0.8)";
    sCtx.fill();
  });
  ctx.beginPath();
  roundRect(ctx, rx, resultY, rw, rh, 10);
  ctx.fillStyle = "rgba(16,185,129,0.85)";
  ctx.fill();
  ctx.font = `700 40px ${FONT}`;
  ctx.fillStyle = "#FFFFFF";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(props.result ?? "Result", 0, resultY + rh / 2);

  ctx.restore();
}

/**
 * Org chart — root node with 3 child nodes.
 * Good for: "team structure", "reports to", "hierarchy" beats.
 */
export function drawOrgChart(ctx, t, props) {
  const root     = props.root     ?? "CEO";
  const children = props.children ?? ["Eng","Mktg","Sales"];
  const rw = 160, rh = 56, cr = 10;
  const cw = 120, ch = 50;
  const gx = 24;
  const rootY = -140;
  const childY = rootY + rh + 60;
  const totalChildW = children.length * cw + (children.length - 1) * gx;

  ctx.save();
  ctx.scale(breathe(t, 0.6) * (props.scale ?? 1), breathe(t, 0.6) * (props.scale ?? 1));

  // Root
  shadow(ctx, (sCtx) => {
    sCtx.beginPath();
    roundRect(sCtx, -rw/2, rootY, rw, rh, cr);
    sCtx.fillStyle = "rgba(37,99,235,0.85)";
    sCtx.fill();
  });
  ctx.beginPath();
  roundRect(ctx, -rw/2, rootY, rw, rh, cr);
  ctx.fillStyle = "rgba(59,130,246,0.9)";
  ctx.fill();
  ctx.font = `700 42px ${FONT}`;
  ctx.fillStyle = "#FFFFFF";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(root, 0, rootY + rh / 2);

  // Lines to children
  const rootCX = 0, rootCY = rootY + rh;
  children.forEach((child, i) => {
    const cx2 = -totalChildW / 2 + i * (cw + gx) + cw / 2;
    const cy2 = childY;
    ctx.beginPath();
    ctx.moveTo(rootCX, rootCY);
    ctx.bezierCurveTo(rootCX, rootCY + 20, cx2, cy2 - 20, cx2, cy2);
    ctx.strokeStyle = "rgba(147,197,253,0.5)";
    ctx.lineWidth = 2;
    ctx.stroke();
  });

  // Children
  children.forEach((child, i) => {
    const cx2 = -totalChildW / 2 + i * (cw + gx);
    shadow(ctx, (sCtx) => {
      sCtx.beginPath();
      roundRect(sCtx, cx2, childY, cw, ch, 8);
      sCtx.fillStyle = "rgba(30,58,138,0.8)";
      sCtx.fill();
    });
    ctx.beginPath();
    roundRect(ctx, cx2, childY, cw, ch, 8);
    ctx.fillStyle = "rgba(37,99,235,0.65)";
    ctx.fill();
    ctx.font = `600 38px ${FONT}`;
    ctx.fillStyle = "#FFFFFF";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(child, cx2 + cw / 2, childY + ch / 2);
  });

  ctx.restore();
}

/**
 * IDE mock — a simplified "editor" card with syntax-colored lines.
 * Good for: "code", "CLAUDE.md", "config", "command" beats.
 */
export function drawIdemock(ctx, t, props) {
  const lines = props.lines ?? ["const agent = new Agent()", "agent.run(task)", "// done ✓"];
  const cardW = 340, cardH = 30 + lines.length * 52 + 20;
  const x = -cardW / 2, y = -cardH / 2;

  ctx.save();
  ctx.scale(props.scale ?? 1, props.scale ?? 1);

  // Card bg
  shadow(ctx, (sCtx) => {
    sCtx.beginPath();
    roundRect(sCtx, x, y, cardW, cardH, 12);
    sCtx.fillStyle = "#1E1E2E";
    sCtx.fill();
  });
  ctx.beginPath();
  roundRect(ctx, x, y, cardW, cardH, 12);
  ctx.fillStyle = "#1E1E2E";
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.08)";
  ctx.lineWidth = 1;
  ctx.stroke();

  // Window dots
  const dotColors = ["#FF5F57","#FEBC2E","#28C840"];
  dotColors.forEach((c, i) => {
    ctx.beginPath();
    ctx.arc(x + 18 + i * 20, y + 18, 6, 0, Math.PI * 2);
    ctx.fillStyle = c;
    ctx.fill();
  });

  // Code lines (34px minimum, color-coded by prefix)
  lines.forEach((line, i) => {
    const ly = y + 42 + i * 52;
    // Simple color rules
    let color = "#A6E3A1"; // green for statements
    if (line.startsWith("//")) color = "#6C7086";        // comment = gray
    if (line.includes("const") || line.includes("let")) color = "#CBA6F7"; // purple for declarations
    if (line.includes("(") && !line.startsWith("//")) color = "#89DCEB";  // teal for calls

    ctx.font = `500 36px ${FONT}`;
    ctx.fillStyle = color;
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
    const maxW = cardW - 28;
    let txt = line;
    while (ctx.measureText(txt).width > maxW && txt.length > 1) txt = txt.slice(0,-1) + "…";
    ctx.fillText(txt, x + 14, ly + 26);
  });

  ctx.restore();
}

/**
 * Stat reveal — large number + label, light paper card.
 * Good for: metrics, counts, percentages. Use a pill for the number; this illustration
 * is the VISUAL companion that shows context (chart bars, trend arrow).
 *
 * IMPORTANT: never a dark card with tiny labels (per manthan's Rule 12).
 * This card is light (#F8F9FA) with large text.
 */
export function drawStatCard(ctx, t, props) {
  const stat  = props.stat  ?? "10×";
  const label = props.label ?? "faster";
  const cw = 260, ch = 140;
  const scale = breathe(t) * (props.scale ?? 1);

  ctx.save();
  ctx.scale(scale, scale);

  shadow(ctx, (sCtx) => {
    sCtx.beginPath();
    roundRect(sCtx, -cw/2, -ch/2, cw, ch, 14);
    sCtx.fillStyle = "#F8F9FA";
    sCtx.fill();
  });
  ctx.beginPath();
  roundRect(ctx, -cw/2, -ch/2, cw, ch, 14);
  ctx.fillStyle = "#F8F9FA";
  ctx.fill();

  // Stat (big, primary label ≥ 40px)
  ctx.font = `800 72px ${FONT}`;
  ctx.fillStyle = "#111827";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(stat, 0, -18);

  // Label (secondary, min 34px)
  ctx.font = `500 40px ${FONT}`;
  ctx.fillStyle = "#6B7280";
  ctx.fillText(label, 0, 40);

  ctx.restore();
}
