---
name: r-ig-comments
description: Fetch Instagram posts and comments via Composio, then AI-generate and post replies. Use when the user wants to review IG comments, respond to them, moderate them, or run a comment engagement session. Trigger on phrases like "respond to IG comments", "reply to Instagram comments", "manage Instagram comments", "fetch my IG posts".
---

# Instagram Comment Manager

Manages the full comment-reply loop for Instagram Business/Creator accounts via Composio.

## Auth Check First

Always verify the instagram toolkit is connected before any operation:

```bash
composio execute INSTAGRAM_GET_IG_USER_MEDIA --get-schema 2>&1 | grep -q "not connected" && composio link instagram || echo "connected"
```

If not connected, run `composio link instagram` and wait for the user to complete OAuth.

## Tool Slugs

| Action | Slug |
|---|---|
| List posts | `INSTAGRAM_GET_IG_USER_MEDIA` |
| Get post details | `INSTAGRAM_GET_IG_MEDIA` |
| Fetch comments | `INSTAGRAM_GET_IG_MEDIA_COMMENTS` |
| Fetch comment replies | `INSTAGRAM_GET_IG_COMMENT_REPLIES` |
| Reply to comment | `INSTAGRAM_POST_IG_COMMENT_REPLIES` |
| Post top-level comment | `INSTAGRAM_POST_IG_MEDIA_COMMENTS` |
| Delete comment | `INSTAGRAM_DELETE_COMMENT` |

## Step 1 — Fetch Recent Posts

```bash
composio execute INSTAGRAM_GET_IG_USER_MEDIA -d '{
  "ig_user_id": "me",
  "limit": 10,
  "fields": "id,caption,media_type,permalink,timestamp,comments_count,like_count"
}'
```

Pick the `id` of the post you want to manage comments on.

## Step 2 — Fetch Comments for a Post

```bash
composio execute INSTAGRAM_GET_IG_MEDIA_COMMENTS -d '{
  "ig_media_id": "<POST_ID>",
  "limit": 50,
  "fields": "id,text,username,timestamp,like_count,parent_id"
}'
```

## Step 3 — AI-Generate + Post Replies (composio run)

Use `composio run` to fetch comments, generate replies with an LLM, and post them in one shot:

```bash
composio run --logs-off '
  const POST_ID = "<POST_ID>";
  const BRAND_VOICE = "friendly, helpful, casual — match the commenter'\''s energy. Keep replies under 150 chars.";

  // Fetch unreplied comments
  const result = await execute("INSTAGRAM_GET_IG_MEDIA_COMMENTS", {
    ig_media_id: POST_ID,
    limit: 50,
    fields: "id,text,username,timestamp,like_count,parent_id,replies{id}"
  });

  const comments = result.data?.data ?? [];
  const unreplied = comments.filter(c => !c.parent_id && (!c.replies || c.replies.data?.length === 0));

  console.log(`Found ${unreplied.length} unreplied comments`);

  for (const comment of unreplied) {
    // Generate a contextual reply
    const generated = await experimental_subAgent(
      `You are a brand responding to an Instagram comment.\n\nBrand voice: ${BRAND_VOICE}\n\nComment from @${comment.username}: "${comment.text}"\n\nWrite ONE reply. No hashtags unless natural. Under 150 characters.`,
      { schema: z.object({ reply: z.string().max(300) }) }
    );

    const reply = generated.structuredOutput.reply;
    console.log(`@${comment.username}: "${comment.text}"\n→ "${reply}"\n`);

    // Post the reply
    await execute("INSTAGRAM_POST_IG_COMMENT_REPLIES", {
      ig_comment_id: comment.id,
      message: reply
    });
  }

  console.log("Done.");
'
```

## Step 4 — Review Mode (dry run, no posting)

To preview replies without posting, swap out the `execute("INSTAGRAM_POST_IG_COMMENT_REPLIES", ...)` call for a `console.log`:

```bash
composio run --logs-off '
  const POST_ID = "<POST_ID>";
  const BRAND_VOICE = "friendly, helpful, casual";

  const result = await execute("INSTAGRAM_GET_IG_MEDIA_COMMENTS", {
    ig_media_id: POST_ID,
    limit: 25,
    fields: "id,text,username,timestamp,parent_id,replies{id}"
  });

  const comments = (result.data?.data ?? []).filter(c => !c.parent_id);

  for (const comment of comments) {
    const generated = await experimental_subAgent(
      `Brand voice: ${BRAND_VOICE}\n\nComment from @${comment.username}: "${comment.text}"\n\nWrite ONE reply under 150 characters.`,
      { schema: z.object({ reply: z.string().max(300) }) }
    );
    console.log(JSON.stringify({
      comment_id: comment.id,
      from: comment.username,
      text: comment.text,
      proposed_reply: generated.structuredOutput.reply
    }));
  }
'
```

## Step 5 — Reply to a Specific Comment

```bash
composio execute INSTAGRAM_POST_IG_COMMENT_REPLIES -d '{
  "ig_comment_id": "<COMMENT_ID>",
  "message": "Your reply here (max 300 chars)"
}'
```

## Pitfalls

- `INSTAGRAM_GET_IG_USER_MEDIA` requires `ig_user_id: "me"` or the numeric Business Account ID — not a username
- Comments from personal accounts are not accessible; only Business/Creator accounts work
- Replies have a 300-character limit; generated replies should stay under 150 to be safe
- `OAuthException code=2` is transient — retry once with backoff before escalating
- Do not post the same reply twice — check `replies{id}` before responding
- `comments_count` on a post includes replies; filter by `!parent_id` to get top-level comments only

## Pagination

If a post has many comments, page through with the cursor:

```bash
composio run '
  const POST_ID = "<POST_ID>";
  let after = undefined;
  let allComments = [];

  do {
    const res = await execute("INSTAGRAM_GET_IG_MEDIA_COMMENTS", {
      ig_media_id: POST_ID,
      limit: 100,
      fields: "id,text,username,timestamp,parent_id",
      ...(after ? { after } : {})
    });
    allComments = allComments.concat(res.data?.data ?? []);
    after = res.data?.paging?.cursors?.after;
  } while (after);

  console.log(`Total comments: ${allComments.length}`);
'
```
