---
name: enabledplugins-format-uncertainty
description: RESOLVED 2026-08-11 — enabledPlugins really is an object-of-booleans on disk, matching antislop's shipped guard. Docs showing an array were wrong/stale.
metadata:
  type: project
---

## RESOLVED 2026-08-11 — object form confirmed, guard is correct

Measured directly: `~/.homedir/.claude/settings.json` (the real user-scope
file, with the plugin enabled) contains

    "enabledPlugins": {"antislop@antislop-marketplace": true}

— a Python `dict`, i.e. the **object-of-booleans** form. That is exactly what
`detectMarketplacePlugin` looks up (`bin/cli.js:1511-1513`, re-verified the
same day: `hasOwnProperty(MARKETPLACE_PLUGIN_KEY)`, then `val === true` /
`val === false`). The #66–71 guard is therefore **not** a no-op and needs no
rework; the feared larger rework is off the table.

The doc-vs-reality discrepancy below was real but resolves in favour of the
shipped code — treat `code.claude.com/docs/en/settings.md`'s array rendering
as wrong or stale for this key, not as a spec to migrate toward.

**How to apply now:** the object form is safe to build on. A temp-project
fixture that needs to simulate "marketplace plugin enabled" writes
`{"enabledPlugins": {"antislop@antislop-marketplace": true}}` into the
project's `.claude/settings.local.json` (highest-precedence scope).

The original open question is kept below for provenance.

---

The antislop standalone installer's `detectMarketplacePlugin` (bin/cli.js) and
the entire #66–70 marketplace hook-coexistence guard assume Claude Code writes
`enabledPlugins` as an OBJECT of booleans, e.g.
`{"antislop@antislop-marketplace": true}`.

Official Claude Code docs (code.claude.com/docs/en/settings.md), as of
2026-07-17, instead document `enabledPlugins` as an ARRAY of
`{marketplace, plugin}` entries / plugin-id strings — the boolean-object form
is not shown at all.

**Why:** surfaced while researching settings precedence for the #71 follow-up
spec (make the detector precedence-aware). The precedence ORDER is documented
and certain — Local (`.claude/settings.local.json`) > Project
(`.claude/settings.json`) > User (`~/.claude/settings.json`), objects
deep-merge with higher scope winning per-key, and `enabledPlugins` is not a
special-cased setting. The DATA FORMAT (object vs array) is the one thing docs
don't settle. The user's real-world "Ran 2 stop hooks" observation and the
shipped code both point to the object form being what's actually in play.

**How to apply:** if the whole guard ever appears not to fire in a real
project, suspect this format mismatch first. If the real format is confirmed to
be the array form, the object-shaped key lookup never matches → the guard is a
no-op and the entire #66–71 feature may not match real settings (a larger
rework than any single follow-up). Verify by inspecting a real
`~/.claude/settings.json` with the plugin enabled, or `/config`//`/doctor` in a
live session, before building further on the object-form assumption. See
[[detect-marketplace-plugin-precedence-spec]] (issue #71) for the recorded open
question and the safe-degradation argument (object-form fix is harmless if the
real form is the array).
