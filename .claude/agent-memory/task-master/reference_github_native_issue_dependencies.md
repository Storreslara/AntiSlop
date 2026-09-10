---
name: reference-github-native-issue-dependencies
description: This repo's GitHub has the native issue-dependencies API live, so blocking edges can be REAL tracker links instead of prose - but gh api needs -F (typed int) not -f (string), and the payload is the blocker's database id, not its issue number.
metadata:
  type: reference
---

Discovered 2026-09-09 while slicing the fable-gate-audit-remediation plan
(#440-#454). `to-tickets` says to "use the platform's native blocking
relationship where it has one; otherwise set each ticket's Blocked by" — on
`Storreslara/AntiSlop` the native one **is** available, so prose-only
`Blocked by:` lines are the fallback, not the default.

**Probe for availability** (returns `[]` + rc=0 when live):
```
gh api repos/Storreslara/AntiSlop/issues/<n>/dependencies/blocked_by
```

**Create an edge** — three traps, all of which fail silently-ish:
```
bid=$(gh api repos/Storreslara/AntiSlop/issues/<blocker-num> -q .id)
gh api -X POST repos/Storreslara/AntiSlop/issues/<blocked-num>/dependencies/blocked_by -F issue_id="$bid"
```
1. **`-F`, never `-f`.** `-f` sends the id as a JSON string and the API rejects
   it: `422 Invalid property /issue_id: "5407946387" is not of type integer`.
   This is the one that bit me — a loop using `-f` reported 15/15 "FAILED".
2. **`issue_id` is the database id (`.id`, a 10-digit number), not the issue
   number.** Fetch it per blocker; there is no by-number form.
3. Redirect stdout — a successful POST dumps the **entire** issue object
   (repo block, body, everything). Check `.issue_dependencies_summary.blocked_by`
   on the blocked issue to confirm instead.

**Verify the graph independently after writing it** — do not trust your own
loop's echoes:
```
gh api repos/.../issues/<n>/dependencies/blocked_by -q '.[] | "#\(.number)"'
gh api repos/.../issues/<n>/dependencies/blocked_by -q 'length'
```

**How to apply:** when a spec hands me a hard ordering constraint and says
"encode it as an actual blocking edge, not narrative ordering", this API is
what satisfies that literally. Still write the prose `## Blocked by` section
too — it names blockers by title, which is what [[pathfinder rule 2]] wants a
reader to key off, and it survives if the dependency UI is ever unavailable.
A "must land last" unit gets one edge per sibling (14 here), not a single note.
