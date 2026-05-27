# Beat-Planner — Stage 3 (GLM-5.1)

Turns the raw transcript of the uploaded video into a JSON **beat plan**: an ordered array of b-roll scenes that the Remotion subproject (Stage 4) renders as the topic-matched background.

- **Model:** `glm-5.1`
- **Endpoint:** `POST https://ollama.com/v1/chat/completions`
- **Auth:** `Authorization: Bearer <LLM_API_KEY>` (read from `cfw-agent/.env` → `LLM_API_KEY`)
- **Body:** `{ model:"glm-5.1", think:false, max_tokens:4000, messages:[{role:"user", content:<prompt below + transcript>}] }`

## Calling notes (learned during the build — read these)

- **GLM-5.1 emits a long `reasoning` field even with `think:false`.** The parseable answer is in `choices[0].message.content`, NOT `reasoning`. Always read `content`.
- **Give it enough tokens.** With `max_tokens:1500` the reasoning consumed the whole budget and `content` came back EMPTY (`finish_reason:"stop"` but nothing usable). Use `max_tokens:4000`. The visible JSON answer is only ~700 chars; the headroom is for the hidden reasoning pass.
- **Prefix the prompt with `/nothink`** and an explicit "do not think, do not explain, first char `{`, last char `}`" instruction — this is what got a clean JSON `content` out of it.
- **The `reasoning` field can contain unescaped control characters** — do not pipe the raw response through `jq` twice naively; extract `content` first (Python `json.load` handles it fine).
- **Strip ```json fences** before parsing `content` (GLM didn't add them in our test, but be defensive).

## The prompt (exact text used)

```
/nothink You are a beat-planner. Convert a transcript into a b-roll BEAT PLAN. Respond with STRICT JSON ONLY. Do not think. Do not explain. The first character must be { and the last must be }.

Shape: {"scenes":[{"text":string,"keywords":[string],"durationInFrames":int}]}
Rules:
- 30fps. Each durationInFrames is an integer between 60 and 120.
- Sum of all durationInFrames must be within ~120 of (totalDurationSeconds*30).
- text = short on-screen phrase (<=6 words) from that part of the transcript, punchy.
- keywords = 2-4 concrete visual nouns for b-roll (e.g. laptop, clock, sleeping).
- Cover the whole transcript in order.

totalDurationSeconds: <DURATION_SECONDS>
transcript: "<RAW_TRANSCRIPT>"
```

Substitute `<DURATION_SECONDS>` with the uploaded video's duration (from Stage 1 `ffprobe`) and `<RAW_TRANSCRIPT>` with the Stage 2 transcript.

## Output schema

```json
{
  "scenes": [
    { "text": "string (<=6 words, on-screen phrase)",
      "keywords": ["concrete", "visual", "noun"],
      "durationInFrames": 90 }
  ]
}
```

- `30fps`. Each `durationInFrames` ∈ [60, 120] (2–4s).
- `Σ durationInFrames ≈ totalDurationSeconds * 30` (within one scene-length).
- Scenes are in narrative order; earlier transcript → earlier scenes.

## Validation (run before passing to Remotion)

1. `content` parses as JSON after stripping any ```json fences.
2. `scenes` is a non-empty array.
3. Every `durationInFrames` is an integer in [60, 120].
4. `Σ durationInFrames` is within 120 frames of `totalDurationSeconds * 30`.
5. Every scene has `text` (non-empty) and 2–4 `keywords`.

On failure: re-call ONCE with the directive hardened ("output ONLY the JSON object, nothing else"). If it still fails, fail fast with the raw `content` in the error — do not ship an unvalidated plan.

## Verified test run (2026-05-24, real GLM-5.1)

Sample transcript:
> "I used to lose six hours every week to copy-paste work. Then I built one automation in an afternoon and now my leads get researched while I sleep. Here's exactly how I did it."

`totalDurationSeconds: 14` → target 420 frames.

GLM-5.1 returned (parsed clean, no fences):

```json
{
  "scenes": [
    { "text": "Lost six hours to copy-paste",   "keywords": ["clock", "spreadsheet", "keyboard"], "durationInFrames": 120 },
    { "text": "Built one automation this afternoon", "keywords": ["laptop", "gears", "code"],      "durationInFrames": 120 },
    { "text": "Leads researched while I sleep",   "keywords": ["bed", "pillow", "phone"],          "durationInFrames": 120 },
    { "text": "Exactly how I did it",             "keywords": ["monitor", "finger", "cursor"],      "durationInFrames": 60 }
  ]
}
```

Validation result: **PASS** — JSON parses; 4 scenes; every duration in [60,120]; Σ = 120+120+120+60 = **420 frames = exactly 14.0s @ 30fps**; each scene has 3 keywords; scenes follow the transcript's narrative order (problem → build → payoff → CTA).
