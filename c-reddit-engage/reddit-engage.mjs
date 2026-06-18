#!/usr/bin/env node
/*
 * c-reddit-engage — durable Reddit engagement via a persistent (logged-in) Chromium profile.
 *
 * This script does BROWSER MECHANICS ONLY. The *reasoning* — which posts are worth
 * engaging, and what a genuine comment should say — is the caller's job (a human or an
 * agent). This deliberately mirrors the verified MCP sequence in SKILL.md, so the
 * selectors are the same ones confirmed working on new Reddit (shreddit-* web components).
 *
 * ── One-time setup ───────────────────────────────────────────────────────────
 *   npm i -g playwright && npx playwright install chromium      # if not already present
 *   HEADFUL=1 node reddit-engage.mjs login    # opens a window; log into Reddit by hand; session persists
 *
 * ── Usage ────────────────────────────────────────────────────────────────────
 *   node reddit-engage.mjs whoami                          -> username, or NOT_LOGGED_IN (exit 3)
 *   node reddit-engage.mjs fetch <subreddit> [limit]       -> JSON [{title,permalink,comments,type}]
 *   node reddit-engage.mjs read  <permalink>               -> JSON {title,body,topComments[]}
 *   node reddit-engage.mjs post  <permalink> <file|->      -> posts comment (text from file or stdin),
 *                                                             verifies it landed, prints {ok,author,permalink}
 *
 * ── Where the session lives ──────────────────────────────────────────────────
 *   ~/.gsai/secrets/reddit-profile   (override with REDDIT_PROFILE)
 *   This dir holds Reddit auth cookies. NEVER commit it. NEVER copy it into the skill repo.
 *
 * ── Safety rails baked in ────────────────────────────────────────────────────
 *   - `post` refuses to double-comment: if a comment by the logged-in user already exists
 *     on the thread, it aborts (exit 4) unless ALLOW_REPEAT=1.
 *   - `post` enforces a minimum gap between posts via a local stamp file
 *     (~/.gsai/secrets/reddit-profile/.last-post); default 1800s, override MIN_GAP_SECONDS.
 */

import { chromium } from 'playwright';
import os from 'os';
import path from 'path';
import fs from 'fs';

const PROFILE = process.env.REDDIT_PROFILE || path.join(os.homedir(), '.gsai/secrets/reddit-profile');
fs.mkdirSync(PROFILE, { recursive: true });
try { fs.chmodSync(PROFILE, 0o700); } catch {}

const STAMP = path.join(PROFILE, '.last-post');
const MIN_GAP_SECONDS = parseInt(process.env.MIN_GAP_SECONDS || '1800', 10);
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

function die(msg, code = 1) { console.error(msg); process.exit(code); }

async function launch(headless) {
  return chromium.launchPersistentContext(PROFILE, {
    headless,
    viewport: { width: 1280, height: 900 },
    userAgent: UA,
    args: ['--disable-blink-features=AutomationControlled'],
  });
}

async function withPage(headless, fn) {
  const ctx = await launch(headless);
  const page = ctx.pages()[0] || await ctx.newPage();
  try { return await fn(page, ctx); }
  finally { await ctx.close(); }
}

async function whoami(page) {
  // Reddit client-side-navigates on load, which can destroy the evaluate context.
  // Settle, then retry the cookie-auth probe a couple times.
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      await page.goto('https://www.reddit.com/', { waitUntil: 'domcontentloaded' });
      await page.waitForTimeout(1500);
      const name = await page.evaluate(async () => {
        try {
          const r = await fetch('/api/me.json', { credentials: 'include' });
          const j = await r.json();
          return j?.data?.name || null;
        } catch { return null; }
      });
      return name;
    } catch {
      if (attempt === 2) return null;
      await page.waitForTimeout(1200);
    }
  }
  return null;
}

// ── commands ────────────────────────────────────────────────────────────────

async function cmdLogin() {
  const ctx = await launch(false);
  const page = ctx.pages()[0] || await ctx.newPage();
  await page.goto('https://www.reddit.com/login/', { waitUntil: 'domcontentloaded' });
  console.error('A Reddit login window is open. Log in by hand (solve any captcha).');
  console.error('Waiting up to 5 min for you to finish — auto-saves the moment you are logged in…');
  // Poll the same-origin auth probe WITHOUT navigating away from the login page.
  const deadline = Date.now() + 5 * 60 * 1000;
  let name = null;
  while (Date.now() < deadline) {
    await page.waitForTimeout(3000);
    try {
      name = await page.evaluate(async () => {
        try { const r = await fetch('/api/me.json', { credentials: 'include' }); const j = await r.json(); return j?.data?.name || null; }
        catch { return null; }
      });
    } catch { /* mid-navigation; retry */ }
    if (name) break;
  }
  await ctx.close();
  if (!name) die('No login detected within 5 min — session not saved. Re-run to retry.', 3);
  console.log(JSON.stringify({ ok: true, loggedInAs: name, profile: PROFILE }));
}

async function cmdWhoami() {
  const name = await withPage(true, (p) => whoami(p));
  if (!name) die('NOT_LOGGED_IN', 3);
  console.log(name);
}

async function cmdFetch(sub, limit) {
  if (!sub) die('usage: fetch <subreddit> [limit]');
  sub = sub.replace(/^r\//, '');
  const out = await withPage(true, async (page) => {
    await page.goto(`https://www.reddit.com/r/${sub}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('shreddit-post', { timeout: 20000 });
    return page.evaluate(async () => {
      for (let i = 0; i < 4; i++) { window.scrollBy(0, 1600); await new Promise(r => setTimeout(r, 600)); }
      return [...document.querySelectorAll('shreddit-post')].map(p => ({
        title: p.getAttribute('post-title'),
        permalink: p.getAttribute('permalink'),
        comments: +p.getAttribute('comment-count'),
        score: +p.getAttribute('score'),
        type: p.getAttribute('post-type'),
        author: p.getAttribute('author'),
      }));
    });
  });
  console.log(JSON.stringify(out.slice(0, limit ? +limit : 25), null, 2));
}

async function cmdRead(permalink) {
  if (!permalink) die('usage: read <permalink>');
  const url = permalink.startsWith('http') ? permalink : `https://www.reddit.com${permalink}`;
  const out = await withPage(true, async (page) => {
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('shreddit-post', { timeout: 20000 });
    return page.evaluate(() => {
      const p = document.querySelector('shreddit-post');
      const body = document.querySelector('[slot="text-body"]')?.innerText
        || document.querySelector('div.md')?.innerText || '[image/link post — no body text]';
      const comments = [];
      document.querySelectorAll('shreddit-comment').forEach(c => {
        const t = c.querySelector('[id$="-comment-rtjson-content"]')?.innerText
          || c.querySelector('.md')?.innerText;
        if (t) comments.push({ author: c.getAttribute('author'), text: t.slice(0, 280).replace(/\s+/g, ' ') });
      });
      return { title: p?.getAttribute('post-title'), flair: p?.getAttribute('flair-text') || null,
               body: body.slice(0, 2500), topComments: comments.slice(0, 8) };
    });
  });
  console.log(JSON.stringify(out, null, 2));
}

async function cmdPost(permalink, src) {
  if (!permalink || !src) die('usage: post <permalink> <file|->');
  const text = (src === '-' ? fs.readFileSync(0, 'utf8') : fs.readFileSync(src, 'utf8')).trim();
  if (!text) die('empty comment text', 1);

  // rate-limit guard
  if (fs.existsSync(STAMP)) {
    const elapsed = (Date.now() - fs.statSync(STAMP).mtimeMs) / 1000;
    if (elapsed < MIN_GAP_SECONDS && !process.env.ALLOW_REPEAT) {
      die(`rate-limit: last post ${Math.round(elapsed)}s ago, min gap ${MIN_GAP_SECONDS}s. Set MIN_GAP_SECONDS or ALLOW_REPEAT=1 to override.`, 5);
    }
  }

  const url = permalink.startsWith('http') ? permalink : `https://www.reddit.com${permalink}`;
  const result = await withPage(true, async (page) => {
    const me = await whoami(page);
    if (!me) return { ok: false, error: 'NOT_LOGGED_IN' };
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('shreddit-post', { timeout: 20000 });

    // don't double-comment
    const already = await page.evaluate((meName) => {
      return [...document.querySelectorAll('shreddit-comment')].some(c => c.getAttribute('author') === meName);
    }, me);
    if (already && !process.env.ALLOW_REPEAT) return { ok: false, error: 'ALREADY_COMMENTED', author: me };

    await page.locator('comment-composer-host').click();
    await page.locator('[contenteditable="true"]').fill(text);
    await page.waitForTimeout(400);
    await page.locator('#comment-composer-submit-button').click();
    await page.waitForTimeout(2500);

    // verify it landed
    const probe = text.slice(0, 40);
    const found = await page.evaluate((needle) => {
      for (const c of document.querySelectorAll('shreddit-comment')) {
        const t = c.querySelector('[id$="-comment-rtjson-content"]')?.innerText || '';
        if (t.includes(needle)) return { author: c.getAttribute('author'), permalink: c.getAttribute('permalink') };
      }
      return null;
    }, probe);
    return found ? { ok: true, author: found.author, permalink: found.permalink } : { ok: false, error: 'NOT_FOUND_AFTER_SUBMIT' };
  });

  if (result.ok) fs.writeFileSync(STAMP, new Date().toISOString());
  console.log(JSON.stringify(result, null, 2));
  if (!result.ok) process.exit(4);
}

// ── dispatch ──────────────────────────────────────────────────────────────────
const [cmd, a, b] = process.argv.slice(2);
const run = {
  login: () => cmdLogin(),
  whoami: () => cmdWhoami(),
  fetch: () => cmdFetch(a, b),
  read: () => cmdRead(a),
  post: () => cmdPost(a, b),
}[cmd];

if (!run) die('commands: login | whoami | fetch <sub> [n] | read <permalink> | post <permalink> <file|->', 2);
run().catch(e => die(String(e?.stack || e), 1));
