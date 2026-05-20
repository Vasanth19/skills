# r-cfw-publisher — environment

| Var | Required | Purpose |
|---|---|---|
| `V2_API_BASE` | yes | Base URL of CFW Social V2's REST API. e.g. `http://host.docker.internal:3000/api/v1` (from inside Docker on macOS), `http://localhost:3000/api/v1` (host laptop), `https://app.cfw.social/api/v1` (prod). |
| `ENCRYPTION_KEY` | yes | 64-char hex (32 bytes). MUST match the value used by openclaw-cfw and cfw-social — required to decrypt `accessTokenEnc` from `/publish-bundle`. |
| `SKILLS_HOME` | no | Path to skills root. Defaults to `~/.claude/skills`. The skill invokes `$SKILLS_HOME/r-social-post-postforme/...` etc. |

## Per-invocation args (passed to `run.sh`)

| Arg | Purpose |
|---|---|
| `--brand-id <id>`  | Brand identifier (only used for log lines — V2 derives the brand from the API key). |
| `--api-key <key>`  | The brand's V2 API key (plaintext). The cron driver decrypts the encrypted form from `telegram_bots.openclaw_api_key_enc` before calling. |

## Why no DB access

The skill never queries Postgres. Brand enumeration + per-brand API-key
decryption is the cron container's responsibility. Keeping the skill stateless
means it ports cleanly into a standalone daemon — that daemon can either
re-implement brand enumeration or take a config file listing brands explicitly.
