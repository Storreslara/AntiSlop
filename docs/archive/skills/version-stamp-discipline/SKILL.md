---
name: version-stamp-discipline
description: >
  Apply before reporting ready-for-review or judging a range that touches
  agents/*.md or templates/*. Runs both halves of the constitution P3 rule:
  the plugin version bump and the CHANGELOG entry, per commit. Only relevant
  in repos that ship version-stamped files.
---

Constitution P3: every commit that touches `agents/*.md` or anything under
`templates/` must, in that same commit, bump `version` in
`.claude-plugin/plugin.json` (and `package.json`) and add a `CHANGELOG.md`
entry containing the new version. The rule is per commit, so a later bump
cannot excuse an earlier commit in the range.

Applicability: only repos that ship version-stamped files. If the repo has no
`agents/*.md` or `templates/`, there is nothing to do.

## Half 1: version bump

```
bash hooks/scripts/version-stamp-check.sh <baseline>..HEAD
```

Prints `version-stamp-check: <verdict> touched: <yes|no|-> old: <ver|-> new: <ver|-> offenders: <list|->`.

- `ok touched: yes` - every touching commit bumped the version. Clears this half only.
- `ok touched: no` - the range touches no `agents/*.md` or `templates/*`; P3 does not apply and nothing is owed.
- `violation` - a touching commit did not bump the version; `offenders` lists `sha:path`. Fix it in the same commit.
- `unknown` - unmeasurable (bad range, missing `python3`, unreadable `plugin.json`). Treat as unverified and say so; never read it as `ok`.

## Half 2: CHANGELOG entry

The script does not check this. For each touching commit `<sha>`, run:

```
git show <sha> -- CHANGELOG.md | grep -q "^+.*$(jq -r .version .claude-plugin/plugin.json)"
```

Exit 0 means the commit added a CHANGELOG line naming the current version;
non-zero means the entry is missing (or a commit without a CHANGELOG hunk).
For the final commit of a unit, `<sha>` is `HEAD`; for a bump made earlier in
the range, substitute that version for the `jq` expression.

Both halves must pass. A reviewer applying this changes no verdict beyond what
the existing P3 check already does.
