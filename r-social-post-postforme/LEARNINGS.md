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

### 2026-05-11 — VAS-451 B-Vasanth LinkedIn image post (Claude Code for B2B Ecommerce)
- B-Vasanth brand API key is `POSTFORME_API_KEY_BVASANTH` in `/Users/vasanth/vasanth-hq/b-vasanth/secrets.env`; export as `POSTFORME_API_KEY` before running scripts (same pattern as MGG).
- LinkedIn image post (no video): use `upload-media.sh` → `create-post.sh` with `scheduled_at` ISO-8601 — no special flags needed. Image uploads and scheduling both succeed in single pass.
- `paperclipai` CLI must be run from `/Users/vasanth` (home dir), not from the workspace dir — "No projects found" error otherwise.

