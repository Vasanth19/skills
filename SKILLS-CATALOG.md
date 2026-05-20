# Creative Studio Skills Catalog

**Your skill arsenal organized by output type + AI method.** Agents use this to find the right skill without guessing.

Every skill is **self-sufficient** (reads LEARNINGS.md before executing) and **self-improving** (appends feedback after every run).

---

## 🎬 SHORT-FORM REELS (9:16 vertical)

### Avatar PIP Shorts
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **p-avatar-short** | HeyGen green-screen | Brand + script | 9:16 avatar PIP on background | ✅ LEARNINGS.md |
| **p-avatar-screenshot-broll** | HeyGen + screenshot b-roll | Brand + script + website | 9:16 avatar PIP with website screenshots | ✅ LEARNINGS.md |

**When to use:** Character-driven content, direct-to-camera pitches, founder messages.
**Checkpoint:** HeyGen job ID required before proceeding.

---

### AI Character Shorts
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **p-ai-character** | Higgsfield Cinema + Veo | Brand + script + style | 9:16 AI character (human/plush/mascot/fantasy) | ✅ LEARNINGS.md |

**When to use:** Animated character brand voice, mascot content, stylized avatars (avoid photorealistic).
**AI Chain:** Higgsfield (cinematic) → Veo (talking head) → composite.

---

### Faceless GFX Shorts
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **p-gfx-short** | HTML graphics + voiceover | Brand + script | 9:16 GFX short with animated overlays | ✅ LEARNINGS.md |
| **p-gfx-batch** | HTML graphics (batch mode) | Brand + 10+ script variants | 10+ GFX shorts (parallel render) | ✅ LEARNINGS.md |

**When to use:** Explainer content, stats/data visualization, faceless education videos.
**Output:** One HTML card → PNG screenshot → 5s video clip with Ken Burns zoom.

---

### Hook-Jacked Reels
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **p-hook-reel** | Brand continuation (b-roll) | Viral hook + brand content | 9:16 hook + brand CTA reel | ✅ LEARNINGS.md |
| **p-viral-reel** | HeyGen OR Higgsfield+Veo | Source URL + brand voice | 9:16 viral recreation (avatar/ai-generated) | ✅ LEARNINGS.md |

**When to use:** Trending audio/format jacking, viral recreation.
**Viral reel note:** `--style avatar` is production-ready; `--style ai-generated` (Higgsfield) needs API update.

---

### Specialty Reels
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **p-snap-bg-swap** | B-roll background replacement | Original + new background | 9:16 finger-snap BG swap effect | ✅ LEARNINGS.md |
| **p-thumbnail** | Static image (no AI) | Video or script | Multiple YouTube thumbnail variants (1280x720) | ✅ LEARNINGS.md |

**When to use:** p-snap-bg-swap for trendy visual effects; p-thumbnail for YouTube CTR testing.

---

## 📺 LONG-FORM VIDEOS (16:9 landscape)

### VSL & Avatar Longform
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **p-vsl** | HeyGen avatar PIP | Brand + script (5-15 min) | 16:9 VSL: avatar PIP + b-roll + SFX + captions | ✅ LEARNINGS.md |

**When to use:** Long-form sales, educational content, webinar recordings.
**Pipeline:** Script → HeyGen → transcribe → b-roll plan → composite → loudnorm → delivery.
**Checkpoints:** Script approval, b-roll plan review, final delivery check.

---

### Visual Tutorial/Explainer Longform
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **p-longform-visual** | Remotion GFX + slides | Brand + tutorial script | 16:9 tutorial with animated slide transitions + voiceover | ✅ LEARNINGS.md |
| **p-demo** | Any (asset reuse) | Raw footage/script + brand | 16:9 short/long/avatar demo from existing assets | ✅ LEARNINGS.md |

**When to use:** Product demos, tutorials, "how-to" content.
**Remotion method:** React-based animation composition → render to MP4.

---

## 🖼️ IMAGES & GRAPHICS

### HTML-Based Graphics
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **c-html-gfx** | Headless Chrome screenshot | HTML template | PNG/JPG graphic (1920x1080, 1080x1080, or custom) | ✅ LEARNINGS.md |
| **p-gfx-batch** | HTML (batch) + Remotion | Brand + 10+ design variants | 10+ PNG cards → 5s video clips with Ken Burns | ✅ LEARNINGS.md |

**When to use:** Social banners, explainer cards, video overlays, stat graphics.
**GFX types:** pipeline-diagram, cost-table, comparison-table, callout-card, hero-stat, terminal-sim, custom.
**Output path:** 1920x1080 Dark Studio theme (Poppins font, purple/green/yellow accent palette).

---

### AI-Generated Images
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **c-ai-media** | Gemini, Higgsfield, Replicate, RunPod | Prompt + brand ref | AI image/video (varies by model) | ✅ LEARNINGS.md |

**AI options:**
- **Gemini 2.0 Flash** — Fast text-to-image, includes in-context learning
- **Higgsfield Cinema** — Cinematic video generation (for p-ai-character backgrounds)
- **RunPod InfiniteTalk** — Talking head video from image + audio
- **Veo** — High-quality video generation (used in p-ai-character)
- **Replicate** — Model hub access (custom models)

**When to use:** Background images, b-roll placeholders, brand asset generation.

---

### B-Roll & Website Capture
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **c-web-capture** | Playwright (no AI) | URL + scroll settings | MP4 video of webpage scroll (1920x1080, 12s default) | ✅ LEARNINGS.md |
| **c-broll** | Library management (no AI) | Script + library | B-roll segment plan + reusable assets | ✅ LEARNINGS.md |

**When to use:** Website screenshots for tutorials, b-roll planning for VSL, asset organization.
**c-broll:** Checks library first; plans placement before generating anything new.

---

### Platform-Specific Graphics
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **p-linkedin-carousel** | PDF (no AI) | 5-10 slide content | Multi-page PDF carousel (optimized for LinkedIn) | ✅ LEARNINGS.md |
| **p-banner** | HTML (no AI) | Brand assets | Platform banners (Instagram, TikTok, YouTube, etc.) | ✅ LEARNINGS.md |

**When to use:** LinkedIn thought leadership, platform-specific templates.

---

## 🎵 AUDIO & VOICE

### Text-to-Speech & Audio Processing
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **c-studio-audio** | ElevenLabs TTS + MLX Whisper | Script text OR audio file | .mp3 voiceover OR .srt transcription | ✅ LEARNINGS.md |

**When to use:** TTS voiceover generation, transcription of video audio.
**Output:** 
- ElevenLabs (Floe API wrapper) — 16+ voices, natural prosody
- MLX Whisper — Accurate transcription to SRT format

---

### Script Preparation
| Skill | AI Method | Input | Output | Self-Learn |
|-------|-----------|-------|--------|-----------|
| **c-studio-script** | Voice adaptation + timing | Draft markdown | TTS-clean script + duration estimate | ✅ LEARNINGS.md |

**When to use:** Before TTS generation — cleans phonetics, adjusts word count for timing.
**Output:** Ready-to-read text that sounds natural at 150 wpm baseline.

---

## 📤 PUBLISHING & SOCIAL WORKFLOWS

### Multi-Platform Social Posting
| Skill | Method | Platforms | Self-Learn |
|--------|---------|-----------|-----------|
| **r-social-post-outstand** | Outstand.so REST API | X, LinkedIn, Instagram, Facebook, Threads, TikTok, YouTube, Bluesky, Pinterest, Google Business (10 total) | ✅ LEARNINGS.md |
| **r-social-post-postforme** | PostForMe REST API | X, LinkedIn, Instagram, Facebook, Threads, TikTok, YouTube, Pinterest, Google Business (9 total) | ✅ LEARNINGS.md |
| **r-social-post-upload** | Upload-Post API | Multi-brand support (integrates with brand folders) | ✅ LEARNINGS.md |

**When to use:** One-off post publishing, scheduling across platforms.
**Difference:** Outstand = usage-based ($0.01/post); PostForMe = pay-per-post; Upload-Post = multi-brand.

---

### Twitter Thread Publishing
| Skill | Method | Platforms | Self-Learn |
|--------|---------|-----------|-----------|
| **r-x-thread** | X API v2 (native) | X only | ✅ LEARNINGS.md |

**When to use:** Multi-tweet threads with proper chaining (not supported by other posting tools).
**Method:** Post tweet 1 → capture ID → reply to ID with tweet 2 → repeat.

---

### YouTube Analytics & Publishing
| Skill | Method | Action | Self-Learn |
|--------|---------|---------|-----------|
| **r-youtube-data-api** | YouTube Data API v3 | Fetch metadata, update video details | ✅ LEARNINGS.md |

**When to use:** Update video titles, descriptions, thumbnails after publish; fetch analytics (views, watch time).
**Limitation:** Metadata updates only (revenue, audience demographics need YouTube Analytics API).

---

### Content Management & Publishing
| Skill | Method | Purpose | Self-Learn |
|--------|---------|---------|-----------|
| **r-cfw-publisher** | CFW content sync | Recover stuck executions, republish content variants | ✅ LEARNINGS.md |

**When to use:** CFW platform-specific publishing, variant management.

---

## 🏢 CFW SOCIAL APP MANAGEMENT

### The CFW Social Platform
| Skill | What it covers | Read it for |
|-------|---------------|-------------|
| **c-cfw-social** | Prisma data model, entity relationships, run/output/composition lifecycle, approval workflows, publishing system, brand/workspace ops, auth cascade, admin runbook | Managing or debugging the CFW Social app itself |

**Files:** `data-model.md` · `lifecycle.md` · `brand-management.md` · `workspace-operations.md` · `approval-workflow.md` · `publishing.md` · `media-capture.md` · `auth.md` · `integrations.md` · `admin-runbook.md` · `routes.json`

**When to use:** Any question about how CFW Social works internally — brands, workspaces, runs, outputs, posts, scheduling, approvals, billing, team access, webhooks.

---

## 🤖 CFW AGENT INTEGRATION

### The CFW Agent Orchestrator
| Skill | What it covers | Read it for |
|-------|---------------|-------------|
| **c-cfw-agent** | How to call cfw-agent via its MCP (`cfw_run` tool), register in Claude Code, auth flow, 28 MCP tools at `/api/v1/mcp`, orchestrator contract v1 | Talking to the cfw-agent from outside (Claude Code, curl, CI) |

**Files:** `mcp.md` · `mcp-example.sh` · `cfw-run.md` · `orchestration-contract.md`

**When to use:** Setting up cfw-agent MCP, calling `cfw_run`, understanding the SSE contract, troubleshooting agent errors.

---

## 🧪 QA & TESTING

### Smoke Testing
| Skill | What it covers | Read it for |
|-------|---------------|-------------|
| **c-cfw-social-smoke-test** | Smoke-test runner for cfw-social HTTP API — hits every route with master-key auth, classifies by auth mode, reports pass/fail | Confirming no 5xx's after deploy or route changes |

**Files:** `smoke.mjs` · `routes.json` · `SKILL.md`

**When to use:** After touching `src/app/api/**`, before shipping to prod, in CI.

---

---

## 🔧 SUPPORTING TOOLS (Auto-Invoked)

### Video Compositing & Effects
| Skill | Capability | Use Case | Self-Learn |
|-------|-----------|----------|-----------|
| **c-ffmpeg** | All video ops: composite, chroma key, PIP, portrait/landscape, concat, trim, speed, Ken Burns, loudnorm, snap detection | Every video production | ✅ LEARNINGS.md |

**Critical rules:**
- Chroma key always `0x00FF00` (two-pass)
- Audio-per-segment architecture (never separate audio/video)
- Never crop-stretch avatar (use 1.15x zoom + crop)

---

### HeyGen Avatar Rendering
| Skill | AI Method | Capability | Self-Learn |
|-------|-----------|-----------|-----------|
| **c-heygen** | HeyGen API | Avatar green-screen render, status polling, download | ✅ LEARNINGS.md |

**When to use:** Any p-avatar-* or p-viral-reel (--style avatar) skill.
**Checkpoint:** User manually triggers render; agent polls for completion.

---

### Cloud Storage & CDN
| Skill | Service | Capability | Self-Learn |
|-------|---------|-----------|-----------|
| **c-cloud-media** | Cloudflare R2 | Upload productions, manage CDN, video library lookup | ✅ LEARNINGS.md |

**When to use:** Final delivery, long-term storage, public distribution.

---

### Production Workflows
| Skill | Capability | Use Case | Self-Learn |
|-------|-----------|----------|-----------|
| **c-studio-production** | Production folder structure, delivery checklist (12-point), hook extraction, snap detection | Every production finalization | ✅ LEARNINGS.md |

**Output:** Standardized delivery format: `ls-{category}01-{description}.mp4`.

---

### Replicate & Custom AI Models
| Skill | Service | Capability | Self-Learn |
|-------|---------|-----------|-----------|
| **c-replicate** | Replicate model hub | Run custom AI models, API operations | ✅ LEARNINGS.md |
| **c-kie-ai** | KIE AI platform | KIE platform integration (if needed) | ✅ LEARNINGS.md |

**When to use:** Custom model experimentation, one-off AI generation beyond standard tools.

---

### LearnLoop Integration
| Skill | Service | Capability | Self-Learn |
|-------|---------|-----------|-----------|
| **c-learnloop** | LearnLoop API | Courses, lessons, bots, library, newsletter, members, events, products, admin | ✅ LEARNINGS.md |

**When to use:** Content library management, course publishing.

---

## 🎯 Decision Tree for Agents

**"I need to produce..."**

- **9:16 short with person on camera?** → `p-avatar-short` (HeyGen) or `p-ai-character` (animated)
- **9:16 short with graphics/no person?** → `p-gfx-short` or `p-gfx-batch`
- **9:16 recreation of viral format?** → `p-viral-reel` (choose --style)
- **16:9 longform (5-15 min)?** → `p-vsl`
- **Tutorial/explainer with slides?** → `p-longform-visual`
- **Static image/graphic?** → `c-html-gfx` (1920x1080) or `c-ai-media` (generated)
- **YouTube thumbnail?** → `p-thumbnail`
- **LinkedIn carousel?** → `p-linkedin-carousel`
- **Social post (multi-platform)?** → `r-social-post-outstand` or `r-social-post-postforme`
- **Twitter thread?** → `r-x-thread`
- **Website screenshot for b-roll?** → `c-web-capture`
- **Voiceover from script?** → `c-studio-audio` + `c-studio-script`

**"I need to manage / debug / understand..."**

- **CFW Social app internals** → `c-cfw-social` (data model, lifecycle, auth, admin)
- **Smoke test after deploy** → `c-cfw-social-smoke-test`
- **Call cfw-agent from Claude Code** → `c-cfw-agent` (MCP registration, `cfw_run`)
- **Recover a stuck run** → `c-cfw-social/admin-runbook.md`
- **Set up social platform OAuth** → `c-cfw-social/integrations.md`
- **Understand the approval flow** → `c-cfw-social/approval-workflow.md`

---

## 📋 Self-Learning Rules (Every Skill)

Before executing **any skill:**
1. Read `LEARNINGS.md` in that skill's folder
2. Apply all items under **Active Feedback** as non-negotiable rules
3. Proceed with normal execution

After completing the task:
1. Ask the user: *"How did this go? Any corrections or improvements for next time?"*
2. Summarize feedback into 1–3 bullet points
3. Append to that skill's `LEARNINGS.md` with today's date
4. If feedback is critical (affects correctness/quality), add to **Active Feedback** section

---

## 🔗 Related Docs

- **README.md** — Installation & Paperclip setup
- **LEARNINGS-INDEX.md** — Aggregated feedback across all skills
- **skills.json** — Machine-readable metadata for agent queries

---

**Last updated:** 2026-05-17  
**Maintained by:** Skills team + self-improvement loop
