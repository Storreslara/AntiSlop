---
name: claudevoice-design-tokens
description: Where the sibling ClaudeVoice repo keeps its design system (Gruvbox Material Dark tokens, 4px spacing scale, monospace stack) — the upstream reference when AntiSlop UI work is asked to match it.
metadata:
  type: reference
---

The project owner maintains a sibling repo at `/home/sebas/ClaudeVoice` and has
asked for AntiSlop UI work to match its aesthetic. Its design system lives in
three files under `frontend/`, and **nowhere else** — verified 2026-08-11:

- `src/theme/gruvbox.ts` — the 13 pinned hexes (Gruvbox Material Dark, medium
  bg) and `applyTheme()`, which sets them on `<html>` as `--gvx-*` custom
  properties at runtime. Single source of truth for the colors.
- `src/index.css` (55 lines) — the static `:root` scale tokens
  (`--space-1/2/3/4/6` = 4/8/12/16/24px; `--radius-card/chip/pill` = 8/6/22px)
  and the `body` type rule.
- `src/App.css` (463 lines) — every component-chrome pattern (three-layer
  depth, pill/ghost buttons, dot chips, status dots, focus ring, motion gated
  behind `prefers-reduced-motion: no-preference`).

**The trap worth remembering:** the repo is React 19 + Vite + TypeScript, so it
*looks* like adopting its styling implies a build step. It does not. The
styling is plain hand-written CSS with zero framework — no Tailwind, no
component library — and the font stack is system-fallback monospace with **no
webfont download** (a deliberate decision recorded in `index.css`'s comments).
So the whole aesthetic ports into a single-file `index.html` with no tooling
change. Say that explicitly when scoping, or a reviewer will assume otherwise.

Also: it is **dark-only** (`color-scheme: dark`, no light branch, no toggle),
and its palette is AA-contrast-verified upstream by `src/theme/contrast.test.ts`
— so adopting the pinned hexes inherits that property and re-gating contrast
downstream would be a vacuous criterion.

`public/favicon.svg` is a purple `#863bff` branded mark — branding, always
excluded from a "match the aesthetic" scope.
