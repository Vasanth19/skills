#!/usr/bin/env node
/**
 * render-cjs.js — CommonJS version, avoids ESM dynamic import overhead
 * Renders a chunk of beats to PNG files, then encodes with ffmpeg.
 */
'use strict';

const fs   = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

// Args: node render-cjs.js beats.json startT endT fps fontPath outMp4
const [,, beatsPath, startTStr, endTStr, fpsStr, fontPath, outMp4] = process.argv;
const startT = parseFloat(startTStr);
const endT   = parseFloat(endTStr);
const FPS    = parseInt(fpsStr || '30');
const chunkDur = endT - startT;
const W = 1080, H = 960;
const TOTAL_FRAMES = Math.ceil(chunkDur * FPS);

process.stderr.write(`[render-cjs] ${startT}s-${endT}s (${TOTAL_FRAMES} frames) → ${outMp4}\n`);

// Load modules (CJS, synchronous)
const { createCanvas, registerFont } = require('canvas');
const illustrations = require('./illustrations.cjs');

if (fontPath && fs.existsSync(fontPath)) {
  registerFont(fontPath, { family: 'Proxima Nova', weight: '800' });
  registerFont(fontPath, { family: 'Proxima Nova', weight: '700' });
}
const SAFE_FONT = fontPath ? "'Proxima Nova', sans-serif" : 'sans-serif';

// Load and shift beats
const rawBeats = JSON.parse(fs.readFileSync(beatsPath, 'utf8'));
const beats = rawBeats.map(b => ({
  ...b,
  start: Math.max(0, b.start - startT),
  end:   Math.min(chunkDur, b.end - startT),
})).filter(b => b.end > b.start && b.end > 0);

// Zone centroids
const ZONE_CENTROIDS = {
  'top-left':   { cx: 360, cy: 360 },
  'top-center': { cx: 540, cy: 540 },
  'top-right':  { cx: 720, cy: 360 },
};
function resolveBeatPosition(beat) {
  if (beat.cx !== undefined) return { cx: beat.cx, cy: beat.cy };
  const z = ZONE_CENTROIDS[beat.zone];
  if (!z) throw new Error(`invalid zone '${beat.zone}'`);
  return { cx: z.cx, cy: z.cy + (beat.cyOffset || 0) };
}

const ANIM_DUR = { pop: 0.25, 'slide-up': 0.3, 'slide-down': 0.3, 'slide-left': 0.3, 'slide-right': 0.3, drop: 0.35, fade: 0.3, 'snap-up': 0.2, 'snap-down': 0.2 };
const easeOut = t => 1 - Math.pow(1 - Math.max(0, Math.min(1, t)), 3);
const easeIn  = t => Math.pow(Math.max(0, Math.min(1, t)), 3);

function beatState(beat, t) {
  if (t < beat.start || t >= beat.end) return null;
  const inDur  = beat.inDur  || ANIM_DUR[beat.inAnim  || 'fade'] || 0.3;
  const outDur = beat.outDur || ANIM_DUR[beat.outAnim || 'fade'] || 0.3;
  const tLocal = t - beat.start, tFromEnd = beat.end - t;
  const isIn = tLocal < inDur, isOut = tFromEnd < outDur;
  const inProg = Math.min(tLocal / inDur, 1), outProg = Math.min((outDur - tFromEnd) / outDur, 1);
  let alpha = 1, scaleX = 1, scaleY = 1, offsetX = 0, offsetY = 0;
  if (isIn) {
    switch (beat.inAnim) {
      case 'fade':        alpha = easeOut(inProg); break;
      case 'pop':         scaleX = scaleY = 0.5 + 0.5 * easeOut(inProg); alpha = easeOut(inProg * 2); break;
      case 'slide-up':    offsetY = (1 - easeOut(inProg)) * 80; alpha = easeOut(inProg); break;
      case 'slide-down':  offsetY = -(1 - easeOut(inProg)) * 80; alpha = easeOut(inProg); break;
      case 'slide-left':  offsetX = (1 - easeOut(inProg)) * 80; alpha = easeOut(inProg); break;
      case 'slide-right': offsetX = -(1 - easeOut(inProg)) * 80; alpha = easeOut(inProg); break;
      case 'drop':        offsetY = -(1 - easeOut(inProg)) * 120; alpha = easeOut(inProg * 2); break;
      default:            alpha = easeOut(inProg);
    }
  }
  if (isOut && outProg > 0) {
    switch (beat.outAnim) {
      case 'fade':      alpha *= 1 - easeIn(outProg); break;
      case 'pop':       scaleX *= 1 + 0.15 * outProg; scaleY = scaleX; alpha *= 1 - easeIn(outProg); break;
      case 'snap-up':   offsetY -= outProg * 60; alpha *= 1 - easeIn(outProg); break;
      case 'snap-down': offsetY += outProg * 60; alpha *= 1 - easeIn(outProg); break;
      default:          alpha *= 1 - easeIn(outProg);
    }
  }
  const idleT = t - beat.start - inDur;
  let idleScale = 1;
  if (!isIn && !isOut && beat.idle) {
    if (beat.idle === 'bob')     offsetY += Math.sin(idleT * 1.8) * 5;
    if (beat.idle === 'breathe') idleScale = 1 + Math.sin(idleT * 1.2) * 0.012;
    if (beat.idle === 'pulse')   idleScale = 1 + Math.sin(idleT * 2.4) * 0.02;
  }
  return { alpha: Math.max(0, Math.min(1, alpha)), scaleX: scaleX * idleScale, scaleY: scaleY * idleScale, offsetX, offsetY };
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath(); ctx.moveTo(x+r,y); ctx.lineTo(x+w-r,y); ctx.quadraticCurveTo(x+w,y,x+w,y+r);
  ctx.lineTo(x+w,y+h-r); ctx.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
  ctx.lineTo(x+r,y+h); ctx.quadraticCurveTo(x,y+h,x,y+h-r); ctx.lineTo(x,y+r);
  ctx.quadraticCurveTo(x,y,x+r,y); ctx.closePath();
}
function drawDropShadow(ctx, fn) {
  [{blur:24,oY:12,a:0.12},{blur:12,oY:6,a:0.18},{blur:6,oY:3,a:0.22}].forEach(({blur,oY,a}) => {
    ctx.save(); ctx.shadowColor=`rgba(0,0,0,${a})`; ctx.shadowBlur=blur; ctx.shadowOffsetX=0; ctx.shadowOffsetY=oY; fn(ctx); ctx.restore();
  });
}
function gradientAngle(t) { return (t*15)%360; }
function strokeLiquidOutline(ctx, cx, cy, pw, ph, r, palette, t) {
  const N=120, WAVE_AMP=10, WAVE_FREQ=4, EXPAND=6;
  const x=cx-pw/2, y=cy-ph/2, totalPerim=2*(pw+ph), points=[];
  for (let i=0;i<N;i++) {
    const u=i/N, d=u*totalPerim; let px,py,nx,ny;
    if(d<pw){px=x+d;py=y;nx=0;ny=-1;}
    else if(d<pw+ph){px=x+pw;py=y+(d-pw);nx=1;ny=0;}
    else if(d<2*pw+ph){px=x+pw-(d-pw-ph);py=y+ph;nx=0;ny=1;}
    else{px=x;py=y+ph-(d-2*pw-ph);nx=-1;ny=0;}
    const phase=u*Math.PI*2*WAVE_FREQ+t*2, amp=WAVE_AMP*((Math.sin(phase)+1)/2);
    points.push({x:px+nx*(EXPAND+amp),y:py+ny*(EXPAND+amp)});
  }
  const grad=ctx.createLinearGradient(cx-pw/2,cy-ph/2,cx+pw/2,cy+ph/2);
  palette.forEach((c,i)=>grad.addColorStop(i/(palette.length-1),c));
  ctx.save(); ctx.beginPath(); ctx.moveTo(points[0].x,points[0].y);
  points.slice(1).forEach(p=>ctx.lineTo(p.x,p.y));
  ctx.closePath(); ctx.strokeStyle=grad; ctx.lineWidth=3; ctx.globalAlpha*=0.7; ctx.stroke(); ctx.restore();
}
function fillPillBody(ctx, cx, cy, pw, ph, r, palette, t) {
  const angle=(gradientAngle(t)*Math.PI)/180, hd=Math.sqrt(pw*pw+ph*ph)/2;
  const grad=ctx.createLinearGradient(cx+Math.cos(angle)*hd,cy+Math.sin(angle)*hd,cx-Math.cos(angle)*hd,cy-Math.sin(angle)*hd);
  grad.addColorStop(0,palette[0]);grad.addColorStop(0.33,palette[1]);grad.addColorStop(0.66,palette[2]);grad.addColorStop(1,palette[3]);
  ctx.save(); ctx.beginPath(); roundRect(ctx,cx-pw/2,cy-ph/2,pw,ph,r); ctx.fillStyle=grad; ctx.fill(); ctx.restore();
}
function drawPill(ctx, beat, t, state) {
  const {cx,cy}=resolveBeatPosition(beat), p=beat.props||{};
  const text=p.text||'', fontSize=p.fontSize||56;
  const palette=p.palette||['#1E3A5F','#2563EB','#3B82F6','#93C5FD','#DBEAFE','#EFF6FF'];
  const fill=p.fill||palette[1], textColor=p.textColor||'#FFFFFF';
  ctx.font=`800 ${fontSize}px ${SAFE_FONT}`;
  const textW=ctx.measureText(text).width, pw=textW+fontSize*1.6, ph=fontSize*1.8, r=ph/2;
  ctx.save(); ctx.globalAlpha=state.alpha; ctx.translate(cx+state.offsetX,cy+state.offsetY); ctx.scale(state.scaleX,state.scaleY);
  drawDropShadow(ctx,s=>{s.beginPath();roundRect(s,-pw/2,-ph/2,pw,ph,r);s.fillStyle=fill;s.fill();});
  fillPillBody(ctx,0,0,pw,ph,r,palette,t);
  strokeLiquidOutline(ctx,0,0,pw,ph,r,palette,t);
  ctx.font=`800 ${fontSize}px ${SAFE_FONT}`; ctx.fillStyle=textColor; ctx.textAlign='center'; ctx.textBaseline='middle'; ctx.fillText(text,0,0);
  ctx.restore();
}
function drawEmoji(ctx, beat, t, state) {
  const {cx,cy}=resolveBeatPosition(beat), p=beat.props||{};
  ctx.save(); ctx.globalAlpha=state.alpha; ctx.font=`${p.size||200}px ${SAFE_FONT}`;
  ctx.textAlign='center'; ctx.textBaseline='middle';
  ctx.translate(cx+state.offsetX,cy+state.offsetY); ctx.scale(state.scaleX,state.scaleY);
  ctx.fillStyle='black'; ctx.fillText(p.text||'✨',0,0); ctx.restore();
}
function drawPrimitive(ctx, beat, t, state) {
  const {cx,cy}=resolveBeatPosition(beat), p=beat.props||{};
  const drawFn=p.draw && illustrations[p.draw];
  if (!drawFn) return;
  ctx.save(); ctx.globalAlpha=state.alpha; ctx.translate(cx+state.offsetX,cy+state.offsetY); ctx.scale(state.scaleX,state.scaleY);
  drawFn(ctx, t-beat.start, p); ctx.restore();
}
function drawBackground(ctx, t) {
  const h1=(220+Math.sin(t*0.08)*15)|0, h2=(260+Math.sin(t*0.05)*20)|0;
  const g=ctx.createLinearGradient(0,0,W,H);
  g.addColorStop(0,`hsl(${h1},30%,8%)`); g.addColorStop(1,`hsl(${h2},25%,6%)`);
  ctx.fillStyle=g; ctx.fillRect(0,0,W,H);
}
function renderFrame(ctx, t) {
  ctx.clearRect(0,0,W,H); 
  for (const beat of beats) {
    if (beat.kind==='broll') continue;
    const state=beatState(beat,t);
    if (!state) continue;
    switch(beat.type) {
      case 'hook': case 'keyword': case 'cta': drawPill(ctx,beat,t,state); break;
      case 'emoji': drawEmoji(ctx,beat,t,state); break;
      case 'primitive': drawPrimitive(ctx,beat,t,state); break;
    }
  }
}

// Create temp PNG dir
const pngDir = `/tmp/split2d-cjs-${startT}-${endT}`;
fs.mkdirSync(pngDir, { recursive: true });

const canvas = createCanvas(W, H);
const ctx = canvas.getContext('2d');

process.stderr.write(`[render-cjs] Starting frame loop...\n`);
const t0 = Date.now();
for (let frame = 0; frame < TOTAL_FRAMES; frame++) {
  const t = frame / FPS;
  renderFrame(ctx, t);
  const buf = canvas.toBuffer('image/png');
  fs.writeFileSync(path.join(pngDir, `frame-${String(frame).padStart(6,'0')}.png`), buf);
  if (frame % 60 === 0) {
    const elapsed = ((Date.now()-t0)/1000).toFixed(1);
    process.stderr.write(`  frame ${frame}/${TOTAL_FRAMES} (${elapsed}s)\n`);
  }
}
process.stderr.write(`[render-cjs] Frames done. Encoding...\n`);

// Encode
fs.mkdirSync(path.dirname(path.resolve(outMp4)), { recursive: true });
const ff = spawnSync('ffmpeg', [
  '-y', '-framerate', String(FPS), '-i', path.join(pngDir, 'frame-%06d.png'),
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'medium', '-crf', '20', '-movflags', '+faststart',
  outMp4
], { stdio: 'inherit' });

if (ff.status !== 0) { process.stderr.write(`[render-cjs] ffmpeg failed\n`); process.exit(1); }

// Cleanup
fs.readdirSync(pngDir).forEach(f => fs.unlinkSync(path.join(pngDir, f)));
fs.rmdirSync(pngDir);
process.stderr.write(`[render-cjs] Done → ${outMp4}\n`);
