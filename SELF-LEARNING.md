# Self-Learning Loop — Rollout Template

Every skill in this library should have a `LEARNINGS.md` file and a feedback loop section in its `SKILL.md`. This makes every skill self-improving over time.

---

## How It Works

1. **Before executing:** The agent reads `LEARNINGS.md` and applies all **Active Feedback**.
2. **During execution:** The agent follows the skill's normal instructions, but with the accumulated feedback in mind.
3. **After executing:** The agent asks the user for feedback, summarizes it, and appends it to `LEARNINGS.md`.
4. **Escalation:** If feedback is critical, the agent moves it to the **Active Feedback** section so it applies on every future run.

---

## Rollout Checklist

For every skill folder (`c-*`, `p-*`, `r-*`):

- [ ] Create `LEARNINGS.md` from the template below
- [ ] Add the self-learning banner at the top of `SKILL.md`
- [ ] Add the feedback loop section at the bottom of `SKILL.md`

---

## `LEARNINGS.md` Template

```markdown
# {Skill Name} Learnings

> This file is the self-learning loop for `{skill-name}`. Every time this skill runs, the agent reads this file first and applies all accumulated feedback. After execution, the agent asks the user for feedback and appends it here.

---

## Active Feedback (apply on every run)

*None yet — add feedback below and it becomes part of the skill's behavior.*

---

## Feedback Log

### {YYYY-MM-DD} — Initial template
- Skill created. No feedback yet.
```

---

## `SKILL.md` Additions

### Top banner (insert after the `# Title` line)

```markdown
> **Self-Learning Loop:** Before executing, read `LEARNINGS.md` in this skill folder. Apply every piece of active feedback listed there. After completing the task, ask the user: "How did this go? What should I do differently next time?" Append their feedback to `LEARNINGS.md` with today's date.
```

### Bottom section (insert at the end of the file)

```markdown
## Feedback Loop (run after every execution)

1. Ask the user: "How did this {skill-type} go? Any issues or changes I should make next time?"
2. Summarize the feedback into 1–3 bullet points.
3. Append to `LEARNINGS.md` in this skill folder with the date.
4. If the feedback is critical, add it to the **Active Feedback** section at the top of `LEARNINGS.md` so it applies on every future run.
```

---

## Why This Pattern Fits Paperclip

Skills are mounted into agent prompts at runtime via `desiredSkills`. The `LEARNINGS.md` lives in the same folder as `SKILL.md` and is referenced explicitly, so it travels with the skill when copied or symlinked into brand repos. Agents read it on demand, just like the existing `references/*.md` files in `c-ffmpeg`.

---

## Example: Feedback Escalation Flow

**Run 1:** Agent composites a video. Audio drifts.
- User feedback: "Audio drifted by 0.5s at the cut point."
- Agent appends to Feedback Log.

**Run 2:** Same issue happens again.
- User feedback: "Audio drifted AGAIN. Check segment alignment before concat."
- Agent moves this to **Active Feedback**: `- ALWAYS verify audio sync at segment boundaries before concat. If drift is detected, re-trim with output-level seeking.`

**Run 3 onwards:** The active feedback is injected at the start of every run. The drift stops.

