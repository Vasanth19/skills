---
name: p-manual-execution
description: Manual CFW execution recovery pipeline. Finds stuck CFW executions, creates the missing HeyGen video, optionally adds b-roll, then submits the video ID to resume the pipeline.
disable-model-invocation: true
argument-hint: "[execution-id?] [content-id?]"
allowed-tools: Bash, Read, Write
---

# pipeline-manual-execution — Recover Stuck CFW Executions

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
If not clean: run `c-studio-script` TTS preprocess first.

### Step 3 — Create HeyGen Video ⛔ CHECKPOINT

→ Skill: `c-heygen` → browser render (or MCP if available)
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
