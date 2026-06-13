#!/usr/bin/env node
/**
 * render-accent-pill.cjs
 * Renders transparent PNG frames (1080×960, 30fps) showing 1–2 accent pills
 * with slide-in → wiggle → hold → slide-out motion.
 *
 * Usage: node render-accent-pill.cjs
 * Output: prints PNGDIR=/tmp/pill-proof2/frames when done
 */
'use strict';

const fs   = require('fs');
const path = require('path');
const { createCanvas } = require('canvas');

// ─── Constants ───────────────────────────────────────────────────────────────
const W        = 1080;
const H        = 960;
const FPS      = 30;
const DURATION = 6.0; // seconds
const TOTAL_FRAMES = Math.ceil(DURATION * FPS); // 180 frames

const PNG_DIR = '/tmp/pill-proof2/frames';
fs.mkdirSync(PNG_DIR, { recursive: true });

// ─── Easing ──────────────────────────────────────────────────────────────────
const easeOut3 = t => 1 - Math.pow(1 - Math.max(0, Math.min(1, t)), 3);
const easeIn3  = t => Math.pow(Math.max(0, Math.min(1, t)), 3);

// ─── Pill phase timing (seconds, relative to pill entry time) ─────────────────
// Phase 1: slide-in   0.00 → 0.30s  (~9 frames)
// Phase 2: wiggle     0.30 → 0.70s  (~12 frames)
// Phase 3: hold       0.70 → 2.00s  (~39 frames)
// Phase 4: slide-out  2.00 → 2.30s  (~9 frames)
const SLIDE_IN_DUR  = 0.30;
const WIGGLE_DUR    = 0.40;
const HOLD_DUR      = 1.30;
const SLIDE_OUT_DUR = 0.30;
const PILL_TOTAL    = SLIDE_IN_DUR + WIGGLE_DUR + HOLD_DUR + SLIDE_OUT_DUR; // 2.30s

/**
 * Compute per-pill animation state at local time tLocal (seconds from entry).
 * Returns { offsetX, offsetY, rotation, alpha, scale } or null if pill is inactive.
 */
function pillState(tLocal) {
  if (tLocal < 0 || tLocal >= PILL_TOTAL) return null;

  const SLIDE_END   = SLIDE_IN_DUR;
  const WIGGLE_END  = SLIDE_END + WIGGLE_DUR;
  const HOLD_END    = WIGGLE_END + HOLD_DUR;
  // SLIDE_OUT_END  = HOLD_END + SLIDE_OUT_DUR = PILL_TOTAL

  let offsetX  = 0;
  let offsetY  = 0;
  let rotation = 0; // degrees
  let scale    = 1.0;
  let alpha    = 1.0;

  if (tLocal < SLIDE_END) {
    // Phase 1: slide-in from right with ease-out
    const progress = tLocal / SLIDE_IN_DUR;
    const tNorm    = easeOut3(progress);  // 0 → 1 (ease-out)
    offsetX        = (1 - tNorm) * 300;  // 300 → 0
    // slight overshoot at end (resolved at wiggle start)
    if (progress > 0.85) {
      const overshootT = (progress - 0.85) / 0.15;
      offsetX -= overshootT * 8; // snap -8px as we land
    }
    alpha = Math.min(1, tNorm * 1.5); // fade in fast during slide

  } else if (tLocal < WIGGLE_END) {
    // Phase 2: damped oscillation (rotation + bounce)
    const τ = tLocal - SLIDE_END;  // τ in seconds, starts at 0
    const decay = Math.exp(-8 * τ);
    const osc   = Math.sin(18 * τ);
    rotation    = 6.0 * decay * osc;        // degrees, ±6° peak → damps
    offsetY     = -10 * decay * osc;        // px vertical bounce, peak -10px
    offsetX     = 0;                        // overshoot resolved
    alpha       = 1.0;

  } else if (tLocal < HOLD_END) {
    // Phase 3: hold with subtle scale breathe
    const holdT = tLocal - WIGGLE_END;
    scale       = 1.0 + 0.01 * Math.sin(2 * Math.PI * holdT * 1.2);
    rotation    = 0;
    offsetY     = 0;
    offsetX     = 0;
    alpha       = 1.0;

  } else {
    // Phase 4: slide-out to right with ease-in
    const progress = (tLocal - HOLD_END) / SLIDE_OUT_DUR;
    const tNorm    = easeIn3(progress);  // 0 → 1 (ease-in)
    offsetX        = tNorm * 300;        // 0 → 300
    alpha          = Math.max(0, 1 - tNorm * 1.2); // fade out as it exits
    rotation       = 0;
    offsetY        = 0;
  }

  return { offsetX, offsetY, rotation, alpha, scale };
}

// ─── Pill drawing ─────────────────────────────────────────────────────────────
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

/**
 * Draw a single accent pill, centered at (cx, cy) in world space.
 * state = { offsetX, offsetY, rotation (deg), alpha, scale }
 */
function drawAccentPill(ctx, label, cx, cy, state) {
  const { offsetX = 0, offsetY = 0, rotation = 0, alpha = 1.0, scale = 1.0 } = state;

  // Pill geometry
  const fontSize   = 28;
  const paddingH   = 32; // horizontal padding each side
  const pillH      = 90;
  const cornerR    = 45; // full pill shape
  const font       = `700 ${fontSize}px sans-serif`;

  ctx.save();
  ctx.globalAlpha = Math.max(0, Math.min(1, alpha));

  // Move to world position + animation offsets
  const drawX = cx + offsetX;
  const drawY = cy + offsetY;
  ctx.translate(drawX, drawY);
  ctx.rotate((rotation * Math.PI) / 180);
  ctx.scale(scale, scale);

  // Measure text at this font
  ctx.font = font;
  const textW   = ctx.measureText(label).width;
  const pillW   = textW + paddingH * 2;
  const pillX   = -pillW / 2;
  const pillY   = -pillH / 2;

  // Drop shadow (layered, for legibility on any background)
  ctx.save();
  ctx.shadowColor   = 'rgba(0, 0, 0, 0.45)';
  ctx.shadowBlur    = 14;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 5;
  ctx.fillStyle     = 'rgba(255, 255, 255, 0.92)';
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.fill();
  ctx.restore();

  // Pill body (white, 92% opacity)
  ctx.fillStyle = 'rgba(255, 255, 255, 0.92)';
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.fill();

  // Optional: thin inner accent ring for polish
  ctx.save();
  ctx.strokeStyle = 'rgba(80, 80, 90, 0.12)';
  ctx.lineWidth   = 1.5;
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.stroke();
  ctx.restore();

  // Text (dark, centered)
  ctx.font         = font;
  ctx.fillStyle    = '#1a1a1a';
  ctx.textAlign    = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(label, 0, 0);

  ctx.restore();
}

// ─── Pill definitions ─────────────────────────────────────────────────────────
// Each pill: { label, entryTime (s), restX, restY }
// restX/restY = center of pill at rest (world coords)
const PILLS = [
  {
    label:     'See this trick',
    entryTime: 0.5,
    restX:     810,  // lower-right zone
    restY:     830,
  },
  {
    label:     'Watch now',
    entryTime: 3.2,
    restX:     800,  // slightly different position
    restY:     855,
  },
];

// ─── Frame render ─────────────────────────────────────────────────────────────
const canvas = createCanvas(W, H);
const ctx    = canvas.getContext('2d');

process.stderr.write(`[render-accent-pill] Rendering ${TOTAL_FRAMES} frames at ${FPS}fps → ${PNG_DIR}\n`);
const t0 = Date.now();

for (let frame = 0; frame < TOTAL_FRAMES; frame++) {
  const tGlobal = frame / FPS; // global time in seconds

  // Clear to fully transparent
  ctx.clearRect(0, 0, W, H);

  // Draw each pill
  for (const pill of PILLS) {
    const tLocal = tGlobal - pill.entryTime;
    const state  = pillState(tLocal);
    if (!state) continue;
    drawAccentPill(ctx, pill.label, pill.restX, pill.restY, state);
  }

  // Write PNG frame
  const buf      = canvas.toBuffer('image/png');
  const framePath = path.join(PNG_DIR, `frame_${String(frame).padStart(4, '0')}.png`);
  fs.writeFileSync(framePath, buf);

  if (frame % 30 === 0) {
    const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
    process.stderr.write(`  frame ${frame}/${TOTAL_FRAMES} (${elapsed}s)\n`);
  }
}

const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
process.stderr.write(`[render-accent-pill] Done — ${TOTAL_FRAMES} frames in ${elapsed}s\n`);

// Print PNGDIR for downstream consumption
process.stdout.write(`PNGDIR=${PNG_DIR}\n`);
