#!/usr/bin/env node
/**
 * render-carousel — deterministic N-slide HTML→PNG carousel renderer.
 *
 * The whole point of this script: a carousel must render ALL its slides in ONE
 * pass. The old freelance path (LLM writing + screenshotting one slide at a
 * time) burned the agent's step budget after the cover and shipped a 1-of-N
 * "carousel" — the production worker then looped forever re-asking for "the
 * rest" (MGG 7-slide carousel, 2026-06-04). This script collapses the entire
 * render to a single Bash invocation: build HTML per slide from a shared
 * template, screenshot each with headless chromium at exact slide size, upload
 * each to R2, and print every public URL. No interactive gates, no per-slide
 * agent turns, immune to the agent step cap.
 *
 * Usage:
 *   render-carousel <brandId> <taskId> <slides.json>
 *
 * slides.json shape (see SKILL.md for the authoring contract):
 *   {
 *     "size":  { "w": 1080, "h": 1350 },          // optional, defaults 1080x1350
 *     "theme": { "bg","accent","text","muted",     // optional, sensible defaults
 *                "titleFont","labelFont","fontHref" },
 *     "slides": [ { kind, eyebrow, headline, accentWords[], body, stat,
 *                   ghost, glow, nodes[], footer }, ... ]
 *   }
 *
 * Required env (consumed by the r2-upload helper it shells out to):
 *   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_URL
 *
 * Exit codes:
 *   0  every slide rendered + uploaded; URLs printed (one per line) after the
 *      `CAROUSEL_SLIDES_BEGIN` marker
 *   1  bad args / malformed spec / missing chromium or r2-upload
 *   2  a slide failed to render or upload (fail-fast — never ship a partial carousel)
 */

import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

// ── arg + spec parsing ───────────────────────────────────────────────────────
const [, , brandId, taskId, specPath] = process.argv;
if (!brandId || !taskId || !specPath) {
  console.error("usage: render-carousel <brandId> <taskId> <slides.json>");
  process.exit(1);
}

let spec;
try {
  spec = JSON.parse(execFileSync("cat", [resolve(specPath)], { encoding: "utf8" }));
} catch (err) {
  console.error(`ERROR: cannot read/parse spec ${specPath}: ${err?.message ?? err}`);
  process.exit(1);
}

const slides = Array.isArray(spec.slides) ? spec.slides : [];
if (slides.length === 0) {
  console.error("ERROR: spec.slides is empty — nothing to render");
  process.exit(1);
}
if (slides.length > 10) {
  // The composition layer (propose_composition.mediaUrls) caps at 10. Refuse
  // loudly rather than render slides that can never be delivered.
  console.error(`ERROR: ${slides.length} slides requested but the carousel limit is 10`);
  process.exit(1);
}

const W = Number(spec?.size?.w) || 1080;
const H = Number(spec?.size?.h) || 1350;

const theme = {
  bg: "#0F172A",
  accent: "#F97316",
  text: "#FFFFFF",
  muted: "rgba(255,255,255,0.70)",
  titleFont: "'Barlow Condensed', 'Arial Narrow', sans-serif",
  labelFont: "'JetBrains Mono', 'Courier New', monospace",
  fontHref:
    "https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600;800;900&family=JetBrains+Mono:wght@500;700&display=swap",
  ...(spec.theme && typeof spec.theme === "object" ? spec.theme : {}),
};

// ── tool resolution ──────────────────────────────────────────────────────────
function resolveBin(envVar, candidates, name) {
  if (process.env[envVar] && existsSync(process.env[envVar])) return process.env[envVar];
  for (const c of candidates) {
    if (existsSync(c)) return c;
  }
  try {
    return execFileSync("sh", ["-c", `command -v ${name}`], { encoding: "utf8" }).trim();
  } catch {
    return "";
  }
}
const CHROMIUM = resolveBin(
  "CHROMIUM_PATH",
  ["/usr/bin/chromium", "/usr/bin/chromium-browser", "/usr/bin/google-chrome"],
  "chromium",
);
const R2_UPLOAD = resolveBin("R2_UPLOAD_BIN", ["/usr/local/bin/r2-upload", "/app/scripts/container/r2-upload"], "r2-upload");
if (!CHROMIUM) {
  console.error("ERROR: chromium not found (set CHROMIUM_PATH)");
  process.exit(1);
}
if (!R2_UPLOAD) {
  console.error("ERROR: r2-upload helper not found (set R2_UPLOAD_BIN)");
  process.exit(1);
}

// ── HTML template ────────────────────────────────────────────────────────────
const esc = (s) =>
  String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

// Wrap accent words in the headline with an accent span. Case-insensitive,
// whole-word; everything else is escaped first so author text can't inject HTML.
function renderHeadline(headline, accentWords) {
  let html = esc(headline);
  for (const w of Array.isArray(accentWords) ? accentWords : []) {
    if (!w) continue;
    const safe = esc(w).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    html = html.replace(new RegExp(`\\b${safe}\\b`, "gi"), (m) => `<span class="accent">${m}</span>`);
  }
  return html;
}

function glowCss(pos) {
  const map = {
    "top-left": "circle at 18% 20%",
    "top-right": "circle at 82% 20%",
    "center": "circle at 50% 50%",
    "center-right": "circle at 82% 50%",
    "bottom-left": "circle at 18% 82%",
    "bottom-center": "circle at 50% 82%",
    "bottom-right": "circle at 82% 82%",
  };
  return map[pos] || map["center"];
}

function nodesHtml(nodes) {
  if (!Array.isArray(nodes) || nodes.length === 0) return "";
  const items = nodes
    .map(
      (n, i) =>
        `<div class="node">${esc(n)}</div>${i < nodes.length - 1 ? '<div class="arrow">&rarr;</div>' : ""}`,
    )
    .join("");
  return `<div class="nodes">${items}</div>`;
}

function slideHtml(slide, idx, total) {
  const kind = slide.kind || (idx === 0 ? "cover" : idx === total - 1 ? "cta" : "content");
  const ghost = slide.ghost && kind !== "cta" ? `<div class="ghost">${esc(slide.ghost)}</div>` : "";
  const eyebrow = slide.eyebrow ? `<div class="eyebrow">${esc(slide.eyebrow)}</div>` : "";
  const headline = slide.headline
    ? `<h1 class="headline ${kind === "cover" ? "headline-xl" : ""}">${renderHeadline(slide.headline, slide.accentWords)}</h1>`
    : "";
  const body = slide.body ? `<p class="body">${esc(slide.body)}</p>` : "";
  const stat = slide.stat ? `<div class="stat">${esc(slide.stat)}</div>` : "";
  const nodes = nodesHtml(slide.nodes);
  const footer = slide.footer ? `<div class="footer">${esc(slide.footer)}</div>` : "";
  const counter =
    total > 1 && kind !== "cta" ? `<div class="counter">${idx + 1} / ${total}</div>` : "";

  return `<!doctype html>
<html><head><meta charset="UTF-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="${theme.fontHref}">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden;
    background: ${theme.bg}; color: ${theme.text};
    font-family: ${theme.titleFont}; -webkit-font-smoothing: antialiased; }
  .slide { position: relative; width: ${W}px; height: ${H}px; padding: 72px;
    display: flex; flex-direction: column; justify-content: center; gap: 28px; overflow: hidden; }
  .glow { position: absolute; inset: 0; pointer-events: none;
    background: radial-gradient(${glowCss(slide.glow)}, ${theme.accent}33 0%, transparent 46%); }
  .ghost { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
    font-weight: 900; font-size: 360px; line-height: 1; letter-spacing: -0.04em; text-transform: uppercase;
    color: ${theme.text}; opacity: 0.06; white-space: nowrap; pointer-events: none; z-index: 0; }
  .counter { position: absolute; top: 72px; right: 72px; font-family: ${theme.labelFont};
    font-size: 24px; font-weight: 500; color: ${theme.muted}; letter-spacing: 0.05em; z-index: 2; }
  .slide > *:not(.glow):not(.ghost):not(.counter) { position: relative; z-index: 1; }
  .eyebrow { font-family: ${theme.labelFont}; font-weight: 700; font-size: 28px;
    letter-spacing: 0.08em; text-transform: uppercase; color: ${theme.accent}; }
  .headline { font-weight: 900; font-size: 76px; line-height: 1.02; letter-spacing: -0.015em;
    text-transform: uppercase; }
  .headline-xl { font-size: 104px; }
  .headline .accent { color: ${theme.accent}; }
  .body { font-family: 'Inter', system-ui, sans-serif; font-weight: 400; font-size: 34px;
    line-height: 1.42; color: ${theme.muted}; max-width: 86%; }
  .stat { font-family: ${theme.labelFont}; font-weight: 700; font-size: 30px; line-height: 1.3;
    color: ${theme.accent}; border-left: 6px solid ${theme.accent}; padding-left: 24px; }
  .nodes { display: flex; align-items: center; gap: 20px; flex-wrap: wrap; margin-top: 12px; }
  .node { font-family: ${theme.labelFont}; font-weight: 700; font-size: 30px; color: ${theme.text};
    border: 2px solid ${theme.accent}; border-radius: 14px; padding: 18px 26px;
    box-shadow: 0 0 32px ${theme.accent}55; }
  .arrow { color: ${theme.accent}; font-size: 40px; font-weight: 900; }
  .footer { font-family: ${theme.labelFont}; font-weight: 700; font-size: 30px; color: ${theme.accent};
    letter-spacing: 0.04em; margin-top: 20px; }
</style></head>
<body><div class="slide">
  <div class="glow"></div>
  ${ghost}
  ${counter}
  ${eyebrow}
  ${headline}
  ${body}
  ${stat}
  ${nodes}
  ${footer}
</div></body></html>`;
}

// ── render loop ──────────────────────────────────────────────────────────────
const workDir = `/tmp/carousel-${taskId}`;
mkdirSync(workDir, { recursive: true });
const total = slides.length;
const urls = [];

for (let i = 0; i < total; i++) {
  const n = String(i + 1).padStart(2, "0");
  const htmlPath = `${workDir}/slide-${n}.html`;
  const pngPath = `${workDir}/slide-${n}.png`;
  const key = `${brandId}/carousels/${taskId}/slide-${n}.png`;

  try {
    writeFileSync(htmlPath, slideHtml(slides[i], i, total), "utf8");
  } catch (err) {
    console.error(`ERROR: write HTML for slide ${i + 1} failed: ${err?.message ?? err}`);
    process.exit(2);
  }

  // Headless screenshot at EXACT slide size. --virtual-time-budget lets web
  // fonts + CSS settle before capture so titles aren't snapped in the fallback
  // font. --force-device-scale-factor=1 keeps output exactly WxH.
  try {
    execFileSync(
      CHROMIUM,
      [
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--hide-scrollbars",
        "--force-device-scale-factor=1",
        "--virtual-time-budget=2500",
        `--window-size=${W},${H}`,
        `--screenshot=${pngPath}`,
        `file://${htmlPath}`,
      ],
      { stdio: ["ignore", "ignore", "pipe"], timeout: 60_000 },
    );
  } catch (err) {
    console.error(`ERROR: chromium render slide ${i + 1} failed: ${err?.message ?? err}`);
    process.exit(2);
  }
  if (!existsSync(pngPath)) {
    console.error(`ERROR: slide ${i + 1} PNG was not produced at ${pngPath}`);
    process.exit(2);
  }

  // Upload + capture the public URL (r2-upload prints "$R2_PUBLIC_URL/$key").
  let url;
  try {
    url = execFileSync(R2_UPLOAD, [pngPath, key, "image/png"], {
      encoding: "utf8",
      timeout: 60_000,
      env: { ...process.env, NODE_PATH: process.env.NODE_PATH || "/app/node_modules" },
    }).trim();
  } catch (err) {
    const stderr = err?.stderr ? String(err.stderr) : "";
    console.error(`ERROR: r2 upload slide ${i + 1} failed: ${err?.message ?? err} ${stderr}`);
    process.exit(2);
  }
  if (!/^https?:\/\//.test(url)) {
    console.error(`ERROR: r2-upload returned a non-URL for slide ${i + 1}: ${url}`);
    process.exit(2);
  }
  urls.push(url);
  console.error(`[render-carousel] slide ${i + 1}/${total} ✓ ${url}`);
}

// ── output contract ──────────────────────────────────────────────────────────
// Print all URLs on stdout, one per line, fenced by a marker the skill echoes
// back verbatim. The production worker scrapes every R2 URL from the reply, so
// printing them plainly (no surrounding prose) is what makes all N slides flow
// through to the carousel composition.
console.log("CAROUSEL_SLIDES_BEGIN");
for (const u of urls) console.log(u);
console.log("CAROUSEL_SLIDES_END");
console.log(`Rendered ${urls.length} carousel slides for task ${taskId}.`);
