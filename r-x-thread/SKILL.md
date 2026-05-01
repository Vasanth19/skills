---
name: r-x-thread
description: >
  Post a multi-tweet thread to X (Twitter) via X API v2, chaining each tweet
  as a reply to the previous one — exactly as n8n does via inReplyToStatusId.
  Use for all MGG X thread publishing. PostForMe cannot chain threads (no
  in_reply_to_tweet_id field); this skill fills that gap.
---

# X Thread — Native X API v2 Thread Poster

## What This Is

Posts a series of tweets as a proper connected thread by:
1. Posting tweet 1 as a top-level tweet → captures the returned `id`
2. Posting tweet 2 as a reply to tweet 1's `id` → captures its `id`
3. Continuing the chain until all tweets are posted

This is the same mechanism as the MGG n8n workflow (`inReplyToStatusId` on
the `Create Tweet7` node). The difference: this skill runs in bash without
n8n, making it directly callable by CMO agents.

## Auth

Requires four X Developer credentials stored in `posting-tools/.gsai/secret`:

```bash
export X_API_KEY="..."            # API Key (consumer key)
export X_API_SECRET="..."         # API Secret (consumer secret)
export X_ACCESS_TOKEN="..."       # Access Token for @MrGrowthGuide
export X_ACCESS_TOKEN_SECRET="..."# Access Token Secret for @MrGrowthGuide
```

These come from the X Developer Portal app registered for @MrGrowthGuide.
**Do not confuse with POSTFORME_API_KEY** — this calls X API directly.

## Scripts

| Script | Usage |
|---|---|
| `post-thread.sh` | Post a thread from inline args or a JSON/text file |

## Usage

```bash
# Inline tweets (positional args — one per tweet)
./post-thread.sh "Tweet 1 text" "Tweet 2 text" "Tweet 3 text"

# From a JSON array file (path to a .json file with an array of strings)
./post-thread.sh --file /path/to/tweets.json

# From a plain text file (one tweet per line)
./post-thread.sh --file /path/to/tweets.txt

# Dry run — prints what would be sent, no API calls
./post-thread.sh --dry-run "Tweet 1" "Tweet 2"

# Delay between tweets (default: 2s; increase if rate-limited)
TWEET_DELAY=3 ./post-thread.sh "Tweet 1" "Tweet 2"
```

## Output

JSON array of X API v2 tweet responses, one object per tweet:
```json
[
  {"data": {"id": "1234567890", "text": "Tweet 1 text"}},
  {"data": {"id": "1234567891", "text": "Tweet 2 text"}}
]
```

The first `id` is the thread root — this is what you link to when referencing the thread.

## CMO Workflow for X Threads

When publishing an X thread for MGG:

1. **Prepare tweet array** — read from the ord's `final/publishes/x.md`. Extract tweets in order (tweet 1 through N).
2. **Run the script**:
   ```bash
   SKILL_DIR="/Users/vasanth/MarketingMr/posting-tools/skills/r-x-thread/docs/scripts"
   "$SKILL_DIR/post-thread.sh" "Tweet 1" "Tweet 2" "Tweet 3"
   ```
3. **Capture the root tweet id** — `results[0].data.id` — and record it in the ord's `final/publishes/x.md` as `thread_root_id`.
4. **Verify on @MrGrowthGuide** — confirm the thread chain is visible before marking done.

## Error Handling

- If a tweet in the chain fails, the script exits immediately with a non-zero code and prints the error response.
- Tweets already posted in the chain are NOT rolled back — note the `thread_root_id` from the partial output and handle manually.
- Rate limit errors (HTTP 429): increase `TWEET_DELAY` and retry from the failed tweet onward using `--reply-to-id`.

## Brand Config

Declared in: `mr-growth-guide/.config/r-x-thread.yaml`
X account: `@MrGrowthGuide` (platformUserId: `850396380787093505`)
