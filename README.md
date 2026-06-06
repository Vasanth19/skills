# Creative Studio Skills

Claude Code skills library for video production workflows. Organized by prefix: **c-** custom tools, **r-** role workflows, **p-** pipelines, **f-** frameworks, **b-** brand pipelines, **t-** third-party platforms, **x-** experimental.

## Install

```bash
# Install a single skill globally
npx skills add vasanth/skills@c-ffmpeg

# Install all studio domain skills
npx skills add vasanth/skills@c-ffmpeg
npx skills add vasanth/skills@t-heygen
npx skills add vasanth/skills@c-broll
npx skills add vasanth/skills@c-studio-audio
npx skills add vasanth/skills@c-studio-script
npx skills add vasanth/skills@c-studio-production
npx skills add vasanth/skills@c-ai-media
npx skills add vasanth/skills@c-html-gfx
npx skills add vasanth/skills@c-web-capture
npx skills add vasanth/skills@c-cloud-media
```

## How Skills Are Managed

**Do NOT symlink all skills globally.** Project-local `.claude/skills/` loads the FULL content of every skill into the system prompt (~500–2000+ tokens per skill). With 40 skills, that's 20K–80K tokens burned before the agent even starts.

Instead, register skills in **Paperclip** and assign them to specific agents via `desiredSkills`:

| Where | What Gets Loaded | Filtering |
|-------|-----------------|-----------|
| Paperclip managed skills (`company_skills` + `desiredSkills`) | Full content, but only for skills the agent was assigned | Per-agent `desiredSkills` |
| Project-local `.claude/skills/` | Full content of EVERY skill in the folder | None — all agents get all of them |

**Rule:** Register skills in Paperclip. Assign only the skills an agent role actually needs.

## 📚 **FIND THE RIGHT SKILL — START HERE**

**→ [`SKILLS-CATALOG.md`](SKILLS-CATALOG.md)** — Your decision tree by output type + AI method

**Quick filters:**
- **Short-form reels (9:16)?** → See "Short-Form Reels" section
- **Long-form video (16:9)?** → See "Long-Form Videos" section
- **Images/graphics (HTML, AI)?** → See "Images & Graphics" section
- **Social publishing?** → See "Publishing & Social Workflows" section
- **A specific AI method (HeyGen, Higgsfield, Gemini)?** → See "Decision Tree" → search by AI

**Agent integrations:**
- **skills.json** — Machine-readable metadata for agent queries (search by output type, AI method, platforms)
- **LEARNINGS-INDEX.md** — Aggregated feedback from all skills (what works, what's stable, what needs attention)

---

## Custom Tools (c-) — Auto-invoked Building Blocks

Composable tools used by any agent. Claude auto-invokes when the task matches.

**[See SKILLS-CATALOG.md → Supporting Tools for full table]**

Core tools:
- `c-ffmpeg` — All video compositing (PIP, chroma key, concat, loudnorm, etc.)
- `c-broll` — B-roll library management & planning
- `c-studio-audio` — TTS voiceover + transcription + loudnorm
- `c-studio-script` — Script preparation & voice adaptation
- `c-studio-production` — Folder structure + 12-point delivery checklist
- `c-ai-media` — AI image/video (Gemini, Higgsfield, Veo, RunPod)
- `c-html-gfx` — HTML graphics & banners (headless Chrome)
- `c-web-capture` — Website scroll capture (Playwright)
- `c-cloud-media` — Cloudflare R2 upload & CDN
- `c-learnloop` — LearnLoop API integration

## Framework Skills (f-) — Tech/Library Reference Knowledge

Auto-invoked when the task involves the relevant framework or library.

- `f-hyperframes` — HyperFrames HTML video composition authoring
- `f-hyperframes-cli` — HyperFrames CLI (init, lint, preview, render, transcribe, tts)
- `f-hyperframes-registry` — HyperFrames registry blocks & components
- `f-gsap` — GSAP animation reference for HyperFrames compositions
- `f-remotion` — Remotion (React-based video) best practices
- `f-sfx` — Sound effects reference

## Brand Pipeline Skills (b-) — Brand-locked Pipeline Variants

Production pipelines locked to a specific brand's workflow.

- `b-growthguide-avatar-broll` — GrowthGuide 20s portrait short: HeyGen avatar + b-roll

## Third-Party Platform Skills (t-) — External API Wrappers

Skills with auth requirements, cost implications, and rate limits.

- `t-heygen` — HeyGen avatar green-screen rendering
- `t-kie-ai` — AI image/video via kie.ai and fal.ai
- `t-replicate` — Replicate model hub (custom AI models)

## Role Workflows (r-) — Intentional Human Actions

Workflows a specific role performs. Kept auto-invokable so Paperclip agents can trigger them.

**[See SKILLS-CATALOG.md → Publishing & Social Workflows for full table]**

- `r-social-post-outstand` — 10 platforms via Outstand.so
- `r-social-post-postforme` — 9 platforms via PostForMe
- `r-social-post-upload` — Multi-brand via Upload-Post
- `r-x-thread` — Native Twitter thread chaining (X API v2)
- `r-youtube-data-api` — YouTube metadata & analytics

## Project Pipelines (p-) — End-to-End Deliverables

Complete production pipelines. Invoked by Creative Director or Video Producer agents.

**[See SKILLS-CATALOG.md for full breakdown by output type]**

**Short-form (9:16):**
`p-avatar-short`, `p-gfx-short`, `p-gfx-batch`, `p-ai-character`, `p-hook-reel`, `p-viral-reel`, `p-snap-bg-swap`

**Long-form (16:9):**
`p-vsl`, `p-longform`, `p-demo`

**Graphics/Publishing:**
`p-thumbnail`, `p-linkedin-carousel`, `p-banner`, `p-broll`, `p-broll-media`, `p-manual-execution`

## Usage

Pipeline skills (`p-*`) are user-invoked — type `/p-vsl brand-slug my-production` in Claude Code.

Custom tool skills (`c-*`) are auto-invoked by Claude when the task matches. You can also invoke directly: `/c-ffmpeg`.

Role workflow skills (`r-*`) are auto-invoked by Paperclip agents when a social posting or thread task matches.

## Environment Variables Required

```bash
# Audio
ELEVENLABS_API_KEY=
FLOE_API_KEY=cfwsfloe_...

# Video
HEYGEN_API_KEY=
RUNPOD_API_KEY=

# Storage
R2_ENDPOINT=
R2_BUCKET=
R2_PUBLIC_DOMAIN=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# AI Generation
GEMINI_API_KEY=
```

See `.env.example` for full template.

## Paperclip Setup (Recommended)

Register skills in your Paperclip org and assign via `desiredSkills`:

```yaml
# Example: CMO agent gets only social posting skills
desiredSkills:
  - r-social-post-postforme
  - r-social-post-outstand
  - r-x-thread

# Example: Creative Director gets pipelines + tools
desiredSkills:
  - p-vsl
  - p-avatar-short
  - p-hook-reel
  - c-ffmpeg
  - t-heygen
  - c-broll
  - c-studio-script
  - c-studio-audio
```

Do NOT put all 40 skills in `.claude/skills/`. Use Paperclip's per-agent filtering.

## Publishing to skills.sh

Before publishing publicly, replace hardcoded values with `$ENV_VAR` placeholders:
- `cfwsfloe_...` API keys → `$FLOE_API_KEY`
- `/Users/vasanth/...` paths → `$STUDIO_PATH`
- Voice IDs → documented in `.env.example`

Submit at [skills.sh](https://skills.sh) after scrubbing.
