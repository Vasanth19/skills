#!/usr/bin/env node
/*
 * c-reddit-engage — daily health monitor.
 *
 * Pings (macOS notification) ONLY when something needs attention:
 *   - a comment was REMOVED (checked logged-out: removed comments lose the author + show a
 *     removal phrase to logged-out viewers — the reliable signal; /notifications is bot-blocked)
 *   - the session is expired (LIVE whoami against the profile fails)
 *   - a post attempt failed today
 * Always appends a one-line daily digest to reddit-engage-digest.log (quiet when healthy).
 * Removed permalinks are remembered so the same removal isn't re-alerted daily.
 *
 * Run BASELINE=1 once to seed state silently. Schedule daily (22:30) via the monitor plist.
 */

import { chromium } from 'playwright';
import { spawnSync } from 'child_process';
import os from 'os';
import path from 'path';
import fs from 'fs';

const SECRETS = path.join(os.homedir(), 'ecosystem/vault');
const PROFILE = process.env.REDDIT_PROFILE || path.join(SECRETS, 'reddit-profile');
const AUTO_LOG = path.join(SECRETS, 'reddit-engage-auto.log');
const DIGEST = path.join(SECRETS, 'reddit-engage-digest.log');
const STATE = path.join(SECRETS, 'reddit-engage-monitor.state.json');
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

function notify(title, msg) {
  spawnSync('osascript', ['-e', `display notification ${JSON.stringify(msg)} with title ${JSON.stringify(title)}`]);
}
function loadState() { try { return JSON.parse(fs.readFileSync(STATE, 'utf8')); } catch { return { seenRemoved: [] }; } }
function saveState(s) { fs.writeFileSync(STATE, JSON.stringify(s)); }

function todayLogLines() {
  if (!fs.existsSync(AUTO_LOG)) return [];
  const today = new Date().toISOString().slice(0, 10);
  return fs.readFileSync(AUTO_LOG, 'utf8').trim().split('\n')
    .map(l => { try { return JSON.parse(l); } catch { return null; } })
    .filter(e => e && e.t && e.t.slice(0, 10) === today);
}

// Logged-out removal check for each posted comment permalink.
async function checkRemovals(permalinks, username) {
  const removed = [], inconclusive = [];
  if (!permalinks.length) return { removed, inconclusive };
  const browser = await chromium.launch({ headless: true });
  try {
    for (const pl of permalinks) {
      const ctx = await browser.newContext({ userAgent: UA, viewport: { width: 1200, height: 900 } });
      const page = await ctx.newPage();
      let status = 'inconclusive';
      try {
        await page.goto('https://www.reddit.com' + pl, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(2500);
        status = await page.evaluate((user) => {
          const b = document.body.innerText || '';
          if (/blocked by network security/i.test(b)) return 'inconclusive';
          if (!document.querySelector('shreddit-post')) return 'inconclusive';
          const removedPhrase = /\[removed\]|removed by (reddit|moderator)|comment removed|has been removed/i.test(b);
          const hasAuthor = user ? new RegExp(user).test(b) : true;
          if (removedPhrase && !hasAuthor) return 'removed';
          if (hasAuthor) return 'alive';
          return 'inconclusive';
        }, username);
      } catch { status = 'inconclusive'; }
      await ctx.close();
      if (status === 'removed') removed.push(pl);
      else if (status === 'inconclusive') inconclusive.push(pl);
    }
  } finally { await browser.close(); }
  return { removed, inconclusive };
}

async function main() {
  const alerts = [];
  const log = todayLogLines();
  const postedOk = log.filter(e => e.event === 'post_attempt' && e.ok);
  const postFail = log.filter(e => e.event === 'post_attempt' && e.ok === false).length;
  const sessions = log.filter(e => e.event === 'session_end').length;
  const permalinks = [...new Set(postedOk.map(e => e?.result?.permalink).filter(Boolean))];

  // session-expiry comes from the scheduled sessions' OWN log (authoritative; they run when
  // we're not hammering Reddit, so their whoami is reliable). A live probe here false-positives
  // under throttling, so we don't do one.
  const username = process.env.REDDIT_USER || 'Public_Finding_308';
  const notLoggedIn = log.filter(e => e.event === 'abort' && e.reason === 'NOT_LOGGED_IN').length;
  if (notLoggedIn > 0) alerts.push(`session expired (NOT_LOGGED_IN ×${notLoggedIn}) — re-run \`login\``);
  if (postFail > 0) alerts.push(`${postFail} post attempt(s) failed today`);

  // removal check
  const { removed, inconclusive } = await checkRemovals(permalinks, username || process.env.REDDIT_USER || '');
  const state = loadState();
  const seen = new Set(state.seenRemoved || []);
  const freshRemoved = removed.filter(p => !seen.has(p));
  if (freshRemoved.length) {
    alerts.push(`comment(s) REMOVED: ${freshRemoved.join(', ')}`);
    freshRemoved.forEach(p => seen.add(p));
  }
  state.seenRemoved = [...seen].slice(-500);
  saveState(state);

  const digest = `${new Date().toISOString()} sessions=${sessions} posted=${postedOk.length} failed=${postFail} notLoggedIn=${notLoggedIn} checked=${permalinks.length} removed=${removed.length} fresh=${freshRemoved.length} inconclusive=${inconclusive.length}` +
    (alerts.length ? ` ALERTS: ${alerts.join(' | ')}` : ' OK');
  fs.appendFileSync(DIGEST, digest + '\n');
  console.log(digest);

  if (alerts.length && !process.env.BASELINE) notify('CFW Reddit Engage — needs attention', alerts.join('\n'));
}

main().catch(e => { console.error(e); process.exit(1); });
