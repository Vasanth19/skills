# Creative Studio Skills

Claude Code skills library for video production workflows. 10 domain skills + 21 production pipelines.

## Install

```bash
# Install a single skill globally
npx skills add vasanth/skills@ffmpeg

# Install all studio domain skills
npx skills add vasanth/skills@ffmpeg
npx skills add vasanth/skills@heygen
npx skills add vasanth/skills@broll
npx skills add vasanth/skills@studio-audio
npx skills add vasanth/skills@studio-script
npx skills add vasanth/skills@studio-production
npx skills add vasanth/skills@ai-media
npx skills add vasanth/skills@html-gfx
npx skills add vasanth/skills@web-capture
npx skills add vasanth/skills@cloud-media
```

## Domain Skills (Auto-Invoked by Claude)

| Skill | Description |
|-------|-------------|
| `ffmpeg` | All FFmpeg operations: composite, colorkey, PIP, portrait/landscape layouts, loudnorm, delivery |
| `heygen` | HeyGen avatar rendering via API, MCP, browser, or human delegation |
| `broll` | B-roll library management, script matching, placement planning, alignment verification |
| `studio-audio` | TTS (ElevenLabs via Floe), SFX, MLX Whisper transcription, loudnorm |
| `studio-script` | Script writing (VSL/short), TTS preprocessing, voice adaptation, duration analysis |
| `studio-production` | Production folder structure, delivery checklist, hook extraction, snap detection |
| `ai-media` | AI image/video generation: Gemini, Higgsfield Cinema, RunPod InfiniteTalk, Veo |
| `html-gfx` | HTML graphics, banners, explainer slides, headless Chrome screenshots, Remotion |
| `web-capture` | Playwright website scroll capture, URL discovery |
| `cloud-media` | Cloudflare R2 upload, CDN management, video library lookup |

## Pipeline Skills (User-Invoked `/pipeline-*`)

| Pipeline | Produces |
|----------|---------|
| `/pipeline-vsl` | 16:9 longform VSL with avatar PIP + b-roll |
| `/pipeline-avatar-short` | 9:16 avatar short with portrait composite |
| `/pipeline-gfx-short` | 9:16 faceless GFX short with voiceover |
| `/pipeline-ai-character` | 9:16 AI character animated short (Gemini + Hailuo) |
| `/pipeline-hook-reel` | 9:16 hook-jacked reel with brand continuation |
| `/pipeline-shared-avatar` | One HeyGen render shared across multiple productions |
| `/pipeline-snap-bg-swap` | Finger-snap background swap reel |
| `/pipeline-viral-reel` | Viral reel recreation with avatar PIP |
| `/pipeline-viral-reel-ai` | AI tool viral reel (Higgsfield + Veo) |
| `/pipeline-longform-visual` | Tutorial video with Remotion GFX + slides |
| `/pipeline-infinite-talk` | Animated talking head via RunPod InfiniteTalk |
| `/pipeline-labubu` | Plush character animated short (Tiny Tales style) |
| `/pipeline-broll-capture` | Website scroll b-roll capture |
| `/pipeline-broll-extract` | Extract clips from source video |
| `/pipeline-broll-upload` | Upload pending b-roll to Cloudflare R2 |
| `/pipeline-broll-media` | Embed b-roll into CFW content variant |
| `/pipeline-gfx-batch` | Batch HTML GFX card production |
| `/pipeline-thumbnail` | YouTube thumbnail variants |
| `/pipeline-linkedin-carousel` | LinkedIn PDF carousel |
| `/pipeline-banner` | Platform social media banners |
| `/pipeline-manual-execution` | Recover stuck CFW executions |

## Usage

Pipeline skills are user-invoked (`disable-model-invocation: true`). Type `/pipeline-vsl brand-slug my-production` in Claude Code.

Domain skills are auto-invoked by Claude when the task matches. You can also invoke directly: `/ffmpeg`.

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

## Local Setup (Symlinks)

```bash
# Link all skills globally (available in every Claude session)
for skill in ~/Code/skills/*/; do
  name=$(basename "$skill")
  ln -sf "$skill" ~/.claude/skills/"$name"
done
```

## Publishing to skills.sh

Before publishing publicly, replace hardcoded values with `$ENV_VAR` placeholders:
- `cfwsfloe_...` API keys → `$FLOE_API_KEY`  
- `/Users/vasanth/...` paths → `$STUDIO_PATH`
- Voice IDs → documented in `.env.example`

Submit at [skills.sh](https://skills.sh) after scrubbing.
