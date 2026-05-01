---
name: studio-script
description: Script writing and processing for the creative studio. Use for writing VSL longform scripts, short-form scripts, TTS preprocessing (cleaning scripts for ElevenLabs/HeyGen), voice style adaptation, duration estimation, hook extraction, and rewriting scripts to hit target duration.
when_to_use: Trigger on script, write script, VSL script, short script, TTS clean, preprocess script, voice adapt, script duration, hook extract, script rewrite, word count, speaking rate, TTS text, script analyze, script value segments, short-form script, longform script.
allowed-tools: Bash, Read, Write, Edit
---

# Studio Script — Writing & Processing

## Script Types

| Type | Words | Duration | Use For |
|------|-------|----------|---------|
| Short-form | 75–150 | 30–60s | Shorts, Reels, TikTok |
| Medium | 200–400 | 80–160s | Mid-form content |
| VSL / Longform | 800–1800 | 5–12 min | Sales video, YouTube tutorial |

## Short-Form Script Structure (3-Part)

1. **Hook** (5–10s) — scroll-stop, pattern interrupt. First line determines watch-through rate.
2. **Core Value** (15–35s) — shareable insight, one idea per short
3. **Payoff** (5–10s) — aha moment + soft CTA

### Hook Styles

| Style | Pattern | Example |
|-------|---------|---------|
| `pattern-interrupt` | Contradicts expectation | "Stop using Canva for this..." |
| `math-hook` | Number + tension | "3 tools making $10K/mo without employees" |
| `absurd-stack` | Wild claim then justify | "I replaced my entire team with one prompt" |
| `result-first` | Lead with outcome | "Here's how I went from 0 to 10K followers in 30 days" |

## VSL / Longform Structure

Read the brand's `brands/{slug}/brand-ref.md` for the VSL framework. Standard sections:

1. Hook (0:00–0:30) — bold claim, pattern interrupt
2. Problem agitation (0:30–2:00)
3. Solution reveal (2:00–4:00)
4. Proof / social proof (4:00–7:00)
5. Mechanism explain (7:00–9:00)
6. Offer / CTA (9:00–end)

## TTS Preprocessing (MANDATORY before any TTS submit)

Clean script for ElevenLabs / HeyGen voice engine:

### What to strip:
- Markdown formatting: `##`, `**`, `*`, `_`, backticks
- Stage directions: `[pause]`, `[emphasis]`, `(softer)`, `[HOOK]`, `[BODY]`
- Section markers: `## Hook`, `## Core Value`
- Presenter notes in parentheses

### What to replace:
| Raw | TTS-clean replacement |
|-----|-----------------------|
| `AI` | `A.I.` |
| `UI` | `U.I.` |
| `SaaS` | `sass` |
| `API` | `A.P.I.` |
| `%` | `percent` |
| `$1K` | `one thousand dollars` |
| `&` | `and` |
| `e.g.` | `for example` |
| `i.e.` | `that is` |
| em-dash `—` | `,` (comma pause) |

### Output
- `.md` — human-readable with section markers
- `.txt` — TTS-clean plain text, no markers, no formatting

## Duration Estimation

Speaking rate: **2.5 words/second** (standard)

```
WORD_COUNT = count spoken words (skip markers, directions)
ESTIMATED_SECONDS = WORD_COUNT / 2.5
```

| Seconds | Classification |
|---------|---------------|
| < 60s | `short` |
| 60–180s | `in-range` medium |
| 180–720s | `in-range` VSL |
| > 720s | `long` |

If `STATUS == long`: offer to rewrite to target duration. If `STATUS == short` for a VSL: offer to expand.

## Voice Style Adaptation

Before writing for a brand, read `brands/{slug}/brand-ref.md`:
- Tone (casual, professional, authoritative)
- Vocabulary level
- Sentence length preference
- Brand personality adjectives

Adapt all scripts to match brand voice. Never use generic marketing language without brand personality check.

## Hook Extraction (for hook-jacked reel)

Extract the first 5–10 seconds from any script:
- Must be complete thought (not mid-sentence cut)
- Must work standalone (no "as I mentioned" references)
- Mark hook boundary with `[HOOK END]`
- Output: `{production}/interim/scripts/{slug}-hook.txt`

## Value Segment Analysis

Identify 3–5 highest-value moments in a script for b-roll prioritization:
- Moments with specific numbers or statistics
- Claims that need visual proof
- Process steps that benefit from demonstration
- CTA moments

## Output Paths

- Script draft: `{production}/interim/scripts/{slug}-script-draft.md`
- Final script: `{production}/interim/scripts/{slug}-script.md`
- TTS-clean: `{production}/interim/scripts/{slug}-tts.txt`
- Hook extract: `{production}/interim/scripts/{slug}-hook.txt`
