# ADR 0019: Microworld dashboard supersedes the fixture-only narrowing

Date: 2026-08-11
Status: Accepted (plan 2026-08-10-microworld-dashboard, Step D10; issue #323)

## Context

The 2026-07-28 plan deliberately narrowed "microworld" to a fixture bundle whose entire contract is `run.sh`'s exit code — a Papert-microworlds name applied to a much narrower thing. The user overrode that narrowing on 2026-08-10, restoring the primary sense to an interactive, human-explored dashboard while keeping the machine-checkable layer intact underneath as "the check". The re-scoping follows the two-layer model:

| Layer | Artifact | Consumer | Contract |
|---|---|---|---|
| Human-facing (**primary**) | the microworld dashboard | a human | interactive; no verdict, no exit-code meaning |
| Machine-facing (**underlying**) | `run.sh`, "the check" | `reviewer`, rerun hook | exit 0 = pass, non-zero = fail |

## Decision

- **Function contract is declarative and language-agnostic** (`functions[]`/`entry`, one JSON object on stdin, argv array, no shell) — rejected per-language runtime introspection (breaks R8, imports agent-written code into the dashboard's own process) and a single `explore.sh` whose stdout is parsed (fragile, no home for per-function inputs).

- **UI shape is a local `node:http` server plus a browser tab** — rejected a true in-terminal TUI (cannot deliver the Clipboard API portably) and a TUI-over-JSON-core hybrid (doubles the UI surface for no capability gain).

- **"Notebook" is a UI/UX framing only, never a kernel:** cells are independent fresh processes sharing no state, and the UI states this on screen. State what would have to change if this is ever reversed — a bundle-provided warm `session` process (an optional, additive manifest field), which would also require redefining guardrail 4 (bounded execution).

- **Cell/Notebook terminology realization** (record verbatim, do not re-litigate #319's already-PASSed work): the user's original phrase "notebook cell" shipped as two distinct terms, **Cell** (one invocation record) and **Notebook** (the per-function ordered list of Cells) — a more precise outcome than the single original phrase, decided at unit #319 and recorded here as an architectural decision, not reopened.

## Retraction and correction

"No daemon is introduced" (`docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`, its architectural-facts prose) is retracted. This plan introduces the plugin's first standing long-running process — the dashboard, `node bin/cli.js --dashboard` — a **foreground process the user starts and stops**, never a background daemon. The original sentence's framing ("no daemon is introduced") is misleading given a long-running process now exists; state plainly that "no daemon" remains true in the narrow sense (nothing detaches or survives the terminal) but the original phrasing is misleading.

Also record that the original citation **miscited constitution P2** ("prefer deterministic scripts over LLM re-derivation") — P2 has nothing to do with process lifecycle. The constraint actually in tension is G4 (zero runtime dependencies, this plan's own global constraint), which the dashboard satisfies by using only `node:http`, `node:crypto`, `fs.watch`, and `child_process`.

## Rationale

### Why the two-layer model

The fixture-only narrowing solved a real problem: the `reviewer` and the `PostToolUse` rerun hook both need a binary result, and a hook cannot wait for human interaction. The machine-facing "check" layer preserves those constraints intact. Layering allows both to coexist: the human-facing dashboard is an exploration surface (never a gate), while the check underneath keeps the gate-firing semantics unchanged.

### Why this function contract

Declarative manifest entries are language-agnostic, honour R8 (no language-specific adapters), and give the dashboard a predictable input/output shape. The dashboard never executes or parses free-form output; each entry is a pre-declared, bounded contract.

### Why this UI shape

A local HTTP server on `node:http` costs zero new dependencies (G4), yields machine-checkable criteria, and is the only shape that makes the Clipboard API available portably in a browser. A terminal UI cannot deliver clipboard-to-system integration without language-specific or platform-specific hacks.

### Why notebook is framing, not kernel

A warm kernel (a persistent session process holding state between cells) would require per-language adapters, exactly the burden R8 was designed to avoid. The user settled this by accepting the framing-only model: cells are independent invocations, and the UI says so explicitly on screen.

## Accepted costs

- **R1 (bundle-authorship unverifiability):** no commit/clone/CI ever sees a gitignored bundle, so nothing can assert `functions[]`/`location` were actually authored.
- **R5 (poor dogfooding):** this repo is a poor target for its own "class and its functions" framing — antislop is bash + a single-file Node CLI + markdown personas, with no classes.
- **R7 (token-in-scrollback exposure):** the per-launch token appears in terminal scrollback and the browser address bar, accepted as a per-launch, non-persisted secret on a loopback-only endpoint.
- **R9 (stale `location` line numbers):** `location.file`/`startLine`/`endLine` can silently go stale when the code moves, and nothing revalidates it automatically. Mitigation, not a fix: the commit SHA at copy time lets a receiving agent re-derive the real location.

## Related decisions

- **ADR 0004 "Heavy unit trigger":** The three criteria that identify when a unit escalates. This ADR's dashboard renders escalation packets (units #322/#325/#326).
- **ADR 0013 "Fable removed from roast-work advisory pass":** Amends ADR 0004. The dashboard escalation rendering depends on the heavy-unit logic.
- **ADR 0017 "Microworld bundles are gitignored":** The storage layer this ADR's dashboard renders.
- **ADR 0018 "Human-in-the-loop review enabled by default":** The escalation-packet consumer this ADR's dashboard also reads, and the context in which escalations matter.
