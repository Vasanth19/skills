# HeyGen API Audio-Source Avatar Workflow

Use this reference when implementing the automated avatar portion of `demo-with-avatar-via-hgapi`.

## Secrets

Load secrets from the configured local secrets file, usually:

`/Users/vasanth/.gsai/secrets.env`

Common names to check without printing values:

- `HEYGEN_API_KEY`
- `HGAPI_API_KEY`
- `FLOE_API_KEY` when polling through the Floe helper

Fail fast if the required key is missing.

## Stitched Audio Contract

Create:

- `audio/avatar-clip-01-<slug>.mp3`
- `audio/avatar-clip-02-<slug>.mp3`
- `audio/avatar-clip-03-<slug>.mp3`
- `audio/avatar-clips-stitched-0p5s.mp3`
- `script/avatar-clips-split-map.md`

The split map must include:

| clip | start | end | duration | silence_after | text |
|---|---:|---:|---:|---:|---|

Use the actual measured audio durations, not estimates from word count.

## API Submit Pattern

Prefer audio-source voice input. The exact HeyGen payload can vary by API version, so inspect current API docs or existing local scripts if the request fails. Keep the production request payload in `avatar/heygen-request.json`.

Required intent:

- character/avatar selected by configured avatar ID
- voice driven by uploaded/provided audio URL or audio asset ID
- green background `#00FF00`
- 16:9 dimensions for long-form avatar sources unless the project requires vertical

Auth header:

`X-Api-Key: $HEYGEN_API_KEY`

Do not use Bearer auth for the REST API unless HeyGen's current docs explicitly require it.

## Poll And Download

Save:

- `avatar/heygen-submit-response.json`
- `avatar/heygen-poll-log.jsonl`
- `avatar/combined-avatar-raw.mp4`

Poll at 45-60 second intervals. Stop and report the exact API status/error if the render fails.

If using the Floe helper, the previous known pattern was:

```bash
curl -s -X POST "https://floe-production.up.railway.app/api/v1/id-to-heygen-url" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $FLOE_API_KEY" \
  -d "{\"execution_id\":\"poll-$(date +%s)\",\"input_fields\":{\"video_id\":\"$VIDEO_ID\"}}"
```

Treat `status: "success"` as the downloadable state for the Floe helper.

## Split Combined Render

Split the combined HeyGen video back into clips with the split map.

Recommended output:

- `avatar/avatar-clip-01-hook.mp4`
- `avatar/avatar-clip-02-problem.mp4`
- `avatar/avatar-clip-03-workflow.mp4`
- `avatar/avatar-clip-04-cta.mp4`

Use stream-safe cuts only when accuracy is acceptable. For precise sync, re-encode the split clips at the project frame rate.

## Green Screen

If the avatar render uses green screen, remove it only during composition or when creating pre-keyed intermediate assets.

Known FFmpeg standard:

```text
colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01
```

Use `colorkey`, not `chromakey`, unless the local FFmpeg build supports and has verified `chromakey`.

## QA

Before final assembly:

- Verify combined avatar video has audio and expected duration.
- Verify each split starts and ends on the right spoken line.
- Pull stills from each split and inspect framing.
- Confirm no green spill or hard edge is visible if keyed.
- Log HeyGen video ID, avatar ID, audio source path, and final split paths in `DELIVERY.md`.

