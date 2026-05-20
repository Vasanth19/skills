# Goldfish Rescue — Storyline V2 (Tiny Tales Reproduction)

## Character: Lovey-Boo

### Locked Character Description (COPY INTO EVERY PROMPT)

```
Lovey-Boo is a small photorealistic 3D plush toy creature, about 8 inches tall.
Round head slightly wider than tall. Brown messy fluffy wild fur.
Two tall pointed bunny ears — cream/beige inside, dark brown triangular patches on inner ear.
LARGE round glossy black eyes, very expressive.
Small round dark button nose.
X-shaped cross stitch on BOTH cheeks (left and right).
Zigzag jagged stitched mouth line like sewn teeth.
Dark red knitted scarf around neck.
Short stubby arms and legs, round plump body.
Light cream/beige colored face area contrasts with brown fur.
Rendered as photorealistic 3D, like a real handmade plush toy photographed in real environments.
```

### Character Reference Strategy
1. Generate ONE hero reference image (front-facing, clear, neutral pose)
2. Use that reference image in ALL subsequent scene generations via `gemini-character.py`
3. Gemini's multi-ref system preserves face identity across poses

---

## Story Arc: "Lovey-Boo just wanted to save a little goldfish"

### Scene Breakdown (5 scenes, ~14s total)

| Scene | Time | Shot | What Happens | Emotion | Camera |
|-------|------|------|-------------|---------|--------|
| 1 | 0:00–0:03 | Medium wide | Lovey-Boo runs down rainy alley carrying glass fishbowl with goldfish. Red scarf flutters. Wet cobblestones, warm street lamps. | Urgency, determination | Low angle tracking forward |
| 2 | 0:03–0:06 | Low angle close | Fishbowl shattered on wet ground. Glass shards everywhere. Goldfish flopping in puddle. Lovey-Boo on the ground reaching desperately toward goldfish. Tears in eyes. | Panic, despair | Push in toward goldfish |
| 3 | 0:06–0:09 | Medium close | Lovey-Boo sits on wet ground, gently cradling goldfish in both paws, carefully placing it back into a cracked fishbowl filled with water. Gentle caring expression. | Compassion, tenderness | Slight tilt up |
| 4 | 0:09–0:12 | Wide | City waterfront at night. Lovey-Boo tips the fishbowl, releasing goldfish into the harbor water. Goldfish splashes into the sea. City lights reflect on water. Rain has stopped. | Bittersweet joy, letting go | Pull back reveal |
| 5 | 0:12–0:14 | Medium | Lovey-Boo standing at waterfront, big happy smile, holding a brown cardboard sign with a thumbs-up emoji and "Subscribe" written on it. City skyline behind. Night. | Joy, connection, CTA | Static, centered |

### Audio
- `goldfish-audio.mp3` (14.27s) — emotional whimsical music, no dialogue
- Sync: music swells at scene 3 (rescue), resolves at scene 4 (release)

---

## Generation Plan

### Step 1: Character Reference (gemini-character.py)
Generate front-facing hero shot of Lovey-Boo. No scene context, just character on simple background.

### Step 2: Scene Images (gemini-character.py with reference)
For each of 5 scenes, generate with:
- `--model pro` (best quality)
- `--ar 9:16` (portrait)
- Reference image from Step 1
- Full scene prompt with LOCKED character description

### Step 3: Animate (FloeAPI Hailuo i2v)
Each scene image → 5s video clip via `prompt-to-video`

### Step 4: Assemble
Trim each to ~2.8s, concat, overlay goldfish-audio.mp3, scale to 1080x1920

---

## Key Differences from V1

| V1 (Failed) | V2 (This) |
|-------------|-----------|
| GPT Image — no ref system, face drifted | Gemini Pro with character reference lock |
| 4 scenes, no subscribe CTA | 5 scenes including Subscribe card ending |
| Generic "cute creature" prompt | Locked character description in every prompt |
| No library RAG enrichment | SPEC framework for prompts |
| FloeAPI image gen (no refs) | gemini-character.py (multi-ref consistency) |
