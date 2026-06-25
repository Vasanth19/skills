---
name: f-hyperframes-cli
description: HyperFrames CLI tool — hyperframes init, lint, preview, render, transcribe, tts, doctor, browser, info, upgrade, compositions, docs, benchmark. Use when scaffolding a project, linting or validating compositions, previewing in the studio, rendering to video, transcribing audio, generating TTS, or troubleshooting the HyperFrames environment.
kind: framework
visibility: internal
dependsOn: [f-hyperframes]
requires: node, ffmpeg
---

# HyperFrames CLI

Everything runs through `npx hyperframes`. Requires Node.js >= 22 and FFmpeg.

## Workflow

1. **Scaffold** — `npx hyperframes@0.7.5 init my-video`
2. **Write** — author HTML composition (see the `f-hyperframes` skill)
3. **Lint** — `npx hyperframes@0.7.5 lint`
4. **Preview** — `npx hyperframes@0.7.5 preview`
5. **Render** — `npx hyperframes@0.7.5 render`

Lint before preview — catches missing `data-composition-id`, overlapping tracks, unregistered timelines.

## Scaffolding

```bash
npx hyperframes@0.7.5 init my-video                        # interactive wizard
npx hyperframes@0.7.5 init my-video --example warm-grain   # pick an example
npx hyperframes@0.7.5 init my-video --video clip.mp4        # with video file
npx hyperframes@0.7.5 init my-video --audio track.mp3       # with audio file
npx hyperframes@0.7.5 init my-video --non-interactive       # skip prompts (CI/agents)
```

Templates: `blank`, `warm-grain`, `play-mode`, `swiss-grid`, `vignelli`, `decision-tree`, `kinetic-type`, `product-promo`, `nyt-graph`.

`init` creates the right file structure, copies media, transcribes audio with Whisper, and installs AI coding skills. Use it instead of creating files by hand.

## Linting

```bash
npx hyperframes@0.7.5 lint                  # current directory
npx hyperframes@0.7.5 lint ./my-project     # specific project
npx hyperframes@0.7.5 lint --verbose        # info-level findings
npx hyperframes@0.7.5 lint --json           # machine-readable
```

Lints `index.html` and all files in `compositions/`. Reports errors (must fix), warnings (should fix), and info (with `--verbose`).

## Previewing

```bash
npx hyperframes@0.7.5 preview                   # serve current directory
npx hyperframes@0.7.5 preview --port 4567       # custom port (default 3002)
```

Hot-reloads on file changes. Opens the studio in your browser automatically.

## Rendering

```bash
npx hyperframes@0.7.5 render                                # standard MP4
npx hyperframes@0.7.5 render --output final.mp4             # named output
npx hyperframes@0.7.5 render --quality draft                # fast iteration
npx hyperframes@0.7.5 render --fps 60 --quality high        # final delivery
npx hyperframes@0.7.5 render --format webm                  # transparent WebM
npx hyperframes@0.7.5 render --docker                       # byte-identical
```

| Flag           | Options               | Default                    | Notes                       |
| -------------- | --------------------- | -------------------------- | --------------------------- |
| `--output`     | path                  | renders/name_timestamp.mp4 | Output path                 |
| `--fps`        | 24, 30, 60            | 30                         | 60fps doubles render time   |
| `--quality`    | draft, standard, high | standard                   | draft for iterating         |
| `--format`     | mp4, webm             | mp4                        | WebM supports transparency  |
| `--workers`    | 1-8 or auto           | auto                       | Each spawns Chrome          |
| `--docker`     | flag                  | off                        | Reproducible output         |
| `--gpu`        | flag                  | off                        | GPU-accelerated encoding    |
| `--strict`     | flag                  | off                        | Fail on lint errors         |
| `--strict-all` | flag                  | off                        | Fail on errors AND warnings |

**Quality guidance:** `draft` while iterating, `standard` for review, `high` for final delivery.

## Transcription

```bash
npx hyperframes@0.7.5 transcribe audio.mp3
npx hyperframes@0.7.5 transcribe video.mp4 --model medium.en --language en
npx hyperframes@0.7.5 transcribe subtitles.srt   # import existing
npx hyperframes@0.7.5 transcribe subtitles.vtt
npx hyperframes@0.7.5 transcribe openai-response.json
```

## Text-to-Speech

```bash
npx hyperframes@0.7.5 tts "Text here" --voice af_nova --output narration.wav
npx hyperframes@0.7.5 tts script.txt --voice bf_emma
npx hyperframes@0.7.5 tts --list  # show all voices
```

## Troubleshooting

```bash
npx hyperframes@0.7.5 doctor       # check environment (Chrome, FFmpeg, Node, memory)
npx hyperframes@0.7.5 browser      # manage bundled Chrome
npx hyperframes@0.7.5 info         # version and environment details
npx hyperframes upgrade      # check for updates
```

Run `doctor` first if rendering fails. Common issues: missing FFmpeg, missing Chrome, low memory.

## Other

```bash
npx hyperframes@0.7.5 compositions   # list compositions in project
npx hyperframes@0.7.5 docs           # open documentation
npx hyperframes@0.7.5 benchmark .    # benchmark render performance
```
