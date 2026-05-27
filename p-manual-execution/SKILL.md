---
name: p-manual-execution
description: Manual CFW execution recovery pipeline. Finds stuck CFW executions, creates the missing HeyGen video, optionally adds b-roll, then submits the video ID to resume the pipeline.
disable-model-invocation: true
argument-hint: "[execution-id?] [content-id?]"
allowed-tools: Bash, Read, Write
---

# pipeline-manual-execution — Recover Stuck CFW Executions


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

Unstick paused CFW pipelines by manually completing the HeyGen + b-roll step.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| execution_id | No | — | Specific execution to unstick |
| content_id | No | — | Content ID to find stuck execution |
| variant_id | No | — | Variant ID |
| add_broll | No | `false` | Also run b-roll embedding before submitting |

## Steps

### Step 1 — Find Stuck Executions

If no `execution_id`:
→ CFW API → list executions with status `waiting_for_input` or `paused`
→ Show: execution ID, content title, waiting since, what it's waiting for

### Step 2 — Get Script

→ CFW API → fetch content + variant
→ Extract TTS-clean script from variant

Verify script is TTS-clean (no markdown, stage directions, abbreviations).
If not clean: run `c-script` TTS preprocess first.

### Step 3 — Create HeyGen Video ⛔ CHECKPOINT

→ Skill: `t-heygen` → browser render (or MCP if available)
→ Background: `#00FF00`
→ Full script as one render

**Gate: User triggers HeyGen render and confirms job ID.**

Poll & download → save video ID from HeyGen response.

### Step 4 — Add B-Roll (if `add_broll: true`) ⛔ CHECKPOINT

→ Run `pipeline-broll-media` inline:
  - Match library clips to script
  - Log missing
  - Present coverage plan

**Gate: User approves b-roll placement.**

### Step 5 — Submit Video ID

→ CFW API → submit task input:
  - `video_id`: HeyGen video ID
  - `execution_id`: stuck execution ID

→ Confirm execution resumed (status changes from `waiting_for_input`)

### Step 6 — Report

- Execution: {id}
- Status before: `waiting_for_input`
- Status after: `in_progress` or `completed`
- HeyGen video: {video_id}
- B-roll embedded: Yes/No

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

