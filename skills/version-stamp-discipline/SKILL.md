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

## Run the check

```
bash hooks/scripts/version-stamp-check.sh <baseline>..HEAD
```

The script checks both halves of the rule for every commit in the range that touches
`agents/*.md` or `templates/*`: that commit must bump `version` in
`.claude-plugin/plugin.json` and add a `CHANGELOG.md` line naming the new version. It prints
`version-stamp-check: <verdict> touched: <yes|no|-> old: <ver|-> new: <ver|-> offenders: <list|->`.

- `ok touched: yes` - every touching commit bumped the version and added its CHANGELOG entry. Clears the whole P3 rule.
- `ok touched: no` - the range touches no `agents/*.md` or `templates/*`; P3 does not apply and nothing is owed.
- `violation` - a touching commit did not bump the version or did not add a CHANGELOG entry naming it; `offenders` lists `sha:path`, and `sha:CHANGELOG.md` for a missing CHANGELOG entry. Fix it in the same commit.
- `unknown` - unmeasurable (bad range, shallow clone, missing `python3`, unreadable `plugin.json`). Treat as unverified and say so; never read it as `ok`.

A reviewer applying this changes no verdict beyond what the existing P3 check already does.
