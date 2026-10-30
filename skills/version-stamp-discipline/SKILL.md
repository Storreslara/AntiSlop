---
name: version-stamp-discipline
description: >
  Apply before reporting ready-for-review or judging a range that contains a
  version-bumping commit. Runs the constitution P3 rule, which is per release:
  a bump must add its CHANGELOG entry in the same commit and never lower the
  version. Only relevant in repos that ship version-stamped files.
---

Constitution P3, per release: a release is a commit that changes `version` in
`.claude-plugin/plugin.json` (and `package.json`). That same commit must add a
`CHANGELOG.md` entry naming the new version, and the new version must not be
lower than its parent's. Content commits that touch `agents/*.md` or
`templates/*` need no bump of their own.

Applicability: only repos that ship version-stamped files. If the repo has no
`agents/*.md` or `templates/`, there is nothing to do.

## Run the check

```
bash hooks/scripts/version-stamp-check.sh <baseline>..HEAD
```

For every commit in the range that changes `version`, the script checks two
things: the commit adds a `CHANGELOG.md` line naming the new version, and the
new version is not lower than its parent's. It prints
`version-stamp-check: <verdict> touched: <yes|no|-> old: <ver|-> new: <ver|-> offenders: <list|->`;
`touched` is informational (does the range touch `agents/*.md` or `templates/*`).

- `ok` - every bumping commit in the range has its CHANGELOG line and no version decreased; a range with no bump is `ok` too. Clears the P3 rule.
- `violation` - a bumping commit lacks its CHANGELOG line (`offenders` lists `sha:CHANGELOG.md`) or lowers the version (`sha:.claude-plugin/plugin.json`). Fix it in that release commit.
- `unknown` - unmeasurable (bad range, shallow clone, missing `python3`, unreadable `plugin.json`). Treat as unverified and say so; never read it as `ok`.

A reviewer applying this changes no verdict beyond what the existing P3 check already does.
