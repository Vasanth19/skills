/**
 * p-reels-split-2d — Konva/Canvas-2D headless top-half overlay renderer
 *
 * Renders a 1080×960 MP4 (the top half of a split-screen reel) using Konva as the
 * scene graph and node-canvas as the headless Canvas 2D backend.
 *
 * Usage:
 *   node render-overlay.mjs \
 *     --beats beats.json \
 *     --duration 42.5 \
 *     --out /tmp/top-overlay.mp4 \
 *     [--fps 30] \
 *     [--width 1080] [--height 960] \
 *     [--font /path/to/font.ttf] \
 *     [--illustrations ./illustrations.mjs] \
 *     [--smoke 1.5,8.0,22.0]
 *
 * --smoke: comma-separated timestamps → renders those frames as PNGs to
 *          /tmp/split2d-smoke/<t>s.png then exits (no MP4 produced).
 *          Use this for fast visual QA before burning the full render.
 *
 * Output: 1080×960 MP4, no audio, H.264 yuv420p 30fps.
 *         The file is suitable for ffmpeg vstack with the face-cam bottom half.
 */

import { parseArgs } from "node:util";
import fs from "node:fs";
import path from "node:path";
import { execSync, spawn } from "node:child_process";
import os from "node:os";

// ── Arg parsing ───────────────────────────────────────────────────────────────
const { values: args } = parseArgs({
  options: {
    beats:         { type: "string" },
    duration:      { type: "string" },
    out:           { type: "string" },
    fps:           { type: "string",  default: "30" },
    width:         { type: "string",  default: "1080" },
    height:        { type: "string",  default: "960" },
    font:          { type: "string",  default: "" },
    illustrations: { type: "string",  default: "" },
    smoke:         { type: "string",  default: "" },
  },
  strict: false,
});

const BEATS_PATH    = args.beats       ?? die("--beats required");
const DURATION      = parseFloat(args.duration ?? die("--duration required"));
const OUT_PATH      = args.out         ?? die("--out required");
const FPS           = parseInt(args.fps);
const W             = parseInt(args.width);
const H             = parseInt(args.height);    // 960 = top half of 1920
const FONT_PATH     = args.font;
const ILLUS_PATH    = args.illustrations;
const SMOKE_TIMES   = args.smoke ? args.smoke.split(",").map(Number) : null;

const TOTAL_FRAMES  = Math.ceil(DURATION * FPS);

// ── Konva + canvas bootstrap ──────────────────────────────────────────────────
// Konva auto-detects the `canvas` package and uses it as the Node.js backend.
// We must set the canvas factory BEFORE importing Konva so it picks up node-canvas.

let createCanvas_fn, registerFont_fn;
try {
  const canvasMod = await import("canvas");
  createCanvas_fn = canvasMod.createCanvas;
  registerFont_fn = canvasMod.registerFont;
} catch (e) {
  die(
    `node-canvas not found. Install with:\n` +
    `  cd ${path.dirname(new URL(import.meta.url).pathname)} && npm install\n` +
    `Also ensure native deps: brew install pkg-config cairo pango (macOS) ` +
    `or apt-get install libcairo2-dev libpango1.0-dev (Ubuntu)\n\n` +
    `Original error: ${e.message}`
  );
}

// Register font if provided
const FONT_FAMILY = "Proxima Nova";
if (FONT_PATH && fs.existsSync(FONT_PATH)) {
  registerFont_fn(FONT_PATH, { family: FONT_FAMILY, weight: "800" });
  registerFont_fn(FONT_PATH, { family: FONT_FAMILY, weight: "700" });
  registerFont_fn(FONT_PATH, { family: FONT_FAMILY, weight: "400" });
  log(`Registered font: ${FONT_PATH} as '${FONT_FAMILY}'`);
} else {
  // Fall back to DejaVu Sans (present on most Linux systems) so text renders at
  // correct sizes. warn because pill text will look different from the macOS preview.
  warn("No --font provided. Using system sans-serif. " +
       "Pill text may render at incorrect sizes (bitmap font fallback).");
}
const SAFE_FONT = FONT_PATH ? `'${FONT_FAMILY}'` : "sans-serif";

// Konva — must be imported AFTER canvas is available in the environment
let Konva;
try {
  Konva = (await import("konva/cmj/index-node.js")).default;
} catch (_) {
  try {
    Konva = (await import("konva")).default;
  } catch (e) {
    die(`konva not found. Run: cd renderer && npm install\nError: ${e.message}`);
  }
}

// ── Illustrations module ──────────────────────────────────────────────────────
let illustrations = {};
if (ILLUS_PATH && fs.existsSync(ILLUS_PATH)) {
  illustrations = await import(path.resolve(ILLUS_PATH));
  log(`Loaded illustrations: ${Object.keys(illustrations).filter(k => k !== "default").join(", ")}`);
}

// ── Beat loading + validation ─────────────────────────────────────────────────
const beats = JSON.parse(fs.readFileSync(BEATS_PATH, "utf8"));

// Zone centroid table
const ZONE_CENTROIDS = {
  "top-left":   { cx: 360, cy: 360 },
  "top-center": { cx: 540, cy: 540 },
  "top-right":  { cx: 720, cy: 360 },
};

function resolveBeatPosition(beat) {
  if (beat.cx !== undefined && beat.cy !== undefined) return { cx: beat.cx, cy: beat.cy };
  const z = ZONE_CENTROIDS[beat.zone];
  if (!z) throw new Error(`Beat '${beat.id}': invalid zone '${beat.zone}'`);
  return { cx: z.cx, cy: z.cy + (beat.cyOffset ?? 0) };
}

// Validate: cy ≤ 900, no simultaneous zone overlap
const activeByZone = {};
for (const beat of beats) {
  if (beat.kind === "broll") continue; // b-roll handled separately
  const { cy } = resolveBeatPosition(beat);
  if (cy > 900) throw new Error(`ZoneSafetyViolation: beat '${beat.id}' cy=${cy} > 900`);
  const zone = beat.zone ?? `custom:${beat.cx},${beat.cy}`;
  if (!activeByZone[zone]) activeByZone[zone] = [];
  for (const other of activeByZone[zone]) {
    const overlap = beat.start < other.end && beat.end > other.start;
    if (overlap) throw new Error(`ZoneConflict: beats '${beat.id}' and '${other.id}' overlap in zone '${zone}'`);
  }
  activeByZone[zone].push(beat);
}
log(`Beats loaded: ${beats.length}`);

// ── Liquid palette helpers ────────────────────────────────────────────────────
function hexToRgb(hex) {
  const h = hex.replace("#", "");
  return {
    r: parseInt(h.slice(0,2), 16),
    g: parseInt(h.slice(2,4), 16),
    b: parseInt(h.slice(4,6), 16),
  };
}

function rgbToHex({ r, g, b }) {
  return "#" + [r, g, b].map(v => v.toString(16).padStart(2, "0")).join("");
}

function lerpColor(a, b, t) {
  const ca = hexToRgb(a), cb = hexToRgb(b);
  return rgbToHex({
    r: Math.round(ca.r + (cb.r - ca.r) * t),
    g: Math.round(ca.g + (cb.g - ca.g) * t),
    b: Math.round(ca.b + (cb.b - ca.b) * t),
  });
}

// Animated gradient angle that slowly rotates over time (matches manthan's spec)
function gradientAngle(t) {
  return (t * 15) % 360; // 15 deg/sec rotation
}

// ── Animation envelope helpers ────────────────────────────────────────────────
const ANIM_DURATIONS = {
  // in/out anim default durations (seconds)
  pop:         0.25,
  "slide-up":  0.3,
  "slide-down":0.3,
  "slide-left":0.3,
  "slide-right":0.3,
  drop:        0.35,
  fade:        0.3,
  "snap-up":   0.2,
  "snap-down": 0.2,
};

function easePow(t, p) { return Math.pow(Math.min(Math.max(t, 0), 1), p); }
function easeOutCubic(t) { return 1 - Math.pow(1 - Math.min(Math.max(t, 0), 1), 3); }
function easeInCubic(t)  { return Math.pow(Math.min(Math.max(t, 0), 1), 3); }

/**
 * Returns the animation progress factor [0..1] + transform offsets for a beat
 * at global time `t`. Returns null if the beat is not active.
 */
function beatState(beat, t) {
  if (t < beat.start || t >= beat.end) return null;
  const inDur  = beat.inDur  ?? ANIM_DURATIONS[beat.inAnim  ?? "fade"] ?? 0.3;
  const outDur = beat.outDur ?? ANIM_DURATIONS[beat.outAnim ?? "fade"] ?? 0.3;

  const tLocal  = t - beat.start;
  const tFromEnd = beat.end - t;
  const duration  = beat.end - beat.start;

  const inProgress  = Math.min(tLocal / inDur, 1);
  const outProgress = Math.min((outDur - tFromEnd) / outDur, 1);
  const isIn  = tLocal < inDur;
  const isOut = tFromEnd < outDur;

  let alpha = 1, scaleX = 1, scaleY = 1, offsetX = 0, offsetY = 0;

  // --- In animation ---
  if (isIn) {
    switch (beat.inAnim) {
      case "fade":
        alpha = easeOutCubic(inProgress);
        break;
      case "pop":
        scaleX = scaleY = 0.5 + 0.5 * easeOutCubic(inProgress);
        alpha = easeOutCubic(inProgress * 2);
        break;
      case "slide-up":
        offsetY = (1 - easeOutCubic(inProgress)) * 80;
        alpha = easeOutCubic(inProgress);
        break;
      case "slide-down":
        offsetY = -(1 - easeOutCubic(inProgress)) * 80;
        alpha = easeOutCubic(inProgress);
        break;
      case "slide-left":
        offsetX = (1 - easeOutCubic(inProgress)) * 80;
        alpha = easeOutCubic(inProgress);
        break;
      case "slide-right":
        offsetX = -(1 - easeOutCubic(inProgress)) * 80;
        alpha = easeOutCubic(inProgress);
        break;
      case "drop":
        offsetY = -(1 - easeOutCubic(inProgress)) * 120;
        alpha = easeOutCubic(inProgress * 2);
        break;
      default:
        alpha = easeOutCubic(inProgress);
    }
  }

  // --- Out animation ---
  if (isOut && outProgress > 0) {
    switch (beat.outAnim) {
      case "fade":
        alpha *= 1 - easeInCubic(outProgress);
        break;
      case "pop":
        scaleX *= 1 + 0.15 * outProgress;
        scaleY  = scaleX;
        alpha  *= 1 - easeInCubic(outProgress);
        break;
      case "snap-up":
        offsetY -= outProgress * 60;
        alpha   *= 1 - easeInCubic(outProgress);
        break;
      case "snap-down":
        offsetY += outProgress * 60;
        alpha   *= 1 - easeInCubic(outProgress);
        break;
      case "slide-left":
        offsetX -= outProgress * 80;
        alpha   *= 1 - easeInCubic(outProgress);
        break;
      case "slide-right":
        offsetX += outProgress * 80;
        alpha   *= 1 - easeInCubic(outProgress);
        break;
      default:
        alpha *= 1 - easeInCubic(outProgress);
    }
  }

  // --- Idle ---
  const idleT = t - beat.start - inDur;
  let idleScale = 1;
  if (!isIn && !isOut && beat.idle) {
    switch (beat.idle) {
      case "bob":      offsetY += Math.sin(idleT * 1.8) * 5; break;
      case "breathe":  idleScale = 1 + Math.sin(idleT * 1.2) * 0.012; break;
      case "pulse":    idleScale = 1 + Math.sin(idleT * 2.4) * 0.02; break;
    }
  }

  return { alpha: Math.max(0, Math.min(1, alpha)), scaleX: scaleX * idleScale, scaleY: scaleY * idleScale, offsetX, offsetY };
}

// ── Drop shadow helper (3-layer, matches manthan spec) ────────────────────────
function drawDropShadow(ctx, fn) {
  const layers = [
    { blur: 24, offsetY: 12, alpha: 0.12 },
    { blur: 12, offsetY: 6,  alpha: 0.18 },
    { blur: 6,  offsetY: 3,  alpha: 0.22 },
  ];
  for (const { blur, offsetY, alpha } of layers) {
    ctx.save();
    ctx.shadowColor  = `rgba(0,0,0,${alpha})`;
    ctx.shadowBlur   = blur;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = offsetY;
    fn(ctx);
    ctx.restore();
  }
}

// ── Outward-only wave stroke (strokeLiquidOutline) ────────────────────────────
/**
 * Draws a wave stroke that bumps OUTWARD only around a rounded rectangle.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} cx - center x
 * @param {number} cy - center y
 * @param {number} pw - pill width
 * @param {number} ph - pill height
 * @param {number} r  - pill corner radius
 * @param {string[]} palette - 6-stop hex palette
 * @param {number} t  - current time (drives animation)
 */
function strokeLiquidOutline(ctx, cx, cy, pw, ph, r, palette, t) {
  const WAVE_AMP   = 10;   // max outward bump
  const WAVE_FREQ  = 4;    // bumps around the perimeter
  const EXPAND     = 6;    // base outward expansion (never inward)

  const x = cx - pw / 2;
  const y = cy - ph / 2;

  // Sample perimeter points and expand them outward
  const N = 120;
  const points = [];
  const totalPerim = 2 * (pw + ph);

  for (let i = 0; i < N; i++) {
    const u = i / N;
    const d = u * totalPerim;

    let px, py, nx, ny; // position + outward normal
    if (d < pw) {
      // top edge
      px = x + d; py = y; nx = 0; ny = -1;
    } else if (d < pw + ph) {
      // right edge
      px = x + pw; py = y + (d - pw); nx = 1; ny = 0;
    } else if (d < 2 * pw + ph) {
      // bottom edge
      px = x + pw - (d - pw - ph); py = y + ph; nx = 0; ny = 1;
    } else {
      // left edge
      px = x; py = y + ph - (d - 2 * pw - ph); nx = -1; ny = 0;
    }

    // Outward-only wave
    const phase = u * Math.PI * 2 * WAVE_FREQ + t * 2;
    const amp = WAVE_AMP * ((Math.sin(phase) + 1) / 2); // always ≥ 0

    points.push({
      x: px + nx * (EXPAND + amp),
      y: py + ny * (EXPAND + amp),
    });
  }

  // Stroke using the palette colors as a gradient
  const grad = ctx.createLinearGradient(cx - pw / 2, cy - ph / 2, cx + pw / 2, cy + ph / 2);
  for (let i = 0; i < palette.length; i++) {
    grad.addColorStop(i / (palette.length - 1), palette[i]);
  }

  ctx.save();
  ctx.beginPath();
  ctx.moveTo(points[0].x, points[0].y);
  for (let i = 1; i < points.length; i++) {
    ctx.lineTo(points[i].x, points[i].y);
  }
  ctx.closePath();
  ctx.strokeStyle = grad;
  ctx.lineWidth   = 3;
  ctx.globalAlpha *= 0.7;
  ctx.stroke();
  ctx.restore();
}

// ── Animated gradient body ────────────────────────────────────────────────────
function fillPillBody(ctx, cx, cy, pw, ph, r, palette, t) {
  const angle = (gradientAngle(t) * Math.PI) / 180;
  const halfDiag = Math.sqrt(pw * pw + ph * ph) / 2;
  const gx1 = cx + Math.cos(angle) * halfDiag;
  const gy1 = cy + Math.sin(angle) * halfDiag;
  const gx2 = cx - Math.cos(angle) * halfDiag;
  const gy2 = cy - Math.sin(angle) * halfDiag;

  const grad = ctx.createLinearGradient(gx1, gy1, gx2, gy2);
  // Body uses stops 0-3
  grad.addColorStop(0,    palette[0]);
  grad.addColorStop(0.33, palette[1]);
  grad.addColorStop(0.66, palette[2]);
  grad.addColorStop(1,    palette[3]);

  ctx.save();
  ctx.beginPath();
  roundRect(ctx, cx - pw / 2, cy - ph / 2, pw, ph, r);
  ctx.fillStyle = grad;
  ctx.fill();
  ctx.restore();
}

// ── Canvas rounded-rect path helper ──────────────────────────────────────────
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

// ── Pill renderer ─────────────────────────────────────────────────────────────
function drawPill(ctx, beat, t, state) {
  const { cx, cy } = resolveBeatPosition(beat);
  const p = beat.props ?? {};
  const text     = p.text ?? "";
  const fontSize = p.fontSize ?? 56;
  const palette  = p.palette ?? ["#1E3A5F","#2563EB","#3B82F6","#93C5FD","#DBEAFE","#EFF6FF"];
  const fill     = p.fill    ?? palette[1];
  const textColor = p.textColor ?? "#FFFFFF";

  // Measure text to size the pill
  ctx.font = `800 ${fontSize}px ${SAFE_FONT}`;
  const textW = ctx.measureText(text).width;
  const pw = textW + fontSize * 1.6; // horizontal padding
  const ph = fontSize * 1.8;         // vertical padding
  const r  = ph / 2;                 // fully rounded ends

  ctx.save();
  ctx.globalAlpha = state.alpha;
  ctx.translate(cx + state.offsetX, cy + state.offsetY);
  ctx.scale(state.scaleX, state.scaleY);

  // 3-layer drop shadow + static fill plate
  drawDropShadow(ctx, (sCtx) => {
    sCtx.beginPath();
    roundRect(sCtx, -pw / 2, -ph / 2, pw, ph, r);
    sCtx.fillStyle = fill;
    sCtx.fill();
  });

  // Animated gradient body (drawn over static plate)
  fillPillBody(ctx, 0, 0, pw, ph, r, palette, t);

  // Outward-only wave stroke
  strokeLiquidOutline(ctx, 0, 0, pw, ph, r, palette, t);

  // Pill text (plain fill, no stroke)
  ctx.font       = `800 ${fontSize}px ${SAFE_FONT}`;
  ctx.fillStyle  = textColor;
  ctx.textAlign  = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(text, 0, 0);

  ctx.restore();
}

// ── Emoji renderer ────────────────────────────────────────────────────────────
function drawEmoji(ctx, beat, t, state) {
  const { cx, cy } = resolveBeatPosition(beat);
  const p = beat.props ?? {};
  const emoji = p.text ?? "✨";
  const size  = p.size ?? 200;

  ctx.save();
  ctx.globalAlpha = state.alpha;
  ctx.font = `${size}px ${SAFE_FONT}`;
  ctx.textAlign    = "center";
  ctx.textBaseline = "middle";
  ctx.translate(cx + state.offsetX, cy + state.offsetY);
  ctx.scale(state.scaleX, state.scaleY);
  ctx.fillStyle = "black"; // required before drawImage on some canvas impls
  ctx.fillText(emoji, 0, 0);
  ctx.restore();
}

// ── Logo renderer (PNG file) ──────────────────────────────────────────────────
const logoCache = {};

async function loadImage(src) {
  if (logoCache[src]) return logoCache[src];
  const { createCanvas: cc, loadImage: li } = await import("canvas");
  const img = await li(src);
  logoCache[src] = img;
  return img;
}

function drawLogo(ctx, beat, logoImg, state) {
  const { cx, cy } = resolveBeatPosition(beat);
  const p = beat.props ?? {};
  const logoSize = p.logoSize ?? 90;
  const label    = p.label    ?? "";
  const fontSize = p.fontSize ?? 44;
  const palette  = p.palette  ?? ["#1E3A5F","#2563EB","#3B82F6","#93C5FD","#DBEAFE","#EFF6FF"];
  const fill     = p.fill     ?? palette[1];
  const textColor = p.textColor ?? "#FFFFFF";

  // Pill width = logoSize + gap + text width + padding
  ctx.font = `700 ${fontSize}px ${SAFE_FONT}`;
  const labelW = label ? ctx.measureText(label).width : 0;
  const gap = logoSize * 0.3;
  const pw = logoSize + (label ? gap + labelW : 0) + fontSize * 1.6;
  const ph = Math.max(logoSize + 20, fontSize * 1.8);
  const r  = ph / 2;

  ctx.save();
  ctx.globalAlpha = state.alpha;
  ctx.translate(cx + state.offsetX, cy + state.offsetY);
  ctx.scale(state.scaleX, state.scaleY);

  drawDropShadow(ctx, (sCtx) => {
    sCtx.beginPath();
    roundRect(sCtx, -pw / 2, -ph / 2, pw, ph, r);
    sCtx.fillStyle = fill;
    sCtx.fill();
  });
  fillPillBody(ctx, 0, 0, pw, ph, r, palette, 0);
  strokeLiquidOutline(ctx, 0, 0, pw, ph, r, palette, 0);

  // Logo image
  const startX = label ? -pw / 2 + fontSize * 0.8 : -logoSize / 2;
  ctx.drawImage(logoImg, startX, -logoSize / 2, logoSize, logoSize);

  // Label
  if (label) {
    ctx.font = `700 ${fontSize}px ${SAFE_FONT}`;
    ctx.fillStyle   = textColor;
    ctx.textAlign   = "left";
    ctx.textBaseline = "middle";
    ctx.fillText(label, startX + logoSize + gap, 0);
  }

  ctx.restore();
}

// ── Primitive (custom illustration) renderer ──────────────────────────────────
function drawPrimitive(ctx, beat, t, state) {
  const { cx, cy } = resolveBeatPosition(beat);
  const p = beat.props ?? {};
  const drawKey = p.draw;
  const drawFn  = drawKey ? (illustrations[drawKey] ?? null) : null;

  if (!drawFn) {
    // Fallback: draw a placeholder card so the reel isn't blank
    ctx.save();
    ctx.globalAlpha = state.alpha * 0.6;
    ctx.translate(cx + state.offsetX, cy + state.offsetY);
    ctx.scale(state.scaleX, state.scaleY);
    ctx.beginPath();
    roundRect(ctx, -140, -100, 280, 200, 14);
    ctx.fillStyle = "rgba(255,255,255,0.1)";
    ctx.fill();
    ctx.font = `400 32px ${SAFE_FONT}`;
    ctx.fillStyle = "rgba(255,255,255,0.5)";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(drawKey ?? "(primitive)", 0, 0);
    ctx.restore();
    return;
  }

  ctx.save();
  ctx.globalAlpha = state.alpha;
  ctx.translate(cx + state.offsetX, cy + state.offsetY);
  ctx.scale(state.scaleX, state.scaleY);
  drawFn(ctx, t - beat.start, p);
  ctx.restore();
}

// ── Background gradient ───────────────────────────────────────────────────────
function drawBackground(ctx, t) {
  // Deep gradient background for the top half — subtle shifting hue
  const hue1 = (220 + Math.sin(t * 0.08) * 15) | 0;
  const hue2 = (260 + Math.sin(t * 0.05) * 20) | 0;
  const grad = ctx.createLinearGradient(0, 0, W, H);
  grad.addColorStop(0, `hsl(${hue1}, 30%, 8%)`);
  grad.addColorStop(1, `hsl(${hue2}, 25%, 6%)`);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);
}

// ── Preload all logo images ───────────────────────────────────────────────────
const logoImages = {};
for (const beat of beats) {
  if (beat.type === "logo" && beat.props?.src) {
    if (!logoImages[beat.props.src]) {
      try {
        logoImages[beat.props.src] = await loadImage(beat.props.src);
        log(`Loaded logo: ${beat.props.src}`);
      } catch (e) {
        warn(`Could not load logo '${beat.props.src}': ${e.message}. A placeholder will be drawn.`);
        logoImages[beat.props.src] = null;
      }
    }
  }
}

// ── Smoke render ──────────────────────────────────────────────────────────────
if (SMOKE_TIMES) {
  const smokeDir = "/tmp/split2d-smoke";
  fs.mkdirSync(smokeDir, { recursive: true });

  const { createCanvas: cc } = await import("canvas");

  for (const t of SMOKE_TIMES) {
    const canvas = cc(W, H);
    const ctx    = canvas.getContext("2d");
    renderFrame(ctx, t);
    const outPng = path.join(smokeDir, `${t.toFixed(1)}s.png`);
    const buf = canvas.toBuffer("image/png");
    fs.writeFileSync(outPng, buf);
    log(`Smoke frame: ${outPng}`);
  }
  log(`Smoke complete. ${SMOKE_TIMES.length} frames in ${smokeDir}`);
  log(`Review frames, then re-run without --smoke for the full render.`);
  process.exit(0);
}

// ── Full render via ffmpeg pipe ───────────────────────────────────────────────
// We pipe raw BGRA frames to ffmpeg stdin; ffmpeg encodes to H.264 yuv420p.
// This avoids writing N PNG files to disk (typically 900–1800 frames for a 30-60s reel).

const ffPath = process.env.FFMPEG_PATH ?? "ffmpeg";

// Ensure output dir exists
fs.mkdirSync(path.dirname(path.resolve(OUT_PATH)), { recursive: true });

const ffArgs = [
  "-y",
  "-f", "rawvideo",
  "-pix_fmt", "bgra",
  "-s", `${W}x${H}`,
  "-r", String(FPS),
  "-i", "pipe:0",
  "-c:v", "libx264",
  "-pix_fmt", "yuv420p",
  "-preset", "medium",
  "-crf", "20",
  "-movflags", "+faststart",
  OUT_PATH,
];

log(`Starting render: ${TOTAL_FRAMES} frames @ ${FPS}fps → ${OUT_PATH}`);

const ff = spawn(ffPath, ffArgs, {
  stdio: ["pipe", "inherit", "inherit"],
});

ff.on("error", (e) => {
  die(`ffmpeg spawn failed: ${e.message}\nEnsure ffmpeg is on PATH or set FFMPEG_PATH env var.`);
});

ff.stdin.on("error", (e) => {
  // Ignore EPIPE (ffmpeg closed its stdin after an error — its stderr already reported it)
  if (e.code !== "EPIPE") throw e;
});

const { createCanvas: ccFull } = await import("canvas");
const canvas = ccFull(W, H);
const ctx    = canvas.getContext("2d");

let lastPct = -1;
for (let frame = 0; frame < TOTAL_FRAMES; frame++) {
  const t = frame / FPS;
  renderFrame(ctx, t);
  const raw = canvas.toBuffer("raw"); // raw BGRA, same dims as canvas
  // node-canvas raw buffer = BGRA which is what ffmpeg expects with -pix_fmt bgra
  ff.stdin.write(raw);

  const pct = Math.floor((frame / TOTAL_FRAMES) * 100);
  if (pct !== lastPct && pct % 10 === 0) {
    process.stderr.write(`\r[render-overlay] ${pct}% (frame ${frame}/${TOTAL_FRAMES})`);
    lastPct = pct;
  }
}

ff.stdin.end();

await new Promise((resolve, reject) => {
  ff.on("close", (code) => {
    process.stderr.write("\n");
    if (code === 0) resolve();
    else reject(new Error(`ffmpeg exited with code ${code}`));
  });
});

log(`Done → ${OUT_PATH}`);

// ── Frame renderer (called per-frame for both smoke and full render) ───────────
function renderFrame(ctx, t) {
  ctx.clearRect(0, 0, W, H);
  drawBackground(ctx, t);

  for (const beat of beats) {
    if (beat.kind === "broll") continue; // b-roll handled outside renderer
    const state = beatState(beat, t);
    if (!state) continue;

    switch (beat.type) {
      case "hook":
      case "keyword":
      case "cta":
        drawPill(ctx, beat, t, state);
        break;
      case "emoji":
        drawEmoji(ctx, beat, t, state);
        break;
      case "logo": {
        const img = logoImages[beat.props?.src ?? ""] ?? null;
        if (img) {
          drawLogo(ctx, beat, img, state);
        } else {
          // Fallback pill if logo didn't load
          drawPill(ctx, { ...beat, props: { ...beat.props, text: beat.props?.label ?? "?" } }, t, state);
        }
        break;
      }
      case "primitive":
        drawPrimitive(ctx, beat, t, state);
        break;
      default:
        // Unknown type — draw a fallback pill
        drawPill(ctx, { ...beat, props: { ...beat.props, text: beat.id } }, t, state);
    }
  }
}

// ── Utilities ─────────────────────────────────────────────────────────────────
function log(msg)  { process.stderr.write(`[render-overlay] ${msg}\n`); }
function warn(msg) { process.stderr.write(`[render-overlay] WARN: ${msg}\n`); }
function die(msg)  { process.stderr.write(`[render-overlay] ERROR: ${msg}\n`); process.exit(1); }
