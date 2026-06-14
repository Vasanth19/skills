#!/usr/bin/env node
/**
 * render-overlay-fx.cjs
 * Renders transparent PNG sequences (1080×1920, 30fps) for 3 animated overlay elements:
 *   - flowchart: compact "Record → Edit → Post" flow diagram, lower-center
 *   - sticker:   🔥 emoji badge or "$0 FREE" rounded badge, top-right
 *   - pill:      accent pill "See this →", mid-left
 *
 * All three share the same motion envelope (reused from render-accent-pill.cjs):
 *   slide-in (ease-out + overshoot) → wiggle (damped oscillation) → hold (breathe) → slide-out (ease-in)
 *
 * Usage:
 *   node render-overlay-fx.cjs <element_type> <outdir>
 *   element_type: flowchart | sticker | pill
 *
 * Output: <outdir>/frame-NNNN.png  (75 frames = 2.5s at 30fps)
 */
'use strict';

const fs   = require('fs');
const path = require('path');
const { createCanvas } = require('canvas');

// ─── CLI args ────────────────────────────────────────────────────────────────
const [,, elementType, outDir] = process.argv;
if (!elementType || !outDir) {
  process.stderr.write('Usage: node render-overlay-fx.cjs <flowchart|sticker|pill> <outdir>\n');
  process.exit(1);
}
const VALID_TYPES = ['flowchart', 'sticker', 'pill'];
if (!VALID_TYPES.includes(elementType)) {
  process.stderr.write(`Unknown element type "${elementType}". Valid: ${VALID_TYPES.join(', ')}\n`);
  process.exit(1);
}

fs.mkdirSync(outDir, { recursive: true });

// ─── Canvas / timing constants ────────────────────────────────────────────────
const W          = 1080;
const H          = 1920;
const FPS        = 30;
const DURATION   = 2.5;   // seconds
const TOTAL_FRAMES = Math.ceil(DURATION * FPS); // 75

// ─── Motion envelope phase timings (proportional, matching render-accent-pill.cjs) ───
// 2.5s total:
//   slide-in   0.00 → 0.375s  (15% of 2.5s)
//   wiggle     0.375 → 0.875s  (20% of 2.5s)
//   hold       0.875 → 2.125s (50% of 2.5s)
//   slide-out  2.125 → 2.5s   (15% of 2.5s)
const SLIDE_IN_DUR  = 0.375;
const WIGGLE_DUR    = 0.500;
const HOLD_DUR      = 1.250;
const SLIDE_OUT_DUR = 0.375;
// total = 2.5s

// ─── Easing ──────────────────────────────────────────────────────────────────
function easeOutBack(t) {
  // cubic ease-out with slight overshoot
  const c1 = 1.70158;
  const c3 = c1 + 1;
  const tt = Math.max(0, Math.min(1, t));
  return 1 + c3 * Math.pow(tt - 1, 3) + c1 * Math.pow(tt - 1, 2);
}
function easeInBack(t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  const tt = Math.max(0, Math.min(1, t));
  return c3 * tt * tt * tt - c1 * tt * tt;
}
const easeOut3 = t => 1 - Math.pow(1 - Math.max(0, Math.min(1, t)), 3);
const easeIn3  = t => Math.pow(Math.max(0, Math.min(1, t)), 3);

/**
 * Compute the motion state at local time tLocal (0 → DURATION).
 * direction: 'left' | 'right' | 'up' | 'down'  — which edge to slide in from
 * slideAmount: pixels to slide (default: 220px for element width)
 */
function motionState(tLocal, direction, slideAmount) {
  const slide = slideAmount || 220;
  const SLIDE_END  = SLIDE_IN_DUR;
  const WIGGLE_END = SLIDE_END + WIGGLE_DUR;
  const HOLD_END   = WIGGLE_END + HOLD_DUR;

  if (tLocal < 0 || tLocal >= DURATION) return null;

  let offsetX  = 0;
  let offsetY  = 0;
  let rotation = 0;
  let scale    = 1.0;
  let alpha    = 1.0;

  if (tLocal < SLIDE_END) {
    // Phase 1: slide-in with ease-out-back overshoot
    const progress = tLocal / SLIDE_IN_DUR;
    const tNorm    = easeOutBack(progress); // 0→1 with overshoot
    const raw      = (1 - Math.max(0, Math.min(1.05, tNorm))) * slide;
    switch (direction) {
      case 'left':  offsetX = -raw; break;
      case 'right': offsetX =  raw; break;
      case 'up':    offsetY =  raw; break;
      case 'down':  offsetY = -raw; break;
    }
    alpha = Math.min(1, progress * 2.5); // fast fade-in

  } else if (tLocal < WIGGLE_END) {
    // Phase 2: damped oscillation (rotation + bounce)
    const τ     = tLocal - SLIDE_END;
    const decay = Math.exp(-8 * τ);
    const osc   = Math.sin(18 * τ);
    rotation    = 6.0 * decay * osc;   // degrees, ±6° peak → damps
    offsetY     = -10 * decay * osc;   // px vertical bounce
    offsetX     = 0;
    alpha       = 1.0;

  } else if (tLocal < HOLD_END) {
    // Phase 3: hold with subtle scale breathe
    const holdT = tLocal - WIGGLE_END;
    scale       = 1.0 + 0.015 * Math.sin(2 * Math.PI * 1.2 * holdT);
    rotation    = 0;
    offsetX     = 0;
    offsetY     = 0;
    alpha       = 1.0;

  } else {
    // Phase 4: slide-out (opposite direction) with ease-in-back
    const progress = (tLocal - HOLD_END) / SLIDE_OUT_DUR;
    const tNorm    = easeInBack(Math.min(progress, 1));
    const raw      = Math.max(0, tNorm) * slide;
    switch (direction) {
      case 'left':  offsetX = -raw; break;
      case 'right': offsetX =  raw; break;
      case 'up':    offsetY =  raw; break;
      case 'down':  offsetY = -raw; break;
    }
    alpha = Math.max(0, 1 - progress * 1.3);
    rotation = 0;
  }

  return { offsetX, offsetY, rotation, scale, alpha };
}

// ─── Helper: rounded rect path ───────────────────────────────────────────────
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

// ─── ELEMENT DRAWERS ─────────────────────────────────────────────────────────

/**
 * PILL — accent pill with text "See this →", slides in from LEFT, centered at mid-left
 * Rest position: cx=270, cy=960 (mid-left)
 */
function drawPill(ctx, tLocal) {
  const state = motionState(tLocal, 'left', 320);
  if (!state) return;
  const { offsetX, offsetY, rotation, scale, alpha } = state;

  const restX = 270;
  const restY = 960;

  const label    = 'See this →';
  const fontSize = 34;
  const paddingH = 36;
  const pillH    = 80;
  const cornerR  = 40;

  ctx.save();
  ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
  ctx.translate(restX + offsetX, restY + offsetY);
  ctx.rotate((rotation * Math.PI) / 180);
  ctx.scale(scale, scale);

  ctx.font = `700 ${fontSize}px sans-serif`;
  const textW = ctx.measureText(label).width;
  const pillW = textW + paddingH * 2;
  const pillX = -pillW / 2;
  const pillY = -pillH / 2;

  // Shadow
  ctx.save();
  ctx.shadowColor   = 'rgba(0,0,0,0.35)';
  ctx.shadowBlur    = 16;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 6;
  ctx.fillStyle     = 'rgba(255,255,255,0.93)';
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.fill();
  ctx.restore();

  // Body
  ctx.fillStyle = 'rgba(255,255,255,0.93)';
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.fill();

  // Accent left stripe
  ctx.save();
  ctx.fillStyle = '#6366F1'; // indigo
  roundRect(ctx, pillX, pillY, 8, pillH, 4);
  ctx.fill();
  ctx.restore();

  // Border
  ctx.strokeStyle = 'rgba(99,102,241,0.25)';
  ctx.lineWidth   = 1.5;
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.stroke();

  // Text
  ctx.font         = `700 ${fontSize}px sans-serif`;
  ctx.fillStyle    = '#1a1a2e';
  ctx.textAlign    = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(label, 0, 0);

  ctx.restore();
}

/**
 * STICKER — "$0 FREE" bold badge, slides in from RIGHT, top-right position
 * Rest position: cx=870, cy=380
 */
function drawSticker(ctx, tLocal) {
  const state = motionState(tLocal, 'right', 280);
  if (!state) return;
  const { offsetX, offsetY, rotation, scale, alpha } = state;

  const restX = 870;
  const restY = 380;

  ctx.save();
  ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
  ctx.translate(restX + offsetX, restY + offsetY);
  ctx.rotate((rotation * Math.PI) / 180);
  ctx.scale(scale, scale);

  // Outer badge circle / rounded square
  const bW = 160, bH = 160, bR = 28;
  const bX = -bW / 2, bY = -bH / 2;

  // Shadow
  ctx.save();
  ctx.shadowColor   = 'rgba(0,0,0,0.40)';
  ctx.shadowBlur    = 20;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 8;
  ctx.fillStyle     = '#FF6B00'; // bold orange
  roundRect(ctx, bX, bY, bW, bH, bR);
  ctx.fill();
  ctx.restore();

  // Badge body (orange gradient-ish via layers)
  const grad = ctx.createLinearGradient(bX, bY, bX, bY + bH);
  grad.addColorStop(0, '#FF8A00');
  grad.addColorStop(1, '#E84000');
  ctx.fillStyle = grad;
  roundRect(ctx, bX, bY, bW, bH, bR);
  ctx.fill();

  // Inner highlight ring
  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.lineWidth   = 2.5;
  roundRect(ctx, bX + 5, bY + 5, bW - 10, bH - 10, bR - 2);
  ctx.stroke();

  // "$0" big text
  ctx.font         = '800 58px sans-serif';
  ctx.fillStyle    = '#FFFFFF';
  ctx.textAlign    = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('$0', 0, -20);

  // "FREE" label below
  ctx.font         = '700 28px sans-serif';
  ctx.fillStyle    = 'rgba(255,255,220,0.95)';
  ctx.fillText('FREE', 0, 26);

  // Small star accents in corners
  ctx.font         = '18px sans-serif';
  ctx.fillStyle    = 'rgba(255,255,255,0.7)';
  ctx.fillText('★', bX + 12, bY + 16);
  ctx.fillText('★', bX + bW - 28, bY + bH - 18);

  ctx.restore();
}

/**
 * FLOWCHART — compact 3-node "Record → Edit → Post" flow, slides UP from bottom
 * Rest position: cx=540, cy=1650 (lower-center)
 */
function drawFlowchart(ctx, tLocal) {
  const state = motionState(tLocal, 'down', 300);
  if (!state) return;
  const { offsetX, offsetY, rotation, scale, alpha } = state;

  const restX = 540;
  const restY = 1650;

  ctx.save();
  ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
  ctx.translate(restX + offsetX, restY + offsetY);
  ctx.rotate((rotation * Math.PI) / 180);
  ctx.scale(scale, scale);

  // Flow nodes: 3 boxes side-by-side with arrows
  const nodes    = ['Record', 'Edit', 'Post'];
  const colors   = ['#6366F1', '#8B5CF6', '#10B981'];  // indigo, violet, emerald
  const nodeW    = 130, nodeH = 60, nodeR = 14;
  const gap      = 28;
  const arrowLen = gap;
  const totalW   = nodes.length * nodeW + (nodes.length - 1) * gap;
  const startX   = -totalW / 2;
  const nodeY    = -nodeH / 2;

  // Background capsule behind the entire chart
  const padX = 20, padY = 16;
  ctx.save();
  ctx.shadowColor   = 'rgba(0,0,0,0.30)';
  ctx.shadowBlur    = 22;
  ctx.shadowOffsetY = 8;
  ctx.fillStyle     = 'rgba(15,15,30,0.82)';
  roundRect(ctx, startX - padX, nodeY - padY, totalW + padX * 2, nodeH + padY * 2, 24);
  ctx.fill();
  ctx.restore();

  // Draw each node + arrows
  for (let i = 0; i < nodes.length; i++) {
    const nx = startX + i * (nodeW + gap);

    // Node shadow
    ctx.save();
    ctx.shadowColor   = 'rgba(0,0,0,0.25)';
    ctx.shadowBlur    = 10;
    ctx.shadowOffsetY = 4;
    ctx.fillStyle     = colors[i];
    roundRect(ctx, nx, nodeY, nodeW, nodeH, nodeR);
    ctx.fill();
    ctx.restore();

    // Node body
    ctx.fillStyle = colors[i];
    roundRect(ctx, nx, nodeY, nodeW, nodeH, nodeR);
    ctx.fill();

    // Node inner highlight
    ctx.save();
    ctx.strokeStyle = 'rgba(255,255,255,0.3)';
    ctx.lineWidth   = 1.5;
    roundRect(ctx, nx + 2, nodeY + 2, nodeW - 4, nodeH - 4, nodeR - 1);
    ctx.stroke();
    ctx.restore();

    // Node label
    ctx.font         = '700 28px sans-serif';
    ctx.fillStyle    = '#FFFFFF';
    ctx.textAlign    = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(nodes[i], nx + nodeW / 2, 0);

    // Arrow to next node
    if (i < nodes.length - 1) {
      const arrowStartX = nx + nodeW + 4;
      const arrowEndX   = nx + nodeW + gap - 4;
      const midY        = 0;

      ctx.save();
      ctx.strokeStyle = 'rgba(255,255,255,0.65)';
      ctx.lineWidth   = 2.5;
      ctx.lineCap     = 'round';
      ctx.beginPath();
      ctx.moveTo(arrowStartX, midY);
      ctx.lineTo(arrowEndX - 8, midY);
      ctx.stroke();

      // Arrowhead
      ctx.fillStyle = 'rgba(255,255,255,0.65)';
      ctx.beginPath();
      ctx.moveTo(arrowEndX, midY);
      ctx.lineTo(arrowEndX - 10, midY - 5);
      ctx.lineTo(arrowEndX - 10, midY + 5);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }
  }

  // Bottom label: "Your content workflow"
  ctx.font         = '600 22px sans-serif';
  ctx.fillStyle    = 'rgba(255,255,255,0.55)';
  ctx.textAlign    = 'center';
  ctx.textBaseline = 'top';
  ctx.fillText('your content workflow', 0, nodeH / 2 + 10);

  ctx.restore();
}

// ─── ELEMENT REGISTRY ────────────────────────────────────────────────────────
const ELEMENTS = {
  pill:      drawPill,
  sticker:   drawSticker,
  flowchart: drawFlowchart,
};

// ─── MAIN RENDER LOOP ────────────────────────────────────────────────────────
const drawFn = ELEMENTS[elementType];
if (!drawFn) {
  process.stderr.write(`No draw function for "${elementType}"\n`);
  process.exit(1);
}

const canvas = createCanvas(W, H);
const ctx    = canvas.getContext('2d');

process.stderr.write(`[render-overlay-fx] type=${elementType} → ${TOTAL_FRAMES} frames (${DURATION}s @ ${FPS}fps) → ${outDir}\n`);
const t0 = Date.now();

for (let frame = 0; frame < TOTAL_FRAMES; frame++) {
  const tLocal = frame / FPS;

  // Clear to fully transparent
  ctx.clearRect(0, 0, W, H);

  // Draw the element
  drawFn(ctx, tLocal);

  // Write PNG (toBuffer with image/png preserves alpha)
  const buf       = canvas.toBuffer('image/png');
  const framePath = path.join(outDir, `frame-${String(frame).padStart(4, '0')}.png`);
  fs.writeFileSync(framePath, buf);

  if (frame % 15 === 0) {
    const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
    process.stderr.write(`  frame ${frame}/${TOTAL_FRAMES} (${elapsed}s)\n`);
  }
}

const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
process.stderr.write(`[render-overlay-fx] Done — ${TOTAL_FRAMES} frames in ${elapsed}s\n`);
process.stdout.write(`PNGDIR=${outDir}\n`);
