# Dashboard Capability Register

Inventory of HTTP API routes served by the microworld dashboard (`bin/microworld-dashboard/server.js`), with classification of status (load-bearing or speculative) and citations for load-bearing routes.

The demand gate: a new route, a new manifest field consumed by the dashboard, or a new pane may be added only with a register row citing an actual escalation or debugging session that needed it, or explicitly marked `speculative` with a rationale.

## Capabilities

| Route | Capability | Status | Cited by |
|---|---|---|---|
| `POST /api/invoke` | run a `functions[]` entry (notebook cells) | load-bearing | gate debugging on `hdg-prose-2`, `hdg-anchor-1`, `rpg-canon-2` (`why`, `differential`, `branch`, `arms`, `spelling`, `sites`) |
| `GET /api/bundles`, `GET /api/status` | bundle enumeration + rerun status | load-bearing | surfaces the machine layer; every bundle listing |
| `GET /api/decisions` | four human-decision touchpoints | load-bearing | ADR 0018; inert while `humanReviewMode: "off"` |
| `GET /api/context` | git HEAD sha + userName for decision stamps | load-bearing | stamps every composed decision block |
| `POST /api/decision/arm`, `POST /api/decision/run` | arm/execute a composed decision | load-bearing | ADR 0018 decision surface |
| `GET /api/source` | bounded source excerpt for `location` click-through (load-bearing); general code exploration (speculative) | load-bearing as location click-through; speculative as general code exploration | `location` click-through is exactly what D6 has the reviewer verify |
