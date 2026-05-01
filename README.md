# Creative Studio Skills

Claude Code skills library for video production workflows. Organized by prefix: **c-** custom tools, **r-** role workflows, **p-** project pipelines.

## Install

```bash
# Install a single skill globally
npx skills add vasanth/skills@c-ffmpeg

# Install all studio domain skills
npx skills add vasanth/skills@c-ffmpeg
npx skills add vasanth/skills@c-heygen
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

## Custom Tools (c-) — Auto-invoked Building Blocks

Composable tools used by any agent. Claude auto-invokes when the task matches.

| Skill | Used By | Description |
|-------|---------|-------------|
| `c-ffmpeg` | Any agent | Video/audio operations: composite, colorkey, PIP, portrait/landscape layouts, loudnorm, delivery |
| `c-heygen` | Any agent | HeyGen avatar rendering via API, MCP, browser, or human delegation |
| `c-broll` | Any agent | B-roll library management, script matching, placement planning, alignment verification |
| `c-studio-audio` | Any agent | TTS (ElevenLabs via Floe), SFX, MLX Whisper transcription, loudnorm |
| `c-studio-script` | Any agent | Script writing (VSL/short), TTS preprocessing, voice adaptation, duration analysis |
| `c-studio-production` | Any agent | Production folder structure, delivery checklist, hook extraction, snap detection |
| `c-ai-media` | Any agent | AI image/video generation: Gemini, Higgsfield Cinema, RunPod InfiniteTalk, Veo |
| `c-html-gfx` | Any agent | HTML graphics, banners, explainer slides, headless Chrome screenshots, Remotion |
| `c-web-capture` | Any agent | Playwright website scroll capture, URL discovery |
| `c-cloud-media` | Any agent | Cloudflare R2 upload, CDN management, video library lookup |
| `c-fal-ai` | Any agent | Fal.ai image/video generation API |
| `c-kie-ai` | Any agent | KIE AI platform integration |
| `c-replicate` | Any agent | Replicate model running and API operations |

## Role Workflows (r-) — Intentional Human Actions

Workflows a specific role performs. Kept auto-invokable so Paperclip agents can trigger them.

| Skill | Typical Role | Description |
|-------|--------------|-------------|
| `r-social-post-outstand` | Social Manager / Marketer | Post via Outstand.so (10 platforms, usage-based) |
| `r-social-post-postforme` | Social Manager / Marketer | Post via PostForMe (9 platforms, pay-per-post) |
| `r-social-post-upload` | Social Manager / Marketer | Post via Upload-Post (multi-brand support) |
| `r-x-thread` | Social Manager / Marketer | Post multi-tweet threads via X API v2 |

## Project Pipelines (p-) — End-to-End Deliverables

Complete production pipelines. Invoked by Creative Director or Video Producer agents.

| Pipeline | Produces |
|----------|---------|
| `/p-vsl` | 16:9 longform VSL with avatar PIP + b-roll |
| `/p-avatar-short` | 9:16 avatar short with portrait composite |
| `/p-gfx-short` | 9:16 faceless GFX short with voiceover |
| `/p-ai-character` | 9:16 AI character short — human, plush, mascot, or fantasy |
| `/p-hook-reel` | 9:16 hook-jacked reel with brand continuation |
| `/p-shared-avatar` | One HeyGen render shared across multiple productions |
| `/p-snap-bg-swap` | Finger-snap background swap reel |
| `/p-viral-reel` | Viral reel recreation — `--style avatar` or `--style ai-generated` |
| `/p-longform-visual` | Tutorial video with Remotion GFX + slides |
| `/p-broll` | B-roll library — `capture`, `extract`, or `upload` |
| `/p-broll-media` | Embed b-roll into CFW content variant |
| `/p-gfx-batch` | Batch HTML GFX card production |
| `/p-thumbnail` | YouTube thumbnail variants |
| `/p-linkedin-carousel` | LinkedIn PDF carousel |
| `/p-banner` | Platform social media banners |
| `/p-manual-execution` | Recover stuck CFW executions |
| `/p-demo-short` | Short-form demo distribution from raw assets |
| `/p-demo-long` | Long-form demo distribution from raw assets |
| `/p-demo-avatar` | Demo video with HeyGen API avatar automation |

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
  - c-heygen
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
