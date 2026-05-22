# SFX Library

> Centralized, cross-brand sound effects library. Check here before generating new SFX via ElevenLabs (~$0.10 saved per reuse).

## Catalog

| ID | File | Dur | Category | Description | Use When... | Source |
|----|------|-----|----------|-------------|-------------|--------|
| whoosh-01 | `whoosh/whoosh-01-hook-dramatic.mp3` | 2s | whoosh | Dramatic cinematic whoosh, attention grabber | Hook opening, pattern interrupt | cfw--vsl-0210-15hrs-wasted |
| whoosh-02 | `whoosh/whoosh-02-hook-cinematic.mp3` | 2s | whoosh | Cinematic hook whoosh, modern tech feel | Hook opening, bold statement | mgg--generic-0226-ai-movie-55cents |
| whoosh-03 | `whoosh/whoosh-03-hook-tech.mp3` | 2s | whoosh | Tech-style hook whoosh | Hook opening, fast intro | cfw--lp-asset-0217-homepage-hero |
| ding-01 | `ding/ding-01-trust.mp3` | 2s | ding | Trust/credibility notification chime | Social proof, testimonial, trust moment | cfw--vsl-0210-15hrs-wasted |
| ding-02 | `ding/ding-02-price.mp3` | 2s | ding | Price reveal notification ding | Cost reveal, pricing, dollar amount | mgg--generic-0226-ai-movie-55cents |
| ding-03 | `ding/ding-03-reveal-chime.mp3` | 2s | ding | Uplifting reveal chime, positive | Solution reveal, feature showcase | cfw--vsl-0210-15hrs-wasted |
| ding-04 | `ding/ding-04-winner-chime.mp3` | 2s | ding | Winner/success chime | Winner announcement, best option | mgg--generic-0226-ai-movie-55cents |
| ding-05 | `ding/ding-05-solution-chime.mp3` | 2s | ding | Solution transition chime | Problem-to-solution pivot | cfw--lp-asset-0217-homepage-hero |
| trans-01 | `transition/trans-01-tech.mp3` | 1.5s | transition | Tech-style scene transition | Scene change, topic shift | cfw--vsl-0210-15hrs-wasted |
| tens-01 | `tension/tens-01-problem.mp3` | 3s | tension | Low problem tension rumble | Problem statement, pain point | mgg--generic-0226-ai-movie-55cents |
| tens-02 | `tension/tens-02-stat-impact.mp3` | 2s | tension | Stat impact rumble, subtle weight | Surprising statistic, data reveal | cfw--vsl-0210-15hrs-wasted |
| swell-01 | `swell/swell-01-money-shot.mp3` | 3s | swell | Uplifting money shot swell | Key result, impressive outcome | mgg--generic-0226-ai-movie-55cents |
| swell-02 | `swell/swell-02-cta-sting.mp3` | 3s | swell | Confident CTA outro sting | Call to action, closing | cfw--vsl-0210-15hrs-wasted |
| swell-03 | `swell/swell-03-cta-sting.mp3` | 2.5s | swell | Tech-style CTA sting | Call to action, sign-up prompt | cfw--lp-asset-0217-homepage-hero |

## Categories

| Category | Subfolder | Typical Use |
|----------|-----------|-------------|
| `whoosh` | `whoosh/` | Transition swooshes, hook attention grabbers |
| `ding` | `ding/` | Chimes, reveals, notifications, success sounds |
| `transition` | `transition/` | Scene change sounds, topic shifts |
| `tension` | `tension/` | Low rumbles, suspense, problem reveals |
| `swell` | `swell/` | Uplifting reveals, CTA stings, climax moments |
| `ambient` | `ambient/` | Background textures (none yet) |

## Usage

**Before generating new SFX:**
1. Check this library for a matching sound
2. Preview with `afplay sfx/{category}/{file}.mp3`
3. If a match exists, use the local path directly in `ffmpeg/sfx-mix`
4. Only generate via ElevenLabs if no suitable match found

**Adding new SFX:**
1. Generate via `elevenlabs/sfx-generate` skill
2. Save to `sfx/{category}/{prefix}-{NN}-{description}.mp3`
3. Add a row to this table with source production
