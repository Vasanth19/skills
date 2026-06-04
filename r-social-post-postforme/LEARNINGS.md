# r-social-post-postforme Learnings

> This file is the self-learning loop for `r-social-post-postforme`. Before executing this skill, the agent reads this file and applies all accumulated `Active Feedback`. After execution, the agent asks the user for feedback and appends it here.

---

## Active Feedback (apply on every run)

*None yet — add feedback below and it becomes part of this skill's behavior.*

---

## Feedback Log

### 2026-05-08 — Initial template
- Skill created. No feedback yet.

### 2026-05-10 — VAS-450 Top 20 Claude Code Skills reel publish
- POSTFORME_API_KEY for MGG brand lives in `~/.gsai/secrets.env` as `POSTFORME_API_KEY_MGG`; must `source` that file before running scripts since the posting-tools .gsai/secret file is empty.
- All 3 platforms (IG, TikTok, YT Shorts) processed successfully in ~60s; no issues with TikTok token despite expiry warning (PostForMe auto-refreshed via refresh token).
- TikTok returns channel page URL only (`https://www.tiktok.com/@mr.growthguide`), not a direct video permalink — expected behavior per existing memory.

### 2026-06-01 — VAS-504 MGG Day14.Reel3 — weekly review system reel
- Threads 500-char caption limit hit (full caption was 547 chars) — need a separate `create-post.sh` call for Threads with trimmed caption whenever the main caption exceeds 500 chars.
- X OAuth2 token (`X_OAUTH2_ACCESS_TOKEN`) expired; refresh rejected with HTTP 401 invalid_request — separate from POSTFORME_API_KEY. When X thread fails, save draft to `final/publishes/x-thread.md` and create a Vasanth-assigned issue for re-auth rather than blocking the full publish.
- Scheduled posts return empty results from `get-post-results.sh` until they fire — expected behavior; don't treat empty results as a create failure for future-dated schedules.

### 2026-06-01 — VAS-503 MGG Day14.Reel2 — weekly review prompt reel
- PostForMe YouTube resumable upload fails for small MP4 files (<3MB): chunk math leaves a final chunk of 186KB which is below YouTube's 256KB minimum per-chunk. Use `.scripts/youtube-upload.py` direct YT Data API v3 for any MGG video under ~3MB — it uploads in one shot with no chunking.
- YouTube access token can expire but PostForMe auto-refreshes via the stored refresh_token — don't skip YT publish just because the access token expiry date has passed.
- `spc_p6l0enswFPmD8grVPT1M` is the correct Threads account ID for MGG (the 'g' in 'gr' was misread as 'c' in earlier attempts — always verify via `list-accounts.sh` before the first publish on a new machine).
- CEO agent handoff-by-mention does not auto-release the issue to CMO; CMO cannot checkout or comment on a CEO-assigned issue. Workflow fix: CEO must `PATCH /api/issues/{id} { "assigneeAgentId": "<CMO-id>" }` BEFORE posting the @CMO handoff comment so CMO can checkout autonomously.

### 2026-05-11 — VAS-451 B-Vasanth LinkedIn image post (Claude Code for B2B Ecommerce)
- B-Vasanth brand API key is `POSTFORME_API_KEY_BVASANTH` in `/Users/vasanth/vasanth-hq/b-vasanth/secrets.env`; export as `POSTFORME_API_KEY` before running scripts (same pattern as MGG).
- LinkedIn image post (no video): use `upload-media.sh` → `create-post.sh` with `scheduled_at` ISO-8601 — no special flags needed. Image uploads and scheduling both succeed in single pass.
- `paperclipai` CLI must be run from `/Users/vasanth` (home dir), not from the workspace dir — "No projects found" error otherwise.

