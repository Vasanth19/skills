# r-brand-content-pipeline — Learnings

> Append-only operational notes. Newest at top.

## Active Feedback

(Items here are applied as non-negotiable rules on every run. Empty for now — populates over time as the skill is used.)

## History

### 2026-05-13 — Skill created
- Initial scaffold
- Composes c-learnloop + r-social-post-postforme + brand config
- Read `.config/posting-pipeline.yaml` per brand from brand repo (resolved via `~/.gsai/ecosystem.yaml`)
- Stateless: no DB, no daemon — caller invokes per-post
- Writes canonical record to brain-personal at `projects/<brand>/posts/<date>-<slug>.md`
- Approval gate default: `draft_only` for new brands until trust is established
