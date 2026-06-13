# Beat Schema — p-reels-split-2d

This document describes the full JSON schema for `beats.json` consumed by `render-overlay.mjs`.

---

## Top-level structure

`beats.json` is a flat JSON array of beat objects. Order does not matter (the renderer sorts by `start`).

---

## Common fields (all beat types)

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | YES | Unique identifier. Used in error messages. |
| `type` | string | YES | `hook`, `keyword`, `cta`, `emoji`, `logo`, `primitive` |
| `kind` | string | No | `broll` for b-roll windows (handled outside the Konva renderer). |
| `start` | number | YES | Start time in seconds (relative to reel start). |
| `end` | number | YES | End time in seconds. |
| `zone` | string | YES* | `top-left`, `top-center`, or `top-right`. *Or provide `cx`/`cy` directly. |
| `cx` | number | No | Override centroid x (takes priority over zone). |
| `cy` | number | No | Override centroid y (takes priority over zone). |
| `cyOffset` | number | No | Vertical offset from the zone centroid (e.g. `280` for CTA). |
| `inAnim` | string | No | Entrance animation. Default: `fade`. |
| `outAnim` | string | No | Exit animation. Default: `fade`. |
| `inDur` | number | No | Entrance duration override (seconds). |
| `outDur` | number | No | Exit duration override (seconds). |
| `idle` | string/false | No | Idle motion during hold phase: `bob`, `breathe`, `pulse`, or `false`. |
| `props` | object | No | Type-specific properties (see below). |

### Zone centroids (1080×960 canvas)

```
top-left:   cx=360, cy=360
top-center: cx=540, cy=540
top-right:  cx=720, cy=360
```

**Hard constraint: effective cy ≤ 900.** The renderer throws at load time if this is violated.

### Animation enum values

**inAnim:** `pop | slide-up | slide-down | slide-left | slide-right | drop | fade`
**outAnim:** `pop | snap-up | snap-down | slide-left | slide-right | fade`
**idle:** `bob | breathe | pulse | false`

---

## Type-specific `props`

### `hook` / `keyword` / `cta`

| Field | Type | Default | Description |
|---|---|---|---|
| `text` | string | `""` | Pill text. Max 4 words. CTA = exactly 2 words. |
| `fontSize` | number | 56 | Font size in px. Hook: 70-84. Keyword: 52-72. CTA: 56-72. |
| `fill` | string | palette[1] | Static base fill (shown under gradient). Set to `palette[1]` or `palette[2]`. |
| `textColor` | string | `"#FFFFFF"` | Text color. Use `#1F2937` for light palettes. |
| `palette` | string[6] | required | 6-stop hex array: `[deepShadow, bodyDeep, bodyMid, bodyLight, accentLight, accentBright]`. |

**Every pill must have its own `palette` array.** Never share palettes across pills in the same reel.

**Example palettes:**

```json
"orange":  ["#5B1F0E","#A04A2C","#D97757","#F2A684","#FCDDC9","#FFE8B8"]
"violet":  ["#2E1065","#5B21B6","#7C3AED","#A78BFA","#DDD6FE","#F5F3FF"]
"emerald": ["#064E3B","#065F46","#059669","#6EE7B7","#A7F3D0","#ECFDF5"]
"rose":    ["#4C0519","#9F1239","#E11D48","#FB7185","#FECDD3","#FFF1F2"]
"amber":   ["#451A03","#92400E","#D97706","#FCD34D","#FDE68A","#FFFBEB"]
"sky":     ["#082F49","#0C4A6E","#0284C7","#38BDF8","#BAE6FD","#F0F9FF"]
```

### `emoji`

| Field | Type | Default | Description |
|---|---|---|---|
| `text` | string | `"✨"` | A single Unicode emoji character (Apple/system color emoji). |
| `size` | number | 200 | Font size in px. Range: 150-280. |

**Note:** node-canvas renders system emoji — on Linux this is the system's emoji font (Noto Emoji, etc.). On macOS it's Apple Color Emoji. If the emoji does not render correctly on Linux, fall back to a `primitive` illustration.

### `logo`

| Field | Type | Default | Description |
|---|---|---|---|
| `src` | string | — | Absolute path or URL to a PNG logo (≥512px, icon-only, NOT a wordmark). |
| `label` | string | `""` | Brand name displayed next to the logo. |
| `logoSize` | number | 90 | Logo image height/width in px. |
| `fontSize` | number | 44 | Label font size. |
| `fill` | string | palette[1] | Pill base fill. |
| `textColor` | string | `"#FFFFFF"` | Label text color. |
| `palette` | string[6] | required | Same 6-stop palette as pill types. |

**Rules:** Logo PNG must be ≥512px, icon-only (no wordmark), native aspect ratio (no forced 512×512 square padding).

### `primitive`

| Field | Type | Default | Description |
|---|---|---|---|
| `draw` | string | — | Export name from `renderer/illustrations.mjs`. E.g. `"drawAgentGrid"`. |
| `scale` | number | 1 | Scale the whole illustration. |
| (any) | any | — | Additional props passed to the illustration function as `props`. |

---

## B-roll beats (`kind: "broll"`)

B-roll beats are planned by `c-broll-sync` but are NOT rendered by the Konva renderer. Instead, the pipeline builds b-roll clips via ffmpeg blurred-fill (same 3-chain filter as p-reels-split) and concatenates them at the correct timestamps into `top-all.mp4`.

When the beat list contains `kind: "broll"` entries, the pipeline must handle them separately before calling `render-overlay.mjs` for the Konva segments. A simpler approach: the Konva renderer renders the FULL duration with animated background; the b-roll clips are then overlaid on top (via ffmpeg `overlay` filter with time-gated `enable=`) after the Konva pass.

B-roll beat schema:

```json
{
  "id": "broll-0",
  "kind": "broll",
  "start": 12.0,
  "end": 16.5,
  "broll": {
    "clip": "broll-clip-0.mp4",
    "in": 0.5,
    "out": 5.0
  }
}
```

---

## Full example beats.json (short reel)

```json
[
  {
    "id": "hook",
    "type": "hook",
    "start": 0.1,
    "end": 4.2,
    "zone": "top-center",
    "inAnim": "fade",
    "outAnim": "fade",
    "inDur": 0.5,
    "outDur": 0.4,
    "idle": false,
    "props": {
      "text": "147 agents",
      "fontSize": 76,
      "fill": "#A04A2C",
      "textColor": "#FFFFFF",
      "palette": ["#5B1F0E","#A04A2C","#D97757","#F2A684","#FCDDC9","#FFE8B8"]
    }
  },
  {
    "id": "viz-agents",
    "type": "primitive",
    "start": 0.4,
    "end": 4.2,
    "zone": "top-right",
    "inAnim": "fade",
    "outAnim": "fade",
    "idle": false,
    "props": {
      "draw": "drawAgentGrid",
      "labels": ["Aria","Cody","Remy","Kyle","Quinn","Zoe"]
    }
  },
  {
    "id": "kw-parallel",
    "type": "keyword",
    "start": 5.0,
    "end": 9.5,
    "zone": "top-left",
    "inAnim": "pop",
    "outAnim": "snap-up",
    "idle": "breathe",
    "props": {
      "text": "in parallel",
      "fontSize": 56,
      "fill": "#5B21B6",
      "textColor": "#FFFFFF",
      "palette": ["#2E1065","#5B21B6","#7C3AED","#A78BFA","#DDD6FE","#F5F3FF"]
    }
  },
  {
    "id": "viz-parallel",
    "type": "primitive",
    "start": 5.3,
    "end": 9.5,
    "zone": "top-right",
    "inAnim": "slide-up",
    "outAnim": "fade",
    "idle": false,
    "props": {
      "draw": "drawParallelLanes",
      "lanes": ["Task A","Task B","Task C"],
      "result": "Done"
    }
  },
  {
    "id": "kw-speed",
    "type": "keyword",
    "start": 10.0,
    "end": 14.0,
    "zone": "top-center",
    "inAnim": "drop",
    "outAnim": "fade",
    "idle": "bob",
    "props": {
      "text": "10× faster",
      "fontSize": 60,
      "fill": "#065F46",
      "textColor": "#FFFFFF",
      "palette": ["#064E3B","#065F46","#059669","#6EE7B7","#A7F3D0","#ECFDF5"]
    }
  },
  {
    "id": "viz-stat",
    "type": "primitive",
    "start": 10.3,
    "end": 14.0,
    "zone": "top-left",
    "inAnim": "fade",
    "outAnim": "fade",
    "idle": false,
    "props": {
      "draw": "drawStatCard",
      "stat": "10×",
      "label": "throughput"
    }
  },
  {
    "id": "emoji-spark",
    "type": "emoji",
    "start": 15.0,
    "end": 18.0,
    "zone": "top-right",
    "inAnim": "pop",
    "outAnim": "fade",
    "idle": "pulse",
    "props": { "text": "⚡", "size": 200 }
  },
  {
    "id": "cta",
    "type": "cta",
    "start": 22.0,
    "end": 28.0,
    "zone": "top-center",
    "cyOffset": 280,
    "inAnim": "pop",
    "outAnim": "fade",
    "idle": "pulse",
    "props": {
      "text": "COMMENT below",
      "fontSize": 60,
      "fill": "#9F1239",
      "textColor": "#FFFFFF",
      "palette": ["#4C0519","#9F1239","#E11D48","#FB7185","#FECDD3","#FFF1F2"]
    }
  }
]
```
