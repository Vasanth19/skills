#!/usr/bin/env node
/**
 * render-overlay-fx-safe.cjs
 * Wrapper around render-overlay-fx.cjs draw logic with LAYOUT-SAFE positions
 * for the HyperFrames split reel (1080x1920):
 *   top half (0-960):    graphics + title text "I BUILT A CONTENT PIPELINE IN 2 HOURS" (~y:120-460)
 *   bottom half (960-1920): avatar face centered (~x:220-860, y:1000-1700)
 *
 * SAFE positions chosen to avoid face AND title:
 *   sticker   (160x160): top-right corner, below title   cx=920, cy=680  → x:840-1000, y:600-760  CLEAR
 *   flowchart (~490x92): top-half center, below title    cx=540, cy=750  → x:297-783, y:704-796  CLEAR
 *   pill      (~300x80): lower-right margin beside face  cx=960, cy=1800 → x:810-1110, y:1760-1840  CLEAR (x>860)
 *
 * Same motion envelope as render-overlay-fx.cjs — slide-in→wiggle→hold→slide-out
 */
'use strict';

const fs   = require('fs');
const path = require('path');
const { createCanvas } = require('canvas');

const [,, elementType, outDir] = process.argv;
if (!elementType || !outDir) {
  process.stderr.write('Usage: node render-overlay-fx-safe.cjs <flowchart|sticker|pill> <outdir>\n');
  process.exit(1);
}

const VALID_TYPES = ['flowchart', 'sticker', 'pill'];
if (!VALID_TYPES.includes(elementType)) {
  process.stderr.write(`Unknown element type "${elementType}". Valid: ${VALID_TYPES.join(', ')}\n`);
  process.exit(1);
}

fs.mkdirSync(outDir, { recursive: true });

const W            = 1080;
const H            = 1920;
const FPS          = 30;
const DURATION     = 2.5;
const TOTAL_FRAMES = Math.ceil(DURATION * FPS); // 75

const SLIDE_IN_DUR  = 0.375;
const WIGGLE_DUR    = 0.500;
const HOLD_DUR      = 1.250;
const SLIDE_OUT_DUR = 0.375;

function easeOutBack(t) {
  const c1 = 1.70158, c3 = c1 + 1, tt = Math.max(0, Math.min(1, t));
  return 1 + c3 * Math.pow(tt - 1, 3) + c1 * Math.pow(tt - 1, 2);
}
function easeInBack(t) {
  const c1 = 1.70158, c3 = c1 + 1, tt = Math.max(0, Math.min(1, t));
  return c3 * tt * tt * tt - c1 * tt * tt;
}

function motionState(tLocal, direction, slideAmount) {
  const slide    = slideAmount || 220;
  const SLIDE_END  = SLIDE_IN_DUR;
  const WIGGLE_END = SLIDE_END + WIGGLE_DUR;
  const HOLD_END   = WIGGLE_END + HOLD_DUR;

  if (tLocal < 0 || tLocal >= DURATION) return null;

  let offsetX = 0, offsetY = 0, rotation = 0, scale = 1.0, alpha = 1.0;

  if (tLocal < SLIDE_END) {
    const progress = tLocal / SLIDE_IN_DUR;
    const tNorm    = easeOutBack(progress);
    const raw      = (1 - Math.max(0, Math.min(1.05, tNorm))) * slide;
    switch (direction) {
      case 'left':  offsetX = -raw; break;
      case 'right': offsetX =  raw; break;
      case 'up':    offsetY =  raw; break;
      case 'down':  offsetY = -raw; break;
    }
    alpha = Math.min(1, progress * 2.5);
  } else if (tLocal < WIGGLE_END) {
    const τ = tLocal - SLIDE_END;
    const decay = Math.exp(-8 * τ), osc = Math.sin(18 * τ);
    rotation = 6.0 * decay * osc;
    offsetY  = -10 * decay * osc;
  } else if (tLocal < HOLD_END) {
    const holdT = tLocal - WIGGLE_END;
    scale = 1.0 + 0.015 * Math.sin(2 * Math.PI * 1.2 * holdT);
  } else {
    const progress = (tLocal - HOLD_END) / SLIDE_OUT_DUR;
    const tNorm    = easeInBack(Math.min(progress, 1));
    const raw      = Math.max(0, tNorm) * slide;
    switch (direction) {
      case 'left':  offsetX = -raw; break;
      case 'right': offsetX =  raw; break;
      case 'up':    offsetY =  raw; break;
      case 'down':  offsetY = -raw; break;
    }
    alpha    = Math.max(0, 1 - progress * 1.3);
    rotation = 0;
  }

  return { offsetX, offsetY, rotation, scale, alpha };
}

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

// ─── PILL — lower-right margin, beside the face (x > 860) ───────────────────
// Safe: cx=960, cy=1800 → bounds x:810-1110 (clipped to 1080), y:1760-1840
// Face is at x:220-860, so x>860 is clear; y:1800 is below y:1700 face bottom
function drawPill(ctx, tLocal) {
  const state = motionState(tLocal, 'right', 280);  // slides in from RIGHT edge
  if (!state) return;
  const { offsetX, offsetY, rotation, scale, alpha } = state;

  const restX = 960;   // SAFE: right margin, x>860 avoids face
  const restY = 1800;  // SAFE: y>1750 is below face bottom

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

  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.35)'; ctx.shadowBlur = 16; ctx.shadowOffsetY = 6;
  ctx.fillStyle = 'rgba(255,255,255,0.93)';
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.fill();
  ctx.restore();

  ctx.fillStyle = 'rgba(255,255,255,0.93)';
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.fill();

  ctx.save();
  ctx.fillStyle = '#6366F1';
  roundRect(ctx, pillX, pillY, 8, pillH, 4);
  ctx.fill();
  ctx.restore();

  ctx.strokeStyle = 'rgba(99,102,241,0.25)'; ctx.lineWidth = 1.5;
  roundRect(ctx, pillX, pillY, pillW, pillH, cornerR);
  ctx.stroke();

  ctx.font = `700 ${fontSize}px sans-serif`;
  ctx.fillStyle = '#1a1a2e';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText(label, 0, 0);

  ctx.restore();
}

// ─── STICKER — top-right corner, below title text ───────────────────────────
// Title text ends ~y:460. Safe: cx=920, cy=680 → badge bounds y:600-760
// x:840-1000 — right margin, clear of face (face is bottom-half)
function drawSticker(ctx, tLocal) {
  const state = motionState(tLocal, 'right', 280);
  if (!state) return;
  const { offsetX, offsetY, rotation, scale, alpha } = state;

  const restX = 920;   // SAFE: right margin; original was 870 (in title zone)
  const restY = 680;   // SAFE: below title (~460) and above seam (~960)

  ctx.save();
  ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
  ctx.translate(restX + offsetX, restY + offsetY);
  ctx.rotate((rotation * Math.PI) / 180);
  ctx.scale(scale, scale);

  const bW = 160, bH = 160, bR = 28;
  const bX = -bW / 2, bY = -bH / 2;

  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.40)'; ctx.shadowBlur = 20; ctx.shadowOffsetY = 8;
  ctx.fillStyle = '#FF6B00';
  roundRect(ctx, bX, bY, bW, bH, bR);
  ctx.fill();
  ctx.restore();

  const grad = ctx.createLinearGradient(bX, bY, bX, bY + bH);
  grad.addColorStop(0, '#FF8A00');
  grad.addColorStop(1, '#E84000');
  ctx.fillStyle = grad;
  roundRect(ctx, bX, bY, bW, bH, bR);
  ctx.fill();

  ctx.strokeStyle = 'rgba(255,255,255,0.35)'; ctx.lineWidth = 2.5;
  roundRect(ctx, bX + 5, bY + 5, bW - 10, bH - 10, bR - 2);
  ctx.stroke();

  ctx.font = '800 58px sans-serif'; ctx.fillStyle = '#FFFFFF';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText('$0', 0, -20);

  ctx.font = '700 28px sans-serif'; ctx.fillStyle = 'rgba(255,255,220,0.95)';
  ctx.fillText('FREE', 0, 26);

  ctx.font = '18px sans-serif'; ctx.fillStyle = 'rgba(255,255,255,0.7)';
  ctx.fillText('★', bX + 12, bY + 16);
  ctx.fillText('★', bX + bW - 28, bY + bH - 18);

  ctx.restore();
}

// ─── FLOWCHART — top-half center, below title, above seam ───────────────────
// Title ends ~y:460. Seam/subtitle at ~y:950. Clear band: y:500-920
// cx=540, cy=750 → chart bounds: roughly y:714-786. Centered, safe.
function drawFlowchart(ctx, tLocal) {
  const state = motionState(tLocal, 'down', 200);  // slides down from above
  if (!state) return;
  const { offsetX, offsetY, rotation, scale, alpha } = state;

  const restX = 540;   // centered horizontally
  const restY = 750;   // SAFE: y:500-920 band between title (460) and seam (950)

  ctx.save();
  ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
  ctx.translate(restX + offsetX, restY + offsetY);
  ctx.rotate((rotation * Math.PI) / 180);
  ctx.scale(scale, scale);

  const nodes  = ['Record', 'Edit', 'Post'];
  const colors = ['#6366F1', '#8B5CF6', '#10B981'];
  const nodeW = 130, nodeH = 60, nodeR = 14;
  const gap   = 28;
  const totalW = nodes.length * nodeW + (nodes.length - 1) * gap;
  const startX = -totalW / 2;
  const nodeY  = -nodeH / 2;

  const padX = 20, padY = 16;
  ctx.save();
  ctx.shadowColor = 'rgba(0,0,0,0.30)'; ctx.shadowBlur = 22; ctx.shadowOffsetY = 8;
  ctx.fillStyle = 'rgba(15,15,30,0.82)';
  roundRect(ctx, startX - padX, nodeY - padY, totalW + padX * 2, nodeH + padY * 2, 24);
  ctx.fill();
  ctx.restore();

  for (let i = 0; i < nodes.length; i++) {
    const nx = startX + i * (nodeW + gap);

    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.25)'; ctx.shadowBlur = 10; ctx.shadowOffsetY = 4;
    ctx.fillStyle = colors[i];
    roundRect(ctx, nx, nodeY, nodeW, nodeH, nodeR);
    ctx.fill();
    ctx.restore();

    ctx.fillStyle = colors[i];
    roundRect(ctx, nx, nodeY, nodeW, nodeH, nodeR);
    ctx.fill();

    ctx.save();
    ctx.strokeStyle = 'rgba(255,255,255,0.3)'; ctx.lineWidth = 1.5;
    roundRect(ctx, nx + 2, nodeY + 2, nodeW - 4, nodeH - 4, nodeR - 1);
    ctx.stroke();
    ctx.restore();

    ctx.font = '700 28px sans-serif'; ctx.fillStyle = '#FFFFFF';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(nodes[i], nx + nodeW / 2, 0);

    if (i < nodes.length - 1) {
      const arrowStartX = nx + nodeW + 4;
      const arrowEndX   = nx + nodeW + gap - 4;

      ctx.save();
      ctx.strokeStyle = 'rgba(255,255,255,0.65)'; ctx.lineWidth = 2.5; ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(arrowStartX, 0);
      ctx.lineTo(arrowEndX - 8, 0);
      ctx.stroke();

      ctx.fillStyle = 'rgba(255,255,255,0.65)';
      ctx.beginPath();
      ctx.moveTo(arrowEndX, 0);
      ctx.lineTo(arrowEndX - 10, -5);
      ctx.lineTo(arrowEndX - 10, 5);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }
  }

  ctx.font = '600 22px sans-serif'; ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.textAlign = 'center'; ctx.textBaseline = 'top';
  ctx.fillText('your content workflow', 0, nodeH / 2 + 10);

  ctx.restore();
}

// ─── MAIN ────────────────────────────────────────────────────────────────────
const ELEMENTS = { pill: drawPill, sticker: drawSticker, flowchart: drawFlowchart };
const drawFn   = ELEMENTS[elementType];
if (!drawFn) { process.stderr.write(`No draw fn for "${elementType}"\n`); process.exit(1); }

const canvas = createCanvas(W, H);
const ctx    = canvas.getContext('2d');

process.stderr.write(`[render-overlay-fx-safe] type=${elementType} → ${TOTAL_FRAMES} frames @ ${FPS}fps → ${outDir}\n`);
const t0 = Date.now();

for (let frame = 0; frame < TOTAL_FRAMES; frame++) {
  const tLocal = frame / FPS;
  ctx.clearRect(0, 0, W, H);
  drawFn(ctx, tLocal);
  const buf       = canvas.toBuffer('image/png');
  const framePath = path.join(outDir, `frame-${String(frame).padStart(4, '0')}.png`);
  fs.writeFileSync(framePath, buf);
  if (frame % 15 === 0) {
    process.stderr.write(`  frame ${frame}/${TOTAL_FRAMES} (${((Date.now()-t0)/1000).toFixed(1)}s)\n`);
  }
}
process.stderr.write(`[render-overlay-fx-safe] Done in ${((Date.now()-t0)/1000).toFixed(1)}s\n`);
process.stdout.write(`PNGDIR=${outDir}\n`);
