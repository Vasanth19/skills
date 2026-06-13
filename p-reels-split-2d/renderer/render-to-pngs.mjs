/**
 * render-to-pngs.mjs — renders a beats JSON to a sequence of PNG files
 * then encodes them with ffmpeg. Bypasses the stdin pipe entirely.
 *
 * Usage: node render-to-pngs.mjs --beats beats.json --start 0 --end 12
 *        --out /tmp/chunk.mp4 --fps 30 --font /path/to/font.ttf
 *        --pngdir /tmp/frames/ [--illustrations /path/to/illustrations.mjs]
 */

import { parseArgs } from "node:util";
import fs from "node:fs";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import os from "node:os";

const { values: args } = parseArgs({
  options: {
    beats:         { type: "string" },
    start:         { type: "string", default: "0" },
    end:           { type: "string" },
    out:           { type: "string" },
    fps:           { type: "string", default: "30" },
    width:         { type: "string", default: "1080" },
    height:        { type: "string", default: "960" },
    font:          { type: "string", default: "" },
    illustrations: { type: "string", default: "" },
    pngdir:        { type: "string", default: "" },
  },
  strict: false,
});

const startT   = parseFloat(args.start);
const endT     = parseFloat(args.end);
const chunkDur = endT - startT;
const FPS      = parseInt(args.fps);
const W        = parseInt(args.width);
const H        = parseInt(args.height);
const OUT_PATH = args.out;
const FONT_PATH = args.font;
const ILLUS_PATH = args.illustrations || "/Users/vasanth/Code/skills/p-reels-split-2d/renderer/illustrations.mjs";
const TOTAL_FRAMES = Math.ceil(chunkDur * FPS);

// PNG output directory
const pngDir = args.pngdir || path.join(os.tmpdir(), `split2d-frames-${startT}-${endT}`);
fs.mkdirSync(pngDir, { recursive: true });

// Load canvas
let createCanvas_fn, registerFont_fn;
try {
  const canvasMod = await import("canvas");
  createCanvas_fn = canvasMod.createCanvas;
  registerFont_fn = canvasMod.registerFont;
} catch (e) {
  console.error("node-canvas not found:", e.message);
  process.exit(1);
}

// Register font
const FONT_FAMILY = "Proxima Nova";
if (FONT_PATH && fs.existsSync(FONT_PATH)) {
  registerFont_fn(FONT_PATH, { family: FONT_FAMILY, weight: "800" });
  registerFont_fn(FONT_PATH, { family: FONT_FAMILY, weight: "700" });
  registerFont_fn(FONT_PATH, { family: FONT_FAMILY, weight: "400" });
}
const SAFE_FONT = FONT_PATH ? `'${FONT_FAMILY}'` : "sans-serif";

// Load Konva
let Konva;
try {
  Konva = (await import("konva/cmj/index-node.js")).default;
} catch (_) {
  Konva = (await import("konva")).default;
}

// Load illustrations
let illustrations = {};
if (ILLUS_PATH && fs.existsSync(ILLUS_PATH)) {
  illustrations = await import(path.resolve(ILLUS_PATH));
}

// Load and shift beats
const rawBeats = JSON.parse(fs.readFileSync(args.beats, "utf8"));
const beats = rawBeats.map(b => ({
  ...b,
  start: Math.max(0, b.start - startT),
  end:   Math.min(chunkDur, b.end - startT),
})).filter(b => b.end > b.start && b.end > 0);

// Copy animation/rendering helpers from render-overlay.mjs
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

function hexToRgb(hex) {
  const h = hex.replace("#", "");
  return { r: parseInt(h.slice(0,2), 16), g: parseInt(h.slice(2,4), 16), b: parseInt(h.slice(4,6), 16) };
}
function rgbToHex({ r, g, b }) { return "#" + [r,g,b].map(v => v.toString(16).padStart(2, "0")).join(""); }
function lerpColor(a, b, t) {
  const ca = hexToRgb(a), cb = hexToRgb(b);
  return rgbToHex({ r: Math.round(ca.r + (cb.r - ca.r) * t), g: Math.round(ca.g + (cb.g - ca.g) * t), b: Math.round(ca.b + (cb.b - ca.b) * t) });
}
function gradientAngle(t) { return (t * 15) % 360; }
const ANIM_DURATIONS = { pop: 0.25, "slide-up": 0.3, "slide-down": 0.3, "slide-left": 0.3, "slide-right": 0.3, drop: 0.35, fade: 0.3, "snap-up": 0.2, "snap-down": 0.2 };
function easeOutCubic(t) { return 1 - Math.pow(1 - Math.min(Math.max(t, 0), 1), 3); }
function easeInCubic(t)  { return Math.pow(Math.min(Math.max(t, 0), 1), 3); }

function beatState(beat, t) {
  if (t < beat.start || t >= beat.end) return null;
  const inDur  = beat.inDur  ?? ANIM_DURATIONS[beat.inAnim  ?? "fade"] ?? 0.3;
  const outDur = beat.outDur ?? ANIM_DURATIONS[beat.outAnim ?? "fade"] ?? 0.3;
  const tLocal  = t - beat.start;
  const tFromEnd = beat.end - t;
  const inProgress  = Math.min(tLocal / inDur, 1);
  const outProgress = Math.min((outDur - tFromEnd) / outDur, 1);
  const isIn  = tLocal < inDur;
  const isOut = tFromEnd < outDur;
  let alpha = 1, scaleX = 1, scaleY = 1, offsetX = 0, offsetY = 0;
  if (isIn) {
    switch (beat.inAnim) {
      case "fade": alpha = easeOutCubic(inProgress); break;
      case "pop": scaleX = scaleY = 0.5 + 0.5 * easeOutCubic(inProgress); alpha = easeOutCubic(inProgress * 2); break;
      case "slide-up": offsetY = (1 - easeOutCubic(inProgress)) * 80; alpha = easeOutCubic(inProgress); break;
      case "slide-down": offsetY = -(1 - easeOutCubic(inProgress)) * 80; alpha = easeOutCubic(inProgress); break;
      case "slide-left": offsetX = (1 - easeOutCubic(inProgress)) * 80; alpha = easeOutCubic(inProgress); break;
      case "slide-right": offsetX = -(1 - easeOutCubic(inProgress)) * 80; alpha = easeOutCubic(inProgress); break;
      case "drop": offsetY = -(1 - easeOutCubic(inProgress)) * 120; alpha = easeOutCubic(inProgress * 2); break;
      default: alpha = easeOutCubic(inProgress);
    }
  }
  if (isOut && outProgress > 0) {
    switch (beat.outAnim) {
      case "fade": alpha *= 1 - easeInCubic(outProgress); break;
      case "pop": scaleX *= 1 + 0.15 * outProgress; scaleY = scaleX; alpha *= 1 - easeInCubic(outProgress); break;
      case "snap-up": offsetY -= outProgress * 60; alpha *= 1 - easeInCubic(outProgress); break;
      case "snap-down": offsetY += outProgress * 60; alpha *= 1 - easeInCubic(outProgress); break;
      case "slide-left": offsetX -= outProgress * 80; alpha *= 1 - easeInCubic(outProgress); break;
      case "slide-right": offsetX += outProgress * 80; alpha *= 1 - easeInCubic(outProgress); break;
      default: alpha *= 1 - easeInCubic(outProgress);
    }
  }
  const idleT = t - beat.start - inDur;
  let idleScale = 1;
  if (!isIn && !isOut && beat.idle) {
    switch (beat.idle) {
      case "bob": offsetY += Math.sin(idleT * 1.8) * 5; break;
      case "breathe": idleScale = 1 + Math.sin(idleT * 1.2) * 0.012; break;
      case "pulse": idleScale = 1 + Math.sin(idleT * 2.4) * 0.02; break;
    }
  }
  return { alpha: Math.max(0, Math.min(1, alpha)), scaleX: scaleX * idleScale, scaleY: scaleY * idleScale, offsetX, offsetY };
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath(); ctx.moveTo(x+r, y); ctx.lineTo(x+w-r, y); ctx.quadraticCurveTo(x+w, y, x+w, y+r);
  ctx.lineTo(x+w, y+h-r); ctx.quadraticCurveTo(x+w, y+h, x+w-r, y+h);
  ctx.lineTo(x+r, y+h); ctx.quadraticCurveTo(x, y+h, x, y+h-r); ctx.lineTo(x, y+r);
  ctx.quadraticCurveTo(x, y, x+r, y); ctx.closePath();
}

function drawDropShadow(ctx, fn) {
  for (const { blur, offsetY, alpha } of [{ blur:24, offsetY:12, alpha:0.12 },{ blur:12, offsetY:6, alpha:0.18 },{ blur:6, offsetY:3, alpha:0.22 }]) {
    ctx.save(); ctx.shadowColor = `rgba(0,0,0,${alpha})`; ctx.shadowBlur = blur; ctx.shadowOffsetX = 0; ctx.shadowOffsetY = offsetY;
    fn(ctx); ctx.restore();
  }
}

function strokeLiquidOutline(ctx, cx, cy, pw, ph, r, palette, t) {
  const WAVE_AMP = 10, WAVE_FREQ = 4, EXPAND = 6;
  const x = cx - pw/2, y = cy - ph/2;
  const N = 120; const points = []; const totalPerim = 2 * (pw + ph);
  for (let i = 0; i < N; i++) {
    const u = i/N; const d = u * totalPerim; let px, py, nx, ny;
    if (d < pw) { px = x+d; py = y; nx = 0; ny = -1; }
    else if (d < pw+ph) { px = x+pw; py = y+(d-pw); nx = 1; ny = 0; }
    else if (d < 2*pw+ph) { px = x+pw-(d-pw-ph); py = y+ph; nx = 0; ny = 1; }
    else { px = x; py = y+ph-(d-2*pw-ph); nx = -1; ny = 0; }
    const phase = u * Math.PI * 2 * WAVE_FREQ + t * 2;
    const amp = WAVE_AMP * ((Math.sin(phase) + 1) / 2);
    points.push({ x: px + nx*(EXPAND+amp), y: py + ny*(EXPAND+amp) });
  }
  const grad = ctx.createLinearGradient(cx-pw/2, cy-ph/2, cx+pw/2, cy+ph/2);
  for (let i = 0; i < palette.length; i++) grad.addColorStop(i/(palette.length-1), palette[i]);
  ctx.save(); ctx.beginPath(); ctx.moveTo(points[0].x, points[0].y);
  for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y);
  ctx.closePath(); ctx.strokeStyle = grad; ctx.lineWidth = 3; ctx.globalAlpha *= 0.7; ctx.stroke(); ctx.restore();
}

function fillPillBody(ctx, cx, cy, pw, ph, r, palette, t) {
  const angle = (gradientAngle(t) * Math.PI) / 180;
  const halfDiag = Math.sqrt(pw*pw + ph*ph) / 2;
  const grad = ctx.createLinearGradient(cx + Math.cos(angle)*halfDiag, cy + Math.sin(angle)*halfDiag, cx - Math.cos(angle)*halfDiag, cy - Math.sin(angle)*halfDiag);
  grad.addColorStop(0, palette[0]); grad.addColorStop(0.33, palette[1]); grad.addColorStop(0.66, palette[2]); grad.addColorStop(1, palette[3]);
  ctx.save(); ctx.beginPath(); roundRect(ctx, cx-pw/2, cy-ph/2, pw, ph, r); ctx.fillStyle = grad; ctx.fill(); ctx.restore();
}

function drawPill(ctx, beat, t, state) {
  const { cx, cy } = resolveBeatPosition(beat); const p = beat.props ?? {};
  const text = p.text ?? ""; const fontSize = p.fontSize ?? 56;
  const palette = p.palette ?? ["#1E3A5F","#2563EB","#3B82F6","#93C5FD","#DBEAFE","#EFF6FF"];
  const fill = p.fill ?? palette[1]; const textColor = p.textColor ?? "#FFFFFF";
  ctx.font = `800 ${fontSize}px ${SAFE_FONT}`;
  const textW = ctx.measureText(text).width;
  const pw = textW + fontSize*1.6; const ph = fontSize*1.8; const r = ph/2;
  ctx.save(); ctx.globalAlpha = state.alpha; ctx.translate(cx+state.offsetX, cy+state.offsetY); ctx.scale(state.scaleX, state.scaleY);
  drawDropShadow(ctx, (sCtx) => { sCtx.beginPath(); roundRect(sCtx, -pw/2, -ph/2, pw, ph, r); sCtx.fillStyle = fill; sCtx.fill(); });
  fillPillBody(ctx, 0, 0, pw, ph, r, palette, t);
  strokeLiquidOutline(ctx, 0, 0, pw, ph, r, palette, t);
  ctx.font = `800 ${fontSize}px ${SAFE_FONT}`; ctx.fillStyle = textColor; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText(text, 0, 0);
  ctx.restore();
}

function drawEmoji(ctx, beat, t, state) {
  const { cx, cy } = resolveBeatPosition(beat); const p = beat.props ?? {};
  const emoji = p.text ?? "✨"; const size = p.size ?? 200;
  ctx.save(); ctx.globalAlpha = state.alpha; ctx.font = `${size}px ${SAFE_FONT}`;
  ctx.textAlign = "center"; ctx.textBaseline = "middle";
  ctx.translate(cx+state.offsetX, cy+state.offsetY); ctx.scale(state.scaleX, state.scaleY);
  ctx.fillStyle = "black"; ctx.fillText(emoji, 0, 0); ctx.restore();
}

function drawPrimitive(ctx, beat, t, state) {
  const { cx, cy } = resolveBeatPosition(beat); const p = beat.props ?? {};
  const drawKey = p.draw; const drawFn = drawKey ? (illustrations[drawKey] ?? null) : null;
  if (!drawFn) {
    ctx.save(); ctx.globalAlpha = state.alpha * 0.6; ctx.translate(cx+state.offsetX, cy+state.offsetY); ctx.scale(state.scaleX, state.scaleY);
    ctx.beginPath(); roundRect(ctx, -140, -100, 280, 200, 14); ctx.fillStyle = "rgba(255,255,255,0.1)"; ctx.fill();
    ctx.font = `400 32px ${SAFE_FONT}`; ctx.fillStyle = "rgba(255,255,255,0.5)"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText(drawKey ?? "(primitive)", 0, 0); ctx.restore(); return;
  }
  ctx.save(); ctx.globalAlpha = state.alpha; ctx.translate(cx+state.offsetX, cy+state.offsetY); ctx.scale(state.scaleX, state.scaleY);
  drawFn(ctx, t - beat.start, p); ctx.restore();
}

function drawBackground(ctx, t) {
  const hue1 = (220 + Math.sin(t * 0.08) * 15) | 0;
  const hue2 = (260 + Math.sin(t * 0.05) * 20) | 0;
  const grad = ctx.createLinearGradient(0, 0, W, H);
  grad.addColorStop(0, `hsl(${hue1}, 30%, 8%)`); grad.addColorStop(1, `hsl(${hue2}, 25%, 6%)`);
  ctx.fillStyle = grad; ctx.fillRect(0, 0, W, H);
}

function renderFrame(ctx, t) {
  ctx.clearRect(0, 0, W, H);
  drawBackground(ctx, t);
  for (const beat of beats) {
    if (beat.kind === "broll") continue;
    const state = beatState(beat, t);
    if (!state) continue;
    switch (beat.type) {
      case "hook": case "keyword": case "cta": drawPill(ctx, beat, t, state); break;
      case "emoji": drawEmoji(ctx, beat, t, state); break;
      case "primitive": drawPrimitive(ctx, beat, t, state); break;
      default: drawPill(ctx, { ...beat, props: { ...beat.props, text: beat.id } }, t, state);
    }
  }
}

// Create canvas
const canvas = createCanvas_fn(W, H);
const ctx = canvas.getContext("2d");

// Render frames to PNG files
process.stderr.write(`[render-to-pngs] ${startT}s-${endT}s (${TOTAL_FRAMES} frames) → ${pngDir}\n`);

for (let frame = 0; frame < TOTAL_FRAMES; frame++) {
  const t = frame / FPS;
  renderFrame(ctx, t);
  const buf = canvas.toBuffer("image/png");
  const framePath = path.join(pngDir, `frame-${String(frame).padStart(6, "0")}.png`);
  fs.writeFileSync(framePath, buf);
  if (frame % 30 === 0) process.stderr.write(`\r[render-to-pngs] ${Math.floor(frame/TOTAL_FRAMES*100)}% (${frame}/${TOTAL_FRAMES})`);
}
process.stderr.write(`\n[render-to-pngs] All frames written. Encoding with ffmpeg...\n`);

// Encode PNG sequence to MP4
fs.mkdirSync(path.dirname(path.resolve(OUT_PATH)), { recursive: true });
const ffResult = spawnSync("ffmpeg", [
  "-y",
  "-framerate", String(FPS),
  "-i", path.join(pngDir, "frame-%06d.png"),
  "-c:v", "libx264",
  "-pix_fmt", "yuv420p",
  "-preset", "medium",
  "-crf", "20",
  "-movflags", "+faststart",
  OUT_PATH
], { stdio: "inherit" });

if (ffResult.status !== 0) {
  process.stderr.write(`[render-to-pngs] ERROR: ffmpeg failed\n`);
  process.exit(1);
}

// Cleanup PNG frames
for (let frame = 0; frame < TOTAL_FRAMES; frame++) {
  const framePath = path.join(pngDir, `frame-${String(frame).padStart(6, "0")}.png`);
  fs.unlinkSync(framePath);
}
fs.rmdirSync(pngDir);

process.stderr.write(`[render-to-pngs] Done → ${OUT_PATH}\n`);
