# Anti-Patterns & Gotchas — p-reels-fmt6

## Anti-Patterns (don't do this)

**Use the brand's cloned ElevenLabs voice for every production.** Always pass the `voiceId` from `brand.yaml` — do not swap to a generic ElevenLabs preset or a different voice ID mid-sprint; audiences notice voice drift. If accepting a user-uploaded VO track instead, loudnorm it to -16 LUFS before compositing.

**Don't skip the outro to hit 35-46s.** Brand consistency > target precision. 47-51s final is acceptable; 60s is the hard cap.

**Don't concat `-c copy` as the last step.** The outro source has B-frames and a different time_base; `-c copy` preserves both. Always do a canonical re-encode after concat (see `pipeline.md` Step 4).

**Don't re-theme the visuals away from MGG's typography.** MGG is Inter + JetBrains Mono on dark navy with coral/violet/teal accents. This format (face off-camera + screen UI) does not mean a generic white-on-white minimal aesthetic — preserve the MGG visual identity in every scene.

**Don't use this recipe for news-jacks.** News-jacks need the creator's face for credibility ("this is ME telling you this dropped today"). Use `p-bottom-avatar-pip` for those.

---

## Known Gotchas

**pnpm-installed `node_modules` don't survive `cp -r`.**
When cloning a prior order's Remotion project as a template, run `rm -rf node_modules && npm install` in the new copy. Using pnpm-installed modules from a copied directory causes silent Remotion render failures.

**Speed override math: `raw_seconds / multiplier ≈ final_VO_seconds`.**
Always verify with `ffprobe` after the atempo pass — drift >0.2s means the broll frame budget will mismatch the audio. Recalculate and adjust scene timings before proceeding.

**Concat duration drift.**
Re-encoded final may differ from `composed + outro` source by ±0.1s due to AAC frame alignment. Not worth chasing — document in checklist "pipeline decisions" section.

**Cover frame selection matters.**
Always pick mid-PromptReveal or start-of-ResponseReveal as the cover timestamp, NOT the Hook scene. The Hook uses abstract colored text — it doesn't communicate value in a feed thumbnail. The "money shot" (Claude UI + prompt or result) gets the click.
