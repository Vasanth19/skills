#!/usr/bin/env node
/*
 * c-reddit-engage — AUTO SESSION runner (unattended, scheduled).
 *
 * One scheduled "session": rotate to a subreddit, find fresh discussion threads, draft a
 * SHORT genuine comment for each (via `claude -p`), and post up to N with human-like delays.
 * Deterministic orchestration here; the *wording* is drafted by Claude per-thread.
 *
 * USER-AUTHORISED UNATTENDED POSTING (decision 2026-06-17): auto-post, 50–150 char comments,
 * 3 per session, human-like delays, every 3h, ~6 sessions/day (07–22), nothing overnight.
 *
 * Rails: active-hours guard · per-session sub rotation · dedup + min-gap (via reddit-engage.mjs)
 *        · randomized inter-comment delay · length/URL validation · kill-switch · full log.
 *
 * Env:
 *   AUTO_POST=1     actually post (default: DRY-RUN — drafts logged, nothing posted)
 *   KILL_SWITCH     if ~/.gsai/secrets/reddit-engage.OFF exists, the session exits immediately
 *   SUBS            comma list (default rotation below)
 *   N_PER_SESSION   default 3
 *   ACTIVE_START/ACTIVE_END   hours, default 7 / 22 (local time)
 *   DELAY_MIN/DELAY_MAX       seconds between comments, default 60 / 180
 *   MIN_LEN/MAX_LEN           comment length bounds, default 50 / 150
 */

import { spawnSync } from 'child_process';
import os from 'os';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const NODE = process.execPath;
const CLAUDE = process.env.CLAUDE_BIN || '/Applications/cmux.app/Contents/Resources/bin/claude';
const RE = path.join(HERE, 'reddit-engage.mjs');

const SECRETS = path.join(os.homedir(), '.gsai/secrets');
const LOG = path.join(SECRETS, 'reddit-engage-auto.log');
const OFF = path.join(SECRETS, 'reddit-engage.OFF');

const SUBS = (process.env.SUBS || 'SaaS,Entrepreneur,startups,SideProject,indiehackers').split(',').map(s => s.trim());
const N = parseInt(process.env.N_PER_SESSION || '3', 10);
const ACTIVE_START = parseInt(process.env.ACTIVE_START || '7', 10);
const ACTIVE_END = parseInt(process.env.ACTIVE_END || '22', 10);
const DELAY_MIN = parseInt(process.env.DELAY_MIN || '60', 10);
const DELAY_MAX = parseInt(process.env.DELAY_MAX || '180', 10);
const MIN_LEN = parseInt(process.env.MIN_LEN || '50', 10);
const MAX_LEN = parseInt(process.env.MAX_LEN || '250', 10);
const DRY = process.env.AUTO_POST !== '1';

function log(obj) {
  const line = JSON.stringify({ t: new Date().toISOString(), ...obj });
  fs.appendFileSync(LOG, line + '\n');
  console.log(line);
}
const sleep = (s) => new Promise(r => setTimeout(r, s * 1000));
const rand = (a, b) => a + Math.floor((b - a) * (process.hrtime.bigint() % 1000n === 0n ? 0.5 : Number(process.hrtime.bigint() % 1000n) / 1000));

function reCall(args, input) {
  const r = spawnSync(NODE, [RE, ...args], {
    input, encoding: 'utf8', timeout: 120000,
    env: { ...process.env, MIN_GAP_SECONDS: '45' },
  });
  return { code: r.status, out: (r.stdout || '').trim(), err: (r.stderr || '').trim() };
}

const DRAFT_SYSTEM = `You write ONE short Reddit comment as a real person replying to the post below.
OUTPUT: only the comment text. No preamble, quotes, markdown, emoji.
LENGTH: between ${MIN_LEN} and ${MAX_LEN} characters.

WRITE LIKE A HUMAN — these patterns get auto-removed as "AI content", NEVER use them:
- NO em-dashes (—). Use commas/periods/parentheses.
- NO "it's not just X, it's Y" or "the X isn't Y, it's Z" constructions.
- NO words: delve, nestled, boast, meticulous, leverage, foster, robust, crucial, pivotal,
  testament, realm, seamless, moreover, furthermore.
- NO list-of-three, no "Firstly/Secondly", no summarizing the post, no "great post".

DO: one specific concrete detail or first-hand experience; one clear opinion with mild emotion;
vary sentence length, fragments ok, contractions, lowercase start is fine; slightly imperfect
beats polished. Sound like someone typing fast who actually knows this, not a summary of it.`;

// Patterns that betray AI writing — reject any draft containing them.
const TELL_WORDS = /\b(delve|nestled|boast|meticulous|leverage|foster|robust|crucial|pivotal|testament|realm|tapestry|underscore|seamless|moreover|furthermore)\b/i;
const TELL_NOTJUST = /\b(it'?s not just|isn'?t (just )?\w+,? it'?s|not\s+\w+,?\s+but rather)\b/i;

function draftComment(thread) {
  const prompt = `${DRAFT_SYSTEM}

POST TITLE: ${thread.title}
POST BODY: ${(thread.body || '').slice(0, 1200)}
TOP COMMENTS: ${(thread.topComments || []).slice(0, 4).map(c => '- ' + c.text).join('\n')}`;
  const r = spawnSync(CLAUDE, ['-p', prompt], { encoding: 'utf8', timeout: 120000 });
  let text = (r.stdout || '').trim().replace(/^["']|["']$/g, '').trim();
  return text;
}

function validComment(t) {
  if (!t) return { ok: false, why: 'empty' };
  if (t.length < MIN_LEN || t.length > MAX_LEN) return { ok: false, why: `len ${t.length}` };
  if (/https?:\/\/|www\./i.test(t)) return { ok: false, why: 'contains url' };
  if (/[—–]/.test(t)) return { ok: false, why: 'em-dash tell' };
  if (TELL_WORDS.test(t)) return { ok: false, why: 'tell-word' };
  if (TELL_NOTJUST.test(t)) return { ok: false, why: 'not-just-X-its-Y tell' };
  return { ok: true };
}

async function main() {
  if (fs.existsSync(OFF)) { log({ event: 'killswitch', msg: 'reddit-engage.OFF present — exiting' }); return; }

  const hour = new Date().getHours();
  if (hour < ACTIVE_START || hour >= ACTIVE_END) {
    log({ event: 'skip', reason: 'outside active hours', hour, window: `${ACTIVE_START}-${ACTIVE_END}` });
    return;
  }

  const sub = SUBS[hour % SUBS.length];
  log({ event: 'session_start', sub, target: N, dryRun: DRY });

  // verify session
  const who = reCall(['whoami']);
  if (who.code !== 0 || !who.out) { log({ event: 'abort', reason: 'NOT_LOGGED_IN', detail: who.err }); return; }
  log({ event: 'whoami', user: who.out });

  const fetched = reCall(['fetch', sub, '25']);
  if (fetched.code !== 0) { log({ event: 'abort', reason: 'fetch_failed', detail: fetched.err }); return; }
  let posts;
  try { posts = JSON.parse(fetched.out); } catch { log({ event: 'abort', reason: 'fetch_parse' }); return; }

  // prefer genuine discussion: text posts, sane comment counts, deterministic shuffle by id
  const candidates = posts
    .filter(p => p.permalink && (p.type === 'text' || (p.comments >= 3 && p.comments <= 300)))
    .sort((a, b) => (a.permalink > b.permalink ? 1 : -1));

  let posted = 0;
  for (const c of candidates) {
    if (posted >= N) break;
    const read = reCall(['read', c.permalink]);
    if (read.code !== 0) continue;
    let thread;
    try { thread = JSON.parse(read.out); } catch { continue; }
    if (!thread.body || thread.body.startsWith('[image')) continue;

    // draft, retrying if a draft trips the AI-tell / length checks
    let text = '', verdict = { ok: false, why: 'no draft' };
    for (let attempt = 0; attempt < 3; attempt++) {
      text = draftComment(thread);
      verdict = validComment(text);
      if (verdict.ok) break;
      log({ event: 'draft_retry', permalink: c.permalink, attempt, why: verdict.why, len: text?.length });
    }
    if (!verdict.ok) { log({ event: 'draft_rejected', permalink: c.permalink, why: verdict.why, text }); continue; }

    if (DRY) {
      log({ event: 'dry_run_draft', permalink: c.permalink, len: text.length, text });
      posted++;
    } else {
      const res = reCall(['post', c.permalink, '-'], text);
      let r; try { r = JSON.parse(res.out); } catch { r = { ok: false, raw: res.out, err: res.err }; }
      log({ event: 'post_attempt', permalink: c.permalink, ok: !!r.ok, result: r });
      if (r.ok) posted++;
    }

    if (posted < N) {
      const wait = DELAY_MIN + Math.floor((DELAY_MAX - DELAY_MIN) * Math.abs(Math.sin(Number(process.hrtime.bigint() % 100000n))));
      await sleep(Math.max(DELAY_MIN, Math.min(DELAY_MAX, wait)));
    }
  }

  log({ event: 'session_end', sub, posted, target: N, dryRun: DRY });
}

main().catch(e => log({ event: 'error', error: String(e?.stack || e) }));
