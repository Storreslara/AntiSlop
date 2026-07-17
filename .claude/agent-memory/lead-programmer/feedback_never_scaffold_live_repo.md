---
name: feedback_never_scaffold_live_repo
description: Never run bin/cli.js scaffold commands (--target=cursor/codex, or plain claude-target) against this repo's own root when verifying byte-for-byte output — always target a throwaway tmp cwd
metadata:
  type: feedback
---

When verifying cli.js scaffold behavior (e.g. diffing hooks.json output
pre/post a code change), every invocation of `node bin/cli.js ...` must run
inside a subshell explicitly `cd`'d into a tmp directory —
`(cd "$TMPDIR" && node /abs/path/to/bin/cli.js --target=...)` — never a bare
`node bin/cli.js ...` after only a top-level `cd` to the repo root. A bare
top-level `cd /home/sebas/seb_claude_setup` followed later by an un-subshelled
`node bin/cli.js --target=cursor` runs the scaffold against the LIVE
dogfooding repo (this repo's own `.claude/`-driven persona setup), creating a
real `.cursor/` tree and appending to the real `.gitignore` — caught only by
a post-hoc `git status` diff, not prevented.

**Why:** this repo dogfoods the antislop plugin on itself (`.claude/agents/*`,
`.claude/settings.json`, `CLAUDE.md` all live and load-bearing for the
persona system running the session itself). An accidental scaffold write
here isn't a harmless tmp-dir mistake — it pollutes the actual working tree
the current and future sessions depend on, and only `.cursor/`-prefixed
writes + a `.gitignore` diff are the tell (`scaffoldCursor`/`scaffoldCodex`
never touch `.claude/*`, `CLAUDE.md`, or create `.claude/hooks/`, so those
stay clean even when this mistake happens — don't mistake that partial
cleanliness for "nothing happened").

**How to apply:** before writing any Bash block that calls `node bin/cli.js`
for verification/testing purposes (not the project's own test files, which
already spawnSync into `os.tmpdir()`-created dirs correctly), write every
invocation as `(cd "$TMP" && node "$REPO_ROOT/bin/cli.js" ...)` with the `cd`
INSIDE the same parenthesized subshell as the invocation, never relying on an
earlier `cd` in the same script to have "stuck" to a non-repo-root directory.
After any such verification pass, always `git status --short` before ending
the turn to confirm no `.cursor/`, `.codex/`, or `.gitignore`/`CLAUDE.md`
diff leaked into the real tree, even if the intent was tmp-dir-only.
