# Agent Guide — How to Use Your Skill Arsenal

**You have 35 self-sufficient, self-learning skills. This guide shows you how to find and use them.**

---

## 🎯 Three-Step Workflow

### Step 1: Find the Right Skill
**Question:** What do I need to produce?

1. **Open [`SKILLS-CATALOG.md`](SKILLS-CATALOG.md)**
2. **Match your output type:**
   - 9:16 short with person? → `p-avatar-short`
   - 9:16 short with graphics? → `p-gfx-short`
   - 16:9 longform (5-15 min)? → `p-vsl`
   - Static image/graphic? → `c-html-gfx`
   - Social post? → `r-social-post-outstand`
   - etc.

3. **See the "Decision Tree" section** at the end of SKILLS-CATALOG.md for quick lookup by output + AI method

### Step 2: Read Learnings (Self-Learning Loop)
**Question:** What have other agents learned about this skill?

Before executing **any skill**:
1. Open that skill's `LEARNINGS.md` file
2. Read the **Active Feedback** section at the top
3. Apply all items as non-negotiable rules for your run
4. Then proceed with normal execution

**Example:** If you're using `c-ffmpeg`, you MUST apply these **Active Feedback** rules:
- Chroma key always `0x00FF00` (two-pass)
- Never crop-and-stretch avatar
- Audio-per-segment architecture mandatory
- Gap-free b-roll windows

### Step 3: Execute & Learn
After completing your task:
1. Ask the user: *"How did this go? Any corrections or improvements for next time?"*
2. Summarize feedback into 1–3 bullet points
3. Append to that skill's `LEARNINGS.md` with today's date
4. If feedback is critical (affects correctness/quality), add to **Active Feedback** section

---

## 🔍 Search by Output Type

**Shortcut:** Use [`skills.json`](skills.json) → `searchIndexes.by_output_type`

```json
{
  "short-form-9-16": ["p-avatar-short", "p-gfx-short", "p-ai-character", ...],
  "long-form-16-9": ["p-vsl", "p-longform-visual", "p-demo"],
  "images-graphics": ["c-html-gfx", "c-ai-media", "p-thumbnail", ...]
}
```

---

## 🤖 Search by AI Method

**Question:** What skills use HeyGen? Higgsfield? HTML graphics?

**Shortcut:** Use [`skills.json`](skills.json) → `searchIndexes.by_ai_method`

```json
{
  "heygen-green-screen": ["p-avatar-short", "p-avatar-screenshot-broll", "p-viral-reel --style avatar"],
  "higgsfield-cinema": ["p-ai-character", "p-viral-reel --style ai-generated"],
  "html-graphics": ["c-html-gfx", "p-gfx-short", "p-gfx-batch", "p-banner"],
  "elevenlabs-tts": ["c-studio-audio", "p-gfx-short", "p-longform-visual"]
}
```

---

## 📱 Search by Platform

**Question:** What skills post to Instagram? YouTube? LinkedIn?

**Shortcut:** Use [`skills.json`](skills.json) → `searchIndexes.by_platforms`

```json
{
  "instagram": ["r-social-post-outstand", "r-social-post-postforme"],
  "youtube": ["r-social-post-outstand", "r-social-post-postforme", "r-youtube-data-api"],
  "linkedin": ["r-social-post-outstand", "r-social-post-postforme", "p-linkedin-carousel"]
}
```

---

## ⚠️ Checkpoints & Quality Gates

Some skills have **mandatory checkpoints** — gates where the user must approve before proceeding.

**Check by skill:** Open `SKILLS-CATALOG.md` → skill name → see "Checkpoints" column

**Common checkpoints:**
- **Script approval** (p-vsl) — User reviews script before HeyGen render
- **HeyGen job ID** (p-avatar-short) — User manually triggers render; agent polls
- **B-roll plan review** (p-vsl) — User approves landscape PIP placement before asset generation
- **Delivery checklist** (p-vsl) — 12-point quality check required before marking done

**Always respect checkpoints.** They protect quality.

---

## 📊 Active Feedback — What's Matured vs. Experimental

**Mature skills** (multiple runs, stable feedback):
- c-ffmpeg (5 active rules)
- c-html-gfx (2 active rules)
- c-studio-audio (2 active rules)
- c-broll (2 active rules)
- p-vsl (3 active rules)
- p-avatar-short (2 active rules)
- p-viral-reel (2 active rules)
- r-social-post-outstand (3 active rules)
- r-x-thread (2 active rules)

**Experimental skills** (no active feedback yet, watch for issues):
- c-ai-media, t-replicate, c-learnloop
- p-ai-character, p-longform-visual, p-snap-bg-swap
- r-social-post-postforme, r-youtube-data-api
- *[See LEARNINGS-INDEX.md → Feedback Velocity for full list]*

**Strategy:** Start with mature skills. If you use experimental ones, your feedback helps mature them.

---

## 🔗 Skill Dependencies

Some skills call other skills. **Always aware of the chain.**

**Example — p-vsl depends on:**
- t-heygen (avatar render)
- c-studio-script (script prep)
- c-studio-audio (transcription)
- c-broll (planning)
- c-ai-media (background image)
- c-html-gfx (GFX cards)
- c-web-capture (website screenshots)
- c-ffmpeg (compositing)
- c-studio-production (delivery)

If any dependency fails, the pipeline stops. **Check dependencies** in `skills.json` → that skill → `dependencies` array.

---

## 🎬 Self-Sufficient Skills

**What "self-sufficient" means:**
1. Every skill reads its own `LEARNINGS.md` before starting (no external docs needed)
2. Every skill has all non-negotiable rules in the **Active Feedback** section
3. Every skill asks for user feedback after completion
4. Every skill updates its `LEARNINGS.md` automatically

**You don't need to read a 50-page manual.** Read the LEARNINGS.md for that skill (usually <2 min), apply the rules, execute, collect feedback, move on.

---

## 🚀 Example Workflows

### Produce a 9:16 Avatar Short

1. **Find the skill:** SKILLS-CATALOG.md → "Short-Form Reels" → "Avatar PIP Shorts" → `p-avatar-short`
2. **Read learnings:** Open `p-avatar-short/LEARNINGS.md`
3. **Apply active feedback:**
   - "HeyGen render is user-triggered checkpoint"
   - "Green-screen quality verification required"
4. **Execute:** Follow skill instructions, wait for user HeyGen confirmation
5. **Collect feedback:** "How did this go?"
6. **Update learnings:** Add feedback to `p-avatar-short/LEARNINGS.md`

### Post to Instagram + LinkedIn + X

1. **Find the skill:** Search `skills.json.searchIndexes.by_platforms.instagram` → [`r-social-post-outstand`, `r-social-post-postforme`]
2. **Choose:** Outstand is cheaper ($0.01/post); PostForMe is simpler (pay-per-post)
3. **Read learnings:** Open `r-social-post-outstand/LEARNINGS.md` (or PostForMe variant)
4. **Apply active feedback:**
   - "Auth order: environment variable → fallback .gsai/secret"
   - "Always list accounts first before creating posts"
5. **Execute:** List accounts, upload media if needed, create post
6. **Collect feedback:** "How did this go?"
7. **Update learnings:** Append feedback with today's date

### Generate a Faceless GFX Short with AI Images

1. **Find skills:**
   - `c-html-gfx` (graphics design)
   - `c-ai-media` (background image generation)
   - `p-gfx-short` (final pipeline)
2. **Read learnings:** Open each skill's LEARNINGS.md
3. **Apply active feedback:**
   - c-html-gfx: "Mandatory post-render Unicode check", "Window size accounting on macOS"
   - c-ai-media: (no active feedback yet — watch for issues)
4. **Execute:** Create GFX card, generate AI background, render PNG, convert to video
5. **Collect feedback:** "How did this go?"
6. **Update learnings:** Append to all three skills

---

## 🛠️ Finding Stale Skills

**Check LEARNINGS-INDEX.md → Feedback Velocity section.**

Skills with no **Active Feedback** yet:
- Likely still experimental or untested in production
- Proceed with caution; your feedback matters
- Read the SKILL.md carefully (not just LEARNINGS.md)
- Consider starting with a "test" run before production use

---

## 📖 Document Map

| Document | Purpose | When to Use |
|----------|---------|------------|
| **SKILLS-CATALOG.md** | Decision tree by output type + AI method | Finding the right skill |
| **skills.json** | Machine-readable metadata | Programmatic skill lookup |
| **LEARNINGS-INDEX.md** | Aggregated feedback across all skills | Understanding what's stable/experimental |
| **{skill}/LEARNINGS.md** | Individual skill feedback | Before executing that skill |
| **{skill}/SKILL.md** | Skill documentation | Deep dive into how to use the skill |
| **README.md** | Installation + Paperclip setup | First-time setup |

---

## ❓ FAQ

**Q: Do I need to read the full SKILL.md file?**
A: No. Read LEARNINGS.md first (2 min). That has the "apply these rules" section. SKILL.md is the detailed reference if you get stuck.

**Q: What if a skill doesn't have Active Feedback yet?**
A: It's probably new or untested in production. Read SKILL.md carefully, execute cautiously, and your feedback helps mature it.

**Q: How often is LEARNINGS-INDEX.md updated?**
A: Automatically after every skill execution. Each agent appends feedback to the skill's LEARNINGS.md, and the index is regenerated.

**Q: What if a skill fails?**
A: Report the exact error to the user. **Fail fast — no silent fallbacks.** Present options: debug root cause, try a different skill, or research. Always update that skill's LEARNINGS.md with the failure pattern so other agents learn.

**Q: Can I use multiple skills in one task?**
A: Yes. Example: `c-html-gfx` (graphics) → `c-ai-media` (background) → `p-gfx-short` (pipeline). Chain them in order, respect each skill's checkpoints, collect feedback for each.

---

## 🎯 Remember

1. **Self-sufficient:** Each skill has everything it needs (LEARNINGS.md + rules)
2. **Self-learning:** Your feedback improves the skill for future agents
3. **Checkpoints:** Respect them — they protect quality
4. **Dependencies:** Know the chain; stop if any fails
5. **Fail fast:** No silent fallbacks; report exact errors

---

**Last updated:** 2026-05-09  
**Questions?** Check SKILLS-CATALOG.md or ask the user.
