---
name: c-find-skill
description: Discover and install Claude Code skills. Use when the user asks "find a skill for X", "is there a skill that does X", "add a skill for X", or wants to extend the agent with capabilities that may already exist. Checks /Users/vasanth/Code/skills/ first, then searches the ecosystem. Always installs to /Code/skills/ and symlinks — never downloads directly into .claude/skills/.
---

# c-find-skill

Discover, install, and symlink Claude Code skills into the right place.

## Prefix taxonomy — assign before installing

Every skill gets a prefix based on what it does:

| Prefix | Type | When |
|--------|------|------|
| `c-` | Custom tool | Composable building block, auto-invoked by Claude |
| `p-` | Pipeline | End-to-end deliverable (input → output) |
| `r-` | Role workflow | Action sequence tied to a specific agent role |
| `f-` | Framework | Tech/library reference knowledge |
| `b-` | Brand | Locked to one brand, not portable |
| `t-` | Third-party platform | External API wrapper (auth/cost/rate-limits) |
| `x-` | Experimental | WIP or unstable |

Pick the prefix before naming the skill. The full slug is `<prefix>-<name>` (e.g. `c-ffmpeg`, `t-heygen`, `f-gsap`).

## Install location — read this carefully

**Never download a skill directly into `.claude/skills/`.** Always:
1. Install to `/Users/vasanth/Code/skills/<prefix>-<name>/`
2. Symlink from there to the target location

This keeps `/Code/skills/` as the canonical source of truth. Symlinks are cheap to add and remove.

**Target locations:**
- **Global** (`~/.claude/skills/<prefix>-<name>`) — cross-cutting skills used in any project
- **Project-local** (`/path/to/project/.claude/skills/<prefix>-<name>`) — project-specific skills

Default to project-local unless the skill is genuinely cross-cutting.

## Process

### Step 1 — Check /Code/skills/ first

```bash
ls /Users/vasanth/Code/skills/ | grep -i "<keyword>"
```

If the skill already exists with the right prefix: skip to Step 4 (just symlink it).

### Step 2 — Search the ecosystem

- **Catalog**: https://skills.sh — browsable leaderboard
- **Vasanth's skills repo**: https://github.com/Vasanth19/skills
- **Anthropic**: https://github.com/anthropics/skills
- **Vercel Labs**: https://github.com/vercel-labs/agent-skills

Use `WebSearch` and `WebFetch` with precise terms ("react testing skill" beats "testing").

Shortlist 2–3 candidates. Present each with: name, one-line description, source URL, why it fits. Don't install the first hit.

### Step 3 — Install to /Code/skills/

Determine the right prefix for the skill, then install:

**Shape A — single SKILL.md file:**
```bash
mkdir -p /Users/vasanth/Code/skills/<prefix>-<name>
curl -fsSL <raw-url>/SKILL.md -o /Users/vasanth/Code/skills/<prefix>-<name>/SKILL.md
# Update the name: field in SKILL.md frontmatter to match the new prefix-slug
```

**Shape B — directory with supporting files:**
```bash
mkdir -p /Users/vasanth/Code/skills/<prefix>-<name>
# Fetch the tarball and extract only the skill path:
curl -fsSL https://github.com/<owner>/<repo>/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=N -C /Users/vasanth/Code/skills/<prefix>-<name> <repo>-main/<skill-path>
# Update the name: field in SKILL.md frontmatter to match <prefix>-<name>
```

After installing, update the `name:` field in `SKILL.md` frontmatter to match the new `<prefix>-<name>` slug.

### Step 4 — Symlink to target

**Global:**
```bash
ln -s /Users/vasanth/Code/skills/<prefix>-<name> ~/.claude/skills/<prefix>-<name>
```

**Project-local:**
```bash
mkdir -p /path/to/project/.claude/skills
ln -s /Users/vasanth/Code/skills/<prefix>-<name> /path/to/project/.claude/skills/<prefix>-<name>
```

### Step 5 — Verify

```bash
ls -la ~/.claude/skills/<prefix>-<name>   # or project path
head -5 /Users/vasanth/Code/skills/<prefix>-<name>/SKILL.md
```

Tell the user to start a new Claude Code session so the loader picks up the new skill.

## If nothing fits

- Say so honestly — don't fabricate a match.
- Offer to scaffold a new skill at `/Users/vasanth/Code/skills/<prefix>-<name>/SKILL.md`. A minimal skill is just frontmatter + instructions:

```markdown
---
name: <prefix>-<name>
description: One-line description of when this skill activates
---

Instructions Claude should follow when invoked…
```

## After adding to /Code/skills/

Consider registering the skill in Paperclip so agents can use it too:
```bash
curl -X POST "http://localhost:3100/api/companies/<company-id>/skills/import" \
  -H "Content-Type: application/json" \
  -d '{"source":"/Users/vasanth/Code/skills/<prefix>-<name>"}'
```
